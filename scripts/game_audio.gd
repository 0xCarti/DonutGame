extends Node
## Small, self-contained audio mixer. Instantiate, add_child(), then start_music().
## Music volume uses a linear 0..1 slider; muting affects only this game audio node.

const EVENT_STREAMS := {
	"drop": preload("res://assets/audio/drop.wav"),
	"flip": preload("res://assets/audio/flip.wav"),
	"sale": preload("res://assets/audio/sale.wav"),
	"upgrade": preload("res://assets/audio/upgrade.wav"),
	"failure": preload("res://assets/audio/failure.wav"),
	"win": preload("res://assets/audio/win.wav"),
	"click": preload("res://assets/audio/click.wav"),
}
const MUSIC_STREAM = preload("res://assets/audio/fairground_loop.wav")
const EVENT_LEVELS := {
	"drop": -15.0, "flip": -18.0, "sale": -9.0, "upgrade": -10.0,
	"failure": -10.0, "win": -9.0, "click": -15.0,
}
const EVENT_ALIASES := {"load": "drop", "land": "flip", "chime": "sale", "fail": "failure", "lose": "failure"}
const MIN_INTERVAL_MS := {"drop": 55, "flip": 55, "sale": 100, "click": 35}

var muted := false
var music_volume := 0.35
var _players: Dictionary = {}
var _last_played: Dictionary = {}
var _music: AudioStreamPlayer
var _music_requested := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for event_name: String in EVENT_STREAMS:
		var player := AudioStreamPlayer.new()
		player.name = "SFX_" + event_name
		player.stream = EVENT_STREAMS[event_name]
		player.max_polyphony = 4 if event_name in ["drop", "flip", "click"] else 2
		add_child(player)
		_players[event_name] = player
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


func play_event(event_name: String) -> void:
	if muted:
		return
	var key: String = str(EVENT_ALIASES.get(event_name.to_lower(), event_name.to_lower()))
	if not _players.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -10000)) < int(MIN_INTERVAL_MS.get(key, 0)):
		return
	_last_played[key] = now
	var player := _players[key] as AudioStreamPlayer
	player.pitch_scale = _rng.randf_range(0.96, 1.04) if key in ["drop", "flip", "click"] else 1.0
	player.play()


func set_muted(value: bool) -> void:
	muted = value
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
	for key: String in _players:
		var player := _players[key] as AudioStreamPlayer
		player.volume_db = -80.0 if muted else float(EVENT_LEVELS.get(key, -12.0))
	if is_instance_valid(_music):
		_music.volume_db = -80.0 if muted or music_volume <= 0.0 else -12.0 + linear_to_db(music_volume)
