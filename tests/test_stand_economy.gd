extends SceneTree

const Profile = preload("res://scripts/player_profile.gd")
const Catalog = preload("res://scripts/stand_catalog.gd")
const Gateway = preload("res://scripts/purchase_gateway.gd")
var checks: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("ECONOMY FAIL: " + message)

func _run() -> void:
	var p = Profile.new()
	p.test_mode = true
	check(p.tickets == 0 and p.buff_count("fresh_oil") == 0, "career starts with an empty earned wallet and no buffs")
	check(p.get_badges().size() == 16, "six original and ten new achievements")
	var seen: Dictionary = {}
	var categories: Dictionary = {}
	for item in Catalog.get_catalog():
		check(not seen.has(item.id), "catalogue IDs are unique: " + str(item.id))
		seen[item.id] = true
		categories[item.category] = true
		check(item.tickets == item.ticket_cost and item.tickets >= 0 and item.currency == "tickets", "catalogue has real Tickets price: " + str(item.id))
	check(categories.size() == 5, "all five shop groups are represented")
	check(Catalog.BUFF_IDS.size() == 5, "all five approved buffs exist")
	check(not p.purchase_with_tickets("neon_midway").ok, "insufficient funds cannot buy a cosmetic")
	check(not p.equip_item("neon_midway").ok, "unowned cosmetics cannot equip")
	var before: Dictionary = p.get_summary()
	for bad in [{}, {"completed": false, "served": 20}, {"completed": "true"}, {"completed": true, "served": -1}, {"completed": true, "served": 1.5}, {"completed": true, "served": NAN}, {"completed": true, "mode": "practice"}]:
		check(not p.grant_shift_reward("invalid", 0, bad).ok and p.get_summary() == before, "invalid or incomplete shift does not mint Tickets")
	var reward: Dictionary = p.grant_shift_reward("first", 0, {"completed": true, "served": 12})
	check(reward.ok and reward.granted and reward.tickets == 37 and p.tickets == 37, "completed shift earns base reward plus customers")
	before = p.get_summary()
	check(not p.grant_shift_reward("first", 0, {"completed": true, "served": 999}).granted and p.get_summary() == before, "a repeated shift cannot be rewarded again with altered results")
	check(p.purchase_with_tickets("fresh_oil").ok and p.tickets == 12 and p.buff_count("fresh_oil") == 1, "buff purchase deducts price and adds one use")
	check(p.consume_buff("fresh_oil", "first:1:fresh_oil") and p.buff_count("fresh_oil") == 0, "buff consumes once")
	check(p.consume_buff("fresh_oil", "first:1:fresh_oil") and p.buff_count("fresh_oil") == 0, "same transaction replay succeeds without second removal")
	check(not p.consume_buff("good_vibes", "first:1:fresh_oil"), "one consume transaction cannot refer to two buffs")
	check(not p.consume_buff("fresh_oil", "new-transaction"), "empty inventory cannot be consumed")
	check(not p.consume_buff("unknown", "valid-id") and not p.consume_buff("fresh_oil", ""), "invalid buff requests do not mutate inventory")
	check(p.record_achievement("head_chef") and p.tickets == 27, "first achievement earns a small Tickets reward")
	before = p.get_summary()
	check(not p.record_achievement("head_chef") and not p.record_achievement("invented") and p.get_summary() == before, "achievements cannot award twice or accept unknown IDs")
	for badge in p.get_badges():
		if badge.id == "head_chef": check(badge.name == "Head Chef" and badge.unlocked, "earned secret reveals its name")
		if badge.id == "definitely_human": check(badge.name == "???" and not badge.unlocked, "unearned secret stays hidden")
	# Cross the old 256-entry window, then replay the first completion.
	for index in range(300):
		p.grant_shift_reward("long-career", index, {"completed": true, "served": 10})
		p.record_run({"run_id": "run-%d" % index, "shift": 1})
	before = p.get_summary()
	check(not p.grant_shift_reward("long-career", 0, {"completed": true, "served": 10}).granted and p.get_summary() == before, "shift receipts remain idempotent beyond 256 completions")
	check(p.record_run({"run_id": "run-0", "shift": 1}).is_empty() and p.get_summary() == before, "run receipts remain idempotent beyond 256 completions")
	for item in p.get_catalog():
		var previous_balance: int = p.tickets
		if item.id == "celebration_confetti": continue
		check(p.purchase_with_tickets(str(item.id)).ok, "earned Tickets can buy catalogue item: " + str(item.id))
		check(p.tickets == previous_balance - int(item.tickets), "purchase debits the published price: " + str(item.id))
		if item.kind == "cosmetic":
			check(p.equip_item(str(item.id)).ok and p.cosmetic_loadout()[item.slot] == item.id, "owned cosmetic equips its own slot: " + str(item.id))
			before = p.get_summary()
			check(not p.purchase_with_tickets(str(item.id)).ok and p.get_summary() == before, "duplicate cosmetic purchase is a no-op: " + str(item.id))
		else:
			check(p.buff_count(str(item.id)) == 1, "buff stock is distinct from cosmetic ownership: " + str(item.id))
	check(p.selected_cosmetic == "chrome_carnival", "shop palette uses the existing stand selection")
	check(p.equip_item("classic_gloves").ok and p.cosmetic_loadout().operator_gloves == "classic_gloves", "original operator look can be re-equipped")
	check(not p.equip_item("good_vibes").ok, "buffs cannot be equipped as cosmetics")
	var copy = Profile.new()
	copy.test_mode = true
	check(copy.from_data(JSON.parse_string(JSON.stringify(p.get_summary()))), "economy and receipts survive JSON serialization")
	check(copy.get_summary() == p.get_summary(), "roundtrip preserves full career ownership balances and selections")
	before = copy.get_summary()
	check(copy.consume_buff("fresh_oil", "first:1:fresh_oil") and copy.get_summary() == before, "consumption replay after reload keeps newly bought inventory intact")
	var corruptions: Array = []
	for key in ["tickets", "owned_items", "loadout", "buff_inventory", "shift_rewards", "buff_transactions"]:
		var missing: Dictionary = p.get_summary()
		missing.erase(key)
		corruptions.append(missing)
	var bad: Dictionary = p.get_summary()
	bad.tickets = -1
	corruptions.append(bad)
	bad = p.get_summary()
	bad.tickets = 0.5
	corruptions.append(bad)
	bad = p.get_summary()
	bad.buff_inventory.fresh_oil = INF
	corruptions.append(bad)
	bad = p.get_summary()
	bad.owned_items.append("unknown")
	corruptions.append(bad)
	bad = p.get_summary()
	bad.loadout.operator_gloves = "chrome_carnival_watch"
	corruptions.append(bad)
	bad = p.get_summary()
	bad.buff_transactions["forged"] = "neon_midway"
	corruptions.append(bad)
	bad = p.get_summary()
	bad.shift_rewards["malformed"] = 50
	corruptions.append(bad)
	for invalid in corruptions:
		check(not copy.from_data(invalid) and copy.get_summary() == before, "corrupt economy is rejected without partial mutation")
	var gateway = Gateway.new()
	check(not gateway.store_configured() and not gateway.get_status().available, "real checkout is unconfigured")
	for item in gateway.get_catalog():
		check(not item.available and not item.store_configured and item.price_text.is_empty() and item.product_id.is_empty(), "no invented live products or prices: " + str(item.id))
	check(not gateway.request_purchase("fresh_oil").ok and gateway.request_purchase("fresh_oil").reason == "store_unconfigured", "checkout returns a clear unavailable result")
	check(not gateway.request_purchase("forged-product").ok and not gateway.restore_purchases().ok, "unknown products and restores cannot create entitlements")
	check(copy.get_summary() == before, "gateway never changes local wallet or inventory")
	print("ECONOMY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
