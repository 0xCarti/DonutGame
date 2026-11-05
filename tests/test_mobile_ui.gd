extends SceneTree
## Touch layout, controller signal contract, and interruption-safe hold controls.
const HUD = preload("res://scripts/stand_hud.gd")
var checks = 0
var failures = 0


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("MOBILE UI: " + message)


func _visible_labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	if node is Label and node.is_visible_in_tree(): result.append(node)
	for child in node.get_children(): result.append_array(_visible_labels(child))
	return result


func _run() -> void:
	var hud = HUD.new()
	var theme = Theme.new()
	theme.default_font = load("res://assets/fonts/Fredoka.ttf")
	hud.theme = theme
	root.add_child(hud)
	hud.set_process(false)
	check(not hud.mobile_mode and hud.mobile.is_empty(), "desktop starts without touch overlays")
	check(hud.controls.orders[0].card.position == Vector2(380,16), "desktop front ticket keeps its existing placement")
	check(hud.controls.orders[0].order.get_theme_font_size("font_size") == 23, "desktop typography remains unchanged")
	var actions: Array[String] = []
	var started: Array[String] = []
	var ended: Array[String] = []
	hud.mobile_action_requested.connect(func(action: String): actions.append(action))
	hud.mobile_hold_started.connect(func(action: String): started.append(action))
	hud.mobile_hold_ended.connect(func(action: String): ended.append(action))
	hud.configure_mobile(true)
	var touch = hud.mobile_controls
	var state = {"sales":12.5, "target":110, "time_left":95, "temperature":175, "heat_setting":2, "production_speed":2, "appeal":87, "venue_id":"concert", "machine_id":"twin_lane", "active_buff":"good_vibes", "supply":18, "supply_capacity":36, "batter":42, "held_tool":"none", "package_type":"", "package_count":0, "package_flavor":"", "hold_station":"", "orders":[{"package":"bag","flavor":"cinnamon","patience":40,"max_patience":50},{"package":"bucket","flavor":"powdered","patience":50,"max_patience":50}]}
	var context = {"station":"bag", "prompt":"Take the right container", "key":"B", "hint":"Press B to take a bag", "step":"CHOOSE · B", "machine_status":"MAKING DONUTS", "faults":[], "practice":false}
	hud.refresh(state,context)
	await process_frame
	check(hud.mobile.order.text == "Bag · 6 mini donuts", "mobile displays the authoritative first order prominently")
	check(hud.mobile.flavor.text == "Cinnamon sugar" and hud.mobile.waiting.text == "1 waiting", "mobile keeps flavor and queue count without three competing tickets")
	check(hud.mobile.progress.text == "$12.50 / $110", "mobile status preserves exact money")
	check(hud.mobile.clock.text == "1:35 remaining", "mobile clock is readable and accurate")
	check(hud.mobile.machine.text.contains("175°") and hud.mobile.stock.text.contains("Batter 42"), "essential fryer resources stay visible")
	check(hud.mobile.appeal.text.contains("87") and hud.mobile.venue.text == "Concert · Twin-Lane" and hud.mobile.buff.text.contains("Good Vibes"), "touch HUD exposes authoritative appeal venue machine and active supply")
	check(hud.mobile.flow.text.contains("Fast"), "feed speed is separate from heat on the touch HUD")
	for buff_id in ["", "fresh_oil", "freshly_serviced", "good_vibes", "emergency_batter", "rush_contract"]:
		state.active_buff = buff_id
		hud.refresh(state,context)
		var label: Label = hud.mobile.buff
		var text_width = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		check(text_width <= label.size.x, "appeal hint or active supply fits without ellipsis: " + label.text)
	check(not hud.controls.orders[0].card.visible, "desktop overlay is hidden in mobile mode")
	check(touch.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud._mobile_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "open counter space remains available to touch gestures")
	check(not touch.drawer.visible, "secondary tool controls start collapsed")
	check(touch.context_button.size == Vector2(420,80), "context action has a large touch target")
	var no_keyboard = true
	var readable = true
	for label in _visible_labels(hud):
		no_keyboard = no_keyboard and not label.text.contains("Press ") and not label.text.contains("CLICK") and not label.text.contains("Esc")
		readable = readable and label.get_theme_font_size("font_size") >= 20
	check(no_keyboard, "mobile guidance does not depend on desktop key prompts")
	check(readable, "all visible mobile label text is at least20 logical pixels")
	for action in ["recenter","pause","help","settings"]:
		var button: Button = touch.buttons[action]
		check(button.size.y >= 80 and button.size.x >= 104, action + " has a large toolbar target")
		button.pressed.emit()
	check(actions == ["recenter","pause","help","settings"], "toolbar signals preserve the main controller API")
	touch.context_button.pressed.emit()
	check(actions.back() == "bag", "context button routes the exact station action")
	touch.buttons.tools.pressed.emit()
	check(touch.drawer.visible and touch.order_page.visible and not touch.fryer_page.visible, "Tools opens a separate order page")
	var inside = true
	for button in touch.buttons.values():
		inside = inside and Rect2(Vector2.ZERO,Vector2(1280,800)).encloses(button.get_global_rect())
	check(inside, "all touch controls stay within the safe-area-owned logical canvas")
	touch.buttons.bag.pressed.emit()
	check(actions.back() == "bag" and not touch.drawer.visible, "tool action closes the drawer to reveal physical props")
	touch.set_tools_open(true)
	touch.buttons.fryer_tab.pressed.emit()
	check(touch.fryer_page.visible and not touch.order_page.visible, "fryer controls are separated from order shortcuts")
	for station in ["speed_down", "speed_up"]:
		touch.set_tools_open(true)
		touch.buttons.fryer_tab.pressed.emit()
		touch.buttons[station].pressed.emit()
		check(actions.back() == station, "touch feeder control routes distinct action: " + station)
	touch.set_tools_open(true)
	touch.buttons.fryer_tab.pressed.emit()
	touch.buttons.repair.button_down.emit()
	touch.buttons.repair.button_down.emit()
	check(started == ["repair"], "a hold starts exactly once")
	touch.buttons.repair.mouse_exited.emit()
	touch.buttons.repair.button_up.emit()
	check(ended == ["repair"], "dragging away cancels once and later release does not repeat")
	touch.buttons.refill.button_down.emit()
	touch.set_tools_open(false)
	check(ended.back() == "refill", "closing Tools cancels an active refill")
	touch.set_context("repair","Hold to repair")
	touch.context_button.button_down.emit()
	touch.set_context("bag","Take bag")
	check(touch._context_action == "repair", "context target cannot change beneath a held finger")
	touch.context_button.button_up.emit()
	check(ended.back() == "repair", "context hold ends on finger release")
	touch.set_context("refill","Hold to refill")
	touch.context_button.button_down.emit()
	touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(ended.back() == "refill" and touch._active_hold.is_empty(), "app focus loss cancels holds")
	context.faults = [{"code":"fire", "station":"extinguish", "title":"FRYER ON FIRE!", "critical":true, "action":"Press Q"}]
	hud.refresh(state,context)
	check(hud.mobile.fault.visible and touch._context_action == "extinguish", "critical fault exposes an immediate touch action")
	check(not hud.mobile.fault_action.text.contains("Press") and touch.context_button.text == "Use extinguisher", "fault wording is touch-first")
	context.faults = [{"code":"jam", "station":"repair", "title":"FEEDER JAMMED", "critical":true}]
	state.hold_station = "repair"
	state.jam_progress = .45
	hud.refresh(state,context)
	check(hud.mobile.hold.visible and is_equal_approx(hud.mobile.hold.value,45), "hold progress is visible and reflects model state")
	touch.context_button.button_down.emit()
	hud.configure_mobile(false)
	check(ended.back() == "repair" and touch._active_hold.is_empty(), "switching away from mobile cancels active holds")
	check(hud.controls.orders[0].card.visible and not hud._mobile_layer.visible, "desktop layout returns without touch overlays")
	check(hud.controls.key.text == "B", "desktop retains its keyboard guidance")
	hud.configure_mobile(true)
	touch.set_context("refill","Hold to refill")
	touch.context_button.button_down.emit()
	hud.queue_free()
	await process_frame
	check(ended.back() == "refill", "destroying the HUD releases the held action")
	print("MOBILE UI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
