extends Node3D
signal delivery_settled(delivery_id: int, kept: bool)
signal stock_spilled(delivery_id: int)
signal action_finished
## First-person Golden Hour stand. Original meshes and material generators reused
## from the original art library; all interaction staging is specific to this game.
var camera: Camera3D
var _mat: Dictionary = {}
var _bubble_nodes: Array[MeshInstance3D] = []
var _steam_nodes: Array[MeshInstance3D] = []
var _fan: Node3D
var _flipper: Node3D
var _hopper_piston: Node3D
var _upgrade_nodes: Dictionary = {}
var _customers: Array[Node3D] = []
var _venue_root: Node3D
var _donut_mesh: Mesh
var _coating_mesh: Mesh
var _sprinkle_meshes: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _loaded: bool = false
var _state: Dictionary = {}
var _stations: Dictionary = {}
var _markers: Dictionary = {}
var _machine_root: Node3D
var _machine_donuts: Array[Node3D] = []
var _bulk_donuts: Array[Node3D] = []
var _food: Node3D
var _station_meshes: Dictionary = {}
var _station_overlays: Dictionary = {}
var _highlight_strengths: Dictionary = {}
var _heat_knobs: Array[Node3D] = []
var _motions: Array[Dictionary] = []
var _tool_home: Transform3D
var _shakers: Dictionary = {}
var _shaker_homes: Dictionary = {}
var _package_stacks: Dictionary = {}
var _action_duration: float = 0.45
var _action_reach: Vector3 = Vector3.ZERO
var _scoop_pose: Transform3D
var _package_pose: Transform3D
var _action_before: Dictionary = {}
var _prep_donuts: Array[Node3D] = []
var _prep: Node3D
var _prep_type: String = ""
var _prep_flavor: String = ""
var _people: Dictionary = {}
var _departing: Array[Node3D] = []
var _served_person: Node3D
var _view_hands: Node3D
var _held_scoop: Node3D
var _held_package: Node3D
var _held_shaker: Node3D
var _held_scoop_donuts: Array[Node3D] = []
var _held_type: String = ""
var _hover: String = ""
var _reduced_motion: bool = false
var _look: Vector2 = Vector2.ZERO
var _action: String = ""
var _action_time: float = 0.0
var _effects: Array[Dictionary] = []
var _reward_pulse: float = 0.0
var _reward_strength: float = 0.12
var _camera_kick: float = 0.0
var _production_time: float = 0.0
var _donut_crust: ShaderMaterial
var _powder_sugar: ShaderMaterial
var _environment: Environment
var _error_beacon: MeshInstance3D
var _error_glow: OmniLight3D
var _machine_status: Label3D
var _machine_progress: MeshInstance3D
var _station_frames: Dictionary = {}
var _station_labels: Dictionary = {}
var _context_station: String = ""
var _paused: bool = false
var _hands: Array[Node3D] = []
var _detail_lights: Array[Light3D] = []
var _bg_walkers: Array[Dictionary] = []
var _quality: int = 2
var _static_batch_report: Dictionary = {}
var _coating_active: bool = false
var _action_serial: int = 0
var _world_font: Font
var _cosmetic: String = "classic"
var _fair_bulbs: Array[MeshInstance3D] = []
var _handoff: Node3D
var _action_prop: Node3D
var _maintenance_prop: Node3D
var _pitcher_home: Transform3D
var _batter_stream: Node3D
var _refilling: bool = false
var _repair_motion: float = 0.0
var _hand_reach_weight: float = 0.0
var _repair_handle: MeshInstance3D
var _work_light: OmniLight3D
var _heat_fill: MeshInstance3D
var _heat_needle: Node3D
var _repair_lamp: MeshInstance3D
var _repair_label: Label3D
var _batter_fill: MeshInstance3D
var _package_anchor: Vector3 = Vector3(0.55, 1.73, 2.00)
var _supply_anchor: Vector3 = Vector3(-1.40, 1.76, 0.93)
var _serve_anchor: Vector3 = Vector3(0.50, 1.71, -0.95)
const MAX_EFFECTS: int = 64

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.seed = 7132026
	if ResourceLoader.exists("res://assets/fonts/Fredoka-Medium.ttf"):
		_world_font = load("res://assets/fonts/Fredoka-Medium.ttf")
	_make_materials()
	_stand_materials()
	_stand_lighting()
	_make_fairground()
	_build_counter()
	_build_compact_machine()
	_make_donut_resources()
	_build_stations()
	_build_view()
	_build_hands()
	_build_authored_details()
	_batch_static_venue()
	_food = load("res://scripts/stand_food_physics.gd").new()
	add_child(_food)
	_food.configure(self)
	_food.delivery_settled.connect(func(delivery_id: int, kept: bool): delivery_settled.emit(delivery_id, kept))
	_food.stock_spilled.connect(func(delivery_id: int): stock_spilled.emit(delivery_id))
	_loaded = true
	sync_state({})
func _material(key: String, color: Color, metallic: float = 0.0, rough: float = 0.7, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mat[key] = m
	return m


func _make_materials() -> void:
	_material("steel", Color("a7b7bc"), 0.80, 0.30)
	_material("steel_light", Color("d5e0df"), 0.86, 0.22)
	_material("steel_dark", Color("3c505b"), 0.72, 0.38)
	_material("black", Color("202830"), 0.15, 0.55)
	_material("red", Color("b8443d"), 0.08, 0.72)
	_material("red_dark", Color("71343a"), 0.12, 0.65)
	_material("cream", Color("f5dfac"), 0.0, 0.85)
	_material("wood", Color("815235"), 0.0, 0.9)
	_material("wood_light", Color("b17b4a"), 0.0, 0.85)
	_material("wood_dark", Color("4d3934"), 0.0, 0.9)
	_material("brass", Color("e0ac4c"), 0.67, 0.3)
	_material("gold_light", Color("ffe7a7"), 0.4, 0.3, 0.45)
	_material("bulb", Color("ffe5a3"), 0.0, 0.5, 2.0)
	_material("bulb_pink", Color("f78572"), 0.0, 0.55, 1.1)
	_material("bulb_teal", Color("79d6bc"), 0.0, 0.55, 1.1)
	_material("oil_bubble", Color("e5ac3f"), 0.25, 0.28, 0.13)
	_material("dough", Color("d59336"), 0.0, 0.74)
	_material("cinnamon", Color("ad5f25"), 0.0, 0.85)
	_material("powdered", Color("fff0d4"), 0.0, 0.95)
	_material("cocoa", Color("543022"), 0.0, 0.33)
	_material("golden", Color("ffd66b"), 0.54, 0.24, 0.3)
	_material("sprinkle_cinnamon", Color("d9aa65"), 0.0, 0.85)
	_material("sprinkle_powdered", Color("ffffff"), 0.0, 0.95)
	_material("sprinkle_cocoa", Color("e9ac6e"), 0.0, 0.8)
	_material("tray_paper", Color("ead6ae"), 0.0, 1.0)
	_material("selected", Color("ffd276"), 0.35, 0.35, 0.32)
	_material("chalk", Color("263f42"), 0.0, 0.95)
	_material("ground", Color("45415a"), 0.0, 1.0)
	_material("fair_teal", Color("397875"), 0.0, 0.95)
	_material("fair_purple", Color("6a526c"), 0.0, 1.0)
	_material("skin", Color("bf896c"), 0.0, 0.92)
	_material("shirt", Color("637f86"), 0.0, 0.95)
	_material("pants", Color("33374a"), 0.0, 0.95)
	_material("trim_red", Color("782e30"), 0.23, 0.36)
	_material("rubber", Color("162024"), 0.05, 0.82)
	_material("warm_reflector", Color("ffdb9a"), 0.08, 0.5, 0.7)
	_material("bulb_dim", Color("9c6535"), 0.12, 0.45, 0.12)
	_material("bulb_hot", Color("fff0b1"), 0.02, 0.24, 3.0)
	_material("coin", Color("efb941"), 0.76, 0.22, 0.1)
	_material("ground_gravel", Color("514554"), 0.0, 0.95)
	_apply_procedural_materials()
	var steam: StandardMaterial3D = _material("steam", Color(1.0, 0.9, 0.71, 0.12), 0.0, 1.0)
	steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam.disable_receive_shadows = true


func _apply_procedural_materials() -> void:
	# Five intentionally different physical surfaces: directional machine brushing,
	# flowing timber grain, parchment fibres, irregular baked pores, and canvas weave.
	# These are original images baked once at startup, not per-frame shader noise.
	for kind in ["steel", "wood", "paper", "dough", "canvas", "ground"]:
		var maps: Dictionary = _bake_surface(kind)
		var keys: Array = []
		match kind:
			"steel": keys = ["steel", "steel_light", "steel_dark", "brass"]
			"wood": keys = ["wood", "wood_light", "wood_dark"]
			"paper": keys = ["tray_paper"]
			"dough": keys = ["dough", "cinnamon", "powdered", "cocoa"]
			"canvas": keys = ["red", "cream", "red_dark", "fair_teal", "fair_purple"]
			"ground": keys = ["ground", "ground_gravel"]
		for key in keys:
			var material: StandardMaterial3D = _mat[key]
			material.albedo_texture = maps["color"]
			material.normal_enabled = true
			material.normal_texture = maps["normal"]
			material.normal_scale = 0.30 if kind == "steel" else (0.16 if kind == "wood" else 0.24)
			material.roughness_texture = maps["roughness"]
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if kind != "dough":
				material.uv1_triplanar = true
				material.uv1_triplanar_sharpness = 8.0
				material.uv1_scale = Vector3.ONE * (1.4 if kind == "steel" else 0.65)
			if key == "cocoa":
				material.normal_scale = 0.12
				material.roughness = 0.28


func _bake_surface(kind: String) -> Dictionary:
	var resolution: int = 192
	var color_image: Image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var height_image: Image = Image.create(resolution, resolution, false, Image.FORMAT_RGB8)
	var rough_image: Image = Image.create(resolution, resolution, false, Image.FORMAT_RGB8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 8317
	noise.frequency = 0.075
	noise.fractal_octaves = 3
	for y in range(resolution):
		for x in range(resolution):
			var coarse: float = noise.get_noise_2d(float(x), float(y))
			var fine: float = noise.get_noise_2d(float(x) * 7.0, float(y) * 7.0)
			var tone: float = 0.9
			var height_value: float = 0.5
			var rough: float = 0.9
			match kind:
				"steel":
					var line: float = sin(float(y) * 2.7 + sin(float(y) * 0.23))
					var scratches: float = pow(maxf(0.0, sin(float(y) * 1.93 + 0.3)), 20.0)
					tone = 0.90 + line * 0.035 + coarse * 0.025 - scratches * 0.03
					height_value = 0.5 + line * 0.12 + fine * 0.03
					rough = 0.80 + line * 0.12
				"wood":
					var bend: float = sin(float(y) * 0.022) * 1.2 + coarse * 0.35
					var grain: float = sin(float(x) * 0.23 + bend)
					var fibres: float = sin(float(x) * 2.2 + bend * 0.4)
					var knot_distance: float = Vector2((float(x) - 62.0) * 1.3, (float(y) - 89.0) * 0.36).length()
					var knot: float = sin(knot_distance * 0.65) * exp(-knot_distance * 0.045)
					tone = 0.91 + grain * 0.028 + fibres * 0.009 + knot * 0.034 + coarse * 0.018
					height_value = 0.5 + grain * 0.025 + fibres * 0.006
					rough = 0.78 + grain * 0.08
				"paper":
					var fibre: float = noise.get_noise_2d(float(x) * 0.3, float(y) * 3.0)
					var fold: float = pow(maxf(0.0, sin(float(x) * 0.033 + 0.8)), 18.0)
					tone = 0.95 + fibre * 0.06 - fold * 0.035
					height_value = 0.5 + fine * 0.16 + fold * 0.08
				"dough":
					var pore: float = pow(maxf(0.0, fine), 2.0)
					tone = 0.90 + coarse * 0.16 - pore * 0.25
					height_value = 0.5 + coarse * 0.18 - pore * 0.3
					rough = 0.9 + fine * 0.1
				"canvas":
					var weave: float = sin(float(x) * PI * 0.5) * sin(float(y) * PI * 0.5)
					tone = 0.92 + coarse * 0.055 + weave * 0.025
					height_value = 0.5 + weave * 0.12
				"ground":
					tone = 0.72 + coarse * 0.20 + fine * 0.08
					height_value = 0.5 + fine * 0.25
			color_image.set_pixel(x, y, Color(tone, tone, tone, 1.0))
			height_image.set_pixel(x, y, Color(height_value, height_value, height_value))
			rough_image.set_pixel(x, y, Color(rough, rough, rough))
	height_image.bump_map_to_normal_map(2.0)
	color_image.generate_mipmaps()
	height_image.generate_mipmaps()
	rough_image.generate_mipmaps()
	return {"color": ImageTexture.create_from_image(color_image), "normal": ImageTexture.create_from_image(height_image), "roughness": ImageTexture.create_from_image(rough_image)}


func _mesh_node(mesh: Mesh, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


func _box(at: Vector3, size: Vector3, key: String, parent: Node3D = self) -> MeshInstance3D:
	if key in ["steel", "steel_light", "steel_dark", "wood_light", "wood_dark", "red_dark", "brass", "trim_red"] and minf(size.x, minf(size.y, size.z)) > 0.075:
		return _mesh_node(_bevel_box_mesh(size, minf(0.065, minf(size.x, minf(size.y, size.z)) * 0.23)), at, _mat[key], parent)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh_node(mesh, at, _mat[key], parent)


func _bevel_box_mesh(size: Vector3, bevel: float) -> ArrayMesh:
	var h: Vector3 = size * 0.5
	var core: Vector3 = h - Vector3.ONE * bevel
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six inset faces, twelve planar chamfers, and eight triangular corners.
	for axis in range(3):
		var b: int = (axis + 1) % 3
		var c: int = (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var normal: Vector3 = Vector3.ZERO
			normal[axis] = sign_value
			var verts: Array[Vector3] = []
			for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				var v: Vector3 = Vector3.ZERO
				v[axis] = h[axis] * sign_value
				v[b] = core[b] * corner.x
				v[c] = core[c] * corner.y
				verts.append(v)
			_surface_quad(st, verts[0], verts[1], verts[2], verts[3], normal)
	for axis in range(3):
		var b: int = (axis + 1) % 3
		var c: int = (axis + 2) % 3
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var v0: Vector3 = Vector3.ZERO
				v0[axis] = h[axis] * sa
				v0[b] = core[b] * sb
				v0[c] = -core[c]
				var v1: Vector3 = v0
				v1[c] = core[c]
				var v2: Vector3 = v1
				v2[axis] = core[axis] * sa
				v2[b] = h[b] * sb
				var v3: Vector3 = v2
				v3[c] = -core[c]
				var n: Vector3 = Vector3.ZERO
				n[axis] = sa
				n[b] = sb
				_surface_quad(st, v0, v1, v2, v3, n.normalized())
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var signs: Vector3 = Vector3(sx, sy, sz)
				var a: Vector3 = core * signs
				var b: Vector3 = a
				var c: Vector3 = a
				a.x = h.x * sx
				b.y = h.y * sy
				c.z = h.z * sz
				_surface_triangle(st, a, b, c, signs.normalized())
	st.generate_tangents()
	return st.commit()


func _surface_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_surface_triangle(st, a, b, c, normal)
	_surface_triangle(st, a, c, d, normal)


func _surface_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var vertices: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		vertices = [a, c, b]
	for vertex in vertices:
		st.set_normal(normal)
		var uv: Vector2 = Vector2(vertex.x, vertex.z)
		if absf(normal.x) > 0.7:
			uv = Vector2(vertex.z, vertex.y)
		elif absf(normal.z) > 0.7:
			uv = Vector2(vertex.x, vertex.y)
		st.set_uv(uv)
		st.add_vertex(vertex)


func _cylinder(at: Vector3, radius: float, height: float, key: String, parent: Node3D = self, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	return _mesh_node(mesh, at, _mat[key], parent)


func _sphere(at: Vector3, radius: float, key: String, parent: Node3D = self) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _mesh_node(mesh, at, _mat[key], parent)


func _tube(a: Vector3, b: Vector3, radius: float, key: String, parent: Node3D = self) -> MeshInstance3D:
	var node: MeshInstance3D = _cylinder((a + b) * 0.5, radius, a.distance_to(b), key, parent)
	var direction: Vector3 = (b - a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		node.quaternion = Quaternion(Vector3.UP, direction)
	return node


func _label(text_value: String, at: Vector3, size: int, color: Color, parent: Node3D = self) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = at
	label.font_size = size
	if _world_font != null:
		label.font = _world_font
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
	return label


func _make_machine() -> void:
	# Low long stainless steel oil bath: the photo's distinctive open conveyor.
	_box(Vector3(0, 1.91, -0.28), Vector3(8.85, 0.52, 1.95), "steel_dark")
	_box(Vector3(0, 2.0, 0.72), Vector3(8.95, 0.55, 0.12), "steel")
	_box(Vector3(0, 2.03, -1.28), Vector3(8.95, 0.62, 0.12), "steel")
	_box(Vector3(-4.45, 2.07, -0.28), Vector3(0.13, 0.65, 1.95), "steel_light")
	_box(Vector3(4.45, 2.07, -0.28), Vector3(0.13, 0.65, 1.95), "steel_light")
	for z in [-1.3, 0.74]:
		_tube(Vector3(-4.48, 2.35, z), Vector3(4.48, 2.35, z), 0.052, "steel_light")
	var oil_mesh: PlaneMesh = PlaneMesh.new()
	oil_mesh.size = Vector2(8.68, 1.82)
	oil_mesh.subdivide_width = 48
	oil_mesh.subdivide_depth = 10
	var oil_material: ShaderMaterial = ShaderMaterial.new()
	oil_material.shader = load("res://assets/shaders/oil.gdshader")
	_mesh_node(oil_mesh, Vector3(0, 2.23, -0.28), oil_material)
	# Rails and conveyor fingers keep the engineering legible from above.
	for z in [-0.9, 0.34]:
		_tube(Vector3(-4.15, 2.27, z), Vector3(4.0, 2.27, z), 0.025, "steel_dark")
	for i in range(14):
		_box(Vector3(-4.0 + float(i) * 0.60, 2.25, -0.28), Vector3(0.034, 0.06, 1.20), "steel_dark")
	for x in [-3.6, 3.6]:
		for z in [-1.04, 0.48]:
			_cylinder(Vector3(x, 1.69, z), 0.10, 0.18, "black")
	# Stamped panel, hot indicator, service screws, vents and control knobs.
	_box(Vector3(-2.05, 1.99, 0.80), Vector3(1.45, 0.36, 0.06), "steel_light")
	_label("GOLDEN HOUR / 01", Vector3(-2.05, 2.04, 0.84), 18, Color("33454a"))
	_label("MINI-DONUT AUTOMATIC", Vector3(-2.05, 1.91, 0.84), 10, Color("33454a"))
	for x in [-4.20, -3.15, -2.72, -1.38, 0.4, 2.7, 4.20]:
		var screw: MeshInstance3D = _cylinder(Vector3(x, 2.05, 0.80), 0.035, 0.025, "steel_dark")
		screw.rotation_degrees.x = 90.0
	for i in range(7):
		_box(Vector3(1.0 + float(i) * 0.13, 1.99, 0.795), Vector3(0.055, 0.20, 0.014), "steel_dark")
	_box(Vector3(-4.35, 2.31, 0.88), Vector3(0.95, 1.1, 0.45), "steel")
	_box(Vector3(-4.35, 2.31, 1.12), Vector3(0.79, 0.94, 0.025), "steel_light")
	for y in [2.48, 2.06]:
		var control: MeshInstance3D = _cylinder(Vector3(-4.45, y, 1.16), 0.14, 0.09, "black")
		control.rotation_degrees.x = 90.0
		_box(Vector3(-4.45, y + 0.06, 1.22), Vector3(0.026, 0.07, 0.025), "cream")
	_sphere(Vector3(-4.08, 2.52, 1.17), 0.065, "bulb_teal")
	_sphere(Vector3(-4.08, 2.14, 1.17), 0.065, "bulb_pink")
	# Hopper: wide open bowl, tapered funnel, small extrusion nozzle.
	_tube(Vector3(-4.14, 2.3, -1.02), Vector3(-4.14, 4.84, -1.02), 0.08, "steel_dark")
	_box(Vector3(-3.72, 4.7, -0.55), Vector3(1.0, 0.13, 0.95), "steel")
	_cylinder(Vector3(-3.65, 3.57, -0.25), 0.18, 0.95, "steel", self, 0.82)
	_cylinder(Vector3(-3.65, 4.12, -0.25), 0.82, 0.18, "steel_light")
	_batter_fill = _cylinder(Vector3(-3.65, 4.22, -0.25), 0.735, 0.015, "dough")
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 0.73
	rim.outer_radius = 0.85
	rim.rings = 40
	rim.ring_segments = 8
	_mesh_node(rim, Vector3(-3.65, 4.24, -0.25), _mat["steel_light"])
	_cylinder(Vector3(-3.65, 2.91, -0.25), 0.15, 0.42, "steel_light")
	_box(Vector3(-3.68, 4.73, -0.25), Vector3(0.58, 0.72, 0.61), "steel")
	_box(Vector3(-3.68, 4.73, 0.075), Vector3(0.47, 0.59, 0.045), "steel_dark")
	_fan = Node3D.new()
	_fan.position = Vector3(-3.68, 4.73, 0.13)
	add_child(_fan)
	var motor: MeshInstance3D = _cylinder(Vector3.ZERO, 0.21, 0.06, "black", _fan)
	motor.rotation_degrees.x = 90.0
	for i in range(4):
		var blade: MeshInstance3D = _box(Vector3.ZERO, Vector3(0.09, 0.34, 0.04), "steel_light", _fan)
		blade.rotation_degrees.z = float(i) * 45.0
	_hopper_piston = Node3D.new()
	_hopper_piston.position = Vector3(-3.65, 4.30, -0.25)
	add_child(_hopper_piston)
	_cylinder(Vector3.ZERO, 0.045, 0.90, "steel_dark", _hopper_piston)
	# The physical mid-bath turning paddle.
	_flipper = Node3D.new()
	_flipper.position = Vector3(0.02, 2.43, -0.28)
	add_child(_flipper)
	_tube(Vector3(0, 0, -1.03), Vector3(0, 0, 1.03), 0.055, "steel_light", _flipper)
	_box(Vector3(0, 0, 0), Vector3(0.53, 0.055, 1.54), "steel", _flipper)
	_box(Vector3(0, 0, 0), Vector3(0.055, 0.50, 1.54), "steel", _flipper)
	for z in [-1.34, 0.79]:
		_box(Vector3(0.02, 2.36, z), Vector3(0.22, 0.42, 0.15), "steel_dark")
	# Conveyor lift and chute at the right-hand end.
	var lift: MeshInstance3D = _box(Vector3(3.89, 2.44, -0.25), Vector3(1.0, 0.08, 1.55), "steel_dark")
	lift.rotation_degrees.z = 18.0
	for i in range(7):
		var roller: MeshInstance3D = _cylinder(Vector3(3.43 + float(i) * 0.13, 2.34 + float(i) * 0.043, -0.25), 0.045, 1.51, "steel_light")
		roller.rotation_degrees.x = 90.0
	var chute: MeshInstance3D = _box(Vector3(4.50, 2.45, 0.32), Vector3(0.76, 0.06, 1.45), "steel_light")
	chute.rotation_degrees.x = 20.0
	for x in [4.13, 4.87]:
		var lip: MeshInstance3D = _box(Vector3(x, 2.50, 0.32), Vector3(0.05, 0.2, 1.45), "steel")
		lip.rotation_degrees.x = 20.0
	_tube(Vector3(4.3, 2.31, -1.24), Vector3(4.3, 3.11, -1.24), 0.04, "steel_light")
	_tube(Vector3(4.3, 3.11, -1.24), Vector3(4.3, 3.11, 0.7), 0.04, "steel_light")
	_tube(Vector3(4.3, 3.11, 0.7), Vector3(4.3, 2.31, 0.7), 0.04, "steel_light")
	for i in range(32):
		var bubble: MeshInstance3D = _sphere(Vector3(_rng.randf_range(-4.0, 3.3), 2.245, _rng.randf_range(-1.0, 0.40)), _rng.randf_range(0.025, 0.065), "oil_bubble")
		bubble.scale.y = 0.3
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubble.set_meta("phase", _rng.randf_range(0, TAU))
		_bubble_nodes.append(bubble)
	for i in range(7):
		var puff: MeshInstance3D = _sphere(Vector3.ZERO, 0.1, "steam")
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.set_meta("phase", float(i) / 7.0)
		puff.set_meta("start_x", _rng.randf_range(-2.5, 3.0))
		_steam_nodes.append(puff)
	# Purchasable machine attachments, initially absent.
	var turbo: Node3D = Node3D.new()
	turbo.position = Vector3(-4.9, 2.9, -0.48)
	add_child(turbo)
	_cylinder(Vector3.ZERO, 0.31, 0.65, "red_dark", turbo)
	_cylinder(Vector3(0, 0.35, 0), 0.33, 0.08, "brass", turbo)
	_sphere(Vector3(0, 0.44, 0), 0.07, "bulb_teal", turbo)
	turbo.visible = false
	_upgrade_nodes["turbo"] = turbo
	var golden: Node3D = Node3D.new()
	golden.position = Vector3(2.4, 2.6, -1.4)
	add_child(golden)
	_cylinder(Vector3(0, 0.3, 0), 0.22, 0.55, "brass", golden)
	_sphere(Vector3(0, 0.64, 0), 0.15, "gold_light", golden)
	_tube(Vector3(0, 0, 0), Vector3(0, 0.6, 0.6), 0.035, "brass", golden)
	golden.visible = false
	_upgrade_nodes["golden"] = golden


func _make_fairground() -> void:
	var existing_children: Array[Node] = get_children()
	_venue_root = Node3D.new()
	_venue_root.name = "FairgroundVenue"
	add_child(_venue_root)
	_box(Vector3(0, -0.18, -5), Vector3(70, 0.2, 65), "ground")
	# Raised timber midway and its verge establish distance and a grounded setting.
	_box(Vector3(0, -0.10, -6.5), Vector3(38, 0.14, 4.5), "wood_dark")
	for row in range(12):
		_box(Vector3(0, -0.017, -4.43 - float(row) * 0.37), Vector3(37.5, 0.035, 0.345), "wood" if row % 3 else "wood_dark")
	for x in [-19.0, 19.0]:
		_box(Vector3(x, 0.025, -6.5), Vector3(0.15, 0.15, 4.8), "wood_light")
	for i in range(10):
		var at: Vector3 = Vector3(-22.0 + float(i) * 4.7, 1.3, -18.5 - float(i % 3))
		var shrub: MeshInstance3D = _sphere(at, 2.2, "ground_gravel")
		shrub.scale = Vector3(1.25, 0.75, 0.70)
	# A boardwalk under the foreground stand.
	for i in range(16):
		_box(Vector3(-8 + float(i), -0.035, 0.0), Vector3(0.94, 0.07, 10.0), "wood_dark" if i % 3 == 0 else "wood")
	# Distant booths create a real miniature carnival, rather than an empty void.
	for i in range(5):
		var x: float = -13.0 + float(i) * 6.8
		var z: float = -10.7 - absf(float(i) - 2.0) * 0.7
		var key: String = "fair_teal" if i % 2 == 0 else "fair_purple"
		_box(Vector3(x, 1.25, z), Vector3(5.0, 2.5, 3.0), key)
		_box(Vector3(x, 2.05, z + 1.52), Vector3(4.45, 1.2, 0.03), "wood_dark")
		_box(Vector3(x, 1.40, z + 1.78), Vector3(5.15, 0.16, 0.52), "wood_light")
		for j in range(10):
			var stripe: MeshInstance3D = _box(Vector3(x - 2.25 + float(j) * 0.5, 2.88, z + 0.75), Vector3(0.5, 0.10, 2.15), "cream" if j % 2 else key)
			stripe.rotation_degrees.x = -13.0
		for j in range(7):
			_sphere(Vector3(x - 2.1 + float(j) * 0.7, 2.58, z + 1.8), 0.065, "bulb")
		var text_value: String = ["LEMONADE", "PRIZES", "NIGHT MARKET", "ARCADE", "CANDY"][i]
		_label(text_value, Vector3(x, 3.42, z + 1.50), 45, Color("d6c69e"))
		_box(Vector3(x, 3.42, z + 1.43), Vector3(4.0, 0.64, 0.12), key)
	# Ferris-wheel silhouette, luminous rim and tiny enclosed cabins.
	var wheel_center: Vector3 = Vector3(-12.5, 8.7, -20.0)
	var wheel_radius: float = 5.6
	var wheel_torus: TorusMesh = TorusMesh.new()
	wheel_torus.inner_radius = wheel_radius - 0.08
	wheel_torus.outer_radius = wheel_radius + 0.08
	wheel_torus.rings = 64
	wheel_torus.ring_segments = 6
	var wheel: MeshInstance3D = _mesh_node(wheel_torus, wheel_center, _mat["fair_purple"])
	wheel.rotation_degrees.x = 90.0
	for i in range(16):
		var angle: float = float(i) / 16.0 * TAU
		var end: Vector3 = wheel_center + Vector3(sin(angle) * wheel_radius, cos(angle) * wheel_radius, 0)
		_tube(wheel_center, end, 0.035, "fair_purple")
		_sphere(end + Vector3(0, 0, 0.12), 0.10, "bulb_pink" if i % 2 else "bulb")
		_box(end + Vector3(0, -0.45, 0), Vector3(0.65, 0.70, 0.58), "fair_teal" if i % 2 else "red_dark")
	_tube(wheel_center, Vector3(-15.8, 0, -18.4), 0.12, "fair_purple")
	_tube(wheel_center, Vector3(-9.0, 0, -18.4), 0.12, "fair_purple")
	# Sagging festoon lights, with actual cords and sockets.
	for row in range(2):
		var last: Vector3 = Vector3.ZERO
		for i in range(33):
			var t: float = float(i) / 32.0
			var point: Vector3 = Vector3(-17.0 + t * 34.0, 7.0 - sin(t * PI) * 1.7 + float(row) * 1.6, -6.0 - float(row) * 8.0)
			if i > 0:
				_tube(last, point, 0.018, "wood_dark")
			if i % 2 == 0:
				_tube(point, point + Vector3(0, -0.13, 0), 0.025, "black")
				_sphere(point + Vector3(0, -0.20, 0), 0.085, "bulb" if i % 6 != 0 else "bulb_pink")
			last = point
	# Pennants are small original triangular meshes rather than flat rectangles.
	for i in range(24):
		var x: float = -15.0 + float(i) * 1.25
		var y: float = 4.65 - sin(float(i) / 23.0 * PI) * 0.9
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.add_vertex(Vector3(-0.35, 0, 0))
		st.add_vertex(Vector3(0.35, 0, 0))
		st.add_vertex(Vector3(0, -0.65, 0.03))
		st.generate_normals()
		var flag_mat: StandardMaterial3D = _mat[["red", "cream", "fair_teal"][i % 3]].duplicate()
		flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_node(st.commit(), Vector3(x, y, -7.0), flag_mat)
	# Small fairgoers remain background scenery and never obscure the work area.
	for i in range(9):
		var person: Node3D = Node3D.new()
		person.position = Vector3(-13.0 + float(i) * 3.5, 0.0, -6.3 - _rng.randf_range(0.0, 2.0))
		person.scale = Vector3.ONE * _rng.randf_range(0.85, 1.08)
		add_child(person)
		_sphere(Vector3(0, 1.65, 0), 0.23, "skin", person)
		_cylinder(Vector3(0, 1.03, 0), 0.28, 0.90, "shirt" if i % 2 else "fair_purple", person, 0.23)
		for leg in [-0.13, 0.13]:
			_cylinder(Vector3(leg, 0.36, 0), 0.095, 0.72, "pants", person)
		person.set_meta("phase", float(i) * 1.8)
		_customers.append(person)
	# Keep scenery in its own replaceable branch for later concert/sports venues.
	for child in get_children():
		if child != _venue_root and not existing_children.has(child):
			child.reparent(_venue_root)


func _make_donut_resources() -> void:
	_donut_mesh = _organic_donut_mesh(0.181, 0.073)
	_coating_mesh = _organic_donut_mesh(0.181, 0.075)
	_donut_crust = ShaderMaterial.new()
	_donut_crust.shader = load("res://assets/shaders/donut_crust.gdshader")
	_powder_sugar = ShaderMaterial.new()
	_powder_sugar.shader = load("res://assets/shaders/powder_sugar.gdshader")
	for recipe in ["cinnamon", "powdered", "cocoa"]:
		var sprinkle: BoxMesh = BoxMesh.new()
		sprinkle.size = Vector3(0.028, 0.019, 0.047) if recipe == "cocoa" else Vector3(0.010, 0.007, 0.012)
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sprinkle
		mm.instance_count = 11 if recipe == "cocoa" else 36
		for i in range(mm.instance_count):
			var angle: float = float(i) / float(mm.instance_count) * TAU + _rng.randf_range(-0.12, 0.12)
			var radius: float = _rng.randf_range(0.13, 0.20)
			var position_value: Vector3 = Vector3(cos(angle) * radius, 0.082 + _rng.randf_range(-0.004, 0.004), sin(angle) * radius)
			var basis_value: Basis = Basis(Vector3.UP, _rng.randf_range(0, TAU))
			mm.set_instance_transform(i, Transform3D(basis_value, position_value))
		_sprinkle_meshes[recipe] = mm


func _organic_donut_mesh(major: float, minor: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var rings: int = 40
	var sides: int = 14
	for i in range(rings + 1):
		var theta: float = float(i) / float(rings) * TAU
		var width: float = minor * (1.0 + sin(theta * 5.0 + 0.7) * 0.085 + cos(theta * 9.0) * 0.038)
		for j in range(sides + 1):
			var phi: float = float(j) / float(sides) * TAU
			var radial: float = major + cos(phi) * width
			vertices.append(Vector3(cos(theta) * radial, sin(phi) * width + sin(theta * 3.0) * 0.004, sin(theta) * radial))
			normals.append(Vector3(cos(theta) * cos(phi), sin(phi), sin(theta) * cos(phi)).normalized())
			uvs.append(Vector2(float(i) / float(rings), float(j) / float(sides)))
			if i < rings and j < sides:
				var a: int = i * (sides + 1) + j
				var b: int = a + sides + 1
				indices.append_array(PackedInt32Array([a, b, a + 1, b, b + 1, a + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_tangents()
	return surface.commit()


func _create_donut(data: Dictionary, at: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.position = at + Vector3(0, 0.45, 0)
	add_child(node)
	var recipe: String = str(data.get("recipe", "cinnamon"))
	if not _mat.has(recipe):
		recipe = "cinnamon"
	var is_golden: bool = bool(data.get("golden", false))
	var body: MeshInstance3D = _mesh_node(_donut_mesh, Vector3.ZERO, _mat["golden"] if is_golden else _donut_crust, node)
	body.scale = Vector3(1.0, 1.08, 1.0)
	var icing: MeshInstance3D = _mesh_node(_coating_mesh, Vector3.ZERO, _powder_sugar if recipe == "powdered" else _mat["golden" if is_golden else recipe], node)
	icing.scale = Vector3(1.0, 1.08, 1.0)
	icing.visible = recipe != "cinnamon" or is_golden
	var sprinkles: MultiMeshInstance3D = MultiMeshInstance3D.new()
	sprinkles.multimesh = _sprinkle_meshes[recipe]
	sprinkles.material_override = _mat["gold_light" if is_golden else "sprinkle_" + recipe]
	node.add_child(sprinkles)
	if is_golden:
		var star: MeshInstance3D = _sphere(Vector3(0, 0.17, 0), 0.045, "gold_light", node)
		star.scale = Vector3(0.5, 1.6, 0.5)
	node.set_meta("recipe", recipe)
	node.set_meta("golden", is_golden)
	node.set_meta("target", at)
	node.set_meta("roll", 0.0)
	node.set_meta("yaw", float(int(data.get("id", 0)) % 17) * 0.37)
	node.set_meta("age", 0.0)
	return node

func _stand_materials() -> void:
	_material("skin_warm", Color("c88b60"), 0.0, 0.85)
	_material("skin_light", Color("efb794"), 0.0, 0.88)
	_material("skin_dark", Color("79503e"), 0.0, 0.85)
	_material("sleeve", Color("b94b36"), 0.0, 0.8)
	_material("glove", Color("ab9b7e"), 0.0, 0.94)
	_material("shirt_mint", Color("66a99b"), 0.0, 0.88)
	_material("shirt_gold", Color("d3a34e"), 0.0, 0.88)
	_material("shirt_blue", Color("566f9c"), 0.0, 0.88)
	_material("hair", Color("392d2a"), 0.0, 0.9)
	_material("paper_bag", Color("a57d52"), 0.0, 0.93)
	_material("package_inside", Color("62482d"), 0.0, 0.93)
	_material("station_hover", Color("ffd38a"), 0.18, 0.6, 0.5)
	_material("mat_green", Color("415f55"), 0.0, 0.95)
	_material("white", Color("fff3df"), 0.0, 0.85)
	_material("eye", Color("1b2127"), 0.0, 0.3)
	_material("gauge_red", Color("ed6948"), 0.05, 0.5, 0.4)
	_material("gauge_green", Color("92d397"), 0.05, 0.5, 0.3)
	_material("stitched_cuff", Color("f0d6a8"), 0.0, 0.94)
	_material("dark_enamel", Color("163b3b"), 0.30, 0.3)
	_material("paper_fold", Color("7d5d40"), 0.0, 0.96)
	_material("fair_dark", Color("202638"), 0.0, 0.96)
	_material("warning", Color("ff9944"), 0.0, 0.6, 1.3)
	_material("fault", Color("ff5b45"), 0.0, 0.55, 1.6)
	_material("mint_light", Color("a5e3cf"), 0.0, 0.55, 0.8)
	_material("lamp_diffuser", Color("ffc985"), 0.0, 0.7, 0.35)
	_mat["wood_light"].albedo_color = Color("805a3c")
	_mat["wood"].albedo_color = Color("6d4731")
	_mat["wood_dark"].albedo_color = Color("362d2b")
	_mat["red"].albedo_color = Color("9b3a39")
	_mat["red_dark"].albedo_color = Color("512a30")
	_mat["cream"].albedo_color = Color("d9c9a8")
	_mat["ground"].albedo_color = Color("212637")
	_mat["fair_teal"].albedo_color = Color("305a61")
	_mat["fair_purple"].albedo_color = Color("4c405e")
	_mat["paper_bag"].albedo_texture = _mat["tray_paper"].albedo_texture
	_mat["paper_bag"].normal_enabled = true
	_mat["paper_bag"].normal_texture = _mat["tray_paper"].normal_texture
	_mat["paper_bag"].normal_scale = 0.25

func _stand_lighting() -> void:
	var environment: Environment = Environment.new()
	_environment = environment
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7286af")
	environment.ambient_light_energy = 0.16
	environment.ambient_light_sky_contribution = 0.0
	var sky: Sky = Sky.new()
	var sky_material: ShaderMaterial = ShaderMaterial.new()
	sky_material.shader = load("res://assets/shaders/fairground_sky.gdshader")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_light_color = Color("283048")
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.15
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sunlight: DirectionalLight3D = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-32, -24, 0)
	sunlight.light_color = Color("a6b9e4")
	sunlight.light_energy = 0.24
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 36.0
	add_child(sunlight)
	_work_light = OmniLight3D.new()
	_work_light.position = Vector3(0.0, 4.5, 0.3)
	_work_light.omni_range = 5.5
	_work_light.light_color = Color("ffd6a0")
	_work_light.light_energy = 0.42
	_work_light.shadow_enabled = false
	add_child(_work_light)
	var customer_light: OmniLight3D = OmniLight3D.new()
	customer_light.position = Vector3(1.0, 3.8, -0.6)
	customer_light.omni_range = 7.0
	customer_light.light_color = Color("ffd2b5")
	customer_light.light_energy = 0.50
	add_child(customer_light)
	for side in [-1.0, 1.0]:
		var task_light: SpotLight3D = SpotLight3D.new()
		task_light.position = Vector3(side * 2.5, 4.05, 2.5)
		task_light.spot_range = 5.2
		task_light.spot_angle = 44.0
		task_light.spot_attenuation = 0.7
		task_light.light_energy = 1.15
		task_light.light_color = Color("ffdcaa")
		task_light.shadow_enabled = side < 0.0
		add_child(task_light)
		task_light.look_at(Vector3(side * 1.7, 1.7, 1.1), Vector3.UP)
		_detail_lights.append(task_light)

func _build_counter() -> void:
	_box(Vector3(0, 1.48, 0.70), Vector3(10.2, 0.27, 5.1), "wood_dark")
	for i in range(17):
		_box(Vector3(-4.8 + float(i) * 0.6, 1.65, 0.70), Vector3(0.585, 0.10, 5.1), "wood_light" if i % 3 else "wood")
	_box(Vector3(0, 0.85, -1.88), Vector3(10.2, 1.4, 0.16), "red_dark")
	_tube(Vector3(-5.1, 1.72, -1.88), Vector3(5.1, 1.72, -1.88), 0.055, "brass")
	for x in [-4.95, 4.95]:
		_box(Vector3(x, 3.20, -1.80), Vector3(0.16, 5.8, 0.16), "wood_dark")
		_box(Vector3(x, 3.20, 3.22), Vector3(0.16, 5.8, 0.16), "wood_dark")
	# From the operator's eye the canopy is overhead, never a miniature roof.
	for i in range(20):
		var key: String = "red" if i % 2 == 0 else "cream"
		_make_canopy_strip(-4.75 + float(i) * 0.5, key)
		_box(Vector3(-4.75 + float(i) * 0.5, 4.96, -1.87), Vector3(0.50, 0.50, 0.07), key)
		_tube(Vector3(-5.0 + float(i) * 0.5, 4.73, -1.825), Vector3(-4.51 + float(i) * 0.5, 4.73, -1.825), 0.012, "brass")
	for z in [-1.77, 0.65, 3.05]:
		_tube(Vector3(-4.95, 5.02, z), Vector3(4.95, 5.02, z), 0.045, "wood_dark")
	_tube(Vector3(-4.95, 4.68, -1.80), Vector3(4.95, 4.68, -1.80), 0.025, "black")
	for i in range(17):
		_sphere(Vector3(-4.8 + float(i) * 0.6, 4.60, -1.80), 0.065, "bulb")
	# Above the customer window, seen naturally when glancing up.
	_box(Vector3(0.5, 4.15, -1.90), Vector3(3.38, 1.16, 0.11), "red_dark")
	if not ResourceLoader.exists("res://assets/art/counter_sign.png"):
		_label("HOT MINI DONUTS", Vector3(0.5, 4.18, -1.82), 45, Color("ffe1a3"))
	_box(Vector3(0, 1.72, 2.25), Vector3(2.55, 0.025, 1.58), "mat_green")
	_box(Vector3(0, 1.725, 2.98), Vector3(2.55, 0.03, 0.05), "brass")
	# Clear a serving pad across the counter, between the machine and condiments.
	_box(_serve_anchor, Vector3(1.37, 0.035, 0.92), "cream")
	_box(_serve_anchor + Vector3(0, 0.025, -0.42), Vector3(1.35, 0.025, 0.05), "red")
	var serve_text: Label3D = _label("HAND OVER ORDER", _serve_anchor + Vector3(0, 0.026, 0.12), 22, Color("84472e"))
	serve_text.rotation_degrees.x = -90.0

func _make_canopy_strip(x: float, key: String) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(12):
		var t0: float = float(i) / 12.0
		var t1: float = float(i + 1) / 12.0
		var z0: float = -1.9 + t0 * 5.1
		var z1: float = -1.9 + t1 * 5.1
		var y0: float = 5.24 - sin(t0 * PI) * 0.14
		var y1: float = 5.24 - sin(t1 * PI) * 0.14
		_surface_quad(st, Vector3(x - 0.25, y0, z0), Vector3(x + 0.25, y0, z0), Vector3(x + 0.25, y1, z1), Vector3(x - 0.25, y1, z1), Vector3.DOWN)
	var material: StandardMaterial3D = _mat[key].duplicate()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var strip: MeshInstance3D = _mesh_node(st.commit(), Vector3.ZERO, material)
	strip.set_meta("cosmetic_stripe", key)

func _build_compact_machine() -> void:
	var previous: Array[Node] = get_children()
	_machine_root = Node3D.new()
	_machine_root.name = "AutomaticDonutMachine"
	_machine_root.position = Vector3(-2.35, 1.01, -0.60)
	_machine_root.scale = Vector3.ONE * 0.48
	add_child(_machine_root)
	_make_machine()
	for child in get_children():
		if child != _machine_root and not previous.has(child):
			child.reparent(_machine_root, false)
	_box(Vector3(-2.35, 1.765, -0.72), Vector3(4.5, 0.16, 1.14), "dark_enamel")
	# The discharge dogleg ends over the inside of the tray, not its rim.
	var chute_start: Vector3 = Vector3(-0.22, 2.105, -0.10)
	var chute_end: Vector3 = Vector3(-0.62, 2.03, 0.43)
	var direction: Vector3 = (chute_end - chute_start).normalized()
	var chute: MeshInstance3D = _box((chute_start + chute_end) * 0.5, Vector3(0.43, 0.035, chute_start.distance_to(chute_end) + 0.10), "steel_light")
	chute.look_at(chute.position - direction, Vector3.UP)
	for side in [-1.0, 1.0]:
		var offset: Vector3 = direction.cross(Vector3.UP).normalized() * side * 0.22 + Vector3(0, 0.065, 0)
		_tube(chute_start + offset, chute_end + offset, 0.025, "steel")

func _build_stations() -> void:
	# Bulk tray contains visible individual donuts, with a scoop resting beside it.
	_box(_supply_anchor - Vector3(0, 0.06, 0), Vector3(2.25, 0.12, 1.46), "steel_dark")
	_box(_supply_anchor + Vector3(0, 0.01, 0), Vector3(2.12, 0.035, 1.32), "tray_paper")
	for z in [-0.72, 0.72]:
		_box(_supply_anchor + Vector3(0, 0.08, z), Vector3(2.28, 0.22, 0.055), "steel_light")
	for x in [-1.12, 1.12]:
		_box(_supply_anchor + Vector3(x, 0.08, 0), Vector3(0.055, 0.22, 1.46), "steel_light")
	_station("supply", _supply_anchor + Vector3(0, 0.20, 0), Vector3(2.15, 0.35, 1.35), "FRESH DONUTS")
	_station("serve", _serve_anchor + Vector3(0, 0.13, 0), Vector3(1.35, 0.30, 0.92), "SERVE")
	_station("package", _package_anchor + Vector3(0, 0.23, 0), Vector3(0.88, 0.52, 0.72), "PACK HERE")
	var resting_scoop: Node3D = _make_scoop(self)
	_held_scoop = resting_scoop
	resting_scoop.position = Vector3(-0.83, 1.80, 2.48)
	resting_scoop.rotation_degrees.y = -20.0
	_tool_home = resting_scoop.global_transform
	_station("scoop", Vector3(-0.83, 1.93, 2.44), Vector3(0.66, 0.30, 0.90), "SCOOP")
	_package_stacks["bag"] = []
	_package_stacks["bucket"] = []
	for i in range(5):
		var bag: Node3D = Node3D.new()
		add_child(bag)
		bag.position = Vector3(2.25, 1.74 + float(i) * 0.032, 2.24)
		bag.rotation_degrees.y = -8.0 + float(i) * 3.0
		_package_stacks["bag"].append(bag)
		_box(Vector3.ZERO, Vector3(0.67, 0.026, 0.85), "paper_bag", bag)
		_box(Vector3(0, 0.016, 0.03), Vector3(0.39, 0.009, 0.40), "red", bag)
		_box(Vector3(0, 0.016, 0.36), Vector3(0.62, 0.009, 0.06), "cream", bag)
	_station("bag", Vector3(2.25, 1.89, 2.24), Vector3(0.80, 0.38, 0.90), "BAGS · 6 DONUTS")
	for i in range(3):
		var bucket: Node3D = _make_package("bucket", self)
		bucket.position = Vector3(3.32, 1.72 + float(i) * 0.15, 1.67)
		_package_stacks["bucket"].append(bucket)
		if i > 0:
			for child in bucket.get_children():
				if child is Label3D or child.has_meta("branding"):
					child.visible = false
	_station("bucket", Vector3(3.32, 2.13, 1.67), Vector3(0.91, 0.90, 0.90), "BUCKETS · 12 DONUTS")
	for i in range(2):
		var flavor: String = "cinnamon" if i == 0 else "powdered"
		var shaker: Node3D = _make_shaker(flavor, self)
		shaker.position = Vector3(1.55 + float(i) * 0.85, 1.72, 0.63)
		_shakers[flavor] = shaker
		_shaker_homes[flavor] = shaker.global_transform
		_station(flavor, shaker.position + Vector3(0, 0.35, 0), Vector3(0.64, 0.78, 0.67), "CINNAMON" if i == 0 else "POWDERED")
	# A front-facing operating panel makes heat adjustments physically legible.
	var panel: Node3D = Node3D.new()
	panel.position = Vector3(-3.52, 2.50, 0.88)
	panel.rotation_degrees.x = -18.0
	add_child(panel)
	_box(Vector3(-3.52, 2.00, 0.72), Vector3(0.24, 0.67, 0.23), "steel_dark")
	_box(Vector3.ZERO, Vector3(1.35, 0.70, 0.18), "steel_dark", panel)
	_box(Vector3(0, 0.03, 0.11), Vector3(1.20, 0.55, 0.04), "black", panel)
	_label("FRYER HEAT", Vector3(0, 0.20, 0.14), 22, Color("f9d398"), panel)
	_box(Vector3(0, 0.0, 0.145), Vector3(0.90, 0.10, 0.025), "red_dark", panel)
	_box(Vector3(-0.01, 0.0, 0.163), Vector3(0.33, 0.10, 0.017), "gauge_green", panel)
	_heat_needle = Node3D.new()
	_heat_needle.position = Vector3(0, 0, 0.19)
	panel.add_child(_heat_needle)
	_box(Vector3.ZERO, Vector3(0.035, 0.17, 0.025), "white", _heat_needle)
	for i in range(2):
		var button_x: float = -0.40 if i == 0 else 0.40
		var dial: Node3D = Node3D.new()
		panel.add_child(dial)
		dial.position = Vector3(button_x, -0.22, 0.17)
		var control: MeshInstance3D = _cylinder(Vector3.ZERO, 0.15, 0.09, "brass", dial)
		control.rotation_degrees.x = 90.0
		var cap: MeshInstance3D = _cylinder(Vector3(0, 0, 0.052), 0.12, 0.025, "black", dial)
		cap.rotation_degrees.x = 90.0
		_box(Vector3(0, 0.068, 0.070), Vector3(0.027, 0.075, 0.015), "cream", dial)
		_heat_knobs.append(dial)
		_label("-" if i == 0 else "+", Vector3(button_x + (-0.22 if i == 0 else 0.22), -0.21, 0.20), 24, Color("ffe3af"), panel)
		var world_position: Vector3 = panel.to_global(Vector3(button_x, -0.20, 0.20))
		var station_id: String = "heat_down" if i == 0 else "heat_up"
		_station(station_id, world_position, Vector3(0.35, 0.35, 0.30), "LESS HEAT" if i == 0 else "MORE HEAT", false)
		_register_highlight(station_id, dial)
	# Repair cover is a conspicuous orange handhold on the machine's near edge.
	_box(Vector3(-2.64, 2.08, 0.16), Vector3(0.66, 0.35, 0.22), "red_dark")
	_repair_handle = _tube(Vector3(-2.88, 2.16, 0.32), Vector3(-2.40, 2.16, 0.32), 0.055, "brass")
	_repair_lamp = _sphere(Vector3(-2.64, 2.34, 0.18), 0.055, "bulb_teal")
	_repair_label = _label("DRIVE COVER", Vector3(-2.64, 1.98, 0.29), 13, Color("ffe4b4"))
	_station("repair", Vector3(-2.64, 2.12, 0.25), Vector3(0.72, 0.55, 0.55), "HOLD TO CLEAR JAM", false)
	var hopper_target: Vector3 = _machine_root.to_global(Vector3(-3.65, 4.2, -0.25))
	_station("refill", hopper_target + Vector3(0, 0.12, 0), Vector3(0.90, 0.75, 0.90), "REFILL BATTER")
	# A persistent pitcher is lifted from its own resting place for every refill.
	_maintenance_prop = Node3D.new()
	add_child(_maintenance_prop)
	_maintenance_prop.position = Vector3(-4.20, 1.72, 1.72)
	_cylinder(Vector3(0, 0.24, 0), 0.23, 0.48, "cream", _maintenance_prop, 0.27)
	_tube(Vector3(0.20, 0.37, 0), Vector3(0.38, 0.37, 0), 0.027, "dark_enamel", _maintenance_prop)
	_tube(Vector3(0.38, 0.37, 0), Vector3(0.38, 0.10, 0), 0.027, "dark_enamel", _maintenance_prop)
	_tube(Vector3(0.38, 0.10, 0), Vector3(0.20, 0.10, 0), 0.027, "dark_enamel", _maintenance_prop)
	_tube(Vector3(-0.20, 0.45, 0), Vector3(-0.37, 0.46, 0), 0.045, "cream", _maintenance_prop)
	_pitcher_home = _maintenance_prop.global_transform
	_batter_stream = _tube(hopper_target + Vector3(0, 0.50, 0), hopper_target + Vector3(0, 0.02, 0), 0.028, "dough")
	_batter_stream.visible = false
	# A real bin at the operator's left; it never overlaps the food tray.
	_cylinder(Vector3(-3.15, 1.94, 2.35), 0.39, 0.53, "red_dark", self, 0.47)
	_cylinder(Vector3(-3.15, 2.22, 2.35), 0.48, 0.045, "steel_light")
	_cylinder(Vector3(-3.15, 2.24, 2.35), 0.41, 0.018, "black")
	_station("trash", Vector3(-3.15, 2.15, 2.35), Vector3(0.98, 0.55, 0.98), "DISCARD")

func _station(id: String, at: Vector3, dimensions: Vector3, label_text: String, show_label: bool = true) -> void:
	var area: Area3D = Area3D.new()
	area.name = "Station_" + id
	area.position = at
	area.collision_layer = 1
	area.collision_mask = 0
	area.set_meta("station_id", id)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	_stations[id] = area
	var overlay: StandardMaterial3D = StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.albedo_color = Color(1.0, 0.78, 0.35, 0.0)
	overlay.no_depth_test = false
	_station_overlays[id] = overlay
	_station_meshes[id] = []
	_highlight_strengths[id] = 0.0
	_collect_station_meshes(self, id, at, dimensions * 0.54)
	if show_label:
		var label_at: Vector3 = Vector3(at.x, maxf(1.77, at.y - dimensions.y * 0.5), at.z + dimensions.z * 0.5 + 0.04)
		if id == "trash":
			label_at.x += 0.35
		_box(label_at, Vector3(minf(1.2, dimensions.x + 0.16), 0.19, 0.035), "chalk")
		var text_label: Label3D = _label(label_text, label_at + Vector3(0, 0, 0.025), 14, Color("d6cbb1"))
		_station_labels[id] = text_label

func _make_package(kind: String, parent: Node3D) -> Node3D:
	var package: Node3D = Node3D.new()
	parent.add_child(package)
	if kind == "bucket":
		var outer: MeshInstance3D = _cylinder(Vector3(0, 0.28, 0), 0.28, 0.56, "red", package, 0.39)
		outer.mesh.cap_top = false
		var band: MeshInstance3D = _cylinder(Vector3(0, 0.29, 0), 0.319, 0.23, "cream", package, 0.365)
		band.mesh.cap_top = false
		band.mesh.cap_bottom = false
		var inner: MeshInstance3D = _cylinder(Vector3(0, 0.285, 0), 0.265, 0.54, "cream", package, 0.376)
		inner.mesh.cap_top = false
		var inner_mat: StandardMaterial3D = _mat["cream"].duplicate()
		inner_mat.cull_mode = BaseMaterial3D.CULL_FRONT
		inner.material_override = inner_mat
		var rim: TorusMesh = TorusMesh.new()
		rim.inner_radius = 0.375
		rim.outer_radius = 0.405
		rim.rings = 40
		rim.ring_segments = 8
		_mesh_node(rim, Vector3(0, 0.565, 0), _mat["cream"], package).scale.y = 0.7
		_cylinder(Vector3(0, 0.025, 0), 0.265, 0.012, "package_inside", package)
		if not _add_brand_decal(package, Vector3(0, 0.30, 0), Vector2(0.32, 0.32), 0.35):
			_label("GOLDEN\nHOUR", Vector3(0, 0.29, 0.405), 15, Color("6c4130"), package)
	else:
		_box(Vector3(0, 0.31, -0.235), Vector3(0.58, 0.62, 0.035), "paper_bag", package)
		_box(Vector3(0, 0.27, 0.235), Vector3(0.58, 0.54, 0.035), "paper_bag", package)
		for x in [-0.28, 0.28]:
			_box(Vector3(x, 0.27, 0), Vector3(0.028, 0.54, 0.47), "paper_bag", package)
		_box(Vector3(0, 0.035, 0), Vector3(0.56, 0.04, 0.45), "package_inside", package)
		# Folded lips, side gussets and a pressed bottom seam make it read as paper.
		for x in [-0.285, 0.285]:
			_tube(Vector3(x, 0.06, -0.19), Vector3(x, 0.47, 0.0), 0.005, "paper_fold", package)
			_tube(Vector3(x, 0.06, 0.19), Vector3(x, 0.47, 0.0), 0.005, "paper_fold", package)
			_box(Vector3(x, 0.52, 0), Vector3(0.035, 0.028, 0.45), "paper_fold", package)
		_box(Vector3(0, 0.535, 0.237), Vector3(0.59, 0.035, 0.043), "paper_bag", package)
		_box(Vector3(0, 0.615, -0.237), Vector3(0.59, 0.035, 0.043), "paper_bag", package)
		_box(Vector3(0, 0.065, 0.255), Vector3(0.54, 0.016, 0.012), "paper_fold", package)
		if not _add_brand_decal(package, Vector3(0, 0.29, 0.270), Vector2(0.37, 0.37)):
			_box(Vector3(0, 0.28, 0.258), Vector3(0.40, 0.34, 0.012), "dark_enamel", package)
			_label("GOLDEN\nHOUR", Vector3(0, 0.29, 0.27), 18, Color("e1c99f"), package)
	return package

func _add_brand_decal(parent: Node3D, at: Vector3, size: Vector2, curved_radius: float = 0.0) -> bool:
	if not ResourceLoader.exists("res://assets/art/brand_seal.png"):
		return false
	var mesh: Mesh
	if curved_radius <= 0.0:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = size
		mesh = quad
	else:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(12):
			var u0: float = float(i) / 12.0
			var u1: float = float(i + 1) / 12.0
			for corner in [Vector2(u0, 0), Vector2(u1, 1), Vector2(u0, 1), Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1)]:
				var angle: float = (corner.x - 0.5) * size.x / curved_radius
				var y: float = (0.5 - corner.y) * size.y
				var radius: float = curved_radius + y * 0.19 + 0.003
				st.set_normal(Vector3(sin(angle), 0, cos(angle)))
				st.set_uv(corner)
				st.add_vertex(Vector3(sin(angle) * radius, y, cos(angle) * radius))
		mesh = st.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/art/brand_seal.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var decal: MeshInstance3D = _mesh_node(mesh, at, material, parent)
	decal.set_meta("branding", true)
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return true

func _make_scoop(parent: Node3D) -> Node3D:
	var scoop: Node3D = Node3D.new()
	parent.add_child(scoop)
	_box(Vector3(0, 0, -0.12), Vector3(0.42, 0.035, 0.51), "steel_light", scoop)
	for x in [-0.20, 0.20]:
		_box(Vector3(x, 0.09, -0.12), Vector3(0.028, 0.18, 0.51), "steel", scoop)
	_box(Vector3(0, 0.08, 0.125), Vector3(0.42, 0.16, 0.03), "steel", scoop)
	_box(Vector3(0, -0.015, 0.37), Vector3(0.12, 0.11, 0.48), "wood_dark", scoop)
	_box(Vector3(0, -0.01, 0.61), Vector3(0.14, 0.13, 0.08), "brass", scoop)
	# A curved front lip, riveted socket and an inlaid wooden handle.
	_tube(Vector3(-0.20, 0.02, -0.38), Vector3(0.20, 0.02, -0.38), 0.016, "steel_light", scoop)
	_box(Vector3(0, 0.045, 0.16), Vector3(0.19, 0.03, 0.15), "steel", scoop)
	for z in [0.25, 0.47]:
		_cylinder(Vector3(0, 0.046, z), 0.019, 0.009, "brass", scoop)
	return scoop

func _make_shaker(flavor: String, parent: Node3D) -> Node3D:
	var shaker: Node3D = Node3D.new()
	parent.add_child(shaker)
	_cylinder(Vector3(0, 0.29, 0), 0.22, 0.58, "cream", shaker)
	_cylinder(Vector3(0, 0.61, 0), 0.235, 0.08, "steel_light", shaker)
	_box(Vector3(0, 0.29, 0.221), Vector3(0.35, 0.31, 0.015), flavor, shaker)
	_label("CINNAMON\nSUGAR" if flavor == "cinnamon" else "POWDERED\nSUGAR", Vector3(0, 0.29, 0.237), 12, Color("fff1ce") if flavor == "cinnamon" else Color("694c35"), shaker)
	for i in range(5):
		var a: float = float(i) * TAU / 5.0
		_cylinder(Vector3(cos(a) * 0.105, 0.655, sin(a) * 0.105), 0.023, 0.006, "black", shaker)
	return shaker

func _build_view() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 3.45, 5.65)
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 80.0
	add_child(camera)
	camera.look_at(Vector3(0, 2.28, -1.2), Vector3.UP)
	camera.current = true
	# Soft reflected counter light keeps near-camera paper and food readable.
	var hand_fill: OmniLight3D = OmniLight3D.new()
	hand_fill.position = Vector3(0.10, 0.05, -0.20)
	hand_fill.omni_range = 1.8
	hand_fill.light_energy = 0.38
	hand_fill.light_color = Color("ffe1b9")
	camera.add_child(hand_fill)

func _build_authored_details() -> void:
	# The stand has visible construction: painted metal, inset boards, fittings,
	# individual lamp sockets and paper goods. These meshes are original art.
	for side in [-1.0, 1.0]:
		var lamp: Node3D = Node3D.new()
		lamp.position = Vector3(side * 2.5, 4.05, 2.5)
		add_child(lamp)
		_cylinder(Vector3(0, 0.08, 0), 0.30, 0.20, "dark_enamel", lamp, 0.13)
		_cylinder(Vector3(0, -0.035, 0), 0.27, 0.028, "lamp_diffuser", lamp)
		_cylinder(Vector3(0, -0.052, 0), 0.06, 0.025, "gold_light", lamp)
		for i in range(8):
			var angle: float = float(i) * TAU / 8.0
			_tube(Vector3(cos(angle) * 0.27, -0.055, sin(angle) * 0.27), Vector3(cos(angle) * 0.07, -0.055, sin(angle) * 0.07), 0.007, "brass", lamp)
		_tube(Vector3(0, 0.18, 0), Vector3(0, 1.12, 0), 0.025, "black", lamp)
		_box(Vector3(side * 4.88, 2.05, 0.65), Vector3(0.08, 0.55, 5.1), "dark_enamel")
		for y in [1.83, 2.25]:
			_tube(Vector3(side * 4.82, y, -1.85), Vector3(side * 4.82, y, 3.15), 0.022, "brass")
	# Embossed preparation mat border and a shallow shelf for the seasoning tins.
	for x in [-1.22, 1.22]:
		_tube(Vector3(x, 1.75, 1.51), Vector3(x, 1.75, 2.96), 0.012, "stitched_cuff")
	for x in [1.22, 2.80]:
		_box(Vector3(x, 1.77, 0.59), Vector3(0.045, 0.11, 0.8), "dark_enamel")
	_box(Vector3(2.01, 1.73, 0.59), Vector3(1.62, 0.05, 0.80), "dark_enamel")
	# Machine cabinet seams, protective cage and the warning beacon are functional
	# landmarks, with a live label on the operator-facing status plaque.
	for x in [-3.00, -2.31]:
		for y in [1.98, 2.23]:
			var screw: MeshInstance3D = _cylinder(Vector3(x, y, 0.286), 0.022, 0.012, "steel_light")
			screw.rotation_degrees.x = 90
			_box(Vector3(x, y, 0.296), Vector3(0.028, 0.006, 0.004), "black")
	for i in range(7):
		_box(Vector3(-3.18 + float(i) * 0.11, 2.03, -0.08), Vector3(0.047, 0.19, 0.025), "black")
	var previous: Vector3 = Vector3(-3.13, 1.91, 0.15)
	for i in range(1, 9):
		var t: float = float(i) / 8.0
		var point: Vector3 = Vector3(-3.13 - t * 0.51, 1.91 - sin(t * PI) * 0.20, 0.15 + t * 0.51)
		_tube(previous, point, 0.027, "rubber")
		previous = point
	_cylinder(Vector3(-2.62, 2.52, -0.10), 0.12, 0.07, "black")
	_error_beacon = _cylinder(Vector3(-2.62, 2.65, -0.10), 0.092, 0.22, "mint_light", self, 0.070)
	_cylinder(Vector3(-2.62, 2.775, -0.10), 0.077, 0.028, "steel_dark")
	_error_glow = OmniLight3D.new()
	_error_glow.position = Vector3(-2.62, 2.67, 0.15)
	_error_glow.omni_range = 1.45
	_error_glow.light_energy = 0.0
	add_child(_error_glow)
	_box(Vector3(-1.85, 2.38, -0.04), Vector3(0.92, 0.30, 0.065), "dark_enamel")
	_machine_status = _label("FRYING", Vector3(-1.85, 2.41, 0.002), 16, Color("c8e4cb"))
	_box(Vector3(-1.85, 2.29, 0.008), Vector3(0.78, 0.028, 0.012), "black")
	_machine_progress = _box(Vector3(-1.85, 2.29, 0.019), Vector3(0.76, 0.025, 0.009), "mint_light")
	# Tall service-window framing and a row of marquee bulbs anchor the foreground.
	for i in range(21):
		var x: float = -4.5 + float(i) * 0.45
		if x > -1.25 and x < 2.25:
			continue
		var bulb: MeshInstance3D = _sphere(Vector3(x, 4.20, -1.78), 0.040, "bulb_dim")
		_fair_bulbs.append(bulb)
	for i in range(9):
		_fair_bulbs.append(_sphere(Vector3(-1.04 + float(i) * 0.385, 3.57, -1.79), 0.032, "bulb_dim"))
	if ResourceLoader.exists("res://assets/art/counter_sign.png"):
		var sign_mesh: QuadMesh = QuadMesh.new()
		sign_mesh.size = Vector2(3.3, 1.1)
		var sign_mat: StandardMaterial3D = StandardMaterial3D.new()
		sign_mat.albedo_texture = load("res://assets/art/counter_sign.png")
		sign_mat.roughness = 0.9
		sign_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mesh_node(sign_mesh, Vector3(0.50, 4.15, -1.80), sign_mat)
	# Layered midway details create depth beyond the queue: warm pools of light,
	# stocked windows, lanterns, planters and slowly passing silhouettes.
	for i in range(5):
		var x: float = -13.0 + float(i) * 6.8
		var z: float = -10.7 - absf(float(i) - 2.0) * 0.7
		for post in [-2.35, 2.35]:
			_box(Vector3(x + post, 1.94, z + 1.66), Vector3(0.10, 1.35, 0.12), "brass", _venue_root)
		for j in range(6):
			_cylinder(Vector3(x - 1.6 + float(j) * 0.63, 1.64, z + 1.6), 0.12, 0.34, "cream" if j % 2 else "red", _venue_root)
		var stall_light: OmniLight3D = OmniLight3D.new()
		stall_light.position = Vector3(x, 2.40, z + 2.3)
		stall_light.light_color = Color("f8b773") if i % 2 else Color("b9ded2")
		stall_light.light_energy = 1.1
		stall_light.omni_range = 5.0
		_venue_root.add_child(stall_light)
	for x in [-5.9, 5.6]:
		_cylinder(Vector3(x, 0.50, -4.1), 0.55, 0.82, "dark_enamel", _venue_root, 0.70)
		for i in range(6):
			var shrub: MeshInstance3D = _sphere(Vector3(x + sin(float(i) * 2) * 0.45, 1.04 + float(i % 2) * 0.2, -4.1 + cos(float(i) * 2) * 0.37), 0.48, "fair_teal", _venue_root)
			shrub.scale.y = 0.75
	for i in range(_customers.size()):
		_bg_walkers.append({"node": _customers[i], "origin": _customers[i].position, "speed": 0.20 + float(i % 3) * 0.08, "phase": float(i) * 1.7})

func _batch_static_venue() -> void:
	# Scenery keeps the same triangles, normals, UVs, materials and shadow mode.
	# Only its submission changes: stationary pieces sharing a material become
	# one mesh. Walking fairgoers, lights and labels remain independent nodes.
	var groups: Dictionary = {}
	var sources: Array[MeshInstance3D] = []
	for child in _venue_root.get_children():
		if child is MeshInstance3D and child.visible and child.mesh != null:
			sources.append(child)
	var original_bounds: AABB = AABB()
	var has_bounds: bool = false
	var original_indices: int = 0
	for node in sources:
		var transform_to_venue: Transform3D = _venue_root.global_transform.affine_inverse() * node.global_transform
		var bounds: AABB = transform_to_venue * node.get_aabb()
		original_bounds = original_bounds.merge(bounds) if has_bounds else bounds
		has_bounds = true
		for surface in range(node.mesh.get_surface_count()):
			var material: Material = node.material_override if node.material_override != null else node.get_active_material(surface)
			var key: String = "%d:%d:%d" % [material.get_instance_id() if material != null else 0, node.cast_shadow, node.layers]
			if not groups.has(key):
				var builder: SurfaceTool = SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"builder": builder, "material": material, "shadows": node.cast_shadow, "layers": node.layers}
			# Mixing indexed primitives with unindexed authored triangles silently
			# drops unindexed faces on append. Normalize each source, then re-index
			# the completed material batch to retain both geometry and GPU reuse.
			var normalized: SurfaceTool = SurfaceTool.new()
			normalized.create_from(node.mesh, surface)
			normalized.deindex()
			groups[key].builder.append_from(normalized.commit(), 0, transform_to_venue)
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			original_indices += arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()
	var merged_bounds: AABB = AABB()
	var first: bool = true
	var merged_indices: int = 0
	for key in groups:
		var group: Dictionary = groups[key]
		group.builder.index()
		var mesh: ArrayMesh = group.builder.commit()
		var batch: MeshInstance3D = _mesh_node(mesh, Vector3.ZERO, group.material, _venue_root)
		batch.name = "StaticVenue_" + key.replace(":", "_")
		batch.cast_shadow = group.shadows
		batch.layers = group.layers
		batch.set_meta("static_venue_batch", true)
		merged_bounds = mesh.get_aabb() if first else merged_bounds.merge(mesh.get_aabb())
		first = false
		var arrays: Array = mesh.surface_get_arrays(0)
		merged_indices += arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()
	for node in sources:
		_venue_root.remove_child(node)
		node.queue_free()
	_static_batch_report = {"source_meshes": sources.size(), "batches": groups.size(), "source_indices": original_indices, "batch_indices": merged_indices, "source_bounds": original_bounds, "batch_bounds": merged_bounds, "walkers": _bg_walkers.size()}

func _build_hands() -> void:
	_view_hands = Node3D.new()
	camera.add_child(_view_hands)
	# Forearms enter the bottom of the eye-height camera, anchoring the player.
	for side in [-1.0, 1.0]:
		var elbow: Vector3 = Vector3(side * 0.55, -0.79, -0.55)
		var wrist: Vector3 = Vector3(side * 0.34, -0.48, -0.88)
		var hand: Node3D = Node3D.new()
		hand.position = wrist
		_view_hands.add_child(hand)
		_hands.append(hand)
		_tube(elbow - wrist, Vector3(0, -0.025, 0.028), 0.105, "sleeve", hand)
		_tube(Vector3(0, -0.025, 0.03), Vector3(0, 0.005, -0.025), 0.103, "stitched_cuff", hand)
		var palm: MeshInstance3D = _sphere(Vector3(0, 0.025, -0.07), 0.095, "glove", hand)
		palm.scale = Vector3(0.89, 0.57, 1.15)
		for i in range(4):
			var finger_x: float = -0.059 + float(i) * 0.039
			var length: float = 0.082 if i in [1, 2] else 0.062
			var knuckle: Vector3 = Vector3(finger_x, 0.049, -0.12)
			var bend: Vector3 = Vector3(finger_x, 0.068, -0.12 - length * 0.55)
			var tip: Vector3 = Vector3(finger_x, 0.025, -0.12 - length)
			_tube(knuckle, bend, 0.022, "glove", hand)
			_tube(bend, tip, 0.020, "glove", hand)
			_sphere(bend, 0.024, "glove", hand)
			_sphere(tip, 0.021, "glove", hand)
			_tube(knuckle + Vector3(-0.011, 0.010, 0.002), knuckle + Vector3(0.011, 0.010, 0.002), 0.002, "paper_fold", hand)
		_tube(Vector3(-side * 0.065, 0.015, -0.03), Vector3(-side * 0.104, 0.02, -0.085), 0.033, "glove", hand)
		_tube(Vector3(-side * 0.104, 0.02, -0.085), Vector3(-side * 0.08, 0.043, -0.125), 0.028, "glove", hand)
		_sphere(Vector3(-side * 0.08, 0.043, -0.125), 0.028, "glove", hand)
		for stitch in range(5):
			_box(Vector3(-0.066 + float(stitch) * 0.033, 0.063, -0.004), Vector3(0.014, 0.003, 0.009), "paper_fold", hand)
	_scoop_pose = Transform3D(Basis.from_euler(Vector3(deg_to_rad(12), deg_to_rad(-10), 0)).scaled(Vector3.ONE * 0.82), Vector3(0.32, -0.40, -1.17))
	_package_pose = Transform3D(Basis.from_euler(Vector3(deg_to_rad(9), deg_to_rad(-14), 0)).scaled(Vector3.ONE * 0.65), Vector3(0.28, -0.49, -1.13))

func get_camera() -> Camera3D:
	return camera

func pick_station(screen_position: Vector2) -> String:
	if not _loaded:
		return ""
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var end: Vector3 = origin + camera.project_ray_normal(screen_position) * 30.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("collider"):
		return str(hit["collider"].get_meta("station_id", ""))
	return ""

func station_screen_position(id: String) -> Vector2:
	if not _stations.has(id) or not is_instance_valid(camera):
		return Vector2.ZERO
	return camera.unproject_position(_stations[id].global_position)

func get_station_screen_position(id: String) -> Vector2:
	return station_screen_position(id)

func get_station_world_position(id: String) -> Vector3:
	return _stations[id].global_position if _stations.has(id) else Vector3.ZERO

func set_quality(level: int) -> void:
	_quality = clampi(level, 0, 2)
	for light in _detail_lights:
		light.shadow_enabled = _quality >= 2 and light.position.x < 0.0

func set_cosmetic(id: String) -> void:
	_cosmetic = id if id in ["classic", "midnight", "cherry"] else "classic"
	if not _mat.has("red"):
		return
	var red_color: String = "9b3a39"
	var dark_color: String = "512a30"
	if _cosmetic == "midnight":
		red_color = "354f7a"
		dark_color = "23324e"
	elif _cosmetic == "cherry":
		red_color = "773746"
		dark_color = "462633"
	_mat["red"].albedo_color = Color(red_color)
	_mat["red_dark"].albedo_color = Color(dark_color)
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("cosmetic_stripe"):
			var stripe_key: String = str(child.get_meta("cosmetic_stripe"))
			child.material_override.albedo_color = _mat[stripe_key].albedo_color

func set_hover_station(id: String) -> void:
	_hover = id

func _collect_station_meshes(node: Node, id: String, center: Vector3, half: Vector3) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var difference: Vector3 = (child.global_position - center).abs()
			if difference.x <= half.x and difference.y <= half.y and difference.z <= half.z:
				_register_highlight(id, child)
		_collect_station_meshes(child, id, center, half)

func _register_highlight(id: String, node: Node) -> void:
	if not _station_meshes.has(id):
		return
	_station_meshes[id] = _station_meshes[id].filter(func(item): return is_instance_valid(item))
	if node is MeshInstance3D and not _station_meshes[id].has(node):
		if float(_highlight_strengths.get(id, 0.0)) > 0.001:
			node.material_overlay = _station_overlays[id]
		_station_meshes[id].append(node)
	for child in node.get_children():
		_register_highlight(id, child)

func _update_highlights(delta: float) -> void:
	for id in _station_overlays:
		var target: float = 0.12 if id == _hover else 0.0
		var color: Color = Color(1.0, 0.79, 0.36, 1)
		if id == _context_station:
			target = maxf(target, 0.12 if _reduced_motion else 0.09 + sin(_time * 3.6) * 0.025)
			color = Color(1.0, 0.30, 0.13, 1)
		_highlight_strengths[id] = move_toward(float(_highlight_strengths[id]), target, delta * 0.85)
		color.a = _highlight_strengths[id]
		var overlay: StandardMaterial3D = _station_overlays[id]
		overlay.albedo_color = color
		# An alpha-zero overlay can still cost a transparent draw pass. Remove
		# that pass only after the smooth fade finishes; reattach on first light.
		for mesh in _station_meshes[id]:
			if not is_instance_valid(mesh): continue
			if color.a > 0.001:
				if mesh.material_overlay != overlay: mesh.material_overlay = overlay
			elif mesh.material_overlay == overlay:
				mesh.material_overlay = null

func look_offset(delta: Vector2) -> void:
	_look.x = clampf(_look.x - delta.x * 0.0018, -0.157, 0.157)
	_look.y = clampf(_look.y - delta.y * 0.0018, -0.087, 0.087)

func reset_look() -> void:
	_look = Vector2.ZERO

func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_camera_kick = 0.0

func sync_state(state: Dictionary) -> void:
	if not _loaded:
		return
	var previous: Dictionary = _state
	_state = state.duplicate(true)
	_paused = bool(state.get("paused", false))
	_sync_food(previous)
	_sync_package()
	_sync_people()
	_sync_held_tool()
	var temperature: float = float(state.get("temperature", 180.0))
	_heat_needle.position.x = clampf((temperature - 180.0) / 100.0, -0.45, 0.45)
	var jammed: bool = bool(state.get("jammed", false))
	_repair_lamp.material_override = _mat["bulb_pink" if jammed else "bulb_teal"]
	_repair_label.text = "HOLD TO CLEAR" if jammed else "DRIVE COVER"
	_context_station = ""
	var status: String = "FRYING"
	var indicator: String = "mint_light"
	var progress: float = 1.0
	if jammed:
		_context_station = "repair"
		status = "DRIVE JAM"
		indicator = "fault"
		progress = float(state.get("jam_progress", 0.0))
	elif bool(state.get("overheated", false)):
		_context_station = "heat_down"
		status = "TOO HOT"
		indicator = "fault"
		progress = 0.0
	elif int(state.get("batter", 30)) <= 0 or str(state.get("hold_station", "")) == "refill":
		_context_station = "refill"
		status = "REFILLING" if float(state.get("refill_progress", 0.0)) > 0.0 else "NO BATTER"
		indicator = "warning"
		progress = float(state.get("refill_progress", 0.0))
	elif temperature < 145.0:
		_context_station = "heat_up"
		status = "WARMING"
		indicator = "warning"
		progress = clampf((temperature - 90.0) / 55.0, 0.0, 1.0)
	elif int(state.get("supply", 0)) >= int(state.get("supply_capacity", 30)):
		status = "TRAY FULL"
		progress = 1.0
	if _paused:
		status = "PAUSED"
	_machine_status.text = status
	_machine_status.modulate = _mat[indicator].albedo_color
	_error_beacon.material_override = _mat[indicator]
	_machine_progress.material_override = _mat[indicator]
	_machine_progress.scale.x = maxf(0.015, clampf(progress, 0.0, 1.0))
	_error_glow.light_color = _mat[indicator].albedo_color
	_batter_fill.visible = int(state.get("batter", 1)) > 0
	set_hover_station(_hover)
	var pouring_batter: bool = str(state.get("hold_station", "")) == "refill"
	if pouring_batter != _refilling:
		_refilling = pouring_batter
		var target: Transform3D = Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(65))), _stations["refill"].position + Vector3(0.34, 0.35, 0)) if pouring_batter else _pitcher_home
		_move_node(_maintenance_prop, target, 0.28, 0.15)
	_batter_stream.visible = pouring_batter and not _node_is_moving(_maintenance_prop)

func reset_food(supply: int, capacity: int, pending_ids: Array = []) -> void:
	if not is_instance_valid(_food):
		return
	for motion in _motions:
		var node: Node3D = motion.node
		if is_instance_valid(node) and node != _held_scoop and not _shakers.values().has(node) and node != _prep and node != _maintenance_prop:
			node.queue_free()
	_motions.clear()
	for person in _people.values():
		if is_instance_valid(person): person.queue_free()
	_people.clear()
	for person in _departing:
		if is_instance_valid(person): person.queue_free()
	_departing.clear()
	_served_person = null
	_action_time = 0.0
	_action = ""
	_action_prop = null
	_refilling = false
	_maintenance_prop.global_transform = _pitcher_home
	_batter_stream.visible = false
	for flavor in _shakers: _shakers[flavor].global_transform = _shaker_homes[flavor]
	for kind in _package_stacks:
		for package in _package_stacks[kind]: package.visible = true
	for donut in _held_scoop_donuts:
		if is_instance_valid(donut): donut.queue_free()
	_held_scoop_donuts.clear()
	if is_instance_valid(_prep): _prep.queue_free()
	_prep = null
	_held_package = null
	_prep_donuts.clear()
	_prep_type = ""
	_prep_flavor = ""
	_held_type = "none"
	_held_scoop.global_transform = _tool_home
	_state = {}
	_food.clear_food()
	_food.seed_stock(supply, capacity)
	for delivery_id in pending_ids:
		_food.enqueue_production(int(delivery_id))

func enqueue_production(delivery_id: int) -> void:
	_food.enqueue_production(delivery_id)

func _sync_food(previous: Dictionary) -> void:
	_food.set_capacity(int(_state.get("supply_capacity", 30)))
	_food.set_paused(_paused or str(_state.get("phase", "playing")) != "playing")
	var gained: int = int(_state.get("scoop_count", 0)) - int(previous.get("scoop_count", 0))
	if gained > 0 and _action == "supply":
		var donuts: Array = _food.take_donuts(gained)
		for donut in donuts:
			_held_scoop_donuts.append(donut)
			var index: int = _held_scoop_donuts.size() - 1
			var local: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.62), Vector3(-0.10 + float(index % 2) * 0.19, 0.085 + float(index / 2) * 0.10, -0.15 + float(index / 2) * 0.12))
			_move_node(donut, _held_scoop.global_transform * local, 0.24, 0.11, func():
				if is_instance_valid(donut):
					donut.reparent(_held_scoop, true)
					donut.transform = local)
			_motions.back()["target_node"] = _held_scoop
			_motions.back()["target_local"] = local

func _plain_donut(id: int, at: Vector3) -> Node3D:
	var donut: Node3D = _create_donut({"id": id, "recipe": "cinnamon"}, at)
	for child_index in range(1, donut.get_child_count()):
		var child: Node3D = donut.get_child(child_index)
		child.visible = false
	return donut

func _sync_package() -> void:
	var kind: String = str(_state.get("package_type", ""))
	var flavor: String = str(_state.get("package_flavor", ""))
	if kind == "none": kind = ""
	if kind != _prep_type:
		if is_instance_valid(_prep):
			_prep.queue_free()
		_prep_donuts.clear()
		_prep = null
		_held_package = null
		_prep_type = kind
		if not kind.is_empty():
			_prep = _make_package(kind, self)
			_prep.position = _package_anchor
			_register_highlight("package", _prep)
			if _action == kind and is_action_busy():
				var stack: Array = _package_stacks[kind]
				var top: Node3D = stack.back()
				_prep.global_transform = top.global_transform
				if kind == "bag": _prep.scale = Vector3(1.05, 0.06, 1.7)
				top.visible = false
				var target: Transform3D = Transform3D(Basis.IDENTITY, _package_anchor)
				_move_node(_prep, target, 0.43, 0.48, func(): top.visible = true)
	if not is_instance_valid(_prep): return
	_prep.visible = true
	var count: int = mini(int(_state.get("package_count", 0)), 12)
	while _prep_donuts.size() < count:
		var index: int = _prep_donuts.size()
		var donut: Node3D
		var transferred: bool = not _held_scoop_donuts.is_empty()
		var scoop_origin: Transform3D = Transform3D.IDENTITY
		if transferred:
			donut = _held_scoop_donuts.pop_front()
			scoop_origin = donut.transform
			donut.reparent(self, true)
		else:
			donut = _plain_donut(500 + index, Vector3.ZERO)
		_prep_donuts.append(donut)
		var local: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.60), _package_donut_position(index, kind))
		var package: Node3D = _prep
		if transferred:
			_move_node(donut, package.global_transform * local, 0.27 + float(index % 3) * 0.04, 0.15, func():
				if is_instance_valid(donut) and is_instance_valid(package):
					donut.reparent(package, true)
					donut.transform = local)
			_motions.back()["delay"] = 0.13
			_motions.back()["follow_source"] = _held_scoop
			_motions.back()["source_local"] = scoop_origin
		else:
			donut.reparent(package, false)
			donut.transform = local
	while _prep_donuts.size() > count:
		_prep_donuts.pop_back().queue_free()
	if flavor != _prep_flavor:
		_prep_flavor = flavor
		if not (_action in ["cinnamon", "powdered"] and is_action_busy()): _coat_package(flavor)

func _coat_package(flavor: String) -> void:
	for donut in _prep_donuts:
		if is_instance_valid(donut) and donut.get_child_count() > 1:
			var icing: MeshInstance3D = donut.get_child(1)
			icing.visible = not flavor.is_empty()
			icing.material_override = _powder_sugar if flavor == "powdered" else _mat["cinnamon"]

func _package_donut_position(index: int, kind: String) -> Vector3:
	if kind == "bucket":
		return Vector3(-0.16 + float(index % 3) * 0.16, 0.13 + float(index / 3) * 0.12, sin(float(index) * 2.0) * 0.13)
	return Vector3(-0.13 + float(index % 2) * 0.26, 0.12 + float(index / 2) * 0.15, 0)

func _sync_held_tool() -> void:
	var tool: String = str(_state.get("held_tool", "none"))
	if tool == _held_type: return
	var prior: String = _held_type
	_held_type = tool
	if tool == "scoop":
		_move_node(_held_scoop, _view_hands.global_transform * _scoop_pose, 0.32, 0.15)
	elif prior == "scoop":
		_move_node(_held_scoop, _tool_home, 0.30, 0.12)
	if tool == "package" and is_instance_valid(_prep):
		_held_package = _prep
		_move_node(_prep, _view_hands.global_transform * _package_pose, 0.36, 0.20)
	elif prior == "package" and is_instance_valid(_prep):
		_held_package = null
		_move_node(_prep, Transform3D(Basis.IDENTITY, _package_anchor), 0.30, 0.12)

func _sync_people() -> void:
	var orders: Array = _state.get("orders", [])
	var seen: Dictionary = {}
	for i in range(mini(3, orders.size())):
		var order: Dictionary = orders[i]
		var id: int = int(order.get("id", i))
		seen[id] = true
		var target: Vector3 = Vector3(0.4 + float(i) * 1.35, 0.15, -2.15 - float(i) * 0.95)
		var arriving: bool = not _people.has(id)
		if arriving:
			_people[id] = _make_customer(id)
			_people[id].position = target + Vector3(1.7, 0, -1.2)
		var person: Node3D = _people[id]
		if int(person.get_meta("queue_index", -1)) != i:
			person.set_meta("queue_index", i)
			var pose: Transform3D = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(-float(i) * 7.0), 0)), target)
			_move_node(person, pose, 0.64 if arriving else 0.42)
			if is_instance_valid(_served_person) and not arriving: _motions.back()["delay"] = 0.43
		var serve_hit: Area3D = person.get_meta("serve_hit")
		serve_hit.collision_layer = 1 if i == 0 else 0
		var label: Label3D = person.get_meta("order_label")
		var package: String = str(order.get("package", "bag"))
		var flavor: String = str(order.get("flavor", "cinnamon"))
		label.text = ("POWDERED" if flavor == "powdered" else "CINNAMON") + "\n" + package.to_upper()
		var patience: float = clampf(float(order.get("patience", 1.0)) / maxf(1.0, float(order.get("max_patience", 1.0))), 0.0, 1.0)
		var patience_bar: MeshInstance3D = person.get_meta("patience")
		patience_bar.scale.x = maxf(0.02, patience)
		patience_bar.material_override = _mat["gauge_green" if patience > 0.4 else "gauge_red"]
	for id in _people.keys():
		if not seen.has(id):
			var leaving: Node3D = _people[id]
			var hit: Area3D = leaving.get_meta("serve_hit")
			hit.collision_layer = 0
			leaving.get_meta("order_label").visible = false
			leaving.get_meta("patience").visible = false
			_departing.append(leaving)
			if leaving == _served_person:
				_move_node(leaving, leaving.global_transform, 0.48, 0.0, func(): _depart_customer(leaving))
			else:
				_depart_customer(leaving)
			_people.erase(id)

func _depart_customer(person: Node3D) -> void:
	if not is_instance_valid(person): return
	var target: Transform3D = Transform3D(Basis.from_euler(Vector3(0, -1.2, 0)), Vector3(-6.8, 0.15, -3.5))
	_move_node(person, target, 1.45, 0.0, func():
		_departing.erase(person)
		if _served_person == person: _served_person = null
		person.queue_free())

func _make_customer(id: int) -> Node3D:
	var person: Node3D = Node3D.new()
	add_child(person)
	var skin: String = ["skin_light", "skin_warm", "skin_dark"][posmod(id, 3)]
	var shirt: String = ["shirt_mint", "shirt_gold", "shirt_blue", "red"][posmod(id, 4)]
	_cylinder(Vector3(0, 2.13, 0), 0.34, 0.88, shirt, person, 0.27)
	var head: MeshInstance3D = _sphere(Vector3(0, 2.82, 0), 0.255, skin, person)
	head.scale = Vector3(1.0, 1.12, 0.94)
	_cylinder(Vector3(0, 2.50, 0), 0.10, 0.22, skin, person)
	# Layered lapels, shoulder volume and tiny seams make distinct clothes, rather
	# than a single unbroken cone. Hands are linked at elbow/shoulder pivots.
	for side in [-1.0, 1.0]:
		var collar: MeshInstance3D = _box(Vector3(side * 0.10, 2.50, 0.18), Vector3(0.17, 0.11, 0.05), "cream", person)
		collar.rotation_degrees.z = side * 24
	_box(Vector3(0, 2.27, 0.291), Vector3(0.018, 0.40, 0.018), "cream", person)
	for y in [2.37, 2.23, 2.10]:
		_sphere(Vector3(0.035, y, 0.305), 0.015, "brass", person)
	_box(Vector3(-0.19, 2.30, 0.27), Vector3(0.16, 0.11, 0.025), shirt, person)
	_tube(Vector3(-0.27, 2.34, 0.29), Vector3(-0.11, 2.34, 0.29), 0.005, "cream", person)
	var arms: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var arm: Node3D = Node3D.new()
		arm.position = Vector3(side * 0.27, 2.43, 0)
		person.add_child(arm)
		arms.append(arm)
		_sphere(Vector3.ZERO, 0.13, shirt, arm)
		_tube(Vector3.ZERO, Vector3(side * 0.20, -0.43, 0.08), 0.11, shirt, arm)
		_tube(Vector3(side * 0.20, -0.43, 0.08), Vector3(side * 0.02, -0.60, 0.49), 0.075, skin, arm)
		_tube(Vector3(side * 0.20, -0.41, 0.07), Vector3(side * 0.18, -0.46, 0.13), 0.09, "cream", arm)
		var palm: MeshInstance3D = _sphere(Vector3(side * 0.02, -0.60, 0.49), 0.09, skin, arm)
		palm.scale = Vector3(0.8, 0.45, 1.2)
		for finger in range(3):
			_tube(Vector3(side * 0.02 - 0.045 + float(finger) * 0.035, -0.59, 0.51), Vector3(side * 0.02 - 0.045 + float(finger) * 0.035, -0.59, 0.61), 0.018, skin, arm)
		_sphere(Vector3(side * 0.092, 2.85, 0.227), 0.032, "white", person)
		_sphere(Vector3(side * 0.09, 2.85, 0.251), 0.019, "eye", person)
		_sphere(Vector3(side * 0.085, 2.858, 0.268), 0.006, "white", person)
		_tube(Vector3(side * 0.06, 2.93, 0.23), Vector3(side * 0.13, 2.93, 0.22), 0.014, "hair", person)
		var ear: MeshInstance3D = _sphere(Vector3(side * 0.245, 2.82, 0.0), 0.064, skin, person)
		ear.scale = Vector3(0.55, 1.0, 0.70)
		if id % 4 == 0:
			var glass: TorusMesh = TorusMesh.new()
			glass.inner_radius = 0.047
			glass.outer_radius = 0.055
			glass.rings = 24
			glass.ring_segments = 6
			var rim: MeshInstance3D = _mesh_node(glass, Vector3(side * 0.095, 2.85, 0.263), _mat["brass"], person)
			rim.rotation_degrees.x = 90
			_tube(Vector3(side * 0.14, 2.86, 0.26), Vector3(side * 0.24, 2.87, 0.02), 0.009, "brass", person)
	person.set_meta("arms", arms)
	if id % 4 == 0:
		_tube(Vector3(-0.04, 2.86, 0.263), Vector3(0.04, 2.86, 0.263), 0.008, "brass", person)
	_sphere(Vector3(0, 2.78, 0.26), 0.045, skin, person)
	_tube(Vector3(-0.065, 2.70, 0.226), Vector3(0, 2.68, 0.244), 0.012, "hair", person)
	_tube(Vector3(0, 2.68, 0.244), Vector3(0.065, 2.70, 0.226), 0.012, "hair", person)
	if id % 3 == 0:
		_cylinder(Vector3(0, 3.05, 0), 0.29, 0.14, shirt, person, 0.22)
		_box(Vector3(0, 3.015, 0.22), Vector3(0.39, 0.045, 0.25), shirt, person)
	elif id % 3 == 1:
		_cylinder(Vector3(0, 3.05, 0), 0.25, 0.20, "cream", person, 0.20)
		_cylinder(Vector3(0, 2.975, 0), 0.34, 0.04, "cream", person)
		_cylinder(Vector3(0, 3.0, 0), 0.255, 0.06, "red", person)
	else:
		var hair: MeshInstance3D = _sphere(Vector3(0, 2.99, -0.025), 0.245, "hair", person)
		hair.scale.y = 0.5
		for i in range(6):
			var curl: MeshInstance3D = _sphere(Vector3(-0.20 + float(i) * 0.08, 3.04 + sin(float(i) * 1.8) * 0.035, 0.07), 0.085, "hair", person)
			curl.scale = Vector3(0.85, 1.1, 1.0)
	# The customer's physical order card and a small readable patience strip.
	_box(Vector3(0, 2.16, 0.34), Vector3(0.78, 0.49, 0.045), "cream", person)
	var order_label: Label3D = _label("", Vector3(0, 2.16, 0.371), 23, Color("6a402d"), person)
	person.set_meta("order_label", order_label)
	_box(Vector3(0, 3.37, 0), Vector3(0.79, 0.065, 0.03), "black", person)
	var patience: MeshInstance3D = _box(Vector3(0, 3.37, 0.022), Vector3(0.76, 0.045, 0.02), "gauge_green", person)
	person.set_meta("patience", patience)
	var serve_hit: Area3D = Area3D.new()
	serve_hit.position = Vector3(0, 2.50, 0.15)
	serve_hit.collision_layer = 1
	serve_hit.collision_mask = 0
	serve_hit.set_meta("station_id", "serve")
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.95, 1.6, 0.75)
	shape.shape = box
	serve_hit.add_child(shape)
	person.add_child(serve_hit)
	person.set_meta("serve_hit", serve_hit)
	return person

func is_action_busy() -> bool:
	if _action in ["repair", "refill"]: return false
	if _action_time > 0.001: return true
	for motion in _motions:
		var node: Node3D = motion.node
		if is_instance_valid(node) and node != _maintenance_prop and not node.has_meta("serve_hit"):
			return true
	return false

func animate_action(id: String) -> void:
	# Heat clicks may arrive during a transfer; never cancel a hand movement.
	if id in ["heat_down", "heat_up"]: return
	_action = id
	_action_before = _state.duplicate(true)
	_action_duration = 0.44 if id != "serve" else 0.50
	_action_time = _action_duration
	_action_serial += 1
	_action_reach = get_station_world_position(id)
	if id == "supply":
		var dipped: Transform3D = Transform3D(Basis.from_euler(Vector3(0, -0.3, -0.15)), _supply_anchor + Vector3(0.30, 0.21, 0.12))
		_move_node(_held_scoop, dipped, 0.18, 0.15, func(): _move_node(_held_scoop, _view_hands.global_transform * _scoop_pose, 0.24, 0.22))
	elif id == "package" and str(_state.get("held_tool", "")) == "scoop":
		var tipped: Transform3D = Transform3D(Basis.from_euler(Vector3(deg_to_rad(55), 0, 0)).scaled(Vector3.ONE * 0.82), _package_anchor + Vector3(0.03, 0.8, 0.12))
		_move_node(_held_scoop, tipped, 0.18, 0.15, func(): _move_node(_held_scoop, _view_hands.global_transform * _scoop_pose, 0.24, 0.10))
	elif id in ["cinnamon", "powdered"]:
		_action_prop = _shakers[id]
		var shaker: Node3D = _action_prop
		var home: Transform3D = _shaker_homes[id]
		var tilted: Transform3D = Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(-135))), _package_anchor + Vector3(0.16, 1.0, 0))
		_move_node(shaker, tilted, 0.18, 0.18, func():
			_coat_package(id)
			_move_node(shaker, home, 0.24, 0.14, func(): _action_prop = null))
		for i in range(18 if not _reduced_motion else 6):
			var grain: MeshInstance3D = _sphere(_package_anchor + Vector3(_rng.randf_range(-0.13, 0.13), 0.85, _rng.randf_range(-0.12, 0.12)), 0.011, id)
			_add_effect(grain, Vector3(_rng.randf_range(-0.10, 0.10), -1.15, _rng.randf_range(-0.10, 0.10)), 0.22 + float(i % 5) * 0.025)
			grain.visible = false
			_effects.back()["delay"] = 0.14
	if id == "trash":
		var recoverable: Array[Node3D] = []
		recoverable.append_array(_held_scoop_donuts)
		if str(_state.get("package_flavor", "")).is_empty(): recoverable.append_array(_prep_donuts)
		var returned: int = mini(recoverable.size(), int(_state.get("supply_capacity", 30)) - int(_state.get("supply", 0)))
		for index in range(recoverable.size()):
			var donut: Node3D = recoverable[index]
			_held_scoop_donuts.erase(donut)
			_prep_donuts.erase(donut)
			donut.reparent(self, true)
			if index < returned:
				var target: Vector3 = _supply_anchor + Vector3(_rng.randf_range(-0.65, 0.65), 0.38, _rng.randf_range(-0.35, 0.35))
				_move_node(donut, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.62), target), 0.30, 0.30, func():
					var recovered: Array[Node3D] = [donut]
					_food.return_donuts(recovered))
			else:
				_move_node(donut, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.62), get_station_world_position("trash")), 0.3, 0.25, func(): donut.queue_free())
	if id in ["serve", "trash"] and is_instance_valid(_prep):
		var package: Node3D = _prep
		_prep = null
		_held_package = null
		_prep_donuts.clear()
		_prep_type = ""
		var destination: Vector3 = get_station_world_position("trash") + Vector3(0, -0.1, 0)
		if id == "serve":
			var orders: Array = _state.get("orders", [])
			_served_person = _people.get(int(orders[0].get("id", -1))) if not orders.is_empty() else null
			destination = _served_person.to_global(Vector3(0.12, 1.78, 0.48)) if is_instance_valid(_served_person) else _serve_anchor + Vector3(0, 0.16, -0.62)
		_handoff = package if id == "serve" else null
		var recipient: Node3D = _served_person if id == "serve" else null
		_move_node(package, Transform3D(Basis.IDENTITY, destination), 0.48, 0.30, func():
			if is_instance_valid(recipient): package.reparent(recipient, true)
			else: package.queue_free())
		for person_id in _people: _people[person_id].set_meta("cheer", 0.95)

func _move_node(node: Node3D, destination: Transform3D, duration: float, arc: float = 0.0, finished: Callable = Callable()) -> void:
	for index in range(_motions.size() - 1, -1, -1):
		if _motions[index].node == node: _motions.remove_at(index)
	_motions.append({"node": node, "from": node.global_transform, "to": destination, "duration": duration, "age": 0.0, "arc": arc, "finished": finished})

func _node_is_moving(node: Node3D) -> bool:
	for motion in _motions:
		if motion.node == node: return true
	return false

func _advance_motions(delta: float) -> void:
	var completed: Array[Callable] = []
	for index in range(_motions.size() - 1, -1, -1):
		var motion: Dictionary = _motions[index]
		var node: Node3D = motion.node
		if not is_instance_valid(node):
			_motions.remove_at(index)
			continue
		if float(motion.get("delay", 0.0)) > 0.0:
			if motion.has("follow_source") and is_instance_valid(motion.follow_source):
				node.global_transform = motion.follow_source.global_transform * Transform3D(motion.source_local)
				motion.from = node.global_transform
			motion.delay = maxf(0.0, float(motion.delay) - delta)
			continue
		motion.age = minf(float(motion.duration), float(motion.age) + delta)
		var t: float = float(motion.age) / float(motion.duration)
		var eased: float = t * t * (3.0 - 2.0 * t)
		if motion.has("target_node") and is_instance_valid(motion.target_node):
			motion.to = motion.target_node.global_transform * Transform3D(motion.target_local)
		var pose: Transform3D = Transform3D(motion.from).interpolate_with(motion.to, eased)
		pose.origin.y += sin(t * PI) * float(motion.arc)
		node.global_transform = pose
		if t >= 1.0:
			var callback: Callable = motion.finished
			if callback.is_valid(): completed.append(callback)
			_motions.remove_at(index)
	for callback in completed: callback.call()

func _add_path_effect(node: Node3D, start: Vector3, destination: Vector3, duration: float, arc: float, spin: bool) -> void:
	node.position = start
	_add_effect(node, Vector3.ZERO, duration)
	var effect: Dictionary = _effects.back()
	effect["path_start"] = start
	effect["path_end"] = destination
	effect["arc"] = 0.0 if _reduced_motion else arc
	effect["spin"] = spin and not _reduced_motion

func burst_reward(amount: float, tier: int = 0) -> void:
	tier = clampi(tier, 0, 3)
	_reward_pulse = 0.7 + float(tier) * 0.12
	_reward_strength = 0.12 + float(tier) * 0.16 + minf(maxf(amount, 0.0) * 0.00025, 0.04)
	if tier >= 2 and not _reduced_motion:
		_camera_kick = minf(0.12, _camera_kick + (0.065 if tier == 2 else 0.11))
	# Exact payout typography belongs to the shared feedback canvas. The booth
	# contributes a light chase, physical confetti and the brief camera response.
	for i in range(0 if _reduced_motion else 5 + mini(3, tier) * 4):
		var confetti: MeshInstance3D = _box(_serve_anchor + Vector3(0, 0.40, 0), Vector3(0.045, 0.07, 0.01), "gold_light")
		_add_effect(confetti, Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(1.0, 1.8), _rng.randf_range(-0.3, 0.3)), 0.9)

func _add_effect(node: Node3D, velocity: Vector3, lifetime: float) -> void:
	while _effects.size() >= MAX_EFFECTS:
		var old: Dictionary = _effects.pop_front()
		old["node"].queue_free()
	_effects.append({"node": node, "velocity": velocity, "age": 0.0, "lifetime": lifetime, "scale": node.scale})

func _process(delta: float) -> void:
	if not _loaded:
		return
	if _paused:
		return
	_time += delta
	var was_busy: bool = is_action_busy()
	_action_time = maxf(0.0, _action_time - delta)
	_reward_pulse = maxf(0.0, _reward_pulse - delta)
	_camera_kick = maxf(0.0, _camera_kick - delta * 0.55)
	_work_light.light_energy = 0.42 + _reward_pulse * _reward_strength
	_error_glow.light_energy = (0.12 + (0.35 if _reduced_motion else pow(sin(_time * 5.0) * 0.5 + 0.5, 3.0) * 0.7)) if not _context_station.is_empty() else 0.0
	_update_highlights(delta)
	for knob in _heat_knobs:
		knob.rotation.z = lerp_angle(knob.rotation.z, deg_to_rad(120.0 - float(_state.get("heat_setting", 3)) * 60.0), 1.0 - exp(-delta * 15.0))
	_repair_motion = move_toward(_repair_motion, 1.0 if str(_state.get("hold_station", "")) == "repair" else 0.0, delta * 7.0)
	_repair_handle.position.y = 2.16 + (sin(_time * 13.0) * 0.018 * _repair_motion if not _reduced_motion else 0.0)
	_batter_stream.visible = _refilling and not _node_is_moving(_maintenance_prop)
	for i in range(_fair_bulbs.size()):
		var chase: int = 0 if _reduced_motion else int(_time * 24.0)
		_fair_bulbs[i].material_override = _mat["bulb_hot" if _reward_pulse > 0.0 and (i + chase) % 4 < 2 else "bulb_dim"]
	camera.position = Vector3(0, 3.45, 5.65)
	camera.look_at(Vector3(0, 2.28, -1.2), Vector3.UP)
	camera.rotation.y += _look.x
	camera.rotation.x += _look.y
	if not _reduced_motion:
		camera.position.y += sin(_time * 71.0) * _camera_kick * 0.20
		camera.position.x += cos(_time * 83.0) * _camera_kick * 0.12
		camera.rotation.z += sin(_time * 67.0) * _camera_kick * 0.018
	var action_phase: float = sin(clampf(_action_time / _action_duration, 0.0, 1.0) * PI)
	_view_hands.position = Vector3(0, 0.0 if _reduced_motion else sin(_time * 1.2) * 0.008, 0)
	_advance_motions(delta)
	if was_busy and not is_action_busy(): action_finished.emit()
	if _held_type == "scoop" and not _node_is_moving(_held_scoop):
		_held_scoop.global_transform = _view_hands.global_transform * _scoop_pose
	if is_instance_valid(_held_package) and not _node_is_moving(_held_package):
		_held_package.global_transform = _view_hands.global_transform * _package_pose
	if _hands.size() == 2:
		var right_home: Vector3 = Vector3(0.34, -0.48, -0.88)
		var reaching_to: Vector3 = _action_reach + Vector3(0, 0.20, 0.24)
		var reach_amount: float = action_phase * 0.90
		# Keep the glove on the moving object rather than pointing at its old station.
		if _action in ["bag", "bucket"] and is_instance_valid(_prep) and is_action_busy():
			reaching_to = _prep.to_global(Vector3(0.27, 0.24, 0.10))
			reach_amount = 1.0
		elif is_instance_valid(_handoff) and _action == "serve" and is_action_busy():
			reaching_to = _handoff.to_global(Vector3(0.27, 0.21, 0.08))
			reach_amount = 1.0
		elif is_instance_valid(_action_prop):
			reaching_to = _action_prop.to_global(Vector3(0.18, 0.25, 0))
			reach_amount = 1.0
		elif is_instance_valid(_held_package):
			reaching_to = _held_package.to_global(Vector3(0.27, 0.21, 0.08))
			reach_amount = 1.0
		elif _held_type == "scoop":
			reaching_to = _held_scoop.to_global(Vector3(0, -0.005, 0.42))
			reach_amount = 1.0
		if str(_state.get("hold_station", "")) == "refill":
			reaching_to = _maintenance_prop.to_global(Vector3(0.34, 0.24, 0))
			reach_amount = 1.0
		elif str(_state.get("hold_station", "")) == "repair":
			reaching_to = _repair_handle.global_position
			reach_amount = 1.0
		_hand_reach_weight = lerpf(_hand_reach_weight, reach_amount, 1.0 - exp(-delta * 24.0))
		var reach: Vector3 = _view_hands.to_local(reaching_to)
		_hands[1].position = right_home.lerp(reach, _hand_reach_weight)
		_hands[1].rotation.x = action_phase * -0.30
		_hands[0].rotation.z = action_phase * -0.16 if _action == "serve" else 0.0
		for side_index in range(2):
			var hand: Node3D = _hands[side_index]
			var sleeve: MeshInstance3D = hand.get_child(0)
			var elbow: Vector3 = _view_hands.to_global(Vector3(-0.55 if side_index == 0 else 0.55, -0.79, -0.55))
			var wrist: Vector3 = hand.to_global(Vector3(0, -0.025, 0.028))
			var direction: Vector3 = (wrist - elbow).normalized()
			sleeve.global_position = (elbow + wrist) * 0.5
			sleeve.global_basis = Basis(Quaternion(Vector3.UP, direction))
			sleeve.scale.y = elbow.distance_to(wrist) / maxf(0.001, float(sleeve.mesh.height))
	var running: bool = str(_state.get("phase", "playing")) == "playing" and not bool(_state.get("jammed", false)) and int(_state.get("batter", 1)) > 0 and not bool(_state.get("overheated", false)) and float(_state.get("temperature", 180.0)) >= 145.0 and str(_state.get("hold_station", "")) != "refill"
	if running:
		_production_time += delta
		_fan.rotation.z += delta * 3.5
		_flipper.rotation.z += delta * 1.8
		_hopper_piston.position.y = 4.30 + sin(_time * 3.4) * 0.055
	_food.set_machine_running(running)
	for bubble in _bubble_nodes:
		var phase: float = float(bubble.get_meta("phase"))
		var size: float = 0.6 + sin(_time * 3.0 + phase) * 0.35
		bubble.scale = Vector3(size, size * 0.3, size)
	for puff in _steam_nodes:
		var life: float = fmod(_time * 0.24 + float(puff.get_meta("phase")), 1.0)
		puff.position = Vector3(float(puff.get_meta("start_x")), 2.38 + life * 1.0, -0.4)
		puff.scale = Vector3.ONE * sin(life * PI) * 1.5
	for id in _people:
		var person: Node3D = _people[id]
		person.rotation.z = 0.0 if _reduced_motion else sin(_time * 1.4 + float(id)) * 0.012
		var cheer: float = maxf(0.0, float(person.get_meta("cheer", 0.0)) - delta)
		person.set_meta("cheer", cheer)
		if person.has_meta("arms"):
			for arm in person.get_meta("arms"):
				arm.rotation.x = sin(cheer * PI) * -0.32 if not _reduced_motion else 0.0
	for walker in _bg_walkers:
		var node: Node3D = walker["node"]
		var origin: Vector3 = walker["origin"]
		node.position.x = origin.x + (sin(_time * float(walker["speed"]) * 0.12 + float(walker["phase"])) * 2.2 if not _reduced_motion else 0.0)
		node.rotation.z = sin(_time * 2.1 + float(walker["phase"])) * 0.025 if not _reduced_motion else 0.0
	for i in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[i]
		if float(effect.get("delay", 0.0)) > 0.0:
			effect.delay = maxf(0.0, float(effect.delay) - delta)
			continue
		effect["node"].visible = true
		var age: float = float(effect["age"]) + delta
		effect["age"] = age
		var node: Node3D = effect["node"]
		if effect.has("path_start"):
			var path_t: float = clampf(age / float(effect["lifetime"]), 0.0, 1.0)
			node.position = Vector3(effect["path_start"]).lerp(Vector3(effect["path_end"]), smoothstep(0.0, 1.0, path_t)) + Vector3(0, sin(path_t * PI) * float(effect["arc"]), 0)
			if bool(effect.get("spin", false)):
				node.rotation.z += delta * 7.0
		else:
			node.position += Vector3(effect["velocity"]) * delta
		var remaining: float = 1.0 - smoothstep(0.65, 1.0, age / float(effect["lifetime"]))
		node.scale = Vector3(effect["scale"]) * remaining
		if age >= float(effect["lifetime"]):
			node.queue_free()
			_effects.remove_at(i)
