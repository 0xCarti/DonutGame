extends SceneTree
## Score presentation must be bounded and leave all authoritative run data alone.

const Feedback = preload("res://scripts/score_feedback.gd")
const Effects = preload("res://scripts/score_effects.gd")
const Model = preload("res://scripts/run_model.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tiers_and_chains()
	_test_model_and_receipt_purity()
	await _test_effect_bounds_and_reduced_motion()
	print("FEEDBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _receipt(amount: float, full: bool = true) -> Dictionary:
	return {"amount": amount, "count": 6 if full else 2, "full": full, "golden": 0, "combo": "Perfect six" if full else "Quick sale", "multiplier": 2.0 if full else 1.0, "streak": 0}


func _test_tiers_and_chains() -> void:
	var feedback = Feedback.new()
	var partial: Dictionary = feedback.describe_sale(_receipt(8.0, false), 0.0)
	_check(int(partial["tier"]) == 0 and int(partial["chain"]) == 0, "small partial sale uses quiet base feedback")
	feedback.reset()
	var full: Dictionary = feedback.describe_sale(_receipt(48.0), 0.0)
	_check(int(full["tier"]) == 1 and int(full["chain"]) == 1, "full matching tray gets first full-tray tier")
	for spec in [[119.99, 1], [120.0, 2], [279.99, 2], [280.0, 3], [999999.0, 3]]:
		feedback.reset()
		var described: Dictionary = feedback.describe_sale(_receipt(float(spec[0])), 0.0)
		_check(int(described["tier"]) == int(spec[1]), "magnitude threshold for $%.2f" % float(spec[0]))
	feedback.reset()
	for index in range(8):
		var described: Dictionary = feedback.describe_sale(_receipt(48.0), float(index))
		_check(int(described["chain"]) == index + 1, "consecutive full sale increments chain %d" % (index + 1))
		if index == 2:
			_check(int(described["tier"]) == 2, "third consecutive tray earns stronger visual tier")
		if index == 4:
			_check(int(described["tier"]) == 3, "fifth consecutive tray reaches maximum visual tier")
	var capped: Dictionary = feedback.describe_sale(_receipt(48.0), 8.0)
	_check(int(capped["chain"]) == 8 and int(capped["tier"]) == 3, "rapid-sale chain and tier are capped")
	var boundary: Dictionary = feedback.describe_sale(_receipt(48.0), 13.0)
	_check(int(boundary["chain"]) == 8, "five-second boundary continues chain")
	var gap: Dictionary = feedback.describe_sale(_receipt(48.0), 18.01)
	_check(int(gap["chain"]) == 1 and int(gap["tier"]) == 1, "gap longer than five seconds restarts chain")
	feedback.describe_sale(_receipt(8.0, false), 18.5)
	var after_partial: Dictionary = feedback.describe_sale(_receipt(48.0), 19.0)
	_check(int(after_partial["chain"]) == 1, "partial sale breaks full-tray chain")
	var rewound: Dictionary = feedback.describe_sale(_receipt(48.0), 2.0)
	_check(int(rewound["chain"]) == 1, "rewound shift clock does not extend old chain")
	feedback.reset()
	_check(feedback.chain == 0 and feedback.last_sale_time == -100.0, "explicit reset clears presentation history")
	var goal: Dictionary = feedback.describe_sale(_receipt(48.0), 0.0, true)
	_check(int(goal["tier"]) == 2 and bool(goal["goal"]), "crossing target raises presentation tier")
	feedback.reset()
	var goal_partial: Dictionary = feedback.describe_sale(_receipt(8.0, false), 0.0, true)
	_check(int(goal_partial["chain"]) == 0 and bool(goal_partial["goal"]), "partial sale can cross target without creating full-tray chain")
	_check(not str(goal_partial["title"]).contains("SIX"), "partial goal sale is not mislabeled as six donuts")
	var prior_chain: int = feedback.chain
	var prior_time: float = feedback.last_sale_time
	for invalid_amount in [0.0, -1.0, NAN, INF]:
		_check(feedback.describe_sale(_receipt(invalid_amount), 100.0).is_empty(), "zero or invalid amount produces no feedback")
	_check(feedback.chain == prior_chain and feedback.last_sale_time == prior_time, "rejected receipts do not change feedback history")


func _test_model_and_receipt_purity() -> void:
	var model = Model.new()
	model.new_run(806)
	model.owned["golden_sixth"] = 1
	model.owned["matching_bonus"] = 1
	model.start_shift()
	model.queue_batch("cocoa", 1)
	model.tick(12.0)
	var receipt: Dictionary = model.sell_tray(1)
	var original_receipt: Dictionary = receipt.duplicate(true)
	var original_model: Dictionary = model.to_save()
	var feedback = Feedback.new()
	for index in range(20):
		var described: Dictionary = feedback.describe_sale(receipt, float(index) * 0.1, index == 0)
		_check(is_equal_approx(float(described["amount"]), float(receipt["amount"])), "celebration amount stays authoritative during chain %d" % index)
	_check(receipt == original_receipt, "tier and goal calculation never mutate sale receipt")
	_check(model.to_save() == original_model, "tier and chain processing never mutate payout, upgrades, timers, or RNG")


func _test_effect_bounds_and_reduced_motion() -> void:
	var effects = Effects.new()
	root.add_child(effects)
	effects.set_process(false)
	var feedback = Feedback.new()
	var sale: Dictionary = feedback.describe_sale(_receipt(390.0), 0.0, true)
	var original_sale: Dictionary = sale.duplicate(true)
	_check(_ignores_input(effects), "entire celebration layer ignores pointer input")
	for index in range(12):
		effects.celebrate(sale, Vector2(400 + index * 5, 500))
		_check(effects.coins.size() <= 84 and effects.trails.size() <= 4, "rapid celebration keeps particle bounds %d" % index)
	_check(effects.coins.size() == 84 and effects.trails.size() == 4, "rapid-sale fixture reaches exact bounded caps")
	_check(effects._group.visible and str(effects._goal.text) == "TARGET SMASHED!", "goal celebration is visible")
	_check(sale == original_sale, "effects do not mutate feedback receipt")
	effects._process(0.1)
	_check(effects._amount.text != "+$390", "normal presentation animates toward final amount")
	effects.set_reduced_motion(true)
	_check(effects.coins.is_empty() and effects.trails.is_empty(), "enabling reduced motion immediately clears moving particles")
	_check(effects._group.scale == Vector2.ONE, "reduced motion removes scale bounce")
	_check(effects._amount.text == "+$390", "enabling reduced motion during countup immediately reveals exact final amount")
	effects._process(0.1)
	_check(effects._amount.text == "+$390", "reduced-motion amount remains correct after processing")
	effects.celebrate(sale, Vector2(500, 500))
	_check(effects.coins.is_empty() and effects.trails.is_empty(), "reduced-motion celebrations do not create moving particles")
	_check(effects._amount.text == "+$390" and effects._group.visible, "reduced motion still shows readable success feedback")
	effects.reset()
	_check(effects.active_receipt.is_empty() and effects.coins.is_empty() and effects.trails.is_empty() and not effects._group.visible, "reset removes every transient celebration")
	effects.set_reduced_motion(false)
	effects.celebrate(sale, Vector2(500, 500))
	effects._process(4.0)
	_check(effects.coins.is_empty() and effects.trails.is_empty() and not effects._group.visible, "expired celebration releases all visual particles")
	effects.free()
	await process_frame


func _ignores_input(control: Node) -> bool:
	if control is Control and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in control.get_children():
		if not _ignores_input(child):
			return false
	return true
