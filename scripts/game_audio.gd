extends Node
## Owned audio mixer: six total one-shot voices plus music, with conservative
## peak headroom. Sale layers grow in harmony/texture rather than raw loudness.

const EVENT_STREAMS := {
	"drop": preload("res://assets/audio/drop.wav"),
	"flip": preload("res://assets/audio/flip.wav"),
	"sale": preload("res://assets/audio/sale.wav"),
	"upgrade": preload("res://assets/audio/upgrade.wav"),
	"failure": preload("res://assets/audio/failure.wav"),
	"win": preload("res://assets/audio/win.wav"),
	"click": preload("res://assets/audio/click.wav"),
}
const SALE_STREAMS := [
	preload("res://assets/audio/sale_small.wav"),
	preload("res://assets/audio/sale.wav"),
	preload("res://assets/audio/sale_big.wav"),
	preload("res://assets/audio/sale_jackpot.wav"),
]
const COIN_STREAM = preload("res://assets/audio/score_coins.wav")
const RISE_STREAM = preload("res://assets/audio/score_rise.wav")
const GOAL_STREAM = preload("res://assets/audio/quota_goal.wav")
const MUSIC_STREAM = preload("res://assets/audio/fairground_loop.wav")
const MAX_SFX_VOICES := 6
const SCORE_POOL_SIZE := 4
const MAX_SFX_DB := -15.0
const SALE_LEVELS := [-22.0, -19.0, -17.0, -15.0]
const EVENT_LEVELS := {
	"drop": -24.0, "flip": -27.0, "sale": -19.0, "upgrade": -17.0,
	"failure": -19.0, "win": -16.0, "click": -22.0,
}
const EVENT_ALIASES := {"load": "drop", "land": "flip", "chime": "sale", "fail": "failure", "lose": "failure", "goal": "quota", "quota_met": "quota"}
const MIN_INTERVAL_MS := {"drop": 55, "flip": 55, "sale": 90, "click": 35}

var muted := false
var music_volume := 0.35
var _players: Dictionary = {}
var _last_played: Dictionary = {}
var _score_players: Array[AudioStreamPlayer] = []
var _all_effect_players: Array[AudioStreamPlayer] = []
var _voice_levels: Dictionary = {}
var _voice_order: Dictionary = {}
var _voice_serial := 0
var _score_cursor := 0
var _last_sale_msec := -10000
var _last_sale_tier := -1
var _last_accent_msec := -10000
var _last_goal_msec := -10000
var _music: AudioStreamPlayer
var _music_requested := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for event_name: String in EVENT_STREAMS:
		var player := _make_effect_player("SFX_" + event_name)
		player.stream = EVENT_STREAMS[event_name]
		_players[event_name] = player
		_voice_levels[player.get_instance_id()] = float(EVENT_LEVELS[event_name])
	for index in range(SCORE_POOL_SIZE):
		_score_players.append(_make_effect_player("ScoreVoice%d" % index))
	_music = AudioStreamPlayer.new()
	_music.name = "FairgroundMusic"
	var loop_stream := MUSIC_STREAM.duplicate() as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = int(round(loop_stream.get_length() * float(loop_stream.mix_rate)))
	_music.stream = loop_stream
	add_child(_music)
	_apply_volumes()
	if _music_requested:
		_music.play()


func _make_effect_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.max_polyphony = 1
	add_child(player)
	_all_effect_players.append(player)
	_voice_levels[player.get_instance_id()] = -24.0
	return player


func play_event(event_name: String) -> void:
	if muted:
		return
	var key: String = str(EVENT_ALIASES.get(event_name.to_lower(), event_name.to_lower()))
	if key == "sale":
		play_sale(1)
		return
	if key == "quota":
		play_goal()
		return
	if not _players.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -10000)) < int(MIN_INTERVAL_MS.get(key, 0)):
		return
	_last_played[key] = now
	var player := _players[key] as AudioStreamPlayer
	var pitch := _rng.randf_range(0.96, 1.04) if key in ["drop", "flip", "click"] else 1.0
	_start_voice(player, EVENT_STREAMS[key], float(EVENT_LEVELS[key]), pitch)


func play_sale(tier: int, chain: int = 0) -> void:
	if muted or _score_players.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_sale_msec < 90:
		return
	var safe_tier := clampi(tier, 0, 3)
	var safe_chain := clampi(chain, 0, 6)
	var repeated := safe_tier == _last_sale_tier and now - _last_sale_msec < 750
	var level := float(SALE_LEVELS[safe_tier]) - (2.0 if repeated else 0.0)
	var pitch := 1.0 + float(safe_chain) * 0.01 + _rng.randf_range(-0.012, 0.012)
	_play_score(SALE_STREAMS[safe_tier], level, pitch)
	# Decorative layers get their own cooldown so rapid sales remain readable.
	if safe_tier >= 2 and now - _last_accent_msec >= 900:
		_play_score(RISE_STREAM if safe_tier == 3 else COIN_STREAM, -25.0, pitch)
		_last_accent_msec = now
	elif safe_tier == 1 and safe_chain >= 2 and now - _last_accent_msec >= 1200:
		_play_score(COIN_STREAM, -28.0, pitch)
		_last_accent_msec = now
	_last_sale_msec = now
	_last_sale_tier = safe_tier


func play_goal() -> void:
	if muted or _score_players.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_goal_msec < 1500:
		return
	_last_goal_msec = now
	_play_score(GOAL_STREAM, -16.0, 1.0)


func _play_score(stream: AudioStream, level: float, pitch: float) -> void:
	var player: AudioStreamPlayer = _score_players[_score_cursor]
	for available in _score_players:
		if not available.playing:
			player = available
			break
	_score_cursor = (_score_players.find(player) + 1) % SCORE_POOL_SIZE
	_start_voice(player, stream, level, pitch)


func _start_voice(player: AudioStreamPlayer, stream: AudioStream, level: float, pitch: float) -> void:
	player.stop()
	# Share a total voice budget across machine, UI, and scoring effects.
	while _active_effect_count() >= MAX_SFX_VOICES:
		var oldest: AudioStreamPlayer = null
		var oldest_order := 9223372036854775807
		for voice in _all_effect_players:
			var order := int(_voice_order.get(voice.get_instance_id(), 0))
			if voice.playing and order < oldest_order:
				oldest = voice
				oldest_order = order
		if oldest == null:
			break
		oldest.stop()
	_voice_serial += 1
	_voice_order[player.get_instance_id()] = _voice_serial
	_voice_levels[player.get_instance_id()] = minf(level, MAX_SFX_DB)
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.9, 1.12)
	player.volume_db = -80.0 if muted else float(_voice_levels[player.get_instance_id()])
	player.play()


func _active_effect_count() -> int:
	var count := 0
	for player in _all_effect_players:
		if player.playing:
			count += 1
	return count


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for player in _all_effect_players:
			player.stop()
	_apply_volumes()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func start_music() -> void:
	_music_requested = true
	if is_instance_valid(_music) and not _music.playing:
		_music.play()


func stop_music() -> void:
	_music_requested = false
	if is_instance_valid(_music):
		_music.stop()


func _apply_volumes() -> void:
	for player in _all_effect_players:
		player.volume_db = -80.0 if muted else minf(float(_voice_levels[player.get_instance_id()]), MAX_SFX_DB)
	if is_instance_valid(_music):
		_music.volume_db = -80.0 if muted or music_volume <= 0.0 else -12.0 + linear_to_db(music_volume)
