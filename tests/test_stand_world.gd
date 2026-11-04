extends SceneTree
## Real scene regression gate: physical target rays, persistent fault feedback,
## maintenance/pausing, cosmetic invariants and bounded transient lifetimes.
var failures: int = 0
var checks: int = 0
func _init() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func advance(world, seconds: float) -> void:
	for frame in range(ceili(seconds * 60.0)):
		world._process(1.0 / 60.0)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	var batching: Dictionary = world._static_batch_report
	check(int(batching.source_meshes) > int(batching.batches) * 4, "Static venue geometry is batched by shared material")
	check(int(batching.source_indices) == int(batching.batch_indices), "Batching preserves every original triangle")
	var original_bounds: AABB = batching.source_bounds
	var merged_bounds: AABB = batching.batch_bounds
	check(original_bounds.position.is_equal_approx(merged_bounds.position) and original_bounds.size.is_equal_approx(merged_bounds.size), "Batching preserves transformed scenery bounds")
	check(int(batching.walkers) == 9 and world._bg_walkers.size() == 9, "Animated fairgoers remain independent")
	var state: Dictionary = {"phase":"playing", "temperature":180, "batter":40, "supply":20, "supply_capacity":30, "package_type":"bag", "package_count":6, "package_flavor":"cinnamon", "held_tool":"scoop", "scoop_count":3, "orders":[{"id":4,"package":"bag","flavor":"cinnamon","patience":30,"max_patience":60}]}
	world.reset_food(20, 30)
	world.sync_state(state)
	await physics_frame
	await physics_frame
	for id in ["bag","bucket","scoop","supply","package","cinnamon","powdered","serve","heat_down","heat_up","repair","refill","trash"]:
		check(world.pick_station(world.station_screen_position(id)) == id, "Ray " + id)
	state.jammed = true
	state.jam_progress = 0.5
	world.sync_state(state)
	check(world._context_station == "repair" and world._station_meshes.repair.size() > 0, "Jam stays highlighted")
	check(world._machine_status.text == "DRIVE JAM", "Jam status")
	check(is_equal_approx(world._machine_progress.scale.x,0.5), "Normalized repair progress")
	state.jammed = false
	state.hold_station = "refill"
	state.refill_progress = 0.5
	world.sync_state(state)
	check(is_instance_valid(world._maintenance_prop), "Batter pitcher visible")
	var before: float = world._production_time
	world._process(0.5)
	check(world._production_time == before, "Production stops while refilling")
	state.hold_station = ""
	state.paused = true
	world.sync_state(state)
	before = world._time
	world._process(1.0)
	check(world._time == before, "Pause freezes world")
	state.paused = false
	world.sync_state(state)
	for i in range(20):
		world.animate_action("package")
		world.burst_reward(22.5,3)
	check(world._effects.size() <= 64, "Rapid actions bounded")
	check(world._camera_kick <= 0.12, "Camera recoil capped")
	world.set_reduced_motion(true)
	check(world._camera_kick == 0.0, "Reduced motion resets recoil")
	for i in range(180):
		world._process(1.0 / 60.0)
	check(world._effects.is_empty(), "Effects clean up")
	world.burst_reward(45.5,3)
	check(world._effects.is_empty(), "Reduced motion suppresses celebration particles")
	world.animate_action("powdered")
	check(is_instance_valid(world._action_prop), "Physical seasoning tin")
	world._process(0.20)
	world._process(0.30)
	check(not is_instance_valid(world._action_prop), "Seasoning prop cleans up")
	world.set_hover_station("bag")
	world._process(0.20)
	check(world._station_frames.is_empty() and world._markers.is_empty(), "No hovering frames or selection rectangles")
	check(world._station_overlays.bag.albedo_color.a > 0.0, "Existing bag meshes highlight")
	var highlighted_mesh: MeshInstance3D = world._station_meshes.bag[0]
	check(highlighted_mesh.material_overlay == world._station_overlays.bag, "Hover attaches the shared material pass")
	world.set_hover_station("")
	world._process(0.04)
	check(highlighted_mesh.material_overlay != null and world._station_overlays.bag.albedo_color.a > 0.0, "Leaving hover preserves the gradual fade")
	world._process(0.3)
	check(highlighted_mesh.material_overlay == null, "Finished highlight removes its invisible render pass")
	var dial_start: float = world._heat_knobs[0].rotation.z
	state.heat_setting = 0
	world.sync_state(state)
	world._process(0.03)
	check(not is_equal_approx(world._heat_knobs[0].rotation.z, dial_start), "Heat knob rotates with setting")
	check(not is_equal_approx(world._heat_knobs[0].rotation.z, deg_to_rad(120.0)), "Heat knob interpolates instead of snapping")
	# Follow one real batch through pickup, scoop, pour and handoff. Identity,
	# intermediate poses and inventory must agree, not merely final positions.
	state = {"phase":"playing", "temperature":180, "heat_setting":2, "batter":40, "supply":12, "supply_capacity":30, "package_type":"", "package_count":0, "package_flavor":"", "held_tool":"none", "scoop_count":0, "orders":[{"id":40,"package":"bag","flavor":"cinnamon","patience":30,"max_patience":60},{"id":41,"package":"bag","flavor":"powdered","patience":50,"max_patience":60}]}
	world.reset_food(12, 30)
	world.sync_state(state)
	advance(world, 0.7)
	world.animate_action("bag")
	state.package_type = "bag"
	world.sync_state(state)
	var bag = world._prep
	var bag_start: Vector3 = bag.position
	check(bag_start.distance_to(world._package_anchor) > 1.0, "Bag begins at actual stack")
	advance(world, 0.14)
	check(bag.position.distance_to(bag_start) > 0.1 and bag.position.distance_to(world._package_anchor) > 0.1, "Bag passes through intermediate lift pose")
	world.animate_action("heat_down")
	check(world._action == "bag" and world.is_action_busy(), "Heat adjustment preserves active package transfer")
	advance(world, 0.4)
	check(bag.position.is_equal_approx(world._package_anchor), "Bag opens onto prep mat")
	var scoop_identity = world._held_scoop.get_instance_id()
	world.animate_action("scoop")
	state.held_tool = "scoop"
	world.sync_state(state)
	advance(world, 0.5)
	check(world._held_scoop.get_instance_id() == scoop_identity, "Counter scoop stays the same object in hand")
	world.animate_action("supply")
	state.supply = 9
	state.scoop_count = 3
	world.sync_state(state)
	advance(world, 0.5)
	check(world._food.get_available_count() == 9 and world._held_scoop_donuts.size() == 3, "Physical scooping removes precisely three stock bodies")
	var food_identity = world._held_scoop_donuts[0].get_instance_id()
	world.animate_action("package")
	state.scoop_count = 0
	state.package_count = 3
	world.sync_state(state)
	advance(world, 0.5)
	check(world._prep_donuts[0].get_instance_id() == food_identity and world._held_scoop_donuts.is_empty(), "Pour transfers existing food nodes without replacements")
	state.package_flavor = "cinnamon"
	world.animate_action("cinnamon")
	state.held_tool = "none"
	world.sync_state(state)
	advance(world, 0.5)
	world.animate_action("package")
	state.held_tool = "package"
	world.sync_state(state)
	advance(world, 0.5)
	check(world._held_package == bag and world._prep == bag, "Filled bag remains the same object after lifting")
	var customer = world._people[40]
	world.animate_action("serve")
	state.package_type = ""
	state.package_count = 0
	state.package_flavor = ""
	state.held_tool = "none"
	state.orders.remove_at(0)
	world.sync_state(state)
	check(is_instance_valid(customer) and world._departing.has(customer), "Served customer waits for physical handoff")
	advance(world, 0.52)
	check(is_instance_valid(bag) and bag.get_parent() == customer, "Same filled package reaches departing customer")
	check(customer.get_meta("serve_hit").collision_layer == 0, "Departing customer cannot take next order")
	advance(world, 1.5)
	await process_frame
	check(not is_instance_valid(customer) and not is_instance_valid(bag), "Customer carries order away before cleanup")
	world.reset_food(12, 30)
	check(world._held_scoop_donuts.is_empty() and world._prep == null and world._motions.is_empty(), "Fresh session clears all old transfers")
	world.set_cosmetic("midnight")
	check(world._mat.red.albedo_color == Color("354f7a"), "Earned palette applies")
	check(world._mat.fault.albedo_color == Color("ff5b45"), "Palette preserves safety color")
	world.queue_free()
	await process_frame
	await process_frame
	print("WORLD QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
