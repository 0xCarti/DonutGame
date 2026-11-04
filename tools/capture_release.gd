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
	for customer in range(10):
		var safety = 0
		while app.model.orders.is_empty() or app.model.supply < 12:
			app.model.tick_practice(.1)
			if app.model.jammed: app.model.repair(.1)
			if app.model.batter < 20: app.model.refill(.1)
			if app.model.temperature > 185: app.model.adjust_heat(-1)
			if app.model.temperature < 160: app.model.adjust_heat(1)
			safety += 1
			if safety > 2000:
				push_error("Capture could not prepare next real order")
				quit(1)
				return
		var order: Dictionary = app.model.orders[0]
		app._act(str(order.package))
		app._act("scoop")
		while app.model.package_count < app.model.package_capacity():
			app._act("supply")
			app._act("package")
		app._act(str(order.flavor))
		app._act("package")
		if customer == 0: await _capture("handoff")
		app._act("serve")
		if customer in [0,2,5,9]:
			await create_timer(.46).timeout
			await _capture("sale-%d" % (customer+1))
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
