extends RefCounted
## Original, reusable venue dressing and equipment. Static venue geometry is
## batched once; gameplay anchors and the physical fryer remain authoritative.
var world: Node3D
var venues: Dictionary = {}
var machines: Dictionary = {}
var venue_id: String = "fairground"
var machine_id: String = "compact"
var speed_knob: Node3D
var speed_buttons: Array[Node3D] = []
var speed_press: Array[float] = [0.0, 0.0]
var speed_target: float = 0.0
var speed_velocity: float = 0.0
var loadout: Dictionary = {}
var celebration: String = "celebration_confetti"
var _clock: float = 0.0
var _lights: Array[MeshInstance3D] = []
var _watch: Node3D
var _watch_face: MeshInstance3D
var _jar: Node3D
var _jar_trim: MeshInstance3D
var _bell_trim: MeshInstance3D
var _shaker_trim: Array[MeshInstance3D] = []
var _packaging_material: StandardMaterial3D
var _counter_trim: Array[MeshInstance3D] = []
var _reveals: Array[Dictionary] = []
var _stand_defaults: Dictionary = {}
var _gingham: Texture2D

func configure(owner_world: Node3D) -> void:
	world = owner_world
	venues.fairground = world._venue_root
	for key in ["red","red_dark"]:
		var material: StandardMaterial3D = world._mat[key]
		_stand_defaults[key] = {"texture":material.albedo_texture,"metal":material.metallic,"rough":material.roughness,"uv":material.uv1_scale}
	var textile: Image = Image.create(32,32,false,Image.FORMAT_RGB8)
	for y in range(32):
		for x in range(32):
			var bands: int = int(x/8)%2+int(y/8)%2
			textile.set_pixel(x,y,[Color("fff1d4"),Color("d8b49f"),Color("8f6358")][bands])
	textile.generate_mipmaps()
	_gingham = ImageTexture.create_from_image(textile)
	for i in range(5):
		world._material("crowd_skin_%d"%i,[Color("cf9f7c"),Color("9f7153"),Color("6f4c36"),Color("c29379"),Color("a56b51")][i],0.0,0.9)

	world._material("concert_violet", Color("492f78"), 0.15, 0.6)
	world._material("concert_led", Color("9a20cc"), 0.1, 0.5, 0.42)
	world._material("concert_cyan", Color("148f99"), 0.1, 0.5, 0.38)
	world._material("stadium_turf", Color("36744b"), 0.0, 1.0)
	world._material("stadium_seat", Color("3b6492"), 0.0, 0.85)
	world._material("stadium_gold", Color("e8b247"), 0.1, 0.7)
	world._material("gull_coat", Color("ac8965"), 0.0, 0.9)
	world._material("gull_coat_dark", Color("755c48"), 0.0, 0.9)
	_make_speed_control()
	_make_cosmetic_props()
	_make_machine("twin_lane")
	_make_machine("festival_pro")

func sync_state(state: Dictionary) -> void:
	var requested: String = str(state.get("venue_id", "fairground"))
	if requested not in ["fairground", "concert", "stadium"]: requested = "fairground"
	if not venues.has(requested): _make_venue(requested)
	for key in venues: venues[key].visible = key == requested
	venue_id = requested
	world._venue_root = venues[requested]
	var next_machine: String = str(state.get("machine_id", "compact"))
	if next_machine not in ["compact", "twin_lane", "festival_pro"]: next_machine = "compact"
	machine_id = next_machine
	for key in machines: machines[key].visible = key == machine_id
	var speed: int = clampi(int(state.get("production_speed", 1)), 0, 2)
	speed_target = float(1 - speed) * 0.82
	world._food.set_machine_profile(machine_id, speed)
	var equipped: Dictionary = state.get("cosmetic_loadout", {})
	if equipped != loadout:
		loadout = equipped.duplicate(true)
		_apply_cosmetics()

func _make_venue(id: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = "ConcertVenue" if id == "concert" else "StadiumVenue"
	world.add_child(root)
	venues[id] = root
	world._box(Vector3(0,-0.10,-10),Vector3(65,0.15,65),"ground",root)
	# Common concourse floor makes the customer's feet meet a physical place.
	world._box(Vector3(0,0.01,-3.5),Vector3(24,0.12,9),"wood_dark" if id == "concert" else "steel_dark",root)
	if id == "concert": _concert(root)
	else: _stadium(root)
	# This retains all triangles but collapses stationary material groups.
	var saved_report: Dictionary = world._static_batch_report
	world._venue_root = root
	world._batch_static_venue()
	root.set_meta("batch_report", world._static_batch_report.duplicate())
	world._static_batch_report = saved_report

func _concert(root: Node3D) -> void:
	world._box(Vector3(0,0.8,-16),Vector3(19,1.5,7),"black",root)
	world._box(Vector3(0,5.2,-19),Vector3(15,7,0.4),"concert_violet",root)
	world._label("GOLDEN HOUR LIVE",Vector3(0,7.5,-18.72),90,Color("ffe0ad"),root)
	for side in [-1.0,1.0]:
		for x in [8.3,9.2]: world._tube(Vector3(side*x,0,-14),Vector3(side*x,10,-14),0.09,"steel_light",root)
		for y in range(10):
			world._tube(Vector3(side*8.3,float(y),-14),Vector3(side*9.2,float(y+1),-14),0.05,"steel",root)
		for y in [2.5,4.0,5.5]:
			world._box(Vector3(side*7.1,y,-15.1),Vector3(1.3,1.35,0.9),"black",root)
			for cone_y in [-0.3,0.3]:
				var cone: MeshInstance3D = world._cylinder(Vector3(side*7.1,y+cone_y,-14.59),0.23,0.06,"steel_dark",root)
				cone.rotation.x = PI*0.5
	world._tube(Vector3(-9.2,9.8,-14),Vector3(9.2,9.8,-14),0.13,"steel_light",root)
	for x in range(-6,7,2):
		world._box(Vector3(float(x),4.1,-18.7),Vector3(1.25,3.9,0.08),"concert_cyan" if x%4==0 else "concert_led",root)
		var lamp: MeshInstance3D = world._sphere(Vector3(float(x),9.4,-14),0.20,"concert_led",root)
		# Only six moving lamps remain outside the static material batch.
		var rig: Node3D = Node3D.new()
		root.add_child(rig)
		lamp.reparent(rig,true)
		_lights.append(lamp)
	for x in [-3.2,0.0,3.2]:
		world._tube(Vector3(x,1.55,-15),Vector3(x,3.15,-15),0.045,"steel",root)
		world._sphere(Vector3(x,3.18,-15),0.10,"black",root)
	for x in range(-9,10,2):
		world._tube(Vector3(float(x),0,-8.0),Vector3(float(x),1.1,-8.0),0.045,"steel",root)
	world._tube(Vector3(-9,1.0,-8),Vector3(9,1.0,-8),0.05,"steel_light",root)
	_crowd(root, -10.0, 28, 0.0)
	world._label("NIGHT MARKET  /  STAGE 01",Vector3(-8.5,3.2,-6),29,Color("e6c0ff"),root)

func _stadium(root: Node3D) -> void:
	world._box(Vector3(0,-0.02,-25),Vector3(36,0.12,32),"stadium_turf",root)
	for x in range(-15,16,5): world._box(Vector3(float(x),0.05,-24),Vector3(0.08,0.02,25),"white",root)
	for z in [-11.5,-36.5]: world._box(Vector3(0,0.05,z),Vector3(30,0.02,0.10),"white",root)
	for side in [-1.0,1.0]:
		world._tube(Vector3(side*14,0,-25),Vector3(side*14,4.0,-25),0.08,"stadium_gold",root)
		world._tube(Vector3(side*14,3.0,-27.5),Vector3(side*14,3.0,-22.5),0.08,"stadium_gold",root)
		for z in [-27.5,-22.5]: world._tube(Vector3(side*14,3,z),Vector3(side*14,6,z),0.08,"stadium_gold",root)
	for tier in range(7):
		var y: float = 0.6+float(tier)*0.8
		var z: float = -39.0-float(tier)*1.15
		world._box(Vector3(0,y,z),Vector3(49,0.6,1.35),"steel_dark",root)
		for block in range(8): world._box(Vector3(-21.0+float(block)*6,y+0.5,z),Vector3(4.9,0.45,0.6),"stadium_seat" if block%2==0 else "red",root)
	world._box(Vector3(0,10,-41),Vector3(13,4.5,0.6),"black",root)
	world._label("GOLDEN HOUR
HOME  07   :   AWAY  06",Vector3(0,10.1,-40.65),72,Color("ffe4a4"),root)
	for x in [-21.0,21.0]:
		world._tube(Vector3(x,0,-32),Vector3(x,15,-32),0.21,"steel",root)
		world._box(Vector3(x,14.7,-31.9),Vector3(4,1.7,0.25),"steel_dark",root)
		for offset in [-1.2,0.0,1.2]: world._box(Vector3(x+offset,14.7,-31.7),Vector3(0.8,1.1,0.12),"bulb",root)
	for x in range(-11,12,2): world._tube(Vector3(float(x),0,-8),Vector3(float(x),1.1,-8),0.055,"steel",root)
	world._tube(Vector3(-11,1.1,-8),Vector3(11,1.1,-8),0.055,"steel_light",root)
	world._label("SECTION 108  /  FIELD CLUB",Vector3(-8.5,3,-6),29,Color("ffe0a7"),root)
	_crowd(root,-6.8,16,0.0)

func _crowd(root: Node3D, z: float, count: int, floor_y: float) -> void:
	# Distant silhouettes use only a few batched meshes, with varied dress and
	# human proportions rather than repeated white sphere heads.
	for i in range(count):
		var x: float = -10.0+20.0*float(i)/float(count-1)+sin(float(i)*3.7)*0.17
		var height: float = 1.5+sin(float(i)*1.7)*0.19
		var depth: float = z-float(i%3)*0.7
		var shirt: String = ["red_dark","fair_teal","fair_purple","stadium_seat","wood_light"][i%5]
		world._cylinder(Vector3(x,floor_y+height*0.54,depth),0.17,height*0.43,shirt,root,0.26)
		for side in [-1.0,1.0]:
			world._cylinder(Vector3(x+side*0.09,floor_y+height*0.20,depth),0.08,height*0.40,"black",root)
			var arm: MeshInstance3D = world._cylinder(Vector3(x+side*0.25,floor_y+height*0.55,depth),0.07,height*0.35,shirt,root)
			arm.rotation.z = side*0.10
		var head_at: Vector3 = Vector3(x,floor_y+height*0.86,depth)
		var head: MeshInstance3D = world._sphere(head_at,0.15,"crowd_skin_%d"%(i%5),root)
		head.scale = Vector3(0.83,1.15,0.90)
		if i%4==0:
			world._cylinder(head_at+Vector3(0,0.14,0),0.18,0.08,shirt,root)
			world._box(head_at+Vector3(0,0.12,0.13),Vector3(0.25,0.03,0.21),shirt,root)
		else:
			var hair: MeshInstance3D = world._sphere(head_at+Vector3(0,0.08,-0.025),0.15,"black" if i%2==0 else "wood_dark",root)
			hair.scale = Vector3(0.90,0.70 if i%3 else 1.15,0.87)

func _make_machine(id: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = "TwinLaneUpgrade" if id == "twin_lane" else "FestivalProUpgrade"
	world._machine_root.add_child(root)
	machines[id] = root
	root.visible = false
	var lanes: int = 2 if id == "twin_lane" else 3
	for lane in range(lanes):
		var z: float = -0.28+(float(lane)-float(lanes-1)*0.5)*0.65
		world._tube(Vector3(-3.65,3.15,-0.25),Vector3(-3.65,2.82,z),0.09,"steel_light",root)
		world._cylinder(Vector3(-3.65,2.72,z),0.16,0.25,"brass",root,0.21)
		if lane < lanes-1:
			world._box(Vector3(-0.4,2.34,z+0.325),Vector3(5.6,0.075,0.025),"steel_dark",root)
	world._box(Vector3(-2.55,3.04,-1.38),Vector3(1.5,1.25,0.65),"red_dark" if lanes==2 else "steel_dark",root)
	for i in range(5): world._box(Vector3(-2.55,2.68+float(i)*0.15,-1.02),Vector3(1.05,0.045,0.035),"black",root)
	world._tube(Vector3(-2.55,3.6,-1.38),Vector3(-3.65,3.6,-0.25),0.09,"steel",root)
	if lanes==3:
		world._cylinder(Vector3(-2.8,4.15,-1.5),0.62,1.1,"steel_light",root,0.68)
		world._cylinder(Vector3(-2.8,4.73,-1.5),0.72,0.09,"steel_dark",root)
		world._tube(Vector3(-2.8,3.62,-1.5),Vector3(-3.65,3.20,-0.25),0.15,"steel",root)
		for x in [-3.1,2.8]: world._box(Vector3(x,1.84,0.70),Vector3(0.35,0.60,0.15),"brass",root)
	world._box(Vector3(0.0,2.0,0.755),Vector3(3.0,0.40,0.08),"black",root)
	world._label("TWIN LANE / 02" if lanes==2 else "FESTIVAL PRO / 03",Vector3(0,2.02,0.81),26,Color("ffe6ae"),root)

func _make_speed_control() -> void:
	var panel: Node3D = Node3D.new()
	panel.name = "IndependentFeedSpeedControl"
	world.add_child(panel)
	panel.position = Vector3(-2.25,2.60,0.90)
	panel.rotation.x = deg_to_rad(-18)
	world._box(Vector3.ZERO,Vector3(0.74,0.72,0.12),"steel_dark",panel)
	world._label("FEED SPEED",Vector3(0,0.25,0.073),13,Color("ffe7b4"),panel)
	world._label("S    N    F",Vector3(0,0.105,0.076),11,Color("e9d6b4"),panel)
	speed_knob = Node3D.new()
	panel.add_child(speed_knob)
	speed_knob.position = Vector3(0,-0.03,0.09)
	var dial: MeshInstance3D = world._cylinder(Vector3.ZERO,0.115,0.10,"black",speed_knob)
	dial.rotation.x = PI*0.5
	world._box(Vector3(0,0.062,0.062),Vector3(0.019,0.068,0.018),"cream",speed_knob)
	for i in range(2):
		var button: Node3D = Node3D.new()
		panel.add_child(button)
		button.position = Vector3(-0.24+float(i)*0.48,-0.22,0.085)
		var cap: MeshInstance3D = world._cylinder(Vector3.ZERO,0.075,0.05,"brass",button)
		cap.rotation.x = PI*0.5
		world._label("−" if i==0 else "+",Vector3(0,0.005,0.035),16,Color("352e2b"),button)
		var action: String = "speed_down" if i==0 else "speed_up"
		world._station(action,button.global_position,Vector3(0.19,0.19,0.16),"FEED SLOWER" if i==0 else "FEED FASTER",false)
		world._register_highlight(action,button)
		speed_buttons.append(button)

func press_speed(id: String) -> void:
	speed_press[0 if id=="speed_down" else 1] = 0.16

func advance(delta: float) -> void:
	_clock += delta
	# Exact critically damped spring is stable at variable render frame rates.
	var displacement: float = speed_knob.rotation.z-speed_target
	var transient: float = speed_velocity+18.0*displacement
	var decay: float = exp(-18.0*delta)
	speed_knob.rotation.z = speed_target+(displacement+transient*delta)*decay
	speed_velocity = (speed_velocity-18.0*transient*delta)*decay
	for i in range(2):
		speed_press[i] = maxf(0.0,speed_press[i]-delta)
		speed_buttons[i].position.z = 0.085-sin(speed_press[i]/0.16*PI)*0.025
	for i in range(_lights.size()):
		_lights[i].scale = Vector3.ONE if world._reduced_motion else Vector3.ONE*(0.85+0.15*sin(_clock*3.0+float(i)*0.8))
	for index in range(_reveals.size()-1,-1,-1):
		var reveal: Dictionary = _reveals[index]
		if not is_instance_valid(reveal.person):
			_reveals.remove_at(index)
			continue
		reveal.age += delta
		var open: float = smoothstep(0.0,0.55,float(reveal.age))
		var person: Node3D = reveal.person
		var panels: Array = person.get_meta("coat_panels")
		for i in range(2): panels[i].rotation.y = (-1.0 if i==0 else 1.0)*open*1.30
		var birds: Array = person.get_meta("gulls")
		for i in range(3):
			birds[i].rotation.z = 0.0 if world._reduced_motion else sin(float(reveal.age)*13+float(i))*0.09*open
			birds[i].position.x = [-0.72,0.66,0.0][i]*open
			birds[i].position.y = 0.58+float(i)*0.94+[1.28,0.42,0.10][i]*open
			for wing in birds[i].get_meta("wings"): wing.rotation.z = 0.0 if world._reduced_motion else sin(float(reveal.age)*17)*0.55*open
		if float(reveal.age)>2.5: _reveals.remove_at(index)

func _style(id: String) -> Dictionary:
	if "neon_midway" in id: return {"base":Color("7254c7"),"accent":Color("6cf3dc"),"metal":0.25}
	if "grandmas_recipe" in id: return {"base":Color("aa4747"),"accent":Color("f4dec0"),"metal":0.08}
	if "chrome_carnival" in id: return {"base":Color("bac9d2"),"accent":Color("eab65c"),"metal":0.85}
	return {"base":Color("a94735"),"accent":Color("e5b55d"),"metal":0.3}

func _make_cosmetic_props() -> void:
	_packaging_material = StandardMaterial3D.new()
	_packaging_material.albedo_color = Color("e5b55d")
	_jar = Node3D.new()
	_jar.name = "TipsJar"
	world.add_child(_jar)
	_jar.position = Vector3(2.65,1.72,-0.64)
	world._cylinder(Vector3(0,0.20,0),0.18,0.39,"steel_dark",_jar)
	world._cylinder(Vector3(0,0.20,0.005),0.165,0.33,"cream",_jar)
	_jar_trim = world._cylinder(Vector3(0,0.40,0),0.19,0.055,"brass",_jar)
	world._label("THANK
YOU!",Vector3(0,0.23,0.174),11,Color("59402b"),_jar)
	for i in range(4): world._cylinder(Vector3(-0.08+float(i%2)*0.12,0.03+float(i)*0.025,0),0.055,0.018,"brass",_jar)
	_bell_trim = world._cylinder(Vector3(0,0.03,0),0.20,0.025,"brass",world._bell)
	for shaker in world._shakers.values():
		_shaker_trim.append(world._cylinder(Vector3(0,0.10,0),0.135,0.035,"brass",shaker))
	_watch = Node3D.new()
	_watch.name = "OperatorWatch"
	world._hands[0].add_child(_watch)
	_watch.position = Vector3(0,-0.10,0)
	world._box(Vector3.ZERO,Vector3(0.18,0.045,0.12),"steel_dark",_watch)
	_watch_face = world._box(Vector3(0,0,0.075),Vector3(0.10,0.075,0.025),"brass",_watch)
	world._box(Vector3(0,0,0.09),Vector3(0.055,0.042,0.008),"black",_watch)
	world._box(Vector3(0,0.009,0.098),Vector3(0.006,0.024,0.003),"cream",_watch)
	for side in [-1.0,1.0]: _counter_trim.append(world._box(Vector3(side*4.65,1.70,0.70),Vector3(0.035,0.035,4.5),"brass"))

func _tint(mesh: MeshInstance3D, style: Dictionary, accent: bool = true) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = style.accent if accent else style.base
	material.metallic = float(style.metal)
	material.roughness = 0.28 if float(style.metal)>0.5 else 0.65
	mesh.material_override = material

func _apply_cosmetics() -> void:
	var stand: String = str(loadout.get("stand",world._cosmetic))
	world.set_cosmetic(stand)
	for key in ["red","red_dark"]:
		var material: StandardMaterial3D = world._mat[key]
		var original: Dictionary = _stand_defaults[key]
		material.albedo_texture = _gingham if stand=="grandmas_recipe" else original.texture
		material.uv1_scale = Vector3(2.5,2.5,1) if stand=="grandmas_recipe" else original.uv
		material.metallic = 0.86 if stand=="chrome_carnival" else original.metal
		material.roughness = 0.25 if stand=="chrome_carnival" else original.rough
		material.emission_enabled = stand=="neon_midway"
		material.emission = Color("281646")
		material.emission_energy_multiplier = 0.12
	for mesh in _counter_trim: _tint(mesh,_style(stand))
	var gloves: String = str(loadout.get("operator_gloves","classic_gloves"))
	var glove_color: Color = Color("b8b3a3") if gloves.begins_with("classic") else _style(gloves).accent
	for material in world._player_glove_materials.values(): material.set_shader_parameter("glove_color",glove_color)
	var sleeves: Dictionary = _style(str(loadout.get("operator_sleeves","classic_sleeves")))
	for rig in world._arm_rigs:
		rig.upper_material.set_shader_parameter("sleeve_color",sleeves.base)
		rig.fore_material.set_shader_parameter("sleeve_color",sleeves.base)
	_tint(_watch_face,_style(str(loadout.get("operator_watch","classic_watch"))))
	_tint(_jar_trim,_style(str(loadout.get("counter_tipjar","classic_tipjar"))))
	_tint(_bell_trim,_style(str(loadout.get("counter_bell","classic_bell"))))
	for trim in _shaker_trim: _tint(trim,_style(str(loadout.get("counter_shaker","classic_shaker"))))
	_packaging_material.albedo_color = _style(str(loadout.get("counter_packaging","classic_packaging"))).accent
	celebration = str(loadout.get("celebration","celebration_confetti"))
	for kind in world._package_stacks:
		for package in world._package_stacks[kind]: decorate_package(package,kind)
	if is_instance_valid(world._prep): decorate_package(world._prep,world._prep_type)

func decorate_package(package: Node3D, kind: String) -> void:
	if package.has_meta("cosmetic_trim"): return
	var trim: MeshInstance3D = world._box(Vector3(0,0.11,0.22 if kind=="bag" else 0.31),Vector3(0.38,0.025,0.006),"brass",package)
	trim.name = "EquippedPackagingAccent"
	trim.material_override = _packaging_material
	package.set_meta("cosmetic_trim",trim)

func celebration_particle(index: int) -> Dictionary:
	if celebration == "celebration_tickets":
		return {"size":Vector3(0.065,0.14,0.008),"key":"cream" if index%2==0 else "red","velocity":Vector3(world._rng.randf_range(-0.7,0.7),world._rng.randf_range(1.3,2.0),world._rng.randf_range(-0.4,0.4))}
	if celebration == "celebration_fireworks":
		var angle: float = float(index)*2.39996
		return {"size":Vector3(0.035,0.035,0.035),"key":["bulb_pink","bulb_teal","gold_light"][index%3],"velocity":Vector3(cos(angle)*1.5,1.5+sin(angle)*1.3,sin(angle*1.7)*0.6)}
	return {"size":Vector3(0.045,0.07,0.01),"key":"gold_light","velocity":Vector3(world._rng.randf_range(-0.8,0.8),world._rng.randf_range(1.0,1.8),world._rng.randf_range(-0.3,0.3))}

func make_seagull_customer(id: int) -> Node3D:
	var person: Node3D = Node3D.new()
	person.name = "ThreeGulls_%d" % id
	world.add_child(person)
	person.set_meta("special","seagulls")
	person.set_meta("order_id",id)
	var birds: Array[Node3D] = []
	for i in range(3):
		var bird: Node3D = Node3D.new()
		person.add_child(bird)
		bird.position = Vector3(0,0.58+float(i)*0.94,0.02)
		var torso: MeshInstance3D = world._sphere(Vector3.ZERO,0.35,"white",bird)
		torso.scale = Vector3(0.8,1.2,0.8)
		world._sphere(Vector3(0,0.33,0.09),0.22,"white",bird)
		var beak: MeshInstance3D = world._cylinder(Vector3(0,0.30,0.34),0.09,0.27,"brass",bird,0.006)
		beak.rotation.x = PI*0.5
		for side in [-1.0,1.0]:
			world._sphere(Vector3(side*0.125,0.39,0.245),0.035,"black",bird)
			world._box(Vector3(side*0.16,-0.40,0.10),Vector3(0.16,0.045,0.24),"brass",bird)
		var wings: Array[Node3D] = []
		for side in [-1.0,1.0]:
			var wing: MeshInstance3D = world._sphere(Vector3(side*0.29,0.0,-0.02),0.20,"steel_light",bird)
			wing.scale = Vector3(0.48,1.55,0.8)
			wings.append(wing)
		bird.set_meta("wings",wings)
		birds.append(bird)
	var panels: Array[Node3D] = []
	world._box(Vector3(0,1.32,-0.25),Vector3(0.85,2.15,0.13),"gull_coat_dark",person)
	for side in [-1.0,1.0]:
		var hinge: Node3D = Node3D.new()
		person.add_child(hinge)
		hinge.position = Vector3(side*0.44,1.30,0.0)
		world._box(Vector3(-side*0.225,0,0.28),Vector3(0.47,2.18,0.12),"gull_coat",hinge)
		var lapel: MeshInstance3D = world._box(Vector3(-side*0.20,0.76,0.36),Vector3(0.25,0.48,0.045),"gull_coat_dark",hinge)
		lapel.rotation.z = side*0.3
		for y in [-0.45,0.05,0.55]: world._sphere(Vector3(-side*0.29,y,0.36),0.035,"brass",hinge)
		panels.append(hinge)
	world._cylinder(Vector3(0,3.16,0.02),0.40,0.06,"gull_coat_dark",person)
	world._cylinder(Vector3(0,3.29,0.02),0.28,0.23,"gull_coat",person,0.24)
	var hit: Area3D = Area3D.new()
	person.add_child(hit)
	hit.position = Vector3(0,1.8,0)
	hit.collision_mask = 0
	hit.set_meta("station_id","customer")
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.1,2.7,0.8)
	collision.shape = shape
	hit.add_child(collision)
	var label: Label3D = world._label("",Vector3(0,3.7,0),25,Color("fff0d0"),person)
	var patience: MeshInstance3D = world._box(Vector3(0,3.40,0.08),Vector3(0.75,0.055,0.025),"gauge_green",person)
	person.set_meta("serve_hit",hit)
	person.set_meta("order_label",label)
	person.set_meta("patience",patience)
	person.set_meta("gulls",birds)
	person.set_meta("coat_panels",panels)
	person.set_meta("portrait",birds[2])
	person.set_meta("eyes",[])
	person.set_meta("arms",[])
	return person

func reveal_seagulls(order_id: int) -> void:
	var candidates: Array = world._people.values()+world._departing
	for person in candidates:
		if not is_instance_valid(person) or str(person.get_meta("special",""))!="seagulls": continue
		if order_id>=0 and int(person.get_meta("order_id",-1))!=order_id: continue
		if person.get_meta("revealed",false): return
		person.set_meta("revealed",true)
		_reveals.append({"person":person,"age":0.0})
		world._gag_bubble("THREE FOR THE ROAD!",person.to_global(Vector3(0.4,3.6,0.4)))
		world.gag_sound.emit("seagull")
		return
