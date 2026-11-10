extends SceneTree
## Run from an empty project directory so source files cannot mask pack omissions.

const EVENT_ART = ["crew", "customer", "machine", "opportunity", "story", "travel", "weather"]
const ICON_ART = ["arrow", "bag", "calendar", "cash", "check", "clock", "close", "coin", "crew", "fryer",
	"garage", "heart", "info", "journal", "location", "map", "recipe", "rep", "rest", "settings",
	"shield", "skill", "stand", "star", "stock", "train", "truck", "upgrade", "weather", "wrench"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0]):
		push_error("Could not mount the exported Circuit resource pack")
		quit(1)
		return
	for path in ["res://scripts/circuit_model.gd", "res://scripts/circuit_content.gd",
		"res://docs/licenses/Godot-LICENSE.txt", "res://docs/licenses/Godot-COPYRIGHT.txt",
		"res://docs/licenses/ASSET-PROVENANCE.txt",
		"res://docs/licenses/ART-VISUAL-UPDATE.txt",
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
	# Build the asset inventory from the packed catalogue, never the source tree.
	var catalog = load("res://scripts/circuit_content.gd")
	if catalog == null:
		push_error("Could not load the exported Circuit catalogue")
		quit(1)
		return
	var art_paths: Array[String] = []
	for venue in catalog.VENUES: art_paths.append("venues/" + str(venue.id))
	for person in catalog.STAFF: art_paths.append("crew/" + str(person.id))
	for recipe in catalog.RECIPES: art_paths.append("recipes/" + str(recipe.id))
	for gear in [["fryer", catalog.FRYERS], ["truck", catalog.TRUCKS], ["stand", catalog.STANDS]]:
		for level in range(gear[1].size()): art_paths.append("equipment/%s_%d" % [gear[0], level])
	for key in EVENT_ART: art_paths.append("events/" + key)
	for key in ICON_ART: art_paths.append("icons/" + key)
	if art_paths.size() != 85:
		push_error("Expected 85 illustrated UI assets in the exported catalogue; found %d" % art_paths.size())
		quit(1)
		return
	var loaded: Dictionary = {}
	for key in art_paths:
		var path = "res://assets/ui/" + key + ".svg"
		if loaded.has(path):
			push_error("Duplicate UI asset in the exported catalogue: " + path)
			quit(1)
			return
		var texture = load(path)
		if not texture is Texture2D or texture.get_width() <= 0 or texture.get_height() <= 0:
			push_error("Missing or invalid exported UI texture: " + path)
			quit(1)
			return
		loaded[path] = true
	print("PASS: %d UI textures loaded from the isolated exported pack, with catalogue, license notices and runtime resources" % loaded.size())
	quit(0)
