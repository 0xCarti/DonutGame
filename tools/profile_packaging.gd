extends SceneTree
## Read-only scene construction profile; deliberately not a machine-speed gate.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world._food.set_paused(true)
	var results: Dictionary = {}
	for kind in ["bag", "bucket"]:
		var milliseconds: Array[float] = []
		for trial in range(12):
			var started: int = Time.get_ticks_usec()
			var package: Node3D = world._make_package(kind, world)
			milliseconds.append(float(Time.get_ticks_usec() - started) / 1000.0)
			package.free()
		var total: float = 0.0
		for value in milliseconds: total += value
		results[kind] = {"samples_ms":milliseconds, "average_ms":total / milliseconds.size(), "max_ms":milliseconds.max()}
	print("PACKAGING PROFILE ", JSON.stringify(results))
	world.queue_free()
	await process_frame
	quit()
