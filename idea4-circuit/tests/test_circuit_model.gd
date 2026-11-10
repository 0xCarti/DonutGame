extends SceneTree

const Model = preload("res://scripts/circuit_model.gd")
const Content = preload("res://scripts/circuit_content.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_new_company_and_rejections()
	_test_accounting_and_event_once()
	_test_save_and_pending_determinism()
	_test_staff_equipment_and_credit()
	_test_content_choices()
	_test_full_calendar_seasons()
	_test_eight_stops_and_next_season()
	_test_owner_only_opening()
	_test_bankruptcy_and_recovery()
	_test_progression_and_price_tradeoffs()
	_test_stock_costs_and_permanent_recipes()
	_test_fee_rounding_and_risk_affordability()
	_test_recorded_outcomes_and_duration()
	_test_outcome_migration_and_validation()
	if failures.is_empty():
		print("PASS: %d circuit model checks; 36-day seasons, eight stops, every event choice, deterministic reloads and money reconciliation." % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d failures across %d checks." % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _new(seed_value: int = 2026):
	var model = Model.new()
	model.new_run("Test Company", seed_value)
	return model

func _snapshot(model) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(model.to_save())), "", true)

func _free_choice(model) -> int:
	for i in range(model.state.event.choices.size()):
		var choice: Dictionary = model.state.event.choices[i]
		var cost := maxf(0, -float(choice.get("effects", {}).get("cash", 0)))
		cost += maxf(0, -float(choice.get("risk", {}).get("effects", {}).get("cash", 0)))
		var stock_cost := maxi(0, -int(choice.get("effects", {}).get("stock", 0)))
		stock_cost += maxi(0, -int(choice.get("risk", {}).get("effects", {}).get("stock", 0)))
		if cost <= 0 and stock_cost <= int(model.state.stock): return i
	return 0

func _resolve_free(model) -> void:
	_check(bool(model.act("decide", {"choice": _free_choice(model)}).ok), "A zero-cash choice resolves the pending event")

func _quiet_event(model, context: String, effects: Dictionary = {}) -> void:
	model.state.phase = "event"
	model.state.event = {"id": "test_quiet", "title": "A quiet moment", "body": "A reproducible test decision.",
		"context": context, "instance_id": "test:%d:%d" % [int(model.state.day), int(model.state.event_serial)],
		"once": false, "tags": [context], "choices": [{"label": "Continue", "detail": "No random cost.", "result": "A steady day.", "effects": effects}]}

func _test_new_company_and_rejections() -> void:
	var model = _new()
	_check(model.state.phase == "planning" and model.state.cash == 2800, "A new company starts in planning with $2,800")
	_check(model.state.stock == 160 and model.state.staff.is_empty(), "Owner-only start includes 160 prepaid portions")
	_check(model.venue_offers().size() >= 8 and model.equipment_options().size() == 3, "Fair and equipment APIs expose the catalog")
	for invalid in [
		["buy_stock", {"amount": -20}], ["buy_stock", {"amount": 0}], ["buy_stock", {"amount": 0.5}],
		["buy_stock", {"amount": 10000000}], ["buy_stock", {"amount": NAN}], ["buy_stock", {"amount": "100"}],
		["set_price", {"value": INF}], ["set_price", {"value": NAN}], ["set_price", {"value": 0}],
		["set_price", {"value": 20}], ["set_recipe", {"id": "missing"}], ["set_recipe", {"id": "cocoa"}],
		["set_quality", {"id": "unknown"}], ["book", {"id": "unknown"}], ["hire", {"id": "unknown"}],
		["fire", {"id": "unknown"}], ["train", {"id": "unknown"}], ["rest", {"id": "unknown"}],
		["upgrade", {"id": "unknown"}], ["service", {"id": "stand"}], ["loan", {"amount": -500}],
		["loan", {"amount": 500.5}], ["repay", {"amount": 500}], ["set_policy", {"id": "restock", "enabled": 1}],
		["minigame", {"score": 0.8}], ["rename", {"name": ""}], ["decide", {"choice": 0}],
		["dismiss_report", {}], ["next_season", {}], ["unknown", {}]
	]:
		var before := _snapshot(model)
		_check(not bool(model.act(invalid[0], invalid[1]).ok), "Invalid action rejected: %s %s" % invalid)
		_check(before == _snapshot(model), "Rejected action is atomic: " + str(invalid[0]))
	var affordable: Dictionary = model.venue_offers()[0]
	_check(bool(affordable.can_book), "First fair can be booked by a new company")
	_check(bool(model.act("book", {"id": affordable.id}).ok), "Booking queues travel")
	_check(model.state.phase == "event" and model.state.event.context == "travel", "Booking leads to travel decision")
	for action in ["buy_stock", "hire", "loan", "advance", "book", "rename", "upgrade"]:
		var before := _snapshot(model)
		_check(not bool(model.act(action, {"amount": 100, "id": "bea", "name": "Oops"}).ok), "Pending event blocks " + action)
		_check(before == _snapshot(model), "Pending event rejection preserves state")
	_resolve_free(model)
	_check(model.state.phase == "planning" and model.state.day == 2, "Travel consumes exactly one day and returns to planning")
	_check(not bool(model.act("book", {"id": "brass_bell"}).ok), "Cannot replace an active booking")
	_check(bool(model.act("minigame", {"score": 0.95}).ok), "Practice can be completed before opening")
	_check(not bool(model.act("minigame", {"score": 1}).ok), "Practice rewards cannot be repeated today")
	_check("steady_hand" in model.state.achievements, "Practice awards its badge")

func _record(outcome: Dictionary, key: String, source: String = "certain") -> Dictionary:
	for effect in outcome.get("effects", []):
		if str(effect.key) == key and str(effect.source) == source: return effect
	return {}

func _test_recorded_outcomes_and_duration() -> void:
	var model = _new(88)
	model.act("hire", {"id": "bea"})
	model.act("hire", {"id": "nell"})
	model.state.staff[0].morale = 98.0
	model.state.staff[1].morale = 40.0
	model.state.rep = 99.0
	model.state.truck = 99.0
	model.act("book", {"id": "willowbank"})
	_quiet_event(model, "travel", {"rep": 5, "truck": 8, "morale": 8, "quality": 0.1, "demand": 0.12, "delay": 0.1, "stock": 500})
	model.state.event.choices[0]["risk"] = {"chance": 1.0, "effects": {"cash": -20, "rep": -2}, "summary": "The extra cost happened."}
	var before := float(model.state.cash)
	_check(model.act("decide", {"choice": 0}).ok, "Outcome fixture resolves travel")
	var outcome: Dictionary = model.state.last_outcome
	_check(outcome.choice_label == "Continue" and outcome.context == "travel", "Choice identity and context are recorded")
	_check(outcome.risk_happened and outcome.risk_chance == 1.0, "A realised risk is explicitly recorded")
	_check(_record(outcome, "rep").value == 1 and _record(outcome, "rep", "risk").value == -2, "Guaranteed and risk reputation record separately after caps")
	_check(_record(outcome, "truck").value == 1 and _record(outcome, "truck").after == 100, "Decision repair delta excludes subsequent travel wear")
	_check(_record(outcome, "stock").value == 100, "Stock reward records only storage space actually filled")
	var morale: Dictionary = _record(outcome, "morale")
	_check(morale.value == 5 and morale.members[0].value == 2 and morale.members[1].value == 8, "Crew records retain each employee's clamped change")
	_check(is_equal_approx(float(model.state.cash), before - 20), "Outcome recording never applies cash twice")
	_check(not outcome.consumed and model.state.active_outcomes.size() == 1, "Travel modifiers remain pending until trading")
	var resumed = Model.new()
	_check(resumed.from_save(JSON.parse_string(JSON.stringify(model.to_save()))), "Travel outcome and pending buffs survive reload")
	_check(_snapshot(model) == _snapshot(resumed), "Recorded outcome reload changes no gameplay or evidence")
	model.act("advance")
	_quiet_event(model, "trading", {"quality": 0.1})
	model.state.event.choices[0]["risk"] = {"chance": 0.0, "effects": {"cash": -100}, "summary": "This cannot happen."}
	model.act("decide", {"choice": 0})
	_check(not model.state.last_outcome.risk_happened and _record(model.state.last_outcome, "cash", "risk").is_empty(), "Avoided risk records no fictional penalty")
	_check(model.state.last_report.event_outcomes.size() == 2, "Report includes travel and trading decisions consumed by the day")
	_check(is_equal_approx(float(model.state.last_report.used_modifiers.quality), 0.2), "Report preserves the aggregate quality actually used")
	_check(model.state.active_outcomes.is_empty() and model.state.last_outcome.consumed, "Resolved buffs leave no active pending effects")
	for key in ["demand", "quality", "delay"]:
		_check(is_zero_approx(float(model.state.day_modifiers[key])), "Used modifier expires immediately: " + key)
	for recorded in model.state.last_report.event_outcomes:
		_check(recorded.consumed and recorded.consumed_day == model.state.last_report.day, "Report records when each modifier was consumed")
	var report_save := _snapshot(model)
	_check(not model.act("decide", {"choice": 0}).ok and report_save == _snapshot(model), "Re-clicking cannot reapply recorded effects")
	_check(resumed.from_save(JSON.parse_string(JSON.stringify(model.to_save()))) and report_save == _snapshot(resumed), "Consumed evidence and reports survive reload exactly")
	model.act("dismiss_report")
	model.act("advance")
	_quiet_event(model, "trading")
	model.act("decide", {"choice": 0})
	_check(model.state.last_report.event_outcomes.size() == 1 and is_zero_approx(float(model.state.last_report.used_modifiers.quality)), "Next trading day does not reuse travel effects")
	var alone = _new()
	alone.act("book", {"id": "willowbank"})
	_quiet_event(alone, "travel", {"morale": 8, "loyalty": 4})
	alone.act("decide", {"choice": 0})
	_check(_record(alone.state.last_outcome, "morale").value == 0 and _record(alone.state.last_outcome, "morale").members.is_empty(), "Owner-only morale reward records no effect")
	_check(_record(alone.state.last_outcome, "loyalty").value == 0, "Owner-only loyalty reward records no effect")

func _test_outcome_migration_and_validation() -> void:
	var original = _new(2026)
	original.act("book", {"id": "willowbank"})
	_quiet_event(original, "travel", {"demand": 0.2})
	original.act("decide", {"choice": 0})
	var old: Dictionary = original.to_save()
	old.erase("last_outcome")
	old.erase("active_outcomes")
	var loaded = Model.new()
	_check(loaded.from_save(old), "A v0.1 save without outcome fields remains accepted")
	_check(loaded.state.last_outcome.is_empty() and loaded.state.active_outcomes.is_empty(), "Old saves receive safe empty evidence defaults")
	_check(is_equal_approx(float(loaded.state.day_modifiers.demand), 0.2), "Migration keeps genuine pending travel effects")
	loaded.act("advance")
	_quiet_event(loaded, "trading")
	loaded.act("decide", {"choice": 0})
	_check(is_equal_approx(float(loaded.state.last_report.used_modifiers.demand), 0.2), "Migrated travel bonus still applies once")
	var old_report: Dictionary = loaded.to_save()
	old_report.erase("last_outcome")
	old_report.erase("active_outcomes")
	old_report.last_report.erase("event_outcomes")
	old_report.day_modifiers.demand = 0.2
	var migrated = Model.new()
	_check(migrated.from_save(old_report) and migrated.state.day_modifiers.demand == 0, "Older reports clear already-consumed stale modifiers")
	for corruption in ["container", "risk", "number", "members", "source"]:
		var bad: Dictionary = original.to_save()
		match corruption:
			"container": bad.last_outcome = "wrong"
			"risk": bad.last_outcome.risk_chance = 7
			"number": bad.last_outcome.effects[0].value = NAN
			"members": bad.last_outcome.effects[0].members = ["wrong"]
			"source": bad.last_outcome.effects[0].source = "reapply"
		var before := _snapshot(loaded)
		_check(not loaded.from_save(bad), "Malformed outcome is rejected: " + corruption)
		_check(before == _snapshot(loaded), "Malformed evidence never replaces the running company")
	for corruption in ["used_modifiers", "practice_boost"]:
		var bad: Dictionary = loaded.to_save()
		bad.last_report[corruption] = "invalid"
		_check(not loaded.from_save(bad), "Malformed consumed modifier evidence is rejected: " + corruption)

func _test_accounting_and_event_once() -> void:
	var model = _new(10)
	var start_cash := float(model.state.cash)
	_check(bool(model.act("buy_stock", {"amount": 100}).ok), "Buying supplies succeeds within capacity")
	_check(is_equal_approx(float(model.state.cash), start_cash - 100), "Supplies charge exactly $1 per portion")
	var offer: Dictionary = model.venue_offers()[0]
	model.act("book", {"id": offer.id})
	_quiet_event(model, "travel", {"cash": -40.0, "demand": 0.1})
	model.act("decide", {"choice": 0})
	_check(is_equal_approx(float(model.state.booked_prepaid_total), float(offer.total_cost) + 40), "Travel event expenses enter prepaid fair costs")
	var day_cash := float(model.state.cash)
	model.act("advance")
	_check(is_equal_approx(float(model.state.day_modifiers.demand), 0.1), "Travel appeal carries into the next opening")
	_quiet_event(model, "trading", {"cash": -25.0})
	_check(bool(model.act("decide", {"choice": 0}).ok), "Trading choice resolves sales")
	var report: Dictionary = model.state.last_report
	_check(model.state.phase == "report", "Trading produces a report")
	_check(report.sold > 0 and report.wages == 0, "Owner sells without staff wages")
	_check(is_equal_approx(float(report.ingredients), float(report.sold) + float(report.stock_waste)), "Classic standard recipe costs only prepaid $1 base")
	_check(is_zero_approx(float(report.extra_ingredients)), "Classic base is never billed a second time")
	_check(is_equal_approx(float(model.state.cash) - day_cash, float(report.cash_delta)), "Report cash delta equals actual cash movement including decision cost")
	_check(is_equal_approx(float(report.profit), float(report.revenue) + float(report.event_cash) - float(report.ingredients) - float(report.wages) - float(report.fees)), "Every report profit component reconciles")
	_check(absf(float(report.cash_delta) - float(report.profit) - float(report.prepaid_stock) - float(report.prepaid_fees)) < 0.02, "Cash/profit difference equals earlier inventory and fee prepayments")
	var after := _snapshot(model)
	_check(not bool(model.act("decide", {"choice": 0}).ok), "An event instance can resolve only once")
	_check(after == _snapshot(model), "Repeated decision cannot duplicate revenue")
	_check(not bool(model.act("buy_stock", {"amount": 1}).ok), "Report blocks management until dismissed")
	model.act("dismiss_report")
	model.act("set_recipe", {"id": "lemon"})
	model.act("set_quality", {"id": "premium"})
	model.act("advance")
	_check(is_zero_approx(float(model.state.day_modifiers.demand)), "Travel appeal expires after the first sales day")
	_quiet_event(model, "trading")
	model.act("decide", {"choice": 0})
	report = model.state.last_report
	_check(absf(float(report.extra_ingredients) - int(report.sold) * (0.3 + 0.85)) < 0.02, "Only recipe and premium extras are charged on selling")
	_check(model.state.completed.size() == 1 and model.state.booked_id == "", "The final sales day completes and clears the stop")

func _test_save_and_pending_determinism() -> void:
	var a = _new(88441)
	a.act("book", {"id": "willowbank"})
	var b = Model.new()
	_check(b.from_save(JSON.parse_string(JSON.stringify(a.to_save()))), "JSON round-trip loads a pending travel event")
	_check(a.state.event.instance_id == b.state.event.instance_id, "Pending event instance survives reload")
	var choice := _free_choice(a)
	a.act("decide", {"choice": choice})
	b.act("decide", {"choice": choice})
	_check(_snapshot(a) == _snapshot(b), "Reload preserves travel outcome and exact RNG continuation")
	a.act("advance")
	b.act("advance")
	_check(_snapshot(a) == _snapshot(b), "Reload preserves next weather and selected trading event")
	var c = Model.new()
	_check(c.from_save(JSON.parse_string(JSON.stringify(a.to_save()))), "JSON round-trip loads a pending trading event")
	choice = _free_choice(a)
	a.act("decide", {"choice": choice})
	c.act("decide", {"choice": choice})
	_check(_snapshot(a) == _snapshot(c), "Reload preserves sales, wages, risk and all report values")
	var good: Dictionary = a.to_save()
	for corrupted in ["rng_state", "stats", "stock", "phase", "day_modifiers", "policy", "day_cash_start"]:
		var bad: Dictionary = good.duplicate(true)
		match corrupted:
			"rng_state": bad.rng_state = "not an integer"
			"stats": bad.stats = {}
			"stock": bad.stock = -1
			"phase": bad.phase = "made_up"
			"day_modifiers": bad.day_modifiers = {"demand": "huge", "quality": 0, "delay": 0}
			"policy": bad.policy = {"restock": "yes", "service": false}
			"day_cash_start": bad.erase("day_cash_start")
		var before := _snapshot(a)
		_check(not a.from_save(bad), "Corrupted save rejected: " + corrupted)
		_check(before == _snapshot(a), "Rejected save does not replace the running company")

func _test_staff_equipment_and_credit() -> void:
	var model = _new()
	var cash := float(model.state.cash)
	_check(bool(model.act("loan", {"amount": 500}).ok), "Recovery credit is available")
	_check(model.state.cash == cash + 500 and model.state.debt == 500, "Loan creates equal cash and liability")
	_check(bool(model.act("repay", {"amount": 500}).ok), "Loan can be repaid")
	_check(model.state.cash == cash and model.state.debt == 0, "Loan/repay cycles cannot create money")
	_check("debt_free" in model.state.achievements, "Repayment badge is awarded")
	model.act("loan", {"amount": 2000})
	_check(not bool(model.act("loan", {"amount": 100}).ok), "Credit cap is enforced")
	model.act("repay", {"amount": 2000})
	_check(bool(model.act("hire", {"id": "bea"}).ok), "An applicant can be hired")
	_check(not bool(model.act("hire", {"id": "bea"}).ok), "Duplicate staff are rejected")
	var skill := int(model.state.staff[0].skill)
	model.act("train", {"id": "bea"})
	_check(int(model.state.staff[0].skill) > skill and model.state.staff[0].trained == 1, "Training improves skill and records its level")
	model.act("rest", {"id": "bea"})
	_check(not bool(model.act("rest", {"id": "bea"}).ok), "Rest cannot repeatedly farm loyalty in one day")
	model.act("hire", {"id": "nell"})
	_check(not bool(model.act("hire", {"id": "kit"}).ok), "Stand capacity limits crew")
	model.state.cash = 50000.0
	for id in ["truck", "fryer", "stand"]:
		var before_cash := float(model.state.cash)
		var next_cost := float(model.equipment_options()[["truck", "fryer", "stand"].find(id)].next_cost)
		_check(bool(model.act("upgrade", {"id": id}).ok), id + " can be upgraded")
		_check(model.state[id + "_tier"] == 1 and is_equal_approx(before_cash - float(model.state.cash), next_cost), "Upgrade applies correct tier and one-time cost")
	model.state.truck = 10.0
	_check(bool(model.act("service", {"id": "truck"}).ok) and model.state.truck == 100, "Servicing restores worn equipment")
	_check(not bool(model.act("service", {"id": "truck"}).ok), "Perfect equipment cannot be needlessly serviced")
	_check(bool(model.act("hire", {"id": "kit"}).ok), "Stand upgrade increases staff capacity")
	_check(bool(model.act("fire", {"id": "kit"}).ok), "Staff can be released to reduce expenses")
	model.act("book", {"id": "willowbank"})
	_quiet_event(model, "travel")
	model.act("decide", {"choice": 0})
	model.act("rest", {"id": "bea"})
	model.act("rest", {"id": "nell"})
	model.act("loan", {"amount": 500})
	model.act("advance")
	_quiet_event(model, "trading")
	model.act("decide", {"choice": 0})
	_check(model.state.last_report.wages == 77, "Resting employees retain their guaranteed wages")
	_check(is_equal_approx(float(model.state.last_report.interest), 2.5), "Loan interest is included once per sales day")

func _test_content_choices() -> void:
	_check(Content.EVENTS.size() >= 45, "There are at least 45 authored events")
	var known_effects := ["cash", "rep", "stock", "truck", "fryer", "morale", "loyalty", "fame", "relationship", "demand", "quality", "delay", "flag", "clear_flag"]
	var event_ids: Array = []
	for event in Content.EVENTS:
		_check(str(event.id) not in event_ids, "Event ID is unique: " + str(event.id))
		event_ids.append(str(event.id))
		var has_free := false
		for index in range(event.choices.size()):
			var choice: Dictionary = event.choices[index]
			var effects: Dictionary = choice.get("effects", {})
			var risk_effects: Dictionary = choice.get("risk", {}).get("effects", {})
			for key in effects.keys() + risk_effects.keys(): _check(str(key) in known_effects, "Event uses supported effect: " + str(key))
			if float(effects.get("cash", 0)) >= 0 and float(risk_effects.get("cash", 0)) >= 0: has_free = true
			var model = _new(9000 + index)
			model.state.cash = 100000.0
			model.state.day_cash_start = 100000.0
			model.state.day = 20
			model.state.booked_id = "willowbank"
			model.state.booked_prepaid_total = 160.0
			model.act("hire", {"id": "bea"})
			model.state.day_cash_start = float(model.state.cash)
			model.state.event = event.duplicate(true)
			model.state.event.context = "travel" if "travel" in event.tags else "trading"
			model.state.event.instance_id = "all_choices:" + str(event.id) + ":" + str(index)
			model.state.phase = "event"
			_check(bool(model.act("decide", {"choice": index}).ok), "Choice executes: %s/%d" % [str(event.id), index])
			_check(model.state.event.is_empty(), "Resolved event clears its instance")
			_check(is_finite(float(model.state.cash)) and model.state.stock >= 0 and model.state.stock <= 260, "Choice preserves finite cash and bounded inventory")
			_check(model.state.truck >= 0 and model.state.truck <= 100 and model.state.fryer >= 0 and model.state.fryer <= 100, "Choice preserves equipment bounds")
		_check(has_free, "Event has a financially free recovery choice: " + str(event.id))

func _test_full_calendar_seasons() -> void:
	for seed_value in [1, 2026, 95131]:
		var model = _new(seed_value)
		model.act("set_policy", {"id": "restock", "enabled": true})
		model.act("set_policy", {"id": "service", "enabled": true})
		for day in range(36):
			_check(model.state.day == day + 1, "Calendar day increments once per opening")
			_check(bool(model.act("advance").ok), "Roadside recovery offers a complete daily loop")
			_resolve_free(model)
			_check(model.state.phase == "report", "Every calendar day creates one report")
			_check(bool(model.act("dismiss_report").ok), "Every report can be acknowledged")
		_check(model.state.phase == "season_end" and model.state.day == 37, "A full 36-day season ends cleanly")
		_check(model.state.stats.days_traded == 36 and model.state.records.size() == 1, "Season records count every actual trading day")
		_check(model.state.cash > 2800, "Owner-only recovery remains viable over the calendar season")
		print("CALENDAR seed=%d cash=%.2f profit=%.2f rep=%.1f" % [seed_value, float(model.state.cash), float(model.state.stats.total_profit), float(model.state.rep)])

func _test_eight_stops_and_next_season() -> void:
	var model = _new(7733)
	model.state.cash = 100000.0
	model.state.rep = 100.0
	model.state.truck_tier = 3
	model.state.fryer_tier = 3
	model.state.stand_tier = 3
	model.act("hire", {"id": "bea"})
	model.act("hire", {"id": "kit"})
	model.act("hire", {"id": "june"})
	model.act("hire", {"id": "sol"})
	model.act("set_policy", {"id": "restock", "enabled": true})
	model.act("set_policy", {"id": "service", "enabled": true})
	for stop in range(8):
		var venue: Dictionary = Content.VENUES[stop]
		_check(bool(model.act("book", {"id": venue.id}).ok), "Eight-stop run books venue " + str(venue.id))
		_resolve_free(model)
		for day in range(int(venue.days)):
			model.act("advance")
			_resolve_free(model)
			model.act("dismiss_report")
	_check(model.state.phase == "season_end" and model.state.completed.size() == 8, "Eight completed fairs end the season before the calendar limit")
	_check(float(model.state.season_summary.equipment_value) > 0, "Career scoring recognises investment in equipment")
	_check("long_road" in model.state.achievements and "full_crew" in model.state.achievements, "Season and staff achievements are reachable")
	var relationships: Dictionary = model.state.relationships.duplicate(true)
	var cash := float(model.state.cash)
	var staff_count: int = model.state.staff.size()
	_check(bool(model.act("next_season").ok), "A successful company can play another season")
	_check(model.state.season == 2 and model.state.day == 1 and model.state.phase == "planning", "Next season resets the calendar")
	_check(model.state.completed.is_empty() and model.state.relationships == relationships, "New season resets visits while preserving town memories")
	_check(model.state.cash == cash and model.state.staff.size() == staff_count and model.state.fryer_tier == 3, "Company assets and team persist")
	_check("golden_hour" in model.state.achievements and model.state.records.size() == 1, "Career badge and prior season record persist")
	_check(bool(model.act("book", {"id": "willowbank"}).ok), "A returning town can be booked again next season")
	_resolve_free(model)
	model.act("advance")
	_resolve_free(model)
	_check(float(model.state.relationships.get("Willowbank", 0)) >= float(relationships.get("Willowbank", 0)), "Returning trade can strengthen an existing town relationship")

func _test_owner_only_opening() -> void:
	for seed_value in [19, 77, 2026, 9911]:
		var model = _new(seed_value)
		model.act("set_policy", {"id": "restock", "enabled": true})
		model.act("set_policy", {"id": "service", "enabled": true})
		for venue_id in ["willowbank", "brass_bell"]:
			_check(bool(model.act("book", {"id": venue_id}).ok), "Owner can afford first two venue bookings")
			_resolve_free(model)
			while not str(model.state.booked_id).is_empty():
				model.act("advance")
				_resolve_free(model)
				model.act("dismiss_report")
		_check(model.state.completed.size() == 2 and model.state.staff.is_empty(), "First two fairs complete without employees")
		_check(model.state.cash > 2800 and model.state.debt == 0, "First two fairs grow starting cash without loans")
		print("OWNER seed=%d first_two_cash=%.2f profit=%.2f" % [seed_value, float(model.state.cash), float(model.state.stats.total_profit)])

func _test_bankruptcy_and_recovery() -> void:
	var recovery = _new()
	recovery.state.cash = 0.0
	recovery.state.stock = 0
	_check(bool(recovery.act("loan", {"amount": 500}).ok), "An empty pantry and zero cash still allow recovery credit")
	_check(bool(recovery.act("buy_stock", {"amount": 100}).ok), "Recovery credit can buy supplies")
	recovery.act("advance")
	_quiet_event(recovery, "trading")
	recovery.act("decide", {"choice": 0})
	recovery.act("dismiss_report")
	_check(recovery.state.phase == "planning" and recovery.state.cash > 400, "A roadside day can rebuild available cash")
	var bankrupt = _new()
	bankrupt.state.cash = -900.0
	bankrupt.state.debt = 2000.0
	bankrupt.state.stock = 0
	bankrupt.act("advance")
	_quiet_event(bankrupt, "trading")
	bankrupt.act("decide", {"choice": 0})
	bankrupt.act("dismiss_report")
	_check(bankrupt.state.phase == "bankrupt", "Unrecoverable finances lead to an explicit company ending")
	_check(not bool(bankrupt.act("next_season").ok), "Bankrupt companies cannot erase closure by starting another season")
	_check(bankrupt.primary_action().action == "restart", "Bankruptcy exposes a clear restart action")
	bankrupt.new_run("Second Chance", 2)
	_check(bankrupt.state.phase == "planning" and bankrupt.state.cash == 2800, "Restart creates a genuinely fresh company")
	var late = _new()
	late.state.day = 35
	_check(not bool(late.act("book", {"id": "willowbank"}).ok), "A stay cannot be booked if travel and all trading days do not fit")

func _test_stock_costs_and_permanent_recipes() -> void:
	var model = _new()
	model.act("book", {"id": "willowbank"})
	_quiet_event(model, "travel", {"stock": -20, "rep": 10})
	model.state.stock = 0
	var before := _snapshot(model)
	_check(not bool(model.act("decide", {"choice": 0}).ok), "Stock-cost choices cannot donate nonexistent portions")
	_check(before == _snapshot(model), "Rejected stock donation grants no reputation or calendar advance")
	_quiet_event(model, "travel", {"rep": 60})
	model.act("decide", {"choice": 0})
	_check("cocoa" in model.state.unlocked_recipes, "Reputation milestones permanently unlock advanced recipes")
	model.state.rep = 10.0
	_check(bool(model.act("set_recipe", {"id": "cocoa"}).ok), "A setback cannot erase a previously learned recipe")
	var loaded = Model.new()
	_check(loaded.from_save(JSON.parse_string(JSON.stringify(model.to_save()))), "Learned recipes survive a save round-trip")
	_check("cocoa" in loaded.state.unlocked_recipes, "Save preserves recipes earned before reputation fell")

func _test_progression_and_price_tradeoffs() -> void:
	var profits: Dictionary = {}
	for price in [3.0, 6.0, 8.0, 14.0]:
		var model = _new(44)
		model.act("book", {"id": "willowbank"})
		_quiet_event(model, "travel")
		model.act("decide", {"choice": 0})
		model.act("set_price", {"value": price})
		model.act("advance")
		_quiet_event(model, "trading")
		model.act("decide", {"choice": 0})
		profits[price] = float(model.state.last_report.profit)
		_check(float(profits[price]) > 0, "Opening fair can earn an operating profit at price $%.0f" % price)
	_check(float(profits[14.0]) < float(profits[6.0]) and float(profits[14.0]) < float(profits[8.0]), "Maximum price is not a dominant strategy; demand falls")
	for seed_value in [42, 2026, 9911]:
		var model = _new(seed_value)
		model.act("set_price", {"value": 7.0})
		model.act("set_policy", {"id": "restock", "enabled": true})
		model.act("set_policy", {"id": "service", "enabled": true})
		var turn := 0
		while model.state.phase == "planning" and turn < 70:
			turn += 1
			var stops: int = model.state.completed.size()
			if stops >= 2 and model.state.staff.is_empty(): model.act("hire", {"id": "bea"})
			if stops >= 2 and int(model.state.fryer_tier) == 0 and float(model.state.cash) > 2900: model.act("upgrade", {"id": "fryer"})
			if stops >= 4 and model.state.staff.size() == 1: model.act("hire", {"id": "kit"})
			if stops >= 4 and int(model.state.truck_tier) == 0 and float(model.state.cash) > 3600: model.act("upgrade", {"id": "truck"})
			if stops >= 5 and int(model.state.fryer_tier) == 1 and float(model.state.cash) > 5600: model.act("upgrade", {"id": "fryer"})
			if float(model.state.rep) < 55 and float(model.state.cash) > 900: model.act("set_quality", {"id": "premium"})
			else: model.act("set_quality", {"id": "standard"})
			if str(model.state.booked_id).is_empty() and stops < 8:
				var offer: Dictionary = model.venue_offers()[stops]
				if bool(offer.can_book):
					model.act("book", {"id": offer.id})
					_resolve_free(model)
					continue
			if not str(model.state.booked_id).is_empty(): model.act("minigame", {"score": 0.8})
			model.act("advance")
			if model.state.phase == "event": _resolve_free(model)
			if model.state.phase == "report": model.act("dismiss_report")
		_check(model.state.phase == "season_end", "Natural-capital progression reaches a season ending")
		_check(model.state.completed.size() >= 6 and model.state.cash > 0, "Sensible investment supports at least six full fairs from the real starting balance")
		print("PROGRESSION seed=%d stops=%d days=%d cash=%.2f rep=%.1f tiers=%d/%d" % [seed_value, model.state.completed.size(), int(model.state.day), float(model.state.cash), float(model.state.rep), int(model.state.truck_tier), int(model.state.fryer_tier)])

func _test_fee_rounding_and_risk_affordability() -> void:
	var model = _new(54)
	var total: float = model.venue_offers()[1].total_cost
	model.act("set_policy", {"id": "restock", "enabled": true})
	model.act("book", {"id": "brass_bell"})
	_quiet_event(model, "travel")
	model.act("decide", {"choice": 0})
	var allocated := 0.0
	for day in range(3):
		model.act("advance")
		_quiet_event(model, "trading")
		model.act("decide", {"choice": 0})
		allocated += float(model.state.last_report.prepaid_fees)
		model.act("dismiss_report")
	_check(is_equal_approx(allocated, total), "Three-day booking allocates every prepaid cent exactly once")
	model.state.cash = 30.0
	_quiet_event(model, "trading", {"cash": -20})
	model.state.event.choices[0].risk = {"chance": 0.5, "effects": {"cash": -20}, "summary": "Another $20 might be lost."}
	var before := _snapshot(model)
	_check(not bool(model.act("decide", {"choice": 0}).ok), "A choice reserves enough cash for its disclosed downside")
	_check(before == _snapshot(model), "Unaffordable risk does not consume RNG or apply its certain cost")
	var loaded = Model.new()
	_check(loaded.from_save(JSON.parse_string(JSON.stringify(model.to_save()))), "An affordable-or-not pending choice can be saved without being rerolled")
