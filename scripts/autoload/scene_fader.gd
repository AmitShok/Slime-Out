extends CanvasLayer
## Scene transitions (autoload "SceneFader"): a dithered pixel iris closes,
## the scene swaps, and it opens again on the new scene.

const SHADER := preload("res://shaders/iris_wipe.gdshader")

var busy := false
var _rect := ColorRect.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material.shader = SHADER
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_set_progress(0.0)


func change_scene(path: String, duration := 0.45) -> void:
	if busy:
		return
	busy = true
	# Anything holding run state (the game) saves before the scene goes away.
	get_tree().call_group(&"run_saver", &"save_run")
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var close := create_tween()
	close.tween_method(_set_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await close.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	open(duration)


## Plays just the opening half (e.g. on boot).
func open(duration := 0.45) -> void:
	_set_progress(1.0)
	var reveal := create_tween()
	reveal.tween_method(_set_progress, 1.0, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


func _set_progress(value: float) -> void:
	_material.set_shader_parameter(&"progress", value)
	_rect.visible = value > 0.0
