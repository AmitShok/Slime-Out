class_name OptionsMenu
extends CanvasLayer
## Options screen: Audio, Video and Crosshair tabs. Every control writes
## straight to the Settings autoload (applied and saved immediately). The
## crosshair tab has live previews that animate recoil and hit markers.

const LABEL_COLOR := Color("94b0c2")
const SWATCHES := [
	Color("f4f4f4"), Color("73eff7"), Color("a7f070"), Color("ffcd75"),
	Color("ef7d57"), Color("ff77a8"), Color("c06ce8"), Color("41a6f6"),
]
const STYLE_LABELS := { "brackets": "Brackets", "round": "Round", "cross": "Cross", "chevrons": "Chevrons", "dot": "Dot" }
const CENTER_LABELS := { "none": "None", "dot": "Dot", "plus": "Plus", "ring": "Ring" }

var _was_paused := false
var _root := Control.new()
var _tabs := TabContainer.new()
var _refreshers: Array[Callable] = []
var _previews: Array[ReticleView] = []
var _preview_time := 0.0


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh_all()
	_root.show()
	Sound.play(&"ui_open")


func close() -> void:
	_root.hide()
	get_tree().paused = _was_paused
	Sound.play(&"ui_back")


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"pause"):
		close()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	# Preview animation: a burst of three shots, a hit marker, then rest.
	_preview_time += delta
	var cycle := fmod(_preview_time, 1.6)
	for i in _previews.size():
		var view := _previews[i]
		var recoil := 0.0
		if Settings.value(&"crosshair_recoil"):
			for shot in 3:
				var t := cycle - shot * 0.12
				if t >= 0.0:
					recoil = maxf(recoil, 2.5 * exp(-t * 10.0) * (1.0 + shot * 0.3))
		var breathe := 1.0 if bool(Settings.value(&"crosshair_breathe")) and sin(_preview_time * 3.2) > 0.6 else 0.0
		view.extra_gap = roundf(recoil + breathe)
		view.pulse = cycle < 0.3 and fmod(cycle, 0.12) < 0.06
		var on_target: bool = i == 1 and bool(Settings.value(&"crosshair_react"))
		view.color = Settings.value(&"crosshair_target_color") if on_target else Settings.value(&"crosshair_color")
		if cycle > 0.05 and cycle < 0.06 + delta:
			view.show_hit(i == 1)


# --- Layout -------------------------------------------------------------------

func _build() -> void:
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.051, 0.055, 0.086, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 560)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 10)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := _label("OPTIONS", 34, Color("ffcd75"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_constant_override(&"outline_size", 10)
	header.add_child(title)
	var hint := _label("[Esc] back", 14, LABEL_COLOR)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(hint)

	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override(&"font_size", 18)
	vbox.add_child(_tabs)
	_build_audio()
	_build_video()
	_build_crosshair()

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override(&"separation", 14)
	vbox.add_child(footer)
	var reset := Button.new()
	reset.text = "Reset tab"
	reset.pressed.connect(func() -> void:
		Settings.reset_section(["audio", "video", "crosshair"][_tabs.current_tab])
		_refresh_all())
	footer.add_child(reset)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	footer.add_child(back)


func _page(tab_name: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 28)
	grid.add_theme_constant_override(&"v_separation", 12)
	margin.add_child(grid)
	return grid


func _build_audio() -> void:
	var grid := _page("Audio")
	_slider(grid, "Master volume", &"master_volume", 0.0, 1.0, 0.05, _percent)
	_slider(grid, "Music", &"music_volume", 0.0, 1.0, 0.05, _percent)
	_slider(grid, "Sound effects", &"sfx_volume", 0.0, 1.0, 0.05, _percent)
	_slider(grid, "Interface", &"ui_volume", 0.0, 1.0, 0.05, _percent)
	_slider(grid, "Ambience", &"ambience_volume", 0.0, 1.0, 0.05, _percent)
	_toggle(grid, "Mute all", &"muted")


func _build_video() -> void:
	var grid := _page("Video")
	_toggle(grid, "Fullscreen", &"fullscreen")
	_toggle(grid, "V-Sync", &"vsync")
	_toggle(grid, "CRT effect", &"crt_enabled")
	_slider(grid, "CRT strength", &"crt_strength", 0.2, 1.0, 0.05, _percent)
	_slider(grid, "Screen shake", &"shake_strength", 0.0, 1.5, 0.05, _percent)
	_toggle(grid, "Hit-stop (impact freeze)", &"hit_stop")
	_toggle(grid, "Damage numbers", &"damage_numbers")


func _build_crosshair() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Crosshair"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 24)
	scroll.add_child(row)

	var margin := MarginContainer.new()
	for side in [&"margin_left", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	row.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 10)
	margin.add_child(grid)
	_choice(grid, "Style", &"crosshair_style", STYLE_LABELS)
	_slider(grid, "Size", &"crosshair_size", 1.0, 6.0, 1.0, func(v: float) -> String: return "x%d" % roundi(v))
	_color(grid, "Colour", &"crosshair_color")
	_choice(grid, "Centre", &"crosshair_center", CENTER_LABELS)
	_slider(grid, "Opacity", &"crosshair_opacity", 0.3, 1.0, 0.05, _percent)
	_toggle(grid, "Change colour on target", &"crosshair_react")
	_color(grid, "Target colour", &"crosshair_target_color")
	_toggle(grid, "Spin", &"crosshair_spin")
	_slider(grid, "Spin speed", &"crosshair_spin_speed", 30.0, 360.0, 10.0, func(v: float) -> String: return "%d deg/s" % roundi(v))
	_toggle(grid, "Breathing", &"crosshair_breathe")
	_toggle(grid, "Recoil kick", &"crosshair_recoil")
	_toggle(grid, "Hit marker", &"crosshair_hit_marker")

	var previews := VBoxContainer.new()
	previews.add_theme_constant_override(&"separation", 12)
	previews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(previews)
	previews.add_child(_label("PREVIEW", 15, Color("ffcd75")))
	for caption in ["Aiming", "On target"]:
		previews.add_child(_preview_box(caption))


func _preview_box(caption: String) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(230, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("38734f")  # arena grass, so colours read in context
	style.border_color = Color("1a1c2c")
	style.set_border_width_all(3)
	box.add_theme_stylebox_override(&"panel", style)
	var holder := Control.new()
	holder.clip_contents = true
	box.add_child(holder)
	var view := ReticleView.new()
	holder.add_child(view)
	holder.resized.connect(func() -> void: view.position = (holder.size * 0.5).round())
	_previews.append(view)
	var label := _label(caption, 13, Color("f4f4f4"))
	label.position = Vector2(8, 4)
	holder.add_child(label)
	return box


# --- Controls -----------------------------------------------------------------

func _row_label(grid: GridContainer, text: String) -> void:
	var label := _label(text, 17, Color("f4f4f4"))
	label.custom_minimum_size.x = 210
	grid.add_child(label)


func _slider(grid: GridContainer, text: String, key: StringName, low: float, high: float, step: float, format: Callable) -> void:
	_row_label(grid, text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(220, 26)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var readout := _label("", 16, LABEL_COLOR)
	readout.custom_minimum_size.x = 84
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = format.call(v)
		var stored = Settings.value(key)
		Settings.set_value(key, roundi(v) if stored is int else v))
	row.add_child(slider)
	row.add_child(readout)
	grid.add_child(row)
	_refreshers.append(func() -> void:
		slider.set_value_no_signal(float(Settings.value(key)))
		readout.text = format.call(slider.value))


func _toggle(grid: GridContainer, text: String, key: StringName) -> void:
	_row_label(grid, text)
	var check := CheckButton.new()
	check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	grid.add_child(check)
	_refreshers.append(func() -> void: check.set_pressed_no_signal(bool(Settings.value(key))))


func _choice(grid: GridContainer, text: String, key: StringName, labels: Dictionary) -> void:
	_row_label(grid, text)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 180
	option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	option.add_theme_font_size_override(&"font_size", 17)
	var ids: Array = labels.keys()
	for id in ids:
		option.add_item(labels[id])
	option.item_selected.connect(func(index: int) -> void: Settings.set_value(key, ids[index]))
	grid.add_child(option)
	_refreshers.append(func() -> void: option.select(maxi(0, ids.find(Settings.value(key)))))


func _color(grid: GridContainer, text: String, key: StringName) -> void:
	_row_label(grid, text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var swatches: Array[Button] = []
	for swatch_color in SWATCHES:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.tooltip_text = "#" + swatch_color.to_html(false)
		for state in [&"normal", &"hover", &"pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = swatch_color
			style.set_border_width_all(2)
			style.border_color = Color("1a1c2c") if state == &"normal" else Color("f4f4f4")
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(func() -> void: Settings.set_value(key, swatch_color))
		row.add_child(swatch)
		swatches.append(swatch)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(40, 24)
	picker.edit_alpha = false
	picker.tooltip_text = "Custom colour"
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.set_border_width_all(2)
		frame.border_color = Color("f4f4f4") if state == &"hover" else Color("566c86")
		frame.set_content_margin_all(3)
		picker.add_theme_stylebox_override(state, frame)
	picker.color_changed.connect(func(c: Color) -> void: Settings.set_value(key, c))
	row.add_child(picker)
	grid.add_child(row)
	_refreshers.append(func() -> void:
		var current: Color = Settings.value(key)
		picker.color = current
		for i in swatches.size():
			swatches[i].modulate = Color.WHITE if SWATCHES[i].is_equal_approx(current) else Color(1, 1, 1, 0.55))
	Settings.changed.connect(func(changed_key: StringName) -> void:
		if changed_key == key:
			_refresh_all())


func _refresh_all() -> void:
	for refresh in _refreshers:
		refresh.call()


func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
