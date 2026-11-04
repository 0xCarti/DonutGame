extends SceneTree
const OUT = "res://playtest-reports/counter-1.0.3"
var world

func _init() -> void:
	call_deferred("_run")

func capture(label: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world._view_hands.visible = false
	world.reset_food(18, 30)
	world.sync_state({"phase":"playing", "supply":18, "supply_capacity":30, "package_type":"bag", "package_count":6, "package_flavor":"cinnamon"})
	world._food.set_paused(true)
	await capture("00-player-view")
	world.camera.position = Vector3(-2.05, 3.85, 4.10)
	world.camera.look_at(Vector3(-3.15, 1.20, 2.35), Vector3.UP)
	world.camera.fov = 48.0
	await capture("01-recessed-well")
	world.camera.position = Vector3(1.55, 2.90, 3.70)
	world.camera.look_at(Vector3(0.55, 2.00, 2.0), Vector3.UP)
	world.camera.fov = 42.0
	await capture("02-filled-bag")
	world.queue_free()
	await process_frame
	print("COUNTER_CAPTURE_COMPLETE")
	quit()
