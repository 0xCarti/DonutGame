extends SceneTree
const Feedback = preload("res://scripts/stand_feedback.gd")
var checks = 0
var failures = 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PRESENTATION FAIL: " + message)

func _input_transparent(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE: return false
	for child in node.get_children():
		if not _input_transparent(child): return false
	return true

func _run() -> void:
	var view = Feedback.new()
	root.add_child(view)
	view.set_process(false)
	check(_input_transparent(view), "every celebration control passes clicks to actual stations")
	check(Feedback.tier_for({"amount":15,"streak":1}) == 0, "small sale starts restrained")
	check(Feedback.tier_for({"amount":15,"streak":3}) == 1, "third sale raises celebration")
	check(Feedback.tier_for({"amount":15,"streak":6}) == 2, "sixth sale raises celebration")
	check(Feedback.tier_for({"amount":45,"streak":1}) == 2, "large individual sale is recognized")
	check(Feedback.tier_for({"amount":15,"streak":10}) == 3, "ten-order streak reaches top tier")
	var receipt = {"amount":23.47, "base_price":20.0, "tip":3.47, "streak":3}
	view.celebrate(receipt)
	receipt.amount = 999
	for i in range(5): view._process(.1)
	check(view._amount.text == "+$23.47", "receipt count-up preserves authoritative cents and copies input")
	check(view._detail.text == "$20.00 order  +  $3.47 tip", "base and tip breakdown uses actual receipt values")
	check(view._title.text == "ON A ROLL", "streak wording matches tier")
	check(view._group.visible, "successful sale remains visible long enough to read")
	view.celebrate({"amount":34.27,"base_price":25,"tip":9.27,"patience_tip":3.77,"streak_tip":2.5,"upgrade_tip":3.0,"streak":10})
	check(view._detail.text.contains("Speed $3.77") and view._detail.text.contains("Streak $2.50") and view._detail.text.contains("Bonuses $3.00"), "receipt explains speed, streak and venue/equipment bonus contributions")
	for i in range(250): view.celebrate({"amount":51.82,"streak":20})
	check(view.coins.size() <= Feedback.MAX_COINS and view.sparks.size() <= Feedback.MAX_SPARKS, "dense sale bursts stay bounded")
	check(view.get_child_count() == 2 and view._group.get_child_count() == 4, "effects reuse controls instead of accumulating nodes")
	for i in range(40): view._process(.1)
	check(view.coins.is_empty() and view.sparks.is_empty() and not view._group.visible, "expired sale effects fully retire")
	view.show_goal()
	check(view._goal.visible and view._goal.text == "SHIFT TARGET CLEARED", "goal clear has explicit readable wording")
	view.set_reduced_motion(true)
	view.celebrate({"amount":33.21,"streak":15})
	check(view._amount.text == "+$33.21" and view.coins.is_empty() and view.sparks.is_empty(), "reduced motion shows exact amount without particles")
	view._process(.1)
	check(view._group.scale == Vector2.ONE and view._flash == 0, "reduced motion removes scale and flash")
	view.notify_fault("jam")
	check(view.fault_code == "jam" and view.fault_age == 0, "fault onset is distinct from sale state")
	view.reset()
	check(view.active_receipt.is_empty() and not view._goal.visible and not view._group.visible and view.fault_age > 1.4, "screen changes clear all pending effects")
	for invalid in [{}, {"amount":0}, {"amount":-1}, {"amount":INF}, {"amount":NAN}]:
		view.celebrate(invalid)
		check(view.active_receipt.is_empty(), "invalid receipt cannot invent a payout")
	view.queue_free()
	await process_frame
	print("STAND PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
