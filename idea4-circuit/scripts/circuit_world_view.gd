extends Control
## Original vector fairground vignette. Decorative animation never touches game state.
const Content = preload("res://scripts/circuit_content.gd")
const FONT = preload("res://assets/fonts/Fredoka-Medium.ttf")
const INK = Color("173c3f")
const CREAM = Color("fff8e8")
const GOLD = Color("efbc64")
const CORAL = Color("c9694b")
const MINT = Color("64988a")

var reduced_motion: bool = false
var _state: Dictionary = {}
var _clock: float = 0.0
var _portraits: Dictionary = {}
var _clouds: Array[Vector2] = []

func _init() -> void:
	custom_minimum_size = Vector2(0, 236)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var decorative_rng := RandomNumberGenerator.new()
	decorative_rng.seed = 17431
	for index in range(6):
		_clouds.append(Vector2(decorative_rng.randf_range(15, 460), decorative_rng.randf_range(12, 43)))

func configure(state: Dictionary, use_reduced_motion: bool = false) -> void:
	_state = state.duplicate(true)
	reduced_motion = use_reduced_motion
	if reduced_motion: _clock = 0.0
	for person: Dictionary in _state.get("staff", []):
		var id: String = String(person.get("id", ""))
		var path: String = "res://assets/ui/crew/" + id + ".svg"
		if not _portraits.has(id) and ResourceLoader.exists(path):
			_portraits[id] = load(path) as Texture2D
	tooltip_text = scene_description()
	_sync_process()
	queue_redraw()

func _ready() -> void:
	_sync_process()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED: _sync_process()
	if what == NOTIFICATION_RESIZED: queue_redraw()

func _sync_process() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and not reduced_motion)

func _process(delta: float) -> void:
	_clock = fmod(_clock + minf(delta, 0.1), 120.0)
	queue_redraw()

func scene_description() -> String:
	var truck_tier: int = clampi(int(_state.get("truck_tier", 0)), 0, 3)
	var fryer_tier: int = clampi(int(_state.get("fryer_tier", 0)), 0, 3)
	var stand_tier: int = clampi(int(_state.get("stand_tier", 0)), 0, 3)
	var recipe: Dictionary = Content.find(Content.RECIPES, String(_state.get("recipe", "classic")))
	var decoration_count: int = _decorations().size()
	return "%s · %s · %s. %s. %d crew; %d earned decorations. %s." % [
		Content.TRUCKS[truck_tier].name, Content.FRYERS[fryer_tier].name,
		Content.STANDS[stand_tier].name, recipe.get("name", "Golden Original"),
		_state.get("staff", []).size(), decoration_count, _state.get("weather", "Clear")
	]

func _decorations() -> Array:
	var circuit: Dictionary = _state.get("circuit", {})
	var result: Variant = circuit.get("decorations", [])
	return result if result is Array else []

func queue_size() -> int:
	if String(_state.get("booked_id", "")).is_empty(): return 0
	var report: Dictionary = _state.get("last_report", {})
	var popularity: float = maxf(float(_state.get("rep", 0)) / 17.0, float(report.get("sold", 0)) / 65.0)
	return clampi(1 + int(popularity), 1, 7)

func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	var weather: String = String(_state.get("weather", "Clear"))
	var wet: bool = weather in ["Showers", "Rain", "Rainy", "Storm"]
	var sky: Color = Color("dce7d9") if not wet else Color("c6d4d1")
	_round(Rect2(Vector2.ZERO, size), sky, 18)
	# Art uses a bounded 480 x 204 canvas; the two text rows retain readable screen pixels.
	var art_scale: float = minf((size.x - 12.0) / 480.0, (size.y - 58.0) / 204.0)
	var extra_height: float = maxf(0, size.y - 58.0 - 204.0 * art_scale)
	var offset: Vector2 = Vector2((size.x - 480.0 * art_scale) * 0.5, 27.0 + extra_height * 0.3)
	var grass_top: float = offset.y + 151.0 * art_scale
	_round(Rect2(0, grass_top, size.x, size.y - grass_top), Color("c9cfaa"), 18)
	draw_rect(Rect2(0, grass_top, size.x, 18), Color("c9cfaa"))
	draw_set_transform(offset, 0.0, Vector2.ONE * art_scale)
	_draw_landscape(wet, weather)
	_draw_truck(clampi(int(_state.get("truck_tier", 0)), 0, 3), float(_state.get("truck", 75)))
	_draw_stand(clampi(int(_state.get("stand_tier", 0)), 0, 3))
	_draw_queue()
	_draw_decorations()
	if wet: _draw_rain()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var venue: Dictionary = Content.find(Content.VENUES, String(_state.get("booked_id", "")))
	var title: String = String(venue.get("town", "Your travelling company"))
	_text(title, Vector2(14, 21), 16, INK, size.x - 113)
	_text(weather, Vector2(size.x - 99, 21), 13, INK, 85, HORIZONTAL_ALIGNMENT_RIGHT)
	var recipe: Dictionary = Content.find(Content.RECIPES, String(_state.get("recipe", "classic")))
	_text(String(recipe.get("name", "Golden Original")), Vector2(14, size.y - 12), 13, INK, size.x - 103)
	var crew: Array = _state.get("staff", [])
	var footer: String = "Owner + %d" % crew.size() if not crew.is_empty() else "Owner-run"
	_text(footer, Vector2(size.x - 95, size.y - 12), 12, INK, 81, HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_landscape(wet: bool, weather: String) -> void:
	if not wet:
		draw_circle(Vector2(414, 35), 22, Color("f6ce7c"))
		draw_circle(Vector2(414, 35), 30, Color(0.96, 0.81, 0.49, 0.14))
	for index in range(_clouds.size()):
		var drift: float = sin(_clock * 0.12 + index) * 5.0
		_cloud(_clouds[index] + Vector2(drift, 0), Color("eef0df") if not wet else Color("a8bbb8"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 121), Vector2(65, 98), Vector2(154, 115), Vector2(278, 91), Vector2(397, 112), Vector2(480, 90), Vector2(480, 204), Vector2(0, 204)]), Color("adc3a0"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 157), Vector2(91, 132), Vector2(210, 151), Vector2(349, 130), Vector2(480, 151), Vector2(480, 204), Vector2(0, 204)]), Color("c9cfaa"))
	draw_style_box(_box(Color("e3cbaa"), 18), Rect2(-10, 174, 500, 36))
	draw_line(Vector2(0, 194), Vector2(480, 194), Color("d6b993"), 2.0, true)
	_draw_wheel(Vector2(76, 82), 43.0)
	# A distant tent frames the stand without suggesting another owned business.
	draw_colored_polygon(PackedVector2Array([Vector2(351, 107), Vector2(392, 67), Vector2(435, 107)]), Color("cf987e"))
	draw_colored_polygon(PackedVector2Array([Vector2(379, 107), Vector2(392, 67), Vector2(407, 107)]), CREAM)
	draw_rect(Rect2(357, 107, 72, 31), Color("dfb79a"))
	draw_line(Vector2(392, 68), Vector2(392, 52), INK, 1.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(392, 52), Vector2(408, 56 + sin(_clock) * 2), Vector2(392, 61)]), CORAL)
	if weather == "Windy":
		for index in range(3):
			var start: Vector2 = Vector2(305 + sin(_clock * 0.6 + index) * 9, 28 + index * 12)
			draw_line(start, start + Vector2(34, -2), Color(1, 1, 1, 0.65), 1.6, true)
	if wet:
		_ellipse(Rect2(30, 184, 75, 9), Color("a7bdb8"))
		_ellipse(Rect2(357, 190, 88, 8), Color("a7bdb8"))
		draw_line(Vector2(372, 192), Vector2(408, 192), Color("d8e7de"), 1.5, true)

func _draw_wheel(center: Vector2, radius: float) -> void:
	var wheel_color := Color("73968c")
	draw_line(center, center + Vector2(-23, 63), wheel_color, 4, true)
	draw_line(center, center + Vector2(23, 63), wheel_color, 4, true)
	draw_arc(center, radius, 0, TAU, 64, wheel_color, 2.5, true)
	draw_arc(center, radius - 5, 0, TAU, 64, Color("b5c6af"), 1.2, true)
	var angle: float = _clock * 0.055
	for index in range(8):
		var point: Vector2 = center + Vector2.from_angle(angle + index * TAU / 8.0) * radius
		draw_line(center, point, Color("91ac9c"), 1.4, true)
		_round(Rect2(point + Vector2(-6, 0), Vector2(12, 9)), CORAL if index % 2 == 0 else GOLD, 3)
	draw_circle(center, 4, GOLD)

func _draw_truck(tier: int, condition: float) -> void:
	var colors: Array[Color] = [Color("c78261"), Color("5c9489"), Color("557f88"), Color("d2a95e")]
	var origin := Vector2(18, 128)
	if tier >= 2:
		_round(Rect2(10, 136, 45, 35), Color("ead5ad"), 4)
		draw_line(Vector2(51, 165), Vector2(65, 165), INK, 3, true)
		_wheel(Vector2(23, 174), 7)
	if tier == 3:
		# The second support van is visually distinct from the connected trailer.
		_round(Rect2(28, 100, 69, 33), Color("b58b4f"), 5)
		_round(Rect2(80, 109, 25, 24), Color("b58b4f"), 4)
		draw_rect(Rect2(87, 113, 12, 9), Color("c0d7ce"))
		_wheel(Vector2(41, 134), 7)
		_wheel(Vector2(92, 134), 7)
		origin.x = 56
	var width: float = 102.0 + tier * 8.0
	_round(Rect2(origin, Vector2(width - 30, 42)), colors[tier], 7)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(width - 31, 10), origin + Vector2(width - 6, 10), origin + Vector2(width + 12, 29), origin + Vector2(width + 12, 43), origin + Vector2(width - 31, 43)]), colors[tier])
	draw_colored_polygon(PackedVector2Array([origin + Vector2(width - 24, 15), origin + Vector2(width - 8, 15), origin + Vector2(width + 2, 27), origin + Vector2(width - 24, 27)]), Color("bcd6cd"))
	draw_rect(Rect2(origin + Vector2(1, 32), Vector2(width + 10, 8)), Color("f0d9b3"))
	_round(Rect2(origin + Vector2(12, 8), Vector2(43, 21)), CREAM, 3)
	_donut(origin + Vector2(33, 18), 8, GOLD, Color("c78261"))
	_wheel(origin + Vector2(20, 46), 10)
	_wheel(origin + Vector2(width - 5, 46), 10)
	if tier == 0:
		draw_line(origin + Vector2(7, 27), origin + Vector2(18, 25), Color("aa634a"), 1.5, true)
		draw_line(origin + Vector2(61, 8), origin + Vector2(67, 10), Color("aa634a"), 1.5, true)
	if condition < 45.0:
		_steam(origin + Vector2(width + 7, 17), Color("76847a"), 0.8, 1.4)
		draw_circle(origin + Vector2(width + 10, 35), 2.3, CORAL)

func _draw_stand(tier: int) -> void:
	var width: float = 150.0 + tier * 13.0
	var x: float = 268.0 - width * 0.5
	var decorations: Array = _decorations()
	var striped: bool = decorations.has("striped_awning")
	# The structure gets wider and gains solid walls with higher stand tiers.
	if tier >= 2:
		_round(Rect2(x + 8, 87, width - 16, 88), Color("efe2bd"), 5)
		draw_rect(Rect2(x + 18, 105, width - 36, 53), Color("57867a"))
	else:
		draw_line(Vector2(x + 9, 91), Vector2(x + 9, 185), INK, 3, true)
		draw_line(Vector2(x + width - 9, 91), Vector2(x + width - 9, 185), INK, 3, true)
	if tier == 3:
		_round(Rect2(x + 21, 68, width - 42, 20), INK, 4)
		_text("GOLDEN HOUR", Vector2(x + 26, 82), 12, GOLD, width - 52, HORIZONTAL_ALIGNMENT_CENTER)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 8, 105), Vector2(x + 16, 79), Vector2(x + width - 16, 79), Vector2(x + width + 8, 105)]), CORAL)
	if striped:
		for index in range(5):
			var stripe_x: float = x + 17 + index * (width - 34) / 5.0
			draw_colored_polygon(PackedVector2Array([Vector2(stripe_x, 80), Vector2(stripe_x + 12, 80), Vector2(stripe_x + 15, 105), Vector2(stripe_x - 3, 105)]), CREAM)
	draw_rect(Rect2(x - 8, 103, width + 16, 8), CORAL)
	for index in range(8):
		draw_circle(Vector2(x + 2 + index * (width - 4) / 7.0, 111), 4.5, CORAL)
	# Owner is always visible, even with no employees.
	_person(Vector2(x + 30, 142), 0.86, Color("e8c6a2"), Color("f4e6c8"), true)
	var staff: Array = _state.get("staff", [])
	for index in range(mini(staff.size(), 5)):
		var person: Dictionary = staff[index]
		var portrait_id: String = String(person.get("id", ""))
		var px: float = x + 52 + index * 23.0
		if _portraits.has(portrait_id):
			draw_texture_rect(_portraits[portrait_id], Rect2(px, 122, 22, 25), false)
		else:
			_person(Vector2(px + 10, 145), 0.62, Color("d5a47f"), MINT)
	_round(Rect2(x + 7, 149, width - 14, 35), Color("ead4a8"), 4)
	draw_rect(Rect2(x + 5, 147, width - 10, 7), GOLD)
	_draw_fryer(Vector2(x + 20, 146), clampi(int(_state.get("fryer_tier", 0)), 0, 3))
	var recipe: Dictionary = Content.find(Content.RECIPES, String(_state.get("recipe", "classic")))
	var glaze := Color(String(recipe.get("color", "#D8AD68")))
	_round(Rect2(x + width - 47, 156, 29, 23), INK, 3)
	_donut(Vector2(x + width - 32, 167), 9, glaze, INK)
	if tier >= 1:
		draw_line(Vector2(x + 13, 184), Vector2(x + 13, 190), INK, 3, true)
		draw_line(Vector2(x + width - 13, 184), Vector2(x + width - 13, 190), INK, 3, true)

func _draw_fryer(origin: Vector2, tier: int) -> void:
	var width: float = 30.0 + tier * 9.0
	_round(Rect2(origin, Vector2(width, 24)), Color("9eafb0"), 3)
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2(width - 4, 5)), Color("617d80"))
	for index in range(tier + 1):
		draw_rect(Rect2(origin + Vector2(4 + index * 9, 2), Vector2(7, 5)), Color("ddb16a"))
		draw_line(origin + Vector2(7 + index * 9, 2), origin + Vector2(7 + index * 9, -4), INK, 1.6, true)
		draw_circle(origin + Vector2(7 + index * 9, 17), 2.2, INK)
	var worn: bool = float(_state.get("fryer", 80)) < 45.0
	_steam(origin + Vector2(width * 0.5, 0), Color("7a827c") if worn else Color("fff8e8"), 0.9, 0.9)

func _draw_queue() -> void:
	var coats: Array[Color] = [Color("687f9d"), Color("cf9376"), Color("6e9c89"), Color("a1849d"), Color("b3a161"), Color("7e939c"), Color("bf8776")]
	for index in range(queue_size() - 1, -1, -1):
		var bob: float = sin(_clock * 0.9 + index * 1.9) * 0.8
		var point := Vector2(389 + (index % 3) * 22, 171 + floori(index / 3.0) * 9 + bob)
		_person(point, 0.83, Color("d6a87f") if index % 2 == 0 else Color("a97153"), coats[index])
		if index == 0:
			_round(Rect2(point + Vector2(-15, -8), Vector2(9, 12)), Color("ead4a8"), 2)
			draw_circle(point + Vector2(-10.5, -3), 2.0, GOLD)

func _draw_decorations() -> void:
	var earned: Array = _decorations()
	if earned.has("bunting"):
		var points := PackedVector2Array()
		for index in range(13):
			points.append(Vector2(130 + index * 24, 43 + sin(index * PI / 12.0) * 12))
		draw_polyline(points, INK, 1.3, true)
		for index in range(11):
			var p: Vector2 = points[index + 1]
			var flutter: float = sin(_clock * 1.5 + index) * 2.0
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(13, 0), p + Vector2(7 + flutter, 14)]), CORAL if index % 2 == 0 else GOLD)
	if earned.has("route_sign"):
		draw_line(Vector2(463, 145), Vector2(463, 190), INK, 3, true)
		draw_colored_polygon(PackedVector2Array([Vector2(444, 145), Vector2(470, 145), Vector2(478, 153), Vector2(470, 161), Vector2(444, 161)]), Color("e7d4ac"))
		draw_line(Vector2(449, 153), Vector2(469, 153), MINT, 2.0, true)
	if earned.has("flower_box"):
		_round(Rect2(180, 178, 35, 12), CORAL, 2)
		for index in range(4):
			var center := Vector2(185 + index * 8, 174 + sin(index) * 2)
			draw_line(center, center + Vector2(0, 8), MINT, 2, true)
			for petal in range(5): draw_circle(center + Vector2.from_angle(petal * TAU / 5) * 3, 2.5, Color("f7d9a0"))
			draw_circle(center, 2, CORAL)
	if earned.has("golden_lamp"):
		draw_line(Vector2(355, 105), Vector2(355, 137), INK, 2, true)
		draw_circle(Vector2(355, 137), 16, Color(1.0, 0.78, 0.35, 0.15))
		_round(Rect2(350, 132, 10, 13), GOLD, 3)
		draw_line(Vector2(351, 130), Vector2(359, 130), INK, 2, true)
	if earned.has("review_board"):
		_round(Rect2(354, 161, 24, 29), INK, 3)
		for index in range(3): draw_circle(Vector2(360 + index * 6, 170), 1.8, GOLD)
		draw_line(Vector2(360, 177), Vector2(372, 177), CREAM, 1.3, true)
		draw_line(Vector2(360, 182), Vector2(369, 182), CREAM, 1.3, true)
	if earned.has("crew_frame"):
		_round(Rect2(283, 159, 22, 19), GOLD, 2)
		draw_rect(Rect2(286, 162, 16, 13), CREAM)
		for index in range(3):
			draw_circle(Vector2(289 + index * 5, 167), 2, CORAL if index == 1 else MINT)
			draw_line(Vector2(289 + index * 5, 169), Vector2(289 + index * 5, 173), INK, 2)
	if earned.has("golden_rosette"):
		draw_colored_polygon(PackedVector2Array([Vector2(337, 114), Vector2(334, 130), Vector2(341, 127), Vector2(347, 131), Vector2(344, 114)]), CORAL)
		for index in range(10): draw_circle(Vector2(341, 114) + Vector2.from_angle(index * TAU / 10) * 6, 3.5, GOLD)
		draw_circle(Vector2(341, 114), 5, Color("fff1b3"))
		draw_circle(Vector2(341, 114), 2, CORAL)

func _draw_rain() -> void:
	for index in range(20):
		var x: float = fmod(19.0 + index * 73.0, 472.0)
		var y: float = fmod(index * 31.0 + _clock * 43.0, 183.0)
		draw_line(Vector2(x, y), Vector2(x - 3, y + 8), Color(0.64, 0.77, 0.78, 0.65), 1.2, true)

func _person(feet: Vector2, scale_factor: float, skin: Color, coat: Color, owner: bool = false) -> void:
	_ellipse(Rect2(feet + Vector2(-8, -2) * scale_factor, Vector2(16, 4) * scale_factor), Color(0.16, 0.25, 0.21, 0.13))
	draw_line(feet + Vector2(-3, -10) * scale_factor, feet + Vector2(-4, 0) * scale_factor, INK, 3 * scale_factor, true)
	draw_line(feet + Vector2(3, -10) * scale_factor, feet + Vector2(4, 0) * scale_factor, INK, 3 * scale_factor, true)
	_round(Rect2(feet + Vector2(-7, -26) * scale_factor, Vector2(14, 19) * scale_factor), coat, 4)
	draw_circle(feet + Vector2(0, -32) * scale_factor, 6.5 * scale_factor, skin)
	draw_arc(feet + Vector2(0, -33) * scale_factor, 6.2 * scale_factor, PI, TAU, 16, INK, 2 * scale_factor, true)
	if owner:
		_round(Rect2(feet + Vector2(-8, -40) * scale_factor, Vector2(16, 5) * scale_factor), CREAM, 2)
		draw_rect(Rect2(feet + Vector2(-4, -24) * scale_factor, Vector2(8, 15) * scale_factor), GOLD)

func _steam(origin: Vector2, tint: Color, amplitude: float, speed: float) -> void:
	for index in range(3):
		var line := PackedVector2Array()
		for step in range(9):
			line.append(origin + Vector2((index - 1) * 7 + sin(_clock * speed + step * 0.65 + index) * 2.6 * amplitude, -step * 2.7 - 3))
		var alpha_color := Color(tint, 0.5)
		draw_polyline(line, alpha_color, 1.8, true)

func _cloud(center: Vector2, tint: Color) -> void:
	draw_circle(center, 9, tint)
	draw_circle(center + Vector2(11, -4), 12, tint)
	draw_circle(center + Vector2(24, 0), 8, tint)
	draw_rect(Rect2(center + Vector2(0, 0), Vector2(24, 8)), tint)

func _wheel(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, INK)
	draw_circle(center, radius * 0.5, Color("b7beb0"))
	draw_circle(center, radius * 0.18, CREAM)

func _donut(center: Vector2, radius: float, glaze: Color, hole: Color) -> void:
	draw_circle(center, radius, GOLD)
	draw_circle(center + Vector2(0, -0.5), radius * 0.8, glaze)
	draw_circle(center, radius * 0.3, hole)

func _ellipse(rect: Rect2, tint: Color) -> void:
	var polygon := PackedVector2Array()
	for index in range(32):
		polygon.append(rect.get_center() + Vector2(cos(index * TAU / 32), sin(index * TAU / 32)) * rect.size * 0.5)
	draw_colored_polygon(polygon, tint)

func _round(rect: Rect2, tint: Color, radius: int) -> void:
	draw_style_box(_box(tint, radius), rect)

func _box(tint: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(radius)
	return style

func _text(value: String, position: Vector2, font_size: int, tint: Color, width: float, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var text: String = value
	while text.length() > 1 and FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		text = text.left(text.length() - 2).strip_edges() + "…"
	draw_string(FONT, position, text, alignment, width, font_size, tint)
