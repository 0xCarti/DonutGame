extends SceneTree
const Profile = preload("res://scripts/player_profile.gd")
var checks = 0
var failures = 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PROFILE FAIL: " + message)

func _run() -> void:
	var p = Profile.new()
	p.test_mode = true
	check(not p.is_endless_unlocked(), "new career does not bypass endless unlock")
	check(p.get_cosmetics().size() == 6, "three earned booth palettes plus three shop sets")
	check(p.select_cosmetic("classic"), "default palette available")
	check(not p.select_cosmetic("midnight"), "locked palette cannot be selected")
	var receipt = {"run_id":"first-run", "won": false, "mode":"campaign", "difficulty":"normal", "shift":2,"total_served":15,"total_sales":260.5,"best_streak":7}
	var rewards: Array = p.record_run(receipt)
	check(rewards.size() == 1 and rewards[0].id == "first_dozen", "first achievement grants after actual completed run")
	check(p.total_runs == 1 and p.total_served == 15, "career aggregates completed run")
	var before: Dictionary = p.get_summary()
	check(p.record_run(receipt).is_empty() and p.get_summary() == before, "repeated results are idempotent")
	receipt.run_id = "second-run"
	receipt.won = true
	receipt.shift = 6
	receipt.total_served = 51
	receipt.best_streak = 14
	rewards = p.record_run(receipt)
	check(p.campaign_wins == 1 and p.is_endless_unlocked(), "campaign victory unlocks endless")
	check(p.select_cosmetic("midnight") and p.select_cosmetic("cherry"), "earned palettes unlock by their real requirements")
	check(p.badges.has("closing_crew") and p.badges.has("on_a_roll"), "victory and streak achievements unlock")
	check(p.best_streak == 14 and p.total_sales == 521.0, "totals retain cents and maximum streak")
	receipt.run_id = "endless-run"
	receipt.mode = "endless"
	receipt.difficulty = "relaxed"
	receipt.won = false
	receipt.shift = 8
	p.record_run(receipt)
	check(p.badges.has("night_owl") and p.badges.has("regular"), "endless and career achievements grant")
	check(p.records.size() == 2 and p.records.has("endless/relaxed"), "difficulty and game mode records stay separate")
	check(p.campaign_wins == 1, "endless result does not invent a campaign win")
	check(p.get_badges()[-1].name == "???", "undiscovered gag badge keeps the surprise hidden")
	check(not p.record_gag("invented_badge"), "unknown gag cannot mutate career")
	check(p.record_gag("unscheduled_delivery"), "a real gull delivery can unlock its secret")
	check(not p.record_gag("unscheduled_delivery"), "repeat gull deliveries cannot duplicate the badge")
	check(p.get_badges()[-1].name == "Unscheduled Delivery" and p.get_badges()[-1].unlocked, "earned secret shows its name")
	var copy = Profile.new()
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(p.get_summary()))
	check(copy.from_data(roundtrip), "JSON career roundtrip loads")
	check(copy.total_served == p.total_served and copy.selected_cosmetic == p.selected_cosmetic, "career progress and selection survive roundtrip")
	check(copy.badges.has("unscheduled_delivery"), "secret gag badge survives profile roundtrip")
	before = copy.get_summary()
	for corrupt in [{}, {"version":999}, {"version":1,"total_runs":-1}]:
		check(not copy.from_data(corrupt) and copy.get_summary() == before, "invalid career does not partially mutate progress")
	var corrupt = p.get_summary()
	corrupt.total_sales = INF
	check(not copy.from_data(corrupt), "nonfinite money rejected")
	corrupt = p.get_summary()
	corrupt.badges.append("closing_crew")
	check(not copy.from_data(corrupt), "duplicate badges rejected")
	corrupt = p.get_summary()
	corrupt.records["campaign/normal"]["round"] = -2
	check(not copy.from_data(corrupt), "invalid record rejected")
	before = p.get_summary()
	check(p.record_run({"run_id":"bad", "total_sales":NAN}).is_empty() and p.get_summary() == before, "invalid result never adds career money")
	# Unit tests remain entirely in memory, including save/load entry points.
	p.storage_path = "user://a-directory-that-does-not-exist/profile.json"
	before = p.get_summary()
	check(p.save_profile() and p.load_profile() and p.get_summary() == before, "test mode performs no profile filesystem IO")
	var legacy: Dictionary = p.get_summary()
	legacy.version = 1
	for key in ["tickets", "owned_items", "loadout", "buff_inventory", "shift_rewards", "buff_transactions"]: legacy.erase(key)
	var migrated = Profile.new()
	migrated.test_mode = true
	check(migrated.from_data(legacy), "version one migrates in memory")
	check(migrated.selected_cosmetic == "cherry" and migrated.badges == p.badges and migrated.records == p.records, "migration preserves earned selection badges and records")
	check(migrated.recent_runs == p.recent_runs and migrated.tickets == 0, "migration preserves run receipts without inventing wallet value")
	check(migrated.cosmetic_loadout().stand == "cherry" and migrated.owned_items.has("celebration_confetti"), "migration initializes new loadout around the old palette")
	before = migrated.get_summary()
	check(migrated.record_run(receipt).is_empty() and migrated.get_summary() == before, "migrated completion receipts remain idempotent")
	legacy["tickets"] = 999999
	legacy["owned_items"] = "malformed extra field"
	check(migrated.from_data(legacy) and migrated.tickets == 0, "legacy extension fields cannot inject economy state")
	print("PROFILE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
