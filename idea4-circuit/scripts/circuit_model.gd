extends RefCounted
## Deterministic company simulation. Inventory is prepaid at $1 per portion.
## Daily profit includes consumed prepaid stock and allocated prepaid booking fees;
## cash_delta adds those prepayments back, so the same ingredient is never billed twice.
## stats: total_sales/profit/sold, best_day, completed_stops, days_traded,
## stock_bought, prepaid_consumed, debt_repaid, best_minigame, season_profit/sales,
## seasons_finished. Money is rounded to cents; RNG integers are saved as strings.

const Content = preload("res://scripts/circuit_content.gd")
const CREDIT_LIMIT := 2000.0
const QUALITIES := ["budget", "standard", "premium"]
const TERMINAL_PHASES := ["season_end", "bankrupt"]
var state: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func new_run(company: String, seed_value: int = 2026) -> void:
	_rng.seed = seed_value
	state = {
		"schema": 1, "company": company.strip_edges().left(30) if not company.strip_edges().is_empty() else "Golden Hour",
		"season": 1, "day": 1, "season_length": 36, "phase": "planning",
		"cash": 2800.0, "debt": 0.0, "rep": 24.0, "fame": 0.0,
		"stock": 160, "recipe": "classic", "price": 6.0, "quality": "standard",
		"staff": [], "truck": 75.0, "fryer": 80.0,
		"truck_tier": 0, "fryer_tier": 0, "stand_tier": 0,
		"booked_id": "", "venue_day": 0, "completed": [], "relationships": {},
		"journal": [], "event": {}, "last_report": {}, "flags": {}, "achievements": [],
		"stats": {"total_sales": 0.0, "total_profit": 0.0, "total_sold": 0,
			"best_day": 0.0, "completed_stops": 0, "days_traded": 0, "stock_bought": 0,
			"prepaid_consumed": 0.0, "debt_repaid": 0.0, "best_minigame": 0.0,
			"season_profit": 0.0, "season_sales": 0.0, "seasons_finished": 0},
		"policy": {"restock": false, "service": false}, "weather": "Clear", "difficulty": "standard",
		"booked_prepaid_total": 0.0, "event_serial": 0, "seen_events": [], "records": [],
		"day_modifiers": {"demand": 0.0, "quality": 0.0, "delay": 0.0},
		"minigame_day": -1, "minigame_boost": 0.0, "season_summary": {}, "end_reason": "", "unlocked_recipes": [],
		"day_rep_start": 24.0, "day_cash_start": 2800.0, "carry_travel_modifiers": false,
		"last_outcome": {}, "active_outcomes": [],
	}
	_unlock_recipes(false)
	_sync_rng()
	_journal("The first light", "Your van, one fryer, 160 prepaid portions and $2,800. The owner can run the first fairs alone. Book a fair, buy ingredients, then open the stand.", "story")

func act(action: String, args: Dictionary = {}) -> Dictionary:
	if state.is_empty():
		return _fail("Start a company first.")
	var result: Dictionary
	if action == "decide":
		result = _decide(args)
	elif action == "dismiss_report":
		result = _dismiss_report()
	elif action == "next_season":
		result = _next_season()
	elif str(state.phase) != "planning":
		return _fail("Finish the current decision or report before managing the company.")
	else:
		match action:
			"book": result = _book(str(args.get("id", "")))
			"advance": result = _advance()
			"buy_stock": result = _buy_stock(args.get("amount", 0))
			"set_price": result = _set_price(args.get("value", 0))
			"set_recipe": result = _set_recipe(str(args.get("id", "")))
			"set_quality": result = _set_quality(str(args.get("id", "")))
			"hire": result = _hire(str(args.get("id", "")))
			"fire": result = _fire(str(args.get("id", "")))
			"train": result = _train(str(args.get("id", "")))
			"rest": result = _rest(str(args.get("id", "")))
			"service": result = _service(str(args.get("id", "")))
			"upgrade": result = _upgrade(str(args.get("id", "")))
			"loan": result = _loan(args.get("amount", 0))
			"repay": result = _repay(args.get("amount", 0))
			"set_policy": result = _set_policy(args)
			"minigame": result = _minigame(args.get("score", -1))
			"rename": result = _rename(str(args.get("name", "")))
			_: result = _fail("That action is not available.")
	if result.ok:
		_award_badges()
		_sync_rng()
	return result

func primary_action() -> Dictionary:
	match str(state.get("phase", "planning")):
		"event": return {"label": "Make a decision", "hint": str(state.event.get("title", "A moment on the circuit")), "enabled": true, "action": "decide"}
		"report": return {"label": "Continue the circuit", "hint": "Review today's trading before moving on.", "enabled": true, "action": "dismiss_report"}
		"season_end": return {"label": "Begin the next season", "hint": "Keep your company, equipment, team and town relationships.", "enabled": true, "action": "next_season"}
		"bankrupt": return {"label": "Start a new company", "hint": "This company has closed. A new run begins with fresh capital.", "enabled": true, "action": "restart"}
	if str(state.booked_id).is_empty():
		return {"label": "Choose the next fair", "hint": "Book a stop or run a roadside pop-up to rebuild cash.", "enabled": true, "action": "book"}
	var venue := _venue()
	return {"label": "Open the stand", "hint": "Day %d of %d at %s" % [int(state.venue_day) + 1, int(venue.days), str(venue.name)], "enabled": true, "action": "advance"}

func venue_offers() -> Array:
	var offers: Array = []
	for venue in Content.VENUES:
		var offer: Dictionary = venue.duplicate(true)
		var travel_cost := _travel_cost(venue)
		offer["travel_cost"] = travel_cost
		offer["total_cost"] = _money(float(venue.fee) * int(venue.days) + travel_cost)
		var reason := ""
		if str(state.phase) != "planning": reason = "Finish the current decision or report."
		elif not str(state.booked_id).is_empty(): reason = "Finish your current fair first."
		elif str(venue.id) in state.completed: reason = "Already visited this season."
		elif int(state.day) + int(venue.days) > int(state.season_length): reason = "Not enough days for travel and the full stay."
		elif float(state.rep) < float(venue.min_rep): reason = "Requires %d reputation." % int(venue.min_rep)
		elif float(state.cash) < float(offer.total_cost): reason = "Need $%.0f to book this stop." % float(offer.total_cost)
		offer["can_book"] = reason.is_empty()
		offer["reason"] = reason
		offers.append(offer)
	return offers

func equipment_options() -> Array:
	var rows: Array = []
	for id in ["truck", "fryer", "stand"]:
		var catalog: Array = _equipment_catalog(id)
		var level := int(state.get(id + "_tier", 0))
		var current: Dictionary = catalog[level]
		var maxed := level >= catalog.size() - 1
		var next: Dictionary = current if maxed else catalog[level + 1]
		rows.append({"id": id, "name": current.name, "level": level, "condition": float(state.get(id, 100)),
			"service_cost": 0.0 if id == "stand" else _service_cost(id), "next_name": "Fully upgraded" if maxed else next.name,
			"next_cost": 0.0 if maxed else float(next.cost), "description": current.description, "maxed": maxed,
			"capacity": current.capacity})
	return rows

func to_save() -> Dictionary:
	_sync_rng()
	return state.duplicate(true)

func from_save(data: Dictionary) -> bool:
	if int(data.get("schema", 0)) != 1:
		return false
	for key in ["company", "phase", "recipe", "quality", "booked_id", "rng_seed", "rng_state"]:
		if not data.get(key) is String: return false
	if not str(data.rng_seed).is_valid_int() or not str(data.rng_state).is_valid_int(): return false
	if str(data.phase) not in ["planning", "event", "report", "season_end", "bankrupt"]: return false
	if str(data.quality) not in QUALITIES or Content.find(Content.RECIPES, str(data.recipe)).is_empty(): return false
	for key in ["season", "day", "season_length", "cash", "debt", "rep", "fame", "stock", "price", "truck", "fryer", "truck_tier", "fryer_tier", "stand_tier", "venue_day", "event_serial"]:
		if not _is_number(data.get(key)): return false
		if absf(float(data[key])) > 1000000000.0: return false
	for key in ["season", "day", "season_length", "stock", "truck_tier", "fryer_tier", "stand_tier", "venue_day", "event_serial"]:
		if float(data[key]) != floorf(float(data[key])): return false
	if int(data.season) < 1 or int(data.day) < 1 or int(data.day) > 37 or int(data.season_length) != 36: return false
	if float(data.debt) < 0 or float(data.debt) > CREDIT_LIMIT or float(data.stock) < 0 or float(data.price) < 3 or float(data.price) > 14: return false
	if float(data.fame) < 0 or float(data.fame) > 10000 or int(data.venue_day) < 0 or int(data.event_serial) < 0: return false
	for key in ["rep", "truck", "fryer"]:
		if float(data[key]) < 0 or float(data[key]) > 100: return false
	for id in ["truck", "fryer", "stand"]:
		if int(data[id + "_tier"]) < 0 or int(data[id + "_tier"]) >= _equipment_catalog(id).size(): return false
	if float(data.stock) > float(Content.TRUCKS[int(data.truck_tier)].capacity): return false
	for key in ["staff", "completed", "journal", "achievements", "seen_events", "records"]:
		if not data.get(key) is Array: return false
	for key in ["relationships", "event", "last_report", "flags", "stats", "policy", "day_modifiers", "season_summary"]:
		if not data.get(key) is Dictionary: return false
	for key in ["booked_prepaid_total", "minigame_day", "minigame_boost", "day_rep_start", "day_cash_start"]:
		if not _is_number(data.get(key)) or absf(float(data[key])) > 1000000000: return false
	for key in ["restock", "service"]:
		if not data.policy.get(key) is bool: return false
	for key in ["demand", "quality", "delay"]:
		if not _is_number(data.day_modifiers.get(key)) or absf(float(data.day_modifiers[key])) > 1: return false
	if float(data.day_modifiers.delay) < 0: return false
	if str(data.get("weather", "")) not in ["Clear", "Sunny", "Showers", "Windy"]: return false
	for value in data.relationships.values():
		if not _is_number(value) or float(value) < -50 or float(value) > 100: return false
	if data.get("unlocked_recipes", []) is not Array: return false
	for id in data.get("unlocked_recipes", []):
		if not id is String or Content.find(Content.RECIPES, id).is_empty(): return false
	if data.staff.size() > int(Content.STANDS[int(data.stand_tier)].capacity): return false
	var staff_ids: Array = []
	for person in data.staff:
		if not person is Dictionary or Content.find(Content.STAFF, str(person.get("id", ""))).is_empty(): return false
		if person.id in staff_ids: return false
		staff_ids.append(person.id)
		for key in ["morale", "loyalty", "trained", "rested_day", "wage", "skill", "reliability", "kindness"]:
			if not _is_number(person.get(key)) or absf(float(person[key])) > 10000: return false
		for key in ["morale", "loyalty", "skill", "reliability", "kindness"]:
			if float(person[key]) < 0 or float(person[key]) > 100: return false
		if float(person.wage) <= 0 or float(person.trained) < 0 or float(person.trained) > 3: return false
	for key in ["total_sales", "total_profit", "total_sold", "best_day", "completed_stops", "days_traded", "stock_bought", "prepaid_consumed", "debt_repaid", "best_minigame", "season_profit", "season_sales", "seasons_finished"]:
		if not _is_number(data.stats.get(key)): return false
	if not str(data.booked_id).is_empty() and Content.find(Content.VENUES, str(data.booked_id)).is_empty(): return false
	if not str(data.booked_id).is_empty() and int(data.venue_day) >= int(Content.find(Content.VENUES, str(data.booked_id)).days): return false
	if str(data.phase) == "event":
		if data.event.is_empty() or not data.event.get("choices") is Array or data.event.choices.is_empty(): return false
		if str(data.event.get("context", "")) not in ["travel", "trading"]: return false
		if not data.event.get("instance_id") is String: return false
		if str(data.event.context) == "travel" and str(data.booked_id).is_empty(): return false
		for choice in data.event.choices:
			if not choice is Dictionary or not choice.get("label") is String or not _valid_effects(choice.get("effects", {})): return false
			if choice.has("risk"):
				if not choice.risk is Dictionary or not _is_number(choice.risk.get("chance")): return false
				if float(choice.risk.chance) < 0 or float(choice.risk.chance) > 1 or not _valid_effects(choice.risk.get("effects", {})): return false
	elif not data.event.is_empty(): return false
	if str(data.phase) == "report" and data.last_report.is_empty(): return false
	# Outcome history is optional for v0.1 saves. It is display evidence, never replayed.
	if not _valid_outcome(data.get("last_outcome", {})): return false
	if not _valid_outcomes(data.get("active_outcomes", [])): return false
	if not _valid_outcomes(data.last_report.get("event_outcomes", [])): return false
	if data.last_report.has("used_modifiers"):
		if not data.last_report.used_modifiers is Dictionary: return false
		for key in ["demand", "quality", "delay"]:
			if not _is_number(data.last_report.used_modifiers.get(key)) or absf(float(data.last_report.used_modifiers[key])) > 1: return false
	if data.last_report.has("practice_boost"):
		if not _is_number(data.last_report.practice_boost) or float(data.last_report.practice_boost) < 0 or float(data.last_report.practice_boost) > 0.2: return false
	var loaded: Dictionary = data.duplicate(true)
	state = loaded
	if not state.has("unlocked_recipes"): state.unlocked_recipes = []
	if not state.has("last_outcome"): state.last_outcome = {}
	if not state.has("active_outcomes"): state.active_outcomes = []
	# Older reports retained already-consumed modifiers until the next opening.
	if str(state.phase) in ["report", "season_end", "bankrupt"]:
		state.day_modifiers = {"demand": 0.0, "quality": 0.0, "delay": 0.0}
		state.carry_travel_modifiers = false
		state.active_outcomes = []
	_unlock_recipes(false)
	_rng.seed = int(state.rng_seed)
	_rng.state = int(state.rng_state)
	return true

func _book(id: String) -> Dictionary:
	for offer in venue_offers():
		if str(offer.id) != id: continue
		if not bool(offer.can_book): return _fail(str(offer.reason))
		state.cash = _money(float(state.cash) - float(offer.total_cost))
		state.booked_id = id
		state.venue_day = 0
		state.booked_prepaid_total = float(offer.total_cost)
		state.day_modifiers = {"demand": 0.0, "quality": 0.0, "delay": 0.0}
		state.active_outcomes = []
		_journal("Next stop: " + str(offer.name), "$%.0f prepaid: %d days of pitch fees and $%.0f travel. These costs are allocated in your daily profit reports." % [float(offer.total_cost), int(offer.days), float(offer.travel_cost)], "info", -float(offer.total_cost))
		_queue_event("travel")
		return _ok("Packed up for " + str(offer.town) + ". Make your travel decision.")
	return _fail("Choose a fair on the circuit.")

func _advance() -> Dictionary:
	if int(state.day) > int(state.season_length) or state.completed.size() >= 8:
		_end_season(false)
		return _ok("The season is complete.")
	_apply_policies()
	if not bool(state.get("carry_travel_modifiers", false)):
		state.day_modifiers = {"demand": 0.0, "quality": 0.0, "delay": 0.0}
		state.active_outcomes = []
	state.carry_travel_modifiers = false
	state.day_rep_start = float(state.rep)
	state.day_cash_start = float(state.cash)
	var weather_roll := _rng.randi_range(0, 99)
	state.weather = "Clear" if weather_roll < 45 else ("Sunny" if weather_roll < 68 else ("Showers" if weather_roll < 88 else "Windy"))
	_queue_event("trading")
	return _ok("The stand is ready. There is one decision before sales begin.")

func _queue_event(context: String) -> void:
	var candidates: Array = []
	var total_weight := 0.0
	for event in Content.EVENTS:
		if context not in event.tags or int(state.day) < int(event.get("min_day", 1)): continue
		if bool(event.get("once", false)) and str(event.id) in state.seen_events: continue
		if event.has("requires_flag") and not bool(state.flags.get(str(event.requires_flag), false)): continue
		if event.has("excludes_flag") and bool(state.flags.get(str(event.excludes_flag), false)): continue
		if event.has("max_truck") and float(state.truck) > float(event.max_truck): continue
		if event.has("max_fryer") and float(state.fryer) > float(event.max_fryer): continue
		if bool(event.get("requires_staff", false)) and state.staff.is_empty(): continue
		candidates.append(event)
		total_weight += maxf(0.01, float(event.get("weight", 1)))
	var selected: Dictionary = {}
	if not candidates.is_empty():
		var roll := _rng.randf() * total_weight
		for candidate in candidates:
			roll -= maxf(0.01, float(candidate.get("weight", 1)))
			if roll <= 0:
				selected = candidate.duplicate(true)
				break
		if selected.is_empty(): selected = candidates.back().duplicate(true)
	else:
		selected = {"id": "quiet_" + context, "title": "A clear stretch of road" if context == "travel" else "The first customers arrive",
			"body": "A quiet moment to take a breath and focus on the company.", "tags": [context], "weight": 1.0, "min_day": 1, "once": false,
			"choices": [{"label": "Take it steady", "detail": "Keep the day simple.", "result": "Steady work keeps the circuit moving.", "effects": {}}]}
	state.event_serial = int(state.event_serial) + 1
	selected["context"] = context
	selected["instance_id"] = "%d:%d:%d:%s" % [int(state.season), int(state.day), int(state.event_serial), str(selected.id)]
	state.event = selected
	state.phase = "event"

func _decide(args: Dictionary) -> Dictionary:
	if str(state.phase) != "event" or state.event.is_empty(): return _fail("There is no decision waiting.")
	var raw = args.get("choice", -1)
	if not _is_number(raw) or float(raw) != floorf(float(raw)): return _fail("Choose one of the available responses.")
	var index := int(raw)
	if index < 0 or index >= state.event.choices.size(): return _fail("Choose one of the available responses.")
	var event: Dictionary = state.event.duplicate(true)
	var choice: Dictionary = event.choices[index]
	var effects: Dictionary = choice.get("effects", {})
	var certain_cost := maxf(0.0, -float(effects.get("cash", 0)))
	var risk_cost := 0.0
	var stock_cost := maxi(0, -int(effects.get("stock", 0)))
	if choice.has("risk"):
		risk_cost = maxf(0.0, -float(choice.risk.get("effects", {}).get("cash", 0)))
		stock_cost += maxi(0, -int(choice.risk.get("effects", {}).get("stock", 0)))
	if certain_cost + risk_cost > maxf(0.0, float(state.cash)):
		return _fail("That response needs $%.0f available, including its disclosed financial risk." % (certain_cost + risk_cost))
	if stock_cost > int(state.stock):
		return _fail("That response needs %d stocked portions, including its disclosed risk." % stock_cost)
	var event_cash_before := float(state.cash)
	var recorded: Array = _apply_effects(effects)
	var result_text := str(choice.get("result", "The company moves forward."))
	var risk_happened := false
	if choice.has("risk") and _rng.randf() < clampf(float(choice.risk.get("chance", 0)), 0, 1):
		risk_happened = true
		recorded.append_array(_apply_effects(choice.risk.get("effects", {}), "risk"))
		result_text += " " + str(choice.risk.get("summary", "The risk did not go your way."))
	state.last_outcome = {"instance_id": str(event.instance_id), "event_id": str(event.id),
		"title": str(event.title), "choice_label": str(choice.label), "result": result_text,
		"context": str(event.context), "day": int(state.day), "season": int(state.season),
		"risk_chance": float(choice.get("risk", {}).get("chance", -1)), "risk_happened": risk_happened,
		"effects": recorded, "consumed": false, "consumed_day": -1}
	state.active_outcomes.append(state.last_outcome.duplicate(true))
	if bool(event.get("once", false)) and str(event.id) not in state.seen_events:
		state.seen_events.append(str(event.id))
	_journal(str(event.title), result_text, "story")
	state.event = {}
	if str(event.context) == "travel":
		state.booked_prepaid_total = _money(float(state.booked_prepaid_total) - (float(state.cash) - event_cash_before))
		state.carry_travel_modifiers = true
		var venue := _venue()
		var wear := maxf(2.0, float(venue.get("distance", 25)) / (23.0 + int(state.truck_tier) * 8.0))
		state.truck = clampf(float(state.truck) - wear, 0, 100)
		state.day = int(state.day) + 1
		state.phase = "planning"
		_journal("Arrived in " + str(venue.get("town", "town")), "Travel used one day. Prepare your stock, menu and team before opening.", "info")
	else:
		_trade_day(result_text)
	return _ok(result_text)

func _apply_effects(effects: Dictionary, source: String = "certain") -> Array:
	var recorded: Array = []
	for key in effects:
		var value = effects[key]
		var before := _effect_value(str(key))
		var members: Array = []
		if str(key) in ["morale", "loyalty"]:
			for person in state.staff:
				members.append({"id": str(person.id), "name": str(person.name), "before": float(person[key])})
		match str(key):
			"cash": state.cash = _money(float(state.cash) + float(value))
			"rep": state.rep = clampf(float(state.rep) + float(value), 0, 100)
			"fame": state.fame = clampf(float(state.fame) + float(value), 0, 10000)
			"stock": state.stock = clampi(int(state.stock) + int(value), 0, _stock_capacity())
			"truck", "fryer": state[key] = clampf(float(state[key]) + float(value), 0, 100)
			"morale", "loyalty":
				for person in state.staff: person[key] = clampf(float(person[key]) + float(value), 0, 100)
			"relationship":
				var town := str(_venue().get("town", "The roadside"))
				state.relationships[town] = clampf(float(state.relationships.get(town, 0)) + float(value), -50, 100)
			"demand", "quality": state.day_modifiers[key] = clampf(float(state.day_modifiers.get(key, 0)) + float(value), -0.8, 1.0)
			"delay": state.day_modifiers.delay = clampf(float(state.day_modifiers.get("delay", 0)) + float(value), 0, 0.85)
			"flag": state.flags[str(value)] = true
			"clear_flag": state.flags.erase(str(value))
		if value is int or value is float:
			var after := _effect_value(str(key))
			for i in range(members.size()):
				members[i]["after"] = float(state.staff[i][key])
				members[i]["value"] = snappedf(float(members[i].after) - float(members[i].before), 0.000001)
			recorded.append({"key": str(key), "requested": float(value), "before": before, "after": after,
				"value": snappedf(after - before, 0.000001), "source": source, "members": members,
				"town": str(_venue().get("town", "The roadside")) if str(key) == "relationship" else ""})
	# JSON saves sort dictionary keys. Keep evidence ordering stable across reloads.
	recorded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.key) < str(b.key))
	return recorded

func _effect_value(key: String) -> float:
	if key in ["morale", "loyalty"]:
		var total := 0.0
		for person in state.staff: total += float(person[key])
		return total / state.staff.size() if not state.staff.is_empty() else 0.0
	if key == "relationship": return float(state.relationships.get(str(_venue().get("town", "The roadside")), 0))
	if key in ["demand", "quality", "delay"]: return float(state.day_modifiers.get(key, 0))
	return float(state.get(key, 0))

func _trade_day(event_result: String) -> void:
	var venue := _venue()
	var roadside := venue.is_empty()
	var recipe: Dictionary = Content.find(Content.RECIPES, str(state.recipe))
	var town := str(venue.get("town", "The roadside"))
	var weather_factor := {"Clear": 1.0, "Sunny": 1.12, "Showers": 0.76, "Windy": 0.87}
	var quality_appeal := -0.12 if str(state.quality) == "budget" else (0.15 if str(state.quality) == "premium" else 0.0)
	var premium_cost := 0.85 if str(state.quality) == "premium" else 0.0
	var price_factor := clampf(1.0 - (float(state.price) - 6.0) * 0.12, 0.12, 1.45)
	var reputation_factor := 0.72 + float(state.rep) / 160.0
	var relationship := float(state.relationships.get(town, 0))
	var taste_bonus := 0.0
	for tag in recipe.get("tags", []):
		if tag in venue.get("tags", []): taste_bonus = 0.1; break
	var event_quality := float(state.day_modifiers.quality)
	var minigame_bonus := float(state.minigame_boost) if int(state.minigame_day) == int(state.day) else 0.0
	# A roadside pitch is a recovery option. Its small audience keeps investing in
	# proper fairs more rewarding than spending every season on the free route.
	var demand_base := float(venue.get("demand", 40))
	var appeal := 1.0 + float(recipe.appeal) / 100.0 + quality_appeal + taste_bonus + relationship / 250.0 + int(state.stand_tier) * 0.06 + float(state.day_modifiers.demand) + event_quality * 0.4 + minigame_bonus
	var demand := maxi(0, int(round(demand_base * float(weather_factor[state.weather]) * price_factor * reputation_factor * maxf(0.15, appeal) * _rng.randf_range(0.9, 1.1))))
	var fryer: Dictionary = Content.FRYERS[int(state.fryer_tier)]
	var labor := 112.0 + maxf(0.0, float(fryer.capacity) - 140.0) * 0.28
	var wages := 0.0
	var kindness := 0.0
	var active_count := 0
	var absent_names: Array[String] = []
	for person in state.staff:
		wages += float(person.wage)
		if int(person.rested_day) == int(state.day): continue
		var absence_chance := (100.0 - float(person.reliability)) / 650.0 + maxf(0.0, 40.0 - float(person.morale)) / 400.0
		if _rng.randf() < absence_chance:
			absent_names.append(str(person.name))
			continue
		labor += 25.0 + float(person.skill) * 0.35
		kindness += float(person.kindness)
		active_count += 1
		person.morale = clampf(float(person.morale) - 1.1 + minigame_bonus * 5.0, 0, 100)
		person.loyalty = clampf(float(person.loyalty) + 0.7, 0, 100)
	var condition_factor := 0.35 + float(state.fryer) * 0.0065
	var capacity := maxi(1, int(floor(minf(float(fryer.capacity), labor) * condition_factor * (1.0 - float(state.day_modifiers.delay)))))
	var starting_stock := int(state.stock)
	var sold := mini(mini(demand, capacity), starting_stock)
	var waste := mini(maxi(0, starting_stock - sold), int(floor(maxi(0, starting_stock - sold) * 0.015)))
	state.stock = starting_stock - sold - waste
	var revenue := _money(sold * float(state.price))
	var base_ingredients := float(sold + waste)
	var extra_ingredients := _money(sold * (maxf(0.0, float(recipe.cost) - 1.0) + premium_cost))
	var ingredients := base_ingredients + extra_ingredients
	var prepaid_fees := 0.0
	if not roadside:
		var daily_allocation := _money(float(state.booked_prepaid_total) / maxi(1, int(venue.days)))
		prepaid_fees = daily_allocation if int(state.venue_day) + 1 < int(venue.days) else _money(float(state.booked_prepaid_total) - daily_allocation * (int(venue.days) - 1))
	var interest := _money(float(state.debt) * 0.005)
	var immediate_fees := (25.0 if roadside else 0.0) + interest
	var fees := _money(prepaid_fees + immediate_fees)
	var event_cash := _money(float(state.cash) - float(state.day_cash_start))
	var trading_cash_delta := _money(revenue - extra_ingredients - wages - immediate_fees)
	var cash_delta := _money(trading_cash_delta + event_cash)
	var profit := _money(revenue + event_cash - ingredients - wages - fees)
	state.cash = _money(float(state.cash) + trading_cash_delta)
	var rep_gain := (0.15 if roadside else 0.6) + quality_appeal * 6.0 + event_quality * 2.5 + minigame_bonus * 3.0 + taste_bonus * 3.0 - maxf(0, float(state.price) - 8.0) * 0.5
	if active_count > 0: rep_gain += kindness / active_count / 240.0
	if sold == 0: rep_gain -= 2.0
	elif starting_stock < mini(demand, capacity): rep_gain -= 0.9
	state.rep = clampf(float(state.rep) + rep_gain, 0, 100)
	state.fame = clampf(float(state.fame) + sold / (360.0 if roadside else 180.0) + maxf(0, rep_gain) * 0.2, 0, 10000)
	if not roadside and sold > 0:
		state.relationships[town] = clampf(relationship + 0.8 + maxf(0.0, quality_appeal) * 3.0, -50, 100)
	state.fryer = clampf(float(state.fryer) - (2.5 + sold / 65.0) / (1.0 + int(state.fryer_tier) * 0.2), 0, 100)
	var completed_stop := false
	if not roadside:
		state.venue_day = int(state.venue_day) + 1
		if int(state.venue_day) >= int(venue.days):
			completed_stop = true
			state.completed.append(str(venue.id))
			state.stats.completed_stops = int(state.stats.completed_stops) + 1
			state.relationships[town] = clampf(float(state.relationships.get(town, 0)) + 3.0, -50, 100)
			state.booked_id = ""
			state.booked_prepaid_total = 0.0
			state.venue_day = 0
	state.stats.total_sales = _money(float(state.stats.total_sales) + revenue)
	state.stats.total_profit = _money(float(state.stats.total_profit) + profit)
	state.stats.total_sold = int(state.stats.total_sold) + sold
	state.stats.best_day = maxf(float(state.stats.best_day), profit)
	state.stats.days_traded = int(state.stats.days_traded) + 1
	state.stats.prepaid_consumed = _money(float(state.stats.prepaid_consumed) + base_ingredients + prepaid_fees)
	state.stats.season_profit = _money(float(state.stats.season_profit) + profit)
	state.stats.season_sales = _money(float(state.stats.season_sales) + revenue)
	var summary: Array[String] = [
		event_result,
		"%d potential customers; capacity %d; %d portions available. Sold %d." % [demand, capacity, starting_stock, sold],
		"$%.2f price changes demand by %+.0f%%. %s weather changes it by %+.0f%%." % [float(state.price), (price_factor - 1) * 100, str(state.weather), (float(weather_factor[state.weather]) - 1) * 100],
		"Ingredients $%.2f = $%.2f prepaid base stock and $%.2f freshly added recipe/quality ingredients." % [ingredients, base_ingredients, extra_ingredients],
		"Fees $%.2f = $%.2f prepaid booking/travel and $%.2f paid today%s." % [fees, prepaid_fees, immediate_fees, " (including loan interest)" if interest > 0 else ""],
		"Cash rose by $%.2f; operating profit is $%.2f after allocating earlier prepayments." % [cash_delta, profit]
	]
	if taste_bonus > 0: summary.append("Your recipe matched this town's tastes: +10% appeal.")
	if not is_zero_approx(event_cash): summary.append("Today's decision changed cash and profit by $%+.2f." % event_cash)
	if active_count == 0 and state.staff.is_empty(): summary.append("The owner ran the stand alone. No staff wages were charged.")
	if not absent_names.is_empty(): summary.append("Absent today: " + ", ".join(absent_names) + ". Their guaranteed wages were paid.")
	if int(state.fryer) < 40: summary.append("The fryer needs attention. Low condition reduces daily capacity.")
	if completed_stop: summary.append("Stop complete. The town will remember you next season.")
	state.last_report = {"title": "Closing time", "venue": str(venue.get("name", "Roadside pop-up")), "weather": state.weather,
		"sold": sold, "revenue": revenue, "ingredients": ingredients, "wages": wages, "fees": fees, "profit": profit,
		"rep_change": _money(float(state.rep) - float(state.day_rep_start)), "stock_waste": waste, "summary": summary,
		"cash_delta": cash_delta, "prepaid_stock": base_ingredients, "prepaid_fees": _money(prepaid_fees),
		"extra_ingredients": extra_ingredients, "event_cash": event_cash, "interest": interest, "demand": demand, "capacity": capacity,
		"day": int(state.day), "completed_stop": completed_stop, "season_end": false}
	# Retain the exact decision evidence and aggregate modifiers used for this report.
	# Expiring a modifier changes no money or RNG and never reapplies its effect.
	for outcome in state.active_outcomes:
		outcome.consumed = true
		outcome.consumed_day = int(state.day)
	if not state.last_outcome.is_empty():
		state.last_outcome.consumed = true
		state.last_outcome.consumed_day = int(state.day)
	state.last_report["event_outcomes"] = state.active_outcomes.duplicate(true)
	state.last_report["used_modifiers"] = state.day_modifiers.duplicate(true)
	state.last_report["practice_boost"] = minigame_bonus
	state.active_outcomes = []
	state.day_modifiers = {"demand": 0.0, "quality": 0.0, "delay": 0.0}
	state.carry_travel_modifiers = false
	_journal("%s: %d sold" % [str(venue.get("name", "Roadside")), sold], "$%.0f revenue, $%.0f operating profit. %s" % [revenue, profit, "Fair complete." if completed_stop else "The circuit continues."], "good" if profit >= 0 else "bad", profit)
	state.day = int(state.day) + 1
	state.phase = "report"
	state.minigame_boost = 0.0
	state.last_report.season_end = int(state.day) > int(state.season_length) or state.completed.size() >= 8

func _dismiss_report() -> Dictionary:
	if str(state.phase) != "report": return _fail("There is no trading report to close.")
	var recovery_value := float(state.cash) + maxf(0, CREDIT_LIMIT - float(state.debt)) + int(state.stock) * maxf(0, float(state.price) - 1)
	if recovery_value < -100.0:
		_end_season(true)
	elif int(state.day) > int(state.season_length) or state.completed.size() >= 8:
		_end_season(false)
	else:
		state.phase = "planning"
	return _ok("Report filed. Your next decision is ready.")

func _end_season(bankrupt: bool) -> void:
	state.phase = "bankrupt" if bankrupt else "season_end"
	state.end_reason = "The company's cash shortfall exceeds its remaining credit and saleable stock." if bankrupt else ("Eight fairs completed." if state.completed.size() >= 8 else "The 36-day season has ended.")
	var equipment_value := 0.0
	for id in ["truck", "fryer", "stand"]:
		for tier in range(1, int(state[id + "_tier"]) + 1): equipment_value += float(_equipment_catalog(id)[tier].cost) * 0.5
	var score := maxi(0, int(round(float(state.cash) + int(state.stock) + equipment_value - float(state.debt) + float(state.rep) * 40.0 + float(state.fame) * 35.0 + state.completed.size() * 120.0)))
	state.season_summary = {"season": int(state.season), "score": score, "profit": float(state.stats.season_profit), "sales": float(state.stats.season_sales), "stops": state.completed.size(), "reputation": float(state.rep), "cash": float(state.cash), "debt": float(state.debt), "equipment_value": equipment_value, "bankrupt": bankrupt}
	state.records.append(state.season_summary.duplicate(true))
	if state.records.size() > 30: state.records.pop_front()
	if not bankrupt: state.stats.seasons_finished = int(state.stats.seasons_finished) + 1
	_journal("The shutters come down" if bankrupt else "A season to remember", str(state.end_reason) + " Score: %d." % score, "bad" if bankrupt else "good")

func _next_season() -> Dictionary:
	if str(state.phase) != "season_end": return _fail("Finish a season before beginning the next.")
	state.season = int(state.season) + 1
	state.day = 1
	state.phase = "planning"
	state.completed = []
	state.booked_id = ""
	state.venue_day = 0
	state.booked_prepaid_total = 0.0
	state.event = {}
	state.last_report = {}
	state.last_outcome = {}
	state.active_outcomes = []
	state.day_modifiers = {"demand": 0.0, "quality": 0.0, "delay": 0.0}
	state.carry_travel_modifiers = false
	state.minigame_day = -1
	state.minigame_boost = 0.0
	state.stats.season_profit = 0.0
	state.stats.season_sales = 0.0
	state.end_reason = ""
	for person in state.staff: person.morale = clampf(float(person.morale) + 15, 0, 100)
	_journal("Season %d: familiar faces" % int(state.season), "Your equipment, team, recipes, debt and town relationships carry forward. A new circuit is open.", "story")
	return _ok("A new season begins. The towns remember your company.")

func _buy_stock(raw) -> Dictionary:
	if not _is_positive_integer(raw, 10000): return _fail("Choose a positive whole number of portions.")
	var amount := int(raw)
	if int(state.stock) + amount > _stock_capacity(): return _fail("Your van has room for %d more portions." % (_stock_capacity() - int(state.stock)))
	if float(state.cash) < amount: return _fail("Supplies cost $1 per portion. You need $%d." % amount)
	state.cash = _money(float(state.cash) - amount)
	state.stock = int(state.stock) + amount
	state.stats.stock_bought = int(state.stats.stock_bought) + amount
	_journal("Pantry restocked", "%d portions prepaid at $1 each. Recipe extras are charged only when sold." % amount, "info", -amount)
	return _ok("Bought %d portions for $%d." % [amount, amount])

func _set_price(raw) -> Dictionary:
	if not _is_number(raw) or float(raw) < 3 or float(raw) > 14: return _fail("Set a price from $3 to $14.")
	state.price = _money(float(raw))
	return _ok("Price set to $%.2f per bag." % float(state.price))

func _set_recipe(id: String) -> Dictionary:
	var recipe: Dictionary = Content.find(Content.RECIPES, id)
	if recipe.is_empty(): return _fail("That recipe is not in the notebook.")
	if id not in state.unlocked_recipes: return _fail("This recipe unlocks at %d reputation." % int(recipe.unlock_rep))
	state.recipe = id
	return _ok(str(recipe.name) + " is on the menu.")

func _set_quality(id: String) -> Dictionary:
	if id not in QUALITIES: return _fail("Choose budget, standard or premium ingredients.")
	state.quality = id
	return _ok("Ingredient quality set to " + id + ".")

func _hire(id: String) -> Dictionary:
	var candidate: Dictionary = Content.find(Content.STAFF, id)
	if candidate.is_empty(): return _fail("That applicant is unavailable.")
	if _staff_index(id) >= 0: return _fail("They already work for your company.")
	if state.staff.size() >= int(Content.STANDS[int(state.stand_tier)].capacity): return _fail("Upgrade the stand to make room for another employee.")
	if float(state.cash) < float(candidate.wage): return _fail("The signing payment is one day's wage.")
	var person: Dictionary = candidate.duplicate(true)
	person.merge({"morale": 78.0, "loyalty": 45.0, "trained": 0, "rested_day": -1}, true)
	state.staff.append(person)
	state.cash = _money(float(state.cash) - float(person.wage))
	_journal(str(person.name) + " joins the van", "$%.0f signing payment; $%.0f guaranteed wage on each trading day." % [float(person.wage), float(person.wage)], "good", -float(person.wage))
	return _ok(str(person.name) + " is hired.")

func _fire(id: String) -> Dictionary:
	var index := _staff_index(id)
	if index < 0: return _fail("That employee is not on your team.")
	var name := str(state.staff[index].name)
	state.staff.remove_at(index)
	_journal("A different road", name + " has left the company. No severance fee was charged.", "info")
	return _ok(name + " has left the team.")

func _train(id: String) -> Dictionary:
	var index := _staff_index(id)
	if index < 0: return _fail("Choose someone on your team.")
	var person: Dictionary = state.staff[index]
	if int(person.trained) >= 3: return _fail("They have completed all three training sessions.")
	if float(state.cash) < 120: return _fail("Training costs $120.")
	state.cash = _money(float(state.cash) - 120)
	person.trained = int(person.trained) + 1
	person.skill = mini(100, int(person.skill) + 7)
	person.reliability = mini(100, int(person.reliability) + 4)
	person.kindness = mini(100, int(person.kindness) + 3)
	person.morale = minf(100, float(person.morale) + 8)
	person.loyalty = minf(100, float(person.loyalty) + 6)
	_journal("Learning the craft", str(person.name) + " gained skill, reliability and confidence.", "good", -120)
	return _ok(str(person.name) + " completed a training session.")

func _rest(id: String) -> Dictionary:
	var index := _staff_index(id)
	if index < 0: return _fail("Choose someone on your team.")
	var person: Dictionary = state.staff[index]
	if int(person.rested_day) == int(state.day): return _fail("They are already resting today.")
	person.rested_day = int(state.day)
	person.morale = minf(100, float(person.morale) + 18)
	person.loyalty = minf(100, float(person.loyalty) + 3)
	return _ok(str(person.name) + " is resting today, with pay and no production capacity.")

func _service(id: String) -> Dictionary:
	if id not in ["truck", "fryer"]: return _fail("Choose the van or fryer to service.")
	if float(state[id]) >= 99.9: return _fail("That equipment is already in perfect condition.")
	var cost := _service_cost(id)
	if float(state.cash) < cost: return _fail("Servicing this equipment costs $%.0f." % cost)
	state.cash = _money(float(state.cash) - cost)
	state[id] = 100.0
	_journal("Ready for the next rush", "The %s was fully serviced." % id, "good", -cost)
	return _ok("The %s is back to 100%% condition." % id)

func _upgrade(id: String) -> Dictionary:
	if id not in ["truck", "fryer", "stand"]: return _fail("Choose equipment to upgrade.")
	var catalog := _equipment_catalog(id)
	var tier := int(state[id + "_tier"])
	if tier + 1 >= catalog.size(): return _fail("That equipment is fully upgraded.")
	var next: Dictionary = catalog[tier + 1]
	if float(state.cash) < float(next.cost): return _fail("The upgrade costs $%.0f." % float(next.cost))
	state.cash = _money(float(state.cash) - float(next.cost))
	state[id + "_tier"] = tier + 1
	if id != "stand": state[id] = 100.0
	_journal(str(next.name), str(next.description), "good", -float(next.cost))
	return _ok(str(next.name) + " is ready for the road.")

func _loan(raw) -> Dictionary:
	if not _is_positive_integer(raw, int(CREDIT_LIMIT)) or int(raw) % 100 != 0: return _fail("Borrow a positive multiple of $100, up to $2,000 total debt.")
	var amount := int(raw)
	if float(state.debt) + amount > CREDIT_LIMIT: return _fail("Your total credit limit is $2,000.")
	state.debt = _money(float(state.debt) + amount)
	state.cash = _money(float(state.cash) + amount)
	_journal("A little breathing room", "$%d borrowed. Interest is 0.5%% of outstanding debt per trading day; travel days have no charge." % amount, "info", amount)
	return _ok("Borrowed $%d. Repay whenever cash allows." % amount)

func _repay(raw) -> Dictionary:
	if not _is_positive_integer(raw, int(CREDIT_LIMIT)): return _fail("Choose a positive repayment amount.")
	var amount := minf(float(raw), float(state.debt))
	if amount <= 0: return _fail("The company has no debt to repay.")
	if float(state.cash) < amount: return _fail("There is not enough cash for that repayment.")
	state.cash = _money(float(state.cash) - amount)
	state.debt = _money(float(state.debt) - amount)
	state.stats.debt_repaid = _money(float(state.stats.debt_repaid) + amount)
	_journal("Lighter on the road", "$%.0f repaid. Remaining debt: $%.0f." % [amount, float(state.debt)], "good", -amount)
	return _ok("Repaid $%.0f." % amount)

func _set_policy(args: Dictionary) -> Dictionary:
	var id := str(args.get("id", ""))
	if id not in ["restock", "service"] or not args.get("enabled") is bool: return _fail("Choose a valid policy and an on/off setting.")
	state.policy[id] = bool(args.enabled)
	return _ok("%s policy %s. Automatic spending keeps a $250 cash reserve." % [id.capitalize(), "enabled" if bool(args.enabled) else "disabled"])

func _minigame(raw) -> Dictionary:
	if not _is_number(raw) or float(raw) < 0 or float(raw) > 1: return _fail("Practice score must be between 0 and 1.")
	if str(state.booked_id).is_empty(): return _fail("Book a fair before preparing a practice batch.")
	if int(state.minigame_day) == int(state.day): return _fail("Today's practice batch is already prepared.")
	state.minigame_day = int(state.day)
	state.minigame_boost = float(raw) * 0.2
	state.stats.best_minigame = maxf(float(state.stats.best_minigame), float(raw))
	return _ok("Practice adds %d%% customer appeal today." % int(round(float(raw) * 20)))

func _rename(name: String) -> Dictionary:
	var clean := name.strip_edges()
	if clean.length() < 2 or clean.length() > 30: return _fail("Choose a company name of 2 to 30 characters.")
	state.company = clean
	return _ok("The company is now " + clean + ".")

func _apply_policies() -> void:
	if bool(state.policy.service):
		for id in ["truck", "fryer"]:
			if float(state[id]) < 40 and float(state.cash) >= _service_cost(id) + 250: _service(id)
	if bool(state.policy.restock):
		var target := mini(_stock_capacity(), int(ceil(float(_venue().get("demand", 80)) * 1.5)))
		var amount := maxi(0, mini(target - int(state.stock), int(floor(float(state.cash) - 250))))
		if amount > 0: _buy_stock(amount)

func _award_badges() -> void:
	_unlock_recipes(true)
	var unlocked: int = state.unlocked_recipes.size()
	var familiar := false
	for value in state.relationships.values():
		if float(value) >= 20: familiar = true
	var conditions := {"first_stop": int(state.stats.completed_stops) >= 1, "steady_hand": float(state.stats.best_minigame) >= 0.9,
		"familiar_face": familiar, "six_flavors": unlocked >= 6, "full_crew": state.staff.size() >= 4,
		"road_ready": int(state.truck_tier) >= 2, "copper_kettle": int(state.fryer_tier) >= 2,
		"fleet_dream": int(state.truck_tier) >= 3, "crowd_favorite": float(state.rep) >= 80,
		"debt_free": float(state.stats.debt_repaid) >= 500 and float(state.debt) <= 0,
		"long_road": int(state.stats.completed_stops) >= 8, "golden_hour": int(state.season) >= 2}
	for badge in Content.BADGES:
		if bool(conditions.get(str(badge.id), false)) and str(badge.id) not in state.achievements:
			state.achievements.append(str(badge.id))
			_journal("Badge earned: " + str(badge.name), str(badge.description), "good")

func _unlock_recipes(announce: bool) -> void:
	for recipe in Content.RECIPES:
		if float(state.rep) >= float(recipe.unlock_rep) and str(recipe.id) not in state.unlocked_recipes:
			state.unlocked_recipes.append(str(recipe.id))
			if announce: _journal("Recipe learned: " + str(recipe.name), "Your reputation opened a new page in the recipe notebook. This recipe remains yours through future seasons.", "good")

func _valid_outcomes(outcomes) -> bool:
	if not outcomes is Array or outcomes.size() > 8: return false
	for outcome in outcomes:
		if not _valid_outcome(outcome): return false
	return true

func _valid_outcome(outcome) -> bool:
	if not outcome is Dictionary: return false
	if outcome.is_empty(): return true
	for key in ["instance_id", "event_id", "title", "choice_label", "result", "context"]:
		if not outcome.get(key) is String: return false
	if outcome.context not in ["travel", "trading"]: return false
	for key in ["day", "season", "consumed_day", "risk_chance"]:
		if not _is_number(outcome.get(key)): return false
	if float(outcome.risk_chance) < -1 or float(outcome.risk_chance) > 1: return false
	if not outcome.get("risk_happened") is bool or not outcome.get("consumed") is bool: return false
	if not outcome.get("effects") is Array or outcome.effects.size() > 26: return false
	for effect in outcome.effects:
		if not effect is Dictionary or str(effect.get("key", "")) not in ["cash", "rep", "stock", "truck", "fryer", "morale", "loyalty", "fame", "relationship", "demand", "quality", "delay"]: return false
		if str(effect.get("source", "")) not in ["certain", "risk"] or not effect.get("town") is String: return false
		for key in ["requested", "before", "after", "value"]:
			if not _is_number(effect.get(key)) or absf(float(effect[key])) > 1000000000: return false
		if not effect.get("members") is Array or effect.members.size() > 8: return false
		for member in effect.members:
			if not member is Dictionary or not member.get("id") is String or not member.get("name") is String: return false
			for key in ["before", "after", "value"]:
				if not _is_number(member.get(key)) or absf(float(member[key])) > 100: return false
	return true

func _valid_effects(effects) -> bool:
	if not effects is Dictionary: return false
	for key in effects:
		if str(key) in ["flag", "clear_flag"]:
			if not effects[key] is String: return false
		elif str(key) in ["cash", "rep", "stock", "truck", "fryer", "morale", "loyalty", "fame", "relationship", "demand", "quality", "delay"]:
			if not _is_number(effects[key]) or absf(float(effects[key])) > 100000: return false
		else: return false
	return true

func _venue() -> Dictionary:
	return Content.find(Content.VENUES, str(state.get("booked_id", "")))

func _stock_capacity() -> int:
	return int(Content.TRUCKS[int(state.truck_tier)].capacity)

func _equipment_catalog(id: String) -> Array:
	match id:
		"truck": return Content.TRUCKS
		"fryer": return Content.FRYERS
		"stand": return Content.STANDS
	return []

func _service_cost(id: String) -> float:
	return ceilf((30.0 if id == "truck" else 40.0) + (100.0 - float(state[id])) * (1.1 if id == "truck" else 1.25))

func _travel_cost(venue: Dictionary) -> float:
	return ceilf(maxf(20.0, float(venue.distance) * (0.6 - int(state.truck_tier) * 0.045)))

func _staff_index(id: String) -> int:
	for i in range(state.staff.size()):
		if str(state.staff[i].id) == id: return i
	return -1

func _journal(title: String, body: String, tone: String, amount = null) -> void:
	var entry := {"day": int(state.day), "season": int(state.season), "title": title, "text": body, "tone": tone}
	if amount != null: entry["amount"] = _money(float(amount))
	state.journal.append(entry)
	while state.journal.size() > 180: state.journal.pop_front()

func _sync_rng() -> void:
	if state.is_empty(): return
	state["rng_seed"] = str(_rng.seed)
	state["rng_state"] = str(_rng.state)

func _is_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _is_positive_integer(value, maximum: int) -> bool:
	return _is_number(value) and float(value) > 0 and float(value) <= maximum and float(value) == floorf(float(value))

func _money(value: float) -> float:
	return snappedf(value, 0.01)

func _ok(message: String) -> Dictionary:
	return {"ok": true, "message": message}

func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
