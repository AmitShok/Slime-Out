class_name Weapon
extends Node2D
## The gun the player holds. Every number is read from PlayerStats on use,
## so upgrades and weapon swaps take effect immediately.

signal ammo_changed(current: int, maximum: int)
signal reload_started(duration: float)
signal reload_finished

const MULTISHOT_FAN_DEGREES := 9.0
const RECOIL_DISTANCE := 1.5
## Below this distance the cursor is "inside" the gun; aim along the barrel.
const MIN_AIM_DISTANCE := 8.0
## How long before the reload ends the "mag in + rack" sound starts.
const RELOAD_IN_LEAD := 0.42

static var _frames_cache: Dictionary = {}

@export var projectile_scene: PackedScene

var data: WeaponData
var ammo := 0
var enabled := true

var _stats: PlayerStats
var _cooldown := 0.0
var _reload_left := 0.0
var _reload_total := 0.0
var _reload_in_played := true
var _recoil_tween: Tween

@onready var _holder: Node2D = $Holder
@onready var _sprite: AnimatedSprite2D = $Holder/Sprite
@onready var _grip_hand: Sprite2D = $Holder/GripHand
@onready var _support_hand: Sprite2D = $Holder/SupportHand
@onready var _muzzle: Marker2D = $Holder/Muzzle


func _ready() -> void:
	_sprite.animation_finished.connect(_on_animation_finished)


func setup(stats: PlayerStats) -> void:
	_stats = stats
	_stats.weapon_changed.connect(equip)
	_stats.changed.connect(refill)
	equip(_stats.weapon)


func equip(weapon: WeaponData) -> void:
	data = weapon
	_sprite.sprite_frames = _frames_for(weapon)
	_sprite.scale = Vector2.ONE * weapon.sprite_scale
	_sprite.offset = Vector2(weapon.frame_size) * 0.5 - weapon.grip
	_muzzle.position = (weapon.muzzle - weapon.grip) * weapon.sprite_scale
	_holder.position = Vector2(weapon.hold_distance, 0.0)
	# Hands are full-size pixels placed on the gun's grip points.
	_grip_hand.position = Vector2.ZERO
	_support_hand.position = (weapon.support_grip - weapon.grip) * weapon.sprite_scale
	_cooldown = 0.0
	refill()


## Instantly cancels any reload and fills the magazine.
func refill() -> void:
	if data == null:
		return
	_reload_left = 0.0
	ammo = max_ammo()
	_sprite.speed_scale = 1.0
	_sprite.play(&"idle")
	ammo_changed.emit(ammo, max_ammo())


func max_ammo() -> int:
	return _stats.get_int(Stats.Stat.MAGAZINE)


func is_reloading() -> bool:
	return _reload_left > 0.0


func reload_progress() -> float:
	return 1.0 - _reload_left / _reload_total if is_reloading() else 1.0


func start_reload() -> void:
	if is_reloading() or data == null or ammo >= max_ammo():
		return
	_reload_total = maxf(0.1, _stats.get_stat(Stats.Stat.RELOAD_TIME))
	_reload_left = _reload_total
	if _sprite.sprite_frames.has_animation(&"reload"):
		_sprite.play(&"reload")
		_sprite.speed_scale = SpriteSheetUtil.duration(_sprite.sprite_frames, &"reload") / _reload_total
	_reload_in_played = false
	if not data.reload_out_sound.is_empty():
		# A beat after the last shot so its echo doesn't mask the mag release.
		var out_sound := data.reload_out_sound
		get_tree().create_timer(0.09, false).timeout.connect(func() -> void:
			if is_inside_tree():
				Sound.play(out_sound, global_position))
	reload_started.emit(_reload_total)


func _process(delta: float) -> void:
	if data == null:
		return
	_aim()
	_cooldown = maxf(0.0, _cooldown - delta)
	if is_reloading():
		_reload_left -= delta
		# Seat the mag / rack the slide so the sound finishes with the reload.
		if not _reload_in_played and _reload_left <= RELOAD_IN_LEAD:
			_reload_in_played = true
			if not data.reload_in_sound.is_empty():
				Sound.play(data.reload_in_sound, global_position)
		if _reload_left <= 0.0:
			_finish_reload()
	if not enabled:
		return
	if Input.is_action_just_pressed(&"reload"):
		start_reload()
	if Input.is_action_pressed(&"click") and _cooldown <= 0.0 and not is_reloading():
		if ammo > 0:
			_fire()
		else:
			start_reload()


func _aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() < 1.0:
		return
	rotation = to_mouse.angle()
	# Mirror instead of rotating upside down when aiming left.
	scale.y = -1.0 if to_mouse.x < 0.0 else 1.0


func _fire() -> void:
	var count := _stats.get_int(Stats.Stat.PROJECTILE_COUNT)
	var spread := deg_to_rad(_stats.get_stat(Stats.Stat.SPREAD))
	var fan := deg_to_rad(MULTISHOT_FAN_DEGREES)
	var origin := _muzzle.global_position
	var aim_angle := (get_global_mouse_position() - origin).angle()
	if origin.distance_to(get_global_mouse_position()) < MIN_AIM_DISTANCE:
		aim_angle = global_rotation

	var damage := _stats.get_stat(Stats.Stat.DAMAGE)
	var crit_chance := _stats.get_stat(Stats.Stat.CRIT_CHANCE)
	var container := _projectile_container()
	for i in count:
		var angle := aim_angle + (i - (count - 1) * 0.5) * fan + randf_range(-0.5, 0.5) * spread
		var is_crit := randf() < crit_chance
		var projectile: Projectile = projectile_scene.instantiate()
		projectile.setup({
			"angle": angle,
			"speed": _stats.get_stat(Stats.Stat.PROJECTILE_SPEED),
			"damage": damage * (Stats.CRIT_MULTIPLIER if is_crit else 1.0),
			"crit": is_crit,
			"pierce": _stats.get_int(Stats.Stat.PIERCE),
			"knockback": _stats.get_stat(Stats.Stat.KNOCKBACK),
			"explosion_radius": _stats.get_stat(Stats.Stat.EXPLOSION_RADIUS),
			"ricochet": _stats.get_int(Stats.Stat.RICOCHET),
			"chain": _stats.get_int(Stats.Stat.CHAIN_LIGHTNING),
			"burn": _stats.get_stat(Stats.Stat.BURN),
			"range": data.max_range,
			"texture": data.projectile_texture,
			"texture_scale": data.projectile_scale,
		})
		container.add_child(projectile)
		projectile.global_position = origin

	ammo -= 1
	ammo_changed.emit(ammo, max_ammo())
	_cooldown = 1.0 / maxf(0.1, _stats.get_stat(Stats.Stat.FIRE_RATE))
	_play_shoot_animation()
	_kick()
	Sound.play(data.fire_sound, origin)
	Events.screen_shake.emit(data.screen_shake)
	# Vlambeer recipe: flare, ejected shell, camera nudged against the shot.
	Fx.muzzle_flare(origin, aim_angle)
	if not data.is_explosive():
		Fx.casing(_holder.global_position, aim_angle, scale.y < 0.0)
	Events.camera_kick.emit(-Vector2.from_angle(aim_angle) * (1.0 + data.screen_shake * 12.0))
	if ammo <= 0:
		start_reload()


func _play_shoot_animation() -> void:
	_sprite.play(&"shoot")
	_sprite.frame = 0
	# Speed the animation up so it never lags behind the fire rate.
	var length := SpriteSheetUtil.duration(_sprite.sprite_frames, &"shoot")
	_sprite.speed_scale = maxf(1.0, length / maxf(_cooldown, 0.01))


func _kick() -> void:
	if _recoil_tween:
		_recoil_tween.kill()
	# Kick the whole holder so the hands recoil with the gun.
	var rest := Vector2(data.hold_distance, 0.0)
	_holder.position = rest - Vector2(RECOIL_DISTANCE, 0.0)
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_holder, "position", rest, 0.09).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _finish_reload() -> void:
	_reload_left = 0.0
	ammo = max_ammo()
	_sprite.speed_scale = 1.0
	_sprite.play(&"idle")
	ammo_changed.emit(ammo, max_ammo())
	reload_finished.emit()


func _on_animation_finished() -> void:
	if _sprite.animation == &"shoot" and not is_reloading():
		_sprite.speed_scale = 1.0
		_sprite.play(&"idle")


func _projectile_container() -> Node:
	var container := get_tree().get_first_node_in_group(&"projectile_layer")
	return container if container else get_tree().current_scene


static func _frames_for(weapon: WeaponData) -> SpriteFrames:
	if _frames_cache.has(weapon):
		return _frames_cache[weapon]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var shoot := SpriteSheetUtil.slice(weapon.shoot_sheet, weapon.frame_size)
	SpriteSheetUtil.add_animation(frames, &"idle", shoot.slice(0, 1), 1.0, false)
	SpriteSheetUtil.add_animation(frames, &"shoot", shoot, weapon.shoot_fps, false)
	if weapon.reload_sheet:
		var reload := SpriteSheetUtil.slice(weapon.reload_sheet, weapon.frame_size)
		SpriteSheetUtil.add_animation(frames, &"reload", reload, weapon.reload_fps, false)
	_frames_cache[weapon] = frames
	return frames
