class_name Projectile
extends Area2D
## A bullet or rocket. Configured entirely by Weapon.setup().

@export var explosion_scene: PackedScene

var damage := 10.0
var is_crit := false
var pierce := 0
var knockback := 0.0
var explosion_radius := 0.0
var ricochet := 0
var chain_hops := 0
var burn := 0.0

const RICOCHET_RANGE := 140.0
const RICOCHET_TRAVEL := 220.0
const TRACER := preload("res://assets/floor38/fx/tracer.png")
const IMPACT := preload("res://assets/floor38/fx/spark.png")
const SMOKE_INTERVAL := 0.035

var _velocity := Vector2.ZERO
var _tint := Fx.GLOW_WARM
var _smoke_timer := 0.0
var _range_left := 400.0
var _texture: Texture2D
var _texture_scale := 1.0
var _already_hit: Dictionary = {}
var _spent := false

@onready var _sprite: Sprite2D = $Sprite2D


func setup(config: Dictionary) -> void:
	rotation = config.angle
	_velocity = Vector2.from_angle(config.angle) * config.speed
	damage = config.damage
	is_crit = config.crit
	pierce = config.pierce
	knockback = config.knockback
	explosion_radius = config.explosion_radius
	ricochet = config.get("ricochet", 0)
	chain_hops = config.get("chain", 0)
	burn = config.get("burn", 0.0)
	_range_left = config.range
	_texture = config.texture
	_texture_scale = config.texture_scale
	_tint = config.get("tint", Fx.GLOW_WARM)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_sprite.texture = _texture
	_sprite.scale = Vector2.ONE * _texture_scale
	if explosion_radius <= 0.0:
		# Glowing streak behind bullets; crits burn hotter.
		var tracer := Sprite2D.new()
		tracer.texture = TRACER
		tracer.offset = Vector2(-5.0, 0.0)
		tracer.show_behind_parent = true
		tracer.modulate = _tint * (1.4 if is_crit else 1.0)
		add_child(tracer)
		_sprite.modulate = _tint
	elif is_crit:
		_sprite.modulate = Fx.GLOW_WARM


func _physics_process(delta: float) -> void:
	if explosion_radius > 0.0:
		_smoke_timer -= delta
		if _smoke_timer <= 0.0:
			_smoke_timer = SMOKE_INTERVAL
			Fx.smoke(global_position - _velocity.normalized() * 6.0)
	var step := _velocity * delta
	position += step
	_range_left -= step.length()
	if _range_left <= 0.0:
		_finish(explosion_radius > 0.0)


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	var enemy := body as Enemy
	if enemy == null:
		# Hit the arena wall.
		_finish(explosion_radius > 0.0)
		return
	if not enemy.can_be_hit() or _already_hit.has(enemy):
		return
	_already_hit[enemy] = true
	if explosion_radius > 0.0:
		_finish(true)
		return
	_apply_on_hit_effects(enemy)
	enemy.take_damage(damage, _velocity.normalized() * knockback, is_crit)
	Events.enemy_hit.emit(enemy, is_crit)
	Fx.one_shot(IMPACT, Vector2i(7, 7), 30.0, global_position, _tint, randf() * TAU)
	if pierce > 0:
		pierce -= 1
	elif ricochet > 0 and _bounce_from(enemy):
		ricochet -= 1
	else:
		_finish(false)


func _apply_on_hit_effects(enemy: Enemy) -> void:
	if burn > 0.0:
		enemy.ignite(damage * burn)
	if is_crit and chain_hops > 0:
		ChainLightning.strike(enemy, damage * Stats.CHAIN_DAMAGE, chain_hops, _already_hit)


## Redirect towards the closest enemy we haven't hit yet.
func _bounce_from(origin: Enemy) -> bool:
	var best: Enemy = null
	var best_distance := RICOCHET_RANGE
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy == origin or _already_hit.has(enemy) or not enemy.can_be_hit():
			continue
		var distance := origin.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	if best == null:
		return false
	var direction := global_position.direction_to(best.global_position + Vector2(0, -4))
	_velocity = direction * _velocity.length()
	rotation = direction.angle()
	_range_left = RICOCHET_TRAVEL
	return true


func _finish(explode: bool) -> void:
	if _spent:
		return
	_spent = true
	if explode and explosion_scene:
		var explosion: Explosion = explosion_scene.instantiate()
		explosion.setup(explosion_radius, damage, knockback, is_crit)
		explosion.burn = burn
		explosion.position = global_position
		get_parent().add_child.call_deferred(explosion)
	set_deferred(&"monitoring", false)
	hide()
	queue_free()
