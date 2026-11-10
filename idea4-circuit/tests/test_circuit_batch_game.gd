extends SceneTree
## Quantitative timing fairness, seeded replay, real touch input and settlement.
const Batch = preload("res://scripts/circuit_batch_game.gd")
var checks = 0
var failures: Array[String] = []
var capture_dir = ""
var window_min = INF
var window_max = 0.0
var good_window_min = INF
var good_window_max = 0.0
var blind_new = 0.0
var blind_old = 0.0
var previous_touch_emulation = false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	previous_touch_emulation = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(390, 460)
	root.content_scale_size = Vector2i(390, 460)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color("fff8e8"))
	_scoring_rules()
	_seed_and_timing_rules()
	_blind_input_comparison()
	await _touch_playthrough()
	await _motion_parity()
	await _result_boundaries()
	Input.emulate_touch_from_mouse = previous_touch_emulation
	print("BATCH_BALANCE perfect_ms=", roundi(window_min * 1000), "..", roundi(window_max * 1000),
		" good_ms=", roundi(good_window_min * 1000), "..", roundi(good_window_max * 1000),
		" blind_mean_v031=", snappedf(blind_old, 0.001), " blind_mean_v032=", snappedf(blind_new, 0.001))
	if failures.is_empty():
		print("CIRCUIT_BATCH_GAME_PASS checks=", checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _scoring_rules() -> void:
	for stage in 3:
		for tier in 4:
			for gentle in [false, true]:
				var core = Batch.target_half_width(stage, tier, gentle)
				var good = Batch.good_half_width(stage, tier, gentle)
				_check(core < good * 0.55, "Perfect core is visibly narrower than useful good zone")
				for center in [0.23, 0.5, 0.77]:
					_check(Batch.score_at(stage, center, tier, center, gentle) == 1, "Exact advertised center is perfect")
					_check(Batch.score_at(stage, center + core, tier, center, gentle) == 1, "Advertised perfect edge still scores perfect")
					_check(is_equal_approx(Batch.score_at(stage, center + good, tier, center, gentle), 0.6), "Advertised mint edge gives useful partial credit")
					_check(Batch.score_at(stage, center + good + 0.02, tier, center, gentle) < 0.3, "Missing the useful zone falls off steeply")
					var previous = 1.0
					for step in 51:
						var distance = step * 0.004
						var score = Batch.score_at(stage, center + distance, tier, center, gentle)
						_check(score >= 0 and score <= 1 and score <= previous + 0.00001, "Score is bounded and improves toward target")
						_check(is_equal_approx(score, Batch.score_at(stage, center - distance, tier, center, gentle)), "Both sides of the target score equally")
						previous = score
		_check(Batch.target_half_width(stage, 3) <= Batch.target_half_width(stage) * 1.27, "Upgrades help modestly without removing precision")
	_check(Batch.score_at(0, NAN) == 0 and Batch.score_at(0, INF) == 0 and Batch.score_at(0, 0.5, 0, NAN) == 0, "Non-finite values cannot corrupt scores")

func _seed_and_timing_rules() -> void:
	var game = Batch.new()
	var replay = Batch.new()
	var distinct = {}
	for seed_value in range(1, 65):
		game.configure("classic", 0, false, seed_value, false)
		replay.configure("classic", 0, true, seed_value, false)
		_check(game._beats == replay._beats, "Same seed repeats the whole sequence regardless of reduced motion")
		distinct[JSON.stringify(game._beats)] = true
		var ideal_seconds = Batch.FINISH_SECONDS + Batch.BEAT_COUNT * (Batch.READY_SECONDS + Batch.RESOLVE_SECONDS)
		for beat in Batch.BEAT_COUNT:
			game.beat_index = beat
			game.stage_index = beat / 2
			var spec = game.current_beat()
			var bands = game.target_bands()
			var perfect_seconds = bands.perfect * 2 / spec.speed
			var good_seconds = bands.good * 2 / spec.speed
			window_min = minf(window_min, perfect_seconds)
			window_max = maxf(window_max, perfect_seconds)
			good_window_min = minf(good_window_min, good_seconds)
			good_window_max = maxf(good_window_max, good_seconds)
			_check(perfect_seconds >= 0.100 and perfect_seconds <= 0.180, "Every standard perfect window is phone-fair but demanding")
			_check(good_seconds >= 0.39 and good_seconds <= 0.54, "Useful partial result has a larger forgiving window")
			_check(bands.center - bands.good > 0 and bands.center + bands.good < 1, "Both target bands stay fully visible")
			_check(bands.center == spec.center and bands.perfect == Batch.target_half_width(game.stage_index), "Drawing uses exactly the scored target and width")
			_check(bands.good == Batch.good_half_width(game.stage_index), "Drawing uses exactly the useful scoring width")
			if beat % 2 == 1:
				_check(spec.direction == -game._beats[beat - 1].direction, "Second beat visibly changes direction")
				_check(absf(spec.center - game._beats[beat - 1].center) >= 0.1, "Second beat gets a distinct target")
			ideal_seconds += spec.first_target_seconds
			game._state = "playing"
			game._phase = spec.first_target_seconds * spec.speed
			_check(is_equal_approx(game.indicator_position(), spec.center), "Declared first-pass timing really reaches the target")
			var center_phase = game._phase
			game._phase = center_phase - perfect_seconds * 0.5 * spec.speed
			_check(Batch.score_at(game.stage_index, game.indicator_position(), 0, spec.center) == 1, "Actual motion enters perfect at its declared boundary")
			game._phase = center_phase + (perfect_seconds * 0.5 + 0.01) * spec.speed
			_check(Batch.score_at(game.stage_index, game.indicator_position(), 0, spec.center) < 1, "Actual motion leaves perfect just beyond its declared boundary")
			var prior = spec.start
			for frame in 240:
				game._phase = frame / 60.0 * spec.speed
				var position = game.indicator_position()
				var distance = absf(position - prior)
				if game.stage_index == 1: distance = minf(distance, 1.0 - distance)
				_check(distance <= spec.speed / 60.0 + 0.00001, "Indicator never teleports or unexpectedly accelerates within a beat")
				prior = position
		_check(ideal_seconds >= 15.0 and ideal_seconds <= 25.0, "A first-pass batch fits the short 15–25 second flow")
		var standard = game._beats.duplicate(true)
		replay.configure("classic", 0, false, seed_value, true)
		for beat in Batch.BEAT_COUNT:
			_check(replay._beats[beat].center == standard[beat].center and replay._beats[beat].direction == standard[beat].direction, "Relaxed preserves the seeded pattern")
			_check(replay._beats[beat].speed < standard[beat].speed and Batch.target_half_width(beat / 2, 0, true) > Batch.target_half_width(beat / 2), "Relaxed explicitly slows timing and widens the core")
	_check(distinct.size() == 64, "Different company/day seeds produce varied sequences")
	game.free()
	replay.free()

func _blind_input_comparison() -> void:
	# Equal sampling across each motion cycle, not cherry-picked successful taps.
	# The old Heat/Pack sine sweep spends more time near the ends than its center.
	var old_total = 0.0
	var new_total = 0.0
	var old_perfect = 0
	var new_perfect = 0
	var samples = 0
	for stage in 3:
		for step in 2001:
			var phase = float(step) / 2001.0
			var old_position = phase if stage == 1 else (sin(phase * TAU - PI / 2) + 1) * 0.5
			var old_score = _legacy_score(stage, old_position)
			var score = Batch.score_at(stage, phase, 0, [0.64, 0.31, 0.72][stage])
			old_total += old_score
			new_total += score
			old_perfect += int(old_score >= 0.999)
			new_perfect += int(score >= 0.999)
			samples += 1
	blind_old = old_total / samples
	blind_new = new_total / samples
	_check(blind_new < blind_old * 0.45 and blind_new < 0.20, "Blind input earns less than half the old generous baseline")
	_check(new_perfect < old_perfect * 0.5, "Blind perfect hits are substantially rarer")
	var game = Batch.new()
	var center_spam = 0.0
	for seed_value in range(32):
		game.configure("classic", 0, true, seed_value)
		for beat in Batch.BEAT_COUNT:
			center_spam += Batch.score_at(beat / 2, 0.5, 0, game._beats[beat].center)
	_check(center_spam / (32.0 * Batch.BEAT_COUNT) < 0.3, "The formerly guaranteed center tap is no longer a winning pattern")
	game.free()

func _legacy_score(stage: int, position: float) -> float:
	var width = [0.085, 0.078, 0.10][stage]
	return clampf(1.0 - maxf(0, absf(position - 0.5) - width) / (0.5 - width), 0.0, 1.0)

func _touch_playthrough() -> void:
	var game = _make_game(false, 8128)
	var settled: Array[float] = []
	var finished: Array[float] = []
	var cues: Array[String] = []
	game.result_ready.connect(func(score): settled.append(score))
	game.completed.connect(func(score): finished.append(score))
	game.feedback.connect(func(kind): cues.append(kind))
	await process_frame
	_check(game.action_button.size.y >= 48 and game._donut != null and game._icons.size() == 3, "Touch target and illustrations are available")
	await _capture(game, "01-heat-ready")
	for beat in Batch.BEAT_COUNT:
		_check(game.beat_index == beat and game.stage_index == beat / 2 and game._state == "ready", "Each of six beats announces its target before motion")
		await _tap(game.action_button)
		_check(game.beat_scores.size() == beat, "Ready cue ignores premature input")
		game._process(Batch.READY_SECONDS)
		var spec = game.current_beat()
		game._process(spec.first_target_seconds)
		_check(is_equal_approx(game.indicator_position(), game.target_position()), "Real motion reaches each announced target")
		await _capture(game, "%02d-%s-%d-target" % [beat + 2, Batch.STAGES[beat / 2].to_lower(), beat % 2 + 1])
		await _tap(game.action_button)
		_check(game.beat_scores.size() == beat + 1 and game.beat_scores.back() == 1, "Real touchscreen press/release scores this beat")
		_check(game.stage_scores.size() == (beat + 1) / 2, "A stage average records only after both beats")
		await _tap(game.action_button)
		_check(game.beat_scores.size() == beat + 1, "Animation gates rapid extra touches")
		_check(finished.is_empty(), "Animation completion waits for the final medal")
		_check(settled.size() == (1 if beat == 5 else 0), "Result commits exactly at scoring input six")
		game._process(Batch.RESOLVE_SECONDS * 0.5)
		if beat == 5: await _capture(game, "08-final-drop")
		game._process(Batch.RESOLVE_SECONDS)
	_check(game.stage_scores == [1.0, 1.0, 1.0] and settled == [1.0], "Perfect pair averages and total stay correct")
	await _capture(game, "09-golden-batch")
	game._process(Batch.FINISH_SECONDS + 0.01)
	_check(finished == settled and finished.size() == 1, "Animated completion reuses settled result once")
	_check(cues.count("batch_perfect") == 6 and cues.count("batch_finish") == 1, "Six successful beats and one celebration provide feedback")
	for width in [290, 300, 340, 450]:
		game.configure("rainbow", 0, false, 8128)
		game.size.x = width
		game._layout()
		await process_frame
		for child in game.get_children():
			if child is Control:
				_check(child.position.x >= 0 and child.position.x + child.size.x <= width + 1, "Controls fit a narrow phone card")
		if width == 300: await _capture(game, "10-phone-300-ready")
	game.configure("missing_recipe", -5, true, 8128, true)
	_check(game._donut != null and game.fryer_tier == 0 and game.beat_scores.is_empty(), "Reconfiguration safely resets attempts and artwork")
	await _capture(game, "11-relaxed-ready")
	game.queue_free()
	await process_frame

func _motion_parity() -> void:
	var full = _make_game(false, 442)
	var reduced = _make_game(true, 442)
	for beat in Batch.BEAT_COUNT:
		for game in [full, reduced]: game._process(Batch.READY_SECONDS)
		for frame in 95:
			full._process(1.0 / 60)
			reduced._process(1.0 / 60)
			_check(full.indicator_position() == reduced.indicator_position(), "Reduced motion never changes essential timing")
		for game in [full, reduced]: game.press_action()
		_check(full.beat_scores == reduced.beat_scores, "Reduced motion never changes scores")
		_check(reduced._particles.is_empty(), "Reduced motion only removes decorative particles")
		for game in [full, reduced]: game._process(Batch.RESOLVE_SECONDS)
	_check(full.total_score() == reduced.total_score(), "The same six inputs produce identical totals in either motion setting")
	full.queue_free()
	reduced.queue_free()
	await process_frame

func _result_boundaries() -> void:
	for perfect in [false, true]:
		for exit_on_result in [false, true]:
			var game = _make_game(true, 512)
			var ready: Array[float] = []
			var finished: Array[float] = []
			game.result_ready.connect(func(score): ready.append(score))
			game.completed.connect(func(score): finished.append(score))
			for beat in Batch.BEAT_COUNT:
				game._process(Batch.READY_SECONDS)
				if perfect: game._process(game.current_beat().first_target_seconds)
				game.press_action()
				if beat < 5:
					_check(ready.is_empty() and not game.has_result(), "Five or fewer scores remain unfinished")
					game._process(Batch.RESOLVE_SECONDS)
			_check(ready == [1.0 if perfect else 0.0], "Last scoring input settles exact high/low result immediately")
			_check(game.has_result() and game._state == "resolving" and finished.is_empty(), "Settlement precedes final drop and medal animation")
			for repeat in 4: game.press_action()
			_check(ready.size() == 1, "Extra final inputs cannot duplicate a reward")
			if not exit_on_result:
				game._process(Batch.RESOLVE_SECONDS)
				game._process(Batch.FINISH_SECONDS)
				game._process(10)
				_check(finished == ready, "Normal animation completes with already committed score")
			root.remove_child(game)
			game.queue_free()
			await process_frame
			_check(ready.size() == 1 and finished.size() == (0 if exit_on_result else 1), "Close/focus-loss deletion cannot discard or duplicate a final score")
	for actions in Batch.BEAT_COUNT:
		var game = _make_game(true, 71)
		var ready: Array[float] = []
		game.result_ready.connect(func(score): ready.append(score))
		for action in actions:
			game._process(Batch.READY_SECONDS)
			game.press_action()
			game._process(Batch.RESOLVE_SECONDS)
		root.remove_child(game)
		game.queue_free()
		await process_frame
		_check(ready.is_empty(), "Leaving an unfinished batch remains free and safe")

func _make_game(reduced: bool, seed_value: int):
	var game = Batch.new()
	game.configure("rainbow", 0, reduced, seed_value)
	root.add_child(game)
	game.position = Vector2(25, 30)
	game.size = Vector2(340, 390)
	game.set_process(false)
	return game

func _tap(button: Button) -> void:
	var point = button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event = InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		for frame in 3: await process_frame

func _capture(game: Control, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var result = root.get_texture().get_image().save_png(capture_dir.path_join(filename + ".png"))
	_check(result == OK, "Screenshot saves " + filename)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
