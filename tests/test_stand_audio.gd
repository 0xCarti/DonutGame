extends SceneTree
const StandAudio = preload("res://scripts/stand_audio.gd")
var checks = 0
var failures = 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("STAND AUDIO FAIL: " + message)

func _run() -> void:
	var sound = StandAudio.new()
	root.add_child(sound)
	await process_frame
	await create_timer(.05).timeout
	var initial_nodes: int = sound.get_child_count()
	check(initial_nodes == 25, "fixed pool owns service effects, score effects and three loops")
	check(is_equal_approx(sound._music.stream.get_length(), 76.8), "original evening theme has complete 32-bar arrangement")
	for player in [sound._music,sound._machine_loop,sound._air_loop]:
		check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and player.stream.loop_end == roundi(player.stream.get_length()*player.stream.mix_rate), "each loop contains all its sample frames")
	check(sound._machine_loop.volume_db == -80 and sound._air_loop.volume_db == -80, "title screen has no running machinery ambience")
	var state = {"phase":"playing","paused":false,"jammed":false,"overheated":false,"batter":40,"temperature":178.0,"supply":20,"supply_capacity":36}
	sound.sync_machine(state)
	check(sound._machine_loop.volume_db > -80 and sound._air_loop.volume_db > -80, "working machine has quiet continuous ambience")
	state.jammed = true
	sound.sync_machine(state)
	check(sound._machine_loop.volume_db == -80 and sound._air_loop.volume_db > -80, "jam stops machine sound while fairground remains")
	state.jammed = false
	state.overheated = true
	sound.sync_machine(state)
	check(sound._machine_loop.volume_db == -80, "thermal cutoff stops machinery")
	state.overheated = false
	state.supply = 36
	sound.sync_machine(state)
	check(sound._machine_loop.volume_db > -80, "full tray keeps producing with spill risk")
	state.supply = 20
	state.paused = true
	sound.sync_machine(state)
	check(sound._machine_loop.volume_db == -80 and sound._air_loop.volume_db == -80, "pause quiets both ambient loops")
	state.paused = false
	sound.sync_machine(state)
	for hold in ["refill", "repair"]:
		state.hold_station = hold
		sound.sync_machine(state)
		check(sound._machine_loop.volume_db == -80, "maintenance hold stops machinery sound")
	state.hold_station = ""
	sound.sync_machine(state)
	sound.set_ambience_volume(0)
	check(sound._machine_loop.volume_db == -80 and sound._air_loop.volume_db == -80, "ambience slider silences loops independently")
	sound.set_sfx_volume(.25)
	sound.play_action("scoop")
	check(sound._stand_players.scoop.stream == sound.STAND_STREAMS.scoop and is_equal_approx(sound._stand_players.scoop.volume_db,-23+linear_to_db(.25)), "service action uses its own sound and actual SFX slider")
	sound.play_warning("jam")
	check(sound._stand_players.jam.playing and sound._stand_players.jam.stream != sound.STAND_STREAMS.overheat, "jam and overheat have distinct cues")
	var serial: int = sound._voice_serial
	sound.play_warning("jam")
	check(sound._voice_serial == serial, "repeated fault does not flood the audio mix")
	sound.play_warning("overheat")
	check(sound._stand_players.overheat.playing, "a different fault still sounds immediately")
	for i in range(80):
		sound._last_played.clear()
		sound._warning_times.clear()
		sound._last_sale_msec = -10000
		sound._last_accent_msec = -10000
		sound.play_action(["scoop","pour","cinnamon","refill","repair","bag"][i%6])
		sound.play_warning("jam" if i%2==0 else "overheat")
		sound.play_served(60, i)
		check(sound._active_effect_count() <= 6, "combined service/warning/sales obey shared six-voice budget")
	check(sound.get_child_count() == initial_nodes, "stress creates no new audio players")
	sound.set_sfx_volume(0)
	for player in sound._all_effect_players: check(player.volume_db == -80, "zero SFX volume affects every service and score player")
	sound.set_ambience_volume(.8)
	sound.start_music()
	sound.set_muted(true)
	for player in sound.get_children(): check(player.volume_db == -80, "master mute affects all loops and effects")
	check(sound._active_effect_count() == 0 and sound._music.playing, "mute clears transient effects but retains music position")
	sound.set_muted(false)
	check(sound._machine_loop.volume_db > -80 and sound._music.volume_db > -80, "unmute restores independent loop settings")
	for player in sound.get_children(): player.stop()
	await process_frame
	await create_timer(.2).timeout
	for player in sound.get_children(): player.stream = null
	sound.queue_free()
	await process_frame
	await process_frame
	await create_timer(.05).timeout
	print("STAND AUDIO: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
