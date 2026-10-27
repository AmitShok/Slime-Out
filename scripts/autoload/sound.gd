extends Node
## Audio director (autoload "Sound").
##
##   Sound.play(&"slime_death", global_position)   # positional
##   Sound.play(&"ui_click")                       # non-positional
##   Sound.play_music(&"fight")
##
## Every sound id has variants, random pitch, a voice cap and a minimum
## retrigger interval, so a 150-slime fight stays punchy instead of turning
## into mush. World sounds pause with the game; UI sounds never do.
## Weapon foley in assets/audio/sfx is our own (art_src/tools/build_sfx.gd);
## everything in assets/audio/ninja is from the Ninja Adventure pack (CC0).

const N := "res://assets/audio/ninja/sounds/"
const J := "res://assets/audio/ninja/jingles/"
const S := "res://assets/audio/sfx/"

## id -> files, bus, volume (dB), pitch jitter, base pitch, max voices,
## min interval (s), optional layered ids.
const SOUNDS := {
	&"shot_pistol": { "files": [S + "shot_pistol_0.wav", S + "shot_pistol_1.wav", S + "shot_pistol_2.wav"], "db": -7.0, "jitter": 0.06, "voices": 4 },
	&"shot_revolver": { "files": [S + "shot_revolver_0.wav", S + "shot_revolver_1.wav", S + "shot_revolver_2.wav"], "db": -5.0, "jitter": 0.05, "voices": 3 },
	&"shot_smg": { "files": [S + "shot_smg_0.wav", S + "shot_smg_1.wav", S + "shot_smg_2.wav"], "db": -10.0, "jitter": 0.07, "voices": 4 },
	&"shot_rifle": { "files": [S + "shot_rifle_0.wav", S + "shot_rifle_1.wav", S + "shot_rifle_2.wav"], "db": -8.0, "jitter": 0.05, "voices": 4 },
	&"shot_rocket": { "files": [S + "shot_rocket_0.wav", S + "shot_rocket_1.wav", S + "shot_rocket_2.wav"], "db": -6.0, "jitter": 0.05, "voices": 2, "layers": [&"rocket_whoosh"] },
	&"rocket_whoosh": { "files": [N + "elemental_fireball2.wav"], "db": -8.0, "jitter": 0.08, "voices": 2 },
	&"casing": { "files": [S + "casing_0.wav", S + "casing_1.wav", S + "casing_2.wav"], "db": -19.0, "jitter": 0.12, "voices": 3, "interval": 0.04 },
	&"reload_out": { "files": [S + "reload_out.wav"], "db": -4.0, "jitter": 0.04, "voices": 1 },
	&"reload_in": { "files": [S + "reload_in.wav"], "db": -2.0, "jitter": 0.04, "voices": 1 },
	&"reload_revolver_out": { "files": [S + "reload_revolver_out.wav"], "db": -4.0, "jitter": 0.04, "voices": 1 },
	&"reload_revolver_in": { "files": [S + "reload_revolver_in.wav"], "db": -1.0, "jitter": 0.04, "voices": 1 },
	&"reload_rocket": { "files": [S + "reload_rocket.wav"], "db": -2.0, "jitter": 0.04, "voices": 1 },
	&"empty_click": { "files": [S + "empty_click.wav"], "db": -8.0, "voices": 1, "interval": 0.15 },
	&"swing_light": { "files": [N + "whoosh_slash_slash.wav", N + "whoosh_slash_slash3.wav"], "db": -6.0, "jitter": 0.08, "voices": 3, "interval": 0.05 },
	&"swing_heavy": { "files": [N + "whoosh_slash_slash4.wav", N + "whoosh_slash_whoosh2.wav"], "db": -4.0, "jitter": 0.06, "pitch": 0.75, "voices": 2, "interval": 0.08 },
	&"parry": { "files": [N + "whoosh_slash_sword2.wav"], "db": -5.0, "jitter": 0.06, "pitch": 1.2, "voices": 2, "interval": 0.05 },
	&"drone_shot": { "files": [S + "drone_shot_0.wav", S + "drone_shot_1.wav", S + "drone_shot_2.wav"], "db": -17.0, "jitter": 0.06, "voices": 3, "interval": 0.05 },
	&"enemy_hit": { "files": [N + "hit_impact_impact4.wav", N + "hit_impact_impact.wav"], "db": -15.0, "jitter": 0.15, "voices": 4, "interval": 0.035 },
	&"enemy_crit": { "files": [N + "hit_impact_hit7.wav"], "db": -10.0, "jitter": 0.08, "voices": 3, "interval": 0.05 },
	&"slime_death": { "files": [N + "elemental_water3.wav", N + "elemental_water5.wav", N + "elemental_water2.wav"], "db": -8.0, "jitter": 0.15, "voices": 5, "interval": 0.03 },
	&"split": { "files": [N + "elemental_bubble2.wav"], "db": -11.0, "jitter": 0.1, "voices": 2, "interval": 0.08 },
	&"spit": { "files": [N + "elemental_water6.wav"], "db": -13.0, "jitter": 0.12, "voices": 3, "interval": 0.06 },
	&"acid_splat": { "files": [N + "elemental_water8.wav"], "db": -15.0, "jitter": 0.12, "voices": 2, "interval": 0.06 },
	&"charger_alert": { "files": [N + "alert_alert3.wav"], "db": -12.0, "jitter": 0.05, "voices": 2, "interval": 0.1 },
	&"charger_dash": { "files": [N + "whoosh_slash_whoosh2.wav"], "db": -11.0, "jitter": 0.1, "voices": 2, "interval": 0.08 },
	&"explosion": { "files": [N + "elemental_explosion5.wav", N + "elemental_explosion2.wav"], "db": -3.0, "jitter": 0.08, "voices": 3, "interval": 0.05 },
	&"thunder": { "files": [N + "elemental_explosion3.wav"], "db": -7.0, "jitter": 0.06, "pitch": 1.25, "voices": 2 },
	&"chain": { "files": [N + "magic_skill_magic4.wav"], "db": -14.0, "jitter": 0.1, "pitch": 1.3, "voices": 2, "interval": 0.08 },
	&"shockwave": { "files": [N + "hit_impact_impact3.wav"], "db": -6.0, "jitter": 0.05, "voices": 2, "interval": 0.08 },
	&"orb_hit": { "files": [N + "hit_impact_impact.wav"], "db": -18.0, "jitter": 0.1, "pitch": 1.4, "voices": 2, "interval": 0.06 },
	&"burn": { "files": [N + "elemental_fire3.wav"], "db": -20.0, "jitter": 0.1, "voices": 1, "interval": 0.4 },
	&"player_hurt": { "files": [N + "hit_impact_hit2.wav"], "db": -3.0, "jitter": 0.05, "voices": 1 },
	&"player_death": { "files": [N + "hit_impact_impact3.wav"], "db": 0.0, "pitch": 0.7, "voices": 1 },
	&"footstep": { "files": [N + "elemental_grass.wav", N + "elemental_grass2.wav"], "db": 6.0, "jitter": 0.15, "voices": 2, "interval": 0.1 },
	&"dash": { "files": [N + "whoosh_slash_whoosh.wav"], "db": -7.0, "jitter": 0.08, "voices": 2 },
	&"dodge": { "files": [N + "magic_skill_magic2.wav"], "db": -10.0, "jitter": 0.04, "pitch": 1.2, "voices": 1 },
	&"gem": { "files": [N + "bonus_coin3.wav"], "db": -15.0, "voices": 4, "interval": 0.025 },
	&"heart": { "files": [N + "magic_skill_heal2.wav"], "db": -5.0, "voices": 1 },
	&"magnet": { "files": [N + "bonus_powerup1.wav"], "db": -5.0, "voices": 1 },
	&"level_up": { "files": [J + "levelup1.wav"], "bus": &"UI", "db": -5.0, "voices": 1 },
	&"round_start": { "files": [N + "alert_alert2.wav"], "bus": &"UI", "db": -9.0, "voices": 1 },
	&"round_clear": { "files": [J + "success2.wav"], "bus": &"UI", "db": -5.0, "voices": 1 },
	&"boss_alert": { "files": [N + "alert_alert5.wav"], "bus": &"UI", "db": -5.0, "voices": 1 },
	&"game_over": { "files": [J + "gameover2.wav"], "bus": &"UI", "db": -3.0, "voices": 1 },
	&"revive": { "files": [J + "secret1.wav"], "bus": &"UI", "db": -3.0, "voices": 1 },
	&"upgrade_pick": { "files": [N + "menu_accept3.wav"], "bus": &"UI", "db": -7.0, "voices": 1 },
	&"weapon_pick": { "files": [N + "bonus_powerup2.wav"], "bus": &"UI", "db": -5.0, "voices": 1 },
	&"ui_hover": { "files": [N + "menu_move1.wav"], "bus": &"UI", "db": -15.0, "jitter": 0.04, "voices": 2, "interval": 0.03 },
	&"ui_click": { "files": [N + "menu_accept4.wav"], "bus": &"UI", "db": -9.0, "voices": 2, "interval": 0.05 },
	&"ui_back": { "files": [N + "menu_cancel2.wav"], "bus": &"UI", "db": -9.0, "voices": 1 },
	&"ui_open": { "files": [N + "menu_menu12.wav"], "bus": &"UI", "db": -11.0, "voices": 1, "interval": 0.1 },
}

## gameplay = our own track (art_src/tools/build_music.gd); theme = pause /
## menu music; boss = boss rounds.
const MUSIC := {
	&"gameplay": "res://assets/audio/music/slime_rush.wav",
	&"theme": "res://assets/audio/ninja/music/fight.ogg",
	&"boss": "res://assets/audio/ninja/music/boss.ogg",
	&"clearing": "res://assets/audio/ninja/music/clearing.ogg",
}
const MUSIC_DB := -6.0
const AMBIENCE := "res://assets/audio/ninja/ambient/wind.wav"

const WORLD_VOICES := 32
const UI_VOICES := 8
## Collecting gems in quick succession climbs the scale (Vampire Survivors).
const GEM_CHAIN_WINDOW := 0.35
const GEM_CHAIN_MAX := 12

var _streams := {}
var _world_pool: Array[AudioStreamPlayer2D] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _last_played := {}
var _playing := {}  # player -> id
var _music_a := AudioStreamPlayer.new()
var _music_b := AudioStreamPlayer.new()
var _music_id: StringName
var _music_tween: Tween
var _theme := AudioStreamPlayer.new()
var _theme_tween: Tween
var _in_menu := false
var _ambience := AudioStreamPlayer.new()
var _gem_chain := 0
var _gem_last := 0.0
var _world_root := Node2D.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in SOUNDS:
		var list: Array[AudioStream] = []
		for path in SOUNDS[id].files:
			list.append(load(path))
		_streams[id] = list
	# World sounds pause with the game.
	_world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world_root)
	for i in WORLD_VOICES:
		var player := AudioStreamPlayer2D.new()
		player.bus = &"SFX"
		player.max_distance = 700.0
		player.attenuation = 1.4
		player.panning_strength = 0.6
		_world_root.add_child(player)
		_world_pool.append(player)
	for i in UI_VOICES:
		var ui := AudioStreamPlayer.new()
		ui.bus = &"SFX"
		add_child(ui)
		_ui_pool.append(ui)
	for music in [_music_a, _music_b]:
		music.bus = &"Music"
		music.volume_db = -80.0
		add_child(music)
	_theme.bus = &"Music"
	_theme.volume_db = -80.0
	var theme_stream: AudioStream = load(MUSIC[&"theme"])
	(theme_stream as AudioStreamOggVorbis).loop = true
	_theme.stream = theme_stream
	add_child(_theme)
	_ambience.bus = &"Ambience"
	_ambience.stream = _looping_wav(load(AMBIENCE))
	_ambience.volume_db = 4.0
	add_child(_ambience)
	get_tree().node_added.connect(_on_node_added)


## Plays `id`. Pass a world position for positional audio (panned and
## attenuated by distance to the camera), or leave it out for flat sound.
func play(id: StringName, at: Variant = null, pitch_scale := 1.0) -> void:
	var def: Dictionary = SOUNDS.get(id, {})
	if def.is_empty():
		push_warning("Unknown sound '%s'" % id)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -10.0)) < float(def.get("interval", 0.0)):
		return
	if _voices(id) >= int(def.get("voices", 4)):
		return
	_last_played[id] = now

	if id == &"gem":
		_gem_chain = mini(_gem_chain + 1, GEM_CHAIN_MAX) if now - _gem_last < GEM_CHAIN_WINDOW else 0
		_gem_last = now
		pitch_scale *= pow(2.0, _gem_chain / 12.0)

	var list: Array = _streams[id]
	var stream: AudioStream = list[randi() % list.size()]
	var jitter: float = def.get("jitter", 0.0)
	var pitch := float(def.get("pitch", 1.0)) * pitch_scale * randf_range(1.0 - jitter, 1.0 + jitter)
	var bus: StringName = def.get("bus", &"SFX")

	if at is Vector2 and bus == &"SFX":
		var player := _free_world_player()
		player.stream = stream
		player.volume_db = def.get("db", 0.0)
		player.pitch_scale = pitch
		player.global_position = at
		player.play()
		_playing[player] = id
	else:
		var ui := _free_ui_player()
		ui.stream = stream
		ui.bus = bus
		ui.volume_db = def.get("db", 0.0)
		ui.pitch_scale = pitch
		ui.play()
		_playing[ui] = id

	for layer in def.get("layers", []):
		play(layer, at, pitch_scale)


func play_music(id: StringName, fade := 1.2) -> void:
	if id == _music_id and (_music_a.playing or _music_b.playing):
		return
	_music_id = id
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	var stream: AudioStream = load(MUSIC[id])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		stream = _looping_wav(stream)
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(incoming, "volume_db", MUSIC_DB, fade)
	_music_tween.tween_property(outgoing, "volume_db", -60.0, fade)
	_music_tween.chain().tween_callback(outgoing.stop)
	if not _ambience.playing:
		_ambience.play()


func stop_music(fade := 1.5) -> void:
	_music_id = &""
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()
	for music in [_music_a, _music_b]:
		_music_tween.tween_property(music, "volume_db", -60.0, fade)
	_music_tween.chain().tween_callback(func() -> void:
		_music_a.stop()
		_music_b.stop())


## Pause / options / game over: the gameplay track pauses where it is and the
## theme plays; leaving resumes the gameplay track from the same spot.
func set_menu_music(on: bool, fade := 0.6) -> void:
	if on == _in_menu:
		return
	_in_menu = on
	if _theme_tween:
		_theme_tween.kill()
	_theme_tween = create_tween()
	if on:
		_music_a.stream_paused = true
		_music_b.stream_paused = true
		if not _theme.playing:
			_theme.play()
		_theme.stream_paused = false
		_theme_tween.tween_property(_theme, "volume_db", MUSIC_DB, fade)
	else:
		_theme_tween.tween_property(_theme, "volume_db", -50.0, fade * 0.5)
		_theme_tween.tween_callback(func() -> void: _theme.stream_paused = true)
		_music_a.stream_paused = false
		_music_b.stream_paused = false


## Low-pass the music while menus are up (it keeps playing, just muffled).
func set_muffled(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.set_bus_effect_enabled(bus, 0, on)


func _process(_delta: float) -> void:
	# Upgrade/build screens muffle the action music; the menu theme stays clear.
	set_muffled(get_tree().paused and not _in_menu)


func _voices(id: StringName) -> int:
	var count := 0
	for player in _playing.keys():
		if not is_instance_valid(player) or not player.playing:
			_playing.erase(player)
		elif _playing[player] == id:
			count += 1
	return count


func _free_world_player() -> AudioStreamPlayer2D:
	for player in _world_pool:
		if not player.playing:
			return player
	return _world_pool[randi() % _world_pool.size()]


func _free_ui_player() -> AudioStreamPlayer:
	for player in _ui_pool:
		if not player.playing:
			return player
	return _ui_pool[0]


## Looping is set in the .import files; this is only a fallback for raw PCM.
func _looping_wav(source: AudioStreamWAV) -> AudioStreamWAV:
	if source.loop_mode != AudioStreamWAV.LOOP_DISABLED or source.format == AudioStreamWAV.FORMAT_QOA or source.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
		return source
	var wav := source.duplicate() as AudioStreamWAV
	var bytes_per_frame := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / bytes_per_frame
	return wav


## Every button in the game gets hover/click sounds automatically.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				play(&"ui_hover"))
		button.pressed.connect(func() -> void: play(&"ui_click"))
	elif node is Slider:
		(node as Slider).drag_ended.connect(func(_changed: bool) -> void: play(&"ui_click"))
	elif node is TabBar:
		(node as TabBar).tab_changed.connect(func(_tab: int) -> void: play(&"ui_open"))
