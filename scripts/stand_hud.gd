extends Control
## The operator's dashboard. Every panel ignores pointer input except its own
## menu buttons, so the physical counter remains the primary way to work.

signal pause_requested
signal help_requested
signal mobile_action_requested(action: String)
signal mobile_hold_started(action: String)
signal mobile_hold_ended(action: String)

const MobileControls = preload("res://scripts/mobile_controls.gd")

const INK = Color("10252b")
const PANEL = Color("152f35")
const BORDER = Color("3b5353")
const CREAM = Color("fff1d2")
const GOLD = Color("ffc76f")
const MINT = Color("a4e1c1")
const RED = Color("ff987e")
const MUTED = Color("a6bdb8")
var controls: Dictionary = {}
var fault_target = Vector2(-100, -100)
var fault_color = GOLD
var reduced_motion = false
var _pulse = 0.0
var _last_fault = ""
var _fault_age = 0.0
var _step = 0
var mobile_mode = false
var mobile_controls: Control
var mobile: Dictionary = {}
var _desktop_nodes: Array[CanvasItem] = []
var _mobile_layer: Control
var _last_state: Dictionary = {}
var _last_context: Dictionary = {}


class Glyph extends Control:
	var kind = "donut"
	var tint = Color("ffc76f")
	func _draw() -> void:
		var c = Vector2(20, 20)
		match kind:
			"bag":
				draw_colored_polygon(PackedVector2Array([Vector2(8, 7), Vector2(31, 7), Vector2(34, 35), Vector2(6, 35)]), tint)
				draw_line(Vector2(11, 8), Vector2(29, 8), Color("744f34"), 3)
				draw_circle(Vector2(20, 23), 6, Color("b56a46"))
				draw_circle(Vector2(20, 23), 2, tint)
			"bucket":
				draw_colored_polygon(PackedVector2Array([Vector2(5, 10), Vector2(35, 10), Vector2(30, 35), Vector2(10, 35)]), tint)
				draw_line(Vector2(5, 10), Vector2(35, 10), Color("fff1d2"), 4)
				draw_line(Vector2(15, 14), Vector2(17, 32), Color("a94736"), 5)
				draw_line(Vector2(25, 14), Vector2(23, 32), Color("a94736"), 5)
			"scoop":
				draw_colored_polygon(PackedVector2Array([Vector2(5, 7), Vector2(27, 7), Vector2(27, 23), Vector2(9, 26)]), tint)
				draw_line(Vector2(23, 23), Vector2(35, 35), Color("bf8a57"), 6)
				draw_line(Vector2(8, 10), Vector2(25, 10), Color("fff1d2"), 2)
			"heat":
				draw_style_box(_pill(Color("466164"), 5), Rect2(15, 4, 10, 26))
				draw_line(Vector2(20, 12), Vector2(20, 30), tint, 4)
				draw_circle(Vector2(20, 30), 7, tint)
				for y in [11, 18, 25]: draw_line(Vector2(28, y), Vector2(33, y), tint, 2)
			"batter":
				draw_colored_polygon(PackedVector2Array([Vector2(6, 7), Vector2(34, 7), Vector2(27, 26), Vector2(23, 26), Vector2(23, 35), Vector2(17, 35), Vector2(17, 26), Vector2(13, 26)]), tint)
				draw_line(Vector2(10, 11), Vector2(30, 11), Color("fff1d2"), 2)
			"warning":
				draw_colored_polygon(PackedVector2Array([Vector2(20, 3), Vector2(38, 35), Vector2(2, 35)]), tint)
				draw_line(Vector2(20, 12), Vector2(20, 24), Color("10252b"), 4)
				draw_circle(Vector2(20, 29), 2, Color("10252b"))
			"clock":
				draw_arc(c, 15, 0, TAU, 32, tint, 2, true)
				draw_line(c, Vector2(20, 10), tint, 2)
				draw_line(c, Vector2(28, 24), tint, 2)
			"hand":
				draw_style_box(_pill(tint, 6), Rect2(10, 17, 23, 19))
				for x in [12, 18, 24, 30]: draw_line(Vector2(x, 10), Vector2(x, 27), tint, 4)
				draw_line(Vector2(12, 26), Vector2(5, 18), tint, 5)
			"gear":
				draw_circle(c, 11, tint)
				for i in range(8):
					var direction = Vector2.from_angle(float(i) * TAU / 8.0)
					draw_line(c + direction * 10, c + direction * 17, tint, 6)
				draw_circle(c, 5, Color("152f35"))
			_:
				draw_circle(c, 15, tint)
				draw_circle(c, 6, Color("152f35"))
				for i in range(5):
					var p = c + Vector2.from_angle(float(i) * TAU / 5.0 + 0.5) * 10
					draw_line(p - Vector2(1, 1), p + Vector2(2, 1), Color("fff1d2"), 2)
	func _pill(color: Color, radius: int) -> StyleBoxFlat:
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		return style


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 800)
	_build()
	for child in get_children():
		if child is CanvasItem: _desktop_nodes.append(child)
	_apply_mobile_mode()


func configure_mobile(enabled: bool) -> void:
	mobile_mode = enabled
	if is_node_ready(): _apply_mobile_mode()


func cancel_mobile_holds() -> void:
	if is_instance_valid(mobile_controls): mobile_controls.cancel_holds()


func _apply_mobile_mode() -> void:
	if mobile_mode and not is_instance_valid(_mobile_layer): _build_mobile()
	for node in _desktop_nodes: node.visible = not mobile_mode
	if is_instance_valid(_mobile_layer):
		_mobile_layer.visible = mobile_mode
		if not mobile_mode: mobile_controls.cancel_holds()
	if not _last_state.is_empty(): refresh(_last_state, _last_context)
	elif not mobile_mode: controls.fault.hide()
	queue_redraw()


func _build_mobile() -> void:
	_mobile_layer = Control.new()
	_mobile_layer.name = "MobileHUD"
	_mobile_layer.size = Vector2(1280, 800)
	_mobile_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mobile_layer)
	var score = _panel(_mobile_layer, Vector2(16, 16), Vector2(268, 108), PANEL)
	mobile.shift = _label(score, "PRACTICE", Vector2(14, 8), Vector2(240, 28), 20, GOLD)
	mobile.progress = _label(score, "$0 / $110", Vector2(14, 40), Vector2(240, 36), 28)
	mobile.clock = _label(score, "", Vector2(14, 78), Vector2(240, 25), 20, MUTED)
	var ticket = _panel(_mobile_layer, Vector2(300, 16), Vector2(508, 108), CREAM)
	mobile.heading = _label(ticket, "FRONT CUSTOMER", Vector2(16, 8), Vector2(290, 26), 20, Color("9e5538"))
	mobile.waiting = _label(ticket, "", Vector2(326, 8), Vector2(166, 26), 20, Color("9e5538"))
	mobile.waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mobile.order = _label(ticket, "", Vector2(16, 35), Vector2(476, 34), 28, INK)
	mobile.flavor = _label(ticket, "", Vector2(16, 71), Vector2(476, 28), 22, INK)
	mobile.patience = _bar(ticket, Vector2(16, 102), Vector2(476, 4), Color("4e9477"))
	mobile.look_hint = _label(_mobile_layer, "Drag to look · tap objects to use", Vector2(824, 102), Vector2(440, 28), 20, CREAM)
	mobile.look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mobile.look_hint.add_theme_color_override("font_outline_color", INK)
	mobile.look_hint.add_theme_constant_override("outline_size", 4)

	var machine = _panel(_mobile_layer, Vector2(16, 636), Vector2(384, 148), PANEL)
	mobile.machine = _label(machine, "", Vector2(16, 10), Vector2(352, 32), 25, GOLD)
	mobile.stock = _label(machine, "", Vector2(16, 47), Vector2(352, 32), 24)
	mobile.condition = _label(machine, "", Vector2(16, 85), Vector2(352, 26), 20, MINT)
	mobile.flow = _label(machine, "", Vector2(16, 115), Vector2(352, 26), 20, MUTED)
	var next = _panel(_mobile_layer, Vector2(416, 636), Vector2(448, 148), Color("1c393c"))
	mobile.prompt = _label(next, "YOUR NEXT MOVE", Vector2(14, 10), Vector2(420, 42), 22, CREAM)
	mobile.prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var held = _panel(_mobile_layer, Vector2(880, 636), Vector2(384, 148), PANEL)
	mobile.package = _label(held, "", Vector2(16, 9), Vector2(352, 32), 26)
	mobile.tool = _label(held, "", Vector2(16, 45), Vector2(352, 27), 20, GOLD)
	mobile.coating = _label(held, "", Vector2(16, 84), Vector2(212, 48), 20, MUTED)
	mobile.coating.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var fault = _panel(_mobile_layer, Vector2(300, 138), Vector2(508, 102), Color("342e2d"))
	mobile.fault = fault
	mobile.warning = _label(fault, "", Vector2(16, 10), Vector2(476, 30), 24, RED)
	mobile.fault_action = _label(fault, "", Vector2(16, 46), Vector2(476, 42), 20, CREAM)
	mobile.fault_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mobile.hold = _bar(fault, Vector2(16, 92), Vector2(476, 5), GOLD)
	fault.hide()
	mobile.notice = _label(_mobile_layer, "", Vector2(316, 250), Vector2(650, 50), 22, MINT)
	mobile.notice.add_theme_color_override("font_outline_color", INK)
	mobile.notice.add_theme_constant_override("outline_size", 4)
	mobile_controls = MobileControls.new()
	_mobile_layer.add_child(mobile_controls)
	mobile_controls.action_requested.connect(func(action: String): mobile_action_requested.emit(action))
	mobile_controls.hold_started.connect(func(action: String): mobile_hold_started.emit(action))
	mobile_controls.hold_ended.connect(func(action: String): mobile_hold_ended.emit(action))


func _refresh_mobile(state: Dictionary, context: Dictionary) -> void:
	var practice = bool(context.get("practice", false))
	mobile.shift.text = "PRACTICE · NO TIMER" if practice else "SHIFT %d" % (int(state.get("shift_index", 0)) + 1)
	mobile.progress.text = "%s / $%d" % [_money(float(state.get("sales", 0))), int(state.get("target", 0))]
	var remaining = int(ceil(float(state.get("time_left", 0))))
	mobile.clock.text = "Take your time" if practice else "%d:%02d remaining" % [remaining / 60, remaining % 60]
	mobile.clock.add_theme_color_override("font_color", RED if remaining < 20 and not practice else MUTED)
	var orders: Array = state.get("orders", [])
	mobile.heading.text = "FRONT CUSTOMER" if not orders.is_empty() else "COUNTER OPEN"
	mobile.waiting.text = "%d waiting" % maxi(0, orders.size() - 1) if orders.size() > 1 else ""
	mobile.order.text = "A moment to restock"
	mobile.flavor.text = "Next customer arriving soon"
	mobile.patience.visible = not orders.is_empty()
	if not orders.is_empty():
		var order: Dictionary = orders[0]
		var kind = str(order.get("package", "bag"))
		mobile.order.text = "%s · %d mini donuts" % [kind.capitalize(), 6 if kind == "bag" else 12]
		mobile.flavor.text = "Cinnamon sugar" if order.get("flavor", "cinnamon") == "cinnamon" else "Powdered sugar"
		mobile.patience.value = 100.0 * float(order.get("patience", 0)) / maxf(1, float(order.get("max_patience", 1)))
		mobile.patience.add_theme_stylebox_override("fill", _bar_style(RED if mobile.patience.value < 30 else Color("4e9477")))
	var temperature = float(state.get("temperature", 175))
	mobile.machine.text = "%.0f° · Heat %d / 4" % [temperature, int(state.get("heat_setting", 2))]
	mobile.machine.add_theme_color_override("font_color", RED if temperature >= 200 else GOLD if temperature < 150 else MINT)
	mobile.stock.text = "Tray %d / %d · Batter %d" % [int(state.get("supply", 0)), int(state.get("supply_capacity", 36)), int(state.get("batter", 0))]
	mobile.condition.text = str(context.get("machine_status", "MAKING DONUTS"))
	mobile.condition.add_theme_color_override("font_color", RED if bool(state.get("jammed", false)) or bool(state.get("fire_active", false)) or bool(state.get("overheated", false)) else MINT)
	mobile.flow.text = "%d frying · %d wasted" % [int(state.get("in_flight", 0)), int(state.get("waste_count", 0))]
	var kind = str(state.get("package_type", ""))
	var tool = str(state.get("held_tool", "none"))
	var flavor = str(state.get("package_flavor", ""))
	mobile.package.text = "No container yet" if kind.is_empty() else "%s %d / %d" % [kind.capitalize(), int(state.get("package_count", 0)), 6 if kind == "bag" else 12]
	mobile.tool.text = "Scoop · %d donuts" % int(state.get("scoop_count", 0)) if tool == "scoop" else "Order ready to hand over" if tool == "package" else "Hands free"
	mobile.coating.text = "Match the ticket" if kind.is_empty() else "Add sugar when full" if flavor.is_empty() else "Cinnamon sugar" if flavor == "cinnamon" else "Powdered sugar"
	var action = str(context.get("station", ""))
	var caption = str(context.get("prompt", "Tap a counter object"))
	if action == "customer": action = "serve" if tool == "package" else ""
	var faults: Array = context.get("faults", [])
	mobile.fault.visible = not faults.is_empty()
	if not faults.is_empty():
		var fault: Dictionary = faults[0]
		var fault_station = str(fault.get("station", ""))
		mobile.warning.text = str(fault.get("title", "CHECK THE FRYER"))
		mobile.warning.add_theme_color_override("font_color", RED if fault.get("critical", false) else GOLD)
		var hints = {"extinguish":"Tap the extinguisher for one blast.", "heat_down":"Tap the heat dial or lower the heat in Tools.", "heat_up":"Tap the heat dial or raise the heat in Tools.", "repair":"Hold the feeder lever or Hold to repair.", "refill":"Hold the batter hopper or Hold to refill.", "supply":"Fresh donuts are on the way."}
		mobile.fault_action.text = str(hints.get(fault_station, "Tap the matching counter object."))
		if bool(fault.get("critical", false)) and fault_station in MobileControls.ACTIONS:
			action = fault_station
			caption = str({"extinguish":"Use extinguisher", "heat_down":"Lower heat", "heat_up":"Raise heat", "repair":"Hold to repair", "refill":"Hold to refill"}.get(action, caption))
	var hold = str(state.get("hold_station", ""))
	mobile.hold.visible = not hold.is_empty()
	if not hold.is_empty():
		action = hold
		caption = "Hold to repair" if hold == "repair" else "Hold to refill"
		mobile.hold.value = float(state.get("jam_progress", 0) if hold == "repair" else state.get("refill_progress", 0)) * 100.0
		mobile.fault_action.text = "%d%% · keep holding; release to stop" % int(mobile.hold.value)
	elif action in ["repair", "refill"]:
		caption = "Hold to repair" if action == "repair" else "Hold to refill"
	mobile.prompt.text = "MACHINE CARE" if action in ["repair", "refill", "extinguish", "heat_down", "heat_up"] else "YOUR NEXT MOVE · TAP TO USE"
	if not str(context.get("queued_action", "")).is_empty(): mobile.prompt.text = "NEXT: " + str(context.queued_action)
	mobile_controls.set_context(action, caption)
	mobile.notice.text = "" if practice else str(context.get("notice", ""))
	if mobile.notice.text.begins_with("QUOTA REACHED"): mobile.notice.text = "Goal reached · extra orders earn upgrade coins"


func _build() -> void:
	var score = _panel(self, Vector2(16, 16), Vector2(350, 105), PANEL)
	_label(score, "GOLDEN HOUR", Vector2(16, 9), Vector2(200, 20), 15, GOLD)
	controls.shift = _label(score, "", Vector2(16, 30), Vector2(218, 19), 13, MUTED)
	controls.progress = _label(score, "$0", Vector2(14, 50), Vector2(165, 39), 31)
	controls.target = _label(score, "/ $110", Vector2(178, 58), Vector2(74, 27), 16, MUTED)
	controls.clock = _label(score, "1:45", Vector2(256, 36), Vector2(84, 39), 30)
	controls.clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.clock_caption = _label(score, "REMAINING", Vector2(252, 78), Vector2(88, 15), 10, MUTED)
	controls.clock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.quota = _bar(score, Vector2(16, 94), Vector2(220, 4), GOLD)
	controls.orders = []
	for i in range(3):
		var width = 318.0 if i == 0 else 220.0
		var x = 380.0 if i == 0 else 712.0 + (i - 1) * 234.0
		var card = _panel(self, Vector2(x, 16), Vector2(width, 105), CREAM if i == 0 else PANEL)
		var accent = Color("9e5538") if i == 0 else GOLD
		var ink = INK if i == 0 else CREAM
		var heading = _label(card, "SERVE THIS CUSTOMER" if i == 0 else "NEXT IN LINE", Vector2(13, 9), Vector2(width - 26, 18), 12, accent)
		var glyph = _glyph(card, "bag", Vector2(12, 32), GOLD)
		var order = _label(card, "", Vector2(60, 31), Vector2(width - 72, 29), 23, ink)
		var flavor = _label(card, "", Vector2(61, 60), Vector2(width - 72, 21), 15, ink.lightened(0.15) if i == 0 else MUTED)
		var patience = _bar(card, Vector2(13, 93), Vector2(width - 26, 4), Color("4e9477") if i == 0 else MINT)
		var patience_text = _label(card, "", Vector2(width - 77, 10), Vector2(65, 15), 11, accent)
		patience_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		controls.orders.append({"card": card, "heading": heading, "glyph": glyph, "order": order, "flavor": flavor, "patience": patience, "time": patience_text})
	_button(self, "II", Vector2(1180, 16), Vector2(38, 46), func(): pause_requested.emit())
	_button(self, "?", Vector2(1226, 16), Vector2(38, 46), func(): help_requested.emit())
	controls.mode = _label(self, "", Vector2(1178, 73), Vector2(90, 42), 11, GOLD)
	controls.mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.mode.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var machine = _panel(self, Vector2(16, 676), Vector2(364, 108), PANEL)
	_glyph(machine, "gear", Vector2(10, 8), GOLD).scale = Vector2.ONE * 0.55
	_label(machine, "FRYER CONTROL", Vector2(36, 10), Vector2(165, 18), 12, GOLD)
	controls.condition = _label(machine, "RUNNING", Vector2(200, 10), Vector2(149, 19), 12, MINT)
	controls.condition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_glyph(machine, "heat", Vector2(8, 35), GOLD).scale = Vector2.ONE * 0.70
	controls.machine = _label(machine, "175°", Vector2(38, 34), Vector2(91, 30), 24)
	controls.heat_setting = _label(machine, "HEAT 2 / 4", Vector2(39, 66), Vector2(96, 17), 10, MUTED)
	controls.heat = _bar(machine, Vector2(15, 92), Vector2(113, 4), MINT)
	_glyph(machine, "batter", Vector2(134, 36), GOLD).scale = Vector2.ONE * 0.60
	controls.batter = _label(machine, "72", Vector2(164, 34), Vector2(63, 31), 24)
	_label(machine, "BATTER", Vector2(164, 66), Vector2(66, 17), 10, MUTED)
	controls.batter_bar = _bar(machine, Vector2(145, 92), Vector2(82, 4), GOLD)
	_glyph(machine, "donut", Vector2(242, 36), GOLD).scale = Vector2.ONE * 0.60
	controls.stock = _label(machine, "18", Vector2(272, 34), Vector2(70, 31), 24)
	_label(machine, "READY", Vector2(272, 66), Vector2(71, 17), 10, MUTED)
	controls.stock_bar = _bar(machine, Vector2(253, 92), Vector2(95, 4), MINT)
	controls.flow = _label(self, "", Vector2(22, 648), Vector2(358, 23), 13, MUTED)
	controls.flow.add_theme_color_override("font_outline_color", INK)
	controls.flow.add_theme_constant_override("outline_size", 5)

	var task = _panel(self, Vector2(394, 676), Vector2(492, 108), Color("1c393c"))
	controls.step = _label(task, "", Vector2(15, 9), Vector2(423, 17), 11, GOLD)
	controls.key = _label(task, "CLICK", Vector2(15, 36), Vector2(63, 31), 14, INK)
	controls.key.add_theme_stylebox_override("normal", _style(GOLD, 6, false))
	controls.key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.prompt = _label(task, "", Vector2(91, 32), Vector2(386, 35), 21)
	controls.hint = _label(task, "", Vector2(15, 75), Vector2(462, 20), 13, MUTED)
	controls.hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var held = _panel(self, Vector2(900, 676), Vector2(364, 108), PANEL)
	controls.tool_glyph = _glyph(held, "hand", Vector2(11, 34), GOLD)
	controls.tool = _label(held, "HANDS FREE", Vector2(15, 10), Vector2(330, 19), 12, GOLD)
	controls.package = _label(held, "", Vector2(63, 35), Vector2(285, 30), 23)
	controls.coating = _label(held, "", Vector2(64, 69), Vector2(282, 20), 13, MUTED)

	var fault = _panel(self, Vector2(16, 137), Vector2(418, 82), Color("342e2d"))
	controls.fault = fault
	controls.fault_glyph = _glyph(fault, "warning", Vector2(12, 13), RED)
	controls.warning = _label(fault, "", Vector2(62, 10), Vector2(341, 26), 20, RED)
	controls.fault_action = _label(fault, "", Vector2(63, 41), Vector2(340, 26), 14, CREAM)
	controls.fault_more = _label(self, "", Vector2(25, 226), Vector2(430, 26), 13, GOLD)
	controls.hold = _bar(fault, Vector2(13, 73), Vector2(392, 6), GOLD)
	controls.hold.visible = false
	fault.visible = false
	controls.notice = _label(self, "", Vector2(444, 136), Vector2(500, 31), 18, MINT)
	controls.notice.add_theme_color_override("font_outline_color", INK)
	controls.notice.add_theme_constant_override("outline_size", 5)


func refresh(state: Dictionary, context: Dictionary) -> void:
	if controls.is_empty(): return
	_last_state = state.duplicate(true)
	_last_context = context.duplicate(true)
	if mobile_mode:
		_refresh_mobile(state, context)
		return
	controls.progress.text = _money(float(state.get("sales", 0)))
	controls.target.text = "/ $%d" % int(state.get("target", 0))
	controls.quota.value = float(state.get("sales", 0)) * 100.0 / maxf(1.0, float(state.get("target", 1)))
	var remaining = int(ceil(float(state.get("time_left", 0))))
	var practice = bool(context.get("practice", false))
	controls.clock.text = "OPEN" if practice else "%d:%02d" % [remaining / 60, remaining % 60]
	controls.clock_caption.text = "NO CLOCK" if practice else "REMAINING"
	controls.clock.add_theme_color_override("font_color", RED if remaining < 20 and not practice else CREAM)
	var round_label = "PRACTICE" if practice else ("ROUND %d" % [int(state.get("shift_index", 0)) + 1] if context.get("endless", false) else "SHIFT %d / %d" % [int(state.get("shift_index", 0)) + 1, int(context.get("total_shifts", 6))])
	controls.shift.text = "%s  ·  %s" % [round_label, str(context.get("shift_name", "Opening time"))]
	controls.mode.text = "NO\nPRESSURE" if practice else ("RELAXED" if context.get("difficulty", "normal") == "relaxed" else "")
	var orders: Array = state.get("orders", [])
	for i in range(3):
		var card: Dictionary = controls.orders[i]
		var active = i < orders.size()
		card.card.visible = active or i == 0
		card.card.modulate.a = 1.0 if active else 0.35
		card.glyph.visible = active
		card.patience.visible = active
		card.heading.text = ("SERVE THIS CUSTOMER" if i == 0 else "UP NEXT") if active else "COUNTER OPEN" if i == 0 else "NEXT CUSTOMER"
		card.order.text = "A moment to restock" if i == 0 else "—"
		card.flavor.text = "" if i > 0 else "The next customer is on their way"
		card.time.text = ""
		if not active: continue
		var order: Dictionary = orders[i]
		var kind = str(order.get("package", "bag"))
		var flavor = str(order.get("flavor", "cinnamon"))
		card.glyph.kind = kind
		card.glyph.queue_redraw()
		card.order.text = "%s  ·  %d" % [kind.capitalize(), 6 if kind == "bag" else 12]
		card.flavor.text = "Cinnamon sugar" if flavor == "cinnamon" else "Powdered sugar"
		card.patience.value = 100.0 * float(order.get("patience", 0)) / maxf(1, float(order.get("max_patience", 1)))
		var urgent = card.patience.value < 30.0
		card.patience.add_theme_stylebox_override("fill", _bar_style(RED if urgent else Color("4e9477")))
		card.time.text = "CALM" if practice else "%ds" % int(ceil(float(order.get("patience", 0))))
		card.time.add_theme_color_override("font_color", Color("a5362a") if urgent and i == 0 else (RED if urgent else Color("9e5538") if i == 0 else GOLD))
	var temperature = float(state.get("temperature", 175))
	var heat_color = RED if temperature >= 200 else GOLD if temperature < 150 else MINT
	controls.machine.text = "%.0f°" % temperature
	controls.machine.add_theme_color_override("font_color", heat_color)
	controls.heat.value = clampf((temperature - 90.0) / 150.0 * 100.0, 0, 100)
	controls.heat.add_theme_stylebox_override("fill", _bar_style(heat_color))
	controls.heat_setting.text = "HEAT %d / 4" % int(state.get("heat_setting", 2))
	controls.batter.text = str(state.get("batter", 0))
	controls.batter_bar.value = 100.0 * float(state.get("batter", 0)) / maxf(1.0, float(context.get("batter_capacity", 72)))
	controls.stock.text = str(state.get("supply", 0))
	controls.stock_bar.value = 100.0 * float(state.get("supply", 0)) / maxf(1.0, float(state.get("supply_capacity", 36)))
	controls.flow.text = "%d IN THE FRYER   ·   %d WASTED" % [int(state.get("in_flight", 0)), int(state.get("waste_count", 0))]
	controls.condition.text = str(context.get("machine_status", "RUNNING"))
	controls.condition.add_theme_color_override("font_color", RED if bool(state.get("jammed", false)) or bool(state.get("overheated", false)) else MINT)
	var tool = str(state.get("held_tool", "none"))
	var kind = str(state.get("package_type", ""))
	var flavor = str(state.get("package_flavor", ""))
	controls.tool.text = "SCOOP IN HAND  ·  %d DONUTS" % int(state.get("scoop_count", 0)) if tool == "scoop" else "ORDER IN HAND  ·  READY TO SERVE" if tool == "package" else "HANDS FREE"
	controls.tool_glyph.kind = "scoop" if tool == "scoop" else kind if tool == "package" else "hand"
	controls.tool_glyph.queue_redraw()
	controls.package.text = "Choose a container" if kind.is_empty() else "%s  %d / %d" % [kind.capitalize(), int(state.get("package_count", 0)), 6 if kind == "bag" else 12]
	controls.coating.text = "Read the front customer's ticket" if kind.is_empty() else "Plain  ·  needs sugar when full" if flavor.is_empty() else "Cinnamon sugar" if flavor == "cinnamon" else "Powdered sugar"
	controls.prompt.text = str(context.get("prompt", "Read the first ticket"))
	controls.key.text = str(context.get("key", "CLICK"))
	controls.hint.text = str(context.get("hint", ""))
	if not str(context.get("queued_action", "")).is_empty():
		controls.hint.text = "Next: " + str(context.queued_action).to_lower()
	controls.step.text = str(context.get("step", "YOUR NEXT MOVE"))
	var faults: Array = context.get("faults", [])
	controls.fault.visible = not faults.is_empty()
	controls.fault_more.text = ""
	if not faults.is_empty():
		var fault: Dictionary = faults[0]
		var code = str(fault.get("code", ""))
		if code != _last_fault: _fault_age = 0
		_last_fault = code
		fault_color = RED if fault.get("critical", false) else GOLD
		controls.warning.text = str(fault.get("title", "Check the fryer"))
		controls.warning.add_theme_color_override("font_color", fault_color)
		controls.fault_glyph.tint = fault_color
		controls.fault_glyph.queue_redraw()
		controls.fault_action.text = str(fault.get("action", ""))
		controls.hold.visible = not str(state.get("hold_station", "")).is_empty() and str(state.get("hold_station", "")) == str(fault.get("station", ""))
		controls.hold.value = float(state.get("jam_progress", 0) if state.get("hold_station", "") == "repair" else state.get("refill_progress", 0)) * 100.0
		if controls.hold.visible:
			controls.fault_action.text = "%s  %d%%  ·  keep holding %s" % ["Clearing the feeder" if state.get("hold_station", "") == "repair" else "Filling the hopper", int(controls.hold.value), "R" if state.get("hold_station", "") == "repair" else "T"]
		if faults.size() > 1:
			controls.fault_more.text = "ALSO: " + str(faults[1].get("title", ""))
	else:
		_last_fault = ""
		fault_target = Vector2(-100, -100)
	controls.notice.text = str(context.get("notice", ""))
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	_fault_age += delta
	if not controls.is_empty() and controls.fault.visible:
		queue_redraw()


func _draw() -> void:
	if mobile_mode: return
	if controls.is_empty() or not controls.fault.visible or fault_target.x < 0: return
	var start = Vector2(222, 220)
	var endpoint = fault_target - Vector2(0, 17)
	var middle = Vector2(start.x, maxf(240, endpoint.y - 30))
	var color = Color(fault_color, 0.65)
	draw_polyline(PackedVector2Array([start, middle, endpoint]), color, 1.5, true)
	var radius = 18.0 + (0.0 if reduced_motion else sin(_pulse * 4.0) * 2.0)
	draw_arc(fault_target, radius, 0, TAU, 40, fault_color, 2.0, true)
	draw_colored_polygon(PackedVector2Array([endpoint + Vector2(-5, -5), endpoint + Vector2(5, -5), endpoint + Vector2(0, 2)]), fault_color)
	if _fault_age < 1.5 and not reduced_motion:
		draw_style_box(_outline(Color(fault_color, (1.0 - _fault_age / 1.5) * 0.8)), Rect2(16, 137, 418, 82))


func _style(color: Color, radius: int = 13, border: bool = true) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border:
		style.set_border_width_all(1)
		style.border_color = BORDER if color != CREAM else Color("ffe0a2")
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 3)
	return style


func _outline(color: Color) -> StyleBoxFlat:
	var style = _style(Color.TRANSPARENT)
	style.set_border_width_all(3)
	style.border_color = color
	return style


func _bar_style(color: Color) -> StyleBoxFlat:
	var style = _style(color, 2, false)
	style.set_content_margin_all(0)
	return style


func _panel(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> Panel:
	var node = Panel.new()
	node.position = at
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", _style(color))
	parent.add_child(node)
	return node


func _label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color = CREAM) -> Label:
	var node = Label.new()
	node.text = text
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.position = at
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node


func _glyph(parent: Node, kind: String, at: Vector2, tint: Color) -> Glyph:
	var node = Glyph.new()
	node.kind = kind
	node.position = at
	node.size = Vector2(40, 40)
	node.tint = tint
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func _bar(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var node = ProgressBar.new()
	node.position = at
	node.size = dimensions
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", 1)
	node.add_theme_stylebox_override("background", _bar_style(Color("30494b")))
	node.add_theme_stylebox_override("fill", _bar_style(color))
	parent.add_child(node)
	node.set_deferred("size", dimensions)
	return node


func _button(parent: Node, text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> void:
	var node = Button.new()
	node.position = at
	node.size = dimensions
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 19)
	node.add_theme_color_override("font_color", CREAM)
	node.add_theme_stylebox_override("normal", _style(PANEL))
	node.add_theme_stylebox_override("hover", _style(Color("35544e")))
	node.pressed.connect(callback)
	parent.add_child(node)


func _money(value: float) -> String:
	return "$%d" % int(value) if is_equal_approx(value, roundf(value)) else "$%.2f" % value
