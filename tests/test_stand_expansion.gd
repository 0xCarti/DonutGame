extends SceneTree
var checks: int = 0
var failures: int = 0
var offers: Array[int] = []
var spills: Array[int] = []
var accept: bool = true
var world: Node3D
var state: Dictionary = {"phase":"playing","temperature":180.0,"batter":0,"supply":0,"supply_capacity":36,"held_tool":"none","package_type":"","orders":[]}
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func advance(seconds: float) -> void:
	for i in range(ceili(seconds*60)): world._process(1.0/60.0)
func _run() -> void:
	root.size = Vector2i(1280,800)
	world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.sync_state(state)
	var original: Node3D = world._venue_root
	for venue in ["concert","stadium","fairground"]:
		state.venue_id = venue
		world.sync_state(state)
		check(world._expansion.venue_id==venue and world._venue_root.visible,"Selected venue is physically visible: "+venue)
		var visible_count: int = 0
		for node in world._expansion.venues.values():
			if node.visible: visible_count += 1
		check(visible_count==1,"Only one venue is rendered")
		if venue!="fairground":
			var report: Dictionary = world._venue_root.get_meta("batch_report")
			check(int(report.source_meshes)>30 and int(report.batches)<25,"New venue static geometry is batched")
	check(world._venue_root==original,"Returning to fairground reuses original scenery")
	for machine in ["compact","twin_lane","festival_pro"]:
		state.machine_id = machine
		world.sync_state(state)
		check(world._food._lane_count==["compact","twin_lane","festival_pro"].find(machine)+1,"Machine config uses correct actual feed lanes")
		for id in world._expansion.machines: check(world._expansion.machines[id].visible==(id==machine),"Only equipped machine attachment visible")
	world.reset_food(0,60)
	world.enqueue_production(8001)
	world.enqueue_production(8002)
	world.enqueue_production(8003)
	var lanes: Dictionary = {}
	for entry in world._food._entries: lanes[entry.lane] = true
	check(lanes.size()==3,"Festival production emits in three physical bath lanes")
	check(world._food.lane_position(0.2,-0.312).distance_to(world._food.lane_position(0.2,0.312))>0.6,"Bath lanes are spatially separate")
	check(world._food.lane_position(0.8,-0.312).is_equal_approx(world._food.lane_position(0.8,0.312)),"Lanes smoothly converge before shared discharge chute")
	world._food.set_machine_profile("compact",1)
	world.reset_food(0,36,[8101,8102,8103])
	var pending_ids: Array = []
	for pending in world._food._entries: pending_ids.append(pending.id)
	world._food.set_machine_profile("festival_pro",2)
	var replay_lanes: Dictionary = {}
	var replay_ids: Array = []
	for pending in world._food._entries:
		replay_lanes[pending.lane] = true
		replay_ids.append(pending.id)
	check(replay_lanes.size()==3 and pending_ids==replay_ids,"Resume profile redistributes queued feed lanes without changing pending identities")
	world.reset_food(0,36)
	var heat: Array[Vector3] = [world._heat_knobs[0].rotation,world._heat_knobs[1].rotation]
	state.production_speed = 2
	world.sync_state(state)
	world.animate_action("speed_up")
	advance(0.1)
	check(world._expansion.speed_knob.rotation.z < -0.15 and world._expansion.speed_knob.rotation.z > -0.82,"Feed knob eases clockwise toward the right-hand Fast mark")
	check(world._heat_knobs[0].rotation.is_equal_approx(heat[0]) and world._heat_knobs[1].rotation.is_equal_approx(heat[1]),"Feed click does not animate heat dials")
	advance(0.8)
	check(absf(world._expansion.speed_knob.rotation.z+0.82)<0.001,"Feed knob settles at the right-hand Fast position")
	check(is_equal_approx(world._food._feed_multiplier,1.32),"Fast speed changes actual conveyor travel")
	state.production_speed = 0
	world.sync_state(state)
	advance(1.0)
	check(absf(world._expansion.speed_knob.rotation.z-0.82)<0.001,"Feed knob settles at the left-hand Slow position")
	state.production_speed = 1
	world.sync_state(state)
	advance(1.0)
	check(absf(world._expansion.speed_knob.rotation.z)<0.001,"Feed knob settles upright at Normal")
	state.batter = 20
	state.production_speed = 1
	world.sync_state(state)
	advance(0.28)
	var prior_piston: float = world._hopper_piston.position.y
	state.production_speed = 2
	world.sync_state(state)
	world._process(0.0)
	check(is_equal_approx(world._hopper_piston.position.y,prior_piston),"Speed change preserves piston phase with no animation jump")
	state.batter = 0
	var root_ids: Dictionary = {}
	for venue in world._expansion.venues: root_ids[venue] = world._expansion.venues[venue].get_instance_id()
	var baseline_light_count: int = world.find_children("*","Light3D",true,false).size()
	for quality in [0,1,2]:
		world.set_quality(quality,true)
		for venue in ["fairground","concert","stadium"]:
			state.venue_id = venue
			world.sync_state(state)
			check(world._venue_root.get_instance_id()==root_ids[venue],"Quality and repeated venue changes reuse cached geometry")
			check(world.find_children("*","Light3D",true,false).size()==baseline_light_count,"New venue emission adds no shadow-casting lights")
			check(world._sunlight.shadow_enabled==(quality>=1),"All venues obey mobile quality directional-shadow policy")
			var detail_shadows: int = 0
			for light in world._detail_lights:
				if light.shadow_enabled: detail_shadows += 1
			check(detail_shadows==(1 if quality==2 else 0),"All venues obey task-light shadow budget")
	for venue in ["concert","stadium"]:
		var report: Dictionary = world._expansion.venues[venue].get_meta("batch_report")
		print("VENUE GEOMETRY ",venue,": ",report.source_meshes," sources -> ",report.batches," batches; ",int(report.batch_indices)/3," triangles")
	world.set_quality(2,false)
	state.paused = true
	state.cosmetic_loadout = {"stand":"neon_midway","operator_gloves":"chrome_carnival_gloves","operator_sleeves":"grandmas_recipe_sleeves","operator_watch":"chrome_carnival_watch","counter_tipjar":"neon_midway_tipjar","counter_bell":"grandmas_recipe_bell","counter_shaker":"chrome_carnival_shaker","counter_packaging":"neon_midway_packaging","celebration":"celebration_tickets"}
	world.sync_state(state)
	check(world._mat.red.albedo_color.is_equal_approx(Color("7254c7")),"Paused preview applies equipped stand palette")
	check(world._arm_rigs[0].fore_material.get_shader_parameter("sleeve_color").is_equal_approx(Color("aa4747")),"Sleeves are independently equipped shader surfaces")
	check(world._expansion._jar_trim.material_override.albedo_color.is_equal_approx(Color("6cf3dc")),"Tip jar visibly uses its own equipped cosmetic")
	check(world._expansion._watch_face.material_override.metallic>0.8,"Chrome watch has distinct visible metallic finish")
	check(world._expansion.celebration_particle(0).size.y>0.1,"Tickets use a distinct particle shape")
	state.cosmetic_loadout.stand = "grandmas_recipe"
	world.sync_state(state)
	check(world._mat.red.albedo_texture==world._expansion._gingham,"Grandma set applies actual checked textile")
	state.cosmetic_loadout.stand = "chrome_carnival"
	world.sync_state(state)
	check(world._mat.red.metallic>0.8 and world._mat.red.roughness<0.3,"Chrome stand has a distinct reflective material finish")
	state.cosmetic_loadout.stand = "classic"
	world.sync_state(state)
	check(world._mat.red.albedo_texture==world._expansion._stand_defaults.red.texture and world._mat.red.metallic<0.2,"Removing premium stand restores original material properties")
	state.cosmetic_loadout.celebration = "celebration_fireworks"
	world.sync_state(state)
	check(world._expansion.celebration_particle(0).key=="bulb_pink","Fireworks use luminous radial particles")
	state.paused = false
	state.orders = [{"id":9001,"special":"seagulls","package":"bag","flavor":"cinnamon","patience":60,"max_patience":60}]
	world.sync_state(state)
	advance(0.8)
	var trio: Node3D = world._people[9001]
	check(trio.get_meta("gulls").size()==3 and trio.get_meta("coat_panels").size()==2,"Special order creates three actual gulls and two hinged coat panels")
	world.play_gag("seagulls_reveal",{"order_id":9001})
	advance(0.35)
	check(absf(trio.get_meta("coat_panels")[0].rotation.y)>0.3,"Reveal visibly opens coat with eased animation")
	world.play_gag("seagulls_reveal",{"order_id":9001})
	check(world._expansion._reveals.size()==1,"Trio reveal is idempotent")
	# The gag must move the existing scoop object before any model resync.
	var hat_donut: Node3D = world._plain_donut(9100,Vector3.ZERO)
	hat_donut.reparent(world._held_scoop,false)
	hat_donut.position = Vector3(0,0.2,0)
	hat_donut.scale = Vector3.ONE*0.62
	world._held_scoop_donuts.append(hat_donut)
	var hat_start: Vector3 = hat_donut.global_position
	world.play_gag("hat_toss",{"order_id":9001})
	advance(0.22)
	check(world._held_scoop_donuts.is_empty() and is_instance_valid(hat_donut),"Hat toss removes the exact scoop donut without spawning replacement")
	check(hat_donut.global_position.distance_to(hat_start)>0.1 and not trio.has_meta("donut_hat"),"Hat travels visibly through an arc before landing")
	advance(0.50)
	check(trio.get_meta("donut_hat")==hat_donut and hat_donut.get_parent()==trio.get_meta("portrait"),"Airborne hat attaches to intended order's head")
	state.orders = []
	state.package_type = "bag"
	state.package_count = 0
	state.package_flavor = ""
	world.sync_state(state)
	advance(1.8)
	world.air_mail_caught.connect(func(id: int):
		offers.append(id)
		world.resolve_air_mail(id,accept)
	)
	world.stock_spilled.connect(func(id: int): spills.append(id))
	check(world.air_mail_target_open(),"Only idle open unseasoned bag accepts an Air Mail offer")
	world._food.seed_stock(1,36)
	var entry: Dictionary = world._food._entries[0]
	var donut: Node3D = entry.visual
	var food_id: int = int(entry.id)
	entry.launched_burst = 123
	entry.launch_age = 0.0
	entry.body.position = Vector3(-0.45,2.17,1.45)
	entry.previous_position = entry.body.global_position
	entry.body.sleeping = false
	entry.body.linear_velocity = Vector3(1.9,3.3,1.06)
	await frames(65)
	check(offers==[food_id],"Real ballistic launch from tray into bag offers exactly once")
	check(world._food.get_available_count()==0 and world._prep_donuts.size()==1,"Accepted catch transfers one inventory body into package")
	check(not world._prep_donuts.is_empty() and world._prep_donuts[0]==donut and donut.get_parent()==world._prep,"Catch preserves exact donut visual")
	check(spills.is_empty(),"Accepted Air Mail never emits stock spill")
	state.package_count = 1
	world.sync_state(state)
	check(world._prep_donuts.size()==1,"Authoritative state sync does not duplicate caught visual")
	accept = false
	world._food.seed_stock(1,36)
	entry = world._food._entries[0]
	entry.launched_burst = 124
	entry.launch_age = 0.0
	entry.body.position = world._prep.global_position+Vector3(0,1.0,0)
	entry.previous_position = entry.body.global_position
	entry.body.sleeping = false
	entry.body.linear_velocity = Vector3(0,-0.5,0)
	await frames(80)
	check(offers.size()==2 and world._prep_donuts.size()==1,"Rejected catch leaves package unchanged")
	check(spills.size()==1 and world._food.get_available_count()==0,"Rejected body physically lands as exactly one waste item")
	world.reserve_food_ids([-10001,-20000,8000])
	world._food.seed_stock(1,36)
	check(int(world._food._entries[0].id)<-20000,"Resumed saved catch IDs cannot collide with new physical opening stock")
	state.package_flavor = "cinnamon"
	world.sync_state(state)
	check(not world.air_mail_target_open(),"Seasoned bags reject catch eligibility")
	# Expanded machine capacity includes both twelve-donut tray upgrades.
	world._food.seed_stock(84,84)
	check(world._food._capacity==84 and world._food.get_available_count()==84,"Festival Pro plus both tray upgrades restores all 84 physical stock items")
	var full_ids: Dictionary = {}
	for stock in world._food._entries: full_ids[stock.id] = true
	check(full_ids.size()==84,"Maximum upgraded opening stock retains unique body IDs")
	await frames(180)
	var remaining_stock: int = world._food.get_available_count()
	var visible_waste: int = 0
	for stock in world._food._entries:
		if str(stock.stage)=="waste": visible_waste += 1
	check(remaining_stock+visible_waste==84,"Maximum upgraded tray settling preserves all stock as resident or physical waste")
	print("MAXIMUM TRAY SETTLE ",remaining_stock," resident; ",visible_waste," physical waste")
	var maximum_deliveries: Array = []
	world.delivery_settled.connect(func(id: int,kept: bool): maximum_deliveries.append({"id":id,"kept":kept}))
	var spilled_before: int = spills.size()
	world._food.set_machine_running(true)
	world.enqueue_production(88401)
	world.enqueue_production(88402)
	await frames(480)
	var kept_count: int = 0
	var settled_ids: Dictionary = {}
	for result in maximum_deliveries:
		settled_ids[result.id] = true
		if result.kept: kept_count += 1
	check(maximum_deliveries.size()==2 and settled_ids.size()==2,"Full 84-stock tray settles both arriving IDs exactly once")
	check(world._food.get_available_count()==84+kept_count-(spills.size()-spilled_before),"Maximum-capacity arrivals and physical spills conserve authoritative inventory")

	world.queue_free()
	await process_frame
	print("EXPANSION WORLD QA: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
