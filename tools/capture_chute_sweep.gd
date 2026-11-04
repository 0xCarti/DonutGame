extends SceneTree
## Native rendered proof of the real sweep/physics scene. No controller or save
## APIs are created. Run with --fixed-fps 30 and --audio-driver Dummy.
const OUT: String = "res://playtest-reports/chute-sweep"
var world
var food
var recording: bool = false
var frame_index: int = 0
var close_camera: bool = true
var caption: Label
var stage: String = "partial"
var records: Array = []
var kept: int = 0
var wasted: int = 0
var maximum_tip_mismatch: float = 0.0
var next_id: int = 5000
var inspection_camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/frames"))
	root.size = Vector2i(1280, 800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	inspection_camera = Camera3D.new()
	root.add_child(inspection_camera)
	inspection_camera.position = Vector3(0.05, 3.25, 3.10)
	inspection_camera.look_at(Vector3(-1.40, 2.03, 0.20), Vector3.UP)
	inspection_camera.current = true
	food = world._food
	food.delivery_settled.connect(func(_id: int, retained: bool) -> void:
		if retained: kept += 1
		else: wasted += 1)
	food.stock_spilled.connect(func(_id: int) -> void: wasted += 1)
	var overlay: CanvasLayer = CanvasLayer.new()
	root.add_child(overlay)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(640, 68)
	panel.color = Color(0.035, 0.025, 0.02, 0.82)
	overlay.add_child(panel)
	caption = Label.new()
	caption.position = Vector2(40, 32)
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color("fff0c8"))
	overlay.add_child(caption)
	reset_stage(24)
	caption.text = "Sweeping chute • Live donut physics\n24 donuts in the tray • Production continues"
	await create_timer(0.3).timeout
	recording = true
	record_frames()
	await run_phase(12.0, true)
	await snapshot("01-partial-tray-distributed")
	stage = "full"
	reset_stage(36)
	caption.text = "Full catch tray • Physical overflow\nExtra donuts cross the rim and become waste"
	await run_phase(11.0, false)
	await snapshot("02-full-tray-overflow")
	close_camera = false
	inspection_camera.current = false
	world.camera.current = true
	caption.text = "Player viewpoint\nThe sweeping chute stays above the catch tray"
	await create_timer(1.5).timeout
	await snapshot("03-player-view")
	recording = false
	await process_frame
	var valid: bool = wasted > 0 and maximum_tip_mismatch < 0.001
	var file: FileAccess = FileAccess.open(OUT + "/capture-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames": frame_index, "frame_rate": 30, "kept": kept, "wasted": wasted, "maximum_visual_outlet_mismatch": maximum_tip_mismatch, "samples": records, "valid": valid}, "  "))
	file.close()
	world.queue_free()
	inspection_camera.queue_free()
	overlay.queue_free()
	await process_frame
	await process_frame
	print("CHUTE_SWEEP_CAPTURE_COMPLETE frames=%d wasted=%d max_tip_mismatch=%f valid=%s" % [frame_index, wasted, maximum_tip_mismatch, valid])
	quit(0 if valid else 1)


func reset_stage(stock: int) -> void:
	world.reset_food(stock, 36)
	world.sync_state({"phase":"playing", "paused":false, "temperature":180, "batter":72, "supply":stock, "supply_capacity":36, "package_type":"", "held_tool":"none", "orders":[]})
	food.set_machine_running(true)
	food.set_paused(false)
	world._view_hands.visible = false


func run_phase(duration: float, demonstrate_controls: bool) -> void:
	var elapsed: float = 0.0
	var next_production: float = 0.0
	var shook: bool = false
	var captured_left: bool = false
	var captured_right: bool = false
	var paused_now: bool = false
	var jammed_now: bool = false
	while elapsed < duration:
		await process_frame
		var delta: float = minf(root.get_process_delta_time(), 0.1)
		elapsed += delta
		var should_pause: bool = demonstrate_controls and elapsed >= 6.8 and elapsed < 7.55
		var should_jam: bool = demonstrate_controls and elapsed >= 9.1 and elapsed < 9.85
		if should_pause != paused_now or should_jam != jammed_now:
			paused_now = should_pause
			jammed_now = should_jam
			world.sync_state({"phase":"playing", "paused":paused_now, "jammed":jammed_now, "temperature":180, "batter":72, "supply":food.get_available_count(), "supply_capacity":36, "package_type":"", "held_tool":"none", "orders":[]})
			food.set_machine_running(not jammed_now)
			food.set_paused(paused_now)
			caption.text = "Paused • Chute and donuts hold their position" if paused_now else ("Machine jam • Sweep and feed stop together" if jammed_now else "Sweeping chute • Production resumed\nDonuts spread across the catch tray")
		if paused_now or jammed_now:
			next_production += delta
		else:
			while elapsed >= next_production:
				food.enqueue_production(next_id)
				next_id += 1
				next_production += 0.615
		if demonstrate_controls and not shook and elapsed >= 3.0:
			shook = true
			world.shake_tray()
			world.animate_action("tray_shake")
			caption.text = "Gentle tray shake\nRigid donuts loosen and settle back into the tray"
		if demonstrate_controls and elapsed >= 4.3 and elapsed < 4.4:
			caption.text = "Sweeping chute • Live donut physics\nA smooth sweep distributes the falling donuts"
		if int(elapsed * 10.0) % 28 == 0:
			var mismatch: float = world._discharge_chute_tip.global_position.distance_to(food.conveyor_position(1.0))
			maximum_tip_mismatch = maxf(maximum_tip_mismatch, mismatch)
		if demonstrate_controls and food.conveyor_position(1.0).x < -1.855 and not captured_left:
			captured_left = true
			snapshot("sweep-left")
		if demonstrate_controls and food.conveyor_position(1.0).x > -0.990 and not captured_right:
			captured_right = true
			snapshot("sweep-right")


func record_frames() -> void:
	while recording:
		await RenderingServer.frame_pre_draw
		world._view_hands.visible = false
		await RenderingServer.frame_post_draw
		if not recording: break
		root.get_texture().get_image().save_jpg(OUT + "/frames/frame-%05d.jpg" % frame_index, 0.86)
		frame_index += 1


func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")
	records.append({"label":label, "frame":frame_index, "stage":stage, "food":food.debug_snapshot()})
	print("CHUTE_SWEEP_SAMPLE " + label)
