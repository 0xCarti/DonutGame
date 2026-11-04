extends SceneTree
## Input/UI/lifecycle integration. Native save files are fingerprinted and never written.
const Controller = preload("res://scripts/stand_main.gd")

class InputProbe extends Controller:
	var actions: Array = []
	var persistence_attempts = 0
	var dispatch_actions = false
	func _act(station: String) -> void:
		if dispatch_actions:
			super._act(station)
			return
		if current_view == "play" and not paused: actions.append(station)
	func _write_json_atomic(_path: String, _data: Dictionary) -> bool:
		persistence_attempts += 1
		return true

var app
var checks = 0
var failures = 0
var ui_clicks = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var before = _fingerprints()
	app = InputProbe.new()
	app.test_mode = true
	app.mobile_mode = true
	root.add_child(app)
	app.set_process(false)
	app.world.set_process(false)
	app.audio.set_muted(true)
	app.model.new_run(731)
	app.model.start_shift()
	app._show_play()
	app._sync_world()
	await process_frame
	await physics_frame
	await physics_frame
	_check(app.mobile_mode and not quit_on_go_back, "Mobile mode owns Android Back handling")
	_check(app.dashboard.mobile_mode, "Controller configures the phone HUD")
	var point: Vector2 = app.world.station_screen_position("bag")
	_check(not app._mobile_control_at(app.ui, point), "World package station is not blocked by mobile HUD")
	_check(app.world.pick_station(point) == "bag", "Touch test targets the actual bag station")
	_touch(1, point, true)
	_check(app.actions.is_empty(), "Touch-down does not dispatch a world action")
	_touch(1, point, false)
	_check(app.actions == ["bag"], "Tap release dispatches one bag action")
	var emulated = InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.position = point
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	app._unhandled_input(emulated)
	_check(app.actions.size() == 1, "Emulated mouse cannot duplicate the native world tap")
	# Some Android backends label generated mouse input as ordinary device 0.
	# Simulate that platform policy even though this suite runs on desktop.
	app.mobile_mouse_preview = false
	for device in [0, InputEvent.DEVICE_ID_EMULATION, 32]:
		for down in [true, false]:
			var duplicate = InputEventMouseButton.new()
			duplicate.device = device
			duplicate.position = point
			duplicate.button_index = MOUSE_BUTTON_LEFT
			duplicate.pressed = down
			app._input(duplicate)
			app._unhandled_input(duplicate)
	_check(app.actions.size() == 1, "Android ignores device-0, emulated and physical mouse pairs after a native touch")
	_check(not app.mobile_input.owns(-2), "Android generated mouse cannot acquire a second gesture")
	_touch(2, point, true)
	var drag = InputEventScreenDrag.new()
	drag.index = 2
	drag.position = point + Vector2(45, 0)
	app._input(drag)
	_touch(2, drag.position, false)
	_check(app.actions.size() == 1, "Drag beginning on a station never dispatches its action")
	_check(app.world.get("_look") != Vector2.ZERO, "Dragging changes the camera look")
	app._mobile_action("recenter")
	_check(app.world.get("_look") == Vector2.ZERO, "Center touch action resets camera look")
	# Native UI must retain emulated mouse input, despite world duplicate filtering.
	var button = Button.new()
	button.position = Vector2(450, 310)
	button.size = Vector2(240, 80)
	button.text = "Touch probe"
	button.pressed.connect(func(): ui_clicks += 1)
	app.ui.add_child(button)
	var gui_point = button.get_global_rect().get_center()
	_touch(3, gui_point, true)
	_check(not app.mobile_input.owns(3), "A GUI touch never starts a world gesture")
	for down in [true, false]:
		var click = InputEventMouseButton.new()
		click.device = 0
		click.position = gui_point
		click.global_position = gui_point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		Input.parse_input_event(click)
		await process_frame
	_check(ui_clicks == 1 and app.actions.size() == 1, "Android device-0 GUI click remains usable without world leakage")
	button.queue_free()
	await process_frame
	await _touch_service("bag", "cinnamon", 2)
	await _touch_service("bucket", "powdered", 4)
	app.model.batter = 0
	var toolbar = app.dashboard.mobile_controls
	toolbar.set_context("refill", "Hold to refill")
	var hold_point: Vector2 = toolbar.context_button.get_global_rect().get_center()
	var hold_event = InputEventMouseButton.new()
	hold_event.device = 0
	hold_event.position = hold_point
	hold_event.global_position = hold_point
	hold_event.button_index = MOUSE_BUTTON_LEFT
	hold_event.pressed = true
	Input.parse_input_event(hold_event)
	await process_frame
	_check(app.hold_station == "refill" and toolbar.get("_active_hold") == "refill", "Real HUD button_down preserves both model hold and its GUI release owner")
	hold_event = hold_event.duplicate()
	hold_event.pressed = false
	Input.parse_input_event(hold_event)
	await process_frame
	_check(app.hold_station.is_empty() and str(toolbar.get("_active_hold")).is_empty(), "Real HUD button_up cancels model maintenance through integrated signals")
	app._mobile_hold_begin("refill")
	app._queued_action = "serve"
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(app.paused and is_instance_valid(app.overlay), "Background notification opens a paused counter")
	_check(app.hold_station.is_empty() and app._queued_action.is_empty(), "Backgrounding cancels holds and buffered actions")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(app.paused, "Foreground resume does not automatically restart gameplay")
	app._close_overlay()
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(app.paused and is_instance_valid(app.overlay), "Android Back pauses active play")
	app._show_settings()
	_check(_has_text(app.overlay, "GRAPHICS"), "Mobile settings exposes device graphics choices")
	app._mobile_back()
	_check(app.paused and _has_text(app.overlay, "Take a breather."), "Back from mobile settings returns to pause")
	app._show_mobile_license("Engine", "res://docs/licenses/Godot-LICENSE.txt")
	_check(_has_text(app.overlay, "Permission is hereby granted"), "Bundled engine license is readable in-app")
	app._close_overlay()
	app.mobile_safe_insets = Vector4(72, 18, 24, 20)
	app._resize()
	var safe = app._mobile_safe_rect(root.get_visible_rect().size)
	_check(safe.encloses(Rect2(app.ui.position, app.ui.size * app.ui.scale)), "Main controller applies safe-area canvas placement")
	app.mobile_safe_insets = Vector4.ZERO
	app._resize()
	app.saved_run.clear()
	app._show_title()
	_check_mobile_menu("New-player title", app.screen)
	app.saved_run = {"model": app.model.to_save()}
	app._show_title()
	_check_mobile_menu("Continue title", app.screen)
	app._request_new_run()
	_check_mobile_menu("Replace-save confirmation", app.overlay)
	app._close_overlay()
	app._show_play()
	app.practice = false
	app._show_pause()
	_check_mobile_menu("Shift pause", app.overlay)
	app.practice = true
	app._show_pause()
	_check_mobile_menu("Practice pause", app.overlay)
	app._close_overlay()
	app.practice = false
	app.model.sales = app.model.target
	app.model.finish_shift()
	app._show_shop()
	_check_mobile_menu("Upgrade shop", app.screen)
	app._show_collection()
	_check_mobile_menu("Collection", app.screen)
	app._show_mobile_badges()
	_check_mobile_menu("Career badges", app.overlay)
	app._save_run()
	app._save_settings()
	app._delete_run_files()
	_check(app.persistence_attempts == 0 and _fingerprints() == before, "Test mode protects all real save/settings/profile files")
	app.audio.stop_music()
	for player in app.audio.get_children():
		if player is AudioStreamPlayer: player.stop()
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("MOBILE CONTROLLER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _touch(id: int, position: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = id
	event.position = position
	event.pressed = down
	app._input(event)

func _touch_service(kind: String, flavor: String, portions: int) -> void:
	app.dispatch_actions = true
	app.model.new_run(4182)
	app.model.start_shift()
	app.held_tool = "none"
	app.model.orders[0]["package"] = kind
	app.model.orders[0]["flavor"] = flavor
	app.model.orders[0]["base_price"] = 32.0 if kind == "bucket" else 18.0
	app._show_play()
	app._sync_world()
	await physics_frame
	await physics_frame
	await _tap_station(kind)
	await _tap_station("scoop")
	for _portion in range(portions):
		await _tap_station("supply")
		await _tap_station("package")
	_check(app.model.package_count == portions * 3, "Touch scooping fills the real " + kind)
	await _tap_station(flavor)
	await _tap_station("package")
	await _tap_station("serve")
	_check(app.model.served == 1 and app.model.sales >= 18.0, "Complete touch-only " + kind + " service pays exactly one order")
	_check(app.model.package_count == 0 and app.held_tool == "none", "Touch service clears consumed package and hands")
	app.dispatch_actions = false

func _tap_station(station: String) -> void:
	var point: Vector2 = app.world.station_screen_position(station)
	_check(not app._mobile_control_at(app.ui, point), "Mobile HUD leaves station tappable: " + station)
	_touch(11, point, true)
	_touch(11, point, false)
	for _tick in range(120):
		app.world._process(1.0 / 60.0)
		app._drain_action_queue()
		if not app.world.is_action_busy() and app._queued_action.is_empty(): break
	await process_frame

func _has_text(node: Node, text: String) -> bool:
	if (node is Label or node is Button or node is RichTextLabel) and text in node.text: return true
	for child in node.get_children():
		if _has_text(child, text): return true
	return false

func _check_mobile_menu(label: String, node: Node) -> void:
	var buttons: Array = []
	_collect_buttons(node, buttons)
	var canvas: Rect2 = app.ui.get_global_rect()
	var correct_size = not buttons.is_empty()
	var in_bounds = true
	var no_overlap = true
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		correct_size = correct_size and button.size.y >= 80 and button.get_theme_font_size("font_size") >= 24
		in_bounds = in_bounds and canvas.encloses(button.get_global_rect())
		for j in range(i):
			if button.get_global_rect().intersects(buttons[j].get_global_rect()): no_overlap = false
	_check(correct_size, label + " has touch-sized readable controls")
	_check(in_bounds and no_overlap, label + " controls fit the logical canvas without overlap")

func _collect_buttons(node: Node, result: Array) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Button: result.append(node)
	for child in node.get_children(): _collect_buttons(child, result)

func _fingerprints() -> Dictionary:
	var result = {}
	for file in ["golden_hour_run.json", "golden_hour_settings.json", "stand_run.json", "stand_settings.json", "career.json"]:
		for suffix in ["", ".backup", ".tmp"]:
			var path = "user://" + file + suffix
			result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result

func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(detail)
