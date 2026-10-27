class_name RunSave
extends RefCounted
## The in-progress run, saved to user://run.json so quitting mid-round can
## be continued later. Resources are stored by resource path, vectors as
## [x, y]. A run ends (and its save is deleted) when the player dies.

const PATH := "user://run.json"
const VERSION := 1

## Set by the main menu's Continue button before the game scene loads.
static var resume_requested := false


static func exists() -> bool:
	return not load_data().is_empty()


static func write(data: Dictionary) -> void:
	data["version"] = VERSION
	data["saved_at"] = Time.get_datetime_string_from_system()
	# Write to a temp file first so a crash mid-write never corrupts the save.
	var temp := PATH + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("RunSave: can't write %s (%s)" % [temp, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(PATH))


## Returns {} when there is no valid save.
static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != VERSION:
		return {}
	return parsed


static func delete() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Short description for the Continue button, e.g. "Round 4  -  LV 7  -  AK-47".
static func summary() -> String:
	var data := load_data()
	if data.is_empty():
		return ""
	var weapon_name := ""
	var weapon := load(str(data.stats.weapon)) as WeaponData
	if weapon:
		weapon_name = weapon.display_name
	return "Round %d   -   LV %d   -   %s" % [int(data.round), int(data.stats.level), weapon_name]


static func vec(value: Vector2) -> Array:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]


static func to_vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
