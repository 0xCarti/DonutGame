extends Control
## Six readable precision beats: two each for Heat, Coat and Pack.
## Economic effects belong to the parent. A fixed attempt seed prevents rerolling.
## configure() can be called before or after adding this control to a scene.
signal completed(score: float)
## Commit this result immediately; completed only marks the end of its animation.
signal result_ready(score: float)
signal feedback(kind: String)

const FONT = preload("res://assets/fonts/Fredoka-Medium.ttf")
const NAVY = Color("142c40")
const IVORY = Color("fff8e8")
const GOLD = Color("ffc857")
const CORAL = Color("ef6348")
const MINT = Color("31ba96")
const MUTED = Color("b2c6cb")
const STAGES = ["Heat", "Coat", "Pack"]
const ACTIONS = ["LOCK THE HEAT", "COAT THE BATCH", "DROP INTO BAG"]
const HINTS = ["Needle into the gold core. Mint still counts.", "Shaker into the gold arc. Mint still counts.", "Bag under the gold line. Mint still counts."]
const ICONS = ["fryer", "recipe", "bag"]
const BEAT_COUNT = 6
const READY_SECONDS = 0.65
const RESOLVE_SECONDS = 0.65
const FINISH_SECONDS = 1.65

var stage_index = 0
var beat_index = 0
var beat_scores: Array[float] = []
var stage_scores: Array[float] = []
var reduced_motion = false
var relaxed = false
var attempt_seed = 1
var fryer_tier = 0
var recipe_id = "classic"
var action_button: Button
var _title: Label
var _hint: Label
var _status: Label
var _donut: Texture2D
var _icons: Array[Texture2D] = []
var _phase = 0.0
var _time = 0.0
var _state = "ready"
var _pause = 0.0
var _locked_position = 0.0
var _emitted = false
var _result_emitted = false
var _particles: Array[Dictionary] = []
var _beats: Array[Dictionary] = []

func configure(new_recipe_id: String, new_fryer_tier: int, use_reduced_motion: bool, new_seed: int = 1, use_relaxed: bool = false) -> void:
	recipe_id = new_recipe_id
	fryer_tier = clampi(new_fryer_tier, 0, 3)
	reduced_motion = use_reduced_motion
	relaxed = use_relaxed
	attempt_seed = new_seed
	var path = "res://assets/ui/recipes/" + recipe_id + ".svg"
	if not ResourceLoader.exists(path): path = "res://assets/ui/recipes/classic.svg"
	_donut = load(path) as Texture2D
	stage_index = 0
	beat_index = 0
	beat_scores.clear()
	stage_scores.clear()
	_phase = 0.0
	_time = 0.0
	_pause = 0.0
	_state = "ready"
	_emitted = false
	_result_emitted = false
	_particles.clear()
	_build_beats()
	_locked_position = float(_beats[0].start)
	if is_instance_valid(action_button): _update_labels()
	queue_redraw()

func _build_beats() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = attempt_seed
	_beats.clear()
	for stage in 3:
		var first_direction = 1 if rng.randi_range(0, 1) == 1 else -1
		for repeat in 2:
			var direction = first_direction if repeat == 0 else -first_direction
			# Targets are announced before motion begins, and never move mid-beat.
			var distance = rng.randf_range(0.55, 0.77)
			var center = distance if direction > 0 else 1.0 - distance
			var speed = rng.randf_range(0.36, 0.43) * (0.82 if relaxed else 1.0)
			var start = 0.0 if direction > 0 else 1.0
			if stage == 1:
				# The circular stage wraps smoothly; both directions get equal runway.
				distance = rng.randf_range(0.57, 0.73)
				start = fposmod(center - direction * distance, 1.0)
			_beats.append({"center": center, "start": start, "direction": direction,
				"speed": speed, "first_target_seconds": distance / speed})

func current_beat() -> Dictionary:
	return _beats[clampi(beat_index, 0, BEAT_COUNT - 1)].duplicate()

func target_position() -> float:
	return float(_beats[clampi(beat_index, 0, BEAT_COUNT - 1)].center)

func target_bands() -> Dictionary:
	# Drawing and scoring share these normalized bounds on every stage.
	return {"center": target_position(), "perfect": target_half_width(stage_index, fryer_tier, relaxed),
		"good": good_half_width(stage_index, fryer_tier, relaxed)}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 390)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	if not is_instance_valid(_donut): configure(recipe_id, fryer_tier, reduced_motion, attempt_seed, relaxed)
	for key in ICONS:
		_icons.append(load("res://assets/ui/icons/" + key + ".svg") as Texture2D)
	_title = _label("BatchStageTitle", 23, IVORY)
	_hint = _label("BatchInstructions", 13, MUTED)
	_status = _label("BatchStageResult", 19, GOLD)
	action_button = Button.new()
	action_button.mouse_filter = Control.MOUSE_FILTER_PASS
	action_button.name = "BatchAction"
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.add_theme_font_override("font", FONT)
	action_button.add_theme_font_size_override("font_size", 18)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style = _panel(GOLD if state_name != "disabled" else Color("355364"), 17)
		style.border_width_bottom = 4 if state_name != "pressed" else 1
		style.border_color = Color("bb8425") if state_name != "disabled" else Color("254354")
		if state_name == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = IVORY
			style.set_border_width_all(2)
		action_button.add_theme_stylebox_override(state_name, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		action_button.add_theme_color_override(key, NAVY)
	action_button.add_theme_color_override("font_disabled_color", MUTED)
	action_button.pressed.connect(press_action)
	add_child(action_button)
	resized.connect(_layout)
	_layout()
	_update_labels()

func _label(node_name: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	add_child(label)
	return label

func _layout() -> void:
	if not is_instance_valid(action_button): return
	_title.position = Vector2(10, 48)
	_title.size = Vector2(size.x - 20, 30)
	_hint.position = Vector2(8, 78)
	_hint.size = Vector2(size.x - 16, 22)
	_status.position = Vector2(10, 281)
	_status.size = Vector2(size.x - 20, 29)
	action_button.position = Vector2(14, 323)
	action_button.size = Vector2(size.x - 28, 55)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _state == "ready":
		_pause += delta
		if _pause >= READY_SECONDS:
			_pause = 0.0
			_state = "playing"
			_update_labels()
	elif _state == "playing":
		# Only the indicator is essential motion. It always moves, including reduced motion.
		_phase += delta * float(_beats[beat_index].speed)
	elif _state == "resolving":
		_pause += delta
		if _pause >= RESOLVE_SECONDS: _advance_stage()
	elif _state == "finishing":
		_pause += delta
		if _pause >= FINISH_SECONDS and not _emitted:
			_emitted = true
			_state = "complete"
			completed.emit(total_score())
	if not reduced_motion:
		for particle in _particles:
			particle.age += delta
			particle.pos += particle.velocity * delta
			particle.velocity.y += 160.0 * delta
		_particles = _particles.filter(func(particle): return particle.age < particle.life)
	queue_redraw()

func indicator_position() -> float:
	if _state != "playing": return _locked_position
	var beat = _beats[beat_index]
	var position = float(beat.start) + float(beat.direction) * _phase
	if stage_index == 1: return fposmod(position, 1.0)
	# A constant-speed sweep with visible end stops. No random acceleration.
	return 1.0 - absf(fposmod(position, 2.0) - 1.0)

static func target_half_width(stage: int, tier: int = 0, gentle: bool = false) -> float:
	return ([0.024, 0.023, 0.027][clampi(stage, 0, 2)] + clampi(tier, 0, 3) * 0.002) * (1.7 if gentle else 1.0)

static func good_half_width(stage: int, tier: int = 0, gentle: bool = false) -> float:
	return ([0.088, 0.085, 0.095][clampi(stage, 0, 2)] + clampi(tier, 0, 3) * 0.003) * (1.35 if gentle else 1.0)

static func score_at(stage: int, position: float, tier: int = 0, center: float = 0.5, gentle: bool = false) -> float:
	if not is_finite(position) or not is_finite(center): return 0.0
	var distance = absf(clampf(position, 0.0, 1.0) - clampf(center, 0.0, 1.0))
	var perfect = target_half_width(stage, tier, gentle)
	var good = good_half_width(stage, tier, gentle)
	if distance <= perfect + 0.000001: return 1.0
	if distance <= good: return lerpf(1.0, 0.6, (distance - perfect) / (good - perfect))
	# Near misses have a short tail. Blind taps no longer earn most of the reward.
	return 0.6 * pow(clampf(1.0 - (distance - good) / (0.045 if not gentle else 0.065), 0.0, 1.0), 2.0)

func total_score() -> float:
	if beat_scores.is_empty(): return 0.0
	var total = 0.0
	for score in beat_scores: total += score
	return total / beat_scores.size()

func has_result() -> bool:
	return _result_emitted

func press_action() -> void:
	if _state != "playing" or _emitted: return
	_locked_position = indicator_position()
	var score = score_at(stage_index, _locked_position, fryer_tier, target_position(), relaxed)
	beat_scores.append(score)
	if beat_scores.size() % 2 == 0:
		stage_scores.append((beat_scores[-2] + beat_scores[-1]) * 0.5)
	_state = "resolving"
	_pause = 0.0
	if not reduced_motion: _burst(Vector2(size.x * 0.5, 185), score)
	feedback.emit("batch_perfect" if score >= 0.999 else "batch_good")
	_update_labels()
	queue_redraw()
	# The sixth timing action fixes the score. Leaving during the
	# drop/medal animation must not turn a completed batch into a free retry.
	if beat_scores.size() == BEAT_COUNT and not _result_emitted:
		_result_emitted = true
		result_ready.emit(total_score())

func _advance_stage() -> void:
	_pause = 0.0
	if beat_index == BEAT_COUNT - 1:
		_state = "finishing"
		if not reduced_motion: _burst(Vector2(size.x * 0.5, 170), 1.0)
		feedback.emit("batch_finish")
	else:
		beat_index += 1
		stage_index = beat_index / 2
		_phase = 0.0
		_locked_position = float(_beats[beat_index].start)
		_state = "ready"
	_update_labels()

func _update_labels() -> void:
	if not is_instance_valid(action_button): return
	var final = _state in ["finishing", "complete"]
	_title.text = ("Golden batch!" if total_score() >= 0.9 else "Ready for the rush!") if final else "%s   %d / 2%s" % [STAGES[stage_index], beat_index % 2 + 1, " · relaxed" if relaxed else ""]
	_hint.text = "Your opening batch is ready." if final else HINTS[stage_index]
	action_button.disabled = _state != "playing"
	action_button.text = "BATCH READY" if final else ("GET READY" if _state == "ready" else ACTIONS[stage_index] if _state == "playing" else "NICE WORK" if beat_scores.back() >= 0.6 else "NEXT BEAT")
	if final:
		_status.text = "+%d%% customer appeal today" % roundi(total_score() * 20.0)
	elif _state == "resolving":
		var grade = "Perfect!" if beat_scores.back() >= 0.999 else ("Good!" if beat_scores.back() >= 0.6 else "Too far!" if beat_scores.back() <= 0.01 else "Just missed!")
		_status.text = "%s   %d / 100" % [grade, roundi(beat_scores.back() * 100.0)]
	else:
		var direction = "Moves right" if _beats[beat_index].direction > 0 else "Moves left"
		if stage_index == 1: direction = "Turns clockwise" if _beats[beat_index].direction > 0 else "Turns counterclockwise"
		_status.text = direction if _state == "ready" else "Gold = perfect · Mint = good"
	_status.add_theme_color_override("font_color", MINT if _state == "resolving" and beat_scores.back() >= 0.6 else GOLD)

func _draw() -> void:
	if size.x < 1: return
	draw_style_box(_panel(NAVY, 22), Rect2(Vector2.ZERO, size))
	draw_style_box(_panel(Color("1b3c50"), 18), Rect2(10, 104, size.x - 20, 169))
	# Soft glow and small static stars give depth without rapid flashes.
	for index in range(7, 0, -1):
		draw_circle(Vector2(size.x * 0.5, 185), 26 + index * 10, Color(GOLD, 0.014))
	for index in 7:
		var point = Vector2(26 + fposmod(index * 67.3, maxf(1, size.x - 52)), 122 + fposmod(index * 39.2, 128))
		_spark(point, 2.0, Color(IVORY, 0.19))
	_draw_progress()
	if _state in ["finishing", "complete"]: _draw_finish()
	elif stage_index == 0: _draw_heat()
	elif stage_index == 1: _draw_coat()
	else: _draw_pack()
	if not reduced_motion:
		for particle in _particles:
			var alpha = clampf(1.0 - float(particle.age) / float(particle.life), 0, 1)
			_spark(particle.pos, particle.radius, Color(particle.color, alpha))

func _draw_progress() -> void:
	var spacing = (size.x - 48.0) / 3.0
	for index in 3:
		var point = Vector2(24 + spacing * (index + 0.5), 21)
		var done = index < stage_scores.size()
		var active = index == stage_index and _state not in ["finishing", "complete"]
		if index < 2:
			draw_line(point + Vector2(20, 0), point + Vector2(spacing - 20, 0), MINT if done else Color("355467"), 2, true)
		draw_circle(point, 14, MINT if done else GOLD if active else Color("2b4b60"))
		if index < _icons.size(): draw_texture_rect(_icons[index], Rect2(point - Vector2(9, 9), Vector2(18, 18)), false, NAVY if done or active else MUTED)
		for repeat in 2:
			var beat = index * 2 + repeat
			var dot = point + Vector2(-7 if repeat == 0 else 7, 22)
			var color = Color("466373")
			if beat < beat_scores.size(): color = GOLD if beat_scores[beat] >= 0.999 else MINT if beat_scores[beat] >= 0.6 else CORAL
			draw_circle(dot, 3.5, color)
			if beat == beat_index and beat >= beat_scores.size(): draw_arc(dot, 5.5, 0, TAU, 16, IVORY, 1.3, true)

func _draw_heat() -> void:
	var center = Vector2(size.x * 0.5, 178)
	var bob = 0.0 if reduced_motion else sin(_time * 2.6) * 2.0
	# Layered steel tank, warm oil, feet and separate illuminated heat dial.
	draw_style_box(_panel(Color("0b1e2e"), 12), Rect2(center.x - 99, 158, 198, 66))
	draw_style_box(_panel(Color("81a6aa"), 12), Rect2(center.x - 95, 149, 190, 68))
	draw_style_box(_panel(Color("c9dcce"), 9), Rect2(center.x - 92, 146, 184, 22))
	draw_style_box(_panel(Color("a35a27"), 9), Rect2(center.x - 84, 150, 168, 24))
	draw_style_box(_panel(Color("e8a63f"), 8), Rect2(center.x - 82, 150, 164, 16))
	for index in 12:
		var btime = _time if not reduced_motion else 1.0
		var pos = Vector2(center.x - 76 + index * 13, 156 + sin(btime * 3 + index) * 6)
		draw_arc(pos, 2.2, 0, TAU, 10, Color(IVORY, 0.30), 1, true)
	for index in 3:
		_draw_donut(Vector2(center.x - 49 + index * 49, 154 + bob * (1 if index % 2 else -1)), 23, 0.07 * sin(_time + index) if not reduced_motion else 0)
	for index in 3:
		var steam = fposmod(_time * 19 + index * 17, 42.0) if not reduced_motion else 22.0
		var pos = Vector2(center.x - 48 + index * 48 + sin(steam * 0.11) * 4, 137 - steam * 0.55)
		draw_arc(pos, 5, 0.3, 3.2, 12, Color(IVORY, (1.0 - steam / 42.0) * 0.20), 2, true)
	draw_circle(Vector2(center.x + 58, 192), 14, NAVY)
	draw_arc(Vector2(center.x + 58, 192), 17, PI * 0.7, PI * 2.3, 24, GOLD, 3, true)
	var dial_angle = lerpf(PI * 0.7, PI * 2.3, indicator_position())
	draw_line(Vector2(center.x + 58, 192), Vector2(center.x + 58, 192) + Vector2.from_angle(dial_angle) * 10, IVORY, 3, true)
	_center_text("GOLDEN HOUR", Vector2(center.x - 22, 197), 13, NAVY)
	var gauge = Rect2(32, 239, size.x - 64, 14)
	draw_style_box(_panel(Color("0d2535"), 7), gauge)
	var bands = target_bands()
	draw_style_box(_panel(MINT, 4), Rect2(gauge.position.x + gauge.size.x * (bands.center - bands.good), 237, gauge.size.x * bands.good * 2, 18))
	draw_style_box(_panel(GOLD, 2), Rect2(gauge.position.x + gauge.size.x * (bands.center - bands.perfect), 235, gauge.size.x * bands.perfect * 2, 22))
	for edge in [-1, 1]:
		var x = gauge.position.x + gauge.size.x * (bands.center + bands.perfect * edge)
		draw_line(Vector2(x, 235), Vector2(x, 257), IVORY, 1, true)
	var marker_x = gauge.position.x + gauge.size.x * indicator_position()
	draw_line(Vector2(marker_x, 232), Vector2(marker_x, 259), IVORY, 4, true)
	draw_circle(Vector2(marker_x, 232), 4, GOLD)
	_center_text("%d°C" % roundi(160 + indicator_position() * 60), Vector2(center.x - 28, 219), 14, IVORY)

func _draw_coat() -> void:
	var center = Vector2(size.x * 0.5, 184)
	var wobble = 0.0 if reduced_motion else sin(_time * 1.4) * 0.025
	draw_set_transform(center, wobble, Vector2.ONE)
	if is_instance_valid(_donut): draw_texture_rect(_donut, Rect2(-57, -57, 114, 114), false)
	draw_set_transform(Vector2.ZERO)
	draw_arc(center, 69, 0, TAU, 80, Color("466373"), 8, true)
	var bands = target_bands()
	var target_angle = bands.center * TAU - PI / 2
	draw_arc(center, 69, target_angle - bands.good * TAU, target_angle + bands.good * TAU, 32, MINT, 10, true)
	draw_arc(center, 69, target_angle - bands.perfect * TAU, target_angle + bands.perfect * TAU, 16, GOLD, 13, true)
	# White ticks frame the narrow perfect core as well as its distinct gold color.
	for angle in [target_angle - bands.perfect * TAU, target_angle + bands.perfect * TAU]:
		draw_line(center + Vector2.from_angle(angle) * 61, center + Vector2.from_angle(angle) * 77, IVORY, 2, true)
	# Keep the target's center visible even when the shaker crosses the core.
	draw_circle(center + Vector2.from_angle(target_angle) * 88, 3, GOLD)
	draw_line(center + Vector2.from_angle(target_angle) * 81, center + Vector2.from_angle(target_angle) * 85, GOLD, 2, true)
	var angle = indicator_position() * TAU - PI / 2
	var pos = center + Vector2.from_angle(angle) * 69
	draw_circle(pos, 13, Color("0b2030"))
	draw_set_transform(pos, angle + PI / 2, Vector2.ONE)
	draw_style_box(_panel(IVORY, 4), Rect2(-8, -12, 16, 23))
	draw_rect(Rect2(-8, -12, 16, 6), CORAL)
	for hole in [-4, 0, 4]: draw_circle(Vector2(hole, -9), 1, NAVY)
	draw_set_transform(Vector2.ZERO)
	if _state == "resolving" and not reduced_motion:
		for index in 24:
			var travel = clampf(_pause * 1.7 - float(index % 5) * 0.06, 0.0, 1.0)
			var end = center + Vector2(sin(index * 1.23) * 38, cos(index * 2.39) * 28)
			var point = pos.lerp(end, travel) + Vector2(0, -sin(travel * PI) * 25)
			draw_circle(point, 1.7, IVORY if index % 3 else GOLD)

func _draw_pack() -> void:
	var bands = target_bands()
	var center_x = lerpf(51, size.x - 51, bands.center)
	var bag_x = lerpf(51, size.x - 51, indicator_position())
	var lane = bands.good * (size.x - 102)
	var core = bands.perfect * (size.x - 102)
	draw_style_box(_panel(Color(MINT, 0.14), 9), Rect2(center_x - lane, 128, lane * 2, 119))
	draw_style_box(_panel(Color(GOLD, 0.35), 3), Rect2(center_x - core, 128, core * 2, 119))
	for side in [-1, 1]: draw_line(Vector2(center_x + core * side, 132), Vector2(center_x + core * side, 249), Color(IVORY, 0.6), 1, true)
	for side in [-1, 1]:
		draw_line(Vector2(center_x + lane * side, 242), Vector2(center_x + lane * side, 249), MINT, 2, true)
	for offset in range(0, 92, 12): draw_line(Vector2(center_x, 135 + offset), Vector2(center_x, 140 + offset), Color(IVORY, 0.35), 2, true)
	draw_style_box(_panel(Color("102638"), 9), Rect2(25, 242, size.x - 50, 10))
	# Folded kraft bag: elliptical opening, pleated side and a stamped donut seal.
	var bag_top = 190.0
	var bag_bottom = 240.0
	draw_colored_polygon(PackedVector2Array([Vector2(bag_x - 28, bag_top), Vector2(bag_x + 28, bag_top), Vector2(bag_x + 24, bag_bottom), Vector2(bag_x - 24, bag_bottom)]), Color("bd8148"))
	_draw_ellipse(Vector2(bag_x, bag_top), Vector2(28, 8), Color("5d3a29"))
	var drop = clampf(_pause / 0.6, 0, 1) if _state == "resolving" else 0.0
	for index in 3:
		var start = Vector2(center_x + (index - 1) * 30, 132 - (index % 2) * 10)
		if not reduced_motion and _state == "playing": start.y += sin(_time * 2.0 + index) * 2
		var target = Vector2(bag_x + (index - 1) * 8, 208)
		var pos = start.lerp(target, drop * drop)
		_draw_donut(pos, 18, (drop * 2 + index * 0.15) if not reduced_motion else 0)
	draw_colored_polygon(PackedVector2Array([Vector2(bag_x - 28, bag_top + 3), Vector2(bag_x - 16, bag_top + 7), Vector2(bag_x + 20, bag_top + 5), Vector2(bag_x + 28, bag_top + 1), Vector2(bag_x + 24, bag_bottom), Vector2(bag_x - 24, bag_bottom)]), Color("e5b574"))
	draw_colored_polygon(PackedVector2Array([Vector2(bag_x + 20, bag_top + 5), Vector2(bag_x + 28, bag_top + 1), Vector2(bag_x + 24, bag_bottom), Vector2(bag_x + 16, bag_bottom - 7)]), Color("c78d52"))
	draw_line(Vector2(bag_x - 19, 202), Vector2(bag_x - 16, 233), Color("f5cf91"), 2, true)
	draw_circle(Vector2(bag_x, 219), 14, NAVY)
	draw_arc(Vector2(bag_x, 219), 7, 0, TAU, 24, GOLD, 5, true)
	draw_line(Vector2(bag_x, 238), Vector2(bag_x, 252), IVORY, 3, true)
	_center_text("ALIGN THE BAG'S CENTER", Vector2(size.x * 0.5, 266), 11, MUTED)

func _draw_finish() -> void:
	var center = Vector2(size.x * 0.5, 184)
	var bounce = 1.0 if reduced_motion else 1.0 + sin(minf(_pause * 7, PI)) * 0.10
	for index in 12:
		var angle = index * TAU / 12.0 + (0 if reduced_motion else _time * 0.07)
		draw_line(center + Vector2.from_angle(angle) * 64, center + Vector2.from_angle(angle) * 77, Color(GOLD, 0.35), 3, true)
	draw_circle(center, 59 * bounce, GOLD)
	draw_circle(center, 53 * bounce, Color("b57b2c"))
	draw_circle(center, 50 * bounce, Color("ffe3a2"))
	if is_instance_valid(_donut): draw_texture_rect(_donut, Rect2(center - Vector2(46, 46) * bounce, Vector2(92, 92) * bounce), false)
	for index in 3:
		var p = center + Vector2((index - 1) * 36, 70)
		_spark(p, 8 if index == 1 else 6, GOLD if stage_scores[index] >= 0.7 else MUTED)

func _draw_donut(center: Vector2, radius: float, angle: float) -> void:
	draw_set_transform(center, angle, Vector2.ONE)
	_draw_ellipse(Vector2(0, 3), Vector2(radius, radius * 0.75), Color("9f5929"))
	_draw_ellipse(Vector2.ZERO, Vector2(radius, radius * 0.75), Color("d9953f"))
	_draw_ellipse(Vector2(-1, -3), Vector2(radius * 0.86, radius * 0.56), Color("f2bf6a"))
	draw_arc(Vector2(-1, -1), radius * 0.67, PI * 1.05, PI * 1.75, 15, Color("ffdb8f"), 2, true)
	for index in 13:
		var point = Vector2(sin(index * 3.7) * radius * 0.65, cos(index * 5.3) * radius * 0.4 - 3)
		draw_circle(point, 0.8, IVORY)
	_draw_ellipse(Vector2(0, -1), Vector2(radius * 0.085, radius * 0.11), Color("7a421e"))
	draw_set_transform(Vector2.ZERO)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for index in 32: points.append(center + Vector2.from_angle(index * TAU / 32) * radii)
	draw_colored_polygon(points, color)

func _center_text(text: String, point: Vector2, font_size: int, color: Color) -> void:
	var width = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(FONT, point - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _spark(point: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius * 0.3, -radius * 0.3), point + Vector2(radius, 0), point + Vector2(radius * 0.3, radius * 0.3), point + Vector2(0, radius), point + Vector2(-radius * 0.3, radius * 0.3), point + Vector2(-radius, 0), point + Vector2(-radius * 0.3, -radius * 0.3)]), color)

func _burst(point: Vector2, score: float) -> void:
	var count = 20 if score >= 0.9 else 12
	for index in count:
		var angle = index * TAU / count - PI / 2
		_particles.append({"pos": point, "velocity": Vector2.from_angle(angle) * (45 + (index % 5) * 13) + Vector2(0, -40), "age": 0.0, "life": 0.75 + (index % 3) * 0.1, "radius": 2.0 + index % 3, "color": [GOLD, IVORY, MINT, CORAL][index % 4]})

func _panel(color: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style
