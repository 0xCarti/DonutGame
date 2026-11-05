extends Node3D
## Conveyor and catch-tray food are persistent physical objects.  A production
## identifier becomes inventory only after the corresponding body lands.
signal delivery_settled(id: int, kept: bool)
signal stock_spilled(id: int)

const DONUT_SCALE: float = 0.62
const MODEL_RING_RADIUS: float = 0.119
const MODEL_TUBE_RADIUS: float = 0.106
const MODEL_HALF_HEIGHT: float = 0.064
const RING_RADIUS: float = MODEL_RING_RADIUS * DONUT_SCALE
const RADIAL_CRUST_RADIUS: float = MODEL_TUBE_RADIUS * DONUT_SCALE
const CRUST_RADIUS: float = MODEL_HALF_HEIGHT * DONUT_SCALE
const OUTER_RADIUS: float = RING_RADIUS + RADIAL_CRUST_RADIUS
const CONVEYOR_SECONDS: float = 5.2
const WASTE_SECONDS: float = 11.0
const MAX_BODIES: int = 100
const FOOD_LAYER: int = 4
const SURFACE_LAYER: int = 2
const TRAY_CENTER: Vector3 = Vector3(-1.40, 1.76, 0.93)
const TRAY_FLOOR_Y: float = 1.7875
const CHUTE_PIVOT: Vector3 = Vector3(-0.19, 2.22, -0.35)
const CHUTE_LENGTH: float = 1.85
const CHUTE_DROP: float = 0.08
const SWEEP_SECONDS: float = 8.4
const SHAKE_SECONDS: float = 0.60
const SHAKE_CHAIN_SECONDS: float = 0.65
const MAX_SHAKE_STRENGTH: float = 5.0

var _world: Node3D
var _capacity: int = 36
var _paused: bool = false
var _machine_running: bool = true
var _lane_count: int = 1
var _feed_multiplier: float = 1.0
var _lane_serial: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _entries: Array[Dictionary] = []
var _surfaces: Node3D
var _path: Curve3D
var _seed_serial: int = -10000
var _paused_velocities: Dictionary = {}
var _crust_shape: CapsuleShape3D
var _fixed_path_length: float = 0.0
var _total_path_length: float = 0.0
var _sweep_phase: float = 0.0
var _chute_angle: float = PI * 0.25
var _chute_tip: Vector3
var _outlet_velocity: Vector3 = Vector3.ZERO
var _tray_surfaces: Array[StaticBody3D] = []
var _shake_time: float = SHAKE_SECONDS
var _shake_cooldown: float = 0.0
var _shake_strength: float = 0.0
var _shake_chain_age: float = 1000.0
var _shake_extra_pulse: bool = false
var _shake_burst: int = 0
var _shower_announced: bool = false
var _gull_cooldown: float = 0.0
var _gull_caught_burst: int = -1


func configure(world: Node3D) -> void:
	_world = world
	_rng.seed = 21072026
	if get_parent() == null:
		world.add_child(self)
	name = "PhysicalDonuts"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_crust_shape = CapsuleShape3D.new()
	_crust_shape.radius = CRUST_RADIUS
	_crust_shape.height = RADIAL_CRUST_RADIUS * 2.0
	_build_surfaces()
	_build_path()
	_update_chute_pose(0.0)


func _build_surfaces() -> void:
	_surfaces = Node3D.new()
	_surfaces.name = "FoodCollisionSurfaces"
	add_child(_surfaces)
	# This aperture matches the boards, substrate and stainless scrap well.
	# Separate static panels let fallen food genuinely pass below the worktop.
	_surface("CounterLeft", Vector3(-4.40, 1.64, 0.70), Vector3(1.40, 0.12, 5.10))
	_surface("CounterRight", Vector3(1.25, 1.64, 0.70), Vector3(7.70, 0.12, 5.10))
	_surface("CounterBack", Vector3(-3.15, 1.64, -0.005), Vector3(1.10, 0.12, 3.69))
	_surface("CounterFront", Vector3(-3.15, 1.64, 3.055), Vector3(1.10, 0.12, 0.39))
	_surface("DiscardFloor", Vector3(-3.15, 0.735, 2.35), Vector3(1.10, 0.04, 1.02))
	for side in [-1.0, 1.0]:
		_surface("DiscardWall", Vector3(-3.15 + side * 0.5675, 1.22, 2.35), Vector3(0.035, 0.94, 1.02))
		_surface("DiscardWall", Vector3(-3.15, 1.22, 2.35 + side * 0.5275), Vector3(1.10, 0.94, 0.035))
	_surface("TrayFloor", TRAY_CENTER + Vector3(0, 0.01, 0), Vector3(2.12, 0.035, 1.32))
	for z in [-0.72, 0.72]:
		_surface("TrayRim", TRAY_CENTER + Vector3(0, 0.08, z), Vector3(2.28, 0.22, 0.055))
	for x in [-1.12, 1.12]:
		_surface("TrayRim", TRAY_CENTER + Vector3(x, 0.08, 0), Vector3(0.055, 0.22, 1.46))


func _surface(label: String, at: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = label
	body.collision_layer = SURFACE_LAYER
	body.collision_mask = FOOD_LAYER
	body.position = at
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_surfaces.add_child(body)
	if label.begins_with("Counter") or label.begins_with("Discard"):
		body.set_meta("food_waste_surface", true)
	if label.begins_with("Tray"):
		body.set_meta("rest_position", at)
		_tray_surfaces.append(body)


func _build_path() -> void:
	_path = Curve3D.new()
	_path.bake_interval = 0.012
	var machine: Node3D = _world.get("_machine_root") as Node3D
	var points: PackedVector3Array = []
	for point in [Vector3(-3.65, 2.34, -0.28), Vector3(-0.35, 2.34, -0.28), Vector3(2.95, 2.34, -0.28), Vector3(3.38, 2.48, -0.25), Vector3(4.00, 2.69, -0.25), Vector3(4.34, 2.80, -0.25), Vector3(4.50, 2.70, 0.05)]:
		points.append(to_local(machine.to_global(point)) if is_instance_valid(machine) else point)
	points.append(CHUTE_PIVOT)
	for index in range(points.size()):
		var before: Vector3 = points[maxi(0, index - 1)]
		var after: Vector3 = points[mini(points.size() - 1, index + 1)]
		var tangent: Vector3 = (after - before).normalized()
		var handle: float = minf(points[index].distance_to(before), points[index].distance_to(after)) * 0.20
		_path.add_point(points[index], -tangent * handle, tangent * handle)
	_fixed_path_length = _path.get_baked_length()
	_total_path_length = _fixed_path_length + Vector2(CHUTE_LENGTH, CHUTE_DROP).length()


func conveyor_position(progress: float) -> Vector3:
	var distance: float = clampf(progress, 0.0, 1.0) * _total_path_length
	if distance <= _fixed_path_length:
		return _path.sample_baked(distance, true)
	return CHUTE_PIVOT.lerp(_chute_tip, (distance - _fixed_path_length) / (_total_path_length - _fixed_path_length))


func _update_chute_pose(delta: float) -> void:
	if _machine_running:
		_sweep_phase = fposmod(_sweep_phase + delta * TAU / SWEEP_SECONDS, TAU)
	_chute_angle = deg_to_rad(45.0 + 20.0 * sin(_sweep_phase))
	_chute_tip = CHUTE_PIVOT + Vector3(-sin(_chute_angle) * CHUTE_LENGTH, -CHUTE_DROP, cos(_chute_angle) * CHUTE_LENGTH)
	var angular_speed: float = deg_to_rad(20.0) * cos(_sweep_phase) * TAU / SWEEP_SECONDS if _machine_running else 0.0
	_outlet_velocity = Vector3(-cos(_chute_angle), 0, -sin(_chute_angle)) * CHUTE_LENGTH * angular_speed
	if _world.has_method("set_discharge_chute_pose"):
		_world.call("set_discharge_chute_pose", CHUTE_PIVOT, _chute_tip)


func shake_tray() -> bool:
	if _paused:
		return false
	var continuing: bool = _shake_chain_age <= SHAKE_CHAIN_SECONDS
	if continuing:
		_shake_strength = minf(MAX_SHAKE_STRENGTH, maxf(1.0, _shake_strength) + 1.0)
	else:
		_shake_strength = 1.0
		_shake_burst += 1
		_shower_announced = false
	if _shake_time >= SHAKE_SECONDS:
		_shake_time = 0.0 if continuing else -0.20
		_shake_extra_pulse = continuing
	elif _shake_time >= 0.0:
		# Extra clicks add momentum without resetting the hands' reach or phase.
		_shake_extra_pulse = true
	_shake_chain_age = 0.0
	_shake_cooldown = SHAKE_CHAIN_SECONDS
	if _shake_strength >= 3.0 and not _shower_announced and get_available_count() > 0:
		_shower_announced = true
		if _world.has_method("play_gag"):
			_world.call("play_gag", "donut_shower", {"strength":_shake_strength})
	return true


func _loosen_tray(pulse: int = 0) -> void:
	# Isolated shakes remain helpful. Deliberate rapid clicks build toward a
	# comic launch, but target velocities remain finite and strictly bounded.
	var crowding: float = clampf(float(get_available_count() - 30) / 30.0, 0.0, 1.0)
	var speed: float = 0.94 * (1.0 - crowding * 0.34) * (1.0 - float(pulse) * 0.11)
	var rage: bool = _shake_strength >= 3.0
	if rage: speed = 1.55 + (_shake_strength - 3.0) * 0.55
	elif _shake_strength >= 2.0: speed *= 1.18
	var stroke: Vector3 = Vector3(1.0 if pulse % 2 == 0 else -1.0, 0, 0.32 if pulse == 1 else -0.18)
	for entry in _entries:
		if str(entry.stage) != "resident": continue
		var body: RigidBody3D = entry.body
		var offset: Vector3 = body.position - TRAY_CENTER
		var direction: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0)) + stroke * 0.65
		# Local contact pressure biases movement into gaps, rather than moving an
		# intact clump back and forth or forcing every donut toward the center.
		for other in _entries:
			if other == entry or str(other.stage) != "resident": continue
			var separation: Vector3 = body.position - other.body.position
			if absf(separation.y) > 0.14: continue
			separation.y = 0.0
			var distance: float = separation.length()
			if distance > 0.001 and distance < 0.40:
				direction += separation / distance * (1.0 - distance / 0.40) * 1.5
		if rage:
			direction = Vector3(offset.x, 0, offset.z).normalized() + direction * 0.30
			entry["launched_burst"] = _shake_burst
			entry["launch_age"] = 0.0
		else:
			if absf(offset.x) > 0.74: direction.x = -signf(offset.x) * maxf(0.85, absf(direction.x))
			if absf(offset.z) > 0.39: direction.z = -signf(offset.z) * maxf(0.85, absf(direction.z))
		direction = direction.normalized()
		var horizontal: Vector3 = Vector3(body.linear_velocity.x, 0, body.linear_velocity.z)
		body.sleeping = false
		var lift: float = 0.20 * (1.0 - crowding * 0.4)
		if rage: lift = 2.30 + (_shake_strength - 3.0) * 0.65 - body.linear_velocity.y
		body.apply_central_impulse((direction * speed - horizontal + Vector3(0, lift, 0)) * body.mass)
		if rage:
			body.angular_velocity = Vector3(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-3.0, 3.0), _rng.randf_range(-4.0, 4.0))
		else:
			body.apply_torque_impulse(Vector3(_rng.randf_range(-0.00012, 0.00012), 0, _rng.randf_range(-0.00012, 0.00012)))


func _update_tray_shake(delta: float) -> void:
	_shake_cooldown = maxf(0.0, _shake_cooldown - delta)
	_shake_chain_age += delta
	_gull_cooldown = maxf(0.0, _gull_cooldown - delta)
	if _shake_chain_age > SHAKE_CHAIN_SECONDS:
		_shake_strength = maxf(0.0, _shake_strength - delta * 2.5)
	var before: float = _shake_time
	_shake_time = minf(SHAKE_SECONDS, _shake_time + delta)
	if _shake_extra_pulse and _shake_time >= 0.0:
		_loosen_tray(0)
		_shake_extra_pulse = false
	for pulse in range(3):
		var pulse_time: float = float(pulse) * 0.20
		if before < pulse_time and _shake_time >= pulse_time:
			_loosen_tray(pulse)
	if _shake_time >= SHAKE_SECONDS and _shake_chain_age < SHAKE_CHAIN_SECONDS and _shake_strength >= 2.0:
		_shake_time = 0.0
		_shake_extra_pulse = true
	var t: float = maxf(0.0, _shake_time) / SHAKE_SECONDS
	var intensity: float = 1.0 + maxf(0.0, _shake_strength - 1.0) * 0.32
	var offset: Vector3 = Vector3(sin(t * TAU * 2.0) * sin(t * PI) * 0.055, 0, sin(t * TAU) * sin(t * PI) * 0.028) * intensity if t < 1.0 else Vector3.ZERO
	for body in _tray_surfaces:
		body.position = Vector3(body.get_meta("rest_position")) + offset
	if _world.has_method("set_tray_shake_offset"):
		_world.call("set_tray_shake_offset", offset)


func set_capacity(capacity: int) -> void:
	_capacity = clampi(capacity, 0, 84)


func set_machine_running(running: bool) -> void:
	_machine_running = running


func set_paused(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	for entry in _entries:
		var body: RigidBody3D = entry.body
		if str(entry.stage) == "conveyor":
			continue
		if paused:
			_paused_velocities[body.get_instance_id()] = [body.linear_velocity, body.angular_velocity, body.sleeping, body.global_transform]
			body.freeze = true
			PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
			body.reset_physics_interpolation()
		else:
			body.freeze = false
			var saved: Array = _paused_velocities.get(body.get_instance_id(), [Vector3.ZERO, Vector3.ZERO, false])
			body.linear_velocity = saved[0]
			body.angular_velocity = saved[1]
			body.sleeping = saved[2]
	if not paused:
		_paused_velocities.clear()


func clear_food() -> void:
	for entry in _entries:
		var body: RigidBody3D = entry.body
		remove_child(body)
		body.queue_free()
	_entries.clear()
	_paused_velocities.clear()
	_shake_time = SHAKE_SECONDS
	_shake_cooldown = 0.0
	_shake_strength = 0.0
	_shake_chain_age = 1000.0
	_shake_extra_pulse = false
	_shake_burst = 0
	_shower_announced = false
	_gull_cooldown = 0.0
	_gull_caught_burst = -1
	_update_tray_shake(0.0)


func seed_stock(count: int, capacity: int) -> void:
	clear_food()
	set_capacity(capacity)
	# Poisson-spaced hand-scattered layers are ready to scoop immediately.  Their
	# live rigid bodies settle the final few millimetres under gravity on first tick.
	var placed: Array[Vector3] = []
	var layer: int = 0
	for index in range(clampi(count, 0, _capacity)):
		var at: Vector3
		var found: bool = false
		for attempt in range(500):
			at = Vector3(_rng.randf_range(-2.28, -0.52), TRAY_FLOOR_Y + CRUST_RADIUS + float(layer) * CRUST_RADIUS * 2.05, _rng.randf_range(0.43, 1.43))
			found = true
			for previous in placed:
				if absf(previous.y - at.y) < 0.01 and Vector2(previous.x, previous.z).distance_to(Vector2(at.x, at.z)) < OUTER_RADIUS * 1.93:
					found = false
					break
			if found:
				break
		if not found:
			layer += 1
			at.y = TRAY_FLOOR_Y + CRUST_RADIUS + float(layer) * CRUST_RADIUS * 2.05
		placed.append(at)
		_seed_serial -= 1
		var entry: Dictionary = _new_body(_seed_serial, at)
		entry.stage = "resident"
		entry.age = -0.75
		entry.body.rotation = Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.04, 0.04))
		entry.body.freeze = _paused
		entry.body.sleeping = true
		entry.body.reset_physics_interpolation()
		_entries.append(entry)


func set_machine_profile(machine_id: String, speed: int) -> void:
	var next_lanes: int = 3 if machine_id == "festival_pro" else (2 if machine_id == "twin_lane" else 1)
	if next_lanes != _lane_count:
		_lane_count = next_lanes
		_lane_serial = 0
		# Resume queues are restored before the new view-state profile arrives.
		# Redistribute only waiting entries, preserving IDs and in-progress paths.
		for entry in _entries:
			if str(entry.stage) != "conveyor" or float(entry.progress) > 0.0: continue
			entry.lane = (float(_lane_serial % _lane_count)-float(_lane_count-1)*0.5)*0.312
			_lane_serial += 1
			if float(entry.progress) == 0.0:
				entry.body.position = lane_position(0.0,float(entry.lane))
				entry.body.reset_physics_interpolation()
	_feed_multiplier = [0.72,1.0,1.32][clampi(speed,0,2)]

func lane_position(progress: float, lane: float = 0.0) -> Vector3:
	var point: Vector3 = conveyor_position(progress)
	# Separate bath lanes converge before the existing discharge incline.
	point.z += lane * (1.0-smoothstep(0.46,0.64,progress))
	return point

func enqueue_production(id: int) -> void:
	for existing in _entries:
		if int(existing.id) == id:
			return
	_trim_waste()
	var entry: Dictionary = _new_body(id, conveyor_position(0.0))
	entry.stage = "conveyor"
	entry.lane = (float(_lane_serial % _lane_count)-float(_lane_count-1)*0.5)*0.312
	_lane_serial += 1
	# Restored/batched production waits behind the feeder instead of placing
	# several donuts in the same conveyor slot and releasing them as one lump.
	var gap: float = (OUTER_RADIUS * 2.0 + 0.13) / _total_path_length
	for previous in _entries:
		if str(previous.stage) == "conveyor":
			entry.progress = minf(float(entry.progress), float(previous.progress) - gap)
	entry.visual.visible = float(entry.progress) >= 0.0
	entry.body.freeze = true
	entry.body.collision_layer = 0
	entry.body.collision_mask = 0
	entry.body.rotation.y = _rng.randf_range(0.0, TAU)
	entry.yaw = entry.body.rotation.y
	_entries.append(entry)


func _new_body(id: int, at: Vector3, existing_visual: Node3D = null) -> Dictionary:
	var body: RigidBody3D = RigidBody3D.new()
	body.name = "Donut_%d" % id
	body.mass = 0.025
	body.position = at
	body.collision_layer = FOOD_LAYER
	body.collision_mask = FOOD_LAYER | SURFACE_LAYER
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.linear_damp = 0.45
	body.angular_damp = 0.80
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.60
	material.bounce = 0.17
	body.physics_material_override = material
	# Radial capsules preserve the pinhole opening and the flatter cake profile.
	# Their width matches the visible outer edge without making the donut taller.
	for segment in range(8):
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = _crust_shape
		var angle: float = float(segment) * TAU / 8.0
		shape.position = Vector3(cos(angle) * RING_RADIUS, 0, sin(angle) * RING_RADIUS)
		shape.basis = Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, -angle)
		body.add_child(shape)
	add_child(body)
	var visual: Node3D = existing_visual if is_instance_valid(existing_visual) else _world.call("_plain_donut", id, Vector3.ZERO)
	var existing_rotation: Vector3 = visual.global_rotation
	visual.reparent(body, false)
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE * DONUT_SCALE
	if is_instance_valid(existing_visual):
		body.global_rotation = existing_rotation
	body.set_meta("food_id", id)
	body.reset_physics_interpolation()
	return {"id": id, "body": body, "visual": visual, "stage": "falling", "progress": 0.0, "age": 0.0, "stable": 0.0, "spill_started": false}


func get_available_count() -> int:
	var count: int = 0
	for entry in _entries:
		if str(entry.stage) == "resident":
			count += 1
	return count


func return_donuts(nodes: Array[Node3D]) -> void:
	# The caller animates the recovered plain food above the catch tray first.
	# Preserve those exact visuals; the existing inventory count is authoritative.
	for visual in nodes:
		if not is_instance_valid(visual):
			continue
		_seed_serial -= 1
		var entry: Dictionary = _new_body(_seed_serial, to_local(visual.global_position), visual)
		entry.stage = "resident"
		entry.age = -0.8
		entry.body.freeze = _paused
		entry.body.linear_velocity = Vector3(_rng.randf_range(-0.18, 0.18), -0.08, _rng.randf_range(-0.18, 0.18))
		_entries.append(entry)


func take_donuts(count: int) -> Array[Node3D]:
	var result: Array[Node3D] = []
	# Scoop from the top of the pile, rather than pulling its bottom supports out.
	var candidates: Array[Dictionary] = []
	for entry in _entries:
		if str(entry.stage) == "resident":
			candidates.append(entry)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.body.position.y > b.body.position.y)
	for index in range(mini(count, candidates.size())):
		var entry: Dictionary = candidates[index]
		var body: RigidBody3D = entry.body
		var visual: Node3D = entry.visual
		var rendered_transform: Transform3D = visual.get_global_transform_interpolated()
		visual.reparent(_world, false)
		visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		visual.global_transform = rendered_transform
		visual.reset_physics_interpolation()
		result.append(visual)
		_entries.erase(entry)
		_paused_velocities.erase(body.get_instance_id())
		remove_child(body)
		body.queue_free()
	return result


func _physics_process(delta: float) -> void:
	if _paused:
		for entry in _entries:
			var body: RigidBody3D = entry.body
			var saved: Array = _paused_velocities.get(body.get_instance_id(), [])
			if saved.size() >= 4:
				body.global_transform = saved[3]
		return
	if not is_instance_valid(_world):
		return
	_update_chute_pose(delta)
	_update_tray_shake(delta)
	for index in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[index]
		var body: RigidBody3D = entry.body
		var stage: String = entry.stage
		if stage == "conveyor":
			if _machine_running:
				entry.progress = minf(1.0, float(entry.progress) + delta * _feed_multiplier / CONVEYOR_SECONDS)
				var progress: float = float(entry.progress)
				entry.visual.visible = progress >= 0.0
				if progress < 0.0: continue
				body.position = lane_position(progress, float(entry.get("lane",0.0)))
				var tangent: Vector3 = lane_position(minf(1.0, progress + 0.002),float(entry.get("lane",0.0))) - lane_position(maxf(0.0, progress - 0.002),float(entry.get("lane",0.0)))
				var horizontal_squared: float = tangent.x * tangent.x + tangent.z * tangent.z
				var normal: Vector3 = Vector3(-tangent.x * tangent.y, horizontal_squared, -tangent.z * tangent.y).normalized()
				# The mid-bath paddle turns each donut once with eased acceleration.
				var flip: float = smoothstep(0.35, 0.45, progress)
				body.quaternion = Quaternion(Vector3.UP, normal) * Quaternion(Vector3.UP, float(entry.get("yaw", 0.0))) * Quaternion(Vector3.RIGHT, flip * PI)
				if progress >= 1.0:
					_release(entry)
			continue
		entry.age = float(entry.age) + delta
		if entry.has("launch_age"): entry.launch_age = float(entry.launch_age) + delta
		if stage == "waste":
			if float(entry.age) > WASTE_SECONDS - 1.0:
				_set_transparency(entry.visual, clampf(float(entry.age) - (WASTE_SECONDS - 1.0), 0.0, 1.0))
			if float(entry.age) >= WASTE_SECONDS or body.position.y < -2.0:
				remove_child(body)
				body.queue_free()
				_entries.remove_at(index)
			continue
		var inside: bool = _inside_tray(body.position)
		var contacts: bool = body.get_contact_count() > 0
		var counter_contact: bool = _touching_counter(body)
		if stage == "resident":
			var previous: Vector3 = entry.get("previous_position",body.global_position)
			entry.previous_position = body.global_position
			var air_mail: bool = int(entry.get("launched_burst",-1)) >= 0 and _world.has_method("air_mail_target_open") and _world.air_mail_flight_candidate(body.global_position,body.linear_velocity)
			if air_mail and _world.try_air_mail(int(entry.id),previous,body.global_position):
				var visual: Node3D = entry.visual
				_world.accept_air_mail_visual(visual)
				_paused_velocities.erase(body.get_instance_id())
				remove_child(body)
				body.queue_free()
				_entries.remove_at(index)
				continue
			var launched_out: bool = int(entry.get("launched_burst", -1)) >= 0 and float(entry.get("launch_age", 100.0)) < 2.0 and _fully_left_tray(body.position)
			if (launched_out and not air_mail) or (float(entry.age) > 0.20 and not inside and (counter_contact or body.position.y < 1.72)):
				_mark_waste(entry, true)
				if launched_out and not counter_contact and _try_gull_catch(entry):
					_entries.remove_at(index)
			continue
		if not inside and (counter_contact or body.position.y < 1.72):
			_mark_waste(entry, false)
			continue
		if contacts:
			entry.stable = float(entry.stable) + delta if body.linear_velocity.length() < 0.55 else 0.0
			if not bool(entry.spill_started) and get_available_count() >= _capacity:
				# A full catch pile deflects the arriving donut over the outer rim.
				# Its flight, impact, roll and final counter position remain physical.
				entry.spill_started = true
				_deflect_over_rim(body)
			elif inside and not bool(entry.spill_started) and (float(entry.stable) > 0.12 or float(entry.age) > 1.6):
				entry.stage = "resident"
				entry.age = 0.0
				delivery_settled.emit(int(entry.id), true)
			elif bool(entry.spill_started) and float(entry.stable) > 0.5:
				# A donut can balance on a rim after its first impact.  The next
				# conveyor arrival pushes it onward instead of leaving it pending.
				entry.stable = 0.0
				_deflect_over_rim(body)


func _touching_counter(body: RigidBody3D) -> bool:
	for other in body.get_colliding_bodies():
		if other is StaticBody3D and bool(other.get_meta("food_waste_surface", false)):
			return true
	return false


func _deflect_over_rim(body: RigidBody3D) -> void:
	# Upright rings have a taller support radius and can hook on a rim. Use only
	# the lift required to clear that current orientation, never a fixed high hop.
	var vertical_radius: float = CRUST_RADIUS + (OUTER_RADIUS - CRUST_RADIUS) * sqrt(maxf(0.0, 1.0 - body.basis.y.dot(Vector3.UP) ** 2))
	var clearance: float = maxf(0.025, 1.95 + vertical_radius + 0.025 - body.position.y)
	var lift: float = clampf(sqrt(2.0 * 9.8 * clearance), 0.70, 2.10)
	# Spill toward the closest rim. A moving outlet must not keep pushing every
	# overflow donut across the entire tray toward the old fixed right exit.
	var offset: Vector3 = body.position - TRAY_CENTER
	var x_distance: float = 1.10 - absf(offset.x)
	var z_distance: float = 0.70 - absf(offset.z)
	var direction: Vector3 = Vector3(signf(offset.x) if absf(offset.x) > 0.01 else 1.0, 0, 0) if x_distance < z_distance else Vector3(0, 0, signf(offset.z) if absf(offset.z) > 0.01 else 1.0)
	var distance: float = maxf(0.0, minf(x_distance, z_distance)) + OUTER_RADIUS + 0.08
	var flight_time: float = maxf(0.20, 2.0 * lift / 9.8)
	body.sleeping = false
	body.linear_velocity = direction * clampf(distance / flight_time, 1.10, 3.0) + Vector3(0, lift, 0)
	body.angular_velocity = Vector3(direction.z, 0.4, -direction.x) * 1.2


func _release(entry: Dictionary) -> void:
	var body: RigidBody3D = entry.body
	entry.stage = "falling"
	entry.age = 0.0
	body.collision_layer = FOOD_LAYER
	body.collision_mask = FOOD_LAYER | SURFACE_LAYER
	body.freeze = false
	body.sleeping = false
	var direction: Vector3 = (_chute_tip - CHUTE_PIVOT).normalized()
	body.linear_velocity = direction * 0.30 + _outlet_velocity * 0.65 + Vector3(_rng.randf_range(-0.035, 0.035), -0.12, _rng.randf_range(-0.025, 0.025))
	body.angular_velocity = Vector3(_rng.randf_range(-0.70, 0.70), _rng.randf_range(-1.6, 1.6), _rng.randf_range(-1.1, 1.1))


func _inside_tray(at: Vector3) -> bool:
	return at.x > TRAY_CENTER.x - 1.10 and at.x < TRAY_CENTER.x + 1.10 and at.z > TRAY_CENTER.z - 0.70 and at.z < TRAY_CENTER.z + 0.70 and at.y > 1.75


func _fully_left_tray(at: Vector3) -> bool:
	# A tagged airborne donut is waste only once its entire outline clears a rim.
	return absf(at.x - TRAY_CENTER.x) > 1.10 + OUTER_RADIUS or absf(at.z - TRAY_CENTER.z) > 0.70 + OUTER_RADIUS


func _try_gull_catch(entry: Dictionary) -> bool:
	var burst: int = int(entry.get("launched_burst", -1))
	if _gull_cooldown > 0.0 or burst < 0 or burst == _gull_caught_burst or not _world.has_method("play_gag"):
		return false
	var body: RigidBody3D = entry.body
	var visual: Node3D = entry.visual
	if body.position.y < 1.72 or not is_instance_valid(visual): return false
	_gull_caught_burst = burst
	_gull_cooldown = 8.0
	var origin: Vector3 = visual.global_position
	visual.reparent(_world, true)
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	remove_child(body)
	body.queue_free()
	# stock_spilled already fired above. The gag owns this exact detached visual
	# and is responsible for freeing it on exit/reset; it cannot charge stock again.
	_world.call("play_gag", "seagull", {"donut":visual, "from":origin, "id":int(entry.id), "burst":burst})
	return true


func _mark_waste(entry: Dictionary, was_stock: bool) -> void:
	if str(entry.stage) == "waste": return
	entry.stage = "waste"
	entry.age = 0.0
	if was_stock:
		stock_spilled.emit(int(entry.id))
	else:
		delivery_settled.emit(int(entry.id), false)


func _set_transparency(node: Node, amount: float) -> void:
	if node is GeometryInstance3D:
		node.transparency = amount
	for child in node.get_children():
		_set_transparency(child, amount)


func _trim_waste() -> void:
	if _entries.size() < MAX_BODIES:
		return
	for index in range(_entries.size() - 1, -1, -1):
		if str(_entries[index].stage) == "waste":
			var body: RigidBody3D = _entries[index].body
			remove_child(body)
			body.queue_free()
			_entries.remove_at(index)
			return


func debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {"available": 0, "conveyor": 0, "falling": 0, "waste": 0, "bodies": _entries.size(), "paused": _paused, "capacity": _capacity, "positions": [], "entries": [], "chute_angle": _chute_angle, "chute_phase": _sweep_phase, "outlet": _chute_tip, "shaking": _shake_time < SHAKE_SECONDS}
	snapshot["shake_strength"] = _shake_strength
	snapshot["rage_shaking"] = _shake_strength >= 3.0 and _shake_time < SHAKE_SECONDS
	snapshot["shake_burst"] = _shake_burst
	snapshot["gull_cooldown"] = _gull_cooldown
	for entry in _entries:
		var stage: String = entry.stage
		if stage == "resident":
			snapshot.available += 1
		else:
			snapshot[stage] = int(snapshot.get(stage, 0)) + 1
		snapshot.positions.append(entry.body.position)
		snapshot.entries.append({"id": entry.id, "stage": stage, "position": entry.body.position, "velocity": entry.body.linear_velocity, "age": entry.age, "contacts": entry.body.get_contact_count()})
	return snapshot
