extends SceneTree
## Actual controller actions with isolated persistence. Optional frame recording
## uses --fixed-fps 30 so review footage has a defined simulation rate.
const Controller = preload("res://scripts/stand_main.gd")
const DEFAULT_OUT: String = "res://playtest-reports/counter-flow-1.0.4"
var output_directory: String = DEFAULT_OUT
var app
var recording: bool = false
var frame_index: int = 0
var stages: Array = []

func _init() -> void:
	call_deferred("_run")

func _snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_directory + "/" + label + ".png")

func _record() -> void:
	while recording:
		await RenderingServer.frame_post_draw
		if not recording: break
		root.get_texture().get_image().save_jpg(output_directory + "/frames/frame-%05d.jpg" % frame_index, 0.85)
		frame_index += 1

func _perform(station: String, label: String) -> void:
	var before: int = frame_index
	app._act(station)
	await create_timer(0.22).timeout
	await _snapshot(label + "-grasp")
	await create_timer(0.20).timeout
	await _snapshot(label + "-moving")
	while app.world.is_action_busy(): await process_frame
	await _snapshot(label + "-end")
	stages.append({"action": station, "frames": frame_index - before, "held": app.held_tool, "scoop_count": app.model.scoop_count, "package": app.model.package_type})

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output_directory = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory + "/frames"))
	root.size = Vector2i(1280, 800)
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.audio.set_muted(true)
	app._start_practice()
	await create_timer(0.8).timeout
	recording = OS.get_cmdline_user_args().has("--record")
	if recording: _record()
	await _perform("scoop", "01-scoop-first")
	await _perform("bag", "02-free-hand-bag")
	await _perform("supply", "03-loaded-scoop")
	await _perform("bucket", "04-free-hand-bucket")
	await _perform("bag", "05-return-to-bag")
	await _perform("package", "06-pour")
	var valid: bool = app.held_tool == "scoop" and app.model.package_count == 3 and app.model.scoop_count == 0
	await _perform("trash", "07-clear-counter")
	# Stop new production while inspecting redistribution of existing stock.
	app.set_process(false)
	app.model.jammed = true
	app.model.supply = 24
	app.world.reset_food(24, app.model.supply_capacity)
	app._sync_world()
	await create_timer(1.4).timeout
	await _snapshot("08-before-shake")
	await _perform("supply", "09-shake")
	await create_timer(1.5).timeout
	await _snapshot("10-after-shake")
	recording = false
	await RenderingServer.frame_post_draw
	var file: FileAccess = FileAccess.open(output_directory + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": Controller.VERSION, "valid": valid, "frames": frame_index, "frame_rate": 30, "actions": stages}, "\t"))
	file.close()
	# Audio playback releases its WAV references on the mixer thread. The
	# fixed-fps capture can finish its last two rendered frames before that
	# thread ticks, so allow a small real-time drain before freeing the scene.
	app.set_process(false)
	app.audio.set_process(false)
	for child in app.audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	var audio_drain_until: int = Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < audio_drain_until:
		await process_frame
	app.world.reset_food(0, 30)
	app.queue_free()
	await process_frame
	await process_frame
	print("COUNTER_FLOW_CAPTURE valid=", valid, " frames=", frame_index)
	quit(0 if valid else 1)
