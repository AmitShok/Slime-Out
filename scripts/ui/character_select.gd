class_name CharacterSelect
extends Node2D
## Pick a survivor and customise their colours before a new run.
## Reached from the main menu's PLAY / NEW RUN; START RUN begins the game.

const GAME_SCENE := "res://scenes/main_game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const PREVIEW_SCALE := 6.0
const CARD_PORTRAIT := Rect2(9, 2, 14, 16)
const ROLE_COLORS := { "GUNS": Color("ffcd75"), "MELEE": Color("ef7d57"), "DRONES": Color("73eff7") }
const MUZZLE_FLARE := preload("res://assets/floor38/fx/muzzle_flare.png")
const SLASH := preload("res://assets/floor38/melee/slash.png")

@onready var _camera: Camera2D = %Camera

var _characters: Array[CharacterData] = []
var _index := 0
var _looks := {}
var _time := 0.0
var _attack_timer := 2.0

var _ui := CanvasLayer.new()
var _cards: Array[PanelContainer] = []
var _stage := Control.new()
var _rig := Node2D.new()
var _body := AnimatedSprite2D.new()
var _gun_pivot := Node2D.new()
var _gun := Sprite2D.new()
var _hand := Sprite2D.new()
var _pedestal := ColorRect.new()
var _name := Label.new()
var _role := Label.new()
var _description := RichTextLabel.new()
var _traits := VBoxContainer.new()
var _bars := {}
var _weapon_label := Label.new()
var _weapon_icon := TextureRect.new()
var _swatches := {}
var _start: Button


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_characters = Profile.all_characters()
	for character in _characters:
		_looks[character.id] = Profile.look_for(character.id)
	var last := Profile.last_character_id()
	for i in _characters.size():
		if _characters[i].id == last:
			_index = i
	_build_ui()
	add_child(OptionsMenu.new())
	add_child(Reticle.new())
	Sound.set_menu_music(true, 0.6)
	_show_character(false)
	SceneFader.open(0.45)


func _process(delta: float) -> void:
	_time += delta
	_camera.position = Vector2(40, -10) + Vector2(sin(_time * 0.11) * 30.0, cos(_time * 0.08) * 16.0)
	_stage_layout()
	# Idle breathing comes from the sprite; add a slow turn + an attack demo.
	# Every few seconds jog in place to show off the run cycle.
	var want_run := fmod(_time, 6.0) > 4.2
	var anim := &"run_side" if want_run else &"idle_side"
	if _body.sprite_frames and _body.animation != anim:
		_body.play(anim)
	_attack_timer -= delta
	if _attack_timer <= 0.0 and not want_run:
		_attack_timer = randf_range(1.6, 2.6)
		_demo_attack()
	var glow := 0.55 + 0.15 * sin(_time * 2.4)
	_pedestal.color = Color(0.45, 0.94, 0.97, glow * 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		_select((_index - 1 + _characters.size()) % _characters.size())
	elif event.is_action_pressed(&"ui_right"):
		_select((_index + 1) % _characters.size())
	elif event.is_action_pressed(&"pause"):
		_on_back()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Layout -------------------------------------------------------------------

func _build_ui() -> void:
	_ui.layer = 20
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(root)
	var veil := ColorRect.new()
	veil.color = Color(0.04, 0.04, 0.08, 0.62)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)

	var page := MarginContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [&"margin_left", &"margin_right"]:
		page.add_theme_constant_override(side, 40)
	page.add_theme_constant_override(&"margin_top", 18)
	page.add_theme_constant_override(&"margin_bottom", 18)
	root.add_child(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	page.add_child(column)

	var title := _label("CHOOSE YOUR SURVIVOR", 34, Color("ffcd75"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override(&"outline_size", 10)
	column.add_child(title)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override(&"separation", 18)
	column.add_child(card_row)
	for i in _characters.size():
		card_row.add_child(_make_card(i))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 24)
	column.add_child(body)

	# Preview stage + customise (left).
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_constant_override(&"separation", 6)
	body.add_child(left)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_stage)
	_pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_pedestal)
	_stage.add_child(_rig)
	_body.position = Vector2(0, -14)
	_rig.add_child(_body)
	_gun_pivot.position = Vector2(0, -12)
	_rig.add_child(_gun_pivot)
	_gun_pivot.add_child(_gun)
	_gun_pivot.add_child(_hand)
	_rig.scale = Vector2.ONE * PREVIEW_SCALE
	_stage.clip_contents = false

	# Info + customise panel (right).
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 8)
	panel.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 14)
	_name.add_theme_font_size_override(&"font_size", 30)
	_name.add_theme_constant_override(&"outline_size", 8)
	name_row.add_child(_name)
	_role.add_theme_font_size_override(&"font_size", 16)
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_role)
	info.add_child(name_row)
	_description.bbcode_enabled = true
	_description.fit_content = true
	_description.scroll_active = false
	_description.add_theme_font_size_override(&"normal_font_size", 16)
	info.add_child(_description)
	_traits.add_theme_constant_override(&"separation", 0)
	info.add_child(_traits)

	var bars := GridContainer.new()
	bars.columns = 2
	bars.add_theme_constant_override(&"h_separation", 12)
	bars.add_theme_constant_override(&"v_separation", 4)
	for stat in ["Health", "Speed", "Damage", "Range"]:
		bars.add_child(_label(stat, 14, Color("94b0c2")))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(200, 12)
		bar.max_value = 1.0
		bar.step = 0.0
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bars.add_child(bar)
		_bars[stat] = bar
	info.add_child(bars)

	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override(&"separation", 10)
	weapon_row.add_child(_label("Starts with", 14, Color("94b0c2")))
	weapon_row.add_child(_weapon_icon)
	_weapon_label.add_theme_font_size_override(&"font_size", 15)
	weapon_row.add_child(_weapon_label)
	info.add_child(weapon_row)

	var custom_panel := PanelContainer.new()
	left.add_child(custom_panel)
	var custom_box := VBoxContainer.new()
	custom_box.add_theme_constant_override(&"separation", 4)
	custom_panel.add_child(custom_box)
	custom_box.add_child(_label("CUSTOMIZE", 16, Color("ffcd75")))
	var custom := GridContainer.new()
	custom.columns = 2
	custom.add_theme_constant_override(&"h_separation", 18)
	custom.add_theme_constant_override(&"v_separation", 4)
	for slot in CharacterLooks.SLOTS:
		custom.add_child(_swatch_row(slot))
	custom_box.add_child(custom)
	var look_buttons := HBoxContainer.new()
	look_buttons.add_theme_constant_override(&"separation", 10)
	look_buttons.add_child(_small_button("RANDOMIZE", func() -> void:
		_looks[_current().id] = CharacterLooks.random_look()
		_refresh_look(true)))
	look_buttons.add_child(_small_button("RESET", func() -> void:
		_looks[_current().id] = CharacterLooks.default_look(_current().id)
		_refresh_look(true)))
	custom_box.add_child(look_buttons)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 16)
	column.add_child(footer)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_on_back)
	footer.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	footer.add_child(_label("<  >  switch survivor", 14, Color("94b0c2")))
	_start = Button.new()
	_start.text = "START RUN"
	_start.custom_minimum_size = Vector2(240, 0)
	_start.pressed.connect(_on_start)
	footer.add_child(_start)


func _make_card(i: int) -> PanelContainer:
	var character := _characters[i]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 74)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = Vector2(105, 37)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = CARD_PORTRAIT.size * 3.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_label(character.display_name, 20, Color("f4f4f4")))
	text.add_child(_label(character.role, 13, ROLE_COLORS.get(character.role, Color.WHITE)))
	row.add_child(text)
	card.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_select(i))
	card.mouse_entered.connect(func() -> void:
		Sound.play(&"ui_hover")
		if i != _index:
			card.create_tween().tween_property(card, "scale", Vector2.ONE * 1.04, 0.08))
	card.mouse_exited.connect(func() -> void:
		if i != _index:
			card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.08))
	_cards.append(card)
	_update_portrait(i)
	return card


func _swatch_row(slot: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var label := _label(CharacterLooks.SLOT_LABELS[slot], 14, Color("f4f4f4"))
	label.custom_minimum_size.x = 60
	row.add_child(label)
	row.add_child(_small_button("<", _cycle.bind(slot, -1)))
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(46, 26)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	row.add_child(_small_button(">", _cycle.bind(slot, 1)))
	_swatches[slot] = { "panel": swatch, "label": label }
	return row


# --- Behaviour ------------------------------------------------------------------

func _current() -> CharacterData:
	return _characters[_index]


func _select(i: int) -> void:
	if i == _index:
		return
	_index = i
	Sound.play(&"ui_click")
	_show_character(true)


func _show_character(animate: bool) -> void:
	var character := _current()
	_name.text = character.display_name.to_upper()
	_role.text = character.role
	_role.add_theme_color_override(&"font_color", ROLE_COLORS.get(character.role, Color.WHITE))
	_description.text = character.description
	for child in _traits.get_children():
		child.queue_free()
	for line in character.traits:
		_traits.add_child(_label("+  " + line, 14, Color("a7f070")))
	_bars["Health"].value = character.bar_health
	_bars["Speed"].value = character.bar_speed
	_bars["Damage"].value = character.bar_damage
	_bars["Range"].value = character.bar_range
	var weapon := character.starting_weapon
	_weapon_label.text = weapon.display_name
	PixelUI.fit_integer(_weapon_icon, weapon.icon, Vector2(64, 28))
	for i in _cards.size():
		var selected := i == _index
		var card := _cards[i]
		card.modulate = Color.WHITE if selected else Color(0.7, 0.7, 0.75)
		card.create_tween().tween_property(card, "scale", Vector2.ONE * (1.08 if selected else 1.0), 0.12).set_trans(Tween.TRANS_BACK)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.102, 0.11, 0.173, 0.9)
		style.set_border_width_all(3)
		style.border_color = Color("ffcd75") if selected else Color("566c86")
		style.set_content_margin_all(8)
		card.add_theme_stylebox_override(&"panel", style)
	_refresh_look(false)
	_equip_preview(weapon)
	if animate:
		_rig.scale = Vector2(PREVIEW_SCALE * 1.15, PREVIEW_SCALE * 0.85)
		create_tween().tween_property(_rig, "scale", Vector2.ONE * PREVIEW_SCALE, 0.25).set_trans(Tween.TRANS_BACK)


func _cycle(slot: String, step: int) -> void:
	var look: Dictionary = _looks[_current().id]
	var count: int = CharacterLooks.RAMPS[slot].size()
	look[slot] = posmod(int(look[slot]) + step, count)
	_refresh_look(true)


func _refresh_look(changed: bool) -> void:
	var character := _current()
	var look: Dictionary = _looks[character.id]
	var sheet := CharacterLooks.recolor(character.body_sheet, character.id, look)
	var anim := _body.animation if _body.sprite_frames else &"idle_side"
	_body.sprite_frames = Player._frames_for(sheet)
	_body.play(anim if _body.sprite_frames.has_animation(anim) else &"idle_side")
	_hand.texture = CharacterLooks.recolor(character.hand_texture, character.id, look)
	for slot in CharacterLooks.SLOTS:
		var style := StyleBoxFlat.new()
		style.bg_color = CharacterLooks.slot_color(slot, int(look[slot]))
		style.set_border_width_all(2)
		style.border_color = Color("1a1c2c")
		_swatches[slot].panel.add_theme_stylebox_override(&"panel", style)
	# The Knight's "hair" is his plume; his outfit is armour.
	var knight := character.id == &"knight"
	_swatches["hair"].label.text = "Plume" if knight else "Hair"
	_swatches["outfit"].label.text = "Armour" if knight else "Outfit"
	_update_portrait(_index)
	if changed:
		Profile.save(character.id, look)
		Sound.play(&"ui_hover")


func _update_portrait(i: int) -> void:
	var character := _characters[i]
	var sheet := CharacterLooks.recolor(character.body_sheet, character.id, _looks[character.id])
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = CARD_PORTRAIT
	(_cards[i].find_child("Portrait", true, false) as TextureRect).texture = atlas if i < _cards.size() else null


func _equip_preview(weapon: WeaponData) -> void:
	var texture := weapon.icon
	_gun.texture = texture
	_gun.scale = Vector2.ONE * weapon.sprite_scale
	_gun.offset = texture.get_size() * 0.5 - weapon.grip
	_gun.position = Vector2(weapon.hold_distance, weapon.mount_height)
	_gun.rotation = 0.0
	_hand.position = _gun.position
	_body.play(&"idle_side")


func _demo_attack() -> void:
	var weapon := _current().starting_weapon
	var muzzle := _gun.position + (weapon.muzzle - weapon.grip) * weapon.sprite_scale
	if weapon.is_melee():
		var swing := create_tween()
		swing.tween_property(_gun_pivot, "rotation", -1.2, 0.08)
		swing.tween_property(_gun_pivot, "rotation", 0.9, 0.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		swing.tween_property(_gun_pivot, "rotation", 0.0, 0.2)
		var slash := AnimatedSprite2D.new()
		slash.sprite_frames = SpriteSheetUtil.strip(SLASH, Vector2i(40, 40), 30.0, false)
		slash.modulate = weapon.slash_tint
		slash.offset = Vector2(14, 0)
		slash.position = _gun_pivot.position
		_rig.add_child(slash)
		slash.play()
		slash.animation_finished.connect(slash.queue_free)
		Sound.play(weapon.swing_sound)
	else:
		for shot in 3:
			get_tree().create_timer(shot * 0.16).timeout.connect(func() -> void:
				var flare := AnimatedSprite2D.new()
				flare.sprite_frames = SpriteSheetUtil.strip(MUZZLE_FLARE, Vector2i(9, 9), 30.0, false)
				flare.modulate = Color(2.2, 1.7, 1.1)
				flare.position = _gun_pivot.position + muzzle
				_rig.add_child(flare)
				flare.play()
				flare.animation_finished.connect(flare.queue_free)
				_gun.position.x = weapon.hold_distance - 1.5
				create_tween().tween_property(_gun, "position:x", weapon.hold_distance, 0.09)
				Sound.play(weapon.fire_sound))


func _stage_layout() -> void:
	var base := Vector2(_stage.size.x * 0.42, _stage.size.y - 18.0)
	_rig.position = base.round()
	_pedestal.size = Vector2(190, 26)
	_pedestal.position = base + Vector2(-95, -8)


func _on_back() -> void:
	SceneFader.change_scene(MENU_SCENE)


func _on_start() -> void:
	var character := _current()
	Profile.selected = character
	Profile.selected_look = _looks[character.id].duplicate()
	Profile.save(character.id, Profile.selected_look)
	RunSave.resume_requested = false
	RunSave.delete()
	Sound.play(&"weapon_pick")
	Sound.set_menu_music(false, 0.4)
	SceneFader.change_scene(GAME_SCENE)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _small_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 16)
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("333c57") if state != &"hover" else Color("566c86")
		style.set_border_width_all(2)
		style.border_color = Color("1a1c2c") if state != &"focus" else Color("ffcd75")
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 2
		style.content_margin_bottom = 4
		style.draw_center = state != &"focus"
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button
