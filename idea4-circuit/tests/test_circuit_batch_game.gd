extends SceneTree
## Deterministic scoring, input gating, accessibility and screenshots without a save.
const Batch = preload("res://scripts/circuit_batch_game.gd")
var checks = 0
var failures: Array[String] = []
var emissions: Array[float] = []
var cues: Array[String] = []
var capture_dir = ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(390, 460)
	root.content_scale_size = Vector2i(390, 460)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color("fff8e8"))
	for stage in 3:
		for tier in 4:
			_check(is_equal_approx(Batch.score_at(stage, 0.5, tier), 1.0), "Exact center is perfect")
			_check(is_zero_approx(Batch.score_at(stage, 0.0, tier)), "Left edge is a miss")
			_check(is_zero_approx(Batch.score_at(stage, 1.0, tier)), "Right edge is a miss")
			var previous = 0.0
			for step in 51:
				var score = Batch.score_at(stage, step / 100.0, tier)
				_check(score >= 0 and score <= 1, "Score is bounded")
				_check(score >= previous, "Moving toward target improves score")
				_check(is_equal_approx(score, Batch.score_at(stage, 1.0 - step / 100.0, tier)), "Target is symmetric")
				previous = score
	_check(Batch.score_at(0, NAN) == 0 and Batch.score_at(0, INF) == 0, "Non-finite positions cannot corrupt the score")
	_check(Batch.target_half_width(0, 3) > Batch.target_half_width(0, 0), "Upgraded fryer slightly widens target")
	var game = Batch.new()
	game.configure("rainbow", 2, false)
	game.completed.connect(func(score): emissions.append(score))
	game.feedback.connect(func(kind): cues.append(kind))
	root.add_child(game)
	game.position = Vector2(25, 30)
	game.size = Vector2(340, 390)
	game.set_process(false)
	await process_frame
	_check(game.action_button.size.y >= 48, "Touch action has a generous hit target")
	_check(game._donut != null, "Recipe illustration is loaded")
	_check(game._icons.size() == 3 and not null in game._icons, "All stage icons load")
	for stage in 3:
		_check(game.stage_index == stage and game._state == "playing", "Each stage begins playable")
		game._phase = PI / 2 if stage == 1 else 0.0
		_check(is_equal_approx(game.indicator_position(), 0.5), "Each stage supports exact timing")
		await _capture(game, "%02d-%s" % [stage + 1, Batch.STAGES[stage].to_lower()])
		game.press_action()
		_check(game.stage_scores.size() == stage + 1, "One input records one score")
		_check(game.action_button.disabled, "Button waits for result animation")
		game.press_action()
		game.press_action()
		_check(game.stage_scores.size() == stage + 1, "Repeated taps cannot skip stages")
		_check(emissions.is_empty(), "No economic result before all three stages finish")
		game._process(Batch.RESOLVE_SECONDS * 0.45)
		await _capture(game, "%02d-%s-success" % [stage + 1, Batch.STAGES[stage].to_lower()])
		game._process(Batch.RESOLVE_SECONDS)
	_check(game._state == "finishing", "Third stage enters a final celebration")
	_check(emissions.is_empty(), "Celebration is visible before completion")
	await _capture(game, "04-golden-batch")
	game._process(Batch.FINISH_SECONDS + 0.1)
	_check(emissions.size() == 1 and is_equal_approx(emissions[0], 1.0), "Completed emits perfect average once")
	for index in 10:
		game.press_action()
		game._process(10)
	_check(emissions.size() == 1, "Completion cannot be emitted again")
	_check(cues == ["batch_perfect", "batch_perfect", "batch_perfect", "batch_finish"], "Feedback follows stage results and finale")
	game.configure("not_a_recipe", -5, true)
	_check(game._donut != null and game.fryer_tier == 0, "Unknown artwork and invalid tier have safe fallbacks")
	_check(game.stage_scores.is_empty() and game.stage_index == 0 and not game._emitted, "Reconfiguration starts a clean attempt")
	var before = game.indicator_position()
	game._process(0.4)
	_check(not is_equal_approx(before, game.indicator_position()), "Essential timing still works with reduced motion")
	game.press_action()
	_check(game._particles.is_empty(), "Reduced motion suppresses decorative particles")
	await _capture(game, "05-reduced-motion")
	game._process(Batch.RESOLVE_SECONDS + 0.1)
	game._phase = -PI / 2
	game.press_action()
	game._process(Batch.RESOLVE_SECONDS + 0.1)
	game._phase = 0
	game.press_action()
	game._process(Batch.RESOLVE_SECONDS + 0.1)
	game._process(Batch.FINISH_SECONDS + 0.1)
	_check(emissions.size() == 2 and emissions[1] > 0 and emissions[1] < 1, "Mixed-quality batch averages all stages")
	for width in [290, 340, 450]:
		game.size.x = width
		game._layout()
		await process_frame
		for child in game.get_children():
			if child is Control:
				_check(child.position.x >= 0 and child.position.x + child.size.x <= width + 1, "Controls stay within phone card")
	if failures.is_empty():
		print("CIRCUIT_BATCH_GAME_PASS checks=", checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

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
