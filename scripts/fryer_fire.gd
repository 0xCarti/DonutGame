extends Node3D
## Procedural fire for the open oil trough. There are no solid flame meshes or
## per-frame allocations: three soft flame sheets, smoke wisps and tiny embers.
## The owner advances the simulation, so the entire effect pauses with gameplay.
const FIRE_SHADER = preload("res://assets/shaders/fryer_fire.gdshader")
const SHEET_COUNT: int = 3
const SMOKE_COUNT: int = 8
const EMBER_COUNT: int = 14
var _flames: Array[MeshInstance3D] = []
var _smoke: Array[MeshInstance3D] = []
var _embers: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _clock: float = 0.0
var _active: bool = false
var _danger: float = 0.0
var _foam_time: float = 0.0
var _reduced_motion: bool = false
var _built: bool = false

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	if _built: return
	_built = true
	var flame_mesh: ArrayMesh = _sheet_mesh()
	for i in range(SHEET_COUNT):
		var sheet: MeshInstance3D = _make_visual("FlameLayer%d" % i, flame_mesh, 0, float(i) * 0.79)
		sheet.position = Vector3(-0.06 + float(i) * 0.06, 0.0, -0.20 + float(i) * 0.20)
		sheet.scale = Vector3(0.96 + float(i) * 0.02, [0.88, 1.14, 0.80][i], 1.0)
		sheet.rotation.y = [-0.035, 0.025, -0.025][i]
		_flames.append(sheet)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	for i in range(SMOKE_COUNT):
		var puff: MeshInstance3D = _make_visual("SmokeWisp%d" % i, quad, 1, float(i) * 0.713)
		_smoke.append(puff)
	for i in range(EMBER_COUNT):
		var ember: MeshInstance3D = _make_visual("RisingEmber%d" % i, quad, 2, float(i) * 0.319)
		_embers.append(ember)

func _make_visual(label: String, mesh: Mesh, kind: int, seed_value: float) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = FIRE_SHADER
	material.set_shader_parameter("effect_type", kind)
	material.set_shader_parameter("seed", seed_value)
	visual.material_override = material
	_materials.append(material)
	add_child(visual)
	return visual

func _sheet_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const COLUMNS: int = 28
	const ROWS: int = 12
	for row in range(ROWS):
		for column in range(COLUMNS):
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var uv: Vector2 = Vector2(float(column + corner.x) / float(COLUMNS), float(row + corner.y) / float(ROWS))
				surface.set_uv(uv)
				surface.set_normal(Vector3.FORWARD)
				surface.add_vertex(Vector3((uv.x - 0.5) * 2.9, uv.y, sin(uv.x * PI) * 0.045))
	return surface.commit()

func set_state(active: bool, danger: float, foam_time: float, reduced_motion: bool) -> void:
	_active = active
	_danger = clampf(danger, 0.0, 1.0)
	_foam_time = maxf(foam_time, 0.0)
	_reduced_motion = reduced_motion
	if _built: _refresh()

func advance(delta: float) -> void:
	if not _built or delta <= 0.0 or not is_finite(delta): return
	_clock += minf(delta, 0.1) * (0.18 if _reduced_motion else 1.0)
	_refresh()

func reset() -> void:
	_clock = 0.0
	_active = false
	_danger = 0.0
	_foam_time = 0.0
	if _built: _refresh()

func _refresh() -> void:
	var warning: bool = _danger >= 0.35 and _foam_time <= 0.0
	visible = _active or warning
	if not visible: return
	for material in _materials:
		material.set_shader_parameter("simulation_time", _clock)
	for layer in _flames:
		layer.visible = _active
		layer.material_override.set_shader_parameter("opacity", 0.78)
		layer.material_override.set_shader_parameter("movement", 0.20 if _reduced_motion else 1.0)
	for i in range(SMOKE_COUNT):
		var puff: MeshInstance3D = _smoke[i]
		puff.visible = _active or i < 4
		var life: float = fposmod(_clock * 0.20 + float(i) * 0.137, 1.0)
		var offset: float = float(i) * 2.39996
		var drift: float = sin(offset + life * 2.4) * life * 0.25
		puff.position = Vector3(-1.03 + fposmod(float(i) * 0.689, 2.1) + drift, 0.32 + life * 1.40, -0.09 + cos(offset) * 0.11)
		var size: float = 0.32 + life * 0.70
		puff.scale = Vector3(size, size * 1.20, size)
		puff.rotation.z = sin(offset) * 0.8 + life * 0.24
		var fade: float = smoothstep(0.0, 0.18, life) * (1.0 - smoothstep(0.68, 1.0, life))
		puff.material_override.set_shader_parameter("opacity", fade * (0.40 if _active else 0.23))
	for i in range(EMBER_COUNT):
		var ember: MeshInstance3D = _embers[i]
		ember.visible = _active and (not _reduced_motion or i < 4)
		var life: float = fposmod(_clock * (0.33 + float(i % 3) * 0.07) + float(i) * 0.197, 1.0)
		var seed_value: float = float(i) * 2.39996
		ember.position = Vector3(-1.15 + fposmod(float(i) * 0.371, 2.30) + sin(seed_value + life * 4.1) * life * 0.11, 0.15 + life * 1.32, 0.02 + cos(seed_value) * 0.20)
		var size: float = 0.014 + float(i % 4) * 0.004
		ember.scale = Vector3(size, size * 1.9, size)
		ember.rotation.z = sin(seed_value + life * 4.0) * 0.35
		var fade: float = smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.60, 1.0, life))
		ember.material_override.set_shader_parameter("opacity", fade * 0.85)

func debug_snapshot() -> Dictionary:
	return {"clock": _clock, "active": _active, "visible": visible, "flames": _flames.size(), "smoke": _smoke.size(), "embers": _embers.size(), "nodes": get_child_count()}
