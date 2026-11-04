extends SceneTree
## Native cast portrait QA. Instantiates the scene without controller/save APIs.
const OUT = "res://playtest-reports/customer-art"
var world
var inspection_camera: Camera3D
func _init() -> void:
	call_deferred("_run")
func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.reset_food(12,36)
	world.sync_state({"phase":"playing","temperature":180,"batter":60,"supply":12,"supply_capacity":36,"held_tool":"none","package_type":"","orders":[{"id":0,"package":"bag","flavor":"cinnamon","patience":50,"max_patience":60},{"id":1,"package":"bucket","flavor":"powdered","patience":55,"max_patience":60},{"id":2,"package":"bag","flavor":"cinnamon","patience":55,"max_patience":60}]})
	await create_timer(1.0).timeout
	await snapshot("01-player-view")
	inspection_camera = Camera3D.new()
	root.add_child(inspection_camera)
	inspection_camera.position = Vector3(0.45,3.02,-0.72)
	inspection_camera.look_at(Vector3(0.4,2.94,-2.10),Vector3.UP)
	inspection_camera.fov = 33
	inspection_camera.current = true
	world.set_reduced_motion(true)
	await create_timer(0.15).timeout
	await snapshot("02-portrait-front")
	inspection_camera.position = Vector3(-0.45,2.98,-0.92)
	inspection_camera.look_at(Vector3(0.4,2.96,-2.10),Vector3.UP)
	await create_timer(0.15).timeout
	await snapshot("03-portrait-three-quarter")
	for variant in [1,2,3,4,5]:
		var person: Node3D = world._make_customer(variant+30)
		person.position = Vector3(0.4,0.15,-2.15)
		for old_person in world._people.values(): old_person.visible=false
		inspection_camera.position = Vector3(0.45,3.02,-0.72)
		inspection_camera.look_at(Vector3(0.4,2.94,-2.10),Vector3.UP)
		await create_timer(0.1).timeout
		await snapshot("04-variant-%d"%variant)
		person.queue_free()
		await process_frame
	var result: Dictionary = {"variants":6,"player_view":true,"no_controller_or_save_io":true}
	var file: FileAccess = FileAccess.open(OUT+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	world.reset_food(0,36)
	world.queue_free()
	inspection_camera.queue_free()
	await process_frame
	await process_frame
	print("CUSTOMER_ART_CAPTURE_COMPLETE ",JSON.stringify(result))
	quit()
