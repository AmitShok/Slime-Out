class_name GameOverScreen
extends CanvasLayer
## Shown when the player dies. Restart reloads the arena.

@onready var _root: Control = $Root
@onready var _summary: Label = %Summary
@onready var _best: Label = %Best
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_root.hide()
	_restart_button.pressed.connect(restart)
	_menu_button.pressed.connect(func() -> void: SceneFader.change_scene("res://scenes/main_menu.tscn"))


func open(round_reached: int, kills: int, best_round: int) -> void:
	_summary.text = "You fell on round %d  -  %d slimes defeated" % [round_reached, kills]
	_best.text = "New best!" if round_reached >= best_round else "Best: round %d" % best_round
	_root.modulate.a = 0.0
	_root.show()
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.4)
	_restart_button.grab_focus()


func restart() -> void:
	get_tree().paused = false
	Sound.set_menu_music(false)
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed(&"reload"):
		get_viewport().set_input_as_handled()
		restart()
