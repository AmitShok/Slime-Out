class_name Explosion
extends Node2D
## Area damage + visuals for explosive projectiles.
## Larger radii add extra explosion sprites instead of scaling one up,
## so the pixel art stays crisp at any upgrade level.

const SHEET := preload("res://assets/floor38/fx/explosion.png")
## The goo splat shapes double as scorch marks when tinted dark.
const SCORCH := preload("res://assets/floor38/fx/goo.png")
const FRAME_SIZE := Vector2i(48, 48)
## Radius one explosion sprite visually covers at scale 1.
const VISUAL_RADIUS := 20.0
const EXTRA_BLAST_SPACING := 9.0
const BASE_SHAKE := 0.3

static var _frames: SpriteFrames

var radius := 30.0
var damage := 40.0
var knockback := 200.0
var is_crit := false
var burn := 0.0


func setup(blast_radius: float, blast_damage: float, blast_knockback: float, crit: bool) -> void:
	radius = blast_radius
	damage = blast_damage
	knockback = blast_knockback
	is_crit = crit


func _ready() -> void:
	z_index = 2
	_spawn_blast(Vector2.ZERO, 0.0)
	var extra := int((radius - VISUAL_RADIUS) / EXTRA_BLAST_SPACING)
	for i in extra:
		var angle := TAU * float(i) / float(extra) + randf_range(-0.4, 0.4)
		var offset := Vector2.from_angle(angle) * radius * randf_range(0.45, 0.7)
		_spawn_blast(offset, 0.04 * (i + 1))
	_apply_damage()
	Events.screen_shake.emit(BASE_SHAKE + radius / 200.0)
	Sound.play(&"explosion", global_position, clampf(28.0 / maxf(radius, 1.0), 0.75, 1.15))
	Events.hit_stop(0.03)
	Fx.decal(SCORCH, Vector2i(16, 9), global_position, Color(0.1, 0.08, 0.08, 0.55))
	get_tree().create_timer(1.5, false).timeout.connect(queue_free)


func _apply_damage() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.can_be_hit():
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > radius + enemy.hit_radius():
			continue
		var direction := offset.normalized() if offset.length() > 0.5 else Vector2.from_angle(randf() * TAU)
		if burn > 0.0:
			enemy.ignite(damage * burn)
		enemy.take_damage(damage, direction * knockback, is_crit)


func _spawn_blast(offset: Vector2, delay: float) -> void:
	var blast := AnimatedSprite2D.new()
	blast.sprite_frames = _get_frames()
	blast.modulate = Color(1.6, 1.4, 1.2)
	blast.position = offset
	blast.visible = delay <= 0.0
	add_child(blast)
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
		blast.visible = true
	blast.play(&"explode")
	blast.animation_finished.connect(blast.queue_free)


static func _get_frames() -> SpriteFrames:
	if _frames:
		return _frames
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	var textures := SpriteSheetUtil.slice(SHEET, FRAME_SIZE)
	_frames.add_animation(&"explode")
	_frames.set_animation_speed(&"explode", 25.0)
	_frames.set_animation_loop(&"explode", false)
	for i in textures.size():
		# First two frames are a fast flash, the rest linger as smoke.
		_frames.add_frame(&"explode", textures[i], 1.0 if i < 2 else 1.75)
	return _frames
