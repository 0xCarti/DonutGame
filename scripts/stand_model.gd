extends RefCounted
## Idea #2: an order-serving stand. Presentation/tool selection lives in stand_main.
## The clock, food, orders, heat, repairs and money are authoritative here.

const Content = preload("res://scripts/stand_content.gd")
const SAVE_VERSION: int = 4
const FIRE_BUILDUP_SECONDS: float = 12.0
const FIRE_RECOVERY_SECONDS: float = 2.4
const FOAM_SECONDS: float = 8.0
const ENABLE_FUTURE_BOOSTS: bool = false
const TARGETS: Array[int] = [110, 175, 250, 330, 420, 520]
const SHIFT_TIMES: Array[float] = [105.0, 110.0, 115.0, 120.0, 125.0, 130.0]
const ARRIVAL_TIMES: Array[float] = [15.0, 12.0, 10.5, 9.2, 8.4, 7.8]
const PATIENCE_TIMES: Array[float] = [56.0, 51.0, 48.0, 45.0, 43.0, 42.0]
const FLAVORS: Dictionary = {"cinnamon": {"name": "Cinnamon", "color": Color("cf843f")}, "powdered": {"name": "Powdered sugar", "color": Color("fff2dc")}}
const PACKAGES: Dictionary = {"bag": {"name": "Bag", "capacity": 6, "price": 18.0}, "bucket": {"name": "Bucket", "capacity": 12, "price": 32.0}}
const UPGRADES: Dictionary = Content.UPGRADES

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
var fire_active: bool = false
var fire_danger: float = 0.0
var fire_recovery: float = 0.0
var foam_time: float = 0.0
var refill_progress: float = 0.0
var production_count: int = 0
## Rendering enables this so food becomes stock only after its physical landing.
var external_delivery: bool = false
var delivery_epoch: int = 0
var waste_count: int = 0
var _run_wasted: int = 0
var _next_delivery_id: int = 1
var _pending_deliveries: Array = []
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
var difficulty: String = "normal"
var mode: String = "campaign"
var shift_name: String = "Opening Day"
var shift_description: String = ""
var jam_risk: float = 0.0
var heat_warning: bool = false
var assisted: bool = false
var active_boosts: Dictionary = {}
var last_save_error: String = ""

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
var _best_streak: int = 0
var _rules: Dictionary = {}
var _legacy_shift: bool = false
var _machine_elapsed: float = 0.0
var _last_jam_production: int = 0
var _service_age: float = 10.0
var _jam_warned: bool = false


func _init() -> void:
	new_run(1)


func new_run(run_seed: int = 0, run_difficulty: String = "normal", game_mode: String = "campaign") -> void:
	difficulty = run_difficulty if run_difficulty in ["normal", "relaxed"] else "normal"
	mode = game_mode if game_mode in ["campaign", "endless"] else "campaign"
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
	_run_wasted = 0
	_best_streak = 0
	assisted = false
	active_boosts = {}
	_legacy_shift = false
	_reset_shift()


func _reset_shift() -> void:
	delivery_epoch += 1
	_pending_deliveries.clear()
	waste_count = 0
	_rules = Content.shift_info(shift_index, difficulty, mode)
	_legacy_shift = false
	shift_name = str(_rules["name"])
	shift_description = str(_rules["description"])
	shift_duration = float(_rules["duration"])
	time_left = shift_duration
	target = int(_rules["target"])
	orders = []
	supply_capacity = 36 + level("extra_tray") * 12
	supply = mini(supply_capacity, 18 + level("extra_tray") * 6 + level("opening_stock") * 12 + (6 if difficulty == "relaxed" else 0))
	batter = batter_capacity()
	temperature = 175.0
	heat_setting = 3
	jammed = false
	jam_progress = 0.0
	overheated = false
	fire_active = false
	fire_danger = 0.0
	fire_recovery = 0.0
	foam_time = 0.0
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
	active_boosts = {}
	jam_risk = 0.0
	heat_warning = false
	_production_clock = 0.0
	_arrival_clock = float(_rules["arrival"])
	_next_jam_at = int(_rules["jam_interval"]) + _rng.randi_range(-2, 2) + level("steady_feed") * 10
	_orders_created = 0
	_refill_age = 10.0
	_service_age = 10.0
	_machine_elapsed = 0.0
	_last_jam_production = 0
	_jam_warned = false
	_offers = []
	_offers_generated = false


func start_shift() -> void:
	if phase != "ready" and phase != "shop": return
	if phase == "shop": shift_index += 1
	if mode == "campaign" and shift_index >= TARGETS.size():
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


func tick_practice(delta: float) -> void:
	if phase != "playing" or not is_finite(delta) or delta <= 0.0: return
	var remaining: float = minf(delta, 30.0)
	while remaining > 0.0000001:
		var step: float = minf(remaining, 0.1)
		_step(step, true)
		remaining -= step
	if orders.is_empty(): _spawn_order()


func _step(step: float, practice: bool = false) -> void:
	if not practice: time_left = maxf(0.0, time_left - step)
	_machine_elapsed += step
	_refill_age = minf(10.0, _refill_age + step)
	_service_age = minf(10.0, _service_age + step)
	fire_recovery = maxf(0.0, fire_recovery - step)
	foam_time = maxf(0.0, foam_time - step)
	for boost in active_boosts.keys():
		active_boosts[boost] = maxf(0.0, float(active_boosts[boost]) - step)
		if float(active_boosts[boost]) <= 0.000001: active_boosts.erase(boost)
	var desired: float = [90.0, 135.0, 175.0, 210.0, 240.0][heat_setting]
	if level("thermostat") > 0 and heat_setting == 3: desired = 190.0
	var thermal_rate: float = 0.06 if desired < temperature else 0.035
	temperature = clampf(temperature + (desired - temperature) * thermal_rate * step, 20.0, 260.0)
	if active_boosts.has("coolant"):
		temperature = minf(175.0, temperature)
		overheated = false
	if fire_active:
		overheated = true
	elif not overheated and temperature >= 205.0:
		overheated = true
		events.append({"type": "overheat", "temperature": temperature})
	elif overheated and temperature <= 190.0:
		overheated = false
		events.append({"type": "cooled", "temperature": temperature})
	_update_fire(step, desired)
	if _can_produce():
		var interval: float = clampf(1.5 - (temperature - 145.0) * 0.01, 0.85, 1.5) * pow(0.85, float(level("fast_motor")))
		_production_clock += step
		while _production_clock >= interval and _can_produce():
			_production_clock -= interval
			batter -= 1
			production_count += 1
			var delivery_id: int = _next_delivery_id
			_next_delivery_id += 1
			_pending_deliveries.append(delivery_id)
			temperature = minf(260.0, temperature + 0.12)
			events.append({"type": "production", "supply": supply, "batter": batter, "count": production_count, "delivery_id": delivery_id, "delivery_epoch": delivery_epoch})
			if not external_delivery: settle_delivery(delivery_id, true, delivery_epoch)
			if production_count >= _next_jam_at and _machine_elapsed >= 22.0:
				jammed = true
				events.append({"type": "jam", "count": production_count})
	_refresh_alerts()
	if practice: return
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
			var interval: float = float(_rules["arrival"])
			if bool(_rules.get("waves", false)):
				interval = (6.5 if _orders_created % 4 < 2 else 10.5) * (1.15 if difficulty == "relaxed" else 1.0)
			_arrival_clock += interval + _rng.randf_range(-0.75, 0.75)
		else:
			_arrival_clock = 2.5


func _can_produce() -> bool:
	return phase == "playing" and not jammed and not overheated and not fire_active and fire_recovery <= 0.0 and temperature >= 145.0 and batter > 0 and not (refill_progress > 0.0 and _refill_age <= 0.25) and not (jam_progress > 0.0 and _service_age <= 0.25)


func _update_fire(step: float, desired_temperature: float) -> void:
	if fire_active: return
	var previous_danger: float = fire_danger
	if temperature >= 205.0 and desired_temperature >= 205.0 and fire_recovery <= 0.0:
		fire_danger = minf(1.0, fire_danger + step / FIRE_BUILDUP_SECONDS)
	else:
		# Turning the heater down to a safe setting helps immediately, even while
		# the oil is still cooling. Warning smoke therefore leaves time to react.
		fire_danger = maxf(0.0, fire_danger - step / 5.0)
	if previous_danger < 0.35 and fire_danger >= 0.35:
		events.append({"type": "fire_warning", "danger": fire_danger})
	if fire_danger >= 1.0 - 0.000001:
		fire_danger = 1.0
		fire_active = true
		overheated = true
		events.append({"type": "fire", "temperature": temperature})


func extinguish_fire() -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if not fire_active: return _fail("no_fire", "The fryer is not on fire.")
	fire_active = false
	fire_danger = 0.0
	fire_recovery = FIRE_RECOVERY_SECONDS
	foam_time = FOAM_SECONDS
	heat_setting = 0
	temperature = 175.0
	overheated = false
	_refresh_alerts()
	events.append({"type": "extinguished", "recovery": fire_recovery, "foam_time": foam_time})
	return _ok("extinguished", "Fire out! Let the fryer settle, then set the heat.", {"recovery": fire_recovery, "foam_time": foam_time})


func pending_delivery_ids() -> Array:
	# A copy prevents presentation code from changing authoritative inventory.
	return _pending_deliveries.duplicate()


func settle_delivery(delivery_id: int, kept: bool, epoch: int = -1) -> Dictionary:
	if (epoch >= 0 and epoch != delivery_epoch) or not _pending_deliveries.has(delivery_id):
		return _fail("stale_delivery", "That donut has already landed or belongs to an earlier shift.", {"kept": false, "accepted": false, "delivery_id": delivery_id})
	_pending_deliveries.erase(delivery_id)
	var accepted: bool = kept and supply < supply_capacity
	if accepted:
		supply += 1
	else:
		waste_count += 1
		_run_wasted += 1
	if phase != "playing" and not last_result.is_empty():
		last_result["wasted"] = waste_count
		last_result["total_wasted"] = _run_wasted
	var receipt: Dictionary = _ok("delivery_kept" if accepted else "delivery_wasted", "Donut landed in the tray." if accepted else "Donut spilled onto the counter and went to waste.", {"delivery_id": delivery_id, "kept": accepted, "accepted": accepted, "supply": supply, "wasted": 0 if accepted else 1, "waste_count": waste_count})
	events.append({"type": "delivery", "delivery_id": delivery_id, "delivery_epoch": delivery_epoch, "kept": accepted, "supply": supply, "waste_count": waste_count})
	return receipt


func spill_stock(count: int = 1) -> Dictionary:
	if count <= 0: return _fail("invalid_spill", "No donuts left the tray.", {"wasted": 0})
	var lost: int = mini(count, supply)
	supply -= lost
	waste_count += lost
	_run_wasted += lost
	if phase != "playing" and not last_result.is_empty():
		last_result["wasted"] = waste_count
		last_result["total_wasted"] = _run_wasted
	if lost > 0: events.append({"type": "stock_spilled", "wasted": lost, "supply": supply, "waste_count": waste_count})
	return _ok("stock_spilled", "Donuts spilled out of the tray.", {"wasted": lost, "supply": supply, "waste_count": waste_count})


func _refresh_alerts() -> void:
	jam_risk = 1.0 if jammed else clampf(float(production_count - _last_jam_production) / float(maxi(1, _next_jam_at - _last_jam_production)), 0.0, 1.0)
	heat_warning = temperature >= 195.0
	if jam_risk >= 0.72 and not jammed and not _jam_warned:
		_jam_warned = true
		events.append({"type": "jam_warning", "risk": jam_risk})


func _spawn_order() -> void:
	if orders.size() >= 3: return
	var kind: String = "bag"
	var flavor: String = "cinnamon"
	if mode == "campaign" and shift_index == 0 and _orders_created < 3:
		kind = "bucket" if _orders_created == 2 else "bag"
		flavor = "powdered" if _orders_created == 1 else "cinnamon"
	else:
		kind = "bucket" if _rng.randf() < float(_rules["bucket_chance"]) else "bag"
		flavor = "powdered" if _rng.randf() < float(_rules.get("powder_chance", 0.5)) else "cinnamon"
	var welcome: bool = level("warm_welcome") > 0 and _orders_created < 3
	var patience: float = float(_rules["patience"]) + (float(_rules.get("bucket_patience", 8.0)) if kind == "bucket" else 0.0) + float(level("calm_queue") * 7) + (12.0 if welcome else 0.0)
	var premium: float = float(_rules.get("menu_premium", 0.0)) + (float(_rules.get("powder_premium", 0.0)) if flavor == "powdered" else 0.0)
	var order: Dictionary = {"id": _next_order_id, "package": kind, "flavor": flavor, "patience": patience, "max_patience": patience, "base_price": float(PACKAGES[kind]["price"]) + premium, "menu_premium": premium, "welcome": welcome}
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
		order["patience"] = maxf(0.0, float(order["patience"]) - (1.0 if level("second_chance") > 0 else 4.0))
		events.append({"type": "wrong_order", "order_id": order["id"], "mistakes": mistakes})
		return _fail("wrong_order", "They want a %s of %s donuts. Your food is still on the counter." % [str(order["package"]), str(order["flavor"])], {"order_id": order["id"]})
	var earnings: Dictionary = get_tip_breakdown(order)
	var tip: float = float(earnings["tip"])
	var amount: float = float(earnings["amount"])
	sales = snappedf(sales + amount, 0.01)
	served += 1
	_run_served += 1
	_run_sales = snappedf(_run_sales + amount, 0.01)
	streak += 1
	_best_streak = maxi(_best_streak, streak)
	orders.pop_front()
	package_type = ""
	package_count = 0
	package_flavor = ""
	var receipt: Dictionary = _ok("served", "Order served! +$%.2f" % amount, {"amount": amount, "tip": tip, "order_id": order["id"], "streak": streak, "package": order["package"], "flavor": order["flavor"], "assisted": assisted})
	receipt.merge(earnings)
	var event: Dictionary = receipt.duplicate(true)
	event["type"] = "sale"
	events.append(event)
	return receipt


func punch_customer() -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if orders.is_empty(): return _fail("no_customer", "There is nobody at the counter.")
	var leaving: Dictionary = orders.pop_front()
	missed += 1
	_run_missed += 1
	streak = 0
	if orders.is_empty(): _arrival_clock = minf(_arrival_clock, 1.2)
	var receipt: Dictionary = _ok("customer_punched", "That customer has had enough!", {"order_id": leaving["id"], "missed": missed})
	events.append({"type": "customer_punched", "order_id": leaving["id"], "missed": missed})
	return receipt


func get_tip_breakdown(requested_order: Dictionary = {}) -> Dictionary:
	var order: Dictionary = requested_order
	if order.is_empty():
		if orders.is_empty(): return {}
		order = orders[0]
	var kind: String = str(order["package"])
	var age: float = float(order["max_patience"]) - float(order["patience"])
	var patience_tip: float = floor((6.0 if kind == "bucket" else 4.0) * clampf(float(order["patience"]) / float(order["max_patience"]), 0.0, 1.0))
	var streak_tip: float = float(mini(streak, 5)) * 0.5
	var parts: Array = [{"label": "Menu price", "amount": float(PACKAGES[kind]["price"])}]
	var premium: float = float(order.get("menu_premium", 0.0))
	if premium > 0.0: parts.append({"label": "Fairground special", "amount": premium})
	parts.append({"label": "Patience tip", "amount": patience_tip})
	if streak_tip > 0.0: parts.append({"label": "Service streak", "amount": streak_tip})
	var extras: Array = [
		["Tip jar", float(level("generous_tips"))],
		["Express service", float(level("rush_tips") * 3) if age <= 14.0 else 0.0],
		["Regulars club", float(level("loyal_customers") * 5) if (streak + 1) % 3 == 0 else 0.0],
		["Bucket special", float(level("bucket_sign") * 4) if kind == "bucket" else 0.0],
		["Bag appeal", float(level("bag_deals") * 2) if kind == "bag" else 0.0],
		["Warm welcome", 2.0 if bool(order.get("welcome", false)) else 0.0],
		["Crowd pleaser", float(level("crowd_pleaser") * 3) if orders.size() >= 3 else 0.0],
		["Sunset rush", float(_rules.get("rush_tip", 0.0)) if age <= 14.0 else 0.0],
		["Stage-break crowd", float(_rules.get("crowd_tip", 0.0)) if orders.size() >= 3 else 0.0],
		["Fireworks tip", float(_rules.get("closing_tip", 0.0)) if time_left <= 30.0 else 0.0],
	]
	var upgrade_tip: float = 0.0
	for extra in extras:
		if float(extra[1]) > 0.0:
			parts.append({"label": str(extra[0]), "amount": float(extra[1])})
			upgrade_tip += float(extra[1])
	var tip: float = patience_tip + streak_tip + upgrade_tip
	return {"base_price": float(order["base_price"]), "menu_premium": premium, "patience_tip": patience_tip, "streak_tip": streak_tip, "upgrade_tip": upgrade_tip, "tip": tip, "amount": snappedf(float(order["base_price"]) + tip, 0.01), "tip_breakdown": parts, "assisted": assisted}


func discard() -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	var recoverable: int = scoop_count + (package_count if package_flavor.is_empty() else 0)
	var returned: int = mini(recoverable, supply_capacity - supply)
	var wasted: int = scoop_count + package_count - returned
	waste_count += wasted
	_run_wasted += wasted
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
	if not jammed and jam_risk < 0.5 and jam_progress <= 0.0: return _fail("not_jammed", "The feeder is healthy. Preventive service is available above 50% feed risk.")
	if not is_finite(delta) or delta <= 0.0 or delta > 1.0: return _fail("invalid_time", "Keep holding the repair control.")
	_service_age = 0.0
	var was_jammed: bool = jammed
	var duration: float = (1.8 if jammed else 1.2) * (0.65 if level("easy_repair") > 0 else 1.0)
	jam_progress = minf(1.0, jam_progress + delta / duration)
	if jam_progress >= 0.999999:
		jammed = false
		jam_progress = 0.0
		_reset_feed_risk()
		events.append({"type": "repair", "preventive": not was_jammed})
		return _ok("repaired" if was_jammed else "serviced", "Feeder cleared. Donuts are moving again." if was_jammed else "Feeder serviced before it jammed.")
	return _ok("repairing", "Clearing the feeder...", {"progress": jam_progress})


func _reset_feed_risk(extra_grace: int = 0) -> void:
	_last_jam_production = production_count
	_next_jam_at = production_count + int(_rules.get("jam_interval", 27)) + _rng.randi_range(-2, 2) + level("steady_feed") * 10 + extra_grace
	_service_age = 10.0
	_jam_warned = false
	_refresh_alerts()


func refill(delta: float) -> Dictionary:
	if phase != "playing": return _fail("closed", "The stand is closed.")
	if batter >= batter_capacity(): return _fail("batter_full", "The hopper is already full.")
	if not is_finite(delta) or delta <= 0.0 or delta > 1.0: return _fail("invalid_time", "Keep holding the batter refill.")
	_refill_age = 0.0
	refill_progress = minf(1.0, refill_progress + delta / (1.2 if level("quick_refill") > 0 else 2.0))
	if refill_progress >= 0.999999:
		batter = batter_capacity()
		refill_progress = 0.0
		_refill_age = 10.0
		events.append({"type": "refill", "batter": batter})
		return _ok("refilled", "Fresh batter loaded.", {"batter": batter})
	return _ok("refilling", "Pouring fresh batter...", {"progress": refill_progress})


func apply_boost(id: String) -> Dictionary:
	if not ENABLE_FUTURE_BOOSTS: return _fail("unavailable", "Boosts are not part of this version.")
	if phase != "playing": return _fail("closed", "Boosts can be used while the stand is open.")
	match id:
		"coolant":
			if active_boosts.has("coolant"): return _fail("already_active", "Coolant is already protecting the fryer.")
			temperature = 175.0
			overheated = false
			active_boosts["coolant"] = 30.0
		"repair_kit":
			if not jammed: return _fail("not_jammed", "Save the repair kit until the feeder jams.")
			jammed = false
			jam_progress = 0.0
			_reset_feed_risk(10)
		"patience":
			if orders.is_empty(): return _fail("no_customer", "There are no waiting customers.")
			var changed: bool = false
			for order in orders:
				var cap: float = float(order.get("boost_patience_cap", minf(180.0, float(order["max_patience"]) + 15.0)))
				var refreshed: float = minf(cap, float(order["patience"]) + 15.0)
				if refreshed > float(order["patience"]) + 0.001:
					order["boost_patience_cap"] = cap
					order["patience"] = refreshed
					order["max_patience"] = maxf(float(order["max_patience"]), refreshed)
					changed = true
			if not changed: return _fail("already_full", "The queue already has its maximum patience.")
		_:
			return _fail("unknown_boost", "That boost is not available.")
	assisted = true
	_refresh_alerts()
	var result: Dictionary = _ok("boost_applied", {"coolant": "Coolant protects the fryer for 30 seconds.", "repair_kit": "Jam cleared, with ten extra donuts of feed grace.", "patience": "Waiting customers gained up to 15 seconds."}[id], {"id": id, "assisted": true, "duration": 30.0 if id == "coolant" else 0.0})
	events.append({"type": "boost_applied", "id": id, "assisted": true, "duration": result["duration"]})
	return result


func finish_shift() -> void:
	if phase != "playing": return
	var cleared: bool = sales + 0.001 >= float(target)
	var earned: int = 8 + served * 3 + int(sales / 45.0) if cleared else 0
	credits += earned
	phase = ("won" if mode == "campaign" and shift_index == TARGETS.size() - 1 else "shop") if cleared else "lost"
	last_result = {"cleared": cleared, "shift": shift_index + 1, "sales": sales, "target": target, "served": served, "missed": missed, "mistakes": mistakes, "wasted": waste_count, "total_wasted": _run_wasted, "credits_earned": earned, "total_served": _run_served, "total_missed": _run_missed, "total_sales": _run_sales, "best_streak": _best_streak, "assisted": assisted, "difficulty": difficulty, "mode": mode}
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
		if level(str(id)) >= int(UPGRADES[id]["max_level"]): continue
		if UPGRADES[id].has("requires") and level(str(UPGRADES[id]["requires"])) == 0: continue
		eligible.append(id)
	# Both throughput and earnings are available in every draft. The third card
	# can support a maintenance, patience or storage build without an income drought.
	for id in ["wide_scoop", "deep_scoop", "fast_motor", "calm_queue", "generous_tips"]:
		if eligible.has(id):
			_offers.append(id)
			eligible.erase(id)
			break
	var earnings: Array = []
	var affordable_earnings: Array = []
	var budget: int = credits - (_upgrade_cost(str(_offers[0])) if not _offers.is_empty() else 0)
	for id in ["generous_tips", "rush_tips", "loyal_customers", "bucket_sign", "bag_deals"]:
		if not eligible.has(id): continue
		earnings.append(id)
		if _upgrade_cost(id) <= budget: affordable_earnings.append(id)
	if not earnings.is_empty():
		var candidates: Array = affordable_earnings if not affordable_earnings.is_empty() else earnings
		var income_id: String = str(candidates[_rng.randi_range(0, candidates.size() - 1)])
		_offers.append(income_id)
		eligible.erase(income_id)
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
	if level("deep_scoop") > 0: return 6
	return 4 if level("wide_scoop") > 0 else 3


func batter_capacity() -> int:
	return 72 + level("large_hopper") * 30


func production_status() -> String:
	if phase != "playing": return "Stand closed"
	if fire_active: return "FRYER FIRE - use extinguisher"
	if fire_recovery > 0.0: return "Fryer settling after fire"
	if jammed: return "JAMMED - hold repair"
	if overheated: return "TOO HOT - lower heat"
	if temperature < 145.0: return "Warming up - raise heat"
	if batter <= 0: return "OUT OF BATTER - hold refill"
	if refill_progress > 0.0 and _refill_age <= 0.25: return "Refilling batter"
	if jam_progress > 0.0 and _service_age <= 0.25: return "Servicing feeder"
	if supply >= supply_capacity: return "TRAY FULL - donuts will overflow"
	return "Making donuts"


func get_stats() -> Dictionary:
	return {"scoop_capacity": scoop_capacity(), "batter_capacity": batter_capacity(), "supply_capacity": supply_capacity, "production_count": production_count, "waste_count": waste_count, "total_wasted": _run_wasted, "pending_deliveries": _pending_deliveries.size(), "total_served": _run_served, "total_missed": _run_missed, "total_sales": _run_sales, "best_streak": _best_streak, "assisted": assisted, "difficulty": difficulty, "mode": mode, "shift_duration": shift_duration, "repair_duration": 1.8 * (0.65 if level("easy_repair") > 0 else 1.0), "service_duration": 1.2 * (0.65 if level("easy_repair") > 0 else 1.0), "refill_duration": 1.2 if level("quick_refill") > 0 else 2.0, "jam_risk": jam_risk, "heat_warning": heat_warning, "fire_active": fire_active, "fire_danger": fire_danger, "fire_recovery": fire_recovery, "foam_time": foam_time}


func total_shifts() -> int:
	return TARGETS.size() if mode == "campaign" else 0


func get_campaign_info() -> Dictionary:
	var result: Dictionary = _rules.duplicate(true)
	result["name"] = shift_name
	result["description"] = shift_description
	result["target"] = target
	result["duration"] = shift_duration
	result["arrival_interval"] = float(_rules.get("arrival", 15.0))
	result["display_round"] = shift_index + 1
	result["endless"] = mode == "endless"
	result["total_shifts"] = total_shifts()
	result["assisted"] = assisted
	return result


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
	last_save_error = ""
	if data.get("version") == 1:
		data = _migrate_v1(data)
		if data.is_empty():
			last_save_error = "This older save is invalid or already finished. Start a new fairground run."
			return false
	if data.get("version") == 2: data = _migrate_v2(data)
	if data.get("version") == 3: data = _migrate_v3(data)
	if not _valid_save(data):
		last_save_error = "This save is damaged or from an unsupported version. Start a new run."
		return false
	var previous_next_id: int = _next_delivery_id
	for key in _saved_keys(): set(key, data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key])
	_next_delivery_id = maxi(previous_next_id, _next_delivery_id)
	delivery_epoch += 1
	for index in range(_pending_deliveries.size()): _pending_deliveries[index] = int(_pending_deliveries[index])
	for order in orders:
		order["id"] = int(order["id"])
		order["patience"] = float(order["patience"])
		order["max_patience"] = float(order["max_patience"])
		order["base_price"] = float(order["base_price"])
	for id in owned: owned[id] = int(owned[id])
	for key in ["shift", "target", "served", "missed", "mistakes", "credits_earned", "total_served", "total_missed", "best_streak", "wasted", "total_wasted"]:
		if last_result.has(key): last_result[key] = int(last_result[key])
	for key in ["sales", "total_sales"]:
		if last_result.has(key): last_result[key] = float(last_result[key])
	_rules = Content.shift_info(shift_index, difficulty, mode)
	if _legacy_shift: _rules = _legacy_rules(shift_index)
	seed_value = int(str(data["seed_value"]))
	_rng.seed = seed_value
	_rng.state = int(str(data["rng_state"]))
	events = []
	return true


func _saved_keys() -> Array[String]:
	return ["phase", "shift_index", "time_left", "shift_duration", "orders", "supply", "supply_capacity", "batter", "temperature", "heat_setting", "jammed", "jam_progress", "overheated", "refill_progress", "production_count", "package_type", "package_count", "package_flavor", "scoop_count", "sales", "served", "missed", "mistakes", "streak", "target", "credits", "owned", "last_result", "_production_clock", "_arrival_clock", "_next_jam_at", "_next_order_id", "_orders_created", "_refill_age", "_offers", "_offers_generated", "_run_served", "_run_missed", "_run_sales", "difficulty", "mode", "shift_name", "shift_description", "jam_risk", "heat_warning", "_best_streak", "_legacy_shift", "_machine_elapsed", "_last_jam_production", "_service_age", "_jam_warned", "assisted", "active_boosts", "waste_count", "_run_wasted", "_next_delivery_id", "_pending_deliveries", "fire_active", "fire_danger", "fire_recovery", "foam_time"]


func _legacy_rules(index: int) -> Dictionary:
	return {"name": "Saved Fairground Shift", "description": "Finish your saved shift under its original target and timing. The expanded fairground continues afterward.", "target": [110, 180, 260][index], "duration": [105.0, 110.0, 115.0][index], "arrival": [15.0, 12.0, 9.5][index], "patience": [52.0, 44.0, 37.0][index], "bucket_chance": 0.35 + float(index) * 0.1, "jam_interval": 26, "modifiers": ["Original saved-shift timing and quota"]}


func _migrate_v1(old: Dictionary) -> Dictionary:
	if not _integer_in(old.get("shift_index"), 0, 2) or not old.get("phase") is String or not str(old["phase"]) in ["ready", "playing", "shop"]: return {}
	for key in ["production_count", "_next_jam_at", "streak", "shift_duration", "time_left", "temperature"]:
		if not _number_in(old.get(key), 0.0, 100000.0): return {}
	var migrated: Dictionary = old.duplicate(true)
	var legacy: Dictionary = _legacy_rules(int(old["shift_index"]))
	var last_production: int = clampi(int(old["_next_jam_at"]) - 26, 0, int(old["production_count"]))
	migrated.merge({"version": 2, "difficulty": "normal", "mode": "campaign", "shift_name": legacy["name"], "shift_description": legacy["description"], "jam_risk": clampf(float(int(old["production_count"]) - last_production) / float(maxi(1, int(old["_next_jam_at"]) - last_production)), 0.0, 1.0), "heat_warning": float(old["temperature"]) >= 195.0, "_best_streak": int(old["streak"]), "_legacy_shift": true, "_machine_elapsed": float(old["shift_duration"]) - float(old["time_left"]), "_last_jam_production": last_production, "_service_age": 10.0, "_jam_warned": false, "assisted": false, "active_boosts": {}}, true)
	return migrated


func _migrate_v2(old: Dictionary) -> Dictionary:
	var migrated: Dictionary = old.duplicate(true)
	# Previously production already added every cooked donut to supply. There is
	# no uncredited physical food to reconstruct from either older save format.
	migrated.merge({"version": 3, "waste_count": 0, "_run_wasted": 0, "_next_delivery_id": 1, "_pending_deliveries": []}, true)
	return migrated


func _migrate_v3(old: Dictionary) -> Dictionary:
	var migrated: Dictionary = old.duplicate(true)
	# Older overheating remains recoverable; loading an old save never invents
	# a fire or spends food, money, remaining time or pending delivery credits.
	migrated.merge({"version": 4, "fire_active": false, "fire_danger": 0.0, "fire_recovery": 0.0, "foam_time": 0.0}, true)
	return migrated


func _valid_save(data: Dictionary) -> bool:
	if not _integer_in(data.get("version"), SAVE_VERSION, SAVE_VERSION): return false
	for key in _saved_keys():
		if not data.has(key): return false
	if not data.get("phase") is String or not str(data["phase"]) in ["ready", "playing", "shop", "won", "lost"]: return false
	if not data.get("difficulty") is String or not str(data["difficulty"]) in ["normal", "relaxed"]: return false
	if not data.get("mode") is String or not str(data["mode"]) in ["campaign", "endless"]: return false
	if not _integer_in(data.get("shift_index"), 0, 5 if str(data["mode"]) == "campaign" else 999): return false
	if not data.get("shift_name") is String or not data.get("shift_description") is String: return false
	if not _valid_int64_text(data.get("seed_value")) or not _valid_int64_text(data.get("rng_state")): return false
	for spec in [["time_left", 0, 180], ["shift_duration", 100, 180], ["temperature", 20, 260], ["jam_progress", 0, 1], ["refill_progress", 0, 1], ["sales", 0, 1000000000], ["_production_clock", 0, 3], ["_arrival_clock", -1, 30], ["_refill_age", 0, 10], ["_service_age", 0, 10], ["_machine_elapsed", 0, 10000000], ["jam_risk", 0, 1], ["_run_sales", 0, 10000000000]]:
		if not _number_in(data.get(spec[0]), float(spec[1]), float(spec[2])): return false
	for spec in [["fire_danger", 0.0, 1.0], ["fire_recovery", 0.0, FIRE_RECOVERY_SECONDS], ["foam_time", 0.0, FOAM_SECONDS]]:
		if not _number_in(data.get(spec[0]), float(spec[1]), float(spec[2])): return false
	for spec in [["supply", 0, 60], ["supply_capacity", 36, 60], ["batter", 0, 132], ["heat_setting", 0, 4], ["production_count", 0, 100000], ["package_count", 0, 12], ["scoop_count", 0, 6], ["served", 0, 100000], ["missed", 0, 100000], ["mistakes", 0, 100000], ["streak", 0, 100000], ["credits", 0, 1000000], ["_next_jam_at", 1, 100000], ["_next_order_id", 1, 100000], ["_orders_created", 0, 100000], ["_run_served", 0, 100000], ["_run_missed", 0, 100000], ["_last_jam_production", 0, 100000], ["_best_streak", 0, 100000], ["waste_count", 0, 1000000], ["_run_wasted", 0, 100000000], ["_next_delivery_id", 1, 1000000000]]:
		if not _integer_in(data.get(spec[0]), int(spec[1]), int(spec[2])): return false
	if int(data["_run_wasted"]) < int(data["waste_count"]): return false
	if not data["_pending_deliveries"] is Array or data["_pending_deliveries"].size() > mini(64, int(data["production_count"])): return false
	var delivery_ids: Dictionary = {}
	for id in data["_pending_deliveries"]:
		if not _integer_in(id, 1, int(data["_next_delivery_id"]) - 1) or delivery_ids.has(int(id)): return false
		delivery_ids[int(id)] = true
	for key in ["jammed", "overheated", "fire_active", "_offers_generated", "heat_warning", "_legacy_shift", "_jam_warned", "assisted"]:
		if not data[key] is bool: return false
	if bool(data["fire_active"]) and (not bool(data["overheated"]) or float(data["fire_danger"]) != 1.0 or float(data["fire_recovery"]) > 0.0): return false
	if not bool(data["fire_active"]) and float(data["fire_danger"]) >= 1.0: return false
	if float(data["fire_recovery"]) > float(data["foam_time"]): return false
	if bool(data["_legacy_shift"]) and (str(data["mode"]) != "campaign" or int(data["shift_index"]) > 2): return false
	var definition: Dictionary = _legacy_rules(int(data["shift_index"])) if bool(data["_legacy_shift"]) else Content.shift_info(int(data["shift_index"]), str(data["difficulty"]), str(data["mode"]))
	if not _integer_in(data.get("target"), int(definition["target"]), int(definition["target"])): return false
	if float(data["shift_duration"]) != float(definition["duration"]) or float(data["time_left"]) > float(data["shift_duration"]): return false
	if not data["active_boosts"] is Dictionary or (not ENABLE_FUTURE_BOOSTS and (bool(data["assisted"]) or not data["active_boosts"].is_empty())): return false
	if not data["owned"] is Dictionary or not data["last_result"] is Dictionary: return false
	for id in data["owned"]:
		if not UPGRADES.has(id) or not _integer_in(data["owned"][id], 1, int(UPGRADES[id]["max_level"])): return false
		if UPGRADES[id].has("requires") and int(data["owned"].get(UPGRADES[id]["requires"], 0)) <= 0: return false
	if int(data["supply_capacity"]) != 36 + int(data["owned"].get("extra_tray", 0)) * 12 or int(data["supply"]) > int(data["supply_capacity"]): return false
	if int(data["batter"]) > 72 + int(data["owned"].get("large_hopper", 0)) * 30: return false
	if int(data["scoop_count"]) > (6 if int(data["owned"].get("deep_scoop", 0)) > 0 else (4 if int(data["owned"].get("wide_scoop", 0)) > 0 else 3)): return false
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
		if not _number_in(order.get("max_patience"), 1, 180) or not _number_in(order.get("patience"), 0, float(order["max_patience"])): return false
		if not _number_in(order.get("base_price"), 1, 1000): return false
		if order.has("menu_premium") and not _number_in(order["menu_premium"], 0, 20): return false
		if order.has("welcome") and not order["welcome"] is bool: return false
	if not data["_offers"] is Array or data["_offers"].size() > 3: return false
	var offers_seen: Dictionary = {}
	for id in data["_offers"]:
		if not id is String or not UPGRADES.has(id) or offers_seen.has(id): return false
		if int(data["owned"].get(id, 0)) >= int(UPGRADES[id]["max_level"]): return false
		if UPGRADES[id].has("requires") and int(data["owned"].get(UPGRADES[id]["requires"], 0)) <= 0: return false
		offers_seen[id] = true
	var result: Dictionary = data["last_result"]
	if not result.is_empty():
		if not result.get("cleared") is bool: return false
		if not _integer_in(result.get("shift"), 1, 1000): return false
		if not _integer_in(result.get("target"), 1, 1000000000): return false
		for key in ["served", "missed", "mistakes", "credits_earned", "total_served", "total_missed"]:
			if not _integer_in(result.get(key), 0, 1000000): return false
		for key in ["sales", "total_sales"]:
			if not _number_in(result.get(key), 0.0, 10000000.0): return false
		for key in ["wasted", "total_wasted"]:
			if result.has(key) and not _integer_in(result[key], 0, 100000000): return false
		if result.has("best_streak") and not _integer_in(result["best_streak"], 0, 100000): return false
		if result.has("assisted") and not result["assisted"] is bool: return false
		if result.has("difficulty") and not result["difficulty"] in ["normal", "relaxed"]: return false
		if result.has("mode") and not result["mode"] in ["campaign", "endless"]: return false
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
