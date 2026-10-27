class_name Pickup
extends Node2D
## XP gem / heart / magnet lying on the ground. Flies to the player once
## inside their pickup radius (or when magnetised), then applies itself.

enum Kind { GEM, HEART, MAGNET }

const GEM_SMALL := preload("res://assets/floor38/pickups/gem_small.png")
const GEM_MEDIUM := preload("res://assets/floor38/pickups/gem_medium.png")
const GEM_LARGE := preload("res://assets/floor38/pickups/gem_large.png")
const HEART := preload("res://assets/floor38/pickups/heart_pickup.png")
const MAGNET := preload("res://assets/floor38/pickups/magnet_pickup.png")

const COLLECT_DISTANCE := 7.0
const ACCELERATION := 900.0
const HEART_HEAL := 15.0
const HEART_LIFETIME := 15.0
## Above this many gems, new XP merges into an existing gem instead.
const MAX_GEMS := 250

var kind := Kind.GEM
var value := 1.0

var _magnetised := false
var _speed := 0.0
var _age := 0.0
var _player: Player
var _sprite: AnimatedSprite2D


static func drop_gem(at: Vector2, xp: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gems := tree.get_nodes_in_group(&"gems")
	if gems.size() >= MAX_GEMS:
		var target := gems[randi() % gems.size()] as Pickup
		target.value += xp
		target._refresh_gem_tier()
		return
	_spawn(Kind.GEM, at, xp)


static func drop(kind_to_drop: Kind, at: Vector2) -> void:
	_spawn(kind_to_drop, at, 0.0)


static func _spawn(kind_to_drop: Kind, at: Vector2, amount: float) -> void:
	var pickup := Pickup.new()
	pickup.kind = kind_to_drop
	pickup.value = amount
	Fx.layer(&"pickup_layer").add_child(pickup)
	pickup.global_position = at + Vector2(randf_range(-3, 3), randf_range(-3, 3))


## Pull every gem on the map to the player (magnet pickup / round end).
static func magnetise_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for node in tree.get_nodes_in_group(&"pickups"):
		var pickup := node as Pickup
		if pickup.kind == Kind.GEM:
			pickup._magnetised = true


func _ready() -> void:
	add_to_group(&"pickups")
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)
	match kind:
		Kind.GEM:
			add_to_group(&"gems")
			_refresh_gem_tier()
		Kind.HEART:
			_sprite.sprite_frames = SpriteSheetUtil.strip(HEART, Vector2i(9, 8), 1.0, false)
		Kind.MAGNET:
			_sprite.sprite_frames = SpriteSheetUtil.strip(MAGNET, Vector2i(9, 8), 1.0, false)
	_sprite.play()
	# Pop out of the corpse.
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_gem_tier() -> void:
	var texture := GEM_SMALL
	if value >= 25.0:
		texture = GEM_LARGE
	elif value >= 5.0:
		texture = GEM_MEDIUM
	_sprite.sprite_frames = SpriteSheetUtil.strip(texture, Vector2i(7, 7), 4.0, true)
	_sprite.play()
	# Gems glow a touch through the bloom.
	_sprite.modulate = Color(1.35, 1.35, 1.35)


func _process(delta: float) -> void:
	_age += delta
	if _player == null or _player.is_dead:
		return
	if kind == Kind.HEART and _age > HEART_LIFETIME:
		queue_free()
		return
	var to_player := _player.global_position + Vector2(0, -6) - global_position
	var distance := to_player.length()
	if not _magnetised and distance < _player.stats.get_stat(Stats.Stat.PICKUP_RADIUS):
		_magnetised = true
	if _magnetised:
		_speed += ACCELERATION * delta
		global_position += to_player.normalized() * minf(_speed * delta, distance)
		if distance <= COLLECT_DISTANCE:
			_collect()
	else:
		# Idle bob so pickups catch the eye.
		_sprite.position.y = sin(_age * 4.0 + position.x) * 1.0


func _collect() -> void:
	match kind:
		Kind.GEM:
			_player.stats.add_xp(value)
			Sound.play(&"gem")
		Kind.HEART:
			_player.heal(HEART_HEAL)
			Sound.play(&"heart")
		Kind.MAGNET:
			magnetise_all()
			Sound.play(&"magnet")
			Events.screen_shake.emit(0.1)
	queue_free()
