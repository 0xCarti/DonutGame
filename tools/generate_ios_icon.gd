extends SceneTree
## Rasterize the original project icon on an opaque square for Apple app icons.

func _init() -> void:
	var svg = FileAccess.get_file_as_string("res://assets/icon.svg")
	var foreground = Image.new()
	if foreground.load_svg_from_string(svg, 4.0) != OK:
		push_error("Could not rasterize the original project icon")
		quit(1)
		return
	var icon = Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	icon.fill(Color("172c32"))
	icon.blend_rect(foreground, Rect2i(0, 0, 1024, 1024), Vector2i.ZERO)
	icon.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute("res://assets/ios")
	if icon.save_png("res://assets/ios/app_icon.png") != OK:
		push_error("Could not save iOS app icon")
		quit(1)
		return
	print("Saved opaque 1024 x 1024 iOS icon from assets/icon.svg")
	quit(0)
