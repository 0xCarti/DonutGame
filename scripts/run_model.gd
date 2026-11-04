extends RefCounted
## Deterministic gameplay model. No nodes, drawing, sound, or real-time reads
## after new_run(); the controller only supplies elapsed time and player actions.

const UpgradeData = preload("res://scripts/upgrades.gd")
const SAVE_VERSION: int = 1
const BATCH_SIZE: int = 6
const TRAY_CAPACITY: int = 6
const ACTIVE_CAPACITY: int = 18
const BASE_SHIFT_TIME: float = 65.0
const TARGETS: Array[float] = [180.0, 340.0, 560.0, 850.0, 1250.0, 1800.0]
const RECIPE_ORDER: Array[String] = ["cinnamon", "powdered", "cocoa"]
const RECIPES: Dictionary = {
	"cinnamon": {"label": "Cinnamon", "name": "Cinnamon", "base_value": 4.0, "value": 4.0, "color": Color("d97d35")},
	"powdered": {"label": "Powdered", "name": "Powdered", "base_value": 4.5, "value": 4.5, "color": Color("f4e9d2")},
	"cocoa": {"label": "Cocoa", "name": "Cocoa", "base_value": 5.0, "value": 5.0, "color": Color("713c2a")},
}

var phase: String = "ready"
var shift_index: int = 0
var shift_time: float = BASE_SHIFT_TIME
var time_left: float = BASE_SHIFT_TIME
var target: float = TARGETS[0]
var sales: float = 0.0
var credits: int = 24
var batter: int = 120
var selected_recipe: String = "cinnamon"
var selected_tray: int = 0
var trays: Array = [[], [], []]
var active: Array = []
var owned: Dictionary = {}
var cooldown: float = 0.0
var seed_value: int = 1
var last_result: Dictionary = {}
var events: Array = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_id: int = 1
var _batch_count: int = 0
var _donuts_created: int = 0
var _sales_count: int = 0
var _full_sales_count: int = 0
var _last_sale_time: float = -1000.0
var _streak: int = 0
var _last_full_amount: float = 0.0
var _offers: Array = []
var _offers_generated: bool = false


func _init() -> void:
	new_run(1)


func new_run(run_seed: int = 0) -> void:
	seed_value = run_seed
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec() & 0x7fffffff)
		if seed_value == 0:
			seed_value = 1
	_rng.seed = seed_value
	phase = "ready"
	shift_index = 0
	shift_time = BASE_SHIFT_TIME
	time_left = shift_time
	target = TARGETS[0]
	sales = 0.0
	credits = 24
	batter = 120
	selected_recipe = "cinnamon"
	selected_tray = 0
	trays = [[], [], []]
	active = []
	owned = {}
	cooldown = 0.0
	last_result = {}
	events = []
	_next_id = 1
	_batch_count = 0
	_donuts_created = 0
	_sales_count = 0
	_full_sales_count = 0
	_last_sale_time = -1000.0
	_streak = 0
	_last_full_amount = 0.0
	_offers = []
	_offers_generated = false


func start_shift() -> void:
	if phase != "ready" and phase != "shop":
		return
	if phase == "shop":
		shift_index += 1
	if shift_index >= TARGETS.size():
		phase = "won"
		return
	phase = "playing"
	shift_time = BASE_SHIFT_TIME + 8.0 * float(level("spare_seconds"))
	time_left = shift_time
	target = TARGETS[shift_index]
	sales = 0.0
	batter = 120 + shift_index * 12 + level("bulk_batter") * 18
	trays = [[], [], []]
	active = []
	cooldown = 0.0
	_batch_count = 0
	_sales_count = 0
	_full_sales_count = 0
	_last_sale_time = -1000.0
	_streak = 0
	_last_full_amount = 0.0
	_offers = []
	_offers_generated = false
	events.append({"type": "shift_start", "shift": shift_index, "target": target})


func tick(delta: float) -> void:
	if phase != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	var step: float = minf(delta, time_left)
	time_left = maxf(0.0, time_left - step)
	cooldown = maxf(0.0, cooldown - step)
	var cook_duration: float = 8.0 * pow(0.85, float(level("quick_cook")))
	var remaining: Array = []
	for entry in active:
		var donut: Dictionary = entry
		donut["progress"] = minf(1.0, float(donut["progress"]) + step / cook_duration)
		var tray_id: int = int(donut["tray"])
		if float(donut["progress"]) >= 1.0 and trays[tray_id].size() < TRAY_CAPACITY:
			trays[tray_id].append(donut)
			events.append({"type": "land", "id": donut["id"], "recipe": donut["recipe"], "golden": donut["golden"], "tray": tray_id})
		else:
			remaining.append(donut)
	active = remaining
	if time_left <= 0.0:
		finish_shift()


func queue_batch(recipe: String, tray: int) -> bool:
	if phase != "playing" or not RECIPES.has(recipe) or tray < 0 or tray >= 3:
		return false
	if not can_queue_batch():
		return false
	var batter_cost: int = next_batch_cost()
	batter -= batter_cost
	_batch_count += 1
	selected_recipe = recipe
	selected_tray = tray
	cooldown = maxf(0.8, 2.0 - 0.5 * float(level("turbo_feed")))
	var recipe_offset: int = RECIPE_ORDER.find(recipe)
	for index in range(BATCH_SIZE):
		var actual_recipe: String = recipe
		if level("assorted_batter") > 0 and index == 2:
			actual_recipe = RECIPE_ORDER[(recipe_offset + 1) % 3]
		elif level("assorted_batter") > 0 and index == 5:
			actual_recipe = RECIPE_ORDER[(recipe_offset + 2) % 3]
		_donuts_created += 1
		var donut: Dictionary = {"id": _next_id, "recipe": actual_recipe, "golden": level("golden_sixth") > 0 and _donuts_created % 6 == 0, "progress": -0.065 * float(index), "tray": tray}
		_next_id += 1
		active.append(donut)
		events.append({"type": "spawn", "id": donut["id"], "recipe": actual_recipe, "golden": donut["golden"], "tray": tray, "progress": donut["progress"]})
	return true


func next_batch_cost() -> int:
	return 0 if level("frugal_batter") > 0 and (_batch_count + 1) % 4 == 0 else BATCH_SIZE


func can_queue_batch() -> bool:
	return phase == "playing" and cooldown <= 0.00001 and active.size() + BATCH_SIZE <= ACTIVE_CAPACITY and batter >= next_batch_cost()


func tray_quote(index: int) -> Dictionary:
	var quote: Dictionary = {"amount": 0.0, "count": 0, "combo": "Empty tray", "multiplier": 1.0, "full": false, "golden": 0, "streak": 0}
	if index < 0 or index >= 3 or trays[index].is_empty():
		return quote
	var tray: Array = trays[index]
	var count: int = tray.size()
	var recipe_types: Dictionary = {}
	var subtotal: float = 0.0
	var golden_count: int = 0
	for donut in tray:
		var recipe: String = str(donut["recipe"])
		recipe_types[recipe] = true
		var value: float = float(RECIPES[recipe]["base_value"])
		var recipe_upgrade: String = {"cinnamon": "cinnamon_king", "powdered": "snow_day", "cocoa": "cocoa_crown"}[recipe]
		value *= 1.0 + 0.35 * float(level(recipe_upgrade))
		value *= 1.0 + 0.15 * float(level("sugar_dust"))
		if bool(donut["golden"]):
			value *= 2.5 + float(level("golden_glaze"))
			golden_count += 1
		subtotal += value
	var full: bool = count == TRAY_CAPACITY
	var multiplier: float = 1.0
	var combo: String = "Quick sale"
	var next_streak: int = 0
	if full:
		if recipe_types.size() == 1:
			multiplier = 2.0 + 0.6 * float(level("matching_bonus"))
			combo = "Perfect six"
		else:
			multiplier = 1.6 + 0.8 * float(level("variety_bonus"))
			combo = "Sweet assortment"
		multiplier *= 1.0 + 0.15 * float(level("tray_liner"))
		if _full_sales_count < 3:
			multiplier *= 1.0 + 0.4 * float(level("comeback"))
		var elapsed: float = shift_time - time_left
		next_streak = mini(_streak + 1, 5) if elapsed - _last_sale_time <= 7.0 else 0
		if level("hot_streak") > 0 and next_streak > 0:
			multiplier *= 1.0 + 0.1 * float(next_streak * level("hot_streak"))
			combo += " + Rush x%d" % (next_streak + 1)
	else:
		multiplier *= 1.0 + 0.35 * float(level("quick_sale"))
	if time_left <= 15.0 and level("closing_time") > 0:
		multiplier *= 1.0 + 0.5 * float(level("closing_time"))
		combo += " + Last call"
	var amount: float = subtotal * multiplier
	if full and (_full_sales_count + 1) % 3 == 0 and level("echo_box") > 0:
		amount += _last_full_amount * 0.35 * float(level("echo_box"))
		combo += " + Echo!"
	if golden_count > 0:
		combo += " + Golden"
	quote = {"amount": snappedf(amount, 0.01), "count": count, "combo": combo, "multiplier": multiplier, "full": full, "golden": golden_count, "streak": next_streak}
	return quote


func sell_tray(index: int) -> Dictionary:
	if phase != "playing":
		return {"amount": 0.0, "count": 0, "combo": "Stand closed"}
	var quote: Dictionary = tray_quote(index)
	if int(quote["count"]) == 0:
		return quote
	trays[index] = []
	sales = snappedf(sales + float(quote["amount"]), 0.01)
	_sales_count += 1
	if bool(quote["full"]):
		_full_sales_count += 1
		_streak = int(quote["streak"])
		_last_sale_time = shift_time - time_left
		_last_full_amount = float(quote["amount"])
	else:
		_streak = 0
		_last_sale_time = -1000.0
	var event: Dictionary = quote.duplicate(true)
	event["type"] = "sale"
	event["tray"] = index
	event["sales"] = sales
	events.append(event)
	return quote


func finish_shift() -> void:
	if phase != "playing":
		return
	var cleared: bool = sales + 0.001 >= target
	var credit_award: int = 0
	if cleared:
		credit_award = 10 + shift_index * 3 + int(floor(sales / 18.0))
		credits += credit_award
		phase = "won" if shift_index == TARGETS.size() - 1 else "shop"
	else:
		phase = "lost"
	last_result = {"cleared": cleared, "shift": shift_index + 1, "sales": sales, "target": target, "credits_earned": credit_award, "credits": credits, "full_trays": _full_sales_count, "trays_sold": _sales_count, "unsold_donuts": active.size() + trays[0].size() + trays[1].size() + trays[2].size(), "time_remaining": time_left}
	events.append({"type": "shift_end", "phase": phase, "result": last_result.duplicate(true)})
	if phase == "shop":
		_generate_offers()


func get_shop_offers() -> Array:
	if phase != "shop":
		return []
	if not _offers_generated:
		_generate_offers()
	var result: Array = []
	for id in _offers:
		result.append(UpgradeData.describe(str(id), level(str(id))))
	return result


func buy_upgrade(id: String) -> bool:
	if phase != "shop" or not _offers.has(id) or not UpgradeData.ALL.has(id):
		return false
	var data: Dictionary = UpgradeData.ALL[id]
	var current_level: int = level(id)
	if current_level >= int(data["max_level"]):
		return false
	if data.has("requires") and level(str(data["requires"])) == 0:
		return false
	var cost: int = UpgradeData.price(id, current_level)
	if credits < cost:
		return false
	credits -= cost
	owned[id] = current_level + 1
	_offers.erase(id)
	events.append({"type": "upgrade", "id": id, "name": data["name"], "level": current_level + 1, "cost": cost})
	return true


func _generate_offers() -> void:
	_offers = []
	_offers_generated = true
	var eligible: Array = []
	for id in UpgradeData.ALL.keys():
		var data: Dictionary = UpgradeData.ALL[id]
		if level(str(id)) >= int(data["max_level"]):
			continue
		if data.has("requires") and level(str(data["requires"])) == 0:
			continue
		eligible.append(id)
	# Four choices each shop. The first is always an available money multiplier;
	# an unlucky draft cannot consist entirely of supply/utility upgrades.
	var value_options: Array = []
	for id in eligible:
		if str(id) in ["sugar_dust", "matching_bonus", "tray_liner", "golden_sixth", "cinnamon_king", "snow_day", "cocoa_crown", "comeback"]:
			value_options.append(id)
	if not value_options.is_empty():
		var chosen: String = str(value_options[_rng.randi_range(0, value_options.size() - 1)])
		_offers.append(chosen)
		eligible.erase(chosen)
	while _offers.size() < 4 and not eligible.is_empty():
		var position: int = _rng.randi_range(0, eligible.size() - 1)
		_offers.append(eligible[position])
		eligible.remove_at(position)


func level(id: String) -> int:
	return int(owned.get(id, 0))


func total_shifts() -> int:
	return TARGETS.size()


func shift_number() -> int:
	return shift_index + 1


func get_stats() -> Dictionary:
	return {"cook_time": 8.0 * pow(0.85, float(level("quick_cook"))), "load_cooldown": maxf(0.8, 2.0 - 0.5 * float(level("turbo_feed"))), "tray_capacity": TRAY_CAPACITY, "active_capacity": ACTIVE_CAPACITY, "batch_size": BATCH_SIZE, "batter_per_shift": 120 + shift_index * 12 + level("bulk_batter") * 18, "matching_multiplier": 2.0 + 0.6 * float(level("matching_bonus")), "mixed_multiplier": 1.6 + 0.8 * float(level("variety_bonus")), "batches_loaded": _batch_count, "full_trays_sold": _full_sales_count}


func get_recipe_label(recipe: String) -> String:
	return str(RECIPES.get(recipe, {}).get("label", recipe.capitalize()))


func to_save() -> Dictionary:
	# RNG uses signed 64-bit state. Strings preserve every bit through JSON.
	return {"version": SAVE_VERSION, "phase": phase, "shift_index": shift_index, "shift_time": shift_time, "time_left": time_left, "target": target, "sales": sales, "credits": credits, "batter": batter, "selected_recipe": selected_recipe, "selected_tray": selected_tray, "trays": trays.duplicate(true), "active": active.duplicate(true), "owned": owned.duplicate(true), "cooldown": cooldown, "seed_value": str(seed_value), "rng_state": str(_rng.state), "last_result": last_result.duplicate(true), "next_id": _next_id, "batch_count": _batch_count, "donuts_created": _donuts_created, "sales_count": _sales_count, "full_sales_count": _full_sales_count, "last_sale_time": _last_sale_time, "streak": _streak, "last_full_amount": _last_full_amount, "offers": _offers.duplicate(), "offers_generated": _offers_generated}


func from_save(data: Dictionary) -> bool:
	# Validate all input before changing this model. A malformed save cannot
	# leave a half-restored run or inject NaNs into timers/payouts.
	if not _valid_save(data):
		return false
	phase = str(data["phase"])
	shift_index = int(data["shift_index"])
	shift_time = float(data["shift_time"])
	time_left = float(data["time_left"])
	target = TARGETS[shift_index]
	sales = float(data["sales"])
	credits = int(data["credits"])
	batter = int(data["batter"])
	selected_recipe = str(data["selected_recipe"])
	selected_tray = int(data["selected_tray"])
	trays = data["trays"].duplicate(true)
	active = data["active"].duplicate(true)
	owned = data["owned"].duplicate(true)
	cooldown = float(data["cooldown"])
	seed_value = int(str(data["seed_value"]))
	_rng.seed = seed_value
	_rng.state = int(str(data["rng_state"]))
	last_result = data["last_result"].duplicate(true)
	_next_id = int(data["next_id"])
	_batch_count = int(data["batch_count"])
	_donuts_created = int(data["donuts_created"])
	_sales_count = int(data["sales_count"])
	_full_sales_count = int(data["full_sales_count"])
	_last_sale_time = float(data["last_sale_time"])
	_streak = int(data["streak"])
	_last_full_amount = float(data["last_full_amount"])
	_offers = data["offers"].duplicate()
	_offers_generated = bool(data["offers_generated"])
	events = []
	return true


func _valid_save(data: Dictionary) -> bool:
	if not _integer_in(data.get("version"), SAVE_VERSION, SAVE_VERSION):
		return false
	if not data.get("phase") is String or not str(data["phase"]) in ["ready", "playing", "shop", "won", "lost"]:
		return false
	if not _integer_in(data.get("shift_index"), 0, TARGETS.size() - 1):
		return false
	if not _number_in(data.get("target"), 0.0, 1000000.0) or float(data["target"]) != TARGETS[int(data["shift_index"])]:
		return false
	for spec in [["shift_time", 1.0, 120.0], ["time_left", 0.0, 120.0], ["sales", 0.0, 1000000000.0], ["cooldown", 0.0, 10.0], ["last_sale_time", -1000.0, 120.0], ["last_full_amount", 0.0, 1000000000.0]]:
		if not _number_in(data.get(spec[0]), float(spec[1]), float(spec[2])):
			return false
	if float(data["time_left"]) > float(data["shift_time"]):
		return false
	for spec in [["credits", 0, 10000000], ["batter", 0, 10000], ["selected_tray", 0, 2], ["next_id", 1, 10000000], ["batch_count", 0, 100000], ["donuts_created", 0, 10000000], ["sales_count", 0, 100000], ["full_sales_count", 0, 100000], ["streak", 0, 5]]:
		if not _integer_in(data.get(spec[0]), int(spec[1]), int(spec[2])):
			return false
	if not data.get("selected_recipe") is String or not RECIPES.has(data["selected_recipe"]):
		return false
	for key in ["seed_value", "rng_state"]:
		if not _valid_int64_text(data.get(key)):
			return false
	if not data.get("owned") is Dictionary or not data.get("last_result") is Dictionary or not data.get("offers_generated") is bool:
		return false
	for id in data["owned"]:
		if not UpgradeData.ALL.has(id) or not _integer_in(data["owned"][id], 1, int(UpgradeData.ALL[id]["max_level"])):
			return false
		var prerequisite: String = str(UpgradeData.ALL[id].get("requires", ""))
		if not prerequisite.is_empty() and int(data["owned"].get(prerequisite, 0)) == 0:
			return false
	if not data.get("trays") is Array or data["trays"].size() != 3 or not data.get("active") is Array or data["active"].size() > ACTIVE_CAPACITY:
		return false
	var seen_ids: Dictionary = {}
	for index in range(3):
		if not data["trays"][index] is Array or data["trays"][index].size() > TRAY_CAPACITY:
			return false
		for donut in data["trays"][index]:
			if not _valid_donut(donut, seen_ids, int(data["next_id"])):
				return false
			if int(donut["tray"]) != index or float(donut["progress"]) != 1.0:
				return false
	for donut in data["active"]:
		if not _valid_donut(donut, seen_ids, int(data["next_id"])):
			return false
	if not data.get("offers") is Array or data["offers"].size() > 4:
		return false
	var offer_ids: Dictionary = {}
	for id in data["offers"]:
		if not id is String or not UpgradeData.ALL.has(id) or offer_ids.has(id):
			return false
		offer_ids[id] = true
	# Result data is displayed by the UI, so validate its expected fields too.
	var result: Dictionary = data["last_result"]
	if not result.is_empty():
		if not result.get("cleared") is bool:
			return false
		for key in ["sales", "target", "time_remaining"]:
			if not _number_in(result.get(key), 0.0, 1000000000.0):
				return false
		for key in ["shift", "credits_earned", "credits", "full_trays", "trays_sold", "unsold_donuts"]:
			if not _integer_in(result.get(key), 0, 10000000):
				return false
	return true


func _valid_donut(value: Variant, seen_ids: Dictionary, next_id: int) -> bool:
	if not value is Dictionary:
		return false
	if not _integer_in(value.get("id"), 1, next_id - 1) or seen_ids.has(int(value["id"])):
		return false
	if not value.get("recipe") is String or not RECIPES.has(value["recipe"]):
		return false
	if not value.get("golden") is bool or not _number_in(value.get("progress"), -1.0, 1.0) or not _integer_in(value.get("tray"), 0, 2):
		return false
	seen_ids[int(value["id"])] = true
	return true


func _number_in(value: Variant, minimum: float, maximum: float) -> bool:
	if not value is int and not value is float:
		return false
	var number: float = float(value)
	return is_finite(number) and number >= minimum and number <= maximum


func _integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	if not _number_in(value, float(minimum), float(maximum)):
		return false
	return float(value) == floor(float(value))


func _valid_int64_text(value: Variant) -> bool:
	if not value is String or not str(value).is_valid_int():
		return false
	var text: String = str(value)
	var negative: bool = text.begins_with("-")
	var digits: String = text.substr(1) if negative else text
	if digits.length() > 19:
		return false
	var boundary: String = "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() == 19 and digits.casecmp_to(boundary) > 0:
		return false
	return str(int(text)) == text
