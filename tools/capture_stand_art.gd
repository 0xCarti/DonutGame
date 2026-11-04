extends SceneTree
## Actual runtime meshes/materials from three review angles; no player save data.
const OUT: String = "res://playtest-reports/stand-art-1.0.3"
var world

func _init() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.reset_food(24, 36)
	world.sync_state({"phase":"playing", "temperature":180.0, "heat_setting":2, "batter":40, "supply":24, "supply_capacity":36, "package_type":"bag", "package_count":6, "package_flavor":"cinnamon", "held_tool":"none", "scoop_count":0, "orders":[]})
	await create_timer(1.2).timeout
	await _capture("01-player-view")
	world._view_hands.visible = false
	world._process(0.016)
	world.set_process(false)
	world._food.set_paused(true)
	world.camera.fov = 40.0
	world.camera.position = Vector3(2.0, 2.65, 2.45)
	world.camera.look_at(Vector3(1.98, 2.10, 0.63), Vector3.UP)
	await _capture("02-shakers")
	world.camera.fov = 40.0
	world.camera.position = Vector3(-1.40, 4.35, 2.0)
	world.camera.look_at(Vector3(-1.40, 1.82, 0.93), Vector3.UP)
	await _capture("03-mini-donut-tray")
	world.reset_food(0, 36)
	world.queue_free()
	await process_frame
	await process_frame
	print("STAND_ART_CAPTURE_COMPLETE")
	quit()
