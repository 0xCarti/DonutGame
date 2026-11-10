extends SceneTree
const Model = preload("res://scripts/circuit_model.gd")
const Content = preload("res://scripts/circuit_content.gd")
const SEEDS := [1, 19, 42, 77, 2026, 9911]
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var record_only := "--record-only" in args
	var results: Array = []
	for strategy in ["careless", "overpriced", "roadside", "prudent", "reckless"]:
		for seed_value in SEEDS: results.append(_season(strategy, seed_value))
	var grouped := {}
	for strategy in ["careless", "overpriced", "roadside", "prudent", "reckless"]:
		var summary := {"strategy":strategy, "runs":0, "cash":0.0, "profit":0.0, "rep":0.0, "stops":0.0, "loss_days":0.0, "waste":0.0, "seasons_finished":0}
		for result in results:
			if result.strategy != strategy: continue
			summary.runs += 1
			for key in ["cash", "profit", "rep", "stops", "loss_days", "waste"]: summary[key] += float(result[key])
			if result.phase == "season_end": summary.seasons_finished += 1
		for key in ["cash", "profit", "rep", "stops", "loss_days", "waste"]: summary[key] = snappedf(float(summary[key]) / float(summary.runs), 0.01)
		grouped[strategy] = summary
		print("BALANCE " + JSON.stringify(summary))
	if not record_only:
		_check(float(grouped.prudent.stops) > float(grouped.careless.stops), "Sensible investment reaches more fairs than neglect")
		_check(float(grouped.prudent.profit) > float(grouped.careless.profit), "Sensible management earns higher operating profit than neglect")
		_check(float(grouped.reckless.loss_days) > float(grouped.prudent.loss_days), "Overstaffing, underpricing and neglect cause more losing days")
		_check(int(grouped.prudent.seasons_finished) == SEEDS.size(), "A sensible strategy can finish every seeded season")
		_check(float(grouped.careless.loss_days) >= 5, "Neglect has material losing days")
		_test_economy_edges()
	var report := {"seeds":SEEDS, "strategies":results, "averages":grouped, "checks":checks, "failures":failures}
	var output_index := args.find("--output")
	if output_index >= 0 and output_index + 1 < args.size():
		var output := FileAccess.open(args[output_index + 1], FileAccess.WRITE)
		if output: output.store_string(JSON.stringify(report, "\t"))
	if failures.is_empty():
		print("PASS: %d balance checks; %d seeded strategy seasons." % [checks, results.size()])
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _new(seed_value: int = 2026):
	var m = Model.new()
	m.new_run("Balance Company", seed_value)
	return m

func _choice(m, prudent: bool) -> int:
	var pick := -1
	var best := -100000.0
	for i in range(m.state.event.choices.size()):
		var choice: Dictionary = m.state.event.choices[i]
		var effects: Dictionary = choice.get("effects", {})
		var risk: Dictionary = choice.get("risk", {}).get("effects", {})
		var cost := maxf(0, -float(effects.get("cash", 0))) + maxf(0, -float(risk.get("cash", 0)))
		var stock := maxi(0, -int(effects.get("stock", 0))) + maxi(0, -int(risk.get("stock", 0)))
		if cost > maxf(0, float(m.state.cash)) or stock > int(m.state.stock): continue
		if not prudent and cost == 0: return i
		var score := _effect_score(effects) + float(choice.get("risk", {}).get("chance", 0)) * _effect_score(risk)
		if prudent and cost > maxf(0, float(m.state.cash) - 300): score -= 10000
		if score > best:
			best = score
			pick = i
	return maxi(pick, 0)

func _effect_score(effects: Dictionary) -> float:
	return float(effects.get("cash", 0)) + float(effects.get("rep", 0)) * 35 + float(effects.get("relationship", 0)) * 8 + float(effects.get("fryer", 0)) * 3 + float(effects.get("truck", 0)) * 2 + float(effects.get("demand", 0)) * 100 + float(effects.get("quality", 0)) * 100 - float(effects.get("delay", 0)) * 200 - maxf(0, -float(effects.get("stock", 0))) * 2

func _season(strategy: String, seed_value: int) -> Dictionary:
	var m = _new(seed_value)
	var prudent := strategy == "prudent"
	if strategy != "prudent": m.act("set_policy", {"id":"restock", "enabled":true})
	m.act("set_price", {"value":14.0 if strategy == "overpriced" else 3.0 if strategy == "reckless" else 7.0 if prudent else 6.0})
	if strategy == "reckless":
		m.act("hire", {"id":"bea"})
		m.act("hire", {"id":"nell"})
		m.act("set_quality", {"id":"premium"})
	var losses := 0
	var waste := 0
	var iterations := 0
	while str(m.state.phase) not in ["season_end", "bankrupt"] and iterations < 200:
		iterations += 1
		match str(m.state.phase):
			"event":
				_check(bool(m.act("decide", {"choice":_choice(m, prudent)}).ok), "Strategy resolves affordable event")
			"report":
				if float(m.state.last_report.profit) < 0: losses += 1
				waste += int(m.state.last_report.stock_waste)
				m.act("dismiss_report")
			"planning":
				if prudent: _prepare_prudent(m)
				if str(m.state.booked_id).is_empty() and strategy != "roadside":
					var selected := ""
					for offer in m.venue_offers():
						if not bool(offer.can_book): continue
						if prudent and float(offer.total_cost) > float(m.state.cash) - 400: continue
						selected = str(offer.id)
						if strategy != "reckless": break
					if not selected.is_empty():
						m.act("book", {"id":selected})
						continue
				if prudent and not str(m.state.booked_id).is_empty():
					m.act("minigame", {"score":0.65})
					for contract in m.contract_offers():
						if bool(contract.complete) and not bool(contract.claimed): m.act("claim_contract", {"id":contract.id})
				m.act("advance")
	_check(iterations < 200, "Strategy reaches a bounded season end")
	return {"strategy":strategy, "seed":seed_value, "phase":str(m.state.phase), "day":int(m.state.day), "cash":float(m.state.cash), "profit":float(m.state.stats.total_profit), "rep":float(m.state.rep), "stops":m.state.completed.size(), "loss_days":losses, "waste":waste, "fryer":float(m.state.fryer), "crew":m.state.staff.size(), "fryer_tier":int(m.state.fryer_tier), "truck_tier":int(m.state.truck_tier)}

func _prepare_prudent(m) -> void:
	var stops: int = m.state.completed.size()
	for target in ["fryer", "truck"]:
		if float(m.state[target]) < (65 if target == "fryer" else 45): m.act("service", {"id":target})
	if stops >= 2 and int(m.state.fryer_tier) == 0 and float(m.state.cash) > 3000: m.act("upgrade", {"id":"fryer"})
	if int(m.state.fryer_tier) > 0 and m.state.staff.is_empty(): m.act("hire", {"id":"bea"})
	if stops >= 4 and m.state.staff.size() == 1 and float(m.state.cash) > 2300: m.act("hire", {"id":"kit"})
	if stops >= 4 and int(m.state.truck_tier) == 0 and float(m.state.cash) > 3800: m.act("upgrade", {"id":"truck"})
	if stops >= 5 and int(m.state.fryer_tier) == 1 and float(m.state.cash) > 6500: m.act("upgrade", {"id":"fryer"})
	m.act("set_quality", {"id":"premium" if float(m.state.rep) < 55 and float(m.state.cash) > 1400 else "standard"})
	var venue: Dictionary = Content.find(Content.VENUES, str(m.state.booked_id))
	var chosen := "classic"
	for recipe in Content.RECIPES:
		if str(recipe.id) not in m.state.unlocked_recipes: continue
		if str(recipe.id) == str(venue.get("flavor", "classic")): chosen = str(recipe.id)
	m.act("set_recipe", {"id":chosen})
	var storage := int(Content.TRUCKS[int(m.state.truck_tier)].capacity)
	var target := mini(storage, int(ceil(float(venue.get("demand", 60)) * 1.2)))
	var amount := maxi(0, mini(target - int(m.state.stock), int(float(m.state.cash) - 300)))
	if amount > 0: m.act("buy_stock", {"amount":amount})

func _test_economy_edges() -> void:
	var m = _new()
	var before := JSON.stringify(m.to_save(), "", true)
	var info: Dictionary = m.pricing_info()
	_check(info.unit_cost == 1.85 and info.unit_margin == 4.15 and info.price_factor == 1, "Menu exposes exact default cost, contribution and demand factor")
	_check(before == JSON.stringify(m.to_save(), "", true), "Pricing preview does not mutate save or consume RNG")
	m.act("set_quality", {"id":"budget"})
	_check(m.pricing_info().unit_cost == 1.55 and m.pricing_info().quality_review < 0, "Budget quality genuinely discounts ingredients and harms reviews")
	m.act("set_quality", {"id":"premium"})
	_check(m.pricing_info().unit_cost == 2.7 and is_equal_approx(float(m.pricing_info().quality_review), 0.9), "Premium ingredient cost and review contribution are explicit")
	m.act("set_price", {"value":14.0})
	_check(float(m.pricing_info().price_factor) < 0.15, "Maximum price sharply shrinks potential audience")
	m.act("set_price", {"value":3.0})
	_check(is_equal_approx(float(m.pricing_info().price_factor), 1.3), "Deep discounts have a bounded audience bonus")
	for quality in ["budget", "standard", "premium"]:
		m = _new()
		m.act("set_quality", {"id":quality})
		var cash := float(m.state.cash)
		info = m.pricing_info()
		_quiet_trade(m)
		var report: Dictionary = m.state.last_report
		_check(is_equal_approx(float(report.unit_ingredient_cost), float(info.unit_cost)), "Trade uses the exact previewed ingredient cost: " + quality)
		_check(is_equal_approx(float(report.extra_ingredients), snappedf(float(report.sold) * (float(info.unit_cost) - 1.0), 0.01)), "Extras charged only for sold portions: " + quality)
		_check(is_equal_approx(float(report.prepaid_stock), float(report.sold) + float(report.stock_waste)), "Spoiled base stock is allocated once: " + quality)
		_check(is_equal_approx(float(m.state.cash) - cash, float(report.cash_delta)), "Revised costs still reconcile with cash: " + quality)
		_check(absf(float(report.cash_delta) - float(report.profit) - float(report.prepaid_stock) - float(report.prepaid_fees)) < 0.02, "Revised costs keep cash/profit accounting exact: " + quality)
		_roundtrip(m)
	var broken = _new()
	broken.state.fryer = 0.0
	_quiet_trade(broken)
	_check(broken.state.last_report.capacity == 0 and broken.state.last_report.sold == 0, "Broken equipment produces no magical residual output")
	_check(broken.state.last_report.profit < 0 and broken.state.last_report.rep_change < 0, "Opening with broken equipment causes visible loss and review damage")
	broken.act("dismiss_report")
	_check(bool(broken.act("service", {"id":"fryer"}).ok), "Cash or credit can restore a broken fryer")
	_quiet_trade(broken)
	_check(broken.state.last_report.sold > 0 and broken.state.last_report.profit > 0, "Service restores a viable roadside recovery day")
	var steady = _new(18)
	var relaxed = _new(18)
	relaxed.state.difficulty = "relaxed"
	_quiet_trade(steady)
	_quiet_trade(relaxed)
	_check(float(relaxed.state.fryer) > float(steady.state.fryer), "Relaxed companies retain slower equipment wear")
	_check(int(relaxed.state.last_report.stock_waste) < int(steady.state.last_report.stock_waste), "Relaxed companies retain gentler spoilage")
	_check(relaxed.state.last_report.spoilage_rate == 0.015 and steady.state.last_report.spoilage_rate == 0.06, "Reports disclose the actual mode's spoilage rate")
	for mood in [10.0, 90.0]:
		m = _new(44)
		m.state.cash = 20000
		m.act("upgrade", {"id":"fryer"})
		m.act("hire", {"id":"bea"})
		m.state.staff[0].reliability = 100.0
		m.state.staff[0].morale = mood
		m.state.fryer = 100
		_quiet_trade(m)
		if mood == 10:
			info = {"capacity":int(m.state.last_report.capacity)}
		else: _check(int(m.state.last_report.capacity) > int(info.capacity), "Crew morale materially changes actual production capacity")
	var crowded = _new()
	crowded.state.booked_id = "moonwheel"
	crowded.state.fryer = 25
	_quiet_trade(crowded)
	_check(float(crowded.state.last_report.service_review_penalty) > 0, "An underserved fair crowd affects reviews")
	_check(str(crowded.state.last_report.drivers[1].id) == "service", "Material service review penalty is visible in the first three drivers")
	_roundtrip(crowded)
	var stockpile = _new()
	stockpile.state.stock = 260
	_quiet_trade(stockpile)
	var modest = _new()
	modest.state.stock = 35
	_quiet_trade(modest)
	_check(int(stockpile.state.last_report.sold) == int(modest.state.last_report.sold), "Excess stock does not create customers")
	_check(int(stockpile.state.last_report.stock_waste) > int(modest.state.last_report.stock_waste), "Bulk overstock causes material avoidable waste")
	var saved: Dictionary = _new().to_save()
	for key in ["unit_ingredient_cost", "spoilage_rate", "service_review_penalty"]:
		var invalid := saved.duplicate(true)
		invalid.last_report[key] = NAN
		var loader = _new()
		_check(not loader.from_save(invalid), "Malformed new report evidence is rejected: " + key)
	_test_legacy_save()

func _quiet_trade(m) -> void:
	m.act("advance")
	m.state.weather = "Clear"
	m.state.event.choices = [{"label":"Continue", "detail":"No cost", "result":"Quiet trade", "effects":{}}]
	_check(bool(m.act("decide", {"choice":0}).ok), "Quiet trade executes")

func _roundtrip(m) -> void:
	var loaded = Model.new()
	_check(loaded.from_save(JSON.parse_string(JSON.stringify(m.to_save()))), "Updated economics save loads")
	_check(JSON.stringify(JSON.parse_string(JSON.stringify(loaded.to_save())), "", true) == JSON.stringify(JSON.parse_string(JSON.stringify(m.to_save())), "", true), "Updated economics save preserves exact state and RNG")

func _test_legacy_save() -> void:
	# Exact phone-emulator save from v0.3.0; unavailable in source-only handoffs.
	var path := ProjectSettings.globalize_path("res://").path_join("../playtest-reports/circuit/0.3.0/android/after-cold-restart-ready-save.json")
	if not FileAccess.file_exists(path): return
	var wrapper: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var original: Dictionary = wrapper.model
	var loaded = Model.new()
	_check(loaded.from_save(original), "Real v0.3.0 company loads into harder rules")
	for key in original:
		_check(JSON.stringify(loaded.state[key], "", true) == JSON.stringify(original[key], "", true), "Legacy state is untouched before any new action: " + str(key))
	var before := JSON.stringify(loaded.to_save(), "", true)
	loaded.pricing_info()
	_check(before == JSON.stringify(loaded.to_save(), "", true), "Legacy company is not charged or reset by viewing new pricing")
	print("LEGACY v0.3.0 phone-emulator save: all %d original state fields unchanged; day%d cash$%.2f stock%d rep%.2f." % [original.size(), int(loaded.state.day), float(loaded.state.cash), int(loaded.state.stock), float(loaded.state.rep)])
