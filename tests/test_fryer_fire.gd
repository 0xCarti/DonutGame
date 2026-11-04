extends SceneTree
## Fire lifecycle: paused clocks, warning-only smoke, recovery, reduced motion,
## fixed resource budget and repeatable restart. Native capture checks the shader.
const Fire = preload("res://scripts/fryer_fire.gd")
var checks: int = 0
var failures: int = 0

func _init() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var fire = Fire.new()
	root.add_child(fire)
	check(not fire.visible, "A cool fryer has no fire visuals")
	check(fire.get_child_count() == 25, "Fire uses a fixed 25-visual budget")
	fire.set_state(false, 0.6, 0.0, false)
	check(fire.visible, "Overheating produces a smoke warning")
	for layer in fire._flames: check(not layer.visible, "Warning smoke does not fabricate flames")
	for i in range(fire._smoke.size()): check(fire._smoke[i].visible == (i < 4), "Warning uses four wisps")
	fire.set_state(false, 0.6, 4.0, false)
	check(not fire.visible, "Foam suppresses warning smoke during recovery")
	fire.set_state(true, 1.0, 0.0, false)
	fire.advance(0.1)
	for layer in fire._flames:
		check(layer.visible, "An active fire shows all flame layers")
		check(layer.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Transparent flames do not cast solid shadows")
		check(is_equal_approx(float(layer.material_override.get_shader_parameter("simulation_time")), 0.1), "Shader clock follows simulation time")
	var clock_before: float = fire._clock
	var positions: Array[Vector3] = []
	for ember in fire._embers: positions.append(ember.position)
	for i in range(20): fire.set_state(true, 1.0, 0.0, false)
	check(is_equal_approx(fire._clock, clock_before), "Refreshing paused state cannot advance the shader")
	for i in range(positions.size()): check(fire._embers[i].position == positions[i], "Paused embers remain still")
	fire.advance(0.0)
	fire.advance(-1.0)
	check(is_equal_approx(fire._clock, clock_before), "Invalid time steps cannot rewind or advance effects")
	fire.set_state(true, 1.0, 0.0, true)
	fire.advance(0.1)
	check(is_equal_approx(fire._clock - clock_before, 0.018), "Reduced motion slows turbulent movement")
	for i in range(fire._embers.size()): check(fire._embers[i].visible == (i < 4), "Reduced motion retains only four subtle embers")
	for i in range(1200): fire.advance(1.0 / 60.0)
	check(fire.get_child_count() == 25 and fire._materials.size() == 25, "A long burn never allocates new effects")
	fire.reset()
	check(not fire.visible and is_zero_approx(fire._clock), "Reset clears fire and its simulation clock")
	fire.set_state(true, 1.0, 0.0, false)
	fire.advance(0.1)
	for i in range(positions.size()): check(fire._embers[i].position == positions[i], "Restart is deterministic")
	fire.queue_free()
	await process_frame
	print("FRYER FIRE QA: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
