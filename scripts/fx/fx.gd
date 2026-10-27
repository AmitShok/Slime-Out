class_name Fx
extends RefCounted
## Shared spawners for short-lived and persistent visual effects.
## Persistent debris (casings, goo) is capped so long runs stay fast.

const MUZZLE_FLARE := preload("res://assets/floor38/fx/muzzle_flare.png")
const SMOKE := preload("res://assets/floor38/fx/smoke_puff.png")
const GOO := preload("res://assets/floor38/fx/goo.png")
const DROPLET := preload("res://assets/floor38/fx/droplet.png")
const CASING := preload("res://assets/floor38/fx/casing.png")
const SKY_BOLT := preload("res://assets/floor38/fx/sky_bolt.png")

## Values above 1.0 bloom through the WorldEnvironment glow.
const GLOW_WARM := Color(2.2, 1.7, 1.1)
const GLOW_COOL := Color(1.4, 2.2, 2.6)

const MAX_DECALS := 160
const MAX_CASINGS := 140
const DECAL_LIFETIME := 30.0

static var _decals: Array[Node2D] = []
static var _casings: Array[Node2D] = []


static func layer(group: StringName) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var node := tree.get_first_node_in_group(group)
	return node if node else tree.current_scene


## Plays a horizontal strip once at `at`, then frees itself.
static func one_shot(texture: Texture2D, frame_size: Vector2i, fps: float, at: Vector2, tint := Color.WHITE, angle := 0.0, group: StringName = &"fx_layer") -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteSheetUtil.strip(texture, frame_size, fps, false)
	sprite.modulate = tint
	sprite.rotation = angle
	layer(group).add_child(sprite)
	sprite.global_position = at
	sprite.play()
	sprite.animation_finished.connect(sprite.queue_free)
	return sprite


static func muzzle_flare(at: Vector2, angle: float) -> void:
	one_shot(MUZZLE_FLARE, Vector2i(9, 9), 30.0, at, GLOW_WARM, angle)


static func smoke(at: Vector2) -> void:
	var puff := one_shot(SMOKE, Vector2i(7, 7), 12.0, at, Color(1, 1, 1, 0.8))
	puff.rotation = randf() * TAU
	puff.create_tween().tween_property(puff, "position:y", puff.position.y - 4.0, 0.25)


static func sky_bolt(at: Vector2) -> void:
	# Bolt art is 40px tall; anchor its bottom on the target.
	var bolt := one_shot(SKY_BOLT, Vector2i(11, 40), 18.0, at + Vector2(0, -20), GLOW_COOL)
	bolt.z_index = 4


## Ground decal that stays for a while (slime goo, scorch...).
static func decal(texture: Texture2D, frame_size: Vector2i, at: Vector2, tint: Color) -> void:
	var frames := SpriteSheetUtil.slice(texture, frame_size)
	var sprite := Sprite2D.new()
	sprite.texture = frames[randi() % frames.size()]
	sprite.modulate = tint
	sprite.flip_h = randf() < 0.5
	_track(_decals, sprite, MAX_DECALS)
	layer(&"decal_layer").add_child(sprite)
	sprite.global_position = at
	var tween := sprite.create_tween()
	tween.tween_interval(DECAL_LIFETIME)
	tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
	tween.tween_callback(sprite.queue_free)


static func goo_splat(at: Vector2, tint: Color, droplets := 5) -> void:
	decal(GOO, Vector2i(16, 9), at, Color(tint, 0.85))
	for i in droplets:
		var velocity := Vector2.from_angle(randf() * TAU) * randf_range(40.0, 110.0)
		Debris.launch(DROPLET, at, velocity, randf_range(60.0, 120.0), tint, false)


static func casing(at: Vector2, aim_angle: float, facing_left: bool) -> void:
	# Ejected sideways from the gun, slightly backwards, Vlambeer-style.
	var side := -1.0 if facing_left else 1.0
	var direction := Vector2.from_angle(aim_angle - PI * 0.5 * side + randf_range(-0.3, 0.3) + PI * 0.15 * side)
	var debris := Debris.launch(CASING, at, direction * randf_range(30.0, 60.0), randf_range(50.0, 80.0), Color.WHITE, true)
	_track(_casings, debris, MAX_CASINGS)


static func _track(list: Array[Node2D], node: Node2D, limit: int) -> void:
	for i in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]):
			list.remove_at(i)
	list.append(node)
	while list.size() > limit:
		var oldest: Node2D = list.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
