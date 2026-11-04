extends SceneTree
## Inspect the real runtime art and colliders, so regressions in scale, shading,
## printed labels and assigned surface maps fail before a release is exported.
var checks: int = 0
var failures: int = 0
var world

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _bounds(mesh: Mesh) -> Dictionary:
	var inner: float = INF
	var outer: float = 0.0
	for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var radial: float = Vector2(vertex.x, vertex.z).length()
		inner = minf(inner, radial)
		outer = maxf(outer, radial)
	return {"inner": inner, "outer": outer, "height": mesh.get_aabb().size.y}

func _surface_integrity(mesh: Mesh, label: String) -> void:
	check(mesh.get_surface_count() == 1, label + " has a complete render surface")
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for index in range(vertices.size()): indices.append(index)
	check(vertices.size() > 100 and normals.size() == vertices.size() and uvs.size() == vertices.size(), label + " supplies positions, smooth normals and UVs for every vertex")
	var valid_normals: bool = true
	var valid_faces: bool = true
	var valid_uvs: bool = true
	var outward: bool = true
	var uv_min: Vector2 = Vector2(INF, INF)
	var uv_max: Vector2 = Vector2(-INF, -INF)
	for index in range(vertices.size()):
		valid_normals = valid_normals and vertices[index].is_finite() and normals[index].is_finite() and absf(normals[index].length() - 1.0) < 0.002
		uv_min = uv_min.min(uvs[index])
		uv_max = uv_max.max(uvs[index])
	for index in range(0, indices.size(), 3):
		var a: int = indices[index]
		var b: int = indices[index + 1]
		var c: int = indices[index + 2]
		var face: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		valid_faces = valid_faces and face.length() > 0.00000001
		valid_uvs = valid_uvs and absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) > 0.000001
		outward = outward and face.dot(normals[a] + normals[b] + normals[c]) < 0.0
	check(valid_normals, label + " has finite unit lighting normals")
	check(valid_faces and valid_uvs, label + " contains no collapsed geometric or UV triangles")
	check(outward, label + " uses outward lighting with Godot clockwise face winding")
	check(uv_min.distance_to(Vector2.ZERO) < 0.001 and uv_max.distance_to(Vector2.ONE) < 0.001, label + " maps the full texture without a collapsed coordinate axis")
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var valid_tangents: bool = tangents.size() == vertices.size() * 4
	for tangent in tangents: valid_tangents = valid_tangents and is_finite(tangent)
	check(valid_tangents, label + " provides finite normal-map tangents")

func _has_material(node: Node, material: Material) -> bool:
	if node is GeometryInstance3D and node.material_override == material: return true
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			if node.get_active_material(surface) == material: return true
	for child in node.get_children():
		if _has_material(child, material): return true
	return false

func _texture_valid(texture: Texture2D) -> bool:
	return texture != null and texture.get_width() >= 256 and texture.get_height() >= 256

func _texture_has_detail(texture: Texture2D) -> bool:
	if not _texture_valid(texture): return false
	var image: Image = texture.get_image()
	if image == null or image.is_empty(): return false
	if image.is_compressed() and image.decompress() != OK: return false
	var lowest: Vector3 = Vector3.ONE
	var highest: Vector3 = Vector3.ZERO
	for y in range(16):
		for x in range(16):
			var pixel: Color = image.get_pixel(int((float(x) + 0.5) / 16.0 * image.get_width()), int((float(y) + 0.5) / 16.0 * image.get_height()))
			var rgb: Vector3 = Vector3(pixel.r, pixel.g, pixel.b)
			lowest = lowest.min(rgb)
			highest = highest.max(rgb)
	return highest.distance_to(lowest) > 0.01

func _run() -> void:
	root.size = Vector2i(1280, 800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.reset_food(1, 36)
	world._food.set_paused(true)
	world._make_package("bag", world)
	_surface_integrity(world._donut_mesh, "Cake donut")
	_surface_integrity(world._coating_mesh, "Sugar coating")
	var cake: Dictionary = _bounds(world._donut_mesh)
	var coating: Dictionary = _bounds(world._coating_mesh)
	var entry: Dictionary = world._food._entries[0]
	var visual: Node3D = entry.visual
	var scale_value: float = visual.scale.x
	check(visual.scale.is_equal_approx(Vector3.ONE * scale_value), "Live donuts use uniform scaling without distorting the cake profile")
	var diameter: float = cake.outer * 2.0 * scale_value
	check(diameter > 0.20 and diameter < 0.34, "Live donuts remain mini size relative to the tray and scoop")
	check(cake.height / (cake.outer * 2.0) > 0.18 and cake.height / (cake.outer * 2.0) < 0.38, "Cake profile is flatter than a round inflated torus")
	check(cake.inner > 0.0 and cake.inner / cake.outer < 0.10, "Cake donut retains a small open pinhole")
	check(coating.inner > 0.002 and coating.inner < cake.inner, "Sugar shell preserves the through-hole instead of plugging the center")
	check(coating.outer > cake.outer and coating.outer < cake.outer * 1.04 and coating.height > cake.height and coating.height < cake.height * 1.06, "Sugar remains a thin shell around the cake surface")
	check(visual.get_child(0).mesh == world._donut_mesh, "The inspected mini-donut mesh is used by actual physical food")
	var shapes: Array[CollisionShape3D] = []
	for child in entry.body.get_children():
		if child is CollisionShape3D: shapes.append(child)
	var radial_capsules: bool = shapes.size() >= 6
	var hole_open: bool = true
	for node in shapes:
		if not node.shape is CapsuleShape3D:
			radial_capsules = false
			continue
		var axis: Vector3 = node.basis.y.normalized()
		radial_capsules = radial_capsules and absf(axis.y) < 0.001 and absf(axis.dot(node.position.normalized())) > 0.99
		hole_open = hole_open and node.position.length() - node.shape.height * 0.5 > 0.0
	check(radial_capsules, "Live collider capsules lie radially in the cake plane, not vertically like tall pegs")
	check(hole_open, "Collider capsules preserve the center opening")
	var bounds_match: bool = true
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var support: float = -INF
		for node in shapes:
			if not node.shape is CapsuleShape3D: continue
			var radius: float = node.shape.radius
			var extent: float = maxf(0.0, node.shape.height * 0.5 - radius)
			support = maxf(support, node.position.dot(direction) + radius + extent * absf(direction.dot(node.basis.y)))
		var visual_support: float = -INF
		for vertex in world._donut_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			visual_support = maxf(visual_support, (vertex * visual.scale).dot(direction))
		bounds_match = bounds_match and absf(support - visual_support) < 0.012
	check(bounds_match, "Physical outer edges and cake height agree with visible geometry within a small crust margin")
	var label_textures: Array[Texture2D] = []
	for flavor in ["cinnamon", "powdered"]:
		var label: MeshInstance3D = world._shakers[flavor].get_node("PrintedPaperLabel")
		var material: StandardMaterial3D = label.material_override
		check(label.get_meta("printed_flavor") == flavor and _texture_valid(material.albedo_texture), flavor + " shaker has an actual high-resolution printed label")
		check(material.albedo_texture.resource_path == "res://assets/art/shaker_" + flavor + ".svg", flavor + " shaker uses its authored SVG artwork")
		check(_texture_has_detail(material.albedo_texture), flavor + " SVG imports into visible printed texture content")
		label_textures.append(material.albedo_texture)
		_surface_integrity(label.mesh, flavor + " label")
		var radial_min: float = INF
		var radial_max: float = 0.0
		for vertex in label.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var radius: float = Vector2(vertex.x, vertex.z).length()
			radial_min = minf(radial_min, radius)
			radial_max = maxf(radial_max, radius)
		check(radial_max - radial_min < 0.001 and label.mesh.get_aabb().size.z > 0.05, flavor + " label follows the curved shaker body instead of floating as a flat panel")
	check(label_textures[0] != label_textures[1], "The two flavor shakers have distinct readable artwork")
	for key in ["wood", "wood_light", "wood_dark", "paper_bag", "paper_fold", "package_inside"]:
		var material: StandardMaterial3D = world._mat[key]
		var prefix: String = "res://assets/materials/" + ("counter_wood" if key.begins_with("wood") else "kraft_paper")
		check(_texture_valid(material.albedo_texture) and material.albedo_texture.resource_path == prefix + "_color.png", key + " uses the generated authored color map")
		check(material.normal_enabled and material.normal_scale > 0.0 and _texture_valid(material.normal_texture) and material.normal_texture.resource_path == prefix + "_normal.png", key + " has an active matching normal map")
		check(_texture_valid(material.roughness_texture) and material.roughness_texture.resource_path == prefix + "_roughness.png" and material.roughness > 0.0, key + " has a matching roughness map affecting the actual material")
	check(_has_material(world, world._mat.wood_light), "Generated wood material is assigned to visible world geometry")
	check(_has_material(world, world._mat.paper_bag), "Generated kraft paper material is assigned to actual bags")
	for key in ["wood_light", "paper_bag"]:
		var material: StandardMaterial3D = world._mat[key]
		check(_texture_has_detail(material.albedo_texture), key + " color image contains surface detail rather than a blank fill")
		check(_texture_has_detail(material.normal_texture), key + " normal image contains usable surface relief")
		check(_texture_has_detail(material.roughness_texture), key + " roughness image contains varying surface response")
	world.reset_food(0, 36)
	world.queue_free()
	await process_frame
	await process_frame
	print("STAND ART QA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
