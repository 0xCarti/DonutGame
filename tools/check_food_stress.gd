extends SceneTree
## Sustained real-controller physics/render stress. Does not write player data.
const Controller = preload("res://scripts/stand_main.gd")
var app
var failures: int = 0
var checks: int = 0
var delivery_ids: Dictionary = {}
var spill_ids: Dictionary = {}
var duplicate_deliveries: int = 0
var duplicate_spills: int = 0


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FOOD STRESS: " + description)


func _run() -> void:
	var native: bool = OS.get_cmdline_user_args().has("--stress-native")
	var baseline_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var disk_before: Dictionary = fingerprints()
	root.size = Vector2i(1280, 800)
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false)
	app.muted = true
	app.music_on = false
	app.audio.set_muted(true)
	app.audio.set_music_volume(0.0)
	app.audio.stop_music()
	app.world.delivery_settled.connect(func(id: int, _kept: bool):
		if delivery_ids.has(id): duplicate_deliveries += 1
		delivery_ids[id] = true)
	app.world.stock_spilled.connect(func(id: int):
		if spill_ids.has(id): duplicate_spills += 1
		spill_ids[id] = true)
	reset_stand()
	var elapsed: float = 0.0
	var duration: float = 30.0 if native else 45.0
	var next_return: float = 1.0
	var next_bump: float = 5.0
	var next_reset: float = 10.0 if native else 15.0
	var reset_interval: float = next_reset
	var resets: int = 1
	var transfers: int = 0
	var peak_bodies: int = 0
	var peak_pending: int = 0
	var peak_nodes: int = 0
	var peak_waste: int = 0
	var mismatches: int = 0
	var conservation_failures: int = 0
	var frame_ms: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var draws: Array[float] = []
	var focused_frames: int = 0
	while elapsed < duration:
		await physics_frame
		await process_frame
		var delta: float = minf(0.1, root.get_process_delta_time())
		elapsed += delta
		if elapsed >= next_reset:
			reset_stand()
			resets += 1
			next_reset += reset_interval
		if elapsed >= next_return:
			var visuals: Array[Node3D] = app.world._food.take_donuts(6)
			app.world._food.return_donuts(visuals)
			transfers += 1
			next_return += 1.0
		if elapsed >= next_bump:
			# An outward edge bump exercises loss of already credited inventory,
			# separately from new output missing an overflowing catch tray.
			var edge_body: RigidBody3D
			for entry in app.world._food._entries:
				if entry.stage == "resident" and (edge_body == null or entry.body.position.x > edge_body.position.x): edge_body = entry.body
			if edge_body != null:
				edge_body.sleeping = false
				edge_body.linear_velocity += Vector3(3.2, 2.8, 0.6)
			next_bump += 5.0
		# Stress continuous maximum upgraded production without service pauses;
		# this deliberately overrides maintenance rather than claiming balance.
		if app.model.jammed:
			app.model.jammed = false
			app.model._reset_feed_risk()
		if app.model.batter < 10: app.model.batter = app.model.batter_capacity()
		app.model.temperature = 190.0
		app.model.overheated = false
		app.model.tick_practice(delta)
		app._process_events()
		app._sync_world()
		var snapshot: Dictionary = app.world._food.debug_snapshot()
		peak_bodies = maxi(peak_bodies, int(snapshot.bodies))
		peak_waste = maxi(peak_waste, int(snapshot.waste))
		peak_pending = maxi(peak_pending, app.model.pending_delivery_ids().size())
		peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if app.model.supply != int(snapshot.available): mismatches += 1
		if app.model.supply + app.model.waste_count + app.model.pending_delivery_ids().size() != 60 + app.model.production_count: conservation_failures += 1
		if elapsed > 5.0:
			if native and DisplayServer.window_is_focused(): focused_frames += 1
			frame_ms.append(root.get_process_delta_time() * 1000.0)
			process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
			physics_ms.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
			draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	check(mismatches == 0, "model stock matches actual resident objects every frame")
	check(conservation_failures == 0, "all food remains accounted for across repeated production, spills and take/return")
	check(duplicate_deliveries == 0 and duplicate_spills == 0, "no delivery or stock spill callback is emitted twice")
	check(peak_bodies <= 100, "physical bodies remain within the designed bounded budget")
	check(peak_pending <= 64, "ordinary in-flight ledger remains below save safety limit")
	check(delivery_ids.size() >= (6 if native else 12) and spill_ids.size() > 0, "stress includes multiple actual landings and resident spills across resets")
	check(fingerprints() == disk_before, "stress preserves every actual player save/settings/career file")
	var report: Dictionary = {"native_renderer": native, "resolution": "1280x800", "game_seconds": snappedf(elapsed, 0.01), "warmup_seconds": 5, "sample_frames": frame_ms.size(), "focused_sample_frames": focused_frames, "static_batch_report": app.world._static_batch_report, "frame_ms_mean": mean(frame_ms), "frame_ms_p95": percentile(frame_ms, 0.95), "fps_from_mean": 1000.0 / maxf(0.001, mean(frame_ms)), "process_ms_mean": mean(process_ms), "physics_ms_mean": mean(physics_ms), "draw_calls_mean": mean(draws), "peak_bodies": peak_bodies, "peak_pending": peak_pending, "peak_visible_waste": peak_waste, "peak_nodes": peak_nodes, "resets": resets, "take_return_cycles": transfers, "unique_deliveries": delivery_ids.size(), "unique_resident_spills": spill_ids.size(), "duplicate_deliveries": duplicate_deliveries, "duplicate_spills": duplicate_spills, "stock_mismatch_frames": mismatches, "conservation_failure_frames": conservation_failures, "saves_unchanged": fingerprints() == disk_before}
	app.audio.stop_music()
	for player in app.audio.get_children():
		if player is AudioStreamPlayer: player.stop()
	OS.delay_msec(250)
	app.queue_free()
	await process_frame
	await process_frame
	await process_frame
	var orphans_after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	check(orphans_after <= baseline_orphans, "cleanup leaves no additional orphan nodes")
	report["orphan_nodes_before"] = baseline_orphans
	report["orphan_nodes_after"] = orphans_after
	report["checks"] = checks
	report["failures"] = failures
	var path: String = "res://playtest-reports/food-stress-%s.json" % ("native" if native else "headless")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("FOOD STRESS REPORT " + JSON.stringify(report))
	print("FOOD STRESS QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func reset_stand() -> void:
	app.model.new_run(1234, "normal", "campaign")
	app.model.owned = {"extra_tray": 2, "fast_motor": 2, "large_hopper": 2}
	app.model.start_shift()
	app.model.supply = 60
	app.model.temperature = 190.0
	app.model.heat_setting = 2
	app.practice = true
	app.paused = false
	app.held_tool = "none"
	app._show_play()
	app._sync_world()


func mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value in values: total += value
	return total / maxf(1.0, values.size())


func percentile(values: Array[float], fraction: float) -> float:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[clampi(int(float(ordered.size() - 1) * fraction), 0, ordered.size() - 1)] if not ordered.is_empty() else 0.0


func fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Controller.SAVE_PATH, Controller.SETTINGS_PATH, Controller.LEGACY_SAVE_PATH, Controller.LEGACY_SETTINGS_PATH, "user://career.json", "user://career.json.backup", Controller.SAVE_PATH + ".backup", Controller.SETTINGS_PATH + ".backup"]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result
