extends SceneTree
## Real controller integration: physical station rays, dispatched input, orders,
## maintenance, menus, continuation, and byte-for-byte persistent save protection.

const Controller = preload("res://scripts/stand_main.gd")
const Model = preload("res://scripts/stand_model.gd")
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
	app = Controller.new()
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
	await _test_bag_service()
	await _test_bucket_and_mistakes()
	await _test_maintenance_and_pause()
	await _test_settings_and_continuation()
	await _test_shop_and_results()
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
	await _click_text(app.screen, "STEP BEHIND THE COUNTER  >")
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
	await _key(KEY_P)
	_check(app.model.package_flavor == "cinnamon", "wrong coating cannot be overwritten")
	await _key(KEY_X)
	_check(app.model.package_type.is_empty() and app.model.supply == 6, "discarding coated food does not return edible stock")
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
	await _click_text(app.overlay, "DONE")
	_check(not app.paused and not is_instance_valid(app.overlay), "settings Done returns to play")
	_reset_shift(735)
	app._act("bag")
	app._act("scoop")
	app._act("supply")
	var snapshot: Dictionary = app.model.to_save()
	app.saved_run = {"model": snapshot.duplicate(true), "held_tool": "scoop"}
	app._show_title()
	app.model.new_run(736)
	await _click_text(app.screen, "CONTINUE SHIFT")
	_check(app.current_view == "play" and app.model.phase == "playing", "continue restores the running shift")
	_check(app.held_tool == "scoop" and app.model.scoop_count == 3 and app.model.package_type == "bag", "continue preserves loaded scoop and the prepared container")
	_check(app.model.time_left == snapshot["time_left"], "continue preserves remaining shift time")
	app._save_run()
	app._save_settings()
	_check(_persistent_fingerprints() == disk_before, "test mode suppresses explicit run and settings writes")
	app._show_title()
	await _click_text(app.screen, "STEP BEHIND THE COUNTER  >")
	_check(is_instance_valid(app.overlay) and _has_label(app.overlay, "Start a fresh shift?"), "new run asks before replacing an existing saved run")
	await _click_text(app.overlay, "Keep my run")
	_check(app.current_view == "title" and not app.saved_run.is_empty(), "cancelling a fresh run preserves continuation")
	app.saved_run.clear()


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
	app.model.shift_index = 2
	app.model.target = Model.TARGETS[2]
	app.model.sales = app.model.target
	app.model.finish_shift()
	app._process(0.0)
	_check(app.model.phase == "won" and app.current_view == "result" and _has_label(app.screen, "Rush handled."), "third completed shift shows the success result")
	_check(_has_label_containing(app.screen, "SHIFT 3 / 3"), "success reports the actual third shift")
	await _click_text(app.screen, "Back to the stand")
	_check(app.current_view == "title", "result can return to the title")
	_reset_shift(738)
	app.model.time_left = 0.05
	app._process(0.1)
	_check(app.model.phase == "lost" and app.current_view == "result" and _has_label(app.screen, "Closing time."), "missed quota opens the failure result")
	_check(_has_label_containing(app.screen, "SHIFT 1 / 3"), "failure reports the actual failed shift")
	await _click_text(app.screen, "TRY ANOTHER RUN")
	_check(app.current_view == "play" and app.model.phase == "playing" and app.model.shift_index == 0, "replay starts a fresh first shift")
	_check(app.model.sales == 0.0 and app.model.owned.is_empty() and app.held_tool == "none", "replay clears earnings, upgrades and held tools")


func _reset_shift(seed: int) -> void:
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


func _key_event(keycode: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _click_station(station: String) -> void:
	await _mouse_station(station, true)
	await _mouse_station(station, false)


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
	for path in [Controller.SAVE_PATH, Controller.SETTINGS_PATH]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result
