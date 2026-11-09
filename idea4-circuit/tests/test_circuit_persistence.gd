extends SceneTree
## Real filesystem regression: only unique user://qa paths, never the normal save.

class PersistenceUI extends "res://scripts/circuit_main.gd":
	var notices: Array[String] = []
	func _notify(message: String, _color: Color = Color("36725f")) -> void:
		notices.append(message)

const Main = preload("res://scripts/circuit_main.gd")
var checks = 0
var failures: Array[String] = []
var qa_path = ""
var instances: Array[PersistenceUI] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var protected_before := _normal_fingerprints()
	var directory := "user://qa/persistence-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create unique QA-only save directory")
	qa_path = directory + "/company.json"
	var writer := _app()
	writer.model.new_run("Filesystem Fair", 88441)
	writer.has_run = true
	_check(bool(writer.model.act("book", {"id": "willowbank"}).ok), "Create a real pending travel event")
	_check(writer.model.state.phase == "event", "Travel decision is pending before disk save")
	_check(writer._save_game(), "Write the first complete company to disk")
	_check(FileAccess.file_exists(qa_path) and not FileAccess.file_exists(qa_path + ".tmp"), "Successful atomic commit leaves a primary and no temporary file")
	var loaded := _app()
	loaded._load_game()
	_check(loaded.has_run, "A fresh UI instance loads the filesystem save")
	_check(_model_json(writer) == _model_json(loaded), "Pending event and RNG survive the real JSON file round trip")
	var choice := _free_choice(writer)
	writer.model.act("decide", {"choice": choice})
	loaded.model.act("decide", {"choice": choice})
	_check(_model_json(writer) == _model_json(loaded), "Reloaded travel decision has exactly the same outcome")
	writer.model.act("advance")
	loaded.model.act("advance")
	_check(_model_json(writer) == _model_json(loaded), "Reloaded continuation selects the same weather and trading event")
	_check(writer._save_game(), "Save while trading decision remains pending")
	var trading := _app()
	trading._load_game()
	choice = _free_choice(writer)
	writer.model.act("decide", {"choice": choice})
	trading.model.act("decide", {"choice": choice})
	_check(_model_json(writer) == _model_json(trading), "Disk-reloaded trading preserves sales, costs, risk and report")
	var resolved := _model_json(trading)
	_check(not bool(trading.model.act("decide", {"choice": choice}).ok), "A reloaded event cannot be paid twice")
	_check(_model_json(trading) == resolved, "Duplicate resolution leaves persisted company state unchanged")

	writer.settings.sound = false
	writer.settings.motion = false
	writer.records = [{"company": "Filesystem Fair", "season": 1, "profit": 213.5}]
	_check(writer._save_game(), "Commit settings and records together with the model")
	var first_generation := _read_payload()
	writer.settings.music = true
	writer.settings.guide = false
	writer.records.append({"company": "Filesystem Fair", "season": 2, "profit": 376.0})
	_check(writer._save_game(), "Replace an existing primary atomically")
	_check(not FileAccess.file_exists(qa_path + ".tmp"), "Replacement consumes the temporary file")
	_check(_json(_read_payload(qa_path + ".backup")) == _json(first_generation), "Backup is the previous complete generation")
	var latest := _app()
	latest._load_game()
	_check(_json(latest.settings) == _json(writer.settings), "Updated accessibility and audio settings survive reload")
	_check(_json(latest.records) == _json(writer.records), "Updated season history survives reload")
	_check(_model_json(latest) == _model_json(writer), "Settings/history update preserves the company")

	_write_text(qa_path, "{incomplete-save")
	var recovery := _app()
	recovery._load_game()
	_check(recovery.has_run, "A malformed primary recovers from the valid backup")
	_check(_model_json(recovery) == _json(first_generation.model), "Recovered model matches the prior full generation")
	_check(_json(recovery.settings) == _json(first_generation.settings), "Backup recovers matching settings")
	_check(_json(recovery.records) == _json(first_generation.records), "Backup recovers matching records")
	var good_backup_hash := FileAccess.get_sha256(qa_path + ".backup")
	_check(recovery._save_game(), "A recovered game repairs the malformed primary")
	_check(FileAccess.get_sha256(qa_path + ".backup") == good_backup_hash, "Repair does not replace a valid backup with malformed JSON")

	var invalid: Dictionary = _read_payload()
	invalid.model.stock = -7
	_write_text(qa_path, JSON.stringify(invalid))
	var semantic_recovery := _app()
	semantic_recovery._load_game()
	_check(semantic_recovery.has_run and int(semantic_recovery.model.state.stock) >= 0, "Model-invalid primary falls back to the good backup")
	_check(semantic_recovery._save_game(), "Repair a syntactically valid but model-invalid primary")
	_check(FileAccess.get_sha256(qa_path + ".backup") == good_backup_hash, "An invalid primary cannot displace the last valid backup")

	var primary_before := FileAccess.get_sha256(qa_path)
	var backup_before := FileAccess.get_sha256(qa_path + ".backup")
	_check(DirAccess.make_dir_absolute(qa_path + ".tmp") == OK, "Create a QA-only obstacle to simulate an unwritable temporary file")
	semantic_recovery.settings.sound = not semantic_recovery.settings.sound
	_check(not semantic_recovery._save_game() and semantic_recovery.save_failed, "A failed write is reported to the caller")
	_check(FileAccess.get_sha256(qa_path) == primary_before, "Failed update preserves the previous primary bytes")
	_check(FileAccess.get_sha256(qa_path + ".backup") == backup_before, "Failed update preserves the backup bytes")
	_check(DirAccess.remove_absolute(qa_path + ".tmp") == OK, "Remove only the known empty QA obstacle")
	_check(semantic_recovery._save_game() and not semantic_recovery.save_failed, "A later successful save clears the failure state")
	_check(_normal_fingerprints() == protected_before, "Normal company save, backup and temporary file were never modified")
	for app in instances: app.free()
	for failure in failures: print("FAIL: " + failure)
	print("CIRCUIT_PERSISTENCE_CHECKS %d passed / %d; real filesystem evidence: %s" % [checks - failures.size(), checks, ProjectSettings.globalize_path(directory)])
	quit(0 if failures.is_empty() else 1)

func _app() -> PersistenceUI:
	var app := PersistenceUI.new()
	app.save_path = qa_path
	app.test_mode = false
	instances.append(app)
	return app

func _free_choice(app: PersistenceUI) -> int:
	for index in range(app.model.state.event.choices.size()):
		var choice: Dictionary = app.model.state.event.choices[index]
		var effects: Dictionary = choice.get("effects", {})
		if float(effects.get("cash", 0)) >= 0 and float(effects.get("stock", 0)) >= 0 and not choice.has("risk"):
			return index
	return app.model.state.event.choices.size() - 1

func _normal_fingerprints() -> Array:
	var result: Array = []
	for suffix in ["", ".backup", ".tmp"]:
		var path: String = Main.SAVE + suffix
		result.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT")
	return result

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "QA fixture file opened")
	if file != null:
		file.store_string(text)
		file.flush()
		file.close()

func _read_payload(path: String = "") -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(qa_path if path.is_empty() else path))

func _model_json(app: PersistenceUI) -> String:
	return _json(app.model.to_save())

func _json(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
