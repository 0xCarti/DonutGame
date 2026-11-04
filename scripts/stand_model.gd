extends RefCounted
## Idea #2: an order-serving stand. Presentation/tool selection lives in stand_main.
## The clock, food, orders, heat, repairs and money are authoritative here.

const SAVE_VERSION: int = 1
const TARGETS: Array[int] = [110, 180, 260]
const SHIFT_TIMES: Array[float] = [105.0, 110.0, 115.0]
const ARRIVAL_TIMES: Array[float] = [15.0, 12.0, 9.5]
const PATIENCE_TIMES: Array[float] = [52.0, 44.0, 37.0]
const FLAVORS: Dictionary = {"cinnamon": {"name": "Cinnamon", "color": Color("cf843f")}, "powdered": {"name": "Powdered sugar", "color": Color("fff2dc")}}
const PACKAGES: Dictionary = {"bag": {"name": "Bag", "capacity": 6, "price": 18.0}, "bucket": {"name": "Bucket", "capacity": 12, "price": 32.0}}
const UPGRADES: Dictionary = {
	"wide_scoop": {"name": "Bigger scoop", "description": "Carry 4 donuts per scoop instead of 3. Buckets take one fewer scoop.", "cost": 18, "max_level": 1},
	"fast_motor": {"name": "Fresh off the fryer", "description": "The machine produces donuts 15% faster per level.", "cost": 16, "max_level": 2},
	"large_hopper": {"name": "Deep batter hopper", "description": "Hold and start with 30 more batter per level.", "cost": 14, "max_level": 2},
	"extra_tray": {"name": "Bigger catch tray", "description": "Store 12 more cooked donuts per level, with 6 more ready at opening.", "cost": 12, "max_level": 2},
	"easy_repair": {"name": "Quick-release guard", "description": "Clear jams 35% faster. Repair progress is kept when you let go.", "cost": 14, "max_level": 1},
	"calm_queue": {"name": "Friendly service", "description": "Customers wait 7 seconds longer per level.", "cost": 15, "max_level": 2},
	"steady_feed": {"name": "Smooth feeder", "description": "The machine makes 10 more donuts between jams.", "cost": 18, "max_level": 1},
	"generous_tips": {"name": "Tip jar", "description": "Each correctly served customer leaves one extra dollar per level.", "cost": 12, "max_level": 2},
}

var phase: String = "ready"
var shift_index: int = 0
var time_left: float = SHIFT_TIMES[0]
var shift_duration: float = SHIFT_TIMES[0]
var orders: Array = []
var supply: int = 18
var supply_capacity: int = 36
var batter: int = 72
var temperature: float = 175.0
var heat_setting: int = 3
var jammed: bool = false
var jam_progress: float = 0.0
var overheated: bool = false
var refill_progress: float = 0.0
var production_count: int = 0
var package_type: String = ""
var package_count: int = 0
var package_flavor: String = ""
var scoop_count: int = 0
var sales: float = 0.0
var served: int = 0
var missed: int = 0
var mistakes: int = 0
var streak: int = 0
var target: int = TARGETS[0]
var credits: int = 0
var events: Array = []
var owned: Dictionary = {}
var last_result: Dictionary = {}
var seed_value: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _production_clock: float = 0.0
var _arrival_clock: float = ARRIVAL_TIMES[0]
var _next_jam_at: int = 25
var _next_order_id: int = 1
var _orders_created: int = 0
var _refill_age: float = 10.0
var _offers: Array = []
var _offers_generated: bool = false
var _run_served: int = 0
var _run_missed: int = 0
var _run_sales: float = 0.0


func _init() -> void:
	new_run(1)


func new_run(run_seed: int = 0) -> void:
	seed_value = run_seed
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec() & 0x7fffffff)
		if seed_value == 0: seed_value = 1
	_rng.seed = seed_value
	phase = "ready"
	shift_index = 0
	credits = 0
	owned = {}
	events = []
	last_result = {}
	_next_order_id = 1
	_run_served = 0
	_run_missed = 0
	_run_sales = 0.0
	_reset_shift()


func _reset_shift() -> void:
	shift_duration = SHIFT_TIMES[shift_index]
	time_left = shift_duration
	target = TARGETS[shift_index]
	orders = []
	supply_capacity = 36 + level("extra_tray") * 12
	supply = 18 + level("extra_tray") * 6
	batter = batter_capacity()
	temperature = 175.0
	heat_setting = 3
	jammed = false
	jam_progress = 0.0
	overheated = false
	refill_progress = 0.0
	production_count = 0
	package_type = ""
	package_count = 0
	package_flavor = ""
	scoop_count = 0
	sales = 0.0
	served = 0
	missed = 0
	mistakes = 0
	streak = 0
	_production_clock = 0.0
	_arrival_clock = ARRIVAL_TIMES[shift_index]
	_next_jam_at = _rng.randi_range(23, 29) + level("steady_feed") * 10
	_orders_created = 0
	_refill_age = 10.0
	_offers = []
	_offers_generated = false


func start_shift() -> void:
	if phase != "ready" and phase != "shop": return
	if phase == "shop": shift_index += 1
	if shift_index >= TARGETS.size():
		phase = "won"
		return
	_reset_shift()
	phase = "playing"
	_spawn_order()
	events.append({"type": "shift_start", "shift": shift_index, "target": target})


func tick(delta: float) -> void:
	if phase != "playing" or not is_finite(delta) or delta <= 0.0: return
	var remaining: float = minf(delta, time_left)
	while remaining > 0.0000001 and phase == "playing":
		var step: float = minf(remaining, 0.1)
		_step(step)
		remaining -= step
	if phase == "playing" and time_left <= 0.000001:
		time_left = 0.0
		finish_shift()


func _step(step: float) -> void:
	time_left = maxf(0.0, time_left - step)
	_refill_age = minf(10.0, _refill_age + step)
	var desired: float = [90.0, 135.0, 175.0, 210.0, 240.0][heat_setting]
	var thermal_rate: float = 0.06 if desired < temperature else 0.035
	temperature = clampf(temperature + (desired - temperature) * thermal_rate * step, 20.0, 260.0)
	if not overheated and temperature >= 205.0:
		overheated = true
		events.append({"type": "overheat", "temperature": temperature})
	elif overheated and temperature <= 190.0:
		overheated = false
		events.append({"type": "cooled", "temperature": temperature})
	if _can_produce():
		var interval: float = clampf(1.5 - (temperature - 145.0) * 0.01, 0.85, 1.5) * pow(0.85, float(level("fast_motor")))
		_production_clock += step
		while _production_clock >= interval and _can_produce():
			_production_clock -= interval
			supply += 1
			batter -= 1
			production_count += 1
			temperature = minf(260.0, temperature + 0.12)
			events.append({"type": "production", "supply": supply, "batter": batter, "count": production_count})
			if production_count >= _next_jam_at and shift_duration - time_left >= 22.0:
				jammed = true
				jam_progress = 0.0
				events.append({"type": "jam", "count": production_count})
	for index in range(orders.size() - 1, -1, -1):
		orders[index]["patience"] = maxf(0.0, float(orders[index]["patience"]) - step)
		if float(orders[index]["patience"]) <= 0.0:
			var leaving: Dictionary = orders[index]
			orders.remove_at(index)
			missed += 1
			_run_missed += 1
			streak = 0
			events.append({"type": "walkout", "order_id": leaving["id"], "missed": missed})
	_arrival_clock -= step
	if _arrival_clock <= 0.0:
		if orders.size() < 3:
			_spawn_order()
			_arrival_clock += ARRIVAL_TIMES[shift_index] + _rng.randf_range(-1.5, 1.5)
		else:
			_arrival_clock = 2.5


func _can_produce() -> bool:
	return phase == "playing" and not jammed and not overheated and temperature >= 145.0 and supply < supply_capacity and batter > 0 and not (refill_progress > 0.0 and _refill_age <= 0.25)


func _spawn_order() -> void:
	if orders.size() >= 3: return
	var kind: String = "bag"
	var flavor: String = "cinnamon"
	if shift_index == 0 and _orders_created < 3:
		kind = "bucket" if _orders_created == 2 else "bag"
		flavor = "powdered" if _orders_created == 1 else "cinnamon"
	else:
		kind = "bucket" if _rng.randf() < 0.35 + float(shift_index) * 0.1 else "bag"
		flavor = "cinnamon" if _rng.randi_range(0, 1) == 0 else "powdered"
	var patience: float = PATIENCE_TIMES[shift_index] + (8.0 if kind == "bucket" else 0.0) + float(level("calm_queue") * 7)
	var order: Dictionary = {"id": _next_order_id, "package": kind, "flavor": flavor, "patience": patience, "max_patience": patience, "base_price": float(PACKAGES[kind]["price"])}
	_next_order_id += 1
	_orders_created += 1
	orders.append(order)
	events.append({"type": "customer_arrived", "order": order.duplicate(true)})


func choose_package(kind: String) -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if not PACKAGES.has(kind): return _fail("invalid_package", "Choose a bag or a bucket.")
	if package_count > 0 and package_type != kind: return _fail("occupied", "Finish this package or clear it first.")
	package_type = kind
	return _ok("package_ready", "%s ready: %d donuts." % [str(PACKAGES[kind]["name"]), package_capacity()])


func scoop() -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if package_type.is_empty(): return _fail("no_package", "Put out a bag or bucket first.")
	if scoop_count > 0: return _fail("scoop_full", "Dump the donuts already in your scoop.")
	if not package_flavor.is_empty(): return _fail("already_coated", "This package is already seasoned.")
	if package_count >= package_capacity(): return _fail("package_full", "The package is full. Add the requested sugar.")
	if supply <= 0: return _fail("empty_supply", "The catch tray is empty. Check the machine.")
	scoop_count = mini(mini(scoop_capacity(), supply), package_capacity() - package_count)
	supply -= scoop_count
	return _ok("scooped", "%d donuts in the scoop." % scoop_count, {"count": scoop_count})


func dump() -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if package_type.is_empty(): return _fail("no_package", "Put out a bag or bucket first.")
	if scoop_count <= 0: return _fail("empty_scoop", "Scoop some donuts first.")
	if not package_flavor.is_empty(): return _fail("already_coated", "This package is already seasoned.")
	var moved: int = mini(scoop_count, package_capacity() - package_count)
	if moved <= 0: return _fail("package_full", "This package is already full.")
	package_count += moved
	scoop_count -= moved
	return _ok("dumped", "%d / %d donuts." % [package_count, package_capacity()], {"count": moved, "full": package_count == package_capacity()})


func coat(flavor: String) -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if not FLAVORS.has(flavor): return _fail("invalid_flavor", "Choose cinnamon or powdered sugar.")
	if package_type.is_empty() or package_count != package_capacity(): return _fail("not_full", "Fill the package before adding sugar.")
	if not package_flavor.is_empty() and package_flavor != flavor: return _fail("already_coated", "That sugar cannot be removed. Clear the package to start again.")
	package_flavor = flavor
	return _ok("coated", "%s %s ready." % [str(FLAVORS[flavor]["name"]), package_type], {"flavor": flavor})


func serve() -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if orders.is_empty(): return _fail("no_customer", "Wait for a customer to reach the counter.")
	if package_type.is_empty() or package_count == 0: return _fail("no_food", "Prepare the customer's order first.")
	var order: Dictionary = orders[0]
	if package_type != str(order["package"]) or package_count != int(PACKAGES[order["package"]]["capacity"]) or package_flavor != str(order["flavor"]):
		mistakes += 1
		streak = 0
		order["patience"] = maxf(0.0, float(order["patience"]) - 4.0)
		events.append({"type": "wrong_order", "order_id": order["id"], "mistakes": mistakes})
		return _fail("wrong_order", "They want a %s of %s donuts. Your food is still on the counter." % [str(order["package"]), str(order["flavor"])], {"order_id": order["id"]})
	var patience_ratio: float = clampf(float(order["patience"]) / float(order["max_patience"]), 0.0, 1.0)
	var tip: float = floor((6.0 if package_type == "bucket" else 4.0) * patience_ratio) + float(mini(streak, 5)) * 0.5 + float(level("generous_tips"))
	var amount: float = snappedf(float(order["base_price"]) + tip, 0.01)
	sales = snappedf(sales + amount, 0.01)
	served += 1
	_run_served += 1
	_run_sales = snappedf(_run_sales + amount, 0.01)
	streak += 1
	orders.pop_front()
	package_type = ""
	package_count = 0
	package_flavor = ""
	var receipt: Dictionary = _ok("served", "Order served! +$%.2f" % amount, {"amount": amount, "tip": tip, "order_id": order["id"], "streak": streak, "package": order["package"], "flavor": order["flavor"]})
	var event: Dictionary = receipt.duplicate(true)
	event["type"] = "sale"
	events.append(event)
	return receipt


func discard() -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	var recoverable: int = scoop_count + (package_count if package_flavor.is_empty() else 0)
	var returned: int = mini(recoverable, supply_capacity - supply)
	var wasted: int = scoop_count + package_count - returned
	supply += returned
	scoop_count = 0
	package_type = ""
	package_count = 0
	package_flavor = ""
	return _ok("cleared", "Counter cleared. %d plain donuts recovered; %d discarded." % [returned, wasted], {"returned": returned, "wasted": wasted})


func adjust_heat(change: int) -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	heat_setting = clampi(heat_setting + clampi(change, -4, 4), 0, 4)
	return _ok("heat_changed", "Heat setting %d / 4." % heat_setting, {"setting": heat_setting})


func repair(delta: float) -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if not jammed: return _fail("not_jammed", "The feeder is running.")
	if not is_finite(delta) or delta <= 0.0 or delta > 1.0: return _fail("invalid_time", "Keep holding the repair control.")
	var duration: float = 1.8 * (0.65 if level("easy_repair") > 0 else 1.0)
	jam_progress = minf(1.0, jam_progress + delta / duration)
	if jam_progress >= 0.999999:
		jammed = false
		jam_progress = 0.0
		_next_jam_at = production_count + _rng.randi_range(23, 29) + level("steady_feed") * 10
		events.append({"type": "repair"})
		return _ok("repaired", "Feeder cleared. Donuts are moving again.")
	return _ok("repairing", "Clearing the feeder...", {"progress": jam_progress})


func refill(delta: float) -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if batter >= batter_capacity(): return _fail("batter_full", "The hopper is already full.")
	if not is_finite(delta) or delta <= 0.0 or delta > 1.0: return _fail("invalid_time", "Keep holding the batter refill.")
	_refill_age = 0.0
	refill_progress = minf(1.0, refill_progress + delta / 2.0)
	if refill_progress >= 0.999999:
		batter = batter_capacity()
		refill_progress = 0.0
		_refill_age = 10.0
		events.append({"type": "refill", "batter": batter})
		return _ok("refilled", "Fresh batter loaded.", {"batter": batter})
	return _ok("refilling", "Pouring fresh batter...", {"progress": refill_progress})


func finish_shift() -> void:
	if phase != "playing": return
	var cleared: bool = sales + 0.001 >= float(target)
	var earned: int = 8 + served * 3 + int(sales / 45.0) if cleared else 0
	credits += earned
	phase = ("won" if shift_index == TARGETS.size() - 1 else "shop") if cleared else "lost"
	last_result = {"cleared": cleared, "shift": shift_index + 1, "sales": sales, "target": target, "served": served, "missed": missed, "mistakes": mistakes, "credits_earned": earned, "total_served": _run_served, "total_missed": _run_missed, "total_sales": _run_sales}
	events.append({"type": "shift_end", "phase": phase, "result": last_result.duplicate(true)})
	if phase == "shop": _generate_offers()


func get_shop_offers() -> Array:
	if phase != "shop": return []
	if not _offers_generated: _generate_offers()
	var result: Array = []
	for id in _offers:
		var offer: Dictionary = UPGRADES[id].duplicate(true)
		offer["id"] = id
		offer["level"] = level(str(id))
		offer["cost"] = _upgrade_cost(str(id))
		result.append(offer)
	return result


func _generate_offers() -> void:
	_offers = []
	_offers_generated = true
	var eligible: Array = []
	for id in UPGRADES:
		if level(str(id)) < int(UPGRADES[id]["max_level"]): eligible.append(id)
	while _offers.size() < 3 and not eligible.is_empty():
		var index: int = _rng.randi_range(0, eligible.size() - 1)
		_offers.append(eligible[index])
		eligible.remove_at(index)


func buy_upgrade(id: String) -> bool:
	if phase != "shop" or not _offers.has(id) or not UPGRADES.has(id): return false
	var cost: int = _upgrade_cost(id)
	if credits < cost or level(id) >= int(UPGRADES[id]["max_level"]): return false
	credits -= cost
	owned[id] = level(id) + 1
	if id == "extra_tray": supply_capacity = 36 + level("extra_tray") * 12
	_offers.erase(id)
	events.append({"type": "upgrade", "id": id, "name": UPGRADES[id]["name"], "level": level(id)})
	return true


func _upgrade_cost(id: String) -> int:
	return int(ceil(float(UPGRADES[id]["cost"]) * (1.0 + float(level(id)) * 0.5)))


func level(id: String) -> int:
	return int(owned.get(id, 0))


func package_capacity() -> int:
	return int(PACKAGES.get(package_type, {}).get("capacity", 0))


func scoop_capacity() -> int:
	return 4 if level("wide_scoop") > 0 else 3


func batter_capacity() -> int:
	return 72 + level("large_hopper") * 30


func production_status() -> String:
	if phase != "playing": return "Stand closed"
	if jammed: return "JAMMED - hold repair"
	if overheated: return "TOO HOT - lower heat"
	if temperature < 145.0: return "Warming up - raise heat"
	if batter <= 0: return "OUT OF BATTER - hold refill"
	if supply >= supply_capacity: return "Catch tray full"
	if refill_progress > 0.0 and _refill_age <= 0.25: return "Refilling batter"
	return "Making donuts"


func get_stats() -> Dictionary:
	return {"scoop_capacity": scoop_capacity(), "batter_capacity": batter_capacity(), "supply_capacity": supply_capacity, "production_count": production_count, "total_served": _run_served, "total_missed": _run_missed, "total_sales": _run_sales, "shift_duration": shift_duration, "repair_duration": 1.8 * (0.65 if level("easy_repair") > 0 else 1.0), "refill_duration": 2.0}


func _ok(code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "code": code, "message": message}
	result.merge(extra)
	return result


func _fail(code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": false, "code": code, "message": message}
	result.merge(extra)
	return result


func to_save() -> Dictionary:
	var result: Dictionary = {"version": SAVE_VERSION, "seed_value": str(seed_value), "rng_state": str(_rng.state)}
	for key in _saved_keys(): result[key] = get(key)
	return result.duplicate(true)


func from_save(data: Dictionary) -> bool:
	if not _valid_save(data): return false
	for key in _saved_keys(): set(key, data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key])
	for order in orders:
		order["id"] = int(order["id"])
		order["patience"] = float(order["patience"])
		order["max_patience"] = float(order["max_patience"])
		order["base_price"] = float(order["base_price"])
	for id in owned: owned[id] = int(owned[id])
	for key in ["shift", "target", "served", "missed", "mistakes", "credits_earned", "total_served", "total_missed"]:
		if last_result.has(key): last_result[key] = int(last_result[key])
	for key in ["sales", "total_sales"]:
		if last_result.has(key): last_result[key] = float(last_result[key])
	seed_value = int(str(data["seed_value"]))
	_rng.seed = seed_value
	_rng.state = int(str(data["rng_state"]))
	events = []
	return true


func _saved_keys() -> Array[String]:
	return ["phase", "shift_index", "time_left", "shift_duration", "orders", "supply", "supply_capacity", "batter", "temperature", "heat_setting", "jammed", "jam_progress", "overheated", "refill_progress", "production_count", "package_type", "package_count", "package_flavor", "scoop_count", "sales", "served", "missed", "mistakes", "streak", "target", "credits", "owned", "last_result", "_production_clock", "_arrival_clock", "_next_jam_at", "_next_order_id", "_orders_created", "_refill_age", "_offers", "_offers_generated", "_run_served", "_run_missed", "_run_sales"]


func _valid_save(data: Dictionary) -> bool:
	if not _integer_in(data.get("version"), SAVE_VERSION, SAVE_VERSION): return false
	for key in _saved_keys():
		if not data.has(key): return false
	if not data.get("phase") is String or not str(data["phase"]) in ["ready", "playing", "shop", "won", "lost"]: return false
	if not _integer_in(data.get("shift_index"), 0, 2): return false
	if not _valid_int64_text(data.get("seed_value")) or not _valid_int64_text(data.get("rng_state")): return false
	for spec in [["time_left", 0, 115], ["shift_duration", 105, 115], ["temperature", 20, 260], ["jam_progress", 0, 1], ["refill_progress", 0, 1], ["sales", 0, 1000000], ["_production_clock", 0, 3], ["_arrival_clock", -1, 30], ["_refill_age", 0, 10], ["_run_sales", 0, 10000000]]:
		if not _number_in(data.get(spec[0]), float(spec[1]), float(spec[2])): return false
	for spec in [["supply", 0, 60], ["supply_capacity", 36, 60], ["batter", 0, 132], ["heat_setting", 0, 4], ["production_count", 0, 100000], ["package_count", 0, 12], ["scoop_count", 0, 4], ["served", 0, 100000], ["missed", 0, 100000], ["mistakes", 0, 100000], ["streak", 0, 100000], ["credits", 0, 1000000], ["_next_jam_at", 1, 100000], ["_next_order_id", 1, 100000], ["_orders_created", 0, 100000], ["_run_served", 0, 100000], ["_run_missed", 0, 100000]]:
		if not _integer_in(data.get(spec[0]), int(spec[1]), int(spec[2])): return false
	if not _integer_in(data.get("target"), TARGETS[int(data["shift_index"])], TARGETS[int(data["shift_index"])]): return false
	if float(data["shift_duration"]) != SHIFT_TIMES[int(data["shift_index"])] or float(data["time_left"]) > float(data["shift_duration"]): return false
	for key in ["jammed", "overheated", "_offers_generated"]:
		if not data[key] is bool: return false
	if not data["owned"] is Dictionary or not data["last_result"] is Dictionary: return false
	for id in data["owned"]:
		if not UPGRADES.has(id) or not _integer_in(data["owned"][id], 1, int(UPGRADES[id]["max_level"])): return false
	if int(data["supply_capacity"]) != 36 + int(data["owned"].get("extra_tray", 0)) * 12 or int(data["supply"]) > int(data["supply_capacity"]): return false
	if int(data["batter"]) > 72 + int(data["owned"].get("large_hopper", 0)) * 30: return false
	if int(data["scoop_count"]) > (4 if int(data["owned"].get("wide_scoop", 0)) > 0 else 3): return false
	if not data["package_type"] is String or not data["package_flavor"] is String: return false
	if str(data["package_type"]) != "" and not PACKAGES.has(data["package_type"]): return false
	if str(data["package_flavor"]) != "" and not FLAVORS.has(data["package_flavor"]): return false
	var capacity: int = int(PACKAGES.get(data["package_type"], {}).get("capacity", 0))
	if int(data["package_count"]) > capacity: return false
	if str(data["package_flavor"]) != "" and (capacity == 0 or int(data["package_count"]) != capacity): return false
	if not data["orders"] is Array or data["orders"].size() > 3: return false
	var ids: Dictionary = {}
	for order in data["orders"]:
		if not order is Dictionary or not _integer_in(order.get("id"), 1, int(data["_next_order_id"]) - 1): return false
		if ids.has(int(order["id"])) or not PACKAGES.has(order.get("package")) or not FLAVORS.has(order.get("flavor")): return false
		ids[int(order["id"])] = true
		if not _number_in(order.get("max_patience"), 1, 100) or not _number_in(order.get("patience"), 0, float(order["max_patience"])): return false
		if not _number_in(order.get("base_price"), 1, 1000): return false
	if not data["_offers"] is Array or data["_offers"].size() > 3: return false
	var offers_seen: Dictionary = {}
	for id in data["_offers"]:
		if not id is String or not UPGRADES.has(id) or offers_seen.has(id): return false
		offers_seen[id] = true
	var result: Dictionary = data["last_result"]
	if not result.is_empty():
		if not result.get("cleared") is bool: return false
		if not _integer_in(result.get("shift"), 1, 3): return false
		if not _integer_in(result.get("target"), 1, 260): return false
		for key in ["served", "missed", "mistakes", "credits_earned", "total_served", "total_missed"]:
			if not _integer_in(result.get(key), 0, 1000000): return false
		for key in ["sales", "total_sales"]:
			if not _number_in(result.get(key), 0.0, 10000000.0): return false
	return true


func _number_in(value: Variant, minimum: float, maximum: float) -> bool:
	if not value is int and not value is float: return false
	return is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


func _integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	return _number_in(value, float(minimum), float(maximum)) and float(value) == floor(float(value))


func _valid_int64_text(value: Variant) -> bool:
	if not value is String or not str(value).is_valid_int(): return false
	var text: String = str(value)
	var negative: bool = text.begins_with("-")
	var digits: String = text.substr(1) if negative else text
	if digits.length() > 19: return false
	var boundary: String = "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() == 19 and digits.casecmp_to(boundary) > 0: return false
	return str(int(text)) == text
