extends "res://tests/test_stand_model.gd"
## Expansion rules, durable achievement conditions, migrations and real-hand pacing.

const World = preload("res://scripts/stand_world.gd")


func _run() -> void:
	_test_appeal_and_imperfect_service()
	_test_speed_and_machine_progression()
	_test_shift_buffs()
	_test_gags_and_achievements()
	_test_expansion_saves()
	_test_animation_pacing()
	print("EXPANSION MODEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _open(seed_number: int = 5501):
	var model = Stand.new()
	model.new_run(seed_number)
	model.start_shift()
	return model


func _serve_front(model) -> Dictionary:
	if model.orders.is_empty(): model._spawn_order()
	model.supply = model.supply_capacity
	var order: Dictionary = model.orders[0]
	_fill(model, str(order.package), str(order.flavor))
	return model.serve()


func _test_appeal_and_imperfect_service() -> void:
	var model = _open()
	_check(model.appeal == 60.0, "appeal starts at sixty")
	var receipt: Dictionary = _serve_front(model)
	_check(receipt.correct and receipt.rating == 5 and receipt.appeal_delta == 3.0 and model.appeal == 63.0, "fast correct service awards a five-star rating and explicit appeal gain")
	model._spawn_order()
	model.orders[0].patience = 4.0
	receipt = _serve_front(model)
	_check(receipt.correct and receipt.rating == 2 and receipt.appeal_delta == -2.0, "very late correct food gets a poor rating instead of automatic praise")
	model.appeal = 0.0
	_check(is_equal_approx(model.arrival_multiplier(), 1.18), "low appeal keeps arrivals at a playable bounded rate")
	model.appeal = 100.0
	_check(is_equal_approx(model.arrival_multiplier(), 0.88), "high appeal attracts a bounded faster crowd")
	model = _open()
	model.adjust_heat(-1)
	model.tick(30.0)
	_check(model.appeal < 60.0 and model.appeal > 58.0, "long waits gradually reduce appeal before any walkout")
	model.orders[0].patience = 0.01
	var before: float = model.appeal
	model.tick(0.1)
	_check(model.missed == 1 and model.appeal <= before - 6.0, "walkout applies a visible reputation consequence")
	model = _open()
	_fill(model, "bucket", "powdered")
	receipt = model.serve()
	_check(receipt.ok and not receipt.correct and receipt.amount == 4.5 and receipt.tip == 0.0, "wrong size and flavor receive twenty-five percent of the cheaper menu price")
	_check(receipt.rating == 1 and model.appeal == 51.0 and model.streak == 0 and model.served == 1, "imperfect sale records one served customer with rating and streak consequences")
	_check(model.orders.is_empty() and model.package_type.is_empty() and not model.serve().ok, "imperfect order cannot be paid or consumed twice")
	model = _open()
	model.choose_package("bag")
	model.scoop()
	model.dump()
	before = model.appeal
	_check(not model.serve().ok and model.package_count == 3 and model.appeal == before, "unfinished preparation is refused without an appeal penalty")
	model = _open()
	model.owned["second_chance"] = 1
	_fill(model, "bag", "powdered")
	_check(model.serve().appeal_delta == -5.0, "Friendly Apology meaningfully reduces imperfect-sale appeal loss")


func _test_speed_and_machine_progression() -> void:
	var counts: Array = []
	for speed in range(3):
		var model = Stand.new()
		model.new_run(5502)
		model.adjust_speed(speed - 1)
		model.start_shift()
		model.adjust_heat(-1)
		model.tick(12.0)
		counts.append(model.production_count)
		_check(model.production_speed == speed, "selected production speed survives opening the shift")
	_check(counts[0] > 0 and counts[0] < counts[1] and counts[1] < counts[2], "slow, normal and fast are distinct nonzero production rates")
	var model = _open()
	model.adjust_speed(100)
	_check(model.production_speed == 2 and model.heat_setting == 3, "speed clamps independently from oil heat")
	model.adjust_speed(-100)
	_check(model.production_speed == 0, "slow is the lowest production speed")
	var machine_ids: Array = ["compact", "twin_lane", "festival_pro"]
	var venue_ids: Array = ["fairground", "concert", "stadium"]
	var prior_count: int = 0
	var prior_capacity: int = 0
	var prior_grace: int = 0
	for tier in range(3):
		model = Stand.new()
		model.new_run(5503)
		model.shift_index = tier * 6
		model.start_shift()
		model.adjust_heat(-1)
		var grace: int = model._next_jam_at
		model.tick(10.0)
		_check(model.venue_id() == venue_ids[tier] and model.machine_id() == machine_ids[tier], "venue boundary unlocks its matching machine tier")
		_check(model.batter_capacity() > prior_capacity and grace > prior_grace and model.production_count > prior_count, "machine tiers improve hopper capacity, reliability and production")
		prior_capacity = model.batter_capacity()
		prior_grace = grace
		prior_count = model.production_count
		var copy = Stand.new()
		_check(copy.from_save(JSON.parse_string(JSON.stringify(model.to_save()))) and copy.machine_id() == machine_ids[tier], "earned machine tier survives JSON save and resume")
	model = Stand.new()
	for shift in range(18):
		model.start_shift()
		model.sales = model.target
		model.finish_shift()
		_check(model.phase == ("won" if shift == 17 else "shop"), "only the eighteenth campaign shift ends the full tour")


func _test_shift_buffs() -> void:
	for id in Stand.BUFFS:
		var model = Stand.new()
		_check(model.equip_buff(id).ok and model.pending_buff == id and model.active_buff.is_empty(), "buff queues before opening: " + id)
		var queued: Dictionary = model.to_save()
		_check(not model.equip_buff("fresh_oil").ok and model.to_save() == queued, "second queued buff is refused without consuming the first")
		var copy = Stand.new()
		_check(copy.from_save(JSON.parse_string(JSON.stringify(queued))) and copy.pending_buff == id, "queued buff survives saving: " + id)
		copy.start_shift()
		_check(copy.pending_buff.is_empty() and copy.active_buff == id and not copy.equip_buff(id).ok, "opening consumes exactly one queued buff for the active shift")
		_check(model.from_save(JSON.parse_string(JSON.stringify(copy.to_save()))) and model.active_buff == id, "active buff and modified rules survive save: " + id)
		copy.sales = copy.target
		copy.finish_shift()
		copy.start_shift()
		_check(copy.active_buff.is_empty(), "shift buff expires at the next opening: " + id)
	var model = Stand.new()
	model.equip_buff("fresh_oil")
	model.start_shift()
	model.tick(95.0)
	_check(not model.overheated and not model.fire_active and model.temperature < 195.0, "fresh oil makes heat three safe throughout the shift")
	var baseline = _open(5504)
	model.new_run(5504)
	model.equip_buff("freshly_serviced")
	model.start_shift()
	_check(model._next_jam_at == baseline._next_jam_at + 18, "service buff grants eighteen extra donuts between jams")
	model.new_run(5504)
	model.equip_buff("good_vibes")
	model.start_shift()
	_check(model.orders[0].max_patience == baseline.orders[0].max_patience + 10.0 and _serve_front(model).appeal_delta == 5.0, "good vibes grants extra patience and correct-service appeal")
	model.new_run(5504)
	model.equip_buff("emergency_batter")
	model.start_shift()
	model.batter = 0
	model.tick(0.1)
	_check(model.batter == model.batter_capacity() and not model._emergency_batter_ready, "emergency reserve refills an empty hopper once")
	model.batter = 0
	model.tick(0.1)
	_check(model.batter == 0, "spent emergency reserve cannot refill again")
	model.new_run(5504)
	model.equip_buff("rush_contract")
	model.start_shift()
	_check(model.target == 127 and is_equal_approx(model.get_campaign_info().arrival_interval, 12.3), "rush contract exposes increased quota and faster arrival spacing")
	var receipt: Dictionary = _serve_front(model)
	_check(receipt.amount == 27.5 and receipt.tip_breakdown[-1].label == "Rush contract", "rush contract payout increase is explicit in the authoritative receipt")


func _test_gags_and_achievements() -> void:
	var model = _open()
	_check(not model.note_gag("hat", 999).ok, "hat cannot tag a customer who already left")
	_check(not model.hat_customer().ok and not bool(model.orders[0].hat), "an empty scoop cannot tag a customer by admiring an existing hat")
	model.choose_package("bag")
	model.scoop()
	var hatted: Dictionary = model.hat_customer()
	_check(hatted.ok and hatted.order_id == model.orders[0].id and model.scoop_count == 2 and model.waste_count == 1, "intentional hat toss consumes one held donut and tags the actual front customer")
	_check(not model.hat_customer().ok and model.scoop_count == 2, "repeat hat toss cannot consume food or award another tag")
	var receipt: Dictionary = _serve_front(model)
	_check(receipt.hat and model.unlocked_achievements.has("head_chef"), "correctly serving the tagged hat customer earns Head Chef")
	for i in range(3): model.note_gag("seagull_feed")
	model._spawn_order()
	_check(model.orders[0].special == "seagulls", "three completed feeds schedule the next disguised seagull customer")
	receipt = _serve_front(model)
	_check(receipt.special == "seagulls" and model.unlocked_achievements.has("definitely_human"), "correct special service identifies the reveal and earns Definitely Human")
	model.choose_package("bag")
	model.supply = 3
	var previous_waste: int = model.waste_count
	_check(model.catch_air_mail(77).ok and model.supply == 2 and model.package_count == 1 and model.waste_count == previous_waste, "air mail atomically moves one existing donut straight into a plain bag")
	var before: Dictionary = model.to_save()
	_check(not model.catch_air_mail(77).ok and model.to_save() == before, "repeated air-mail identity cannot duplicate the same donut")
	var copy = Stand.new()
	_check(copy.from_save(JSON.parse_string(JSON.stringify(before))) and not copy.catch_air_mail(77).ok, "air-mail identity survives saving")
	_check(model.catch_air_mail(-10001).ok and not model.catch_air_mail(-10001).ok, "seeded and returned physical food negative IDs also deduplicate")
	_check(copy.from_save(JSON.parse_string(JSON.stringify(model.to_save()))) and not copy.catch_air_mail(-10001).ok, "negative physical food identities survive saving")
	before = model.to_save()
	_check(not model.catch_air_mail(2147483648).ok and model.to_save() == before, "out-of-range catch identities cannot create an unreadable save")
	model.discard()
	model.choose_package("bucket")
	_check(not model.catch_air_mail(78).ok, "air mail requires a bag rather than a bucket")
	_check(model.unlocked_achievements.has("air_mail"), "successful catch earns Air Mail")
	model = _open()
	for i in range(5):
		model._run_elapsed = float(i) * 10.0
		_serve_front(model)
	_check(model.unlocked_achievements.has("rush_hour"), "five correct sales inside forty-five seconds earn Rush Hour")
	var event_count: int = model.events.filter(func(event): return event.type == "achievement" and event.id == "rush_hour").size()
	_serve_front(model)
	_check(model.events.filter(func(event): return event.type == "achievement" and event.id == "rush_hour").size() == event_count, "achievement event is emitted only once per run")
	model = _open()
	model.fire_active = true
	model.fire_danger = 1.0
	model.overheated = true
	model.extinguish_fire()
	model.tick(9.0)
	_serve_front(model)
	_check(model.unlocked_achievements.has("this_is_fine"), "correct service within ten seconds after extinguishing earns This Is Fine")
	model = _open()
	for i in range(3):
		if model.orders.is_empty(): model._spawn_order()
		model.punch_customer()
	_check(model.unlocked_achievements.has("express_checkout") and model.appeal == 24.0, "three real punches in one shift earn Express Checkout and reduce appeal")
	for i in range(21): _serve_front(model)
	_check(model.appeal >= 85.0 and model.unlocked_achievements.has("five_star_comeback"), "rebuilding low appeal through correct service earns Five-Star Comeback")
	model = _open()
	model.adjust_speed(-1)
	model.adjust_heat(-1)
	model.tick(3.0)
	for i in range(8): _serve_front(model)
	model._pending_deliveries.append(model._next_delivery_id)
	model._next_delivery_id += 1
	model.production_count += 1
	model.finish_shift()
	_check(model.unlocked_achievements.has("no_crumb_left_behind") and model.unlocked_achievements.has("slow_and_steady") and model.pending_delivery_ids().size() == 1, "zero-waste and all-slow achievements evaluate at the buzzer even when physical food is frozen in transit")
	model = _open()
	model.tick(3.0)
	model.adjust_speed(-1)
	for i in range(8): _serve_front(model)
	model.spill_stock(1)
	model.finish_shift()
	_check(not model.unlocked_achievements.has("slow_and_steady") and not model.unlocked_achievements.has("no_crumb_left_behind"), "normal-speed production and waste cannot earn the restricted shift achievements")


func _test_expansion_saves() -> void:
	var model = _open()
	model.note_gag("hat")
	model.note_gag("seagull_feed")
	model.note_gag("seagull_feed")
	_serve_front(model)
	var saved: Dictionary = model.to_save()
	var restored = Stand.new()
	_check(restored.from_save(JSON.parse_string(JSON.stringify(saved))) and _same_state(saved, restored.to_save()), "all expanded state survives JSON save without changing RNG")
	restored.note_gag("seagull_feed")
	restored._spawn_order()
	_check(restored.orders[0].special == "seagulls", "saved feed count resumes the third-feed special trigger")
	for change in [{"appeal": NAN}, {"appeal": 101}, {"production_speed": 3}, {"machine_tier": 2}, {"pending_buff": "unknown"}, {"active_buff": "unknown"}, {"_recent_correct_times": [INF]}, {"_caught_stock_ids": [4, 4]}, {"_slow_only": 1}, {"_emergency_batter_ready": true}, {"unlocked_achievements": ["unknown"]}, {"_saved_shift_rules": {"duration": 999}}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.merge(change, true)
		var before: Dictionary = restored.to_save()
		_check(not restored.from_save(bad) and restored.to_save() == before, "invalid expansion save rejected atomically: " + str(change.keys()[0]))
	model = Stand.new()
	model.shift_index = 5
	model.start_shift()
	model.time_left = 75.0
	model.choose_package("bag")
	model.scoop()
	var old: Dictionary = model.to_save()
	old.version = 4
	old.shift_duration = 130.0
	var untouched: Dictionary = old.duplicate(true)
	_check(restored.from_save(old), "v4 save with the earlier final-shift duration migrates")
	_check(old == untouched and restored.time_left == 75.0 and restored.shift_duration == 130.0 and restored.scoop_count == 3 and restored.appeal == 60.0, "migration preserves old input, remaining time, held food and original shift rules")
	restored.sales = restored.target
	restored.finish_shift()
	restored.start_shift()
	_check(restored.shift_index == 6 and restored.venue_id() == "concert" and restored.machine_id() == "twin_lane", "migrated fairground completion continues into the actual concert venue")


func _test_animation_pacing() -> void:
	for difficulty in ["normal", "relaxed"]:
		var wins: int = 0
		for i in range(12):
			var result: Dictionary = _simulate_run((1600 if difficulty == "normal" else 1800) + i, 0.10, difficulty, 7.0, World.ACTION_DURATIONS)
			if result.won: wins += 1
			else: print("EXPANSION PACING FAILURE %s seed%d: %s" % [difficulty, i, str(result)])
			_check(result.steps < 50000, "actual animation pacing completes without simulation deadlock")
		_check(wins == 12, "all eighteen shifts support actual hand durations across twelve seeds: " + difficulty)
		print("EXPANSION ACTUAL ANIMATIONS %s: %d/12 full-tour wins" % [difficulty, wins])
