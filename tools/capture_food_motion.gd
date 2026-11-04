extends SceneTree
## Captures the actual native 3D conveyor/tray motion without player save access.
var world


func _init() -> void:
	call_deferred("_run")


func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://playtest-reports/food-motion-%s.png" % label)
	root.get_texture().get_image().save_png(path)
	print("FOOD_MOTION_CAPTURE " + label)


func _run() -> void:
	root.size = Vector2i(1280, 800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.sync_state({"phase":"playing", "temperature":180, "batter":40, "supply":36, "supply_capacity":36, "package_type":"", "held_tool":"", "orders":[]})
	world._view_hands.visible = false
	world.camera.position = Vector3(-0.05, 3.1, 2.8)
	world.camera.look_at(Vector3(-1.25, 2.0, -0.05), Vector3.UP)
	var food = world._food
	food.seed_stock(36, 36)
	food.set_machine_running(true)
	food.set_paused(false)
	food.enqueue_production(8001)
	food._entries.back().progress = 0.55
	for index in range(18):
		await create_timer(0.20).timeout
		await capture("%02d" % index)
	await create_timer(2.0).timeout
	await capture("counter-rest")
	var result: Dictionary = food.debug_snapshot()
	print("FOOD_MOTION_RENDER_COMPLETE available=%d waste=%d pending=%d" % [result.available, result.waste, result.falling + result.conveyor])
	world.queue_free()
	await process_frame
	quit(0)
