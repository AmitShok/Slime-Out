class_name Debris
extends Sprite2D
## A small bit of stuff (shell casing, goo droplet) tossed with a fake height
## arc: it bounces once and then rests on the ground.

const GRAVITY := 420.0
const BOUNCE := 0.35
const FRICTION := 6.0

var _velocity := Vector2.ZERO
var _ground := Vector2.ZERO
var _height := 0.0
var _vertical := 0.0
var _spin := 0.0
var _bounces := 0
var _persist := true


static func launch(texture: Texture2D, at: Vector2, velocity: Vector2, upward: float, tint: Color, persist: bool) -> Debris:
	var debris := Debris.new()
	debris.texture = texture
	debris.modulate = tint
	debris._velocity = velocity
	debris._vertical = upward
	debris._persist = persist
	debris._spin = randf_range(-14.0, 14.0)
	Fx.layer(&"decal_layer").add_child(debris)
	debris.global_position = at
	debris._ground = debris.position
	return debris


func _process(delta: float) -> void:
	_vertical -= GRAVITY * delta
	_height += _vertical * delta
	if _height <= 0.0:
		_height = 0.0
		_bounces += 1
		if _bounces == 1 and _persist:
			Sound.play(&"casing", global_position)
		_vertical = -_vertical * BOUNCE
		if _bounces >= 2:
			_land()
			return
	_ground += _velocity * delta
	_velocity = _velocity.move_toward(Vector2.ZERO, FRICTION * delta * _velocity.length())
	rotation += _spin * delta
	position = _ground + Vector2(0.0, -_height)


func _land() -> void:
	set_process(false)
	position = _ground
	if not _persist:
		# Droplets soak into the ground.
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.5).set_delay(4.0)
		tween.tween_callback(queue_free)
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 1.0).set_delay(12.0)
	fade.tween_callback(queue_free)
