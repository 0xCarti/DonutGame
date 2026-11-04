extends Control
## Bounded, input-transparent celebration layer in the 1280x800 UI coordinate space.

const COLORS = [Color("ffe1ac"), Color("ffc05e"), Color("7cf6d5"), Color("ffdb79")]
const CREAM = Color("fff4d8")
var reduced_motion: bool = false
var active_receipt: Dictionary = {}
var age: float = 10.0
var lifetime: float = 2.2
var coins: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var _rng = RandomNumberGenerator.new()
var _heading: Label
var _amount: Label
var _detail: Label
var _chain: Label
var _goal: Label
var _group: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 800)
	_rng.seed = 914
	_group = Control.new()
	_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_group.position = Vector2(340, 186)
	_group.size = Vector2(600, 170)
	_group.pivot_offset = Vector2(300, 70)
	add_child(_group)
	_heading = _text(Vector2(0, 0), Vector2(600, 34), 25)
	_amount = _text(Vector2(0, 25), Vector2(600, 95), 70)
	_detail = _text(Vector2(10, 115), Vector2(580, 42), 17)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chain = _text(Vector2(0, 158), Vector2(600, 26), 17)
	_goal = _text(Vector2(0, 190), Vector2(600, 35), 24)
	_group.visible = false

func _text(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label = Label.new()
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_color_override("font_outline_color", Color("172a30"))
	label.add_theme_constant_override("outline_size", 8 if font_size > 30 else 5)
	_group.add_child(label)
	return label

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		coins.clear()
		trails.clear()
		_group.scale = Vector2.ONE
		if not active_receipt.is_empty():
			_amount.text = "+$%d" % int(float(active_receipt.amount))
	queue_redraw()

func reset() -> void:
	active_receipt.clear()
	coins.clear()
	trails.clear()
	age = 10.0
	if is_instance_valid(_group): _group.visible = false
	queue_redraw()

func celebrate(receipt: Dictionary, origin: Vector2) -> void:
	if receipt.is_empty(): return
	active_receipt = receipt.duplicate()
	var tier: int = clampi(int(receipt.get("tier", 0)), 0, 3)
	age = 0.0
	lifetime = 1.7 + float(tier) * 0.2
	_group.visible = true
	_group.modulate.a = 1.0
	_heading.text = str(receipt.get("title", "FRESH SALE"))
	_heading.add_theme_color_override("font_color", COLORS[tier])
	_amount.add_theme_font_size_override("font_size", 54 + tier * 10)
	_amount.text = "+$%d" % int(float(receipt.amount)) if reduced_motion else "+$0"
	_detail.text = str(receipt.get("combo", ""))
	var multiplier: float = float(receipt.get("multiplier", 1.0))
	if multiplier > 1.0:
		_detail.text += "  |  %.1f× tray bonus" % multiplier
	_chain.text = "%d TRAYS IN A ROW" % int(receipt.chain) if int(receipt.get("chain", 0)) >= 2 else ""
	_goal.text = "TARGET SMASHED!" if bool(receipt.get("goal", false)) else ""
	_goal.add_theme_color_override("font_color", Color("99f0cc"))
	if not reduced_motion:
		var count: int = 5 + tier * 7
		for i in range(count):
			var offset = Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-100, -40))
			coins.append({"start": origin, "bend": origin + offset, "end": Vector2(480, 62), "age": -float(i) * 0.018, "duration": 0.65 + _rng.randf_range(0.0, 0.25), "tier": tier})
		while coins.size() > 84: coins.pop_front()
		trails.append({"origin": origin, "age": 0.0, "tier": tier})
		while trails.size() > 4: trails.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if _group.visible:
		var fade = 1.0 - smoothstep(lifetime - 0.4, lifetime, age)
		_group.modulate.a = fade
		if reduced_motion:
			_group.scale = Vector2.ONE
		else:
			var tier: int = int(active_receipt.get("tier", 0))
			var pop: float = 1.0 + sin(minf(age / 0.3, 1.0) * PI) * (0.07 + tier * 0.035)
			_group.scale = Vector2.ONE * pop
			var progress: float = 1.0 - pow(1.0 - minf(age / 0.45, 1.0), 3.0)
			_amount.text = "+$%d" % int(float(active_receipt.get("amount", 0)) * progress)
		if age >= lifetime: _group.visible = false
	for i in range(coins.size() - 1, -1, -1):
		coins[i].age += delta
		if float(coins[i].age) > float(coins[i].duration): coins.remove_at(i)
	for i in range(trails.size() - 1, -1, -1):
		trails[i].age += delta
		if float(trails[i].age) > 0.7: trails.remove_at(i)
	if _group.visible or not coins.is_empty() or not trails.is_empty():
		queue_redraw()
	elif age < lifetime + delta * 2.0:
		queue_redraw()

func _draw() -> void:
	if not active_receipt.is_empty() and age < lifetime:
		var tier: int = clampi(int(active_receipt.get("tier", 0)), 0, 3)
		var glow: float = exp(-age * 2.7) * (0.07 + tier * 0.045)
		if reduced_motion: glow *= 0.3
		for edge in range(6):
			var color: Color = COLORS[tier]
			color.a = glow * (1.0 - float(edge) / 6.0)
			draw_rect(Rect2(Vector2.ONE * edge * 7, Vector2(1280, 800) - Vector2.ONE * edge * 14), color, false, 7.0)
		if not reduced_motion and tier >= 2 and age < 0.7:
			for ray in range(16):
				var angle: float = float(ray) * TAU / 16.0
				var direction = Vector2(cos(angle), sin(angle))
				var color: Color = COLORS[tier]
				color.a = (1.0 - age / 0.7) * 0.4
				draw_line(Vector2(640, 268) + direction * (85 + age * 100), Vector2(640, 268) + direction * (125 + age * 160), color, 3.0, true)
	for trail in trails:
		var progress: float = float(trail.age) / 0.7
		var color: Color = COLORS[int(trail.tier)]
		color.a = (1.0 - progress) * 0.7
		draw_arc(trail.origin, 18 + progress * 70, 0, TAU, 40, color, 3 * (1.0 - progress), true)
	for coin in coins:
		if float(coin.age) < 0: continue
		var progress: float = clampf(float(coin.age) / float(coin.duration), 0, 1)
		var a: Vector2 = coin.start.lerp(coin.bend, progress)
		var b: Vector2 = coin.bend.lerp(coin.end, progress)
		var position_value: Vector2 = a.lerp(b, progress)
		var color: Color = COLORS[int(coin.tier)]
		color.a = 1.0 - smoothstep(0.82, 1.0, progress)
		draw_circle(position_value, 5.0, color)
		draw_circle(position_value + Vector2(-1, -1), 2.0, Color(1, 0.97, 0.85, color.a))
