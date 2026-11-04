extends SceneTree
## Real controller capture, with no writes to player saves. Each action finishes
## on its actual animation gate rather than a guessed fixed delay.
const Controller = preload("res://scripts/stand_main.gd")
const OUT = "res://playtest-reports/hand-motion"
var app
var frame_index: int = 0
var recording: bool = false
var stages: Array = []
var poses_only: bool = false

func _init() -> void:
	call_deferred("_run")

func _record() -> void:
	while recording:
		await RenderingServer.frame_post_draw
		if not recording: break
		root.get_texture().get_image().save_jpg(OUT + "/frames/frame-%05d.jpg" % frame_index, 0.82)
		frame_index += 1

func _snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")

func _perform(station: String, label: String) -> void:
	var before: int = frame_index
	var before_clock: float = app.world._time
	app._act(station)
	await create_timer(0.10).timeout
	await _snapshot(label + "-reach")
	await create_timer(0.30).timeout
	await _snapshot(label + "-middle")
	while app.world.is_action_busy() or not app._queued_action.is_empty():
		await process_frame
	await _snapshot(label + "-end")
	stages.append({"action": station, "frames": frame_index - before, "game_seconds": app.world._time - before_clock})

func _run() -> void:
	poses_only = OS.get_cmdline_user_args().has("--poses-only")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/frames"))
	root.size = Vector2i(1280, 800)
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.audio.set_muted(true)
	app._start_practice()
	await create_timer(0.75).timeout
	recording = not poses_only
	if recording: _record()
	await _snapshot("00-idle")
	await _perform("bag", "01-bag")
	await _perform("scoop", "02-scoop")
	await _perform("supply", "03-fill-scoop")
	await _perform("package", "04-pour")
	await _perform("supply", "05-fill-scoop")
	await _perform("package", "06-pour")
	await _perform("cinnamon", "07-season")
	await _perform("package", "08-lift")
	await _perform("serve", "09-handoff")
	var served: int = app.model.served
	await _perform("supply", "10-shake-tray")
	app._act("heat_down")
	await create_timer(0.08).timeout
	await _snapshot("11-single-dial")
	await create_timer(0.7).timeout
	app.model.batter = 10
	app._start_hold("refill")
	await create_timer(0.35).timeout
	await _snapshot("12-pitcher-reach")
	await create_timer(0.50).timeout
	await _snapshot("13-pitcher-pour")
	app._stop_hold()
	await create_timer(0.8).timeout
	await _snapshot("14-pitcher-return")
	recording = false
	await RenderingServer.frame_post_draw
	var file: FileAccess = FileAccess.open(OUT + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"served": served, "frames": frame_index, "actions": stages}, "\t"))
	file.close()
	print("HAND_MOTION_CAPTURE served=", served, " frames=", frame_index, " actions=", JSON.stringify(stages))
	app.set_process(false)
	for child in app.audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await create_timer(0.2).timeout
	app.world.reset_food(0, 30)
	app.queue_free()
	await process_frame
	await process_frame
	quit(0 if served == 1 else 1)
