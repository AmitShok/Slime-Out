class_name Shockwave
extends Node2D
## Expanding ring that damages and shoves every enemy inside `radius`.
## Used by Thorns, Shockwave Dash and Second Chance.

const SHEET := preload("res://assets/floor38/fx/shockwave.png")
const FRAME := Vector2i(40, 40)
## Radius the ring art reaches at scale 1.
const ART_RADIUS := 19.0


static func spawn(at: Vector2, radius: float, damage: float, knockback: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var parent := tree.get_first_node_in_group(&"fx_layer")
	if parent == null:
		parent = tree.current_scene
	var wave := Shockwave.new()
	parent.add_child(wave)
	wave.global_position = at
	wave._fire(radius, damage, knockback)


func _fire(radius: float, damage: float, knockback: float) -> void:
	var ring := AnimatedSprite2D.new()
	ring.sprite_frames = SpriteSheetUtil.strip(SHEET, FRAME, 20.0, false)
	# Whole-number scale keeps the ring's pixels square.
	ring.scale = Vector2.ONE * maxf(1.0, roundf(radius / ART_RADIUS))
	add_child(ring)
	ring.play()
	ring.animation_finished.connect(queue_free)
	if damage > 0.0 or knockback > 0.0:
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var enemy := node as Enemy
			if enemy == null or not enemy.can_be_hit():
				continue
			var offset := enemy.global_position - global_position
			if offset.length() <= radius + enemy.hit_radius():
				enemy.take_damage(damage, offset.normalized() * knockback)
	Events.screen_shake.emit(0.15)
	Sound.play(&"shockwave", global_position)
