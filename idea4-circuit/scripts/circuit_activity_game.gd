extends Control
## Original optional activity games. This control awards a score, never money or game state.
signal completed(score: float)
signal feedback(kind: String)

const FONT = preload("res://assets/fonts/Fredoka-Medium.ttf")
const NAVY = Color("142c40")
const INK = Color("0b1e2e")
const IVORY = Color("fff8e8")
const GOLD = Color("ffc857")
const CORAL = Color("ef6348")
const MINT = Color("31ba96")
const MUTED = Color("b2c6cb")
const FINISH_SECONDS = 1.25
const ORDER_PAUSE = 0.65
const DIRECTIONS = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const TITLES = {"repair": "Circuit rescue", "orders": "Order up!", "inspection": "Spot the trouble"}
const HINTS = {"repair": "Tap pipes to connect IN to OUT.", "orders": "Remember the orders from left to right.", "inspection": "Find four problems around the stand."}
const ORDER_NAMES = ["Sugar bag", "Cinnamon bag", "Sugar bucket", "Cinnamon bucket"]
const HAZARD_NAMES = ["Uncovered food", "Cleaner by food", "Floor spill", "Trailing cable"]

var kind = "repair"
var seed_value = 1
var difficulty = 0
var reduced_motion = false
var action_button: Button
var _title: Label
var _hint: Label
var _status: Label
var _controls: Array[Button] = []
var _scene_button: Button
var _icon: Texture2D
var _state = "playing"
var _time = 0.0
var _pause = 0.0
var _score = 0.0
var _emitted = false
var _particles: Array[Dictionary] = []
var _rng = RandomNumberGenerator.new()
var pipe_masks: Array[int] = []
var solution_masks: Array[int] = []
var solution_route: Array[int] = []
var _pipe_angles: Array[float] = []
var moves = 0
var optimal_moves = 0
var move_limit = 0
var order_sequence: Array[int] = []
var order_answers: Array[int] = []
var order_correct = 0
var hazards_found: Array[int] = []
var wrong_taps = 0
var _last_hazard = -1
var _wrong_point = Vector2.ZERO
var _wrong_flash = 0.0
var _inspection_mirrored = false
var _canopy_color = CORAL

func configure(activity_kind: String, new_seed: int, use_reduced_motion: bool, new_difficulty: int = 0) -> void:
	kind = activity_kind if TITLES.has(activity_kind) else "repair"
	seed_value = new_seed
	difficulty = clampi(new_difficulty, 0, 2)
	reduced_motion = use_reduced_motion
	_rng.seed = seed_value
	_state = "memorize" if kind == "orders" else "playing"
	_time = 0.0
	_pause = 0.0
	_score = 0.0
	_emitted = false
	_particles.clear()
	pipe_masks.clear()
	solution_masks.clear()
	solution_route.clear()
	_pipe_angles.clear()
	order_sequence.clear()
	order_answers.clear()
	hazards_found.clear()
	moves = 0
	optimal_moves = 0
	move_limit = 0
	order_correct = 0
	wrong_taps = 0
	_last_hazard = -1
	_wrong_flash = 0
	_inspection_mirrored = false
	_canopy_color = CORAL
	if kind == "repair": _make_repair()
	elif kind == "orders":
		for index in 4 + difficulty: order_sequence.append(_rng.randi_range(0, 3))
		# A memory game should contain at least two different orders.
		if order_sequence.all(func(value): return value == order_sequence[0]): order_sequence[1] = (order_sequence[0] + 1) % 4
	else:
		_inspection_mirrored = _rng.randi_range(0, 1) == 1
		_canopy_color = [CORAL, Color("537db5"), Color("8871b0")][_rng.randi_range(0, 2)]
	var icon_name = {"repair": "wrench", "orders": "bag", "inspection": "shield"}[kind]
	_icon = load("res://assets/ui/icons/" + icon_name + ".svg") as Texture2D
	if is_instance_valid(action_button):
		_build_controls()
		_layout()
		_update_labels()
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(0, 460)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	if _icon == null: configure(kind, seed_value, reduced_motion, difficulty)
	_title = _label("ActivityTitle", 24, IVORY)
	_hint = _label("ActivityInstructions", 13, MUTED)
	_status = _label("ActivityStatus", 16, GOLD)
	action_button = _button("ActivityAction", "", press_action, true)
	_build_controls()
	resized.connect(_layout)
	_layout()
	_update_labels()

func how_to() -> String:
	return {
		"repair": "Rotate each pipe clockwise. Join the inlet at the upper left to the outlet at the lower right before you run out of turns. Glowing pipes are connected to the inlet.",
		"orders": "Remember the pictured orders in order. Tap I'm ready, then choose the matching bag or bucket and coating for each customer. There is no timer.",
		"inspection": "Find uncovered food, cleaner beside food, a floor spill, and a trailing cable. Tap each problem in the scene. You have three wrong taps, and no timer."
	}[kind]

func _label(node_name: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(node_name: String, text: String, callback: Callable, primary: bool = false) -> Button:
	var button = Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 17)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color = GOLD if primary else Color.TRANSPARENT
		if state_name == "disabled": color = Color("355364") if primary else Color.TRANSPARENT
		if state_name == "hover" and not primary: color = Color(IVORY, 0.08)
		if state_name == "pressed" and not primary: color = Color(GOLD, 0.13)
		var style = _panel(color, 13)
		if primary:
			style.border_width_bottom = 1 if state_name == "pressed" else 4
			style.border_color = Color("b17e2b")
		if state_name == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = IVORY
		button.add_theme_stylebox_override(state_name, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(key, NAVY if primary else IVORY)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _build_controls() -> void:
	for control in _controls:
		remove_child(control)
		control.queue_free()
	_controls.clear()
	if is_instance_valid(_scene_button):
		remove_child(_scene_button)
		_scene_button.queue_free()
	_scene_button = null
	if kind == "repair":
		for index in 9:
			var button = _button("Pipe%d" % index, "", rotate_pipe.bind(index))
			button.tooltip_text = "Rotate pipe %d clockwise" % (index + 1)
			_controls.append(button)
	elif kind == "orders":
		for index in 4:
			var button = _button("Order%d" % index, "", choose_order.bind(index))
			button.tooltip_text = ORDER_NAMES[index]
			_controls.append(button)
	else:
		_scene_button = _button("InspectScene", "", inspect_empty)
		_scene_button.tooltip_text = "Inspect the stand. Find four problems."
		for index in 4:
			var button = _button("InspectArea%d" % index, "", inspect_hazard.bind(index))
			button.tooltip_text = ["Inspect counter area one", "Inspect counter area two", "Inspect floor area one", "Inspect floor area two"][index]
			_controls.append(button)
	# Controls sit above the illustrations. Header and action always remain reachable.
	move_child(action_button, get_child_count() - 1)

func _layout() -> void:
	if not is_instance_valid(action_button): return
	_title.position = Vector2(8, 20)
	_title.size = Vector2(size.x - 16, 34)
	_hint.position = Vector2(8, 57)
	_hint.size = Vector2(size.x - 16, 31)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.position = Vector2(10, 350)
	_status.size = Vector2(size.x - 20, 36)
	action_button.position = Vector2(14, 400)
	action_button.size = Vector2(size.x - 28, 48)
	for index in _controls.size():
		var rect = _pipe_rect(index) if kind == "repair" else _order_choice_rect(index) if kind == "orders" else _hazard_rect(index)
		_controls[index].position = rect.position
		_controls[index].size = rect.size
	if is_instance_valid(_scene_button):
		_scene_button.position = _scene_rect().position
		_scene_button.size = _scene_rect().size
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_wrong_flash = maxf(0, _wrong_flash - delta)
	for index in _pipe_angles.size(): _pipe_angles[index] = move_toward(_pipe_angles[index], 0, delta * 8)
	if _state == "order_feedback":
		_pause += delta
		if _pause >= ORDER_PAUSE:
			if order_answers.size() >= order_sequence.size(): _finish(float(order_correct) / order_sequence.size())
			else:
				_state = "answering"
				_update_labels()
	elif _state == "finishing":
		_pause += delta
		if _pause >= FINISH_SECONDS and not _emitted:
			_emitted = true
			_state = "complete"
			completed.emit(_score)
	if not reduced_motion:
		for particle in _particles:
			particle.age += delta
			particle.pos += particle.velocity * delta
			particle.velocity.y += delta * 160
		_particles = _particles.filter(func(particle): return particle.age < 1.05)
	queue_redraw()

func press_action() -> void:
	if _state in ["finishing", "complete"]: return
	if kind == "orders" and _state == "memorize":
		_state = "answering"
		_update_labels()
	elif kind == "repair":
		if repair_solved(): _finish(_repair_score())
		else:
			_status.text = "Follow the glow — a pipe is disconnected."
			_status.add_theme_font_size_override("font_size", 13)
	elif kind == "inspection":
		_hint.text = "Food • cleaner • floor spill • trailing cable"
	queue_redraw()

func _make_repair() -> void:
	var routes = [[0, 1, 4, 7, 8], [0, 3, 4, 5, 8], [0, 1, 2, 5, 8]]
	solution_route.assign(routes[_rng.randi_range(0, routes.size() - 1)])
	for index in 9:
		solution_masks.append(5 if _rng.randf() < 0.5 else 3)
		_pipe_angles.append(0.0)
	for route_index in solution_route.size():
		var cell = solution_route[route_index]
		var mask = 8 if route_index == 0 else _direction_bit(cell, solution_route[route_index - 1])
		mask |= 2 if route_index == solution_route.size() - 1 else _direction_bit(cell, solution_route[route_index + 1])
		solution_masks[cell] = mask
	for mask in solution_masks:
		var rotated = mask
		for turn in _rng.randi_range(0, 3): rotated = _rotate_mask(rotated)
		pipe_masks.append(rotated)
	# Every seed starts with a challenge, never a free solved board.
	if repair_solved(): pipe_masks[0] = _rotate_mask(pipe_masks[0])
	for cell in solution_route:
		var mask = pipe_masks[cell]
		while mask != solution_masks[cell]:
			mask = _rotate_mask(mask)
			optimal_moves += 1
	move_limit = optimal_moves + 8 - difficulty * 2

static func _rotate_mask(mask: int) -> int:
	return ((mask << 1) & 15) | (mask >> 3)

static func _direction_bit(from: int, to: int) -> int:
	var delta = Vector2i(to % 3 - from % 3, to / 3 - from / 3)
	return 1 << DIRECTIONS.find(delta)

func flow_path() -> Array[int]:
	var visited: Array[int] = []
	if pipe_masks.size() != 9 or (pipe_masks[0] & 8) == 0: return visited
	var pending: Array[int] = [0]
	while not pending.is_empty():
		var cell = pending.pop_front()
		if cell in visited: continue
		visited.append(cell)
		for direction in 4:
			if (pipe_masks[cell] & (1 << direction)) == 0: continue
			var next = Vector2i(cell % 3, cell / 3) + DIRECTIONS[direction]
			if next.x < 0 or next.x > 2 or next.y < 0 or next.y > 2: continue
			var next_cell = next.x + next.y * 3
			if (pipe_masks[next_cell] & (1 << ((direction + 2) % 4))) != 0 and not next_cell in visited: pending.append(next_cell)
	return visited

func repair_solved() -> bool:
	return pipe_masks.size() == 9 and 8 in flow_path() and (pipe_masks[8] & 2) != 0

func rotate_pipe(index: int) -> void:
	if kind != "repair" or _state != "playing" or index < 0 or index >= 9: return
	pipe_masks[index] = _rotate_mask(pipe_masks[index])
	_pipe_angles[index] = -PI * 0.5 if not reduced_motion else 0.0
	moves += 1
	if repair_solved(): _finish(_repair_score())
	elif moves >= move_limit: _finish(0.0)
	else: _update_labels()
	queue_redraw()

func _repair_score() -> float:
	return clampf(1.0 - maxf(0, moves - optimal_moves) * 0.07, 0.4, 1.0)

func choose_order(order_id: int) -> void:
	if kind != "orders" or _state != "answering" or order_id < 0 or order_id > 3: return
	var correct = order_sequence[order_answers.size()] == order_id
	order_answers.append(order_id)
	if correct: order_correct += 1
	_state = "order_feedback"
	_pause = 0.0
	feedback.emit("batch_perfect" if correct else "batch_good")
	if correct and not reduced_motion: _burst(_order_choice_rect(order_id).get_center(), 10)
	_update_labels()
	queue_redraw()

func inspect_hazard(index: int) -> void:
	if kind != "inspection" or _state != "playing" or index < 0 or index >= 4 or index in hazards_found: return
	hazards_found.append(index)
	_last_hazard = index
	feedback.emit("batch_perfect")
	if not reduced_motion: _burst(_hazard_rect(index).get_center(), 12)
	if hazards_found.size() == 4: _finish(clampf(1.0 - wrong_taps * 0.1, 0, 1))
	else: _update_labels()
	queue_redraw()

func inspect_empty() -> void:
	if kind != "inspection" or _state != "playing": return
	wrong_taps += 1
	_wrong_point = get_local_mouse_position()
	_wrong_flash = 0.5
	feedback.emit("batch_good")
	if wrong_taps >= 3: _finish(float(hazards_found.size()) / 4.0 * 0.8)
	else: _update_labels()
	queue_redraw()

func total_score() -> float:
	return _score

func _finish(score: float) -> void:
	if _state in ["finishing", "complete"]: return
	_score = clampf(score, 0.0, 1.0)
	_state = "finishing"
	_pause = 0
	feedback.emit("batch_finish")
	if not reduced_motion: _burst(Vector2(size.x * 0.5, 218), 26)
	_update_labels()
	queue_redraw()

func _update_labels() -> void:
	if not is_instance_valid(action_button): return
	var final = _state in ["finishing", "complete"]
	_title.text = ("Brilliant work!" if _score >= 0.9 else "Job done!" if _score >= 0.4 else "A learning moment") if final else TITLES[kind]
	_hint.text = "Your result is ready." if final else HINTS[kind]
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", GOLD)
	for index in _controls.size():
		_controls[index].visible = not final and (kind != "orders" or _state != "memorize")
		_controls[index].disabled = final or (kind == "orders" and _state != "answering")
	if is_instance_valid(_scene_button): _scene_button.visible = not final
	action_button.disabled = final or (kind == "orders" and _state != "memorize")
	if final:
		_status.text = "%d / 100" % roundi(_score * 100)
		action_button.text = "RESULT READY"
	elif kind == "repair":
		_status.text = "%d turns left" % (move_limit - moves)
		action_button.text = "TEST THE CONNECTION"
		action_button.tooltip_text = how_to()
	elif kind == "orders":
		action_button.text = "I'M READY" if _state == "memorize" else "CHOOSE THE MATCHING ORDER"
		if _state == "memorize":
			_status.text = "Take your time. No timer."
		elif _state == "order_feedback":
			var correct = order_answers.back() == order_sequence[order_answers.size() - 1]
			_status.text = "That's the one!" if correct else "It was: " + ORDER_NAMES[order_sequence[order_answers.size() - 1]]
			_status.add_theme_color_override("font_color", MINT if correct else CORAL)
		else:
			_hint.text = "Which order came next?"
			_status.text = "Customer %d of %d" % [order_answers.size() + 1, order_sequence.size()]
	else:
		_status.text = "%d / 4 fixed   ·   %d mistakes left" % [hazards_found.size(), 3 - wrong_taps]
		if _last_hazard >= 0: _hint.text = HAZARD_NAMES[_last_hazard] + " — sorted!"
		action_button.text = "WHAT AM I LOOKING FOR?"
		action_button.tooltip_text = how_to()

func _pipe_rect(index: int) -> Rect2:
	var cell = minf(70, (size.x - 90) / 3.0)
	return Rect2(Vector2((size.x - cell * 3) * 0.5 + (index % 3) * cell, 109 + (index / 3) * cell), Vector2(cell - 4, cell - 4))

func _order_choice_rect(index: int) -> Rect2:
	var width = (size.x - 44) * 0.5
	return Rect2(16 + (index % 2) * (width + 12), 188 + (index / 2) * 77, width, 69)

func _scene_rect() -> Rect2:
	return Rect2(16, 110, size.x - 32, 232)

func _hazard_rect(index: int) -> Rect2:
	var scene = _scene_rect()
	var regions = [Rect2(0.055, 0.31, 0.25, 0.28), Rect2(0.36, 0.32, 0.17, 0.28), Rect2(0.06, 0.73, 0.30, 0.24), Rect2(0.61, 0.73, 0.30, 0.24)]
	var region: Rect2 = regions[index]
	if _inspection_mirrored: region.position.x = 1.0 - region.end.x
	return Rect2(scene.position + region.position * scene.size, region.size * scene.size)

func _draw() -> void:
	if size.x < 1: return
	draw_style_box(_panel(NAVY, 22), Rect2(Vector2.ZERO, size))
	# Small marquee lights and a recessed play surface create fairground depth.
	for index in 9:
		var pos = Vector2(22 + index * (size.x - 44) / 8.0, 8)
		draw_circle(pos, 4.5, Color(GOLD, 0.07))
		draw_circle(pos, 2, GOLD if index % 2 else MINT)
	draw_style_box(_panel(INK, 15), Rect2(10, 99, size.x - 20, 247))
	if _state in ["finishing", "complete"]: _draw_finish()
	elif kind == "repair": _draw_repair()
	elif kind == "orders": _draw_orders()
	else: _draw_inspection()
	if not reduced_motion:
		for particle in _particles:
			var alpha = 1.0 - float(particle.age) / 1.05
			_spark(particle.pos, particle.radius, Color(particle.color, alpha))

func _draw_repair() -> void:
	var flowing = flow_path()
	var first = _pipe_rect(0)
	var last = _pipe_rect(8)
	var in_pos = Vector2(first.position.x - 17, first.get_center().y)
	var out_pos = Vector2(last.end.x + 17, last.get_center().y)
	draw_line(in_pos, Vector2(first.position.x, in_pos.y), MINT, 10, true)
	draw_line(Vector2(last.end.x, out_pos.y), out_pos, GOLD, 10, true)
	_center_text("IN", in_pos + Vector2(-1, 26), 11, MINT)
	_center_text("OUT", out_pos + Vector2(0, 26), 10, GOLD)
	for index in 9:
		var rect = _pipe_rect(index)
		var center = rect.get_center()
		var powered = index in flowing
		draw_style_box(_panel(Color("234959") if powered else Color("233749"), 10), rect)
		draw_line(rect.position + Vector2(9, 2), Vector2(rect.end.x - 9, rect.position.y + 2), Color(IVORY, 0.15), 1, true)
		for corner in [rect.position + Vector2(7, 7), rect.end - Vector2(7, 7)]:
			draw_circle(corner, 2.3, Color("59717c"))
			draw_line(corner - Vector2(1.4, 0), corner + Vector2(1.4, 0), INK, 1, true)
		draw_set_transform(center, _pipe_angles[index])
		for direction in 4:
			if (pipe_masks[index] & (1 << direction)) == 0: continue
			var end = Vector2(DIRECTIONS[direction]) * (rect.size.x * 0.51)
			draw_line(Vector2(1, 3), end + Vector2(1, 3), Color("081722"), 18, true)
			draw_line(Vector2.ZERO, end, Color("769ca1"), 15, true)
			draw_line(Vector2.ZERO, end, MINT if powered else Color("bfd1c8"), 8, true)
			if powered:
				var flow = 0.55 if reduced_motion else fposmod(_time * 0.9 + index * 0.2, 1.0)
				draw_circle(end * flow, 2.4, IVORY)
		draw_circle(Vector2.ZERO, 7, MINT if powered else Color("bfd1c8"))
		draw_set_transform(Vector2.ZERO)
	_center_text("ROTATE  ↻  CONNECT", Vector2(size.x * 0.5, 336), 11, MUTED)

func _draw_orders() -> void:
	var count = order_sequence.size()
	var card_width = minf(68, (size.x - 38) / count)
	var total_width = card_width * count
	for index in count:
		var rect = Rect2((size.x - total_width) * 0.5 + index * card_width, 111, card_width - 4, 65)
		var answered = index < order_answers.size()
		var correct = answered and order_answers[index] == order_sequence[index]
		var active = index == order_answers.size() and _state == "answering"
		draw_style_box(_panel(Color("225c56") if correct else Color("633d3d") if answered else Color("294757"), 9), rect)
		if active: draw_style_box(_outline(GOLD, 9), rect)
		if _state == "memorize":
			_draw_order(order_sequence[index], rect.get_center() + Vector2(0, -4), minf(0.73, card_width / 72))
			_center_text(str(index + 1), Vector2(rect.get_center().x, rect.end.y - 4), 10, MUTED)
		else:
			_center_text(str(index + 1), rect.get_center() + Vector2(0, 1), 20, IVORY)
			if answered:
				if correct: _tick(rect.get_center() + Vector2(0, 20), 6, MINT)
				else: _cross(rect.get_center() + Vector2(0, 20), 4, CORAL)
	if _state == "memorize":
		# The four illustrations below explain the vocabulary before anything is hidden.
		_center_text("THE MENU", Vector2(size.x * 0.5, 207), 11, GOLD)
		for index in 4:
			var width = (size.x - 36) / 4.0
			var center = Vector2(18 + (index + 0.5) * width, 252)
			_draw_order(index, center, 0.82)
			_center_text("Bag" if index < 2 else "Bucket", center + Vector2(0, 42), 12, IVORY)
			_center_text("Sugar" if index % 2 == 0 else "Cinnamon", center + Vector2(0, 58), 11, MUTED)
	else:
		for index in 4:
			var rect = _order_choice_rect(index)
			draw_style_box(_panel(Color("28495c"), 11), rect)
			draw_line(rect.position + Vector2(12, 2), Vector2(rect.end.x - 12, rect.position.y + 2), Color(IVORY, 0.17), 1, true)
			_draw_order(index, rect.position + Vector2(29, 33), 0.74)
			_center_text("Sugar" if index % 2 == 0 else "Cinnamon", rect.position + Vector2(rect.size.x * 0.68, 29), 12, IVORY)
			_center_text("BAG" if index < 2 else "BUCKET", rect.position + Vector2(rect.size.x * 0.68, 47), 10, MUTED)

func _draw_order(order_id: int, center: Vector2, scale_value: float) -> void:
	draw_set_transform(center, 0, Vector2.ONE * scale_value)
	var sugar = order_id % 2 == 0
	var color = IVORY if sugar else Color("b66e35")
	if order_id < 2:
		draw_colored_polygon(PackedVector2Array([Vector2(-22, -20), Vector2(-14, -25), Vector2(-8, -20), Vector2(0, -24), Vector2(8, -20), Vector2(20, -24), Vector2(17, 25), Vector2(-18, 25)]), Color("e5b574"))
		draw_colored_polygon(PackedVector2Array([Vector2(13, -21), Vector2(20, -24), Vector2(17, 25), Vector2(10, 19)]), Color("ba804c"))
		draw_line(Vector2(-14, -12), Vector2(-12, 18), Color("ffda9a"), 2, true)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-26, -18), Vector2(26, -18), Vector2(19, 25), Vector2(-19, 25)]), CORAL)
		for x in [-15, -1, 13]: draw_line(Vector2(x, -15), Vector2(x * 0.72, 22), IVORY, 6, true)
		_ellipse(Vector2(0, -18), Vector2(26, 9), Color("ad6938"))
		for index in 5: _donut(Vector2(-15 + index * 7, -20 + (index % 2) * 4), 7, sugar)
		_ellipse(Vector2(0, -13), Vector2(25, 4), Color("f9d08b"))
	draw_circle(Vector2(0, 3), 15, NAVY)
	_donut(Vector2(0, 3), 11, sugar)
	if sugar:
		for index in 5: draw_circle(Vector2(-6 + (index % 3) * 6, -4 + (index / 3) * 7), 1.2, color)
	else:
		draw_line(Vector2(-7, 13), Vector2(7, 16), color, 3, true)
		draw_line(Vector2(-5, 16), Vector2(9, 19), color, 3, true)
	draw_set_transform(Vector2.ZERO)

func _draw_inspection() -> void:
	var rect = _scene_rect()
	var scale_x = rect.size.x / 308.0
	draw_set_transform(rect.position + Vector2(rect.size.x if _inspection_mirrored else 0, 0), 0, Vector2(-scale_x if _inspection_mirrored else scale_x, 1))
	draw_style_box(_panel(Color("204657"), 11), Rect2(0, 0, 308, 232))
	# Night sky, a striped canopy, and a warm lamp make a miniature stand.
	for index in 9: _spark(Vector2(12 + index * 34, 16 + (index % 3) * 9), 1.2, Color(IVORY, 0.4))
	draw_rect(Rect2(20, 27, 267, 35), Color("ecb94f"))
	for index in 9:
		var x = 20 + index * 30
		draw_rect(Rect2(x, 27, 16, 35), _canopy_color)
		_ellipse(Vector2(x + 8, 62), Vector2(8, 5), _canopy_color)
		draw_line(Vector2(24, 62), Vector2(24, 165), Color("a2b7ac"), 5, true)
		draw_line(Vector2(282, 62), Vector2(282, 165), Color("a2b7ac"), 5, true)
	for index in 5:
		draw_circle(Vector2(50 + index * 51, 71), 6, Color(GOLD, 0.1))
		draw_circle(Vector2(50 + index * 51, 71), 2.6, GOLD)
	# Neutral fryer and stack of bags are deliberately not hazards.
	draw_style_box(_panel(Color("94b3b6"), 6), Rect2(184, 91, 65, 34))
	draw_style_box(_panel(Color("4c7280"), 4), Rect2(190, 91, 53, 8))
	draw_circle(Vector2(201, 114), 3, INK)
	draw_circle(Vector2(231, 114), 3, MINT)
	for index in 3: draw_rect(Rect2(255 + index * 2, 101 - index * 4, 14, 25), Color("dfb780"))
	# Counter and rolling cabinet.
	draw_style_box(_panel(Color("c56f41"), 6), Rect2(26, 128, 256, 47))
	draw_rect(Rect2(22, 124, 264, 9), Color("f1cc92"))
	draw_rect(Rect2(28, 136, 252, 4), Color("93503b"))
	draw_circle(Vector2(68, 175), 9, INK)
	draw_circle(Vector2(242, 175), 9, INK)
	draw_circle(Vector2(155, 154), 17, NAVY)
	_donut(Vector2(155, 154), 12, true)
	# 1. Uncovered food attracts conspicuous little flies; finding it closes the lid.
	draw_style_box(_panel(Color("abc7c7"), 4), Rect2(29, 108, 60, 14))
	for index in 4: _donut(Vector2(38 + index * 13, 108 - (index % 2) * 3), 7, false)
	if 0 in hazards_found:
		draw_style_box(_panel(Color("bdd2cd"), 7), Rect2(27, 99, 64, 12))
		draw_line(Vector2(51, 96), Vector2(65, 96), IVORY, 3, true)
	else:
		for index in 3:
			var bob = 0.0 if reduced_motion else sin(_time * 4 + index) * 2
			var pos = Vector2(39 + index * 20, 89 - (index % 2) * 7 + bob)
			_ellipse(pos + Vector2(-3, -2), Vector2(4, 2.5), Color(IVORY, 0.8))
			_ellipse(pos + Vector2(3, -2), Vector2(4, 2.5), Color(IVORY, 0.8))
			draw_circle(pos, 2.8, INK)
	# 2. A conspicuous cleaning bottle sitting beside the tray.
	if not 1 in hazards_found:
		draw_style_box(_panel(Color("a0d5b5"), 4), Rect2(118, 96, 18, 27))
		draw_rect(Rect2(122, 90, 9, 9), Color("75a0a4"))
		draw_colored_polygon(PackedVector2Array([Vector2(122, 88), Vector2(140, 88), Vector2(140, 94), Vector2(128, 94)]), CORAL)
		draw_rect(Rect2(120, 104, 14, 11), IVORY)
		_cross(Vector2(127, 109), 3, CORAL)
	else:
		draw_rect(Rect2(121, 111, 14, 12), Color("ce8452"))
		draw_line(Vector2(128, 111), Vector2(128, 97), MINT, 3, true)
		_ellipse(Vector2(123, 102), Vector2(6, 3), MINT)
		_spark(Vector2(128, 96), 6, GOLD)
	# 3. A shiny, spreading puddle on the walkway.
	if not 2 in hazards_found:
		_ellipse(Vector2(67, 199), Vector2(40, 12), Color("80603a"))
		_ellipse(Vector2(58, 196), Vector2(23, 6), Color("c9944d"))
		_ellipse(Vector2(84, 197), Vector2(18, 6), Color("b47a36"))
		draw_arc(Vector2(54, 197), 11, PI * 1.1, PI * 1.7, 10, Color("eac783"), 2, true)
	else:
		_spark(Vector2(53, 196), 6, MINT)
		_spark(Vector2(83, 204), 4, IVORY)
	# 4. A loop of loose electrical cable crosses the walkway.
	if not 3 in hazards_found:
		var points = PackedVector2Array([Vector2(225, 174), Vector2(223, 186), Vector2(256, 188), Vector2(265, 199), Vector2(255, 207), Vector2(214, 207), Vector2(205, 198), Vector2(218, 193), Vector2(237, 201)])
		draw_polyline(points, INK, 8, true)
		draw_polyline(points, Color("f0ba4e"), 3, true)
		draw_style_box(_panel(CORAL, 3), Rect2(232, 197, 13, 9))
	else:
		for index in 3: draw_arc(Vector2(259, 156), 7 + index * 2, 0, TAU, 28, Color("e3b454"), 2, true)
	draw_set_transform(Vector2.ZERO)
	for index in hazards_found:
		var center = _hazard_rect(index).get_center()
		draw_circle(center, 12, MINT)
		_tick(center, 6, INK)
	if _wrong_flash > 0 and not reduced_motion:
		draw_circle(_wrong_point, 15, Color(CORAL, _wrong_flash * 0.35))
		_cross(_wrong_point, 5, CORAL)

func _draw_finish() -> void:
	var center = Vector2(size.x * 0.5, 214)
	var bounce = 1.0 if reduced_motion else 1.0 + sin(minf(_pause * 6, PI)) * 0.08
	for index in 12:
		var angle = index * TAU / 12 + (0 if reduced_motion else _time * 0.07)
		draw_line(center + Vector2.from_angle(angle) * 72, center + Vector2.from_angle(angle) * 86, Color(GOLD, 0.3), 3, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-35, 28), center + Vector2(-54, 94), center + Vector2(-31, 82), center + Vector2(-17, 101), center + Vector2(0, 38)]), CORAL)
	draw_colored_polygon(PackedVector2Array([center + Vector2(35, 28), center + Vector2(54, 94), center + Vector2(31, 82), center + Vector2(17, 101), center + Vector2(0, 38)]), Color("b84439"))
	draw_circle(center, 61 * bounce, Color("b58432"))
	draw_circle(center + Vector2(0, -3), 57 * bounce, GOLD)
	draw_circle(center + Vector2(0, -3), 49 * bounce, Color("ffe5a7"))
	if is_instance_valid(_icon): draw_texture_rect(_icon, Rect2(center - Vector2(29, 32) * bounce, Vector2(58, 58) * bounce), false, NAVY)
	for index in 3:
		var threshold = [0.25, 0.65, 0.9][index]
		_spark(center + Vector2((index - 1) * 28, -82), 9 if index == 1 else 7, GOLD if _score >= threshold else Color("38505f"))

func _donut(center: Vector2, radius: float, sugar: bool) -> void:
	_ellipse(center + Vector2(0, 2), Vector2(radius, radius * 0.67), Color("9b542e"))
	_ellipse(center, Vector2(radius, radius * 0.65), Color("e5ac55"))
	_ellipse(center - Vector2(1, 1), Vector2(radius * 0.82, radius * 0.48), IVORY if sugar else Color("bf7b3f"))
	_ellipse(center, Vector2(radius * 0.12, radius * 0.15), Color("784127"))

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for index in 32: points.append(center + Vector2.from_angle(index * TAU / 32) * radii)
	draw_colored_polygon(points, color)

func _tick(point: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([point + Vector2(-radius, 0), point + Vector2(-radius * 0.2, radius * 0.65), point + Vector2(radius, -radius * 0.65)]), color, 3, true)

func _cross(point: Vector2, radius: float, color: Color) -> void:
	draw_line(point - Vector2(radius, radius), point + Vector2(radius, radius), color, 2.5, true)
	draw_line(point + Vector2(-radius, radius), point + Vector2(radius, -radius), color, 2.5, true)

func _spark(point: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius * 0.3, -radius * 0.3), point + Vector2(radius, 0), point + Vector2(radius * 0.3, radius * 0.3), point + Vector2(0, radius), point + Vector2(-radius * 0.3, radius * 0.3), point + Vector2(-radius, 0), point + Vector2(-radius * 0.3, -radius * 0.3)]), color)

func _burst(point: Vector2, count: int) -> void:
	for index in count:
		var angle = index * TAU / count - PI / 2
		_particles.append({"pos": point, "velocity": Vector2.from_angle(angle) * (40 + (index % 5) * 14) + Vector2(0, -35), "age": 0.0, "radius": 2.0 + index % 3, "color": [GOLD, IVORY, MINT, CORAL][index % 4]})

func _center_text(text: String, point: Vector2, font_size: int, color: Color) -> void:
	var width = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(FONT, point - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _panel(color: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

func _outline(color: Color, radius: int) -> StyleBoxFlat:
	var style = _panel(Color.TRANSPARENT, radius)
	style.set_border_width_all(2)
	style.border_color = color
	return style
