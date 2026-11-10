extends Control
## Small decorative bursts; never intercept game input or run in reduced motion.
var elapsed = 0.0
var particles: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 8
	var rng = RandomNumberGenerator.new()
	rng.seed = 8032
	for i in range(38):
		particles.append({"x": rng.randf_range(0.15, 0.85), "vx": rng.randf_range(-90, 90), "vy": rng.randf_range(-130, -260), "delay": rng.randf_range(0, 0.2), "size": rng.randf_range(3, 7), "color": [Color("ffc857"), Color("ee6953"), Color("2bba98"), Color("b39ad8")][i % 4]})

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed > 2.2: queue_free()

func _draw() -> void:
	for piece in particles:
		var t = elapsed - float(piece.delay)
		if t < 0: continue
		var point = Vector2(size.x * float(piece.x) + float(piece.vx) * t, size.y * 0.4 + float(piece.vy) * t + 160 * t * t)
		var color: Color = piece.color
		color.a = clampf((2.2 - elapsed) / 0.6, 0, 1)
		draw_circle(point, float(piece.size), color)
