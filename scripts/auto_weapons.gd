class_name AutoWeapons
extends Node2D
## "Bullet heaven" companions that fight on their own: guardian orbs,
## combat drones and sky lightning. Counts come from PlayerStats, and all
## damage scales with the player's damage upgrades.

const ORB_SHEET := preload("res://assets/floor38/fx/orb.png")
const DRONE_SHEET := preload("res://assets/floor38/fx/drone.png")
const DRONE_BULLET := preload("res://assets/Guns_V1.01 - Commission - Copy/01 - Individual sprites/Bullets & Ammo/Glock - P80/Bullet.png")
const PROJECTILE := preload("res://scenes/projectile.tscn")

const ORB_RADIUS := 30.0
const ORB_SPEED := 3.2
const ORB_DAMAGE := 14.0
const ORB_HIT_RADIUS := 7.0
const ORB_REHIT := 0.35

const DRONE_DAMAGE := 9.0
const DRONE_INTERVAL := 0.55
const DRONE_RANGE := 190.0

const THUNDER_DAMAGE := 40.0
const THUNDER_INTERVAL := 2.2
const THUNDER_RANGE := 200.0

var _stats: PlayerStats
var _orbs: Array[AnimatedSprite2D] = []
var _orb_hits: Dictionary = {}
var _orb_angle := 0.0
var _drones: Array[AnimatedSprite2D] = []
var _drone_timers: Array[float] = []
var _thunder_timer := THUNDER_INTERVAL
var _time := 0.0


func setup(stats: PlayerStats) -> void:
	_stats = stats
	_stats.changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	_resize(_orbs, _stats.get_int(Stats.Stat.ORBITALS), ORB_SHEET, Vector2i(9, 9), 10.0, Fx.GLOW_COOL)
	_resize(_drones, _stats.get_int(Stats.Stat.DRONES), DRONE_SHEET, Vector2i(12, 9), 24.0, Color.WHITE)
	while _drone_timers.size() < _drones.size():
		_drone_timers.append(randf() * DRONE_INTERVAL)
	_drone_timers.resize(_drones.size())


func _resize(list: Array[AnimatedSprite2D], count: int, sheet: Texture2D, frame: Vector2i, fps: float, tint: Color) -> void:
	while list.size() < count:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = SpriteSheetUtil.strip(sheet, frame, fps, true)
		sprite.modulate = tint
		sprite.top_level = true
		sprite.z_index = 3
		add_child(sprite)
		sprite.global_position = global_position
		sprite.play()
		list.append(sprite)
	while list.size() > count:
		list.pop_back().queue_free()


func _physics_process(delta: float) -> void:
	if _stats == null or (get_parent() as Player).is_dead:
		return
	_time += delta
	_update_orbs(delta)
	_update_drones(delta)
	_update_thunder(delta)


func _update_orbs(delta: float) -> void:
	if _orbs.is_empty():
		return
	_orb_angle += ORB_SPEED * delta
	if _orb_hits.size() > 400:
		_orb_hits.clear()
	var damage := ORB_DAMAGE * _stats.damage_multiplier()
	var now := _time
	for i in _orbs.size():
		var orb := _orbs[i]
		orb.global_position = global_position + Vector2.from_angle(_orb_angle + TAU * i / _orbs.size()) * ORB_RADIUS
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var enemy := node as Enemy
			if not enemy.can_be_hit():
				continue
			if orb.global_position.distance_to(enemy.global_position + Vector2(0, -4)) > ORB_HIT_RADIUS + enemy.hit_radius():
				continue
			if now < float(_orb_hits.get(enemy, 0.0)):
				continue
			_orb_hits[enemy] = now + ORB_REHIT
			var push := (enemy.global_position - global_position).normalized() * 90.0
			enemy.take_damage(damage, push)
			Sound.play(&"orb_hit", enemy.global_position)


func _update_drones(delta: float) -> void:
	for i in _drones.size():
		var drone := _drones[i]
		# Hover over the shoulders, trailing behind with a gentle bob.
		var side := -1.0 if i % 2 == 0 else 1.0
		var slot := Vector2(side * (14.0 + 6.0 * (i / 2)), -16.0 + sin(_time * 3.0 + i) * 2.0)
		drone.global_position = drone.global_position.lerp(global_position + slot, minf(1.0, 8.0 * delta))
		_drone_timers[i] -= delta
		if _drone_timers[i] > 0.0:
			continue
		var target := _nearest_enemy(drone.global_position, DRONE_RANGE)
		if target == null:
			continue
		_drone_timers[i] = DRONE_INTERVAL / maxf(0.2, _stats.get_stat(Stats.Stat.DRONE_RATE))
		var angle := (target.global_position + Vector2(0, -4) - drone.global_position).angle()
		var projectile: Projectile = PROJECTILE.instantiate()
		projectile.setup({
			"angle": angle, "speed": 380.0, "damage": DRONE_DAMAGE * _stats.damage_multiplier() * _stats.get_stat(Stats.Stat.DRONE_DAMAGE),
			"crit": false, "pierce": 0, "knockback": 40.0, "explosion_radius": 0.0,
			"range": DRONE_RANGE + 40.0, "texture": DRONE_BULLET, "texture_scale": 1.0, "tint": Fx.GLOW_COOL,
		})
		Fx.layer(&"projectile_layer").add_child(projectile)
		projectile.global_position = drone.global_position + Vector2(0, 3)
		Fx.muzzle_flare(projectile.global_position, angle)
		Sound.play(&"drone_shot", drone.global_position)


func _update_thunder(delta: float) -> void:
	var strikes := _stats.get_int(Stats.Stat.THUNDER)
	if strikes <= 0:
		return
	_thunder_timer -= delta
	if _thunder_timer > 0.0:
		return
	_thunder_timer = THUNDER_INTERVAL
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.can_be_hit() and enemy.global_position.distance_to(global_position) <= THUNDER_RANGE:
			candidates.append(enemy)
	candidates.shuffle()
	for i in mini(strikes, candidates.size()):
		var enemy: Enemy = candidates[i]
		Fx.sky_bolt(enemy.global_position)
		Shockwave.spawn(enemy.global_position, 12.0, 0.0, 0.0)
		enemy.take_damage(THUNDER_DAMAGE * _stats.damage_multiplier(), Vector2.ZERO, true)
	if not candidates.is_empty():
		Events.screen_shake.emit(0.15)
		Sound.play(&"thunder", (candidates[0] as Node2D).global_position)


func _nearest_enemy(from: Vector2, max_range: float) -> Enemy:
	var best: Enemy = null
	var best_distance := max_range
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if not enemy.can_be_hit():
			continue
		var distance := from.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best
