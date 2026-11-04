extends Node
## Idea 2: a first-person workbench. Physical props perform the actions; HUD reports state.

const Model = preload("res://scripts/stand_model.gd")
const World = preload("res://scripts/stand_world.gd")
const Audio = preload("res://scripts/stand_audio.gd")
const VERSION = "0.3.0-playtest"
const SAVE_PATH = "user://stand_run.json"
const SETTINGS_PATH = "user://stand_settings.json"
const INK = Color("152c30")
const CREAM = Color("fff0d2")
const GOLD = Color("ffc768")
const MINT = Color("9fe4bc")
const RED = Color("f39172")
const MUTED = Color("bac4b9")
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

func _ready() -> void:
	DisplayServer.window_set_title("Golden Hour — Behind the Counter (Idea 2)")
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke" or arg == "--test-mode": test_mode = true
		if arg.begins_with("--capture-view="):
			capture_view = arg.trim_prefix("--capture-view=")
			test_mode = true
	_load_settings()
	_load_saved_run()
	world = World.new()
	add_child(world)
	audio = Audio.new()
	add_child(audio)
	audio.set_muted(muted)
	audio.set_music_volume(0.28 if music_on else 0.0)
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme = Theme.new()
	theme.default_font = load("res://assets/fonts/Fredoka-Medium.ttf")
	theme.default_font_size = 20
	ui.theme = theme
	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast_layer)
	_resize()
	get_viewport().size_changed.connect(_resize)
	_apply_effect_settings()
	_show_title()
	if not capture_view.is_empty() or OS.get_cmdline_user_args().has("--smoke"):
		model.new_run(4182)
		model.start_shift()
		_show_play()
		if capture_view == "title": _show_title()
		elif capture_view == "help": _show_help(false)
		elif capture_view == "settings": _show_settings()
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
		model.tick(step)
		_process_events()
		_sync_world()
		_refresh_hud()
		if not right_dragging:
			hover_station = world.pick_station(get_viewport().get_mouse_position())
			world.set_hover_station(hover_station)
		autosave_time += delta
		if autosave_time >= 2.0:
			autosave_time = 0
			_save_run()
		if model.phase == "shop":
			_save_run()
			_show_shop()
		elif model.phase in ["won", "lost"]: _finish_run()
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
		world.look_offset(event.relative)

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
				audio.play_served(amount, model.streak)
				world.burst_reward(amount, mini(3, model.streak / 2))
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
	_toast(str(result.get("message", "")), MINT if bool(result.get("ok", false)) else RED)
	_process_events()
	_sync_world()
	_refresh_hud()

func _start_hold(station: String) -> void:
	if current_view != "play" or paused or station not in ["repair", "refill"]: return
	hold_station = station
	world.animate_action(station)

func _stop_hold() -> void:
	hold_station = ""

func _handle_hold_result(result: Dictionary) -> void:
	var complete = (hold_station == "repair" and not model.jammed) or (hold_station == "refill" and model.refill_progress <= 0 and bool(result.get("ok", false)))
	if complete:
		_stop_hold()
		if not str(result.get("message", "")).is_empty(): _toast(str(result.message), MINT)

func _process_events() -> void:
	for event in model.events:
		var kind = str(event.get("type", ""))
		if kind == "customer_arrived": audio.play_customer()
		elif kind in ["jam", "overheat", "walkout"]:
			audio.play_warning(kind)
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
		"shift_duration": model.shift_duration, "supply_capacity": model.supply_capacity}

func _sync_world() -> void:
	world.sync_state(_view_state())

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

func _show_title() -> void:
	current_view = "title"
	_new_screen()
	world.reset_look()
	var p = _panel(screen, Vector2(38, 92), Vector2(456, 620), Color(0.055, 0.12, 0.13, 0.97))
	_label(p, "GOLDEN HOUR", Vector2(30, 30), Vector2(396, 54), 43, GOLD)
	_label(p, "YOUR SHIFT.", Vector2(28, 105), Vector2(402, 70), 53)
	_label(p, "YOUR STAND.", Vector2(28, 171), Vector2(402, 70), 53)
	_text(p, "A first-person donut stand.\nScoop. Sugar. Serve. Keep it running.", Vector2(32, 270), Vector2(392, 72), 22)
	_button(p, "STEP BEHIND THE COUNTER  >", Vector2(30, 369), Vector2(396, 58), _request_new_run)
	if not saved_run.is_empty():
		_button(p, "CONTINUE SHIFT", Vector2(30, 440), Vector2(396, 46), _continue_run, Color("375550"))
	else:
		_label(p, "3 rushes  /  a pair of hands  /  one fryer", Vector2(30, 447), Vector2(396, 32), 16, MUTED)
	_button(p, "How to play", Vector2(30, 510), Vector2(190, 46), func(): _show_help(false), Color("375550"))
	_button(p, "Settings", Vector2(236, 510), Vector2(190, 46), _show_settings, Color("375550"))
	_label(p, "IDEA 2 PLAYTEST 0.3", Vector2(30, 582), Vector2(396, 22), 14, MUTED)

func _request_new_run() -> void:
	if saved_run.is_empty():
		_start_new_run()
		return
	var p = _modal(Vector2(530, 280))
	_label(p, "Start a fresh shift?", Vector2(30, 25), Vector2(470, 50), 34)
	_text(p, "This replaces your saved Idea 2 run.", Vector2(30, 93), Vector2(470, 60), 23)
	_button(p, "Keep my run", Vector2(30, 197), Vector2(220, 52), _close_overlay, Color("375550"))
	_button(p, "Start fresh", Vector2(270, 197), Vector2(230, 52), _start_new_run)

func _start_new_run() -> void:
	model.new_run()
	held_tool = "none"
	_close_overlay()
	if not tutorial_seen: _show_help(true)
	else: _begin_shift()

func _begin_shift() -> void:
	model.start_shift()
	held_tool = "none"
	audio.start_music()
	_show_play()
	_sync_world()
	_save_run()

func _continue_run() -> void:
	if not model.from_save(saved_run.get("model", {})):
		_toast("Save could not load. Start a fresh shift.", RED)
		return
	held_tool = str(saved_run.get("held_tool", "none"))
	if held_tool not in ["none", "scoop", "package"]: held_tool = "none"
	audio.start_music()
	if model.phase == "shop": _show_shop()
	else: _show_play()
	_sync_world()

func _show_play() -> void:
	current_view = "play"
	_new_screen()
	var summary = _panel(screen, Vector2(20, 18), Vector2(338, 110), Color(0.06, 0.13, 0.14, 0.94))
	_label(summary, "GOLDEN HOUR", Vector2(16, 10), Vector2(270, 27), 22, GOLD)
	hud.progress = _label(summary, "", Vector2(16, 44), Vector2(230, 35), 27)
	hud.clock = _label(summary, "", Vector2(245, 44), Vector2(90, 35), 27)
	hud.shift = _label(summary, "", Vector2(16, 84), Vector2(290, 23), 14, MUTED)
	_button(screen, "II", Vector2(373, 20), Vector2(48, 43), _show_pause, Color("375550"))
	_button(screen, "?", Vector2(373, 76), Vector2(48, 43), func(): _show_help(false), Color("375550"))
	hud.orders = []
	for i in range(3):
		var card = _panel(screen, Vector2(442 + i * 274, 18), Vector2(258, 110), Color(0.08, 0.17, 0.18, 0.94))
		var heading = _label(card, "", Vector2(14, 9), Vector2(228, 22), 14, GOLD if i == 0 else MUTED)
		var order = _label(card, "", Vector2(14, 34), Vector2(228, 29), 21)
		var flavor = _label(card, "", Vector2(14, 64), Vector2(228, 22), 16, MUTED)
		var patience = ProgressBar.new()
		patience.position = Vector2(14, 95)
		patience.size = Vector2(230, 5)
		patience.show_percentage = false
		patience.add_theme_font_size_override("font_size", 1)
		patience.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patience.add_theme_stylebox_override("background", _bar_style(Color("304747")))
		patience.add_theme_stylebox_override("fill", _bar_style(MINT))
		card.add_child(patience)
		patience.set_deferred("size", Vector2(230, 5))
		hud.orders.append({"card": card, "heading": heading, "order": order, "flavor": flavor, "patience": patience})
	var machine = _panel(screen, Vector2(20, 650), Vector2(286, 130), Color(0.06, 0.13, 0.14, 0.94))
	hud.machine = _label(machine, "", Vector2(14, 10), Vector2(258, 29), 21, GOLD)
	hud.stock = _label(machine, "", Vector2(14, 43), Vector2(258, 25), 17)
	hud.condition = _text(machine, "", Vector2(14, 78), Vector2(258, 42), 15, MUTED)
	var hand = _panel(screen, Vector2(974, 650), Vector2(286, 130), Color(0.06, 0.13, 0.14, 0.94))
	_label(hand, "ON YOUR COUNTER", Vector2(14, 10), Vector2(258, 22), 14, GOLD)
	hud.package = _label(hand, "", Vector2(14, 38), Vector2(258, 30), 22)
	hud.coating = _label(hand, "", Vector2(14, 74), Vector2(258, 22), 16)
	hud.tool = _label(hand, "", Vector2(14, 104), Vector2(258, 21), 14, MUTED)
	var prompt = _panel(screen, Vector2(326, 700), Vector2(628, 80), Color(0.04, 0.10, 0.11, 0.93))
	hud.prompt = _label(prompt, "", Vector2(15, 8), Vector2(598, 29), 23, GOLD)
	hud.hint = _text(prompt, "", Vector2(15, 43), Vector2(598, 30), 15)
	var repair_bar = ProgressBar.new()
	repair_bar.position = Vector2(470, 662)
	repair_bar.size = Vector2(340, 18)
	repair_bar.show_percentage = true
	repair_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	repair_bar.add_theme_stylebox_override("fill", _style(GOLD))
	screen.add_child(repair_bar)
	hud.hold = repair_bar
	hud.warning = _label(screen, "", Vector2(340, 142), Vector2(610, 33), 21, RED)
	hud.warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.warning.add_theme_color_override("font_outline_color", INK)
	hud.warning.add_theme_constant_override("outline_size", 5)
	_refresh_hud()

func _refresh_hud() -> void:
	if current_view != "play" or hud.is_empty(): return
	hud.progress.text = "%s / $%d" % [_money(model.sales), model.target]
	hud.clock.text = "%d:%02d" % [int(model.time_left) / 60, int(model.time_left) % 60]
	hud.clock.add_theme_color_override("font_color", RED if model.time_left < 20 else CREAM)
	hud.shift.text = "SHIFT %d / 3   ·   %d served   ·   %d walked away" % [model.shift_index + 1, model.served, model.missed]
	for i in range(3):
		var card: Dictionary = hud.orders[i]
		var has_order: bool = i < model.orders.size()
		card.order.text = "Waiting for customers" if i == 0 else ""
		card.heading.text = "NEXT IN LINE" if i == 0 else "QUEUED"
		card.flavor.text = ""
		card.patience.visible = has_order
		card.card.modulate.a = 1.0 if has_order else 0.45
		if has_order:
			var order: Dictionary = model.orders[i]
			card.order.text = "%s  ·  %d DONUTS" % [str(order.get("package", "bag")).to_upper(), 6 if str(order.get("package", "bag")) == "bag" else 12]
			card.flavor.text = "%s   /   %ds patience" % [str(order.get("flavor", "cinnamon")).capitalize(), int(ceil(float(order.get("patience", 0))))]
			card.patience.value = 100.0 * float(order.get("patience", 0)) / maxf(1, float(order.get("max_patience", 1)))
			card.patience.add_theme_stylebox_override("fill", _bar_style(RED if card.patience.value < 30 else MINT))
	hud.machine.text = "%.0f°C   ·   HEAT %d / 4" % [model.temperature, model.heat_setting]
	hud.stock.text = "%d fresh   /   %d batter" % [model.supply, model.batter]
	hud.condition.text = model.production_status()
	hud.package.text = "No container" if model.package_type.is_empty() else "%s   %d / %d" % [model.package_type.capitalize(), model.package_count, model.package_capacity()]
	hud.coating.text = "Choose a bag or bucket" if model.package_type.is_empty() else ("Uncoated" if model.package_flavor.is_empty() else model.package_flavor.capitalize())
	hud.tool.text = "SCOOP IN HAND  ·  %d donuts" % model.scoop_count if held_tool == "scoop" else ("ORDER IN HAND  ·  ready to give" if held_tool == "package" else "HANDS FREE")
	hud.prompt.text = _context_prompt()
	hud.hint.text = _next_hint()
	hud.hold.visible = not hold_station.is_empty()
	hud.hold.value = (model.jam_progress if hold_station == "repair" else model.refill_progress) * 100
	if model.jammed: hud.warning.text = "MACHINE JAMMED  ·  hold the red repair lever"
	elif model.overheated: hud.warning.text = "TOO HOT  ·  turn the heat down to cool the oil"
	elif model.batter <= 0: hud.warning.text = "OUT OF BATTER  ·  hold the refill hopper"
	else: hud.warning.text = ""

func _context_prompt() -> String:
	if not hold_station.is_empty(): return "HOLDING: " + ("CLEAR THE JAM" if hold_station == "repair" else "REFILL BATTER")
	if hover_station == "package":
		if held_tool == "scoop" and model.scoop_count > 0: return "CLICK  ·  Pour scoop into your order"
		if held_tool == "package": return "CLICK  ·  Set your order down"
		if not model.package_flavor.is_empty(): return "CLICK  ·  Lift the finished order"
	if not hover_station.is_empty(): return "CLICK  ·  " + str(STATION_NAMES.get(hover_station, hover_station))
	return "Point at something on your counter"

func _next_hint() -> String:
	if held_tool == "package": return "Click the customer to hand over this order."
	if model.package_type.is_empty(): return "Read the first ticket, then take a bag or a bucket."
	if held_tool == "scoop" and model.scoop_count > 0: return "Click your container to pour in the scoop."
	if model.package_count < model.package_capacity():
		return "Click the fresh donut tray to load your scoop." if held_tool == "scoop" else "Pick up the scoop, then click the fresh donut tray."
	if model.package_flavor.is_empty(): return "Click cinnamon or powdered sugar to coat the full order."
	return "Click your finished order to lift it, then click the customer."

func _show_shop() -> void:
	current_view = "shop"
	_new_screen()
	_shade(screen)
	_label(screen, "A BREATHER BETWEEN RUSHES", Vector2(70, 65), Vector2(1120, 32), 21, GOLD)
	_label(screen, "Make the next shift smoother.", Vector2(68, 110), Vector2(1140, 70), 46)
	_label(screen, "%s earned  ·  %d served  ·  %d upgrade coins" % [_money(model.sales), model.served, model.credits], Vector2(72, 195), Vector2(1100, 40), 25, MINT)
	var offers: Array = model.get_shop_offers()
	for i in range(mini(offers.size(), 3)):
		var offer: Dictionary = offers[i]
		var card = _panel(screen, Vector2(70 + i * 385, 285), Vector2(360, 280), Color("223f40"))
		_text(card, str(offer.get("name", "Upgrade")), Vector2(22, 24), Vector2(316, 70), 30)
		_text(card, str(offer.get("description", "")), Vector2(22, 107), Vector2(316, 95), 20, MUTED)
		var button = _button(card, "INSTALL  ·  %d COINS" % int(offer.get("cost", 0)), Vector2(22, 216), Vector2(316, 46), _buy_upgrade.bind(str(offer.id)))
		button.disabled = model.credits < int(offer.get("cost", 0))
	_button(screen, "START NEXT SHIFT  >", Vector2(820, 650), Vector2(390, 58), _begin_shift, MINT)
	_button(screen, "Save & return to title", Vector2(70, 650), Vector2(350, 58), func():
		_save_run()
		_show_title(), Color("375550"))
	_label(screen, "Keep serving by hand. Upgrades help you manage the bottlenecks.", Vector2(72, 744), Vector2(1110, 28), 18, MUTED)

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
	if not test_mode:
		saved_run.clear()
		if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(SAVE_PATH)
	var won: bool = model.phase == "won"
	audio.play_event("win" if won else "failure")
	_shade(screen)
	var p = _panel(screen, Vector2(285, 145), Vector2(710, 510), INK)
	_label(p, "THAT'S A SHIFT TO REMEMBER." if won else "TIME TO RESET THE COUNTER.", Vector2(32, 28), Vector2(646, 28), 18, GOLD)
	_label(p, "Rush handled." if won else "Closing time.", Vector2(30, 85), Vector2(650, 70), 54)
	_text(p, "Three shifts, countless little donuts. You kept the stand moving." if won else "The queue got ahead of the stand. Try a different rhythm: serve, restock, and use quiet moments to fix the machine.", Vector2(34, 177), Vector2(642, 100), 24)
	_label(p, "SHIFT %d / 3   ·   %s / $%d   ·   %d served" % [model.shift_index + 1, _money(model.sales), model.target, model.served], Vector2(34, 292), Vector2(642, 37), 24, GOLD)
	_button(p, "TRY ANOTHER RUN", Vector2(34, 361), Vector2(310, 54), _start_new_run)
	_button(p, "Back to the stand", Vector2(366, 361), Vector2(310, 54), _show_title, Color("375550"))
	_button(p, "Copy playtest report", Vector2(34, 437), Vector2(642, 43), _copy_report, Color("375550"))

func _show_pause() -> void:
	if current_view != "play": return
	_save_run()
	var p = _modal(Vector2(510, 355))
	_label(p, "Hands off for a moment.", Vector2(28, 26), Vector2(454, 54), 32)
	_button(p, "BACK TO THE COUNTER", Vector2(28, 112), Vector2(454, 54), _close_overlay)
	_button(p, "Settings", Vector2(28, 186), Vector2(216, 46), _show_settings, Color("375550"))
	_button(p, "How to play", Vector2(266, 186), Vector2(216, 46), func(): _show_help(false), Color("375550"))
	_button(p, "Save & return to title", Vector2(28, 266), Vector2(454, 48), func():
		_save_run()
		_show_title(), Color("375550"))

func _show_help(start_after: bool) -> void:
	var p = _modal(Vector2(900, 680))
	_label(p, "You're behind the counter now.", Vector2(32, 24), Vector2(836, 54), 36)
	_label(p, "CLICK THE REAL OBJECTS IN FRONT OF YOU", Vector2(34, 86), Vector2(832, 28), 18, GOLD)
	var steps = [
		["1  READ THE FIRST TICKET", "Take a bag for 6 donuts or a bucket for 12. Serve the customer at the front of the queue."],
		["2  SCOOP, THEN POUR", "Pick up the scoop. Click the fresh donut tray, then click your container to pour. Repeat until full."],
		["3  COAT, LIFT, HAND OVER", "Click the ordered sugar. Click the finished package to lift it, then click the customer to give it to them."],
		["4  KEEP THE FRYER RUNNING", "Hold the repair lever when it jams. Lower the heat if it gets too hot. Hold the hopper to refill batter."]
	]
	for i in range(4):
		_label(p, steps[i][0], Vector2(34, 140 + i * 91), Vector2(832, 28), 20, GOLD)
		_text(p, steps[i][1], Vector2(34, 173 + i * 91), Vector2(832, 52), 19)
	_text(p, "Customers lose patience. Wrong orders cost time. Empty mistakes into the scrap bin.\nRight-drag to look around; Home recentres. Keyboard shortcuts are optional.", Vector2(34, 515), Vector2(832, 62), 17, MUTED)
	_button(p, "LET'S OPEN  >" if start_after else "GOT IT", Vector2(34, 606), Vector2(832, 48), func():
		_close_overlay()
		if start_after:
			tutorial_seen = true
			_save_settings()
			_begin_shift())

func _show_settings() -> void:
	var p = _modal(Vector2(560, 510))
	_label(p, "Your side of the counter.", Vector2(30, 25), Vector2(500, 52), 31)
	_button(p, "Sound: " + ("OFF" if muted else "ON"), Vector2(30, 111), Vector2(500, 50), func():
		muted = not muted
		audio.set_muted(muted)
		_save_settings()
		_show_settings(), Color("375550"))
	_button(p, "Music: " + ("ON" if music_on else "OFF"), Vector2(30, 177), Vector2(500, 50), func():
		music_on = not music_on
		audio.set_music_volume(0.28 if music_on else 0)
		_save_settings()
		_show_settings(), Color("375550"))
	_button(p, "Motion: " + ("REDUCED" if reduced_motion else "FULL"), Vector2(30, 243), Vector2(500, 50), func():
		reduced_motion = not reduced_motion
		_apply_effect_settings()
		_save_settings()
		_show_settings(), Color("375550"))
	_text(p, "Optional keys: B bag / V bucket / S scoop / F scoop tray\nSpace pour or lift / C cinnamon / P powdered / E serve\nHold R repair / hold T refill / - + heat / X empty order", Vector2(30, 320), Vector2(500, 84), 17, MUTED)
	_button(p, "DONE", Vector2(30, 434), Vector2(500, 48), _close_overlay)

func _apply_effect_settings() -> void:
	world.set_reduced_motion(reduced_motion)

func _modal(dimensions: Vector2) -> Panel:
	_close_overlay()
	_stop_hold()
	paused = current_view == "play"
	right_dragging = false
	overlay = Control.new()
	overlay.size = Vector2(1280, 800)
	ui.add_child(overlay)
	_shade(overlay)
	return _panel(overlay, (Vector2(1280, 800) - dimensions) * 0.5, dimensions, INK)

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
		overlay = null
	paused = false

func _style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
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
	var panel = _panel(toast_layer, Vector2(326, 615), Vector2(628, 66), Color(0.04, 0.10, 0.11, 0.96))
	var label = _text(panel, value, Vector2(14, 8), Vector2(600, 50), 18, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween = panel.create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(panel, "modulate:a", 0, 0.2)
	tween.tween_callback(panel.queue_free)

func _save_run() -> void:
	if test_mode or model.phase not in ["playing", "shop"]: return
	saved_run = {"model": model.to_save(), "held_tool": held_tool}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(saved_run))

func _load_saved_run() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary and data.get("model") is Dictionary: saved_run = data

func _save_settings() -> void:
	if test_mode: return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"muted": muted, "music_on": music_on, "reduced_motion": reduced_motion, "tutorial_seen": tutorial_seen}))

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not data is Dictionary: return
	muted = bool(data.get("muted", false))
	music_on = bool(data.get("music_on", true))
	reduced_motion = bool(data.get("reduced_motion", false))
	tutorial_seen = bool(data.get("tutorial_seen", false))

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
