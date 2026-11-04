extends SceneTree
## Rendered, real-time motion inspection. The controller's test mode prevents
## all player-data writes. Frames capture the actual scene, not a mockup.
const Controller = preload("res://scripts/stand_main.gd")
const OUT = "res://playtest-reports/motion-1.0.1"
var app
var recording = true
var frame_index = 0
var stage = "opening"
var report: Array = []

func _init() -> void:
	call_deferred("_run")

func _record_frames() -> void:
	while recording:
		await RenderingServer.frame_post_draw
		if not recording: break
		root.get_texture().get_image().save_jpg(OUT + "/frames/frame-%05d.jpg" % frame_index, 0.82)
		frame_index += 1

func _snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")
	var food: Dictionary = app.world._food.debug_snapshot()
	report.append({"stage": label, "frame": frame_index, "supply": app.model.supply, "waste": app.model.waste_count, "pending": app.model.pending_delivery_ids(), "physics": food})
	print("MOTION_CAPTURE ", label, " stock=", app.model.supply, " physical=", food.available, " waste=", app.model.waste_count)

func _perform(station: String) -> void:
	app._act(station)
	await create_timer(0.60).timeout

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/frames"))
	root.size = Vector2i(1280,800)
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.audio.set_muted(true)
	app._start_practice()
	app.world.set_hover_station("bag")
	await create_timer(0.3).timeout
	_record_frames()
	await _snapshot("01-object-highlight")
	app._act("bag")
	await create_timer(0.20).timeout
	await _snapshot("02-bag-in-flight")
	app._act("scoop") # Deliberately buffer this while the bag is travelling.
	await create_timer(0.8).timeout
	await _snapshot("03-scoop-picked-up")
	await _perform("supply")
	await _perform("package")
	await _perform("supply")
	await _perform("package")
	await _perform("cinnamon")
	await _perform("package")
	await _snapshot("04-order-in-hand")
	await _perform("serve")
	await _perform("heat_down")
	await _snapshot("05-delivered-and-dial-turned")
	var served_orders: int = app.model.served
	# A controlled full-tray scenario isolates the overflow mechanics. No quota,
	# receipt or campaign progress is fabricated or persisted by this harness.
	app._start_practice()
	app.model.supply = app.model.supply_capacity
	app.model.heat_setting = 2
	app.world.reset_food(app.model.supply, app.model.supply_capacity)
	app._sync_world()
	await create_timer(0.5).timeout
	await _snapshot("06-full-tray")
	await create_timer(4.2).timeout
	await _snapshot("07-donuts-on-incline")
	await create_timer(2.0).timeout
	await _snapshot("08-discharge-and-landing")
	await create_timer(4.0).timeout
	await _snapshot("09-overflow-on-counter")
	await create_timer(2.0).timeout
	await _snapshot("10-overflow-continued")
	app._show_pause()
	await create_timer(0.35).timeout
	recording = false
	var file = FileAccess.open(OUT + "/motion-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames": frame_index, "served_orders": served_orders, "samples": report}, "\t"))
	file.close()
	var valid: bool = served_orders == 1 and app.model.waste_count > 0 and app.model.supply == app.world._food.get_available_count()
	print("MOTION_RENDER_COMPLETE frames=", frame_index, " served_first_order=", served_orders, " overflow=", app.model.waste_count, " valid=", valid)
	app.queue_free()
	await process_frame
	await process_frame
	quit(0 if valid else 1)
