extends Control
## A portrait-first, offline company journal. The model owns every economic action.

const Model = preload("res://scripts/circuit_model.gd")
const Content = preload("res://scripts/circuit_content.gd")
const Presenter = preload("res://scripts/circuit_presenter.gd")
const BatchGame = preload("res://scripts/circuit_batch_game.gd")
const Celebration = preload("res://scripts/circuit_celebration.gd")
const ActivityGame = preload("res://scripts/circuit_activity_game.gd")
const WorldView = preload("res://scripts/circuit_world_view.gd")
const RouteView = preload("res://scripts/circuit_route_view.gd")
const SalesView = preload("res://scripts/circuit_sales_view.gd")
const FONT = preload("res://assets/fonts/Fredoka-Medium.ttf")
const LANDSCAPE = preload("res://assets/circuit_landscape.svg")
const PAPER = Color("f2e6ce")
const CREAM = Color("fffcf3")
const INK = Color("172c45")
const MUTED = Color("586777")
const LINE = Color("d9c9ab")
const GOLD = Color("ffc857")
const RED = Color("de503c")
const GREEN = Color("147a67")
const VIOLET = Color("7553a6")
const MINT = Color("27b393")
const SAVE = "user://circuit_save.json"
const NAV = [["Journal", "journal"], ["Circuit", "circuit"], ["Crew", "crew"], ["Menu", "menu"], ["Garage", "garage"]]

var model = Model.new()
var settings: Dictionary = {"sound": true, "music": false, "motion": true, "guide": true, "haptics": true}
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
var _batch_game: Control
var _modal_close_allowed = true
var _rng_seed = 2026
var _focus_return: Control
var _reviewing_season = false
var venue_filter = "ready"
var _art_cache: Dictionary = {}
var _activity_game: Control
var _activity_offer_id = ""
var _activity_busy = false

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
	print("CIRCUIT_READY version=0.3.0")
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		print("CIRCUIT_SMOKE_PASS")
		get_tree().quit()

func _process(_delta: float) -> void:
	pass

func _notification(what: int) -> void:
	if not _ready_done: return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_save_game()
		if _minigame_playing or _activity_busy:
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
	if is_instance_valid(toast):
		var width = minf(get_viewport_rect().size.x - 32, 620)
		toast.position.x = (get_viewport_rect().size.x - width) / 2
		for child in toast.get_children():
			if child is Label: child.custom_minimum_size.x = width - 24
		toast.size.x = width

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
	var col = _column(_box(screen, INK, 0, 14), 5)
	_picture(col, "decor/light_strand", Vector2(0, 20))
	var row = _row(col)
	var names = _column(row, 1)
	_label(names, "ON THE CIRCUIT", 10, GOLD)
	var title = _label(names, str(model.state.company), 25, CREAM)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var company_button = _icon_button(row, "Company", "stand", func(): _navigate("company"), GOLD, INK)
	company_button.custom_minimum_size.x = 128
	company_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	var stats = _row(col, 10)
	_header_stat(stats, "cash", _money(model.state.cash), "Cash")
	_header_stat(stats, "rep", str(int(model.state.rep)), "Rep", GOLD)
	_header_stat(stats, "stock", str(int(model.state.stock)), "Stock")
	var line = _row(col)
	_icon(line, "calendar", 16, GOLD)
	_label(line, "Day %d / %d   ·   Season %d" % [model.state.day, model.state.season_length, model.state.season], 12, Color("c8d5cb"))
	var location = _venue()
	var town = _label(line, "On the road" if location.is_empty() else str(location.town), 12, GOLD)
	town.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	town.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	town.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _build_welcome() -> void:
	var welcome_scroll = ScrollContainer.new()
	welcome_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	welcome_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(welcome_scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	welcome_scroll.add_child(margin)
	var col = _column(margin, 16)
	_label(col, "GOLDEN HOUR", 14, RED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(col, "On the Circuit", 41, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_hero(col, 210)
	_label(col, "Your stand. Your story.", 28, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var features = _row(col, 10)
	for item in [["map", "Travel"], ["crew", "Hire"], ["recipe", "Create"]]:
		var tile = _column(_box(features, CREAM, 14, 12), 5)
		tile.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_icon(tile, item[0], 28, GREEN)
		_label(tile, item[1], 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var card = _column(_box(col, CREAM, 16, 18), 12)
	_label(card, "YOUR COMPANY", 12, GREEN)
	var name_edit = LineEdit.new()
	name_edit.name = "CompanyName"
	name_edit.text = "Golden Hour"
	name_edit.max_length = 28
	name_edit.custom_minimum_size.y = 54
	name_edit.add_theme_stylebox_override("normal", _style(PAPER, 10, LINE))
	name_edit.add_theme_stylebox_override("focus", _style(PAPER, 10, GREEN))
	name_edit.add_theme_color_override("font_color", INK)
	card.add_child(name_edit)
	var relaxed = CheckButton.new()
	relaxed.mouse_filter = Control.MOUSE_FILTER_PASS
	relaxed.text = "Relaxed start (+$700)"
	relaxed.custom_minimum_size.y = 54
	card.add_child(relaxed)
	_icon_button(card, "START YOUR SEASON", "arrow", func(): _start_company(name_edit.text, relaxed.button_pressed), RED, CREAM)
	if not model.state.is_empty():
		_button(card, "Resume " + str(model.state.company), func():
			has_run = true
			_render(), PAPER, INK)
	_icon_button(col, "How to play", "info", _show_help, PAPER, INK)
	_label(col, "Offline · Autosaves · No timers", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

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
	var outer = _column(_box(screen, PAPER, 0, 10), 0)
	var data: Dictionary = model.primary_action()
	if _reviewing_season: data.label = "Season summary"
	var button = _icon_button(outer, str(data.get("label", "Continue")).to_upper(), "arrow", _primary, RED, CREAM)
	button.name = "PrimaryAction"
	button.disabled = not bool(data.get("enabled", true))

func _build_nav() -> void:
	var row = _row(_box(screen, INK, 0, 7), 3)
	var icons = {"journal": "journal", "circuit": "map", "crew": "crew", "menu": "recipe", "garage": "garage"}
	for entry in NAV:
		var id: String = entry[1]
		var selected: bool = tab == id
		var button = _button(row, "", func(): _navigate(id), GOLD if selected else INK, INK if selected else CREAM, 64)
		button.name = "Nav_" + id
		button.tooltip_text = str(entry[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var center = VBoxContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_theme_constant_override("separation", 2)
		button.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.offset_top = 7
		center.offset_bottom = -5
		_icon(center, str(icons[id]), 25, INK if selected else CREAM)
		_label(center, str(entry[0]), 12, INK if selected else CREAM, HORIZONTAL_ALIGNMENT_CENTER)

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
	var cover = _column(_box(content, INK, 20, 12), 9)
	var world = WorldView.new()
	world.name = "LivingStand"
	cover.add_child(world)
	world.configure(model.state, not bool(settings.motion))
	_label(cover, "Where to next?" if venue.is_empty() else str(venue.name), 26, CREAM)
	if venue.is_empty():
		_icon_button(cover, "Find a fair", "map", func(): _navigate("circuit"), GOLD, INK)
	else:
		var details = _flow(cover)
		_chip(details, "calendar", "%d / %d days" % [int(model.state.venue_day) + 1, venue.days], INK, GOLD)
		_chip(details, "weather", str(model.state.weather), INK, CREAM)
		var batch_done: bool = int(model.state.minigame_day) == int(model.state.day)
		var batch_button = _icon_button(cover, "Batch ready · view" if batch_done else "Make the opening batch", "recipe", _show_minigame, GOLD, INK)
		batch_button.disabled = str(model.state.phase) != "planning"
	_build_company_shortcuts(content)
	_build_active_effects()
	var ready = _row(content, 9)
	for item in [["truck", "Truck", int(model.state.truck), "garage"], ["fryer", "Fryer", int(model.state.fryer), "garage"], ["stock", "Supplies", int(model.state.stock), "menu"]]:
		var destination: String = item[3]
		var low: bool = item[2] < (50 if item[0] == "stock" else 35)
		var box = _column(_box(ready, Color("f6dfcc") if low else CREAM, 13, 10), 5)
		box.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_icon(box, item[0], 28, RED if low else GREEN)
		_label(box, str(item[2]) + ("" if item[0] == "stock" else "%"), 24, RED if low else INK, HORIZONTAL_ALIGNMENT_CENTER)
		_button(box, str(item[1]), func(): _navigate(destination), PAPER, INK).add_theme_font_size_override("font_size", 14)
	if settings.guide and int(model.state.day) <= 4:
		var steps = _row(_box(content, Color("e7eddf"), 14, 10), 10)
		for item in [["map", "1  Book"], ["stock", "2  Prep"], ["fryer", "3  Open"]]:
			var step = _column(steps, 4)
			_icon(step, item[0], 24, GREEN)
			_label(step, item[1], 14, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_section("RECENT MOMENTS")
	var entries: Array = model.state.get("journal", [])
	for index in range(entries.size() - 1, maxi(-1, entries.size() - 5), -1):
		var entry: Dictionary = entries[index]
		var tone: String = str(entry.get("tone", "info"))
		var row = _row(_box(content, CREAM, 12, 10), 10)
		_icon(row, "star" if tone == "good" else "wrench" if tone == "bad" else "journal", 25, GREEN if tone == "good" else RED)
		var col = _column(row, 2)
		_label(col, "DAY %d" % int(entry.get("day", 1)), 10, MUTED)
		_button(col, str(entry.get("title", "A new chapter")), func(): _show_entry(entry), CREAM, INK).alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not entries.is_empty(): _icon_button(content, "Full journal", "journal", _show_history, PAPER, INK)

func _build_circuit() -> void:
	var route = RouteView.new()
	route.name = "CircuitMap"
	content.add_child(route)
	route.configure(model.state, model.venue_offers(), model.state.get("circuit", {}).get("itinerary", []), not bool(settings.motion))
	route.venue_selected.connect(_show_venue)
	_icon_button(content, "Plan the season · calendar", "calendar", _show_calendar, INK, CREAM).name = "SeasonCalendar"
	_build_itinerary(content, true)
	_section("PICK YOUR NEXT STOP")
	var current = _venue()
	if not current.is_empty():
		var booked = _column(_box(content, Color("e7eddf"), 14, 14), 6)
		_label(booked, str(current.name), 23, INK)
		_chip(_flow(booked), "calendar", "%d days left · booked" % maxi(0, int(current.days) - int(model.state.venue_day)))
	var filters = _row(content)
	for option in [["ready", "Ready to book"], ["all", "All stops"]]:
		var key: String = option[0]
		_button(filters, option[1], func():
			venue_filter = key
			_render(), GOLD if venue_filter == key else CREAM, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown = 0
	for offer in model.venue_offers():
		if venue_filter == "ready" and not bool(offer.can_book): continue
		shown += 1
		var col = _column(_box(content, CREAM, 16, 12), 8)
		_picture(col, "venues/" + str(offer.id), Vector2(0, 125), true)
		_label(col, str(offer.name), 24, INK)
		var badges = _flow(col)
		_chip(badges, "calendar", "%d days" % offer.days)
		_chip(badges, "truck", "%d km" % offer.distance)
		_chip(badges, "recipe", str(offer.flavor).capitalize())
		var id: String = str(offer.id)
		var buttons = _row(col)
		var book = _icon_button(buttons, "Book · " + _money(offer.total_cost), "map", func(): _confirm_booking(id), INK, CREAM)
		book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		book.disabled = not bool(offer.can_book)
		_icon_button(buttons, "Info", "info", func(): _show_venue(id), PAPER, INK).custom_minimum_size.x = 90
		if not bool(offer.can_book): _label(col, str(offer.reason), 13, MUTED)
	if shown == 0: _label(content, "Finish this stop to travel again." if not current.is_empty() else "No ready bookings. Try All stops or a pop-up.", 17, MUTED)
	if current.is_empty():
		var backup = _row(_box(content, Color("e7eddf"), 14, 12), 12)
		_picture(backup, "equipment/stand_0", Vector2(92, 72))
		var col = _column(backup, 5)
		_label(col, "Roadside pop-up", 21, INK)
		_icon_button(col, "Open · $25", "stand", func(): _act("advance"), GREEN, CREAM)

func _confirm_booking(id: String) -> void:
	var offer: Dictionary = {}
	for candidate in model.venue_offers():
		if candidate.id == id: offer = candidate
	if offer.is_empty(): return
	var col = _modal_page("NEXT STOP", str(offer.name))
	_picture(col, "venues/" + id, Vector2(0, 145), true)
	var chips = _flow(col)
	_chip(chips, "calendar", "%d trading days" % offer.days)
	_chip(chips, "truck", "%d km" % offer.distance)
	_chip(chips, "clock", "1 travel day")
	_receipt(col, "Pitch fees", _money(float(offer.fee) * int(offer.days)))
	_receipt(col, "Travel", _money(offer.travel_cost))
	_label(col, "Full stop paid now.", 15, MUTED)
	_icon_button(col, "BOOK · " + _money(offer.total_cost), "arrow", func(): _act("book", {"id": id}), RED, CREAM)

func _build_crew() -> void:
	_build_crew_moments(content)
	var wages = 0
	for employee in model.state.staff: wages += int(employee.wage)
	var summary = _flow(content)
	_chip(summary, "crew", "%d crew + you" % model.state.staff.size(), INK, CREAM)
	_chip(summary, "cash", _money(wages) + " / day", INK, GOLD)
	for employee in model.state.staff:
		var col = _column(_box(content, CREAM, 16, 13), 9)
		_staff_heading(col, employee)
		var chips = _flow(col)
		_chip(chips, "heart", "%d morale" % employee.morale)
		_chip(chips, "shield", "%d loyalty" % employee.loyalty)
		_icon_button(col, "Manage", "crew", func(): _show_staff(str(employee.id)), GREEN, CREAM)
	_section("MEET YOUR NEXT HIRE")
	var board = GridContainer.new()
	board.columns = 2
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("h_separation", 12)
	board.add_theme_constant_override("v_separation", 12)
	content.add_child(board)
	for applicant in Content.STAFF:
		var employed = false
		for employee in model.state.staff:
			if employee.id == applicant.id: employed = true
		if employed: continue
		var col = _column(_box(board, CREAM, 16, 10), 7)
		col.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_picture(col, "crew/" + str(applicant.id), Vector2(0, 120))
		_label(col, str(applicant.name), 22, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_label(col, str(applicant.role), 14, VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
		_staff_mini_stats(col, applicant)
		var id: String = applicant.id
		_chip(_flow(col), "cash", _money(applicant.wage) + " / day")
		_icon_button(col, "Hire · " + _money(applicant.wage), "crew", func(): _act("hire", {"id": id}), GREEN, CREAM)
		_icon_button(col, "Profile", "info", func(): _show_staff(id), PAPER, INK)

func _staff_heading(parent: Node, entry: Dictionary) -> void:
	var row = _row(parent, 12)
	_picture(row, "crew/" + str(entry.id), Vector2(84, 84))
	var col = _column(row, 3)
	_label(col, str(entry.name), 24, INK)
	_label(col, str(entry.role), 14, GREEN)
	var chips = _flow(col)
	_chip(chips, "skill", str(int(entry.skill)), PAPER, INK, "Skill")
	_chip(chips, "shield", str(int(entry.reliability)), PAPER, INK, "Reliability")
	_chip(chips, "heart", str(int(entry.kindness)), PAPER, INK, "Kindness")

func _build_menu() -> void:
	var active = Content.find(Content.RECIPES, str(model.state.recipe))
	var card = _column(_box(content, INK, 16, 14), 9)
	var current = _row(card, 12)
	_picture(current, "recipes/" + str(active.id), Vector2(96, 96))
	var title = _column(current, 4)
	_label(title, "ON THE MENU", 11, GOLD)
	_label(title, str(active.name), 24, CREAM)
	var prices = _row(card)
	_button(prices, "−", func(): _act("set_price", {"value": float(model.state.price) - 0.5}), GOLD, INK).custom_minimum_size.x = 62
	var price = _label(prices, _money(model.state.price) + " / bag", 30, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(prices, "+", func(): _act("set_price", {"value": float(model.state.price) + 0.5}), GOLD, INK).custom_minimum_size.x = 62
	var capacity: int = Content.TRUCKS[int(model.state.truck_tier)].capacity
	var room: int = maxi(0, capacity - int(model.state.stock))
	var stock = _column(_box(content, CREAM, 14, 13), 9)
	_chip(_flow(stock), "stock", "%d / %d bags" % [model.state.stock, capacity])
	var stock_row = _row(stock)
	for amount in [50, 100, 200]:
		var order: int = room if amount == 200 else mini(amount, room)
		var caption: String = "Fill · $%d" % order if amount == 200 else "+%d · $%d" % [order, order]
		var purchase = _button(stock_row, caption if room > 0 else "Full", func(): _act("buy_stock", {"amount": order}), PAPER, INK)
		purchase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		purchase.disabled = room == 0 or float(model.state.cash) < order
	var quality_row = _row(content)
	for quality in ["budget", "standard", "premium"]:
		var selected: bool = str(model.state.quality) == quality
		_button(quality_row, quality.capitalize(), func(): _act("set_quality", {"id": quality}), GOLD if selected else CREAM, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_disclosure(content, "Pricing & ingredients", "Higher prices reduce demand. Base supplies cost $1 per bag; recipe and quality extras are charged when sold. Budget lowers costs; premium improves reviews.")
	_section("RECIPE BOOK")
	var board = GridContainer.new()
	board.columns = 2
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("h_separation", 12)
	board.add_theme_constant_override("v_separation", 12)
	content.add_child(board)
	for recipe in Content.RECIPES:
		var item = _column(_box(board, CREAM, 15, 10), 7)
		item.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = recipe.id
		_picture(item, "recipes/" + id, Vector2(0, 114))
		_label(item, str(recipe.name), 21, INK, HORIZONTAL_ALIGNMENT_CENTER)
		var chips = _flow(item)
		_chip(chips, "cash", _money(recipe.cost))
		_chip(chips, "heart", "+%d" % recipe.appeal, PAPER, GREEN, "Recipe appeal")
		var locked: bool = id not in model.state.get("unlocked_recipes", [])
		var selected: bool = str(model.state.recipe) == id
		var button = _icon_button(item, "On menu" if selected else "%d rep" % recipe.unlock_rep if locked else "Serve this", "check" if selected else "rep" if locked else "recipe", func(): _act("set_recipe", {"id": id}), GOLD if selected else PAPER, INK)
		button.disabled = selected or locked
		_icon_button(item, "Details", "info", func(): _show_recipe(id), CREAM, INK)

func _build_garage() -> void:
	_section("YOUR EQUIPMENT")
	for gear in model.equipment_options():
		var col = _column(_box(content, CREAM, 16, 13), 9)
		var id: String = gear.id
		_picture(col, "equipment/" + id + "_" + str(gear.level), Vector2(0, 135))
		_label(col, str(gear.name), 25, INK)
		var chips = _flow(col)
		_chip(chips, id, "Level %d" % (int(gear.level) + 1))
		_chip(chips, "stock" if id == "truck" else "crew" if id == "stand" else "recipe", "%d %s" % [int(gear.capacity), "stored bags" if id == "truck" else "crew places" if id == "stand" else "bags / day"])
		if id != "stand": _meter(col, "Condition", float(gear.condition), RED if float(gear.condition) < 35 else GREEN)
		var actions = _row(col)
		if id != "stand":
			_icon_button(actions, "Service · " + _money(gear.service_cost), "wrench", func(): _act("service", {"id": id}), PAPER, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_icon_button(actions, "Details" if bool(gear.maxed) else "Upgrade", "info" if bool(gear.maxed) else "upgrade", func(): _show_gear(id), INK, CREAM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section("AUTO-PILOT")
	for policy in [["restock", "Auto stock", "stock"], ["service", "Auto service", "wrench"]]:
		var id: String = policy[0]
		var enabled: bool = model.state.policy.get(id, false)
		_icon_button(content, policy[1] + (" · ON" if enabled else " · OFF"), policy[2], func(): _act("set_policy", {"id": id, "enabled": not enabled}), GOLD if enabled else CREAM, INK)
	_disclosure(content, "How auto-pilot works", "Auto stock buys supplies before trading when there is room and cash. Auto service repairs worn equipment when the budget allows.")

func _build_company() -> void:
	var stats: Dictionary = model.state.get("stats", {})
	var top = _column(_box(content, INK, 16, 14), 10)
	_label(top, str(model.state.company), 28, CREAM)
	var metrics = _row(top)
	_header_stat(metrics, "bag", str(int(stats.get("total_sold", 0))), "Sold")
	_header_stat(metrics, "cash", _money(stats.get("total_sales", 0)), "Sales", GOLD)
	_chip(_flow(top), "map", "%d stops complete" % int(stats.get("completed_stops", 0)), INK, CREAM)
	_icon_button(content, "Season contracts & keepsakes", "star", _show_contracts, GOLD, INK)
	var bank = _column(_box(content, CREAM, 14, 14), 8)
	_chip(_flow(bank), "coin", "Debt: " + _money(model.state.debt))
	var buttons = _row(bank)
	_icon_button(buttons, "Borrow $500", "cash", func(): _confirm_action("Borrow $500?", "$2,000 credit limit. Interest is charged on trading days. Borrowing adds debt, not profit.", "loan", {"amount": 500}), PAPER, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon_button(buttons, "Repay $500", "check", func(): _act("repay", {"amount": 500}), PAPER, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section("MILESTONES · %d / %d" % [model.state.achievements.size(), Content.BADGES.size()])
	var board = GridContainer.new()
	board.columns = 3
	board.add_theme_constant_override("h_separation", 9)
	board.add_theme_constant_override("v_separation", 9)
	content.add_child(board)
	for badge in Content.BADGES:
		var earned: bool = model.state.achievements.has(str(badge.id))
		var cell = _column(_box(board, Color("e7eddf") if earned else CREAM, 14, 10), 7)
		cell.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_icon(cell, "star", 38, GREEN if earned else Color("b9b5a7"))
		_button(cell, str(badge.name), func(): _show_info(str(badge.name), str(badge.description), "star", "Earned" if earned else "Not earned yet"), CREAM if not earned else Color("e7eddf"), INK, 72).add_theme_font_size_override("font_size", 14)
	if not records.is_empty():
		var history = ""
		for record in records: history += "%s · Season %d · %s\n" % [record.get("company", "Company"), record.get("season", 1), _money(record.get("profit", 0))]
		_disclosure(content, "Past seasons", history.strip_edges())
	_icon_button(content, "Settings", "settings", _show_settings, INK, CREAM)
	_icon_button(content, "How to play", "info", _show_help, CREAM, INK)
	_button(content, "Credits & licenses", _show_credits, CREAM, INK)
	_button(content, "New company", _confirm_restart, CREAM, RED)

func _act(action: String, args: Dictionary = {}) -> void:
	if not has_run: return
	var result: Dictionary = model.act(action, args)
	if not bool(result.get("ok", false)):
		_notify(str(result.get("message", "That action is unavailable right now.")), RED)
		return
	_chime("sale_small" if action in ["decide", "dismiss_report"] else "click")
	_reviewing_season = action == "claim_contract" and str(model.state.phase) == "season_end"
	_save_game()
	_render()
	if action == "claim_contract":
		_pulse(65)
		_show_contract_reward(result.get("contract", {}))
	elif action == "crew_decide":
		_show_company_result(result.get("crew", {}), "A MOMENT WITH YOUR CREW")
	elif action == "decide" and str(model.state.phase) == "planning":
		call_deferred("_show_outcome")
	elif str(model.state.phase) == "planning" and not str(result.get("message", "")).is_empty(): _notify(str(result.message), GREEN)

func _show_event() -> void:
	if not has_run or str(model.state.phase) != "event": return
	var event: Dictionary = model.state.get("event", {})
	if event.is_empty(): return
	var col = _modal_page("A MOMENT ON THE CIRCUIT", str(event.title), false)
	_picture(col, "events/" + Presenter.event_art_key(event), Vector2(0, 86), true)
	_label(col, Presenter.event_teaser(event), 19, INK)
	var context = str(event.get("context", "trading"))
	_chip(_flow(col), "timer", "Temporary effects: next opening" if context == "travel" else "Temporary effects: today's trade", INK, GOLD)
	var choices: Array = event.get("choices", [])
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var box = _column(_box(col, PAPER, 15, 11), 8)
		var pick = index
		var button = _button(box, str(choice.label), func(): _act("decide", {"choice": pick}), INK, CREAM)
		button.name = "EventChoice_" + str(index)
		_effect_grid(box, Presenter.choice_effects(choice, context, model.state), true)
		var effects: Dictionary = choice.get("effects", {})
		var risk: Dictionary = choice.get("risk", {}).get("effects", {})
		var cost = maxf(0, -float(effects.get("cash", 0))) + maxf(0, -float(risk.get("cash", 0)))
		var portions = maxi(0, -int(effects.get("stock", 0))) + maxi(0, -int(risk.get("stock", 0)))
		button.disabled = cost > maxf(0, float(model.state.cash)) or portions > int(model.state.stock)
		if cost > maxf(0, float(model.state.cash)): _label(box, "Needs " + _money(cost) + " available", 13, RED)
		if portions > int(model.state.stock): _label(box, "Needs %d stocked bags" % portions, 13, RED)
	var details = str(event.body)
	for choice in choices: details += "\n\n" + str(choice.label) + "\n" + str(choice.detail)
	_disclosure(col, "Story & details", details)

func _show_report() -> void:
	if not has_run or str(model.state.phase) != "report": return
	var report: Dictionary = model.state.get("last_report", {})
	var col = _modal_page("DAY COMPLETE", "Closing time", false)
	var result = _row(col, 14)
	_icon(result, "cash", 52, GREEN if float(report.get("profit", 0)) >= 0 else RED)
	var hero = _column(result, 2)
	var profit: float = report.get("profit", 0)
	var profit_label = _label(hero, _money(profit), 44, GREEN if profit >= 0 else RED)
	if settings.motion:
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_method(func(value):
			if is_instance_valid(profit_label): profit_label.text = _money(value), 0.0, profit, 0.65)
		if profit >= 350:
			var celebration = Celebration.new()
			modal.add_child(celebration)
			celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label(hero, "PROFIT" if profit >= 0 else "LOSS", 12, MUTED)
	var chips = _flow(col)
	_chip(chips, "bag", "%d sold" % int(report.get("sold", 0)))
	_chip(chips, "rep", "%+.2f rep" % float(report.get("rep_change", 0)))
	var sales_view = SalesView.new()
	sales_view.name = "TradingResults"
	col.add_child(sales_view)
	sales_view.configure(report, not bool(settings.motion))
	var totals = _column(_box(col, PAPER, 14, 16), 9)
	_receipt(totals, "Sales", _money(report.get("revenue", 0)))
	_receipt(totals, "Cash change", _money(report.get("cash_delta", 0)))
	_icon_button(col, "CONTINUE", "arrow", func(): _act("dismiss_report"), RED, CREAM).name = "DismissReport"
	_build_report_insights(col, report)
	var outcome_cards = Presenter.outcome_effects(model.state)
	if not outcome_cards.is_empty():
		_label(col, "YOUR DECISION · WHAT CHANGED", 12, GREEN)
		_outcome_groups(col, outcome_cards)
	var details = _column(col, 10)
	_receipt(details, "Ingredients", "−" + _money(report.get("ingredients", 0)))
	_receipt(details, "Wages", "−" + _money(report.get("wages", 0)))
	_receipt(details, "Pitch & travel", "−" + _money(float(report.get("fees", 0)) - float(report.get("interest", 0))))
	if float(report.get("interest", 0)) > 0: _receipt(details, "Interest", "−" + _money(report.interest))
	if not is_zero_approx(float(report.get("event_cash", 0))): _receipt(details, "Decision", _money(report.event_cash))
	for line in report.get("summary", []): _label(details, str(line), 16, INK)
	details.visible = false
	var disclosure = _icon_button(col, "Story & receipt", "journal", func(): details.visible = not details.visible, PAPER, INK)
	disclosure.name = "ReportDetails"
	col.move_child(disclosure, details.get_index())

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
		var ready = 0
		for contract in model.contract_offers():
			if bool(contract.complete) and not bool(contract.claimed): ready += 1
		var rewards = _icon_button(col, "Collect season rewards · %d ready" % ready if ready > 0 else "Review season contracts", "star", _show_contracts, GOLD, INK)
		rewards.name = "SeasonContracts"
		if ready > 0: _label(col, "Collect your rewards before starting the next season.", 15, GREEN)
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
		_show_batch_result(float(model.state.minigame_boost) / 0.2)
		return
	if str(model.state.phase) != "planning" or str(model.state.booked_id).is_empty():
		_notify("Book a fair first. Then make your opening batch.", RED)
		return
	var col = _modal_page("HEAT · COAT · PACK", "Make it golden")
	_batch_game = BatchGame.new()
	col.add_child(_batch_game)
	_batch_game.configure(str(model.state.recipe), int(model.state.fryer_tier), not bool(settings.motion))
	_batch_game.feedback.connect(_game_feedback)
	_batch_game.completed.connect(func(score): _finish_batch.call_deferred(float(score)))
	_button(col, "Skip · no penalty", _close_modal, PAPER, INK)
	_minigame_playing = true

func _stop_minigame() -> void:
	if _minigame_playing and is_instance_valid(_batch_game): _batch_game.press_action()

func _show_settings() -> void:
	var col = _modal_page("MAKE YOURSELF AT HOME", "Settings")
	for entry in [["sound", "Game sound effects"], ["music", "Fairground music"], ["motion", "Scene & menu animation"], ["haptics", "Gentle phone vibrations"], ["guide", "First-season guide"]]:
		var key: String = entry[0]
		var toggle = CheckButton.new()
		toggle.mouse_filter = Control.MOUSE_FILTER_PASS
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
		["01  Book a stop", "Tap the circuit map to explore a fair. Plan three future stops in the calendar for free; booking pays the fair fee and fuel up front."],
		["02  Prepare", "Menu sets your price, recipe and supplies. Crew adds capacity and skill. Garage keeps your truck and fryer healthy."],
		["03  Open the stand", "One tap advances a trading day. Make the event decision, then read the daily receipt. Time never advances while you browse."],
		["04  Learn the crowd", "Match recipes to local tastes. Higher prices can lose customers. Reviews, service and reliability shape reputation."],
		["05  Leave a story", "Get to know your crew, support friendships and discuss wages. People and towns remember earlier decisions. Your company carries on next season."],
		["A little hands-on help", "Activities offer repairs, order memory and spot-the-hazard jobs. Play yourself, delegate to available crew, or pay a specialist. They're optional; costs and rewards appear before you choose."],
		["Make the stand your own", "Complete three contracts each season, then collect cash and permanent decorations. Upgrades, crew, weather and keepsakes appear on your stand."],
		["Need a second chance?", "Borrow working capital in Company, or run a $25 roadside pop-up. Staff and bigger machines are optional at the start."]]:
		_label(col, entry[0], 20, GREEN)
		_label(col, entry[1], 17, INK)
	_button(col, "I'M READY", _close_modal, RED, CREAM)

func _show_credits() -> void:
	var col = _modal_page("MADE FOR THE LONG WAY ROUND", "Credits & licenses")
	_label(col, "Golden Hour: On the Circuit\nIdea #4 · Demo 0.3.0", 22, INK)
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
	var panel = _box(margin, CREAM, 23, 18)
	var list = ScrollContainer.new()
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.follow_focus = true
	panel.add_child(list)
	var col = _column(list, 15)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if close_allowed:
		var row = _row(col)
		var label = _label(row, kicker, 11, VIOLET)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row, "Close", _close_modal, PAPER, INK, 44).custom_minimum_size.x = 72
	else: _label(col, kicker, 11, VIOLET)
	_label(col, title, 30, INK)
	if settings.motion:
		panel.modulate.a = 0
		create_tween().tween_property(panel, "modulate:a", 1.0, 0.16)
	return col

func _close_modal() -> void:
	_minigame_playing = false
	_batch_game = null
	_activity_busy = false
	_activity_game = null
	_activity_offer_id = ""
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
	# Let a surrounding ScrollContainer receive finger drags through the card.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style = _style(fill, radius, Color("304760") if fill == INK else Color("e6d7bb"))
	if radius > 10:
		style.shadow_color = Color(0.10, 0.17, 0.24, 0.17)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 3)
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
	# Godot cancels the pending button press when its ScrollContainer begins a drag.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
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
	var raised = _style(fill, 13, fill.lightened(0.18))
	raised.shadow_color = fill.darkened(0.32)
	raised.shadow_size = 0
	raised.shadow_offset = Vector2(0, 3)
	raised.border_width_bottom = 4
	raised.border_color = fill.darkened(0.19)
	button.add_theme_stylebox_override("normal", raised)
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.06), 11))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.12), 13, fill.darkened(0.25), 2))
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


func _art(key: String) -> Texture2D:
	if not _art_cache.has(key):
		var path = "res://assets/ui/" + key + ".svg"
		_art_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _art_cache[key]

func _picture(parent: Node, key: String, dimensions: Vector2, crop: bool = false) -> TextureRect:
	var art = TextureRect.new()
	art.texture = _art(key)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if crop else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = dimensions
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _icon(parent: Node, key: String, pixels: int = 24, tint: Color = GREEN) -> TextureRect:
	var icon = _picture(parent, "icons/" + key, Vector2(pixels, pixels))
	icon.modulate = tint
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon

func _icon_button(parent: Node, text: String, key: String, callback: Callable, fill: Color = INK, ink: Color = CREAM) -> Button:
	var button = _button(parent, text, callback, fill, ink)
	button.icon = _art("icons/" + key)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 21)
	button.add_theme_constant_override("h_separation", 8)
	for state_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]: button.add_theme_color_override(state_name, ink)
	button.add_theme_color_override("icon_disabled_color", MUTED)
	return button

func _flow(parent: Node) -> HFlowContainer:
	var flow = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 7)
	flow.add_theme_constant_override("v_separation", 6)
	parent.add_child(flow)
	return flow

func _chip(parent: Node, key: String, text: String, fill: Color = PAPER, ink: Color = INK, hint: String = "") -> void:
	var panel = _box(parent, fill, 9, 7)
	panel.tooltip_text = hint
	var row = _row(panel, 5)
	_icon(row, key, 18, ink)
	_label(row, text, 13, ink)

func _header_stat(parent: Node, key: String, value: String, caption: String, color: Color = CREAM) -> void:
	var block = _column(parent, 1)
	var line = _row(block, 6)
	_icon(line, key, 22, color)
	_label(line, value, 23, color)
	_label(block, caption, 10, Color("b9cec4"))

func _disclosure(parent: Node, title: String, text: String) -> void:
	var detail = Label.new()
	var button = _icon_button(parent, title, "info", func(): detail.visible = not detail.visible, PAPER, INK)
	button.tooltip_text = "Show or hide details"
	parent.add_child(detail)
	detail.text = text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", MUTED)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.visible = false

func _show_info(title: String, body: String, icon: String = "info", status: String = "") -> void:
	var col = _modal_page(status.to_upper() if not status.is_empty() else "DETAILS", title)
	_icon(col, icon, 50, GREEN)
	_label(col, body, 19, INK)

func _show_entry(entry: Dictionary) -> void:
	var col = _modal_page("DAY %d" % int(entry.get("day", 1)), str(entry.get("title", "On the circuit")))
	_label(col, str(entry.get("text", "")), 19, INK)

func _show_history() -> void:
	var col = _modal_page("YOUR STORY", "Company journal")
	var entries: Array = model.state.get("journal", [])
	for index in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		_label(col, "Day %d · %s" % [entry.get("day", 1), entry.get("title", "")], 21, GREEN)
		_label(col, str(entry.get("text", "")), 17, INK)

func _show_venue(id: String) -> void:
	var venue = Content.find(Content.VENUES, id)
	var col = _modal_page(str(venue.town), str(venue.name))
	_picture(col, "venues/" + id, Vector2(0, 155), true)
	_label(col, Presenter.venue_tagline(venue), 21, VIOLET)
	var chips = _flow(col)
	_chip(chips, "recipe", "Favorite: " + str(venue.flavor).capitalize())
	_chip(chips, "rep", "%d reputation" % venue.min_rep)
	_chip(chips, "cash", _money(venue.fee) + " / day")
	_chip(chips, "heart", "%+d town goodwill" % int(model.state.relationships.get(str(venue.town), 0)))
	var planned: Array = model.state.get("circuit", {}).get("itinerary", [])
	var is_planned = id in planned
	var plan = _icon_button(col, "Remove from route" if is_planned else "Add to route · no payment", "calendar", func():
		_act("unplan_stop" if is_planned else "plan_stop", {"id": id})
		_show_calendar(), PAPER, INK)
	plan.disabled = str(model.state.phase) != "planning" or id in model.state.completed or id == str(model.state.booked_id)
	for offer in model.venue_offers():
		if str(offer.id) != id: continue
		var book = _icon_button(col, "Book · " + _money(offer.total_cost), "map", func(): _confirm_booking(id), GREEN, CREAM)
		book.disabled = not bool(offer.can_book)
		if not bool(offer.can_book): _label(col, str(offer.reason), 13, MUTED)
	_disclosure(col, "About this fair", str(venue.description))

func _show_staff(id: String) -> void:
	var person: Dictionary = Content.find(Content.STAFF, id)
	var employed = false
	for employee in model.state.staff:
		if str(employee.id) == id:
			person = employee
			employed = true
	var col = _modal_page("YOUR CREW" if employed else "STAFF CARD", str(person.name))
	var banner = _column(_box(col, INK, 18, 10), 3)
	_picture(banner, "decor/light_strand", Vector2(0, 18))
	var portrait = _row(banner, 12)
	_picture(portrait, "crew/" + id, Vector2(126, 134))
	var identity = _column(portrait, 7)
	_icon(identity, _role_icon(str(person.role)), 38, GOLD)
	_label(identity, str(person.role), 21, CREAM)
	_label(identity, Presenter.staff_note(person), 13, GOLD)
	var skills = _row(col, 8)
	_stat_card(skills, "proficiency", "Skill", float(person.skill), VIOLET)
	_stat_card(skills, "punctuality", "Reliable", float(person.reliability), GREEN)
	_stat_card(skills, "hospitality", "Kindness", float(person.kindness), RED)
	if employed:
		var personality: Dictionary = model.staff_personality(id)
		_chip(_flow(col), "mood", str(personality.get("mood", "Settling in")), PAPER, GREEN)
		for friend in personality.get("friends", []):
			var friendship = _row(_box(col, Color("ece5f6"), 12, 8), 8)
			_picture(friendship, "crew/" + str(friend.id), Vector2(42, 42))
			_label(friendship, str(friend.name) + " · " + str(friend.get("label", "Getting to know each other")), 14, VIOLET)
		var mood = _row(col, 8)
		_stat_card(mood, "mood", "Morale", float(person.morale), GREEN, true)
		_stat_card(mood, "bond", "Loyalty", float(person.loyalty), VIOLET, true)
		_chip(_flow(col), "cash", _money(person.wage) + " / trading day", INK, GOLD)
		var actions = _row(col)
		_icon_button(actions, "Train · $120", "train", func(): _act("train", {"id": id}), VIOLET, CREAM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.get_child(0).disabled = int(person.trained) >= 3
		_icon_button(actions, "Paid day off", "rest", func(): _act("rest", {"id": id}), GREEN, CREAM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.get_child(1).disabled = int(person.rested_day) == int(model.state.day)
		_disclosure(col, "Care & training", "Training improves skill, reliability and morale (up to three sessions). A day off restores morale; wages are still paid, and they do not work that day.")
	else:
		_chip(_flow(col), "cash", _money(person.wage) + " / trading day", INK, GOLD)
		_icon_button(col, "Hire · " + _money(person.wage) + " now", "crew", func(): _act("hire", {"id": id}), GREEN, CREAM)
	_disclosure(col, "Their story", str(person.description))
	_disclosure(col, "What do these stats do?", "Skill helps your crew serve more bags. Reliability reduces missed shifts. Kindness improves reviews. Morale affects productivity. Hiring costs one day's wage; daily wages are paid on trading days.")
	if employed: _button(col, "Let them go", func(): _confirm_action("Let " + str(person.name) + " go?", "They leave your roster.", "fire", {"id": id}), PAPER, RED)

func _show_recipe(id: String) -> void:
	var recipe = Content.find(Content.RECIPES, id)
	var col = _modal_page("RECIPE CARD", str(recipe.name))
	_picture(col, "recipes/" + id, Vector2(0, 185))
	var chips = _flow(col)
	_chip(chips, "cash", _money(recipe.cost) + " / bag base")
	_chip(chips, "heart", "+%d recipe appeal" % recipe.appeal)
	var locked: bool = id not in model.state.get("unlocked_recipes", [])
	if locked: _chip(chips, "rep", "%d rep to unlock" % recipe.unlock_rep)
	else: _icon_button(col, "Serve this recipe", "recipe", func(): _act("set_recipe", {"id": id}), GREEN, CREAM)
	_disclosure(col, "The recipe story", str(recipe.description))

func _show_gear(id: String) -> void:
	for gear in model.equipment_options():
		if str(gear.id) != id: continue
		var col = _modal_page("EQUIPMENT", str(gear.name))
		_picture(col, "equipment/" + id + "_" + str(gear.level), Vector2(0, 140))
		_chip(_flow(col), id, "YOUR CURRENT EQUIPMENT", INK, GOLD)
		if not bool(gear.maxed):
			_label(col, "NEXT: " + str(gear.next_name), 22, GREEN)
			_picture(col, "equipment/" + id + "_" + str(int(gear.level) + 1), Vector2(0, 140))
			var catalog: Array = Content.TRUCKS if id == "truck" else Content.FRYERS if id == "fryer" else Content.STANDS
			var units: String = "stored bags" if id == "truck" else "crew places" if id == "stand" else "bags / day"
			_chip(_flow(col), "upgrade", "%d to %d %s" % [int(gear.capacity), int(catalog[int(gear.level) + 1].capacity), units], PAPER, GREEN)
			_disclosure(col, "Upgrade details", str(gear.description) + "\n\n" + str(catalog[int(gear.level) + 1].description))
			_icon_button(col, "Buy upgrade · " + _money(gear.next_cost), "upgrade", func(): _confirm_action("Upgrade " + id + "?", str(gear.next_name) + " · " + _money(gear.next_cost), "upgrade", {"id": id}), RED, CREAM)
		else:
			_chip(_flow(col), "check", "Fully upgraded")
			_disclosure(col, "Equipment story", str(gear.description))

func _role_icon(role: String) -> String:
	var value = role.to_lower()
	if "fryer" in value or "cook" in value: return "fryer_role"
	if "mechanic" in value: return "mechanic"
	if "driver" in value: return "driver"
	if "runner" in value or "stock" in value: return "runner"
	if "decorator" in value or "barker" in value: return "creative"
	return "counter"

func _staff_mini_stats(parent: Node, person: Dictionary) -> void:
	var row = _row(parent, 6)
	for stat in [["proficiency", "skill", VIOLET], ["punctuality", "reliability", GREEN], ["hospitality", "kindness", RED]]:
		var cell = _column(row, 2)
		_icon(cell, stat[0], 19, stat[2])
		_label(cell, str(int(person[stat[1]])), 15, INK, HORIZONTAL_ALIGNMENT_CENTER)

func _stat_card(parent: Node, icon: String, label: String, value: float, tint: Color, compact: bool = false) -> void:
	var panel = _box(parent, tint.lightened(0.90), 13, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col = _column(panel, 3)
	_icon(col, icon, 22 if compact else 29, tint)
	_label(col, "%d" % int(value), 24 if compact else 31, tint, HORIZONTAL_ALIGNMENT_CENTER)
	_label(col, label, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var pips = _row(col, 3)
	for i in range(5):
		var pip = ColorRect.new()
		pip.color = tint if value >= (i + 1) * 20 else tint.lightened(0.75)
		pip.custom_minimum_size = Vector2(2, 5)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)

func _effect_grid(parent: Node, effects: Array, prediction: bool = false) -> void:
	var certain: Array = []
	var risks: Array = []
	for effect in effects:
		if prediction and str(effect.get("source", "")) == "risk": risks.append(effect)
		else: certain.append(effect)
	for group in [certain, risks]:
		if group.is_empty(): continue
		var target = parent
		if group == risks:
			target = _column(_box(parent, Color("fff0c9"), 12, 8), 6)
			_chip(_flow(target), "dice", "%d%% CHANCE" % roundi(float(group[0].get("chance", 0)) * 100), GOLD, INK)
		var grid = GridContainer.new()
		grid.columns = 2 if group.size() > 1 else 1
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 7)
		grid.add_theme_constant_override("v_separation", 7)
		target.add_child(grid)
		for effect in group:
			var tone = str(effect.get("tone", "neutral"))
			if str(effect.get("duration", "")) == "No effect":
				tone = "neutral"
			elif tone == "risk":
				var amount = float(effect.get("amount", 0))
				var beneficial = amount < 0 if str(effect.get("key", "")) == "delay" else amount > 0
				tone = "good" if beneficial else "bad" if amount != 0 else "neutral"
			var tint = RED if tone == "bad" else GREEN if tone == "good" else MUTED
			var tile = _box(grid, tint.lightened(0.93), 10, 7)
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile.tooltip_text = str(effect.get("detail", ""))
			var col = _column(tile, 2)
			var top = _row(col, 5)
			_icon(top, str(effect.get("icon", "info")), 19, tint)
			var value = _label(top, str(effect.get("value", "")), 19, tint)
			value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label(col, str(effect.get("title", "Effect")), 13, INK)
			if str(effect.get("key", "")) == "quality":
				_label(col, "%+.2f review points" % (float(effect.get("amount", 0)) * 2.5), 12, tint)
			var footer = _row(col, 2)
			var duration = _label(footer, str(effect.get("duration", "")), 11, MUTED)
			duration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			duration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var detail = _label(col, str(effect.get("detail", "")), 13, INK)
			detail.name = "EffectDetail"
			detail.visible = false
			var explain = Button.new()
			explain.mouse_filter = Control.MOUSE_FILTER_PASS
			explain.name = "EffectExplain"
			explain.icon = _art("icons/info")
			explain.expand_icon = true
			explain.add_theme_constant_override("icon_max_width", 18)
			explain.add_theme_color_override("icon_normal_color", tint)
			explain.add_theme_color_override("icon_hover_color", tint)
			explain.custom_minimum_size = Vector2(36, 44)
			explain.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, 8))
			explain.add_theme_stylebox_override("hover", _style(tint.lightened(0.85), 8))
			explain.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 8, GOLD, 2))
			explain.tooltip_text = "Explain this effect"
			explain.pressed.connect(func(): detail.visible = not detail.visible)
			footer.add_child(explain)

func _build_active_effects() -> void:
	var effects: Array = Presenter.active_effects(model.state)
	if effects.is_empty():
		if not model.state.get("last_outcome", {}).is_empty():
			_icon_button(content, "Last decision · what changed", "info", _show_outcome, CREAM, INK)
		return
	var col = _column(_box(content, Color("e4f3e9"), 17, 11), 7)
	var row = _row(col)
	_icon(row, "timer", 24, GREEN)
	_label(row, "FOR YOUR NEXT OPENING", 12, GREEN)
	_effect_grid(col, effects)
	if not model.state.get("last_outcome", {}).is_empty():
		_icon_button(col, "Last decision", "info", _show_outcome, CREAM, INK)

func _show_outcome() -> void:
	var outcome: Dictionary = model.state.get("last_outcome", {})
	if outcome.is_empty(): return
	var col = _modal_page("DECISION RESOLVED", str(outcome.get("choice_label", "Here's what changed")))
	var risk = bool(outcome.get("risk_happened", false))
	_chip(_flow(col), "dice" if risk else "check", "The risk happened" if risk else "Applied to your company", GOLD if risk else GREEN, INK if risk else CREAM)
	_outcome_groups(col, Presenter.outcome_effects(model.state))
	_disclosure(col, "The full story", str(outcome.get("result", "")))
	_icon_button(col, "CONTINUE", "arrow", _close_modal, RED, CREAM)

func _finish_batch(score: float) -> void:
	if not _minigame_playing: return
	_minigame_playing = false
	var result: Dictionary = model.act("minigame", {"score": score})
	if not bool(result.get("ok", false)):
		_notify(str(result.get("message", "Batch already finished.")), RED)
		return
	_save_game()
	_render()
	_show_batch_result(score)

func _outcome_groups(parent: Node, cards: Array) -> void:
	var groups: Dictionary = {}
	for card in cards:
		var key = str(card.get("event_title", "Decision")) + "\n" + str(card.get("choice_label", ""))
		if not groups.has(key): groups[key] = []
		groups[key].append(card)
	for key in groups:
		var first: Dictionary = groups[key][0]
		_label(parent, str(first.get("event_title", "Decision")), 19, VIOLET)
		_label(parent, str(first.get("choice_label", "")), 14, MUTED)
		_effect_grid(parent, groups[key])

func _show_batch_result(score: float) -> void:
	var grade = "perfect" if score >= 0.9 else "great" if score >= 0.65 else "good"
	var col = _modal_page("YOUR OPENING BATCH", "Golden touch!" if grade == "perfect" else "Fresh from the fryer")
	_picture(col, "decor/reward_" + grade, Vector2(0, 155))
	_label(col, "%d%%" % roundi(score * 100), 52, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_label(col, ("RUSTIC" if score < 0.35 else grade.to_upper()) + " BATCH", 17, VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
	var earned = Presenter.active_effects(model.state).filter(func(effect): return str(effect.get("key", "")) == "practice")
	_effect_grid(col, earned)
	if earned.is_empty(): _label(col, "No bonus this time. Your next batch is a fresh chance.", 17, MUTED)
	_icon_button(col, "BACK TO YOUR STAND", "arrow", _close_modal, RED, CREAM)
	_chime("batch_finish")
	if score >= 0.9: _pulse(45)
	if settings.motion:
		var sparkles = Celebration.new()
		modal.add_child(sparkles)
		sparkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _game_feedback(kind: String) -> void:
	_chime(kind)
	if kind == "batch_perfect": _pulse(28)

func _pulse(milliseconds: int = 35) -> void:
	if test_mode or not bool(settings.get("haptics", true)): return
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(milliseconds, 0.3)

func _build_company_shortcuts(parent: Node) -> void:
	var row = _row(parent, 9)
	var opportunities = model.activity_offers().size()
	_icon_button(row, "Activities · %d" % opportunities, "wrench", _show_activities, PAPER, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ready = 0
	for contract in model.contract_offers():
		if bool(contract.complete) and not bool(contract.claimed): ready += 1
	_icon_button(row, "Contracts" + (" · %d ready" % ready if ready else ""), "star", _show_contracts, GOLD if ready else CREAM, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var moments: Array = model.crew_moments()
	if not moments.is_empty():
		var moment: Dictionary = moments[0]
		var panel = _row(_box(parent, Color("ece5f6"), 13, 8), 8)
		_picture(panel, "crew/" + str(moment.staff_ids[0]), Vector2(52, 52))
		_icon_button(panel, str(moment.title), "crew", func(): _show_crew_moment(str(moment.id)), Color("ece5f6"), VIOLET).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _show_activities() -> void:
	var col = _modal_page("LITTLE JOBS, REAL DIFFERENCE", "At your stand")
	var offers: Array = model.activity_offers()
	if offers.is_empty():
		_icon(col, "check", 70, GREEN)
		_label(col, "All caught up", 26, INK)
		_label(col, "New fairs and worn equipment bring new jobs. Your opening batch is available on trading days.", 18, MUTED)
	for offer in offers:
		var card = _column(_box(col, PAPER, 15, 11), 7)
		var heading = _row(card, 9)
		_icon(heading, _activity_icon(str(offer.kind)), 42, VIOLET)
		_label(heading, str(offer.title), 22, INK)
		_label(card, str(offer.reward_hint), 15, MUTED)
		var id = str(offer.id)
		_icon_button(card, "Choose how", "arrow", func(): _show_activity_choice(id), INK, CREAM).name = "ActivityOffer_" + str(offer.kind) + "_" + str(offer.target)

func _activity_icon(kind: String) -> String:
	return "wrench" if kind == "repair" else "bag" if kind == "orders" else "shield"

func _activity_offer(id: String) -> Dictionary:
	for offer in model.activity_offers():
		if str(offer.id) == id: return offer
	return {}

func _show_activity_choice(id: String) -> void:
	var offer: Dictionary = _activity_offer(id)
	if offer.is_empty():
		_notify("That job is already handled or no longer available.", MUTED)
		return
	var col = _modal_page("YOUR CALL", str(offer.title))
	var hero = _column(_box(col, INK, 18, 16), 9)
	_icon(hero, _activity_icon(str(offer.kind)), 64, GOLD)
	_label(hero, str(offer.description), 20, CREAM)
	_label(col, str(offer.reward_hint), 18, GREEN)
	var self_cost = float(offer.self_cost)
	var play = _icon_button(col, "Handle it yourself" + (" · " + _money(self_cost) if self_cost else " · free"), "skill", func(): _start_activity(id), GOLD, INK)
	play.name = "ActivitySelf"
	play.disabled = not bool(offer.can_self)
	var delegate_label = "No available crew" if str(offer.delegate_id).is_empty() else "Ask " + str(offer.delegate_name) + (" · " + _money(offer.delegate_cost) if float(offer.delegate_cost) else "")
	var delegate = _icon_button(col, delegate_label, "crew", func(): _resolve_activity(id, "delegate"), GREEN, CREAM)
	delegate.name = "ActivityDelegate"
	delegate.disabled = not bool(offer.can_delegate)
	_label(col, str(offer.delegate_hint) if not str(offer.delegate_id).is_empty() else "Hire an available crew member to delegate this job.", 14, MUTED)
	var help = _icon_button(col, "Hire a specialist · " + _money(offer.help_cost), "cash", func(): _resolve_activity(id, "help"), INK, CREAM)
	help.name = "ActivityHelp"
	help.disabled = not bool(offer.can_help)
	_label(col, "Optional. Leaving this sheet does not spend money or use the attempt.", 13, MUTED)
	if not str(offer.reason).is_empty(): _label(col, str(offer.reason), 14, RED)

func _start_activity(id: String) -> void:
	var offer = _activity_offer(id)
	if offer.is_empty() or not bool(offer.can_self): return
	var col = _modal_page("A LITTLE HANDS-ON HELP", str(offer.title))
	_activity_game = ActivityGame.new()
	_activity_game.name = "ContextActivity"
	col.add_child(_activity_game)
	_activity_game.configure(str(offer.kind), int(offer.seed), not bool(settings.motion), int(offer.difficulty))
	_activity_game.feedback.connect(_game_feedback)
	_activity_game.completed.connect(func(score): _finish_activity.call_deferred(id, float(score)))
	_activity_offer_id = id
	_activity_busy = true
	if float(offer.self_cost) > 0: _label(col, "Parts: " + _money(offer.self_cost) + " when you finish, even if the repair is unsuccessful.", 13, MUTED)
	_button(col, "Leave for later", _close_modal, PAPER, INK)

func _finish_activity(id: String, score: float) -> void:
	if not _activity_busy or id != _activity_offer_id: return
	_activity_busy = false
	_resolve_activity(id, "self", score)

func _resolve_activity(id: String, mode: String, score: float = 0) -> void:
	var result: Dictionary = model.act("activity", {"id": id, "mode": mode, "score": score})
	if not bool(result.get("ok", false)):
		_close_modal()
		_notify(str(result.get("message", "This job is no longer available.")), RED)
		return
	_save_game()
	_render()
	_chime("batch_finish")
	if float(result.get("activity", {}).get("score", 0)) >= 0.85: _pulse(50)
	_show_company_result(result.get("activity", {}), "JOB COMPLETE")

func _show_company_result(record: Dictionary, heading: String) -> void:
	var col = _modal_page(heading, str(record.get("title", "A little progress")))
	if record.has("score"):
		var score = float(record.score)
		_picture(col, "decor/reward_" + ("perfect" if score >= 0.9 else "great" if score >= 0.65 else "good"), Vector2(0, 122))
		_label(col, "%d%%" % roundi(score * 100), 42, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		_label(col, {"self":"YOUR RESULT", "delegate":"YOUR CREW'S RESULT", "help":"SPECIALIST RESULT"}.get(str(record.get("mode", "self")), "RESULT"), 12, VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
	_label(col, str(record.get("message", "Here's what changed.")), 18, INK)
	_effect_grid(col, _company_effect_cards(record.get("effects", [])))
	_icon_button(col, "BACK TO THE CIRCUIT", "arrow", _close_modal, RED, CREAM)

func _company_effect_cards(effects: Array) -> Array:
	var cards: Array = []
	var names = {"cash":"Company cash", "truck":"Truck condition", "fryer":"Fryer condition", "rep":"Reputation", "demand":"Customer appeal", "morale":"Morale", "loyalty":"Loyalty", "friendship":"Friendship", "wage":"Daily wage", "skill":"Skill"}
	var icons = {"cash":"cash", "truck":"truck", "fryer":"fryer", "rep":"rep", "demand":"star", "morale":"mood", "loyalty":"bond", "friendship":"crew", "wage":"cash", "skill":"skill"}
	for effect in effects:
		var key = str(effect.get("key", ""))
		var amount = float(effect.get("value", 0))
		var value = ("+" if amount > 0 else "−" if amount < 0 else "") + _money(absf(amount)) if key in ["cash", "wage"] else "%+.1f%% appeal" % (amount * 100) if key == "demand" else "%+.2f points" % amount
		var title = str(names.get(key, key.capitalize()))
		if effect.has("name"): title = str(effect.name) + " · " + title
		cards.append({"key":key, "icon":icons.get(key, "info"), "title":title, "value":value, "amount":amount,
			"tone":"neutral" if key == "wage" else "good" if amount > 0 else "bad" if amount < 0 else "neutral", "duration":"Every trading day" if key == "wage" else "Next trading day" if key == "demand" else "Immediate" if key == "cash" else "Permanent",
			"detail":"Actual change: %.2f → %.2f." % [float(effect.get("before", 0)), float(effect.get("after", 0))], "source":"result"})
	return cards

func _show_contracts() -> void:
	if str(model.state.phase) == "season_end": _reviewing_season = true
	var col = _modal_page("SEASON %d NOTICEBOARD" % int(model.state.season), "Something to aim for")
	for contract in model.contract_offers():
		var claimed = bool(contract.claimed)
		var ready = bool(contract.complete) and not claimed
		var card = _column(_box(col, Color("e4f3e9") if ready else PAPER, 15, 12), 8)
		var row = _row(card, 9)
		_icon(row, str(contract.icon), 34, GREEN if ready or claimed else VIOLET)
		_label(row, str(contract.title), 22, INK)
		_label(card, str(contract.get("description", _contract_objective(contract))), 15, MUTED)
		var progress = float(contract.progress)
		var goal = float(contract.goal)
		var metric = str(contract.metric)
		var progress_text = _money(progress) if metric == "profit" else "%.2f" % progress if metric == "reputation" else str(floori(progress))
		_receipt(card, "Progress", "%s / %s" % [progress_text, _money(goal) if metric == "profit" else str(roundi(goal))])
		var bar = ProgressBar.new()
		bar.value = progress / maxf(goal, 1) * 100
		bar.show_percentage = false
		bar.custom_minimum_size.y = 12
		bar.add_theme_stylebox_override("background", _style(LINE, 6))
		bar.add_theme_stylebox_override("fill", _style(GREEN if ready or claimed else GOLD, 6))
		card.add_child(bar)
		var rewards = _flow(card)
		_chip(rewards, "cash", _money(contract.cash_reward))
		_chip(rewards, "star", str(contract.decoration_name))
		var id = str(contract.id)
		var button = _icon_button(card, "Collected" if claimed else "Collect reward" if ready else "Keep going", "check" if claimed else "star", func(): _act("claim_contract", {"id": id}), GREEN if ready else CREAM, CREAM if ready else INK)
		button.name = "ContractClaim_" + id
		button.disabled = not ready or str(model.state.phase) not in ["planning", "season_end"]
	var decorations: Array = model.state.get("circuit", {}).get("decorations", [])
	if not decorations.is_empty():
		_label(col, "ON YOUR STAND · %d KEEPSAKES" % decorations.size(), 12, VIOLET)
		var chips = _flow(col)
		for decoration in decorations: _chip(chips, "star", str(decoration).replace("_", " ").capitalize())
	_disclosure(col, "How contracts work", "Progress begins when this season's contracts arrive. Collect each reward once; decorations stay with your company. New seasons bring new goals. Planned stops do not count as completed visits.")
	if str(model.state.phase) == "season_end": _icon_button(col, "BACK TO YOUR SEASON", "arrow", _show_ending, INK, CREAM)

func _contract_objective(contract: Dictionary) -> String:
	return {"sold":"Serve bags of donuts this season.", "stops":"Complete fairground stops.", "activities":"Complete optional jobs yourself or with help.", "profit":"Earn operating profit from trading.", "reputation":"Earn positive reputation changes.", "training":"Invest in staff training.", "perfect":"Earn great mini-game results.", "upgrades":"Improve a piece of equipment."}.get(str(contract.metric), "Keep building your company.")

func _show_contract_reward(contract: Dictionary) -> void:
	var col = _modal_page("CONTRACT COMPLETE", str(contract.get("title", "Well earned")))
	_picture(col, "decor/reward_perfect", Vector2(0, 132))
	_label(col, "+" + _money(contract.get("cash_reward", 0)), 42, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_label(col, str(contract.get("decoration_name", "A new keepsake")), 24, VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
	var world = WorldView.new()
	col.add_child(world)
	world.configure(model.state, not bool(settings.motion))
	_icon_button(col, "SEE YOUR CONTRACTS", "star", _show_contracts, GOLD, INK)
	if settings.motion:
		var celebration = Celebration.new()
		modal.add_child(celebration)
		celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_itinerary(parent: Node, compact: bool = false) -> void:
	var itinerary: Array = model.itinerary()
	if itinerary.is_empty():
		if not compact: _label(parent, "Tap a map stop and add it to your route. Plan up to three stops ahead.", 17, MUTED)
		return
	for index in range(mini(1, itinerary.size()) if compact else itinerary.size()):
		var stop: Dictionary = itinerary[index]
		var card = _column(_box(parent, Color("ece5f6"), 13, 10), 6)
		_label(card, "%d · %s" % [index + 1, str(stop.name)], 21, INK)
		_chip(_flow(card), "calendar", "Travel %d · trade %d–%d" % [int(stop.travel_day), int(stop.start_day), int(stop.end_day)], CREAM, VIOLET)
		_label(card, str(stop.reason), 13, MUTED if bool(stop.fits) else RED)
		var id = str(stop.id)
		if not compact:
			var actions = _row(card, 6)
			for entry in [[-1, "Move up"], [1, "Move down"]]:
				var direction = int(entry[0])
				var reorder = _button(actions, str(entry[1]), func():
					_act("move_stop", {"id": id, "direction": direction})
					_show_calendar(), CREAM, INK)
				reorder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				reorder.disabled = str(model.state.phase) != "planning" or index + direction < 0 or index + direction >= itinerary.size()
			var remove = _button(card, "Remove from route", func():
				_act("unplan_stop", {"id": id})
				_show_calendar(), PAPER, RED)
			remove.disabled = str(model.state.phase) != "planning"
		for offer in model.venue_offers():
			if str(offer.id) != id: continue
			var book = _icon_button(card, "Book this stop · " + _money(offer.total_cost), "map", func(): _confirm_booking(id), INK, CREAM)
			book.disabled = not bool(offer.can_book)

func _show_calendar() -> void:
	var col = _modal_page("YOUR ROUTE, YOUR PACE", "Season %d · 36 days" % int(model.state.season))
	_label(col, "Sketch your next stops. Payment happens when you book.", 16, MUTED)
	var itinerary: Array = model.itinerary()
	var grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	col.add_child(grid)
	var current_end = int(model.state.day) - 1
	var venue = _venue()
	if not venue.is_empty(): current_end += int(venue.days) - int(model.state.venue_day)
	for day in range(1, 37):
		var fill = CREAM
		var ink = INK
		var hint = "Available"
		if day < int(model.state.day):
			fill = LINE
			hint = "Past day"
		elif day <= current_end:
			fill = GREEN
			ink = CREAM
			hint = str(venue.get("name", "Booked"))
		for stop in itinerary:
			if day == int(stop.travel_day):
				fill = INK
				ink = CREAM
				hint = "Travel to " + str(stop.name)
			elif day >= int(stop.start_day) and day <= int(stop.end_day):
				fill = VIOLET
				ink = CREAM
				hint = "Planned: " + str(stop.name)
		if day == int(model.state.day):
			fill = GOLD
			ink = INK
		var cell = _box(grid, fill, 10, 4)
		cell.custom_minimum_size.y = 44
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = "Day %d · %s" % [day, hint]
		_label(cell, str(day), 18, ink, HORIZONTAL_ALIGNMENT_CENTER)
	var legend = _flow(col)
	_chip(legend, "calendar", "Today", GOLD, INK)
	_chip(legend, "check", "Booked", GREEN, CREAM)
	_chip(legend, "map", "Planned", VIOLET, CREAM)
	_chip(legend, "truck", "Travel", INK, CREAM)
	_build_itinerary(col)
	_disclosure(col, "Planning notes", "Travel uses one day. Fair fees cover the whole stay. Planned stops are estimates; reputation, cash and remaining season days are checked when booking. Plans can be rearranged freely. Other activities or roadside trading can shift these dates.")

func _build_crew_moments(parent: Node) -> void:
	var moments: Array = model.crew_moments()
	if moments.is_empty(): return
	_label(parent, "AROUND THE COUNTER", 13, VIOLET)
	for moment in moments:
		var row = _row(_box(parent, Color("ece5f6"), 13, 8), 9)
		_picture(row, "crew/" + str(moment.staff_ids[0]), Vector2(60, 60))
		var id = str(moment.id)
		_icon_button(row, str(moment.title), "crew", func(): _show_crew_moment(id), Color("ece5f6"), INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _show_crew_moment(id: String) -> void:
	for moment in model.crew_moments():
		if str(moment.id) != id: continue
		var col = _modal_page("THE PEOPLE BEHIND THE COUNTER", str(moment.title))
		var portraits = _row(col, 12)
		for person_id in moment.staff_ids: _picture(portraits, "crew/" + str(person_id), Vector2(106, 106))
		_label(col, str(moment.body), 20, INK)
		for index in range(moment.choices.size()):
			var choice: Dictionary = moment.choices[index]
			var pick = index
			var card = _column(_box(col, PAPER, 14, 10), 6)
			var button = _icon_button(card, str(choice.label) + (" · " + _money(choice.cost) if float(choice.cost) else ""), "crew", func(): _act("crew_decide", {"id": id, "choice": pick}), INK, CREAM)
			button.disabled = float(choice.cost) > maxf(0, float(model.state.cash))
			_label(card, str(choice.detail), 15, MUTED)
		return

func _build_report_insights(parent: Node, report: Dictionary) -> void:
	var drivers: Array = report.get("drivers", [])
	if not drivers.is_empty():
		_label(parent, "WHAT SHAPED TODAY", 12, VIOLET)
		for driver in drivers.slice(0, 3):
			if driver is Dictionary:
				var card = _column(_box(parent, PAPER, 11, 8), 4)
				var row = _row(card, 6)
				_icon(row, str(driver.get("icon", "info")), 23, GREEN if str(driver.get("tone", "")) == "good" else RED if str(driver.get("tone", "")) == "bad" else VIOLET)
				var heading = _label(row, str(driver.get("title", driver.get("label", "Today"))), 18, INK)
				heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_label(card, str(driver.get("detail", driver.get("text", ""))), 15, MUTED)
			else: _label(parent, str(driver), 17, INK)
		if drivers.size() > 3:
			var extra: Array[String] = []
			for driver in drivers.slice(3):
				if driver is Dictionary: extra.append(str(driver.get("label", "")) + ": " + str(driver.get("detail", "")))
			_disclosure(parent, "More about today's result", "\n\n".join(extra))
	for reaction in report.get("reactions", []).slice(0, 2):
		var negative = reaction is Dictionary and str(reaction.get("tone", "")) == "bad"
		var quote = _row(_box(parent, Color("f8e5dd") if negative else Color("e4f3e9"), 15, 10), 8)
		_icon(quote, str(reaction.get("icon", "heart")) if reaction is Dictionary else "heart", 25, RED if negative else GREEN)
		var reaction_text = _label(quote, str(reaction.get("text", "")) if reaction is Dictionary else str(reaction), 17, INK)
		reaction_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reaction_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
