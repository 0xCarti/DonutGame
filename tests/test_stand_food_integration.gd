extends SceneTree
## Controller/model/world conservation using real SceneTree fixed-step physics.
const Controller = preload("res://scripts/stand_main.gd")
var app
var checks: int = 0
var failures: int = 0
var disk_before: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FOOD INTEGRATION: " + message)


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 800)
	disk_before = _persistent_fingerprints()
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	# Advance the model only when requested; visuals and rigid bodies still use
	# their actual engine callbacks, independently of our test coroutine.
	app.set_process(false)
	app.audio.set_muted(true)
	app.audio.set_music_volume(0.0)
	app.audio.stop_music()
	app.muted = true
	app.music_on = false
	app.tutorial_seen = true
	await _frames(2)
	await _test_landing_and_service()
	await _test_full_tray_overflow()
	await _test_pending_resume_and_pause()
	_check(_persistent_fingerprints() == disk_before, "all real run/settings/career save bytes remain unchanged")
	app.audio.stop_music()
	for player in app.audio.get_children():
		if player is AudioStreamPlayer: player.stop()
	# Let the independent audio mixer retire stopped voices even in --fixed-fps runs.
	OS.delay_msec(250)
	app.queue_free()
	await _frames(2)
	await create_timer(0.2).timeout
	print("FOOD INTEGRATION QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _reset(supply: int) -> void:
	app.model.new_run(90210, "normal", "campaign")
	app.model.start_shift()
	app.model.supply = supply
	app.practice = false
	app.paused = false
	app.held_tool = "none"
	app._show_play()
	app._sync_world()
	await _frames(2)
	_check(app.model.external_delivery and app.world._food.get_available_count() == supply, "controller reconstructs exactly the authoritative opening stock")


func _produce(seconds: float) -> void:
	app.model.tick(seconds)
	app._process_events()
	app._sync_world()


func _wait_landings(limit: int = 600) -> void:
	for frame in range(limit):
		if app.model.pending_delivery_ids().is_empty(): break
		await _frames(1)
	_check(app.model.pending_delivery_ids().is_empty(), "every physical delivery reaches a terminal kept/waste outcome")


func _action(station: String) -> void:
	app._act(station)
	for frame in range(180):
		if not app.world.is_action_busy(): break
		await _frames(1)
	await _frames(2)
	_check(not app.world.is_action_busy(), "physical action completes: " + station)


func _check_inventory(opening: int, context: String) -> void:
	_check(app.model.supply == app.world._food.get_available_count(), context + ": scoopable model stock matches live tray objects")
	var accounted: int = app.model.supply + app.model.scoop_count + app.model.package_count + app.model.waste_count + app.model.pending_delivery_ids().size()
	_check(accounted == opening + app.model.production_count, context + ": every original or produced donut is in exactly one inventory state")


func _test_landing_and_service() -> void:
	await _reset(18)
	_produce(1.3)
	_check(app.model.production_count == 1 and app.model.pending_delivery_ids().size() == 1, "one produced donut has one pending ledger entry")
	_check(app.model.supply == 18 and app.world._food.get_available_count() == 18, "conveyor food is not scoopable before its physical landing")
	await _frames(30)
	_check(app.model.supply == 18 and app.model.pending_delivery_ids().size() == 1, "stock remains unchanged while donut visibly traverses the conveyor")
	await _wait_landings()
	_check(app.model.supply == 19 and app.model.waste_count == 0, "real gravity/contact landing credits exactly one available donut")
	_check_inventory(18, "landing")
	await _action("bag")
	await _action("scoop")
	await _action("supply")
	_check(app.model.scoop_count == 3 and app.world._held_scoop_donuts.size() == 3, "scoop carries the same three removed physical visuals")
	_check_inventory(18, "scoop")
	await _action("package")
	_check(app.model.package_count == 3 and app.world._prep_donuts.size() == 3, "pour deposits all three carried donuts into the package")
	_check_inventory(18, "pour")
	await _action("supply")
	_check(app.model.scoop_count == 3 and app.model.package_count == 3, "recovery case has plain food in both scoop and bag")
	await _action("trash")
	await _frames(60)
	_check(app.model.package_count == 0 and app.model.scoop_count == 0 and app.model.waste_count == 0, "clearing plain food recovers it without charging waste")
	_check_inventory(18, "plain-food recovery")


func _test_full_tray_overflow() -> void:
	await _reset(36)
	_produce(1.3)
	_check(app.model.batter == app.model.batter_capacity() - 1 and app.model.pending_delivery_ids().size() == 1, "full tray still consumes batter and launches actual output")
	await _wait_landings(720)
	await _frames(90)
	_check(app.model.waste_count > 0, "actual full tray overflows and records food waste")
	_check(app.model.supply <= app.model.supply_capacity, "physical arrivals never exceed authoritative tray capacity")
	_check_inventory(36, "full-tray overflow")
	var visible_counter_waste: bool = false
	for entry in app.world._food.debug_snapshot().entries:
		if entry.stage == "waste" and not app.world._food._inside_tray(entry.position) and entry.position.y > 1.65:
			visible_counter_waste = true
	if not visible_counter_waste: print("FOOD OVERFLOW FAILURE SNAPSHOT " + JSON.stringify(app.world._food.debug_snapshot()))
	_check(visible_counter_waste, "overflow remains as a visible rigid donut on the counter outside the tray")


func _test_pending_resume_and_pause() -> void:
	await _reset(18)
	_produce(2.8)
	await _frames(30)
	var pending: Array = app.model.pending_delivery_ids()
	_check(pending.size() == 2, "save scenario contains two distinct airborne deliveries")
	var saved: Dictionary = {"model": app.model.to_save(), "held_tool": "none", "run_id": "food-integration", "best_streak": 0}
	app.saved_run = JSON.parse_string(JSON.stringify(saved))
	var old_epoch: int = app.model.delivery_epoch
	app._show_title()
	app._continue_run()
	_check(app.model.delivery_epoch > old_epoch and app.model.pending_delivery_ids() == pending, "continue restores pending IDs under a fresh world generation")
	var physical_pending: Array = []
	for entry in app.world._food.debug_snapshot().entries:
		if entry.id > 0: physical_pending.append(entry.id)
	_check(physical_pending.size() == pending.size() and physical_pending.has(pending[0]) and physical_pending.has(pending[1]), "each saved pending ID is reconstructed exactly once")
	# A repeated production notification must not duplicate a restored body.
	app.model.events.append({"type": "production", "delivery_id": pending[0], "delivery_epoch": app.model.delivery_epoch})
	app._process_events()
	_check(app.world._food.debug_snapshot().conveyor == 2, "replayed production event cannot duplicate restored in-flight food")
	await _frames(35)
	app._show_pause()
	var paused_transforms: Dictionary = {}
	for entry in app.world._food._entries: paused_transforms[int(entry.id)] = entry.body.global_transform
	var before_pending: Array = app.model.pending_delivery_ids()
	await _frames(45)
	var unchanged: bool = true
	for entry in app.world._food._entries:
		if not entry.body.global_transform.is_equal_approx(paused_transforms[int(entry.id)]): unchanged = false
	_check(unchanged and app.model.pending_delivery_ids() == before_pending, "pause freezes every resident and airborne transform and its pending stock ledger")
	app._close_overlay()
	await _wait_landings()
	_check(app.model.supply == 20 and app.model.waste_count == 0, "resumed pending food credits exactly twice with no duplicated inventory")
	_check_inventory(18, "resume")
	var duplicate_id: int = int(pending[0])
	var before: Dictionary = app.model.to_save()
	app._on_delivery_settled(duplicate_id, true)
	_check(app.model.to_save() == before, "repeated world landing callback cannot grant a second donut")
	await _reset(18)
	before = app.model.to_save()
	app._on_delivery_settled(duplicate_id, false)
	_check(app.model.to_save() == before, "old-world delivery callback cannot mutate a fresh shift")


func _persistent_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Controller.SAVE_PATH, Controller.SETTINGS_PATH, Controller.LEGACY_SAVE_PATH, Controller.LEGACY_SETTINGS_PATH, "user://career.json", "user://career.json.backup", Controller.SAVE_PATH + ".backup", Controller.SETTINGS_PATH + ".backup"]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result
