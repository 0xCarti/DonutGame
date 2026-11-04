extends SceneTree
## Integration regression: real main.gd UI, input dispatch, and run model.
## Smoke mode is enabled before _ready and must suppress all persistent writes.

const Controller = preload("res://scripts/main.gd")
const Model = preload("res://scripts/run_model.gd")
const UpgradeData = preload("res://scripts/upgrades.gd")
var app
var checks: int = 0
var failures: int = 0
var disk_before: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	disk_before = _persistent_fingerprints()
	app = Controller.new()
	app.smoke_mode = true
	root.add_child(app)
	app.set_process(false)
	app.world.set_process(false)
	app.audio.set_muted(true)
	app.audio.set_music_volume(0.0)
	app.reduced_motion = false
	app._apply_effect_settings()
	app.score_fx.set_process(false)
	app.model.new_run(711)
	app.saved_run.clear()
	app.tutorial_seen = false
	app.stats = {"runs": 0, "wins": 0, "best_shift": 0, "best_sales": 0.0}
	app.total_time = 0.0
	app._show_title()
	await process_frame
	await _test_title_and_first_run()
	await _test_keyboard_and_pause()
	await _test_drop_availability()
	await _test_score_feedback_and_settings()
	await _test_shop_and_next_shift()
	await _test_results()
	_check(_persistent_fingerprints() == disk_before, "integration suite leaves real save and settings bytes unchanged")
	# The final replay starts the music again. Stop playback before removing
	# the fixture, then let the asynchronous audio mixer release its references.
	app.audio.stop_music()
	for player in app.audio.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("CONTROLLER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _test_title_and_first_run() -> void:
	_check(app.current_view == "title", "initial title is visible")
	_check(_has_label(app.screen, "GOLDEN\nHOUR"), "title has the game name")
	_check(_find_button(app.screen, "OPEN THE STAND  >") != null, "title offers new run")
	await _click_text(app.screen, "OPEN THE STAND  >")
	_check(is_instance_valid(app.overlay), "first run opens instructions")
	_check(app.model.phase == "ready", "clock does not start behind first-run help")
	_check(not app.tutorial_seen, "tutorial is not marked read before confirmation")
	_check(_has_label(app.overlay, "Welcome to your little stand."), "first-run help has expected content")
	await _click_text(app.overlay, "LET'S FRY  >")
	_check(app.tutorial_seen, "starting marks tutorial as read")
	_check(app.current_view == "play" and app.model.phase == "playing", "tutorial enters the first shift")
	_check(not is_instance_valid(app.overlay), "tutorial closes before gameplay")
	_check(app.route_buttons.size() == 3 and app.recipe_buttons.size() == 3 and app.sell_buttons.size() == 3, "play screen exposes all routes, recipes, and sales")
	_check(app.model.shift_index == 0 and app.model.target == 180.0, "first shift uses the introductory quota")
	_check(app.stats.runs == 1, "new-run record increments once in memory")


func _test_keyboard_and_pause() -> void:
	await _key(KEY_D)
	await _key(KEY_2)
	_check(app.model.selected_recipe == "cocoa" and app.model.selected_tray == 1, "keyboard selects recipe and destination")
	await _key(KEY_SPACE)
	_check(app.model.active.size() == 6, "space dispatches a six-donut batch")
	_check(str(app.model.active[0]["recipe"]) == "cocoa" and int(app.model.active[0]["tray"]) == 1, "batch uses selected cocoa and tray two")
	await _key(KEY_SPACE)
	_check(app.model.active.size() == 6, "keyboard obeys hopper cooldown")
	await _key(KEY_ESCAPE)
	_check(app.paused and is_instance_valid(app.overlay), "Escape opens pause")
	var saved_time: float = app.model.time_left
	app._process(0.1)
	app._process(0.1)
	_check(is_equal_approx(app.model.time_left, saved_time), "paused controller does not tick the model")
	await _key(KEY_3)
	await _key(KEY_SPACE)
	_check(app.model.selected_tray == 1 and app.model.active.size() == 6, "production keys are ignored while paused")
	await _key(KEY_ESCAPE)
	_check(not app.paused and not is_instance_valid(app.overlay), "Escape resumes")
	app._process(0.1)
	_check(app.model.time_left < saved_time, "unpaused controller advances the clock")
	app.model.tick(12.0)
	app._process(0.0)
	_check(app.model.trays[1].size() == 6, "real batch reaches selected tray")
	_check(not app.sell_buttons[1].disabled, "filled tray enables sale button")
	await _key(KEY_W)
	_check(app.model.trays[1].is_empty() and is_equal_approx(app.model.sales, 60.0), "W sells tray two for its full matching payout")
	await _key(KEY_W)
	_check(is_equal_approx(app.model.sales, 60.0), "repeated sale input cannot duplicate earnings")
	await _key(KEY_H)
	_check(app.paused and is_instance_valid(app.overlay), "help pauses active gameplay")
	await _click_text(app.overlay, "GOT IT")
	_check(not app.paused and app.model.phase == "playing", "help dismissal resumes same shift")


func _test_drop_availability() -> void:
	app.model.new_run(712)
	app.model.owned["frugal_batter"] = 1
	app.model.start_shift()
	for index in range(3):
		app.model.queue_batch("cinnamon", index)
		app.model.tick(2.0)
	app.model.tick(12.0)
	for index in range(3):
		app.model.sell_tray(index)
	app.model.batter = 0
	app._show_play()
	_check(app.model.next_batch_cost() == 0 and not app.hud.drop.disabled, "free fourth batch stays enabled with zero batter")
	await _key(KEY_SPACE)
	_check(app.model.active.size() == 6 and app.model.batter == 0, "UI can load the free batch at zero batter")
	app.model.new_run(713)
	app.model.start_shift()
	for index in range(3):
		app.model.queue_batch("cinnamon", index)
		if index < 2:
			app.model.tick(2.0)
	app.model.tick(4.1)
	app._show_play()
	_check(app.model.active.size() == 17, "capacity regression fixture has seventeen donuts in transit")
	_check(app.hud.drop.disabled, "UI disables whole batch when fewer than six fryer slots remain")
	var count: int = app.model.active.size()
	await _key(KEY_SPACE)
	_check(app.model.active.size() == count, "keyboard cannot bypass partial fryer capacity")


func _test_shop_and_next_shift() -> void:
	app.model.new_run(717)
	app.model.start_shift()
	app.model.sales = app.model.target + 100.0
	app.model.finish_shift()
	app._show_play()
	app._process(0.0)
	_check(app.current_view == "shop", "controller transitions successful shift to shop")
	var install_buttons: Array = _buttons_with_prefix(app.screen, "INSTALL")
	_check(install_buttons.size() == 4, "all four offered upgrades are visible and actionable")
	_check(_has_label_containing(app.screen, "next target $340"), "shop previews correct next quota")
	var offer: Dictionary = app.model.get_shop_offers()[0]
	var upgrade_id: String = str(offer["id"])
	var before_credits: int = app.model.credits
	_check(not install_buttons[0].disabled, "affordable upgrade button is enabled")
	install_buttons[0].pressed.emit()
	await process_frame
	_check(app.model.level(upgrade_id) == 1, "shop button installs its offered upgrade")
	_check(app.model.credits == before_credits - int(offer["cost"]), "shop button charges the displayed cost")
	_check(_buttons_with_prefix(app.screen, "INSTALL").size() == 3, "purchased shop card disappears")
	_check(app._owned_description().contains(str(UpgradeData.ALL[upgrade_id]["name"])), "build summary uses human-readable upgrade name")
	await _click_text(app.screen, "NEXT SHIFT  >")
	_check(app.current_view == "play" and app.model.phase == "playing", "next-shift button returns to gameplay")
	_check(app.model.shift_index == 1 and app.model.target == 340.0 and app.model.sales == 0.0, "next shift advances quota and resets gross sales")
	_check(app.model.level(upgrade_id) == 1 and app.model.active.is_empty(), "next shift preserves upgrade and resets production")
	_check(app.hud.shift.text.contains("SHIFT 2 / 6"), "HUD reports new shift")


func _test_score_feedback_and_settings() -> void:
	app.model.new_run(715)
	app.model.start_shift()
	for index in range(3):
		app.model.queue_batch("cocoa", index)
		app.model.tick(2.0)
	app.model.tick(12.0)
	app.model.sales = app.model.target - 60.0
	app._show_play()
	app._sell(0)
	_check(app.feedback.chain == 1 and is_equal_approx(app.model.sales, app.model.target), "one sale advances feedback once and adds only its real payout")
	_check(bool(app.score_fx.active_receipt.get("goal", false)), "sale crossing quota triggers target celebration")
	_check(is_equal_approx(float(app.score_fx.active_receipt.get("amount", 0.0)), 60.0), "celebration uses exact sale receipt amount")
	app._process(0.0)
	_check(app.feedback.chain == 1, "draining model sale event does not celebrate or count sale twice")
	app._sell(1)
	_check(app.feedback.chain == 2 and is_equal_approx(app.model.sales, 240.0), "consecutive sale creates visual chain without adding bonus revenue")
	_check(not bool(app.score_fx.active_receipt.get("goal", true)), "later sales do not retrigger already-crossed target")
	var initial_muted: bool = app.muted
	var initial_music: bool = app.music_on
	var before_state: Dictionary = app.model.to_save()
	app._show_settings()
	await process_frame
	_check(app.paused and is_instance_valid(app.overlay), "settings pauses active gameplay")
	for button in _buttons_with_prefix(app.overlay, ""):
		_check(button.position.y >= 0.0 and button.position.y + button.size.y <= button.get_parent().size.y, "settings button remains inside enlarged modal: " + button.text)
	await _click_text(app.overlay, "Motion: FULL CELEBRATIONS")
	_check(app.reduced_motion and app.score_fx.reduced_motion and app.world._reduced_motion, "motion toggle immediately updates controller, score layer, and world")
	_check(app.score_fx.coins.is_empty() and app.score_fx.trails.is_empty(), "motion toggle clears in-flight visual particles")
	_check(app.muted == initial_muted and app.music_on == initial_music, "motion preference does not change sound preferences")
	app._process(0.1)
	_check(app.model.to_save() == before_state, "changing presentation while paused leaves run and clock unchanged")
	await _click_text(app.overlay, "DONE")
	_check(not app.paused and app.current_view == "play", "settings Done resumes gameplay")
	app._sell(2)
	_check(app.score_fx.coins.is_empty() and app.score_fx.trails.is_empty(), "real sale honors reduced-motion particle suppression")
	_check(app.score_fx._amount.text == "+$60", "real reduced-motion sale immediately shows full amount")
	app._show_settings()
	await _click_text(app.overlay, "Motion: REDUCED")
	_check(not app.reduced_motion and not app.score_fx.reduced_motion and not app.world._reduced_motion, "full celebration mode can be restored")
	await _click_text(app.overlay, "DONE")
	app._toast("First bounded toast")
	app._toast("Second bounded toast")
	_check(app.toasts.get_child_count() == 1 and _has_label(app.toasts, "Second bounded toast"), "rapid notices keep only the latest readable toast")
	app.model.finish_shift()
	app._process(0.0)
	_check(app.current_view == "shop" and app.score_fx.active_receipt.is_empty(), "changing screen clears transient celebration")
	_check(app.toasts.get_child_count() == 0, "old notifications do not bleed into shop")


func _test_results() -> void:
	var before_stats: Dictionary = app.stats.duplicate(true)
	app.model.shift_index = 5
	app.model.target = Model.TARGETS[5]
	app.model.sales = app.model.target
	app.model.finish_shift()
	app._process(0.0)
	_check(app.current_view == "result" and app.model.phase == "won", "sixth completed quota enters victory screen")
	_check(_has_label(app.screen, "A golden run."), "victory screen has success heading")
	_check(_has_label_containing(app.screen, "SHIFT 6 / 6"), "final result remains shift six without off-by-one")
	_check(_has_label_containing(app.screen, "$1800 / $1800"), "victory uses actual final quota and sales")
	_check(app.stats == before_stats, "smoke-mode victory does not mutate persistent records")
	_check(_find_button(app.screen, "ONE MORE RUN") != null and _find_button(app.screen, "Copy playtest report") != null, "result offers replay and feedback")
	# Results read current state and do not require optional prior receipt data.
	app.model.last_result = {}
	app._finish_run()
	_check(_has_label(app.screen, "A golden run."), "result screen tolerates empty optional last_result")
	await _click_text(app.screen, "Back to the stand")
	_check(app.current_view == "title", "result can return to title")
	app.model.new_run(719)
	app.model.start_shift()
	app.model.tick(65.0)
	app._show_play()
	app._process(0.0)
	_check(app.current_view == "result" and app.model.phase == "lost", "missed quota enters defeat screen")
	_check(_has_label(app.screen, "Closing time."), "defeat heading differs from victory")
	_check(_has_label_containing(app.screen, "SHIFT 1 / 6"), "defeat reports the actual failed shift")
	await _click_text(app.screen, "ONE MORE RUN")
	_check(app.current_view == "play" and app.model.phase == "playing" and app.model.shift_index == 0, "replay starts a clean first shift after tutorial was seen")
	_check(app.model.sales == 0.0 and app.model.owned.is_empty(), "replay clears prior earnings and upgrades")


func _key(keycode: int) -> void:
	var pressed: InputEventKey = InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released: InputEventKey = InputEventKey.new()
	released.keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame


func _click_text(parent: Node, text: String) -> void:
	var button: Button = _find_button(parent, text)
	_check(button != null, "button exists: " + text)
	if button != null:
		_check(not button.disabled, "button is enabled: " + text)
		if not button.disabled:
			button.pressed.emit()
	await process_frame


func _find_button(parent: Node, text: String) -> Button:
	if parent is Button and parent.text == text:
		return parent
	for child in parent.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _buttons_with_prefix(parent: Node, prefix: String) -> Array:
	var result: Array = []
	if parent is Button and parent.text.begins_with(prefix):
		result.append(parent)
	for child in parent.get_children():
		result.append_array(_buttons_with_prefix(child, prefix))
	return result


func _has_label(parent: Node, text: String) -> bool:
	if parent is Label and parent.text == text:
		return true
	for child in parent.get_children():
		if _has_label(child, text):
			return true
	return false


func _has_label_containing(parent: Node, text: String) -> bool:
	if parent is Label and parent.text.contains(text):
		return true
	for child in parent.get_children():
		if _has_label_containing(child, text):
			return true
	return false


func _persistent_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Controller.SAVE_PATH, Controller.SETTINGS_PATH]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result
