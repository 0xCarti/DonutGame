extends Control
## A schematic route board. Positions show catalogue order, never real geography.
signal venue_selected(id: String)
const Content = preload("res://scripts/circuit_content.gd")
const FONT = preload("res://assets/fonts/Fredoka-Medium.ttf")
const INK = Color("173c3f")
const GOLD = Color("efbc64")
const CREAM = Color("fff8e8")
const GREEN = Color("387c6c")
const CORAL = Color("bd674e")
const SHORT_NAMES: Dictionary = {
	"willowbank": "Willowbank\nFair", "brass_bell": "Brass Bell\nCarnival",
	"juniper": "Juniper\nCounty", "lantern_quay": "Lantern\nQuay",
	"copperfield": "Copperfield\nSteam", "orchard_days": "Orchard\nDays",
	"cedar_sound": "Cedar Sound\nSessions", "moonwheel": "Moonwheel\nCarnival",
	"saltwind": "Saltwind\nFestival", "meadow_crown": "Meadow\nCrown",
	"solstice": "Solstice\nField", "grand_circuit": "Grand Circuit\nJubilee"
}

var reduced_motion: bool = false
var venue_buttons: Dictionary = {}
var _state: Dictionary = {}
var _offers: Dictionary = {}
var _planned_ids: Array = []
var _clock: float = 0.0
var _centers: Array[Vector2] = []

func _init() -> void:
	custom_minimum_size = Vector2(0, 370)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true

func configure(state: Dictionary, offers: Array, planned_ids: Array, use_reduced_motion: bool = false) -> void:
	_state = state.duplicate(true)
	_offers.clear()
	for offer: Dictionary in offers:
		_offers[String(offer.get("id", ""))] = offer.duplicate(true)
	_planned_ids = planned_ids.duplicate()
	reduced_motion = use_reduced_motion
	if reduced_motion: _clock = 0.0
	_rebuild()
	_sync_process()

func _ready() -> void:
	if venue_buttons.is_empty(): _rebuild()
	_layout_buttons()
	_sync_process()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_buttons()
		queue_redraw()
	if what == NOTIFICATION_VISIBILITY_CHANGED: _sync_process()

func _sync_process() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and not reduced_motion and not String(_state.get("booked_id", "")).is_empty())

func _process(delta: float) -> void:
	_clock = fmod(_clock + minf(delta, 0.1), 120.0)
	queue_redraw()

func venue_status(id: String) -> String:
	if id == String(_state.get("booked_id", "")): return "current"
	var completed: Array = _state.get("completed", [])
	if completed.has(id): return "visited"
	if _planned_ids.has(id): return "planned"
	var venue: Dictionary = Content.find(Content.VENUES, id)
	if float(_state.get("rep", 0)) < float(venue.get("min_rep", 0)): return "locked"
	return "ready"

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	venue_buttons.clear()
	for venue: Dictionary in Content.VENUES:
		var id: String = String(venue.id)
		var status: String = venue_status(id)
		var button := Button.new()
		button.name = "Venue_" + id
		button.custom_minimum_size = Vector2(44, 64)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var offer: Dictionary = _offers.get(id, {})
		var reason: String = String(offer.get("reason", ""))
		button.tooltip_text = String(venue.name) + "\n" + String(venue.town)
		if not reason.is_empty(): button.tooltip_text += "\n" + reason
		button.set_meta("venue_id", id)
		button.set_meta("route_status", status)
		var border: Color = Color("c9c5ac")
		var fill: Color = CREAM
		match status:
			"current":
				border = CORAL
				fill = Color("f9dfbc")
			"visited":
				border = GREEN
				fill = Color("e7efdb")
			"planned":
				border = Color("9e7f48")
				fill = Color("f8ebcb")
			"locked":
				border = Color("b9c4ba")
				fill = Color("e1e6d8")
		button.add_theme_stylebox_override("normal", _button_style(fill, border, 2))
		button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.08), INK, 2))
		button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.06), INK, 2))
		button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), INK, 3))
		button.pressed.connect(_select_venue.bind(id))
		add_child(button)
		var label := Label.new()
		label.name = "VenueName"
		label.text = String(SHORT_NAMES.get(id, venue.name))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 4
		label.offset_right = -4
		label.offset_top = 4
		label.offset_bottom = -21
		button.add_child(label)
		var sub := Label.new()
		sub.name = "RouteStatus"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub.add_theme_font_override("font", FONT)
		sub.add_theme_font_size_override("font_size", 10)
		sub.add_theme_color_override("font_color", GREEN if status == "visited" else INK)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.clip_text = true
		match status:
			"current": sub.text = "HERE NOW"
			"visited": sub.text = "VISITED"
			"planned": sub.text = "PLAN %d" % (_planned_ids.find(id) + 1)
			"locked": sub.text = "REP %d" % int(venue.min_rep)
			_: sub.text = "EXPLORE"
		sub.anchor_top = 1.0
		sub.anchor_bottom = 1.0
		sub.anchor_right = 1.0
		sub.offset_left = 4
		sub.offset_right = -4
		sub.offset_top = -21
		sub.offset_bottom = -4
		button.add_child(sub)
		venue_buttons[id] = button
	_layout_buttons()
	queue_redraw()

func _layout_buttons() -> void:
	if venue_buttons.is_empty() or size.x < 1: return
	_centers.clear()
	var outer: float = 12.0
	var gap: float = 16.0 if size.x >= 360 else 12.0
	var width: float = maxf(44, (size.x - outer * 2 - gap * 2) / 3.0)
	var top: float = 57.0
	var row_gap: float = maxf(12.0, (size.y - top - 23.0 - 64.0 * 4.0) / 3.0)
	for index in range(Content.VENUES.size()):
		var row: int = index / 3
		var col: int = index % 3 if row % 2 == 0 else 2 - index % 3
		var button: Button = venue_buttons[String(Content.VENUES[index].id)]
		button.position = Vector2(outer + col * (width + gap), top + row * (64 + row_gap))
		button.size = Vector2(width, 64)
		_centers.append(button.position + button.size * 0.5)

func _select_venue(id: String) -> void:
	venue_selected.emit(id)

func _draw() -> void:
	if size.x < 1: return
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("eee8cd")
	paper.set_corner_radius_all(16)
	draw_style_box(paper, Rect2(Vector2.ZERO, size))
	draw_string(FONT, Vector2(13, 23), "The fairground circuit", HORIZONTAL_ALIGNMENT_LEFT, size.x - 26, 16, INK)
	draw_string(FONT, Vector2(13, 42), "A route board, not a scale map.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 26, 11, Color("5d756c"))
	if _centers.size() > 1:
		var road := PackedVector2Array()
		for index in range(_centers.size()):
			if index > 0 and index % 3 == 0:
				var previous: Vector2 = _centers[index - 1]
				var current: Vector2 = _centers[index]
				var edge: float = size.x - 4 if (index / 3) % 2 == 1 else 4.0
				road.append(Vector2(edge, previous.y))
				road.append(Vector2(edge, current.y))
			road.append(_centers[index])
		draw_polyline(road, Color("d1bf92"), 8, true)
		draw_polyline(road, Color("f9f3d9"), 2, true)
	var booked_id: String = String(_state.get("booked_id", ""))
	if venue_buttons.has(booked_id):
		var current_button: Button = venue_buttons[booked_id]
		var center: Vector2 = current_button.position + Vector2(current_button.size.x - 3, 3)
		var pulse: float = 1.0 if reduced_motion else 0.7 + sin(_clock * 2) * 0.2
		draw_circle(center, 8, Color(CORAL, pulse * 0.18))
		draw_circle(center, 4, CORAL)
	draw_string(FONT, Vector2(13, size.y - 8), "Tap any stop to see its fair and booking details.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 26, 10, INK)

func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(11)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style
