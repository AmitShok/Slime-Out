class_name CharacterLooks
extends RefCounted
## Cosmetic recolouring. Every character sheet uses the same palette slots
## (build_player.lua): skin, hair (Knight: plume), outfit (Knight: armour)
## and accent (scarf / tabard / cap). A look picks one hand-made ramp per
## slot; textures are recoloured pixel-exactly on the CPU, so the pixel art
## stays crisp and HDR colour space never matters.

const SLOTS := ["skin", "hair", "outfit", "accent"]
const SLOT_LABELS := { "skin": "Skin", "hair": "Hair", "outfit": "Outfit", "accent": "Accent" }

## Ramps light -> dark. Accent ramps have 3 tones, the others 4.
const RAMPS := {
	"skin": [
		["fde0c4", "f2c09a", "d4936d", "a8644a"],
		["f0c49a", "d9a173", "b07448", "7d4d2c"],
		["e0a878", "c08050", "945a34", "653a20"],
		["b9805a", "93603e", "6c4228", "472816"],
		["8a5a3c", "6c4429", "4d2e1a", "2f1a0e"],
		["c9e0a8", "9fc27a", "6f9452", "476335"],
	],
	"hair": [
		["a6774c", "7a5236", "553621", "33201a"],
		["6b5442", "4d3a2c", "33261c", "1f1712"],
		["2f2a2e", "221e22", "171417", "0c0a0c"],
		["f2d27a", "d9a84a", "a8782a", "6b4a18"],
		["f0605a", "c23d4a", "8a2438", "4f1a2b"],
		["e8eef4", "b9c3d0", "8a96a8", "565f70"],
		["8fd6ff", "4fa3e0", "2f6db0", "1d3f73"],
		["c78bff", "9a5ce0", "6a38a8", "3f1f6b"],
	],
	"outfit": [
		["b5c47a", "8a9c56", "5f7038", "3a4626"],
		["e4e9f0", "a9b3c3", "707c92", "3c4458"],
		["ffb45e", "e5862e", "a85a1e", "5e3012"],
		["8fb8e8", "5b8ac9", "3b5d96", "253a63"],
		["e87878", "c04a4a", "8a2e3a", "521a26"],
		["5a5a66", "40404c", "2a2a34", "17171f"],
		["ffe08a", "e0b040", "a87a24", "6a4a14"],
		["9de0b0", "5fb87e", "3a8a56", "235834"],
	],
	"accent": [
		["e05a5a", "b13e53", "7a2838"],
		["5b8ee6", "3b5dc9", "29366f"],
		["4fd6c7", "2a9d8f", "1c5f5a"],
		["ffcd75", "e0a040", "a06a1e"],
		["a7f070", "5fb84a", "357a2e"],
		["c06ce8", "8a3fb8", "56207a"],
		["f4f4f4", "b0b8c8", "6a7488"],
		["3a3a46", "26262f", "15151b"],
	],
}

## Which ramp each character starts with (indices into RAMPS) - matches the
## colours baked into its sheet, so the default look is the unaltered art.
const DEFAULTS := {
	&"gunner": { "skin": 0, "hair": 0, "outfit": 0, "accent": 0 },
	&"knight": { "skin": 0, "hair": 4, "outfit": 1, "accent": 1 },
	&"engineer": { "skin": 1, "hair": 1, "outfit": 2, "accent": 2 },
}

static var _cache := {}


static func default_look(character_id: StringName) -> Dictionary:
	return DEFAULTS.get(character_id, DEFAULTS[&"gunner"]).duplicate()


static func random_look() -> Dictionary:
	var look := {}
	for slot in SLOTS:
		look[slot] = randi() % RAMPS[slot].size()
	return look


static func slot_color(slot: String, index: int) -> Color:
	return Color(RAMPS[slot][index][1])


## Returns `texture` with this character's default ramps swapped for `look`.
static func recolor(texture: Texture2D, character_id: StringName, look: Dictionary) -> Texture2D:
	if texture == null:
		return null
	var defaults := default_look(character_id)
	var swaps := {}
	for slot in SLOTS:
		var from: Array = RAMPS[slot][int(defaults[slot])]
		var to: Array = RAMPS[slot][int(look.get(slot, defaults[slot])) % RAMPS[slot].size()]
		for i in from.size():
			if from[i] != to[i]:
				swaps[from[i]] = Color(to[i])
	if swaps.is_empty():
		return texture
	var key := "%s|%s|%s" % [texture.resource_path, character_id, str(look)]
	if _cache.has(key):
		return _cache[key]
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var hex := c.to_html(false)
			if swaps.has(hex):
				var to: Color = swaps[hex]
				image.set_pixel(x, y, Color(to.r, to.g, to.b, c.a))
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	return result
