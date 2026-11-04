extends Node

const Model = preload("res://scripts/run_model.gd")
const World = preload("res://scripts/donut_world.gd")
const Audio = preload("res://scripts/game_audio.gd")
const UpgradeData = preload("res://scripts/upgrades.gd")
const Feedback = preload("res://scripts/score_feedback.gd")
const ScoreEffects = preload("res://scripts/score_effects.gd")
const VERSION = "0.2.0-playtest"
const INK = Color("172c32")
const CREAM = Color("fff1d5")
const GOLD = Color("ffc66d")
const ORANGE = Color("d97248")
const MINT = Color("a5dec2")
const MUTED = Color("a6b6b3")
const SAVE_PATH = "user://run.json"
const SETTINGS_PATH = "user://settings.json"
const RECIPES = ["cinnamon", "powdered", "cocoa"]
const RECIPE_NAMES = ["Cinnamon", "Powdered", "Cocoa"]
const RECIPE_COLORS = [Color("e5ad68"), Color("fff5dd"), Color("b87860")]

var model = Model.new()
var world
var audio
var feedback = Feedback.new()
var score_fx
var ui: Control
var screen: Control
var overlay: Control
var toasts: Control
var current_view = "title"
var paused = false
var muted = false
var music_on = true
var tutorial_seen = false
var reduced_motion = false
var saved_run: Dictionary = {}
var stats = {"runs": 0, "wins": 0, "best_shift": 0, "best_sales": 0.0}
var hud: Dictionary = {}
var tray_labels: Array = []
var route_buttons: Array = []
var sell_buttons: Array = []
var recipe_buttons: Array = []
var autosave_time = 0.0
var last_phase = ""
var total_time = 0.0
var toast_serial = 0
var screenshot_mode = false
var smoke_mode = false
var capture_done = false
var capture_view = "gameplay"
var showcase_started = false

func _ready() -> void:
	_load_settings()
	_load_saved_run()
	world = World.new()
	add_child(world)
	audio = Audio.new()
	add_child(audio)
	audio.set_muted(muted)
	audio.set_music_volume(0.35 if music_on else 0.0)
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme = Theme.new()
	theme.default_font = load("res://assets/fonts/Fredoka-Medium.ttf")
	theme.default_font_size = 20
	ui.theme = theme
	_resize_ui()
	get_viewport().size_changed.connect(_resize_ui)
	toasts = Control.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toasts)
	score_fx = ScoreEffects.new()
	ui.add_child(score_fx)
	_apply_effect_settings()
	_show_title()
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke": smoke_mode = true
		if arg == "--capture": screenshot_mode = true
		if arg.begins_with("--capture-view="):
			screenshot_mode = true
			capture_view = arg.trim_prefix("--capture-view=")
	if smoke_mode or screenshot_mode:
		reduced_motion = capture_view == "reduced"
		_apply_effect_settings()
		model.new_run(4182)
		model.start_shift()
		_show_play()
		model.queue_batch("cinnamon", 0)
		model.cooldown = 0.0
		model.queue_batch("powdered", 1)
		if capture_view == "title": _show_title()
		elif capture_view == "help": _show_help(false)
		elif capture_view == "settings": _show_settings()
		elif capture_view == "shop":
			model.sales = model.target + 150
			model.finish_shift()
			_show_shop()
		elif capture_view == "win":
			model.phase = "won"
			model.shift_index = 5
			model.target = Model.TARGETS[5]
			model.sales = model.target + 228
			_finish_run()
	print("GOLDEN_HOUR_READY version=" + VERSION)

func _resize_ui() -> void:
	var view_size = get_viewport().get_visible_rect().size
	var factor = minf(view_size.x / 1280.0, view_size.y / 800.0)
	ui.scale = Vector2(factor, factor)
	ui.position = (view_size - Vector2(1280, 800) * factor) * 0.5
	ui.size = Vector2(1280, 800)

func _process(delta: float) -> void:
	total_time += delta
	if current_view == "play" and not paused:
		model.tick(minf(delta, 0.1))
		_process_events()
		world.sync_state(model.active, model.trays, model.selected_tray, model.owned)
		_refresh_hud()
		autosave_time += delta
		if autosave_time > 2.0:
			autosave_time = 0.0
			_save_run()
		if model.phase == "shop":
			_save_run()
			_show_shop()
		elif model.phase == "won" or model.phase == "lost":
			_finish_run()
	if screenshot_mode and capture_view in ["jackpot", "reduced"] and total_time > 1.3 and not showcase_started:
		showcase_started = true
		model.owned = {"sugar_dust": 3, "matching_bonus": 3, "tray_liner": 3, "cinnamon_king": 3}
		model.tick(12.0)
		world.sync_state(model.active, model.trays, model.selected_tray, model.owned)
		_sell(0)
	if screenshot_mode and capture_view == "stress" and total_time > 1.3 and not showcase_started:
		showcase_started = true
		var receipt = {"amount": 12345.67, "full": true, "combo": "Perfect six + Rush x6 + Last call + Echo! + Golden", "multiplier": 9.6}
		var reward = feedback.describe_sale(receipt, 1.0, true)
		for index in range(3):
			var origin: Vector2 = ui.get_global_transform().affine_inverse() * world.get_tray_screen_position(index)
			score_fx.celebrate(reward, origin)
			world.burst_sale(index, 12345.67, 3)
	if screenshot_mode and total_time > (10.0 if capture_view == "gameplay" else 2.0) and not capture_done:
		capture_done = true
		_capture_frame()
	if smoke_mode and total_time > 12.0:
		print("SMOKE_PASS active=%d trays=%s phase=%s" % [model.active.size(), str(model.trays.map(func(t): return t.size())), model.phase])
		get_tree().quit(0)

func _capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var path = ProjectSettings.globalize_path("res://playtest-reports/%s.png" % capture_view)
	img.save_png(path)
	print("CAPTURE_SAVED " + path)
	if screenshot_mode: get_tree().quit(0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var mode = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_M:
			_toggle_mute()
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(overlay): _close_overlay()
			elif current_view == "play": _show_pause()
			return
		if current_view != "play" or paused: return
		match event.keycode:
			KEY_1: _select_tray(0)
			KEY_2: _select_tray(1)
			KEY_3: _select_tray(2)
			KEY_A: _select_recipe(0)
			KEY_S: _select_recipe(1)
			KEY_D: _select_recipe(2)
			KEY_Q: _sell(0)
			KEY_W: _sell(1)
			KEY_E: _sell(2)
			KEY_SPACE: _drop_batch()
			KEY_H: _show_help(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and current_view == "play" and not paused and not smoke_mode and not screenshot_mode:
		_save_run()
		_show_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_run()

func _new_screen() -> Control:
	_close_overlay()
	if is_instance_valid(score_fx): score_fx.reset()
	for toast in toasts.get_children():
		toasts.remove_child(toast)
		toast.queue_free()
	if is_instance_valid(screen):
		ui.remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.size = Vector2(1280, 800)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen)
	if is_instance_valid(score_fx): ui.move_child(score_fx, ui.get_child_count() - 1)
	ui.move_child(toasts, ui.get_child_count() - 1)
	return screen

func _box_style(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _panel(parent: Node, pos: Vector2, dimensions: Vector2, color: Color = INK, radius: int = 18) -> Panel:
	var p = Panel.new()
	p.position = pos
	p.size = dimensions
	p.add_theme_stylebox_override("panel", _box_style(color, radius))
	parent.add_child(p)
	return p

func _label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int = 20, color: Color = CREAM) -> Label:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _paragraph(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int = 20, color: Color = CREAM) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text = text
	parent.add_child(label)
	label.size = dimensions
	return label

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, action: Callable, color: Color = GOLD, text_color: Color = INK) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = dimensions
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color)
	b.add_theme_color_override("font_pressed_color", text_color)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_stylebox_override("normal", _box_style(color, 12))
	b.add_theme_stylebox_override("hover", _box_style(color.lightened(0.12), 12, CREAM, 2))
	b.add_theme_stylebox_override("pressed", _box_style(color.darkened(0.12), 12))
	b.add_theme_stylebox_override("disabled", _box_style(Color("31474a"), 12))
	b.pressed.connect(func():
		audio.play_event("click")
		action.call())
	parent.add_child(b)
	return b

func _shade(parent: Node, alpha: float = 0.65) -> void:
	var shade = ColorRect.new()
	shade.size = Vector2(1280, 800)
	shade.color = Color(0.025, 0.06, 0.065, alpha)
	parent.add_child(shade)

func _show_title() -> void:
	current_view = "title"
	_new_screen()
	world.set_title_view(true)
	var p = _panel(screen, Vector2(46, 100), Vector2(454, 630), Color(0.065, 0.13, 0.15, 0.94), 26)
	_label(p, "A LITTLE STAND. A BIG DREAM.", Vector2(30, 25), Vector2(394, 28), 16, GOLD)
	_label(p, "GOLDEN\nHOUR", Vector2(26, 53), Vector2(410, 176), 76, CREAM)
	_label(p, "MINI DONUT CLUB", Vector2(32, 235), Vector2(390, 32), 24, GOLD)
	_paragraph(p, "Build a beautiful little money machine.\nFry six. Find a combo. Beat the rush.", Vector2(32, 290), Vector2(388, 76), 21, CREAM)
	_button(p, "OPEN THE STAND  >", Vector2(30, 386), Vector2(394, 58), _request_new_run)
	if not saved_run.is_empty():
		_button(p, "CONTINUE YOUR RUN", Vector2(30, 454), Vector2(394, 50), _continue_run, Color("385350"), CREAM)
	else:
		_label(p, "6 shifts  ·  20 upgrades  ·  one tiny fryer", Vector2(30, 453), Vector2(394, 40), 17, MUTED)
	_button(p, "How to play", Vector2(30, 522), Vector2(190, 44), func(): _show_help(false), Color("2d4548"), CREAM)
	_button(p, "Settings", Vector2(232, 522), Vector2(192, 44), _show_settings, Color("2d4548"), CREAM)
	_label(p, "PLAYTEST 0.2  /  MAKE IT GOLDEN", Vector2(30, 584), Vector2(394, 24), 13, MUTED)
	_label(screen, "Headphones on. Fresh donuts ahead.", Vector2(800, 735), Vector2(440, 28), 18, CREAM)

func _request_new_run() -> void:
	audio.start_music()
	if saved_run.is_empty():
		_start_new_run()
		return
	var p = _open_modal(Vector2(520, 284))
	_label(p, "A fresh start?", Vector2(30, 20), Vector2(460, 50), 34)
	_paragraph(p, "Starting a new run replaces your saved run. Your playtest records stay.", Vector2(30, 88), Vector2(460, 80), 22)
	_button(p, "Keep my run", Vector2(30, 203), Vector2(218, 52), _close_overlay, Color("385350"), CREAM)
	_button(p, "Start fresh", Vector2(265, 203), Vector2(225, 52), _start_new_run)

func _start_new_run() -> void:
	model.new_run()
	stats.runs = int(stats.runs) + 1
	_save_settings()
	_close_overlay()
	if not tutorial_seen:
		_show_help(true)
	else:
		_begin_shift()

func _begin_shift() -> void:
	_close_overlay()
	model.start_shift()
	audio.start_music()
	_show_play()
	_save_run()
	_toast("SHIFT %d  ·  Make $%d before closing" % [model.shift_index + 1, model.target], GOLD)

func _continue_run() -> void:
	if not model.from_save(saved_run):
		_toast("That save could not be loaded. Start a fresh run.", ORANGE)
		return
	audio.start_music()
	if model.phase == "shop": _show_shop()
	elif model.phase == "playing": _show_play()
	else: _begin_shift()

func _show_play() -> void:
	current_view = "play"
	feedback.reset()
	paused = false
	_new_screen()
	world.set_title_view(false)
	var top = _panel(screen, Vector2(20, 16), Vector2(1240, 94), Color(0.07, 0.14, 0.16, 0.96))
	_label(top, "GOLDEN HOUR", Vector2(20, 13), Vector2(220, 30), 24, GOLD)
	hud.shift = _label(top, "", Vector2(20, 48), Vector2(230, 26), 17, MUTED)
	hud.sales = _label(top, "", Vector2(270, 8), Vector2(360, 44), 32)
	var bar = ProgressBar.new()
	bar.position = Vector2(270, 61)
	bar.size = Vector2(370, 11)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box_style(Color("304448"), 6))
	bar.add_theme_stylebox_override("fill", _box_style(GOLD, 6))
	top.add_child(bar)
	hud.progress = bar
	hud.time = _label(top, "", Vector2(680, 9), Vector2(160, 42), 32)
	_label(top, "UNTIL CLOSING", Vector2(680, 53), Vector2(170, 25), 13, MUTED)
	hud.batter = _label(top, "", Vector2(860, 12), Vector2(160, 36), 26, CREAM)
	_label(top, "BATTER LEFT", Vector2(860, 53), Vector2(160, 25), 13, MUTED)
	_button(top, "II", Vector2(1148, 22), Vector2(64, 50), _show_pause, Color("385350"), CREAM)
	_button(top, "?", Vector2(1072, 22), Vector2(64, 50), func(): _show_help(false), Color("385350"), CREAM)
	var hint_panel = _panel(screen, Vector2(24, 122), Vector2(990, 42), Color(0.06, 0.12, 0.14, 0.88), 12)
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.hint = _label(hint_panel, "", Vector2(12, 4), Vector2(966, 34), 19, CREAM)
	hud.close = _button(screen, "Close shift  >", Vector2(1030, 125), Vector2(220, 46), func():
		model.finish_shift()
		_process_events(), MINT)
	hud.close.visible = false
	var bottom = _panel(screen, Vector2(20, 602), Vector2(1240, 179), Color(0.07, 0.14, 0.16, 0.97), 20)
	tray_labels.clear()
	route_buttons.clear()
	sell_buttons.clear()
	for i in range(3):
		var x = 15 + i * 240
		var card = _panel(bottom, Vector2(x, 12), Vector2(228, 154), Color("243d40"), 14)
		var route = _button(card, "TRAY %d  [ %d ]" % [i + 1, i + 1], Vector2(10, 8), Vector2(208, 36), _select_tray.bind(i), Color("3b5451"), CREAM)
		route.add_theme_font_size_override("font_size", 16)
		route_buttons.append(route)
		var info = _paragraph(card, "Empty", Vector2(12, 49), Vector2(204, 43), 17, MUTED)
		tray_labels.append(info)
		var sell = _button(card, "SELL", Vector2(10, 99), Vector2(208, 43), _sell.bind(i), CREAM)
		sell_buttons.append(sell)
	_label(bottom, "LOAD THE HOPPER", Vector2(757, 13), Vector2(410, 25), 17, GOLD)
	recipe_buttons.clear()
	for i in range(3):
		var b = _button(bottom, RECIPE_NAMES[i], Vector2(757 + i * 150, 44), Vector2(140, 42), _select_recipe.bind(i), RECIPE_COLORS[i])
		b.add_theme_font_size_override("font_size", 17)
		recipe_buttons.append(b)
	hud.drop = _button(bottom, "DROP SIX DONUTS  [ SPACE ]", Vector2(757, 99), Vector2(440, 43), _drop_batch)
	var key_panel = _panel(screen, Vector2(30, 565), Vector2(1035, 29), Color(0.06, 0.12, 0.14, 0.86), 8)
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.keys = _label(key_panel, "A / S / D  flavour     1 / 2 / 3  destination     Q / W / E  sell     SPACE  drop     ESC  pause", Vector2(10, 2), Vector2(1015, 25), 14, CREAM)
	_refresh_hud()

func _refresh_hud() -> void:
	if current_view != "play" or hud.is_empty(): return
	hud.shift.text = "SHIFT %d / 6  ·  %d shop coins" % [model.shift_index + 1, model.credits]
	hud.sales.text = "$%d  /  $%d" % [model.sales, model.target]
	hud.progress.value = clampf(float(model.sales) / maxf(model.target, 1.0) * 100.0, 0.0, 100.0)
	hud.time.text = "%02d:%02d" % [int(model.time_left) / 60, int(model.time_left) % 60]
	hud.time.add_theme_color_override("font_color", ORANGE if model.time_left < 15 else CREAM)
	hud.batter.text = "%d donuts" % model.batter
	hud.close.visible = model.sales >= model.target
	var full = false
	for i in range(3):
		var tray: Array = model.trays[i]
		var quote: Dictionary = model.tray_quote(i)
		var selected = model.selected_tray == i
		route_buttons[i].text = ("> " if selected else "") + "TRAY %d  [ %d ]" % [i + 1, i + 1]
		route_buttons[i].add_theme_stylebox_override("normal", _box_style(GOLD if selected else Color("3b5451"), 10))
		route_buttons[i].add_theme_color_override("font_color", INK if selected else CREAM)
		var combo = str(quote.get("combo", ""))
		tray_labels[i].text = "%d / 6  ·  %s" % [tray.size(), combo if not combo.is_empty() else "Collect a batch"]
		tray_labels[i].tooltip_text = combo
		tray_labels[i].add_theme_color_override("font_color", GOLD if tray.size() == 6 else MUTED)
		sell_buttons[i].text = "SELL  $%d  [ %s ]" % [quote.get("amount", 0), ["Q", "W", "E"][i]]
		sell_buttons[i].disabled = tray.is_empty()
		if tray.size() >= 6: full = true
	for i in range(3):
		var selected = model.selected_recipe == RECIPES[i]
		recipe_buttons[i].add_theme_stylebox_override("normal", _box_style(RECIPE_COLORS[i] if selected else Color("3b4b4c"), 10, GOLD if selected else Color.TRANSPARENT, 2 if selected else 0))
		recipe_buttons[i].add_theme_color_override("font_color", INK if selected else CREAM)
	hud.drop.disabled = not model.can_queue_batch()
	if model.cooldown > 0:
		hud.drop.text = "HOPPER RESETTING  %.1fs" % model.cooldown
	else:
		hud.drop.text = "DROP SIX  >  TRAY %d  [ SPACE ]" % [model.selected_tray + 1]
	if model.sales >= model.target:
		hud.hint.text = "Target met! Keep selling for extra shop coins, or close the shift."
		hud.hint.add_theme_color_override("font_color", MINT)
	elif full:
		hud.hint.text = "A tray is full. Sell it to keep the donuts moving."
		hud.hint.add_theme_color_override("font_color", GOLD)
	elif model.batter < model.next_batch_cost() and model.active.is_empty():
		hud.hint.text = "Last batch! Sell your remaining donuts before closing."
		hud.hint.add_theme_color_override("font_color", ORANGE)
	else:
		hud.hint.text = "Full trays earn combo bonuses. Choose a flavour, choose a tray, drop a batch."
		hud.hint.add_theme_color_override("font_color", CREAM)

func _select_recipe(index: int) -> void:
	model.selected_recipe = RECIPES[index]
	_refresh_hud()

func _select_tray(index: int) -> void:
	model.selected_tray = index
	_refresh_hud()

func _drop_batch() -> void:
	if current_view != "play" or paused: return
	if model.queue_batch(model.selected_recipe, model.selected_tray):
		audio.play_event("drop")
	else:
		if model.batter < model.next_batch_cost(): _toast("No batter left. Sell the donuts you have.", ORANGE)
		elif model.active.size() + 6 > 18: _toast("Fryer full. Sell a tray to make room.", ORANGE)
	_refresh_hud()

func _sell(index: int) -> void:
	if current_view != "play" or paused: return
	var before_sales: float = model.sales
	var result: Dictionary = model.sell_tray(index)
	if float(result.get("amount", 0)) > 0:
		var crossed_target: bool = before_sales < model.target and model.sales >= model.target
		var reward: Dictionary = feedback.describe_sale(result, model.shift_time - model.time_left, crossed_target)
		world.burst_sale(index, float(result.amount), int(reward.tier))
		audio.play_sale(int(reward.tier), int(reward.chain))
		if crossed_target:
			audio.play_goal()
			world.celebrate_goal()
		var origin: Vector2 = ui.get_global_transform().affine_inverse() * world.get_tray_screen_position(index)
		score_fx.celebrate(reward, origin)
		_save_run()
	_refresh_hud()

func _process_events() -> void:
	for event in model.events:
		match str(event.get("type", "")):
			"land":
				if int(event.get("id", 0)) % 3 == 0: audio.play_event("land")
			"shift_end":
				if model.phase == "shop": audio.play_event("win")
	model.events.clear()

func _show_shop() -> void:
	current_view = "shop"
	_new_screen()
	_shade(screen, 0.75)
	_label(screen, "A GOOD DAY TO MAKE DOUGH.", Vector2(70, 32), Vector2(1100, 30), 20, GOLD)
	_label(screen, "Make your machine magic.", Vector2(68, 69), Vector2(1140, 68), 48)
	_label(screen, "Shift %d cleared  ·  $%d earned  ·  next target $%d" % [model.shift_index + 1, model.sales, _next_target()], Vector2(72, 145), Vector2(960, 35), 22, MUTED)
	_label(screen, "%d COINS" % model.credits, Vector2(1005, 140), Vector2(210, 42), 28, GOLD)
	var offers: Array = model.get_shop_offers()
	for i in range(mini(offers.size(), 4)):
		var offer: Dictionary = offers[i]
		var x = 64 + i * 292
		var p = _panel(screen, Vector2(x, 218), Vector2(276, 332), Color("213c3e"), 20)
		_label(p, str(offer.get("category", offer.get("rarity", "UPGRADE"))).to_upper(), Vector2(18, 20), Vector2(240, 25), 15, GOLD)
		_paragraph(p, str(offer.get("name", offer.get("title", "Upgrade"))), Vector2(18, 58), Vector2(240, 78), 27)
		_paragraph(p, str(offer.get("description", offer.get("desc", ""))), Vector2(18, 144), Vector2(240, 113), 18, MUTED)
		var price = int(offer.get("price", offer.get("cost", 0)))
		var buy = _button(p, "INSTALL  ·  %d COINS" % price, Vector2(16, 267), Vector2(244, 45), _buy_upgrade.bind(str(offer.id)))
		buy.add_theme_font_size_override("font_size", 18)
		buy.disabled = model.credits < price
	var owned_text = _owned_description()
	_label(screen, "YOUR BUILD", Vector2(74, 578), Vector2(210, 27), 15, GOLD)
	_paragraph(screen, owned_text, Vector2(74, 616), Vector2(760, 104), 18, CREAM)
	_button(screen, "NEXT SHIFT  >", Vector2(886, 610), Vector2(324, 60), _begin_shift, MINT)
	_button(screen, "Save & take a break", Vector2(886, 683), Vector2(324, 46), func():
		_save_run()
		_show_title(), Color("385350"), CREAM)
	_label(screen, "Shop coins are separate from your sales target. Unspent coins carry forward.", Vector2(74, 748), Vector2(1000, 28), 16, MUTED)

func _next_target() -> int:
	return int(Model.TARGETS[mini(model.shift_index + 1, 5)])

func _buy_upgrade(id: String) -> void:
	if model.buy_upgrade(id):
		audio.play_event("upgrade")
		_save_run()
		_show_shop()
		_toast("Installed. Your next batch just got better.", MINT)

func _owned_description() -> String:
	if model.owned.is_empty(): return "A trusty fryer and a little ambition. Your first upgrade starts a build."
	var parts: Array[String] = []
	for id in model.owned:
		var name_text = str(id).replace("_", " ").capitalize()
		if UpgradeData.ALL.has(id):
			var info: Dictionary = UpgradeData.ALL[id]
			name_text = str(info.get("name", name_text))
		parts.append("%s ×%d" % [name_text, model.owned[id]])
	return "   ·   ".join(parts)

func _finish_run() -> void:
	if not smoke_mode and not screenshot_mode:
		stats.best_shift = maxi(int(stats.best_shift), model.shift_index + 1)
		stats.best_sales = maxf(float(stats.best_sales), model.sales)
		if model.phase == "won": stats.wins = int(stats.wins) + 1
		_save_settings()
		saved_run.clear()
		if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(SAVE_PATH)
	current_view = "result"
	_new_screen()
	_shade(screen, 0.7)
	var won = model.phase == "won"
	audio.play_event("win" if won else "failure")
	var p = _panel(screen, Vector2(280, 130), Vector2(720, 544), Color("172f34"), 26)
	_label(p, "THE FAIR WILL REMEMBER THIS." if won else "THERE'S ALWAYS ANOTHER SUNSET.", Vector2(34, 30), Vector2(652, 30), 17, GOLD)
	_label(p, "A golden run." if won else "Closing time.", Vector2(32, 82), Vector2(654, 70), 56)
	_paragraph(p, "All six shifts cleared. A tiny stand became a very big deal." if won else "The target got away this time. Try a different upgrade combination on your next run.", Vector2(36, 173), Vector2(640, 86), 24, CREAM)
	_label(p, "SHIFT %d / 6     $%d / $%d" % [model.shift_index + 1, model.sales, model.target], Vector2(36, 270), Vector2(640, 45), 28, GOLD)
	_button(p, "ONE MORE RUN", Vector2(36, 346), Vector2(312, 59), _start_new_run)
	_button(p, "Back to the stand", Vector2(368, 346), Vector2(316, 59), _show_title, Color("385350"), CREAM)
	_button(p, "Copy playtest report", Vector2(36, 427), Vector2(648, 49), _copy_report, Color("2d4548"), CREAM)
	_label(p, "Tell us: what felt good, what confused you, and which upgrade you loved.", Vector2(36, 493), Vector2(650, 25), 15, MUTED)

func _open_modal(dimensions: Vector2) -> Panel:
	_close_overlay()
	paused = current_view == "play"
	overlay = Control.new()
	overlay.size = Vector2(1280, 800)
	ui.add_child(overlay)
	_shade(overlay)
	return _panel(overlay, (Vector2(1280, 800) - dimensions) * 0.5, dimensions, Color("193238"), 24)

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
		overlay = null
	paused = false

func _show_pause() -> void:
	if current_view != "play": return
	_save_run()
	var p = _open_modal(Vector2(500, 390))
	_label(p, "Take a breather.", Vector2(30, 24), Vector2(440, 60), 38)
	_label(p, "The donuts can wait. Your run is saved.", Vector2(30, 94), Vector2(440, 32), 20, MUTED)
	_button(p, "BACK TO FRYING", Vector2(30, 153), Vector2(440, 54), _close_overlay)
	_button(p, "Settings", Vector2(30, 221), Vector2(210, 48), _show_settings, Color("385350"), CREAM)
	_button(p, "How to play", Vector2(258, 221), Vector2(212, 48), func(): _show_help(false), Color("385350"), CREAM)
	_button(p, "Save & return to title", Vector2(30, 291), Vector2(440, 48), func():
		_save_run()
		_show_title(), Color("2d4548"), CREAM)

func _show_help(start_after: bool) -> void:
	var p = _open_modal(Vector2(850, 616))
	_label(p, "Welcome to your little stand.", Vector2(34, 24), Vector2(782, 60), 36)
	_label(p, "MAKE THE QUOTA. BUILD SOMETHING DELICIOUS.", Vector2(36, 93), Vector2(780, 30), 17, GOLD)
	var steps = [
		["01  CHOOSE & DROP", "Pick Cinnamon, Powdered, or Cocoa. Choose tray 1, 2, or 3, then drop six donuts into the fryer."],
		["02  WATCH THE MAGIC", "Donuts fry, flip, and land in the tray you chose. You can cook several batches at once."],
		["03  SELL A COMBINATION", "Sell six of one flavour for 2× value. Mixed full trays pay 1.6×. Partial trays sell too, but earn less."],
		["04  BEAT THE RUSH", "Meet the sales target before time runs out. Buy upgrades between shifts. Clear all six to win!"]
	]
	for i in range(4):
		_label(p, steps[i][0], Vector2(36, 151 + i * 85), Vector2(775, 26), 19, GOLD)
		_paragraph(p, steps[i][1], Vector2(36, 181 + i * 85), Vector2(775, 52), 19)
	_label(p, "A full tray holds up incoming donuts. Keep selling to keep things moving.", Vector2(36, 503), Vector2(778, 28), 17, MUTED)
	_button(p, "LET'S FRY  >" if start_after else "GOT IT", Vector2(36, 549), Vector2(778, 48), func():
		_close_overlay()
		if start_after:
			tutorial_seen = true
			_save_settings()
			_begin_shift())

func _show_settings() -> void:
	var p = _open_modal(Vector2(540, 506))
	_label(p, "Make yourself comfortable.", Vector2(30, 24), Vector2(480, 55), 30)
	_button(p, "Sound: " + ("OFF" if muted else "ON"), Vector2(30, 108), Vector2(480, 50), func():
		_toggle_mute()
		_show_settings(), Color("385350"), CREAM)
	_button(p, "Music: " + ("ON" if music_on else "OFF"), Vector2(30, 174), Vector2(480, 50), func():
		music_on = not music_on
		audio.set_music_volume(0.35 if music_on else 0.0)
		_save_settings()
		_show_settings(), Color("385350"), CREAM)
	_button(p, "Window / Fullscreen  [ F11 ]", Vector2(30, 240), Vector2(480, 50), func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN), Color("385350"), CREAM)
	_button(p, "Motion: " + ("REDUCED" if reduced_motion else "FULL CELEBRATIONS"), Vector2(30, 306), Vector2(480, 50), func():
		reduced_motion = not reduced_motion
		_apply_effect_settings()
		_save_settings()
		_show_settings(), Color("385350"), CREAM)
	_label(p, "Reduced motion keeps scores and removes camera shake.", Vector2(30, 372), Vector2(480, 30), 16, MUTED)
	_button(p, "DONE", Vector2(30, 431), Vector2(480, 48), _close_overlay)

func _apply_effect_settings() -> void:
	world.set_reduced_motion(reduced_motion)
	score_fx.set_reduced_motion(reduced_motion)

func _toggle_mute() -> void:
	muted = not muted
	audio.set_muted(muted)
	_save_settings()

func _toast(message: String, color: Color = CREAM) -> void:
	toast_serial += 1
	for previous in toasts.get_children():
		toasts.remove_child(previous)
		previous.queue_free()
	var p = _panel(toasts, Vector2(340, 178), Vector2(600, 48), Color(0.08, 0.16, 0.18, 0.96), 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text = _label(p, message, Vector2(12, 7), Vector2(576, 34), 19, color)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween = p.create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(p, "modulate:a", 0.0, 0.35)
	tween.tween_callback(p.queue_free)

func _save_run() -> void:
	if smoke_mode or screenshot_mode: return
	if model.phase != "playing" and model.phase != "shop": return
	saved_run = model.to_save()
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(saved_run))

func _load_saved_run() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary: saved_run = data

func _save_settings() -> void:
	if smoke_mode or screenshot_mode: return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"muted": muted, "music_on": music_on, "reduced_motion": reduced_motion, "tutorial_seen": tutorial_seen, "stats": stats}))

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not data is Dictionary: return
	muted = bool(data.get("muted", false))
	music_on = bool(data.get("music_on", true))
	reduced_motion = bool(data.get("reduced_motion", false))
	tutorial_seen = bool(data.get("tutorial_seen", false))
	if data.get("stats") is Dictionary: stats.merge(data.stats, true)

func _copy_report() -> void:
	var report = {"game": "Golden Hour", "version": VERSION, "platform": OS.get_name(), "outcome": model.phase, "shift": model.shift_index + 1, "sales": model.sales, "target": model.target, "seed": model.seed_value, "upgrades": model.owned, "fps": Engine.get_frames_per_second(), "feedback": "What felt good? What confused you? Any bugs?"}
	DisplayServer.clipboard_set(JSON.stringify(report, "  "))
	_toast("Playtest report copied. Paste it with your feedback.", MINT)
