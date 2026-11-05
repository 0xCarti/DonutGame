extends RefCounted
## Local career progress. Completion receipts are idempotent across save/resume.
## Tickets are earned locally. Cosmetics are presentation only; buffs are single-use.

const PATH = "user://career.json"
const VERSION = 2
const Catalog = preload("res://scripts/stand_catalog.gd")
const MAX_RECEIPTS = 100000
const MAX_TICKETS = 1000000000
const BADGE_TICKETS = 15
const COSMETICS = [
	{"id": "classic", "name": "Golden Hour", "description": "The original cream, cherry-red and emerald booth.", "requirement": "Available from the start", "accent": Color("edb763")},
	{"id": "midnight", "name": "Midnight Special", "description": "Deep blue canvas, cream paper and polished brass.", "requirement": "Serve 60 customers across your career", "accent": Color("8cb9e9")},
	{"id": "cherry", "name": "Cherry Jubilee", "description": "Rich burgundy, warm cream and golden finishing touches.", "requirement": "Complete the campaign", "accent": Color("e8a1a2")}
]
const BADGES = {
	"first_dozen": {"id": "first_dozen", "name": "First Dozen", "description": "Serve 12 customers across your career."},
	"regular": {"id": "regular", "name": "Fairground Regular", "description": "Serve 100 customers across your career."},
	"on_a_roll": {"id": "on_a_roll", "name": "On a Roll", "description": "Finish a run with a best service streak of 10."},
	"closing_crew": {"id": "closing_crew", "name": "Closing Crew", "description": "Complete the campaign."},
	"night_owl": {"id": "night_owl", "name": "Night Owl", "description": "Reach round 8 in Endless Service."},
	"rush_hour": {"id": "rush_hour", "name": "Rush Hour", "description": "Serve five correct orders within 45 seconds."},
	"no_crumb_left_behind": {"id": "no_crumb_left_behind", "name": "No Crumb Left Behind", "description": "Complete a shift with at least eight customers served and zero wasted donuts."},
	"this_is_fine": {"id": "this_is_fine", "name": "This Is Fine", "description": "Serve a correct order within 10 seconds of putting out a fryer fire."},
	"head_chef": {"id": "head_chef", "name": "Head Chef", "description": "Land a donut on a customer's head, then serve that customer correctly.", "secret": true},
	"express_checkout": {"id": "express_checkout", "name": "Express Checkout", "description": "Punch three customers in the same shift.", "secret": true},
	"air_mail": {"id": "air_mail", "name": "Air Mail", "description": "Launch a donut from the tray into an open bag.", "secret": true},
	"close_enough": {"id": "close_enough", "name": "Close Enough", "description": "Earn your first partial payout for an imperfect order."},
	"five_star_comeback": {"id": "five_star_comeback", "name": "Five-Star Comeback", "description": "Recover from the lowest stand appeal tier to the highest within one run."},
	"slow_and_steady": {"id": "slow_and_steady", "name": "Slow and Steady", "description": "Meet a shift's quota using only Slow feed."},
	"definitely_human": {"id": "definitely_human", "name": "Definitely Human", "description": "Correctly serve three seagulls disguised in a trench coat.", "secret": true},
	"unscheduled_delivery": {"id": "unscheduled_delivery", "name": "Unscheduled Delivery", "description": "Feed a customer with wings.", "secret": true}
}
var test_mode = false
var storage_path = PATH
var selected_cosmetic = "classic"
var total_runs = 0
var campaign_wins = 0
var total_served = 0
var total_sales = 0.0
var best_streak = 0
var records: Dictionary = {}
var badges: Array = []
var recent_runs: Array = []
var tickets: int = 0
var owned_items: Array = ["celebration_confetti"]
var loadout: Dictionary = Catalog.default_loadout()
var buff_inventory: Dictionary = {}
var shift_rewards: Dictionary = {}
var buff_transactions: Dictionary = {}
var load_warning = ""

func get_summary() -> Dictionary:
	return {"version": VERSION, "selected_cosmetic": selected_cosmetic, "total_runs": total_runs,
		"campaign_wins": campaign_wins, "total_served": total_served, "total_sales": total_sales,
		"best_streak": best_streak, "records": records.duplicate(true), "badges": badges.duplicate(),
		"recent_runs": recent_runs.duplicate(), "endless_unlocked": is_endless_unlocked(),
		"tickets": tickets, "owned_items": owned_items.duplicate(), "loadout": cosmetic_loadout(),
		"buff_inventory": buff_inventory.duplicate(true), "shift_rewards": shift_rewards.duplicate(true),
		"buff_transactions": buff_transactions.duplicate(true)}

func is_endless_unlocked() -> bool:
	return campaign_wins > 0

func get_cosmetics() -> Array:
	var result: Array = []
	for item in COSMETICS:
		var copy: Dictionary = item.duplicate()
		copy["unlocked"] = _cosmetic_unlocked(str(item.id))
		copy["selected"] = selected_cosmetic == str(item.id)
		result.append(copy)
	for item in Catalog.SETS:
		var copy: Dictionary = item.duplicate(true)
		copy["requirement"] = "%d Tickets in the stand shop" % int(item.tickets)
		copy["unlocked"] = owned_items.has(item.id)
		copy["selected"] = selected_cosmetic == str(item.id)
		result.append(copy)
	return result

func get_badges() -> Array:
	var result: Array = []
	for id in BADGES:
		var badge: Dictionary = BADGES[id].duplicate()
		badge["unlocked"] = badges.has(id)
		if badge.get("secret", false) and not badge.unlocked:
			badge.name = "???"
			badge.description = "Discover a fairground secret."
		result.append(badge)
	return result

func record_gag(id: String) -> bool:
	return record_achievement(id)

func record_achievement(id: String) -> bool:
	if not BADGES.has(id) or badges.has(id): return false
	badges.append(id)
	tickets = mini(MAX_TICKETS, tickets + BADGE_TICKETS)
	return true

func _cosmetic_unlocked(id: String) -> bool:
	if id == "classic" or (id == "midnight" and total_served >= 60) or (id == "cherry" and campaign_wins > 0): return true
	var item: Dictionary = Catalog.get_item(id)
	return item.get("slot") == "stand" and owned_items.has(id)

func select_cosmetic(id: String) -> bool:
	if not _cosmetic_unlocked(id): return false
	selected_cosmetic = id
	loadout["stand"] = id
	return true

func get_catalog() -> Array:
	var result: Array = Catalog.get_catalog()
	for item in result:
		item["owned"] = owned_items.has(item.id)
		item["equipped"] = loadout.get(str(item.slot), "") == item.id
		item["count"] = buff_count(str(item.id)) if item.kind == "buff" else (1 if item.owned else 0)
		item["affordable"] = tickets >= int(item.tickets)
	return result

func purchase_with_tickets(id: String) -> Dictionary:
	var item: Dictionary = Catalog.get_item(id)
	if item.is_empty(): return {"ok": false, "id": id, "reason": "unknown_item", "balance": tickets}
	if item.kind == "cosmetic" and owned_items.has(id):
		return {"ok": false, "id": id, "reason": "already_owned", "balance": tickets}
	var cost: int = int(item.tickets)
	if tickets < cost: return {"ok": false, "id": id, "reason": "insufficient_tickets", "cost": cost, "balance": tickets}
	if item.kind == "buff" and buff_count(id) >= 999:
		return {"ok": false, "id": id, "reason": "inventory_full", "balance": tickets}
	tickets -= cost
	if item.kind == "buff": buff_inventory[id] = buff_count(id) + 1
	else: owned_items.append(id)
	return {"ok": true, "id": id, "reason": "purchased", "cost": cost, "balance": tickets}

func equip_item(id: String) -> Dictionary:
	if _cosmetic_unlocked(id):
		select_cosmetic(id)
		return {"ok": true, "id": id, "slot": "stand", "reason": "equipped"}
	for slot in Catalog.DEFAULT_LOADOUT:
		if Catalog.DEFAULT_LOADOUT[slot] == id:
			loadout[slot] = id
			return {"ok": true, "id": id, "slot": slot, "reason": "equipped"}
	var item: Dictionary = Catalog.get_item(id)
	if item.is_empty() or item.kind != "cosmetic": return {"ok": false, "id": id, "reason": "not_a_cosmetic"}
	if not owned_items.has(id): return {"ok": false, "id": id, "reason": "not_owned"}
	loadout[str(item.slot)] = id
	if item.slot == "stand": selected_cosmetic = id
	return {"ok": true, "id": id, "slot": item.slot, "reason": "equipped"}

func cosmetic_loadout() -> Dictionary:
	var result: Dictionary = loadout.duplicate(true)
	result["stand"] = selected_cosmetic
	return result

func buff_count(id: String) -> int:
	return int(buff_inventory.get(id, 0)) if Catalog.is_buff(id) else 0

func consume_buff(id: String, transaction_id: String) -> bool:
	if not Catalog.is_buff(id) or not _identifier(transaction_id): return false
	if buff_transactions.has(transaction_id): return buff_transactions[transaction_id] == id
	if buff_count(id) <= 0 or buff_transactions.size() >= MAX_RECEIPTS: return false
	buff_inventory[id] = buff_count(id) - 1
	buff_transactions[transaction_id] = id
	return true

func grant_shift_reward(run_id: String, shift_index: int, summary: Dictionary) -> Dictionary:
	var result = {"ok": false, "granted": false, "tickets": 0, "balance": tickets, "reason": "invalid_shift"}
	if not _identifier(run_id) or shift_index < 0 or shift_index > 1000000: return result
	var receipt = JSON.stringify([run_id, shift_index])
	if shift_rewards.has(receipt):
		return {"ok": true, "granted": false, "tickets": 0, "balance": tickets, "reason": "already_rewarded"}
	if shift_rewards.size() >= MAX_RECEIPTS:
		result.reason = "receipt_limit"
		return result
	var completed: Variant = summary.get("completed", summary.get("met_target", summary.get("won", false)))
	if not completed is bool or not completed: return result
	if summary.get("mode", "campaign") not in ["campaign", "endless"]: return result
	var served: Variant = summary.get("served", 0)
	if not _integer(served, 0, 1000000): return result
	var earned: int = 25 + mini(int(served), 100)
	var credited: int = mini(earned, MAX_TICKETS - tickets)
	tickets += credited
	shift_rewards[receipt] = credited
	return {"ok": true, "granted": true, "tickets": credited, "balance": tickets, "reason": "shift_completed"}

func record_run(summary: Dictionary) -> Array:
	var run_id = str(summary.get("run_id", ""))
	if not _identifier(run_id) or recent_runs.has(run_id) or recent_runs.size() >= MAX_RECEIPTS: return []
	var mode = str(summary.get("mode", "campaign"))
	var difficulty = str(summary.get("difficulty", "normal"))
	if mode not in ["campaign", "endless"] or difficulty not in ["normal", "relaxed"]: return []
	for key in ["total_served", "total_sales", "best_streak", "shift"]:
		if not _number(summary.get(key, 0), 0, 1000000000): return []
	var won = bool(summary.get("won", false)) and mode == "campaign"
	var served = int(summary.get("total_served", 0))
	var earned = float(summary.get("total_sales", 0.0))
	var streak = int(summary.get("best_streak", 0))
	var shift = int(summary.get("shift", 1))
	total_runs += 1
	campaign_wins += 1 if won else 0
	total_served += served
	total_sales = snappedf(total_sales + earned, 0.01)
	best_streak = maxi(best_streak, streak)
	var key = mode + "/" + difficulty
	var record: Dictionary = records.get(key, {"sales": 0.0, "served": 0, "round": 0, "wins": 0})
	record["sales"] = maxf(float(record.sales), earned)
	record["served"] = maxi(int(record.served), served)
	record["round"] = maxi(int(record.round), shift)
	record["wins"] = int(record.wins) + (1 if won else 0)
	records[key] = record
	recent_runs.append(run_id)
	var unlocked: Array = []
	var conditions = {"first_dozen": total_served >= 12, "regular": total_served >= 100,
		"on_a_roll": best_streak >= 10, "closing_crew": campaign_wins > 0,
		"night_owl": mode == "endless" and shift >= 8}
	for id in conditions:
		if conditions[id] and record_achievement(id):
			unlocked.append(BADGES[id].duplicate())
	return unlocked

func save_profile() -> bool:
	if test_mode: return true
	var contents = JSON.stringify(get_summary(), "\t")
	var file = FileAccess.open(storage_path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(contents)
	file.flush()
	file.close()
	if FileAccess.file_exists(storage_path):
		var previous = _read_json(storage_path)
		if previous is Dictionary and _valid(previous):
			if DirAccess.copy_absolute(storage_path, storage_path + ".backup") != OK: return false
	return DirAccess.rename_absolute(storage_path + ".tmp", storage_path) == OK

func load_profile() -> bool:
	load_warning = ""
	if test_mode: return true
	if not FileAccess.file_exists(storage_path): return true
	var data = _read_json(storage_path)
	if data is Dictionary and from_data(data): return true
	if FileAccess.file_exists(storage_path + ".backup"):
		data = _read_json(storage_path + ".backup")
		if data is Dictionary and from_data(data):
			load_warning = "Career progress was restored from its backup."
			return true
	load_warning = "Career progress could not be read. The original file has been kept."
	return false

func _read_json(path: String) -> Variant:
	var parser = JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null

func from_data(data: Dictionary) -> bool:
	if not _valid(data): return false
	selected_cosmetic = str(data.selected_cosmetic)
	total_runs = int(data.total_runs)
	campaign_wins = int(data.campaign_wins)
	total_served = int(data.total_served)
	total_sales = float(data.total_sales)
	best_streak = int(data.best_streak)
	records = data.records.duplicate(true)
	for key in records:
		records[key].sales = float(records[key].sales)
		for metric in ["served", "round", "wins"]: records[key][metric] = int(records[key][metric])
	badges = data.badges.duplicate()
	recent_runs = data.recent_runs.duplicate()
	# V1 progress is preserved verbatim. New economy begins at zero; old badges
	# do not silently mint a one-time wallet grant during migration.
	if data.version == VERSION:
		tickets = int(data.tickets)
		owned_items = data.owned_items.duplicate()
		loadout = data.loadout.duplicate(true)
		buff_inventory = data.buff_inventory.duplicate(true)
		shift_rewards = data.shift_rewards.duplicate(true)
		buff_transactions = data.buff_transactions.duplicate(true)
		for id in buff_inventory: buff_inventory[id] = int(buff_inventory[id])
		for receipt in shift_rewards: shift_rewards[receipt] = int(shift_rewards[receipt])
	else:
		tickets = 0
		owned_items = ["celebration_confetti"]
		loadout = Catalog.default_loadout()
		buff_inventory = {}
		shift_rewards = {}
		buff_transactions = {}
	if not _cosmetic_unlocked(selected_cosmetic): selected_cosmetic = "classic"
	loadout["stand"] = selected_cosmetic
	return true

func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floor(float(value))

func _identifier(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128

func _valid(data: Dictionary) -> bool:
	if not _integer(data.get("version"), 1, VERSION): return false
	for key in ["total_runs", "campaign_wins", "total_served", "total_sales", "best_streak"]:
		if not _number(data.get(key), 0, 1000000000000): return false
	if float(data.campaign_wins) > float(data.total_runs): return false
	var chosen: Variant = data.get("selected_cosmetic")
	if not chosen is String: return false
	if chosen not in ["classic", "midnight", "cherry"] and Catalog.get_item(chosen).get("slot") != "stand": return false
	if not data.get("records") is Dictionary or data.records.size() > 4: return false
	for key in data.records:
		if key not in ["campaign/normal", "campaign/relaxed", "endless/normal", "endless/relaxed"]: return false
		var record = data.records[key]
		if not record is Dictionary: return false
		for metric in ["sales", "served", "round", "wins"]:
			if not _number(record.get(metric), 0, 1000000000000): return false
	if not data.get("badges") is Array or data.badges.size() > BADGES.size(): return false
	var seen: Dictionary = {}
	for badge in data.badges:
		if not BADGES.has(badge) or seen.has(badge): return false
		seen[badge] = true
	if not data.get("recent_runs") is Array or data.recent_runs.size() > MAX_RECEIPTS: return false
	seen.clear()
	for run_id in data.recent_runs:
		if not _identifier(run_id) or seen.has(run_id): return false
		seen[run_id] = true
	return _valid_economy(data) if data.version == VERSION else chosen in ["classic", "midnight", "cherry"]

func _valid_economy(data: Dictionary) -> bool:
	if not _integer(data.get("tickets"), 0, MAX_TICKETS): return false
	if not data.get("owned_items") is Array or data.owned_items.size() > Catalog.get_catalog().size(): return false
	var seen: Dictionary = {}
	for id in data.owned_items:
		if not id is String or seen.has(id): return false
		var item: Dictionary = Catalog.get_item(id)
		if item.is_empty() or item.kind != "cosmetic": return false
		seen[id] = true
	if not data.owned_items.has("celebration_confetti"): return false
	if not data.get("loadout") is Dictionary or data.loadout.size() != Catalog.SLOTS.size(): return false
	for slot in data.loadout:
		if slot not in Catalog.SLOTS: return false
		var id: Variant = data.loadout[slot]
		if not id is String: return false
		if slot == "stand":
			if id != data.selected_cosmetic: return false
			if id in ["classic", "midnight", "cherry"]: continue
		if Catalog.DEFAULT_LOADOUT[slot] == id: continue
		var item: Dictionary = Catalog.get_item(id)
		if item.is_empty() or item.get("slot") != slot or not data.owned_items.has(id): return false
	if not data.get("buff_inventory") is Dictionary or data.buff_inventory.size() > Catalog.BUFF_IDS.size(): return false
	for id in data.buff_inventory:
		if not id is String or not Catalog.is_buff(id) or not _integer(data.buff_inventory[id], 0, 999): return false
	if not data.get("shift_rewards") is Dictionary or data.shift_rewards.size() > MAX_RECEIPTS: return false
	for receipt in data.shift_rewards:
		if not receipt is String: return false
		var parser = JSON.new()
		if parser.parse(receipt) != OK: return false
		var tuple: Variant = parser.data
		if not tuple is Array or tuple.size() != 2 or not _identifier(tuple[0]) or not _integer(tuple[1], 0, 1000000): return false
		if receipt != JSON.stringify([str(tuple[0]), int(tuple[1])]): return false
		if not _integer(data.shift_rewards[receipt], 0, 125): return false
	if not data.get("buff_transactions") is Dictionary or data.buff_transactions.size() > MAX_RECEIPTS: return false
	for transaction_id in data.buff_transactions:
		if not _identifier(transaction_id): return false
		var id: Variant = data.buff_transactions[transaction_id]
		if not id is String or not Catalog.is_buff(id): return false
	return true
