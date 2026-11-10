extends SceneTree
const Model = preload("res://scripts/circuit_model.gd")
const Company = preload("res://scripts/circuit_company.gd")
const Content = preload("res://scripts/circuit_content.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_migration_and_reads()
	_activities()
	_negative_cash_options()
	_contracts()
	_routes()
	_crew()
	_crew_chapters()
	_reports()
	_validation()
	if failures.is_empty():
		print("PASS: %d company checks; contextual activities, route dates, season contracts, crew cooldowns, migration and truthful report drivers." % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d failures in %d company checks." % [failures.size(), checks])
		quit(1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _new():
	var m = Model.new()
	m.new_run("New Road", 2468)
	return m

func _snapshot(m) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(m.to_save())), "", true)

func _reject(m, action: String, args: Dictionary) -> void:
	var before := _snapshot(m)
	_check(not bool(m.act(action, args).ok), "Reject " + action + " " + str(args))
	_check(_snapshot(m) == before, "Rejected action is atomic: " + action)

func _quiet(m) -> void:
	m.state.event.choices = [{"label":"Continue", "detail":"No cost", "result":"A quiet opening.", "effects":{}}]
	_check(bool(m.act("decide", {"choice":0}).ok), "Resolve quiet pending event")

func _prepare(m) -> void:
	_check(bool(m.act("book", {"id":"willowbank"}).ok), "Book first fair")
	_quiet(m)

func _offer(m, kind: String) -> Dictionary:
	for offer in m.activity_offers():
		if offer.kind == kind: return offer
	return {}

func _roundtrip(m) -> void:
	var loaded = Model.new()
	_check(loaded.from_save(JSON.parse_string(JSON.stringify(m.to_save()))), "Current expansion save roundtrips")
	_check(_snapshot(loaded) == _snapshot(m), "Roundtrip preserves extension and RNG exactly")

func _migration_and_reads() -> void:
	var m = _new()
	var old: Dictionary = m.to_save()
	old.erase("circuit")
	old.stats.total_sold = 900
	old.stats.total_profit = 3000
	old.stats.completed_stops = 7
	var loaded = Model.new()
	_check(loaded.from_save(old), "Old v0.2 save loads without extension")
	for contract in loaded.contract_offers(): _check(float(contract.progress) == 0, "Migration gives no retroactive contract claims")
	var before := _snapshot(loaded)
	for i in range(20):
		loaded.activity_offers()
		loaded.contract_offers()
		loaded.itinerary()
		loaded.crew_moments()
		loaded.staff_personality("bea")
	_check(before == _snapshot(loaded), "All read APIs leave money, save and RNG unchanged")
	_check(loaded.state.rng_state == old.rng_state, "Migration does not draw random values")
	_roundtrip(loaded)
	_check(_offer(m, "orders").is_empty() and _offer(m, "inspection").is_empty(), "Orders and inspection require a booked fair")
	_check(not _offer(m, "repair").is_empty(), "Worn starting van offers optional repair")
	for def in Company.CONTRACTS:
		_check(not str(def.decoration_name).is_empty() and float(def.goal) > 0 and float(def.cash_reward) > 0, "Authored objective has an earned reward: " + str(def.id))

func _activities() -> void:
	var m = _new()
	var offer := _offer(m, "repair")
	var before_rng: String = m.state.rng_state
	for args in [{"id":"forged", "score":1.0}, {"id":offer.id,"mode":"magic","score":1.0}, {"id":offer.id,"score":NAN}, {"id":offer.id,"score":-0.01}, {"id":offer.id,"score":1.01}, {"id":offer.id,"score":"1"}, {"id":offer.id,"mode":"delegate"}]: _reject(m, "activity", args)
	var result: Dictionary = m.act("activity", {"id":offer.id,"mode":"self","score":0.5})
	_check(result.ok and is_equal_approx(float(m.state.truck), 87), "Repair restores score times 24 condition")
	_check(m.state.cash == 2785 and result.activity.cost == 15, "Self repair charges disclosed parts")
	_check(result.activity.effects[1].value == 12, "Repair evidence stores actual condition delta")
	_check(m.state.rng_state == before_rng, "Activities do not perturb event RNG")
	_reject(m, "activity", {"id":offer.id,"score":1.0})
	m.state.truck = 30.0
	_check(_offer(m, "repair").is_empty(), "Further wear cannot replay repair in same three-day window")
	m.state.day = 4
	_check(not _offer(m, "repair").is_empty(), "Repair reopens in a later worn-equipment context")
	_roundtrip(m)
	_prepare(m)
	var orders := _offer(m, "orders")
	_check(not orders.is_empty(), "Booked fair offers order memory")
	_check(bool(m.act("activity", {"id":orders.id,"score":1.0}).ok), "Complete order memory")
	_check(is_equal_approx(float(m.state.day_modifiers.demand), 0.08), "Perfect orders earn eight percent appeal")
	_check(bool(m.state.carry_travel_modifiers), "Order appeal survives opening reset")
	_roundtrip(m)
	_check(bool(m.act("advance").ok), "Open stand after preparation")
	_check(is_equal_approx(float(m.state.day_modifiers.demand), 0.08), "Opening retains preparation appeal")
	_reject(m, "activity", {"id":orders.id,"score":1.0})
	_quiet(m)
	_check(is_equal_approx(float(m.state.last_report.used_modifiers.demand), 0.08), "Report records exact used activity appeal")
	_check(float(m.state.day_modifiers.demand) == 0, "Appeal expires after one trading day")
	_check(m.state.last_report.event_outcomes.size() >= 3, "Activity evidence joins travel and trading evidence")
	_roundtrip(m)
	m.act("dismiss_report")
	_check(_offer(m, "orders").is_empty(), "Orders cannot replay on the second day of same fair")
	var inspection := _offer(m, "inspection")
	m.state.rep = 99.8
	m.state.fryer = 99.0
	result = m.act("activity", {"id":inspection.id,"score":1.0})
	_check(result.ok and m.state.rep == 100 and m.state.fryer == 100, "Inspection rewards clamp to valid bounds")
	_check(is_equal_approx(float(result.activity.effects[1].value), 0.2) and is_equal_approx(float(result.activity.effects[2].value), 1), "Inspection outcome reports actual clamped gains")
	_roundtrip(m)
	var delegated = _new()
	delegated.act("hire", {"id":"ravi"})
	var repair := _offer(delegated, "repair")
	var expected := float(repair.delegate_score)
	var morale := float(delegated.state.staff[0].morale)
	result = delegated.act("activity", {"id":repair.id,"mode":"delegate","score":1.0})
	_check(result.ok and is_equal_approx(float(result.activity.score), expected), "Delegation ignores client score and uses actual employee skills")
	_check(delegated.state.staff[0].morale == morale - 2, "Delegation has disclosed helper morale cost")
	_roundtrip(delegated)
	var resting = _new()
	resting.act("hire", {"id":"ravi"})
	resting.act("rest", {"id":"ravi"})
	_check(not bool(_offer(resting, "repair").can_delegate), "Resting crew cannot be delegated")
	_reject(resting, "activity", {"id":_offer(resting, "repair").id,"mode":"delegate","staff_id":"ravi"})
	var paid = _new()
	result = paid.act("activity", {"id":_offer(paid,"repair").id,"mode":"help","score":0.0})
	_check(result.ok and paid.state.cash == 2730 and paid.state.truck == 99, "Paid specialist guarantees disclosed repair for exact price")
	_roundtrip(paid)
	var poor = _new()
	poor.state.cash = 0.0
	_reject(poor, "activity", {"id":_offer(poor,"repair").id,"mode":"self","score":1.0})
	_reject(poor, "activity", {"id":_offer(poor,"repair").id,"mode":"help"})
	var zero = _new()
	_prepare(zero)
	var cash := float(zero.state.cash)
	result = zero.act("activity", {"id":_offer(zero,"orders").id,"score":0.0})
	_check(result.ok and float(zero.state.cash) == cash and float(zero.state.day_modifiers.demand) == 0, "Failed free order game has no hidden money penalty or bonus")
	_roundtrip(zero)

func _negative_cash_options() -> void:
	var m = _new()
	m.act("hire", {"id":"bea"})
	_prepare(m)
	m.state.cash = -50.0
	var orders := _offer(m, "orders")
	var inspection := _offer(m, "inspection")
	var repair := _offer(m, "repair")
	_check(bool(orders.can_self) and bool(orders.can_delegate), "Free order options stay available during negative-cash recovery")
	_check(bool(inspection.can_self) and bool(inspection.can_delegate), "Free inspection options stay available during negative-cash recovery")
	_check(not bool(orders.can_help) and not bool(repair.can_self) and not bool(repair.can_delegate), "Negative cash never authorizes paid help or repair parts")
	_reject(m, "activity", {"id":orders.id, "mode":"help"})
	_reject(m, "activity", {"id":repair.id, "mode":"self", "score":1.0})
	_reject(m, "activity", {"id":repair.id, "mode":"delegate"})
	var moment: Dictionary = m.crew_moments()[0]
	_reject(m, "crew_decide", {"id":moment.id, "choice":1})
	_check(bool(m.act("crew_decide", {"id":moment.id, "choice":0}).ok), "Free crew conversation is usable below zero cash")
	_check(m.state.cash == -50, "Free crew conversation does not spend money")
	_check(bool(m.act("activity", {"id":inspection.id, "mode":"delegate"}).ok), "A free delegated inspection works during recovery")
	_check(m.state.cash == -50, "Free delegated inspection charges no invisible fee")
	_check(bool(m.act("activity", {"id":orders.id, "mode":"self", "score":1.0}).ok), "Self-run orders remain a free recovery opportunity")
	_check(m.state.cash == -15, "Tips improve negative cash by their exact earned amount")
	_roundtrip(m)

func _contracts() -> void:
	var m = _new()
	_check(m.contract_offers().size() == 3, "Exactly three active season contracts")
	_reject(m, "claim_contract", {"id":"warm_bags"})
	m.state.stats.total_sold = 250
	var cash := float(m.state.cash)
	_check(bool(m.act("claim_contract", {"id":"warm_bags"}).ok), "Completed contract can be claimed")
	_check(m.state.cash == cash + 120 and "bunting" in m.state.circuit.decorations, "Claim awards exact cash and earned decoration")
	_reject(m, "claim_contract", {"id":"warm_bags"})
	_roundtrip(m)
	var loaded = Model.new()
	loaded.from_save(m.to_save())
	_reject(loaded, "claim_contract", {"id":"warm_bags"})
	m.state.phase = "season_end"
	m.state.stats.completed_stops = 2
	_check(bool(m.act("claim_contract", {"id":"familiar_roads"}).ok), "Completed final-day contracts can be claimed at season end")
	_check(bool(m.act("next_season").ok), "Begin next season")
	_check(m.state.circuit.decorations.size() == 2, "Earned decorations persist across seasons")
	_check(m.state.circuit.contracts[0].id == "rainy_fund", "Next season rotates to new objective set")
	for contract in m.contract_offers(): _check(float(contract.progress) == 0 and not bool(contract.claimed), "New season starts with current baselines")
	_roundtrip(m)
	m.state.cash = 10000
	m.act("hire", {"id":"bea"})
	m.act("train", {"id":"bea"})
	_check(m.state.circuit.metrics.training == 1, "Actual training advances contract metric")
	m.act("upgrade", {"id":"stand"})
	_check(m.state.circuit.metrics.upgrades == 1, "Purchased upgrade advances contract metric")
	_prepare(m)
	m.act("minigame", {"score":0.9})
	_check(m.state.circuit.metrics.perfect == 1, "Existing batch game counts toward golden-touch objective")
	_roundtrip(m)

func _routes() -> void:
	var m = _new()
	var cash := float(m.state.cash)
	for id in ["willowbank", "brass_bell", "juniper"]: _check(bool(m.act("plan_stop", {"id":id}).ok), "Add planned stop " + id)
	_check(m.state.cash == cash, "Planning spends no booking money")
	var rows: Array = m.itinerary()
	_check(rows[0].travel_day == 1 and rows[0].start_day == 2 and rows[0].end_day == 3, "First route leg includes travel and full stay")
	_check(rows[1].travel_day == 4 and rows[1].start_day == 5 and rows[1].end_day == 7, "Second route leg follows first fair without overlap")
	_reject(m, "plan_stop", {"id":"moonwheel"})
	_reject(m, "plan_stop", {"id":"willowbank"})
	_reject(m, "move_stop", {"id":"willowbank", "direction":-1})
	_reject(m, "move_stop", {"id":"juniper", "direction":1})
	_reject(m, "move_stop", {"id":"juniper", "direction":0.5})
	_check(bool(m.act("move_stop", {"id":"juniper", "direction":-1}).ok), "Reorder route")
	_check(m.state.circuit.itinerary == ["willowbank", "juniper", "brass_bell"], "Route order changes exactly one step")
	_check(bool(m.act("book", {"id":"willowbank"}).ok), "Book planned route head")
	_check(m.state.circuit.itinerary == ["juniper", "brass_bell"], "Booking removes only booked planned stop")
	_check(m.itinerary()[0].travel_day == 4, "Pending travel includes current fair arrival day")
	_quiet(m)
	_check(m.itinerary()[0].travel_day == 4, "Arrival keeps route estimate stable")
	_roundtrip(m)
	m.act("unplan_stop", {"id":"brass_bell"})
	_check(m.state.circuit.itinerary == ["juniper"], "Removing a plan leaves actual booking untouched")
	_check(m.state.booked_id == "willowbank", "Unplanning preserves current fair")
	m.state.day = 35
	_check(not bool(m.itinerary()[0].fits), "Route warns when full stay cannot fit remaining season")
	var ambitious = _new()
	ambitious.act("plan_stop", {"id":"grand_circuit"})
	_check("reputation" in str(ambitious.itinerary()[0].reason), "Aspirational plans show reputation gate")
	_reject(ambitious, "book", {"id":"grand_circuit"})
	_roundtrip(ambitious)

func _crew() -> void:
	var m = _new()
	_check(m.crew_moments().is_empty(), "Owner-only company has no invented employee moments")
	m.act("hire", {"id":"bea"})
	m.act("hire", {"id":"nell"})
	var moment: Dictionary = m.crew_moments()[0]
	_check(moment.title == "The regulars' notebook" and moment.staff_ids == ["bea", "nell"], "Authored moment uses current named crew")
	var bea_morale := float(m.state.staff[0].morale)
	var nell_morale := float(m.state.staff[1].morale)
	var result: Dictionary = m.act("crew_decide", {"id":moment.id, "choice":2})
	_check(result.ok and m.state.staff[0].morale == bea_morale + 3 and m.state.staff[1].morale == nell_morale + 3, "Shared moment benefits exactly both crew members")
	_check(m.staff_personality("bea").friends[0].bond == 12, "Friendship records exact earned bond")
	_check(m.crew_moments().is_empty(), "Both participating crew enter cooldown")
	_reject(m, "crew_decide", {"id":moment.id, "choice":2})
	_roundtrip(m)
	m.state.day = 5
	_check(m.crew_moments().is_empty(), "Five-day cooldown cannot resolve early")
	m.state.day = 6
	_check(m.crew_moments().size() == 2, "Crew moments recur after five days")
	_reject(m, "crew_decide", {"id":moment.id, "choice":0})
	m.state.staff[0].morale = 99.0
	m.state.staff[0].loyalty = 99.0
	result = m.act("crew_decide", {"id":m.crew_moments()[0].id, "choice":0})
	_check(result.crew.effects[1].value == 1 and result.crew.effects[2].value == 1, "Crew evidence reports clamped benefits")
	m.act("fire", {"id":"bea"})
	_check(m.state.circuit.friendships.is_empty() and m.state.circuit.last_crew.is_empty(), "Departed crew is removed from active friendships and current moment result")
	_check(m.staff_personality("bea").is_empty() and m.staff_personality("nell").friends.is_empty(), "Profiles show no departed employee relationship")
	m.act("hire", {"id":"bea"})
	_check(m.crew_moments().size() == 1, "Fire and rehire does not bypass personal cooldown")
	_roundtrip(m)
	var poor = _new()
	poor.act("hire", {"id":"ravi"})
	poor.state.cash = 0
	var id := str(poor.crew_moments()[0].id)
	_reject(poor, "crew_decide", {"id":id, "choice":1})
	_reject(poor, "crew_decide", {"id":id, "choice":0.5})
	_reject(poor, "crew_decide", {"id":id, "choice":99})
	_check(bool(poor.act("crew_decide", {"id":id, "choice":0}).ok), "A free crew response is always available")
	_roundtrip(poor)

func _reports() -> void:
	for mode in ["stock", "capacity", "demand"]:
		var m = _new()
		_prepare(m)
		m.state.stock = 1 if mode == "stock" else 260
		m.state.fryer = 5 if mode == "capacity" else 100
		m.state.price = 14 if mode == "demand" else 3
		m.act("advance")
		m.state.weather = "Showers"
		_quiet(m)
		var report: Dictionary = m.state.last_report
		_check(report.drivers[0].id == mode, "Report correctly identifies limiting factor: " + mode)
		_check(report.starting_stock == (1 if mode == "stock" else 260), "Report retains stock before sales/waste")
		var weather_driver: Dictionary = Content.find(report.drivers, "weather")
		_check(not weather_driver.is_empty() and is_equal_approx(float(weather_driver.get("value", 0)), -0.24), "Weather driver reflects actual simulated showers multiplier regardless of warning priority")
		_check(report.sold == mini(int(report.demand), mini(int(report.capacity), int(report.starting_stock))), "Report caps reconcile to actual sales")
		_check(not report.reactions.is_empty(), "Daily report includes contextual customer reaction")
		_roundtrip(m)

func _crew_chapters() -> void:
	var m = _new()
	m.act("hire", {"id":"bea"})
	m.act("hire", {"id":"nell"})
	var first: Dictionary = m.crew_moments()[0]
	m.act("crew_decide", {"id":first.id, "choice":2})
	m.state.day += 5
	var wage_moment: Dictionary = m.crew_moments()[0]
	_check(wage_moment.chapter == 1 and wage_moment.title != first.title, "A recurring employee enters a distinct authored chapter")
	_check("every trading day" in str(wage_moment.choices[1].detail), "Pay rise explicitly discloses recurring wage expense")
	var old_wage := float(m.state.staff[0].wage)
	var old_cash := float(m.state.cash)
	var result: Dictionary = m.act("crew_decide", {"id":wage_moment.id, "choice":1})
	_check(result.ok and m.state.staff[0].wage == old_wage + 4, "Pay rise changes actual guaranteed employee wage")
	_check(m.state.cash == old_cash, "Pay rise has no undisclosed immediate charge")
	_check(result.crew.effects.back().key == "wage" and result.crew.effects.back().value == 4, "Outcome explains recurring wage delta")
	_reject(m, "crew_decide", {"id":wage_moment.id,"choice":1})
	_roundtrip(m)
	_prepare(m)
	m.act("advance")
	_quiet(m)
	_check(m.state.last_report.wages == old_wage + 4 + float(m.state.staff[1].wage), "Daily accounts charge new wage, even if employee is absent")
	m.act("dismiss_report")
	m.state.day = 11
	var lesson: Dictionary = m.crew_moments()[0]
	_check(lesson.chapter == 2 and "usual notebook" in str(lesson.body), "Mentoring chapter remembers the existing friendship")
	var old_skill := float(m.state.staff[0].skill)
	var partner_skill := float(m.state.staff[1].skill)
	old_cash = float(m.state.cash)
	result = m.act("crew_decide", {"id":lesson.id,"choice":2})
	_check(result.ok and m.state.cash == old_cash - 25, "Paired lesson charges exact shared materials cost")
	_check(m.state.staff[0].skill == old_skill + 2 and m.state.staff[1].skill == partner_skill + 2, "Paired lesson improves both real skill ratings")
	_check(m.staff_personality("bea").friends[0].bond == 20, "Mentoring strengthens the existing friendship")
	_roundtrip(m)
	var before_count: int = m.state.circuit.crew_counts.bea
	m.state.phase = "season_end"
	m.act("next_season")
	_check(m.state.circuit.crew_counts.bea == before_count, "Personal story chapters persist into next season")
	_roundtrip(m)
	var legacy: Dictionary = m.to_save()
	legacy.circuit.erase("crew_counts")
	var loaded = Model.new()
	_check(loaded.from_save(legacy) and loaded.state.circuit.crew_counts.is_empty(), "Early expansion saves receive optional story counters")
	_roundtrip(loaded)

func _validation() -> void:
	var m = _new()
	var base: Dictionary = m.to_save()
	var invalid: Array = []
	for key in ["metrics", "baseline", "contracts", "decorations", "itinerary", "resolved_activities", "crew_cooldowns", "friendships", "last_activity", "last_crew"]:
		var bad: Dictionary = base.duplicate(true)
		bad.circuit[key] = "wrong type"
		invalid.append(bad)
	for value in [NAN, INF, -1, "3"]:
		var bad: Dictionary = base.duplicate(true)
		bad.circuit.metrics.activities = value
		invalid.append(bad)
	for route in [["missing"], ["willowbank", "willowbank"], ["willowbank", "brass_bell", "juniper", "moonwheel"]]:
		var bad: Dictionary = base.duplicate(true)
		bad.circuit.itinerary = route
		invalid.append(bad)
	var bad: Dictionary = base.duplicate(true)
	bad.circuit.contracts[1].id = bad.circuit.contracts[0].id
	invalid.append(bad)
	bad = base.duplicate(true)
	bad.circuit.friendships = {"bea:nell":20}
	invalid.append(bad)
	bad = base.duplicate(true)
	bad.circuit.crew_cooldowns.bea = 500
	invalid.append(bad)
	bad = base.duplicate(true)
	bad.circuit.resolved_activities = ["same", "same"]
	invalid.append(bad)
	bad = base.duplicate(true)
	bad.circuit.decorations = ["forged"]
	invalid.append(bad)
	bad = base.duplicate(true)
	bad.circuit.last_activity = {"id":"bad", "kind":"repair", "title":"Bad", "message":"Invalid score", "mode":"self", "score":NAN, "effects":[]}
	invalid.append(bad)
	bad = base.duplicate(true)
	bad.last_report.drivers = [{"id":"bad", "label":"bad", "detail":"bad", "tone":"good", "value":INF}]
	invalid.append(bad)
	for malformed in invalid:
		var loaded = _new()
		var before := _snapshot(loaded)
		_check(not loaded.from_save(malformed), "Malformed optional expansion data is rejected")
		_check(before == _snapshot(loaded), "Invalid load preserves live company")
