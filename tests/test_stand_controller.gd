extends SceneTree
## Real controller integration: physical station rays, dispatched input, orders,
## maintenance, menus, continuation, and byte-for-byte persistent save protection.

const Controller = preload("res://scripts/stand_main.gd")
const Model = preload("res://scripts/stand_model.gd")
const Profile = preload("res://scripts/player_profile.gd")

class SaveProbeController extends Controller:
	var intercept_persistence: bool = false
	var captured_writes: Array = []
	var captured_deletions: int = 0
	func _write_json_atomic(path: String, data: Dictionary) -> bool:
		if intercept_persistence:
			captured_writes.append({"path": path, "data": data.duplicate(true)})
			return true
		return super._write_json_atomic(path, data)
	func _delete_run_files() -> void:
		if intercept_persistence:
			captured_deletions += 1
			return
		super._delete_run_files()

class FailingProfile extends Profile:
	var fail_save: bool = true
	var save_attempts: int = 0
	func save_profile() -> bool:
		save_attempts += 1
		return not fail_save

var app
var checks: int = 0
var failures: int = 0
var disk_before: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# The headless display defaults to a square window. Use the actual baseline
	# playtest aspect ratio so world rays and screen event coordinates agree.
	root.size = Vector2i(1280, 800)
	disk_before = _persistent_fingerprints()
	app = SaveProbeController.new()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false)
	app.world.set_process(false)
	app.audio.set_muted(true)
	app.audio.set_music_volume(0.0)
	app.muted = true
	app.music_on = false
	app.reduced_motion = false
	app._apply_effect_settings()
	app.model.new_run(731)
	app.saved_run.clear()
	app.tutorial_seen = false
	app._show_title()
	await process_frame
	await physics_frame
	await physics_frame
	await _test_first_run()
	await _test_physical_counter()
	await _test_buffered_actions()
	await _test_container_with_scoop()
	await _test_empty_hand_tray_shake()
	await _test_bag_service()
	await _test_bucket_and_mistakes()
	await _test_maintenance_and_pause()
	await _test_settings_and_continuation()
	await _test_dashboard_and_practice()
	await _test_modes_and_atomic_save()
	await _test_shop_and_results()
	_test_result_save_failure()
	_test_save_load_notices()
	_check(_persistent_fingerprints() == disk_before, "integration leaves real Idea 2 save and settings bytes unchanged")
	app.audio.stop_music()
	for player in app.audio.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("STAND CONTROLLER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_first_run() -> void:
	_check(app.current_view == "title", "test mode starts at the normal title")
	_check(_has_label(app.screen, "GOLDEN HOUR"), "title identifies the game")
	await _click_text(app.screen, "OPEN THE STAND  >")
	_check(is_instance_valid(app.overlay), "new player sees instructions")
	_check(app.model.phase == "ready", "first-run instructions do not start the shift clock")
	_check(not app.tutorial_seen, "instructions are not marked seen before confirmation")
	_check(_has_label(app.overlay, "3  COAT, LIFT, HAND OVER"), "help explains the necessary physical handoff")
	await _click_text(app.overlay, "LET'S OPEN  >")
	_check(app.current_view == "play" and app.model.phase == "playing", "opening enters the first shift")
	_check(app.tutorial_seen and not is_instance_valid(app.overlay), "opening closes instructions and remembers them")
	_check(app.model.shift_index == 0 and app.model.target == Model.TARGETS[0], "opening uses the first shift quota")
	_check(app.model.orders.size() == 1 and app.model.orders[0]["package"] == "bag" and app.model.orders[0]["flavor"] == "cinnamon", "first customer teaches the bag and cinnamon sequence")


func _test_physical_counter() -> void:
	var camera: Camera3D = app.world.get_camera()
	_check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "stand uses a perspective 3D camera")
	_check(app.world._view_hands.get_parent() == camera and app.world._view_hands.visible, "operator hands occupy the player's camera space")
	_check(app.world._stations.size() == 13, "all thirteen actions have physical stations")
	var bounds: Rect2 = root.get_visible_rect()
	for station in Controller.STATION_NAMES:
		var point: Vector2 = app.world.station_screen_position(station)
		if not bounds.has_point(point) or app.world.pick_station(point) != station:
			print("STATION_RAY ", station, " point=", point, " hit=", app.world.pick_station(point), " bounds=", bounds)
		_check(bounds.has_point(point), "station center is in the initial camera view: " + station)
		_check(app.world.pick_station(point) == station, "3D ray reaches the correct physical station: " + station)
	await _click_station("bag")
	_check(app.model.package_type == "bag", "actual mouse dispatch selects the physical bag stack")
	await _click_station("scoop")
	_check(app.held_tool == "scoop" and app.world._held_scoop.visible, "actual mouse dispatch picks up a visible scoop")
	await _click_station("supply")
	_check(app.model.scoop_count == 3, "actual mouse dispatch scoops from the physical donut tray")
	await _click_station("package")
	_check(app.model.package_count == 3 and app.model.scoop_count == 0, "actual mouse dispatch pours into the physical package")
	app.world.look_offset(Vector2(30, -20))
	_check(app.world._look != Vector2.ZERO, "look gesture changes the operator view offset")
	await _key(KEY_HOME)
	_check(app.world._look == Vector2.ZERO, "Home recenters the operator view")
	await _key(KEY_X)
	_check(app.model.package_type.is_empty() and app.held_tool == "none", "discard clears the work surface and held tool")


func _test_empty_hand_tray_shake() -> void:
	_reset_shift(1902)
	app.hover_station = "supply"
	_check(app._guide_context().prompt == "Shake the tray to spread donuts", "empty-hand tray hover explains spreading instead of scooping")
	var stock: int = app.model.supply
	app._act("supply")
	_check(app.world._food.debug_snapshot().shaking and app.world._action == "tray_shake", "empty-hand tray click starts physical settling and hand animation together")
	_check(app.model.supply == stock and app.model.scoop_count == 0 and app.held_tool == "none", "shaking neither consumes nor manufactures food or tools")
	app._show_pause()
	var cooldown: float = app.world._food._shake_cooldown
	app._act("supply")
	_check(app.world._food._shake_cooldown == cooldown, "paused clicks cannot restart a tray shake")
	app._close_overlay()
	await _settle_hand_motion()
	_reset_shift(1903)
	app.held_tool = "package"
	app._act("supply")
	_check(not app.world._food.debug_snapshot().shaking, "a hand holding an order cannot shake the tray")
	app.held_tool = "none"

func _test_container_with_scoop() -> void:
	# Exercise actual shortcuts in both orders: tool before an empty container,
	# and a loaded tool retained while swapping the still-empty container.
	for kind in ["bag", "bucket"]:
		for loaded in [false, true]:
			_reset_shift(1950 + int(loaded) + (10 if kind == "bucket" else 0))
			app.model.orders[0]["package"] = kind
			app.hover_station = ""
			if loaded:
				await _key(KEY_V if kind == "bag" else KEY_B)
				var empty_guide: Dictionary = app._guide_context()
				_check(empty_guide.station == kind and empty_guide.prompt == "Switch to a " + kind and empty_guide.hint.contains("swap it directly"), "empty wrong container points to the matching " + kind + " stack instead of discard")
			await _key(KEY_S)
			_check(app.held_tool == "scoop" and (loaded or app.model.package_type.is_empty()), "scoop can be picked up before choosing " + kind)
			var scoop_guide: Dictionary = app._guide_context()
			_check(scoop_guide.station == kind and scoop_guide.hint.contains("scoop stays"), "container guide explains the retained scoop when choosing " + kind)
			if not loaded: _check(scoop_guide.hint.contains("free hand"), "initial " + kind + " guide explains the free-hand pickup")
			if loaded: await _key(KEY_F)
			if loaded:
				var loaded_guide: Dictionary = app._guide_context()
				_check(loaded_guide.station == kind and loaded_guide.prompt == "Switch to a " + kind and loaded_guide.key == ("B" if kind == "bag" else "V"), "loaded scoop with an empty wrong container directs an immediate " + kind + " swap")
				app._refresh_hud()
				_check(app.hud.prompt.text == loaded_guide.prompt, "visible HUD shows the direct " + kind + " swap instead of discarding the loaded scoop")
			var count: int = app.model.scoop_count
			var stock: int = app.model.supply
			var scoop_id: int = app.world._held_scoop.get_instance_id()
			var food_ids: Array[int] = []
			for donut in app.world._held_scoop_donuts: food_ids.append(donut.get_instance_id())
			app._act(kind)
			_check(app.model.package_type == kind and app.held_tool == "scoop" and app.world._held_type == "scoop", "choosing " + kind + " retains the held scoop immediately")
			_check(app.model.scoop_count == count and app.model.supply == stock and app.model.package_count == 0, "choosing " + kind + " preserves all stock and any loaded scoop contents")
			_check(not app.world._node_is_moving(app.world._held_scoop), "choosing " + kind + " does not schedule a scoop put-down")
			if not loaded:
				app._act("supply")
				_check(app._queued_action == "supply" and app.model.scoop_count == 0, "tray input waits behind the off-hand " + kind + " pickup")
			await _settle_hand_motion()
			_check(app.world._held_scoop.get_instance_id() == scoop_id and app.held_tool == "scoop", "the same scoop remains held after " + kind + " lands")
			if loaded:
				var retained_ids: Array[int] = []
				for donut in app.world._held_scoop_donuts: retained_ids.append(donut.get_instance_id())
				_check(retained_ids == food_ids and app.model.scoop_count == count, "swapping to " + kind + " retains the original loaded food objects")
			else:
				_check(app._queued_action.is_empty() and app.model.scoop_count == 3 and app.model.supply == stock - 3 and not app.world._food.debug_snapshot().shaking, "buffered supply scoops once after " + kind + " instead of shaking the tray")
			await _key(KEY_SPACE)
			_check(app.model.package_count == 3 and app.model.scoop_count == 0 and app.held_tool == "scoop", "retained scoop pours directly into the selected " + kind)
	# An occupied package must reject a replacement without disturbing either
	# its food or the freshly loaded scoop that the operator is still holding.
	for kind in ["bag", "bucket"]:
		_reset_shift(1970 + (1 if kind == "bucket" else 0))
		await _key(KEY_B if kind == "bag" else KEY_V)
		await _key(KEY_S)
		await _key(KEY_F)
		await _key(KEY_SPACE)
		await _key(KEY_F)
		app.model.orders[0]["package"] = "bucket" if kind == "bag" else "bag"
		app.hover_station = app.model.orders[0]["package"]
		var occupied_guide: Dictionary = app._guide_context()
		_check(occupied_guide.station == "trash" and occupied_guide.key == "X" and occupied_guide.hint.contains("recover plain donuts"), "filled wrong " + kind + " still requires safe recovery even when hovering the desired stack")
		var package_id: int = app.world._prep.get_instance_id()
		var hand_pose: Transform3D = app.world._hands[1].global_transform
		var scoop_pose: Transform3D = app.world._held_scoop.global_transform
		var serial: int = app.world._action_serial
		var stock: int = app.model.supply
		var food_ids: Array[int] = []
		for donut in app.world._held_scoop_donuts: food_ids.append(donut.get_instance_id())
		app._act("bucket" if kind == "bag" else "bag")
		_check(app.model.package_type == kind and app.model.package_count == 3 and app.model.scoop_count == 3 and app.model.supply == stock, "rejected replacement preserves the occupied " + kind + " and both portions of food")
		_check(app.held_tool == "scoop" and app.world._prep.get_instance_id() == package_id and app.world._action_serial == serial and not app.world.is_action_busy(), "rejected replacement preserves package identity and starts no hand action")
		_check(app.world._hands[1].global_transform.is_equal_approx(hand_pose) and app.world._held_scoop.global_transform.is_equal_approx(scoop_pose), "rejected replacement leaves the gripping hand and scoop pose untouched")
		var retained_ids: Array[int] = []
		for donut in app.world._held_scoop_donuts: retained_ids.append(donut.get_instance_id())
		_check(retained_ids == food_ids, "rejected replacement preserves the same loaded donut objects")

func _test_bag_service() -> void:
	_reset_shift(732)
	await _key(KEY_B)
	var stock: int = app.model.supply
	await _key(KEY_F)
	_check(app.model.supply == stock and app.model.scoop_count == 0, "tray cannot be scooped without picking up the tool")
	await _key(KEY_C)
	_check(app.model.package_flavor.is_empty(), "an empty package cannot be seasoned")
	await _key(KEY_S)
	await _key(KEY_F)
	_check(app.model.scoop_count == 3 and app.model.supply == stock - 3, "scoop transfers exactly three donuts from supply")
	await _key(KEY_F)
	_check(app.model.scoop_count == 3 and app.model.supply == stock - 3, "loaded scoop cannot duplicate donuts")
	await _key(KEY_SPACE)
	_check(app.model.package_count == 3 and app.held_tool == "scoop", "pouring retains the scoop for the next load")
	_check(app._guide_context().station != "trash", "partly filled correct container remains normal preparation rather than a mistake")
	await _key(KEY_C)
	_check(app.model.package_flavor.is_empty(), "half-filled bag cannot be seasoned")
	await _key(KEY_F)
	await _key(KEY_SPACE)
	_check(app.model.package_count == 6 and app.model.scoop_count == 0, "two full scoops fill a bag")
	await _key(KEY_E)
	_check(app.model.served == 0, "unseasoned or unlifted package cannot be handed over")
	await _key(KEY_C)
	_check(app.model.package_flavor == "cinnamon" and app.held_tool == "none", "seasoning leaves the finished package on the counter")
	await _key(KEY_E)
	_check(app.model.served == 0, "finished package must be lifted before handoff")
	await _key(KEY_SPACE)
	_check(app.held_tool == "package" and is_instance_valid(app.world._held_package) and app.world._held_package.visible, "lifting displays the held package")
	await _key(KEY_SPACE)
	_check(app.held_tool == "none", "clicking the work surface puts a held package down")
	await _key(KEY_SPACE)
	await _click_station("serve")
	_check(app.model.served == 1 and app.model.sales >= 18.0 and app.model.orders.is_empty(), "correct physical handoff pays once and advances the queue")
	_check(app.model.package_type.is_empty() and app.held_tool == "none", "successful handoff clears the package and hands")
	var revenue: float = app.model.sales
	await _key(KEY_E)
	_check(app.model.sales == revenue and app.model.served == 1, "repeated serve cannot duplicate a sale")


func _test_bucket_and_mistakes() -> void:
	_reset_shift(733)
	# Deterministic integration fixture: one bucket customer at full patience.
	app.model.orders[0]["package"] = "bucket"
	app.model.orders[0]["flavor"] = "powdered"
	app.model.orders[0]["base_price"] = 32.0
	app._sync_world()
	await _key(KEY_V)
	await _key(KEY_S)
	for portion in range(4):
		await _key(KEY_F)
		await _key(KEY_SPACE)
	_check(app.model.package_count == 12 and app.model.supply == 6, "four scoops fill a twelve-donut bucket")
	await _key(KEY_C)
	await _key(KEY_SPACE)
	var patience: float = app.model.orders[0]["patience"]
	await _key(KEY_E)
	_check(app.model.served == 0 and app.model.sales == 0.0 and app.model.mistakes == 1, "wrong sugar does not pay and records the mistake")
	_check(app.model.package_count == 12 and app.model.orders[0]["patience"] < patience, "wrong order preserves food and costs customer patience")
	app.hover_station = "serve"
	var recovery: Dictionary = app._guide_context()
	_check(recovery.station == "trash" and recovery.key == "X" and recovery.prompt == "Discard this order", "wrong coated food points to discard even when hovering the customer")
	await _key(KEY_P)
	_check(app.model.package_flavor == "cinnamon", "wrong coating cannot be overwritten")
	await _key(KEY_X)
	_check(app.model.package_type.is_empty() and app.model.supply == 6, "discarding coated food does not return edible stock")
	await _key(KEY_B)
	await _key(KEY_S)
	await _key(KEY_F)
	await _key(KEY_SPACE)
	recovery = app._guide_context()
	_check(recovery.station == "trash" and recovery.hint.contains("recover plain donuts"), "wrong container explains safe plain-donut recovery")
	await _key(KEY_X)
	app.model.supply = 18
	await _key(KEY_V)
	await _key(KEY_S)
	for portion in range(4):
		await _key(KEY_F)
		await _key(KEY_SPACE)
	await _key(KEY_P)
	await _key(KEY_SPACE)
	await _key(KEY_E)
	_check(app.model.served == 1 and app.model.sales >= 32.0 and app.model.orders.is_empty(), "correct replacement bucket completes the waiting order")


func _test_maintenance_and_pause() -> void:
	_reset_shift(734)
	app.model.jammed = true
	await _mouse_station("repair", true)
	_check(app.hold_station == "repair", "mouse down on the physical repair control begins a hold")
	await _mouse_station("repair", false)
	_check(app.hold_station.is_empty(), "mouse release stops the repair hold")
	await _key_event(KEY_R, true)
	_check(app.hold_station == "repair", "pressing R begins a continuous repair hold")
	for step in range(5): app._process(0.1)
	var progress: float = app.model.jam_progress
	_check(progress > 0.0 and progress < 1.0 and app.model.jammed, "partial repair advances without instantly clearing a jam")
	await _key(KEY_ESCAPE)
	_check(app.paused and app.hold_station.is_empty(), "pause cancels an active maintenance hold")
	var clock_before: float = app.model.time_left
	for step in range(5): app._process(0.1)
	_check(app.model.time_left == clock_before and app.model.jam_progress == progress, "paused game freezes both customer time and repair progress")
	await _key(KEY_B)
	_check(app.model.package_type.is_empty(), "production shortcuts cannot act through the pause overlay")
	await _key_event(KEY_R, false)
	await _key(KEY_ESCAPE)
	_check(not app.paused and app.hold_station.is_empty(), "resume does not restart a cancelled repair hold")
	await _key_event(KEY_R, true)
	for step in range(15): app._process(0.1)
	await _key_event(KEY_R, false)
	_check(not app.model.jammed and app.hold_station.is_empty(), "resumed hold finishes the remaining repair")
	app.model.production_count = app.model._next_jam_at - 4
	app.model._refresh_alerts()
	await _key_event(KEY_R, true)
	app._process(0.1)
	_check(app.hud.condition.text == "SERVICING" and not app.model.jammed, "preventive maintenance reports servicing instead of active production")
	await _key_event(KEY_R, false)
	app.model.batter = 0
	await _key_event(KEY_T, true)
	for step in range(6): app._process(0.1)
	await _key_event(KEY_T, false)
	_check(app.model.refill_progress > 0.0 and app.model.batter == 0 and app.hold_station.is_empty(), "released refill preserves partial progress without prematurely granting batter")
	await _key_event(KEY_T, true)
	for step in range(16): app._process(0.1)
	await _key_event(KEY_T, false)
	_check(app.model.batter >= app.model.batter_capacity() - 1 and app.model.refill_progress == 0.0, "resumed refill restores the hopper and resets progress")
	var heat: int = app.model.heat_setting
	await _key(KEY_MINUS)
	_check(app.model.heat_setting == heat - 1, "minus adjusts the physical heater setting down")
	await _key(KEY_EQUAL)
	_check(app.model.heat_setting == heat, "plus adjusts the heater setting back up")
	await _key(KEY_H)
	_check(app.paused and is_instance_valid(app.overlay), "help pauses the running shift")
	await _click_text(app.overlay, "GOT IT")
	_check(not app.paused and app.current_view == "play", "help dismissal resumes the same shift")


func _test_settings_and_continuation() -> void:
	app._show_settings()
	await _click_text(app.overlay, "Motion: FULL")
	_check(app.reduced_motion and app.world._reduced_motion, "reduced motion setting reaches the physical world")
	await _click_text(app.overlay, "Motion: REDUCED")
	_check(not app.reduced_motion and not app.world._reduced_motion, "full motion can be restored")
	await _click_text(app.overlay, "Music: OFF")
	_check(app.music_on, "music preference can be enabled independently of master mute")
	await _click_text(app.overlay, "Music: ON")
	_check(not app.music_on, "music preference can be disabled")
	var sliders: Array = _find_sliders(app.overlay)
	_check(sliders.size() == 4, "settings exposes effects, music, ambience and look sliders")
	if sliders.size() == 4:
		sliders[0].value = 26
		sliders[2].value = 42
		sliders[3].value = 80
		_check(is_equal_approx(app.sfx_volume, 0.26) and is_equal_approx(app.audio.sfx_volume, 0.26), "effects slider reaches the live audio mix")
		_check(is_equal_approx(app.ambience_volume, 0.42) and is_equal_approx(app.audio.ambience_volume, 0.42), "ambience slider reaches the machine and fairground mix")
		_check(is_equal_approx(app.look_sensitivity, 1.67), "look sensitivity slider changes camera input scale")
	await _click_text(app.overlay, "Look: NORMAL")
	_check(app.invert_look, "vertical mouse look can be inverted")
	await _click_text(app.overlay, "Look: INVERTED")
	_check(not app.invert_look, "normal mouse look can be restored")
	await _click_text(app.overlay, "DONE")
	_check(not app.paused and not is_instance_valid(app.overlay), "settings Done returns to play")
	_reset_shift(735)
	await _key(KEY_B)
	await _key(KEY_S)
	await _key(KEY_F)
	var snapshot: Dictionary = app.model.to_save()
	app.saved_run = {"model": snapshot.duplicate(true), "held_tool": "scoop"}
	app._show_title()
	app.model.new_run(736)
	await _click_text(app.screen, "CONTINUE YOUR SHIFT")
	_check(app.current_view == "play" and app.model.phase == "playing", "continue restores the running shift")
	_check(app.held_tool == "scoop" and app.model.scoop_count == 3 and app.model.package_type == "bag", "continue preserves loaded scoop and the prepared container")
	_check(app.model.time_left == snapshot["time_left"], "continue preserves remaining shift time")
	app._save_run()
	app._save_settings()
	_check(_persistent_fingerprints() == disk_before, "test mode suppresses explicit run and settings writes")
	app._show_title()
	await _click_text(app.screen, "OPEN THE STAND  >")
	_check(is_instance_valid(app.overlay) and _has_label(app.overlay, "A fresh start?"), "new run asks before replacing an existing saved run")
	await _click_text(app.overlay, "Keep my run")
	_check(app.current_view == "title" and not app.saved_run.is_empty(), "cancelling a fresh run preserves continuation")
	app.saved_run.clear()


func _test_dashboard_and_practice() -> void:
	_reset_shift(739)
	app.hover_station = ""
	app._refresh_hud()
	_check(app.hud.progress.text == "$0" and app.hud.target.text == "/ $110", "dashboard clearly separates sales and quota")
	_check(app.hud.clock.text == "1:45", "dashboard uses the actual shift countdown")
	_check(app.hud.orders[0].order.text == "Bag  ·  6" and app.hud.orders[0].flavor.text == "Cinnamon sugar", "current ticket names container quantity and sugar")
	_check(app.hud.orders[1].flavor.text.is_empty(), "empty queued tickets remain visually quiet")
	_check(app.hud.key.text == "B" and app.hud.prompt.text == "Take the right container", "guide identifies the next useful physical action and its shortcut")
	app.model.jammed = true
	app._refresh_hud()
	_check(app.hud.fault.visible and app.hud.warning.text == "FEEDER JAMMED", "jam produces a persistent prominent fault card")
	_check(app.hud.fault_action.text.contains("Hold R") and app.dashboard.fault_target.x >= 0, "jam alert explains the exact action and points to the physical lever")
	var notices_before: int = app.toast_layer.get_child_count()
	for tick in range(30): app._process(0.1)
	_check(app.hud.warning.text == "FEEDER JAMMED" and app.toast_layer.get_child_count() <= notices_before, "unresolved jam remains visible without per-frame toast spam")
	app.model.jammed = false
	app.model.overheated = true
	app.model.temperature = 210
	app._refresh_hud()
	_check(app.hud.warning.text == "OIL TOO HOT" and app.hud.fault_action.text.contains("190"), "overheat has a distinct cause and cooldown instruction")
	app.hold_station = "refill"
	app.model.refill_progress = 0.4
	app._refresh_hud()
	_check(app.hud.fault_action.text.contains("190") and not app.hud.hold.visible, "refilling cannot replace an unrelated overheat instruction")
	_check(app.hud.hint.text.contains("40%"), "active maintenance progress stays visible below even when another fault has priority")
	app.hold_station = ""
	app.model.refill_progress = 0.0
	app.model.overheated = false
	app.model.temperature = 175
	app.model.batter = 4
	app._refresh_hud()
	_check(app.hud.warning.text == "BATTER RUNNING LOW" and app.hud.fault_action.text.contains("Hold T"), "low batter warning arrives before production stops")
	var retained_save: Dictionary = {"model": app.model.to_save(), "held_tool": "none", "run_id": "fixture-campaign"}
	app.saved_run = retained_save.duplicate(true)
	app._start_practice()
	_check(app.practice and app.current_view == "play", "practice opens a functioning physical counter")
	var clock_before: float = app.model.time_left
	var patience_before: float = app.model.orders[0].patience
	for tick in range(50): app._process(0.1)
	_check(app.model.time_left == clock_before and app.model.orders[0].patience == patience_before, "practice freezes both quota time and customer patience")
	_check(app.hud.clock.text == "OPEN" and app.hud.clock_caption.text == "NO CLOCK" and app.hud.mode.text.contains("PRESSURE"), "practice visibly explains its nonpunitive rules with portable font glyphs")
	app._save_run()
	_check(app.saved_run == retained_save, "practice does not replace the saved campaign wrapper")
	app._show_pause()
	await _click_text(app.overlay, "Try a jam")
	_check(app.model.jammed and not app.paused, "practice offers a repeatable hands-on jam lesson")
	app._show_pause()
	await _click_text(app.overlay, "LEAVE PRACTICE")
	_check(app.current_view == "title" and app.practice and app.saved_run == retained_save, "leaving practice preserves campaign continuation and marks its model as practice")
	# Exercise the production close path, intercepting only the disk boundary.
	# test_mode alone would hide this regression by returning before the practice guard.
	app.intercept_persistence = true
	app.captured_writes.clear()
	app.test_mode = false
	app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.test_mode = true
	app.intercept_persistence = false
	_check(app.captured_writes.is_empty() and app.saved_run == retained_save, "closing from title after practice cannot save practice over the campaign")
	app._show_collection()
	_check(app.current_view == "collection" and _has_label(app.screen, "A stand with a story."), "collection displays earned stand appearances and career progress")
	_check(_find_button(app.screen, "BACK TO THE STAND") != null, "collection has a clear return path")
	app.saved_run.clear()


func _test_modes_and_atomic_save() -> void:
	app.saved_run.clear()
	app.tutorial_seen = true
	var previous_wins: int = app.profile.campaign_wins
	app.profile.campaign_wins = 0
	app._show_title()
	var endless = _find_button(app.screen, "ENDLESS  ·  WIN A CAMPAIGN")
	_check(endless != null and endless.disabled, "Endless clearly explains its earned unlock condition")
	await _click_text(app.screen, "RELAXED")
	await _click_text(app.screen, "OPEN THE STAND  >")
	_check(app.model.difficulty == "relaxed" and app.model.target < Model.TARGETS[0] and app.model.shift_duration > Model.SHIFT_TIMES[0], "Relaxed selection applies real model difficulty changes")
	app.profile.campaign_wins = 1
	app._show_title()
	await _click_text(app.screen, "ENDLESS RUSH")
	_check(app.model.mode == "endless" and app.hud.shift.text.begins_with("ROUND 1"), "earned Endless starts an actual endless run with round-specific HUD")
	app.model.sales = app.model.target
	app.model.finish_shift()
	app._process(0.0)
	_check(app.model.phase == "shop" and app.current_view == "shop", "Endless progression continues through the earned equipment shop")
	app.profile.campaign_wins = previous_wins
	var directory = ProjectSettings.globalize_path("res://builds/controller-save-tests")
	DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.path_join("fixture-%d.json" % Time.get_ticks_usec())
	_check(not FileAccess.file_exists(path), "atomic-save fixture uses a fresh workspace-only path")
	_check(app._write_json_atomic(path, {"revision": 1}), "atomic save writes its first complete document")
	_check(app._write_json_atomic(path, {"revision": 2}), "atomic save replaces the document successfully")
	var current = JSON.parse_string(FileAccess.get_file_as_string(path))
	var backup = JSON.parse_string(FileAccess.get_file_as_string(path + ".backup"))
	_check(current is Dictionary and current.get("revision") == 2 and backup is Dictionary and backup.get("revision") == 1, "atomic replacement retains the prior valid document as a recovery backup")
	_check(not FileAccess.file_exists(path + ".tmp"), "successful atomic save leaves no pending temporary file")
	for suffix in ["", ".backup", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	_check(app._safe_setting({"value": INF}, "value", 0.5, 0.0, 1.0) == 0.5, "nonfinite saved preference falls back safely")
	_check(app._safe_setting({"value": 7.0}, "value", 0.5, 0.0, 1.0) == 1.0, "out-of-range saved preference is clamped")


func _test_shop_and_results() -> void:
	_reset_shift(737)
	app.model.sales = app.model.target
	app.model.served = 7
	app.model.finish_shift()
	app._process(0.0)
	_check(app.current_view == "shop" and app.model.phase == "shop", "meeting quota opens the between-shift shop")
	var offers: Array = app.model.get_shop_offers()
	_check(offers.size() == 3 and _buttons_with_prefix(app.screen, "INSTALL").size() == 3, "all three upgrade offers are visible and actionable")
	var offer: Dictionary = offers[0]
	app.model.credits = 100
	app._show_shop()
	var credits_before: int = app.model.credits
	app._buy_upgrade(str(offer["id"]))
	_check(app.model.level(str(offer["id"])) == 1 and app.model.credits == credits_before - int(offer["cost"]), "shop purchase applies upgrade and deducts the displayed price")
	var owned_before: Dictionary = app.model.owned.duplicate(true)
	await _click_text(app.screen, "START NEXT SHIFT  >")
	_check(app.current_view == "play" and app.model.shift_index == 1 and app.model.phase == "playing", "next shift advances from the shop")
	_check(app.model.owned == owned_before and app.model.sales == 0.0 and app.model.time_left == Model.SHIFT_TIMES[1], "next shift keeps upgrades and resets the working clock and sales")
	app.model.shift_index = Model.TARGETS.size() - 1
	app.model.target = Model.TARGETS[-1]
	app.model.sales = app.model.target
	app.model.finish_shift()
	app._process(0.0)
	_check(app.model.phase == "won" and app.current_view == "result" and _has_label(app.screen, "Rush handled."), "final campaign shift shows the success result")
	_check(_has_label_containing(app.screen, "SHIFT 6 / 6"), "success reports the actual final campaign shift")
	await _click_text(app.screen, "Back to the stand")
	_check(app.current_view == "title", "result can return to the title")
	_reset_shift(738)
	app.model.time_left = 0.05
	app._process(0.1)
	_check(app.model.phase == "lost" and app.current_view == "result" and _has_label(app.screen, "Closing time."), "missed quota opens the failure result")
	_check(_has_label_containing(app.screen, "SHIFT 1 / 6"), "failure reports the actual failed shift")
	await _click_text(app.screen, "OPEN AGAIN")
	_check(app.current_view == "play" and app.model.phase == "playing" and app.model.shift_index == 0, "replay starts a fresh first shift")
	_check(app.model.sales == 0.0 and app.model.owned.is_empty() and app.held_tool == "none", "replay clears earnings, upgrades and held tools")


func _test_result_save_failure() -> void:
	_reset_shift(740)
	var original_profile = app.profile
	var failing_profile = FailingProfile.new()
	app.profile = failing_profile
	app.run_id = "result-save-failure-fixture"
	app.saved_run = {"model": app.model.to_save(), "held_tool": "none", "run_id": app.run_id}
	var checkpoint: Dictionary = app.saved_run.duplicate(true)
	app.model.finish_shift()
	app.intercept_persistence = true
	app.captured_writes.clear()
	app.captured_deletions = 0
	app.test_mode = false
	app._finish_run()
	_check(failing_profile.total_runs == 1 and failing_profile.save_attempts == 1, "finished result is recorded once before its first persistence attempt")
	_check(app.saved_run == checkpoint and app.captured_deletions == 0, "failed career write retains the last playable checkpoint and its backup")
	_check(_find_button(app.screen, "RETRY SAVING CAREER") != null and _has_label_containing(app.screen, "Career could not be saved"), "failed career write has an actionable retry and truthful status")
	app._finish_run()
	_check(failing_profile.total_runs == 1 and failing_profile.save_attempts == 2, "retrying a failed result write does not double-count the run")
	failing_profile.fail_save = false
	app._finish_run()
	_check(failing_profile.total_runs == 1 and failing_profile.save_attempts == 3, "successful retry persists the already-recorded result")
	_check(app.saved_run.is_empty() and app.captured_deletions == 1, "completed checkpoint is removed only after career persistence succeeds")
	_check(_find_button(app.screen, "RETRY SAVING CAREER") == null, "successful save removes the retry prompt")
	app.test_mode = true
	app.intercept_persistence = false
	app.profile = original_profile


func _test_save_load_notices() -> void:
	var directory = ProjectSettings.globalize_path("res://builds/controller-save-tests")
	DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.path_join("load-fixture-%d.json" % Time.get_ticks_usec())
	var backup: String = path + ".backup"
	var paths: Array = [path, backup]
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{interrupted save")
	file.close()
	var broken_hash: String = FileAccess.get_sha256(path)
	app._load_saved_run(paths)
	_check(app.saved_run.is_empty() and app._run_load_notice.contains("could not be read"), "corrupt primary save explains why Continue is unavailable")
	app._show_title()
	_check(_has_label_containing(app.screen, "could not be read") and _find_button(app.screen, "CONTINUE YOUR SHIFT") == null, "corrupt-save explanation is visible on the title")
	_check(FileAccess.get_sha256(path) == broken_hash, "loading a corrupt save keeps its original bytes")
	var recoverable = Model.new()
	recoverable.new_run(741)
	recoverable.start_shift()
	var valid: Dictionary = {"model": recoverable.to_save(), "held_tool": "none", "run_id": "backup-fixture"}
	file = FileAccess.open(backup, FileAccess.WRITE)
	file.store_string(JSON.stringify(valid))
	file.close()
	var backup_hash: String = FileAccess.get_sha256(backup)
	app._load_saved_run(paths)
	app._show_title()
	_check(app.saved_run.get("run_id") == "backup-fixture" and app._run_load_notice.contains("restored"), "valid backup recovers continuation with an explicit notice")
	_check(_has_label_containing(app.screen, "restored") and _find_button(app.screen, "CONTINUE YOUR SHIFT") != null, "backup recovery and Continue are visible together")
	_check(FileAccess.get_sha256(path) == broken_hash and FileAccess.get_sha256(backup) == backup_hash, "recovery reads without overwriting either original or backup")
	DirAccess.remove_absolute(backup)
	valid.model.version = 999
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(valid))
	file.close()
	var unsupported_hash: String = FileAccess.get_sha256(path)
	app._load_saved_run(paths)
	app._show_title()
	_check(app.saved_run.is_empty() and _has_label_containing(app.screen, "unsupported version"), "unsupported model version surfaces its validation explanation on title")
	_check(FileAccess.get_sha256(path) == unsupported_hash, "unsupported save remains untouched")
	var previous_warning: String = app.profile.load_warning
	app.profile.load_warning = "Career progress was restored from its backup."
	app._show_title()
	_check(_has_label_containing(app.screen, app.profile.load_warning), "career recovery warning is also shown on the title")
	app.profile.load_warning = previous_warning
	app._run_load_notice = ""
	DirAccess.remove_absolute(path)
	app.saved_run.clear()


func _reset_shift(seed: int) -> void:
	app.practice = false
	app.selected_difficulty = "normal"
	app.selected_mode = "campaign"
	app._result_recorded = false
	app.model.new_run(seed)
	app.model.start_shift()
	app.held_tool = "none"
	app._show_play()
	app._sync_world()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _key(keycode: int) -> void:
	await _key_event(keycode, true)
	await _key_event(keycode, false)
	await _settle_hand_motion()


func _key_event(keycode: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _click_station(station: String) -> void:
	await _mouse_station(station, true)
	await _mouse_station(station, false)
	await _settle_hand_motion()

func _settle_hand_motion() -> void:
	# The normal controller is intentionally paused by this suite. Advance its
	# real world animation and input buffer instead of bypassing action locks.
	for tick in range(120):
		app.world._process(1.0 / 60.0)
		app._drain_action_queue()
		if not app.world.is_action_busy() and app._queued_action.is_empty(): break
	await process_frame

func _test_buffered_actions() -> void:
	_reset_shift(1901)
	app._act("bag")
	_check(app.world.is_action_busy(), "taking a bag keeps a physical transfer in flight")
	app._act("scoop")
	_check(app._queued_action == "scoop" and app.held_tool == "none", "quick next input waits for the bag to land")
	app._act("supply")
	_check(app._queued_action == "scoop", "buffer retains one intended next move instead of accumulating clicks")
	await _settle_hand_motion()
	_check(app.held_tool == "scoop" and app._queued_action.is_empty(), "buffered scoop pickup executes after bag animation")
	var stock: int = app.model.supply
	app._act("supply")
	app._act("supply")
	_check(app.model.scoop_count == 3 and app.model.supply == stock - 3, "double click cannot duplicate physical donuts during pickup")
	_check(app._queued_action.is_empty(), "same-action spam does not queue a duplicate scoop")
	app._act("package")
	_check(app._queued_action == "package", "pour can be buffered behind the scoop movement")
	app._show_pause()
	_check(app._queued_action.is_empty(), "opening pause cancels buffered actions")
	app._close_overlay()
	await _settle_hand_motion()
	_check(app.model.package_count == 0, "cancelled pour does not fire after unpausing")
	app._act("package")
	await _settle_hand_motion()
	_check(app.model.package_count == 3, "pour remains available after cancelling a buffered move")


func _mouse_station(station: String, pressed: bool) -> void:
	var point: Vector2 = app.world.station_screen_position(station)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _click_text(parent: Node, text: String) -> void:
	var button: Button = _find_button(parent, text)
	_check(button != null, "button exists: " + text)
	if button != null:
		_check(not button.disabled, "button is enabled: " + text)
		if not button.disabled: button.pressed.emit()
	await process_frame


func _find_button(parent: Node, text: String) -> Button:
	if parent is Button and parent.text == text: return parent
	for child in parent.get_children():
		var found: Button = _find_button(child, text)
		if found != null: return found
	return null


func _buttons_with_prefix(parent: Node, prefix: String) -> Array:
	var result: Array = []
	if parent is Button and parent.text.begins_with(prefix): result.append(parent)
	for child in parent.get_children(): result.append_array(_buttons_with_prefix(child, prefix))
	return result


func _has_label(parent: Node, text: String) -> bool:
	if parent is Label and parent.text == text: return true
	for child in parent.get_children():
		if _has_label(child, text): return true
	return false


func _has_label_containing(parent: Node, text: String) -> bool:
	if parent is Label and parent.text.contains(text): return true
	for child in parent.get_children():
		if _has_label_containing(child, text): return true
	return false


func _persistent_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Controller.SAVE_PATH, Controller.SETTINGS_PATH, Controller.LEGACY_SAVE_PATH, Controller.LEGACY_SETTINGS_PATH, "user://career.json", "user://career.json.backup", Controller.SAVE_PATH + ".backup", Controller.SETTINGS_PATH + ".backup"]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result


func _find_sliders(parent: Node) -> Array:
	var result: Array = []
	if parent is HSlider: result.append(parent)
	for child in parent.get_children(): result.append_array(_find_sliders(child))
	return result
