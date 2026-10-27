class_name MainMenu
extends Node2D
## Title screen in "attract mode": the real forest arena runs behind the
## menu, the hero holds the clearing and picks off slimes that hop in from
## the woods, while the dripping SLIME-OUT logo bobs on top.

const GAME_SCENE := "res://scenes/main_game.tscn"
const SAVE_PATH := "user://save.cfg"

const LOGO := preload("res://assets/floor38/ui/logo_letters.png")
const LETTER_SIZE := Vector2i(12, 14)
## Visible width of each letter incl. outline (from build_logo.lua).
const LETTER_WIDTHS := [10, 10, 6, 10, 10, 8, 10, 10, 10]
## Drip tips per letter: [column, length] (from build_logo.lua).
const LETTER_DRIPS := [[[1, 3]], [[4, 4]], [[1, 2]], [[0, 2], [6, 4]], [[3, 3]], [[2, 2]], [[5, 4]], [[1, 2], [5, 3]], [[3, 4]]]
const LOGO_SCALE := 6
const BRACKET := preload("res://assets/floor38/ui/reticle_bracket.png")

const HERO_SHEET := preload("res://assets/floor38/player/hero.png")
const HAND := preload("res://assets/floor38/player/hand.png")
const GUN := preload("res://assets/Guns_V1.01 - Commission - Copy/01 - Individual sprites/Guns/Glock - P80 [64x48].png")
const GUN_GRIP := Vector2(21, 20)
const GUN_MUZZLE := Vector2(48, 11)
const GUN_SCALE := 0.25
const HOLD := 4.0

const SLIME_TYPES := [
	"res://resources/enemies/slime.tres",
	"res://resources/enemies/slime.tres",
	"res://resources/enemies/slime_swift.tres",
	"res://resources/enemies/slime_spitter.tres",
	"res://resources/enemies/slime_splitter.tres",
	"res://resources/enemies/slime_charger.tres",
	"res://resources/enemies/slime_brute.tres",
]
const HERO_POS := Vector2(-24, 8)
const MAX_SLIMES := 7
const SHOOT_RANGE := 105.0

@onready var _world: Node2D = %World
@onready var _camera: Camera2D = %Camera

var _time := 0.0
var _hero := Node2D.new()
var _hero_sprite := AnimatedSprite2D.new()
var _gun_pivot := Node2D.new()
var _gun := Sprite2D.new()
var _slimes: Array[Dictionary] = []
var _slime_data: Array[EnemyData] = []
var _spawn_timer := 0.6
var _shot_timer := 1.0
var _target: Dictionary = {}

var _ui := CanvasLayer.new()
var _logo := Control.new()
var _letters: Array[TextureRect] = []
var _shadows: Array[TextureRect] = []
var _buttons: Array[Button] = []
var _menu_box := VBoxContainer.new()
var _selector: Array[TextureRect] = []
var _selected: Button
var _drip_timer := 0.8
var _squash_timer := 1.5
var _options: OptionsMenu
var _menu_top := -40.0


func _ready() -> void:
	# Never inherit a paused tree / hit-stop from the scene we came from.
	get_tree().paused = false
	Engine.time_scale = 1.0
	for path in SLIME_TYPES:
		_slime_data.append(load(path))
	_build_hero()
	_build_ui()
	_options = OptionsMenu.new()
	add_child(_options)
	var reticle := Reticle.new()
	add_child(reticle)
	Sound.set_menu_music(true, 1.0)
	SceneFader.open(0.6)
	_intro()


# --- Attract mode ---------------------------------------------------------------

func _build_hero() -> void:
	_hero.position = HERO_POS
	_world.add_child(_hero)
	_hero_sprite.sprite_frames = Player._frames_for(HERO_SHEET)
	_hero_sprite.position = Vector2(0, -14)
	_hero_sprite.play(&"idle_side")
	_hero.add_child(_hero_sprite)
	_gun_pivot.position = Vector2(0, -10)
	_hero.add_child(_gun_pivot)
	_gun.texture = GUN
	_gun.scale = Vector2.ONE * GUN_SCALE
	_gun.offset = GUN.get_size() * 0.5 - GUN_GRIP
	_gun.position = Vector2(HOLD, 0)
	_gun_pivot.add_child(_gun)
	var hand := Sprite2D.new()
	hand.texture = HAND
	hand.position = Vector2(HOLD, 0)
	_gun_pivot.add_child(hand)


func _process(delta: float) -> void:
	_time += delta
	# Slow drifting camera so the scene feels alive behind the menu.
	_camera.position = HERO_POS + Vector2(62, -22) + Vector2(sin(_time * 0.13) * 34.0, cos(_time * 0.09) * 18.0)
	_update_slimes(delta)
	_update_hero(delta)
	_animate_logo(delta)
	_update_selector(delta)


func _update_slimes(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _slimes.size() < MAX_SLIMES:
		_spawn_timer = randf_range(0.7, 1.5)
		_spawn_slime()
	for slime in _slimes:
		if slime.dead:
			continue
		var node: Node2D = slime.node
		var sprite: AnimatedSprite2D = slime.sprite
		if sprite.animation == &"spawn" and sprite.is_playing():
			continue
		var to_hero := _hero.position - node.position
		if to_hero.length() < 34.0:
			sprite.play(&"attack_side")
			continue
		node.position += to_hero.normalized() * slime.speed * delta
		var facing := &"side"
		if absf(to_hero.y) > absf(to_hero.x):
			facing = &"down" if to_hero.y > 0.0 else &"up"
		sprite.flip_h = to_hero.x < 0.0
		var anim := StringName("move_" + facing)
		if sprite.animation != anim:
			sprite.play(anim)


func _spawn_slime() -> void:
	var data: EnemyData = _slime_data.pick_random()
	var node := Node2D.new()
	# Enter from just outside the visible edges (never from behind the logo).
	var view := Vector2(get_viewport_rect().size) / _camera.zoom * 0.5
	var centre := _camera.position
	var roll := randf()
	if roll < 0.6:
		node.position = centre + Vector2(view.x + 14.0, randf_range(-view.y * 0.2, view.y * 0.8))
	elif roll < 0.85:
		node.position = centre + Vector2(randf_range(-view.x * 0.6, view.x * 0.6), view.y + 18.0)
	else:
		node.position = centre + Vector2(-view.x - 14.0, randf_range(0.0, view.y * 0.8))
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Enemy._frames_for(data.sheet)
	sprite.scale = Vector2.ONE * data.sprite_scale
	sprite.position = Vector2(0, -Enemy.FEET_OFFSET * data.sprite_scale)
	sprite.play(&"spawn")
	node.add_child(sprite)
	_world.add_child(node)
	_slimes.append({
		"node": node, "sprite": sprite, "data": data, "dead": false,
		"hp": 1 + int(data.sprite_scale > 1.2) * 2, "speed": data.speed * 0.55,
	})


func _update_hero(delta: float) -> void:
	if _target.is_empty() or _target.dead or not is_instance_valid(_target.node):
		_target = _nearest_slime()
	var aim := Vector2.RIGHT
	if not _target.is_empty():
		aim = (_target.node.position + Vector2(0, -4) - (_hero.position + _gun_pivot.position)).normalized()
	_gun_pivot.rotation = lerp_angle(_gun_pivot.rotation, aim.angle(), minf(1.0, delta * 14.0))
	var left := cos(_gun_pivot.rotation) < 0.0
	_gun_pivot.scale.y = -1.0 if left else 1.0
	_hero_sprite.flip_h = left

	_shot_timer -= delta
	if _shot_timer > 0.0 or _target.is_empty():
		return
	if _hero.position.distance_to(_target.node.position) > SHOOT_RANGE:
		return
	_shot_timer = randf_range(0.22, 0.42)
	_fire_at(_target)


func _fire_at(slime: Dictionary) -> void:
	var muzzle := _gun_pivot.to_global(Vector2(HOLD, 0) + (GUN_MUZZLE - GUN_GRIP) * GUN_SCALE)
	var target: Vector2 = slime.node.global_position + Vector2(0, -5)
	var angle := (target - muzzle).angle()
	Fx.muzzle_flare(muzzle, angle)
	Fx.casing(_gun_pivot.global_position, angle, _gun_pivot.scale.y < 0.0)
	Sound.play(&"shot_pistol", muzzle)
	_tracer(muzzle, target)
	# Recoil the gun like the in-game weapon.
	_gun.position = Vector2(HOLD - 1.5, 0)
	create_tween().tween_property(_gun, "position", Vector2(HOLD, 0), 0.09)
	slime.hp -= 1
	var sprite: AnimatedSprite2D = slime.sprite
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if slime.hp <= 0:
		_kill(slime)


func _tracer(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 1.0
	line.default_color = Fx.GLOW_WARM
	line.points = PackedVector2Array([from, to])
	Fx.layer(&"fx_layer").add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.07)
	tween.tween_callback(line.queue_free)


func _kill(slime: Dictionary) -> void:
	slime.dead = true
	var sprite: AnimatedSprite2D = slime.sprite
	var data: EnemyData = slime.data
	sprite.play(&"death")
	Fx.goo_splat(slime.node.global_position, data.goo_color, 3 + int(data.sprite_scale) * 2)
	Sound.play(&"slime_death", slime.node.global_position, 1.0 / sqrt(data.sprite_scale))
	_target = {}
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		_slimes.erase(slime)
		slime.node.queue_free())


func _nearest_slime() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for slime in _slimes:
		if slime.dead:
			continue
		var d: float = _hero.position.distance_to(slime.node.position)
		if d < best_distance:
			best_distance = d
			best = slime
	return best


# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	_ui.layer = 20
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	# Soft dark bands so text stays readable over the busy scene.
	for top in [true, false]:
		var band := TextureRect.new()
		var gradient := GradientTexture2D.new()
		gradient.gradient = Gradient.new()
		gradient.gradient.set_color(0, Color(0.05, 0.05, 0.09, 0.85 if top else 0.0))
		gradient.gradient.set_color(1, Color(0.05, 0.05, 0.09, 0.0 if top else 0.85))
		gradient.fill_from = Vector2(0, 0)
		gradient.fill_to = Vector2(0, 1)
		band.texture = gradient
		band.stretch_mode = TextureRect.STRETCH_SCALE
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		band.custom_minimum_size.y = 230 if top else 160
		if not top:
			band.offset_top = -160
		root.add_child(band)

	# Logo, one TextureRect per letter (+ drop shadow) so they animate alone.
	_logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_logo)
	var total := 0
	for w in LETTER_WIDTHS:
		total += (w - 1) * LOGO_SCALE
	var x := -total * 0.5
	for i in LETTER_WIDTHS.size():
		for is_shadow in [true, false]:
			var atlas := AtlasTexture.new()
			atlas.atlas = LOGO
			atlas.region = Rect2(i * LETTER_SIZE.x, 0, LETTER_SIZE.x, LETTER_SIZE.y)
			var rect := TextureRect.new()
			rect.texture = atlas
			rect.size = Vector2(LETTER_SIZE) * LOGO_SCALE
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.pivot_offset = Vector2(rect.size.x * 0.5, 8 * LOGO_SCALE)
			rect.position = Vector2(x, 34)
			if is_shadow:
				rect.modulate = Color(0.02, 0.02, 0.06, 0.55)
				rect.position += Vector2(LOGO_SCALE, LOGO_SCALE)
				_shadows.append(rect)
			else:
				_letters.append(rect)
			_logo.add_child(rect)
		x += (LETTER_WIDTHS[i] - 1) * LOGO_SCALE

	var tagline := Label.new()
	tagline.text = "SURVIVE   THE   HORDE"
	tagline.add_theme_font_size_override(&"font_size", 20)
	tagline.add_theme_color_override(&"font_color", Color("ffcd75"))
	tagline.add_theme_constant_override(&"outline_size", 8)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.position = Vector2(-300, 34 + 14 * LOGO_SCALE + 14)
	tagline.size = Vector2(600, 30)
	tagline.name = "Tagline"
	_logo.add_child(tagline)

	# Menu column on the right, framed by animated crosshair brackets.
	# Anchored to the right edge, vertically centred: holds at any window size.
	_menu_box.anchor_left = 1.0
	_menu_box.anchor_right = 1.0
	_menu_box.anchor_top = 0.5
	_menu_box.anchor_bottom = 0.5
	_menu_box.grow_vertical = Control.GROW_DIRECTION_END
	_set_menu_offset(0.0)
	_menu_box.add_theme_constant_override(&"separation", 14)
	root.add_child(_menu_box)
	var has_run := RunSave.exists()
	if has_run:
		_menu_top = -110.0
		_set_menu_offset(0.0)
	var entries := [["CONTINUE", _on_continue], ["NEW RUN", _on_play]] if has_run else [["PLAY", _on_play]]
	entries.append_array([["OPTIONS", _on_options], ["QUIT", _on_quit]])
	for entry in entries:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(300, 64)
		button.add_theme_font_size_override(&"font_size", 30)
		button.pressed.connect(entry[1])
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void: _selected = button)
		_menu_box.add_child(button)
		_buttons.append(button)
		if entry[0] == "CONTINUE":
			var run := Label.new()
			run.text = RunSave.summary()
			run.add_theme_font_size_override(&"font_size", 15)
			run.add_theme_color_override(&"font_color", Color("a7f070"))
			run.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			run.custom_minimum_size = Vector2(300, 0)
			_menu_box.add_child(run)
	for i in 4:
		var bracket := TextureRect.new()
		bracket.texture = BRACKET
		bracket.size = Vector2(21, 21)
		bracket.stretch_mode = TextureRect.STRETCH_SCALE
		bracket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bracket.flip_h = i % 2 == 1
		bracket.flip_v = i >= 2
		bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bracket.modulate = Color("ffcd75")
		root.add_child(bracket)
		_selector.append(bracket)

	var best := Label.new()
	best.text = "BEST:  ROUND %d" % _best_round() if _best_round() > 0 else "NO RUNS YET"
	best.add_theme_font_size_override(&"font_size", 18)
	best.add_theme_color_override(&"font_color", Color("73eff7"))
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.custom_minimum_size.x = 300
	_menu_box.add_child(best)

	var footer := Label.new()
	footer.text = "FLOOR 38 STUDIO"
	footer.add_theme_font_size_override(&"font_size", 14)
	footer.add_theme_color_override(&"font_color", Color("94b0c2"))
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(24, -40)
	root.add_child(footer)
	var controls := Label.new()
	controls.text = "WASD move   ·   Mouse aim & shoot   ·   Shift dash   ·   Tab build"
	controls.add_theme_font_size_override(&"font_size", 14)
	controls.add_theme_color_override(&"font_color", Color("94b0c2"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.position = Vector2(-640, -40)
	controls.size = Vector2(616, 24)
	root.add_child(controls)


func _intro() -> void:
	for i in _letters.size():
		for list in [_letters, _shadows]:
			var rect: TextureRect = list[i]
			var final_y := rect.position.y
			rect.position.y = -160
			var drop := create_tween()
			drop.tween_interval(0.25 + i * 0.07)
			drop.tween_property(rect, "position:y", final_y, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			rect.set_meta(&"base_y", final_y)
	_menu_box.modulate.a = 0.0
	_set_menu_offset(220.0)
	var slide := create_tween().set_parallel()
	slide.tween_method(_set_menu_offset, 220.0, 0.0, 0.6).set_delay(0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide.tween_property(_menu_box, "modulate:a", 1.0, 0.4).set_delay(0.9)
	slide.chain().tween_callback(_buttons[0].grab_focus)


func _animate_logo(delta: float) -> void:
	if _time < 1.4:
		return
	for i in _letters.size():
		var wave := sin(_time * 2.6 - i * 0.55) * 5.0
		for list in [_letters, _shadows]:
			var rect: TextureRect = list[i]
			rect.position.y = float(rect.get_meta(&"base_y")) + wave + (LOGO_SCALE if list == _shadows else 0)
	# Every so often a letter squashes like a slime.
	_squash_timer -= delta
	if _squash_timer <= 0.0:
		_squash_timer = randf_range(1.0, 2.2)
		var i := randi() % _letters.size()
		for list in [_letters, _shadows]:
			var rect: TextureRect = list[i]
			var squash := create_tween()
			squash.tween_property(rect, "scale", Vector2(1.18, 0.82), 0.09)
			squash.tween_property(rect, "scale", Vector2(0.92, 1.1), 0.1)
			squash.tween_property(rect, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	# Goo drops fall from the drip tips.
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(0.35, 0.9)
		var i := randi() % _letters.size()
		var drip: Array = LETTER_DRIPS[i].pick_random()
		var rect := _letters[i]
		var tip := rect.position + Vector2((drip[0] + 1.5) * LOGO_SCALE, (9 + drip[1]) * LOGO_SCALE)
		_drop_goo(tip)


func _drop_goo(at: Vector2) -> void:
	var drop := ColorRect.new()
	drop.color = Color("3b5dc9")
	drop.size = Vector2(LOGO_SCALE, LOGO_SCALE * 2)
	drop.position = at - Vector2(LOGO_SCALE * 0.5, 0)
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var core := ColorRect.new()
	core.color = Color("73eff7")
	core.size = Vector2(LOGO_SCALE * 0.5, LOGO_SCALE)
	drop.add_child(core)
	_logo.add_child(drop)
	_logo.move_child(drop, 0)
	var fall := drop.create_tween().set_parallel()
	fall.tween_property(drop, "position:y", at.y + 140.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(drop, "modulate:a", 0.0, 0.3).set_delay(0.6)
	fall.chain().tween_callback(drop.queue_free)


func _update_selector(delta: float) -> void:
	if _selected == null:
		for bracket in _selector:
			bracket.visible = false
		return
	var rect := _selected.get_global_rect()
	var breathe := 3.0 + (2.0 if sin(_time * 4.0) > 0.4 else 0.0)
	var targets := [
		rect.position - Vector2(breathe, breathe),
		Vector2(rect.end.x - 21 + breathe, rect.position.y - breathe),
		Vector2(rect.position.x - breathe, rect.end.y - 21 + breathe),
		rect.end - Vector2(21, 21) + Vector2(breathe, breathe),
	]
	for i in 4:
		_selector[i].visible = _menu_box.modulate.a > 0.5
		_selector[i].global_position = _selector[i].global_position.lerp(targets[i], minf(1.0, delta * 18.0)).round()


func _set_menu_offset(slide: float) -> void:
	_menu_box.offset_left = -380.0 + slide
	_menu_box.offset_right = -80.0 + slide
	_menu_box.offset_top = _menu_top
	_menu_box.offset_bottom = _menu_top


func _best_round() -> int:
	var save := ConfigFile.new()
	save.load(SAVE_PATH)
	return int(save.get_value("records", "best_round", 0))


func _on_continue() -> void:
	RunSave.resume_requested = true
	Sound.play(&"weapon_pick")
	Sound.set_menu_music(false, 0.4)
	SceneFader.change_scene(GAME_SCENE)


func _on_play() -> void:
	RunSave.resume_requested = false
	RunSave.delete()
	Sound.play(&"weapon_pick")
	Sound.set_menu_music(false, 0.4)
	SceneFader.change_scene(GAME_SCENE)


func _on_options() -> void:
	_options.open()


func _on_quit() -> void:
	get_tree().quit()
