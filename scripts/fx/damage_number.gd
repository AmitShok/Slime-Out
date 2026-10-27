class_name DamageNumber
extends Label
## Floating damage text. Rendered at 4x font size and scaled down so it
## stays crisp under the zoomed-in camera.

const RENDER_SCALE := 0.25
const BOX := Vector2(120.0, 40.0)

const MAX_ACTIVE := 45

static var _active := 0
static var _normal_settings: LabelSettings
static var _crit_settings: LabelSettings


static func spawn(at: Vector2, amount: float, is_crit: bool) -> void:
	if not Settings.value(&"damage_numbers"):
		return
	# In a dense horde, drop ordinary numbers first; crits always show.
	if _active >= MAX_ACTIVE and not is_crit:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var parent := tree.get_first_node_in_group(&"fx_layer")
	if parent == null:
		parent = tree.current_scene
	var number := DamageNumber.new()
	number.text = str(roundi(amount)) + ("!" if is_crit else "")
	number.label_settings = _settings(is_crit)
	parent.add_child(number)
	number.global_position = at + Vector2(randf_range(-3.0, 3.0), 0.0) - BOX * RENDER_SCALE * 0.5
	number._animate(is_crit)


## Floating word (e.g. "DODGE!") using the crit styling in a custom colour.
static func spawn_text(at: Vector2, text: String, color: Color) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var parent := tree.get_first_node_in_group(&"fx_layer")
	if parent == null:
		parent = tree.current_scene
	var number := DamageNumber.new()
	number.text = text
	var settings := _settings(true).duplicate() as LabelSettings
	settings.font_color = color
	settings.font_size = 30
	number.label_settings = settings
	parent.add_child(number)
	number.global_position = at - BOX * RENDER_SCALE * 0.5
	number._animate(true)


func _init() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size = BOX
	pivot_offset = BOX * 0.5
	scale = Vector2.ONE * RENDER_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_active += 1
	tree_exiting.connect(func() -> void: _active -= 1)


func _animate(is_crit: bool) -> void:
	var pop := 1.5 if is_crit else 1.2
	scale = Vector2.ONE * RENDER_SCALE * pop
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE * RENDER_SCALE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 10.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.4)
	tween.chain().tween_callback(queue_free)


static func _settings(is_crit: bool) -> LabelSettings:
	if _normal_settings == null:
		_normal_settings = LabelSettings.new()
		_normal_settings.font_size = 26
		_normal_settings.font_color = Color("f4f4f4")
		_normal_settings.outline_size = 8
		_normal_settings.outline_color = Color("1a1c2c")
		_crit_settings = _normal_settings.duplicate()
		_crit_settings.font_size = 34
		_crit_settings.font_color = Color("ffcd75")
	return _crit_settings if is_crit else _normal_settings
