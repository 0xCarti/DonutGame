extends SceneTree
## World-side gag timing, physical target picking, visual ownership and reset.
var checks: int=0
var failures: int=0
var sounds: Array[String]=[]
func _init() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func advance(world,seconds: float) -> void:
	for i in range(ceili(seconds*60.0)): world._process(1.0/60.0)
func gag_of(world,kind: String) -> Dictionary:
	for gag in world._gags:
		if gag.kind==kind: return gag
	return {}
func _run() -> void:
	root.size=Vector2i(1280,800)
	var world=load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.gag_sound.connect(func(id: String): sounds.append(id))
	var state: Dictionary={"phase":"playing","temperature":180,"batter":50,"supply":0,"supply_capacity":30,"held_tool":"none","package_type":"","orders":[{"id":7,"package":"bag","flavor":"cinnamon","patience":60,"max_patience":60},{"id":8,"package":"bucket","flavor":"powdered","patience":60,"max_patience":60}]}
	world.sync_state(state)
	advance(world,0.9)
	await physics_frame
	await physics_frame
	check(world._stations.size()==15,"Bell and extinguisher are the only added counter stations")
	check(not world._stations.has("customer") and not world._stations.has("punch"),"Customer targeting has no phantom area")
	for id in world._stations.keys()+["customer"]:
		var point: Vector2=world.station_screen_position(id)
		check(point.x>0 and point.x<1280 and point.y>0 and point.y<800,id+" actual target is on screen")
		check(world.pick_station(point)==id,id+" target is actually clickable (picked "+world.pick_station(point)+" at "+str(point)+")")
	check(world.station_screen_position("punch").is_equal_approx(world.station_screen_position("customer")),"Punch alias follows actual front customer")
	check(world.front_customer_has_donut_hat(),"Rare customer has a visible physical donut hat")
	world.play_gag("hat")
	advance(world,0.18)
	check(sounds.count("hat")==1 and not gag_of(world,"reaction").is_empty(),"Hat objection animates and emits one sound")
	advance(world,1.3)
	world.animate_action("bell")
	advance(world,0.1)
	check(world._bell_button.position.y<0.19,"Bell plunger visibly depresses")
	advance(world,0.5)
	world.play_gag("bell_reply")
	advance(world,0.15)
	check(absf(world._neighbor_bell.rotation.z)>0.01 and sounds.count("bell_reply")==1,"Neighbor bell moves and replies once")
	advance(world,1.1)
	var old_person: Node3D=world._front_customer()
	var old_position: Vector3=old_person.position
	world.animate_action("punch")
	state.orders.remove_at(0)
	world.sync_state(state)
	check(is_instance_valid(old_person) and world._departing.has(old_person),"Removed order retains its original body for the jab")
	advance(world,0.36)
	check(sounds.count("punch")==1,"Jab emits exactly one sound at glove impact")
	check(old_person.position.distance_to(old_position)>0.01,"Customer visibly recoils at impact")
	check(world._punch_person==old_person and world._people.has(8),"New queue target is distinct from the punched target")
	advance(world,0.8)
	check(world._punch_person==null,"Jab releases its customer after recoil")
	advance(world,1.5)
	await process_frame
	check(not is_instance_valid(old_person),"Recoil target finishes departure and frees")
	check(not world.front_customer_has_donut_hat(),"Ordinary customer does not inherit previous hat")
	check(world._highlighted_customer==world._front_customer(),"Highlight registration follows only the new front customer")
	state.fire_danger=0.5
	world.sync_state(state)
	check(world._fire_visual.visible and not world._fire_flames[0].visible and world._fire_light.light_energy==0.0,"Danger warning produces smoke without flames or fire light")
	advance(world,0.15)
	check(world._fire_smoke[0].visible and world._fire_smoke[0].position.y>2.5,"Warning smoke rises above fryer before ignition")
	state.fire_active=true
	state.fire_danger=1.0
	world.sync_state(state)
	check(world._fire_visual.visible and world._machine_status.text=="FRYER FIRE!" and world._context_station=="extinguish","Fryer fire is visible and points to extinguisher")
	var production: float=world._production_time
	advance(world,0.2)
	check(world._production_time==production,"Fire stops fryer animation")
	world.animate_action("extinguish")
	state.fire_active=false
	state.fire_recovery=3.0
	state.foam_time=8.0
	world.sync_state(state)
	check(world._fire_visual.visible,"Visual flame remains until foam arrives")
	advance(world,0.6)
	check(not world._fire_visual.visible and world._foam_visual.visible,"Spray extinguishes flame and leaves foam blanket")
	check(world._machine_status.text=="COOLING / FOAM","Recovery is visible on machine plaque")
	advance(world,1.0)
	check(world._extinguisher.global_transform.is_equal_approx(world._extinguisher_home),"Foam extinguisher returns to its real home")
	world.play_gag("sneeze")
	var sneeze_origin: Vector3=gag_of(world,"sneeze").node.global_position
	check(sneeze_origin.distance_to(world._front_customer().to_global(Vector3(0,2.69,0.27)))<0.01,"Sneeze begins at customer's mouth")
	advance(world,0.1)
	check(not gag_of(world,"sneeze").is_empty() and sounds.count("sneeze")==1,"Powder sneeze has an actual cloud and single sound")
	check(gag_of(world,"sneeze").node.global_position.z>sneeze_origin.z,"Customer sneeze drifts forward toward player")
	state.paused=true
	world.sync_state(state)
	var frozen_age: float=gag_of(world,"sneeze").age
	advance(world,1.0)
	check(gag_of(world,"sneeze").age==frozen_age,"Pause freezes all gag clocks")
	state.paused=false
	world.sync_state(state)
	advance(world,1.4)
	world.play_gag("donut_shower")
	check(sounds.count("donut_shower")==1,"Donut shower sends exactly one feedback event")
	advance(world,1.2)
	var donut: Node3D=world._plain_donut(909090,Vector3(-1,2.8,1))
	donut.scale=Vector3.ONE*0.62
	world.play_gag("seagull",{"donut":donut,"from":Vector3(-1,2.8,1)})
	var bird: Node3D=gag_of(world,"seagull").node
	advance(world,0.51)
	check(donut.get_parent()==bird,"Gull carries the exact accounted donut object")
	check(sounds.count("seagull")==1,"Gull calls once when its beak catches the donut")
	advance(world,1.8)
	await process_frame
	check(not is_instance_valid(donut) and not is_instance_valid(bird),"Gull and carried food free at the end of the flight")
	world.set_reduced_motion(true)
	world.play_gag("bell_reply")
	advance(world,0.2)
	check(world._neighbor_bell.rotation.z==0.0,"Reduced motion removes neighbor bell shaking")
	var reset_donut: Node3D=world._plain_donut(909091,Vector3.ZERO)
	world.play_gag("seagull",{"donut":reset_donut,"from":Vector3(-1,2.8,1)})
	world.reset_food(0,30)
	await process_frame
	check(world._gags.is_empty() and not is_instance_valid(reset_donut),"Reset removes gag objects and owned stolen food")
	check(world._station_meshes.customer.is_empty() and not is_instance_valid(world._highlighted_customer),"Reset clears customer highlight ownership")
	check(not world._fire_visual.visible and not world._foam_visual.visible and world._fire_light.light_energy==0.0,"Reset clears fire and foam visuals")
	check(is_instance_valid(world._extinguisher) and world._extinguisher.global_transform.is_equal_approx(world._extinguisher_home),"Reset preserves the permanent extinguisher")
	world.queue_free()
	await process_frame
	await process_frame
	print("WORLD GAGS QA: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
