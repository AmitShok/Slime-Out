class_name PlayerStats
extends Node
## Owns the player's current weapon and every upgrade they have picked.
##
## Upgrades are stored as weapon-agnostic modifiers and are never baked into
## a weapon. Swapping guns just changes the base values underneath, so every
## upgrade the player already owns keeps applying to the new weapon.

signal changed
signal weapon_changed(weapon: WeaponData)
signal xp_changed(xp: float, needed: float, level: int)
signal leveled_up(level: int)

@export var starting_weapon: WeaponData
@export var base_move_speed := 115.0
@export var base_max_health := 100.0
@export var base_dash_cooldown := 0.8
@export_range(0.0, 1.0) var base_crit_chance := 0.05
@export var base_pickup_radius := 32.0

@export_group("Levelling")
@export var first_level_xp := 6.0
## Each level needs this much more XP than the last (multiplicative).
@export var level_xp_growth := 1.22

var weapon: WeaponData
## The playable character (base stats, trait modifiers). Null = defaults.
var character: CharacterData
var level := 1
var xp := 0.0
var xp_needed := 6.0
var upgrades: Array[UpgradeData] = []
## Set by Player; drives Last Stand.
var low_health := false

var _flat: Dictionary = {}
var _percent: Dictionary = {}


func _ready() -> void:
	weapon = starting_weapon
	xp_needed = first_level_xp
	_rebuild()


## Switches to a character's kit. Call before any upgrades are applied.
func set_character(value: CharacterData) -> void:
	character = value
	if character.starting_weapon:
		weapon = character.starting_weapon
		weapon_changed.emit(weapon)
	_rebuild()
	changed.emit()


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = roundf(xp_needed * level_xp_growth + 2.0)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_needed, level)


## Global damage scaling for things that aren't the gun (orbs, drones...).
func damage_multiplier() -> float:
	var multiplier := maxf(0.1, 1.0 + float(_percent.get(Stats.Stat.DAMAGE, 0.0)))
	return multiplier * (Stats.LAST_STAND_BONUS if is_last_stand_active() else 1.0)


func apply_upgrade(upgrade: UpgradeData) -> void:
	if upgrade.is_weapon():
		weapon = upgrade.weapon
		weapon_changed.emit(weapon)
	else:
		upgrades.append(upgrade)
		_rebuild()
	changed.emit()


func stack_count(upgrade: UpgradeData) -> int:
	return upgrades.count(upgrade)


## Unique upgrades in pick order, for UI.
func unique_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade in upgrades:
		if not result.has(upgrade):
			result.append(upgrade)
	return result


## Final value of a stat. Pass `for_weapon` to preview another gun with the
## player's current upgrades (used by weapon cards).
func get_stat(stat: Stats.Stat, for_weapon: WeaponData = null) -> float:
	var source := for_weapon if for_weapon else weapon
	var multiplier := 1.0 + float(_percent.get(stat, 0.0))
	if stat in Stats.REDUCIBLE:
		multiplier = maxf(multiplier, Stats.REDUCTION_FLOOR)
	else:
		multiplier = maxf(multiplier, 0.1)
	var value := (_base_value(stat, source) + float(_flat.get(stat, 0.0))) * multiplier
	if is_last_stand_active() and (stat == Stats.Stat.DAMAGE or stat == Stats.Stat.FIRE_RATE):
		value *= Stats.LAST_STAND_BONUS
	match stat:
		Stats.Stat.MAGAZINE:
			return maxf(1.0, roundf(value))
		Stats.Stat.PROJECTILE_COUNT:
			return maxf(1.0, roundf(value))
		Stats.Stat.PIERCE:
			return maxf(0.0, roundf(value))
		Stats.Stat.CRIT_CHANCE:
			return clampf(value, 0.0, 1.0)
		Stats.Stat.ARMOR:
			return clampf(value, 0.0, Stats.ARMOR_CAP)
		Stats.Stat.SLASH_WAVE, Stats.Stat.DRONES, Stats.Stat.ORBITALS:
			return maxf(0.0, roundf(value))
	return value


func is_last_stand_active() -> bool:
	return low_health and float(_flat.get(Stats.Stat.LAST_STAND, 0.0)) > 0.0


func get_int(stat: Stats.Stat, for_weapon: WeaponData = null) -> int:
	return roundi(get_stat(stat, for_weapon))


## Value of a stat before any upgrades (for the build screen).
func base_value(stat: Stats.Stat) -> float:
	return _base_value(stat, weapon)


func _base_value(stat: Stats.Stat, source: WeaponData) -> float:
	match stat:
		Stats.Stat.MOVE_SPEED:
			return character.move_speed if character else base_move_speed
		Stats.Stat.MAX_HEALTH:
			return character.max_health if character else base_max_health
		Stats.Stat.DASH_COOLDOWN:
			return character.dash_cooldown if character else base_dash_cooldown
		Stats.Stat.CRIT_CHANCE:
			return character.crit_chance if character else base_crit_chance
		Stats.Stat.ARMOR:
			return character.armor if character else 0.0
		Stats.Stat.DRONE_DAMAGE, Stats.Stat.DRONE_RATE:
			return 1.0
		Stats.Stat.PICKUP_RADIUS:
			return base_pickup_radius
	return source.get_base(stat) if source else 0.0


func _rebuild() -> void:
	_flat.clear()
	_percent.clear()
	if character:
		for modifier in character.modifiers:
			var trait_bucket := _flat if modifier.mode == StatModifier.Mode.FLAT else _percent
			trait_bucket[modifier.stat] = float(trait_bucket.get(modifier.stat, 0.0)) + modifier.value
	for upgrade in upgrades:
		for modifier in upgrade.modifiers:
			var bucket := _flat if modifier.mode == StatModifier.Mode.FLAT else _percent
			bucket[modifier.stat] = float(bucket.get(modifier.stat, 0.0)) + modifier.value
