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
	var repair_routes: Dictionary = {}
	for difficulty in 3:
		for seed_value in 120:
			game.configure("repair", seed_value, true, difficulty)
			var initial = game.pipe_masks.duplicate()
			var budget = game.move_limit
			_check(not game.repair_solved(), "Seed starts unsolved")
			_check(game.solution_route.size() in [7, 9], "Standard route uses most of the compact board")
			repair_routes[str(game.solution_route)] = true
			_check(game.optimal_moves > 0 and game.optimal_moves < budget, "Every board has enough moves for its solution")
			_check(budget - game.optimal_moves == 3 - difficulty, "Standard offers the disclosed tight spare-turn budget")
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
	_check(repair_routes.size() >= 6, "Repair offers at least six distinct longer route shapes")
	for difficulty in 3:
		for seed_value in 40:
			game.configure("repair", seed_value, false, difficulty, true)
			var masks = game.pipe_masks.duplicate()
			_check(game.move_limit - game.optimal_moves == 8 - difficulty * 2, "Relaxed repair retains generous turns")
			game.configure("repair", seed_value, true, difficulty, true)
			_check(game.pipe_masks == masks, "Repair reduced motion does not change the challenge")
			game._process(1000)
			_check(game._state == "playing" and game.moves == 0, "Repair never has a solving deadline")
			for cell in game.solution_route:
				while game.pipe_masks[cell] != game.solution_masks[cell] and game._state == "playing": game.rotate_pipe(cell)
			_check(game.repair_solved() and game.total_score() == 1, "Relaxed multi-seed solution always fits")
	game.configure("repair", 42, false)
	await _capture(game, "01-repair-start")
	for cell in game.solution_route:
		while game.pipe_masks[cell] != game.solution_masks[cell] and game._state == "playing": game.rotate_pipe(cell)
	game._process(0.35)
	await _capture(game, "02-repair-medal")
	_check(emissions.is_empty(), "Animation-complete signal waits for the celebration")
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
	_fail_repair(game)
	_check(game._state == "finishing" and game.total_score() == 0, "Running out of moves produces a bounded failure result")
	game._process(Activity.FINISH_SECONDS + 0.1)
	_check(emissions.size() == 2 and emissions.back() == 0, "Repair failure emits once")
	_check(game._particles.is_empty() and game._pipe_angles.all(func(angle): return angle == 0), "Reduced motion has no particles or rotation animation")
	for difficulty in 3:
		for seed_value in 25:
			game.configure("orders", seed_value, true, difficulty)
			var first = game.order_sequence.duplicate()
			_check(first.size() == 6 + difficulty, "Standard memory uses six to eight orders")
			_check(first.all(func(order_id): return order_id >= 0 and order_id <= 3), "All generated orders are on the pictured menu")
			for menu_id in 4: _check(menu_id in first, "Every standard sequence contains all four menu items")
			for index in range(2, first.size()): _check(not (first[index] == first[index - 1] and first[index] == first[index - 2]), "Memory avoids trivial repeated triples")
			game.configure("orders", seed_value, true, difficulty)
			_check(game.order_sequence == first, "Memory sequence is deterministic")
	game.configure("orders", 31, false)
	await _capture(game, "03-orders-briefing")
	game.choose_order(game.order_sequence[0])
	_check(game.order_answers.is_empty(), "Cannot answer during memorization")
	game._process(600)
	_check(game._state == "briefing", "Study never starts without the user")
	_check(game._controls.all(func(control): return not control.visible), "Answers remain hidden before the user starts")
	game.press_action()
	_check(game._state == "studying" and game.study_remaining == game.study_seconds, "User starts the full disclosed study countdown")
	await _capture(game, "03b-orders-study")
	game.choose_order(game.order_sequence[0])
	_check(game.order_answers.is_empty(), "Study phase cannot accidentally score an answer")
	game._process(game.study_seconds - 0.1)
	_check(game._state == "studying" and game.study_remaining > 0, "Cards remain available until the actual deadline")
	game._process(0.11)
	_check(game._state == "answering" and game.order_answers.is_empty(), "Study expiry hides cards without inventing an answer")
	game._process(1000)
	_check(game._state == "answering" and game.order_answers.is_empty(), "Answering remains untimed")
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
	game.press_action()
	for index in game.order_sequence.size():
		game.choose_order((game.order_sequence[index] + (1 if index % 2 == 0 else 0)) % 4)
		game._process(Activity.ORDER_PAUSE + 0.01)
	_check(is_zero_approx(game.total_score()), "Half-correct recall earns zero reward")
	_check(game._status.text.contains("50% accurate") and game._status.text.contains("0 reward points"), "Result distinguishes accuracy from earned reward points")
	game._process(Activity.FINISH_SECONDS + 0.1)
	game.configure("orders", 31, true, 2)
	game.press_action()
	game.press_action()
	for index in game.order_sequence.size():
		game.choose_order((game.order_sequence[index] + (1 if index >= 6 else 0)) % 4)
		game._process(Activity.ORDER_PAUSE + 0.01)
	_check(is_equal_approx(game.total_score(), 0.5), "Six of eight correct normalizes 75-percent accuracy to 50 reward points")
	_check(game._status.text.contains("75% accurate") and game._status.text.contains("50 reward points"), "Normalized score is disclosed in final feedback")
	_check(game.how_to().contains("Half correct or less earns zero"), "Order instructions disclose the reward threshold")
	await _capture(game, "05b-orders-accuracy-vs-reward")
	game._process(Activity.FINISH_SECONDS + 0.1)
	game.configure("orders", 31, true)
	game.press_action()
	game.press_action()
	for index in game.order_sequence.size():
		game.choose_order((game.order_sequence[index] + 1) % 4)
		game._process(Activity.ORDER_PAUSE + 0.01)
	_check(game.total_score() == 0, "All wrong orders give zero, not an invented benefit")
	game._process(Activity.FINISH_SECONDS + 0.1)
	for difficulty in 3:
		game.configure("orders", 31, true, difficulty, true)
		_check(game.order_sequence.size() == 4 + difficulty, "Relaxed memory retains shorter sequences")
		game.press_action()
		game._process(1000)
		_check(game._state == "studying" and not game.has_result(), "Relaxed study is untimed")
		game.press_action()
		_check(game._state == "answering", "Relaxed player explicitly starts recall")
	for step in [0.016, 0.2, 10.0, 1000.0]:
		game.configure("orders", 31, true, 2)
		game.press_action()
		var before_answers = game.order_answers.duplicate()
		game._process(NAN)
		game._process(INF)
		_check(game.study_remaining == game.study_seconds, "Invalid frame delta never corrupts study timing")
		while game._state == "studying": game._process(step)
		_check(game._state == "answering" and game.order_answers == before_answers and not game.has_result(), "Low frame rate cannot skip recall or award a score")
	var reward_by_correct = [0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.5, 0.75, 1.0]
	for reduced in [false, true]:
		for correct_count in 9:
			game.configure("orders", 120 + correct_count, reduced, 2)
			game.press_action()
			game._process(1000)
			for index in 8:
				game.choose_order((game.order_sequence[index] + (0 if index < correct_count else 1)) % 4)
				game._process(1000)
			_check(is_equal_approx(game.total_score(), reward_by_correct[correct_count]), "All accuracy levels score fairly under long frames and either motion setting")
	var inspection_variants: Array[bool] = []
	var hazard_sets: Dictionary = {}
	var blind_perfect = 0
	var blind_total = 0.0
	for seed_value in 40:
		game.configure("inspection", seed_value, true)
		var mirror: bool = game._inspection_mirrored
		var color: Color = game._canopy_color
		var hazards = game.active_hazards.duplicate()
		hazard_sets[str(hazards)] = true
		_check(hazards.size() in [2, 3], "Inspection always mixes actual hazards and safe spots")
		if not mirror in inspection_variants: inspection_variants.append(mirror)
		game.configure("inspection", seed_value, true)
		_check(game._inspection_mirrored == mirror and game._canopy_color == color and game.active_hazards == hazards, "Inspection layout and active hazards are seeded and repeatable")
		for index in 4:
			_check(game._scene_rect().encloses(game._hazard_rect(index)), "Mirrored hazard hit areas remain inside the scene")
		for index in 4: game.inspect_hazard(index)
		blind_total += game.total_score()
		if game.total_score() >= 0.9: blind_perfect += 1
	_check(inspection_variants.size() == 2, "Inspection uses more than one scene layout")
	_check(hazard_sets.size() >= 8, "Inspections vary which pictured spots are actually unsafe")
	_check(blind_perfect < 16 and blind_total / 40.0 < 0.8, "Tapping all memorized positions is not a reliable high-score strategy")
	print("ACTIVITY_DIFFICULTY_AUDIT standard_routes=%d inspection_variants=%d blind_high_scores=%d/40 blind_mean=%.3f" % [repair_routes.size(), hazard_sets.size(), blind_perfect, blind_total / 40.0])
	game.configure("inspection", 9, false)
	await _capture(game, "06-inspection-stand")
	game.press_action()
	_check(game._hint.text.contains("cleaner"), "Inspection hint names the four pictorial targets")
	game.inspect_hazard(-1)
	game.inspect_hazard(4)
	_check(game.hazards_found.is_empty(), "Out of range hazards are ignored")
	game.inspect_hazard(game.active_hazards[0])
	game.inspect_hazard(game.active_hazards[0])
	_check(game.hazards_found.size() == 1 and game.wrong_taps == 0, "Retapping a found hazard is harmless")
	await _capture(game, "07-inspection-found")
	var safe_spot = 0
	while safe_spot in game.active_hazards: safe_spot += 1
	game.inspect_hazard(safe_spot)
	_check(game.wrong_taps == 1, "An empty scene tap uses one mistake")
	for index in game.active_hazards: game.inspect_hazard(index)
	_check(game._state == "finishing" and is_equal_approx(game.total_score(), 0.75), "One safe-spot mistake cannot earn a ninety-percent result")
	game._process(Activity.FINISH_SECONDS + 0.1)
	expected_count = emissions.size()
	for index in 8:
		game.inspect_empty()
		game.inspect_hazard(index % 4)
		game._process(10)
	_check(emissions.size() == expected_count, "Inspection cannot emit twice")
	game.configure("inspection", 9, true)
	game.inspect_hazard(game.active_hazards[0])
	for index in game.wrong_limit: game.inspect_empty()
	_check(game._state == "finishing" and is_zero_approx(game.total_score()), "Reaching the guess limit earns zero even after a real discovery")
	game._process(Activity.FINISH_SECONDS + 0.1)
	game.configure("inspection", 9, true)
	game._process(1000)
	_check(game._state == "playing", "Inspection has no hidden timer")
	for index in game.active_hazards: game.inspect_hazard(index)
	_check(game.total_score() == 1 and game._particles.is_empty(), "Perfect inspection works with reduced motion")
	game._process(Activity.FINISH_SECONDS + 0.1)
	game.configure("inspection", 9, true, 0, true)
	_check(game.wrong_limit == 3, "Relaxed inspection allows a third mistake")
	game.inspect_empty()
	for index in game.active_hazards: game.inspect_hazard(index)
	_check(is_equal_approx(game.total_score(), 0.88), "Relaxed inspection still distinguishes an error from perfect work")
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
				if activity_kind == "orders":
					await _touch_button(game.action_button)
					_check(game._state == "studying", "Real touch starts study only from the explicit button")
					await _capture(game, "08b-narrow-orders-study")
					await _touch_button(game.action_button)
					_check(game._state == "answering", "Real touch can end study early")
					await _touch_button(game._controls[game.order_sequence[0]])
					_check(game.order_answers.size() == 1 and game.order_correct == 1, "Real touch chooses one pictured answer")
			if width == 640:
				root.size = Vector2i(690, 520)
				root.content_scale_size = Vector2i(690, 520)
				await _capture(game, "09-landscape-" + activity_kind)
				root.size = Vector2i(390, 520)
				root.content_scale_size = Vector2i(390, 520)
	game.configure("unknown", -42, true, 99)
	_check(game.kind == "repair" and game.difficulty == 2, "Unknown mode and difficulty have safe defaults")
	_check(not game._emitted and game.hazards_found.is_empty() and game.order_answers.is_empty(), "Reconfigure clears every previous attempt")
	_check(not game.has_result(), "Reconfigure clears the previous result settlement")
	await _result_boundaries()
	if failures.is_empty():
		print("CIRCUIT_ACTIVITY_GAME_PASS checks=", checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _result_boundaries() -> void:
	for activity_kind in ["repair", "orders", "inspection"]:
		for perfect in [false, true]:
			for exit_on_result in [false, true]:
				var game = Activity.new()
				game.configure(activity_kind, 42, true)
				var ready: Array[float] = []
				var finished: Array[float] = []
				game.result_ready.connect(func(score): ready.append(score))
				game.completed.connect(func(score): finished.append(score))
				root.add_child(game)
				game.set_process(false)
				if activity_kind == "repair":
					if perfect:
						for cell in game.solution_route:
							while game.pipe_masks[cell] != game.solution_masks[cell] and game._state == "playing": game.rotate_pipe(cell)
					else:
						_fail_repair(game)
				elif activity_kind == "orders":
					game.press_action()
					game.press_action()
					for index in game.order_sequence.size():
						game.choose_order((game.order_sequence[index] + (0 if perfect else 1)) % 4)
						if index < game.order_sequence.size() - 1:
							_check(ready.is_empty() and not game.has_result(), "Partial order sequence has no committed result")
							game._process(Activity.ORDER_PAUSE + 0.01)
					_check(game._state == "order_feedback", "Order result settles before final-answer feedback ends")
				else:
					if perfect:
						for index in game.active_hazards: game.inspect_hazard(index)
					else:
						for mistake in game.wrong_limit: game.inspect_empty()
				_check(ready.size() == 1 and ready[0] == (1.0 if perfect else 0.0), "Final action settles the exact high or low " + activity_kind + " score")
				_check(game.has_result() and finished.is_empty(), "Settlement is immediate while the activity celebration remains visible")
				for repeat in 4:
					game.press_action()
					game.rotate_pipe(0)
					game.choose_order(0)
					game.inspect_empty()
					game.inspect_hazard(0)
				_check(ready.size() == 1, "Extra final inputs cannot resettle " + activity_kind)
				if not exit_on_result:
					if activity_kind == "orders": game._process(Activity.ORDER_PAUSE + 0.01)
					game._process(Activity.FINISH_SECONDS + 0.01)
					game._process(10)
					_check(ready.size() == 1 and finished == ready, "Normal activity animation completes exactly once with the settled result")
				root.remove_child(game)
				game.queue_free()
				await process_frame
				_check(ready.size() == 1 and finished.size() == (0 if exit_on_result else 1), "Closing after the final action cannot discard or duplicate " + activity_kind + " settlement")
		var unfinished = Activity.new()
		unfinished.configure(activity_kind, 42, true)
		var pending: Array[float] = []
		unfinished.result_ready.connect(func(score): pending.append(score))
		root.add_child(unfinished)
		unfinished.set_process(false)
		if activity_kind == "orders":
			unfinished.press_action()
			unfinished.press_action()
			unfinished.choose_order(unfinished.order_sequence[0])
		elif activity_kind == "inspection": unfinished.inspect_hazard(unfinished.active_hazards[0])
		root.remove_child(unfinished)
		unfinished.queue_free()
		await process_frame
		_check(pending.is_empty(), "Unfinished " + activity_kind + " cancellation never commits a score")

func _fail_repair(game: Control) -> void:
	# Leave the exit facing away, then spend turns elsewhere; all pipe shapes stay valid.
	while (game.pipe_masks[8] & 2) != 0: game.pipe_masks[8] = Activity._rotate_mask(game.pipe_masks[8])
	for turn in game.move_limit: game.rotate_pipe(0)

func _touch_button(button: Button) -> void:
	var point = button.get_global_rect().get_center()
	for down in [true, false]:
		var touch = InputEventScreenTouch.new()
		touch.index = 0
		touch.position = point
		touch.pressed = down
		Input.parse_input_event(touch)
		await process_frame

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
