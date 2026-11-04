extends SceneTree
## Native rendered QA, isolated from player saves. Captures actual service output.
const Controller = preload("res://scripts/stand_main.gd")
var app

func _init() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path = "res://playtest-reports/release-%s.png" % label
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("RELEASE_CAPTURE " + path)

func _perform(station: String) -> void:
	app._act(station)
	# Actions now finish on visible hand/prop movement, including low frame rates.
	var deadline: int = Time.get_ticks_msec() + 4000
	while app.world.is_action_busy() or not app._queued_action.is_empty():
		await process_frame
		if Time.get_ticks_msec() > deadline:
			push_error("Capture action did not complete: " + station)
			quit(1)
			return
	await process_frame

func _wait_for_stock() -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while app.model.orders.is_empty() or app.model.supply < 12:
		if not app.world.is_action_busy() and app.hold_station.is_empty():
			if app.model.jammed: app._start_hold("repair")
			elif app.model.batter < 20: app._start_hold("refill")
		await create_timer(0.1).timeout
		if Time.get_ticks_msec() > deadline:
			push_error("Capture could not prepare the next physical order")
			quit(1)
			return
	# Finish an already-started maintenance action before touching food.
	while not app.hold_station.is_empty():
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280,800)
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false)
	app.audio.set_muted(true)
	await process_frame
	await process_frame
	await _capture("title")
	app.model.new_run(4182)
	app.model.start_shift()
	app._show_play()
	app._sync_world()
	await create_timer(.4).timeout
	await _capture("gameplay")
	# Practice uses the same order handling and receipts, with a frozen clock so
	# every celebration tier can be rendered without skipping campaign rules.
	app._start_practice()
	# Keep the real controller event pump and rigid-body simulation active. Model
	# stock is credited only after these actual conveyor bodies land in the tray.
	app.set_process(true)
	await _perform("heat_down")
	for customer in range(10):
		await _wait_for_stock()
		var order: Dictionary = app.model.orders[0]
		await _perform(str(order.package))
		await _perform("scoop")
		while app.model.package_count < app.model.package_capacity():
			await _perform("supply")
			await _perform("package")
		await _perform(str(order.flavor))
		await _perform("package")
		if customer == 0: await _capture("handoff")
		await _perform("serve")
		if customer in [0,2,5,9]:
			await _capture("sale-%d" % (customer+1))
	app.set_process(false)
	app.model.jammed = true
	app._sync_world()
	app._refresh_hud()
	await _capture("jam")
	app.model.jammed = false
	app.model.overheated = true
	app.model.temperature = 210
	app._sync_world()
	app._refresh_hud()
	await _capture("overheat")
	app._show_settings()
	await _capture("settings")
	app._close_overlay()
	app.practice = false
	app.model.sales = app.model.target
	app.model.finish_shift()
	app._show_shop()
	await _capture("shop")
	app._show_collection()
	await _capture("collection")
	print("RELEASE_RENDER_QA_COMPLETE served=%d" % app.model.get_stats().total_served)
	for player in app.audio.get_children(): player.stop()
	await create_timer(.2).timeout
	app.queue_free()
	await process_frame
	await process_frame
	quit(0)
