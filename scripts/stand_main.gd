extends Node
## Idea 2: a first-person workbench. Physical props perform the actions; HUD reports state.

const Model = preload("res://scripts/stand_model.gd")
const World = preload("res://scripts/stand_world.gd")
const Audio = preload("res://scripts/stand_audio.gd")
const Hud = preload("res://scripts/stand_hud.gd")
const VERSION = "1.0.0"
const SAVE_PATH = "user://golden_hour_run.json"
const SETTINGS_PATH = "user://golden_hour_settings.json"
const LEGACY_SAVE_PATH = "user://stand_run.json"
const LEGACY_SETTINGS_PATH = "user://stand_settings.json"
const INK = Color("10252b")
const CREAM = Color("fff1d2")
const GOLD = Color("ffc76f")
const MINT = Color("a4e1c1")
const RED = Color("ff987e")
const MUTED = Color("a6bdb8")
const PANEL = Color("19343a")
const STATION_NAMES = {
	"bag": "Take a paper bag", "bucket": "Take a bucket", "scoop": "Pick up the scoop",
	"supply": "Scoop fresh donuts", "package": "Your order", "cinnamon": "Coat with cinnamon",
	"powdered": "Coat with powdered sugar", "serve": "Hand to the customer",
	"heat_down": "Turn heat down", "heat_up": "Turn heat up",
	"repair": "Hold to free the jam", "refill": "Hold to refill batter", "trash": "Empty the order"
}

var model = Model.new()
var world
var audio
var ui: Control
var screen: Control
var overlay: Control
var toast_layer: Control
var hud: Dictionary = {}
var current_view = "title"
var held_tool = "none"
var hold_station = ""
var hover_station = ""
var paused = false
var muted = false
var music_on = true
var reduced_motion = false
var tutorial_seen = false
var saved_run: Dictionary = {}
var test_mode = false
var capture_view = ""
var capture_done = false
var elapsed = 0.0
var autosave_time = 0.0
var right_dragging = false
var dashboard
var feedback
var profile
var practice = false
var selected_difficulty = "normal"
var selected_mode = "campaign"
var run_id = ""
var best_streak = 0
var sfx_volume = 0.8
var music_volume = 0.35
var ambience_volume = 0.5
var look_sensitivity = 1.0
var invert_look = false
var _active_faults: Dictionary = {}
var _quota_announced = false
var _practice_served = 0
var _result_recorded = false
var _result_badges: Array = []
var _legacy_migration_done = false
var _save_failed = false
var _run_load_notice = ""

func _ready() -> void:
	DisplayServer.window_set_title("Golden Hour")
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke" or arg == "--test-mode": test_mode = true
		if arg.begins_with("--capture-view="):
			capture_view = arg.trim_prefix("--capture-view=")
			test_mode = true
	_load_settings()
	_load_saved_run()
	if ResourceLoader.exists("res://scripts/player_profile.gd"):
		profile = load("res://scripts/player_profile.gd").new()
		profile.test_mode = test_mode
		profile.load_profile()
	world = World.new()
	add_child(world)
	audio = Audio.new()
	add_child(audio)
	_apply_audio_settings()
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme = Theme.new()
	theme.default_font = load("res://assets/fonts/Fredoka-Medium.ttf")
	theme.default_font_size = 20
	ui.theme = theme
	if ResourceLoader.exists("res://scripts/stand_feedback.gd"):
		feedback = load("res://scripts/stand_feedback.gd").new()
		feedback.z_index = 20
		feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(feedback)
	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast_layer)
	_resize()
	get_viewport().size_changed.connect(_resize)
	_apply_effect_settings()
	_apply_cosmetic()
	_show_title()
	if not capture_view.is_empty() or OS.get_cmdline_user_args().has("--smoke"):
		model.new_run(4182)
		model.start_shift()
		_show_play()
		if capture_view == "title": _show_title()
		elif capture_view == "help": _show_help(false)
		elif capture_view == "settings": _show_settings()
		elif capture_view == "collection": _show_collection()
		elif capture_view == "pause": _show_pause()
		elif capture_view == "practice": _start_practice()
		elif capture_view == "jam":
			model.jammed = true
			_refresh_hud()
		elif capture_view == "overheat":
			model.temperature = 210.0
			model.overheated = true
			_refresh_hud()
		elif capture_view == "result":
			model.sales = 30
			model.finish_shift()
			_finish_run()
		elif capture_view == "shop":
			model.sales = model.target
			model.finish_shift()
			_show_shop()
		elif capture_view == "service":
			_act("bag")
			_act("scoop")
			_act("supply")
			_act("package")
			_act("supply")
			_act("package")
			_act("cinnamon")
			_act("package")
	_sync_world()
	print("STAND_READY version=" + VERSION)

func _resize() -> void:
	var size = get_viewport().get_visible_rect().size
	var factor = minf(size.x / 1280.0, size.y / 800.0)
	ui.scale = Vector2.ONE * factor
	ui.position = (size - Vector2(1280, 800) * factor) * 0.5
	ui.size = Vector2(1280, 800)

func _process(delta: float) -> void:
	elapsed += delta
	if current_view == "play" and not paused:
		var step = minf(delta, 0.1)
		if hold_station == "repair": _handle_hold_result(model.repair(step))
		elif hold_station == "refill": _handle_hold_result(model.refill(step))
		if practice and model.has_method("tick_practice"): model.tick_practice(step)
		else: model.tick(step)
		_process_events()
		_sync_world()
		if not right_dragging:
			hover_station = world.pick_station(get_viewport().get_mouse_position())
			world.set_hover_station(hover_station)
		_refresh_hud()
		autosave_time += delta
		if autosave_time >= 2.0:
			autosave_time = 0
			_save_run()
		if model.phase == "shop" and not practice:
			_save_run()
			_show_shop()
		elif model.phase in ["won", "lost"] and not practice: _finish_run()
	if not capture_view.is_empty() and elapsed > 2.5 and not capture_done:
		capture_done = true
		_capture()
	if test_mode and capture_view.is_empty() and OS.get_cmdline_user_args().has("--smoke") and elapsed > 5:
		print("STAND_SMOKE_PASS phase=%s supply=%d orders=%d" % [model.phase, model.supply, model.orders.size()])
		get_tree().quit(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(overlay): _close_overlay()
			elif current_view == "play": _show_pause()
			return
		if current_view != "play" or paused: return
		match event.keycode:
			KEY_B: _act("bag")
			KEY_V: _act("bucket")
			KEY_S: _act("scoop")
			KEY_F: _act("supply")
			KEY_SPACE: _act("package")
			KEY_C: _act("cinnamon")
			KEY_P: _act("powdered")
			KEY_E: _act("serve")
			KEY_MINUS: _act("heat_down")
			KEY_EQUAL: _act("heat_up")
			KEY_R: _start_hold("repair")
			KEY_T: _start_hold("refill")
			KEY_X: _act("trash")
			KEY_H: _show_help(false)
			KEY_HOME: world.reset_look()
	if event is InputEventKey and not event.pressed and event.keycode in [KEY_R, KEY_T]: _stop_hold()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			right_dragging = event.pressed and current_view == "play" and not paused
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_stop_hold()
			elif current_view == "play" and not paused:
				var station: String = world.pick_station(event.position)
				if station in ["repair", "refill"]: _start_hold(station)
				elif not station.is_empty(): _act(station)
	if event is InputEventMouseMotion and right_dragging and not paused:
		world.look_offset(event.relative * Vector2(look_sensitivity, -look_sensitivity if invert_look else look_sensitivity))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and current_view == "play" and not paused and not test_mode:
		_show_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _save_run()

func _act(station: String) -> void:
	if current_view != "play" or paused or model.phase != "playing": return
	_stop_hold()
	var result: Dictionary = {}
	match station:
		"bag", "bucket":
			result = model.choose_package(station)
			if result.get("ok", false): held_tool = "none"
		"scoop":
			held_tool = "scoop"
			result = {"ok": true, "message": "Scoop ready. Click the fresh donut tray."}
		"supply":
			if held_tool != "scoop":
				_toast("Pick up the scoop first.", RED)
				return
			result = model.scoop()
		"package":
			if held_tool == "scoop" and model.scoop_count > 0:
				result = model.dump()
			elif held_tool == "package":
				held_tool = "none"
				result = {"ok": true, "message": "Order on the counter."}
			elif not model.package_type.is_empty() and model.package_count == model.package_capacity() and not model.package_flavor.is_empty():
				held_tool = "package"
				result = {"ok": true, "message": "Order in hand. Click the customer to hand it over."}
			else:
				result = {"ok": false, "message": "Fill your scoop, then click here to pour. Coat a full order before lifting."}
		"cinnamon", "powdered":
			result = model.coat(station)
			if result.get("ok", false): held_tool = "none"
		"serve":
			if held_tool != "package":
				_toast("Lift the filled, coated order from the counter first.", RED)
				return
			result = model.serve()
			if result.get("ok", false):
				held_tool = "none"
				var amount = float(result.get("amount", 0))
				best_streak = maxi(best_streak, model.streak)
				audio.play_served(amount, model.streak)
				var tier = mini(3, model.streak / 2)
				if is_instance_valid(feedback):
					tier = feedback.tier_for(result)
					feedback.celebrate(result, ui.get_global_transform().affine_inverse() * world.station_screen_position("serve"))
				world.burst_reward(amount, tier)
				if practice: _practice_served += 1
			elif result.get("code", "") == "wrong_order": held_tool = "none"
		"heat_down": result = model.adjust_heat(-1)
		"heat_up": result = model.adjust_heat(1)
		"trash":
			result = model.discard()
			held_tool = "none"
	if result.is_empty(): return
	if bool(result.get("ok", false)):
		if station != "serve": audio.play_action(station)
		world.animate_action(station)
		_save_run()
	else:
		audio.play_warning(str(result.get("code", "mistake")))
	# The dashboard explains normal scoop/pour actions continuously. Reserve
	# transient notices for errors and actions with information worth reading.
	if not bool(result.get("ok", false)) or station in ["trash", "heat_down", "heat_up"]:
		_toast(str(result.get("message", "")), MINT if bool(result.get("ok", false)) else RED)
	_process_events()
	_sync_world()
	_refresh_hud()

func _start_hold(station: String) -> void:
	if current_view != "play" or paused or station not in ["repair", "refill"]: return
	if station == "repair" and not model.jammed and float(model.get("jam_risk")) < 0.5:
		_toast("The feeder is healthy. Service it when wear rises.", MINT)
		return
	if station == "refill" and model.batter >= model.batter_capacity():
		_toast("The hopper is already full.", MINT)
		return
	hold_station = station
	world.animate_action(station)

func _stop_hold() -> void:
	hold_station = ""

func _handle_hold_result(result: Dictionary) -> void:
	var complete = str(result.get("code", "")) in ["repaired", "serviced", "refilled"]
	if complete:
		_stop_hold()
		if not str(result.get("message", "")).is_empty(): _toast(str(result.message), MINT)
	elif not bool(result.get("ok", false)):
		_stop_hold()
		_toast(str(result.get("message", "")), GOLD)

func _process_events() -> void:
	for event in model.events:
		var kind = str(event.get("type", ""))
		if kind == "customer_arrived": audio.play_customer()
		elif kind in ["jam", "overheat", "walkout"]:
			audio.play_warning(kind)
			if kind == "walkout": _toast("A customer left. Read the new front ticket.", RED)
		elif kind in ["repair", "refill"]: audio.play_action(kind)
	model.events.clear()

func _view_state() -> Dictionary:
	return {"phase": model.phase, "shift_index": model.shift_index, "time_left": model.time_left,
		"orders": model.orders, "supply": model.supply, "batter": model.batter,
		"temperature": model.temperature, "heat_setting": model.heat_setting,
		"jammed": model.jammed, "overheated": model.overheated, "jam_progress": model.jam_progress,
		"refill_progress": model.refill_progress, "package_type": model.package_type,
		"package_count": model.package_count, "package_flavor": model.package_flavor,
		"scoop_count": model.scoop_count, "held_tool": held_tool, "hold_station": hold_station, "sales": model.sales,
		"served": model.served, "missed": model.missed, "mistakes": model.mistakes,
		"streak": model.streak, "target": model.target, "credits": model.credits,
		"owned": model.owned, "production_count": model.production_count,
		"shift_duration": model.shift_duration, "supply_capacity": model.supply_capacity,
		"paused": paused or current_view != "play", "jam_risk": model.get("jam_risk"), "practice": practice}

func _sync_world() -> void:
	var state = _view_state()
	world.sync_state(state)
	if audio.has_method("sync_machine"): audio.sync_machine(state)

func _new_screen() -> void:
	_stop_hold()
	_close_overlay()
	for child in toast_layer.get_children():
		toast_layer.remove_child(child)
		child.queue_free()
	if is_instance_valid(screen):
		ui.remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.size = Vector2(1280, 800)
	ui.add_child(screen)
	ui.move_child(toast_layer, ui.get_child_count() - 1)
	hud.clear()
	dashboard = null
	if is_instance_valid(feedback): feedback.reset()

func _show_title() -> void:
	current_view = "title"
	# Keep the practice marker until a new/continued run replaces its model.
	# Closing from this title must never save practice over the real checkpoint.
	_new_screen()
	world.reset_look()
	_sync_world()
	if ResourceLoader.exists("res://assets/art/title_keyart.png"):
		var art = TextureRect.new()
		art.texture = load("res://assets/art/title_keyart.png")
		art.position = Vector2.ZERO
		art.size = Vector2(1280, 800)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(art)
	var p = _panel(screen, Vector2(32, 28), Vector2(480, 744), INK)
	_label(p, "FRESH DONUTS. BIG LITTLE MOMENTS.", Vector2(28, 26), Vector2(424, 24), 14, GOLD)
	_label(p, "GOLDEN HOUR", Vector2(25, 67), Vector2(430, 66), 45, CREAM)
	_text(p, "Your hands. Your fryer.\nA whole fairground waiting.", Vector2(30, 147), Vector2(420, 70), 24, MUTED)
	var summary = profile.get_summary() if profile != null else {}
	_label(p, "%d orders served  ·  %d perfect runs" % [int(summary.get("total_served", 0)), int(summary.get("campaign_wins", 0))], Vector2(30, 230), Vector2(420, 27), 15, GOLD)
	_label(p, "CHOOSE YOUR PACE", Vector2(30, 281), Vector2(420, 20), 12, MUTED)
	_button(p, "STANDARD", Vector2(30, 310), Vector2(202, 42), func():
		selected_difficulty = "normal"
		_show_title(), GOLD if selected_difficulty == "normal" else PANEL)
	_button(p, "RELAXED", Vector2(246, 310), Vector2(202, 42), func():
		selected_difficulty = "relaxed"
		_show_title(), GOLD if selected_difficulty == "relaxed" else PANEL)
	_label(p, "A lively rush with room to master the rhythm." if selected_difficulty == "normal" else "More time, patient customers, the same hands-on work.", Vector2(30, 365), Vector2(420, 25), 13, MUTED)
	_button(p, "OPEN THE STAND  >", Vector2(30, 410), Vector2(418, 56), func():
		selected_mode = "campaign"
		_request_new_run())
	if not saved_run.is_empty():
		_button(p, "CONTINUE YOUR SHIFT", Vector2(30, 480), Vector2(418, 45), _continue_run, MINT)
	else:
		_button(p, "PRACTICE  ·  NO PRESSURE", Vector2(30, 480), Vector2(418, 45), _start_practice, PANEL)
	_button(p, "Collection", Vector2(30, 545), Vector2(202, 43), _show_collection, PANEL)
	_button(p, "Settings", Vector2(246, 545), Vector2(202, 43), _show_settings, PANEL)
	var endless_ready = profile != null and profile.is_endless_unlocked()
	var endless = _button(p, "ENDLESS RUSH" if endless_ready else "ENDLESS  ·  WIN A CAMPAIGN", Vector2(30, 603), Vector2(418, 40), func():
		selected_mode = "endless"
		_request_new_run(), PANEL)
	endless.disabled = not endless_ready
	_button(p, "How to play" if saved_run.is_empty() else "Practice", Vector2(30, 665), Vector2(202, 36), func():
		if saved_run.is_empty(): _show_help(false)
		else: _start_practice(), PANEL)
	_button(p, "Credits", Vector2(246, 665), Vector2(202, 36), _show_credits, PANEL)
	_label(screen, "GOLDEN HOUR  /  " + VERSION, Vector2(938, 752), Vector2(310, 26), 13, CREAM).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not OS.has_feature("web"):
		_button(screen, "QUIT GAME", Vector2(1090, 22), Vector2(158, 38), _quit_game, PANEL)
	var notices: Array[String] = []
	if not _run_load_notice.is_empty(): notices.append(_run_load_notice)
	if profile != null and not str(profile.load_warning).is_empty(): notices.append(str(profile.load_warning))
	if not notices.is_empty():
		var notice = _panel(screen, Vector2(552, 568), Vector2(696, 160), INK)
		_label(notice, "SAVE NOTICE", Vector2(22, 15), Vector2(652, 24), 16, GOLD)
		_text(notice, "\n".join(notices), Vector2(22, 49), Vector2(652, 97), 17, CREAM)

func _request_new_run() -> void:
	if saved_run.is_empty():
		_start_new_run()
		return
	var p = _modal(Vector2(550, 300))
	_label(p, "A fresh start?", Vector2(30, 26), Vector2(490, 50), 35)
	_text(p, "Opening a new stand replaces your current saved run. Your collection and records stay with you.", Vector2(30, 98), Vector2(490, 75), 21, MUTED)
	_button(p, "Keep my run", Vector2(30, 213), Vector2(235, 52), _close_overlay, PANEL)
	_button(p, "Start fresh", Vector2(285, 213), Vector2(235, 52), _start_new_run)

func _start_new_run() -> void:
	practice = false
	_run_load_notice = ""
	model.new_run(0, selected_difficulty, selected_mode)
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	best_streak = 0
	_result_recorded = false
	_result_badges.clear()
	held_tool = "none"
	_close_overlay()
	if not tutorial_seen: _show_help(true)
	else: _begin_shift()

func _start_practice() -> void:
	if current_view == "play" and not practice: _save_run()
	practice = true
	_practice_served = 0
	model.new_run(4182, "relaxed", "campaign")
	held_tool = "none"
	_begin_shift()
	_toast("Practice is open. Your saved campaign is safe.", MINT)

func _begin_shift() -> void:
	model.start_shift()
	held_tool = "none"
	_active_faults.clear()
	_quota_announced = false
	audio.start_music()
	_show_play()
	_sync_world()
	_save_run()

func _continue_run() -> void:
	if not model.from_save(saved_run.get("model", {})):
		_toast("This saved shift could not be loaded. You can still open a new stand.", RED)
		return
	practice = false
	selected_difficulty = str(model.get("difficulty"))
	selected_mode = str(model.get("mode"))
	run_id = str(saved_run.get("run_id", "legacy-" + str(model.seed_value)))
	best_streak = int(saved_run.get("best_streak", model.streak))
	_result_recorded = false
	held_tool = str(saved_run.get("held_tool", "none"))
	if held_tool not in ["none", "scoop", "package"]: held_tool = "none"
	audio.start_music()
	_active_faults.clear()
	_quota_announced = model.sales >= model.target
	if model.phase == "shop": _show_shop()
	else: _show_play()
	_sync_world()

func _shift_count() -> int:
	return model.TARGETS.size()

func _show_play() -> void:
	current_view = "play"
	_new_screen()
	dashboard = Hud.new()
	screen.add_child(dashboard)
	dashboard.pause_requested.connect(_show_pause)
	dashboard.help_requested.connect(func(): _show_help(false))
	dashboard.reduced_motion = reduced_motion
	hud = dashboard.controls
	_refresh_hud()

func _refresh_hud() -> void:
	if current_view != "play" or not is_instance_valid(dashboard): return
	var faults = _machine_faults()
	if is_instance_valid(feedback): feedback.visible = faults.is_empty() or not bool(faults[0].get("critical", false))
	var codes: Dictionary = {}
	for fault in faults:
		var code = str(fault.code)
		codes[code] = true
		if not _active_faults.has(code) and code not in ["refilling", "servicing", "low_stock", "cold"]:
			if is_instance_valid(feedback): feedback.notify_fault(code, str(fault.title))
			if code in ["low_batter", "empty_batter"]: audio.play_warning("low_batter")
	_active_faults = codes
	var info: Dictionary = model.get_campaign_info() if model.has_method("get_campaign_info") else {}
	var context: Dictionary = _guide_context()
	context.merge({"practice": practice, "endless": selected_mode == "endless", "total_shifts": _shift_count(), "shift_name": info.get("name", "Opening time"), "difficulty": selected_difficulty, "batter_capacity": model.batter_capacity(), "machine_status": _machine_short_status(), "faults": faults, "notice": "PRACTICE  ·  Time and patience are frozen. Esc to leave." if practice else ("QUOTA REACHED  ·  Every extra order earns upgrade coins." if model.sales >= model.target else "")})
	dashboard.refresh(_view_state(), context)
	if not faults.is_empty():
		var target: Vector2 = world.station_screen_position(str(faults[0].station))
		dashboard.fault_target = ui.get_global_transform().affine_inverse() * target
	if model.sales >= model.target and not _quota_announced and not practice:
		_quota_announced = true
		audio.play_goal()
		if is_instance_valid(feedback): feedback.show_goal()

func _machine_faults() -> Array:
	var faults: Array = []
	if model.jammed:
		faults.append({"code": "jam", "title": "FEEDER JAMMED", "action": "Production stopped. Hold R or the brass lever.", "station": "repair", "critical": true})
	if model.overheated:
		faults.append({"code": "overheat", "title": "OIL TOO HOT", "action": "Turn heat down with −. Cool below 190°.", "station": "heat_down", "critical": true})
	elif model.temperature >= 198:
		faults.append({"code": "heat_warning", "title": "HEAT IS CLIMBING", "action": "Lower the heat with − before the fryer stops.", "station": "heat_down", "critical": false})
	if model.batter <= 0:
		faults.append({"code": "empty_batter", "title": "HOPPER EMPTY", "action": "No new donuts. Hold T or the batter hopper.", "station": "refill", "critical": true})
	elif model.batter <= 12:
		faults.append({"code": "low_batter", "title": "BATTER RUNNING LOW", "action": "%d left. Hold T or the hopper to top up." % model.batter, "station": "refill", "critical": false})
	if hold_station == "refill" and model.batter > 12:
		faults.append({"code": "refilling", "title": "REFILLING THE HOPPER", "action": "Keep holding. Release to pause the refill.", "station": "refill", "critical": false})
	if hold_station == "repair" and not model.jammed:
		faults.append({"code": "servicing", "title": "SERVICING THE FEEDER", "action": "Keep holding to prevent the next jam.", "station": "repair", "critical": false})
	elif not model.jammed and model.jam_risk >= 0.7:
		faults.append({"code": "service_due", "title": "FEEDER NEEDS A SERVICE", "action": "Wear is high. Hold R now to prevent a jam.", "station": "repair", "critical": false})
	if model.temperature < 145:
		faults.append({"code": "cold", "title": "OIL NEEDS TO WARM UP", "action": "Raise heat with +. Donuts cook above 145°.", "station": "heat_up", "critical": false})
	if model.supply <= 3:
		faults.append({"code": "low_stock", "title": "FRESH TRAY LOW" if model.supply > 0 else "FRESH TRAY EMPTY", "action": "Let the fryer replenish the tray. Check its status.", "station": "supply", "critical": false})
	return faults

func _machine_short_status() -> String:
	if model.jammed: return "JAMMED"
	if model.overheated: return "TOO HOT"
	if model.batter <= 0: return "EMPTY HOPPER"
	if model.temperature < 145: return "WARMING UP"
	if hold_station == "refill": return "REFILLING"
	if hold_station == "repair": return "SERVICING"
	if model.supply >= model.supply_capacity: return "TRAY FULL"
	return "MAKING DONUTS"

func _guide_context() -> Dictionary:
	var target = "bag"
	var prompt = "Take the right container"
	var hint = "Read the front customer's ticket, then click its bag or bucket."
	var step = "1 / 5  ·  CHOOSE A CONTAINER"
	if not model.orders.is_empty(): target = str(model.orders[0].package)
	var wrong_package: bool = not model.orders.is_empty() and not model.package_type.is_empty() and model.package_type != str(model.orders[0].package)
	var wrong_coating: bool = not model.orders.is_empty() and not model.package_flavor.is_empty() and model.package_flavor != str(model.orders[0].flavor)
	var needs_recovery: bool = wrong_package or wrong_coating
	if needs_recovery:
		target = "trash"
		prompt = "Discard this order" if not model.package_flavor.is_empty() else "Clear the wrong container"
		hint = "Press X to discard it, then match the front ticket." if not model.package_flavor.is_empty() else "Press X to recover plain donuts and choose a %s." % str(model.orders[0].package)
		step = "RECOVER THE ORDER  ·  X TO CLEAR"
	elif held_tool == "package":
		target = "serve"
		prompt = "Hand over your order"
		hint = "Click the front customer or the serving mat."
		step = "5 / 5  ·  SERVE THE CUSTOMER"
	elif not model.package_type.is_empty():
		if model.package_count < model.package_capacity():
			step = "2 / 5  ·  SCOOP AND POUR"
			if held_tool != "scoop":
				target = "scoop"
				prompt = "Pick up the scoop"
				hint = "Your scoop stays in your hand between portions."
			elif model.scoop_count > 0:
				target = "package"
				prompt = "Pour %d donuts" % model.scoop_count
				hint = "Click your %s. %d more donuts will fill it." % [model.package_type, model.package_capacity() - model.package_count]
			else:
				target = "supply"
				prompt = "Scoop fresh donuts"
				hint = "Click the tray, then your container. Each scoop holds %d." % model.scoop_capacity()
		elif model.package_flavor.is_empty():
			target = str(model.orders[0].flavor) if not model.orders.is_empty() else "cinnamon"
			prompt = "Add the requested sugar"
			hint = "Cinnamon and powdered sugar cannot be swapped once added."
			step = "3 / 5  ·  COAT THE DONUTS"
		else:
			target = "package"
			prompt = "Lift your finished order"
			hint = "Click your coated package, then hand it to the customer."
			step = "4 / 5  ·  LIFT THE PACKAGE"
	if not hover_station.is_empty() and hold_station.is_empty() and not needs_recovery:
		if hover_station != target:
			hint = "Next order step: " + prompt.to_lower() + "."
			step = "COUNTER ACTION  ·  CLICK THE HIGHLIGHTED OBJECT"
		target = hover_station
		prompt = _context_prompt()
	if not hold_station.is_empty():
		target = hold_station
		prompt = "Clearing the feeder" if target == "repair" else "Pouring fresh batter"
		var progress = float(model.jam_progress if target == "repair" else model.refill_progress)
		hint = "%d%% complete. Keep holding; release to pause." % int(progress * 100.0)
		step = "MACHINE CARE  ·  HOLD TO COMPLETE"
	var keys = {"bag": "B", "bucket": "V", "scoop": "S", "supply": "F", "package": "SPACE", "cinnamon": "C", "powdered": "P", "serve": "E", "repair": "HOLD R", "refill": "HOLD T", "heat_down": "−", "heat_up": "+", "trash": "X"}
	return {"prompt": prompt, "hint": hint, "step": step, "key": keys.get(target, "CLICK"), "station": target}

func _context_prompt() -> String:
	if hover_station == "repair":
		if model.jammed: return "Hold to clear the jam"
		if model.jam_risk >= 0.5: return "Hold to service the feeder"
		return "Feeder healthy"
	if hover_station == "refill" and model.batter >= model.batter_capacity(): return "Batter hopper full"
	if hover_station == "package":
		if held_tool == "scoop" and model.scoop_count > 0: return "Pour into your order"
		if held_tool == "package": return "Set your order down"
		if not model.package_flavor.is_empty(): return "Lift the finished order"
	return str(STATION_NAMES.get(hover_station, "Point at your counter"))

func _next_hint() -> String:
	return str(_guide_context().hint)

func _show_shop() -> void:
	current_view = "shop"
	_new_screen()
	_sync_world()
	_shade(screen)
	var info: Dictionary = Model.Content.shift_info(model.shift_index + 1, selected_difficulty, selected_mode)
	_label(screen, "SHIFT COMPLETE  /  TIME TO TUNE YOUR STAND", Vector2(54, 37), Vector2(1140, 25), 16, GOLD)
	_label(screen, "A little better. A little busier.", Vector2(51, 83), Vector2(1170, 60), 42)
	_label(screen, "%s earned   ·   %d customers served   ·   %d upgrade coins" % [_money(model.sales), model.served, model.credits], Vector2(56, 154), Vector2(1160, 31), 22, MINT)
	var next = _panel(screen, Vector2(54, 210), Vector2(1172, 73), PANEL)
	_label(next, "UP NEXT  ·  " + str(info.get("name", "The next rush")), Vector2(18, 10), Vector2(800, 26), 21, GOLD)
	_label(next, "Target $%d  ·  %ds  ·  %s" % [int(info.target), int(info.duration), " / ".join(info.get("modifiers", []))], Vector2(18, 42), Vector2(1136, 22), 14, MUTED)
	var offers: Array = model.get_shop_offers()
	for i in range(mini(offers.size(), 3)):
		var offer: Dictionary = offers[i]
		var card = _panel(screen, Vector2(54 + i * 397, 306), Vector2(378, 312), PANEL)
		_label(card, str(offer.get("category", "EQUIPMENT")), Vector2(22, 19), Vector2(300, 20), 12, GOLD)
		_text(card, str(offer.get("name", "Upgrade")), Vector2(21, 54), Vector2(336, 73), 29)
		_text(card, str(offer.get("description", "")), Vector2(22, 140), Vector2(334, 96), 18, MUTED)
		var cost = int(offer.get("cost", 0))
		var button = _button(card, "INSTALL  ·  %d COINS" % cost, Vector2(22, 253), Vector2(334, 43), _buy_upgrade.bind(str(offer.id)), GOLD if model.credits >= cost else PANEL)
		button.disabled = model.credits < cost
		if button.disabled: button.text = "NEED %d MORE COINS" % (cost - model.credits)
	if offers.is_empty():
		_text(screen, "Your equipment is fully upgraded.\nTake your stand into the next rush.", Vector2(290, 390), Vector2(700, 100), 29, MINT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(screen, "START NEXT SHIFT  >", Vector2(831, 664), Vector2(395, 58), _begin_shift, MINT)
	_button(screen, "Save & return to title", Vector2(54, 664), Vector2(352, 58), func():
		_save_run()
		_show_title(), PANEL)
	_label(screen, "Earn coins by meeting your quota. All equipment is bought with coins earned in this run.", Vector2(56, 751), Vector2(1160, 24), 15, MUTED)

func _buy_upgrade(id: String) -> void:
	var result = model.buy_upgrade(id)
	if result is Dictionary:
		if not result.get("ok", false): return
	elif not result: return
	audio.play_event("upgrade")
	_save_run()
	_show_shop()

func _finish_run() -> void:
	current_view = "result"
	_new_screen()
	_sync_world()
	var won: bool = model.phase == "won"
	var stats: Dictionary = model.get_stats()
	var career_saved: bool = true
	if not _result_recorded:
		_result_recorded = true
		if not test_mode and not practice and profile != null:
			_result_badges = profile.record_run({"run_id": run_id, "won": won, "difficulty": selected_difficulty, "mode": selected_mode, "shift": model.shift_index + 1, "total_served": stats.get("total_served", model.served), "total_sales": stats.get("total_sales", model.sales), "best_streak": maxi(best_streak, int(stats.get("best_streak", 0))), "mistakes": model.mistakes})
		audio.play_event("win" if won else "failure")
	if not test_mode and not practice:
		# Recording is idempotent in memory; persistence can be retried independently.
		# Keep the last playable checkpoint until career progress is on disk.
		career_saved = profile != null and profile.save_profile()
		if career_saved:
			saved_run.clear()
			_legacy_migration_done = true
			_save_settings()
			_delete_run_files()
	_shade(screen)
	var p = _panel(screen, Vector2(235, 87), Vector2(810, 627), INK)
	_label(p, "THE LAST DONUT HAS A LITTLE MAGIC." if won else "EVERY GREAT STAND FINDS ITS RHYTHM.", Vector2(34, 28), Vector2(742, 26), 16, GOLD)
	_label(p, "Rush handled." if won else "Closing time.", Vector2(30, 82), Vector2(750, 71), 55)
	_text(p, "The fair is winding down, and your stand made its mark. Endless Rush and the Cherry Jubilee palette are yours." if won else "Take a breath. Keep your scoop in hand, read the first ticket, and use quiet moments to refill and service the fryer.", Vector2(36, 173), Vector2(738, 88), 23, MUTED)
	_label(p, ("ROUND %d" % [model.shift_index + 1] if selected_mode == "endless" else "SHIFT %d / %d" % [model.shift_index + 1, _shift_count()]) + "   ·   %s / $%d" % [_money(model.sales), model.target], Vector2(36, 278), Vector2(738, 33), 25, GOLD)
	var values = [[str(stats.get("total_served", model.served)), "CUSTOMERS SERVED"], [_money(float(stats.get("total_sales", model.sales))), "TOTAL SALES"], [str(maxi(best_streak, int(stats.get("best_streak", 0)))), "BEST STREAK"]]
	for i in range(3):
		var metric = _panel(p, Vector2(36 + i * 246, 330), Vector2(230, 85), PANEL)
		_label(metric, values[i][0], Vector2(15, 10), Vector2(200, 36), 29, CREAM)
		_label(metric, values[i][1], Vector2(16, 56), Vector2(199, 17), 11, MUTED)
	if not career_saved:
		_button(p, "RETRY SAVING CAREER", Vector2(36, 433), Vector2(738, 46), _finish_run, GOLD)
	elif not _result_badges.is_empty():
		_label(p, "BADGE EARNED  ·  " + str(_result_badges[0].get("name", "New achievement")), Vector2(36, 439), Vector2(738, 29), 18, MINT)
	_button(p, "OPEN AGAIN", Vector2(36, 497), Vector2(355, 56), _start_new_run if career_saved else _request_new_run)
	_button(p, "Back to the stand", Vector2(415, 497), Vector2(359, 56), _show_title, PANEL)
	_text(p, "Your career progress and unlocked stand colours are saved automatically." if career_saved else "Career could not be saved. Your previous shift checkpoint is safe. Free disk space, then retry saving before closing.", Vector2(36, 569), Vector2(738, 43), 14, MUTED if career_saved else RED)

func _delete_run_files() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".backup"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _show_pause() -> void:
	if current_view != "play": return
	_save_run()
	var p = _modal(Vector2(584, 492 if practice else 414))
	_label(p, "Take a breather.", Vector2(30, 27), Vector2(524, 55), 39)
	_label(p, "Practice has no clock or lost customers." if practice else "The stand is paused. Nothing moves until you return.", Vector2(32, 93), Vector2(520, 29), 16, MUTED)
	_button(p, "BACK TO THE COUNTER", Vector2(30, 145), Vector2(524, 55), _close_overlay)
	_button(p, "Settings", Vector2(30, 222), Vector2(251, 46), _show_settings, PANEL)
	_button(p, "How to play", Vector2(303, 222), Vector2(251, 46), func(): _show_help(false), PANEL)
	if practice:
		_button(p, "Try a jam", Vector2(30, 293), Vector2(166, 43), func():
			model.jammed = true
			_close_overlay()
			_refresh_hud(), PANEL)
		_button(p, "Try hot oil", Vector2(209, 293), Vector2(166, 43), func():
			model.temperature = 210.0
			model.overheated = true
			_close_overlay()
			_refresh_hud(), PANEL)
		_button(p, "Try refilling", Vector2(388, 293), Vector2(166, 43), func():
			model.batter = 0
			_close_overlay()
			_refresh_hud(), PANEL)
	_button(p, "LEAVE PRACTICE" if practice else "Save & return to title", Vector2(30, 391 if practice else 316), Vector2(524, 54), func():
		_save_run()
		_show_title(), PANEL)
	_sync_world()

func _show_help(start_after: bool) -> void:
	var p = _modal(Vector2(942, 698))
	_label(p, "Welcome behind the counter.", Vector2(32, 25), Vector2(878, 54), 39)
	_label(p, "CLICK THE OBJECTS. WATCH YOUR HANDS. FIND YOUR RHYTHM.", Vector2(34, 89), Vector2(874, 26), 15, GOLD)
	var steps = [
		["1  READ THE FIRST TICKET", "Take a bag for 6 donuts or a bucket for 12. The cream ticket is the customer you are serving."],
		["2  SCOOP, THEN POUR", "Pick up the scoop. Click the fresh tray, then your container. Keep scooping and pouring until it is full."],
		["3  COAT, LIFT, HAND OVER", "Click the requested sugar. Lift the finished package, then click the customer or serving mat."],
		["4  KEEP THE FRYER RUNNING", "A clear alert points to trouble. Hold R to clear a jam, lower heat with −, and hold T to refill batter."]
	]
	for i in range(4):
		var card = _panel(p, Vector2(32, 138 + i * 94), Vector2(878, 81), PANEL)
		_label(card, steps[i][0], Vector2(15, 10), Vector2(848, 23), 17, GOLD)
		_text(card, steps[i][1], Vector2(16, 39), Vector2(846, 38), 16, MUTED)
	_text(p, "Right-drag to look around; Home recentres. Esc pauses. Keyboard shortcuts appear in the bottom guide.\nPractice freezes time and patience, and lets you try machine faults from its pause menu.", Vector2(34, 528), Vector2(874, 56), 16, MUTED)
	_button(p, "LET'S OPEN  >" if start_after else "GOT IT", Vector2(34, 616), Vector2(566, 48), func():
		_close_overlay()
		if start_after:
			tutorial_seen = true
			_save_settings()
			_begin_shift())
	_button(p, "TRY PRACTICE", Vector2(622, 616), Vector2(286, 48), _start_practice, PANEL)

func _show_settings() -> void:
	var p = _modal(Vector2(718, 712))
	_label(p, "Make yourself at home.", Vector2(30, 25), Vector2(658, 52), 37)
	_button(p, "Sound: " + ("OFF" if muted else "ON"), Vector2(30, 96), Vector2(316, 43), func():
		muted = not muted
		_apply_audio_settings()
		_save_settings()
		_show_settings(), PANEL)
	_button(p, "Music: " + ("ON" if music_on else "OFF"), Vector2(368, 96), Vector2(320, 43), func():
		music_on = not music_on
		_apply_audio_settings()
		_save_settings()
		_show_settings(), PANEL)
	_slider_row(p, "Sound effects", 166, sfx_volume, func(value): sfx_volume = value; _apply_audio_settings(); _save_settings())
	_slider_row(p, "Music", 222, music_volume, func(value): music_volume = value; _apply_audio_settings(); _save_settings())
	_slider_row(p, "Fairground ambience", 278, ambience_volume, func(value): ambience_volume = value; _apply_audio_settings(); _save_settings())
	_button(p, "Motion: " + ("REDUCED" if reduced_motion else "FULL"), Vector2(30, 342), Vector2(316, 43), func():
		reduced_motion = not reduced_motion
		_apply_effect_settings()
		_save_settings()
		_show_settings(), PANEL)
	_button(p, "Look: " + ("INVERTED" if invert_look else "NORMAL"), Vector2(368, 342), Vector2(320, 43), func():
		invert_look = not invert_look
		_save_settings()
		_show_settings(), PANEL)
	_slider_row(p, "Look sensitivity", 412, (look_sensitivity - 0.35) / 1.65, func(value): look_sensitivity = 0.35 + value * 1.65; _save_settings(), "multiplier")
	_text(p, "B bag / V bucket / S scoop / F fresh tray / Space pour or lift\nC cinnamon / P powdered / E serve / hold R repair / hold T refill\n− + heat / X discard / H help / Home recenter / F11 fullscreen", Vector2(30, 486), Vector2(658, 75), 16, MUTED)
	_button(p, "DONE", Vector2(30, 613), Vector2(436, 52), _close_overlay)
	_button(p, "Credits", Vector2(487, 613), Vector2(201, 52), _show_credits, PANEL)

func _slider_row(parent: Node, title: String, y: float, value: float, callback: Callable, label_mode: String = "percent") -> void:
	_label(parent, title, Vector2(32, y), Vector2(250, 27), 17, MUTED)
	var label = _label(parent, "%.2f×" % (0.35 + value * 1.65) if label_mode == "multiplier" else "%d%%" % int(roundf(value * 100)), Vector2(618, y), Vector2(68, 27), 17, GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider = HSlider.new()
	slider.position = Vector2(282, y + 3)
	slider.size = Vector2(311, 25)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value * 100
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(amount):
		label.text = "%.2f×" % (0.35 + amount / 100.0 * 1.65) if label_mode == "multiplier" else "%d%%" % int(amount)
		callback.call(amount / 100.0))
	parent.add_child(slider)

func _show_collection() -> void:
	current_view = "collection"
	_new_screen()
	_sync_world()
	_shade(screen)
	_label(screen, "YOUR LITTLE CORNER OF THE FAIR", Vector2(54, 34), Vector2(1170, 27), 16, GOLD)
	_label(screen, "A stand with a story.", Vector2(51, 78), Vector2(1172, 58), 43)
	var summary: Dictionary = profile.get_summary() if profile != null else {}
	_label(screen, "%d customers served   ·   %d campaigns completed   ·   %d best streak" % [int(summary.get("total_served", 0)), int(summary.get("campaign_wins", 0)), int(summary.get("best_streak", 0))], Vector2(56, 148), Vector2(1168, 30), 21, MINT)
	var cosmetics: Array = profile.get_cosmetics() if profile != null else []
	for i in range(cosmetics.size()):
		var item: Dictionary = cosmetics[i]
		var card = _panel(screen, Vector2(54 + i * 397, 220), Vector2(378, 290), PANEL)
		var swatch = _panel(card, Vector2(20, 20), Vector2(338, 55), item.get("accent", GOLD))
		_label(swatch, "GOLDEN HOUR", Vector2(14, 11), Vector2(310, 32), 21, INK)
		_label(card, str(item.name), Vector2(21, 95), Vector2(336, 37), 25)
		_text(card, str(item.description), Vector2(22, 143), Vector2(334, 50), 17, MUTED)
		var selected = bool(item.get("selected", false))
		var unlocked = bool(item.get("unlocked", false))
		if unlocked:
			var button = _button(card, "EQUIPPED" if selected else "USE THIS LOOK", Vector2(22, 226), Vector2(334, 43), _select_cosmetic.bind(str(item.id)), MINT if selected else GOLD)
			button.disabled = selected
		else:
			_text(card, str(item.get("requirement", "Keep serving to unlock")), Vector2(22, 220), Vector2(334, 50), 16, GOLD)
	_label(screen, "CAREER BADGES", Vector2(56, 548), Vector2(1160, 24), 15, GOLD)
	var badges: Array = profile.get_badges() if profile != null and profile.has_method("get_badges") else []
	for i in range(mini(5, badges.size())):
		var badge: Dictionary = badges[i]
		var card = _panel(screen, Vector2(54 + i * 239, 585), Vector2(220, 82), PANEL)
		_label(card, str(badge.name), Vector2(12, 12), Vector2(196, 23), 16, MINT if badge.get("unlocked", false) else MUTED)
		_text(card, "EARNED" if badge.get("unlocked", false) else str(badge.description), Vector2(12, 41), Vector2(196, 33), 11, GOLD if badge.get("unlocked", false) else MUTED)
	_button(screen, "BACK TO THE STAND", Vector2(831, 714), Vector2(395, 51), _show_title)
	_label(screen, "Every look is earned by playing. Your chosen palette never changes the rules.", Vector2(56, 725), Vector2(735, 29), 15, MUTED)

func _select_cosmetic(id: String) -> void:
	if profile == null or not profile.select_cosmetic(id): return
	profile.save_profile()
	_apply_cosmetic()
	_show_collection()

func _apply_cosmetic() -> void:
	if profile != null and is_instance_valid(world) and world.has_method("set_cosmetic"):
		world.set_cosmetic(profile.selected_cosmetic)

func _show_credits() -> void:
	var p = _modal(Vector2(760, 578))
	_label(p, "Made for the little moments.", Vector2(30, 27), Vector2(700, 54), 36)
	_label(p, "GOLDEN HOUR  /  VERSION " + VERSION, Vector2(33, 98), Vector2(694, 25), 16, GOLD)
	_text(p, "A hands-on mini-donut stand game.\n\nOriginal stand, donuts, characters, interface, animation, illustration and synthesized sound created for Golden Hour.\n\nBuilt with the Godot Engine, available under the MIT licence.\nFredoka typeface is provided under the SIL Open Font License.\n\nComplete engine, third-party and font licence notices are included in the LICENSES folder alongside the game.", Vector2(34, 153), Vector2(692, 288), 19, MUTED)
	_button(p, "BACK", Vector2(34, 486), Vector2(692, 52), _close_overlay)

func _quit_game() -> void:
	_save_run()
	if not test_mode: get_tree().quit()

func _apply_audio_settings() -> void:
	if not is_instance_valid(audio): return
	audio.set_muted(muted)
	audio.set_music_volume(music_volume if music_on else 0.0)
	if audio.has_method("set_sfx_volume"): audio.set_sfx_volume(sfx_volume)
	if audio.has_method("set_ambience_volume"): audio.set_ambience_volume(ambience_volume)

func _apply_effect_settings() -> void:
	world.set_reduced_motion(reduced_motion)
	if is_instance_valid(feedback): feedback.set_reduced_motion(reduced_motion)
	if is_instance_valid(dashboard): dashboard.reduced_motion = reduced_motion

func _modal(dimensions: Vector2) -> Panel:
	_close_overlay()
	_stop_hold()
	paused = current_view == "play"
	right_dragging = false
	overlay = Control.new()
	overlay.size = Vector2(1280, 800)
	ui.add_child(overlay)
	_shade(overlay)
	if is_instance_valid(feedback): feedback.reset()
	_sync_world()
	return _panel(overlay, (Vector2(1280, 800) - dimensions) * 0.5, dimensions, INK)

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
		overlay = null
	paused = false
	if is_instance_valid(world): _sync_world()

func _style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(13)
	style.set_border_width_all(1)
	style.border_color = Color("536663") if color == GOLD or color == MINT else Color("344e51")
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style

func _money(amount: float) -> String:
	return "$%d" % int(amount) if is_equal_approx(amount, roundf(amount)) else "$%.2f" % amount

func _bar_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	style.set_content_margin_all(0)
	return style

func _panel(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> Panel:
	var panel = Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color))
	parent.add_child(panel)
	return panel

func _label(parent: Node, value: String, at: Vector2, dimensions: Vector2, font_size: int = 20, color: Color = CREAM) -> Label:
	var label = Label.new()
	label.position = at
	label.size = dimensions
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _text(parent: Node, value: String, at: Vector2, dimensions: Vector2, font_size: int = 20, color: Color = CREAM) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.position = at
	label.size = dimensions
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, at: Vector2, dimensions: Vector2, callback: Callable, color: Color = GOLD) -> Button:
	var button = Button.new()
	button.position = at
	button.size = dimensions
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", INK if color == GOLD or color == MINT else CREAM)
	button.add_theme_color_override("font_hover_color", INK if color == GOLD or color == MINT else CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(color))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.12)))
	button.add_theme_stylebox_override("disabled", _style(Color("304746")))
	button.pressed.connect(func():
		audio.play_event("click")
		callback.call())
	parent.add_child(button)
	return button

func _shade(parent: Node) -> void:
	var shade = ColorRect.new()
	shade.size = Vector2(1280, 800)
	shade.color = Color(0.025, 0.065, 0.07, 0.72)
	parent.add_child(shade)

func _toast(value: String, color: Color = CREAM) -> void:
	if value.is_empty(): return
	for child in toast_layer.get_children():
		toast_layer.remove_child(child)
		child.queue_free()
	var panel = _panel(toast_layer, Vector2(394, 611), Vector2(492, 54), Color(0.04, 0.10, 0.11, 0.96))
	var label = _text(panel, value, Vector2(14, 7), Vector2(464, 40), 15, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween = panel.create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(panel, "modulate:a", 0, 0.2)
	tween.tween_callback(panel.queue_free)

func _save_run() -> void:
	if test_mode or practice or model.phase not in ["playing", "shop"]: return
	saved_run = {"model": model.to_save(), "held_tool": held_tool, "run_id": run_id, "best_streak": best_streak}
	if _write_json_atomic(SAVE_PATH, saved_run):
		_save_failed = false
		_run_load_notice = ""
		if not _legacy_migration_done:
			_legacy_migration_done = true
			_save_settings()
	elif not _save_failed:
		_save_failed = true
		_toast("Your shift could not be saved. Check free disk space before closing.", RED)

func _load_saved_run(paths: Array = []) -> void:
	saved_run.clear()
	_run_load_notice = ""
	if paths.is_empty():
		paths = [SAVE_PATH, SAVE_PATH + ".backup"]
		if not _legacy_migration_done: paths.append(LEGACY_SAVE_PATH)
	var failed_notice: String = ""
	for index in range(paths.size()):
		var path: String = str(paths[index])
		if not FileAccess.file_exists(path): continue
		var parser = JSON.new()
		var data: Variant = parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null
		if data is Dictionary and data.get("model") is Dictionary:
			var validator = Model.new()
			if validator.from_save(data.model):
				saved_run = data
				if index > 0 and not failed_notice.is_empty():
					_run_load_notice = "Your saved shift was restored from a backup or earlier save. The unreadable original has been kept."
				elif int(data.model.get("version", 0)) == 1:
					_run_load_notice = "Your earlier saved shift is ready to continue. Its original target and remaining time are preserved."
				return
			if failed_notice.is_empty():
				failed_notice = validator.last_save_error + " The original file has been kept."
		elif failed_notice.is_empty():
			failed_notice = "Your saved shift could not be read. The original file has been kept. You can open a new stand."
	_run_load_notice = failed_notice

func _save_settings() -> void:
	if test_mode: return
	_write_json_atomic(SETTINGS_PATH, {"muted": muted, "music_on": music_on, "reduced_motion": reduced_motion, "tutorial_seen": tutorial_seen, "sfx_volume": sfx_volume, "music_volume": music_volume, "ambience_volume": ambience_volume, "look_sensitivity": look_sensitivity, "invert_look": invert_look, "run_migrated": _legacy_migration_done})

func _load_settings() -> void:
	var data: Dictionary = {}
	for path in [SETTINGS_PATH, SETTINGS_PATH + ".backup", LEGACY_SETTINGS_PATH]:
		if not FileAccess.file_exists(path): continue
		var candidate = JSON.parse_string(FileAccess.get_file_as_string(path))
		if candidate is Dictionary:
			data = candidate
			break
	if data.is_empty(): return
	muted = bool(data.get("muted", false))
	music_on = bool(data.get("music_on", true))
	reduced_motion = bool(data.get("reduced_motion", false))
	tutorial_seen = bool(data.get("tutorial_seen", false))
	sfx_volume = _safe_setting(data, "sfx_volume", 0.8, 0.0, 1.0)
	music_volume = _safe_setting(data, "music_volume", 0.35, 0.0, 1.0)
	ambience_volume = _safe_setting(data, "ambience_volume", 0.5, 0.0, 1.0)
	look_sensitivity = _safe_setting(data, "look_sensitivity", 1.0, 0.35, 2.0)
	invert_look = bool(data.get("invert_look", false))
	_legacy_migration_done = bool(data.get("run_migrated", false))

func _safe_setting(data: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value = data.get(key, fallback)
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), low, high)

func _write_json_atomic(path: String, data: Dictionary) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary:
		if DirAccess.copy_absolute(path, path + ".backup") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func _copy_report() -> void:
	var report = {"game": "Golden Hour / Idea 2", "version": VERSION, "seed": model.seed_value, "platform": OS.get_name(), "phase": model.phase, "shift": model.shift_index + 1, "sales": model.sales, "served": model.served, "missed": model.missed, "mistakes": model.mistakes, "upgrades": model.owned, "fps": Engine.get_frames_per_second(), "feedback": "Did scooping and handing over feel good? What was unclear? Too busy or too easy?"}
	DisplayServer.clipboard_set(JSON.stringify(report, "  "))
	_toast("Playtest report copied.", MINT)

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var path = ProjectSettings.globalize_path("res://playtest-reports/stand-%s.png" % capture_view)
	get_viewport().get_texture().get_image().save_png(path)
	print("STAND_CAPTURE " + path)
	get_tree().quit(0)
