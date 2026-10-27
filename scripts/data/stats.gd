class_name Stats
extends RefCounted
## Identifiers for every stat shared by weapons, upgrades and the player.
## NOTE: values are stored as ints inside .tres files - append new stats
## at the end, never reorder.

enum Stat {
	DAMAGE,
	FIRE_RATE,
	MAGAZINE,
	RELOAD_TIME,
	PROJECTILE_SPEED,
	PROJECTILE_COUNT,
	PIERCE,
	SPREAD,
	CRIT_CHANCE,
	KNOCKBACK,
	EXPLOSION_RADIUS,
	MOVE_SPEED,
	MAX_HEALTH,
	DASH_COOLDOWN,
	## Extra bounces to a nearby enemy after the last pierce.
	RICOCHET,
	## Enemies a crit arcs to (50% damage each).
	CHAIN_LIGHTNING,
	HEAL_ON_KILL,
	## Damage dealt around the player when hit.
	THORNS,
	## Burn damage per second, as a fraction of the hit's damage.
	BURN,
	## Shockwave damage released at the end of a dash.
	DASH_SHOCKWAVE,
	## > 0 enables the low-health damage/fire-rate bonus.
	LAST_STAND,
	EXTRA_LIFE,
	## Radius (px) at which XP gems and pickups fly to the player.
	PICKUP_RADIUS,
	## Guardian orbs circling the player.
	ORBITALS,
	## Combat drones that auto-fire at the nearest enemy.
	DRONES,
	## Enemies struck per sky-lightning volley.
	THUNDER,
}

## Last Stand: active below this health fraction, multiplies these stats.
const LAST_STAND_THRESHOLD := 0.3
const LAST_STAND_BONUS := 1.5
## Chain lightning hop damage as a fraction of the crit.
const CHAIN_DAMAGE := 0.5

## Stats where lower is better. Their multiplier is floored so stacking
## reductions can never reach zero.
const REDUCIBLE: Array[Stat] = [Stat.RELOAD_TIME, Stat.SPREAD, Stat.DASH_COOLDOWN]
const REDUCTION_FLOOR := 0.25
const CRIT_MULTIPLIER := 2.0
