extends CanvasLayer
## Drives the screen overlay shader from gameplay events.

const LOW_HEALTH := 0.3

var _flash_tween: Tween

@onready var _overlay: ColorRect = $Overlay


func _ready() -> void:
	Events.player_hurt.connect(_on_player_hurt)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player:
		player.health_changed.connect(_on_health_changed)


func _on_player_hurt() -> void:
	var fx_material := _overlay.material as ShaderMaterial
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v: float) -> void: fx_material.set_shader_parameter(&"damage", v), 1.0, 0.0, 0.4)


func _on_health_changed(current: float, maximum: float) -> void:
	var low := 1.0 if current > 0.0 and current < maximum * LOW_HEALTH else 0.0
	(_overlay.material as ShaderMaterial).set_shader_parameter(&"low_health", low)
