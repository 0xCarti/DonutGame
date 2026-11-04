extends SceneTree
## Renderable customer anatomy, batching integrity and existing queue contracts.
var checks: int = 0
var failures: int = 0
var largest_draws: int = 0
var largest_triangles: int = 0
func _init() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func stats(node: Node) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO
	if node is MeshInstance3D:
		result.x+=1
		var arrays: Array = node.mesh.surface_get_arrays(0)
		result.y+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	if node.has_meta("customer_batch_triangles"):
		var counts: Vector2i = node.get_meta("customer_batch_triangles")
		check(counts.x==counts.y and counts.y>0,"NPC detail batching preserves every triangle: "+str(node.name))
	for child in node.get_children(): result+=stats(child)
	return result
func _run() -> void:
	root.size=Vector2i(1280,800)
	var world=load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world._customer_initialize_geometry()
	var baked_count: int=world._customer_mesh_cache.size()
	check(baked_count>100,"Baked original mesh library is present")
	for variant in range(6):
		var person: Node3D=world._make_customer(variant)
		check(world._customer_mesh_cache.size()==baked_count,"Customer geometry is fully baked; no mesh generation during arrival")
		var result: Vector2i=stats(person)
		largest_draws=maxi(largest_draws,result.x)
		largest_triangles=maxi(largest_triangles,result.y)
		check(result.x<45,"Detailed customer stays below 45 mesh draws")
		check(result.y<65000,"Detailed customer stays below 65k triangles")
		check(person.get_meta("eyes").size()==2 and person.get_meta("arms").size()==2,"Both eyes and arm pivots remain independent")
		check(person.get_meta("serve_hit").get_meta("station_id")=="customer","Customer target supports direct service and empty-hand gag")
		person.queue_free()
		await process_frame
	var state: Dictionary={"phase":"playing","temperature":180,"batter":40,"supply":0,"supply_capacity":30,"held_tool":"none","package_type":"","orders":[{"id":30,"package":"bag","flavor":"cinnamon","patience":60,"max_patience":60},{"id":31,"package":"bucket","flavor":"powdered","patience":55,"max_patience":60}]}
	world.sync_state(state)
	for frame in range(60): world._process(1.0/60.0)
	check(world._people.size()==2,"All queued customers appear")
	check(world._people[30].get_meta("serve_hit").collision_layer==1 and world._people[31].get_meta("serve_hit").collision_layer==0,"Only first customer can receive an order")
	check(world._people[31].get_meta("order_label").text=="POWDERED\nBUCKET","Physical order card text still follows order")
	world._time=4.3-float(posmod(30,7))*0.71+0.12
	world._animate_customer_detail(world._people[30],30,0.016)
	var eye: Node3D=world._people[30].get_meta("eyes")[0]
	check(eye.scale.y<0.2,"Blink reaches closed pose without changing eye position")
	world.set_reduced_motion(true)
	world._animate_customer_detail(world._people[30],30,0.016)
	check(is_equal_approx(eye.scale.y,1.0) and world._people[30].get_meta("portrait").rotation.y==0.0,"Reduced motion suppresses blink and head movement")
	world.set_reduced_motion(false)
	state.paused=true
	world.sync_state(state)
	var before: Transform3D=world._people[30].get_meta("portrait").transform
	world._process(1.0)
	check(world._people[30].get_meta("portrait").transform==before,"Pause freezes portrait motion")
	state.paused=false
	state.orders.remove_at(0)
	world.sync_state(state)
	for frame in range(150): world._process(1.0/60.0)
	await process_frame
	check(world._people.size()==1 and world._people.has(31),"Customer departure retains the next queued person")
	check(world._people[31].get_meta("serve_hit").collision_layer==1,"Next customer becomes the service target")
	world.reset_food(0,30)
	world.queue_free()
	await process_frame
	await process_frame
	print("CUSTOMER ART QA: %d checks, %d failures; maximum %d draws, %d triangles per customer"%[checks,failures,largest_draws,largest_triangles])
	quit(0 if failures==0 else 1)
