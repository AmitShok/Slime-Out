class_name Reticle
extends CanvasLayer
## Live aiming reticle that replaces the OS cursor. Drives a ReticleView from
## gameplay: breathing, weapon spread, recoil kick (spring), hot colour over
## slimes, hit markers and the reload ring. All of it is configurable in
## Options > Crosshair. On paused screens it becomes a calm pointer.

@export var spread_gap := 0.35
@export var recoil_per_shot := 2.5
@export var max_recoil := 6.0

const COLOR_EMPTY := Color("b13e53")

var _view := ReticleView.new()
var _player: Player
var _last_ammo := -1
var _recoil := 0.0
var _recoil_velocity := 0.0
var _pulse_left := 0.0
var _time := 0.0
var _menu_cursor_active := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_view)
	_install_menu_cursor()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Events.enemy_hit.connect(func(_enemy: Node2D, is_crit: bool) -> void: _view.show_hit(is_crit))


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_custom_mouse_cursor(null)


func _notification(what: int) -> void:
	# Give the OS cursor back when the mouse leaves the window.
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_WM_MOUSE_ENTER and not _menu_cursor_active:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_time += real_delta
	_view.position = get_viewport().get_mouse_position().round()
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player:
			_player.weapon.ammo_changed.connect(_on_ammo_changed)

	_view.menu_mode = get_tree().paused or _player == null or _player.is_dead
	_set_menu_cursor(_view.menu_mode)
	if _view.menu_mode:
		return

	_recoil_velocity += (-180.0 * _recoil - 18.0 * _recoil_velocity) * real_delta
	_recoil = maxf(0.0, _recoil + _recoil_velocity * real_delta)

	var gap := _player.stats.get_stat(Stats.Stat.SPREAD) * spread_gap
	if Settings.value(&"crosshair_breathe"):
		gap += 1.0 if sin(_time * 3.2) > 0.6 else 0.0
	if Settings.value(&"crosshair_recoil"):
		gap += _recoil
	_view.extra_gap = gap

	var weapon := _player.weapon
	_view.reload_progress = weapon.reload_progress() if weapon.is_reloading() else -1.0
	var color: Color = Settings.value(&"crosshair_color")
	if weapon.ammo == 0 and not weapon.is_reloading():
		color = COLOR_EMPTY
	elif Settings.value(&"crosshair_react") and _over_enemy():
		color = Settings.value(&"crosshair_target_color")
	_view.color = color
	_pulse_left -= real_delta
	_view.pulse = _pulse_left > 0.0


func _over_enemy() -> bool:
	var mouse := _player.get_global_mouse_position()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		if (node as Node2D).global_position.distance_squared_to(mouse + Vector2(0, 6)) < 110.0:
			return true
	return false


func _on_ammo_changed(current: int, _maximum: int) -> void:
	if _last_ammo >= 0 and current < _last_ammo:
		_recoil = minf(max_recoil, _recoil + recoil_per_shot)
		_recoil_velocity = 0.0
		_pulse_left = 0.06
	_last_ammo = current


## Menus use the real (hardware) cursor so it always draws on top of
## popups such as dropdown lists, which open above every canvas layer.
func _set_menu_cursor(on: bool) -> void:
	if on == _menu_cursor_active:
		return
	_menu_cursor_active = on
	_view.visible = not on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_HIDDEN


func _install_menu_cursor() -> void:
	var sheet := ReticleView.CENTER_TEX.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var pointer := sheet.get_region(Rect2i(ReticleView.MENU_FRAME * 7, 0, 7, 7))
	pointer.resize(21, 21, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(pointer, Input.CURSOR_ARROW, Vector2(10, 10))
	Input.set_custom_mouse_cursor(pointer, Input.CURSOR_POINTING_HAND, Vector2(10, 10))
