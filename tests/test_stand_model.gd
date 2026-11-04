extends SceneTree
## Order/stock/maintenance tests and tool-aware, paced whole-run simulations.

const Stand = preload("res://scripts/stand_model.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_manual_sequence_and_stock()
	_test_order_validation_and_recovery()
	_test_machine_and_holds()
	_test_orders_and_phases()
	_test_save_and_corruption()
	_test_paced_runs()
	print("STAND MODEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _test_manual_sequence_and_stock() -> void:
	var model = Stand.new()
	_check(not model.choose_package("bag").ok, "closed stand rejects prep")
	model.start_shift()
	_check(model.orders.size() == 1 and model.orders[0].package == "bag" and model.orders[0].flavor == "cinnamon", "opening order is predictable cinnamon bag")
	_check(model.supply == 18 and model.batter == 72, "opening buffer supports learning before maintenance")
	_check(not model.scoop().ok and not model.dump().ok and not model.coat("cinnamon").ok, "operations require the appropriate prior preparation")
	_check(not model.choose_package("box").ok, "unknown packaging rejected")
	_check(model.choose_package("bag").ok and model.package_capacity() == 6, "bag capacity is six")
	_check(model.scoop().ok and model.scoop_count == 3 and model.supply == 15, "scoop transfers three physical donuts")
	_check(not model.scoop().ok and model.supply == 15, "holding a loaded scoop prevents taking another scoop")
	_check(model.dump().ok and model.package_count == 3 and model.scoop_count == 0, "dump moves held donuts to bag")
	_check(not model.choose_package("bucket").ok and model.package_count == 3, "changing nonempty package cannot erase food")
	_check(not model.coat("cinnamon").ok, "half-filled bag cannot be coated")
	model.scoop()
	model.dump()
	_check(model.package_count == 6 and model.supply == 12 and not model.scoop().ok, "filled bag prevents overfilling")
	_check(model.coat("cinnamon").ok and model.package_flavor == "cinnamon", "coating follows complete fill")
	var sale: Dictionary = model.serve()
	_check(sale.ok and is_equal_approx(float(sale.amount), 22.0) and is_equal_approx(float(sale.tip), 4.0), "correct fresh order pays menu price plus patience tip")
	_check(model.served == 1 and model.streak == 1 and model.orders.is_empty(), "served customer leaves queue exactly once")
	_check(model.package_type.is_empty() and model.package_count == 0 and model.package_flavor.is_empty(), "service clears only the completed package")
	_check(not model.serve().ok and model.sales == 22.0, "cannot sell a completed order twice")
	model.tick(3.0)
	_check(model.supply > 12 and model.batter < 72 and model.production_count > 0, "machine makes plain donuts automatically while player works")
	_check(model.supply + 6 == 18 + model.production_count, "cooked stock is conserved through production and service")
	_check(model.batter + model.production_count == 72, "production consumes one batter per donut")


func _test_order_validation_and_recovery() -> void:
	var model = Stand.new()
	model.start_shift()
	model.choose_package("bag")
	model.scoop()
	model.dump()
	model.scoop()
	var cleared: Dictionary = model.discard()
	_check(cleared.returned == 6 and cleared.wasted == 0 and model.supply == 18, "clear recovers both plain packed and held donuts")
	_check(model.package_type.is_empty() and model.scoop_count == 0, "clear resets package and scoop")
	_fill(model, "bag", "powdered")
	var old_patience: float = model.orders[0].patience
	var rejected: Dictionary = model.serve()
	_check(not rejected.ok and rejected.code == "wrong_order", "wrong coating rejected by customer")
	_check(model.package_count == 6 and model.package_flavor == "powdered" and model.orders.size() == 1, "wrong service preserves food and customer for recovery")
	_check(model.mistakes == 1 and model.orders[0].patience == old_patience - 4.0 and model.sales == 0.0, "wrong order costs patience and breaks streak without awarding money")
	_check(not model.coat("cinnamon").ok and model.package_flavor == "powdered", "existing coating cannot be silently replaced")
	cleared = model.discard()
	_check(cleared.returned == 0 and cleared.wasted == 6, "coated donuts are discarded instead of returning to plain supply")
	_fill(model, "bag", "cinnamon")
	_check(model.serve().ok, "mistake can be recovered with the correct order")
	model.new_run(9)
	model.start_shift()
	_fill(model, "bucket", "cinnamon")
	_check(not model.serve().ok and model.package_count == 12, "correct flavor in wrong package is rejected intact")
	model.discard()
	model.choose_package("bag")
	model.supply = 1
	model.scoop()
	model.dump()
	_check(model.package_count == 1 and model.supply == 0, "last available donut can be scooped without fabricating stock")
	model.owned["wide_scoop"] = 1
	model.supply = 10
	model.scoop()
	model.dump()
	model.scoop()
	_check(model.scoop_count == 1, "upgraded scoop clips pickup to package room")
	model.dump()
	_check(model.package_count == 6, "upgraded scoop cannot overfill bag")


func _test_machine_and_holds() -> void:
	var model = Stand.new()
	model.new_run(120)
	model.start_shift()
	model.supply = 0
	model.adjust_heat(-1)
	model.tick(20.0)
	_check(not model.jammed, "first jam cannot interrupt initial twenty seconds")
	for index in range(300):
		if model.jammed: break
		model.supply = mini(model.supply, 10)
		model.tick(0.1)
	_check(model.jammed and model.shift_duration - model.time_left >= 22.0, "production eventually produces a repairable jam")
	var stopped_count: int = model.production_count
	model.repair(0.9)
	var held_progress: float = model.jam_progress
	model.tick(2.0)
	_check(model.production_count == stopped_count and is_equal_approx(model.jam_progress, held_progress), "jam stops production and interrupted repair keeps progress")
	_check(not model.repair(NAN).ok and not model.repair(-1.0).ok, "invalid repair delta rejected")
	_check(model.repair(0.9).code == "repaired" and not model.jammed, "resumed hold clears jam")
	model.tick(2.0)
	_check(model.production_count > stopped_count, "production resumes after repair")
	model.batter = 0
	model.refill(1.0)
	model.tick(1.0)
	_check(is_equal_approx(model.refill_progress, 0.5) and model.batter == 0, "interrupted refill keeps progress without granting partial free batter")
	_check(model.refill(1.0).code == "refilled" and model.batter == model.batter_capacity(), "resumed refill restores hopper capacity")
	_check(not model.refill(0.1).ok, "full hopper does not accept redundant refills")
	model.new_run(121)
	model.start_shift()
	model.adjust_heat(1)
	model.tick(25.0)
	_check(model.overheated and model.temperature >= 205.0, "too much heat causes a visible thermal stop")
	stopped_count = model.production_count
	model.tick(2.0)
	_check(model.production_count == stopped_count, "overheated machine cannot produce")
	model.adjust_heat(-2)
	model.tick(25.0)
	_check(not model.overheated and model.temperature <= 190.0, "lower heater setting recovers from overheat")
	model.adjust_heat(-99)
	_check(model.heat_setting == 0, "heater adjustment clamps at minimum")
	model.adjust_heat(99)
	_check(model.heat_setting == 4, "heater adjustment clamps at maximum")
	var old_time: float = model.time_left
	model.tick(NAN)
	model.tick(INF)
	model.tick(-1.0)
	_check(model.time_left == old_time, "invalid time does not contaminate machine state")
	model.new_run(122)
	model.start_shift()
	model.supply = model.supply_capacity
	var old_batter: int = model.batter
	model.tick(3.0)
	_check(model.supply == model.supply_capacity and model.batter == old_batter, "full catch tray stops production without losing stock")


func _test_orders_and_phases() -> void:
	var model = Stand.new()
	model.new_run(130)
	model.start_shift()
	model.tick(16.0)
	_check(model.orders.size() == 2 and model.orders[1].package == "bag" and model.orders[1].flavor == "powdered", "second opening customer asks for powdered bag")
	model.tick(16.0)
	_check(model.orders.size() == 3 and model.orders[2].package == "bucket" and model.orders[2].flavor == "cinnamon", "third opening customer introduces bucket")
	model.tick(30.0)
	_check(model.orders.size() <= 3 and model.missed >= 1, "patience creates walkouts but queue never exceeds three")
	_check(model.phase == "playing", "walkout leaves time to recover rather than ending shift immediately")
	model.orders.clear()
	model._arrival_clock = 0.1
	model.tick(0.2)
	_check(model.orders.size() == 1, "empty queue receives replacement customers and cannot become permanently unwinnable")
	model.sales = model.target
	model.finish_shift()
	_check(model.phase == "shop" and model.get_shop_offers().size() == 3, "quota earns intermission with three equipment choices")
	var offer: Dictionary = model.get_shop_offers()[0]
	model.credits = 0
	_check(not model.buy_upgrade(str(offer.id)), "equipment requires enough earned credits")
	model.credits = int(offer.cost)
	_check(model.buy_upgrade(str(offer.id)) and model.credits == 0 and model.level(str(offer.id)) == 1, "purchase applies one upgrade and charges exact credit price")
	_check(not model.buy_upgrade(str(offer.id)), "shop card cannot be bought twice")
	var restored = Stand.new()
	_check(restored.from_save(JSON.parse_string(JSON.stringify(model.to_save()))), "purchased-upgrade intermission can be saved and restored")
	model.start_shift()
	_check(model.shift_index == 1 and model.target == 180 and model.time_left == 110.0 and model.served == 0, "next shift advances pressure while resetting shift counters")
	model.tick(1000.0)
	_check(model.phase == "lost" and model.time_left == 0.0, "missing timed quota loses cleanly")
	model.new_run(131)
	for index in range(3):
		model.start_shift()
		model.sales = model.target
		model.finish_shift()
	_check(model.phase == "won" and model.shift_index == 2, "third completed shift wins without a fourth shift")
	var old_credits: int = model.credits
	model.finish_shift()
	_check(model.credits == old_credits and not model.scoop().ok, "completed game cannot award credits twice or keep serving")


func _test_save_and_corruption() -> void:
	var model = Stand.new()
	model.new_run(140)
	model.start_shift()
	model.choose_package("bag")
	model.scoop()
	model.dump()
	model.scoop()
	model.tick(8.3)
	var saved: Dictionary = model.to_save()
	var copy = Stand.new()
	_check(copy.from_save(JSON.parse_string(JSON.stringify(saved))), "JSON save restores active order, held scoop and half-filled package")
	_check(copy.scoop_count == 3 and copy.package_count == 3 and copy.orders.size() == model.orders.size(), "physical work-in-progress survives resume")
	model.dump()
	copy.dump()
	model.coat("cinnamon")
	copy.coat("cinnamon")
	_check(model.serve() == copy.serve(), "resumed work earns identical receipt")
	model.tick(26.0)
	copy.tick(26.0)
	_check(_same_state(model.to_save(), copy.to_save()), "restored RNG and machine produce equivalent later orders and stock")
	model.sales = model.target
	copy.sales = copy.target
	model.finish_shift()
	copy.finish_shift()
	_check(model.get_shop_offers() == copy.get_shop_offers(), "restored RNG produces same equipment shop")
	var valid: Dictionary = saved.duplicate(true)
	for change in [{"version": 999}, {"temperature": NAN}, {"time_left": INF}, {"batter": -1}, {"orders": ["broken"]}, {"package_count": 99}, {"scoop_count": 4}, {"package_flavor": "cocoa"}, {"heat_setting": 5}, {"owned": {"unknown": 1}}, {"rng_state": "99999999999999999999999999"}, {"supply": 999}, {"target": 1}, {"jam_progress": 2.0}, {"last_result": {"cleared": true}}, {"_production_clock": NAN}]:
		var broken: Dictionary = valid.duplicate(true)
		broken.merge(change, true)
		var before: Dictionary = copy.to_save()
		_check(not copy.from_save(broken), "invalid stand save rejected: " + str(change.keys()[0]))
		_check(copy.to_save() == before, "invalid save cannot partially mutate live stand")
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate.orders.append(duplicate.orders[0].duplicate(true))
	_check(not copy.from_save(duplicate), "duplicated customer IDs rejected")
	var empty = Stand.new()
	_check(empty.from_save(JSON.parse_string(JSON.stringify(Stand.new().to_save()))), "ready stand state restores")


func _test_paced_runs() -> void:
	for action_seconds in [0.65, 0.9, 1.2]:
		var wins: int = 0
		var first_clears: int = 0
		var example: Dictionary = {}
		for seed_index in range(12):
			var result: Dictionary = _simulate_run(1600 + seed_index, action_seconds)
			if bool(result.won): wins += 1
			if int(result.cleared) >= 1: first_clears += 1
			if seed_index == 0: example = result
			_check(result.steps < 5000, "paced run terminates %.2fs/action seed%d" % [action_seconds, seed_index])
		if action_seconds == 0.65:
			_check(wins == 12, "competent tool-aware play can complete all three shifts across12seeds")
		_check(first_clears == 12, "learnable opening is clearable at %.2fs per physical action" % action_seconds)
		print("STAND BALANCE %.2fs/action: %d/12 wins; example %s" % [action_seconds, wins, str(example)])


func _simulate_run(seed_number: int, action_seconds: float) -> Dictionary:
	var model = Stand.new()
	model.new_run(seed_number)
	model.start_shift()
	var tool: String = "none"
	var action_clock: float = 0.0
	var holding: String = ""
	var history: Array = []
	var steps: int = 0
	var cleared: int = 0
	var stock_wait: float = 0.0
	var repair_time: float = 0.0
	var refill_time: float = 0.0
	while model.phase == "playing" or model.phase == "shop":
		steps += 1
		if steps >= 5000: break
		if model.phase == "shop":
			history.append({"sales": model.sales, "served": model.served, "walkouts": model.missed, "stock_wait": snappedf(stock_wait, 0.1)})
			cleared += 1
			var offers: Array = model.get_shop_offers()
			for preferred in ["wide_scoop", "fast_motor", "calm_queue", "steady_feed", "easy_repair", "large_hopper", "extra_tray", "generous_tips"]:
				for offer in offers:
					if str(offer.id) == preferred: model.buy_upgrade(preferred)
			model.start_shift()
			tool = "none"
			holding = ""
			action_clock = 0.0
			stock_wait = 0.0
		if not model.orders.is_empty() and model.supply == 0 and model.scoop_count == 0 and model.package_count < model.package_capacity(): stock_wait += 0.1
		if holding == "repair":
			model.repair(0.1)
			repair_time += 0.1
			if not model.jammed: holding = ""
		elif holding == "refill":
			model.refill(0.1)
			refill_time += 0.1
			if model.refill_progress == 0.0: holding = ""
		else:
			action_clock -= 0.1
			if action_clock <= 0.0:
				action_clock = action_seconds
				if model.temperature >= 198.0 and model.heat_setting > 2:
					model.adjust_heat(-1)
				elif model.jammed and (model.supply < 12 or model.package_type.is_empty()):
					holding = "repair"
				elif model.batter <= 6 and model.supply < 18:
					holding = "refill"
				elif not model.orders.is_empty():
					var order: Dictionary = model.orders[0]
					if model.package_type.is_empty():
						model.choose_package(str(order.package))
						tool = "none"
					elif model.package_type != str(order.package) or (not model.package_flavor.is_empty() and model.package_flavor != str(order.flavor)):
						model.discard()
						tool = "none"
					elif model.package_count < model.package_capacity():
						if tool != "scoop": tool = "scoop"
						elif model.scoop_count > 0: model.dump()
						else: model.scoop()
					elif model.package_flavor.is_empty():
						model.coat(str(order.flavor))
						tool = "none"
					elif tool != "package": tool = "package"
					else:
						model.serve()
						tool = "none"
		model.tick(0.1)
	history.append({"sales": model.sales, "served": model.served, "walkouts": model.missed, "stock_wait": snappedf(stock_wait, 0.1)})
	if model.phase == "won": cleared += 1
	return {"won": model.phase == "won", "cleared": cleared, "shifts": history, "steps": steps, "repair_seconds": snappedf(repair_time, 0.1), "refill_seconds": snappedf(refill_time, 0.1)}


func _fill(model, kind: String, flavor: String) -> void:
	model.choose_package(kind)
	while model.package_count < model.package_capacity() and model.supply > 0:
		model.scoop()
		model.dump()
	if model.package_count == model.package_capacity(): model.coat(flavor)


func _same_state(left: Variant, right: Variant) -> bool:
	if (left is float or left is int) and (right is float or right is int):
		return absf(float(left) - float(right)) < 0.000001
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _same_state(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _same_state(left[index], right[index]): return false
		return true
	return left == right
