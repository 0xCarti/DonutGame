extends SceneTree
## Real fixed-step physics acceptance for the sweeping discharge chute.
## This deliberately uses no controller, profile, save, or settings APIs.
const Food = preload("res://scripts/stand_food_physics.gd")
const OUT: String = "res://playtest-reports/chute-distribution.json"
var checks: int = 0
var failures: int = 0
var world: FoodWorld
var food
var settled: Dictionary = {}
var spilled: Dictionary = {}
var duplicate_callbacks: int = 0
var report: Dictionary = {"scenarios": []}

class FoodWorld extends Node3D:
	var _machine_root: Node3D
	func _init() -> void:
		_machine_root = Node3D.new()
		_machine_root.position = Vector3(-2.35, 1.01, -0.60)
		_machine_root.scale = Vector3.ONE * 0.48
		add_child(_machine_root)
	func _plain_donut(_id: int, _at: Vector3) -> Node3D:
		var visual: Node3D = Node3D.new()
		add_child(visual)
		return visual


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHUTE DISTRIBUTION: " + description)


func frame() -> void:
	await physics_frame
	await process_frame


func _run() -> void:
	world = FoodWorld.new()
	root.add_child(world)
	food = Food.new()
	food.configure(world)
	food.delivery_settled.connect(func(id: int, kept: bool) -> void:
		if settled.has(id): duplicate_callbacks += 1
		settled[id] = {"kept": kept, "position": _body_position(id)})
	food.stock_spilled.connect(func(id: int) -> void:
		if spilled.has(id): duplicate_callbacks += 1
		spilled[id] = _body_position(id))
	# Default cadence is 180 C with no motor upgrade. The maximum case uses
	# the production formula's absolute floor with two motor upgrades, slightly
	# faster than a player can sustain before overheating. Belt time stays real.
	await production_case("default_partial", 0, 36, 24, 1.15)
	await production_case("maximum_partial", 0, 36, 24, 0.614125)
	await production_case("default_near_capacity", 0, 36, 35, 1.15)
	await production_case("maximum_near_capacity", 0, 36, 35, 0.614125)
	await production_case("full_36", 36, 36, 6, 0.614125)
	await production_case("full_60", 60, 60, 6, 0.614125)
	await production_case("checkpoint_replay", 0, 36, 6, 0.0)
	await pause_and_fault_case()
	await tray_shake_case()
	check(duplicate_callbacks == 0, "delivery and resident spill callbacks remain exactly once")
	report["checks"] = checks
	report["failures"] = failures
	report["duplicate_callbacks"] = duplicate_callbacks
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://playtest-reports"))
	var file: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	world.queue_free()
	await process_frame
	await process_frame
	print("CHUTE DISTRIBUTION QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func production_case(label: String, opening: int, capacity: int, count: int, interval: float) -> void:
	food.set_paused(false)
	food.set_machine_running(true)
	food.seed_stock(opening, capacity)
	settled.clear()
	spilled.clear()
	var released: Dictionary = {}
	var release_positions: Array[Vector3] = []
	var release_times: Array[float] = []
	var minimum_conveyor_separation: float = INF
	var peak_bodies: int = 0
	var conservation_failures: int = 0
	var elapsed: float = 0.0
	var sent: int = 0
	var limit: float = float(count) * interval + 20.0
	while elapsed < limit:
		while sent < count and elapsed + 0.0001 >= float(sent) * interval:
			food.enqueue_production(1000 + sent)
			sent += 1
		await frame()
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)
		var active_positions: Array[Vector3] = []
		for entry in food._entries:
			if int(entry.id) < 1000: continue
			if entry.stage == "conveyor" and float(entry.progress) >= 0.0:
				active_positions.append(entry.body.position)
			elif entry.stage != "conveyor" and not released.has(entry.id):
				released[entry.id] = true
				release_positions.append(entry.body.position)
				release_times.append(elapsed)
		for first in range(active_positions.size()):
			for second in range(first + 1, active_positions.size()):
				minimum_conveyor_separation = minf(minimum_conveyor_separation, active_positions[first].distance_to(active_positions[second]))
		var snapshot: Dictionary = food.debug_snapshot()
		peak_bodies = maxi(peak_bodies, int(snapshot.bodies))
		# Waste objects can fade out, so terminal events are the durable ledger.
		var kept: int = 0
		for event in settled.values():
			if bool(event.kept): kept += 1
		if int(snapshot.available) != opening + kept - spilled.size(): conservation_failures += 1
		if sent == count and settled.size() == count:
			# Leave time for any last impact to knock already credited food out.
			for extra in range(120): await frame()
			break
	var kept_count: int = 0
	var landed_positions: Array[Vector3] = []
	for event in settled.values():
		if bool(event.kept):
			kept_count += 1
			landed_positions.append(event.position)
	var minimum_release_gap: float = INF
	for index in range(1, release_times.size()):
		minimum_release_gap = minf(minimum_release_gap, release_times[index] - release_times[index - 1])
	var release_span: Vector3 = position_span(release_positions)
	var landing_span: Vector3 = position_span(landed_positions)
	var current: Dictionary = food.debug_snapshot()
	var result: Dictionary = {"name": label, "opening": opening, "capacity": capacity, "delivery_count": count, "interval_seconds": interval, "elapsed_seconds": elapsed, "settled_count": settled.size(), "kept": kept_count, "delivery_waste": settled.size() - kept_count, "resident_spills": spilled.size(), "available": current.available, "remaining_conveyor": current.conveyor, "remaining_falling": current.falling, "peak_bodies": peak_bodies, "minimum_conveyor_separation": minimum_conveyor_separation if is_finite(minimum_conveyor_separation) else 0.0, "minimum_release_gap": minimum_release_gap if is_finite(minimum_release_gap) else 0.0, "release_x_span": release_span.x, "release_z_span": release_span.z, "landing_x_span": landing_span.x, "landing_z_span": landing_span.z, "release_positions": positions_json(release_positions), "release_times": release_times, "landing_positions": positions_json(landed_positions), "conservation_failure_frames": conservation_failures, "final_snapshot": current}
	report.scenarios.append(result)
	print("CHUTE SCENARIO " + JSON.stringify(result))
	check(settled.size() == count and released.size() == count, label + ": every produced donut releases and settles exactly once")
	check(int(current.conveyor) == 0 and int(current.falling) == 0, label + ": no stuck or permanently pending deliveries")
	check(conservation_failures == 0 and int(current.available) == opening + kept_count - spilled.size(), label + ": stock and actual bodies remain conserved")
	check(peak_bodies <= Food.MAX_BODIES, label + ": physical body count stays bounded")
	check(minimum_conveyor_separation > Food.OUTER_RADIUS * 2.0, label + ": active conveyor donuts do not overlap before discharge")
	if opening == 0:
		check(kept_count == count and spilled.is_empty() and int(current.available) == count, label + ": partial tray keeps every delivery without premature waste")
		if interval > 0.0:
			check(release_span.x >= 0.70 and release_span.z >= 0.65, label + ": discharge sweeps across the tray rather than one fixed exit")
			check(landing_span.x >= 0.70 and landing_span.z >= 0.50, label + ": physical contacts distribute food across the tray")
		else:
			check(minimum_release_gap >= 0.18, label + ": resumed pending IDs release separately instead of a coincident burst")
	else:
		check(settled.size() - kept_count > 0, label + ": full tray still produces actual waste")
		check(int(current.available) <= capacity, label + ": overflow cannot overcredit tray capacity")
		var actual_counter_waste: bool = false
		for entry in food._entries:
			if entry.stage == "waste" and not food._inside_tray(entry.body.position) and entry.body.position.y > 1.65: actual_counter_waste = true
		check(actual_counter_waste, label + ": overflowing food physically rests outside the tray on the counter")


func pause_and_fault_case() -> void:
	food.seed_stock(0, 36)
	food.set_machine_running(true)
	food.set_paused(false)
	food.enqueue_production(4001)
	for index in range(90): await frame()
	var outlet_before: Vector3 = food.conveyor_position(1.0)
	var body_before: Vector3 = food._entries[0].body.position
	food.set_paused(true)
	for index in range(90): await frame()
	check(food.conveyor_position(1.0).is_equal_approx(outlet_before) and food._entries[0].body.position.is_equal_approx(body_before), "pause freezes both the chute and its carried donut")
	food.set_paused(false)
	for index in range(45): await frame()
	check(food.conveyor_position(1.0).distance_to(outlet_before) > 0.03, "unpausing resumes the smooth chute sweep")
	outlet_before = food.conveyor_position(1.0)
	body_before = food._entries[0].body.position
	food.set_machine_running(false)
	for index in range(90): await frame()
	check(food.conveyor_position(1.0).is_equal_approx(outlet_before) and food._entries[0].body.position.is_equal_approx(body_before), "machine fault stops the chute and conveyor together")
	food.set_machine_running(true)
	for index in range(45): await frame()
	check(food.conveyor_position(1.0).distance_to(outlet_before) > 0.03, "clearing the fault resumes the chute sweep")
	food.clear_food()


func _body_position(id: int) -> Vector3:
	for entry in food._entries:
		if int(entry.id) == id: return entry.body.position
	return Vector3.ZERO


func tray_shake_case() -> void:
	food.seed_stock(24, 36)
	settled.clear()
	spilled.clear()
	for index in range(120): await frame()
	var starts: Dictionary = {}
	for entry in food._entries: starts[entry.id] = entry.body.position
	check(food.shake_tray(), "first deliberate tray shake is accepted")
	check(not food.shake_tray(), "tray shake cooldown prevents repeated impulse stacking")
	var maximum_shift: float = 0.0
	var peak_speed: float = 0.0
	for index in range(120):
		await frame()
		for entry in food._entries:
			maximum_shift = maxf(maximum_shift, entry.body.position.distance_to(starts[entry.id]))
			peak_speed = maxf(peak_speed, entry.body.linear_velocity.length())
	check(maximum_shift > 0.01, "shaking actually moves and resettles rigid donuts")
	check(food.get_available_count() == 24 and spilled.is_empty() and int(food.debug_snapshot().waste) == 0, "gentle shake retains every donut in a partial tray")
	check(peak_speed < 2.0, "gentle shake does not violently launch donuts")
	food.set_paused(true)
	check(not food.shake_tray(), "paused game rejects tray shake")
	var paused_positions: Array = food.debug_snapshot().positions.duplicate()
	for index in range(60): await frame()
	check(food.debug_snapshot().positions == paused_positions, "paused shake scenario preserves every body position")
	food.set_paused(false)
	check(food.shake_tray(), "tray shake is available again after cooldown and resume")
	report["tray_shake"] = {"opening": 24, "maximum_displacement": maximum_shift, "peak_speed": peak_speed, "resident_spills": spilled.size(), "available": food.get_available_count()}
	food.clear_food()
	food.seed_stock(60, 60)
	settled.clear()
	spilled.clear()
	for index in range(120): await frame()
	check(food.get_available_count() == 60, "fully upgraded tray remains stable before shaking")
	check(food.shake_tray(), "fully upgraded tray accepts a deliberate shake")
	peak_speed = 0.0
	for index in range(180):
		await frame()
		for entry in food._entries: peak_speed = maxf(peak_speed, entry.body.linear_velocity.length())
	check(food.get_available_count() + spilled.size() == 60, "full-tray shake accounts for every retained or physically spilled donut")
	check(peak_speed < 2.0, "full-tray shake remains a gentle bounded impulse")
	report["full_tray_shake"] = {"opening": 60, "peak_speed": peak_speed, "resident_spills": spilled.size(), "available": food.get_available_count()}
	food.clear_food()


func position_span(positions: Array[Vector3]) -> Vector3:
	if positions.is_empty(): return Vector3.ZERO
	var smallest: Vector3 = positions[0]
	var largest: Vector3 = positions[0]
	for at in positions:
		smallest = smallest.min(at)
		largest = largest.max(at)
	return largest - smallest


func positions_json(positions: Array[Vector3]) -> Array:
	var result: Array = []
	for at in positions: result.append([at.x, at.y, at.z])
	return result
