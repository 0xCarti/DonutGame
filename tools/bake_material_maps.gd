extends SceneTree
## Derive restrained micro-normal/roughness maps from the original base scans.
## Base-color artwork is retained untouched; these are separate runtime assets.
func _init() -> void:
	for kind in ["counter_wood", "kraft_paper"]:
		var color: Image = Image.load_from_file("res://assets/materials/" + kind + "_color.png")
		color.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		var bump: Image = Image.create(512, 512, false, Image.FORMAT_RGB8)
		var rough: Image = Image.create(512, 512, false, Image.FORMAT_RGB8)
		for y in range(512):
			for x in range(512):
				var luma: float = color.get_pixel(x, y).get_luminance()
				bump.set_pixel(x, y, Color(luma, luma, luma))
				var r: float = clampf((0.61 if kind == "counter_wood" else 0.90) + (luma - 0.5) * 0.16, 0.0, 1.0)
				rough.set_pixel(x, y, Color(r, r, r))
		bump.bump_map_to_normal_map(3.5 if kind == "counter_wood" else 1.8)
		bump.save_png("res://assets/materials/" + kind + "_normal.png")
		rough.save_png("res://assets/materials/" + kind + "_roughness.png")
		print("BAKED_MATERIAL_MAPS ", kind)
	quit()
