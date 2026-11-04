extends SceneTree
## Real controller/model/world integration for optional fairground slapstick.
## Manual frame advancement keeps this headless suite deterministic and fast.
const Controller = preload("res://scripts/stand_main.gd")
var app
var checks: int = 0
var failures: int = 0
var sounds: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func advance(seconds: float) -> void:
	for frame in range(ceili(seconds * 60.0)):
		app.world._process(1.0 / 60.0)
		app._process(1.0 / 60.0)

func settle() -> void:
	for frame in range(240):
		advance(1.0 / 60.0)
		if not app.world.is_action_busy() and app._queued_action.is_empty(): return
	check(false, "Controller hand action finishes without leaving a stuck input lock")

func act(station: String) -> void:
	app._act(station)
	settle()

func reset(seed_value: int = 810) -> void:
	app.model.new_run(seed_value)
	app.model.start_shift()
	app.model.heat_setting = 2
	app.held_tool = "none"
	app.practice = true
	app._show_play()
	app._sync_world()
	advance(0.8)
	sounds.clear()

func _sound(id: String) -> void:
	sounds.append(id)

func _inventory() -> Array:
	return [app.model.supply, app.model.batter, app.model.package_type, app.model.package_count, app.model.package_flavor, app.model.scoop_count, app.model.sales, app.model.served, app.model.waste_count]

func _fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Controller.SAVE_PATH, Controller.SETTINGS_PATH, Controller.LEGACY_SAVE_PATH, Controller.LEGACY_SETTINGS_PATH, "user://career.json", "user://career.json.backup", Controller.SAVE_PATH + ".backup", Controller.SETTINGS_PATH + ".backup"]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var disk_before: Dictionary = _fingerprints()
	app = Controller.new()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false)
	app.world.set_process(false)
	app.audio.set_muted(true)
	app.audio.stop_music()
	app.world.gag_sound.connect(_sound)
	await _test_customer_input()
	_test_fire()
	_test_extinguisher_tool_returns()
	_test_shake()
	_test_bell()
	_test_bell_with_held_items()
	_test_powder()
	_test_hat_and_resets()
	_test_gag_capacity_during_punch()
	check(_fingerprints() == disk_before, "Gag integration tests preserve real career, save and settings bytes")
	for player in app.audio.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	app.world.reset_food(0, 36)
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("STAND GAGS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_customer_input() -> void:
	reset()
	app.model._spawn_order()
	app._sync_world()
	settle()
	await physics_frame
	await physics_frame
	var first_id: int = app.model.orders[0].id
	var second: Dictionary = app.model.orders[1].duplicate(true)
	# The physical customer hitbox and the safe service mat must be distinct.
	var point: Vector2 = app.world.station_screen_position("customer")
	check(app.world.pick_station(point) == "customer", "Physical front-customer ray identifies a customer rather than the service mat")
	var empty_before: Dictionary = app.model.to_save()
	app._act("serve")
	check(app.model.to_save() == empty_before, "Empty-hand service-mat click remains safe and does not punch")
	app.model.choose_package("bag")
	app.model.scoop()
	app.model.dump()
	app._sync_world()
	settle()
	var inventory: Array = _inventory()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	app._unhandled_input(click)
	check(app.model.missed == 1 and app.model.orders.size() == 1 and app.model.orders[0] == second, "One empty-hand customer click immediately removes only that customer")
	check(_inventory() == inventory and app.model.sales == 0.0 and app.model.served == 0, "Punch preserves the prepared order and grants no sale")
	check(app.world._action == "punch" and app.world.is_action_busy(), "Customer removal starts the visible punch action")
	app._act("customer")
	check(app._queued_action.is_empty() and app.model.orders[0].id == second.id, "Busy punch is never buffered onto the next customer")
	settle()
	check(app.model.missed == 1 and app.model.orders[0].id == second.id, "Next customer remains intact after the punch animation finishes")
	check(first_id != app.model.orders[0].id, "Only the originally targeted customer leaves")
	act("scoop")
	var scoop_before: Dictionary = app.model.to_save()
	app._act("customer")
	check(app.model.to_save() == scoop_before and app.held_tool == "scoop", "Customer click while holding a scoop cannot punch or discard the tool")
	app._act("punch")
	check(app.model.to_save() == scoop_before, "Direct punch dispatch also enforces empty hands")
	reset(811)
	act("bag")
	act("scoop")
	for portion in range(2):
		act("supply")
		act("package")
	act("cinnamon")
	act("package")
	app._act("customer")
	check(app.model.served == 1 and app.model.sales > 0.0 and app.model.missed == 0 and app.world._action == "serve", "Customer click with a held finished package routes to service")
	app._act("customer")
	check(app.model.missed == 0 and app._queued_action.is_empty(), "Immediate second click after handing over cannot become a queued empty-hand punch")
	settle()
	app._show_pause()
	var paused_before: Dictionary = app.model.to_save()
	app._act("customer")
	app._act("bell")
	advance(0.5)
	check(app.model.to_save() == paused_before and app._bell_clicks == 0, "Pause blocks customer and bell actions and freezes model time")
	app._close_overlay()

func _test_fire() -> void:
	reset(812)
	app.model.temperature = 220.0
	app.model.heat_setting = 4
	app.model.tick_practice(4.3)
	app._sync_world()
	app._refresh_hud()
	check(app._machine_faults()[0].code == "fire_warning" and app.hud.warning.text == "IS THAT SMOKE?", "Pre-fire danger appears as the primary actionable warning")
	app.model.tick_practice(8.0)
	app.model.jammed = true
	app._process_events()
	app._sync_world()
	app._refresh_hud()
	check(app._machine_faults()[0].code == "fire" and app.hud.warning.text == "FRYER ON FIRE!", "Active fire takes HUD priority over jam and overheat")
	check(app.hud.fault_action.text.contains("Q") and app._machine_short_status() == "ON FIRE!", "Fire HUD gives the extinguisher shortcut and machine status")
	check(app.world._state.fire_active and app.world._state.fire_danger == 1.0, "Controller forwards fire state to the actual 3D world")
	app._show_pause()
	var before: Dictionary = app.model.to_save()
	app._act("extinguish")
	advance(0.5)
	check(app.model.to_save() == before and app.world._state.fire_active, "Pause freezes fire and rejects extinguisher input")
	app._close_overlay()
	var inventory: Array = _inventory()
	app._act("extinguish")
	check(not app.model.fire_active and app.model.fire_recovery > 0 and app.model.foam_time > 0 and _inventory() == inventory, "One extinguisher click clears fire while preserving orders and food")
	check(not app.world._state.fire_active and app.world._state.foam_time > 0 and app.world._action == "extinguish", "Extinguisher action and foam state reach the actual world")
	check(app._machine_faults()[0].code == "fire_recovery", "Recovery replaces the fire alert immediately")
	settle()
	app._show_pause()
	var recovery: float = app.model.fire_recovery
	var foam: float = app.model.foam_time
	advance(0.6)
	check(app.model.fire_recovery == recovery and app.model.foam_time == foam, "Pause also freezes post-fire recovery and foam lifetime")
	app._close_overlay()
	advance(1.5)
	check(app.model.fire_recovery == 0.0 and app.model.foam_time > 0.0, "Normal controller updates finish recovery while foam remains")

func _test_extinguisher_tool_returns() -> void:
	for held_order in [false, true]:
		reset(825 + int(held_order))
		act("bag")
		act("scoop")
		act("supply")
		act("package")
		act("supply")
		if held_order:
			act("package")
			act("cinnamon")
			act("package")
		var food: Array = app.world._prep_donuts.duplicate() if held_order else app.world._held_scoop_donuts.duplicate()
		var package: Node3D = app.world._prep
		app.model.temperature = 220.0
		app.model.heat_setting = 4
		app.model.tick_practice(12.1)
		app._process_events()
		app._sync_world()
		var inventory: Array = _inventory()
		app._act("extinguish")
		check(app.held_tool == "none" and app.world._held_type == "none" and _inventory() == inventory, "Extinguisher frees the hand without consuming the " + ("held coated order" if held_order else "loaded scoop"))
		advance(0.2)
		var returned_prop: Node3D = package if held_order else app.world._held_scoop
		check(app.world._hand_goal(0).node == returned_prop and app.world._hand_goal(1).node == app.world._extinguisher, "Left hand supports the returning item while the right takes the extinguisher")
		settle()
		if held_order:
			check(app.world._held_package == null and app.world._prep == package and package.position.is_equal_approx(app.world._package_anchor), "Extinguishing sets the same held order onto the preparation mat")
			check(app.world._prep_donuts == food and app.model.package_count == 6 and app.model.package_flavor == "cinnamon", "Coated order and original food objects remain ready after extinguishing")
		else:
			check(app.world._held_scoop.global_transform.is_equal_approx(app.world._tool_home), "Extinguishing returns the loaded scoop to its counter rest")
			check(app.world._held_scoop_donuts == food and app.model.scoop_count == 3 and food.all(func(donut): return donut.get_parent() == app.world._held_scoop), "Loaded scoop retains the same three physical donuts while set down")
			act("scoop")
			act("package")
			check(app.model.package_count == 6 and app.model.scoop_count == 0, "Set-down scoop can be picked up and poured normally after the fire")

func _test_shake() -> void:
	reset(813)
	app._act("supply")
	var serial: int = app.world._action_serial
	var first: float = app.world._food.debug_snapshot().shake_strength
	app._act("supply")
	app._act("supply")
	check(app.world._food.debug_snapshot().shake_strength > first and app.world._food.debug_snapshot().rage_shaking, "Rapid empty-hand tray clicks add energy while the first shake is busy")
	check(app.world._action_serial == serial and app._queued_action.is_empty(), "Rapid shake bypass preserves the current hand animation instead of restarting or buffering it")
	app._show_pause()
	var strength: float = app.world._food.debug_snapshot().shake_strength
	app._act("supply")
	check(app.world._food.debug_snapshot().shake_strength == strength, "Pause blocks added tray-shake energy")
	app._close_overlay()
	reset(814)
	act("bag")
	act("scoop")
	app._act("supply")
	app._act("supply")
	check(app.model.scoop_count == 3 and not app.world._food.debug_snapshot().shaking, "Rapid tray clicks with a scoop retain normal scooping and cannot trigger a rage shake")
	settle()

func _test_bell() -> void:
	reset(815)
	act("bell")
	act("bell")
	check(app._bell_reply == 0.0 and not sounds.has("bell_reply"), "Two bell rings do not trigger the neighboring booth's answer")
	app._act("bell")
	check(app._bell_reply > 0 and app._bell_cooldown > 0, "Third quick bell ring schedules a delayed answer")
	app._show_pause()
	var reply: float = app._bell_reply
	advance(1.0)
	check(app._bell_reply == reply and not sounds.has("bell_reply"), "Bell reply waits through pause")
	app._close_overlay()
	advance(1.0)
	check(sounds.count("bell_reply") == 1, "Bell answer fires exactly once after the delay")
	for index in range(3): act("bell")
	advance(1.0)
	check(sounds.count("bell_reply") == 1, "Bell reply cooldown prevents an endless overlapping sound loop")
	reset(816)
	act("bell")
	advance(2.0)
	act("bell")
	check(app._bell_clicks == 1 and app._bell_reply == 0.0, "Separated bell rings do not count as a rapid sequence")

func _test_bell_with_held_items() -> void:
	for held_order in [false, true]:
		reset(826 + int(held_order))
		act("bag")
		act("scoop")
		act("supply")
		if held_order:
			act("package")
			act("supply")
			act("package")
			act("cinnamon")
			act("package")
		var tool: String = app.held_tool
		var prop: Node3D = app.world._held_package if held_order else app.world._held_scoop
		var inventory: Array = _inventory().slice(2)
		app._act("bell")
		advance(0.2)
		check(app.world._hand_goal(0).node == app.world._bell_button and app.world._hand_goal(1).node == prop, "Free left hand rings the bell while right retains the " + tool)
		check(app.world._hands[0].global_position.distance_to(app.world._hand_goal(0).pose.origin) < 0.015 and app.world._hands[1].global_position.distance_to(app.world._hand_goal(1).pose.origin) < 0.001, "Bell reach makes contact without detaching the holding hand")
		settle()
		check(app.held_tool == tool and _inventory().slice(2) == inventory, "Bell leaves the held " + tool + " and prepared food intact")

func _test_powder() -> void:
	reset(817)
	app.model.orders[0].flavor = "powdered"
	act("bag")
	act("scoop")
	for portion in range(2):
		act("supply")
		act("package")
	act("powdered")
	act("powdered")
	check(app._powder_count == 2 and app._sneeze_delay == 0.0, "Two powder coats do not trigger the sneeze")
	var inventory: Array = _inventory()
	app._act("powdered")
	check(app._powder_count == 3 and app._sneeze_delay > 0 and _inventory() == inventory, "Third powder coat schedules slapstick without changing food or sales")
	advance(0.6)
	check(not sounds.has("sneeze"), "Sneeze waits for its comic delay instead of firing on the click")
	advance(0.9)
	check(sounds.count("sneeze") == 1 and app.model.missed == 0, "Powder sneeze fires once without removing or penalizing the customer")
	act("powdered")
	advance(1.0)
	check(sounds.count("sneeze") == 1, "Further coats do not repeatedly trigger the same sneeze")
	# A delayed reaction belongs to the powder's original customer, not whoever
	# happens to be at the counter when the countdown finishes.
	app._powder_count = 2
	app._act("powdered")
	var target: int = app._sneeze_customer
	app.model.punch_customer()
	app.model._spawn_order()
	app._sync_world()
	advance(1.6)
	check(app.model.orders[0].id != target and sounds.count("sneeze") == 1, "Pending sneeze never transfers to a replacement customer")

func _test_hat_and_resets() -> void:
	reset(818)
	act("scoop")
	app._act("customer")
	check(app._hat_customer == -1, "Scoop click on a customer without a donut hat has no secret side effect")
	app.model.orders[0].id = 7
	app.model._next_order_id = 8
	app._sync_world()
	settle()
	check(app.world.front_customer_has_donut_hat(), "Eligible front customer actually has the donut hat")
	var inventory: Array = _inventory()
	app._act("customer")
	check(app._hat_customer == 7 and app.model.missed == 0 and _inventory() == inventory, "Scoop-only hat interaction is cosmetic and preserves the customer and inventory")
	advance(1.2)
	var hat_sounds: int = sounds.count("hat")
	check(hat_sounds == 1, "Eligible hat interaction reaches the actual world reaction and sound")
	app._act("customer")
	advance(1.2)
	check(sounds.count("hat") == hat_sounds, "The same customer's hat reaction cannot be spammed")
	app._bell_reply = 0.5
	app._sneeze_delay = 0.5
	app._show_title()
	check(app._bell_reply == 0.0 and app._sneeze_delay == 0.0, "Leaving play cancels delayed off-screen jokes")
	reset(819)
	check(app._bell_clicks == 0 and app._bell_window == 0.0 and app._bell_reply == 0.0 and app._bell_cooldown == 0.0 and app._powder_count == 0 and app._sneeze_delay == 0.0 and app._sneeze_customer == -1 and app._hat_customer == -1, "A new shift resets every gag counter, timer and customer binding")
	app.profile.badges.erase("unscheduled_delivery")
	app._on_gag_sound("seagull")
	app._on_gag_sound("seagull")
	check(app.profile.badges.count("unscheduled_delivery") == 1, "Seagull gag awards its secret badge once in the isolated test profile")

func _test_gag_capacity_during_punch() -> void:
	reset(830)
	for index in range(15): app.world._gag_bubble("TEST", Vector3(0, 3, -1))
	app._act("customer")
	var jabs: Array = app.world._gags.filter(func(gag): return gag.kind == "jab")
	check(jabs.size() == 1 and app.world._gags.size() == 16, "Stress fixture starts one real controller punch at the bounded gag capacity")
	if jabs.is_empty(): return
	var jab: Dictionary = jabs[0]
	var person: Node3D = jab.person
	app.world._update_gags(0.12)
	check(is_equal_approx(float(jab.age), 0.12), "Jab impact inserting comic effects cannot advance the same animation twice in one frame")
	check(app.world._gags.size() <= 16 and sounds.count("punch") == 1, "At-capacity impact keeps the effect bound and emits one punch sound")
	advance(3.0)
	check(not app.world._departing.has(person), "At-capacity jab still completes customer departure")
	reset(831)
	app._act("customer")
	person = app.world._punch_person
	for index in range(18): app.world._gag_bubble("TEST", Vector3(0, 3, -1))
	advance(3.0)
	check(not app.world._departing.has(person) and app.world._punch_person != person, "Evicting a jab at the effect cap cannot strand its departed customer or stale punch target")
