extends Control
## Presentation only: authoritative receipts drive exact payout text and tiers.
## All drawing is bounded and transparent to mouse/keyboard interaction.

const GOLD = Color("ffc766")
const CREAM = Color("fff2d5")
const MINT = Color("a8ead2")
const INK = Color("102c30")
const PALETTE = [Color("edc78b"), Color("ffc766"), Color("a8ead2"), Color("ffdf8c")]
const TITLES = ["FRESHLY SERVED", "ON A ROLL", "RUSH ROYALTY", "GOLDEN HOUR!"]
const MAX_COINS = 48
const MAX_SPARKS = 70

var reduced_motion = false
var active_receipt: Dictionary = {}
var coins: Array = []
var sparks: Array = []
var age = 10.0
var duration = 2.0
var tier = 0
var goal_age = 10.0
var fault_age = 10.0
var fault_code = ""
var _rng = RandomNumberGenerator.new()
var _group: Control
var _title: Label
var _amount: Label
var _detail: Label
var _chain: Label
var _goal: Label
var _flash = 0.0

static func tier_for(receipt: Dictionary) -> int:
	var streak = int(receipt.get("streak", 1))
	if streak >= 10: return 3
	if streak >= 6 or float(receipt.get("amount", 0)) >= 45.0: return 2
	if streak >= 3: return 1
	return 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(1280, 800)
	z_index = 20
	_rng.seed = 70519
	_group = Control.new()
	_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_group.position = Vector2(380, 174)
	_group.size = Vector2(520, 174)
	_group.pivot_offset = Vector2(260, 74)
	add_child(_group)
	_title = _label(_group, Vector2(0, 9), Vector2(520, 30), 19, GOLD)
	_amount = _label(_group, Vector2(0, 28), Vector2(520, 80), 62, CREAM)
	_detail = _label(_group, Vector2(0, 108), Vector2(520, 36), 13, CREAM)
	_chain = _label(_group, Vector2(0, 151), Vector2(520, 20), 14, MINT)
	_goal = _label(self, Vector2(375, 345), Vector2(530, 54), 24, MINT)
	_goal.visible = false
	_group.visible = false

func _label(parent: Control, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		coins.clear()
		sparks.clear()
		_flash = 0.0
		if is_instance_valid(_group): _group.scale = Vector2.ONE
	queue_redraw()

func reset() -> void:
	active_receipt.clear()
	coins.clear()
	sparks.clear()
	age = 10.0
	goal_age = 10.0
	fault_age = 10.0
	_flash = 0.0
	if is_instance_valid(_group): _group.visible = false
	if is_instance_valid(_goal): _goal.visible = false
	queue_redraw()

func celebrate(receipt: Dictionary, origin: Vector2 = Vector2(680, 340)) -> void:
	if receipt.is_empty() or not is_finite(float(receipt.get("amount", 0))) or float(receipt.get("amount", 0)) <= 0: return
	active_receipt = receipt.duplicate(true)
	tier = tier_for(receipt)
	age = 0.0
	duration = 1.65 + float(tier) * 0.27
	_group.visible = true
	_group.modulate.a = 1.0
	_title.text = TITLES[tier]
	_title.add_theme_color_override("font_color", PALETTE[tier])
	_amount.add_theme_font_size_override("font_size", 54 + tier * 8)
	_amount.text = _money(float(receipt.amount)) if reduced_motion else "+$0"
	var tip = float(receipt.get("tip", 0))
	var base = float(receipt.get("base", receipt.get("base_price", float(receipt.amount) - tip)))
	_detail.text = "$%.2f order  +  $%.2f tip" % [base, tip]
	var bonuses: Array[String] = []
	for part in [["patience_tip", "Speed"], ["streak_tip", "Streak"], ["upgrade_tip", "Bonuses"]]:
		var value = float(receipt.get(part[0], 0))
		if value > 0: bonuses.append("%s $%.2f" % [part[1], value])
	if not bonuses.is_empty(): _detail.text += "\n" + "  ·  ".join(bonuses)
	_chain.text = "%d HAPPY CUSTOMERS IN A ROW" % int(receipt.get("streak", 1)) if int(receipt.get("streak", 1)) >= 2 else "HOT DONUTS. HAPPY CUSTOMER."
	_flash = (0.08 + tier * 0.045) if not reduced_motion else 0.0
	if reduced_motion:
		queue_redraw()
		return
	var count = 6 + tier * 5
	for i in range(count):
		if coins.size() >= MAX_COINS: coins.pop_front()
		var start = origin + Vector2(_rng.randf_range(-28, 28), _rng.randf_range(-12, 18))
		coins.append({"start": start, "bend": start + Vector2(_rng.randf_range(-150, 120), -_rng.randf_range(140, 240)), "end": Vector2(110, 58), "age": -float(i) * 0.024, "life": 0.65 + _rng.randf_range(0, 0.30), "r": 4.0 + tier * 0.55})
	for i in range(10 + tier * 12):
		if sparks.size() >= MAX_SPARKS: sparks.pop_front()
		var angle = _rng.randf_range(-PI, 0)
		sparks.append({"position": Vector2(640, 263), "velocity": Vector2(cos(angle), sin(angle)) * _rng.randf_range(70, 180 + tier * 35), "age": 0.0, "life": _rng.randf_range(0.6, 1.4), "rotation": _rng.randf_range(-PI, PI), "color": PALETTE[_rng.randi_range(0, 3)]})
	queue_redraw()

func show_goal() -> void:
	goal_age = 0.0
	_goal.text = "SHIFT TARGET CLEARED"
	_goal.visible = true
	_goal.modulate.a = 1
	queue_redraw()

func notify_fault(code: String, _title_text: String = "") -> void:
	# Persistent wording and repair instructions live in the HUD.
	# This onset pulse directs attention without occupying another message box.
	fault_code = code
	fault_age = 0.0
	queue_redraw()

func _money(amount: float) -> String:
	return "+$%d" % int(amount) if is_equal_approx(amount, roundf(amount)) else "+$%.2f" % amount

func _process(delta: float) -> void:
	var step = minf(delta, 0.1)
	age += step
	goal_age += step
	fault_age += step
	_flash = maxf(0, _flash - step * 0.45)
	if not active_receipt.is_empty() and age < duration:
		var progress = 1.0 if reduced_motion else ease(clampf(age / 0.45, 0, 1), 0.3)
		_amount.text = _money(snappedf(float(active_receipt.amount) * progress, 0.01))
		_group.modulate.a = 1.0 - smoothstep(duration - 0.4, duration, age)
		if not reduced_motion:
			var pop = sin(clampf(age / 0.26, 0, 1) * PI) * (0.035 + tier * 0.018)
			_group.scale = Vector2.ONE * (1 + pop)
	else:
		_group.visible = false
	_goal.visible = goal_age < 2.7
	_goal.modulate.a = 1.0 - smoothstep(2.2, 2.7, goal_age)
	for i in range(coins.size() - 1, -1, -1):
		coins[i].age += step
		if float(coins[i].age) > float(coins[i].life): coins.remove_at(i)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].age += step
		sparks[i].position += Vector2(sparks[i].velocity) * step
		sparks[i].velocity.y += step * 115
		sparks[i].rotation += step * 2.6
		if float(sparks[i].age) > float(sparks[i].life): sparks.remove_at(i)
	if age < duration + 0.1 or not coins.is_empty() or not sparks.is_empty() or goal_age < 3 or fault_age < 1.5:
		queue_redraw()

func _draw() -> void:
	if not active_receipt.is_empty() and age < duration:
		var fade = 1.0 - smoothstep(duration - 0.4, duration, age)
		var w = 174.0 + tier * 24
		var backdrop = PackedVector2Array([Vector2(640-w, 184), Vector2(640+w,184), Vector2(660+w,320), Vector2(620-w,320)])
		draw_colored_polygon(backdrop, Color(0.025, 0.075, 0.08, 0.78 * fade))
		draw_line(Vector2(640-w,184),Vector2(640+w,184),Color(PALETTE[tier],0.75*fade),2,true)
		if tier > 0:
			for side in [-1.0, 1.0]:
				for n in range(3 + tier):
					var from = Vector2(640 + side * (w + 15), 210 + n * 14)
					draw_line(from, from + Vector2(side * (14 + n * 4), -6), Color(PALETTE[tier],0.6*fade),2,true)
		if not reduced_motion and tier >= 2:
			var halo = (0.5 + sin(age * 9) * 0.15) * fade
			for i in range(28):
				var x = 25 + i * 45.5
				var lit = posmod(i - int(age * 16), 7) < 3
				draw_circle(Vector2(x, 7), 3.5, Color(PALETTE[tier], halo if lit else 0.06),true,-1,true)
	if _flash > 0 and not reduced_motion:
		draw_rect(Rect2(0,0,1280,800),Color(1,0.76,0.32,_flash * 0.18))
	for coin in coins:
		if float(coin.age) < 0: continue
		var t = clampf(float(coin.age)/float(coin.life),0,1)
		var first: Vector2 = Vector2(coin.start).lerp(Vector2(coin.bend),t)
		var second: Vector2 = Vector2(coin.bend).lerp(Vector2(coin.end),t)
		var point = first.lerp(second,t)
		var alpha = 1.0 - smoothstep(0.8,1.0,t)
		draw_circle(point,float(coin.r)+2,Color(0.22,0.12,0.04,alpha),true,-1,true)
		draw_circle(point,float(coin.r),Color(GOLD,alpha),true,-1,true)
		draw_line(point-Vector2(1,2),point+Vector2(1,2),Color(CREAM,alpha),1.5,true)
	for spark in sparks:
		var alpha = 1.0 - float(spark.age)/float(spark.life)
		var vector = Vector2(cos(float(spark.rotation)),sin(float(spark.rotation))) * 3
		draw_line(Vector2(spark.position)-vector,Vector2(spark.position)+vector,Color(spark.color,alpha),2.5,true)
	if goal_age < 2.7:
		var alpha = 1.0-smoothstep(2.2,2.7,goal_age)
		draw_rect(Rect2(374,351,532,42),Color(INK,0.93*alpha))
		draw_line(Vector2(374,351),Vector2(906,351),Color(MINT,alpha),2,true)
	if fault_age < 1.4:
		var alpha = (1.0 - fault_age / 1.4) * (0.45 if reduced_motion else 0.65)
		var warning = Color("e78d60") if fault_code in ["heat_warning","low_batter"] else Color("ed6c59")
		draw_rect(Rect2(1,1,1278,798),Color(warning,alpha),false,3 if reduced_motion else 5)
