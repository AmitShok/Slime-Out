class_name Profile
extends RefCounted
## Player profile (user://profile.cfg): last picked character and the
## custom look for each character. The select screen writes it; a new run
## reads `selected` / `look_for()`.

const PATH := "user://profile.cfg"
const CHARACTERS := [
	"res://resources/characters/gunner.tres",
	"res://resources/characters/knight.tres",
	"res://resources/characters/engineer.tres",
]

## Chosen on the select screen for the next new run.
static var selected: CharacterData
static var selected_look := {}


static func all_characters() -> Array[CharacterData]:
	var list: Array[CharacterData] = []
	for path in CHARACTERS:
		list.append(load(path))
	return list


static func by_id(id: StringName) -> CharacterData:
	for character in all_characters():
		if character.id == id:
			return character
	return all_characters()[0]


static func last_character_id() -> StringName:
	var file := ConfigFile.new()
	file.load(PATH)
	return StringName(file.get_value("profile", "last_character", "gunner"))


static func look_for(id: StringName) -> Dictionary:
	var file := ConfigFile.new()
	file.load(PATH)
	var stored = file.get_value("looks", String(id), {})
	var look := CharacterLooks.default_look(id)
	if typeof(stored) == TYPE_DICTIONARY:
		for slot in CharacterLooks.SLOTS:
			if stored.has(slot):
				look[slot] = int(stored[slot])
	return look


static func save(id: StringName, look: Dictionary) -> void:
	var file := ConfigFile.new()
	file.load(PATH)
	file.set_value("profile", "last_character", String(id))
	file.set_value("looks", String(id), look)
	file.save(PATH)
