extends SceneTree
## Test actual opening geometry, physics, interaction and below-counter disposal.
var checks: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func ray(world, point: Vector2) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, 2.0, point.y), Vector3(point.x, 0.3, point.y), 2))

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var orphaned_before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.sync_state({"phase":"playing", "supply":0, "supply_capacity":30})
	check(world._paper_bag_scene != null, "Detailed bag resources are ready before the first pickup")
	check(world.find_children("PaperBag", "Node3D", true, false).is_empty(), "Prewarming does not leave visible or hidden template geometry in the stand")
	var parent_a: Node3D = Node3D.new()
	var parent_b: Node3D = Node3D.new()
	world.add_child(parent_a)
	world.add_child(parent_b)
	var first_bag: Node3D = world._make_package("bag", parent_a)
	var second_bag: Node3D = world._make_package("bag", parent_b)
	var first_shell: MeshInstance3D = first_bag.get_node("PaperBagShell")
	var second_shell: MeshInstance3D = second_bag.get_node("PaperBagShell")
	check(first_bag != second_bag and first_bag.get_parent() == parent_a and second_bag.get_parent() == parent_b, "Every cached bag receives its own parent and node identity")
	check(first_shell != second_shell, "Every cached bag receives independent render nodes")
	check(first_shell.mesh == second_shell.mesh, "Cached bags share the baked detailed mesh resource")
	check(first_shell.material_override == second_shell.material_override, "Cached bags share immutable kraft material resources")
	first_shell.material_overlay = StandardMaterial3D.new()
	check(second_shell.material_overlay == null, "Highlighting one cached bag cannot highlight another bag")
	first_bag.position = Vector3(2, 0, 0)
	check(second_bag.position.is_zero_approx(), "Moving one cached bag cannot move another bag")
	first_bag.free()
	check(is_instance_valid(second_shell) and second_shell.mesh != null, "Discarding one cached bag preserves the other bag and shared resources")
	parent_a.free()
	parent_b.free()
	await physics_frame
	await physics_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphaned_before, "Prewarming frees the temporary template without orphaning nodes")
	var opening: Rect2 = Rect2(-3.70, 1.84, 1.10, 1.02)
	var panels: int = 0
	for node in world.get_children():
		if node is MeshInstance3D and node.has_meta("counter_panel"):
			panels += 1
			var box: AABB = node.global_transform * node.get_aabb()
			var overlap: Rect2 = opening.intersection(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
			check(overlap.get_area() < 0.000001, "Counter wood never covers the discard aperture")
	check(panels >= 25, "Counter is built from individually cut substrate panels and planks")
	var center_hit: Dictionary = ray(world, opening.get_center())
	check(not center_hit.is_empty() and center_hit.position.y < 0.8, "Vertical ray passes through real aperture to recessed well floor")
	for point in [Vector2(-3.78, 2.35), Vector2(-2.52, 2.35), Vector2(-3.15, 1.76), Vector2(-3.15, 2.94)]:
		var hit: Dictionary = ray(world, point)
		check(not hit.is_empty() and absf(hit.position.y - 1.70) < 0.002, "Counter remains solid beside each edge of opening")
	check(world.pick_station(world.station_screen_position("trash")) == "trash", "Recessed discard remains clickable at its visible center")
	check(world._station_meshes.trash.size() >= 4, "Discard has actual rim and wall meshes for subtle highlight")
	var fixed_surfaces: Dictionary = {}
	for surface in world._food._surfaces.get_children():
		if surface.has_meta("food_waste_surface"): fixed_surfaces[surface] = surface.position
	world._food.shake_tray()
	world._food._update_tray_shake(0.34)
	check(world._food._tray_surfaces.size() == 5, "Only catch tray floor and four rims belong to shake group")
	for surface in fixed_surfaces:
		check(surface.position.is_equal_approx(fixed_surfaces[surface]), "Tray shake cannot move counter or discard colliders")
	world._food._update_tray_shake(1.0)
	var probe: RigidBody3D = RigidBody3D.new()
	probe.position = Vector3(-3.15, 2.1, 2.35)
	probe.collision_layer = 4
	probe.collision_mask = 2
	probe.contact_monitor = true
	probe.max_contacts_reported = 8
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.06
	shape.shape = sphere
	probe.add_child(shape)
	world.add_child(probe)
	for frame in range(90):
		await physics_frame
		await process_frame
	check(probe.position.y < 0.9 and probe.position.y > 0.77, "Real rigid food can fall through opening and rest inside well")
	check(world._food._touching_counter(probe), "Recessed well contacts still classify spilled food as waste")
	probe.queue_free()
	for kind in ["bag", "bucket"]:
		world.sync_state({"phase":"playing", "supply":0, "supply_capacity":30, "package_type":kind, "package_count":6, "package_flavor":"cinnamon", "held_tool":kind})
		var package: Node3D = world._prep
		world.animate_action("trash")
		for frame in range(42): world._process(1.0 / 60.0)
		check(is_instance_valid(package) and package.position.y > 1.90 and absf(package.position.x + 3.15) < 0.02, kind + " reaches aperture before its falling phase")
		check(world._handoff == null, kind + " is released before its descent")
		for frame in range(23): world._process(1.0 / 60.0)
		check(is_instance_valid(package) and package.position.y < 1.3, kind + " remains visible as it falls below the counter")
		check(package.scale.is_equal_approx(Vector3.ONE), kind + " drops at full size instead of shrinking away")
		for frame in range(20): world._process(1.0 / 60.0)
		check(package.is_queued_for_deletion(), kind + " is removed only after entering the recessed well")
		await process_frame
	# Discard retains the established recovery rule: unseasoned food is returned
	# until the tray is full; only the excess enters the new opening.
	world.reset_food(28, 30)
	world.sync_state({"phase":"playing", "supply":28, "supply_capacity":30, "package_type":"bag", "package_count":6, "package_flavor":"", "held_tool":"bag"})
	var recoverable: Array = world._prep_donuts.duplicate()
	world.animate_action("trash")
	for frame in range(92): world._process(1.0 / 60.0)
	check(world._food.get_available_count() == 30, "Discard still returns plain food up to the catch tray capacity")
	check(is_instance_valid(recoverable[0]) and recoverable[0].get_parent() is RigidBody3D, "Recovered plain food retains its actual physical visual object")
	check(recoverable[2].is_queued_for_deletion(), "Only plain food beyond tray capacity drops into the discard well")
	world.queue_free()
	await process_frame
	print("COUNTER QA: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
