extends Node
## Every player-facing option, persisted to user://settings.cfg.
##
## Read with `Settings.value(&"key")`, write with `Settings.set_value()`.
## Audio and window options are applied here; everything else listens to
## `changed(key)` and pulls the new value.

signal changed(key: StringName)

const PATH := "user://settings.cfg"

## Section -> key -> default. Keys are unique across sections.
const DEFAULTS := {
	"audio": {
		"master_volume": 0.8,
		"music_volume": 0.55,
		"sfx_volume": 0.8,
		"ui_volume": 0.7,
		"ambience_volume": 0.5,
		"muted": false,
	},
	"video": {
		"fullscreen": false,
		"vsync": true,
		"crt_enabled": true,
		"crt_strength": 1.0,
		"shake_strength": 1.0,
		"hit_stop": true,
		"damage_numbers": true,
	},
	"crosshair": {
		"crosshair_style": "brackets",
		"crosshair_size": 3,
		"crosshair_color": Color("f4f4f4"),
		"crosshair_react": true,
		"crosshair_target_color": Color("ef7d57"),
		"crosshair_opacity": 1.0,
		"crosshair_center": "dot",
		"crosshair_spin": false,
		"crosshair_spin_speed": 90.0,
		"crosshair_breathe": true,
		"crosshair_recoil": true,
		"crosshair_hit_marker": true,
	},
}

## Bus name per volume key.
const BUSES := {
	&"master_volume": &"Master",
	&"music_volume": &"Music",
	&"sfx_volume": &"SFX",
	&"ui_volume": &"UI",
	&"ambience_volume": &"Ambience",
}

var _values := {}
var _section_of := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var file := ConfigFile.new()
	var loaded := file.load(PATH) == OK
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			_section_of[StringName(key)] = section
			var fallback = DEFAULTS[section][key]
			var stored = file.get_value(section, key, fallback) if loaded else fallback
			# Guard against hand-edited files with the wrong type.
			_values[StringName(key)] = stored if typeof(stored) == typeof(fallback) else fallback
	_apply_all()


func value(key: StringName) -> Variant:
	return _values.get(key)


func set_value(key: StringName, new_value: Variant) -> void:
	if not _values.has(key) or _values[key] == new_value:
		return
	_values[key] = new_value
	_apply(key)
	_save()
	changed.emit(key)


## Restores one section ("audio", "video", "crosshair") to defaults.
func reset_section(section: String) -> void:
	for key in DEFAULTS[section]:
		_values[StringName(key)] = DEFAULTS[section][key]
		_apply(StringName(key))
		changed.emit(StringName(key))
	_save()


func _save() -> void:
	var file := ConfigFile.new()
	for key in _values:
		file.set_value(_section_of[key], key, _values[key])
	file.save(PATH)


func _apply_all() -> void:
	for key in _values:
		_apply(key)


func _apply(key: StringName) -> void:
	if BUSES.has(key) or key == &"muted":
		_apply_volumes()
	elif key == &"fullscreen":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value(&"fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(mode)
	elif key == &"vsync":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value(&"vsync") else DisplayServer.VSYNC_DISABLED)


func _apply_volumes() -> void:
	for key in BUSES:
		var bus := AudioServer.get_bus_index(BUSES[key])
		if bus < 0:
			continue
		var linear: float = value(key)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(bus, linear <= 0.001 or (key == &"master_volume" and value(&"muted")))
