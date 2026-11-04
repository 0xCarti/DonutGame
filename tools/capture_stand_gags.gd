extends SceneTree
## Native world/HUD review of the actual controller, with persistence disabled.
const Controller=preload("res://scripts/stand_main.gd")
const OUT="res://playtest-reports/slapstick-1.0.5"
var app
var recording: bool=false
var frame_index: int=0
var stages: Array=[]
func _init(): call_deferred("run")
func snapshot(label: String) -> void:
	sync()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
	stages.append({"stage":label,"supply":app.model.supply,"waste":app.model.waste_count,"food":app.world._food.debug_snapshot()})
func record() -> void:
	while recording:
		await RenderingServer.frame_post_draw
		if not recording: break
		root.get_texture().get_image().save_jpg(OUT+"/frames/frame-%05d.jpg"%frame_index,0.85)
		frame_index+=1
func sync() -> void:
	app._sync_world()
	app._refresh_hud()
func settle() -> void:
	while app.world.is_action_busy(): await process_frame
	await create_timer(0.10).timeout
func act(id: String) -> void:
	app._act(id)
	await settle()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"/frames"))
	root.size=Vector2i(1280,800)
	app=Controller.new()
	app.test_mode=true
	root.add_child(app)
	app.audio.set_muted(true)
	app._start_practice()
	app.set_process(false)
	app.model.heat_setting=2
	app.model.orders[0].id=7
	app.model._next_order_id=8
	app.model._spawn_order()
	sync()
	await create_timer(1.0).timeout
	recording=OS.get_cmdline_user_args().has("--record")
	if recording: record()
	await snapshot("01-counter-hat")
	await act("scoop")
	app._act("customer")
	await create_timer(0.25).timeout
	await snapshot("02-hat-objection")
	await create_timer(1.2).timeout
	app.held_tool="none"
	sync()
	await settle()
	app._act("bell")
	await create_timer(0.18).timeout
	await snapshot("03-bell-hand")
	await settle()
	app.world.play_gag("bell_reply")
	await create_timer(0.22).timeout
	await snapshot("04-neighbor-reply")
	await create_timer(1.1).timeout
	app._act("customer")
	await create_timer(0.34).timeout
	await snapshot("05-punch-impact")
	await create_timer(0.18).timeout
	await snapshot("06-punch-recoil")
	await create_timer(2.0).timeout
	app.model.temperature=220.0
	app.model.heat_setting=4
	app.model.fire_danger=0.55
	sync()
	await create_timer(0.3).timeout
	await snapshot("07-warning-smoke")
	app.model.fire_active=true
	app.model.fire_danger=1.0
	sync()
	await create_timer(0.5).timeout
	await snapshot("08-fryer-fire")
	# A real loaded scoop is returned by the controller before foam is used.
	await act("bag")
	await act("scoop")
	await act("supply")
	var old_food: Array=app.world._held_scoop_donuts.duplicate()
	app._act("extinguish")
	await create_timer(0.25).timeout
	await snapshot("09-return-loaded-scoop")
	await create_timer(0.42).timeout
	await snapshot("10-foam-spray")
	await settle()
	await snapshot("11-foam-recovery")
	var valid: bool=app.held_tool=="none" and old_food.size()==3 and app.world._held_scoop_donuts==old_food
	app.world.play_gag("sneeze")
	await create_timer(0.19).timeout
	await snapshot("12-customer-sneeze")
	await create_timer(1.3).timeout
	await act("bag")
	await act("scoop")
	await act("package")
	await act("supply")
	await act("package")
	await act("cinnamon")
	await act("package")
	var held_order: Node3D=app.world._prep
	valid=valid and app.held_tool=="package" and app.model.package_count==6
	app.model.fire_active=true
	app.model.fire_danger=1.0
	app.model.fire_recovery=0.0
	app.model.foam_time=0.0
	sync()
	app._act("extinguish")
	await create_timer(0.22).timeout
	await snapshot("12b-return-held-order")
	await settle()
	valid=valid and app.world._prep==held_order and app.world._held_package==null and app.model.package_count==6
	# Exercise the actual escalating shake and accounted gull handoff.
	app.model.supply=24
	app.model.fire_recovery=0.0
	app.model.foam_time=0.0
	app.model.fire_danger=0.0
	app.model.temperature=180.0
	app.model.heat_setting=2
	app.world.reset_food(24,app.model.supply_capacity)
	sync()
	await create_timer(1.2).timeout
	for click in range(5):
		app._act("supply")
		await create_timer(0.10).timeout
	await snapshot("13-rage-shake")
	await create_timer(0.35).timeout
	await snapshot("14-launched-donuts")
	await create_timer(0.40).timeout
	await snapshot("15-gull-flight")
	await create_timer(2.0).timeout
	recording=false
	await RenderingServer.frame_post_draw
	app._show_settings()
	await create_timer(0.15).timeout
	await snapshot("16-settings")
	app._close_overlay()
	app._show_collection()
	await create_timer(0.15).timeout
	await snapshot("17-collection")
	var report=FileAccess.open(OUT+"/report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"valid":valid,"frames":frame_index,"frame_rate":30,"version":Controller.VERSION,"test_mode":true,"stages":stages},"\t"))
	report.close()
	app.audio.set_process(false)
	for child in app.audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
	var drain_until: int=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain_until: await process_frame
	app.world.reset_food(0,36)
	app.queue_free()
	await process_frame
	await process_frame
	print("SLAPSTICK_CAPTURE valid=",valid," frames=",frame_index)
	quit(0 if valid else 1)
