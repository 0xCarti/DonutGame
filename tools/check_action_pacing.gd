extends "res://tests/test_stand_model.gd"
## Exercise the real animation lock times in the existing tool-aware campaign
## bot. Transit is deliberately conservative; this never touches player saves.
const World = preload("res://scripts/stand_world.gd")
const REACTION_SECONDS: float = 0.10
const DELIVERY_SECONDS: float = 7.0

func _run() -> void:
	var durations: Dictionary = World.ACTION_DURATIONS.duplicate()
	var report: Dictionary = {"reaction_seconds": REACTION_SECONDS, "delivery_seconds": DELIVERY_SECONDS, "animation_seconds": durations, "difficulties": {}}
	var trial: Dictionary = {}
	var report_suffix: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--trial-150-156": trial = {4: 150.0, 5: 156.0}; report_suffix = "-trial-150-156"
		elif arg == "--trial-150-155": trial = {4: 150.0, 5: 155.0}; report_suffix = "-trial-150-155"
	report["in_memory_shift_time_overrides"] = trial
	for difficulty in ["normal", "relaxed"]:
		var results: Array = []
		var wins: int = 0
		var openings: int = 0
		for index in range(12):
			var seed_number: int = (1600 if difficulty == "normal" else 1800) + index
			var result: Dictionary = _simulate_run(seed_number, REACTION_SECONDS, difficulty, DELIVERY_SECONDS, durations, trial if difficulty == "normal" else {})
			result["seed"] = seed_number
			results.append(result)
			if bool(result.won): wins += 1
			if int(result.cleared) > 0: openings += 1
			_check(int(result.steps) < 12000, "actual-duration campaign terminates: %s seed%d" % [difficulty, seed_number])
		report.difficulties[difficulty] = {"wins": wins, "opening_clears": openings, "sample_count": 12, "results": results}
		_check(openings == 12, "opening shift supports actual hand durations: " + difficulty)
		_check(wins == 12, "complete campaign supports actual hand durations across twelve seeds: " + difficulty)
		print("ACTION PACING %s: opening %d/12; campaign %d/12; example %s" % [difficulty, openings, wins, str(results[0])])
	var folder: String = ProjectSettings.globalize_path("res://playtest-reports")
	DirAccess.make_dir_recursive_absolute(folder)
	var file = FileAccess.open(folder.path_join("action-pacing-1.0.2" + report_suffix + ".json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("ACTION PACING QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
