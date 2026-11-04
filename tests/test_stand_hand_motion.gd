extends SceneTree
## Numerical motion invariants complement rendered pose review. Tests exercise
## actual scene objects throughout the action, never bypassing busy timers.
var checks: int = 0
var failures: int = 0
var world
var state: Dictionary
var maximum_bone_error: float = 0.0
var maximum_scale_error: float = 0.0
var elapsed: float = 0.0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func advance(seconds: float) -> void:
	for frame in range(ceili(seconds * 120.0)):
		world._process(1.0 / 120.0)
		elapsed += 1.0 / 120.0
		for rig in world._arm_rigs:
			maximum_bone_error = maxf(maximum_bone_error, absf(rig.shoulder.distance_to(rig.elbow) - world.UPPER_ARM_LENGTH))
			maximum_bone_error = maxf(maximum_bone_error, absf(rig.elbow.distance_to(rig.wrist) - world.FOREARM_LENGTH))
			maximum_scale_error = maxf(maximum_scale_error, rig.upper.scale.distance_to(Vector3.ONE))
			maximum_scale_error = maxf(maximum_scale_error, rig.fore.scale.distance_to(Vector3.ONE))

func settle() -> void:
	var start: float = elapsed
	for frame in range(360):
		advance(1.0 / 120.0)
		if not world.is_action_busy(): break
	check(not world.is_action_busy(), "Action finishes within three seconds: " + world._action)
	check(elapsed - start <= 1.7, "Service action does not leave an invisible delay")

func act(id: String, patch: Dictionary = {}) -> void:
	world.animate_action(id)
	state.merge(patch, true)
	world.sync_state(state)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	state = {"phase":"playing", "temperature":180.0, "heat_setting":2, "batter":40, "supply":12, "supply_capacity":30, "package_type":"", "package_count":0, "package_flavor":"", "held_tool":"none", "scoop_count":0, "orders":[]}
	world.reset_food(12, 30)
	world.sync_state(state)
	advance(0.3)
	for index in range(2):
		var hand: Node3D = world._hands[index]
		var palm: MeshInstance3D = hand.get_node("AnatomicalPalm")
		var cuff: MeshInstance3D = hand.get_node("RolledGloveCuff")
		check(world._finger_chains[index].size() == 4 and world._thumb_chains[index].size() == 2, "Each glove has four articulated fingers and an opposed two-part thumb")
		var complete: bool = true
		for chain in world._finger_chains[index]:
			complete = complete and chain.size() == 3 and chain[1].get_parent() == chain[0] and chain[2].get_parent() == chain[1]
		check(complete, "All fingers bend through real proximal, middle and distal joints")
		var wrist_width: float = 0.0
		var palm_width: float = 0.0
		var normals_valid: bool = true
		var arrays: Array = palm.mesh.surface_get_arrays(0)
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			if vertex.z > 0.0: wrist_width = maxf(wrist_width, absf(vertex.x))
			if vertex.z < -0.04 and vertex.z > -0.12: palm_width = maxf(palm_width, absf(vertex.x))
		for normal in arrays[Mesh.ARRAY_NORMAL]:
			normals_valid = normals_valid and normal.is_finite() and absf(normal.length() - 1.0) < 0.001
		check(palm_width > wrist_width * 1.25, "Palm geometry broadens naturally from the narrower wrist")
		check(normals_valid, "Curved glove surfaces have finite smooth lighting normals")
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var face_normal: Vector3 = (vertices[indices[1]] - vertices[indices[0]]).cross(vertices[indices[2]] - vertices[indices[0]])
		check(face_normal.dot(arrays[Mesh.ARRAY_NORMAL][indices[0]]) < 0.0, "Glove faces use Godot clockwise winding with outward lighting normals")
		check(cuff.mesh.get_aabb().size.x < palm.mesh.get_aabb().size.x * 0.9, "Rolled cuff fits the wrist instead of forming an oversized cylindrical cap")
		var middle: Array = world._finger_chains[index][1]
		var little: Array = world._finger_chains[index][3]
		check(absf(middle[1].position.z) + absf(middle[2].position.z) > (absf(little[1].position.z) + absf(little[2].position.z)) * 1.3, "Middle and little fingers have distinct anatomical lengths")
	check(world._thumb_chains[0][0].position.x > 0.0 and world._thumb_chains[1][0].position.x < 0.0, "Left and right thumbs are mirrored toward the inside of their palms")
	# Merely syncing a temperature or setting never turns both encoders.
	state.heat_setting = 4
	world.sync_state(state)
	advance(0.3)
	check(is_zero_approx(world._heat_knobs[0].rotation.z) and is_zero_approx(world._heat_knobs[1].rotation.z), "State updates leave both unclicked encoders still")
	world.animate_action("heat_down")
	advance(0.08)
	check(world._heat_knobs[0].rotation.z < -0.1 and is_zero_approx(world._heat_knobs[1].rotation.z), "Minus rotates alone in its own direction")
	var paused_angle: float = world._heat_knobs[0].rotation.z
	state.paused = true
	world.sync_state(state)
	advance(0.5)
	check(is_equal_approx(world._heat_knobs[0].rotation.z, paused_angle), "Pause freezes encoder spring")
	state.paused = false
	world.sync_state(state)
	advance(0.7)
	world.animate_action("heat_up")
	advance(0.08)
	check(world._heat_knobs[1].rotation.z > 0.1 and absf(world._heat_knobs[0].rotation.z) < 0.001, "Plus rotates alone in the opposite direction")
	advance(0.7)
	check(absf(world._heat_knobs[1].rotation.z) < 0.001, "Encoder returns smoothly to neutral")
	act("bag", {"package_type":"bag"})
	var bag = world._prep
	var bag_start: Transform3D = bag.global_transform
	advance(0.18)
	check(bag.global_transform.is_equal_approx(bag_start), "Bag stays on stack while the glove reaches it")
	advance(0.035)
	var grip: Vector3 = bag.to_global(Vector3(0.35, 0.28, 0.10))
	check(world._hands[1].global_position.distance_to(grip) < 0.015, "Glove grasps the bag before departure")
	advance(0.20)
	check(bag.position.distance_to(bag_start.origin) > 0.15, "Bag lifts through a genuine intermediate position")
	var mid_bag: Transform3D = bag.global_transform
	var mid_hand: Transform3D = world._hands[1].global_transform
	state.paused = true
	world.sync_state(state)
	advance(0.5)
	check(bag.global_transform.is_equal_approx(mid_bag) and world._hands[1].global_transform.is_equal_approx(mid_hand), "Pause freezes prop and gripping glove together")
	state.paused = false
	world.sync_state(state)
	settle()
	check(bag.position.is_equal_approx(world._package_anchor), "Bag sets down at the preparation mat")
	act("scoop", {"held_tool":"scoop"})
	settle()
	var scoop_id: int = world._held_scoop.get_instance_id()
	check(world._hands[1].global_position.distance_to(world._held_scoop.to_global(Vector3(0, -0.005, 0.53))) < 0.001, "Holding pose preserves the actual scoop grip")
	check(world._finger_chains[1][0][1].rotation.x < -0.5 and world._finger_chains[1][0][2].rotation.x < -0.25, "Gripping curls middle and distal joints around the handle")
	check(world._thumb_chains[1][0].rotation.y < 0.0 and world._thumb_chains[1][1].rotation.x < -0.4, "Thumb opposes the fingers when gripping")
	act("supply", {"supply":9,"scoop_count":3})
	advance(0.25)
	check(world._held_scoop_donuts[0].get_parent() != world._held_scoop, "Food stays at the tray until the scoop arrives")
	settle()
	var donut = world._held_scoop_donuts[0]
	var donut_id: int = donut.get_instance_id()
	check(donut.get_parent() == world._held_scoop and world._held_scoop.get_instance_id() == scoop_id, "Same food and scoop return together")
	act("package", {"scoop_count":0,"package_count":3})
	advance(0.34)
	var source: Transform3D = donut.global_transform
	check(source.origin.distance_to(world._held_scoop.global_position) < 0.6, "Food is retained while the scoop approaches the bag")
	advance(0.14)
	var lip: Vector3 = world._held_scoop.to_global(Vector3(0, 0, -0.38))
	var handle: Vector3 = world._held_scoop.to_global(Vector3(0, 0, 0.40))
	check(lip.y < handle.y - 0.4, "Pour turns the opening down instead of raising the lip")
	settle()
	check(world._prep_donuts[0].get_instance_id() == donut_id and donut.get_parent() == bag, "Pour delivers the existing food node into the existing bag")
	act("cinnamon", {"package_flavor":"cinnamon", "held_tool":"none"})
	advance(0.3)
	check(world._effects.is_empty(), "Seasoning does not emit before the tin reaches the bag")
	settle()
	check(world._shakers.cinnamon.global_transform.is_equal_approx(world._shaker_homes.cinnamon), "Seasoning tin returns to its original counter place")
	act("package", {"held_tool":"package"})
	settle()
	check(world._held_package == bag, "Lifting keeps the filled physical bag")
	# The return path starts and ends at rest, including the vertical lift. This
	# catches the former sine arc's visible velocity jumps at both endpoints.
	var probe: Node3D = Node3D.new()
	world.add_child(probe)
	probe.position = Vector3(0, 2, 2)
	world._move_node(probe, Transform3D(Basis.IDENTITY, Vector3(1, 2, 2)), 1.0, 0.3)
	var first: Vector3 = probe.position
	advance(1.0 / 120.0)
	var start_speed: float = probe.position.distance_to(first) * 120.0
	advance(118.0 / 120.0)
	var penultimate: Vector3 = probe.position
	advance(1.0 / 120.0)
	var end_speed: float = probe.position.distance_to(penultimate) * 120.0
	check(start_speed < 0.05 and end_speed < 0.05, "Transport lift eases into and out of motion with no arc kick")
	probe.queue_free()
	world.set_reduced_motion(true)
	state.held_tool = "none"
	state.hold_station = "refill"
	world.sync_state(state)
	advance(0.8)
	check(world._batter_stream.visible and not world._node_is_moving(world._maintenance_prop), "Reduced motion preserves essential pitcher movement and pouring")
	check(world._hands[1].global_position.distance_to(world._maintenance_prop.to_global(Vector3(0.39, 0.26, 0.08))) < 0.001, "Refill wrist stays on the moving pitcher handle")
	state.hold_station = ""
	world.sync_state(state)
	advance(0.8)
	check(world._maintenance_prop.global_transform.is_equal_approx(world._pitcher_home), "Pitcher returns after the hold ends")
	_test_offhand_container_pickups()
	check(maximum_bone_error < 0.00001, "Every sampled upper arm and forearm retains its fixed length")
	check(maximum_scale_error < 0.00001, "No sampled arm bone stretches or scales during reach")
	world._view_hands.visible = false
	advance(0.02)
	check(not world._arm_rigs[0].upper.visible and not world._arm_rigs[1].fore.visible, "Hiding the hand rig also hides its independent arm meshes")
	world.reset_food(0,30)
	world.queue_free()
	await process_frame
	await process_frame
	print("HAND MOTION QA: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_offhand_container_pickups() -> void:
	for reduced in [false, true]:
		for kind in ["bag", "bucket"]:
			for loaded in [false, true]:
				world.reset_food(12, 30)
				world.set_reduced_motion(reduced)
				state = {"phase":"playing", "temperature":180.0, "heat_setting":2, "batter":40, "supply":12, "supply_capacity":30, "package_type":"", "package_count":0, "package_flavor":"", "held_tool":"none", "scoop_count":0, "orders":[]}
				world.sync_state(state)
				advance(0.3)
				if loaded:
					var other: String = "bucket" if kind == "bag" else "bag"
					act(other, {"package_type":other})
					settle()
				act("scoop", {"held_tool":"scoop"})
				settle()
				if loaded:
					act("supply", {"supply":9, "scoop_count":3})
					settle()
				var scoop_id: int = world._held_scoop.get_instance_id()
				var food: Array = world._held_scoop_donuts.duplicate()
				var local_poses: Array[Transform3D] = []
				for donut in food: local_poses.append(donut.transform)
				act(kind, {"package_type":kind})
				var container: Node3D = world._prep
				var start: Transform3D = container.global_transform
				var duration: float = elapsed
				var right_grip_error: float = 0.0
				var scoop_stays_held: bool = true
				for frame in range(26):
					advance(1.0 / 120.0)
					right_grip_error = maxf(right_grip_error, world._hands[1].global_position.distance_to(world._held_scoop.to_global(Vector3(0, -0.005, 0.53))))
					scoop_stays_held = scoop_stays_held and world._held_type == "scoop" and not world._node_is_moving(world._held_scoop)
				check(world._hand_goal(0).node == container and world._hand_goal(1).node == world._held_scoop, "Off-hand owns " + kind + " while dominant hand stays assigned to the scoop")
				check(world._hands[0].global_position.distance_to(world._hand_goal(0).pose.origin) < 0.015, "Left glove reaches the " + kind + " grip before its transport begins")
				for frame in range(23):
					advance(1.0 / 120.0)
					right_grip_error = maxf(right_grip_error, world._hands[1].global_position.distance_to(world._held_scoop.to_global(Vector3(0, -0.005, 0.53))))
					scoop_stays_held = scoop_stays_held and world._held_type == "scoop" and not world._node_is_moving(world._held_scoop)
				check(container.global_position.distance_to(start.origin) > 0.1, "Off-hand " + kind + " passes through a lifted intermediate pose")
				var paused_container: Transform3D = container.global_transform
				var paused_scoop: Transform3D = world._held_scoop.global_transform
				var paused_left: Transform3D = world._hands[0].global_transform
				var paused_right: Transform3D = world._hands[1].global_transform
				state.paused = true
				world.sync_state(state)
				advance(0.25)
				check(container.global_transform.is_equal_approx(paused_container) and world._held_scoop.global_transform.is_equal_approx(paused_scoop) and world._hands[0].global_transform.is_equal_approx(paused_left) and world._hands[1].global_transform.is_equal_approx(paused_right), "Pause freezes both hands, " + kind + " and retained scoop together")
				state.paused = false
				world.sync_state(state)
				for frame in range(150):
					advance(1.0 / 120.0)
					right_grip_error = maxf(right_grip_error, world._hands[1].global_position.distance_to(world._held_scoop.to_global(Vector3(0, -0.005, 0.53))))
					scoop_stays_held = scoop_stays_held and world._held_type == "scoop" and not world._node_is_moving(world._held_scoop)
					if not world.is_action_busy(): break
				check(not world.is_action_busy() and elapsed - duration - 0.25 <= 0.95, "Off-hand " + kind + " transfer keeps the existing sub-second action timing")
				check(scoop_stays_held and right_grip_error < 0.001 and world._held_scoop.get_instance_id() == scoop_id, "Right glove continuously holds the same scoop throughout " + kind + " pickup")
				check(container.position.is_equal_approx(world._package_anchor), "Off-hand sets " + kind + " onto the preparation mat")
				var contents_preserved: bool = world._held_scoop_donuts == food
				for index in range(food.size()):
					contents_preserved = contents_preserved and is_instance_valid(food[index]) and food[index].get_parent() == world._held_scoop and food[index].transform.is_equal_approx(local_poses[index])
				check(contents_preserved, "Loaded food remains in the same scoop throughout " + kind + " pickup, including reduced motion")
