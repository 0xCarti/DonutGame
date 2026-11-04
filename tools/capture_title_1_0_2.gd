extends SceneTree
## Isolated title/menu validation plus native screenshots. Never loads or writes
## real player state; the saved-shift and recovery views use in-memory fixtures.
const Controller = preload("res://scripts/stand_main.gd")
var app
var checks: int = 0
var failures: int = 0
var before: Dictionary = {}
const OUT: String = "res://playtest-reports/title-1.0.2"

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func find_button(node: Node, value: String) -> Button:
	if node is Button and node.text == value: return node
	for child in node.get_children():
		var found: Button = find_button(child, value)
		if found != null: return found
	return null

func has_label(node: Node, value: String) -> bool:
	if node is Label and node.text == value: return true
	for child in node.get_children():
		if has_label(child, value): return true
	return false

func click(value: String) -> void:
	var button: Button = find_button(app.screen, value)
	check(button != null and not button.disabled, "Usable title action: " + value)
	if button != null and not button.disabled: button.pressed.emit()
	await process_frame

func fingerprints() -> Dictionary:
	var values: Dictionary = {}
	for file in ["golden_hour_run.json", "golden_hour_run.json.backup", "golden_hour_settings.json", "career.json", "career.json.backup", "stand_run.json", "stand_settings.json"]:
		var path: String = "user://" + file
		values[file] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return values

func capture(label: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = OUT + "/" + label + ".png"
	check(image.save_png(ProjectSettings.globalize_path(path)) == OK, "Rendered " + label)
	print("TITLE_CAPTURE " + path)

func _run() -> void:
	before = fingerprints()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Capture actual output pixels at both aspect ratios rather than Godot's
	# internal 1280x800 stretch viewport. The controller supplies the same fit.
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 800)
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false)
	app.audio.set_muted(true)
	app.saved_run.clear()
	app.tutorial_seen = false
	app._show_title()
	await capture("01-opening-board-1280x800")
	var primary: Button = app.screen.get_node_or_null("TitleOpenStand")
	check(primary != null and primary.size.x <= 460 and primary.size.y == 126, "Opening ticket stays within its intended native layout")
	check(find_button(app.screen, "CONTINUE YOUR SHIFT") == null, "No continuation offered without a saved run")
	check(find_button(app.screen, "PRACTICE  ·  NO PRESSURE") != null, "Practice is always visible")
	await click("RELAXED")
	check(app.selected_difficulty == "relaxed", "Wristband selects real relaxed difficulty")
	await click("STANDARD")
	check(app.selected_difficulty == "normal", "Wristband restores normal difficulty")
	await click("How to play")
	check(is_instance_valid(app.overlay), "Instructions remain accessible from title")
	app._close_overlay()
	find_button(app.screen, "Settings").grab_focus()
	await click("Settings")
	check(is_instance_valid(app.overlay), "Settings remain accessible from title")
	await process_frame
	var focus: Control = root.gui_get_focus_owner()
	check(focus != null and app.overlay.is_ancestor_of(focus), "Opening a modal transfers keyboard focus into it")
	var practice_button: Button = find_button(app.screen, "PRACTICE  ·  NO PRESSURE")
	check(practice_button.focus_mode == Control.FOCUS_NONE, "Background title actions cannot receive modal tab focus")
	practice_button.pressed.emit()
	check(app.current_view == "title" and is_instance_valid(app.overlay), "Title callback guard rejects activation behind an open modal")
	var muted_before: bool = app.muted
	for pressed in [true, false]:
		var accept = InputEventKey.new()
		accept.keycode = KEY_ENTER
		accept.pressed = pressed
		Input.parse_input_event(accept)
		await process_frame
	check(app.muted != muted_before and app.current_view == "title" and is_instance_valid(app.overlay), "Keyboard accept operates the focused modal control only")
	app._close_overlay()
	check(practice_button.focus_mode == Control.FOCUS_ALL, "Closing a modal restores title keyboard navigation")
	await click("Credits")
	check(is_instance_valid(app.overlay), "Credits remain accessible from title")
	app._close_overlay()
	await click("Collection")
	check(app.current_view == "collection", "Career stamp opens the actual earned collection")
	app._show_title()
	await click("OPEN THE STAND  >")
	check(app.model.phase == "ready" and is_instance_valid(app.overlay), "First opening preserves onboarding before the clock starts")
	app._close_overlay()
	app._show_title()
	await click("PRACTICE  ·  NO PRESSURE")
	check(app.practice and app.current_view == "play", "Practice ticket starts a playable pressure-free shift")
	app.model.new_run(4182)
	app.model.start_shift()
	app.saved_run = {"model": app.model.to_save(), "held_tool": "none", "run_id": "title-fixture"}
	app._show_title()
	check(app.screen.get_node_or_null("TitleContinue") != null, "Existing campaign promotes Continue to the main ticket")
	check(find_button(app.screen, "PRACTICE  ·  NO PRESSURE") != null, "Practice stays available beside continuation")
	await click("RELAXED")
	check(has_label(app.screen, "NEW RUN PACE") and has_label(app.screen, "New runs: more time and patient customers."), "Pace choice explicitly applies to new runs")
	check(has_label(app.screen, "Resume your Standard shift."), "Continue describes the saved pace independently of the next-run selector")
	await capture("02-saved-shift-1280x800")
	await click("OPEN THE STAND  >")
	check(is_instance_valid(app.overlay) and not app.saved_run.is_empty(), "Fresh-start choice still asks before replacing a checkpoint")
	app._close_overlay()
	await click("CONTINUE YOUR SHIFT")
	check(app.current_view == "play" and not app.practice and app.model.difficulty == "normal", "Primary continuation resumes the saved campaign pace")
	app.saved_run.clear()
	app._run_load_notice = "Your saved shift could not be read. Your career records are safe."
	app._show_title()
	await capture("03-recovery-notice-1280x800")
	app._run_load_notice = ""
	app._show_title()
	root.size = Vector2i(1280, 720)
	app._resize()
	await capture("04-opening-board-1280x720")
	check(app.ui.scale.is_equal_approx(Vector2(0.9, 0.9)), "720p preserves complete menu through existing letterboxing")
	check(fingerprints() == before, "Title captures and actions preserve all real player files")
	app.audio.stop_music()
	for child in app.audio.get_children():
		if child is AudioStreamPlayer: child.stop()
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("TITLE MENU QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
