extends CanvasLayer
## Full-frame CRT pass. Sits above every game/UI layer (the reticle draws
## on top so aiming stays exact) and follows the player's video settings.

@onready var _screen: ColorRect = $Screen


func _ready() -> void:
	Settings.changed.connect(func(_key: StringName) -> void: _apply())
	_apply()


func _apply() -> void:
	visible = Settings.value(&"crt_enabled")
	(_screen.material as ShaderMaterial).set_shader_parameter(&"strength", Settings.value(&"crt_strength"))
