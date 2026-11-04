extends "res://scripts/game_audio.gd"
## Tactile service, distinguishable fault cues and continuous fryer ambience.
## One-shots share the inherited six-voice limit. Loops stay below -30 dB.
const STAND_STREAMS = {
    "paper": preload("res://assets/audio/stand/paper.wav"),
    "scoop": preload("res://assets/audio/stand/scoop.wav"),
    "pour": preload("res://assets/audio/stand/pour.wav"),
    "sugar": preload("res://assets/audio/stand/sugar.wav"),
    "refill": preload("res://assets/audio/stand/refill.wav"),
    "repair": preload("res://assets/audio/stand/repair.wav"),
    "jam": preload("res://assets/audio/stand/jam.wav"),
    "overheat": preload("res://assets/audio/stand/overheat.wav"),
    "attention": preload("res://assets/audio/stand/attention.wav"),
    "customer": preload("res://assets/audio/stand/customer.wav"),
    "reject": preload("res://assets/audio/stand/reject.wav"),
    "punch": preload("res://assets/audio/gags/punch.wav"),
    "bell": preload("res://assets/audio/gags/bell.wav"),
    "bell_reply": preload("res://assets/audio/gags/bell_reply.wav"),
    "sneeze": preload("res://assets/audio/gags/sneeze.wav"),
    "seagull": preload("res://assets/audio/gags/seagull.wav"),
    "hat": preload("res://assets/audio/gags/hat.wav"),
    "fire": preload("res://assets/audio/gags/fire.wav"),
    "extinguish": preload("res://assets/audio/gags/extinguish.wav")
}
const FRYER = preload("res://assets/audio/stand/fryer_loop.wav")
const AIR = preload("res://assets/audio/stand/evening_air.wav")
const EVENING_THEME = preload("res://assets/audio/stand/evening_theme.wav")
var sfx_volume = 0.8
var ambience_volume = 0.5
var _stand_players: Dictionary = {}
var _warning_times: Dictionary = {}
var _machine_loop: AudioStreamPlayer
var _air_loop: AudioStreamPlayer
var _machine_state: Dictionary = {}
var _last_reminder = 0.0

func _ready() -> void:
    super._ready()
    for key in STAND_STREAMS:
        _stand_players[key] = _make_effect_player("Stand_" + key)
    var song = EVENING_THEME.duplicate() as AudioStreamWAV
    _set_loop(song)
    _music.stream = song
    _machine_loop = _make_loop("FryerAmbience", FRYER)
    _air_loop = _make_loop("EveningAmbience", AIR)
    _apply_volumes()

func _set_loop(stream: AudioStreamWAV) -> void:
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = int(round(stream.get_length() * stream.mix_rate))

func _make_loop(label: String, source: AudioStreamWAV) -> AudioStreamPlayer:
    var player = AudioStreamPlayer.new()
    player.name = label
    var stream = source.duplicate() as AudioStreamWAV
    _set_loop(stream)
    player.stream = stream
    player.volume_db = -80
    add_child(player)
    player.play()
    return player

func set_sfx_volume(value: float) -> void:
    sfx_volume = clampf(value,0,1)
    _apply_volumes()

func set_ambience_volume(value: float) -> void:
    ambience_volume = clampf(value,0,1)
    _apply_volumes()

func _start_voice(player: AudioStreamPlayer, stream: AudioStream, level: float, pitch: float) -> void:
    super._start_voice(player,stream,level,pitch)
    player.volume_db = -80 if muted or sfx_volume <= 0 else minf(level,MAX_SFX_DB) + linear_to_db(sfx_volume)

func _apply_volumes() -> void:
    super._apply_volumes()
    for player in _all_effect_players:
        player.volume_db = -80 if muted or sfx_volume <= 0 else minf(float(_voice_levels[player.get_instance_id()]),MAX_SFX_DB) + linear_to_db(sfx_volume)
    _update_loops()

func _play_stand(key: String, level: float=-23.0) -> void:
    if muted or not _stand_players.has(key): return
    var now = Time.get_ticks_msec()
    if now-int(_last_played.get("stand/"+key,-10000)) < 55: return
    _last_played["stand/"+key] = now
    _start_voice(_stand_players[key],STAND_STREAMS[key],level,_rng.randf_range(.97,1.03))

func play_action(action: String, reward_tier: int=1) -> void:
    match action.to_lower():
        "punch", "bell", "sneeze", "hat", "extinguish": _play_stand(action,-23)
        "bell_reply", "seagull": _play_stand(action,-27)
        "bag", "bucket", "container", "trash", "discard": _play_stand("paper",-24)
        "scoop", "supply", "tray", "pickup_scoop": _play_stand("scoop",-23)
        "package", "pour", "dump": _play_stand("pour",-24)
        "cinnamon", "powdered", "sugar": _play_stand("sugar",-24)
        "refill", "hopper": _play_stand("refill",-23)
        "repair", "jam_cleared", "serviced": _play_stand("repair",-21)
        "heat_down", "heat_up", "heat": super.play_event("click")
        "serve", "order_complete": play_sale(reward_tier)
        "quota", "shift_goal": play_goal()
        "customer": play_customer()
        "jam", "overheat", "too_hot", "wrong_order", "walkout": play_warning(action)
        _: super.play_event(action)

func play_warning(code: String) -> void:
    var key = code
    if key in ["too_hot"]: key="overheat"
    var now = Time.get_ticks_msec()
    if now-int(_warning_times.get(key,-10000)) < 1800: return
    _warning_times[key] = now
    match key:
        "fire": _play_stand("fire",-19)
        "fire_warning": _play_stand("attention",-21)
        "jam": _play_stand("jam",-18)
        "overheat": _play_stand("overheat",-19)
        "low_batter", "heat_warning", "feed_warning", "low_stock", "empty_batter": _play_stand("attention",-22)
        _: _play_stand("reject",-23)

func play_customer() -> void:
    _play_stand("customer",-26)

func play_served(amount: float, streak: int) -> void:
    var reward_tier = 3 if streak >= 10 else (2 if streak >= 6 or amount >= 45 else (1 if streak >= 3 else 0))
    play_sale(reward_tier,streak)

func sync_machine(state: Dictionary) -> void:
    _machine_state = state
    _update_loops()

func _update_loops() -> void:
    if not is_instance_valid(_machine_loop): return
    var active = str(_machine_state.get("phase",""))=="playing" and not bool(_machine_state.get("paused",false))
    var maintaining = str(_machine_state.get("hold_station","")) in ["refill","repair"]
    var running = active and not maintaining and not bool(_machine_state.get("fire_active",false)) and float(_machine_state.get("fire_recovery",0))<=0 and not bool(_machine_state.get("jammed",false)) and not bool(_machine_state.get("overheated",false)) and int(_machine_state.get("batter",0))>0 and float(_machine_state.get("temperature",0))>=145
    var volume = -80.0 if muted or ambience_volume<=0 else linear_to_db(ambience_volume)
    _machine_loop.volume_db = -80 if not running or volume<=-80 else -33 + volume
    _machine_loop.pitch_scale = clampf(0.9+(float(_machine_state.get("temperature",175))-145)*.002, .9,1.12)
    _air_loop.volume_db = -80 if not active or volume<=-80 else -39 + volume

func _process(delta: float) -> void:
    if str(_machine_state.get("phase",""))!="playing" or bool(_machine_state.get("paused",false)):
        _last_reminder=0
        return
    _last_reminder+=delta
    if _last_reminder>=12:
        _last_reminder=0
        if bool(_machine_state.get("fire_active",false)): play_warning("fire")
        elif bool(_machine_state.get("jammed",false)): play_warning("jam")
        elif bool(_machine_state.get("overheated",false)): play_warning("overheat")
