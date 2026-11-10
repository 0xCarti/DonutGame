extends SceneTree
## Screen-level regression checks. Save writes are suppressed, including packaging runs.
const Content = preload("res://scripts/circuit_content.gd")
const Presenter = preload("res://scripts/circuit_presenter.gd")

class DemoUI extends "res://scripts/circuit_main.gd":
	func _load_game() -> void: pass
	func _save_game() -> bool: return true

var app: DemoUI
var failures: Array[String] = []
var checks = 0
var capture_dir = ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(480, 960)
	root.content_scale_size = Vector2i(480, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	app = DemoUI.new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.test_mode = true
	app.settings.motion = false
	await _settle()
	_check(not app.has_run, "First launch starts at company creation")
	await _capture("01-welcome")
	app._start_company("Golden Hour", false)
	await _settle()
	_test_visual_asset_catalog()
	await _test_visual_detail_views()
	await _test_compact_event_views()
	await _test_effect_feedback_flow()
	_check(app.has_run and app.model.state.phase == "planning", "Company starts in planning")
	_check(app.find_child("PrimaryAction", true, false) != null, "Primary action is available")
	await _capture("02-journal")
	for id in ["circuit", "crew", "menu", "garage", "company"]:
		app._navigate(id)
		await _settle()
		_check(app.tab == id, "Navigation reaches " + id)
		await _capture("03-" + id)
	app._confirm_booking("willowbank")
	await _settle()
	_check(is_instance_valid(app.modal), "Booking offers confirmation with costs")
	await _capture("04-booking")
	app._act("book", {"id": "willowbank"})
	await _settle()
	if app.model.state.phase == "event":
		await _capture("05-travel")
		_resolve_event()
		await _settle()
	_check(app.model.state.phase == "planning", "Travel resolves to preparation")
	app._navigate("journal")
	await _settle()
	app._show_minigame()
	await _settle()
	_check(app._minigame_playing, "Optional batch game starts")
	await _capture("06-minigame")
	var batch = app._batch_game
	batch.set_process(false)
	for stage in range(3):
		batch._phase = PI / 2 if stage == 1 else 0.0
		app._stop_minigame()
		batch._process(batch.RESOLVE_SECONDS + 0.01)
	batch._process(batch.FINISH_SECONDS + 0.01)
	await _settle()
	_check(app.model.state.minigame_day == app.model.state.day, "Batch bonus committed once")
	_check(is_equal_approx(float(app.model.state.minigame_boost), 0.2), "Three perfect stages award the exact 20 percent appeal bonus")
	await _capture("06b-batch-reward")
	app._close_modal()
	app._primary()
	await _settle()
	if app.model.state.phase == "event":
		await _capture("07-decision")
		_resolve_event()
		await _settle()
	_check(app.model.state.phase == "report", "Trading reaches daily report")
	_check(app.find_child("DismissReport", true, false) != null, "Report has continuation")
	await _capture("08-report")
	await _test_report_disclosure()
	app._act("dismiss_report")
	await _settle()
	_check(app.model.state.phase == "planning", "Closing receipt returns to preparation")
	app._show_settings()
	await _settle()
	await _capture("09-settings")
	app._close_modal()
	app.model.state.phase = "season_end"
	app._render()
	await _settle()
	await _capture("10-season")
	app._reviewing_season = true
	app._render()
	await _settle()
	_check(app.model.state.phase == "season_end", "Journal review preserves completed season")
	_check(not is_instance_valid(app.modal), "Completed journal can be read")
	app._primary()
	await _settle()
	_check(is_instance_valid(app.modal), "Season summary reopens")
	app._record_season()
	var recorded: int = app.records.size()
	var saved: Dictionary = app.model.to_save()
	app.model.from_save(saved)
	app._rng_seed = 999999
	app._record_season()
	_check(app.records.size() == recorded, "Season history key survives app reload")
	app._act("next_season")
	await _settle()
	_check(app.model.state.season == 2, "Continue carries company to second season")
	for dimensions in [Vector2i(390,844), Vector2i(600,960), Vector2i(960,600)]:
		root.size = dimensions
		await _settle()
		app._navigate("menu")
		await _settle()
		await _capture("11-size-%dx%d" % [dimensions.x, dimensions.y])
	app.queue_free()
	await process_frame
	for failure in failures: print("FAIL: " + failure)
	print("CIRCUIT_UI_CHECKS %d passed / %d" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _test_visual_asset_catalog() -> void:
	var keys: Array[String] = []
	for entry: Dictionary in Content.VENUES: keys.append("venues/" + str(entry.id))
	for entry: Dictionary in Content.STAFF: keys.append("crew/" + str(entry.id))
	for entry: Dictionary in Content.RECIPES: keys.append("recipes/" + str(entry.id))
	for catalog: Array in [Content.TRUCKS, Content.FRYERS, Content.STANDS]:
		for entry: Dictionary in catalog: keys.append("equipment/" + str(entry.id))
	for key in ["travel", "machine", "customer", "crew", "weather", "opportunity", "story"]:
		keys.append("events/" + key)
	for key in ["arrow", "bag", "calendar", "cash", "check", "clock", "close", "coin", "crew", "fryer", "garage", "heart", "info", "journal", "location", "map", "recipe", "rep", "rest", "settings", "shield", "skill", "stand", "star", "stock", "train", "truck", "upgrade", "weather", "wrench"]:
		keys.append("icons/" + key)
	_check(keys.size() == 85, "Complete illustrated catalog includes 85 resources")
	for key in keys:
		var texture: Texture2D = app._art(key)
		_check(texture != null, "Artwork loads: " + key)
		if texture != null:
			_check(texture.get_width() > 0 and texture.get_height() > 0, "Artwork has image dimensions: " + key)
	for event: Dictionary in Content.EVENTS:
		_check(app._art("events/" + Presenter.event_art_key(event)) != null, "Every event resolves to loaded artwork: " + str(event.id))

func _test_visual_detail_views() -> void:
	var original: Dictionary = app.model.to_save()
	root.size = Vector2i(390, 844)
	await _settle()
	for venue: Dictionary in Content.VENUES:
		app.model.state.relationships[str(venue.town)] = 17
		app._show_venue(str(venue.id))
		await _settle()
		await _test_disclosure("About this fair", str(venue.description), "venue " + str(venue.id))
		_check(_label_is_visible(app.modal, "+17 town goodwill"), "Venue details read the correct town relationship: " + str(venue.id))
		_check_widths(app.modal, "venue details " + str(venue.id))
	for person: Dictionary in Content.STAFF:
		app._show_staff(str(person.id))
		await _settle()
		var story = _find_label(app.modal, str(person.description))
		_check(story != null and not story.is_visible_in_tree(), "Staff story is tucked behind a tap: " + str(person.id))
		_check(_label_is_visible(app.modal, "Skill") and _label_is_visible(app.modal, "Kindness"), "Staff uses labeled visual stat cards")
		if person.id == "bea":
			await _click_button(_find_button_prefix(app.modal, "Their story"))
			_check(story.is_visible_in_tree(), "Tapping Their story reveals the full biography")
			await _click_button(_find_button_prefix(app.modal, "Their story"))
		_check(_find_button_prefix(app.modal, "Hire") != null, "Candidate details include hiring action: " + str(person.id))
		_check_widths(app.modal, "staff details " + str(person.id))
		if person.id == "bea": await _capture("12-staff-details")
	app._close_modal()
	var hired: Dictionary = app.model.act("hire", {"id": "bea"})
	_check(bool(hired.ok), "Detail test hires a crew member")
	app._show_staff("bea")
	await _settle()
	_check(_find_button_prefix(app.modal, "Train") != null and _find_button_prefix(app.modal, "Paid day off") != null, "Employed staff details expose training and rest")
	_check(_find_button_prefix(app.modal, "Hire") == null, "Employed staff cannot be hired twice from details")
	await _capture("13-employed-details")
	for recipe: Dictionary in Content.RECIPES:
		app._show_recipe(str(recipe.id))
		await _settle()
		await _test_disclosure("The recipe story", str(recipe.description), "recipe " + str(recipe.id))
		var unlocked: bool = str(recipe.id) in app.model.state.unlocked_recipes
		_check((_find_button_prefix(app.modal, "Serve this recipe") != null) == unlocked, "Recipe details respect unlock: " + str(recipe.id))
		_check_widths(app.modal, "recipe details " + str(recipe.id))
		if recipe.id == "apple": await _capture("14-recipe-details")
	for id in ["truck", "fryer", "stand"]:
		var catalog: Array = Content.TRUCKS if id == "truck" else Content.FRYERS if id == "fryer" else Content.STANDS
		for tier in range(catalog.size()):
			app.model.state[id + "_tier"] = tier
			app._show_gear(id)
			await _settle()
			if tier + 1 < catalog.size():
				await _test_disclosure("Upgrade details", str(catalog[tier].description) + "\n\n" + str(catalog[tier + 1].description), "upgrade " + id + str(tier))
				var units: String = "stored bags" if id == "truck" else "crew places" if id == "stand" else "bags / day"
				_check(_label_is_visible(app.modal, "%d to %d %s" % [catalog[tier].capacity, catalog[tier + 1].capacity, units]), "Upgrade shows both current and next capacity")
				_check(_find_button_prefix(app.modal, "Buy upgrade") != null, "Next equipment can be purchased")
			else:
				await _test_disclosure("Equipment story", str(catalog[tier].description), "maxed " + id)
				_check(_label_is_visible(app.modal, "Fully upgraded") and _find_button_prefix(app.modal, "Buy upgrade") == null, "Maximum tier cannot buy another upgrade")
			_check_widths(app.modal, "equipment details " + id + str(tier))
			if id == "truck" and tier == 0: await _capture("15-equipment-details")
	app._close_modal()
	_check(app.model.from_save(original), "Detail view tests restore original company")
	app._show_staff("nell")
	await _settle()
	await _click_button(_find_button_prefix(app.modal, "Hire"))
	_check(app.model.state.staff.size() == 1 and app.model.state.staff[0].id == "nell", "Candidate detail button hires the pictured person")
	app._show_recipe("cinnamon")
	await _settle()
	await _click_button(_find_button_prefix(app.modal, "Serve this recipe"))
	_check(app.model.state.recipe == "cinnamon", "Recipe detail button selects the pictured recipe")
	app._show_gear("truck")
	await _settle()
	var cash_before: float = app.model.state.cash
	await _click_button(_find_button_prefix(app.modal, "Buy upgrade"))
	_check(app.model.state.truck_tier == 0 and app.model.state.cash == cash_before, "Equipment detail button opens confirmation before spending")
	_check(_find_button_prefix(app.modal, "CONFIRM") != null, "Equipment confirmation provides purchase action")
	await _capture("15b-equipment-confirm")
	await _click_button(_find_button_prefix(app.modal, "CONFIRM"))
	_check(app.model.state.truck_tier == 1 and app.model.state.cash == cash_before - float(Content.TRUCKS[1].cost), "Confirmed equipment action buys exactly the displayed upgrade")
	app._close_modal()
	_check(app.model.from_save(original), "Pointer-action tests restore original company")
	root.size = Vector2i(480, 960)
	app._render()
	await _settle()

func _test_compact_event_views() -> void:
	var original: Dictionary = app.model.to_save()
	root.size = Vector2i(390, 844)
	await _settle()
	var longest: Dictionary = {}
	var longest_score := -1
	for event: Dictionary in Content.EVENTS:
		app.model.state.phase = "event"
		app.model.state.event = event.duplicate(true)
		app.model.state.event.context = "travel" if "travel" in event.tags else "trading"
		app._show_event()
		await _settle()
		_check(_label_is_visible(app.modal, Presenter.event_teaser(event)), "Event opens with concise teaser: " + str(event.id))
		var full_text := str(event.body)
		var chip_count := 0
		for index in range(event.choices.size()):
			var choice: Dictionary = event.choices[index]
			full_text += "\n\n" + str(choice.label) + "\n" + str(choice.detail)
			var button: Button = app.modal.find_child("EventChoice_" + str(index), true, false)
			_check(button != null, "Event choice remains actionable: " + str(event.id))
			if button == null: continue
			var expected: Array[Dictionary] = Presenter.choice_effects(choice, str(app.model.state.event.context), app.model.state)
			chip_count += expected.size()
			for chip in expected:
				_check(_label_is_visible(button.get_parent(), str(chip.value)), "Visible effect value: %s / %s" % [str(event.id), str(chip.value)])
				_check(_label_is_visible(button.get_parent(), str(chip.title)), "Visible effect meaning: " + str(event.id))
				_check(_label_is_visible(button.get_parent(), str(chip.duration)), "Visible effect duration: " + str(event.id))
				if str(chip.source) == "risk":
					_check(_label_is_visible(button.get_parent(), "%d%% CHANCE" % roundi(float(chip.chance) * 100)), "Visible risk probability: " + str(event.id))
		var detail: Label = _find_label(app.modal, full_text)
		_check(detail != null and not detail.is_visible_in_tree(), "Full story is initially collapsed: " + str(event.id))
		_check(_find_button_prefix(app.modal, "Story & details") != null, "Every event offers full story on demand")
		_check_widths(app.modal, "compact event " + str(event.id))
		var score := chip_count * 100 + str(event.title).length()
		if score > longest_score:
			longest_score = score
			longest = event.duplicate(true)
		if event.id == "roadworks":
			var risk_choice: Button = app.modal.find_child("EventChoice_2", true, false)
			var risk_panel: Node = risk_choice.get_parent()
			var effect_button: Button = risk_panel.find_child("EffectExplain", true, false)
			_check(effect_button != null, "Every effect can explain itself by tap, without hover")
			if effect_button != null:
				var saved_modal = app.modal
				var instance: Dictionary = app.model.state.event.duplicate(true)
				var effect_detail: Label = _find_first_hidden_label(effect_button.get_parent().get_parent())
				_check(effect_detail != null and not effect_detail.is_visible_in_tree(), "Effect explanation is initially tucked away")
				await _click_button(effect_button)
				_check(app.modal == saved_modal and app.model.state.event == instance, "Explaining a consequence preserves the pending event and its choices")
				_check(effect_detail != null and effect_detail.is_visible_in_tree(), "Tap reveals effect meaning and limits on mobile")
				_check(_label_is_visible(risk_panel, "35% CHANCE") and _label_is_visible(risk_panel, "-20%") and _label_is_visible(risk_panel, "-3 points"), "Expanding a risk explanation retains its probability and both consequences")
				var penalty_label: Label = _find_label(risk_panel, "-20%")
				_check(penalty_label != null and penalty_label.get_theme_color("font_color") == app.RED, "Risk penalty remains visibly negative")
				_check_widths(app.modal, "negative risk explanation")
				if effect_detail != null:
					var scroll_parent: Node = effect_detail.get_parent()
					while scroll_parent != null:
						if scroll_parent is ScrollContainer: scroll_parent.ensure_control_visible(effect_detail)
						scroll_parent = scroll_parent.get_parent()
					await _settle()
				await _capture("16b-negative-risk-help")
				await _click_button(effect_button)
				_check(effect_detail != null and not effect_detail.is_visible_in_tree(), "Second tap hides effect explanation")
			var disclosure: Button = _find_button_prefix(app.modal, "Story & details")
			await _click_button(disclosure)
			_check(detail.is_visible_in_tree(), "Touch reveals complete event story and all choice details")
			await _capture("16-event-expanded")
			await _click_button(disclosure)
			_check(not detail.is_visible_in_tree(), "Second touch collapses event details")
	app.model.state.event = longest
	app.model.state.event.context = "travel" if "travel" in longest.tags else "trading"
	app._show_event()
	await _settle()
	await _capture("17-longest-event-" + str(longest.id))
	app._close_modal()
	_check(app.model.from_save(original), "Event preview tests restore original company")
	root.size = Vector2i(480, 960)
	app._render()
	await _settle()

func _test_report_disclosure() -> void:
	var ingredients: Label = _find_label(app.modal, "Ingredients")
	var disclosure: Button = app.modal.find_child("ReportDetails", true, false)
	_check(ingredients != null and not ingredients.is_visible_in_tree(), "Detailed receipt starts collapsed")
	_check(disclosure != null, "Report offers full receipt on demand")
	_check(_label_is_visible(app.modal, "Sales") and _label_is_visible(app.modal, "Cash change"), "Compact report retains sales and cash totals")
	if disclosure == null or ingredients == null: return
	await _click_button(disclosure)
	_check(ingredients.is_visible_in_tree(), "Touch expands full receipt")
	for summary in app.model.state.last_report.get("summary", []):
		_check(_label_is_visible(app.modal, str(summary)), "Full receipt preserves accounting and event explanation")
	await _capture("18-report-expanded")
	await _click_button(disclosure)
	_check(not ingredients.is_visible_in_tree(), "Second touch hides detailed receipt")

func _test_disclosure(prefix: String, text: String, context: String) -> void:
	var story: Label = _find_label(app.modal, text)
	var button := _find_button_prefix(app.modal, prefix)
	_check(story != null and not story.is_visible_in_tree(), context + ": longer description starts collapsed")
	_check(button != null, context + ": detail remains accessible by tap")
	if story == null or button == null: return
	await _click_button(button)
	_check(story.is_visible_in_tree(), context + ": tapping reveals complete description")
	_check_widths(app.modal, context + ": expanded details")
	await _click_button(button)
	_check(not story.is_visible_in_tree(), context + ": description can collapse again")

func _test_effect_feedback_flow() -> void:
	var original: Dictionary = app.model.to_save()
	root.size = Vector2i(390, 844)
	app.model.act("book", {"id": "willowbank"})
	app.model.state.event = {"id": "ui_travel", "title": "A helpful mechanic", "body": "Take time for a careful repair.", "context": "travel", "instance_id": "ui:travel", "choices": [{"label": "Repair before the fair", "detail": "A careful repair.", "result": "Ready to trade tomorrow.", "effects": {"truck": 4, "delay": 0.1, "quality": 0.1}}]}
	app._show_event()
	await _settle()
	await _click_button(app.modal.find_child("EventChoice_0", true, false))
	_check(app.model.state.phase == "planning", "Travel effect fixture returns to planning")
	_check(_label_is_visible(app.modal, "Repair before the fair"), "Travel decision immediately shows its actual outcome")
	_check(_label_is_visible(app.modal, "Next trading day"), "Travel outcome labels the pending effect duration")
	app._close_modal()
	app._navigate("journal")
	await _settle()
	_check(_label_is_visible(app.content, "Production capacity") and _label_is_visible(app.content, "-10%"), "Pending travel debuff remains visible in preparation")
	_check(_label_is_visible(app.content, "Batch quality") and _label_is_visible(app.content, "+4% appeal"), "Pending quality bonus shows its actual appeal contribution")
	await _click_button(_find_button_prefix(app.content, "Last decision"))
	_check(_label_is_visible(app.modal, "Repair before the fair") and _label_is_visible(app.modal, "Truck condition"), "Last decision reopens the complete actual outcome")
	app._close_modal()
	app.model.act("minigame", {"score": 0.75})
	app._show_batch_result(0.75)
	await _settle()
	_check(_label_is_visible(app.modal, "Practice batch") and _label_is_visible(app.modal, "+15% appeal"), "Practice reward shows its exact earned bonus")
	_check(not _label_is_visible(app.modal, "Production capacity") and not _label_is_visible(app.modal, "Batch quality"), "Practice result does not claim unrelated travel effects as rewards")
	_check(_label_is_visible(app.modal, "75%"), "Practice reward displays the saved score")
	await _capture("19-practice-effect-isolation")
	app._close_modal()
	app.model.act("advance")
	app.model.state.event = {"id": "ui_trade", "title": "A patient queue", "body": "A small kindness makes an impression.", "context": "trading", "instance_id": "ui:trading", "choices": [{"label": "Thank the waiting customers", "detail": "Customers appreciate it.", "result": "A cheerful closing time.", "effects": {"rep": 0.25}}]}
	app._show_event()
	await _settle()
	await _click_button(app.modal.find_child("EventChoice_0", true, false))
	_check(app.model.state.phase == "report", "Trading fixture reaches the report")
	for title in ["A helpful mechanic", "Repair before the fair", "A patient queue", "Thank the waiting customers"]:
		_check(_label_is_visible(app.modal, title), "Report identifies the source of its changes: " + title)
	_check(_label_is_visible(app.modal, "Used on day 2"), "Consumed temporary effects are clearly marked in the report")
	var rep_delta := float(app.model.state.last_report.rep_change)
	_check(not is_equal_approx(rep_delta, roundf(rep_delta)), "Reputation fixture exercises a fractional change")
	_check(_label_is_visible(app.modal, "%+.2f rep" % rep_delta), "Report preserves the exact signed fractional reputation change")
	_check(Presenter.active_effects(app.model.state).is_empty(), "Reported bonuses are no longer active")
	await _capture("20-grouped-outcomes")
	app._close_modal()
	_check(app.model.from_save(original), "Feedback regression restores the original company")
	root.size = Vector2i(480, 960)
	app._render()
	await _settle()

func _find_first_hidden_label(node: Node) -> Label:
	if node is Label and not node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found: Label = _find_first_hidden_label(child)
		if found != null: return found
	return null

func _click_button(button: Button) -> void:
	_check(button != null, "Disclosure button exists for pointer input")
	if button == null: return
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _settle()
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.pressed = down
		root.push_input(click, true)
	await _settle()

func _find_label(node: Node, value: String) -> Label:
	if node is Label and node.text == value: return node
	for child in node.get_children():
		var found: Label = _find_label(child, value)
		if found != null: return found
	return null

func _label_is_visible(node: Node, value: String) -> bool:
	var label: Label = _find_label(node, value)
	return label != null and label.is_visible_in_tree()

func _find_button_prefix(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found: Button = _find_button_prefix(child, prefix)
		if found != null: return found
	return null

func _resolve_event() -> void:
	var choices: Array = app.model.state.event.choices
	for index in range(choices.size()):
		var effects: Dictionary = choices[index].get("effects", {})
		if float(effects.get("cash", 0)) >= 0 and int(effects.get("stock", 0)) >= 0:
			app._act("decide", {"choice": index})
			return
	app._act("decide", {"choice": choices.size() - 1})

func _settle() -> void:
	for frame in range(8): await process_frame

func _capture(label: String) -> void:
	_check_widths(app, label)
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _check_widths(node: Node, label: String) -> void:
	if node is CheckButton and node.is_visible_in_tree():
		_check(node.get_theme_color("font_pressed_color") == app.INK, label + ": selected toggle has readable text")
		_check(node.get_theme_color("font_hover_pressed_color") == app.INK, label + ": selected hover toggle has readable text")
	if (node is Label or node is Button) and node.is_visible_in_tree():
		var missing: Array[String] = []
		for index in range(node.text.length()):
			var codepoint: int = node.text.unicode_at(index)
			if codepoint > 127 and not app.FONT.has_char(codepoint): missing.append("U+%04X" % codepoint)
		_check(missing.is_empty(), label + ": bundled font covers " + str(missing))
	if node is Button and node.is_visible_in_tree():
		_check(node.size.y >= 43.0, label + ": touch target " + node.text)
	if node is Control and node.is_visible_in_tree() and not node is VScrollBar:
		var bounds: Rect2 = node.get_global_rect()
		var viewport: Vector2 = app.get_viewport_rect().size
		if bounds.size.x > 0 and not node == app.toast:
			_check(bounds.position.x >= -1.0 and bounds.end.x <= viewport.x + 2.0, label + ": fits width " + str(node.get_path()))
	for child in node.get_children(): _check_widths(child, label)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
