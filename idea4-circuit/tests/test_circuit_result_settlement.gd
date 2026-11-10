extends SceneTree
## Completed results must survive closing, focus loss and a reload during animation.
const Model = preload("res://scripts/circuit_model.gd")
class DemoUI extends "res://scripts/circuit_main.gd":
	var saved_model: Dictionary = {}
	func _load_game() -> void: pass
	func _save_game() -> bool:
		saved_model = model.to_save()
		return true

var app: DemoUI
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = DemoUI.new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.test_mode = true
	app.settings.motion = false
	app._start_company("Settled Results", false)
	await _settle()
	var repair = _offer("repair")
	var before: Dictionary = app.model.to_save()
	app._start_activity(str(repair.id))
	await _settle()
	app._close_modal()
	_check(app.model.to_save() == before, "Unfinished activity cancellation remains free")
	_check(not _offer("repair").is_empty(), "Unfinished activity remains available")

	app._start_activity(str(repair.id))
	await _settle()
	var game = app._activity_game
	game.set_process(false)
	var sheet = app.modal
	# Repeatedly rotate one pipe while the rest remain disconnected: a real failure.
	for turn in int(game.move_limit):
		if game.has_result(): break
		game.rotate_pipe(0)
	_check(game.has_result() and is_zero_approx(game.total_score()), "Repair's final move fixes a failed result")
	_check(app.modal == sheet and is_instance_valid(game), "Settlement preserves the result animation")
	_check(str(repair.id) in app.model.state.circuit.resolved_activities, "Final move immediately consumes the repair attempt")
	_check(float(app.model.state.cash) == float(before.cash) - float(repair.self_cost), "Failed repair immediately charges its disclosed parts")
	_check(app.saved_model == app.model.to_save(), "Settled repair is saved before animation completion")
	_check(app.modal.find_child("ActivityLeave", true, false).text == "Back to your stand", "Settled activity no longer offers leave-for-later")
	var settled: Dictionary = app.model.to_save()
	var loaded = Model.new()
	_check(loaded.from_save(app.saved_model), "Saved in-animation repair reloads")
	_check(not bool(loaded.act("activity", {"id":repair.id,"mode":"self","score":1.0}).ok), "Reload cannot retry the completed failure")
	app._close_modal()
	app._finish_activity(str(repair.id), 1.0)
	_check(app.model.to_save() == settled, "Close and stale completion cannot erase or replace failed repair")
	_check(not app._activity_busy and not is_instance_valid(app.modal), "Closing a settled game returns to the refreshed company")

	# A fresh run exercises normal completion after the same early settlement.
	app._start_company("Normal Completion", false)
	repair = _offer("repair")
	app._start_activity(str(repair.id))
	await _settle()
	game = app._activity_game
	game.set_process(false)
	for turn in int(game.move_limit):
		if game.has_result(): break
		game.rotate_pipe(0)
	settled = app.model.to_save()
	game._process(game.FINISH_SECONDS + 0.01)
	await _settle()
	_check(app.model.to_save() == settled, "Animated completion never applies activity cost twice")
	_check(is_instance_valid(app.modal) and not app._activity_busy, "Animated completion shows the existing result sheet")
	app._close_modal()

	app._act("book", {"id":"willowbank"})
	await _settle()
	if str(app.model.state.phase) == "event":
		for index in app.model.state.event.choices.size():
			var effects: Dictionary = app.model.state.event.choices[index].get("effects", {})
			if float(effects.get("cash", 0)) >= 0 and int(effects.get("stock", 0)) >= 0:
				app._act("decide", {"choice":index})
				break
	await _settle()
	app._close_modal()
	app._show_minigame()
	await _settle()
	before = app.model.to_save()
	var initial_seed = app._opening_batch_seed()
	var initial_beat = app._batch_game.current_beat()
	app.model.state.company = "Renamed company"
	_check(app._opening_batch_seed() == initial_seed, "Renaming cannot reroll the daily batch")
	app.model.from_save(before)
	_check(app._opening_batch_seed() == initial_seed, "Save reload preserves daily batch seed")
	app.model.state.day += 1
	_check(app._opening_batch_seed() != initial_seed, "A new trading day gives a new batch")
	app.model.from_save(before)
	app.model.state.rng_seed = str(int(app.model.state.rng_seed) + 1)
	_check(app._opening_batch_seed() != initial_seed, "Another company seed gives another batch")
	app.model.from_save(before)
	app._batch_game.set_process(false)
	if app._batch_game._state == "ready": app._batch_game._process(app._batch_game.READY_SECONDS)
	app._batch_game.press_action()
	_check(app._batch_game.beat_scores.size() == 1, "Cancellation test has actually played a beat")
	app._close_modal()
	_check(app.model.to_save() == before, "Cancelling an unfinished batch remains free")
	app._show_minigame()
	await _settle()
	var batch = app._batch_game
	batch.set_process(false)
	_check(batch.current_beat() == initial_beat, "Reopening does not reroll the batch")
	sheet = app.modal
	for beat in range(batch.BEAT_COUNT):
		if batch._state == "ready": batch._process(batch.READY_SECONDS)
		batch.press_action()
		if beat < batch.BEAT_COUNT - 1:
			_check(not batch.has_result() and app.model.to_save() == before, "Intermediate beat does not settle partial results")
			batch._process(batch.RESOLVE_SECONDS + 0.01)
	_check(batch.has_result(), "Sixth timing action fixes the batch result")
	_check(app.model.state.minigame_day == app.model.state.day, "Sixth action consumes today's batch before the drop animation")
	_check(app.modal == sheet and is_instance_valid(batch), "Batch settlement preserves the drop animation")
	_check(is_equal_approx(float(app.model.state.minigame_boost), batch.total_score() * 0.2), "Saved bonus equals the locked actual batch score")
	_check(app.saved_model == app.model.to_save(), "Final batch score is saved before animation completion")
	_check(app.modal.find_child("BatchLeave", true, false).text == "Back to your stand", "Settled batch no longer says skip with no penalty")
	settled = app.model.to_save()
	loaded = Model.new()
	_check(loaded.from_save(app.saved_model), "Saved in-animation batch reloads")
	_check(not bool(loaded.act("minigame", {"score":1.0}).ok), "Reload cannot retry a completed batch")
	app._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _settle()
	_check(app.model.to_save() == settled, "Focus loss retains the settled score and bonus")
	_check(not app._minigame_playing and not is_instance_valid(app.modal), "Focus loss closes settled animation cleanly")
	app._finish_batch(1.0)
	_check(app.model.to_save() == settled, "Stale batch completion cannot replace the score")
	app._show_minigame()
	await _settle()
	_check(not app._minigame_playing and not is_instance_valid(app._batch_game), "Reopening a settled batch shows its result instead of a retry")
	app.queue_free()
	await process_frame
	for failure in failures: print("FAIL: " + failure)
	print("CIRCUIT_RESULT_SETTLEMENT_CHECKS %d passed / %d" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _offer(kind: String) -> Dictionary:
	for offer in app.model.activity_offers():
		if str(offer.kind) == kind: return offer
	return {}

func _settle() -> void:
	for frame in range(8): await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
