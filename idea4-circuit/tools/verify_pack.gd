extends SceneTree
## Run from an empty project directory so source files cannot mask pack omissions.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0]):
		push_error("Could not mount the exported Circuit resource pack")
		quit(1)
		return
	for path in ["res://scripts/circuit_model.gd", "res://scripts/circuit_content.gd",
		"res://docs/licenses/Godot-LICENSE.txt", "res://docs/licenses/Godot-COPYRIGHT.txt",
		"res://docs/licenses/ASSET-PROVENANCE.txt",
		"res://assets/fonts/OFL.txt"]:
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".remap"):
			push_error("Missing exported resource: " + path)
			quit(1)
			return
	for folder in ["res://tests", "res://tools", "res://unity"]:
		if DirAccess.dir_exists_absolute(folder):
			push_error("Development folder leaked into runtime pack: " + folder)
			quit(1)
			return
	if FileAccess.file_exists("res://scripts/stand_main.gd"):
		push_error("Unrelated prior game found in Circuit pack")
		quit(1)
		return
	print("PASS: Circuit resources, license notices, and isolated runtime pack")
	quit(0)
