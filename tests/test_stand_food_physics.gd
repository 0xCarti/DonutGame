extends SceneTree
## Actual fixed-step rigid-body tests. No game profile, save or interactive window.
var checks: int = 0
var failures: int = 0
var deliveries: Array[Dictionary] = []
var spilled: Array[int] = []

class FoodWorld extends Node3D:
	var _machine_root: Node3D
	func _init() -> void:
		_machine_root = Node3D.new()
		_machine_root.position = Vector3(-2.35, 1.01, -0.60)
		_machine_root.scale = Vector3.ONE * 0.48
		add_child(_machine_root)
	func _plain_donut(_id: int, _at: Vector3) -> Node3D:
		var visual: Node3D = Node3D.new()
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.013
		torus.outer_radius = 0.225
		mesh.scale.y = 0.064 / 0.106
		mesh.mesh = torus
		visual.add_child(mesh)
		add_child(visual)
		return visual


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _run() -> void:
	var world: FoodWorld = FoodWorld.new()
	root.add_child(world)
	var food = load("res://scripts/stand_food_physics.gd").new()
	food.configure(world)
	food.delivery_settled.connect(func(id: int, kept: bool) -> void: deliveries.append({"id": id, "kept": kept}))
	food.stock_spilled.connect(func(id: int) -> void: spilled.append(id))
	food.seed_stock(18, 36)
	check(food.get_available_count() == 18, "Opening stock exists immediately")
	var positions: Array = food.debug_snapshot().positions
	var unique: Dictionary = {}
	for position in positions:
		unique[Vector2(snappedf(position.x, 0.01), snappedf(position.z, 0.01))] = true
	check(unique.size() == 18, "Opening stock uses irregular distinct physical positions")
	check(food._entries[0].body is RigidBody3D, "Food is a rigid body")
	check(food._entries[0].body.get_child_count() == 9, "Ring collider has eight crust shapes and one visual")
	check(food._entries[0].body.collision_layer == 4 and food._entries[0].body.collision_mask == 6, "Food collides with food/table but not station rays")
	check(food.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON, "Physics food explicitly enables render interpolation")
	check(food._surfaces.get_child_count() == 14 and food._tray_surfaces.size() == 5, "Cutout table, recessed well and catch tray have distinct physical surfaces")
	var previous: Vector3 = food.conveyor_position(0.0)
	var maximum_step: float = 0.0
	var crest: float = 0.0
	var ramp_clearance: float = 100.0
	for index in range(1, 1001):
		var at: Vector3 = food.conveyor_position(float(index) / 1000.0)
		maximum_step = maxf(maximum_step, at.distance_to(previous))
		if at.x > -0.8:
			crest = maxf(crest, at.y)
		var machine_local: Vector3 = world._machine_root.to_local(at)
		if machine_local.x >= 3.43 and machine_local.x <= 4.21 and machine_local.z < -0.10:
			var roller_top: float = 2.34 + ((machine_local.x - 3.43) / 0.13) * 0.043 + 0.045
			ramp_clearance = minf(ramp_clearance, (machine_local.y - roller_top) * 0.48 - food.CRUST_RADIUS)
		previous = at
	check(maximum_step < 0.01, "Baked conveyor path is continuous without teleport seams")
	check(crest > 2.34, "Donuts climb visibly above the machine exit ramp")
	check(ramp_clearance >= 0.0, "Donut undersides clear the actual inclined roller tops")
	check(food.conveyor_position(1.0).is_equal_approx(food._chute_tip) and food._inside_tray(food._chute_tip), "Discharge ends at the moving chute tip over the tray interior")
	var removed: Array = food.take_donuts(6)
	check(removed.size() == 6 and food.get_available_count() == 12, "Scoop removes exact physical stock")
	check(removed[0].physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "Scoop hand animation is not double interpolated")
	for visual in removed:
		check(visual.get_parent() == world, "Scoop visuals retain world parent for hand animation")
		visual.position = Vector3(-1.4, 2.25, 0.93)
	food.return_donuts(removed)
	check(food.get_available_count() == 18, "Recovered plain food reuses its visuals as physical inventory")
	check(food._entries.back().visual == removed.back(), "Returning food preserves the actual visual object")
	food.clear_food()
	food.seed_stock(0, 36)
	food.enqueue_production(101)
	food.enqueue_production(101)
	check(food.debug_snapshot().conveyor == 1, "Duplicate production event is idempotent")
	await frames(30)
	var conveyor_before: Vector3 = food._entries[0].body.position
	food.set_machine_running(false)
	await frames(15)
	check(food._entries[0].body.position.is_equal_approx(conveyor_before), "Jam stops conveyor movement")
	food.set_machine_running(true)
	# Accelerate the belt traversal only, then test the real engine gravity step.
	food._entries[0].progress = 0.999
	await frames(2)
	check(food.debug_snapshot().falling == 1, "Conveyor releases the same body into gravity")
	var released = food._entries[0].body
	check(absf(released.basis.y.dot(Vector3.UP)) > 0.90, "Donut follows chute pitch through sideways turn without standing vertically")
	var fall_before: float = released.position.y
	await frames(3)
	check(released.position.y < fall_before, "Released donut actually falls under gravity")
	food.set_paused(true)
	var paused_position: Vector3 = released.position
	await frames(12)
	check(released.position.is_equal_approx(paused_position), "Pause freezes airborne physical food")
	food.set_paused(false)
	await frames(120)
	check(deliveries.size() == 1 and deliveries[0] == {"id":101,"kept":true}, "Real tray landing emits one kept delivery")
	check(food.get_available_count() == 1 and released.position.y > 1.80, "Donut rests above the tray floor")
	check(released.get_contact_count() > 0, "Settled donut has a physical contact")
	# A second falling donut collides with the first ring before settling.
	food.enqueue_production(102)
	food._entries.back().progress = 0.999
	await frames(150)
	check(deliveries.size() == 2 and food.get_available_count() == 2, "Repeated physical delivery does not use a fixed spawn slot")
	check(food._entries[0].body.position.distance_to(food._entries[1].body.position) > 0.07, "Rigid donuts cannot occupy the identical tray position")
	# A full, physically stacked tray deflects the next donut onto the counter.
	food.clear_food()
	food.seed_stock(36, 36)
	food.enqueue_production(201)
	food._entries.back().progress = 0.999
	await frames(240)
	check(deliveries.size() == 3 and deliveries.back() == {"id":201,"kept":false}, "Overflow reports waste exactly once")
	check(food.get_available_count() <= 36 and food.debug_snapshot().waste >= 1, "Overflow remains visible as waste, unavailable to scoop")
	var waste = food._entries.back().body
	check(not food._inside_tray(waste.position) and waste.position.y > 1.70, "Overflow body crosses the real rim and settles on counter")
	food.set_paused(true)
	var age: float = food._entries.back().age
	await frames(5)
	check(food._entries.back().age == age, "Pause also freezes waste fade lifetime")
	food.set_paused(false)
	food._entries.back().age = 11.1
	var count_before_fade: int = food.debug_snapshot().bodies
	await frames(2)
	check(food.debug_snapshot().bodies == count_before_fade - 1, "Waste bodies are recycled after visible lifetime")
	food.clear_food()
	food.seed_stock(0, 36)
	food.enqueue_production(301)
	food._entries.back().progress = 0.999
	await frames(2)
	food._entries.back().age = 6.0
	await frames(1)
	check(food._entries.back().stage == "falling", "Aged airborne food is not falsely declared waste before physical landing")
	await frames(120)
	check(food.get_available_count() == 1 and deliveries.back() == {"id":301,"kept":true}, "An aged airborne donut can still land as usable food")
	food.seed_stock(36, 36)
	await frames(15)
	check(food.get_available_count() == 36, "Full opening stock is stable and immediately usable")
	food.clear_food()
	check(food.get_available_count() == 0 and food.debug_snapshot().bodies == 0, "Reset clears all inventory bodies")
	world.queue_free()
	await process_frame
	print("FOOD PHYSICS QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
