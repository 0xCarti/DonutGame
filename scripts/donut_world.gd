extends Node3D
## Original procedural Golden Hour art. All geometry, materials and animation are
## authored for this game. Public methods deliberately do not depend on game core.

var camera: Camera3D
var _mat: Dictionary = {}
var _donuts: Dictionary = {}
var _tray_rims: Array[MeshInstance3D] = []
var _tray_lamps: Array[MeshInstance3D] = []
var _tray_positions: Array[Vector3] = [Vector3(-2.75, 1.86, 2.02), Vector3(0.0, 1.86, 2.02), Vector3(2.75, 1.86, 2.02)]
var _bubble_nodes: Array[MeshInstance3D] = []
var _steam_nodes: Array[MeshInstance3D] = []
var _fan: Node3D
var _flipper: Node3D
var _hopper_piston: Node3D
var _clock_hand: Node3D
var _upgrade_nodes: Dictionary = {}
var _time: float = 0.0
var _selected: int = 0
var _title_view: bool = false
var _donut_mesh: Mesh
var _coating_mesh: Mesh
var _sprinkle_meshes: Dictionary = {}
var _sale_effects: Array[Dictionary] = []
var _customers: Array[Node3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _loaded: bool = false
var _venue_root: Node3D
var _environment: Environment
var _key_light: DirectionalLight3D
var _title_demo_trays: Array = []
var _reduced_motion: bool = false
var _camera_trauma: float = 0.0
var _celebration_time: float = 0.0
var _celebration_duration: float = 1.0
var _celebration_tier: int = 0
var _marquee_bulbs: Array[MeshInstance3D] = []
var _score_lights: Array[OmniLight3D] = []
var _warm_light: OmniLight3D
const MAX_SALE_EFFECTS: int = 110

func _ready() -> void:
	_rng.seed = 20261103
	_make_materials()
	_make_lighting()
	_make_fairground()
	_make_stand()
	_make_machine()
	_make_trays()
	_make_props()
	_make_finish_details()
	_make_donut_resources()
	_make_camera()
	_loaded = true

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
	_material("sprinkle_cinnamon", Color("61351d"), 0.0, 0.85)
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
			material.normal_scale = 0.30 if kind == "steel" else (0.45 if kind == "wood" else 0.24)
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
					tone = 0.86 + grain * 0.065 + fibres * 0.022 + knot * 0.075 + coarse * 0.035
					height_value = 0.5 + grain * 0.055 + fibres * 0.012
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
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
	return label

func _make_lighting() -> void:
	var environment: Environment = Environment.new()
	_environment = environment
	environment.background_mode = Environment.BG_SKY
	environment.background_color = Color("302b48")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8895b7")
	environment.ambient_light_energy = 0.24
	environment.ambient_light_sky_contribution = 0.0
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("242c48")
	sky_material.sky_horizon_color = Color("a36c62")
	sky_material.sky_curve = 0.2
	sky_material.ground_bottom_color = Color("1d2531")
	sky_material.ground_horizon_color = Color("8b6c68")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_light_color = Color("4b435b")
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	_key_light = sun
	sun.rotation_degrees = Vector3(-34, -48, 0)
	sun.light_color = Color("fbc18d")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var warm: OmniLight3D = OmniLight3D.new()
	_warm_light = warm
	warm.position = Vector3(-2.0, 4.45, 2.0)
	warm.omni_range = 9.0
	warm.light_color = Color("ffdb9f")
	warm.light_energy = 1.65
	warm.shadow_enabled = true
	warm.shadow_bias = 0.04
	add_child(warm)
	var rim: OmniLight3D = OmniLight3D.new()
	rim.position = Vector3(5.5, 4.2, -3.5)
	rim.omni_range = 12.0
	rim.light_color = Color("9db9e3")
	rim.light_energy = 0.85
	add_child(rim)
	for i in range(3):
		var pulse_light: OmniLight3D = OmniLight3D.new()
		pulse_light.position = _tray_positions[i] + Vector3(0, 1.8, 0.15)
		pulse_light.omni_range = 4.0
		pulse_light.light_color = Color("ffca69")
		pulse_light.light_energy = 0.0
		add_child(pulse_light)
		_score_lights.append(pulse_light)

func _make_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(7.2, 8.0, 13.8)
	camera.fov = 38.0
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.1, 0.1), Vector3.UP)
	camera.current = true

func _make_stand() -> void:
	# Heavy timber counter, individual boards and a painted front fascia.
	_box(Vector3(0.0, 1.44, 0.35), Vector3(12.1, 0.24, 6.0), "wood_dark")
	for i in range(12):
		_box(Vector3(-5.5 + float(i), 1.60, 0.35), Vector3(0.98, 0.10, 6.0), "wood_light" if i % 3 != 0 else "wood")
	_box(Vector3(0, 0.78, 3.21), Vector3(12.1, 1.42, 0.18), "red_dark")
	_box(Vector3(0, 1.46, 3.34), Vector3(12.2, 0.13, 0.14), "brass")
	_box(Vector3(0, 0.12, 3.34), Vector3(12.2, 0.14, 0.14), "wood_dark")
	for x in [-5.8, -3.9, -1.95, 0.0, 1.95, 3.9, 5.8]:
		_box(Vector3(x, 0.78, 3.33), Vector3(0.055, 1.22, 0.055), "wood_light")
	var front_sign: Node3D = Node3D.new()
	front_sign.position = Vector3(0, 0.8, 3.36)
	add_child(front_sign)
	_box(Vector3.ZERO, Vector3(4.0, 0.82, 0.08), "cream", front_sign)
	_label("FRESH • HOT • LITTLE RINGS OF JOY", Vector3(0, 0.03, 0.05), 31, Color("733d31"), front_sign)
	for x in [-5.8, 5.8]:
		_box(Vector3(x, 3.50, -2.15), Vector3(0.16, 5.7, 0.16), "wood_dark")
		_cylinder(Vector3(x, 3.49, -2.15), 0.12, 0.24, "brass")
	# A shallow striped rear awning frames the machine without hiding the fryer.
	for i in range(20):
		var x: float = -5.7 + float(i) * 0.6
		var stripe: MeshInstance3D = _box(Vector3(x, 5.86, -2.02), Vector3(0.6, 0.10, 1.85), "red" if i % 2 == 0 else "cream")
		stripe.rotation_degrees.x = -8.0
		_box(Vector3(x, 5.67, -1.1), Vector3(0.6, 0.37, 0.08), "red" if i % 2 == 0 else "cream")
		var scallop: MeshInstance3D = _sphere(Vector3(x, 5.49, -1.10), 0.30, "red" if i % 2 == 0 else "cream")
		scallop.scale = Vector3(1.0, 0.42, 0.15)
	_tube(Vector3(-5.9, 5.47, -1.03), Vector3(5.9, 5.47, -1.03), 0.032, "brass")
	for i in range(17):
		var x: float = -5.6 + float(i) * 0.7
		var bulb: MeshInstance3D = _sphere(Vector3(x, 5.38, -1.01), 0.075, "bulb")
		_marquee_bulbs.append(bulb)
	# Large physical marquee. Deliberately behind the work surface.
	var sign: Node3D = Node3D.new()
	sign.position = Vector3(1.1, 4.43, -2.25)
	add_child(sign)
	_box(Vector3.ZERO, Vector3(5.6, 1.42, 0.18), "brass", sign)
	_box(Vector3(0, 0, 0.12), Vector3(5.37, 1.19, 0.08), "red_dark", sign)
	_label("G O L D E N  H O U R", Vector3(0, 0.16, 0.18), 59, Color("ffe5a3"), sign)
	_label("MINI DONUTS  •  MADE FRESH", Vector3(0, -0.32, 0.18), 25, Color("f3dca7"), sign)
	for i in range(12):
		_marquee_bulbs.append(_sphere(Vector3(-2.52 + float(i) * 0.46, 0.62, 0.19), 0.046, "bulb", sign))
		_marquee_bulbs.append(_sphere(Vector3(-2.52 + float(i) * 0.46, -0.62, 0.19), 0.046, "bulb", sign))

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
	_cylinder(Vector3(-3.65, 4.22, -0.25), 0.735, 0.015, "dough")
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

func _make_trays() -> void:
	for i in range(3):
		var at: Vector3 = _tray_positions[i]
		_box(at + Vector3(0, -0.1, 0), Vector3(2.35, 0.16, 1.54), "steel_dark")
		_box(at + Vector3(0, -0.002, 0), Vector3(2.21, 0.035, 1.40), "tray_paper")
		for z in [-0.74, 0.74]:
			var lip: MeshInstance3D = _box(at + Vector3(0, 0.02, z), Vector3(2.37, 0.19, 0.06), "steel_light")
			if z > 0:
				_tray_rims.append(lip)
		for x in [-1.16, 1.16]:
			_box(at + Vector3(x, 0.02, 0), Vector3(0.06, 0.19, 1.5), "steel_light")
		# Parchment stripes and a numbered brass plaque.
		for k in range(7):
			_box(at + Vector3(-0.95 + float(k) * 0.31, 0.018, 0), Vector3(0.014, 0.006, 1.34), "cream")
		_box(at + Vector3(0, -0.11, 0.80), Vector3(0.68, 0.30, 0.055), "brass")
		_label("TRAY " + str(i + 1), at + Vector3(0, -0.09, 0.838), 18, Color("4b352c"))
		var lamp: MeshInstance3D = _sphere(at + Vector3(-0.90, 0.13, 0.75), 0.055, "bulb")
		_tray_lamps.append(lamp)

func _make_props() -> void:
	# Recipe tins: tangible recognisable toppings on the left rear shelf.
	for i in range(3):
		var x: float = -2.0 + float(i) * 0.72
		var recipe: String = ["cinnamon", "powdered", "cocoa"][i]
		_cylinder(Vector3(x, 2.15, -1.87), 0.26, 0.92, "cream")
		_cylinder(Vector3(x, 2.64, -1.87), 0.27, 0.09, "steel_dark")
		_box(Vector3(x, 2.16, -1.60), Vector3(0.43, 0.37, 0.025), recipe)
		_label(["CIN", "SUGAR", "COCOA"][i], Vector3(x, 2.16, -1.58), 13, Color("fff0d4") if i != 1 else Color("684834"))
	# Kraft bags, stacked serving buckets and scoop on the counter edges.
	for i in range(4):
		var bag: Node3D = Node3D.new()
		bag.position = Vector3(-5.22, 1.76 + float(i) * 0.06, 2.04)
		bag.rotation_degrees.y = -8.0 + float(i) * 6.0
		add_child(bag)
		_box(Vector3.ZERO, Vector3(0.79, 0.055, 1.08), "cream", bag)
		_box(Vector3(0, 0.033, 0), Vector3(0.43, 0.012, 0.5), "red", bag)
	for i in range(3):
		_cylinder(Vector3(5.36, 1.93 + float(i) * 0.14, 1.93), 0.28, 0.60, "red", self, 0.39)
		_cylinder(Vector3(5.36, 2.245 + float(i) * 0.14, 1.93), 0.40, 0.035, "cream")
	_cylinder(Vector3(5.36, 2.54, 1.93), 0.34, 0.01, "red_dark")
	var scoop: Node3D = Node3D.new()
	scoop.position = Vector3(4.70, 1.82, 2.13)
	scoop.rotation_degrees.y = -24.0
	add_child(scoop)
	_box(Vector3(0, 0, 0), Vector3(0.37, 0.045, 0.53), "steel_light", scoop)
	_box(Vector3(-0.17, 0.08, 0), Vector3(0.035, 0.16, 0.53), "steel", scoop)
	_box(Vector3(0.17, 0.08, 0), Vector3(0.035, 0.16, 0.53), "steel", scoop)
	_box(Vector3(0, 0.03, 0.52), Vector3(0.11, 0.09, 0.52), "wood_dark", scoop)
	# Thermometer / little round analog clock at the rear right.
	var clock_face: MeshInstance3D = _cylinder(Vector3(4.65, 4.33, -2.12), 0.56, 0.14, "brass")
	clock_face.rotation_degrees.x = 90.0
	var face: MeshInstance3D = _cylinder(Vector3(4.65, 4.33, -2.025), 0.49, 0.04, "cream")
	face.rotation_degrees.x = 90.0
	for i in range(12):
		var angle: float = float(i) / 12.0 * TAU
		var tick: MeshInstance3D = _box(Vector3(4.65 + sin(angle) * 0.40, 4.33 + cos(angle) * 0.40, -1.99), Vector3(0.035, 0.08, 0.025), "wood_dark")
		tick.rotation.z = -angle
	_clock_hand = Node3D.new()
	_clock_hand.position = Vector3(4.65, 4.33, -1.97)
	add_child(_clock_hand)
	_box(Vector3(0, 0.14, 0), Vector3(0.035, 0.31, 0.02), "red", _clock_hand)
	_box(Vector3(4.77, 4.33, -1.96), Vector3(0.25, 0.04, 0.03), "wood_dark")
	_sphere(Vector3(4.65, 4.33, -1.94), 0.05, "brass")
	# Hand-lettered mini menu board.
	var menu: Node3D = Node3D.new()
	menu.position = Vector3(5.35, 2.72, -1.52)
	menu.rotation_degrees.y = -12.0
	add_child(menu)
	_box(Vector3.ZERO, Vector3(1.05, 1.7, 0.13), "wood_light", menu)
	_box(Vector3(0, 0, 0.08), Vector3(0.91, 1.54, 0.025), "chalk", menu)
	_label("TODAY'S\nLITTLE\nHAPPINESS", Vector3(0, 0.38, 0.11), 22, Color("f7dca0"), menu)
	_label("CINNAMON\nPOWDERED\nCOCOA", Vector3(0, -0.31, 0.11), 15, Color("efe6ca"), menu)

func _make_finish_details() -> void:
	# Folded steel service plates, rubber gaskets and deliberate panel seams.
	for x in [-2.7, 0.0, 2.7]:
		_box(Vector3(x, 1.925, 0.803), Vector3(2.58, 0.31, 0.045), "rubber")
		_box(Vector3(x, 1.95, 0.834), Vector3(2.51, 0.30, 0.055), "steel")
		for dx in [-1.12, 1.12]:
			var washer: MeshInstance3D = _cylinder(Vector3(x + dx, 1.97, 0.872), 0.047, 0.012, "steel_dark")
			washer.rotation_degrees.x = 90.0
			var screw: MeshInstance3D = _cylinder(Vector3(x + dx, 1.97, 0.886), 0.031, 0.019, "steel_light")
			screw.rotation_degrees.x = 90.0
			_box(Vector3(x + dx, 1.97, 0.900), Vector3(0.038, 0.008, 0.006), "black")
	# Durable folded lip and red enamel trim beneath the bath.
	_box(Vector3(0, 1.715, 0.91), Vector3(8.92, 0.105, 0.20), "trim_red")
	_tube(Vector3(-4.40, 1.77, 0.85), Vector3(4.40, 1.77, 0.85), 0.025, "brass")
	# Guard wire around the flipping unit; catches moving warm highlights.
	for x in [-0.42, 0.44]:
		_tube(Vector3(x, 2.37, -1.17), Vector3(x, 2.83, -1.17), 0.025, "steel_light")
		_tube(Vector3(x, 2.83, -1.17), Vector3(x, 2.83, -0.79), 0.025, "steel_light")
	_tube(Vector3(-0.42, 2.83, -0.79), Vector3(0.44, 2.83, -0.79), 0.025, "steel_light")
	# Power cable follows the side of the counter rather than floating in space.
	var points: Array[Vector3] = [Vector3(-4.75, 2.12, 0.83), Vector3(-5.04, 1.78, 0.72), Vector3(-5.26, 1.73, 0.13), Vector3(-5.24, 1.73, -0.85), Vector3(-5.38, 1.72, -1.72), Vector3(-5.71, 1.57, -1.92)]
	for i in range(points.size() - 1):
		_tube(points[i], points[i + 1], 0.047, "rubber")
	_box(Vector3(-5.71, 1.72, -1.92), Vector3(0.20, 0.25, 0.26), "black")
	# Physical overhead work-light shades direct attention to food and steel.
	for x in [-2.6, 2.7]:
		_tube(Vector3(x, 5.6, -1.12), Vector3(x, 5.13, -0.5), 0.032, "black")
		var shade: MeshInstance3D = _cylinder(Vector3(x, 5.02, -0.39), 0.35, 0.22, "red_dark", self, 0.15)
		shade.rotation_degrees.x = 16.0
		var interior: MeshInstance3D = _cylinder(Vector3(x, 4.90, -0.36), 0.30, 0.025, "warm_reflector")
		interior.rotation_degrees.x = 16.0
	# Small safety decal and engraved front plaque, placed above the service panels.
	_box(Vector3(3.38, 2.16, 0.807), Vector3(0.47, 0.14, 0.01), "cream")
	_label("HOT OIL", Vector3(3.38, 2.16, 0.818), 14, Color("74462d"))
	# Fasteners in the timber edge, trim nails, and worn corner protectors.
	for x in [-5.9, 5.9]:
		_box(Vector3(x, 1.59, 3.24), Vector3(0.24, 0.12, 0.34), "brass")
	for i in range(12):
		for z in [-2.46, 3.17]:
			_cylinder(Vector3(-5.5 + float(i), 1.657, z), 0.018, 0.008, "wood_dark")
	# Timber cross-bracing and metal tray feet introduce contact shadows.
	for tray in _tray_positions:
		for x in [-0.85, 0.85]:
			_box(tray + Vector3(x, -0.18, 0), Vector3(0.16, 0.12, 1.12), "rubber")

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
	_donut_mesh = _organic_donut_mesh(0.161, 0.084)
	_coating_mesh = _organic_donut_mesh(0.158, 0.080)
	for recipe in ["cinnamon", "powdered", "cocoa"]:
		var sprinkle: BoxMesh = BoxMesh.new()
		sprinkle.size = Vector3(0.028, 0.019, 0.047) if recipe == "cocoa" else Vector3(0.021, 0.017, 0.023)
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sprinkle
		mm.instance_count = 11 if recipe == "cocoa" else 16
		for i in range(mm.instance_count):
			var angle: float = float(i) / float(mm.instance_count) * TAU + _rng.randf_range(-0.12, 0.12)
			var radius: float = _rng.randf_range(0.13, 0.20)
			var position_value: Vector3 = Vector3(cos(angle) * radius, 0.076 + _rng.randf_range(-0.007, 0.007), sin(angle) * radius)
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
		var width: float = minor * (1.0 + sin(theta * 5.0 + 0.7) * 0.055 + cos(theta * 9.0) * 0.025)
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
	var body: MeshInstance3D = _mesh_node(_donut_mesh, Vector3.ZERO, _mat["golden" if is_golden else "dough"], node)
	body.scale = Vector3(1.0, 0.72, 1.0)
	var icing: MeshInstance3D = _mesh_node(_coating_mesh, Vector3(0, 0.044, 0), _mat["golden" if is_golden else recipe], node)
	icing.scale = Vector3(1.0, 0.38, 1.0)
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

func sync_state(active: Array, trays: Array, selected_tray: int, owned: Dictionary) -> void:
	if not _loaded:
		return
	_selected = clampi(selected_tray, 0, 2)
	var present: Dictionary = {}
	for item in active:
		if not item is Dictionary:
			continue
		var data: Dictionary = item
		if float(data.get("progress", 0.0)) < 0.0:
			continue
		var p: float = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
		var id_value: int = int(data.get("id", 0))
		var lane: float = -0.28 + (0.25 if id_value % 2 == 0 else -0.25)
		var position_value: Vector3 = Vector3(lerpf(-3.65, 3.98, minf(p / 0.93, 1.0)), 2.31, lane)
		if p > 0.87:
			position_value.y += (p - 0.87) * 2.1
		if p > 0.94:
			position_value.x = lerpf(3.98, 4.55, (p - 0.94) / 0.06)
		var roll: float = 0.0
		if p > 0.43 and p < 0.57:
			roll = clampf((p - 0.43) / 0.14, 0.0, 1.0) * TAU
			position_value.y += sin((p - 0.43) / 0.14 * PI) * 0.30
		_update_donut(data, position_value, roll, present)
	for t in range(mini(3, trays.size())):
		var donuts_in_tray: Array = trays[t] if trays[t] is Array else []
		for j in range(donuts_in_tray.size()):
			if not donuts_in_tray[j] is Dictionary:
				continue
			var layer: int = j / 6
			var index_value: int = j % 6
			var at: Vector3 = _tray_positions[t] + Vector3(-0.64 + float(index_value % 3) * 0.64, 0.095 + float(layer) * 0.14, -0.31 + float(index_value / 3) * 0.62)
			if layer > 0:
				at.x += 0.05 if layer % 2 else -0.04
			_update_donut(donuts_in_tray[j], at, 0.0, present)
	for id_value in _donuts.keys():
		if not present.has(id_value):
			var old: Node3D = _donuts[id_value]
			old.queue_free()
			_donuts.erase(id_value)
	for i in range(3):
		_tray_rims[i].material_override = _mat["selected" if i == _selected else "steel_light"]
		_tray_lamps[i].material_override = _mat["bulb" if i == _selected else "steel_dark"]
	var speed_owned: bool = false
	var gold_owned: bool = false
	for key in owned:
		var id_text: String = str(key).to_lower()
		if "speed" in id_text or "turbo" in id_text or "motor" in id_text:
			speed_owned = true
		if "gold" in id_text or "lucky" in id_text:
			gold_owned = true
	_upgrade_nodes["turbo"].visible = speed_owned
	_upgrade_nodes["golden"].visible = gold_owned

func _update_donut(data: Dictionary, at: Vector3, roll: float, present: Dictionary) -> void:
	var id_value: int = int(data.get("id", 0))
	present[id_value] = true
	if _donuts.has(id_value):
		var existing: Node3D = _donuts[id_value]
		if str(existing.get_meta("recipe")) != str(data.get("recipe", "cinnamon")) or bool(existing.get_meta("golden")) != bool(data.get("golden", false)):
			existing.queue_free()
			_donuts.erase(id_value)
	if not _donuts.has(id_value):
		_donuts[id_value] = _create_donut(data, at)
	var node: Node3D = _donuts[id_value]
	node.set_meta("target", at)
	node.set_meta("roll", roll)

func set_title_view(enabled: bool) -> void:
	_title_view = enabled
	if enabled:
		_title_demo_trays = [[], [], []]
		for t in range(3):
			for i in range(6):
				_title_demo_trays[t].append({"id": -1000 - t * 6 - i, "recipe": ["cinnamon", "powdered", "cocoa"][t], "golden": t == 2 and i == 4})
	elif _loaded:
		sync_state([], [[], [], []], 0, {})
	if not enabled and is_instance_valid(camera):
		camera.position = Vector3(7.2, 8.0, 13.8)
		camera.look_at(Vector3(0.0, 2.1, 0.1), Vector3.UP)

func set_venue(config: Dictionary) -> void:
	## The first playtest ships only the fairground. Scenery and lighting are
	## independently configurable so later venue progression can replace them.
	if not _loaded:
		return
	_venue_root.set_meta("venue_name", str(config.get("name", "Golden Hour Fairground")))
	if config.has("sky_color"):
		_environment.background_color = Color(config["sky_color"])
	if config.has("ambient_color"):
		_environment.ambient_light_color = Color(config["ambient_color"])
	if config.has("light_color"):
		_key_light.light_color = Color(config["light_color"])

func get_camera() -> Camera3D:
	return camera

func get_tray_screen_position(index: int) -> Vector2:
	if not is_instance_valid(camera):
		return Vector2.ZERO
	return camera.unproject_position(_tray_positions[clampi(index, 0, 2)] + Vector3(0, 0.15, 0))

func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_camera_trauma = 0.0

func burst_sale(tray_index: int, amount: float, tier: int = 0) -> void:
	if not _loaded:
		return
	tier = clampi(tier, 0, 3)
	var origin: Vector3 = _tray_positions[clampi(tray_index, 0, 2)] + Vector3(0, 0.25, 0)
	var particle_count: int = [7, 16, 30, 48][tier]
	if _reduced_motion:
		particle_count = 3 + tier * 2
	# A hard bound makes repeated/rapid sales safe without long-lived emitters.
	while _sale_effects.size() + particle_count + 1 > MAX_SALE_EFFECTS:
		var oldest: Dictionary = _sale_effects.pop_front()
		var old_node: Node3D = oldest["node"]
		old_node.queue_free()
	for i in range(particle_count):
		var particle: MeshInstance3D
		if tier >= 2 and i % 3 == 0:
			particle = _cylinder(origin, 0.074, 0.025, "coin")
			particle.rotation_degrees = Vector3(65, float(i) * 32.0, 0)
		else:
			particle = _box(origin, Vector3(0.05, 0.11, 0.012) * (1.0 + float(tier) * 0.10), "gold_light" if i % 3 else ("bulb_teal" if tier == 3 else "cream"))
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var energy: float = (0.65 if _reduced_motion else 1.0) * (1.0 + float(tier) * 0.30)
		_sale_effects.append({"node": particle, "velocity": Vector3(_rng.randf_range(-1.35, 1.35), _rng.randf_range(1.4, 2.7), _rng.randf_range(-0.7, 0.8)) * energy, "age": 0.0, "lifetime": 0.95 + float(tier) * 0.24, "spin": 0.0 if _reduced_motion else _rng.randf_range(-9.0, 9.0)})
	var value_label: Label3D = _label("+$" + str(int(amount)), origin + Vector3(0, 0.45, 0), 48 + tier * 9, Color("ffe8a0"))
	value_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	value_label.outline_size = 7
	value_label.outline_modulate = Color("53392e")
	_sale_effects.append({"node": value_label, "velocity": Vector3(0, 0.45 if _reduced_motion else 0.70, 0), "age": 0.0, "lifetime": 1.20 + float(tier) * 0.18, "spin": 0.0})
	if not _reduced_motion:
		_camera_trauma = minf(0.72, _camera_trauma + [0.0, 0.16, 0.38, 0.63][tier])
	_celebration_tier = maxi(_celebration_tier if _celebration_time > 0.0 else 0, tier)
	_celebration_duration = 0.75 + float(_celebration_tier) * 0.52
	_celebration_time = _celebration_duration
	_score_lights[clampi(tray_index, 0, 2)].set_meta("burst", true)

func celebrate_goal() -> void:
	if not _loaded:
		return
	_celebration_tier = 3
	_celebration_duration = 2.4
	_celebration_time = _celebration_duration
	if not _reduced_motion:
		_camera_trauma = maxf(_camera_trauma, 0.35)

func _update_celebration(delta: float) -> void:
	_camera_trauma = maxf(0.0, _camera_trauma - delta * 1.45)
	_celebration_time = maxf(0.0, _celebration_time - delta)
	var envelope: float = smoothstep(0.0, 0.45, _celebration_time)
	for i in range(_score_lights.size()):
		var light: OmniLight3D = _score_lights[i]
		var pulse: float = 1.0 if _reduced_motion else (0.72 + 0.28 * sin(_time * 7.0 - float(i) * 0.8))
		light.light_energy = envelope * pulse * (0.28 + float(_celebration_tier) * 0.55)
	for i in range(_marquee_bulbs.size()):
		var material_key: String = "bulb"
		if _celebration_time > 0.0 and _celebration_tier > 0:
			var chase: float = 1.0 if _reduced_motion else sin(_time * 5.0 - float(i) * 0.52)
			material_key = "bulb_hot" if chase > -0.15 else "bulb_dim"
			if _celebration_tier == 3 and chase > 0.7 and i % 3 == 0:
				material_key = "bulb_teal"
		_marquee_bulbs[i].material_override = _mat[material_key]
	var base_position: Vector3 = Vector3(5.8, 8.0, 13.8) if _title_view else Vector3(7.2, 8.0, 13.8)
	var focus: Vector3 = Vector3(-1.4, 2.1, 0.1) if _title_view else Vector3(0.0, 2.1, 0.1)
	if _title_view and not _reduced_motion:
		base_position.x += sin(_time * 0.15) * 0.22
	var shake: float = 0.0 if _reduced_motion else _camera_trauma * _camera_trauma
	var offset: Vector3 = Vector3(sin(_time * 71.0) * 0.20, cos(_time * 83.0) * 0.12, sin(_time * 47.0) * 0.05) * shake
	camera.position = base_position + offset
	camera.look_at(focus + offset * 0.3, Vector3.UP)
	camera.rotation.z += sin(_time * 67.0) * shake * 0.012

func _process(delta: float) -> void:
	if not _loaded:
		return
	_time += delta
	_update_celebration(delta)
	_fan.rotation.z = _time * 2.5
	_flipper.rotation.z = floorf(_time * 0.7) * PI + smoothstep(0.64, 0.86, fmod(_time * 0.7, 1.0)) * PI
	_hopper_piston.position.y = 4.30 + sin(_time * 3.4) * 0.055
	_clock_hand.rotation.z = -_time * 0.01
	for bubble in _bubble_nodes:
		var phase: float = float(bubble.get_meta("phase"))
		var s: float = 0.55 + 0.45 * sin(_time * 4.0 + phase)
		bubble.scale = Vector3(s, 0.3 * s, s)
	for puff in _steam_nodes:
		var life: float = fmod(_time * 0.22 + float(puff.get_meta("phase")), 1.0)
		puff.position = Vector3(float(puff.get_meta("start_x")) + sin(life * 4.0) * 0.18, 2.38 + life * 1.3, -0.40 - life * 0.25)
		puff.scale = Vector3.ONE * sin(life * PI) * (1.0 + life * 2.4)
	for id_value in _donuts:
		var node: Node3D = _donuts[id_value]
		var target: Vector3 = node.get_meta("target")
		var age: float = float(node.get_meta("age")) + delta
		node.set_meta("age", age)
		node.position = node.position.lerp(target, minf(1.0, delta * 15.0))
		node.rotation = Vector3(0, float(node.get_meta("yaw")), float(node.get_meta("roll")))
		var entry_scale: float = minf(1.0, age * 6.0)
		node.scale = Vector3.ONE * entry_scale
	for i in range(_sale_effects.size() - 1, -1, -1):
		var effect: Dictionary = _sale_effects[i]
		var age: float = float(effect["age"]) + delta
		effect["age"] = age
		var node: Node3D = effect["node"]
		var velocity: Vector3 = effect["velocity"]
		node.position += velocity * delta
		node.rotation.z += float(effect["spin"]) * delta
		if node is MeshInstance3D:
			velocity.y -= delta * 3.0
			effect["velocity"] = velocity
		var life: float = age / float(effect["lifetime"])
		node.scale = Vector3.ONE * (1.0 - smoothstep(0.65, 1.0, life))
		if age >= float(effect["lifetime"]):
			node.queue_free()
			_sale_effects.remove_at(i)
	for person in _customers:
		person.rotation.z = sin(_time * 0.7 + float(person.get_meta("phase"))) * 0.025
	# Tiny title-screen drift, fixed steady gameplay camera for precise controls.
	if _title_view:
		var demo_active: Array = []
		for i in range(10):
			var progress_value: float = _time * 0.075 + float(i) * 0.1
			demo_active.append({"id": -100 - i - int(floorf(progress_value)) * 10, "recipe": ["cinnamon", "powdered", "cocoa"][i % 3], "golden": i == 8, "progress": fmod(progress_value, 1.0), "tray": i % 3})
		sync_state(demo_active, _title_demo_trays, 1, {"golden_sixth": 1})
