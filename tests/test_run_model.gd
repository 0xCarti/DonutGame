extends SceneTree
## Run with: godot --headless --path . --script tests/test_run_model.gd

const Run = preload("res://scripts/run_model.gd")
const UpgradeData = preload("res://scripts/upgrades.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_inputs_and_capacity()
	_test_payouts_and_synergies()
	_test_shop_and_phase_transitions()
	_test_save_and_rng()
	_test_invalid_saves()
	_test_complete_run()
	_test_casual_play()
	print("RUN MODEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.005, "%s (got %.4f, wanted %.4f)" % [message, actual, expected])


func _test_inputs_and_capacity() -> void:
	var model = Run.new()
	model.new_run(42)
	_check(model.phase == "ready", "new run waits for start")
	_check(not model.queue_batch("cinnamon", 0), "closed stand rejects production")
	model.start_shift()
	_check(not model.queue_batch("unknown", 0), "unknown recipe rejected")
	_check(not model.queue_batch("cinnamon", -1), "negative tray rejected")
	_check(not model.queue_batch("cinnamon", 3), "fourth tray rejected")
	_check(model.queue_batch("cinnamon", 0), "first batch accepted")
	_check(model.active.size() == 6 and model.batter == 114, "batch creates six and charges six batter")
	_check(model.next_batch_cost() == 6 and not model.can_queue_batch(), "batch availability includes cooldown")
	_check(not model.queue_batch("cinnamon", 1), "loading cooldown enforced")
	var before: float = model.time_left
	model.tick(NAN)
	model.tick(INF)
	model.tick(-2.0)
	_near(model.time_left, before, "invalid elapsed time cannot change clock")
	model.tick(2.0)
	_check(model.queue_batch("powdered", 1), "second batch accepted after cooldown")
	model.tick(2.0)
	_check(model.queue_batch("cocoa", 2), "third batch accepted")
	model.tick(2.0)
	_check(not model.queue_batch("cocoa", 2), "18-donut active capacity enforced")
	model.tick(12.0)
	_check(model.trays[0].size() == 6 and model.trays[1].size() == 6 and model.trays[2].size() == 6, "all batches land in assigned trays")
	_check(model.active.is_empty(), "landed donuts removed from fryer")
	_check(model.queue_batch("cocoa", 0), "batch can wait behind a full tray")
	model.tick(12.0)
	_check(model.active.size() == 6 and model.trays[0].size() == 6, "full tray blocks without deleting donuts")
	_near(float(model.active[0]["progress"]), 1.0, "blocked donut stays at exit")
	var receipt: Dictionary = model.sell_tray(0)
	_near(float(receipt["amount"]), 48.0, "plain matching cinnamon tray is worth 48")
	_check(int(model.sell_tray(0)["count"]) == 0, "cannot sell a tray twice")
	_near(model.sales, 48.0, "duplicate sale does not change earnings")
	model.tick(0.1)
	_check(model.active.is_empty() and model.trays[0].size() == 6, "blocked donuts land after tray emptied")
	model.batter = 5
	_check(not model.queue_batch("cinnamon", 1), "insufficient batter rejects entire batch")
	_check(int(model.tray_quote(-1)["count"]) == 0 and int(model.sell_tray(9)["count"]) == 0, "invalid sale indexes are harmless")
	model.finish_shift()
	_check(not model.queue_batch("cinnamon", 0), "finished shift rejects batch")
	_check(int(model.sell_tray(0)["count"]) == 0, "finished shift rejects sales")


func _test_payouts_and_synergies() -> void:
	var model = Run.new()
	model.start_shift()
	model.queue_batch("cinnamon", 0)
	model.tick(8.1)
	_check(model.trays[0].size() == 1, "batch lands progressively, not all at once")
	_near(float(model.tray_quote(0)["amount"]), 4.0, "partial tray has no set multiplier")
	model.owned["quick_sale"] = 1
	_near(float(model.tray_quote(0)["amount"]), 5.4, "partial-sale upgrade applies")
	model.tick(3.0)
	model.owned["matching_bonus"] = 1
	_near(float(model.tray_quote(0)["amount"]), 62.4, "matching upgrade increases full set multiplier")
	model.owned["sugar_dust"] = 1
	model.owned["cinnamon_king"] = 1
	_near(float(model.tray_quote(0)["amount"]), 96.88, "recipe, value and set multipliers combine")
	var before: Dictionary = model.to_save()
	model.tray_quote(0)
	model.tray_quote(0)
	_check(model.to_save() == before, "quoting has no side effects")
	model.new_run(2)
	model.owned["assorted_batter"] = 1
	model.start_shift()
	model.queue_batch("cinnamon", 0)
	model.tick(12.0)
	_near(float(model.tray_quote(0)["amount"]), 40.8, "variety pack makes a full mixed tray")
	model.owned["variety_bonus"] = 1
	_near(float(model.tray_quote(0)["amount"]), 61.2, "mixed set upgrade combines with variety pack")
	model.new_run(3)
	model.owned["golden_sixth"] = 1
	model.start_shift()
	model.queue_batch("cinnamon", 0)
	model.tick(12.0)
	_check(int(model.tray_quote(0)["golden"]) == 1, "sixth donut is golden")
	_near(float(model.tray_quote(0)["amount"]), 60.0, "golden donut multiplier applies before tray bonus")
	model.owned["golden_glaze"] = 1
	_near(float(model.tray_quote(0)["amount"]), 68.0, "golden glaze boosts golden donut only")
	model.owned["echo_box"] = 1
	model.sell_tray(0)
	for index in range(2):
		model.queue_batch("cinnamon", 0)
		model.tick(12.0)
		var sale: Dictionary = model.sell_tray(0)
		if index == 1:
			_near(float(sale["amount"]), 91.8, "third full tray echoes 35 percent of previous sale")
	model.new_run(4)
	model.owned["frugal_batter"] = 1
	model.start_shift()
	for index in range(3):
		model.queue_batch("cinnamon", index)
		model.tick(2.0)
	model.tick(12.0)
	model.sell_tray(0)
	model.batter = 0
	_check(model.next_batch_cost() == 0 and model.can_queue_batch(), "UI availability supports free batch at zero batter")
	_check(model.queue_batch("cinnamon", 0), "fourth batch is free even at zero batter")
	_check(model.batter == 0, "free batch does not create negative batter")


func _test_shop_and_phase_transitions() -> void:
	var model = Run.new()
	model.start_shift()
	model.sales = model.target - 0.01
	model.finish_shift()
	_check(model.phase == "lost", "missing quota loses the run")
	var old_credits: int = model.credits
	model.finish_shift()
	_check(model.credits == old_credits, "finish is idempotent")
	model.start_shift()
	_check(model.phase == "lost", "cannot resume lost run without restarting")
	model.new_run(777)
	model.start_shift()
	model.sales = model.target
	model.finish_shift()
	_check(model.phase == "shop", "meeting quota opens shop")
	_check(model.credits == 44, "successful first shift awards earnings separately")
	_check(model.get_shop_offers().size() == 4, "shop offers four distinct upgrades")
	var offers: Array = model.get_shop_offers()
	var first: Dictionary = offers[0]
	model.credits = 0
	_check(not model.buy_upgrade(str(first["id"])), "cannot buy an unaffordable upgrade")
	model.credits = int(first["cost"])
	_check(model.buy_upgrade(str(first["id"])), "affordable offered upgrade purchased")
	_check(model.credits == 0 and model.level(str(first["id"])) == 1, "purchase updates balance and ownership")
	_check(not model.buy_upgrade(str(first["id"])), "one shop card cannot be purchased twice")
	_check(not model.buy_upgrade("not_real"), "unknown upgrade rejected")
	_check(model.get_shop_offers().size() == 3, "purchased card is removed")
	model.start_shift()
	_check(model.phase == "playing" and model.shift_index == 1 and model.target == 340.0, "next shift advances target")
	_check(model.sales == 0.0 and model.batter == 132 and model.active.is_empty(), "next shift resets production and quota")
	model.tick(1000.0)
	_check(model.phase == "lost" and model.time_left == 0.0, "large time step ends shift once without negative clock")
	model.new_run(9)
	model.start_shift()
	model.shift_index = 5
	model.target = Run.TARGETS[5]
	model.sales = model.target
	model.finish_shift()
	_check(model.phase == "won", "final quota produces victory")


func _test_save_and_rng() -> void:
	var original = Run.new()
	original.new_run(8675309)
	original.owned["golden_sixth"] = 1
	original.start_shift()
	original.queue_batch("powdered", 1)
	original.tick(2.5)
	original.queue_batch("cocoa", 2)
	original.tick(6.0)
	var json_text: String = JSON.stringify(original.to_save())
	var restored = Run.new()
	_check(restored.from_save(JSON.parse_string(json_text)), "JSON round trip restores an active run")
	_check(restored.active.size() == original.active.size() and restored.trays[1].size() == original.trays[1].size(), "partial transit and tray state survive save")
	_near(restored.time_left, original.time_left, "remaining time survives save")
	original.tick(5.0)
	restored.tick(5.0)
	_near(float(original.sell_tray(1)["amount"]), float(restored.sell_tray(1)["amount"]), "restored golden sale is identical")
	original.sales = original.target
	restored.sales = restored.target
	original.finish_shift()
	restored.finish_shift()
	_check(original.get_shop_offers() == restored.get_shop_offers(), "saved 64-bit RNG state gives identical future shop offers")
	var offer_id: String = str(original.get_shop_offers()[0]["id"])
	original.buy_upgrade(offer_id)
	restored.buy_upgrade(offer_id)
	var shop_copy = Run.new()
	_check(shop_copy.from_save(JSON.parse_string(JSON.stringify(original.to_save()))), "partly purchased shop can resume")
	_check(shop_copy.get_shop_offers() == original.get_shop_offers(), "resuming shop does not reroll or restore purchased cards")
	original.start_shift()
	restored.start_shift()
	original.sales = original.target
	restored.sales = restored.target
	original.finish_shift()
	restored.finish_shift()
	_check(original.get_shop_offers() == restored.get_shop_offers(), "RNG remains deterministic beyond first restored shop")
	var pristine = Run.new()
	_check(pristine.from_save(JSON.parse_string(JSON.stringify(Run.new().to_save()))), "ready state can round trip")


func _test_invalid_saves() -> void:
	var model = Run.new()
	model.start_shift()
	model.queue_batch("cinnamon", 0)
	var valid: Dictionary = model.to_save()
	var corruptions: Array = [
		{"version": 999}, {"phase": "bogus"}, {"shift_index": 6}, {"sales": NAN}, {"time_left": INF}, {"target": NAN},
		{"time_left": 999.0}, {"credits": -1}, {"batter": 0.5}, {"selected_recipe": "pizza"},
		{"owned": {"missing": 1}}, {"owned": {"sugar_dust": 999}}, {"owned": {"golden_glaze": 1}},
		{"trays": [[], []]}, {"active": ["not a donut"]}, {"seed_value": "oops"},
		{"rng_state": 1234}, {"rng_state": "9999999999999999999999999999999"}, {"offers": ["sugar_dust", "sugar_dust"]}, {"offers_generated": "true"},
		{"last_result": {"cleared": true}}, {"last_full_amount": -1.0}
	]
	for replacement in corruptions:
		var broken: Dictionary = valid.duplicate(true)
		broken.merge(replacement, true)
		_check(not model.from_save(broken), "corrupt save rejected: " + str(replacement.keys()[0]))
		_check(model.to_save() == valid, "rejected save leaves active run intact")
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate["active"].append(duplicate["active"][0].duplicate())
	_check(not model.from_save(duplicate), "duplicate donut IDs rejected")
	var invalid_donut: Dictionary = valid.duplicate(true)
	invalid_donut["active"][0]["progress"] = NAN
	_check(not model.from_save(invalid_donut), "NaN donut position rejected")


func _test_complete_run() -> void:
	var wins: int = 0
	var total: int = 20
	var example: Array = []
	for seed_index in range(total):
		var model = Run.new()
		model.new_run(1000 + seed_index)
		model.start_shift()
		var history: Array = []
		var guard: int = 0
		while model.phase != "won" and model.phase != "lost" and guard < 10000:
			guard += 1
			if model.phase == "shop":
				history.append(snappedf(model.sales, 1.0))
				_buy_sensible_upgrades(model)
				model.start_shift()
				continue
			for tray in range(3):
				if model.trays[tray].size() == 6 or (model.time_left <= 0.25 and not model.trays[tray].is_empty()):
					model.sell_tray(tray)
			if model.cooldown <= 0.00001:
				for tray in range(3):
					var pending: int = model.trays[tray].size()
					for donut in model.active:
						if int(donut["tray"]) == tray:
							pending += 1
					if pending == 0:
						model.queue_batch(_best_recipe(model), tray)
						break
			model.tick(0.1)
		history.append(snappedf(model.sales, 1.0))
		if model.phase == "won":
			wins += 1
		elif seed_index == 0:
			push_warning("Example run stopped at shift %d: %s" % [model.shift_index + 1, str(history)])
		if seed_index == 0:
			example = history
		_check(guard < 10000, "simulated run terminates (seed %d)" % (1000 + seed_index))
	_check(wins == total, "competent automated play can clear all six shifts across 20 seeded drafts (%d/%d)" % [wins, total])
	print("BALANCE: %d/%d complete runs; seed 1000 sales per shift: %s" % [wins, total, str(example)])


func _best_recipe(model) -> String:
	var best: String = "cocoa"
	var best_value: float = 0.0
	for recipe in Run.RECIPE_ORDER:
		var upgrade: String = {"cinnamon": "cinnamon_king", "powdered": "snow_day", "cocoa": "cocoa_crown"}[recipe]
		var value: float = float(Run.RECIPES[recipe]["base_value"]) * (1.0 + 0.35 * float(model.level(upgrade)))
		if value > best_value:
			best_value = value
			best = recipe
	return best


func _test_casual_play() -> void:
	# This is a reproducible balance scenario, not a claim about real players:
	# one deliberate action every 1.5 seconds, occasionally distracted, and only
	# two shop purchases between shifts. Still understands full-tray bonuses.
	var wins: int = 0
	var shifts_cleared: Array = [0, 0, 0, 0, 0, 0]
	var example: Array = []
	for seed_index in range(30):
		var model = Run.new()
		model.new_run(2000 + seed_index)
		var behavior: RandomNumberGenerator = RandomNumberGenerator.new()
		behavior.seed = 9000 + seed_index
		model.start_shift()
		var history: Array = []
		var decision_clock: float = 0.0
		while model.phase == "playing" or model.phase == "shop":
			if model.phase == "shop":
				shifts_cleared[model.shift_index] += 1
				history.append(snappedf(model.sales, 1.0))
				var bought: int = 0
				for offer in model.get_shop_offers():
					if bought < 2 and str(offer["id"]) != "assorted_batter" and str(offer["id"]) != "variety_bonus":
						if model.buy_upgrade(str(offer["id"])):
							bought += 1
				model.start_shift()
				decision_clock = 0.0
			decision_clock -= 0.1
			if decision_clock <= 0.0:
				decision_clock = 1.5
				if behavior.randf() >= 0.12:
					var acted: bool = false
					for tray in range(3):
						if model.trays[tray].size() == 6 or (model.time_left <= 2.0 and not model.trays[tray].is_empty()):
							model.sell_tray(tray)
							acted = true
							break
					if not acted and model.can_queue_batch():
						for tray in range(3):
							var pending: int = model.trays[tray].size()
							for donut in model.active:
								if int(donut["tray"]) == tray:
									pending += 1
							if pending == 0:
								model.queue_batch(_best_recipe(model), tray)
								break
			model.tick(0.1)
		history.append(snappedf(model.sales, 1.0))
		if model.phase == "won":
			wins += 1
			shifts_cleared[5] += 1
		if seed_index == 0:
			example = history
	_check(shifts_cleared[0] == 30, "slower-action scenario reliably clears introductory shift")
	print("CASUAL BALANCE: %d/30 wins; shifts cleared %s; seed2000 sales %s" % [wins, str(shifts_cleared), str(example)])


func _buy_sensible_upgrades(model) -> void:
	var priority: Array = ["matching_bonus", "tray_liner", "sugar_dust", "golden_sixth", "quick_cook", "cocoa_crown", "snow_day", "cinnamon_king", "hot_streak", "golden_glaze", "echo_box", "comeback", "closing_time", "spare_seconds", "turbo_feed", "bulk_batter", "frugal_batter", "quick_sale"]
	var offers: Array = model.get_shop_offers()
	for preferred in priority:
		for offer in offers:
			if str(offer["id"]) == str(preferred):
				model.buy_upgrade(str(offer["id"]))
