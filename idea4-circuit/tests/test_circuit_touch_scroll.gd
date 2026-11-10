extends SceneTree
## Real touch events exercise Godot's scroll cancellation, never pressed.emit().
class DemoUI extends "res://scripts/circuit_main.gd":
	func _load_game() -> void: pass
	func _save_game() -> bool: return true

var app: DemoUI
var checks = 0
var failures: Array[String] = []
var previous_touch_emulation = false

func _initialize() -> void:
	previous_touch_emulation = Input.emulate_touch_from_mouse
	# Desktop ScrollContainer requires this runtime flag to enable its touch path.
	# Android uses the touchscreen feature; production project settings stay intact.
	Input.emulate_touch_from_mouse = true
	call_deferred("_run")

func _run() -> void:
	_check(Input.emulate_mouse_from_touch, "Production touch-to-mouse emulation is enabled")
	root.size = Vector2i(390, 600)
	root.content_scale_size = Vector2i(390, 600)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	app = DemoUI.new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.test_mode = true
	app.settings.motion = false
	app._start_company("Touch Test", false)
	app._navigate("company")
	await _settle()
	var saved: Dictionary = app.model.to_save()
	var card: Control = app.content.get_child(0)
	await _swipe(card, app.scroll, "Company card")
	_check(app.model.to_save() == saved, "Card swipe preserves company state")

	app._navigate("company")
	await _settle()
	var borrow = _button(app.content, "Borrow")
	await _swipe(borrow, app.scroll, "Borrow button", true)
	await _swipe(borrow, app.scroll, "Borrow reverse swipe", true, 90)
	_check(not is_instance_valid(app.modal), "Borrow swipe does not open confirmation")
	_check(app.model.to_save() == saved, "Borrow swipe does not change company state")
	await _tap_visible(borrow, app.scroll)
	_check(is_instance_valid(app.modal), "Ordinary Borrow tap opens confirmation")
	app._close_modal()

	app._navigate("menu")
	await _settle()
	var buy = _button(app.content, "+50")
	saved = app.model.to_save()
	await _swipe(buy, app.scroll, "Stock purchase", true)
	_check(app.model.to_save() == saved, "Purchase swipe spends nothing and adds no stock")
	await _tap_visible(buy, app.scroll)
	_check(int(app.model.state.stock) == int(saved.stock) + 50, "Purchase tap buys exactly 50 servings")
	_check(is_equal_approx(float(app.model.state.cash), float(saved.cash) - 50), "Purchase tap charges exactly once")

	app._navigate("circuit")
	await _settle()
	var venue: Button = app.find_child("Venue_willowbank", true, false)
	saved = app.model.to_save()
	await _swipe(venue, app.scroll, "Route stop", true)
	_check(not is_instance_valid(app.modal), "Route swipe does not open stop details")
	_check(app.model.to_save() == saved, "Route swipe never books a venue")
	await _tap_visible(venue, app.scroll)
	_check(is_instance_valid(app.modal), "Route tap opens stop details")
	app._close_modal()

	app._show_settings()
	await _settle()
	var settings_scroll = _scroll_in(app.modal)
	var toggle: CheckButton = _button(app.modal, "Scene & menu animation")
	var settings_before: Dictionary = app.settings.duplicate(true)
	await _swipe(toggle, settings_scroll, "Settings toggle", true)
	_check(app.settings == settings_before, "Settings swipe does not toggle a preference")
	await _tap_visible(toggle, settings_scroll)
	_check(bool(app.settings.motion) != bool(settings_before.motion), "Settings tap toggles once")
	app.settings.motion = false
	app._close_modal()

	for offer: Dictionary in app.model.activity_offers():
		if str(offer.kind) == "repair":
			app._start_activity(str(offer.id))
			break
	await _settle()
	var repair = app._activity_game
	_check(is_instance_valid(repair), "Real repair sheet opened")
	if is_instance_valid(repair):
		var repair_scroll = _scroll_in(app.modal)
		var pipe: Button = repair._controls[4]
		var masks: Array = repair.pipe_masks.duplicate()
		saved = app.model.to_save()
		await _swipe(pipe, repair_scroll, "Repair pipe", true)
		_check(repair.moves == 0 and repair.pipe_masks == masks, "Repair swipe does not rotate any pipe")
		_check(app.model.to_save() == saved, "Repair swipe does not charge or award anything")
		await _tap_visible(pipe, repair_scroll)
		_check(repair.moves == 1, "Repair tap rotates exactly once")
	app._close_modal()

	app._act("book", {"id":"willowbank"})
	await _settle()
	if str(app.model.state.phase) == "event":
		for index in app.model.state.event.choices.size():
			var effects: Dictionary = app.model.state.event.choices[index].get("effects", {})
			if float(effects.get("cash", 0)) >= 0 and int(effects.get("stock", 0)) >= 0:
				app._act("decide", {"choice":index})
				break
	app._close_modal()
	await _settle()
	app._show_minigame()
	await _settle()
	var batch = app._batch_game
	_check(is_instance_valid(batch), "Real opening batch sheet opened")
	if is_instance_valid(batch):
		batch.set_process(false)
		if batch._state == "ready": batch._process(batch.READY_SECONDS)
		var batch_scroll = _scroll_in(app.modal)
		saved = app.model.to_save()
		await _swipe(batch.action_button, batch_scroll, "Batch action", true, -50)
		_check(batch.beat_scores.is_empty(), "Batch swipe does not play a beat")
		_check(app.model.to_save() == saved, "Batch swipe does not award a bonus")
		await _tap_visible(batch.action_button, batch_scroll)
		_check(batch.beat_scores.size() == 1 and batch.stage_scores.is_empty(), "Batch tap plays exactly one of the two stage beats")
	app.queue_free()
	await process_frame
	Input.emulate_touch_from_mouse = previous_touch_emulation
	for failure in failures: print("FAIL: " + failure)
	print("CIRCUIT_TOUCH_SCROLL_CHECKS %d passed / %d" % [checks-failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _swipe(target: Control, scroller: ScrollContainer, label: String, release_inside: bool = false, distance: float = -90) -> void:
	_check(is_instance_valid(target) and is_instance_valid(scroller), label + " exists")
	if not is_instance_valid(target) or not is_instance_valid(scroller): return
	scroller.ensure_control_visible(target)
	await _settle()
	var before = scroller.scroll_vertical
	var from = target.get_global_rect().intersection(scroller.get_global_rect()).get_center()
	var to = from + Vector2(0, distance)
	_check(scroller.get_global_rect().has_point(from), label + " starts inside visible scroll area")
	_touch(from, true)
	await _settle()
	var last = from
	for step in range(1, 13):
		var event = InputEventScreenDrag.new()
		event.index = 0
		event.position = from.lerp(to, step / 12.0)
		event.relative = event.position - last
		event.screen_relative = event.relative
		event.velocity = Vector2.ZERO
		event.screen_velocity = Vector2.ZERO
		Input.parse_input_event(event)
		last = event.position
		await process_frame
	# Holding the last point avoids inertia obscuring whether the release cancels.
	await _settle()
	if release_inside: _check(target.get_global_rect().has_point(to), label + " release remains over the moved button")
	_touch(to, false)
	await _settle()
	var moved = abs(scroller.scroll_vertical - before)
	_check(moved >= 30, label + " scrolls through content (%d px)" % moved)

func _tap_visible(target: Control, scroller: ScrollContainer) -> void:
	scroller.ensure_control_visible(target)
	await _settle()
	var point = target.get_global_rect().intersection(scroller.get_global_rect()).get_center()
	_touch(point, true)
	await process_frame
	_touch(point, false)
	await _settle()

func _touch(point: Vector2, pressed: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)

func _button(node: Node, prefix: String) -> BaseButton:
	if node is BaseButton and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found = _button(child, prefix)
		if found: return found
	return null

func _scroll_in(node: Node) -> ScrollContainer:
	if node is ScrollContainer: return node
	for child in node.get_children():
		var found = _scroll_in(child)
		if found: return found
	return null

func _settle() -> void:
	for frame in range(8): await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
