extends SceneTree
## Matched hand closeups, then real-controller poses. All player data is isolated.
const Controller = preload("res://scripts/stand_main.gd")
const OUT = "res://playtest-reports/hand-detail"
var app
var label: String = "after"

func _init() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + "-" + name + ".png")

func _act(station: String) -> void:
	app._act(station)
	while app.world.is_action_busy(): await process_frame

func _run() -> void:
	if OS.get_cmdline_user_args().has("--before"): label = "before"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 800)
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.audio.set_muted(true)
	app._start_practice()
	await create_timer(0.8).timeout
	await _act("bag")
	await _act("scoop")
	await _capture("scoop")
	await _act("supply")
	app._act("package")
	await create_timer(0.43).timeout
	await _capture("pour")
	while app.world.is_action_busy(): await process_frame
	app.set_process(false)
	app.world.set_process(false)
	app.world._food.set_paused(true)
	app.ui.visible = false
	app.world._held_scoop.visible = false
	app.world.camera.fov = 45.0
	for index in range(2):
		var hand: Node3D = app.world._hands[index]
		hand.position = Vector3(-0.20 if index == 0 else 0.20, -0.09, -0.84)
		hand.rotation = Vector3(PI * 0.5, 0, 0)
		for finger in app.world._finger_joints[index]: finger.rotation.x = 0.08
		if app.world.has_method("_pose_player_fingers"): app.world._pose_player_fingers(index, false, 1.0)
		for part in [app.world._arm_rigs[index].upper, app.world._arm_rigs[index].fore, app.world._arm_rigs[index].joint]: part.visible = false
	await _capture("dorsal-closeup")
	for index in range(2):
		app.world._hands[index].rotation.x = -PI * 0.5
	await _capture("palm-closeup")
	for child in app.audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await create_timer(0.2).timeout
	app.world.reset_food(0,30)
	app.queue_free()
	await process_frame
	await process_frame
	print("HAND_DETAIL_CAPTURE ", label, " complete")
	quit()
