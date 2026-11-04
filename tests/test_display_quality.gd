extends SceneTree
## Fullscreen must retain native scene detail instead of stretching a fixed render.
var checks: int = 0
var failures: int = 0

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "2D scaling must leave the 3D scene at native render resolution")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "Widescreen displays must render across their full width")
	_check(ProjectSettings.get_setting("display/window/dpi/allow_hidpi"), "Windows must request high DPI backing pixels")
	_check(is_equal_approx(root.scaling_3d_scale, 1.0), "3D rendering must use the full display resolution")
	_check(root.msaa_3d == Viewport.MSAA_4X, "Geometry edges must receive 4x MSAA without screen-blurring FXAA")
	_check(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Avoid full-frame blur from postprocess antialiasing")
	_check(ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level") == 4, "Grazing-angle counter and labels must receive 16x anisotropy")
	for flavor in ["cinnamon", "powdered"]:
		var label: Texture2D = load("res://assets/art/shaker_" + flavor + ".svg")
		_check(label.get_width() == 1024 and label.get_height() == 1152, flavor + " vector label must be rasterized at actual HD detail")
		_check(label.get_image().has_mipmaps(), flavor + " label must have mipmaps to avoid shimmering")
	for kind in ["counter_wood", "kraft_paper"]:
		for channel in ["color", "normal", "roughness"]:
			var texture: Texture2D = load("res://assets/materials/" + kind + "_" + channel + ".png")
			_check(texture.get_width() == 1254 and texture.get_height() == 1254, kind + " " + channel + " must retain its full source resolution")
			_check(texture.get_image().has_mipmaps(), kind + " " + channel + " must retain mipmaps for stable movement")
	for kind in ["steel", "dough", "canvas", "paper", "ground"]:
		for channel in ["color", "normal", "roughness"]:
			var texture: Texture2D = load("res://assets/materials/detail_" + kind + "_" + channel + ".png")
			_check(texture.get_width() == 1024 and texture.get_height() == 1024, kind + " " + channel + " must provide native 1024px physical surface detail")
			_check(texture.get_image().has_mipmaps(), kind + " " + channel + " must remain stable during camera movement")
	var world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	for pair in [["steel_light", "steel"], ["cinnamon", "dough"], ["cream", "canvas"], ["tray_paper", "paper"], ["ground", "ground"]]:
		var material: StandardMaterial3D = world._mat[pair[0]]
		_check(material.albedo_texture.resource_path == "res://assets/materials/detail_" + pair[1] + "_color.png", pair[0] + " uses the authored HD surface in the actual game")
		_check(material.normal_enabled and material.normal_texture.get_width() == 1024 and material.roughness_texture.get_width() == 1024, pair[0] + " uses matching HD normal and roughness maps")
		_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, pair[0] + " activates the configured anisotropic texture sampling")
	var label: Label3D = world._label("Quality inspection", Vector3.ZERO, 18, Color.WHITE)
	_check(label.font_size == 54, "Physical labels use three times the glyph detail")
	_check(is_equal_approx(label.pixel_size * label.font_size, 0.006 * 18), "Higher definition glyphs preserve the physical sign size")
	for dimensions in [Vector2i(906, 920), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		await process_frame
		await physics_frame
		var viewport_rect: Rect2 = root.get_visible_rect()
		var visible: bool = true
		var clickable: bool = true
		for station in world._stations:
			var point: Vector2 = world.station_screen_position(station)
			visible = visible and viewport_rect.has_point(point)
			clickable = clickable and world.pick_station(point) == station
		_check(visible, str(dimensions) + " keeps every physical station inside the visible viewport")
		_check(clickable, str(dimensions) + " preserves physical raycast targets for every station")
		var expected_fov: float = 97.33436 if dimensions.x == 906 else 70.0
		_check(absf(world.camera.fov - expected_fov) < 0.01, str(dimensions) + " preserves the counter framing without changing widescreen FOV")
	world.reset_food(0, 30)
	world.queue_free()
	await process_frame
	await process_frame
	print("DISPLAY QUALITY QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
