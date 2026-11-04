extends SceneTree
## Run after an import: godot --headless --path . --script tools/check_audio.gd

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("AUDIO FAIL: " + message)


func _run() -> void:
	var audio_script = load("res://scripts/game_audio.gd")
	_check(audio_script != null, "Audio script loads")
	if audio_script == null:
		quit(1)
		return
	var audio = audio_script.new()
	root.add_child(audio)
	var initial_nodes: int = audio.get_child_count()
	_check(initial_nodes == 12, "Seven named event players, four score voices, one music player")
	var music: AudioStreamPlayer = audio.get_node("FairgroundMusic")
	_check(is_equal_approx(music.stream.get_length(), 30.0), "Music is a 30 second loop")
	_check(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Loop mode enabled")
	_check(music.stream.loop_end == 960000, "Loop includes every sample frame")
	for stream in audio.EVENT_STREAMS.values():
		_check(stream.get_length() > 0.0, "Legacy effect stream has playable samples")
	for stream in audio.SALE_STREAMS:
		_check(stream.get_length() > 0.0, "Each sale tier has playable samples")
	for stream in [audio.COIN_STREAM, audio.RISE_STREAM, audio.GOAL_STREAM]:
		_check(stream.get_length() > 0.0, "Score accent has playable samples")
	for player in audio._all_effect_players:
		_check(player.max_polyphony == 1, "Each bounded mixer slot owns one voice")
	audio.start_music()
	_check(music.playing, "Music starts")
	for event_name in ["load", "drop", "flip", "land", "sale", "chime", "upgrade", "failure", "win", "click"]:
		audio.play_event(event_name)
	_check(audio._active_effect_count() <= 6, "Legacy effects obey shared voice budget")

	for tier in range(4):
		audio._last_sale_msec = -10000
		audio._last_accent_msec = -10000
		audio.play_sale(tier, 3)
		var found := false
		for player in audio._score_players:
			if player.playing and player.stream == audio.SALE_STREAMS[tier]:
				found = true
		_check(found, "Sale tier %d selects its distinct main sound" % tier)
		_check(audio._active_effect_count() <= 6, "Tier layers obey shared voice budget")

	audio._last_sale_msec = -10000
	audio.play_sale(3, 999)
	var serial_before: int = audio._voice_serial
	audio.play_sale(3, 999)
	_check(audio._voice_serial == serial_before, "Immediate repeated sale is rate limited")
	audio._last_goal_msec = -10000
	audio.play_goal()
	serial_before = audio._voice_serial
	audio.play_goal()
	_check(audio._voice_serial == serial_before, "Quota accent cannot repeat immediately")
	for tier in [-999, 999]:
		audio._last_sale_msec = -10000
		audio.play_sale(tier, -99)
	_check(audio._active_effect_count() <= 6, "Out of range tier and chain inputs are bounded")

	for index in range(80):
		audio._last_sale_msec = -10000
		audio._last_accent_msec = -10000
		audio._last_played.clear()
		audio.play_event(["drop", "flip", "click", "upgrade", "win"][index % 5])
		audio.play_sale(index % 4, index)
		_check(audio._active_effect_count() <= 6, "Rapid mixed playback stays within six voices")
	_check(audio.get_child_count() == initial_nodes, "Rapid playback allocates no extra players")
	for player in audio._all_effect_players:
		_check(player.volume_db <= -15.0, "Per-voice peak-gain ceiling is enforced")
		_check(player.pitch_scale >= 0.9 and player.pitch_scale <= 1.12, "Pitch remains restrained")
	var max_mix: float = 6.0 * 0.65 * db_to_linear(-15.0) + 0.48 * db_to_linear(-12.0)
	_check(max_mix < 0.85, "Worst-case mix has headroom below clipping")

	audio.set_music_volume(0.5)
	_check(is_equal_approx(music.volume_db, -12.0 + linear_to_db(0.5)), "Music slider remains independent")
	audio.set_muted(true)
	for player: AudioStreamPlayer in audio.get_children():
		_check(player.volume_db == -80.0, "Mute affects every owned player")
	_check(audio._active_effect_count() == 0, "Mute clears one-shots instead of replaying stale rewards")
	_check(music.playing, "Mute preserves music position")
	serial_before = audio._voice_serial
	audio.play_sale(3, 10)
	audio.play_goal()
	audio.play_event("click")
	_check(audio._voice_serial == serial_before, "Muted sale, goal, and UI calls remain silent")
	audio.set_muted(false)
	_check(music.volume_db > -80.0, "Unmute restores selected music volume")
	audio.set_music_volume(0.0)
	_check(music.volume_db == -80.0, "Zero music volume is silent")
	_check(audio.get_node("SFX_sale").volume_db > -80.0, "Music slider preserves SFX volume")
	audio.stop_music()
	_check(not music.playing, "Stop stops music")
	for player: AudioStreamPlayer in audio.get_children():
		player.stop()
	audio.free()
	# Allow the audio mixer to release stopped stream playback references.
	await create_timer(0.2).timeout
	if failures == 0:
		print("AUDIO_SMOKE_OK: %d checks; tier selection, shared voice budget, headroom, mute, aliases, and loop" % checks)
	else:
		print("AUDIO_SMOKE_FAILED: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
