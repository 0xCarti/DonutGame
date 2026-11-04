extends SceneTree
## A short real-clock sample of the actual game with its fire effect updating.
## No screenshots, fixed-fps simulation, synthetic workloads or persistent saves.
var app
var output_directory: String = "res://playtest-reports/fire-performance"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output_directory = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.position = Vector2i(-32000, -32000)
	root.size = Vector2i(1920, 1080)
	app = load("res://scripts/stand_main.gd").new()
	app.test_mode = true
	root.add_child(app)
	app.audio.set_muted(true)
	app._start_practice()
	app.model.fire_active = true
	app.model.fire_danger = 1.0
	app.model.overheated = true
	app.model.temperature = 230.0
	app.model.heat_setting = 4
	app._sync_world()
	var viewport_rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	var warmup_until: int = Time.get_ticks_usec() + 2000000
	while Time.get_ticks_usec() < warmup_until: await process_frame
	var fire_clock_before: float = app.world._fire_visual.debug_snapshot().clock
	var sample_start: int = Time.get_ticks_usec()
	var previous: int = sample_start
	var frame_times: Array[float] = []
	while Time.get_ticks_usec() - sample_start < 3000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
	var wall_ms: float = float(previous - sample_start) / 1000.0
	var fire_clock_after: float = app.world._fire_visual.debug_snapshot().clock
	var sorted_frames: Array[float] = frame_times.duplicate()
	sorted_frames.sort()
	var snapshot: Dictionary = app.world._fire_visual.debug_snapshot()
	# Capture only the dimensions after timing ends. ViewportTexture.get_size()
	# reports a stretch-scaled logical size on this Windows renderer; the readback
	# image is the actual backing-buffer pixel count verified by the display probe.
	var actual_pixels: Vector2i = root.get_texture().get_image().get_size()
	var report := {
		"version": app.VERSION,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"window": str(DisplayServer.window_get_size()),
		"render_pixels": str(actual_pixels),
		"window_offscreen": true,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"engine_max_fps": Engine.max_fps,
		"warmup_seconds": 2.0,
		"wall_ms": wall_ms,
		"frames": frame_times.size(),
		"mean_fps": float(frame_times.size()) * 1000.0 / wall_ms,
		"mean_frame_ms": wall_ms / float(frame_times.size()),
		"median_frame_ms": sorted_frames[int(sorted_frames.size() * 0.5)],
		"p95_frame_ms": sorted_frames[mini(sorted_frames.size() - 1, int(sorted_frames.size() * 0.95))],
		"worst_frame_ms": sorted_frames[-1],
		"last_render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),
		"last_render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid),
		"fire_clock_advanced_seconds": fire_clock_after - fire_clock_before,
		"fire": snapshot,
		"frame_times_ms": frame_times,
		"note": "Short native offscreen sample on this machine, default vsync; no screenshot overhead. Not a minimum hardware benchmark."
	}
	var valid: bool = snapshot.active and snapshot.visible and fire_clock_after - fire_clock_before > 1.0 and actual_pixels == Vector2i(1920, 1080)
	report["valid"] = valid
	var file := FileAccess.open(output_directory + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	report.erase("frame_times_ms")
	print("FIRE_PERFORMANCE " + JSON.stringify(report))
	app.set_process(false)
	app.world.set_process(false)
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
	quit(0 if valid else 1)
