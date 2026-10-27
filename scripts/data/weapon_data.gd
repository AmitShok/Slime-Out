class_name WeaponData
extends Resource
## Static definition of a weapon: visuals + base stats.
## Upgrades never modify this resource; PlayerStats layers them on top.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Shown on upgrade cards and the HUD.
@export var icon: Texture2D

@export_group("Visuals")
## Horizontal sheet; frame 0 doubles as the idle pose.
@export var shoot_sheet: Texture2D
@export var reload_sheet: Texture2D
@export var frame_size := Vector2i(64, 48)
@export var shoot_fps := 24.0
@export var reload_fps := 24.0
## Texel position (inside one frame) where the hand holds the gun.
@export var grip := Vector2.ZERO
## Texel position where the second hand rests (foregrip / pump / tube).
## For pistols put it just below the grip for a two-handed hold.
@export var support_grip := Vector2.ZERO
## Texel position (inside one frame) of the barrel tip.
@export var muzzle := Vector2.ZERO
## How far (world px) the grip sits in front of the chest pivot.
@export var hold_distance := 3.0
## Vertical shift of the pivot (negative = up, e.g. shoulder-fired).
@export var mount_height := 0.0
## 0.25 = one gun texel per screen pixel at camera zoom 4.
@export var sprite_scale := 0.25
@export var projectile_texture: Texture2D
@export var projectile_scale := 1.0
## Camera trauma added per shot (explosions add their own).
@export_range(0.0, 1.0) var screen_shake := 0.05
## Sound id in the Sound autoload.
@export var fire_sound: StringName = &"shot_pistol"
## Played when a reload starts / timed to end as the reload completes.
@export var reload_out_sound: StringName = &"reload_out"
@export var reload_in_sound: StringName = &"reload_in"

@export_group("Base Stats")
@export var damage := 10.0
## Shots per second.
@export var fire_rate := 4.0
@export var magazine := 12
## Seconds.
@export var reload_time := 1.2
@export var projectile_speed := 420.0
@export var projectile_count := 1
## Extra enemies a projectile passes through.
@export var pierce := 0
## Total cone in degrees.
@export var spread_degrees := 4.0
@export var knockback := 60.0
## 0 = regular bullet; > 0 = explodes on impact with this radius.
@export var explosion_radius := 0.0
@export var max_range := 400.0

@export_group("Unlock")
## Earliest round this weapon can be offered.
@export var min_round := 2


func get_base(stat: Stats.Stat) -> float:
	match stat:
		Stats.Stat.DAMAGE:
			return damage
		Stats.Stat.FIRE_RATE:
			return fire_rate
		Stats.Stat.MAGAZINE:
			return magazine
		Stats.Stat.RELOAD_TIME:
			return reload_time
		Stats.Stat.PROJECTILE_SPEED:
			return projectile_speed
		Stats.Stat.PROJECTILE_COUNT:
			return projectile_count
		Stats.Stat.PIERCE:
			return pierce
		Stats.Stat.SPREAD:
			return spread_degrees
		Stats.Stat.KNOCKBACK:
			return knockback
		Stats.Stat.EXPLOSION_RADIUS:
			return explosion_radius
	return 0.0


func is_explosive() -> bool:
	return explosion_radius > 0.0
