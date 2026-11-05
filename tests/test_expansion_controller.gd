extends SceneTree
## Expansion integration uses actual UI signals and a real model/world, with
## profile persistence intercepted in memory and no writes to player saves.

const Controller = preload("res://scripts/stand_main.gd")
const Profile = preload("res://scripts/player_profile.gd")
const Market = preload("res://scripts/stand_market.gd")

class MemoryController extends Controller:
	var fail_run_write = false
	var write_attempts = 0
	func _write_json_atomic(_path: String, _data: Dictionary) -> bool:
		write_attempts += 1
		return not fail_run_write
	func _delete_run_files() -> void:
		return

class MemoryProfile extends Profile:
	var fail_save = false
	var save_attempts = 0
	func save_profile() -> bool:
		save_attempts += 1
		return not fail_save

var app
var checks = 0
var failures = 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("EXPANSION CONTROLLER: " + message)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	app = MemoryController.new()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false)
	app.world.set_process(false)
	app.audio.set_muted(true)
	app.audio.set_music_volume(0.0)
	app.profile = MemoryProfile.new()
	app.profile.test_mode = true
	for index in range(60): app.profile.grant_shift_reward("fixture", index, {"completed": true, "served": 20})
	await process_frame
	await physics_frame
	await _market_and_preview()
	await _operator_previews()
	await _badges_and_touch_bounds()
	await _buff_transactions()
	_career_save_retry()
	await _practice_isolation()
	await _partial_and_air_mail()
	await _physical_head_chef()
	app.audio.stop_music()
	for player in app.audio.get_children():
		if player is AudioStreamPlayer: player.stop()
	app.world.reset_food(0, 36)
	app.queue_free()
	await process_frame
	await process_frame
	print("EXPANSION CONTROLLER: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _market_and_preview() -> void:
	app._show_collection()
	await _click(app.screen, "TICKET BOOTH")
	check(_has_text(app.overlay, "THE TICKET BOOTH") and _has_text(app.overlay, "Real-money checkout unavailable"), "collection opens the real catalogue with honest checkout status")
	var balance: int = app.profile.tickets
	await _click(_card(app.overlay, "Neon Midway"), "180 TICKETS")
	check(app.profile.owned_items.has("neon_midway") and app.profile.tickets == balance - 180, "market buy button spends displayed Tickets exactly once")
	await _click(_card(app.overlay, "Neon Midway"), "EQUIP")
	check(app.profile.selected_cosmetic == "neon_midway" and app.profile.cosmetic_loadout().stand == "neon_midway", "market equip updates the career loadout")
	var before: Dictionary = app.profile.get_summary()
	await _click(_card(app.overlay, "Grandma's Recipe"), "PREVIEW")
	check(app.current_view == "preview" and app._view_state().cosmetic_loadout.stand == "grandmas_recipe", "preview shows an unowned set on the counter")
	check(app.profile.get_summary() == before, "preview spends nothing and does not alter the saved outfit")
	await _click(app.screen, "BACK TO TICKET BOOTH")
	check(app._preview_loadout.is_empty() and app._view_state().cosmetic_loadout.stand == "neon_midway" and app.profile.get_summary() == before, "preview close restores the equipped outfit")
	app.profile.fail_save = true
	await _click(_card(app.overlay, "Chrome Carnival"), "220 TICKETS")
	check(app.profile.get_summary() == before, "failed purchase save restores both wallet and ownership")
	app.profile.fail_save = false
	app.profile.purchase_with_tickets("grandmas_recipe")
	before = app.profile.get_summary()
	app.profile.fail_save = true
	app._show_market()
	await _click(_card(app.overlay, "Grandma's Recipe"), "EQUIP")
	check(app.profile.get_summary() == before and app._view_state().cosmetic_loadout.stand == "neon_midway", "failed equip save restores the previous outfit")
	app.profile.fail_save = false
	app.mobile_mode = true
	await _click(_card(app.overlay, "Chrome Carnival"), "PREVIEW")
	app._mobile_back()
	await process_frame
	check(app._preview_loadout.is_empty() and app._view_state().cosmetic_loadout.stand == "neon_midway", "Android Back cancels preview without leaking its appearance")
	app._close_overlay()

func _operator_previews() -> void:
	app.mobile_mode = true
	for dimensions in [Vector2i(2400, 1080), Vector2i(2532, 1170)]:
		root.size = dimensions
		await process_frame
		app._resize()
		for piece in ["gloves", "sleeves", "watch"]:
			app._show_collection()
			var profile_before: Dictionary = app.profile.get_summary()
			var model_before: Dictionary = app.model.to_save()
			var hand_poses: Array = []
			for hand in app.world._hands: hand_poses.append(hand.transform)
			var scoop_pose: Transform3D = app.world._held_scoop.global_transform
			var tracks: Array = app.world._hand_tracks.duplicate(true)
			app._market_preview("neon_midway_" + piece)
			await process_frame
			check(app.world._paused, "operator preview pauses world simulation")
			var back: Button = _find_button(app.screen, "BACK TO TICKET BOOTH")
			check(back.get_global_rect().end.y < root.size.y * 0.30, "operator preview controls remain above the hands")
			for index in range(app.world._hands.size()):
				var wrist: Vector3 = app.world._hands[index].global_position
				var projected: Vector2 = app.world.camera.unproject_position(wrist)
				check(projected.y > back.get_global_rect().end.y and projected.y < root.size.y * 0.86, "preview wrist is inside the unobstructed phone viewport")
				var rig: Dictionary = app.world._arm_rigs[index]
				check(is_equal_approx(rig.shoulder.distance_to(rig.elbow), app.world.UPPER_ARM_LENGTH) and is_equal_approx(rig.elbow.distance_to(rig.wrist), app.world.FOREARM_LENGTH), "preview retains anatomical arm lengths")
			check(app.world._held_scoop.global_transform == scoop_pose and app.world._hand_tracks == tracks, "preview does not move the held tool or advance hand animation")
			check(app.profile.get_summary() == profile_before and app.model.to_save() == model_before, "operator preview leaves all career and run state unchanged")
			if "--capture-preview" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				var destination = "res://playtest-reports/operator-preview-%s-%d.png" % [piece, dimensions.x]
				check(root.get_texture().get_image().save_png(destination) == OK, "native operator preview capture: " + destination)
			if piece == "sleeves": await _click(app.screen, "BACK TO TICKET BOOTH")
			else: app._mobile_back()
			for index in range(hand_poses.size()):
				check(app.world._hands[index].transform == hand_poses[index], "both preview Back paths restore the prior hand pose exactly")
			check(app.world._operator_preview_poses.is_empty(), "preview exit clears its temporary pose")
			app._close_overlay()
	root.size = Vector2i(1280, 800)
	await process_frame
	app._resize()

func _badges_and_touch_bounds() -> void:
	for badge in app.profile.get_badges(): app.profile.record_achievement(str(badge.id))
	app._show_collection()
	app._badge_page = 0
	app._show_mobile_badges()
	var discovered: Dictionary = {}
	for page in range(3):
		await process_frame
		for badge in app.profile.get_badges():
			if _has_text(app.overlay, str(badge.name)): discovered[badge.id] = true
		_check_buttons_inside(app.overlay, "badge page %d" % page)
		if page < 2: await _click(app.overlay, "NEXT ›")
	check(discovered.size() == 16, "all sixteen badge names are reachable through visible pagination")
	check(_find_button(app.overlay, "NEXT ›").disabled, "last badge page stops forward navigation")
	await _click(app.overlay, "‹ PREVIOUS")
	check(app._badge_page == 1, "badge previous button returns to the middle page")
	app._close_overlay()
	for category in Market.CATEGORIES:
		app._market_category = category
		app._market_page = 0
		app._show_market()
		var pages = 1
		while pages <= 8:
			await process_frame
			await process_frame
			_check_buttons_inside(app.overlay, "%s market page %d" % [category, pages])
			_check_market_text(_market_node(app.overlay), "%s page %d" % [category, pages])
			if "--capture-catalog" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				var destination = "res://playtest-reports/catalog-%s-%d.png" % [category, pages]
				check(root.get_texture().get_image().save_png(destination) == OK, "native catalogue capture: " + destination)
			var next: Button = _find_button(app.overlay, "NEXT ›")
			if next == null or next.disabled: break
			await _click(app.overlay, "NEXT ›")
			pages += 1
		check(pages <= 8, "market pagination terminates for " + str(category))
	app._close_overlay()

func _buff_transactions() -> void:
	app.practice = false
	app.model.new_run(2041)
	app.model.start_shift()
	app.run_id = "buff-controller-fixture"
	app.model.sales = app.model.target
	app.model.finish_shift()
	app._reconcile_career()
	app._show_shop()
	app.profile.purchase_with_tickets("fresh_oil")
	app._market_category = "buffs"
	app._market_page = 0
	app._show_market()
	await _click(_card(app.overlay, "Fresh Oil"), "QUEUE (1)")
	check(app.model.pending_buff == "fresh_oil" and app.profile.buff_count("fresh_oil") == 1, "queue button reserves a supply without consuming it")
	app._close_overlay()
	var profile_before: Dictionary = app.profile.get_summary()
	var queued_save: Dictionary = app.model.to_save()
	app.test_mode = false
	app.fail_run_write = true
	app._begin_shift()
	check(app.write_attempts > 0 and app.model.phase == "shop" and app.profile.get_summary() == profile_before, "failed queued checkpoint write blocks starting before any inventory is consumed")
	app.test_mode = true
	app.fail_run_write = false
	app.profile.fail_save = true
	app._begin_shift()
	check(app.model.phase == "shop" and app.model.pending_buff == "fresh_oil" and app.profile.get_summary() == profile_before, "failed inventory save leaves the queued shift and use intact")
	app.profile.fail_save = false
	app._begin_shift()
	check(app.model.phase == "playing" and app.model.active_buff == "fresh_oil" and app.model.pending_buff.is_empty() and app.profile.buff_count("fresh_oil") == 0, "starting a shift consumes and activates the queued supply")
	var receipts: Dictionary = app.profile.buff_transactions.duplicate(true)
	check(app.model.from_save(queued_save), "pre-start checkpoint remains loadable")
	app._begin_shift()
	check(app.model.phase == "playing" and app.model.active_buff == "fresh_oil" and app.profile.buff_count("fresh_oil") == 0 and app.profile.buff_transactions == receipts, "retrying the saved queued shift cannot consume another use")
	app.model.appeal = 87.0
	app.model.production_speed = 0
	app._refresh_hud()
	check(app.dashboard.mobile.appeal.text.contains("87") and app.dashboard.mobile.flow.text.contains("Slow") and app.dashboard.mobile.buff.text.contains("Fresh Oil"), "playing HUD reflects appeal feed speed and actual active supply")
	var heat: int = app.model.heat_setting
	app._mobile_action("speed_up")
	check(app.model.production_speed == 1 and app.model.heat_setting == heat, "mobile feeder action changes production independently from heat")

func _career_save_retry() -> void:
	app.profile = MemoryProfile.new()
	app.profile.test_mode = true
	app.model.new_run(2047)
	app.model.start_shift()
	app.run_id = "career-retry-fixture"
	app.model.sales = app.model.target
	app.model.served = 8
	app.model._run_served = 8
	app.model._run_sales = app.model.sales
	app.model.finish_shift()
	app.model.unlocked_achievements = ["rush_hour"]
	app._show_shop()
	var before: Dictionary = app.profile.get_summary()
	app.profile.fail_save = true
	app._reconcile_career()
	check(app.profile.get_summary() == before and app.model.unlocked_achievements.has("rush_hour"), "failed reward save rolls back wallet and badge while model retains retry evidence")
	var completed_shift: Dictionary = app.model.to_save()
	app._begin_shift()
	check(app.model.to_save() == completed_shift and app.profile.get_summary() == before and app.current_view == "shop", "next-shift action cannot discard an unsaved completed-shift reward")
	app.profile.fail_save = false
	app._begin_shift()
	check(app.profile.badges.has("rush_hour") and app.profile.tickets == 48, "retrying next shift grants exactly one badge bonus and the previous shift reward")
	check(app.model.phase == "playing" and app.model.shift_index == 1 and app.model.served == 0 and app.model.get_stats().total_served == 8 and app.model.get_stats().total_sales == completed_shift.sales, "successful reward retry advances while preserving cumulative service and sales")
	before = app.profile.get_summary()
	app._reconcile_career()
	check(app.profile.get_summary() == before, "repeated career reconciliation cannot duplicate saved rewards")

func _practice_isolation() -> void:
	app.profile = MemoryProfile.new()
	app.profile.test_mode = true
	app._start_practice()
	var before: Dictionary = app.profile.get_summary()
	app.model.events.append({"type": "achievement", "id": "rush_hour"})
	app.model.last_result = {"cleared": true}
	app.model.events.append({"type": "shift_end"})
	app._process_events()
	app._on_gag_sound("seagull")
	check(app.profile.get_summary() == before and app.profile.save_attempts == 0, "practice events and seagull feeds cannot farm badges or Tickets")
	app._show_market()
	check(not _market_node(app.overlay).can_queue, "practice cannot queue consumable career supplies")
	app._close_overlay()

func _partial_and_air_mail() -> void:
	app.practice = false
	app.model.new_run(2042)
	app.model.start_shift()
	app.run_id = "partial-controller-fixture"
	app._show_play()
	app.model.package_type = "bag"
	app.model.package_count = 6
	app.model.package_flavor = "powdered"
	app.model.orders[0].package = "bag"
	app.model.orders[0].flavor = "cinnamon"
	app.held_tool = "package"
	app._sync_world()
	var appeal: float = app.model.appeal
	app._act("serve")
	await _settle_actions()
	check(app.model.served == 1 and app.model.sales > 0.0 and app.model.sales < 18.0 and app.model.appeal < appeal, "partial sale travels through controller payout and appeal integration")
	check(app.held_tool == "none" and app.model.package_type.is_empty() and app.profile.badges.has("close_enough"), "partial handoff clears hands and records its real achievement")
	app.model.new_run(2043)
	app.model.start_shift()
	app.model.package_type = "bag"
	app.held_tool = "none"
	app._show_play()
	app._sync_world()
	var stock: int = app.model.supply
	app._on_air_mail_caught(48151)
	check(app.model.package_count == 1 and app.model.supply == stock - 1 and app.profile.badges.has("air_mail"), "air-mail callback transfers one stock donut and records the achievement")
	app._on_air_mail_caught(48151)
	check(app.model.package_count == 1 and app.model.supply == stock - 1, "duplicate air-mail callback cannot duplicate food")
	app.paused = true
	app._on_air_mail_caught(48152)
	check(app.model.package_count == 1 and app.model.supply == stock - 1, "paused air-mail callback leaves stock and package untouched")
	app.paused = false
	app._food_epoch -= 1
	app._on_air_mail_caught(48153)
	check(app.model.package_count == 1 and app.model.supply == stock - 1, "stale physics epoch cannot deliver into the current run")

func _physical_head_chef() -> void:
	app.practice = false
	app.model.new_run(2051)
	app.model.start_shift()
	app.run_id = "physical-head-chef"
	app.held_tool = "none"
	app._show_play()
	app._sync_world()
	await _settle_actions()
	app._act("bag")
	await _settle_actions()
	app._act("scoop")
	await _settle_actions()
	app._act("supply")
	await _settle_actions()
	var physical_food: Array = app.world._held_scoop_donuts.duplicate()
	var customer_id: int = app.model.orders[0].id
	app._act("customer")
	check(app.model.scoop_count == 2 and app.model.waste_count == 1 and bool(app.model.orders[0].get("hat", false)), "loaded-scoop customer action spends one real donut and tags the same customer")
	check(app.world._action == "hat_toss" and app.world._held_scoop_donuts.size() == 2 and not app.profile.badges.has("head_chef"), "hat toss starts physical motion without granting the badge before service")
	await _settle_actions()
	var person: Node3D = app.world._people[customer_id]
	var hat: Node3D = person.get_meta("donut_hat") if person.has_meta("donut_hat") else null
	check(is_instance_valid(hat) and hat.name == "PlayerDonutHat" and physical_food.has(hat), "the original scooped donut lands on the customer's actual portrait")
	app._act("customer")
	check(app.model.scoop_count == 2 and app.model.waste_count == 1, "repeating the hat action cannot spend another donut on the same customer")
	for action in ["bag", "package", "supply", "package", "supply", "package", "cinnamon", "package", "customer"]:
		app._act(action)
		await _settle_actions()
	check(app.model.served == 1 and app.profile.badges.has("head_chef") and app.model.unlocked_achievements.has("head_chef"), "correctly serving the physically hatted customer grants Head Chef through the controller")
	check(app.model.supply + app.model.scoop_count + app.model.package_count + app.model.waste_count + 6 == 18, "hat and service preserve stock conservation including wasted and sold donuts")

func _click(node: Node, caption: String) -> void:
	var button: Button = _find_button(node, caption)
	check(button != null and not button.disabled, "visible enabled UI action: " + caption)
	if button == null or button.disabled: return
	button.pressed.emit()
	await process_frame

func _settle_actions() -> void:
	for tick in range(180):
		app.world._process(1.0 / 60.0)
		app._drain_action_queue()
		if not app.world.is_action_busy() and app._queued_action.is_empty(): break
	await process_frame

func _find_button(node: Node, caption: String) -> Button:
	if node == null: return null
	if node is Button and node.text == caption and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found: Button = _find_button(child, caption)
		if found != null: return found
	return null

func _has_text(node: Node, value: String) -> bool:
	if node == null: return false
	if (node is Label or node is RichTextLabel) and node.text == value: return true
	for child in node.get_children():
		if _has_text(child, value): return true
	return false

func _card(node: Node, title: String) -> Node:
	if node == null: return null
	if node is Label and node.text == title: return node.get_parent()
	for child in node.get_children():
		var found: Node = _card(child, title)
		if found != null: return found
	return null

func _market_node(node: Node) -> Control:
	if node == null: return null
	if node is Market: return node
	for child in node.get_children():
		var found: Control = _market_node(child)
		if found != null: return found
	return null

func _check_buttons_inside(node: Node, context: String) -> void:
	var buttons: Array = []
	_collect_buttons(node, buttons)
	var canvas = Rect2(Vector2.ZERO, Vector2(1280, 800))
	var inside = not buttons.is_empty()
	var separate = true
	for index in range(buttons.size()):
		var rectangle: Rect2 = buttons[index].get_global_rect()
		inside = inside and canvas.encloses(rectangle)
		for previous in range(index): separate = separate and not rectangle.intersects(buttons[previous].get_global_rect())
	check(inside and separate, context + " keeps every touch button within the canvas without overlap")

func _check_market_text(market: Control, context: String) -> void:
	check(market != null, context + " provides a real catalogue")
	if market == null: return
	for card in market.get_children():
		if not card is Panel: continue
		var text_regions: Array = []
		var buttons: Array = []
		_collect_buttons(card, buttons)
		for child in card.get_children():
			if not child is Label: continue
			var rect: Rect2 = child.get_rect()
			check(Rect2(Vector2.ZERO, card.size).encloses(rect), context + " text stays inside its card: " + str(child.text))
			check(child.clip_text and child.autowrap_mode != TextServer.AUTOWRAP_OFF, context + " labels wrap and clip before they can expand beyond their card")
			check(child.get_line_count() <= child.get_visible_line_count(), context + " shows the full item text: " + str(child.text))
			for previous in text_regions:
				check(not rect.intersects(previous), context + " item name and description never overlap")
			for button in buttons:
				check(not rect.intersects(button.get_rect()), context + " item text never overlaps purchase or preview controls")
			text_regions.append(rect)

func _collect_buttons(node: Node, result: Array) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Button: result.append(node)
	for child in node.get_children(): _collect_buttons(child, result)
