extends RefCounted
## Runtime presentation profiles for the Compatibility renderer. Keep one helper
## per game controller so leaving mobile preview can restore its desktop baseline.
## Official Godot 4.7 API references:
## https://docs.godotengine.org/en/4.7/classes/class_viewport.html
## https://docs.godotengine.org/en/4.7/classes/class_engine.html#class-engine-property-max-fps
## MSAA with subnative scale has a reported 4.7.2 Android framebuffer leak:
## https://github.com/godotengine/godot/issues/124258
## These profiles deliberately avoid that combination. Device FPS is not assumed.

const LOW: int = 0
const BALANCED: int = 1
const HIGH: int = 2
const PROFILE_NAMES: PackedStringArray = ["Low", "Balanced", "High"]

var _viewport_id: int = 0
var _desktop_viewport: Dictionary = {}
var _desktop_max_fps: int = 0
var _baseline_captured: bool = false


func recommended_level(mobile_mode: bool = true) -> int:
	# A predictable starting point, not a hardware benchmark or automatic override.
	return BALANCED if mobile_mode else HIGH


func profile(level: int) -> Dictionary:
	var selected: int = clampi(level, LOW, HIGH)
	return {
		"level": selected,
		"name": PROFILE_NAMES[selected],
		"render_scale": [0.65, 0.80, 1.0][selected],
		"msaa_3d": Viewport.MSAA_2X if selected == HIGH else Viewport.MSAA_DISABLED,
		"max_fps": 30 if selected == LOW else 60,
		"sun_shadows": selected >= BALANCED,
		"detail_shadows": selected == HIGH,
		"performance_verified": false,
	}


func apply(world: Node, level: int, mobile_mode: bool = true) -> Dictionary:
	var selected: Dictionary = profile(level)
	selected["mobile_mode"] = mobile_mode
	selected["applied"] = false
	if not is_instance_valid(world) or not world.is_inside_tree() or not world.has_method("set_quality"):
		selected["reason"] = "The world must be attached to a viewport before applying quality."
		return selected
	var viewport: Viewport = world.get_viewport()
	if not is_instance_valid(viewport):
		selected["reason"] = "No active viewport."
		return selected
	_capture_baseline(viewport)
	if mobile_mode:
		# Disable MSAA before lowering scale, including High -> Balanced switches.
		# Restore native scale before enabling MSAA when switching in the other direction.
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = float(selected.render_scale)
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.use_taa = false
		viewport.msaa_3d = int(selected.msaa_3d)
		Engine.max_fps = int(selected.max_fps)
	else:
		_restore_desktop(viewport)
	world.call("set_quality", int(selected.level), mobile_mode)
	selected["applied"] = true
	# Return actual runtime settings for diagnostics, including a restored desktop.
	selected["render_scale"] = viewport.scaling_3d_scale
	selected["msaa_3d"] = viewport.msaa_3d
	selected["max_fps"] = Engine.max_fps
	selected["sun_shadows"] = not mobile_mode or int(selected.level) >= BALANCED
	return selected


func _capture_baseline(viewport: Viewport) -> void:
	if not _baseline_captured:
		_desktop_max_fps = Engine.max_fps
		_baseline_captured = true
	if _viewport_id == viewport.get_instance_id():
		return
	_viewport_id = viewport.get_instance_id()
	_desktop_viewport = {
		"render_scale": viewport.scaling_3d_scale,
		"scaling_mode": viewport.scaling_3d_mode,
		"msaa_3d": viewport.msaa_3d,
		"screen_space_aa": viewport.screen_space_aa,
		"use_taa": viewport.use_taa,
	}


func _restore_desktop(viewport: Viewport) -> void:
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.scaling_3d_mode = int(_desktop_viewport.scaling_mode)
	viewport.scaling_3d_scale = float(_desktop_viewport.render_scale)
	viewport.screen_space_aa = int(_desktop_viewport.screen_space_aa)
	viewport.use_taa = bool(_desktop_viewport.use_taa)
	viewport.msaa_3d = int(_desktop_viewport.msaa_3d)
	Engine.max_fps = _desktop_max_fps


func describe_device() -> Dictionary:
	var model: String = OS.get_model_name().strip_edges()
	var gpu: String = RenderingServer.get_video_adapter_name().strip_edges()
	return {
		"platform": OS.get_name(),
		"model": model if not model.is_empty() else "Unknown device",
		"gpu": gpu if not gpu.is_empty() else "Unknown GPU",
		"renderer": RenderingServer.get_current_rendering_method(),
		"recommended_level": BALANCED,
		"performance_verified": false,
		"recommendation": "Start with Balanced. Use Low if play stutters or the device gets hot; try High if it stays smooth. Frame-rate caps are targets, not measured performance.",
	}
