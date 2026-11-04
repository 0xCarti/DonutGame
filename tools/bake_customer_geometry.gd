extends SceneTree
## Build original offline geometry; never creates the controller or save system.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var world=load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world._customer_bake_mode=true
	for id in range(6):
		var person: Node3D=world._make_customer(id)
		person.queue_free()
		await process_frame
	var library: Resource=load("res://scripts/customer_geometry.gd").new()
	library.format_version=world.CUSTOMER_GEOMETRY_VERSION
	library.meshes=world._customer_mesh_cache.duplicate()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models"))
	var result: int=ResourceSaver.save(library,"res://assets/models/fairgoer_geometry.res",ResourceSaver.FLAG_COMPRESS)
	print("CUSTOMER_GEOMETRY_BAKE result=",result," meshes=",library.meshes.size())
	world.queue_free()
	await process_frame
	await process_frame
	quit(result)
