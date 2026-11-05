extends SceneTree
var world: Node3D
var state: Dictionary = {"phase":"playing","temperature":180.0,"batter":50,"supply":18,"supply_capacity":36,"production_speed":2,"held_tool":"scoop","package_type":"bag","package_count":0,"package_flavor":"","orders":[{"id":9001,"special":"seagulls","package":"bag","flavor":"cinnamon","patience":60,"max_patience":60}],"cosmetic_loadout":{"stand":"neon_midway","operator_gloves":"chrome_carnival_gloves","operator_sleeves":"grandmas_recipe_sleeves","operator_watch":"chrome_carnival_watch","counter_packaging":"neon_midway_packaging"}}
func _init() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await process_frame
func snap(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://playtest-reports/world-expansion-"+id+".png")
func run() -> void:
	root.size = Vector2i(1280,800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.reset_food(18,36)
	for venue in ["fairground","concert","stadium"]:
		state.venue_id = venue
		state.machine_id = "festival_pro" if venue=="stadium" else "twin_lane"
		world.sync_state(state)
		for i in range(6): world.enqueue_production(50000+i)
		await frames(100)
		await snap(venue)
	world.play_gag("seagulls_reveal",{"order_id":9001})
	await frames(32)
	await snap("seagulls")
	world.reset_food(1,36)
	state.orders = []
	state.batter = 0
	state.package_count = 0
	world.sync_state(state)
	world.air_mail_caught.connect(func(id: int): world.resolve_air_mail(id,true))
	var entry: Dictionary = world._food._entries[0]
	entry.launched_burst = 1
	entry.launch_age = 0.0
	entry.body.position = Vector3(-0.45,2.17,1.45)
	entry.previous_position = entry.body.global_position
	entry.body.sleeping = false
	entry.body.linear_velocity = Vector3(1.9,3.3,1.06)
	await frames(26)
	await snap("air-mail-flight")
	await frames(36)
	await snap("air-mail-caught")
	print("PHYSICAL AIR MAIL CAPTURE ",world._prep_donuts.size()," caught; ",world._food.get_available_count()," stock")
	quit()
