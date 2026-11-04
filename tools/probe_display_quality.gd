extends SceneTree
## Native GPU diagnostic; never instantiates persistence or touches user saves.
var rows: Array = []
var app
var output_directory: String = "res://playtest-reports/display-quality"
var capture_game: bool = false
var check_fullscreen: bool = false
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output_directory = argument.trim_prefix("--out=")
		if argument == "--game": capture_game = true
		if argument == "--fullscreen-check": check_fullscreen = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.position = Vector2i(-32000, -32000)
	if capture_game:
		app = load("res://scripts/stand_main.gd").new()
		app.test_mode = true
		root.add_child(app)
		app.audio.set_muted(true)
		app._start_practice()
		await create_timer(0.6).timeout
		app.set_process(false)
		app.world.set_process(false)
	for dimensions in [Vector2i(906, 920), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		await _inspect("window-" + str(dimensions.x) + "x" + str(dimensions.y), dimensions)
	if check_fullscreen:
		# Use the game's own F11 handler, not operating-system key injection.
		if capture_game:
			var event := InputEventKey.new()
			event.keycode = KEY_F11
			event.pressed = true
			app._unhandled_input(event)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		await _inspect("fullscreen", DisplayServer.screen_get_size())
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		root.position = Vector2i(-32000, -32000)
	var report := {"samples": rows, "failures": failures}
	var file := FileAccess.open(output_directory + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("DISPLAY_PROBE " + JSON.stringify(rows))
	if capture_game:
		app.audio.set_process(false)
		for child in app.audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		var drain_until: int = Time.get_ticks_msec() + 250
		while Time.get_ticks_msec() < drain_until: await process_frame
		app.world.reset_food(0, 30)
		app.queue_free()
		await process_frame
		await process_frame
	quit(1 if failures else 0)

func _inspect(label: String, dimensions: Vector2i) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var sample := {"label": label, "requested": str(dimensions), "window": str(DisplayServer.window_get_size()), "viewport": str(root.get_visible_rect().size), "render_pixels": str(image.get_size()), "content_scale_size": str(root.content_scale_size), "stretch_mode": root.content_scale_mode, "3d_scale": root.scaling_3d_scale, "msaa_3d": root.msaa_3d, "screen": str(DisplayServer.screen_get_size()), "dpi": DisplayServer.screen_get_dpi(), "scale": DisplayServer.screen_get_scale(), "allow_hidpi": ProjectSettings.get_setting("display/window/dpi/allow_hidpi"), "anisotropic_filtering_level": ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level")}
	if image.get_size() != dimensions:
		failures += 1
		push_error(label + " render dimensions do not match the output window")
	if capture_game:
		image.save_png(output_directory + "/" + label + ".png")
		var targets_ok: bool = true
		var targets_inside: bool = true
		var failed_targets: Array[String] = []
		var viewport_rect: Rect2 = root.get_visible_rect()
		for station in app.world._stations:
			var point: Vector2 = app.world.station_screen_position(station)
			var ray_ok: bool = app.world.pick_station(point) == station
			var inside: bool = viewport_rect.has_point(point)
			targets_ok = targets_ok and ray_ok
			targets_inside = targets_inside and inside
			if not ray_ok or not inside: failed_targets.append(station + ": " + str(point))
		sample["station_rays_correct"] = targets_ok
		sample["all_stations_inside_viewport"] = targets_inside
		sample["station_count"] = app.world._stations.size()
		sample["failed_targets"] = failed_targets
		sample["camera_vertical_fov"] = app.world.camera.fov
		if not targets_ok or not targets_inside:
			failures += 1
			push_error(label + " interaction targets must remain visible and clickable: " + str(failed_targets))
	rows.append(sample)
