extends Control
## Read-only closing-time animation. Counts are derived from the supplied report.
const FONT = preload("res://assets/fonts/Fredoka-Medium.ttf")
const INK = Color("173c3f")
const GOLD = Color("efbc64")
const CORAL = Color("c9694b")
const MINT = Color("64988a")
const DURATION: float = 2.4

var reduced_motion: bool = false
var _report: Dictionary = {}
var _elapsed: float = 0.0
var _complete: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(0, 158)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func configure(report: Dictionary, use_reduced_motion: bool = false) -> void:
	_report = report.duplicate(true)
	reduced_motion = use_reduced_motion
	_elapsed = DURATION if reduced_motion else 0.0
	_complete = reduced_motion or int(_report.get("sold", 0)) <= 0
	if _complete: _elapsed = DURATION
	tooltip_text = "%d bags sold. $%.2f sales revenue. These figures come from the closing report." % [maxi(0, int(_report.get("sold", 0))), maxf(0, float(_report.get("revenue", 0)))]
	_sync_process()
	queue_redraw()

func _ready() -> void:
	_sync_process()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED: _sync_process()
	if what == NOTIFICATION_RESIZED: queue_redraw()

func _sync_process() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and not reduced_motion and not _complete)

func _process(delta: float) -> void:
	_elapsed = minf(DURATION, _elapsed + minf(delta, 0.1))
	if _elapsed >= DURATION:
		_complete = true
		_sync_process()
	queue_redraw()

func displayed_totals() -> Dictionary:
	var progress: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 3)
	return {
		"sold": maxi(0, int(round(float(_report.get("sold", 0)) * eased))),
		"revenue": round(maxf(0, float(_report.get("revenue", 0))) * eased * 100.0) / 100.0,
		"complete": _complete
	}

func _draw() -> void:
	if size.x < 1: return
	var background := StyleBoxFlat.new()
	background.bg_color = Color("e9efdc")
	background.set_corner_radius_all(15)
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	draw_string(FONT, Vector2(13, 23), "From warm bags to a day's sales", HORIZONTAL_ALIGNMENT_LEFT, size.x - 26, 15, INK)
	var spacing: float = (size.x - 38.0) / 3.0
	var centers: Array[Vector2] = [Vector2(19 + spacing * 0.5, 72), Vector2(size.x * 0.5, 72), Vector2(size.x - 19 - spacing * 0.5, 72)]
	for index in range(2):
		draw_line(centers[index] + Vector2(24, 0), centers[index + 1] - Vector2(24, 0), Color("b4c8ad"), 2.0, true)
		var arrow: Vector2 = (centers[index] + centers[index + 1]) * 0.5
		draw_line(arrow + Vector2(-3, -4), arrow + Vector2(2, 0), MINT, 1.8, true)
		draw_line(arrow + Vector2(2, 0), arrow + Vector2(-3, 4), MINT, 1.8, true)
	_draw_people(centers[0])
	_draw_bag(centers[1], 1.0, true)
	_draw_till(centers[2])
	if not reduced_motion and not _complete and int(_report.get("sold", 0)) > 0:
		var travel: float = fmod(_elapsed * 0.8, 1.0)
		var point: Vector2 = centers[0].lerp(centers[2], travel) + Vector2(0, -24 - sin(travel * PI) * 8)
		_draw_bag(point, 0.36, false)
	var totals: Dictionary = displayed_totals()
	_text_center("The queue", centers[0].x, 114, 12, INK, spacing)
	_text_center("%d bags" % int(totals.sold), centers[1].x, 114, 17, INK, spacing)
	var money: String = "$%.0f" % float(totals.revenue)
	if not is_equal_approx(float(totals.revenue), round(float(totals.revenue))): money = "$%.2f" % float(totals.revenue)
	var money_size: int = 17
	while money_size > 11 and FONT.get_string_size(money, HORIZONTAL_ALIGNMENT_LEFT, -1, money_size).x > spacing - 3:
		money_size -= 1
	_text_center(money, centers[2].x, 114, money_size, INK, spacing)
	_text_center("BAGS SOLD", centers[1].x, 131, 9, Color("58766b"), spacing)
	_text_center("SALES REVENUE", centers[2].x, 131, 9, Color("58766b"), spacing)
	var caption: String = "No bags sold today." if int(_report.get("sold", 0)) <= 0 else "Your actual closing totals"
	if not _complete: caption = "Counting today's trade…"
	draw_string(FONT, Vector2(13, size.y - 9), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 26, 10, Color("58766b"))

func _draw_people(center: Vector2) -> void:
	var colors: Array[Color] = [MINT, Color("788eaa"), CORAL]
	for index in range(3):
		var x: float = center.x + (index - 1) * 15
		var y: float = center.y + (0 if index == 1 else 3)
		draw_line(Vector2(x - 3, y + 9), Vector2(x - 4, y + 19), INK, 2.5, true)
		draw_line(Vector2(x + 3, y + 9), Vector2(x + 4, y + 19), INK, 2.5, true)
		_round(Rect2(x - 6, y - 8, 12, 19), colors[index], 4)
		draw_circle(Vector2(x, y - 14), 6, Color("d7ac87") if index != 1 else Color("b47b59"))
		draw_arc(Vector2(x, y - 15), 5.6, PI, TAU, 16, INK, 2, true)

func _draw_bag(center: Vector2, scale_factor: float, with_donut: bool) -> void:
	var polygon := PackedVector2Array([
		center + Vector2(-16, -17) * scale_factor, center + Vector2(14, -17) * scale_factor,
		center + Vector2(18, 20) * scale_factor, center + Vector2(-17, 20) * scale_factor
	])
	draw_colored_polygon(polygon, Color("dbc096"))
	draw_line(center + Vector2(-16, -17) * scale_factor, center + Vector2(14, -17) * scale_factor, Color("b89569"), 2 * scale_factor, true)
	draw_circle(center + Vector2(0, 1) * scale_factor, 9 * scale_factor, GOLD)
	draw_circle(center + Vector2(0, 1) * scale_factor, 3 * scale_factor, CORAL)
	if with_donut:
		draw_circle(center + Vector2(-5, -18), 8, GOLD)
		draw_circle(center + Vector2(-5, -18), 2.5, Color("e9efdc"))
		draw_circle(center + Vector2(7, -17), 7, Color("dba660"))
		draw_circle(center + Vector2(7, -17), 2.2, Color("e9efdc"))

func _draw_till(center: Vector2) -> void:
	_round(Rect2(center + Vector2(-23, -8), Vector2(46, 28)), MINT, 5)
	_round(Rect2(center + Vector2(-15, -25), Vector2(30, 19)), INK, 3)
	_round(Rect2(center + Vector2(-11, -22), Vector2(22, 12)), Color("d9e8b9"), 2)
	draw_line(center + Vector2(-7, -16), center + Vector2(7, -16), Color("6a8975"), 2, true)
	for index in range(3):
		draw_circle(center + Vector2(-13 + index * 9, 0), 2, Color("dfebd3"))
		draw_circle(center + Vector2(-13 + index * 9, 7), 2, Color("dfebd3"))
	draw_rect(Rect2(center + Vector2(-17, 14), Vector2(34, 3)), INK)
	draw_circle(center + Vector2(23, 11), 7, GOLD)
	draw_arc(center + Vector2(23, 11), 4.5, 0, TAU, 16, Color("b08c46"), 1, true)

func _round(rect: Rect2, tint: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _text_center(text: String, center_x: float, baseline: float, font_size: int, color: Color, width: float) -> void:
	draw_string(FONT, Vector2(center_x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
