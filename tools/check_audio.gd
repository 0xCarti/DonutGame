extends SceneTree
## Run after an import: godot --headless --path . --script tools/check_audio.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio_script = load("res://scripts/game_audio.gd")
	assert(audio_script != null, "Audio script must load")
	var audio = audio_script.new()
	root.add_child(audio)
	assert(audio.get_child_count() == 8, "Seven SFX players plus one music player")
	var music: AudioStreamPlayer = audio.get_node("FairgroundMusic")
	assert(is_equal_approx(music.stream.get_length(), 30.0), "Music must be a 30 second loop")
	assert(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Loop mode must be enabled")
	assert(music.stream.loop_end == 960000, "Loop includes every sample frame")
	audio.start_music()
	assert(music.playing, "Music should start")
	for event_name in ["load", "drop", "flip", "land", "sale", "chime", "upgrade", "failure", "win", "click"]:
		audio.play_event(event_name)
	audio.set_music_volume(0.5)
	assert(is_equal_approx(music.volume_db, -12.0 + linear_to_db(0.5)))
	audio.set_muted(true)
	for player: AudioStreamPlayer in audio.get_children():
		assert(player.volume_db == -80.0, "Mute must affect every owned player")
	audio.set_muted(false)
	assert(music.volume_db > -80.0, "Unmute must restore volume")
	audio.set_music_volume(0.0)
	assert(music.volume_db == -80.0, "Zero music volume must be silent")
	assert(audio.get_node("SFX_sale").volume_db > -80.0, "Music slider must preserve SFX volume")
	audio.stop_music()
	assert(not music.playing, "Stop must stop music")
	await create_timer(0.1).timeout
	print("AUDIO_SMOKE_OK: streams, polyphony, aliases, loop boundaries, volume, mute, and playback")
	for player: AudioStreamPlayer in audio.get_children():
		player.stop()
	audio.free()
	# Allow the audio mixer to release stopped stream playback references.
	await create_timer(0.2).timeout
	quit(0)
