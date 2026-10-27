class_name EnemyData
extends Resource
## Definition of an enemy type. Round scaling is applied by WaveManager.

enum Behavior {
	## Walks straight at the player.
	CHASER,
	## Keeps its distance and lobs acid that lands where the player was heading.
	SPITTER,
	## Stops, telegraphs with "!", then dashes in a straight line.
	CHARGER,
}

@export var id: StringName
@export var behavior := Behavior.CHASER
@export var display_name := ""
## Slime-layout sheet (32x32 grid, 13 rows - see mystic forest README).
@export var sheet: Texture2D
## Keep to whole numbers so pixels stay square.
@export var sprite_scale := 1.0

## Tint for goo splats and droplets when it dies.
@export var goo_color := Color("65b1b8")
## XP dropped (scaled up a little each round by WaveManager).
@export var xp_value := 1.0

@export_group("Stats")
@export var max_health := 30.0
@export var speed := 42.0
@export var contact_damage := 10.0
## 0 = full knockback, 1 = immune.
@export_range(0.0, 1.0) var knockback_resistance := 0.0
## Body radius before sprite_scale.
@export var radius := 6.0

@export_group("Attack")
## SPITTER: preferred distance. CHARGER: distance that triggers a charge.
@export var attack_range := 110.0
@export var attack_cooldown := 2.5
## SPITTER: acid splash damage.
@export var attack_damage := 12.0
## CHARGER: telegraph time before dashing.
@export var windup_time := 0.65
@export var charge_speed := 270.0
@export var charge_duration := 0.45

@export_group("Split")
## Spawned when this enemy dies (e.g. big splitter -> minis).
@export var split_into: EnemyData
@export var split_count := 0

@export_group("Spawning")
@export var is_boss := false
@export var min_round := 1
@export var spawn_weight := 1.0
## Added to spawn_weight for every round past min_round.
@export var weight_per_round := 0.0
