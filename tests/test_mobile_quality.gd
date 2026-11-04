extends SceneTree
## Exercise actual viewport/light changes and identity preservation while food is
## on the tray, on the conveyor and in the player's scoop. This is not a benchmark.
const MobileQuality = preload("res://scripts/mobile_quality.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("MOBILE QUALITY: " + message)


func _food_identity(world) -> Array:
	var identity: Array = []
	for entry in world._food._entries:
		identity.append([int(entry.id), str(entry.stage), entry.body.get_instance_id(), entry.visual.get_instance_id(), entry.body.collision_layer, entry.body.collision_mask, entry.visual.visible])
	for donut in world._held_scoop_donuts:
		identity.append(["held", donut.get_instance_id(), donut.visible])
	return identity


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var initial_scale: float = root.scaling_3d_scale
	var initial_aa: int = root.msaa_3d
	var initial_screen_aa: int = root.screen_space_aa
	var initial_scale_mode: int = root.scaling_3d_mode
	var initial_taa: bool = root.use_taa
	var initial_fps: int = Engine.max_fps
	var initial_ticks: int = Engine.physics_ticks_per_second
	var initial_time_scale: float = Engine.time_scale
	var initial_window: Vector2i = root.size
	var quality = MobileQuality.new()
	_check(quality.recommended_level() == 1 and quality.recommended_level(false) == 2, "Mobile starts Balanced while desktop remains High")
	var unattached: Node = Node.new()
	_check(not bool(quality.apply(unattached, 0).applied), "Invalid worlds cannot change global rendering or FPS")
	unattached.free()
	_check(Engine.max_fps == initial_fps and is_equal_approx(root.scaling_3d_scale, initial_scale), "Rejected application leaves the baseline intact")
	var world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.reset_food(12, 30)
	world._food.set_physics_process(false)
	world._food.enqueue_production(501)
	world._held_scoop_donuts = world._food.take_donuts(3)
	var before: Array = _food_identity(world)
	var supply_before: int = world._food.get_available_count()
	var surfaces_before: int = world._food._surfaces.get_child_count()
	var ray_points: Dictionary = {}
	for id in world._stations:
		ray_points[id] = world.station_screen_position(id)
	_check(world._sunlight.shadow_enabled and is_equal_approx(world._sunlight.directional_shadow_max_distance, 36.0), "Default desktop sunlight retains its authored shadow range")
	# High -> Low exercises safe AA removal before a scale reduction. Out-of-range
	# saved values must select a bounded profile, with no food state reconstruction.
	for level in [2, 0, 1, 2, -30, 999]:
		var result: Dictionary = quality.apply(world, level)
		var expected: int = clampi(level, 0, 2)
		_check(bool(result.applied) and int(result.level) == expected, "Applies a bounded mobile profile")
		_check(is_equal_approx(root.scaling_3d_scale, [0.65, 0.80, 1.0][expected]), "Profile changes the actual 3D render scale")
		_check(root.msaa_3d == (Viewport.MSAA_2X if expected == 2 else Viewport.MSAA_DISABLED), "Subnative mobile profiles avoid the reported Compatibility/MSAA leak combination")
		_check(Engine.max_fps == (30 if expected == 0 else 60), "Profile sets its actual render-frame cap")
		_check(world._sunlight.shadow_enabled == (expected >= 1), "Low removes real directional shadow rendering")
		var detail_shadow_count: int = 0
		for light in world._detail_lights:
			if light.shadow_enabled: detail_shadow_count += 1
		_check(detail_shadow_count == (1 if expected == 2 else 0), "Only High retains the one authored task-light shadow")
		_check(_food_identity(world) == before and world._food.get_available_count() == supply_before, "Quality switches preserve every owned food ID, body, visible mesh and stock count")
		_check(world._food._surfaces.get_child_count() == surfaces_before, "Quality switches preserve food collision surfaces")
		_check(Engine.physics_ticks_per_second == initial_ticks and is_equal_approx(Engine.time_scale, initial_time_scale), "Rendering profiles do not change the simulation rate")
		_check(root.size == initial_window, "3D scaling leaves the HUD and touch coordinate resolution intact")
		for id in ray_points:
			_check(world.station_screen_position(id).is_equal_approx(ray_points[id]), "3D scale preserves station projection: " + id)
	quality.apply(world, 2, false)
	_check(is_equal_approx(root.scaling_3d_scale, initial_scale) and root.msaa_3d == initial_aa, "Leaving mobile restores original desktop resolution and MSAA")
	_check(root.screen_space_aa == initial_screen_aa and root.scaling_3d_mode == initial_scale_mode and root.use_taa == initial_taa and Engine.max_fps == initial_fps, "Leaving mobile restores all other captured viewport/FPS settings")
	_check(world._sunlight.shadow_enabled and is_equal_approx(world._sunlight.directional_shadow_max_distance, 36.0), "Leaving mobile restores full desktop shadow range")
	world.set_quality(0)
	_check(world._sunlight.shadow_enabled, "Legacy one-argument desktop set_quality keeps its existing directional shadows")
	var device: Dictionary = quality.describe_device()
	_check(not bool(device.performance_verified) and not str(device.recommendation).is_empty(), "Device description never claims unmeasured frame rate")
	world.reset_food(0, 30)
	world.queue_free()
	await process_frame
	print("MOBILE QUALITY QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
