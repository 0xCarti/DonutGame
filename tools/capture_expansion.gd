extends SceneTree
## Render the actual expansion screens; never load or save a player's career.
const Controller = preload("res://scripts/stand_main.gd")
var app

func _init() -> void:
	call_deferred("_run")

func capture(label: String) -> void:
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	var destination = ProjectSettings.globalize_path("res://playtest-reports/expansion-" + label + ".png")
	root.get_texture().get_image().save_png(destination)
	print("EXPANSION_CAPTURE " + destination)

func _run() -> void:
	root.size = Vector2i(1280,800)
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false)
	app.audio.set_muted(true)
	app.profile.tickets = 700
	for index in [0,6,12]:
		app.model.new_run(724)
		app.model.shift_index = index
		app.model.start_shift()
		app._show_play()
		app._sync_world()
		app._refresh_hud()
		await capture(["fairground","concert","stadium"][index / 6])
	app._show_collection()
	await capture("collection")
	app._show_market()
	await capture("market-sets")
	app._market_category = "buffs"
	app._show_market()
	await capture("market-buffs")
	app._market_preview("neon_midway")
	await capture("preview-neon")
	app._end_market_preview()
	app._close_overlay()
	app._badge_page = 2
	app._show_mobile_badges()
	await capture("badges-last-page")
	app._close_overlay()
	app.mobile_mode = true
	app._show_play()
	app._sync_world()
	app._refresh_hud()
	await capture("mobile-play")
	app.dashboard.mobile_controls.set_tools_open(true)
	app.dashboard.mobile_controls._show_page(true)
	await capture("mobile-tools")
	app._show_collection()
	app._market_category = "operator"
	app._market_page = 1
	app._show_market()
	await capture("mobile-market")
	app._close_overlay()
	app.model.new_run(724)
	app._show_opening()
	await capture("opening")
	app.audio.stop_music()
	app.queue_free()
	await process_frame
	await process_frame
	print("EXPANSION_RENDER_COMPLETE")
	quit(0)
