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
func _run() -> void:
	root.size = Vector2i(1280, 800)
	var world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	var state: Dictionary = {"phase":"playing", "temperature":180, "batter":40, "supply":20, "supply_capacity":30, "package_type":"bag", "package_count":6, "package_flavor":"cinnamon", "held_tool":"scoop", "scoop_count":3, "orders":[{"id":4,"package":"bag","flavor":"cinnamon","patience":30,"max_patience":60}]}
	world.sync_state(state)
	await physics_frame
	await physics_frame
	for id in ["bag","bucket","scoop","supply","package","cinnamon","powdered","serve","heat_down","heat_up","repair","refill","trash"]:
		check(world.pick_station(world.station_screen_position(id)) == id, "Ray " + id)
	state.jammed = true
	state.jam_progress = 0.5
	world.sync_state(state)
	check(world._context_station == "repair" and world._station_frames.repair.visible, "Jam stays highlighted")
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
	world._process(1.0)
	check(not is_instance_valid(world._action_prop), "Seasoning prop cleans up")
	world.set_cosmetic("midnight")
	check(world._mat.red.albedo_color == Color("354f7a"), "Earned palette applies")
	check(world._mat.fault.albedo_color == Color("ff5b45"), "Palette preserves safety color")
	world.queue_free()
	await process_frame
	await process_frame
	print("WORLD QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
