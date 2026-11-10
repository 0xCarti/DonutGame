extends SceneTree
## Integration tests for the actual activity, itinerary, contract and crew sheets.
class DemoUI extends "res://scripts/circuit_main.gd":
	func _load_game() -> void: pass
	func _save_game() -> bool: return true

var app: DemoUI
var checks = 0
var failures: Array[String] = []
var capture_dir = ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")

func _has_text(node: Node, value: String) -> bool:
	if node is Label and node.text == value: return true
	for child in node.get_children():
		if _has_text(child, value): return true
	return false

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(390, 844)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	app = DemoUI.new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.test_mode = true
	app.settings.motion = false
	app._start_company("The Little Circuit", false)
	await _settle()
	_check(app.find_child("LivingStand", true, false) != null, "Journal contains live company illustration")
	await _capture("01-living-stand")
	app._show_activities()
	await _settle()
	await _capture("02-activities")
	var repair: Dictionary = _offer("repair")
	_check(not repair.is_empty(), "Initial worn van has contextual repair")
	app._show_activity_choice(str(repair.id))
	await _settle()
	_check(app.find_child("ActivityDelegate", true, false).disabled, "Unstaffed company cannot delegate")
	_check(_has_text(app.modal, "Complexity 1 / 3"), "Activity choice discloses initial repair complexity")
	await _capture("03-activity-choice")
	var original: Dictionary = app.model.to_save()
	app._start_activity(str(repair.id))
	await _settle()
	_check(app._activity_busy, "Parent opens real repair control")
	await _capture("04-repair")
	app._close_modal()
	_check(app.model.to_save() == original, "Cancelling preserves cash and attempt")
	app._start_activity(str(repair.id))
	await _settle()
	app._activity_game.completed.emit(0.75)
	await _settle()
	_check(is_equal_approx(float(app.model.state.cash), float(original.cash) - 15), "Completion charges disclosed parts once")
	_check(float(app.model.state.truck) > float(original.truck), "Completed game applies actual repair")
	var committed = app.model.to_save()
	app._finish_activity(str(repair.id), 1)
	_check(app.model.to_save() == committed, "Stale callback cannot duplicate reward")
	await _capture("05-activity-result")
	app._act("book", {"id":"willowbank"})
	await _settle()
	_resolve_event()
	await _settle()
	app._close_modal()
	app._act("hire", {"id":"bea"})
	await _settle()
	var orders = _offer("orders")
	app._show_activity_choice(str(orders.id))
	await _settle()
	_check(not app.find_child("ActivityDelegate", true, false).disabled, "Available crew can delegate")
	app._start_activity(str(orders.id))
	await _settle()
	await _capture("06-order-memory")
	app._activity_game.completed.emit(0.8)
	await _settle()
	_check(float(app.model.state.day_modifiers.demand) >= 0.064 - 0.00001, "Order activity stores next-opening bonus")
	var inspection = _offer("inspection")
	app._start_activity(str(inspection.id))
	await _settle()
	await _capture("07-inspection")
	app._close_modal()
	app._resolve_activity(str(inspection.id), "delegate")
	await _settle()
	_check(str(app.model.state.circuit.last_activity.mode) == "delegate", "Delegated result uses model score")
	await _capture("08-delegation-result")
	var cash_before = float(app.model.state.cash)
	for id in ["brass_bell", "juniper", "lantern_quay"]: app._act("plan_stop", {"id":id})
	await _settle()
	_check(is_equal_approx(float(app.model.state.cash), cash_before), "Planning never charges booking money")
	_check(app.model.itinerary().size() == 3, "Three future stops planned")
	app._navigate("circuit")
	await _settle()
	_check(app.find_child("CircuitMap", true, false) != null, "Circuit has interactive map")
	await _capture("09-route-map")
	app._show_calendar()
	await _settle()
	await _capture("10-season-calendar")
	app._act("move_stop", {"id":"juniper", "direction":-1})
	await _settle()
	_check(str(app.model.state.circuit.itinerary[0]) == "juniper", "Itinerary reorders through model")
	app._show_venue("solstice")
	await _settle()
	await _capture("11-map-stop-details")
	app.model.state.stats.total_sold += 250
	app._show_contracts()
	await _settle()
	_check(not app.find_child("ContractClaim_warm_bags", true, false).disabled, "Completed contract enables claim")
	await _capture("12-contracts")
	app._act("claim_contract", {"id":"warm_bags"})
	await _settle()
	_check("bunting" in app.model.state.circuit.decorations, "Claim unlocks visible persistent decoration")
	await _capture("13-contract-reward")
	app._act("hire", {"id":"nell"})
	await _settle()
	app._navigate("crew")
	await _settle()
	var moments: Array = app.model.crew_moments()
	_check(not moments.is_empty(), "Named employees offer a personal moment")
	app._show_crew_moment(str(moments[0].id))
	await _settle()
	await _capture("14-crew-moment")
	app._act("crew_decide", {"id":str(moments[0].id), "choice":2})
	await _settle()
	_check(not app.model.staff_personality("bea").friends.is_empty(), "Choice builds a named friendship")
	app._show_staff("bea")
	await _settle()
	await _capture("15-friendship-profile")
	app._close_modal()
	app._act("advance")
	await _settle()
	_resolve_event()
	await _settle()
	_check(str(app.model.state.phase) == "report", "Activities integrate with a real trading day")
	_check(app.find_child("TradingResults", true, false) != null, "Report contains animated real sales")
	_check(not app.model.state.last_report.drivers.is_empty(), "Actual sales drivers reach report")
	_check(is_zero_approx(float(app.model.state.day_modifiers.demand)), "Preparation bonus expires after trade")
	await _capture("16-trading-result")
	for size in [Vector2i(360,780), Vector2i(600,960), Vector2i(960,600)]:
		root.size = size
		await _settle()
		app._show_report()
		await _settle()
		await _capture("17-results-%dx%d" % [size.x,size.y])
	app._act("dismiss_report")
	await _settle()
	root.size = Vector2i(390,844)
	app.model.state.weather = "Showers"
	app.model.state.fryer = 22
	app.model.state.truck_tier = 2
	app.model.state.stand_tier = 2
	app.model.state.circuit.decorations = ["bunting", "route_sign", "flower_box", "golden_lamp", "review_board", "crew_frame", "golden_rosette", "striped_awning"]
	app._navigate("journal")
	await _settle()
	await _capture("18-grown-company-rain")
	# Final-day contracts remain collectible before the next season replaces them.
	app.model.state.circuit.decorations = ["bunting"]
	app.model.state.phase = "season_end"
	app.model.state.stats.completed_stops += 2
	app._reviewing_season = false
	app._render()
	await _settle()
	var season_contracts = app.find_child("SeasonContracts", true, false)
	_check(season_contracts != null, "Ending screen provides a contract reward entry")
	season_contracts.pressed.emit()
	await _settle()
	# Resolve the active stop contract by metric to avoid depending on its caption.
	var final_id = ""
	for contract in app.model.contract_offers():
		if str(contract.metric) == "stops": final_id = str(contract.id)
	var final_claim = app.find_child("ContractClaim_" + final_id, true, false)
	_check(final_claim != null and not final_claim.disabled, "Last-day contract can be collected")
	var final_cash = float(app.model.state.cash)
	final_claim.pressed.emit()
	await _settle()
	_check(float(app.model.state.cash) == final_cash + 180, "Season-end claim pays once")
	_check(app._reviewing_season and str(app.model.state.phase) == "season_end", "Claim preserves season review")
	_check(app.modal.find_children("*", "Label", true, false).any(func(label): return label.text == "CONTRACT COMPLETE"), "Deferred ending cannot replace reward sheet")
	await _capture("19-final-day-reward")
	app._act("claim_contract", {"id":final_id})
	_check(float(app.model.state.cash) == final_cash + 180, "Final-day reward cannot be claimed twice")
	app._close_modal()
	app._primary()
	await _settle()
	_check(app.find_child("SeasonContracts", true, false) != null, "Season summary remains reachable after claiming")
	app._act("next_season")
	await _settle()
	_check(app.model.state.season == 2 and "route_sign" in app.model.state.circuit.decorations, "Claimed keepsake survives next season")
	app.model.state.circuit.metrics.reputation += 4.6
	app._show_contracts()
	await _settle()
	_check(app.find_child("ContractClaim_good_word", true, false).disabled, "Fractional reputation below the goal is not claimable")
	_check(app.modal.find_children("*", "Label", true, false).any(func(label): return label.text == "4.60 / 5"), "Fractional progress is not rounded to a misleading completed goal")
	app.queue_free()
	await process_frame
	for failure in failures: print("FAIL: " + failure)
	print("CIRCUIT_EXPANSION_UI_CHECKS %d passed / %d" % [checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

func _offer(kind: String) -> Dictionary:
	for offer in app.model.activity_offers():
		if str(offer.kind) == kind: return offer
	return {}

func _resolve_event() -> void:
	if str(app.model.state.phase) != "event": return
	for index in range(app.model.state.event.choices.size()):
		var effects: Dictionary = app.model.state.event.choices[index].get("effects", {})
		if float(effects.get("cash", 0)) >= 0 and int(effects.get("stock", 0)) >= 0:
			app._act("decide", {"choice":index})
			return
	app._act("decide", {"choice":app.model.state.event.choices.size()-1})

func _settle() -> void:
	for frame in range(8): await process_frame

func _capture(label: String) -> void:
	_check_widths(app, label)
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _check_widths(node: Node, label: String) -> void:
	if node is Button and node.is_visible_in_tree(): _check(node.size.y >= 43, label + " touch " + node.text)
	if node is Control and node.is_visible_in_tree() and not node is VScrollBar:
		var bounds: Rect2 = node.get_global_rect()
		if bounds.size.x > 0 and node != app.toast:
			_check(bounds.position.x >= -1 and bounds.end.x <= app.get_viewport_rect().size.x + 2, label + " fits " + str(node.get_path()))
	for child in node.get_children(): _check_widths(child, label)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
