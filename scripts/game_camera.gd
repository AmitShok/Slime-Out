extends Camera2D
## Player camera with trauma-based screen shake and a springy recoil kick.
##
## Shake follows smooth simplex noise instead of fresh random offsets each
## frame (which reads as harsh jitter), scales with trauma^2 so small hits
## stay subtle, and is multiplied by the player's shake setting. The kick is
## a slightly under-damped spring, so it eases back with a tiny overshoot.

@export var max_offset := 3.0
@export var max_roll := 0.012
@export var trauma_decay := 1.6
## How fast the noise is sampled - higher feels more violent.
@export var shake_frequency := 22.0
@export var kick_stiffness := 260.0
@export var kick_damping := 22.0
@export var kick_scale := 0.55
@export var max_kick := 4.0

var _trauma := 0.0
var _kick := Vector2.ZERO
var _kick_velocity := Vector2.ZERO
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	Events.screen_shake.connect(add_trauma)
	Events.camera_kick.connect(add_kick)


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func add_kick(amount: Vector2) -> void:
	_kick = (_kick + amount * kick_scale * float(Settings.value(&"shake_strength"))).limit_length(max_kick)


func _process(delta: float) -> void:
	_time += delta
	_trauma = maxf(0.0, _trauma - trauma_decay * delta)

	var spring := -kick_stiffness * _kick - kick_damping * _kick_velocity
	_kick_velocity += spring * delta
	_kick += _kick_velocity * delta

	var shake := _trauma * _trauma * float(Settings.value(&"shake_strength"))
	var t := _time * shake_frequency
	var wobble := Vector2(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(0.0, t + 100.0))
	offset = _kick + wobble * max_offset * shake
	rotation = _noise.get_noise_2d(t + 200.0, t) * max_roll * shake
