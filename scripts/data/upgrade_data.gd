class_name UpgradeData
extends Resource
## A pickable upgrade card. Either grants stat modifiers or (when `weapon`
## is set) swaps the player's gun. Weapon cards are generated at runtime
## from WeaponData via `for_weapon()`.

enum Rarity { COMMON, RARE, EPIC, WEAPON }

@export var id: StringName
@export var title := ""
## BBCode allowed.
@export_multiline var description := ""
@export var icon: Texture2D
@export var rarity := Rarity.COMMON
@export var modifiers: Array[StatModifier] = []
## Instant heal when picked.
@export var heal_on_pick := 0.0
## 0 = unlimited.
@export var max_stacks := 0
@export var min_round := 1
## Only offered while holding an explosive weapon.
@export var requires_explosive := false

var weapon: WeaponData


static func for_weapon(source: WeaponData) -> UpgradeData:
	var card := UpgradeData.new()
	card.id = source.id
	card.title = source.display_name
	card.description = source.description
	card.icon = source.icon
	card.rarity = Rarity.WEAPON
	card.weapon = source
	return card


static func rarity_color(value: Rarity) -> Color:
	match value:
		Rarity.RARE:
			return Color("41a6f6")
		Rarity.EPIC:
			return Color("c06ce8")
		Rarity.WEAPON:
			return Color("ffcd75")
	return Color("94b0c2")


static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.RARE:
			return "RARE"
		Rarity.EPIC:
			return "EPIC"
		Rarity.WEAPON:
			return "NEW WEAPON"
	return "COMMON"


func is_weapon() -> bool:
	return weapon != null
