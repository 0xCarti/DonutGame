extends SceneTree
## Read-only view contracts, touch geometry, motion settings, and optional native QA.
const WorldView = preload("res://scripts/circuit_world_view.gd")
const RouteView = preload("res://scripts/circuit_route_view.gd")
const SalesView = preload("res://scripts/circuit_sales_view.gd")
const Content = preload("res://scripts/circuit_content.gd")
const FONT = preload("res://assets/fonts/Fredoka-Medium.ttf")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := WorldView.new()
	var route := RouteView.new()
	var sales := SalesView.new()
	root.add_child(world)
	root.add_child(route)
	root.add_child(sales)
	var state: Dictionary = _sample_state(0)
	var saved_input: Dictionary = state.duplicate(true)
	world.configure(state, true)
	check(world.queue_size() > 0, "booked stand has a decorative customer queue")
	check(world.scene_description().contains("Used Van"), "the world describes the actual truck tier")
	check(world.scene_description().contains("Golden Original"), "the world describes the chosen recipe")
	check(not world.is_processing(), "reduced-motion world is still")
	state.booked_id = ""
	check(world.queue_size() > 0, "world owns a snapshot rather than the live state")
	world.configure(state, true)
	check(world.queue_size() == 0, "unbooked company has no customer queue")
	check(state.staff.is_empty(), "world does not hire or alter crew")
	state = saved_input.duplicate(true)
	world.configure(state, false)
	check(world.is_processing(), "visible world animates when motion is allowed")
	world.hide()
	check(not world.is_processing(), "hidden world does not spend time animating")
	world.show()
	world.configure(state, true)
	var second_world := WorldView.new()
	root.add_child(second_world)
	second_world.configure(state, true)
	check(world.get("_clouds") == second_world.get("_clouds"), "decorative scenery is deterministic")
	second_world.free()
	for tier in range(4):
		state.truck_tier = tier
		state.fryer_tier = tier
		state.stand_tier = tier
		state.staff = Content.STAFF.slice(0, mini(tier + 1, 5)).duplicate(true)
		state.recipe = Content.RECIPES[tier * 2].id
		state.weather = ["Clear", "Sunny", "Showers", "Windy"][tier]
		state.truck = 30 if tier == 0 else 90
		state.fryer = 35 if tier == 0 else 95
		state.circuit.decorations = ["bunting", "route_sign", "flower_box", "golden_lamp", "review_board", "crew_frame", "golden_rosette", "striped_awning"].slice(0, tier * 2 + 2)
		var before: Dictionary = state.duplicate(true)
		world.configure(state, true)
		world.size = Vector2(300 + tier * 60, 236)
		await process_frame
		check(world.scene_description().contains(String(Content.TRUCKS[tier].name)), "truck tier %d description matches" % tier)
		check(world.scene_description().contains(String(Content.FRYERS[tier].name)), "fryer tier %d description matches" % tier)
		check(world.scene_description().contains(String(Content.STANDS[tier].name)), "stand tier %d description matches" % tier)
		check(state == before, "world tier %d draw/configure leaves state untouched" % tier)
		check(world.queue_size() <= 7, "visual queue is bounded")

	state = _sample_state(0)
	state.completed = ["brass_bell"]
	state.circuit.itinerary = ["juniper", "lantern_quay"]
	var offers: Array = []
	for venue: Dictionary in Content.VENUES:
		var offer: Dictionary = venue.duplicate(true)
		offer.can_book = float(state.rep) >= float(venue.min_rep)
		offer.reason = "Needs more reputation" if not offer.can_book else ""
		offers.append(offer)
	route.configure(state, offers, state.circuit.itinerary, true)
	check(route.venue_buttons.size() == 12, "all twelve named stops are represented")
	check(route.venue_status("willowbank") == "current", "booked stop is current")
	check(route.venue_status("brass_bell") == "visited", "completed stop is visited")
	check(route.venue_status("juniper") == "planned", "planned stop is marked")
	check(route.venue_status("solstice") == "locked", "reputation gate is visible")
	check(route.venue_status("copperfield") == "locked", "minimum reputation is used")
	check(not route.is_processing(), "reduced-motion route is still")
	var selected: Array[String] = []
	route.venue_selected.connect(func(id: String): selected.append(id))
	for width: int in [300, 340, 440, 720]:
		route.size = Vector2(width, 370)
		await process_frame
		for id: String in route.venue_buttons:
			var button: Button = route.venue_buttons[id]
			check(button.size.x >= 44 and button.size.y >= 44, "%dpx route %s has a touch target" % [width, id])
			check(button.position.x >= 0 and button.position.y >= 0 and button.get_rect().end.x <= width + 0.1 and button.get_rect().end.y <= route.size.y, "%dpx route %s remains in bounds" % [width, id])
			check(button.focus_mode == Control.FOCUS_ALL, "%s supports keyboard focus" % id)
			check(button.tooltip_text.contains(String(Content.find(Content.VENUES, id).name)), "%s preserves full venue name" % id)
	for id: String in route.venue_buttons:
		route.venue_buttons[id].pressed.emit()
	check(selected.size() == 12 and selected[0] == "willowbank" and selected[-1] == "grand_circuit", "each route button emits the correct venue id, including locked stops")
	check(state.booked_id == "willowbank" and state.completed == ["brass_bell"], "view clicks never book or change route state")
	state.completed.clear()
	check(route.venue_status("brass_bell") == "visited", "route uses a deep copied snapshot")

	for report: Dictionary in [
		{"sold": 0, "revenue": 0.0}, {"sold": 93, "revenue": 558.0},
		{"sold": 212, "revenue": 1430.25}, {"sold": 0, "revenue": 20.0}
	]:
		var unchanged: Dictionary = report.duplicate(true)
		sales.configure(report, true)
		sales.size = Vector2(300, 158)
		await process_frame
		var totals: Dictionary = sales.displayed_totals()
		check(int(totals.sold) == int(report.sold), "reduced-motion sales shows actual sold total immediately")
		check(is_equal_approx(float(totals.revenue), float(report.revenue)), "reduced-motion sales shows actual revenue to cents")
		check(not sales.is_processing(), "reduced-motion sales has no timer")
		check(report == unchanged, "sales does not change the closing report")
	var report: Dictionary = {"sold": 127, "revenue": 876.45}
	sales.configure(report, false)
	check(sales.is_processing(), "ordinary sales animation starts")
	check(int(sales.displayed_totals().sold) == 0, "animated count starts at zero")
	for step in range(25): sales._process(0.1)
	check(sales.displayed_totals().complete, "sales animation has a bounded completion time")
	check(int(sales.displayed_totals().sold) == 127 and is_equal_approx(float(sales.displayed_totals().revenue), 876.45), "animated count finishes at exact supplied totals")
	check(not sales.is_processing(), "completed sales animation stops processing")
	check(report.sold == 127 and report.revenue == 876.45, "animation never mutates the actual report")
	world.free()
	route.free()
	sales.free()

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var capture_index: int = args.find("--capture")
	if capture_index >= 0 and capture_index + 1 < args.size():
		await _capture(args[capture_index + 1])
	if failures.is_empty():
		print("WORLD VIEWS PASS: %d checks." % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("WORLD VIEWS FAIL: %d of %d checks failed." % [failures.size(), checks])
		quit(1)

func _sample_state(tier: int) -> Dictionary:
	var staff: Array = []
	if tier > 0: staff = Content.STAFF.slice(0, tier + 2).duplicate(true)
	return {
		"company": "Golden Hour", "rep": 24 + tier * 22, "booked_id": ["willowbank", "orchard_days", "grand_circuit"][mini(tier, 2)],
		"truck_tier": mini(tier + int(tier > 1), 3), "fryer_tier": mini(tier * 2, 3), "stand_tier": mini(tier + int(tier > 1), 3),
		"truck": 75 if tier != 1 else 32, "fryer": 80 if tier != 1 else 35, "staff": staff,
		"recipe": ["classic", "apple", "rainbow"][mini(tier, 2)], "weather": ["Sunny", "Showers", "Windy"][mini(tier, 2)],
		"completed": [] if tier == 0 else ["willowbank", "brass_bell", "juniper", "lantern_quay"],
		"last_report": {"sold": [42, 130, 320][mini(tier, 2)]},
		"circuit": {
			"decorations": [] if tier == 0 else ["bunting", "route_sign", "flower_box", "golden_lamp", "review_board", "crew_frame", "golden_rosette", "striped_awning"].slice(0, 4 if tier == 1 else 8),
			"itinerary": ["juniper", "lantern_quay"] if tier == 0 else ["cedar_sound", "moonwheel", "saltwind"]
		}
	}

func _capture(path: String) -> void:
	root.size = Vector2i(964, 900)
	root.content_scale_size = Vector2i(964, 900)
	RenderingServer.set_default_clear_color(Color("f2e6ce"))
	var surface := Control.new()
	surface.size = Vector2(964, 900)
	root.add_child(surface)
	for index in range(3):
		var column := VBoxContainer.new()
		column.position = Vector2(16 + index * 316, 15)
		column.size = Vector2(300, 875)
		column.add_theme_constant_override("separation", 10)
		surface.add_child(column)
		var title := Label.new()
		title.text = ["FIRST PITCH", "GROWING IN THE RAIN", "THE LITTLE FLEET"][index]
		title.add_theme_font_override("font", FONT)
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color("173c3f"))
		column.add_child(title)
		var state: Dictionary = _sample_state(index)
		if index == 2:
			state.rep = 92
			state.staff = Content.STAFF.slice(0, 5).duplicate(true)
		var world := WorldView.new()
		world.configure(state, true)
		column.add_child(world)
		var route := RouteView.new()
		route.configure(state, [], state.circuit.itinerary, true)
		column.add_child(route)
		var sales := SalesView.new()
		sales.configure({"sold": [42, 130, 320][index], "revenue": [252.0, 1040.0, 2880.0][index]}, true)
		column.add_child(sales)
		var note := Label.new()
		note.text = "300 px component width · reduced motion"
		note.add_theme_font_override("font", FONT)
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color("58766b"))
		column.add_child(note)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.get_width() == 964, "native capture has its intended viewport width")
	var error: Error = image.save_png(path)
	check(error == OK, "native component capture saved")
	print("WORLD VIEWS CAPTURE: " + path)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
