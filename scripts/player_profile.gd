extends RefCounted
## Local career progress. Completion receipts are idempotent across save/resume.
## Cosmetics affect presentation only; no entitlements or purchases are implied.

const PATH = "user://career.json"
const VERSION = 1
const COSMETICS = [
	{"id": "classic", "name": "Golden Hour", "description": "The original cream, cherry-red and emerald booth.", "requirement": "Available from the start", "accent": Color("edb763")},
	{"id": "midnight", "name": "Midnight Special", "description": "Deep blue canvas, cream paper and polished brass.", "requirement": "Serve 60 customers across your career", "accent": Color("8cb9e9")},
	{"id": "cherry", "name": "Cherry Jubilee", "description": "Rich burgundy, warm cream and golden finishing touches.", "requirement": "Complete the six-shift campaign", "accent": Color("e8a1a2")}
]
const BADGES = {
	"first_dozen": {"id": "first_dozen", "name": "First Dozen", "description": "Serve 12 customers across your career."},
	"regular": {"id": "regular", "name": "Fairground Regular", "description": "Serve 100 customers across your career."},
	"on_a_roll": {"id": "on_a_roll", "name": "On a Roll", "description": "Finish a run with a best service streak of 10."},
	"closing_crew": {"id": "closing_crew", "name": "Closing Crew", "description": "Complete the six-shift campaign."},
	"night_owl": {"id": "night_owl", "name": "Night Owl", "description": "Reach round 8 in Endless Service."}
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
var load_warning = ""

func get_summary() -> Dictionary:
	return {"version": VERSION, "selected_cosmetic": selected_cosmetic, "total_runs": total_runs,
		"campaign_wins": campaign_wins, "total_served": total_served, "total_sales": total_sales,
		"best_streak": best_streak, "records": records.duplicate(true), "badges": badges.duplicate(),
		"recent_runs": recent_runs.duplicate(), "endless_unlocked": is_endless_unlocked()}

func is_endless_unlocked() -> bool:
	return campaign_wins > 0

func get_cosmetics() -> Array:
	var result: Array = []
	for item in COSMETICS:
		var copy: Dictionary = item.duplicate()
		copy["unlocked"] = _cosmetic_unlocked(str(item.id))
		copy["selected"] = selected_cosmetic == str(item.id)
		result.append(copy)
	return result

func get_badges() -> Array:
	var result: Array = []
	for id in BADGES:
		var badge: Dictionary = BADGES[id].duplicate()
		badge["unlocked"] = badges.has(id)
		result.append(badge)
	return result

func _cosmetic_unlocked(id: String) -> bool:
	return id == "classic" or (id == "midnight" and total_served >= 60) or (id == "cherry" and campaign_wins > 0)

func select_cosmetic(id: String) -> bool:
	if not _cosmetic_unlocked(id): return false
	selected_cosmetic = id
	return true

func record_run(summary: Dictionary) -> Array:
	var run_id = str(summary.get("run_id", ""))
	if run_id.is_empty() or run_id.length() > 128 or recent_runs.has(run_id): return []
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
	if recent_runs.size() > 256: recent_runs.pop_front()
	var unlocked: Array = []
	var conditions = {"first_dozen": total_served >= 12, "regular": total_served >= 100,
		"on_a_roll": best_streak >= 10, "closing_crew": campaign_wins > 0,
		"night_owl": mode == "endless" and shift >= 8}
	for id in conditions:
		if conditions[id] and not badges.has(id):
			badges.append(id)
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
	badges = data.badges.duplicate()
	recent_runs = data.recent_runs.duplicate()
	if not _cosmetic_unlocked(selected_cosmetic): selected_cosmetic = "classic"
	return true

func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

func _valid(data: Dictionary) -> bool:
	if data.get("version") != VERSION: return false
	for key in ["total_runs", "campaign_wins", "total_served", "total_sales", "best_streak"]:
		if not _number(data.get(key), 0, 1000000000000): return false
	if float(data.campaign_wins) > float(data.total_runs): return false
	if data.get("selected_cosmetic") not in ["classic", "midnight", "cherry"]: return false
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
	if not data.get("recent_runs") is Array or data.recent_runs.size() > 256: return false
	seen.clear()
	for run_id in data.recent_runs:
		if not run_id is String or run_id.is_empty() or run_id.length() > 128 or seen.has(run_id): return false
		seen[run_id] = true
	return true
