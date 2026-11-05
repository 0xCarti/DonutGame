extends Node3D
const FoodGeometry = preload("res://scripts/stand_food_physics.gd")
const FryerFire = preload("res://scripts/fryer_fire.gd")
signal delivery_settled(delivery_id: int, kept: bool)
signal stock_spilled(delivery_id: int)
signal action_finished
signal gag_sound(id: String)
signal air_mail_caught(stock_id: int)
var _expansion: RefCounted
var _air_mail_offer_id: int = 0
var _air_mail_accepted: bool = false
## First-person Golden Hour stand. Original meshes and material generators reused
## from the original art library; all interaction staging is specific to this game.
var camera: Camera3D
const CAMERA_REFERENCE_ASPECT: float = 1.6
const CAMERA_VERTICAL_FOV: float = 70.0
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
var _discharge_chute: Node3D
var _discharge_chute_tip: Marker3D
var _discharge_chute_floor: MeshInstance3D
var _machine_donuts: Array[Node3D] = []
var _bulk_donuts: Array[Node3D] = []
var _food: Node3D
var _tray_visual: Node3D
var _station_meshes: Dictionary = {}
var _station_overlays: Dictionary = {}
var _highlight_strengths: Dictionary = {}
var _heat_knobs: Array[Node3D] = []
var _dial_presses: Array[float] = [0.0, 0.0]
var _dial_velocities: Array[float] = [0.0, 0.0]
var _arm_rigs: Array[Dictionary] = []
var _hand_tracks: Array[Dictionary] = []
var _finger_joints: Array[Array] = []
var _finger_chains: Array[Array] = []
var _thumb_chains: Array[Array] = []
var _player_glove_materials: Dictionary = {}
const UPPER_ARM_LENGTH: float = 1.12
const FOREARM_LENGTH: float = 1.04
const GRASP_TIME: float = 0.20
const ACTION_DURATIONS: Dictionary = {"bag": 0.92, "bucket": 0.92, "scoop": 0.80, "supply": 1.02, "package": 1.14, "cinnamon": 1.24, "powdered": 1.24, "serve": 0.90, "tray_shake": 1.06, "punch": 0.36, "bell": 0.30, "extinguish": 1.46}
const JAB_IMPACT_TIME: float = 0.12
const JAB_RECOIL_DURATION: float = 0.72
var _motions: Array[Dictionary] = []
var _tool_home: Transform3D
var _shakers: Dictionary = {}
var _shaker_homes: Dictionary = {}
var _package_stacks: Dictionary = {}
var _paper_bag_scene: PackedScene
var _gag_root: Node3D
var _gags: Array[Dictionary] = []
var _gag_serial: int = 0
var _fire_visual: Node3D
var _foam_visual: Node3D
var _fire_light: OmniLight3D
var _extinguisher: Node3D
var _extinguisher_home: Transform3D
var _bell: Node3D
var _bell_button: Node3D
var _neighbor_bell: Node3D
var _jab_marker: Node3D
var _punch_person: Node3D
var _highlighted_customer: Node3D
var _extinguish_fire_hold: bool = false
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
var _operator_preview_poses: Array[Transform3D] = []
var _detail_lights: Array[Light3D] = []
var _bg_walkers: Array[Dictionary] = []
var _quality: int = 2
var _mobile_quality: bool = false
var _sunlight: DirectionalLight3D
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
const DISCHARGE_HORIZONTAL_LENGTH: float = 1.85
const DISCHARGE_DROP: float = 0.08

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.seed = 7132026
	if ResourceLoader.exists("res://assets/fonts/Fredoka-Medium.ttf"):
		_world_font = load("res://assets/fonts/Fredoka-Medium.ttf")
	_make_materials()
	_stand_materials()
	_apply_authored_materials()
	_stand_lighting()
	_make_fairground()
	_build_counter()
	_build_compact_machine()
	_make_donut_resources()
	_build_stations()
	_build_view()
	_build_hands()
	_build_authored_details()
	_build_slapstick_props()
	_batch_static_venue()
	_food = load("res://scripts/stand_food_physics.gd").new()
	add_child(_food)
	_food.configure(self)
	_food.delivery_settled.connect(func(delivery_id: int, kept: bool): delivery_settled.emit(delivery_id, kept))
	_food.stock_spilled.connect(func(delivery_id: int): stock_spilled.emit(delivery_id))
	_expansion = load("res://scripts/stand_expansion.gd").new()
	_expansion.configure(self)
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


func _apply_authored_materials() -> void:
	for kind in ["counter_wood", "kraft_paper"]:
		var prefix: String = "res://assets/materials/" + kind
		if not ResourceLoader.exists(prefix + "_color.png"): continue
		var keys: Array = ["wood", "wood_light", "wood_dark"] if kind == "counter_wood" else ["paper_bag", "paper_fold", "package_inside"]
		for key in keys:
			var material: StandardMaterial3D = _mat[key]
			material.albedo_texture = load(prefix + "_color.png")
			material.normal_enabled = true
			material.normal_texture = load(prefix + "_normal.png")
			material.normal_scale = 0.45 if kind == "counter_wood" else 0.30
			material.roughness_texture = load(prefix + "_roughness.png")
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.roughness = 1.0
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			material.uv1_triplanar = kind == "counter_wood"
			material.uv1_scale = Vector3.ONE * (0.65 if kind == "counter_wood" else 1.0)
		_mat["wood_light"].albedo_color = Color(0.80, 0.82, 0.86)
		_mat["wood"].albedo_color = Color(0.67, 0.70, 0.75)
		_mat["wood_dark"].albedo_color = Color(0.32, 0.36, 0.40)
		_mat["paper_bag"].albedo_color = Color(1.0, 0.98, 0.92)
		_mat["paper_fold"].albedo_color = Color(0.79, 0.77, 0.72)
		_mat["package_inside"].albedo_color = Color(0.71, 0.68, 0.62)
	for key in ["steel", "steel_light", "steel_dark"]:
		_mat[key].normal_scale = 0.42
		_mat[key].roughness = 0.54 if key == "steel_light" else 0.68

func _bake_surface(kind: String) -> Dictionary:
	# Offline original microdetail provides real 1024px surface information and
	# avoids rebuilding these textures every time the stand opens.
	var prefix: String = "res://assets/materials/detail_" + kind
	if ResourceLoader.exists(prefix + "_color.png"):
		return {"color": load(prefix + "_color.png"), "normal": load(prefix + "_normal.png"), "roughness": load(prefix + "_roughness.png")}
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
	label.font_size = size * 3
	if _world_font != null:
		label.font = _world_font
	label.pixel_size = 0.002
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
	# This fixed upper exit ends at the swivel bearing. The delivery trough below
	# it moves as one rigid assembly; no second fixed floor crosses its sweep.
	var exit_start: Vector3 = Vector3(4.50, 2.65, -0.35)
	var exit_end: Vector3 = Vector3(4.50, (2.175 - 1.01) / 0.48, (-0.35 + 0.60) / 0.48)
	var exit_direction: Vector3 = (exit_end - exit_start).normalized()
	var chute: MeshInstance3D = _box((exit_start + exit_end) * 0.5, Vector3(0.80, 0.06, exit_start.distance_to(exit_end)), "steel_light")
	chute.look_at(chute.position - exit_direction, Vector3.UP)
	for side in [-1.0, 1.0]:
		var offset: Vector3 = Vector3(side * 0.40, 0.075, 0)
		_tube(exit_start + offset, exit_end + offset, 0.028, "steel")
	_tube(Vector3(5.2, 2.31, -1.24), Vector3(5.2, 3.11, -1.24), 0.04, "steel_light")
	_tube(Vector3(5.2, 3.11, -1.24), Vector3(5.2, 3.11, 1.15), 0.04, "steel_light")
	_tube(Vector3(5.2, 3.11, 1.15), Vector3(5.2, 2.31, 1.15), 0.04, "steel_light")
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
	_donut_mesh = _organic_donut_mesh(FoodGeometry.MODEL_RING_RADIUS, FoodGeometry.MODEL_TUBE_RADIUS, FoodGeometry.MODEL_HALF_HEIGHT)
	_coating_mesh = _organic_donut_mesh(FoodGeometry.MODEL_RING_RADIUS, FoodGeometry.MODEL_TUBE_RADIUS + 0.0015, FoodGeometry.MODEL_HALF_HEIGHT + 0.0015)
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
			var phi: float = _rng.randf_range(PI * 0.25, PI * 0.75)
			var radius: float = FoodGeometry.MODEL_RING_RADIUS + cos(phi) * FoodGeometry.MODEL_TUBE_RADIUS
			var position_value: Vector3 = Vector3(cos(angle) * radius, sin(phi) * FoodGeometry.MODEL_HALF_HEIGHT + 0.003, sin(angle) * radius)
			var basis_value: Basis = Basis(Vector3.UP, _rng.randf_range(0, TAU))
			mm.set_instance_transform(i, Transform3D(basis_value, position_value))
		_sprinkle_meshes[recipe] = mm


func _organic_donut_mesh(major: float, minor: float, half_height: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var rings: int = 40
	var sides: int = 14
	for i in range(rings + 1):
		var theta: float = float(i) / float(rings) * TAU
		var outer: float = (major + minor) * (1.0 + sin(theta * 5.0 + 0.7) * 0.028 + cos(theta * 9.0) * 0.012)
		var inner: float = (major - minor) * (1.0 + sin(theta * 3.0 + 0.4) * 0.20)
		var center: float = (outer + inner) * 0.5
		var width: float = (outer - inner) * 0.5
		var height: float = half_height * (1.0 + sin(theta * 5.0 + 0.7) * 0.035)
		for j in range(sides + 1):
			var phi: float = float(j) / float(sides) * TAU
			var radial: float = center + cos(phi) * width
			vertices.append(Vector3(cos(theta) * radial, sin(phi) * height + sin(theta * 3.0) * 0.0015, sin(theta) * radial))
			normals.append(Vector3(cos(theta) * cos(phi) / width, sin(phi) / height, sin(theta) * cos(phi) / width).normalized())
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
	body.scale = Vector3.ONE
	var icing: MeshInstance3D = _mesh_node(_coating_mesh, Vector3.ZERO, _powder_sugar if recipe == "powdered" else _mat["golden" if is_golden else recipe], node)
	icing.scale = Vector3.ONE
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
	_sunlight = sunlight
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
	_apply_quality_lighting()

func _build_counter() -> void:
	# Four substrate panels and individually cut boards leave a genuine opening
	# through the worktop. Its dimensions also define the physical aperture.
	var opening: Rect2 = Rect2(-3.70, 1.84, 1.10, 1.02)
	var counter: Rect2 = Rect2(-5.10, -1.85, 10.20, 5.10)
	var panels: Array[Rect2] = [
		Rect2(counter.position, Vector2(opening.position.x - counter.position.x, counter.size.y)),
		Rect2(Vector2(opening.end.x, counter.position.y), Vector2(counter.end.x - opening.end.x, counter.size.y)),
		Rect2(Vector2(opening.position.x, counter.position.y), Vector2(opening.size.x, opening.position.y - counter.position.y)),
		Rect2(Vector2(opening.position.x, opening.end.y), Vector2(opening.size.x, counter.end.y - opening.end.y))]
	for panel in panels:
		var substrate: MeshInstance3D = _box(Vector3(panel.get_center().x, 1.48, panel.get_center().y), Vector3(panel.size.x, 0.27, panel.size.y), "wood_dark")
		substrate.set_meta("counter_panel", true)
	for i in range(17):
		var plank: Rect2 = Rect2(-4.8 + float(i) * 0.6 - 0.2925, -1.85, 0.585, 5.10)
		for panel in panels:
			var piece: Rect2 = plank.intersection(panel)
			if not piece.has_area(): continue
			var board: MeshInstance3D = _box(Vector3(piece.get_center().x, 1.65, piece.get_center().y), Vector3(piece.size.x, 0.10, piece.size.y), "wood_light" if i % 3 else "wood")
			board.set_meta("counter_panel", true)
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
	_build_discharge_chute()

func _build_discharge_chute() -> void:
	var pivot: Vector3 = Vector3(-0.19, 2.22, -0.35)
	var length: float = Vector2(DISCHARGE_HORIZONTAL_LENGTH, DISCHARGE_DROP).length()
	# Bearing and gear housing remain mounted to the machine. The slim support
	# arm and trough are children of the rotating assembly, not rebuilt meshes.
	_cylinder(pivot + Vector3(0, -0.15, 0), 0.105, 0.18, "steel_dark")
	_cylinder(pivot + Vector3(0, -0.065, 0), 0.145, 0.035, "steel_light")
	_box(pivot + Vector3(0.18, -0.16, -0.04), Vector3(0.25, 0.20, 0.23), "steel_dark")
	_tube(pivot + Vector3(0, -0.16, 0), pivot + Vector3(0.17, -0.16, 0), 0.035, "brass")
	_discharge_chute = Node3D.new()
	_discharge_chute.name = "SweepingDeliveryChute"
	_discharge_chute.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(_discharge_chute)
	_discharge_chute_floor = _box(Vector3(0, -FoodGeometry.CRUST_RADIUS - 0.0125, length * 0.5), Vector3(0.40, 0.025, length), "steel_light", _discharge_chute)
	_discharge_chute_floor.name = "DeliveryFloor"
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.205, -0.025, length * 0.5), Vector3(0.025, 0.080, length), "steel", _discharge_chute)
		_tube(Vector3(side * 0.205, 0.015, 0), Vector3(side * 0.205, 0.015, length), 0.013, "steel_light", _discharge_chute)
	_box(Vector3(0, -0.094, 0.26), Vector3(0.065, 0.055, 0.57), "steel_dark", _discharge_chute)
	_cylinder(Vector3(0, -0.075, 0), 0.067, 0.035, "brass", _discharge_chute)
	_discharge_chute_tip = Marker3D.new()
	_discharge_chute_tip.name = "ReleaseCenter"
	_discharge_chute_tip.position = Vector3(0, 0, length)
	_discharge_chute.add_child(_discharge_chute_tip)
	var angle: float = deg_to_rad(45.0)
	set_discharge_chute_pose(pivot, pivot + Vector3(-sin(angle) * DISCHARGE_HORIZONTAL_LENGTH, -DISCHARGE_DROP, cos(angle) * DISCHARGE_HORIZONTAL_LENGTH))
	_discharge_chute.reset_physics_interpolation()

func set_discharge_chute_pose(start: Vector3, end: Vector3) -> void:
	if not is_instance_valid(_discharge_chute) or start.is_equal_approx(end):
		return
	# Physics owns the clock. This exact transform is shared by the guided food
	# and visible trough, including pause/jam, with interpolation only at render.
	var forward: Vector3 = (end - start).normalized()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var up: Vector3 = forward.cross(right).normalized()
	_discharge_chute.transform = Transform3D(Basis(right, up, forward), start)

func _build_stations() -> void:
	_prewarm_paper_bag()
	# Bulk tray contains visible individual donuts, with a scoop resting beside it.
	_tray_visual = Node3D.new()
	_tray_visual.name = "CatchTray"
	_tray_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(_tray_visual)
	_box(_supply_anchor - Vector3(0, 0.06, 0), Vector3(2.25, 0.12, 1.46), "steel_dark", _tray_visual)
	_box(_supply_anchor + Vector3(0, 0.01, 0), Vector3(2.12, 0.035, 1.32), "tray_paper", _tray_visual)
	for z in [-0.72, 0.72]:
		_box(_supply_anchor + Vector3(0, 0.08, z), Vector3(2.28, 0.22, 0.055), "steel_light", _tray_visual)
	for x in [-1.12, 1.12]:
		_box(_supply_anchor + Vector3(x, 0.08, 0), Vector3(0.055, 0.22, 1.46), "steel_light", _tray_visual)
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
		_make_flat_paper_bag(bag)
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
	# Flush drop-through scrap well: open rim, deep walls, and an inset floor.
	# The opening is cut through both the wood boards and the collision surface.
	var discard: Node3D = Node3D.new()
	discard.name = "RecessedDiscard"
	discard.position = Vector3(-3.15, 1.70, 2.35)
	add_child(discard)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.585, 0.008, 0), Vector3(0.07, 0.025, 1.16), "steel_light", discard)
		_box(Vector3(0, 0.008, side * 0.545), Vector3(1.10, 0.025, 0.07), "steel_light", discard)
		_box(Vector3(side * 0.5675, -0.48, 0), Vector3(0.035, 0.94, 1.02), "steel_dark", discard)
		_box(Vector3(0, -0.48, side * 0.5275), Vector3(1.10, 0.94, 0.035), "steel_dark", discard)
		for depth in [-0.545, 0.545]:
			_cylinder(Vector3(side * 0.585, 0.022, depth), 0.014, 0.004, "steel_dark", discard)
	_box(Vector3(0, -0.965, 0), Vector3(1.10, 0.04, 1.02), "black", discard)
	_station("trash", Vector3(-3.15, 1.72, 2.35), Vector3(1.24, 0.20, 1.16), "DISCARD", false)
	_register_highlight("trash", discard)
	var discard_label: Label3D = _label("DISCARD", Vector3(-3.15, 1.708, 3.03), 16, Color("6e4c32"))
	discard_label.rotation_degrees.x = -90.0
	_station_labels["trash"] = discard_label

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
	if kind != "bucket":
		if _paper_bag_scene == null: _prewarm_paper_bag()
		var bag: Node3D = _paper_bag_scene.instantiate() as Node3D
		parent.add_child(bag)
		if _expansion != null: _expansion.decorate_package(bag, kind)
		return bag
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
	if _expansion != null: _expansion.decorate_package(package, kind)
	return package

func _prewarm_paper_bag() -> void:
	if _paper_bag_scene != null: return
	# Build the detailed paper once while the stand loads. Each order receives
	# independent nodes and overlays while sharing immutable meshes/materials.
	# PackedScene retains resources only; the temporary template is freed here.
	var template: Node3D = Node3D.new()
	template.name = "PaperBag"
	_make_paper_bag(template)
	for child in template.get_children(): child.owner = template
	_paper_bag_scene = PackedScene.new()
	var packed: Error = _paper_bag_scene.pack(template)
	template.free()
	assert(packed == OK, "The paper bag template must be packable")

func _bag_surface_point(u: float, v: float) -> Vector3:
	var angle: float = u * TAU
	var c: float = cos(angle)
	var s: float = sin(angle)
	var half_width: float = 0.270 + 0.025 * sin(minf(v * 2.5, PI * 0.5))
	var depth: float = 0.205 + 0.037 * sin(v * PI) + 0.01 * v
	var x: float = signf(c) * pow(absf(c), 0.32) * half_width
	var z: float = signf(s) * pow(absf(s), 0.32) * depth
	# Soft front/back panels bulge; both side gussets crease inward at the mouth.
	x -= signf(c) * exp(-pow(z / 0.12, 2.0)) * pow(absf(c), 8.0) * (0.004 + 0.045 * smoothstep(0.60, 1.0, v))
	x += sin(angle * 9.0 + v * 8.0) * 0.004 * sin(v * PI)
	z += cos(angle * 7.0 - v * 10.0) * 0.004 * sin(v * PI)
	var lip_height: float = 0.58 - 0.035 * s + 0.006 * sin(angle * 7.0) + 0.003 * sin(angle * 19.0)
	return Vector3(x, 0.03 + v * lip_height, z)

func _bag_surface_normal(u: float, v: float) -> Vector3:
	var along: Vector3 = _bag_surface_point(u + 0.001, v) - _bag_surface_point(u - 0.001, v)
	var vertical: Vector3 = _bag_surface_point(u, v + 0.001) - _bag_surface_point(u, v - 0.001)
	return vertical.cross(along).normalized()

func _make_paper_bag(package: Node3D) -> void:
	# A 2.5 mm open paper shell, rather than four thick rectangular walls.
	for inside in [false, true]:
		var shell: SurfaceTool = SurfaceTool.new()
		shell.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]
		if inside: corners.reverse()
		for row in range(12):
			for segment in range(64):
				for corner in corners:
					var u: float = float(segment + corner.x) / 64.0
					var v: float = float(row + corner.y) / 12.0
					var normal: Vector3 = _bag_surface_normal(u, v)
					shell.set_uv(Vector2(u * 2.0, v))
					shell.set_normal(-normal if inside else normal)
					shell.add_vertex(_bag_surface_point(u, v) - normal * (0.0025 if inside else 0.0))
		shell.generate_tangents()
		var paper: MeshInstance3D = _mesh_node(shell.commit(), Vector3.ZERO, _mat["paper_bag"], package)
		paper.name = "PaperBagInner" if inside else "PaperBagShell"
		paper.set_meta("paper_shell", true)
	var bottom: SurfaceTool = SurfaceTool.new()
	bottom.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lip: SurfaceTool = SurfaceTool.new()
	lip.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(64):
		var u0: float = float(segment) / 64.0
		var u1: float = float(segment + 1) / 64.0
		_surface_triangle(bottom, Vector3(0, 0.03, 0), _bag_surface_point(u0, 0), _bag_surface_point(u1, 0), Vector3.UP)
		var a: Vector3 = _bag_surface_point(u0, 1)
		var b: Vector3 = _bag_surface_point(u1, 1)
		_surface_quad(lip, a, b, b - _bag_surface_normal(u1, 1) * 0.0025, a - _bag_surface_normal(u0, 1) * 0.0025, Vector3.UP)
	_mesh_node(bottom.commit(), Vector3.ZERO, _mat["package_inside"], package).name = "PaperBottom"
	_mesh_node(lip.commit(), Vector3.ZERO, _mat["paper_fold"], package).name = "CrimpedPaperRim"
	# Pressed gusset folds run diagonally from the folded bottom into each side.
	for side_u in [0.0, 0.5]:
		for direction in [-1.0, 1.0]:
			var a: Vector3 = _bag_surface_point(side_u + direction * 0.11, 0.06)
			var b: Vector3 = _bag_surface_point(side_u + direction * 0.018, 0.43)
			var c: Vector3 = _bag_surface_point(side_u, 0.94)
			_tube(a, b, 0.0014, "paper_fold", package)
			_tube(b, c, 0.0012, "paper_fold", package)
	_add_bag_print(package)

func _bag_print_point(uv: Vector2) -> Vector3:
	var x: float = (uv.x - 0.5) * 0.36
	var y: float = 0.47 - uv.y * 0.34
	var v: float = (y - 0.03) / 0.545
	var u: float = 0.25
	for iteration in range(3):
		var half_width: float = 0.270 + 0.025 * sin(minf(v * 2.5, PI * 0.5))
		u = acos(signf(x) * pow(absf(x) / half_width, 1.0 / 0.32)) / TAU
		v = (y - 0.03) / (_bag_surface_point(u, 1).y - 0.03)
	return _bag_surface_point(u, v) + _bag_surface_normal(u, v) * 0.0015

func _add_bag_print(package: Node3D) -> void:
	if not ResourceLoader.exists("res://assets/art/brand_seal.png"):
		_label("GOLDEN\nHOUR", Vector3(0, 0.30, 0.255), 18, Color("6c4130"), package)
		return
	var print_mesh: SurfaceTool = SurfaceTool.new()
	print_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(12):
		for column in range(12):
			for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]:
				var uv: Vector2 = Vector2(column + corner.x, row + corner.y) / 12.0
				print_mesh.set_uv(uv)
				print_mesh.set_normal(Vector3(0, 0, 1))
				print_mesh.add_vertex(_bag_print_point(uv))
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.albedo_texture = load("res://assets/art/brand_seal.png")
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.roughness = 0.98
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var print_node: MeshInstance3D = _mesh_node(print_mesh.commit(), Vector3.ZERO, ink, package)
	print_node.set_meta("branding", true)
	print_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_flat_paper_bag(parent: Node3D) -> void:
	# Thin, slightly curled folded stock, including a pressed gusset and ink seal.
	var sheet: SurfaceTool = SurfaceTool.new()
	sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(8):
		for column in range(8):
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var uv: Vector2 = Vector2(column + corner.x, row + corner.y) / 8.0
				var x: float = (uv.x - 0.5) * 0.65
				var z: float = (uv.y - 0.5) * 0.84
				var y: float = 0.012 + pow(absf(uv.x - 0.5) * 2.0, 4.0) * 0.006 + pow(maxf(0, uv.y - 0.8) * 5.0, 2.0) * 0.010
				sheet.set_uv(uv)
				sheet.set_normal(Vector3.UP)
				sheet.add_vertex(Vector3(x, y, z))
	sheet.generate_tangents()
	var material: StandardMaterial3D = _mat["paper_bag"].duplicate()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_node(sheet.commit(), Vector3.ZERO, material, parent)
	for side in [-1.0, 1.0]:
		_tube(Vector3(side * 0.325, 0.015, -0.40), Vector3(side * 0.325, 0.015, 0.38), 0.0017, "paper_fold", parent)
		_tube(Vector3(side * 0.325, 0.016, 0.26), Vector3(0, 0.016, 0.37), 0.0015, "paper_fold", parent)
	_tube(Vector3(-0.325, 0.016, 0.26), Vector3(0.325, 0.016, 0.26), 0.0014, "paper_fold", parent)
	if _add_brand_decal(parent, Vector3(0, 0.022, -0.05), Vector2(0.34, 0.34)):
		parent.get_child(parent.get_child_count() - 1).rotation_degrees.x = -90.0

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
	shaker.name = "Shaker_" + flavor
	parent.add_child(shaker)
	_cylinder(Vector3(0, 0.29, 0), 0.22, 0.58, "steel", shaker)
	_cylinder(Vector3(0, 0.61, 0), 0.235, 0.08, "steel_light", shaker)
	for y in [0.027, 0.565, 0.655]:
		var rim: TorusMesh = TorusMesh.new()
		rim.inner_radius = 0.218 if y < 0.1 else 0.229
		rim.outer_radius = rim.inner_radius + 0.012
		rim.rings = 40
		rim.ring_segments = 8
		_mesh_node(rim, Vector3(0, y, 0), _mat["steel_light"], shaker)
	_make_shaker_label(flavor, shaker)
	for i in range(5):
		var a: float = float(i) * TAU / 5.0
		_cylinder(Vector3(cos(a) * 0.105, 0.655, sin(a) * 0.105), 0.023, 0.006, "black", shaker)
	return shaker

func _make_shaker_label(flavor: String, parent: Node3D) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(28):
		var u0: float = float(segment) / 28.0
		var u1: float = float(segment + 1) / 28.0
		for uv in [Vector2(u0, 0), Vector2(u1, 1), Vector2(u0, 1), Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1)]:
			var angle: float = (uv.x - 0.5) * 0.60 / 0.223
			surface.set_normal(Vector3(sin(angle), 0, cos(angle)))
			surface.set_uv(uv)
			surface.add_vertex(Vector3(sin(angle) * 0.223, 0.30 + (0.5 - uv.y) * 0.46, cos(angle) * 0.223))
	surface.generate_tangents()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/art/shaker_" + flavor + ".svg")
	material.roughness = 0.93
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.normal_enabled = true
	material.normal_texture = _mat["tray_paper"].normal_texture
	material.normal_scale = 0.12
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var label: MeshInstance3D = _mesh_node(surface.commit(), Vector3.ZERO, material, parent)
	label.name = "PrintedPaperLabel"
	label.set_meta("printed_flavor", flavor)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_view() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 3.45, 5.65)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = CAMERA_VERTICAL_FOV
	camera.near = 0.05
	camera.far = 80.0
	add_child(camera)
	camera.look_at(Vector3(0, 2.28, -1.2), Vector3.UP)
	camera.current = true
	get_viewport().size_changed.connect(_update_camera_framing)
	_update_camera_framing()
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
	# Separate, fixed-length bones solve to the glove. The torso can lean under
	# the counter; the sleeve never scales to bridge the whole camera-to-tool gap.
	for side in [-1.0, 1.0]:
		var wrist: Vector3 = Vector3(side * 0.43, -0.74, -1.35)
		var hand: Node3D = Node3D.new()
		hand.position = wrist
		_view_hands.add_child(hand)
		_hands.append(hand)
		var upper: MeshInstance3D = _mesh_node(_make_sleeve_mesh(UPPER_ARM_LENGTH, false), Vector3.ZERO, _mat["sleeve"])
		var fore: MeshInstance3D = _mesh_node(_make_sleeve_mesh(FOREARM_LENGTH, true), Vector3.ZERO, _mat["sleeve"])
		var elbow: MeshInstance3D = _sphere(Vector3.ZERO, 0.103, "sleeve")
		var upper_material: ShaderMaterial = _arm_material(false)
		var fore_material: ShaderMaterial = _arm_material(true)
		upper.material_override = upper_material
		fore.material_override = fore_material
		elbow.material_override = upper_material
		for segment in [upper, fore, elbow]: segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arm_rigs.append({"upper": upper, "fore": fore, "joint": elbow, "upper_material": upper_material, "fore_material": fore_material, "shoulder": Vector3.ZERO, "elbow": Vector3.ZERO, "wrist": Vector3.ZERO})
		_hand_tracks.append({"node": null, "from": hand.global_transform, "age": 1.0, "duration": GRASP_TIME})
		_build_player_glove(hand, side)
	_scoop_pose = Transform3D(Basis.from_euler(Vector3(deg_to_rad(12), deg_to_rad(-10), deg_to_rad(-5))).scaled(Vector3.ONE * 0.78), Vector3(0.48, -0.62, -1.64))
	_package_pose = Transform3D(Basis.from_euler(Vector3(deg_to_rad(6), deg_to_rad(-12), 0)).scaled(Vector3.ONE * 0.78), Vector3(0.43, -0.82, -1.64))
	_update_hands(1.0)

func _build_player_glove(hand: Node3D, side: float) -> void:
	var palm_material: ShaderMaterial = _player_glove_material("palm")
	var finger_material: ShaderMaterial = _player_glove_material("finger")
	# Cross sections follow the narrow wrist, palm heel and metacarpal fan. This
	# gives the glove a hand silhouette instead of a sphere with tubes attached.
	var palm: MeshInstance3D = _mesh_node(_hand_loft([
		Vector4(0.031, 0.014, 0.001, 0.001), Vector4(0.025, 0.014, 0.054, 0.031),
		Vector4(0.002, 0.016, 0.061, 0.034), Vector4(-0.033, 0.020, 0.077, 0.034),
		Vector4(-0.075, 0.025, 0.082, 0.031), Vector4(-0.111, 0.027, 0.079, 0.027),
		Vector4(-0.137, 0.025, 0.070, 0.022), Vector4(-0.148, 0.023, 0.001, 0.001)
	]), Vector3.ZERO, palm_material, hand)
	palm.name = "AnatomicalPalm"
	# Thenar pad and a slimmer hypothenar edge make the thumbs genuinely opposed
	# and distinguish left from right, even when both gloves are at rest.
	_hand_ellipsoid(hand, Vector3(-side * 0.056, 0.006, -0.044), Vector3(0.036, 0.028, 0.055), palm_material, "ThumbPad")
	_hand_ellipsoid(hand, Vector3(side * 0.057, 0.016, -0.072), Vector3(0.025, 0.024, 0.055), palm_material, "PalmEdge")
	var cuff: MeshInstance3D = _mesh_node(_hand_loft([
		Vector4(0.060, 0.012, 0.059, 0.038), Vector4(0.056, 0.012, 0.066, 0.043),
		Vector4(0.048, 0.012, 0.066, 0.043), Vector4(0.042, 0.012, 0.061, 0.038),
		Vector4(0.018, 0.014, 0.059, 0.034), Vector4(0.010, 0.015, 0.061, 0.034)
	]), Vector3.ZERO, _player_glove_material("cuff"), hand)
	cuff.name = "RolledGloveCuff"
	var roots: Array = []
	var fingers: Array = []
	var proportions: Array = [Vector3(0.043, 0.029, 0.021), Vector3(0.048, 0.032, 0.023), Vector3(0.045, 0.030, 0.021), Vector3(0.034, 0.023, 0.018)]
	var starts: Array = [Vector3(-0.055, 0.027, -0.126), Vector3(-0.018, 0.030, -0.140), Vector3(0.019, 0.028, -0.137), Vector3(0.054, 0.023, -0.119)]
	for digit in range(4):
		var root_joint: Node3D = Node3D.new()
		root_joint.name = ["Index", "Middle", "Ring", "Little"][digit]
		root_joint.position = Vector3(starts[digit].x * side, starts[digit].y, starts[digit].z)
		root_joint.rotation.y = side * [-0.055, -0.015, 0.025, 0.10][digit]
		hand.add_child(root_joint)
		roots.append(root_joint)
		var joints: Array = [root_joint]
		var parent_joint: Node3D = root_joint
		var radius: float = 0.0176 if digit < 3 else 0.0148
		for phalanx in range(3):
			var length: float = proportions[digit][phalanx]
			var bone_radius: float = radius * [1.0, 0.87, 0.75][phalanx]
			var segment: MeshInstance3D = _mesh_node(_finger_segment_mesh(length, bone_radius), Vector3.ZERO, finger_material, parent_joint)
			segment.name = "Phalanx%d" % (phalanx + 1)
			if phalanx < 2:
				var next: Node3D = Node3D.new()
				next.name = "PIP" if phalanx == 0 else "DIP"
				next.position = Vector3(0, 0, -length)
				parent_joint.add_child(next)
				joints.append(next)
				parent_joint = next
		fingers.append(joints)
		_hand_ellipsoid(hand, root_joint.position + Vector3(0, 0.008, 0.008), Vector3(radius * 1.02, 0.012, 0.021), palm_material, "Knuckle%d" % digit)
	_finger_joints.append(roots)
	_finger_chains.append(fingers)
	var thumb: Node3D = Node3D.new()
	thumb.name = "OpposedThumb"
	thumb.position = Vector3(-side * 0.059, 0.008, -0.036)
	thumb.rotation = Vector3(-0.12, side * 0.84, -side * 0.16)
	hand.add_child(thumb)
	_mesh_node(_finger_segment_mesh(0.047, 0.023), Vector3.ZERO, finger_material, thumb).name = "ThumbProximal"
	var thumb_tip: Node3D = Node3D.new()
	thumb_tip.name = "ThumbIP"
	thumb_tip.position = Vector3(0, 0, -0.047)
	thumb.add_child(thumb_tip)
	_mesh_node(_finger_segment_mesh(0.038, 0.0185), Vector3.ZERO, finger_material, thumb_tip).name = "ThumbDistal"
	_thumb_chains.append([thumb, thumb_tip])
	hand.set_meta("anatomical_glove", true)

func _hand_ellipsoid(parent: Node3D, at: Vector3, size: Vector3, material: Material, label: String) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var part: MeshInstance3D = _mesh_node(sphere, at, material, parent)
	part.scale = size
	part.name = label
	return part

func _finger_segment_mesh(length: float, radius: float) -> ArrayMesh:
	return _hand_loft([
		Vector4(radius * 0.40, 0, 0.001, 0.001), Vector4(radius * 0.16, 0, radius * 0.87, radius * 0.72),
		Vector4(0, 0, radius, radius * 0.83), Vector4(-length * 0.45, -0.001, radius * 0.96, radius * 0.81),
		Vector4(-length * 0.90, -0.001, radius * 0.91, radius * 0.77), Vector4(-length, -0.001, radius * 0.89, radius * 0.75),
		Vector4(-length - radius * 0.30, -0.001, radius * 0.77, radius * 0.65), Vector4(-length - radius * 0.52, -0.001, radius * 0.445, radius * 0.375),
		Vector4(-length - radius * 0.60, -0.001, 0.001, 0.001)
	])

func _hand_loft(profile: Array) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size() - 1):
		for segment in range(24):
			for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]:
				var row: int = ring + corner.y
				var angle: float = float(segment + corner.x) * TAU / 24.0
				var current: Vector4 = profile[row]
				var before: Vector4 = profile[maxi(0, row - 1)]
				var after: Vector4 = profile[mini(profile.size() - 1, row + 1)]
				var around: Vector3 = Vector3(-sin(angle) * current.z, cos(angle) * current.w, 0)
				var along: Vector3 = Vector3(cos(angle) * (after.z - before.z), after.y - before.y + sin(angle) * (after.w - before.w), after.x - before.x)
				surface.set_normal(along.cross(around).normalized())
				surface.set_uv(Vector2(float(segment + corner.x) / 24.0, float(row) / float(profile.size() - 1)))
				surface.add_vertex(Vector3(cos(angle) * current.z, current.y + sin(angle) * current.w, current.x))
	surface.index()
	return surface.commit()

func _player_glove_material(part: String) -> ShaderMaterial:
	if _player_glove_materials.has(part): return _player_glove_materials[part]
	var shader: Shader = Shader.new()
	shader.code = """shader_type spatial;
uniform vec4 glove_color : source_color = vec4(0.72, 0.70, 0.64, 1.0);
uniform int part = 0;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
 float grain = hash21(floor(UV * vec2(190.0, 145.0))) - 0.5;
 float back = 1.0 - smoothstep(0.12, 0.23, abs(UV.x - 0.25));
 float palm = 1.0 - smoothstep(0.12, 0.23, abs(UV.x - 0.75));
 float crease = 0.0;
 if (part == 0) {
   crease += palm * (1.0 - smoothstep(0.006, 0.020, abs(UV.y - (0.45 + 0.07 * sin(UV.x * 9.0)))));
   crease += palm * (1.0 - smoothstep(0.004, 0.017, abs(UV.y - (0.64 + 0.04 * cos(UV.x * 14.0)))));
   crease += back * (1.0 - smoothstep(0.006, 0.020, abs(UV.y - 0.80))) * 0.5;
 } else if (part == 1) {
   crease += back * (1.0 - smoothstep(0.008, 0.027, abs(UV.y - 0.23)));
   crease += back * (1.0 - smoothstep(0.006, 0.023, abs(UV.y - 0.30))) * 0.6;
 } else {
   crease = (1.0 - smoothstep(0.01, 0.035, abs(UV.y - 0.55))) * 0.5;
 }
 ALBEDO = glove_color.rgb * (1.0 + grain * 0.035 - crease * 0.11);
 ROUGHNESS = 0.72 + grain * 0.06;
 SPECULAR = 0.32;
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("part", 0 if part == "palm" else (1 if part == "finger" else 2))
	_player_glove_materials[part] = material
	return material

func _make_sleeve_mesh(length: float, forearm: bool) -> ArrayMesh:
	# A tailored taper and a few soft cloth folds replace the straight red rods.
	var levels: Array[float] = [-0.5, -0.46, -0.39, -0.27, -0.10, 0.12, 0.28, 0.36, 0.42, 0.5]
	var widths: Array = [0.105, 0.110, 0.104, 0.102, 0.097, 0.094, 0.089, 0.096, 0.084, 0.082] if forearm else [0.124, 0.126, 0.120, 0.117, 0.114, 0.110, 0.108, 0.112, 0.104, 0.102]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(levels.size() - 1):
		for segment in range(16):
			for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0)]:
				var row: int = ring + corner.y
				var angle: float = float(segment + corner.x) * TAU / 16.0
				var radius: float = widths[row] * (1.0 + sin(angle * 3.0 + levels[row] * 4.0) * 0.025)
				surface.set_uv(Vector2(float(segment + corner.x) / 16.0, levels[row] + 0.5))
				surface.add_vertex(Vector3(cos(angle) * radius, levels[row] * length, sin(angle) * radius))
	surface.generate_normals()
	return surface.commit()

func _arm_material(forearm: bool) -> ShaderMaterial:
	# Counter objects use world space, while the close hand presentation must not
	# expose a severed shoulder at distant stations. Fade to a short cuff there;
	# retain the articulated silhouette as the tool returns to the operator.
	var shader: Shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;
uniform float remote_weight = 0.0;
uniform bool forearm = false;
uniform vec4 sleeve_color : source_color = vec4(0.42, 0.105, 0.068, 1.0);
void fragment() {
 float weave = sin(UV.x * 1131.0) * sin(UV.y * 1382.0);
 float visible_weave = clamp(1.0 - length(fwidth(UV)) * 210.0, 0.0, 1.0);
 float seam = 1.0 - smoothstep(0.004, 0.011, abs(UV.x - 0.16));
 ALBEDO = sleeve_color.rgb * (1.0 + weave * visible_weave * 0.045 - seam * 0.12);
 ROUGHNESS = 0.86 + weave * visible_weave * 0.035;
 float cuff = forearm ? smoothstep(0.62, 0.94, UV.y) : 0.0;
 ALPHA = mix(1.0, cuff, remote_weight);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("forearm", forearm)
	return material

func _update_camera_framing() -> void:
	if not is_instance_valid(camera): return
	var dimensions: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = dimensions.x / maxf(1.0, dimensions.y)
	# Wide displays gain horizontal room. Narrow windows retain the complete
	# original counter instead of cropping off the fryer dials and containers.
	var width_compensation: float = maxf(1.0, CAMERA_REFERENCE_ASPECT / maxf(0.1, aspect))
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(CAMERA_VERTICAL_FOV * 0.5)) * width_compensation))

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
	if id in ["customer", "punch"]:
		return camera.unproject_position(get_station_world_position(id)) if is_instance_valid(camera) and is_instance_valid(_front_customer()) else Vector2.ZERO
	if not _stations.has(id) or not is_instance_valid(camera):
		return Vector2.ZERO
	return camera.unproject_position(_stations[id].global_position)

func get_station_screen_position(id: String) -> Vector2:
	return station_screen_position(id)

func get_station_world_position(id: String) -> Vector3:
	if id in ["customer", "punch"]:
		var person: Node3D = _front_customer()
		return person.to_global(Vector3(0, 2.82, 0.12)) if is_instance_valid(person) else Vector3.ZERO
	return _stations[id].global_position if _stations.has(id) else Vector3.ZERO

func set_quality(level: int, mobile_mode: bool = false) -> void:
	_quality = clampi(level, 0, 2)
	_mobile_quality = mobile_mode
	_apply_quality_lighting()

func _apply_quality_lighting() -> void:
	# Quality changes lighting only: physical food, visible carried food, collision
	# bodies and their fixed-step simulation must never depend on the profile.
	if is_instance_valid(_sunlight):
		_sunlight.shadow_enabled = not _mobile_quality or _quality >= 1
		_sunlight.directional_shadow_max_distance = (18.0 if _quality == 1 else 24.0) if _mobile_quality else 36.0
	for light in _detail_lights:
		light.shadow_enabled = _quality >= 2 and light.position.x < 0.0

func set_cosmetic(id: String) -> void:
	_cosmetic = id if id in ["classic", "midnight", "cherry", "neon_midway", "grandmas_recipe", "chrome_carnival"] else "classic"
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
	elif _cosmetic == "neon_midway":
		red_color = "7254c7"
		dark_color = "493681"
	elif _cosmetic == "grandmas_recipe":
		red_color = "aa4747"
		dark_color = "713333"
	elif _cosmetic == "chrome_carnival":
		red_color = "bac9d2"
		dark_color = "63717b"
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
	if _expansion != null: _expansion.sync_state(state)
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
	if bool(state.get("fire_active", false)):
		_context_station = "extinguish"
		status = "FRYER FIRE!"
		indicator = "fault"
		progress = 1.0
	elif float(state.get("fire_recovery", 0.0)) > 0.0:
		_context_station = "extinguish"
		status = "COOLING / FOAM"
		indicator = "warning"
		progress = 0.0
	elif jammed:
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
	_sync_fire_visual()
	var pouring_batter: bool = str(state.get("hold_station", "")) == "refill"
	if pouring_batter != _refilling:
		_refilling = pouring_batter
		var target: Transform3D = Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(65))), _stations["refill"].position + Vector3(0.34, 0.35, 0)) if pouring_batter else _pitcher_home
		_move_node(_maintenance_prop, target, 0.52 if pouring_batter else 0.48, 0.26)
		if pouring_batter: _motions.back()["delay"] = GRASP_TIME
	_batter_stream.visible = pouring_batter and not _node_is_moving(_maintenance_prop)

func shake_tray() -> bool:
	var accepted: bool = _food.shake_tray() if is_instance_valid(_food) else false
	if accepted and _action == "tray_shake" and _action_time > 0.0:
		_action_time = maxf(_action_time, 0.82)
	return accepted

func set_tray_shake_offset(offset: Vector3) -> void:
	if is_instance_valid(_tray_visual):
		_tray_visual.position = offset

func reset_food(supply: int, capacity: int, pending_ids: Array = []) -> void:
	if not is_instance_valid(_food):
		return
	_reset_gags()
	for motion in _motions:
		var node: Node3D = motion.node
		if is_instance_valid(node) and node != _extinguisher and node != _held_scoop and not _shakers.values().has(node) and node != _prep and node != _maintenance_prop:
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
	_handoff = null
	for track in _hand_tracks:
		track.node = null
		track.age = 1.0
	_dial_presses = [0.0, 0.0]
	_dial_velocities = [0.0, 0.0]
	for knob in _heat_knobs: knob.rotation.z = 0.0
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
			var local: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * FoodGeometry.DONUT_SCALE), Vector3(-0.10 + float(index % 2) * 0.19, 0.085 + float(index / 2) * 0.10, -0.15 + float(index / 2) * 0.12))
			_move_node(donut, _held_scoop.global_transform * local, 0.22, 0.065, func():
				if is_instance_valid(donut):
					donut.reparent(_held_scoop, true)
					donut.transform = local)
			_motions.back()["target_node"] = _held_scoop
			_motions.back()["target_local"] = local
			_motions.back()["delay"] = 0.30 + float(index) * 0.018

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
				_move_node(_prep, target, 0.56, 0.34, func(): top.visible = true)
				_motions.back()["delay"] = GRASP_TIME
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
		var local: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * FoodGeometry.DONUT_SCALE), _package_donut_position(index, kind))
		var package: Node3D = _prep
		if transferred:
			_move_node(donut, package.global_transform * local, 0.26 + float(index % 3) * 0.025, 0.025, func():
				if is_instance_valid(donut) and is_instance_valid(package):
					donut.reparent(package, true)
					donut.transform = local)
			_motions.back()["delay"] = 0.40 + float(index % 3) * 0.035
			_motions.back()["follow_source"] = _held_scoop
			_motions.back()["source_local"] = scoop_origin
			_motions.back()["falling"] = true
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
		_move_node(_held_scoop, _view_hands.global_transform * _scoop_pose, 0.44, 0.16)
		_motions.back()["delay"] = GRASP_TIME
	elif prior == "scoop":
		_move_node(_held_scoop, _tool_home, 0.38, 0.16)
	if tool == "package" and is_instance_valid(_prep):
		_held_package = _prep
		_move_node(_prep, _view_hands.global_transform * _package_pose, 0.50, 0.20)
		_motions.back()["delay"] = GRASP_TIME
	elif prior == "package" and is_instance_valid(_prep):
		_held_package = null
		_move_node(_prep, Transform3D(Basis.IDENTITY, _package_anchor), 0.42, 0.15)

func _sync_people() -> void:
	var orders: Array = _state.get("orders", [])
	if orders.is_empty(): _set_customer_highlight(null)
	var seen: Dictionary = {}
	for i in range(mini(3, orders.size())):
		var order: Dictionary = orders[i]
		var id: int = int(order.get("id", i))
		seen[id] = true
		var target: Vector3 = Vector3(0.4 + float(i) * 1.35, 0.15, -2.15 - float(i) * 0.95)
		var arriving: bool = not _people.has(id)
		if arriving:
			_people[id] = _expansion.make_seagull_customer(id) if str(order.get("special", "")) == "seagulls" else _make_customer(id)
			_people[id].position = target + Vector3(1.7, 0, -1.2)
		var person: Node3D = _people[id]
		if int(person.get_meta("queue_index", -1)) != i:
			person.set_meta("queue_index", i)
			var pose: Transform3D = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(-float(i) * 7.0), 0)), target)
			_move_node(person, pose, 0.64 if arriving else 0.42)
			if is_instance_valid(_punch_person): _motions.back()["delay"] = 0.50
			elif is_instance_valid(_served_person) and not arriving: _motions.back()["delay"] = 0.64
		var serve_hit: Area3D = person.get_meta("serve_hit")
		serve_hit.collision_layer = 1 if i == 0 else 0
		if i == 0: _set_customer_highlight(person)
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
			if leaving == _punch_person:
				pass # The jab owns impact/recoil; its callback starts this departure.
			elif leaving == _served_person:
				_move_node(leaving, leaving.global_transform, 0.70, 0.0, func(): _depart_customer(leaving))
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

const CUSTOMER_GEOMETRY_VERSION: int = 1
var _customer_mesh_cache: Dictionary = {}
var _customer_cache_initialized: bool = false
var _customer_bake_mode: bool = false

func _customer_initialize_geometry() -> void:
	if _customer_cache_initialized: return
	_customer_cache_initialized=true
	if _customer_bake_mode: return
	var path: String = "res://assets/models/fairgoer_geometry.res"
	if ResourceLoader.exists(path):
		var library: Resource = load(path)
		if int(library.format_version)==CUSTOMER_GEOMETRY_VERSION:
			_customer_mesh_cache=library.meshes.duplicate()

func _customer_store_mesh(key: String,mesh: Mesh) -> Mesh:
	mesh.set_meta("customer_geometry_key",key)
	_customer_mesh_cache[key]=mesh
	return mesh

func _make_customer(id: int) -> Node3D:
	_customer_initialize_geometry()
	# A small cast of original sculpted fairgoers. The anatomical surface is one
	# continuous mesh: cheeks, socket recesses, chin, nose and jaw are not balls.
	var person: Node3D = Node3D.new()
	person.name = "Fairgoer_%d" % id
	add_child(person)
	var variant: int = posmod(id, 6)
	var skin: Material = _customer_material("skin", variant)
	var cloth: Material = _customer_material("cloth", variant)
	var hair: Material = _customer_material("hair", variant)
	var seam: Material = _customer_material("seam", variant)
	var lips: Material = _customer_material("lips", variant)
	var head: Node3D = Node3D.new()
	head.name = "Portrait"
	person.add_child(head)
	_customer_mesh("SculptedFace", _customer_head_mesh(variant), Vector3.ZERO, skin, head)
	_customer_loft("Neck", [Vector4(2.40,0.10,0.085,-0.015),Vector4(2.49,0.102,0.085,-0.012),Vector4(2.58,0.082,0.075,0),Vector4(2.69,0.09,0.075,0)], skin, person)
	_customer_loft("TailoredShirt", [Vector4(1.66,0.29,0.17,0),Vector4(1.70,0.30,0.174,0),Vector4(1.76,0.291,0.168,0),Vector4(1.89,0.286,0.16,0),Vector4(2.04,0.306,0.185,0),Vector4(2.23,0.33,0.192,0),Vector4(2.38,0.36,0.16,-0.01),Vector4(2.44,0.337,0.14,-0.016),Vector4(2.50,0.19,0.095,-0.025),Vector4(2.525,0.112,0.085,-0.014)], cloth, person, true)
	var trousers: Material = _customer_material("trousers",variant)
	_customer_loft("TrousersWaist",[Vector4(1.30,0.245,0.15,0),Vector4(1.43,0.29,0.17,0),Vector4(1.67,0.285,0.165,0)],trousers,person,true,16,24)
	for side in [-1.0,1.0]:
		_customer_limb("TrouserLeg",Vector3(side*0.145,1.46,0),Vector3(side*0.16,0.07,0.02),[0.137,0.141,0.127,0.105,0.10,0.105],trousers,person,true)
		_customer_ellipsoid("Shoe",Vector3(side*0.16,-0.05,0.07),Vector3(0.117,0.10,0.23),_mat["black"],person)
	_customer_loft("CollarBand",[Vector4(2.485,0.117,0.095,-0.014),Vector4(2.515,0.118,0.096,-0.014),Vector4(2.545,0.104,0.086,-0.012)],seam,person,false,8,32)
	# Real placket, folded collar leaves, pocket edge, buttons and hem stitching.
	_customer_curve("ShirtPlacket", [Vector3(0,1.74,0.176),Vector3(0,1.94,0.18),Vector3(0,2.20,0.199),Vector3(0,2.41,0.153)], 0.007, seam, person)
	for side in [-1.0,1.0]:
		_customer_patch("FoldedCollar", [Vector3(side*0.020,2.46,0.138),Vector3(side*0.108,2.505,0.087),Vector3(side*0.157,2.455,0.119),Vector3(side*0.09,2.395,0.172)], seam, person)
		_customer_curve("ShoulderSeam", [Vector3(side*0.13,2.48,0.07),Vector3(side*0.26,2.45,0.105),Vector3(side*0.345,2.39,0.073)], 0.0025, seam, person)
	for y in [2.30,2.15,2.0,1.84]:
		_customer_ellipsoid("ShirtButton",Vector3(0.0,y,0.20 if y>2.05 else 0.183),Vector3(0.008,0.008,0.004),_mat["cream"],person)
	_customer_patch("ChestPocket",[Vector3(-0.12,2.28,0.191),Vector3(-0.26,2.26,0.153),Vector3(-0.25,2.13,0.169),Vector3(-0.13,2.13,0.197)],cloth,person)
	_customer_curve("PocketStitch",[Vector3(-0.12,2.28,0.194),Vector3(-0.20,2.27,0.178),Vector3(-0.26,2.26,0.158)],0.0025,seam,person)
	var arms: Array[Node3D] = []
	for side in [-1.0,1.0]:
		var arm: Node3D = Node3D.new()
		arm.name = "CustomerArmLeft" if side < 0 else "CustomerArmRight"
		arm.position = Vector3(side*0.31,2.405,0)
		person.add_child(arm)
		arms.append(arm)
		_customer_ellipsoid("Shoulder",Vector3(0,-0.04,0),Vector3(0.115,0.13,0.106),cloth,arm)
		_customer_limb("Sleeve",Vector3(0,-0.005,0),Vector3(side*0.13,-0.33,0.055),[0.115,0.123,0.115,0.103,0.091,0.095],cloth,arm,true)
		_customer_limb("RolledCuff",Vector3(side*0.115,-0.29,0.05),Vector3(side*0.14,-0.35,0.062),[0.098,0.102,0.101,0.094],seam,arm)
		var elbow: Vector3 = Vector3(side*0.15,-0.385,0.08)
		var wrist: Vector3 = Vector3(side*0.035,-0.56,0.405)
		_customer_limb("UpperForearm",Vector3(side*0.13,-0.32,0.055),elbow,[0.087,0.079,0.071,0.064],skin,arm)
		_customer_limb("Forearm",elbow,wrist,[0.067,0.077,0.075,0.062,0.052,0.046],skin,arm)
		_customer_ellipsoid("Elbow",elbow,Vector3(0.067,0.064,0.075),skin,arm)
		_customer_ellipsoid("Palm",wrist+Vector3(0,-0.005,0.071),Vector3(0.064,0.033,0.095),skin,arm)
		for finger in range(4):
			var x: float = side*0.035-0.047+float(finger)*0.030
			var reach: float = [0.10,0.125,0.118,0.09][finger]
			var a: Vector3 = Vector3(x,-0.566,0.46)
			var b: Vector3 = a+Vector3(0,-0.006,reach*0.60)
			var c: Vector3 = a+Vector3(0,-0.032,reach)
			_customer_limb("Finger",a,b,[0.018,0.019,0.017],skin,arm)
			_customer_limb("Fingertip",b,c,[0.017,0.016,0.012,0.001],skin,arm)
			_customer_ellipsoid("Fingernail",c+Vector3(0,0.011,-0.015),Vector3(0.010,0.003,0.014),_customer_material("nails",variant),arm)
		_customer_limb("Thumb",wrist+Vector3(-side*0.045,-0.005,0.03),wrist+Vector3(-side*0.091,-0.02,0.10),[0.024,0.025,0.022,0.019,0.001],skin,arm)
		_customer_batch(arm)
	person.set_meta("arms",arms)
	# Shallow almond eyes sit in recessed sockets, with actual lid margins.
	var eyes: Array[Node3D] = []
	for side in [-1.0,1.0]:
		var eye: Node3D = Node3D.new()
		eye.position = Vector3(side*0.076,2.873,0.151)
		eye.name = "EyeLeft" if side<0 else "EyeRight"
		eye.rotation.y=side*0.28
		head.add_child(eye)
		eyes.append(eye)
		_customer_ellipsoid("Sclera",Vector3.ZERO,Vector3(0.038,0.012,0.010),_customer_material("sclera",0),eye)
		_customer_ellipsoid("Iris",Vector3(-side*0.001,0,0.009),Vector3(0.0105,0.0115,0.003),_customer_material("iris",variant),eye)
		_customer_ellipsoid("Pupil",Vector3(-side*0.001,0,0.0113),Vector3(0.0044,0.006,0.0015),_mat["eye"],eye)
		_customer_ellipsoid("Catchlight",Vector3(-0.0035,0.004,0.0125),Vector3(0.0018,0.0018,0.001),_mat["white"],eye)
		_customer_curve("UpperEyelid",[Vector3(-0.038,-0.001,0),Vector3(-0.020,0.011,0.008),Vector3(0,0.012,0.009),Vector3(0.021,0.008,0.007),Vector3(0.038,-0.002,0)],0.0025,skin,eye)
		_customer_curve("LowerEyelid",[Vector3(-0.038,-0.001,0),Vector3(-0.017,-0.009,0.008),Vector3(0.01,-0.011,0.008),Vector3(0.038,-0.002,0)],0.0020,skin,eye)
		_customer_curve("LidCrease",[Vector3(-0.031,0.019,-0.001),Vector3(0,0.022,0.002),Vector3(0.028,0.015,-0.001)],0.00065,lips,eye)
		_customer_curve("Brow",[Vector3(side*0.038,2.922,0.174),Vector3(side*0.073,2.931,0.180),Vector3(side*0.109,2.925,0.166),Vector3(side*0.132,2.914,0.145)],0.0038,hair,head)
		_customer_ellipsoid("Ear",Vector3(side*0.193,2.82,-0.008),Vector3(0.028,0.057,0.033),skin,head)
		_customer_ellipsoid("EarConcha",Vector3(side*0.207,2.82,0.017),Vector3(0.013,0.033,0.008),lips,head)
		_customer_curve("EarHelix",[Vector3(side*0.202,2.77,0.019),Vector3(side*0.218,2.80,0.022),Vector3(side*0.217,2.854,0.017),Vector3(side*0.198,2.869,0.006)],0.005,skin,head)
		_customer_ellipsoid("Nostril",Vector3(side*0.019,2.800,_customer_face_depth(side*0.019,2.800,variant)-0.001),Vector3(0.006,0.0025,0.002),_customer_material("shadow",variant),head)
	# A softly modeled cupid's bow and lower lip replace the old painted smile.
	_customer_curve("UpperLip",_customer_surface_points([Vector3(-0.049,2.744,0.174),Vector3(-0.024,2.748,0.188),Vector3(-0.009,2.752,0.194),Vector3(0,2.748,0.195),Vector3(0.009,2.752,0.194),Vector3(0.024,2.748,0.188),Vector3(0.049,2.744,0.174)],variant,0.0025),0.003,lips,head)
	_customer_curve("LowerLip",_customer_surface_points([Vector3(-0.046,2.741,0.176),Vector3(-0.022,2.736,0.190),Vector3(0,2.735,0.195),Vector3(0.022,2.736,0.190),Vector3(0.046,2.741,0.176)],variant,0.0025),0.004,lips,head)
	_customer_curve("MouthLine",_customer_surface_points([Vector3(-0.046,2.744,0.180),Vector3(-0.021,2.742,0.195),Vector3(0,2.742,0.198),Vector3(0.021,2.742,0.195),Vector3(0.046,2.744,0.180)],variant,0.0025),0.0011,_customer_material("shadow",variant),head)
	_customer_mesh("SculptedHair",_customer_hair_mesh(variant),Vector3.ZERO,hair,head)
	for strand in range(22):
		var u: float = lerpf(-0.23,0.23,float(strand)/21.0)
		var points: Array[Vector3] = []
		for step in range(7):
			var v: float = float(step)/7.0
			points.append(_customer_hair_point(u+v*0.04,v,variant)+Vector3(0,0.001,0.001))
		_customer_curve("HairLock",points,0.0016,_customer_material("hair_highlight",variant),head)
	if variant in [1,4]:
		_customer_ellipsoid("HairKnot",Vector3(0,2.99,-0.19),Vector3(0.11,0.10,0.11),hair,head)
	if variant in [0,3]:
		for side in [-1.0,1.0]:
			var rim: Array[Vector3] = []
			for n in range(25):
				var angle: float = float(n)*TAU/24.0
				rim.append(Vector3(side*0.076+cos(angle)*0.056,2.873+sin(angle)*0.034,0.190))
			_customer_curve("SpectacleRim",rim,0.0038,_mat["steel_dark"],head)
			_customer_curve("SpectacleTemple",[Vector3(side*0.13,2.884,0.19),Vector3(side*0.19,2.889,0.08),Vector3(side*0.198,2.865,0.0)],0.0038,_mat["steel_dark"],head)
		_customer_curve("SpectacleBridge",[Vector3(-0.019,2.878,0.19),Vector3(0,2.888,0.205),Vector3(0.019,2.878,0.19)],0.0038,_mat["steel_dark"],head)
	for eye in eyes: _customer_batch(eye)
	_customer_batch(head)
	_customer_batch(person)
	person.set_meta("portrait",head)
	person.set_meta("eyes",eyes)
	person.set_meta("detail_version",2)
	# Preserve the existing order card, patience indicator and service interaction.
	_box(Vector3(0,2.16,0.34),Vector3(0.78,0.49,0.045),"cream",person)
	var order_label: Label3D = _label("",Vector3(0,2.16,0.371),23,Color("6a402d"),person)
	person.set_meta("order_label",order_label)
	_box(Vector3(0,3.37,0),Vector3(0.79,0.065,0.03),"black",person)
	var patience: MeshInstance3D = _box(Vector3(0,3.37,0.022),Vector3(0.76,0.045,0.02),"gauge_green",person)
	person.set_meta("patience",patience)
	var serve_hit: Area3D = Area3D.new()
	serve_hit.position = Vector3(0,2.50,0.15)
	serve_hit.collision_layer = 1
	serve_hit.collision_mask = 0
	serve_hit.set_meta("station_id","customer")
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.95,1.6,0.75)
	shape.shape = box
	serve_hit.add_child(shape)
	person.add_child(serve_hit)
	person.set_meta("serve_hit",serve_hit)
	if posmod(id,7)==0:
		var hat: Node3D = _plain_donut(70000+id, Vector3.ZERO)
		hat.reparent(head,false)
		hat.position=Vector3(0,3.16,0)
		hat.scale=Vector3(1.65,0.90,1.65)
		hat.rotation=Vector3(0.24,0.0,0.12)
		hat.name="DonutHat"
		person.set_meta("donut_hat",hat)
	return person

func _customer_material(kind: String, variant: int) -> Material:
	var key: String = "customer_%s_%d" % [kind,variant]
	if _mat.has(key): return _mat[key]
	var colors: Array = [Color("d3a389"),Color("af7859"),Color("78513d"),Color("c39077"),Color("ab8066"),Color("674632")]
	var base: Color = colors[variant]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 0.66
	if kind == "cloth" or kind == "seam":
		base = [Color("547b6c"),Color("b78950"),Color("566e8e"),Color("9d5549"),Color("687a7e"),Color("6c7161")][variant]
		if kind == "seam": base = base.lightened(0.13)
		material.roughness = 0.94
	elif kind == "trousers":
		base = [Color("263b43"),Color("3d3940"),Color("343d44"),Color("4a4138"),Color("3f4243"),Color("2b3740")][variant]
		material.roughness = 0.94
	elif kind in ["hair","hair_highlight"]:
		base = [Color("29231f"),Color("40291f"),Color("201b19"),Color("6d5841"),Color("49342a"),Color("252220")][variant]
		if kind == "hair_highlight": base = base.lightened(0.075)
		material.roughness = 0.82
	elif kind == "lips": base = base.lerp(Color("8a4841"),0.25)
	elif kind == "nails": base = base.lightened(0.12)
	elif kind == "shadow": base = base.darkened(0.43)
	elif kind == "sclera": base = Color("d3c5ad")
	elif kind == "iris": base = [Color("5b4b31"),Color("624127"),Color("3e3527"),Color("4e665c"),Color("48412b"),Color("33271e")][variant]
	material.resource_name = key
	material.albedo_color = base
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if kind in ["skin","cloth"]:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = 426+variant
		noise.frequency = 0.12 if kind == "skin" else 0.26
		var texture: NoiseTexture2D = NoiseTexture2D.new()
		texture.width = 128
		texture.height = 128
		texture.noise = noise
		texture.as_normal_map = true
		texture.bump_strength = 0.08 if kind == "skin" else 0.17
		material.normal_enabled = true
		material.normal_texture = texture
		material.normal_scale = 0.18 if kind == "skin" else 0.35
		material.uv1_scale = Vector3(5,5,1)
	_mat[key] = material
	return material

func _customer_mesh(label: String, mesh: Mesh, at: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var node: MeshInstance3D = _mesh_node(mesh,at,material,parent)
	node.name = label
	if (parent.name == "Portrait" or str(parent.name).begins_with("Eye")) and label not in ["SculptedFace","SculptedHair"]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _customer_ellipsoid(label: String, at: Vector3, size: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	if not _customer_mesh_cache.has("unit_sphere"):
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 24
		sphere.rings = 12
		_customer_store_mesh("unit_sphere",sphere)
	var node: MeshInstance3D = _customer_mesh(label,_customer_mesh_cache.unit_sphere,at,material,parent)
	node.scale = size
	return node

func _customer_profile(rows: Array, y: float) -> Vector4:
	for i in range(rows.size()-1):
		if y <= rows[i+1].x:
			var u: float = clampf((y-rows[i].x)/(rows[i+1].x-rows[i].x),0,1)
			var p0: Vector4 = rows[maxi(0,i-1)]
			var p1: Vector4 = rows[i]
			var p2: Vector4 = rows[i+1]
			var p3: Vector4 = rows[mini(rows.size()-1,i+2)]
			var value: Vector4 = 0.5*((2.0*p1)+(-p0+p2)*u+(2.0*p0-5.0*p1+4.0*p2-p3)*u*u+(-p0+3.0*p1-3.0*p2+p3)*u*u*u)
			value.x=y
			value.y=maxf(0.001,value.y)
			value.z=maxf(0.001,value.z)
			return value
	return rows.back()

func _customer_loft(label: String, rows: Array, material: Material, parent: Node3D, folds: bool = false, rows_count: int = 40, columns_count: int = 40) -> MeshInstance3D:
	var key: String = "loft:"+str(hash([rows,folds,rows_count,columns_count]))
	if _customer_mesh_cache.has(key): return _customer_mesh(label,_customer_mesh_cache[key],Vector3.ZERO,material,parent)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows_count):
		for col in range(columns_count):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
				var v: float = float(row+corner.y)/float(rows_count)
				var u: float = float(col+corner.x)/float(columns_count)
				var angle: float = u*TAU
				var shape: Vector4 = _customer_profile(rows,lerpf(rows[0].x,rows.back().x,v))
				var fold: float = sin(v*36.0+sin(angle*3.0)*1.4)*0.004*(pow(1.0-v,3.0)+0.15) if folds else 0.0
				st.set_uv(Vector2(u,v))
				st.add_vertex(Vector3(sin(angle)*(shape.y+fold),shape.x,cos(angle)*(shape.z+fold)+shape.w))
	st.generate_normals()
	st.generate_tangents()
	return _customer_mesh(label,_customer_store_mesh(key,st.commit()),Vector3.ZERO,material,parent)

func _customer_head_point(u: float,v: float,variant: int) -> Vector3:
	var rows: Array = [Vector4(2.595,0.025,0.045,0.01),Vector4(2.63,0.074,0.095,0.014),Vector4(2.67,0.111,0.129,0.005),Vector4(2.71,0.135,0.144,0),Vector4(2.76,0.163,0.159,-0.007),Vector4(2.82,0.187,0.171,-0.01),Vector4(2.88,0.191,0.181,-0.012),Vector4(2.95,0.188,0.182,-0.014),Vector4(3.02,0.171,0.171,-0.017),Vector4(3.07,0.129,0.138,-0.018),Vector4(3.102,0.063,0.072,-0.021),Vector4(3.112,0.001,0.001,-0.021)]
	var y: float = lerpf(2.595,3.112,v)
	var p: Vector4 = _customer_profile(rows,y)
	var angle: float = u*TAU
	var x: float = sin(angle)*p.y
	var z: float = cos(angle)*p.z+p.w
	if cos(angle)>0:
		var frontal: float = pow(cos(angle),3.0)
		# Smooth surface displacements sculpt the bridge/tip/nostril wings, brow,
		# cheekbone and chin while keeping sockets tucked under the eyelids.
		z += frontal*(0.032*exp(-pow(x/0.024,2)-pow((y-2.855)/0.071,2)) + 0.045*exp(-pow(x/0.031,2)-pow((y-2.815)/0.024,2)))
		z += frontal*0.018*exp(-pow((absf(x)-0.028)/0.014,2)-pow((y-2.807)/0.016,2))
		z -= frontal*0.012*exp(-pow((absf(x)-0.078)/0.048,2)-pow((y-2.875)/0.024,2))
		z += frontal*0.010*exp(-pow((absf(x)-0.087)/0.057,2)-pow((y-2.922)/0.020,2))
		z += frontal*0.008*exp(-pow((absf(x)-0.110)/0.050,2)-pow((y-2.817)/0.038,2))
		z += frontal*0.037*exp(-pow(x/0.073,2)-pow((y-2.741)/0.034,2))
		z += frontal*0.024*exp(-pow(x/0.066,2)-pow((y-2.677)/0.031,2))
	# Gentle cast variation preserves eye and mouth attachments.
	x *= 1.0+sin(v*PI)*float(variant%3-1)*0.018
	return Vector3(x,y,z)

func _customer_face_depth(x: float,y: float,variant: int) -> float:
	var low: float = -0.24
	var high: float = 0.24
	var v: float = (y-2.595)/0.517
	for step in range(20):
		var u: float = (low+high)*0.5
		if _customer_head_point(u,v,variant).x<x: low=u
		else: high=u
	return _customer_head_point((low+high)*0.5,v,variant).z

func _customer_surface_points(points: Array,variant: int,offset: float) -> Array:
	var result: Array = []
	for point in points:
		result.append(Vector3(point.x,point.y,_customer_face_depth(point.x,point.y,variant)+offset))
	return result

func _customer_head_mesh(variant: int) -> ArrayMesh:
	var key: String = "head:"+str(variant%3)
	if _customer_mesh_cache.has(key): return _customer_mesh_cache[key]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(64):
		for col in range(64):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
				var uv: Vector2 = Vector2(float(col+corner.x)/64.0,float(row+corner.y)/64.0)
				var du: Vector3 = _customer_head_point(uv.x+0.0001,uv.y,variant)-_customer_head_point(uv.x-0.0001,uv.y,variant)
				var dv: Vector3 = _customer_head_point(uv.x,minf(1.0,uv.y+0.0001),variant)-_customer_head_point(uv.x,maxf(0.0,uv.y-0.0001),variant)
				st.set_normal(du.cross(dv).normalized())
				st.set_uv(uv)
				st.add_vertex(_customer_head_point(uv.x,uv.y,variant))
	st.generate_tangents()
	return _customer_store_mesh(key,st.commit())

func _customer_hair_point(u: float,v: float,variant: int) -> Vector3:
	var angle: float = u*TAU
	var hairline: float = 2.89+maxf(0,cos(angle))*0.132+0.010*sin(angle*5.0)
	if variant in [1,4]: hairline -= maxf(0,-cos(angle))*0.12
	var y: float = lerpf(hairline,3.112,v)
	var point: Vector3 = _customer_head_point(u,(y-2.595)/0.517,variant)
	var ripple: float = sin(angle*35.0+v*9.0)*0.0012
	point.x *= 1.075
	point.z = -0.021+(point.z+0.021)*1.075
	point.y += 0.012+ripple
	return point

func _customer_hair_mesh(variant: int) -> ArrayMesh:
	var key: String = "hair:"+str(variant%3)
	if _customer_mesh_cache.has(key): return _customer_mesh_cache[key]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(24):
		for col in range(64):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
				var u: float = float(col+corner.x)/64.0
				var v: float = float(row+corner.y)/24.0
				st.set_uv(Vector2(u,v))
				st.add_vertex(_customer_hair_point(u,v,variant))
	st.generate_normals()
	st.generate_tangents()
	return _customer_store_mesh(key,st.commit())

func _customer_limb(label: String,a: Vector3,b: Vector3,radii: Array,material: Material,parent: Node3D,folds: bool=false) -> MeshInstance3D:
	var rows: Array = []
	var length: float = a.distance_to(b)
	for i in range(radii.size()): rows.append(Vector4(float(i)/float(radii.size()-1)*length,float(radii[i]),float(radii[i])*0.92,0))
	var node: MeshInstance3D = _customer_loft(label,rows,material,parent,folds,12,16)
	node.position = a
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return node

func _customer_curve(label: String,points: Array,radius: float,material: Material,parent: Node3D) -> void:
	var key: String = "curve:"+str(hash([points,radius]))
	if _customer_mesh_cache.has(key):
		_customer_mesh(label,_customer_mesh_cache[key],Vector3.ZERO,material,parent)
		return
	# Catmull-Rom sampling gives curved seams and facial edges, not kinked rods.
	var sampled: Array[Vector3] = []
	for i in range(points.size()-1):
		for step in range(3):
			var t: float = float(step)/3.0
			sampled.append(points[i].cubic_interpolate(points[i+1],points[maxi(0,i-1)],points[mini(points.size()-1,i+2)],t))
	sampled.append(points.back())
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(sampled.size()-1):
		for col in range(6):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
				var index: int = row+corner.y
				var tangent: Vector3 = (sampled[mini(index+1,sampled.size()-1)]-sampled[maxi(0,index-1)]).normalized()
				var axis: Vector3 = tangent.cross(Vector3.FORWARD).normalized()
				if axis.length_squared()<0.1: axis=tangent.cross(Vector3.UP).normalized()
				var other: Vector3 = tangent.cross(axis).normalized()
				var angle: float = float(col+corner.x)*TAU/6.0
				st.set_uv(Vector2(float(col+corner.x)/6.0,float(index)/float(sampled.size()-1)))
				st.add_vertex(sampled[index]+(axis*cos(angle)+other*sin(angle))*radius)
	st.generate_normals()
	_customer_mesh(label,_customer_store_mesh(key,st.commit()),Vector3.ZERO,material,parent)

func _customer_patch(label: String,points: Array,material: Material,parent: Node3D) -> void:
	var key: String = "patch:"+str(hash(points))
	if _customer_mesh_cache.has(key):
		_customer_mesh(label,_customer_mesh_cache[key],Vector3.ZERO,material,parent)
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: Array = [0,1,2,0,2,3] if (points[1]-points[0]).cross(points[2]-points[0]).z < 0 else [0,2,1,0,3,2]
	for index in indices:
		st.set_uv(Vector2(float(index%2),float(index/2)))
		st.add_vertex(points[index])
	st.generate_normals()
	_customer_mesh(label,_customer_store_mesh(key,st.commit()),Vector3.ZERO,material,parent)

func _customer_batch(parent: Node3D) -> void:
	# Mixed indexed/non-indexed sources must be deindexed before concatenation.
	# Tiny facial trim does not cast the large jagged shadows of a whole head.
	var groups: Dictionary = {}
	var source_triangles: int = 0
	var final_triangles: int = 0
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		var material: Material = child.material_override
		var data: Array = child.mesh.surface_get_arrays(0)
		source_triangles += (data[Mesh.ARRAY_INDEX].size() if data[Mesh.ARRAY_INDEX] != null and data[Mesh.ARRAY_INDEX].size()>0 else data[Mesh.ARRAY_VERTEX].size())/3
		var key: String = str(material.get_instance_id())+":"+str(child.cast_shadow)
		if not groups.has(key): groups[key]={"material":material,"shadows":child.cast_shadow,"meshes":[]}
		groups[key].meshes.append(child)
	for key in groups:
		var group: Dictionary = groups[key]
		var meshes: Array = group.meshes
		if meshes.size()<2: continue
		var source_keys: Array = []
		for node in meshes: source_keys.append([node.mesh.get_meta("customer_geometry_key",""),node.transform])
		var material_key: String = group.material.resource_name
		if material_key.is_empty(): material_key=str(group.material.albedo_color)
		var batch_key: String = "batch:"+str(hash([material_key,group.shadows,source_keys]))
		if not _customer_mesh_cache.has(batch_key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for node in meshes:
				var normalized: SurfaceTool = SurfaceTool.new()
				normalized.create_from(node.mesh,0)
				normalized.deindex()
				st.append_from(normalized.commit(),0,node.transform)
			st.index()
			_customer_store_mesh(batch_key,st.commit())
		for node in meshes:
			parent.remove_child(node)
			node.free()
		var batch: MeshInstance3D = _customer_mesh("PortraitDetails",_customer_mesh_cache[batch_key],Vector3.ZERO,group.material,parent)
		batch.cast_shadow=group.shadows
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		var data: Array = child.mesh.surface_get_arrays(0)
		final_triangles += (data[Mesh.ARRAY_INDEX].size() if data[Mesh.ARRAY_INDEX] != null and data[Mesh.ARRAY_INDEX].size()>0 else data[Mesh.ARRAY_VERTEX].size())/3
	parent.set_meta("customer_batch_triangles",Vector2i(source_triangles,final_triangles))

func _animate_customer_detail(person: Node3D,id: int,_delta: float) -> void:
	if str(person.get_meta("special", "")) == "seagulls": return
	if not person.has_meta("portrait"): return
	var portrait: Node3D = person.get_meta("portrait")
	portrait.rotation.x = 0.0
	portrait.rotation.z = 0.0
	portrait.rotation.y = sin(_time*0.51+float(id)*1.7)*0.035 if not _reduced_motion else 0.0
	portrait.position.y = sin(_time*1.65+float(id))*0.003 if not _reduced_motion else 0.0
	var blink_phase: float = fmod(_time+float(posmod(id,7))*0.71,4.3)
	var opening: float = 1.0-clampf(1.0-absf(blink_phase-0.12)/0.12,0.0,1.0)*0.90
	for eye in person.get_meta("eyes"):
		eye.scale.y = opening if not _reduced_motion else 1.0

func is_action_busy() -> bool:
	if _action in ["repair", "refill"]: return false
	if _action_time > 0.001: return true
	for motion in _motions:
		var node: Node3D = motion.node
		if is_instance_valid(node) and node != _maintenance_prop and not node.has_meta("serve_hit"):
			return true
	return false

func animate_action(id: String) -> void:
	if id in ["speed_down", "speed_up"]:
		_expansion.press_speed(id)
		return
	# Heat clicks may arrive during a transfer; never cancel a hand movement.
	if id in ["heat_down", "heat_up"]:
		_dial_presses[0 if id == "heat_down" else 1] = 0.15
		return
	_action = id
	_action_before = _state.duplicate(true)
	_action_duration = ACTION_DURATIONS.get(id, 0.70)
	_action_time = _action_duration
	_action_serial += 1
	_action_reach = get_station_world_position(id)
	if id == "punch":
		_start_customer_jab()
		return
	if id == "bell":
		play_gag("bell")
		return
	if id == "extinguish":
		_start_extinguisher()
		return
	if id == "supply":
		var dipped: Transform3D = Transform3D(Basis.from_euler(Vector3(-0.08, -0.3, -0.08)), _supply_anchor + Vector3(0.30, 0.24, 0.14))
		_move_node(_held_scoop, dipped, 0.30, 0.20, func():
			_move_node(_held_scoop, _view_hands.global_transform * _scoop_pose, 0.34, 0.26)
			_motions.back()["delay"] = 0.26)
	elif id == "package" and str(_state.get("held_tool", "")) == "scoop":
		var over_bag: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.90), _package_anchor + Vector3(0.03, 0.87, 0.16))
		var tipped: Transform3D = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-66), 0, 0)).scaled(Vector3.ONE * 0.90), over_bag.origin)
		_move_node(_held_scoop, over_bag, 0.26, 0.12, func():
			_move_node(_held_scoop, tipped, 0.18, 0.0, func():
				_move_node(_held_scoop, _view_hands.global_transform * _scoop_pose, 0.28, 0.14)
				_motions.back()["delay"] = 0.32))
	elif id in ["cinnamon", "powdered"]:
		_action_prop = _shakers[id]
		var shaker: Node3D = _action_prop
		var home: Transform3D = _shaker_homes[id]
		var tilted: Transform3D = Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(-135))), _package_anchor + Vector3(0.16, 1.0, 0))
		_move_node(shaker, tilted, 0.32, 0.23, func():
			_coat_package(id)
			_emit_seasoning(id)
			_move_node(shaker, tilted, 0.26, 0.0, func():
				_move_node(shaker, home, 0.34, 0.20, func(): _action_prop = null))
			_motions.back()["shake"] = true)
		_motions.back()["delay"] = GRASP_TIME
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
				_drop_into_discard(donut, false)
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
		_handoff = package
		var recipient: Node3D = _served_person if id == "serve" else null
		if id == "serve":
			# Offer at the service ledge, release, then let the customer collect.
			# The operator never needs to reach all the way to the customer's torso.
			_move_node(package, Transform3D(Basis.IDENTITY, _serve_anchor + Vector3(0, 0.045, 0.02)), 0.48, 0.10, func():
				_handoff = null
				_move_node(package, Transform3D(Basis.IDENTITY, destination), 0.20, 0.04, func():
					if is_instance_valid(recipient): package.reparent(recipient, true)
					else: package.queue_free()))
		else:
			_drop_into_discard(package, true)
		for person_id in _people: _people[person_id].set_meta("cheer", 0.95)

func _drop_into_discard(node: Node3D, held_package: bool) -> void:
	# Carry over the real aperture, release the grip, then accelerate downward.
	# The object remains full size and disappears only inside the recessed well.
	var scale_before: Vector3 = node.global_basis.get_scale()
	var above: Transform3D = Transform3D(Basis.IDENTITY.scaled(scale_before), Vector3(-3.15, 1.96, 2.35))
	_move_node(node, above, 0.46 if held_package else 0.30, 0.20, func():
		if held_package: _handoff = null
		var below: Transform3D = Transform3D(Basis.from_euler(Vector3(0.08, 0, 0.10)).scaled(scale_before), Vector3(-3.15, 0.79, 2.35))
		_move_node(node, below, 0.49, 0.0, func(): node.queue_free())
		_motions.back()["falling"] = true)
	if held_package: _motions.back()["delay"] = GRASP_TIME

func _emit_seasoning(flavor: String) -> void:
	for i in range(18 if not _reduced_motion else 6):
		var grain: MeshInstance3D = _sphere(_package_anchor + Vector3(_rng.randf_range(-0.13, 0.13), 0.85, _rng.randf_range(-0.12, 0.12)), 0.011, flavor)
		_add_effect(grain, Vector3(_rng.randf_range(-0.10, 0.10), -1.15, _rng.randf_range(-0.10, 0.10)), 0.28 + float(i % 5) * 0.025)
		grain.visible = false
		_effects.back()["delay"] = float(i % 5) * 0.035

func _minimum_jerk(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

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
		var eased: float = _minimum_jerk(t)
		if motion.has("target_node") and is_instance_valid(motion.target_node):
			motion.to = motion.target_node.global_transform * Transform3D(motion.target_local)
		var pose: Transform3D = Transform3D(motion.from).interpolate_with(motion.to, eased)
		if bool(motion.get("falling", false)):
			pose.origin = Transform3D(motion.from).origin.lerp(Transform3D(motion.to).origin, t * t)
		# Unlike sin(pi*t), this lift has zero speed at pickup and set-down.
		pose.origin.y += 16.0 * t * t * (1.0 - t) * (1.0 - t) * float(motion.arc)
		if bool(motion.get("shake", false)):
			var shake: float = sin(t * TAU * 2.0) * pow(sin(t * PI), 2.0)
			pose.origin += Vector3(0.045, 0.018, 0) * shake
			pose.basis = pose.basis.rotated(Vector3.FORWARD, shake * 0.10)
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
		var particle: Dictionary = _expansion.celebration_particle(i)
		var confetti: MeshInstance3D = _box(_serve_anchor + Vector3(0, 0.40, 0), particle.size, particle.key)
		_add_effect(confetti, particle.velocity, 0.9)

func _add_effect(node: Node3D, velocity: Vector3, lifetime: float) -> void:
	while _effects.size() >= MAX_EFFECTS:
		var old: Dictionary = _effects.pop_front()
		old["node"].queue_free()
	_effects.append({"node": node, "velocity": velocity, "age": 0.0, "lifetime": lifetime, "scale": node.scale})

func _hand_goal(index: int) -> Dictionary:
	var node: Node3D
	var offset: Vector3 = Vector3.ZERO
	var grip_basis: Basis = Basis.IDENTITY
	var side: float = -1.0 if index == 0 else 1.0
	if index == 1 and _action == "punch" and is_instance_valid(_punch_person) and _action_time > 0.19:
		node = _jab_marker
		offset = Vector3.ZERO
		grip_basis = Basis.from_euler(Vector3(-0.12, 0, -0.48)).scaled(Vector3.ONE * 1.35)
	elif index == (0 if _held_type in ["scoop", "package"] else 1) and _action == "bell" and _action_time > 0.07:
		node = _bell_button
		offset = Vector3(0, 0.04, 0.06)
	elif _action == "tray_shake" and _action_time > 0.20:
		node = _tray_visual
		offset = _supply_anchor + Vector3(side * 0.69, 0.13, 0.81)
	elif index == 0:
		if _action == "extinguish" and is_instance_valid(_prep) and _node_is_moving(_prep):
			node = _prep
			offset = Vector3(-0.35, 0.28, 0.10)
			grip_basis = Basis.from_euler(Vector3(0, -PI * 0.5, 0))
		elif _action in ["bag", "bucket"] and _held_type == "scoop" and is_instance_valid(_prep) and _node_is_moving(_prep):
			# The free hand takes the container while the right keeps its scoop grip.
			node = _prep
			offset = Vector3(-0.35, 0.28, 0.10)
			grip_basis = Basis.from_euler(Vector3(0, -PI * 0.5, 0))
		elif _action == "package" and _held_type == "scoop" and is_instance_valid(_prep) and is_action_busy():
			node = _prep
			offset = Vector3(-0.35, 0.28, 0.10)
			grip_basis = Basis.from_euler(Vector3(0, -PI * 0.5, 0))
		elif _held_type != "scoop" and _node_is_moving(_held_scoop):
			node = _held_scoop
			offset = Vector3(0, -0.005, 0.53)
	else:
		if _refilling or _node_is_moving(_maintenance_prop):
			node = _maintenance_prop
			offset = Vector3(0.39, 0.26, 0.08)
			grip_basis = Basis.from_euler(Vector3(0, PI * 0.5, 0))
		elif str(_state.get("hold_station", "")) == "repair":
			node = _repair_handle
			offset = Vector3(0, 0, 0.09)
		elif is_instance_valid(_action_prop):
			node = _action_prop
			offset = Vector3(0.27, 0.28, 0.08)
			grip_basis = Basis.from_euler(Vector3(0, PI * 0.5, 0))
		elif is_instance_valid(_handoff) and _action in ["serve", "trash"] and _node_is_moving(_handoff):
			node = _handoff
			offset = Vector3(0.35, 0.28, 0.10)
			grip_basis = Basis.from_euler(Vector3(0, PI * 0.5, 0))
		elif _action in ["bag", "bucket"] and _held_type != "scoop" and is_instance_valid(_prep) and _node_is_moving(_prep):
			node = _prep
			offset = Vector3(0.35, 0.28, 0.10)
			grip_basis = Basis.from_euler(Vector3(0, PI * 0.5, 0))
		elif is_instance_valid(_held_package):
			node = _held_package
			offset = Vector3(0.35, 0.28, 0.10)
			grip_basis = Basis.from_euler(Vector3(0, PI * 0.5, 0))
		elif _held_type == "scoop":
			node = _held_scoop
			offset = Vector3(0, -0.005, 0.53)
	if is_instance_valid(node):
		var transform: Transform3D = node.get_global_transform_interpolated() if node == _tray_visual else node.global_transform
		return {"node": node, "pose": Transform3D(transform.basis.orthonormalized() * grip_basis, transform * offset)}
	return {"node": null, "pose": _view_hands.global_transform * Transform3D(Basis.IDENTITY, Vector3(side * 0.43, -0.74, -1.35))}

func _update_hands(delta: float) -> void:
	for index in range(_hands.size()):
		var hand: Node3D = _hands[index]
		var track: Dictionary = _hand_tracks[index]
		var goal: Dictionary = _hand_goal(index)
		if track.node != goal.node:
			var returning_jab: bool = track.node == _jab_marker
			track.node = goal.node
			track.from = hand.global_transform
			track.age = 0.0
			track.duration = GRASP_TIME if is_instance_valid(goal.node) else 0.22
			# The jab commits immediately and snaps back; ordinary pickups retain
			# their softer grasp curve and the arm solver retains fixed bone lengths.
			if goal.node == _jab_marker: track.duration = 0.105
			elif returning_jab: track.duration = 0.14
		track.age = minf(float(track.duration), float(track.age) + delta)
		var t: float = clampf(float(track.age) / float(track.duration), 0.0, 1.0)
		hand.global_transform = Transform3D(track.from).interpolate_with(goal.pose, _minimum_jerk(t))
		_pose_player_fingers(index, is_instance_valid(goal.node), delta)
		_solve_arm(index, hand.global_position)

func _pose_player_fingers(index: int, gripping: bool, delta: float) -> void:
	var punching: bool = index == 1 and _action == "punch" and _action_time > 0.16
	var ease: float = 1.0 - exp(-delta * (75.0 if punching else 18.0))
	for digit in range(_finger_chains[index].size()):
		var chain: Array = _finger_chains[index][digit]
		var target: Vector3 = Vector3(-0.27, -0.64, -0.38) if gripping else Vector3(0.045, -0.10, -0.07)
		if punching: target = Vector3(-1.12, -1.48, -1.20)
		if digit == 3 and gripping: target *= 1.10
		for joint in range(3):
			chain[joint].rotation.x = lerpf(chain[joint].rotation.x, target[joint], ease)
	var side: float = -1.0 if index == 0 else 1.0
	var thumb: Node3D = _thumb_chains[index][0]
	thumb.rotation.x = lerpf(thumb.rotation.x, -0.45 if gripping else -0.12, ease)
	thumb.rotation.y = lerpf(thumb.rotation.y, side * (-0.24 if gripping else 0.84), ease)
	_thumb_chains[index][1].rotation.x = lerpf(_thumb_chains[index][1].rotation.x, -0.50 if gripping else -0.10, ease)

func set_operator_preview(enabled: bool) -> void:
	# Preview is a paused presentation pose, so it must not advance hand tracks,
	# held props, finger animations, or the simulation behind the collection.
	if enabled:
		if not _operator_preview_poses.is_empty(): return
		for hand in _hands: _operator_preview_poses.append(hand.transform)
		for index in range(_hands.size()):
			var side: float = -1.0 if index == 0 else 1.0
			_hands[index].transform = Transform3D(Basis.IDENTITY, Vector3(side * 0.32, -0.17, -0.90))
			_solve_arm(index, _hands[index].global_position)
	else:
		for index in range(_operator_preview_poses.size()):
			_hands[index].transform = _operator_preview_poses[index]
			_solve_arm(index, _hands[index].global_position)
		_operator_preview_poses.clear()

func _solve_arm(index: int, wrist: Vector3) -> void:
	var side: float = -1.0 if index == 0 else 1.0
	var rig: Dictionary = _arm_rigs[index]
	# The implied torso leans beneath the opaque counter. At distant stations
	# its shoulder follows the reach; both visible bone lengths remain anatomical.
	var shoulder: Vector3 = _view_hands.to_global(Vector3(side * 0.54, -1.48, -0.35))
	var reach: float = UPPER_ARM_LENGTH + FOREARM_LENGTH - 0.07
	# Vertical reach takes priority: keep the shoulder below the opaque worktop,
	# then slide the hidden torso horizontally. A radial clamp would lift the
	# shoulder into view and expose a disconnected sleeve over the counter.
	shoulder.y = maxf(1.30, wrist.y - reach + 0.015)
	var vertical: float = wrist.y - shoulder.y
	var horizontal_reach: float = sqrt(maxf(0.0, reach * reach - vertical * vertical))
	var horizontal: Vector3 = Vector3(shoulder.x - wrist.x, 0, shoulder.z - wrist.z)
	if horizontal.length() > horizontal_reach:
		horizontal = horizontal.normalized() * horizontal_reach
	shoulder.x = wrist.x + horizontal.x
	shoulder.z = wrist.z + horizontal.z
	var direction: Vector3 = (wrist - shoulder).normalized()
	var distance: float = clampf(shoulder.distance_to(wrist), 0.08, reach)
	var projection: float = (UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - projection * projection))
	var bend: Vector3 = Vector3(side * 0.55, -0.8, 0.20)
	bend = (bend - direction * bend.dot(direction)).normalized()
	var elbow: Vector3 = shoulder + direction * projection + bend * height
	var upper: MeshInstance3D = rig.upper
	var fore: MeshInstance3D = rig.fore
	upper.visible = _view_hands.visible
	fore.visible = _view_hands.visible
	rig.joint.visible = _view_hands.visible
	var remote_weight: float = smoothstep(1.85, 2.60, camera.global_position.distance_to(wrist))
	rig.upper_material.set_shader_parameter("remote_weight", remote_weight)
	rig.fore_material.set_shader_parameter("remote_weight", remote_weight)
	upper.global_position = (shoulder + elbow) * 0.5
	upper.global_basis = Basis(Quaternion(Vector3.UP, (elbow - shoulder).normalized()))
	fore.global_position = (elbow + wrist) * 0.5
	fore.global_basis = Basis(Quaternion(Vector3.UP, (wrist - elbow).normalized()))
	rig.joint.global_position = elbow
	rig.shoulder = shoulder
	rig.elbow = elbow
	rig.wrist = wrist

func _update_dials(delta: float) -> void:
	for index in range(_heat_knobs.size()):
		_dial_presses[index] = maxf(0.0, _dial_presses[index] - delta)
		var target: float = (-0.45 if index == 0 else 0.45) if _dial_presses[index] > 0.0 else 0.0
		# Exact critically damped spring integration keeps repeated presses smooth
		# and frame-rate independent, without touching the neighboring encoder.
		var omega: float = 23.0
		var displacement: float = _heat_knobs[index].rotation.z - target
		var coefficient: float = _dial_velocities[index] + omega * displacement
		var decay: float = exp(-omega * delta)
		_heat_knobs[index].rotation.z = target + (displacement + coefficient * delta) * decay
		_dial_velocities[index] = (_dial_velocities[index] - omega * coefficient * delta) * decay

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
	_update_dials(delta)
	_expansion.advance(delta)
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
	_view_hands.position = Vector3(0, 0.0 if _reduced_motion else sin(_time * 1.2) * 0.008, 0)
	_advance_motions(delta)
	if was_busy and not is_action_busy(): action_finished.emit()
	if _held_type == "scoop" and not _node_is_moving(_held_scoop):
		_held_scoop.global_transform = _view_hands.global_transform * _scoop_pose
	if is_instance_valid(_held_package) and not _node_is_moving(_held_package):
		_held_package.global_transform = _view_hands.global_transform * _package_pose
	_update_hands(delta)
	var running: bool = str(_state.get("phase", "playing")) == "playing" and not bool(_state.get("jammed", false)) and int(_state.get("batter", 1)) > 0 and not bool(_state.get("overheated", false)) and not bool(_state.get("fire_active", false)) and float(_state.get("fire_recovery", 0.0)) <= 0.0 and float(_state.get("temperature", 180.0)) >= 145.0 and str(_state.get("hold_station", "")) != "refill"
	if running:
		var feed_speed: float = _food._feed_multiplier
		_production_time += delta * feed_speed
		_fan.rotation.z += delta * 3.5 * feed_speed
		_flipper.rotation.z += delta * 1.8 * feed_speed
		_hopper_piston.position.y = 4.30 + sin(_production_time * 3.4) * 0.055
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
		_animate_customer_detail(person,int(id),delta)
		var cheer: float = maxf(0.0, float(person.get_meta("cheer", 0.0)) - delta)
		person.set_meta("cheer", cheer)
		if person.has_meta("arms"):
			for arm in person.get_meta("arms"):
				arm.rotation.x = sin(cheer * PI) * -0.32 if not _reduced_motion else 0.0
	_update_gags(delta)
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

func _front_customer() -> Node3D:
	var orders: Array = _state.get("orders", [])
	if orders.is_empty(): return null
	return _people.get(int(orders[0].get("id", -1)))

func _set_customer_highlight(person: Node3D) -> void:
	if person == _highlighted_customer and (is_instance_valid(person) or _station_meshes.get("customer", []).is_empty()): return
	for mesh in _station_meshes.get("customer", []):
		if is_instance_valid(mesh) and mesh.material_overlay == _station_overlays.get("customer"): mesh.material_overlay = null
	_station_meshes["customer"] = []
	_highlighted_customer = person
	if is_instance_valid(person): _register_highlight("customer", person)

func front_customer_has_donut_hat() -> bool:
	var person: Node3D = _front_customer()
	return is_instance_valid(person) and person.has_meta("donut_hat") and is_instance_valid(person.get_meta("donut_hat"))

func _build_slapstick_props() -> void:
	_gag_root = Node3D.new()
	_gag_root.name = "SlapstickEffects"
	add_child(_gag_root)
	_jab_marker = Node3D.new()
	_jab_marker.name = "GloveJabTarget"
	add_child(_jab_marker)
	_material("gag_flame", Color("ff752a"),0.0,0.6,0.85)
	_material("gag_flame_core", Color("ffe67d"),0.0,0.6,1.45)
	_material("gag_foam", Color("edf1dc"),0.0,0.93)
	var powder_material: StandardMaterial3D = _material("gag_powder",Color(0.98,0.98,0.93,0.45),0.0,1.0)
	powder_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_fire_visual=FryerFire.new()
	_fire_visual.name="FryerFlames"
	_fire_visual.position=Vector3(-2.6,2.1,-0.55)
	add_child(_fire_visual)
	_fire_light=OmniLight3D.new()
	_fire_light.position=Vector3(-2.65,2.7,-0.45)
	_fire_light.light_color=Color("ff8128")
	_fire_light.omni_range=4.5
	_fire_light.light_energy=0.0
	add_child(_fire_light)
	_foam_visual=Node3D.new()
	_foam_visual.name="FryerFoamBlanket"
	add_child(_foam_visual)
	for i in range(22):
		var foam: MeshInstance3D=_sphere(Vector3(-3.97+float(i%11)*0.31,2.115,-0.70+float(i/11)*0.32),0.21,"gag_foam",_foam_visual)
		foam.scale=Vector3(1.05,0.28+float(i%3)*0.04,0.83)
		foam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fire_visual.visible=false
	_foam_visual.visible=false
	_extinguisher=Node3D.new()
	_extinguisher.name="FoamExtinguisher"
	_extinguisher.position=Vector3(4.10,1.72,-1.35)
	add_child(_extinguisher)
	_cylinder(Vector3(0,0.28,0),0.18,0.56,"red",_extinguisher,0.17)
	var top: MeshInstance3D=_sphere(Vector3(0,0.56,0),0.17,"red",_extinguisher)
	top.scale.y=0.48
	_cylinder(Vector3(0,0.65,0),0.055,0.12,"steel_dark",_extinguisher)
	_box(Vector3(0.05,0.72,0),Vector3(0.25,0.045,0.09),"steel_dark",_extinguisher)
	_tube(Vector3(0.13,0.61,0),Vector3(0.27,0.36,0.02),0.026,"rubber",_extinguisher)
	_tube(Vector3(0.27,0.36,0.02),Vector3(0.26,0.25,0.15),0.028,"rubber",_extinguisher)
	var nozzle: MeshInstance3D=_cylinder(Vector3(-0.16,0.64,0),0.065,0.19,"steel_dark",_extinguisher,0.038)
	nozzle.rotation.z=PI*0.5
	_box(Vector3(0,0.30,0.174),Vector3(0.27,0.30,0.012),"cream",_extinguisher)
	_label("FOAM\nFIRE",Vector3(0,0.32,0.184),13,Color("8e332c"),_extinguisher)
	_extinguisher_home=_extinguisher.global_transform
	_station("extinguish",_extinguisher.position+Vector3(0,0.37,0),Vector3(0.62,0.85,0.65),"FOAM / FIRE")
	_register_highlight("extinguish",_extinguisher)
	_bell=_make_service_bell(Vector3(1.35,1.74,-0.75),self)
	_bell.name="CounterBell"
	_bell_button=_bell.get_meta("button")
	_station("bell",_bell.position+Vector3(0,0.15,0),Vector3(0.55,0.42,0.55),"RING BELL")
	_register_highlight("bell",_bell)
	_neighbor_bell=_make_service_bell(Vector3(-5.25,2.60,-5.2),self)
	_neighbor_bell.scale=Vector3.ONE*2.4
	_neighbor_bell.name="NeighborReplyBell"
	_box(Vector3(-5.25,2.55,-5.2),Vector3(1.0,0.1,0.75),"wood_dark")
	_label("NEXT STAND",Vector3(-5.25,2.35,-4.85),18,Color("e5cc9d"))
	var overlay: StandardMaterial3D=StandardMaterial3D.new()
	overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.albedo_color=Color(1.0,0.79,0.36,0.0)
	_station_overlays["customer"]=overlay
	_station_meshes["customer"]=[]
	_highlight_strengths["customer"]=0.0

func _make_service_bell(at: Vector3,parent: Node3D) -> Node3D:
	var bell: Node3D=Node3D.new()
	parent.add_child(bell)
	bell.position=at
	_cylinder(Vector3(0,0.025,0),0.23,0.05,"steel_dark",bell)
	var dome: MeshInstance3D=_sphere(Vector3(0,0.065,0),0.20,"brass",bell)
	dome.scale=Vector3(1,0.57,1)
	var button: Node3D=Node3D.new()
	bell.add_child(button)
	button.position=Vector3(0,0.19,0)
	_cylinder(Vector3.ZERO,0.035,0.06,"steel_light",button)
	_cylinder(Vector3(0,0.035,0),0.073,0.027,"brass",button)
	bell.set_meta("button",button)
	return bell

func _new_gag_node(label: String) -> Node3D:
	var node: Node3D=Node3D.new()
	node.name=label
	_gag_root.add_child(node)
	return node

func _gag_bubble(text_value: String, at: Vector3, color: Color=Color("ffe9a4")) -> void:
	var node: Node3D=_new_gag_node("ComicReaction")
	node.position=at
	var label: Label3D=_label(text_value,Vector3.ZERO,44,color,node)
	label.outline_size=24
	label.outline_modulate=Color("402c2b")
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=true
	_push_gag({"kind":"bubble","node":node,"age":0.0,"duration":1.15,"origin":at})

func _push_gag(gag: Dictionary) -> void:
	_gag_serial += 1
	gag["serial"] = _gag_serial
	while _gags.size()>=16:
		_free_gag(_gags.pop_front())
	_gags.append(gag)

func _free_gag(gag: Dictionary) -> void:
	if bool(gag.get("released", false)): return
	gag["released"] = true
	# Eviction has the same ownership obligations as natural completion.
	if str(gag.get("kind", "")) == "jab":
		var person: Node3D = gag.get("person")
		if is_instance_valid(person):
			# A capped effect can be evicted mid-recoil. Restore the same detail
			# transforms as natural completion before giving departure ownership.
			person.get_meta("portrait").transform = gag.portrait_origin
			var arms: Array = person.get_meta("arms")
			for index in range(arms.size()): arms[index].transform = gag.arm_origins[index]
			var eyes: Array = person.get_meta("eyes")
			for index in range(eyes.size()): eyes[index].scale = gag.eye_scales[index]
			person.scale = Transform3D(gag.origin).basis.get_scale()
			_depart_customer(person)
		if _punch_person == person: _punch_person = null
	elif str(gag.get("kind", "")) == "foam_spray":
		_extinguish_fire_hold = false
	if gag.has("donut") and is_instance_valid(gag.donut): gag.donut.queue_free()
	if gag.has("node") and is_instance_valid(gag.node): gag.node.queue_free()

func _sync_fire_visual() -> void:
	if not is_instance_valid(_fire_visual): return
	var burning: bool=bool(_state.get("fire_active",false)) or _extinguish_fire_hold
	var danger: float=float(_state.get("fire_danger",0.0)) if float(_state.get("fire_recovery",0.0))<=0.0 else 0.0
	var foam_time: float=float(_state.get("foam_time",0.0))
	_fire_visual.set_state(burning,danger,foam_time,_reduced_motion)
	_foam_visual.visible=foam_time>0.0
	_fire_light.light_energy=1.8 if burning else 0.0

func _start_customer_jab() -> void:
	var person: Node3D=_front_customer()
	if not is_instance_valid(person): return
	_punch_person=person
	for index in range(_motions.size()-1,-1,-1):
		if _motions[index].node==person: _motions.remove_at(index)
	var impact: Vector3=person.to_global(Vector3(0,2.82,0.20))
	_jab_marker.global_position=impact+Vector3(0.07,-0.035,0.04)
	var arm_origins: Array[Transform3D] = []
	for arm in person.get_meta("arms"): arm_origins.append(arm.transform)
	var eye_scales: Array[Vector3] = []
	for eye in person.get_meta("eyes"): eye_scales.append(eye.scale)
	_push_gag({"kind":"jab","age":0.0,"duration":JAB_RECOIL_DURATION,"person":person,"origin":person.transform,"impact":impact,"hit":false,"portrait_origin":person.get_meta("portrait").transform,"arm_origins":arm_origins,"eye_scales":eye_scales})

func _start_extinguisher() -> void:
	_extinguish_fire_hold=bool(_state.get("fire_active",false))
	_action_prop=_extinguisher
	var pose: Transform3D=Transform3D(Basis.from_euler(Vector3(0,0,-0.22)),Vector3(-0.10,2.45,1.15))
	_move_node(_extinguisher,pose,0.34,0.28,func():
		_move_node(_extinguisher,pose,0.54,0.0,func():
			_move_node(_extinguisher,_extinguisher_home,0.36,0.22,func(): _action_prop=null)))
	_motions.back()["delay"]=GRASP_TIME
	var spray: Node3D=_new_gag_node("ExtinguisherFoamJet")
	for i in range(26):
		var blob: MeshInstance3D=_sphere(Vector3.ZERO,0.045,"gag_foam",spray)
		blob.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.visible=false
	_push_gag({"kind":"foam_spray","node":spray,"age":0.0,"duration":1.1})

func play_gag(id: String, data: Dictionary={}) -> void:
	if id == "hat_toss":
		_toss_customer_hat(int(data.get("order_id", -1)))
		return
	if id == "seagulls_reveal":
		_expansion.reveal_seagulls(int(data.get("order_id", -1)))
		return
	if not is_instance_valid(_gag_root):
		if data.has("donut") and is_instance_valid(data.donut): data.donut.queue_free()
		return
	if id=="seagull":
		_start_seagull(data)
		return
	if id=="bell":
		_push_gag({"kind":"bell","age":0.0,"duration":0.42})
		return
	if id=="bell_reply":
		_push_gag({"kind":"bell_reply","age":0.0,"duration":1.05})
		_gag_bubble("DING DING!",_neighbor_bell.position+Vector3(0,0.95,0))
		gag_sound.emit("bell_reply")
		return
	var person: Node3D=_front_customer()
	if data.has("order_id"):
		person = _people.get(int(data.order_id), null)
		if not is_instance_valid(person):
			for leaving in _departing:
				if str(leaving.name) == "Fairgoer_%d" % int(data.order_id): person = leaving
	if id=="hat":
		if not is_instance_valid(person) or not person.has_meta("donut_hat"): return
		_push_gag({"kind":"reaction","age":0.0,"duration":1.0,"person":person,"reaction":"hat"})
		_gag_bubble("THAT'S MY HAT!",person.to_global(Vector3(0.52,3.34,0.35)))
		gag_sound.emit("hat")
	elif id=="sneeze":
		if not is_instance_valid(person): return
		var cloud: Node3D=_new_gag_node("PowderSneeze")
		cloud.position=person.to_global(Vector3(0,2.69,0.27))
		for i in range(15):
			var puff: MeshInstance3D=_sphere(Vector3(sin(float(i)*2.4)*0.14,cos(float(i)*1.7)*0.07,float(i%4)*0.06),0.075,"gag_powder",cloud)
			puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_push_gag({"kind":"sneeze","node":cloud,"age":0.0,"duration":0.74})
		_gag_bubble("ACHOO!",person.to_global(Vector3(0.50,3.30,0.35)))
		if is_instance_valid(person): _push_gag({"kind":"reaction","age":0.0,"duration":0.9,"person":person,"reaction":"duck"})
		if not _reduced_motion: _camera_kick=maxf(_camera_kick,0.035)
		gag_sound.emit("sneeze")
	elif id=="donut_shower":
		for customer in _people.values(): _push_gag({"kind":"reaction","age":0.0,"duration":0.95,"person":customer,"reaction":"duck"})
		if is_instance_valid(person): _gag_bubble("DONUT WEATHER!",person.to_global(Vector3(0.52,3.34,0.35)))
		gag_sound.emit("donut_shower")

func _start_seagull(data: Dictionary) -> void:
	if not data.has("donut") or not is_instance_valid(data.donut): return
	var donut: Node3D=data.donut
	donut.reparent(_gag_root,true)
	var origin: Vector3=data.get("from",donut.global_position)
	var gull: Node3D=_new_gag_node("DonutThiefGull")
	var body: MeshInstance3D=_sphere(Vector3.ZERO,0.17,"white",gull)
	body.scale=Vector3(0.8,0.85,1.35)
	_sphere(Vector3(0,0.13,0.19),0.11,"white",gull)
	var beak: MeshInstance3D=_cylinder(Vector3(0,0.11,0.31),0.045,0.15,"gag_flame_core",gull,0.004)
	beak.rotation.x=PI*0.5
	for side in [-1.0,1.0]:
		_sphere(Vector3(side*0.077,0.16,0.26),0.018,"eye",gull)
	var wings: Array[Node3D]=[]
	for side in [-1.0,1.0]:
		var wing: Node3D=Node3D.new()
		gull.add_child(wing)
		wing.position=Vector3(side*0.11,0.04,-0.03)
		var white: MeshInstance3D=_sphere(Vector3(side*0.24,0,-0.02),0.23,"white",wing)
		white.scale=Vector3(1.35,0.09,0.42)
		var tip: MeshInstance3D=_sphere(Vector3(side*0.49,0,-0.07),0.15,"steel_dark",wing)
		tip.scale=Vector3(1.1,0.10,0.42)
		wings.append(wing)
	gull.position=origin+Vector3(-4.0,1.5,-0.8)
	_push_gag({"kind":"seagull","node":gull,"donut":donut,"origin":origin,"age":0.0,"duration":2.15,"caught":false,"wings":wings})

func _update_gags(delta: float) -> void:
	_sync_fire_visual()
	if _fire_visual.visible:
		var burning: bool=bool(_state.get("fire_active",false)) or _extinguish_fire_hold
		_fire_visual.advance(delta)
		_fire_light.light_energy=(1.7 if _reduced_motion else 1.7+sin(_time*11.0)*0.20) if burning else 0.0
	if _foam_visual.visible:
		var coverage: float=clampf(float(_state.get("foam_time",0.0))/1.5,0.0,1.0)
		for foam in _foam_visual.get_children(): foam.scale.y=0.30*coverage
	# Impacts may add effects and evict old ones. A snapshot prevents those
	# insertions from advancing a gag twice or removing a different entry.
	var frame_gags: Array[Dictionary] = _gags.duplicate()
	frame_gags.reverse()
	for gag in frame_gags:
		if not _gags.has(gag): continue
		gag.age=float(gag.age)+delta
		var t: float=clampf(float(gag.age)/float(gag.duration),0.0,1.0)
		match str(gag.kind):
			"bubble":
				if is_instance_valid(gag.node):
					gag.node.position=Vector3(gag.origin)+Vector3(0,t*0.20,0)
					gag.node.scale=Vector3.ONE*(1.0-smoothstep(0.78,1.0,t))
			"bell":
				_bell_button.position.y=0.19-sin(t*PI)*0.055
				_bell.rotation.z=0.0 if _reduced_motion else sin(t*TAU*4.0)*(1.0-t)*0.06
			"bell_reply":
				_neighbor_bell.rotation.z=0.0 if _reduced_motion else sin(t*TAU*4.0)*sin(t*PI)*0.24
				_neighbor_bell.position.y=2.60+(0.0 if _reduced_motion else sin(t*PI)*0.15)
			"jab":
				var person: Node3D=gag.person
				if is_instance_valid(person):
					if not bool(gag.hit) and float(gag.age)>=JAB_IMPACT_TIME:
						gag.hit=true
						gag_sound.emit("punch")
						_gag_bubble("POW!",Vector3(gag.impact)+Vector3(-0.35,0.43,0.05))
						_comic_stars(person)
						_comic_impact(Vector3(gag.impact)+Vector3(0,0,0.13))
					_animate_jab_recoil(gag)
			"stars":
				if is_instance_valid(gag.node):
					if is_instance_valid(gag.get("person")): gag.node.global_position=gag.person.to_global(Vector3(0,3.24,0))
					gag.node.rotation.y+=delta*(0.25 if _reduced_motion else 6.0)
					gag.node.scale=Vector3.ONE*(1.0-smoothstep(0.72,1.0,t))
			"comic_impact":
				if is_instance_valid(gag.node):
					gag.node.scale=Vector3.ONE*(0.60+t*1.4)*(1.0-smoothstep(0.46,1.0,t))
			"reaction":
				var person: Node3D=gag.person
				if is_instance_valid(person):
					var portrait: Node3D=person.get_meta("portrait")
					var response: float=sin(t*PI)
					portrait.rotation.x=(0.07 if _reduced_motion else 0.27)*response
					portrait.position.y-=response*(0.04 if _reduced_motion else 0.14)
					if gag.reaction=="hat":
						portrait.rotation.y=sin(t*TAU*2.0)*response*(0.025 if _reduced_motion else 0.20)
						var hat: Node3D=person.get_meta("donut_hat")
						hat.rotation.z=0.12+sin(t*TAU*2.0)*response*0.24
					else:
						for arm in person.get_meta("arms"): arm.rotation.x=-0.70*response
			"sneeze":
				if is_instance_valid(gag.node):
					gag.node.position.z+=delta*1.1
					gag.node.scale=Vector3.ONE*(1.0+t*2.4)*(1.0-smoothstep(0.50,1.0,t))
			"foam_spray":
				var spray_on: bool=float(gag.age)>=0.40 and float(gag.age)<=1.0
				gag.node.visible=spray_on
				if float(gag.age)>0.50: _extinguish_fire_hold=false
				if spray_on:
					var start: Vector3=_extinguisher.to_global(Vector3(-0.25,0.64,0))
					var finish: Vector3=Vector3(-2.6+sin(float(gag.age)*11.0)*0.95,2.15,-0.5)
					for i in range(gag.node.get_child_count()):
						var blob: Node3D=gag.node.get_child(i)
						var travel: float=fmod(float(gag.age)*4.0+float(i)/26.0,1.0)
						blob.global_position=start.lerp(finish,travel)+Vector3(sin(float(i)*2.4),cos(float(i)*1.7),0)*travel*0.10
						blob.scale=Vector3.ONE*(0.55+travel*1.9)
			"seagull":
				var bird: Node3D=gag.node
				if not is_instance_valid(bird): continue
				var origin: Vector3=gag.origin
				if float(gag.age)<0.45:
					bird.position=(origin+Vector3(-4.0,1.5,-0.8)).lerp(origin+Vector3(0,0.10,-0.31),smoothstep(0.0,0.45,float(gag.age)))
					if is_instance_valid(gag.donut): gag.donut.global_position=origin+Vector3(0,sin(float(gag.age)*PI/0.45)*0.06,0)
				else:
					if not bool(gag.caught):
						gag.caught=true
						if is_instance_valid(gag.donut):
							gag.donut.reparent(bird,true)
							gag.donut.position=Vector3(0,-0.02,0.31)
						gag_sound.emit("seagull")
					bird.position=(origin+Vector3(0,0.10,-0.31)).lerp(origin+Vector3(5.0,3.0,-3.0),smoothstep(0.45,2.15,float(gag.age)))
					bird.rotation.y=-0.70
				for i in range(gag.wings.size()): gag.wings[i].rotation.z=(-1.0 if i==0 else 1.0)*(0.18 if _reduced_motion else sin(float(gag.age)*18.0)*0.48)
		if t>=1.0:
			_free_gag(gag)
			_gags.erase(gag)

func _animate_jab_recoil(gag: Dictionary) -> void:
	var person: Node3D = gag.person
	var age: float = maxf(0.0,float(gag.age)-JAB_IMPACT_TIME)
	var kick: float = 1.0-exp(-age*42.0)
	var recovery: float = smoothstep(0.30,0.59,age)
	var spring: float = sin(age*34.0)*exp(-age*5.5)*kick
	var squash: float = sin(clampf(age/0.105,0.0,1.0)*PI)
	var stretch: float = sin(clampf((age-0.105)/0.20,0.0,1.0)*PI)
	var hop: float = sin(clampf(age/0.36,0.0,1.0)*PI)
	var pivot: Vector3 = Vector3(0,1.75,0)
	var body: Basis = Basis.IDENTITY
	if not _reduced_motion:
		body = Basis.from_euler(Vector3(-0.38*kick*(1.0-recovery),0.10*spring,0.24*spring))
		body = body.scaled(Vector3(1.0+squash*0.12-stretch*0.045,1.0-squash*0.18+stretch*0.12,1.0+squash*0.08))
	person.transform = Transform3D(gag.origin)*Transform3D(body,pivot-body*pivot)
	person.position += Vector3(-smoothstep(0.05,0.56,age)*(0.16 if _reduced_motion else 0.48),0.0 if _reduced_motion else hop*0.22,-kick*(1.0-recovery*0.20)*(0.18 if _reduced_motion else 0.66))
	var portrait: Node3D = person.get_meta("portrait")
	var neck: Vector3 = Vector3(0,2.61,0)
	var head: Basis = Basis.IDENTITY if _reduced_motion else Basis.from_euler(Vector3(0.12*spring,0.25*spring,-0.20*kick*(1.0-recovery)+spring*0.25))
	portrait.transform = Transform3D(gag.portrait_origin)*Transform3D(head,neck-head*neck)
	var arms: Array = person.get_meta("arms")
	for index in range(arms.size()):
		arms[index].transform = gag.arm_origins[index]
		if not _reduced_motion:
			arms[index].rotation.x -= kick*(1.0-recovery)*1.15
			arms[index].rotation.z += (-1.0 if index==0 else 1.0)*kick*(1.0-recovery)*(0.60+spring*0.24)
	var eyes: Array = person.get_meta("eyes")
	for index in range(eyes.size()):
		eyes[index].scale = gag.eye_scales[index]*Vector3(1.0,1.0 if _reduced_motion else 1.0+kick*(1.0-recovery)*0.80,1.0)

func _comic_impact(at: Vector3) -> void:
	var node: Node3D = _new_gag_node("ComicImpact")
	node.position = at
	for index in range(6 if _reduced_motion else 9):
		var angle: float = float(index)*TAU/(6.0 if _reduced_motion else 9.0)
		var ray: MeshInstance3D = _box(Vector3(cos(angle),sin(angle),0)*0.18,Vector3(0.12,0.032,0.012),"gold_light",node)
		ray.rotation.z = angle
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_push_gag({"kind":"comic_impact","node":node,"age":0.0,"duration":0.19})

func _comic_stars(person: Node3D) -> void:
	var node: Node3D=_new_gag_node("ComicStars")
	node.position=person.to_global(Vector3(0,3.24,0))
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in range(10):
		for vertex in [Vector3.ZERO,Vector3(cos(float(point)*PI/5.0+PI*0.5),sin(float(point)*PI/5.0+PI*0.5),0)*(0.085 if point%2==0 else 0.036),Vector3(cos(float(point+1)*PI/5.0+PI*0.5),sin(float(point+1)*PI/5.0+PI*0.5),0)*(0.085 if (point+1)%2==0 else 0.036)]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("ffd35d")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(5):
		var star: MeshInstance3D = MeshInstance3D.new()
		node.add_child(star)
		star.mesh = mesh
		star.material_override = material
		star.position = Vector3(cos(float(i)*TAU/5.0)*0.36,sin(float(i)*TAU/5.0)*0.06,sin(float(i)*TAU/5.0)*0.29)
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_push_gag({"kind":"stars","node":node,"person":person,"age":0.0,"duration":0.95})

func _reset_gags() -> void:
	_set_customer_highlight(null)
	for gag in _gags: _free_gag(gag)
	_gags.clear()
	for effect in _effects:
		if is_instance_valid(effect.node): effect.node.queue_free()
	_effects.clear()
	_punch_person=null
	_extinguish_fire_hold=false
	if is_instance_valid(_extinguisher): _extinguisher.global_transform=_extinguisher_home
	if is_instance_valid(_bell):
		_bell.rotation=Vector3.ZERO
		_bell_button.position.y=0.19
	if is_instance_valid(_neighbor_bell):
		_neighbor_bell.rotation=Vector3.ZERO
		_neighbor_bell.position.y=2.60
	if is_instance_valid(_fire_visual):
		_fire_visual.reset()
		_foam_visual.visible=false
		_fire_light.light_energy=0.0


func air_mail_target_open() -> bool:
	return is_instance_valid(_prep) and _prep_type == "bag" and _prep_flavor.is_empty() and int(_state.get("package_count", 0)) < 6 and _held_type != "package" and not _node_is_moving(_prep) and not _paused

func try_air_mail(stock_id: int, previous: Vector3, current: Vector3) -> bool:
	if not air_mail_target_open(): return false
	var a: Vector3 = _prep.to_local(previous)
	var b: Vector3 = _prep.to_local(current)
	# Swept centre crossing is evaluated at the actual lip, with crust clearance.
	var mouth_y: float = 0.61
	if a.y < mouth_y or b.y >= mouth_y or b.y >= a.y: return false
	var crossing: Vector3 = a.lerp(b, (a.y-mouth_y)/(a.y-b.y))
	if absf(crossing.x)>0.15 or absf(crossing.z)>0.10: return false
	_air_mail_offer_id = stock_id
	_air_mail_accepted = false
	air_mail_caught.emit(stock_id)
	return _air_mail_accepted

func resolve_air_mail(stock_id: int, accepted: bool) -> void:
	if stock_id == _air_mail_offer_id: _air_mail_accepted = accepted

func accept_air_mail_visual(visual: Node3D) -> void:
	if not is_instance_valid(_prep):
		visual.queue_free()
		return
	visual.reparent(_prep, true)
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var index: int = _prep_donuts.size()
	_prep_donuts.append(visual)
	var target: Transform3D = _prep.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * FoodGeometry.DONUT_SCALE), _package_donut_position(index,"bag"))
	_move_node(visual,target,0.20,0.0)


func _toss_customer_hat(order_id: int) -> void:
	var person: Node3D = _people.get(order_id)
	if not is_instance_valid(person) or _held_scoop_donuts.is_empty(): return
	var donut: Node3D = _held_scoop_donuts.pop_back()
	var portrait: Node3D = person.get_meta("portrait")
	var at: Vector3 = Vector3(0,3.16,0)
	if str(person.get_meta("special","")) == "seagulls": at = Vector3(0,0.58,0)
	var target: Transform3D = Transform3D(Basis.from_euler(Vector3(0.24,0,0.12)).scaled(Vector3.ONE * FoodGeometry.DONUT_SCALE),at)
	donut.reparent(self,true)
	_action = "hat_toss"
	_action_duration = 0.58
	_action_time = 0.58
	_move_node(donut,portrait.global_transform*target,0.52,0.85,func():
		if not is_instance_valid(donut): return
		if not is_instance_valid(person) or not is_instance_valid(portrait):
			donut.queue_free()
			return
		if person.has_meta("donut_hat") and is_instance_valid(person.get_meta("donut_hat")): person.get_meta("donut_hat").queue_free()
		donut.reparent(portrait,true)
		donut.transform = target
		donut.name = "PlayerDonutHat"
		person.set_meta("donut_hat",donut)
		play_gag("hat",{"order_id":order_id}))
	_motions.back()["target_node"] = portrait
	_motions.back()["target_local"] = target


func air_mail_flight_candidate(position: Vector3, velocity: Vector3) -> bool:
	if not air_mail_target_open(): return false
	var toward: Vector3 = _prep.global_position-position
	toward.y = 0.0
	var horizontal: Vector3 = Vector3(velocity.x,0,velocity.z)
	return toward.length()<0.65 or horizontal.dot(toward)>0.12


func reserve_food_ids(ids: Array) -> void:
	if not is_instance_valid(_food): return
	for value in ids:
		var id: int = int(value)
		if id < 0: _food._seed_serial = mini(_food._seed_serial,id-1)
