class_name UpgradePool
extends RefCounted
## Rolls the three cards offered after each round.

const RARITY_WEIGHTS := {
	UpgradeData.Rarity.COMMON: 60.0,
	UpgradeData.Rarity.RARE: 28.0,
	UpgradeData.Rarity.EPIC: 12.0,
}

var upgrades: Array[UpgradeData] = []
var weapons: Array[WeaponData] = []
## Chance that one of the cards is a weapon swap.
var weapon_offer_chance := 0.4
## Guarantee a weapon card after this many rounds without one.
var weapon_pity_rounds := 2

var _rounds_without_weapon := 0


func _init(upgrade_list: Array[UpgradeData], weapon_list: Array[WeaponData]) -> void:
	upgrades = upgrade_list
	weapons = weapon_list


func roll(count: int, round_number: int, stats: PlayerStats, allow_weapons := true) -> Array[UpgradeData]:
	var offer: Array[UpgradeData] = []

	var weapon_choices := weapons.filter(func(w: WeaponData) -> bool:
		return allow_weapons and w != stats.weapon and w.min_round <= round_number)
	var force_weapon := _rounds_without_weapon >= weapon_pity_rounds
	if not weapon_choices.is_empty() and (force_weapon or randf() < weapon_offer_chance):
		offer.append(UpgradeData.for_weapon(weapon_choices.pick_random()))
		_rounds_without_weapon = 0
	elif allow_weapons and not weapon_choices.is_empty():
		_rounds_without_weapon += 1

	var candidates := upgrades.filter(func(u: UpgradeData) -> bool:
		return _is_eligible(u, round_number, stats))
	while offer.size() < count and not candidates.is_empty():
		var picked := _pick_weighted(candidates)
		candidates.erase(picked)
		offer.append(picked)

	offer.shuffle()
	return offer


func _is_eligible(upgrade: UpgradeData, round_number: int, stats: PlayerStats) -> bool:
	if upgrade.min_round > round_number:
		return false
	if upgrade.max_stacks > 0 and stats.stack_count(upgrade) >= upgrade.max_stacks:
		return false
	if upgrade.requires_explosive and not stats.weapon.is_explosive():
		return false
	return true


func _pick_weighted(candidates: Array) -> UpgradeData:
	var total := 0.0
	for upgrade: UpgradeData in candidates:
		total += RARITY_WEIGHTS.get(upgrade.rarity, 10.0)
	var roll_value := randf() * total
	for upgrade: UpgradeData in candidates:
		roll_value -= RARITY_WEIGHTS.get(upgrade.rarity, 10.0)
		if roll_value <= 0.0:
			return upgrade
	return candidates.back()
