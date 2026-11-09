extends SceneTree
## Keep the Apple icon opaque; derive it from the project's original vector icon.

func _init() -> void:
	var vector := FileAccess.get_file_as_string("res://assets/icon.svg")
	var foreground := Image.new()
	if foreground.load_svg_from_string(vector) != OK:
		push_error("Circuit icon could not be rasterized")
		quit(1)
		return
	foreground.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var output := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	output.fill(Color("182e32"))
	output.blend_rect(foreground, Rect2i(0, 0, 1024, 1024), Vector2i.ZERO)
	output.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute("res://assets/ios")
	if output.save_png("res://assets/ios/app_icon.png") != OK:
		push_error("Circuit iOS icon could not be saved")
		quit(1)
		return
	print("PASS: opaque 1024x1024 Circuit iOS icon generated")
	quit(0)
