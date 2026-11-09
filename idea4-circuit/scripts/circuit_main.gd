extends Control
## A portrait-first, offline company journal. The model owns every economic action.

const Model = preload("res://scripts/circuit_model.gd")
const Content = preload("res://scripts/circuit_content.gd")
const FONT = preload("res://assets/fonts/Fredoka-Medium.ttf")
const LANDSCAPE = preload("res://assets/circuit_landscape.svg")
const PAPER = Color("f5f0e5")
const CREAM = Color("fffbf2")
const INK = Color("173c3f")
const MUTED = Color("647774")
const LINE = Color("dddccc")
const GOLD = Color("e8b85e")
const RED = Color("c35d43")
const GREEN = Color("36725f")
const SAVE = "user://circuit_save.json"
const NAV = [["Journal", "journal"], ["Circuit", "circuit"], ["Crew", "crew"], ["Menu", "menu"], ["Garage", "garage"]]

var model = Model.new()
var settings: Dictionary = {"sound": true, "music": false, "motion": true, "guide": true}
var records: Array = []
var tab = "journal"
var screen: VBoxContainer
var content: VBoxContainer
var scroll: ScrollContainer
var safe: MarginContainer
var modal: Control
var toast: PanelContainer
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var has_run = false
var test_mode = false
var save_failed = false
var save_path = SAVE
var _building = false
var _ready_done = false
var _resize_queued = false
var _day_claim = -1
var _minigame_playing = false
var _minigame_phase = 0.0
var _minigame_gauge: ProgressBar
var _minigame_marker: Label
var _modal_close_allowed = true
var _rng_seed = 2026
var _focus_return: Control
var _reviewing_season = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	test_mode = "--test-mode" in OS.get_cmdline_user_args()
	var theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 17
	for state_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state_name, "CheckButton", INK)
	theme.set_color("font_disabled_color", "CheckButton", MUTED)
	self.theme = theme
	mouse_filter = Control.MOUSE_FILTER_PASS
	RenderingServer.set_default_clear_color(PAPER)
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	music = AudioStreamPlayer.new()
	music.stream = preload("res://assets/audio/evening_theme.wav")
	music.volume_db = -20.0
	music.finished.connect(func():
		if settings.music: music.play())
	add_child(music)
	if not test_mode: _load_game()
	_ready_done = true
	get_viewport().size_changed.connect(_queue_resize)
	_render()
	_sync_music()
	print("CIRCUIT_READY version=0.1.0")
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		print("CIRCUIT_SMOKE_PASS")
		get_tree().quit()

func _process(delta: float) -> void:
	if _minigame_playing and is_instance_valid(_minigame_gauge):
		_minigame_phase += delta * 1.25
		var value = (sin(_minigame_phase) + 1.0) * 50.0
		_minigame_gauge.value = value
		_minigame_marker.text = "%d°C · aim for 185–195°C" % int(160 + value * 0.6)

func _notification(what: int) -> void:
	if not _ready_done: return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_save_game()
		if _minigame_playing:
			_minigame_playing = false
			_close_modal()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: _back()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_back()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and _minigame_playing:
			_stop_minigame()
			get_viewport().set_input_as_handled()

func _queue_resize() -> void:
	if _resize_queued: return
	_resize_queued = true
	call_deferred("_resized")

func _resized() -> void:
	_resize_queued = false
	if is_instance_valid(safe): _apply_safe_area()

func _apply_safe_area() -> void:
	var logical = get_viewport_rect().size
	var native = Vector2(DisplayServer.window_get_size())
	var inset = Vector4.ZERO
	if OS.has_feature("android") or OS.has_feature("ios"):
		var area = DisplayServer.get_display_safe_area()
		if native.x > 0 and native.y > 0 and area.size.x > 0:
			inset = Vector4(area.position.x, area.position.y, maxf(0, native.x - area.end.x), maxf(0, native.y - area.end.y))
	var ratio = logical / native.max(Vector2.ONE)
	var side = maxf(0, (logical.x - 720) / 2.0)
	safe.add_theme_constant_override("margin_left", int(side + inset.x * ratio.x))
	safe.add_theme_constant_override("margin_top", int(inset.y * ratio.y))
	safe.add_theme_constant_override("margin_right", int(side + inset.z * ratio.x))
	safe.add_theme_constant_override("margin_bottom", int(inset.w * ratio.y))

func _render() -> void:
	if _building: return
	_building = true
	_close_modal()
	if is_instance_valid(safe):
		remove_child(safe)
		safe.queue_free()
	safe = MarginContainer.new()
	add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_safe_area()
	screen = VBoxContainer.new()
	screen.add_theme_constant_override("separation", 0)
	safe.add_child(screen)
	if not has_run:
		_build_welcome()
	else:
		_build_header()
		scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		screen.add_child(scroll)
		var margin = MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for edge in ["left", "right", "bottom", "top"]: margin.add_theme_constant_override("margin_" + edge, 18 if edge != "top" else 12)
		scroll.add_child(margin)
		content = _column(margin, 14)
		match tab:
			"circuit": _build_circuit()
			"crew": _build_crew()
			"menu": _build_menu()
			"garage": _build_garage()
			"company": _build_company()
			_: _build_journal()
		_build_primary()
		_build_nav()
	_building = false
	if has_run and not _reviewing_season:
		match str(model.state.get("phase", "planning")):
			"event": call_deferred("_show_event")
			"report": call_deferred("_show_report")
			"season_end", "bankrupt": call_deferred("_show_ending")

func _build_header() -> void:
	var wrap = _box(screen, INK, 0, 16)
	var col = _column(wrap, 9)
	var row = _row(col)
	var names = _column(row, 1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(names, "ON THE CIRCUIT  /  COMPANY JOURNAL", 11, GOLD)
	var title = _label(names, str(model.state.company), 25, CREAM)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_button(row, "Company", func(): _navigate("company"), GOLD, INK, 44).custom_minimum_size.x = 96
	var stats = _row(col, 8)
	_metric(stats, _money(model.state.cash), "CASH ON HAND", CREAM)
	_metric(stats, "%d / 100" % int(model.state.rep), "REPUTATION", GOLD)
	_metric(stats, str(int(model.state.stock)), "BAGS IN STOCK", CREAM)
	var venue = _venue()
	_label(col, "SEASON %02d   ·   DAY %02d / %d   ·   %s" % [model.state.season, model.state.day, model.state.season_length, "ON THE ROAD" if venue.is_empty() else str(venue.town).to_upper()], 12, Color("b9cec4"))

func _build_welcome() -> void:
	var welcome_scroll = ScrollContainer.new()
	welcome_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	welcome_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(welcome_scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	welcome_scroll.add_child(margin)
	var col = _column(margin, 18)
	_label(col, "GOLDEN HOUR", 16, RED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(col, "On the Circuit", 42, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_hero(col, 175)
	_label(col, "A small stand.\nA very big season.", 29, INK)
	_label(col, "Book the fair. Hire the characters. Keep the fryer alive. Build a company the circuit remembers.", 18, MUTED)
	var card = _column(_box(col, CREAM, 16, 18), 12)
	_label(card, "NAME YOUR COMPANY", 12, GREEN)
	var name_edit = LineEdit.new()
	name_edit.name = "CompanyName"
	name_edit.text = "Golden Hour"
	name_edit.max_length = 28
	name_edit.custom_minimum_size.y = 52
	name_edit.add_theme_stylebox_override("normal", _style(PAPER, 10, LINE))
	name_edit.add_theme_stylebox_override("focus", _style(PAPER, 10, GREEN))
	name_edit.add_theme_color_override("font_color", INK)
	card.add_child(name_edit)
	var relaxed = CheckButton.new()
	relaxed.text = "A gentler first season"
	relaxed.custom_minimum_size.y = 48
	relaxed.tooltip_text = "A little more room to recover from a rough day."
	relaxed.add_theme_color_override("font_color", INK)
	card.add_child(relaxed)
	_button(card, "START YOUR FIRST SEASON", func():
		_start_company(name_edit.text, relaxed.button_pressed), RED, CREAM, 60)
	if not model.state.is_empty():
		_button(card, "Return to " + str(model.state.company), func():
			has_run = true
			_render(), PAPER, INK)
	_label(col, "ONE TAP AT A TIME", 12, GREEN)
	_label(col, "Time moves only when you choose. Every day saves automatically. No ads, purchases, or waiting for real-world timers.", 15, MUTED)
	_button(col, "How to play", _show_help, PAPER, INK, 48)
	_label(col, "IDEA #4  ·  PLAYABLE DEMO 0.1", 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _start_company(company: String, relaxed: bool = false) -> void:
	_rng_seed = int(Time.get_unix_time_from_system()) if not test_mode else 2026
	model.new_run(company.strip_edges().left(28) if not company.strip_edges().is_empty() else "Golden Hour", _rng_seed)
	model.state.difficulty = "relaxed" if relaxed else "standard"
	if relaxed: model.state.cash += 700
	has_run = true
	_reviewing_season = false
	tab = "journal"
	_save_game()
	_render()
	_chime("win")

func _build_primary() -> void:
	var outer = _column(_box(screen, PAPER, 0, 12), 4)
	var data: Dictionary = model.primary_action()
	if _reviewing_season: data.label = "Season summary"
	var button = _button(outer, str(data.get("label", "Continue")).to_upper(), _primary, RED, CREAM, 54)
	button.name = "PrimaryAction"
	button.disabled = not bool(data.get("enabled", true))
	_label(outer, str(data.get("hint", "Your next decision awaits.")), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _build_nav() -> void:
	var panel = _box(screen, INK, 0, 7)
	var row = _row(panel, 2)
	for entry in NAV:
		var id: String = entry[1]
		var button = _button(row, str(entry[0]), func(): _navigate(id), GOLD if tab == id else INK, INK if tab == id else CREAM, 51)
		button.name = "Nav_" + id
		button.add_theme_font_size_override("font_size", 16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _navigate(id: String) -> void:
	if not has_run: return
	tab = id
	_chime()
	_render()

func _primary() -> void:
	match str(model.state.phase):
		"event": _show_event()
		"report": _show_report()
		"season_end", "bankrupt": _show_ending()
		_:
			if str(model.state.booked_id).is_empty(): _navigate("circuit")
			else: _act("advance")

func _build_journal() -> void:
	var venue = _venue()
	_hero(content, 135)
	var headline = _column(_box(content, INK, 15, 17), 8)
	_label(headline, "YOUR NEXT CHAPTER", 11, GOLD)
	_label(headline, "The road is calling." if venue.is_empty() else str(venue.name), 27, CREAM)
	_label(headline, "A fresh town, a promising pitch, and somebody who has never tried your donuts." if venue.is_empty() else str(venue.description), 16, Color("c8d5cb"))
	if venue.is_empty():
		_button(headline, "Find your next fair", func(): _navigate("circuit"), GOLD, INK)
	else:
		var row = _row(headline)
		_label(row, "TRADING DAY %d / %d" % [int(model.state.venue_day) + 1, int(venue.days)], 12, GOLD)
		_label(row, "  ·  " + str(model.state.get("weather", "Clear")), 12, CREAM)
		var batch_done = int(model.state.minigame_day) == int(model.state.day)
		var batch_button = _button(headline, "Opening batch complete" if batch_done else "Try a perfect batch", _show_minigame, GOLD, INK, 48)
		batch_button.disabled = batch_done or str(model.state.phase) != "planning"
	if settings.guide and int(model.state.day) <= 4:
		var guide = _column(_box(content, Color("e7eddf"), 14, 16), 8)
		_label(guide, "YOUR FIRST FEW STOPS", 13, GREEN)
		_label(guide, "1  Book a fair that fits your budget.\n2  Check supplies, recipe and equipment.\n3  Open the stand and make the call.\n4  Read the receipt, then do it better tomorrow.", 16, INK)
	var warning: Array[String] = []
	if float(model.state.truck) < 35: warning.append("Truck needs attention before another trip.")
	if float(model.state.fryer) < 35: warning.append("Your fryer is becoming unreliable.")
	if int(model.state.stock) < 50: warning.append("Supplies are low. Restock in Menu before opening.")
	if not warning.is_empty():
		var alert = _column(_box(content, Color("f6dfcc"), 12, 15), 6)
		_label(alert, "A LITTLE ATTENTION NOW…", 12, RED)
		for line in warning: _label(alert, line, 15, INK)
	_section("THE COMPANY JOURNAL", "Your decisions leave a paper trail.")
	var entries: Array = model.state.get("journal", [])
	if entries.is_empty(): _label(content, "Your first entry is waiting at the next fair.", 17, MUTED)
	for index in range(entries.size() - 1, maxi(-1, entries.size() - 31), -1):
		var entry: Dictionary = entries[index]
		var col = _column(_box(content, CREAM, 12, 15), 5)
		var tone: String = str(entry.get("tone", "info"))
		var color: Color = GREEN if tone == "good" else RED if tone == "bad" else MUTED
		_label(col, "DAY %02d  ·  %s" % [int(entry.get("day", 1)), tone.to_upper()], 11, color)
		_label(col, str(entry.get("title", "On the circuit")), 20, INK)
		_label(col, str(entry.get("text", "")), 16, MUTED)

func _build_circuit() -> void:
	_section("THE FAIR CIRCUIT", "Small towns. Big weekends. Find your next good story.")
	var current = _venue()
	if not current.is_empty():
		var booked = _column(_box(content, Color("e7eddf"), 14, 16), 6)
		_label(booked, "YOUR CURRENT BOOKING", 12, GREEN)
		_label(booked, str(current.name), 24, INK)
		_label(booked, "%s · %d trading day(s) remaining" % [current.town, maxi(0, int(current.days) - int(model.state.venue_day))], 15, MUTED)
		_label(booked, "Finish this stop before booking the next. Your entry and travel were paid when you booked.", 15, MUTED)
	for offer in model.venue_offers():
		var col = _column(_box(content, CREAM, 16, 17), 9)
		var color = Color(str(offer.get("color", "36725f")))
		_label(col, str(offer.get("town", "")).to_upper() + "  /  " + str(offer.get("tagline", "ON THE CIRCUIT")).to_upper(), 11, color.darkened(0.35))
		_label(col, str(offer.name), 25, INK)
		_label(col, str(offer.description), 16, MUTED)
		var row = _row(col)
		_pill(row, "%d DAYS" % int(offer.days), PAPER, INK)
		_pill(row, "%d KM" % int(offer.distance), PAPER, INK)
		_pill(row, "%s / DAY" % _money(offer.fee), PAPER, INK)
		_label(col, "Local favorite: " + str(offer.flavor).replace("_", " ").capitalize(), 14, GREEN)
		var relationship = float(model.state.relationships.get(str(offer.id), 0))
		if not is_zero_approx(relationship): _label(col, "Your relationship here: %s%d" % ["+" if relationship > 0 else "", int(relationship)], 14, GREEN if relationship > 0 else RED)
		var id: String = str(offer.id)
		var button = _button(col, "BOOK STOP  ·  " + _money(offer.get("total_cost", offer.fee)), func(): _confirm_booking(id), INK, CREAM)
		button.disabled = not bool(offer.get("can_book", true))
		_label(col, str(offer.get("reason", "Entry for the full stop + fuel. No hidden booking charges.")) if button.disabled else "Full stop entry + travel. Paid now.", 13, MUTED)
	if current.is_empty():
		var backup = _column(_box(content, Color("e7eddf"), 13, 16), 8)
		_label(backup, "Need a little breathing room?", 19, INK)
		_label(backup, "Run a smaller roadside pop-up for a $25 pitch fee. A way to earn your next booking.", 15, MUTED)
		_button(backup, "OPEN A ROADSIDE POP-UP", func(): _act("advance"), GREEN, CREAM)

func _confirm_booking(id: String) -> void:
	var offer: Dictionary = {}
	for candidate in model.venue_offers():
		if candidate.id == id: offer = candidate
	if offer.is_empty(): return
	var col = _modal_page("PACK UP. WE'RE GOING.", str(offer.name))
	_label(col, "%d trading days in %s, %d km down the road." % [offer.days, offer.town, offer.distance], 18, MUTED)
	_label(col, "Pay %s for the full booking and travel. The trip uses one day; you may have a decision to make along the way." % _money(offer.total_cost), 17, INK)
	_label(col, "Truck condition: %d%% · supplies: %d bags" % [int(model.state.truck), int(model.state.stock)], 16, GREEN)
	_button(col, "BOOK & HIT THE ROAD  ·  " + _money(offer.total_cost), func(): _act("book", {"id": id}), RED, CREAM, 56)
	_button(col, "Stay a little longer", _close_modal, PAPER, INK)

func _build_crew() -> void:
	_section("YOUR PEOPLE", "Good people turn a long weekend into a good story.")
	var daily_wages = 0
	for employee in model.state.staff: daily_wages += int(employee.wage)
	var owner = _column(_box(content, INK, 14, 16), 7)
	_label(owner, "YOU'RE ON THE ROSTER, TOO.", 13, GOLD)
	_label(owner, "You always work the stand. Hire when another pair of hands can earn its keep.", 16, CREAM)
	_label(owner, "%d CREW  ·  %s DAILY WAGES" % [model.state.staff.size(), _money(daily_wages)], 13, GOLD)
	for employee in model.state.staff:
		var col = _column(_box(content, CREAM, 14, 16), 8)
		_staff_heading(col, employee)
		_meter(col, "Morale", float(employee.get("morale", 70)), GREEN)
		_meter(col, "Loyalty", float(employee.get("loyalty", 60)), GOLD)
		_label(col, "Skill %d · reliability %d · %s/day" % [employee.skill, employee.reliability, _money(employee.wage)], 14, MUTED)
		var id: String = employee.id
		var row = _row(col)
		_button(row, "Train · $120", func(): _act("train", {"id": id}), INK, CREAM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row, "Give a break", func(): _act("rest", {"id": id}), PAPER, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(col, "Let them go", func(): _confirm_action("Part ways with " + str(employee.name) + "?", "They leave your roster. A good company remembers how it treats its people.", "fire", {"id": id}), CREAM, RED, 44)
	_section("THE HELP-WANTED BOARD", "Signing costs one daily wage. Wages are paid on trading days.")
	for applicant in Content.STAFF:
		var employed = false
		for employee in model.state.staff:
			if employee.id == applicant.id: employed = true
		if employed: continue
		var col = _column(_box(content, CREAM, 14, 16), 8)
		_staff_heading(col, applicant)
		_label(col, str(applicant.description), 16, MUTED)
		_label(col, "Skill %d · reliability %d · kindness %d" % [applicant.skill, applicant.reliability, applicant.kindness], 14, MUTED)
		var id: String = applicant.id
		_button(col, "HIRE  ·  %s + %s / DAY" % [_money(applicant.wage), _money(applicant.wage)], func(): _act("hire", {"id": id}), GREEN, CREAM)

func _staff_heading(parent: Node, entry: Dictionary) -> void:
	var row = _row(parent, 12)
	var badge = _box(row, Color(str(entry.get("color", "e8b85e"))), 26, 8)
	badge.custom_minimum_size = Vector2(51, 51)
	_label(badge, str(entry.name).left(1), 29, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var col = _column(row, 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(col, str(entry.name), 23, INK)
	_label(col, str(entry.role) + " · " + str(entry.trait), 13, GREEN)

func _build_menu() -> void:
	_section("THE DONUT BOARD", "A recipe worth coming back for. A price that pays the bills.")
	var col = _column(_box(content, INK, 15, 17), 11)
	_label(col, "YOUR CURRENT PRICE", 12, GOLD)
	var row = _row(col, 10)
	_button(row, "−", func(): _act("set_price", {"value": float(model.state.price) - 0.5}), GOLD, INK).custom_minimum_size.x = 62
	var price = _label(row, _money(model.state.price) + " / bag", 31, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "+", func(): _act("set_price", {"value": float(model.state.price) + 0.5}), GOLD, INK).custom_minimum_size.x = 62
	_label(col, "Higher prices improve margin, but some crowds will walk on. The daily receipt explains the trade-off.", 15, Color("ccd9cd"))
	var stock = _column(_box(content, CREAM, 14, 16), 10)
	var capacity: int = Content.TRUCKS[int(model.state.truck_tier)].capacity
	var room: int = maxi(0, capacity - int(model.state.stock))
	_label(stock, "%d / %d bags of supplies" % [int(model.state.stock), capacity], 25, INK)
	_label(stock, "$1 buys the base supplies for one bag. Recipe and quality extras are charged as you sell.", 15, MUTED)
	var stock_row = _row(stock)
	for amount in [50, 100, 200]:
		var order: int = room if amount == 200 else mini(amount, room)
		var caption: String = "Fill · $%d" % order if amount == 200 else "+%d · $%d" % [order, order]
		var purchase = _button(stock_row, caption if room > 0 else "Full", func(): _act("buy_stock", {"amount": order}), PAPER, INK)
		purchase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		purchase.disabled = room == 0 or float(model.state.cash) < order
	_section("INGREDIENT STANDARD", "Choose what goes into every batch.")
	var quality_row = _row(content)
	for quality in ["budget", "standard", "premium"]:
		var selected = str(model.state.quality) == quality
		_button(quality_row, quality.capitalize(), func(): _act("set_quality", {"id": quality}), GOLD if selected else CREAM, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(content, "Budget keeps costs down. Premium costs more and can win better reviews.", 14, MUTED)
	_section("YOUR RECIPE BOOK", "Build reputation to unlock more of the good stuff.")
	for recipe in Content.RECIPES:
		var item = _column(_box(content, CREAM, 15, 17), 9)
		var recipe_row = _row(item)
		var swatch = _box(recipe_row, Color(str(recipe.get("color", "e8b85e"))), 24, 6)
		swatch.custom_minimum_size = Vector2(48, 48)
		var center = _box(swatch, CREAM, 8, 0)
		center.custom_minimum_size = Vector2(14, 14)
		center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var title = _label(recipe_row, str(recipe.name), 23, INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(item, str(recipe.description), 16, MUTED)
		_label(item, "Base recipe cost %s / bag · appeal +%d" % [_money(recipe.cost), int(recipe.appeal)], 14, GREEN)
		var id: String = recipe.id
		var locked = id not in model.state.get("unlocked_recipes", [])
		var selected = str(model.state.recipe) == id
		var button = _button(item, "ON YOUR MENU" if selected else "REPUTATION %d TO UNLOCK" % int(recipe.unlock_rep) if locked else "PUT IT ON THE MENU", func(): _act("set_recipe", {"id": id}), GOLD if selected else PAPER, INK)
		button.disabled = selected or locked

func _build_garage() -> void:
	_section("THE WORKING END", "The less glamorous part of making something wonderful.")
	for gear in model.equipment_options():
		var col = _column(_box(content, CREAM, 16, 17), 10)
		_label(col, str(gear.id).to_upper() + "  /  LEVEL %d" % (int(gear.level) + 1), 12, GREEN)
		_label(col, str(gear.name), 26, INK)
		_label(col, str(gear.description), 16, MUTED)
		var id: String = gear.id
		if id != "stand":
			_meter(col, "Condition", float(gear.condition), RED if float(gear.condition) < 35 else GREEN)
			_button(col, "SERVICE  ·  " + _money(gear.service_cost), func(): _act("service", {"id": id}), PAPER, INK)
		if not bool(gear.get("maxed", false)):
			_label(col, "NEXT: " + str(gear.next_name), 13, GREEN)
			_button(col, "UPGRADE  ·  " + _money(gear.next_cost), func(): _confirm_action("A better " + id + ".", "Buy " + str(gear.next_name) + " for " + _money(gear.next_cost) + "?", "upgrade", {"id": id}), INK, CREAM)
		else: _pill(col, "TOP OF THE LINE", GOLD, INK)
	_section("LESS BUSYWORK", "Your crew follows the policies you set.")
	for policy in [["restock", "Automatic restocking", "Buy supplies before trading when there is room and enough cash."], ["service", "Preventive maintenance", "Service low-condition equipment when the budget allows."]]:
		var col = _column(_box(content, CREAM, 13, 15), 7)
		_label(col, policy[1], 21, INK)
		_label(col, policy[2], 15, MUTED)
		var id: String = policy[0]
		var enabled = bool(model.state.policy.get(id, false))
		_button(col, "ENABLED · TAP TO DISABLE" if enabled else "DISABLED · TAP TO ENABLE", func(): _act("set_policy", {"id": id, "enabled": not enabled}), GOLD if enabled else PAPER, INK)

func _build_company() -> void:
	_section("THE BIGGER PICTURE", "A company is more than today's cash drawer.")
	var stats: Dictionary = model.state.get("stats", {})
	var col = _column(_box(content, INK, 16, 17), 12)
	_label(col, str(model.state.company), 29, CREAM)
	var row = _row(col)
	_metric(row, str(int(stats.get("total_sold", 0))), "BAGS SOLD", CREAM)
	_metric(row, _money(stats.get("total_sales", 0)), "LIFETIME SALES", GOLD)
	_label(col, "%d completed stops · season profit %s" % [int(stats.get("completed_stops", 0)), _money(stats.get("season_profit", 0))], 16, CREAM)
	var bank = _column(_box(content, CREAM, 14, 16), 9)
	_label(bank, "A little breathing room", 23, INK)
	_label(bank, "Outstanding loan: " + _money(model.state.debt), 18, RED if float(model.state.debt) > 0 else GREEN)
	_label(bank, "Borrow in $500 steps, up to $2,000. Borrowed cash is not profit. Interest appears on your trading receipts.", 15, MUTED)
	var buttons = _row(bank)
	_button(buttons, "Borrow $500", func(): _confirm_action("Take a $500 loan?", "This gives you working cash and increases your debt. It does not count toward profit.", "loan", {"amount": 500}), PAPER, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(buttons, "Repay $500", func(): _act("repay", {"amount": 500}), PAPER, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section("MILESTONES", "%d / %d collected" % [model.state.achievements.size(), Content.BADGES.size()])
	for badge in Content.BADGES:
		var earned = model.state.achievements.has(str(badge.id))
		var badge_row = _row(_box(content, Color("e7eddf") if earned else CREAM, 12, 14), 12)
		_pill(badge_row, "EARNED" if earned else "LOCKED", GREEN if earned else PAPER, CREAM if earned else MUTED)
		var text = _column(badge_row, 4)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(text, str(badge.get("name", badge.id)), 20, INK)
		_label(text, str(badge.get("description", "")), 15, MUTED)
	if not records.is_empty():
		_section("PAST SEASONS", "The stories that got you here.")
		for record in records:
			_label(content, "%s · season %d · %s" % [record.get("company", "Company"), int(record.get("season", 1)), _money(record.get("profit", 0))], 16, MUTED)
	_button(content, "Settings & accessibility", _show_settings, INK, CREAM)
	_button(content, "How to play", _show_help, CREAM, INK)
	_button(content, "Credits & licenses", _show_credits, CREAM, INK)
	_button(content, "Start a new company", _confirm_restart, CREAM, RED)

func _act(action: String, args: Dictionary = {}) -> void:
	if not has_run: return
	var result: Dictionary = model.act(action, args)
	if not bool(result.get("ok", false)):
		_notify(str(result.get("message", "That action is unavailable right now.")), RED)
		return
	_chime("sale_small" if action in ["decide", "dismiss_report"] else "click")
	_reviewing_season = false
	_save_game()
	_render()
	if str(model.state.phase) == "planning" and not str(result.get("message", "")).is_empty(): _notify(str(result.message), GREEN)

func _show_event() -> void:
	if not has_run or str(model.state.phase) != "event": return
	var event: Dictionary = model.state.get("event", {})
	if event.is_empty(): return
	var col = _modal_page("A MOMENT ON THE CIRCUIT", str(event.get("title", "A decision to make")), false)
	_label(col, str(event.get("body", "")), 20, INK)
	_label(col, "WHAT DO YOU DO?", 12, GREEN)
	var choices: Array = event.get("choices", [])
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var box = _column(_box(col, PAPER, 13, 13), 7)
		var pick = index
		var button = _button(box, str(choice.get("label", "Make the call")), func(): _act("decide", {"choice": pick}), INK if index == 0 else CREAM, CREAM if index == 0 else INK, 50)
		button.name = "EventChoice_" + str(index)
		var effects: Dictionary = choice.get("effects", {})
		var risk: Dictionary = choice.get("risk", {}).get("effects", {})
		var cost = maxf(0, -float(effects.get("cash", 0))) + maxf(0, -float(risk.get("cash", 0)))
		var portions = maxi(0, -int(effects.get("stock", 0))) + maxi(0, -int(risk.get("stock", 0)))
		button.disabled = cost > maxf(0, float(model.state.cash)) or portions > int(model.state.stock)
		_label(box, str(choice.get("detail", "")), 15, MUTED)
		if cost > maxf(0, float(model.state.cash)): _label(box, "Needs " + _money(cost) + " available, including any stated risk.", 13, RED)
		if portions > int(model.state.stock): _label(box, "Needs %d bags of supplies, including any stated risk." % portions, 13, RED)
	_label(col, "The day waits for your decision. Your place is saved.", 13, MUTED)

func _show_report() -> void:
	if not has_run or str(model.state.phase) != "report": return
	var report: Dictionary = model.state.get("last_report", {})
	var col = _modal_page("THE DAILY TAKINGS", str(report.get("title", "That's a day's work.")), false)
	var profit = float(report.get("profit", 0))
	_label(col, _money(profit), 47, GREEN if profit >= 0 else RED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(col, "TODAY'S PROFIT" if profit >= 0 else "TODAY'S LOSS", 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var summary: Array = report.get("summary", [])
	if not summary.is_empty(): _label(col, str(summary[0]), 17, INK)
	var receipt = _column(_box(col, PAPER, 14, 16), 9)
	_receipt(receipt, "Bags sold", str(int(report.get("sold", 0))))
	_receipt(receipt, "Sales", _money(report.get("revenue", 0)))
	_receipt(receipt, "Ingredients used", "−" + _money(report.get("ingredients", 0)))
	_receipt(receipt, "Crew wages", "−" + _money(report.get("wages", 0)))
	_receipt(receipt, "Pitch & travel allocation", "−" + _money(float(report.get("fees", 0)) - float(report.get("interest", 0))))
	if float(report.get("interest", 0)) > 0: _receipt(receipt, "Loan interest", "−" + _money(report.interest))
	if not is_zero_approx(float(report.get("event_cash", 0))): _receipt(receipt, "Today's decision", _money(report.event_cash))
	_receipt(receipt, "Reputation", "%+d" % int(report.get("rep_change", 0)))
	if report.has("cash_delta"):
		_label(col, "Cash change: %s. Profit includes supplies and booking costs you paid earlier." % _money(report.cash_delta), 14, MUTED)
	_button(col, "CLOSE THE BOOKS & CONTINUE", func(): _act("dismiss_report"), RED, CREAM, 56).name = "DismissReport"
	var details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 12)
	var disclosure = _button(col, "WHY DID TODAY GO THIS WAY?", func():
		details.visible = not details.visible, PAPER, INK, 46)
	disclosure.name = "ReportDetails"
	col.add_child(details)
	for index in range(1, summary.size()): _label(details, "•  " + str(summary[index]), 15, INK)
	details.visible = false

func _show_ending() -> void:
	if not has_run or str(model.state.phase) not in ["season_end", "bankrupt"]: return
	_reviewing_season = false
	var failed = str(model.state.phase) == "bankrupt"
	var col = _modal_page("EVERY CIRCUIT HAS A STORY", "A tough road." if failed else "What a season.", false)
	_hero(col, 125)
	_label(col, "Your company ran out of working room. Your journal and milestones are still here to look back on." if failed else "The pitches are packed away. The fryer is quiet. Your next season starts with everything you've learned.", 19, INK)
	var stats: Dictionary = model.state.get("stats", {})
	_receipt(col, "Season profit", _money(stats.get("season_profit", 0)))
	_receipt(col, "Company cash", _money(model.state.cash))
	_receipt(col, "Outstanding debt", _money(model.state.debt))
	_receipt(col, "Reputation", str(int(model.state.rep)) + " / 100")
	_receipt(col, "Stops this season", str(model.state.completed.size()))
	if model.state.season_summary.has("score"): _receipt(col, "Season score", str(int(model.state.season_summary.score)))
	_receipt(col, "Milestones earned", "%d / %d" % [model.state.achievements.size(), Content.BADGES.size()])
	if not failed:
		_button(col, "HIT THE CIRCUIT NEXT SEASON", func():
			_record_season()
			_act("next_season"), RED, CREAM, 56)
	_button(col, "Read the company journal", func():
		_close_modal()
		tab = "journal"
		_reviewing_season = true
		_render(), PAPER, INK)
	_button(col, "Start a fresh company", _confirm_restart, CREAM, RED)
	_chime("win" if not failed else "attention")

func _record_season() -> void:
	var key = str(model.state.rng_seed) + ":" + str(model.state.season)
	for record in records:
		if str(record.get("key", "")) == key: return
	records.push_front({"key": key, "company": model.state.company, "season": model.state.season, "profit": model.state.stats.get("season_profit", 0)})
	if records.size() > 12: records.resize(12)

func _show_minigame() -> void:
	if int(model.state.minigame_day) == int(model.state.day):
		_notify("Today's opening batch is already complete.", GREEN)
		return
	if str(model.state.phase) != "planning" or str(model.state.booked_id).is_empty():
		_notify("Book a fair first. Then you can perfect the opening batch.", RED)
		return
	var col = _modal_page("A LITTLE HANDS-ON MAGIC", "The perfect first batch")
	_label(col, "Stop the thermometer as close to 190°C as you can. A good opening batch gives today's sales a small lift.", 19, INK)
	_label(col, "Optional · once per day · no penalty for skipping", 14, GREEN)
	_minigame_marker = _label(col, "190°C · aim for 185–195°C", 22, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_minigame_gauge = ProgressBar.new()
	_minigame_gauge.custom_minimum_size.y = 42
	_minigame_gauge.show_percentage = false
	_minigame_gauge.add_theme_stylebox_override("background", _style(Color("e8dfc9"), 18))
	_minigame_gauge.add_theme_stylebox_override("fill", _style(GOLD, 18))
	col.add_child(_minigame_gauge)
	_label(col, "160°                 190°                 220°", 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_button(col, "THAT'S THE TEMPERATURE!", _stop_minigame, RED, CREAM, 58)
	_button(col, "Leave it to the crew", _close_modal, PAPER, INK)
	_minigame_phase = -1.57
	_minigame_playing = true

func _stop_minigame() -> void:
	if not _minigame_playing or not is_instance_valid(_minigame_gauge): return
	_minigame_playing = false
	var score = clampf(1.0 - absf(_minigame_gauge.value - 50) / 50, 0, 1)
	_act("minigame", {"score": score})

func _show_settings() -> void:
	var col = _modal_page("MAKE YOURSELF AT HOME", "Settings")
	for entry in [["sound", "Tactile sound effects"], ["music", "Fairground music"], ["motion", "Gentle menu animation"], ["guide", "First-season guide"]]:
		var key: String = entry[0]
		var toggle = CheckButton.new()
		toggle.text = entry[1]
		toggle.custom_minimum_size.y = 54
		toggle.button_pressed = bool(settings.get(key, true))
		toggle.add_theme_color_override("font_color", INK)
		toggle.toggled.connect(func(value):
			settings[key] = value
			_save_game()
			_sync_music())
		col.add_child(toggle)
	_label(col, "Everything saves locally on this device. The new company journal has its own save, separate from the original 3D game.", 15, MUTED)
	_label(col, "Save location: " + ("this device" if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web") else ProjectSettings.globalize_path(save_path)), 12, MUTED)
	_button(col, "DONE", _close_modal, INK, CREAM)

func _show_help() -> void:
	var col = _modal_page("YOUR POCKET FIELD GUIDE", "Welcome to the circuit")
	for entry in [
		["01  Book a stop", "Circuit shows fees, travel, local tastes and reputation requirements. You pay the whole booking and fuel up front."],
		["02  Prepare", "Menu sets your price, recipe and supplies. Crew adds capacity and skill. Garage keeps your truck and fryer healthy."],
		["03  Open the stand", "One tap advances a trading day. Make the event decision, then read the daily receipt. Time never advances while you browse."],
		["04  Learn the crowd", "Match recipes to local tastes. Higher prices can lose customers. Reviews, service and reliability shape reputation."],
		["05  Leave a story", "People and towns remember earlier decisions. Finish the season, then return with your staff, equipment and relationships."],
		["Need a second chance?", "Borrow working capital in Company, or run a $25 roadside pop-up. Staff and bigger machines are optional at the start."]]:
		_label(col, entry[0], 20, GREEN)
		_label(col, entry[1], 17, INK)
	_button(col, "I'M READY", _close_modal, RED, CREAM)

func _show_credits() -> void:
	var col = _modal_page("MADE FOR THE LONG WAY ROUND", "Credits & licenses")
	_label(col, "Golden Hour: On the Circuit\nIdea #4 · Demo 0.1.0", 22, INK)
	_label(col, "Original game design, company stories, illustrations and interface. An independent choice-driven concessions simulator; no affiliation with BitLife or Candywriter.", 16, MUTED)
	_label(col, "Built with Godot 4.7.2. Fredoka typeface under the SIL Open Font License. Original Golden Hour audio reused from the companion game.", 16, MUTED)
	for entry in [["Godot engine license", "res://docs/licenses/Godot-LICENSE.txt"], ["Engine third-party notices", "res://docs/licenses/Godot-COPYRIGHT.txt"], ["Fredoka font license", "res://assets/fonts/OFL.txt"]]:
		var path: String = entry[1]
		var caption: String = entry[0]
		_button(col, caption, func():
			var license_page = _modal_page("BUNDLED OFFLINE NOTICE", caption)
			_label(license_page, FileAccess.get_file_as_string(path), 13, INK)
			_button(license_page, "BACK", _show_credits, PAPER, INK), PAPER, INK)
	_button(col, "BACK", _close_modal, INK, CREAM)

func _confirm_restart() -> void:
	var col = _modal_page("ANOTHER ROAD TO TAKE", "Start a new company?")
	_label(col, "This replaces the current company. Completed season records stay in your history. Your original 3D game's save is unaffected.", 18, INK)
	_button(col, "KEEP THIS COMPANY", _close_modal, INK, CREAM)
	_button(col, "START FRESH", func():
		if has_run: _record_season()
		has_run = false
		_render(), PAPER, RED)

func _confirm_action(title: String, body: String, action: String, args: Dictionary) -> void:
	var col = _modal_page("YOUR CALL", title)
	_label(col, body, 19, INK)
	_button(col, "CONFIRM", func(): _act(action, args), RED, CREAM)
	_button(col, "NOT NOW", _close_modal, PAPER, INK)

func _modal_page(kicker: String, title: String, close_allowed: bool = true) -> VBoxContainer:
	_close_modal()
	if is_instance_valid(toast): toast.queue_free()
	_modal_close_allowed = close_allowed
	modal = Control.new()
	modal.name = "DecisionSheet"
	modal.z_index = 15
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new()
	shade.color = Color(0.03, 0.12, 0.13, 0.72)
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin = MarginContainer.new()
	modal.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var width = get_viewport_rect().size.x
	var side = int(maxf(16, (width - 620) / 2))
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", maxi(24, safe.get_theme_constant("margin_top") + 12))
	margin.add_theme_constant_override("margin_bottom", maxi(24, safe.get_theme_constant("margin_bottom") + 12))
	var panel = _box(margin, CREAM, 20, 20)
	var list = ScrollContainer.new()
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.follow_focus = true
	panel.add_child(list)
	var col = _column(list, 15)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if close_allowed:
		var row = _row(col)
		var label = _label(row, kicker, 11, RED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row, "Close", _close_modal, PAPER, INK, 44).custom_minimum_size.x = 72
	else: _label(col, kicker, 11, RED)
	_label(col, title, 32, INK)
	if settings.motion:
		panel.modulate.a = 0
		create_tween().tween_property(panel, "modulate:a", 1.0, 0.16)
	return col

func _close_modal() -> void:
	_minigame_playing = false
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null

func _back() -> void:
	if is_instance_valid(modal):
		if _modal_close_allowed: _close_modal()
		else: _notify("Make this decision to continue. Your place is saved.", GREEN)
	elif has_run and tab != "journal": _navigate("journal")
	else: _show_settings()

func _save_game() -> bool:
	if test_mode or not has_run: return true
	var payload = {"version": 1, "model": model.to_save(), "settings": settings, "records": records}
	var file = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_failed = true
		_notify("Could not save. Please free some space before closing.", RED)
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		save_failed = true
		_notify("Your last saved company is safe, but this update could not be written.", RED)
		return false
	var target = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		var parser = JSON.new()
		var previous = parser.data if parser.parse(FileAccess.get_file_as_string(save_path)) == OK else null
		var validator = Model.new()
		if previous is Dictionary and int(previous.get("version", 0)) == 1 and previous.get("model") is Dictionary and validator.from_save(previous.model):
			if DirAccess.copy_absolute(target, target + ".backup") != OK:
				save_failed = true
				return false
	var error = DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), target)
	save_failed = error != OK
	if save_failed: _notify("Your last saved company is safe, but this update could not be written.", RED)
	return not save_failed

func _load_game() -> void:
	for path in [save_path, save_path + ".backup"]:
		if not FileAccess.file_exists(path): continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK: continue
		var payload = parser.data
		if not payload is Dictionary or int(payload.get("version", 0)) != 1 or not payload.get("model") is Dictionary: continue
		if not model.from_save(payload.model): continue
		has_run = true
		var options = payload.get("settings", {})
		if options is Dictionary:
			for key in settings: settings[key] = bool(options.get(key, settings[key]))
		if payload.get("records") is Array: records = payload.records.slice(0, 12)
		return

func _sync_music() -> void:
	if settings.music and not music.playing: music.play()
	elif not settings.music: music.stop()

func _chime(kind: String = "click") -> void:
	if not settings.sound or not is_instance_valid(sfx) or test_mode: return
	var path = "res://assets/audio/" + kind + ".wav"
	if ResourceLoader.exists(path):
		sfx.stream = load(path)
		sfx.volume_db = -13.0
		sfx.play()

func _notify(text: String, color: Color = GREEN) -> void:
	if text.is_empty() or not is_inside_tree(): return
	if is_instance_valid(toast): toast.queue_free()
	toast = PanelContainer.new()
	toast.z_index = 30
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override("panel", _style(color, 12))
	add_child(toast)
	var width = minf(get_viewport_rect().size.x - 32, 620)
	toast.position = Vector2((get_viewport_rect().size.x - width) / 2, 28)
	toast.size = Vector2(width, 60)
	var label = _label(toast, text, 16, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	label.custom_minimum_size = Vector2(width - 24, 44)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var current = toast
	var tween = create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(current, "modulate:a", 0.0, 0.22)
	tween.tween_callback(current.queue_free)

func _venue() -> Dictionary:
	return Content.find(Content.VENUES, str(model.state.get("booked_id", "")))

func _section(title: String, description: String = "") -> void:
	var col = _column(content, 5)
	_label(col, title, 13, GREEN)
	if not description.is_empty(): _label(col, description, 19, INK)

func _hero(parent: Node, height: float) -> void:
	var art = TextureRect.new()
	art.texture = LANDSCAPE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size.y = height
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)

func _metric(parent: Node, value: String, caption: String, color: Color) -> void:
	var col = _column(parent, 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(col, value, 23, color)
	_label(col, caption, 10, Color("b9cec4"))

func _receipt(parent: Node, key: String, value: String) -> void:
	var row = _row(parent)
	var label = _label(row, key, 16, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(row, value, 18, INK, HORIZONTAL_ALIGNMENT_RIGHT)

func _meter(parent: Node, title: String, value: float, color: Color) -> void:
	_receipt(parent, title, "%d%%" % int(value))
	var bar = ProgressBar.new()
	bar.value = clampf(value, 0, 100)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", _style(PAPER, 4))
	bar.add_theme_stylebox_override("fill", _style(color, 4))
	parent.add_child(bar)

func _pill(parent: Node, text: String, fill: Color, ink: Color) -> void:
	_label(_box(parent, fill, 8, 8), text, 11, ink).autowrap_mode = TextServer.AUTOWRAP_OFF

func _column(parent: Node, separation: int = 12) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", separation)
	parent.add_child(col)
	return col

func _row(parent: Node, separation: int = 8) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row

func _box(parent: Node, fill: Color, radius: int = 14, padding: int = 14) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = _style(fill, radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, font_size: int = 17, color: Color = INK, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.text = text
	return label

func _button(parent: Node, text: String, callback: Callable, fill: Color = INK, ink: Color = CREAM, height: int = 56) -> Button:
	var button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = maxi(54, height)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(fill, 11))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.06), 11))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.06), 11))
	button.add_theme_stylebox_override("disabled", _style(Color("e8e6da"), 11))
	button.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), 11, GOLD, 2))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _style(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT, border_width: int = 1) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _money(value: Variant) -> String:
	var amount = float(value)
	var whole = str(absi(roundi(amount)))
	var grouped = ""
	for index in range(whole.length()):
		if index > 0 and (whole.length() - index) % 3 == 0: grouped += ","
		grouped += whole[index]
	var fraction = absf(amount) - floorf(absf(amount))
	if fraction > 0.001 and absf(amount) < 100: return ("−" if amount < 0 else "") + "$%.2f" % absf(amount)
	return ("−" if amount < 0 else "") + "$" + grouped
