class_name PauseMenu
extends CanvasLayer
## Esc pause menu. Disabled while other overlays own the pause state.

signal build_requested
signal options_requested

var enabled := true

@onready var _root: Control = $Root
@onready var _resume_button: Button = %ResumeButton
@onready var _build_button: Button = %BuildButton
@onready var _options_button: Button = %OptionsButton
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_root.hide()
	_resume_button.pressed.connect(resume)
	_build_button.pressed.connect(func() -> void: build_requested.emit())
	_options_button.pressed.connect(func() -> void: options_requested.emit())
	_restart_button.pressed.connect(_restart)
	_menu_button.pressed.connect(func() -> void: SceneFader.change_scene("res://scenes/main_menu.tscn"))
	_quit_button.pressed.connect(func() -> void:
		get_tree().call_group(&"run_saver", &"save_run")
		get_tree().quit())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _root.visible:
		resume()
	elif enabled and not get_tree().paused:
		_open()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func resume() -> void:
	_root.hide()
	get_tree().paused = false
	Sound.set_menu_music(false)


func _open() -> void:
	_root.show()
	get_tree().paused = true
	_resume_button.grab_focus()
	Sound.play(&"ui_open")
	Sound.set_menu_music(true)


func _restart() -> void:
	get_tree().paused = false
	Sound.set_menu_music(false)
	get_tree().reload_current_scene()
