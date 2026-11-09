extends SceneTree
## Screen-level regression checks. Save writes are suppressed, including packaging runs.
class DemoUI extends "res://scripts/circuit_main.gd":
	func _load_game() -> void: pass
	func _save_game() -> bool: return true

var app: DemoUI
var failures: Array[String] = []
var checks = 0
var capture_dir = ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(480, 960)
	root.content_scale_size = Vector2i(480, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	app = DemoUI.new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.test_mode = true
	app.settings.motion = false
	await _settle()
	_check(not app.has_run, "First launch starts at company creation")
	await _capture("01-welcome")
	app._start_company("Golden Hour", false)
	await _settle()
	_check(app.has_run and app.model.state.phase == "planning", "Company starts in planning")
	_check(app.find_child("PrimaryAction", true, false) != null, "Primary action is available")
	await _capture("02-journal")
	for id in ["circuit", "crew", "menu", "garage", "company"]:
		app._navigate(id)
		await _settle()
		_check(app.tab == id, "Navigation reaches " + id)
		await _capture("03-" + id)
	app._confirm_booking("willowbank")
	await _settle()
	_check(is_instance_valid(app.modal), "Booking offers confirmation with costs")
	await _capture("04-booking")
	app._act("book", {"id": "willowbank"})
	await _settle()
	if app.model.state.phase == "event":
		await _capture("05-travel")
		_resolve_event()
		await _settle()
	_check(app.model.state.phase == "planning", "Travel resolves to preparation")
	app._navigate("journal")
	await _settle()
	app._show_minigame()
	await _settle()
	_check(app._minigame_playing, "Optional batch game starts")
	await _capture("06-minigame")
	app._minigame_gauge.value = 50
	app._stop_minigame()
	await _settle()
	_check(app.model.state.minigame_day == app.model.state.day, "Batch bonus committed once")
	app._primary()
	await _settle()
	if app.model.state.phase == "event":
		await _capture("07-decision")
		_resolve_event()
		await _settle()
	_check(app.model.state.phase == "report", "Trading reaches daily report")
	_check(app.find_child("DismissReport", true, false) != null, "Report has continuation")
	await _capture("08-report")
	app._act("dismiss_report")
	await _settle()
	_check(app.model.state.phase == "planning", "Closing receipt returns to preparation")
	app._show_settings()
	await _settle()
	await _capture("09-settings")
	app._close_modal()
	app.model.state.phase = "season_end"
	app._render()
	await _settle()
	await _capture("10-season")
	app._reviewing_season = true
	app._render()
	await _settle()
	_check(app.model.state.phase == "season_end", "Journal review preserves completed season")
	_check(not is_instance_valid(app.modal), "Completed journal can be read")
	app._primary()
	await _settle()
	_check(is_instance_valid(app.modal), "Season summary reopens")
	app._record_season()
	var recorded: int = app.records.size()
	var saved: Dictionary = app.model.to_save()
	app.model.from_save(saved)
	app._rng_seed = 999999
	app._record_season()
	_check(app.records.size() == recorded, "Season history key survives app reload")
	app._act("next_season")
	await _settle()
	_check(app.model.state.season == 2, "Continue carries company to second season")
	for dimensions in [Vector2i(390,844), Vector2i(600,960), Vector2i(960,600)]:
		root.size = dimensions
		await _settle()
		app._navigate("menu")
		await _settle()
		await _capture("11-size-%dx%d" % [dimensions.x, dimensions.y])
	app.queue_free()
	await process_frame
	for failure in failures: print("FAIL: " + failure)
	print("CIRCUIT_UI_CHECKS %d passed / %d" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _resolve_event() -> void:
	var choices: Array = app.model.state.event.choices
	for index in range(choices.size()):
		var effects: Dictionary = choices[index].get("effects", {})
		if float(effects.get("cash", 0)) >= 0 and int(effects.get("stock", 0)) >= 0:
			app._act("decide", {"choice": index})
			return
	app._act("decide", {"choice": choices.size() - 1})

func _settle() -> void:
	for frame in range(8): await process_frame

func _capture(label: String) -> void:
	_check_widths(app, label)
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _check_widths(node: Node, label: String) -> void:
	if node is CheckButton and node.is_visible_in_tree():
		_check(node.get_theme_color("font_pressed_color") == app.INK, label + ": selected toggle has readable text")
		_check(node.get_theme_color("font_hover_pressed_color") == app.INK, label + ": selected hover toggle has readable text")
	if (node is Label or node is Button) and node.is_visible_in_tree():
		var missing: Array[String] = []
		for index in range(node.text.length()):
			var codepoint: int = node.text.unicode_at(index)
			if codepoint > 127 and not app.FONT.has_char(codepoint): missing.append("U+%04X" % codepoint)
		_check(missing.is_empty(), label + ": bundled font covers " + str(missing))
	if node is Button and node.is_visible_in_tree():
		_check(node.size.y >= 43.0, label + ": touch target " + node.text)
	if node is Control and node.is_visible_in_tree() and not node is VScrollBar:
		var bounds: Rect2 = node.get_global_rect()
		var viewport: Vector2 = app.get_viewport_rect().size
		if bounds.size.x > 0 and not node == app.toast:
			_check(bounds.position.x >= -1.0 and bounds.end.x <= viewport.x + 2.0, label + ": fits width " + str(node.get_path()))
	for child in node.get_children(): _check_widths(child, label)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
