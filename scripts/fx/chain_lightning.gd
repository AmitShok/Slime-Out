class_name ChainLightning
extends Node2D
## Arcs from one enemy to the next nearest ones, drawing a trail of
## hand-drawn sparks along each hop.

const SPARKS := preload("res://assets/floor38/fx/spark.png")
const SPARK_FRAME := Vector2i(7, 7)
const HOP_RANGE := 90.0
const SPARK_SPACING := 5.0
const LIFETIME := 0.22


static func strike(origin: Enemy, damage: float, hops: int, exclude: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var parent := tree.get_first_node_in_group(&"fx_layer")
	if parent == null:
		parent = tree.current_scene
	var bolt := ChainLightning.new()
	parent.add_child(bolt)
	var hit := exclude.duplicate()
	hit[origin] = true
	var from := origin.global_position + Vector2(0, -4)
	for i in hops:
		var target := _nearest(tree, from, hit)
		if target == null:
			break
		hit[target] = true
		var to := target.global_position + Vector2(0, -4)
		bolt._draw_arc(from, to)
		target.take_damage(damage, Vector2.ZERO)
		from = to
	tree.create_timer(LIFETIME, false).timeout.connect(bolt.queue_free)


static func _nearest(tree: SceneTree, from: Vector2, hit: Dictionary) -> Enemy:
	var best: Enemy = null
	var best_distance := HOP_RANGE
	for node in tree.get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or hit.has(enemy) or not enemy.can_be_hit():
			continue
		var distance := from.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _draw_arc(from: Vector2, to: Vector2) -> void:
	var textures := SpriteSheetUtil.slice(SPARKS, SPARK_FRAME)
	var steps := maxi(1, int(from.distance_to(to) / SPARK_SPACING))
	var normal := (to - from).orthogonal().normalized()
	for i in steps + 1:
		var spark := Sprite2D.new()
		spark.texture = textures[randi() % textures.size()]
		# Jitter sideways so the line reads as electricity, not a rope.
		var jitter := normal * randf_range(-2.5, 2.5) if i > 0 and i < steps else Vector2.ZERO
		add_child(spark)
		spark.global_position = from.lerp(to, float(i) / steps) + jitter
	Events.screen_shake.emit(0.05)
	Sound.play(&"chain", to)
