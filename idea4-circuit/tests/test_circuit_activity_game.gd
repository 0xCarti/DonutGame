extends SceneTree
## Isolated, deterministic rules and layout checks; never reads or writes a company save.
const Activity = preload("res://scripts/circuit_activity_game.gd")
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
	root.size = Vector2i(390, 520)
	root.content_scale_size = Vector2i(390, 520)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color("fff8e8"))
	var game = Activity.new()
	game.configure("repair", 42, false)
	game.completed.connect(func(score): emissions.append(score))
	game.feedback.connect(func(cue): cues.append(cue))
	root.add_child(game)
	game.position = Vector2(25, 30)
	game.size = Vector2(340, 460)
	game.set_process(false)
	await process_frame
	_check(game._icon != null, "Activity art loads")
	_check(game.action_button.size.y >= 44, "Primary action is touch sized")
	_check(game.how_to().contains("inlet"), "Repair has accessible instructions")
	for difficulty in 3:
		for seed_value in 120:
			game.configure("repair", seed_value, true, difficulty)
			var initial = game.pipe_masks.duplicate()
			var budget = game.move_limit
			_check(not game.repair_solved(), "Seed starts unsolved")
			_check(game.solution_route.size() == 5, "Route is short enough for a quick activity")
			_check(game.optimal_moves > 0 and game.optimal_moves < budget, "Every board has enough moves for its solution")
			game.configure("repair", seed_value, true, difficulty)
			_check(game.pipe_masks == initial and game.move_limit == budget, "Same seed reproduces board and budget")
			for cell in game.solution_route:
				var guard = 0
				while game.pipe_masks[cell] != game.solution_masks[cell] and guard < 4 and game._state == "playing":
					game.rotate_pipe(cell)
					guard += 1
				_check(guard < 4, "Each tile reaches its target by clockwise rotation")
			_check(game.repair_solved(), "Generated board is solvable")
			_check(game._state == "finishing", "A connected route completes the puzzle")
			_check(is_equal_approx(game.total_score(), 1.0), "Efficient solution earns full score")
	game.configure("repair", 42, false)
	await _capture(game, "01-repair-start")
	for cell in game.solution_route:
		while game.pipe_masks[cell] != game.solution_masks[cell] and game._state == "playing": game.rotate_pipe(cell)
	game._process(0.35)
	await _capture(game, "02-repair-medal")
	_check(emissions.is_empty(), "No result until the completion celebration")
	game._process(Activity.FINISH_SECONDS)
	_check(emissions.size() == 1 and emissions[0] == 1, "Solved repair emits exactly one full score")
	for index in 12:
		game.rotate_pipe(index % 9)
		game.press_action()
		game._process(10)
	_check(emissions.size() == 1, "Finished repair rejects extra input and re-emission")
	game.configure("repair", 42, true)
	var untouched = game.pipe_masks.duplicate()
	game.rotate_pipe(-1)
	game.rotate_pipe(9)
	_check(game.pipe_masks == untouched and game.moves == 0, "Invalid tile input is ignored")
	# Spend the budget on a tile that is not on the useful route.
	var distractor = 0
	while distractor in game.solution_route: distractor += 1
	for index in game.move_limit: game.rotate_pipe(distractor)
	_check(game._state == "finishing" and game.total_score() == 0, "Running out of moves produces a bounded failure result")
	game._process(Activity.FINISH_SECONDS + 0.1)
	_check(emissions.size() == 2 and emissions.back() == 0, "Repair failure emits once")
	_check(game._particles.is_empty() and game._pipe_angles.all(func(angle): return angle == 0), "Reduced motion has no particles or rotation animation")
	for difficulty in 3:
		for seed_value in 25:
			game.configure("orders", seed_value, true, difficulty)
			var first = game.order_sequence.duplicate()
			_check(first.size() == 4 + difficulty, "Memory sequence grows modestly with difficulty")
			_check(first.all(func(order_id): return order_id >= 0 and order_id <= 3), "All generated orders are on the pictured menu")
			_check(not first.all(func(order_id): return order_id == first[0]), "Every memory sequence has variety")
			game.configure("orders", seed_value, true, difficulty)
			_check(game.order_sequence == first, "Memory sequence is deterministic")
	game.configure("orders", 31, false)
	await _capture(game, "03-orders-memorize")
	game.choose_order(game.order_sequence[0])
	_check(game.order_answers.is_empty(), "Cannot answer during memorization")
	game._process(600)
	_check(game._state == "memorize", "Memorization has no hidden deadline")
	game.press_action()
	_check(game._state == "answering", "Ready button starts recall explicitly")
	game.choose_order(-1)
	game.choose_order(4)
	_check(game.order_answers.is_empty(), "Invalid orders are ignored")
	await _capture(game, "04-orders-choose")
	var expected_count = emissions.size()
	for index in game.order_sequence.size():
		game.choose_order(game.order_sequence[index])
		game.choose_order(game.order_sequence[index])
		_check(game.order_answers.size() == index + 1, "Feedback gates double taps")
		game._process(Activity.ORDER_PAUSE + 0.01)
	_check(game._state == "finishing" and game.total_score() == 1, "Perfect recall earns full score")
	await _capture(game, "05-orders-medal")
	game._process(Activity.FINISH_SECONDS + 0.1)
	_check(emissions.size() == expected_count + 1, "Order activity emits once after every answer")
	game.configure("orders", 31, true)
	game.press_action()
	for index in game.order_sequence.size():
		game.choose_order((game.order_sequence[index] + (1 if index % 2 == 0 else 0)) % 4)
		game._process(Activity.ORDER_PAUSE + 0.01)
	_check(is_equal_approx(game.total_score(), 0.5), "Accuracy score represents mixed answers")
	game._process(Activity.FINISH_SECONDS + 0.1)
	game.configure("orders", 31, true)
	game.press_action()
	for index in game.order_sequence.size():
		game.choose_order((game.order_sequence[index] + 1) % 4)
		game._process(Activity.ORDER_PAUSE + 0.01)
	_check(game.total_score() == 0, "All wrong orders give zero, not an invented benefit")
	game._process(Activity.FINISH_SECONDS + 0.1)
	var inspection_variants: Array[bool] = []
	for seed_value in 40:
		game.configure("inspection", seed_value, true)
		var mirror: bool = game._inspection_mirrored
		var color: Color = game._canopy_color
		if not mirror in inspection_variants: inspection_variants.append(mirror)
		game.configure("inspection", seed_value, true)
		_check(game._inspection_mirrored == mirror and game._canopy_color == color, "Inspection layout is seeded and repeatable")
		for index in 4:
			_check(game._scene_rect().encloses(game._hazard_rect(index)), "Mirrored hazard hit areas remain inside the scene")
	_check(inspection_variants.size() == 2, "Inspection uses more than one scene layout")
	game.configure("inspection", 9, false)
	await _capture(game, "06-inspection-stand")
	game.press_action()
	_check(game._hint.text.contains("cleaner"), "Inspection hint names the four pictorial targets")
	game.inspect_hazard(-1)
	game.inspect_hazard(4)
	_check(game.hazards_found.is_empty(), "Out of range hazards are ignored")
	game.inspect_hazard(0)
	game.inspect_hazard(0)
	_check(game.hazards_found.size() == 1 and game.wrong_taps == 0, "Retapping a found hazard is harmless")
	await _capture(game, "07-inspection-found")
	game.inspect_empty()
	_check(game.wrong_taps == 1, "An empty scene tap uses one mistake")
	for index in [1, 2, 3]: game.inspect_hazard(index)
	_check(game._state == "finishing" and is_equal_approx(game.total_score(), 0.9), "Find all with one mistake earns a reduced good result")
	game._process(Activity.FINISH_SECONDS + 0.1)
	expected_count = emissions.size()
	for index in 8:
		game.inspect_empty()
		game.inspect_hazard(index % 4)
		game._process(10)
	_check(emissions.size() == expected_count, "Inspection cannot emit twice")
	game.configure("inspection", 9, true)
	game.inspect_hazard(0)
	game.inspect_hazard(2)
	for index in 3: game.inspect_empty()
	_check(game._state == "finishing" and is_equal_approx(game.total_score(), 0.4), "Three mistakes end inspection with credit for actual discoveries")
	game._process(Activity.FINISH_SECONDS + 0.1)
	game.configure("inspection", 9, true)
	game._process(1000)
	_check(game._state == "playing", "Inspection has no hidden timer")
	for index in 4: game.inspect_hazard(index)
	_check(game.total_score() == 1 and game._particles.is_empty(), "Perfect inspection works with reduced motion")
	game._process(Activity.FINISH_SECONDS + 0.1)
	_check(cues.all(func(cue): return cue in ["batch_good", "batch_perfect", "batch_finish"]), "All feedback names exist in the shared audio bank")
	for activity_kind in ["repair", "orders", "inspection"]:
		for width in [300, 328, 340, 440, 640]:
			game.configure(activity_kind, 17, true, 2)
			game.size = Vector2(width, 460)
			game._layout()
			await process_frame
			for child in game.get_children():
				if child is Control:
					_check(child.position.x >= 0 and child.position.x + child.size.x <= width + 1, "Controls fit activity width")
					_check(child.position.y >= 0 and child.position.y + child.size.y <= 460 + 1, "Controls fit activity height")
					if child is Button: _check(child.size.x >= 44 and child.size.y >= 44, "Every interactive target is at least 44 pixels")
			if width == 300:
				await _capture(game, "08-narrow-" + activity_kind)
			if width == 640:
				root.size = Vector2i(690, 520)
				root.content_scale_size = Vector2i(690, 520)
				await _capture(game, "09-landscape-" + activity_kind)
				root.size = Vector2i(390, 520)
				root.content_scale_size = Vector2i(390, 520)
	game.configure("unknown", -42, true, 99)
	_check(game.kind == "repair" and game.difficulty == 2, "Unknown mode and difficulty have safe defaults")
	_check(not game._emitted and game.hazards_found.is_empty() and game.order_answers.is_empty(), "Reconfigure clears every previous attempt")
	if failures.is_empty():
		print("CIRCUIT_ACTIVITY_GAME_PASS checks=", checks)
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
	_check(root.get_texture().get_image().save_png(capture_dir.path_join(filename + ".png")) == OK, "Screenshot saves " + filename)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
