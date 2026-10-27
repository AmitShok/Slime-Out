extends Node
## Global gameplay event bus (autoload "Events").
## Lets FX, camera and UI react to gameplay without hard references.

signal screen_shake(trauma: float)
## Directional camera nudge (world px), e.g. opposite the aim when firing.
signal camera_kick(offset: Vector2)
signal enemy_killed(enemy: Node2D)
## A player bullet connected (drives the reticle hit marker).
signal enemy_hit(enemy: Node2D, is_crit: bool)
signal boss_spawned(enemy: Node2D)
signal player_revived
signal player_hurt

var _hit_stop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Freeze-frame for impact. Uses real time so it works while slowed.
func hit_stop(seconds: float) -> void:
	if get_tree().paused or not Settings.value(&"hit_stop"):
		return
	_hit_stop_until = maxi(_hit_stop_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	Engine.time_scale = 0.05


func _process(_delta: float) -> void:
	if _hit_stop_until > 0 and Time.get_ticks_msec() >= _hit_stop_until:
		_hit_stop_until = 0
		Engine.time_scale = 1.0
