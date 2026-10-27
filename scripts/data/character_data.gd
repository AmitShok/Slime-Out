class_name CharacterData
extends Resource
## A playable character: look, base stats, starting kit, which weapons and
## upgrades it can be offered, and its unique trait.

@export var id: StringName
@export var display_name := ""
## Short role tag shown on the select card, e.g. "GUNS".
@export var role := ""
@export_multiline var description := ""
## One line per trait, shown as bullet points on the select screen.
@export var traits: PackedStringArray = []

@export_group("Look")
## Body sheet built by art_src/tools/build_player.lua.
@export var body_sheet: Texture2D
@export var hand_texture: Texture2D

@export_group("Kit")
## &"gun" or &"melee" - filters upgrade cards (see UpgradeData.styles).
@export var style: StringName = &"gun"
@export var starting_weapon: WeaponData
## Weapons that can show up as swap cards.
@export var weapons: Array[WeaponData] = []

@export_group("Base Stats")
@export var max_health := 100.0
@export var move_speed := 115.0
@export var dash_cooldown := 0.8
@export_range(0.0, 1.0) var crit_chance := 0.05
@export_range(0.0, 0.6) var armor := 0.0
## Permanent modifiers (count as the character's trait, not as upgrades).
@export var modifiers: Array[StatModifier] = []

@export_group("Trait")
## Damage dealt to slimes the dash passes through (0 = none).
@export var dash_damage := 0.0
## Melee swings destroy spitter acid in their arc.
@export var parries_projectiles := false

## Select screen stat bars, 0..1.
@export_group("Select Screen")
@export_range(0.0, 1.0) var bar_health := 0.5
@export_range(0.0, 1.0) var bar_speed := 0.5
@export_range(0.0, 1.0) var bar_damage := 0.5
@export_range(0.0, 1.0) var bar_range := 0.5


func can_take(upgrade: UpgradeData) -> bool:
	return upgrade.styles.is_empty() or upgrade.styles.has(style) or upgrade.styles.has(id)
