extends Control
## Optional touch shortcuts. Empty canvas space always reaches the 3D counter.

signal action_requested(action: String)
signal hold_started(action: String)
signal hold_ended(action: String)

const INK = Color("10252b")
const PANEL = Color("152f35")
const CREAM = Color("fff1d2")
const GOLD = Color("ffc76f")
const MINT = Color("a4e1c1")
const ACTIONS = ["bag", "bucket", "scoop", "supply", "package", "cinnamon", "powdered", "serve", "heat_down", "heat_up", "repair", "refill", "trash", "bell", "extinguish"]
var buttons: Dictionary = {}
var context_button: Button
var tools_button: Button
var drawer: Panel
var order_page: Control
var fryer_page: Control
var _context_action = ""
var _active_hold = ""
var _hold_button: Button


func _ready() -> void:
	size = Vector2(1280, 800)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(4):
		var action: String = ["recenter", "help", "pause", "settings"][i]
		var caption: String = ["Center", "Help", "Pause", "Settings"][i]
		var button = _button(self, caption, Vector2(824 + i * 112, 16), Vector2(104, 80))
		button.pressed.connect(_emit_action.bind(action))
		buttons[action] = button
	context_button = _button(self, "Tap a counter object", Vector2(430, 696), Vector2(420, 80), GOLD)
	context_button.name = "ContextAction"
	context_button.pressed.connect(_context_pressed)
	context_button.button_down.connect(_context_down)
	context_button.button_up.connect(_release_hold_for.bind(context_button))
	context_button.mouse_exited.connect(_release_hold_for.bind(context_button))
	tools_button = _button(self, "Tools", Vector2(1126, 696), Vector2(138, 80))
	tools_button.pressed.connect(func(): set_tools_open(not drawer.visible))
	buttons["tools"] = tools_button
	_build_drawer()
	visibility_changed.connect(_visibility_changed)
	set_context("", "Tap a counter object")


func _build_drawer() -> void:
	drawer = Panel.new()
	drawer.name = "ToolsDrawer"
	drawer.position = Vector2(660, 132)
	drawer.size = Vector2(604, 492)
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer.add_theme_stylebox_override("panel", _style(INK))
	add_child(drawer)
	var heading = Label.new()
	heading.text = "COUNTER TOOLS"
	heading.position = Vector2(20, 27)
	heading.size = Vector2(390, 34)
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", GOLD)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.add_child(heading)
	var close = _button(drawer, "Close", Vector2(472, 12), Vector2(116, 64))
	close.pressed.connect(func(): set_tools_open(false))
	buttons["close_tools"] = close
	var orders = _button(drawer, "Order", Vector2(16, 84), Vector2(282, 64), GOLD)
	var fryer = _button(drawer, "Fryer", Vector2(306, 84), Vector2(282, 64))
	orders.pressed.connect(_show_page.bind(false))
	fryer.pressed.connect(_show_page.bind(true))
	buttons["order_tab"] = orders
	buttons["fryer_tab"] = fryer
	order_page = _page()
	fryer_page = _page()
	var order_actions = [["bag", "Take bag"], ["bucket", "Take bucket"], ["scoop", "Pick up scoop"], ["supply", "Fresh tray"], ["cinnamon", "Cinnamon sugar"], ["powdered", "Powdered sugar"], ["package", "Pour / lift order"], ["serve", "Serve customer"]]
	var fryer_actions = [["heat_down", "Heat −"], ["heat_up", "Heat +"], ["repair", "Hold to repair"], ["refill", "Hold to refill"], ["extinguish", "Extinguisher"], ["bell", "Ring bell"], ["trash", "Discard order"]]
	for page in [[order_page, order_actions], [fryer_page, fryer_actions]]:
		for i in range(page[1].size()):
			var item: Array = page[1][i]
			var button = _button(page[0], item[1], Vector2(16 + (i % 2) * 290, 164 + (i / 2) * 80), Vector2(282, 72))
			buttons[item[0]] = button
			if item[0] in ["repair", "refill"]:
				button.button_down.connect(_begin_hold.bind(item[0], button))
				button.button_up.connect(_release_hold_for.bind(button))
				button.mouse_exited.connect(_release_hold_for.bind(button))
			else:
				button.pressed.connect(_emit_action.bind(item[0]))
	_show_page(false)
	drawer.hide()


func _page() -> Control:
	var page = Control.new()
	page.size = Vector2(604, 492)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.add_child(page)
	return page


func _show_page(fryer: bool) -> void:
	cancel_holds()
	order_page.visible = not fryer
	fryer_page.visible = fryer
	buttons.order_tab.add_theme_stylebox_override("normal", _style(PANEL if fryer else GOLD))
	buttons.order_tab.add_theme_color_override("font_color", CREAM if fryer else INK)
	buttons.fryer_tab.add_theme_stylebox_override("normal", _style(GOLD if fryer else PANEL))
	buttons.fryer_tab.add_theme_color_override("font_color", INK if fryer else CREAM)


func set_tools_open(open: bool) -> void:
	cancel_holds()
	drawer.visible = open
	tools_button.text = "Close" if open else "Tools"


func set_context(action: String, caption: String) -> void:
	# Do not rebind an in-progress hold when the model changes beneath a finger.
	if not _active_hold.is_empty() and _hold_button == context_button:
		return
	_context_action = action if action in ACTIONS else ""
	context_button.disabled = _context_action.is_empty()
	context_button.text = caption if not caption.is_empty() else "Tap a counter object"
	context_button.tooltip_text = ""


func _context_down() -> void:
	if _context_action in ["repair", "refill"]:
		_begin_hold(_context_action, context_button)


func _context_pressed() -> void:
	if not _context_action.is_empty() and _context_action not in ["repair", "refill"]:
		_emit_action(_context_action)


func _emit_action(action: String) -> void:
	cancel_holds()
	if is_instance_valid(drawer): drawer.hide()
	if is_instance_valid(tools_button): tools_button.text = "Tools"
	action_requested.emit(action)


func _begin_hold(action: String, button: Button) -> void:
	if button.disabled or not button.is_visible_in_tree(): return
	if _active_hold == action and _hold_button == button: return
	cancel_holds()
	_active_hold = action
	_hold_button = button
	hold_started.emit(action)


func _release_hold_for(button: Button) -> void:
	if _hold_button == button: cancel_holds()


func cancel_holds() -> void:
	if _active_hold.is_empty(): return
	var action = _active_hold
	_active_hold = ""
	_hold_button = null
	hold_ended.emit(action)


func _visibility_changed() -> void:
	if not is_visible_in_tree(): cancel_holds()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		cancel_holds()


func _exit_tree() -> void:
	cancel_holds()


func _style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color("52716b") if color != GOLD else Color("ffe1a6")
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _button(parent: Node, caption: String, at: Vector2, dimensions: Vector2, color: Color = PANEL) -> Button:
	var button = Button.new()
	button.text = caption
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", INK if color == GOLD else CREAM)
	button.add_theme_color_override("font_hover_color", INK if color == GOLD else CREAM)
	button.add_theme_color_override("font_pressed_color", INK if color == GOLD else CREAM)
	button.add_theme_color_override("font_disabled_color", Color("a6bdb8"))
	button.add_theme_stylebox_override("normal", _style(color))
	button.add_theme_stylebox_override("hover", _style(color.lightened(.08)))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(.10)))
	button.add_theme_stylebox_override("disabled", _style(PANEL.darkened(.12)))
	parent.add_child(button)
	return button
