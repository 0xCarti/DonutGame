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
	_test_customer_punches()
	_test_fryer_fire_and_recovery()
	_test_fire_save_migration()
	_test_physical_deliveries_and_overflow()
	_test_orders_and_phases()
	_test_save_and_corruption()
	_test_campaign_content_and_practice()
	_test_upgrade_synergies_and_receipts()
	_test_preventive_service_and_legacy_save()
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
	_check(not model.coat("cinnamon").ok and model.package_flavor == "powdered", "existing coating cannot be silently replaced")
	var rejected: Dictionary = model.serve()
	_check(rejected.ok and not rejected.correct and rejected.code == "imperfect_order", "wrong coating is accepted as an explicitly imperfect order")
	_check(model.package_count == 0 and model.orders.is_empty(), "imperfect service consumes food and advances the actual customer once")
	_check(model.mistakes == 1 and model.appeal == 51.0 and model.sales == 7.2 and rejected.tip == 0.0, "wrong order receives fractional payment, loses appeal and earns no tips")
	model.new_run(8)
	model.start_shift()
	_fill(model, "bag", "powdered")
	cleared = model.discard()
	_check(cleared.returned == 0 and cleared.wasted == 6, "coated donuts are discarded instead of returning to plain supply")
	_check(model.waste_count == 6 and model.get_stats().total_wasted == 6, "discarded coated food is included in the same waste accounting as physical spills")
	_fill(model, "bag", "cinnamon")
	_check(model.serve().ok, "mistake can be recovered with the correct order")
	model.new_run(9)
	model.start_shift()
	_fill(model, "bucket", "cinnamon")
	var wrong_package: Dictionary = model.serve()
	_check(wrong_package.ok and not wrong_package.correct and model.package_count == 0, "wrong package is accepted for a fraction of the cheaper menu price")
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
	_check(model.supply == model.supply_capacity and model.batter < old_batter and model.production_count > 0, "full catch tray keeps producing and consuming batter without inventing extra capacity")
	_check(model.waste_count == model.production_count and model.batter + model.waste_count == old_batter, "overflow converts every excess cooked donut to waste")
	_check(model.production_status() == "TRAY FULL - donuts will overflow", "full tray status explains ongoing overflow")
	model.adjust_heat(-1)
	model.tick(30.0)
	_check(model.jammed and model.waste_count == model.production_count, "overflow still accrues machine wear and eventually jams")


func _food_and_earnings(model) -> Dictionary:
	var result: Dictionary = {}
	for key in ["supply", "batter", "package_type", "package_count", "package_flavor", "scoop_count", "sales", "served", "credits", "waste_count", "mistakes", "_run_served", "_run_sales", "_run_wasted"]:
		result[key] = model.get(key)
	result["pending"] = model.pending_delivery_ids()
	return result


func _test_customer_punches() -> void:
	var model = Stand.new()
	var before: Dictionary = model.to_save()
	_check(not model.punch_customer().ok and model.to_save() == before, "closed stand rejects a punch without changing state")
	model.start_shift()
	model._spawn_order()
	model._spawn_order()
	model.choose_package("bucket")
	model.scoop()
	model.dump()
	model.scoop()
	model.streak = 4
	model.sales = 37.0
	model.served = 2
	model._run_sales = 37.0
	model._run_served = 2
	var remaining_orders: Array = model.orders.slice(1).duplicate(true)
	var first_id: int = model.orders[0].id
	var inventory: Dictionary = _food_and_earnings(model)
	var time_before: float = model.time_left
	model.events.clear()
	var receipt: Dictionary = model.punch_customer()
	_check(receipt.ok and receipt.code == "customer_punched" and receipt.order_id == first_id, "punch receipt identifies the front customer who was actually removed")
	_check(model.orders == remaining_orders, "punch removes only the front customer and preserves queued orders and patience")
	_check(model.missed == 1 and model.get_stats().total_missed == 1 and model.streak == 0, "punch records one missed customer and breaks the streak")
	_check(_food_and_earnings(model) == inventory and model.time_left == time_before, "punch preserves every prepared or scooped donut, stock, earnings and clock without fines")
	_check(model.events.size() == 1 and model.events[0].type == "customer_punched" and model.events[0].order_id == receipt.order_id and model.events[0].missed == receipt.missed, "punch event and receipt agree without a sale or duplicate walkout")
	model.punch_customer()
	model.punch_customer()
	_check(model.orders.is_empty() and model.missed == 3 and model._arrival_clock <= 1.2, "clearing the queue counts each actual customer once and schedules a quick replacement")
	before = model.to_save()
	var event_count: int = model.events.size()
	_check(not model.punch_customer().ok and model.to_save() == before and model.events.size() == event_count, "repeating a punch at an empty counter cannot create misses or rewards")
	model.tick(1.3)
	_check(model.orders.size() == 1 and int(model.orders[0].id) > first_id and model.missed == 3, "normal arrivals recover promptly after the last customer is punched")
	_fill(model, "bag", "powdered")
	inventory = _food_and_earnings(model)
	model.punch_customer()
	_check(_food_and_earnings(model) == inventory and model.package_flavor == "powdered", "punch also preserves a fully coated order ready for another customer")
	model.tick_practice(0.1)
	_check(model.orders.size() == 1, "practice supplies another customer after a punch")
	model.finish_shift()
	before = model.to_save()
	_check(not model.punch_customer().ok and model.to_save() == before, "finished shift cannot continue punching or alter its results")


func _test_fryer_fire_and_recovery() -> void:
	var model = Stand.new()
	var before: Dictionary = model.to_save()
	_check(not model.extinguish_fire().ok and model.to_save() == before, "closed stand rejects extinguisher action without changing state")
	model.start_shift()
	before = model.to_save()
	_check(not model.extinguish_fire().ok and model.to_save() == before, "unnecessary extinguisher clicks do not cool the fryer or grant recovery effects")
	model.temperature = 204.0
	model.heat_setting = 2
	model.tick(4.0)
	_check(model.fire_danger == 0.0 and not model.fire_active, "subcritical cooling oil cannot build fire danger")
	model.new_run(981)
	model.external_delivery = true
	model.start_shift()
	model.heat_setting = 2
	model.tick(2.0)
	model.choose_package("bag")
	model.scoop()
	model.dump()
	model.scoop()
	var inventory: Dictionary = _food_and_earnings(model)
	model.temperature = 220.0
	model.heat_setting = 4
	model.events.clear()
	model.tick(4.1)
	_check(model.fire_danger > 0.30 and model.fire_danger < 0.35 and not model.fire_active, "unattended overheat builds gradual danger rather than igniting immediately")
	_check(not model.events.any(func(event): return event.type == "fire_warning"), "smoke warning is not emitted before the danger threshold")
	model.tick(0.2)
	_check(model.events.filter(func(event): return event.type == "fire_warning").size() == 1 and not model.fire_active, "danger threshold emits one warning with several seconds left to respond")
	var cooling = Stand.new()
	_check(cooling.from_save(JSON.parse_string(JSON.stringify(model.to_save()))), "partial fire danger survives save and resume")
	cooling.adjust_heat(-2)
	cooling.tick(0.1)
	_check(cooling.fire_danger < model.fire_danger and cooling.temperature > 205.0, "turning heat down reduces danger immediately while the oil is still hot")
	cooling.tick(6.0)
	_check(cooling.fire_danger == 0.0 and not cooling.fire_active, "responding during the warning safely prevents ignition")
	model.tick(7.6)
	_check(not model.fire_active and model.fire_danger > 0.98, "the unattended warning window lasts approximately twelve seconds")
	model.tick(0.2)
	_check(model.fire_active and model.overheated and model.fire_danger == 1.0 and model.phase == "playing", "continued overheating ignites a persistent recoverable fire")
	_check(model.events.filter(func(event): return event.type == "fire").size() == 1, "ignition emits exactly one fire event")
	_check(model.production_status().contains("FRYER FIRE") and model.get_stats().fire_active, "status and stats expose the active fire for presentation")
	var burning_copy = Stand.new()
	_check(burning_copy.from_save(JSON.parse_string(JSON.stringify(model.to_save()))) and burning_copy.fire_active, "an active fire remains active when reloading the shift")
	model.adjust_heat(-4)
	var produced: int = model.production_count
	model.tick(20.0)
	_check(model.fire_active and model.overheated and model.production_count == produced and model.temperature < 190.0, "a burning fryer cannot self-extinguish or resume production just by cooling")
	_check(_food_and_earnings(model) == inventory and model.events.filter(func(event): return event.type == "fire").size() == 1, "fire preserves existing food and earnings without repeated ignition events")
	var result: Dictionary = model.extinguish_fire()
	_check(result.ok and result.code == "extinguished" and not model.fire_active and not model.overheated and model.fire_danger == 0.0, "one extinguisher action clears the fire and danger")
	_check(model.heat_setting == 0 and is_equal_approx(model.temperature, 175.0) and is_equal_approx(model.fire_recovery, 2.4) and is_equal_approx(model.foam_time, 8.0), "extinguishing sets a safe heater and a short settling interval with lingering foam")
	_check(_food_and_earnings(model) == inventory and model.events.back().type == "extinguished", "extinguishing neither deletes inventory nor fabricates food or money")
	before = model.to_save()
	_check(not model.extinguish_fire().ok and model.to_save() == before, "repeated extinguisher click cannot refresh recovery or foam once the fire is out")
	model.adjust_heat(2)
	model.tick(2.3)
	_check(model.fire_recovery > 0.0 and model.production_count == produced and model.production_status().contains("settling"), "even a ready heater cannot produce during fire recovery")
	model.tick(1.5)
	_check(model.fire_recovery == 0.0 and model.production_count > produced and model.foam_time > 0.0, "production resumes after recovery while harmless foam remains visible")
	var practice_model = Stand.new()
	_check(practice_model.from_save(JSON.parse_string(JSON.stringify(burning_copy.to_save()))), "practice fire fixture restores normally")
	practice_model.extinguish_fire()
	var practice_time: float = practice_model.time_left
	var patience: float = practice_model.orders[0].patience
	practice_model.tick_practice(3.0)
	_check(practice_model.fire_recovery == 0.0 and practice_model.foam_time > 4.9 and practice_model.foam_time < 5.1 and practice_model.time_left == practice_time and practice_model.orders[0].patience == patience, "practice advances recovery and foam without spending shift time or customer patience")
	practice_model.tick_practice(6.0)
	_check(practice_model.foam_time == 0.0, "foam eventually clears in practice")
	practice_model.fire_danger = 0.5
	practice_model.foam_time = 3.0
	practice_model.sales = practice_model.target
	practice_model.finish_shift()
	practice_model.start_shift()
	_check(not practice_model.fire_active and practice_model.fire_danger == 0.0 and practice_model.fire_recovery == 0.0 and practice_model.foam_time == 0.0, "next shift resets all temporary fire and foam state")


func _test_fire_save_migration() -> void:
	var model = Stand.new()
	model.external_delivery = true
	model.start_shift()
	model.choose_package("bag")
	model.scoop()
	model.dump()
	model.scoop()
	model.tick(3.0)
	var original: Dictionary = model.to_save()
	var restored = Stand.new()
	for version in [2, 3]:
		var legacy: Dictionary = original.duplicate(true)
		legacy.version = version
		for key in ["fire_active", "fire_danger", "fire_recovery", "foam_time"]: legacy.erase(key)
		if version == 2:
			for key in ["waste_count", "_run_wasted", "_next_delivery_id", "_pending_deliveries"]: legacy.erase(key)
		var unchanged: Dictionary = legacy.duplicate(true)
		_check(restored.from_save(JSON.parse_string(JSON.stringify(legacy))) and restored.to_save().version == 5, "version%d save migrates through fire and expansion schemas" % version)
		_check(legacy == unchanged and restored.package_count == original.package_count and restored.scoop_count == original.scoop_count and restored.supply == original.supply and is_equal_approx(restored.time_left, original.time_left), "version%d migration preserves old input and work in progress" % version)
		_check(not restored.fire_active and restored.fire_danger == 0.0 and restored.fire_recovery == 0.0 and restored.foam_time == 0.0, "version%d migration does not invent a fire or recovery delay" % version)
		if version == 3: _check(restored.pending_delivery_ids() == original._pending_deliveries, "v3 migration preserves every uncredited physical donut delivery")
	for change in [{"fire_active": "true"}, {"fire_active": 1}, {"fire_danger": NAN}, {"fire_danger": -0.1}, {"fire_danger": 1.1}, {"fire_recovery": INF}, {"fire_recovery": -0.1}, {"fire_recovery": 2.5}, {"foam_time": -1.0}, {"foam_time": 8.1}, {"fire_active": true}, {"fire_danger": 1.0}, {"fire_recovery": 1.0, "foam_time": 0.5}]:
		var corrupt: Dictionary = original.duplicate(true)
		corrupt.merge(change, true)
		var before: Dictionary = restored.to_save()
		_check(not restored.from_save(corrupt) and restored.to_save() == before, "invalid fire fields reject transactionally: " + str(change))
	for key in ["fire_active", "fire_danger", "fire_recovery", "foam_time"]:
		var corrupt: Dictionary = original.duplicate(true)
		corrupt.erase(key)
		var before: Dictionary = restored.to_save()
		_check(not restored.from_save(corrupt) and restored.to_save() == before, "v4 cannot silently default missing fire field " + key)
	model.temperature = 220.0
	model.heat_setting = 4
	model.tick(12.1)
	model.extinguish_fire()
	model.tick(0.7)
	_check(restored.from_save(JSON.parse_string(JSON.stringify(model.to_save()))) and is_equal_approx(restored.fire_recovery, model.fire_recovery) and is_equal_approx(restored.foam_time, model.foam_time), "partly completed recovery and foam timers resume exactly")
	model.tick(2.0)
	restored.tick(2.0)
	_check(_same_state(model.to_save(), restored.to_save()), "resumed fire recovery produces deterministic subsequent machine and queue state")


func _test_physical_deliveries_and_overflow() -> void:
	var model = Stand.new()
	model.external_delivery = true
	model.start_shift()
	var epoch: int = model.delivery_epoch
	var opening_supply: int = model.supply
	model.tick(4.0)
	var pending: Array = model.pending_delivery_ids()
	_check(model.production_count >= 3 and pending.size() == model.production_count and model.supply == opening_supply, "physical output consumes batter but is unavailable until it actually lands")
	_check(model.batter + pending.size() == model.batter_capacity(), "in-flight donuts conserve consumed batter")
	var production_events: Array = model.events.filter(func(event): return event.type == "production")
	_check(production_events.size() == pending.size() and production_events[0].delivery_id == pending[0] and production_events[0].delivery_epoch == epoch, "each production event exposes its authoritative physical delivery identity")
	pending.clear()
	pending = model.pending_delivery_ids()
	_check(pending.size() == model.production_count, "presentation cannot mutate the pending ledger through its returned array")
	var before: Dictionary = model.to_save()
	_check(not model.settle_delivery(pending[0], true, epoch - 1).ok and model.to_save() == before, "stale physical generation cannot consume a current pending donut")
	var accepted: Dictionary = model.settle_delivery(pending[0], true, epoch)
	_check(accepted.ok and accepted.kept and accepted.accepted and model.supply == opening_supply + 1, "tray landing adds exactly one scoopable donut")
	before = model.to_save()
	_check(not model.settle_delivery(pending[0], true, epoch).ok and model.to_save() == before, "duplicate landing cannot double-credit food")
	_check(not model.settle_delivery(999999, true, epoch).ok and model.to_save() == before, "unknown physical food cannot fabricate stock")
	var missed: Dictionary = model.settle_delivery(pending[1], false, epoch)
	_check(missed.ok and not missed.kept and model.supply == opening_supply + 1 and model.waste_count == 1, "a donut that misses the tray is waste even when storage has space")
	before = model.to_save()
	_check(not model.settle_delivery(pending[1], false, epoch).ok and model.to_save() == before, "repeated waste callback cannot charge twice")
	model.supply = model.supply_capacity
	var overflow: Dictionary = model.settle_delivery(pending[2], true, epoch)
	_check(overflow.ok and not overflow.kept and not overflow.accepted and model.supply == model.supply_capacity and model.waste_count == 2, "authoritative tray capacity converts a late extra landing into waste")
	_check(model.sales == 0.0 and model.mistakes == 0 and model.streak == 0, "spillage spends food without adding unrelated score or mistake penalties")
	_check(model.get_stats().waste_count == 2 and model.get_stats().total_wasted == 2, "shift and career-run waste are exposed in stats")
	var spilled: Dictionary = model.spill_stock(2)
	_check(spilled.ok and spilled.wasted == 2 and model.supply == model.supply_capacity - 2 and model.waste_count == 4, "previously credited tray donuts are removed when physics knocks them onto the counter")
	before = model.to_save()
	_check(not model.spill_stock(-1).ok and model.to_save() == before, "invalid spill cannot manufacture or subtract food")
	spilled = model.spill_stock(1000)
	_check(spilled.wasted == model.supply_capacity - 2 and model.supply == 0, "spill accounting clips to actual available stock")
	before = model.to_save()
	_check(model.spill_stock().wasted == 0 and model.to_save() == before, "empty tray cannot be charged a second time for the same physical spill")
	model.tick(3.0)
	var saved: Dictionary = model.to_save()
	var copy = Stand.new()
	copy.external_delivery = true
	var old_copy_epoch: int = copy.delivery_epoch
	_check(copy.from_save(JSON.parse_string(JSON.stringify(saved))), "physical pending deliveries and waste survive JSON save/resume")
	_check(copy.pending_delivery_ids() == model.pending_delivery_ids() and copy.waste_count == model.waste_count and copy.supply == 0, "resume preserves distinct landed, pending and wasted inventory")
	_check(copy.delivery_epoch > old_copy_epoch and copy.external_delivery, "restoring invalidates old-world callbacks and preserves external delivery configuration")
	var restore_id: int = copy.pending_delivery_ids()[0]
	_check(copy.settle_delivery(restore_id, true, copy.delivery_epoch).kept and copy.supply == 1, "reconstructed in-flight donut credits stock once after resumed landing")
	var old_next_id: int = model._next_delivery_id
	var old_id: int = model.pending_delivery_ids()[0]
	var old_epoch: int = model.delivery_epoch
	model.sales = model.target
	model.finish_shift()
	_check(model.last_result.wasted == model.waste_count and model.last_result.total_wasted == model.get_stats().total_wasted, "shift results record actual food waste")
	model.start_shift()
	_check(model.pending_delivery_ids().is_empty() and model.waste_count == 0 and model.get_stats().total_wasted > 0, "next shift clears physical ledger and shift waste while retaining run waste")
	model.tick(2.0)
	_check(model.pending_delivery_ids()[0] >= old_next_id and model.delivery_epoch > old_epoch, "delivery IDs and runtime generations cannot repeat across shifts")
	before = model.to_save()
	_check(not model.settle_delivery(old_id, true, old_epoch).ok and model.to_save() == before, "previous shift's delayed landing cannot modify the next shift")
	old_next_id = model._next_delivery_id
	model.new_run(555)
	model.start_shift()
	model.tick(2.0)
	_check(model.pending_delivery_ids()[0] >= old_next_id and model.get_stats().total_wasted == 0, "new career run keeps unique physical IDs while resetting run waste")
	var old_format: Dictionary = saved.duplicate(true)
	old_format.version = 2
	for key in ["waste_count", "_run_wasted", "_next_delivery_id", "_pending_deliveries"]: old_format.erase(key)
	var migrated = Stand.new()
	_check(migrated.from_save(JSON.parse_string(JSON.stringify(old_format))), "version2 saves migrate into physical production without requiring nonexistent delivery fields")
	_check(migrated.supply == int(old_format.supply) and migrated.batter == int(old_format.batter) and migrated.production_count == int(old_format.production_count) and migrated.pending_delivery_ids().is_empty() and migrated.waste_count == 0, "legacy migration preserves all credited stock and never replays already credited production")
	for change in [{"_pending_deliveries": [0]}, {"_pending_deliveries": [saved._next_delivery_id]}, {"_pending_deliveries": [restore_id, restore_id]}, {"_pending_deliveries": ["1"]}, {"waste_count": -1}, {"_run_wasted": -1}, {"_next_delivery_id": 0}]:
		var broken: Dictionary = saved.duplicate(true)
		broken.merge(change, true)
		before = copy.to_save()
		_check(not copy.from_save(broken) and copy.to_save() == before, "malformed physical delivery ledger rejected without changing live state: " + str(change.keys()[0]))

	var oversized: Dictionary = saved.duplicate(true)
	oversized.production_count = 65
	oversized._next_delivery_id = 1000
	oversized._pending_deliveries = range(1, 66)
	before = copy.to_save()
	_check(not copy.from_save(oversized) and copy.to_save() == before, "oversized physical save ledger is rejected before creating excessive scene bodies")
	oversized._pending_deliveries = range(1, 65)
	_check(copy.from_save(oversized) and copy.pending_delivery_ids().size() == 64, "conservative pending-ledger boundary accepts sixty-four valid unique donuts")


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
	_check(model.shift_index == 1 and model.target == Stand.TARGETS[1] and model.time_left == 110.0 and model.served == 0, "next shift advances pressure while resetting shift counters")
	model.tick(1000.0)
	_check(model.phase == "lost" and model.time_left == 0.0, "missing timed quota loses cleanly")
	model.new_run(131)
	for index in range(18):
		model.start_shift()
		model.sales = model.target
		model.finish_shift()
	_check(model.phase == "won" and model.shift_index == 17, "eighteenth completed shift wins the full three-venue campaign")
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
	var invalid_offer: Dictionary = model.to_save()
	invalid_offer._offers = ["deep_scoop"]
	_check(not copy.from_save(invalid_offer), "saved shop cannot bypass equipment prerequisites")
	var invalid_result: Dictionary = model.to_save()
	invalid_result.last_result.best_streak = NAN
	_check(not copy.from_save(invalid_result), "saved career result cannot carry nonfinite best streak")
	var empty = Stand.new()
	_check(empty.from_save(JSON.parse_string(JSON.stringify(Stand.new().to_save()))), "ready stand state restores")


func _test_campaign_content_and_practice() -> void:
	var model = Stand.new()
	_check(model.total_shifts() == 18 and Stand.UPGRADES.size() >= 16, "complete campaign has eighteen shifts and at least sixteen equipment choices")
	var names: Dictionary = {}
	for index in range(18):
		model.start_shift()
		var info: Dictionary = model.get_campaign_info()
		names[model.shift_name] = true
		_check(not model.shift_description.is_empty() and info.modifiers.size() >= 1 and int(info.display_round) == index + 1, "shift has explanatory name, rules and round metadata")
		model.sales = model.target
		model.finish_shift()
	_check(names.size() == 18, "all eighteen rushes have distinct names")
	model.new_run(301, "relaxed")
	model.start_shift()
	_check(model.target == 88 and model.time_left == 126.0 and model.supply == 24, "relaxed mode grants explicit time, quota and opening-stock relief")
	_check(model.orders[0].max_patience > 56.0, "relaxed customers are more patient")
	var old_time: float = model.time_left
	var old_patience: float = model.orders[0].patience
	model.tick_practice(8.0)
	_check(model.time_left == old_time and model.orders[0].patience == old_patience and model.production_count > 0, "practice advances physical machine without spending clock or patience")
	_fill(model, "bag", "cinnamon")
	model.serve()
	model.tick_practice(0.1)
	_check(model.orders.size() == 1 and model.orders[0].flavor == "powdered", "practice supplies a new customer after service")
	model.sales = 99999.0
	model.tick_practice(30.0)
	_check(model.phase == "playing" and model.time_left == old_time, "practice cannot accidentally finish a scored run")
	model.new_run(302, "normal", "endless")
	_check(model.total_shifts() == 0 and model.get_campaign_info().endless, "endless exposes unlimited-round metadata")
	var old_target: int = 0
	for index in range(9):
		model.start_shift()
		_check(model.target > old_target, "endless quota grows every round")
		old_target = model.target
		model.sales = model.target
		model.finish_shift()
		_check(model.phase == "shop", "endless completion opens equipment shop instead of campaign victory")
	var restored = Stand.new()
	_check(restored.from_save(JSON.parse_string(JSON.stringify(model.to_save()))) and restored.mode == "endless" and restored.shift_index == 8, "endless rounds beyond campaign can resume from save")
	model.new_run(303)
	model.start_shift()
	var unassisted: Dictionary = model.to_save()
	_check(not model.apply_boost("coolant").ok and model.to_save() == unassisted, "deferred V2 boost API is explicitly disabled and cannot change V1 gameplay")


func _test_upgrade_synergies_and_receipts() -> void:
	var model = Stand.new()
	model.new_run(310)
	model.owned = {"wide_scoop": 1, "deep_scoop": 1, "generous_tips": 2, "rush_tips": 1, "loyal_customers": 1, "bag_deals": 1, "warm_welcome": 1}
	model.start_shift()
	model.streak = 2
	model.choose_package("bag")
	model.scoop()
	_check(model.scoop_count == 6 and model.scoop_capacity() == 6, "handling upgrades combine into a one-scoop bag")
	model.dump()
	model.coat("cinnamon")
	var preview: Dictionary = model.get_tip_breakdown()
	var before: Dictionary = model.to_save()
	model.get_tip_breakdown()
	_check(model.to_save() == before, "tip preview does not mutate gameplay or RNG")
	var receipt: Dictionary = model.serve()
	var sum: float = 0.0
	for line in receipt.tip_breakdown: sum += float(line.amount)
	_check(is_equal_approx(sum, receipt.amount) and is_equal_approx(receipt.amount, preview.amount), "displayed earnings breakdown sums to exact authoritative payout")
	_check(receipt.amount == 37.0 and receipt.streak_tip == 1.0 and receipt.upgrade_tip == 14.0, "fast bag, regulars, welcome and tip upgrades combine through explicit dollar bonuses")
	_check(model.get_stats().best_streak == 3, "run-wide best streak captures successful service")
	model.sales = model.target
	model.finish_shift()
	model.start_shift()
	_check(model.streak == 0 and model.get_stats().best_streak == 3, "best streak survives shift reset while current chain restarts")
	var restored = Stand.new()
	_check(restored.from_save(JSON.parse_string(JSON.stringify(model.to_save()))) and restored.get_stats().best_streak == 3, "best streak survives save and resume")
	model.new_run(311)
	model.owned["thermostat"] = 1
	model.start_shift()
	model.tick(80.0)
	_check(not model.overheated and model.temperature < 195.0, "thermostat makes recommended heat3 stable without removing manual heat4 risk")
	model.new_run(312)
	model.start_shift()
	model.sales = model.target
	model.finish_shift()
	_check(model.get_shop_offers()[0].id == "wide_scoop", "first shop guarantees useful handling upgrade")
	model.credits = 100
	model.buy_upgrade("wide_scoop")
	model.start_shift()
	model.sales = model.target
	model.finish_shift()
	_check(model.get_shop_offers()[0].id == "deep_scoop", "second shop offers prerequisite-compatible handling continuation")
	model.buy_upgrade("deep_scoop")
	model.start_shift()
	model.sales = model.target
	model.finish_shift()
	_check(model.get_shop_offers()[0].id == "fast_motor", "later shop guarantees throughput support for bigger scoop")


func _test_preventive_service_and_legacy_save() -> void:
	var model = Stand.new()
	model.start_shift()
	model.production_count = model._next_jam_at - 4
	model._refresh_alerts()
	_check(model.jam_risk > 0.72 and not model.jammed, "feed risk warns before a jam rather than springing an unseen failure")
	_check(model.events.any(func(event): return event.type == "jam_warning"), "rising risk emits one actionable warning")
	model.repair(0.6)
	var progress: float = model.jam_progress
	model.tick(0.4)
	_check(model.jam_progress == progress, "interrupting preventive service retains hold progress")
	var serviced: Dictionary = model.repair(0.6)
	_check(serviced.ok and serviced.code == "serviced" and model.jam_risk == 0.0 and not model.jammed, "proactive hold resets feed risk without requiring a breakdown")
	model.temperature = 196.0
	model.tick(0.1)
	_check(model.heat_warning and not model.overheated, "heat warning appears before thermal shutdown")
	model.new_run(320)
	model.start_shift()
	model.choose_package("bag")
	model.scoop()
	model.dump()
	model.tick(4.0)
	var old: Dictionary = model.to_save()
	old.version = 1
	for key in ["difficulty", "mode", "shift_name", "shift_description", "jam_risk", "heat_warning", "_best_streak", "_legacy_shift", "_machine_elapsed", "_last_jam_production", "_service_age", "_jam_warned", "assisted", "active_boosts", "waste_count", "_run_wasted", "_next_delivery_id", "_pending_deliveries", "fire_active", "fire_danger", "fire_recovery", "foam_time"]: old.erase(key)
	for order in old.orders:
		order.erase("menu_premium")
		order.erase("welcome")
	var migrated = Stand.new()
	_check(migrated.from_save(JSON.parse_string(JSON.stringify(old))), "version1 active save migrates into expanded campaign")
	_check(migrated.package_count == 3 and migrated.supply == model.supply and migrated.target == 110 and is_equal_approx(migrated.time_left, model.time_left), "migration protects work-in-progress, stock, target and remaining time")
	_check(migrated._legacy_shift and migrated.total_shifts() == 18, "migration marks preserved legacy shift inside full campaign")
	migrated.sales = migrated.target
	migrated.finish_shift()
	migrated.start_shift()
	_check(not migrated._legacy_shift and migrated.shift_name == "Powdered Parade" and migrated.target == 175, "next shift adopts expanded campaign after finishing legacy work")
	old.phase = "won"
	_check(not migrated.from_save(old) and not migrated.last_save_error.is_empty(), "already-finished old save returns a clear unsupported-save explanation")


func _test_paced_runs() -> void:
	for action_seconds in [0.65, 0.9, 1.2]:
		var wins: int = 0
		var first_clears: int = 0
		var example: Dictionary = {}
		var sample_count: int = 64 if action_seconds == 0.65 else 12
		for seed_index in range(sample_count):
			var result: Dictionary = _simulate_run(1600 + seed_index, action_seconds)
			if bool(result.won): wins += 1
			elif action_seconds == 0.65: print("FAST DRAFT REVIEW seed%d: %s" % [1600 + seed_index, str(result)])
			if int(result.cleared) >= 1: first_clears += 1
			if seed_index == 0: example = result
			_check(result.steps < 50000, "paced run terminates %.2fs/action seed%d" % [action_seconds, seed_index])
		if action_seconds == 0.65:
			_check(wins == sample_count, "competent tool-aware play can complete all eighteen shifts across64seeds")
		_check(first_clears == sample_count, "learnable opening is clearable at %.2fs per physical action" % action_seconds)
		print("STAND BALANCE %.2fs/action: %d/%d wins; example %s" % [action_seconds, wins, sample_count, str(example)])
	var relaxed_wins: int = 0
	for seed_index in range(12):
		if bool(_simulate_run(1800 + seed_index, 1.2, "relaxed").won): relaxed_wins += 1
	_check(relaxed_wins == 12, "relaxed difficulty supports deliberate1.2second physical actions across12seeds")
	print("RELAXED BALANCE 1.20s/action: %d/12 wins" % relaxed_wins)
	var physical_wins: int = 0
	var physical_relaxed_wins: int = 0
	for seed_index in range(12):
		if bool(_simulate_run(1600 + seed_index, 0.65, "normal", 7.0).won): physical_wins += 1
		if bool(_simulate_run(1800 + seed_index, 1.2, "relaxed", 7.0).won): physical_relaxed_wins += 1
	_check(physical_wins == 12, "seven-second physical transit remains clearable across twelve normal campaign seeds")
	_check(physical_relaxed_wins == 12, "seven-second physical transit preserves relaxed campaign accessibility across twelve seeds")
	print("PHYSICAL TRANSIT 7.00s: normal %d/12; relaxed %d/12 wins" % [physical_wins, physical_relaxed_wins])


func _simulate_run(seed_number: int, action_seconds: float, difficulty: String = "normal", delivery_delay: float = 0.0, animation_times: Dictionary = {}, shift_time_overrides: Dictionary = {}) -> Dictionary:
	var model = Stand.new()
	model.new_run(seed_number, difficulty)
	model.external_delivery = delivery_delay > 0.0
	model.start_shift()
	if shift_time_overrides.has(model.shift_index):
		model.shift_duration = float(shift_time_overrides[model.shift_index])
		model.time_left = model.shift_duration
	var transit: Dictionary = {}
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
		if steps >= 50000: break
		if model.phase == "shop":
			history.append({"sales": model.sales, "served": model.served, "walkouts": model.missed, "stock_wait": snappedf(stock_wait, 0.1)})
			cleared += 1
			var offers: Array = model.get_shop_offers()
			for preferred in ["wide_scoop", "deep_scoop", "fast_motor", "rush_tips", "loyal_customers", "bucket_sign", "generous_tips", "bag_deals", "calm_queue", "thermostat", "steady_feed", "easy_repair", "large_hopper", "quick_refill", "extra_tray", "warm_welcome", "crowd_pleaser", "opening_stock", "second_chance"]:
				for offer in offers:
					if str(offer.id) == preferred: model.buy_upgrade(preferred)
			model.start_shift()
			if shift_time_overrides.has(model.shift_index):
				model.shift_duration = float(shift_time_overrides[model.shift_index])
				model.time_left = model.shift_duration
			transit.clear()
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
				var animation: String = ""
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
						animation = str(order.package)
						tool = "none"
					elif model.package_type != str(order.package) or (not model.package_flavor.is_empty() and model.package_flavor != str(order.flavor)):
						model.discard()
						animation = "trash"
						tool = "none"
					elif model.package_count < model.package_capacity():
						if tool != "scoop":
							tool = "scoop"
							animation = "scoop"
						elif model.scoop_count > 0:
							model.dump()
							animation = "package"
						else:
							model.scoop()
							animation = "supply"
					elif model.package_flavor.is_empty():
						model.coat(str(order.flavor))
						animation = str(order.flavor)
						tool = "none"
					elif tool != "package":
						tool = "package"
						animation = "package"
					else:
						model.serve()
						animation = "serve"
						tool = "none"
				if not animation_times.is_empty() and not animation.is_empty():
					action_clock = action_seconds + float(animation_times.get(animation, 0.70))
		model.tick(0.1)
		if model.external_delivery:
			for id in model.pending_delivery_ids():
				transit[id] = float(transit.get(id, delivery_delay)) - 0.1
				if float(transit[id]) <= 0.000001:
					model.settle_delivery(int(id), true, model.delivery_epoch)
					transit.erase(id)
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
