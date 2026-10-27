class_name Player
extends CharacterBody2D
## Top-down player: movement, dash, health.
## Combat and movement numbers come from PlayerStats so upgrades apply.

signal health_changed(current: float, maximum: float)
signal died

const FRAME_SIZE := Vector2i(32, 32)
const DIRECTIONS: Array[StringName] = [&"down", &"side", &"up"]
## Per-frame torso bob / lean (px) baked into the character sheets, so the
## hands on the weapon stay attached. Must match art_src/tools/build_player.lua.
const IDLE_BOB: Array[int] = [0, 0, 0, 1, 1, 1, 1, 0]
const RUN_BOB: Array[int] = [0, 1, 1, 0, 0, 1, 1, 0]
const DASH_BOB: Array[int] = [1, 1, 1, 1]
const HURT_BOB: Array[int] = [0, 1]
const RUN_LEAN := 1
const DASH_LEAN := 2
const HURT_LEAN: Array[int] = [-1, 0]
## Run frames where a foot hits the ground (dust + footstep).
const FOOTFALL_FRAMES: Array[int] = [0, 4]
const HURT_ANIM_TIME := 0.24
const DUST := preload("res://assets/mystic forest/sprites/particles/dust_particles_01.png")
## Squash & stretch spring (scale) - snappy with a little wobble.
const SQUASH_STIFFNESS := 300.0
const SQUASH_DAMPING := 13.0

static var _frames_cache: Dictionary = {}

## Character sheet: idle d/s/u (8), run d/s/u (8), death (6), dash d/s/u (4),
## hurt (down/side/up x2).
@export var body_sheet: Texture2D

# Dash variables
@export var dash_speed: float = 360.0
@export var dash_duration: float = 0.18
## Invulnerability kept after the dash ends, so you can dash *into* the
## horde and come out the other side without eating a hit on landing.
@export var dash_grace: float = 0.22
## Seconds of invulnerability after taking a hit.
@export var hurt_invulnerability: float = 0.7
@export var hurt_shake: float = 0.35

var current_health := 100.0
var is_dead := false

var _dash_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_direction := Vector2.ZERO
var _dash_grace_left := 0.0
var _dodged_this_dash := false
## Slimes already hit by this dash (charging dash trait).
var _dash_hits := {}
## Cosmetic look (CharacterLooks slot indices) - saved with the run.
var look := {}
var _invulnerable_left := 0.0
var _hurt_tween: Tween
var _facing: StringName = &"down"
var _weapon_rest := Vector2.ZERO
var _lives_used := 0
var _ghost_timer := 0.0
var _hurt_anim_left := 0.0
var _squash := Vector2.ONE
var _squash_velocity := Vector2.ZERO
var _last_frame := -1
var _last_flip := false

const SHOCKWAVE_RADIUS := 34.0
const GHOST_INTERVAL := 0.035
const GHOST_LIFETIME := 0.22
const REVIVE_HEALTH := 0.5
const REVIVE_INVULNERABILITY := 2.0

@onready var stats: PlayerStats = $PlayerStats
@onready var weapon: Weapon = $Weapon
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group(&"player")
	animated_sprite.sprite_frames = _frames_for(body_sheet)
	animated_sprite.play(&"idle_down")
	_weapon_rest = weapon.position
	current_health = max_health()
	weapon.setup(stats)
	($AutoWeapons as AutoWeapons).setup(stats)
	stats.changed.connect(_on_stats_changed)
	Events.enemy_killed.connect(_on_enemy_killed)


## Puts this player in a character's body, kit and colours.
func set_character(character: CharacterData, character_look: Dictionary) -> void:
	look = character_look.duplicate()
	stats.set_character(character)
	var sheet := CharacterLooks.recolor(character.body_sheet, character.id, look)
	animated_sprite.sprite_frames = _frames_for(sheet)
	animated_sprite.play(&"idle_down")
	weapon.set_hand_texture(CharacterLooks.recolor(character.hand_texture, character.id, look))
	current_health = max_health()
	_on_health_changed()


func max_health() -> float:
	return stats.get_stat(Stats.Stat.MAX_HEALTH)


func is_dashing() -> bool:
	return _dash_left > 0.0


## Dash i-frames: the dash itself plus a short grace period after it.
func is_dash_immune() -> bool:
	return _dash_left > 0.0 or _dash_grace_left > 0.0


func dash_cooldown_progress() -> float:
	var total := stats.get_stat(Stats.Stat.DASH_COOLDOWN)
	return 1.0 - clampf(_dash_cooldown_left / total, 0.0, 1.0) if total > 0.0 else 1.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_timers(delta)

	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0 and direction != Vector2.ZERO:
		_start_dash(direction)

	if is_dashing():
		velocity = _dash_direction * dash_speed
	else:
		velocity = direction * stats.get_stat(Stats.Stat.MOVE_SPEED)

	move_and_slide()
	update_animation(direction)
	_update_squash(delta)


func _tick_timers(delta: float) -> void:
	if _dash_left > 0.0:
		_dash_left -= delta
		_check_dash_through()
		_dash_strike()
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = GHOST_INTERVAL
			_spawn_afterimage()
		if _dash_left <= 0.0:
			_dash_grace_left = dash_grace
			# Land from the dash: squash and kick up a little dust.
			punch(Vector2(1.18, 0.86))
			_dust(global_position, 2)
			var shockwave := stats.get_stat(Stats.Stat.DASH_SHOCKWAVE)
			if shockwave > 0.0:
				Shockwave.spawn(global_position + Vector2(0, -5), SHOCKWAVE_RADIUS, shockwave, 220.0)
	elif _dash_grace_left > 0.0:
		_dash_grace_left -= delta
		if _dash_grace_left <= 0.0:
			_set_immune_glow(false)
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_hurt_anim_left = maxf(0.0, _hurt_anim_left - delta)
	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		# Blink while invulnerable.
		animated_sprite.modulate.a = 0.35 if int(_invulnerable_left * 16.0) % 2 == 0 else 1.0
		if _invulnerable_left <= 0.0:
			animated_sprite.modulate.a = 1.0


func _start_dash(direction: Vector2) -> void:
	_dash_direction = direction.normalized()
	_dash_left = dash_duration
	_dash_cooldown_left = dash_duration + stats.get_stat(Stats.Stat.DASH_COOLDOWN)
	_ghost_timer = 0.0
	Sound.play(&"dash", global_position)
	# Push-off: stretch along the dash and burst dust behind.
	punch(Vector2(1.3, 0.78) if absf(_dash_direction.x) > absf(_dash_direction.y) else Vector2(0.8, 1.28))
	_dust(global_position - _dash_direction * 4.0, 3)
	_dash_grace_left = 0.0
	_dodged_this_dash = false
	_dash_hits.clear()
	_set_immune_glow(true)


func _show_dodge() -> void:
	if _dodged_this_dash:
		return
	_dodged_this_dash = true
	Sound.play(&"dodge")
	DamageNumber.spawn_text(global_position + Vector2(0, -24), "DODGE!", Color("73eff7"))


## Enemies only test contact every 0.1s, so a fast dash can slip through
## them unnoticed; check directly so passing through always reads as a dodge.
func _check_dash_through() -> void:
	if _dodged_this_dash:
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy.global_position.distance_squared_to(global_position) < 144.0:
			_show_dodge()
			return


## Knight trait: the dash is a shoulder charge that hurts what it passes.
func _dash_strike() -> void:
	var character := stats.character
	if character == null or character.dash_damage <= 0.0:
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if _dash_hits.has(enemy) or not enemy.can_be_hit():
			continue
		if enemy.global_position.distance_to(global_position) <= 12.0 + enemy.hit_radius():
			_dash_hits[enemy] = true
			enemy.take_damage(character.dash_damage * stats.damage_multiplier(), _dash_direction * 220.0)
			Events.screen_shake.emit(0.08)


## Cool HDR tint (blooms) while the dash i-frames are active.
func _set_immune_glow(on: bool) -> void:
	if _hurt_tween and _hurt_tween.is_running():
		return
	animated_sprite.self_modulate = Color(0.75, 1.45, 1.65) if on else Color.WHITE


## Dash trail: a fading, tinted copy of the current body frame.
func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.flip_h = animated_sprite.flip_h
	ghost.modulate = Color(0.45, 0.94, 0.97, 0.55)
	# Positioned above our feet, so the y-sort draws it behind the hero.
	get_parent().add_child(ghost)
	ghost.global_position = animated_sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_LIFETIME)
	tween.tween_callback(ghost.queue_free)


func update_animation(direction: Vector2) -> void:
	# The body always faces where the gun points, so they read as one.
	var aim := (get_global_mouse_position() - weapon.global_position).normalized()
	if aim.y < -0.6:
		_facing = &"up"
	elif aim.y > 0.8:
		_facing = &"down"
	elif absf(aim.x) > 0.01:
		_facing = &"side"
	animated_sprite.flip_h = aim.x < 0.0
	# Gun goes behind the body when aiming away from the camera.
	weapon.show_behind_parent = _facing == &"up"

	var moving := direction != Vector2.ZERO
	var state := "idle_"
	var bob_table := IDLE_BOB
	var lean := 0
	if _hurt_anim_left > 0.0:
		state = "hurt_"
		bob_table = HURT_BOB
	elif is_dashing():
		state = "dash_"
		bob_table = DASH_BOB
		lean = DASH_LEAN
	elif moving:
		state = "run_"
		bob_table = RUN_BOB
		lean = RUN_LEAN
	var anim := StringName(state + _facing)
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)
		_last_frame = -1
	# Run cadence follows actual speed (Light Boots make the legs go faster).
	animated_sprite.speed_scale = clampf(velocity.length() / 115.0, 0.8, 1.6) if state == "run_" else 1.0

	var frame := animated_sprite.frame
	if state == "hurt_":
		lean = HURT_LEAN[frame % HURT_LEAN.size()]
	if state == "run_" and frame != _last_frame and FOOTFALL_FRAMES.has(frame):
		_footfall()
	_last_frame = frame
	# Quick squash when the body flips to face the other way.
	if animated_sprite.flip_h != _last_flip:
		_last_flip = animated_sprite.flip_h
		punch(Vector2(0.86, 1.08))

	# Follow the baked-in bob and lean so the hands stay on the weapon.
	var bob: int = bob_table[frame % bob_table.size()]
	var facing_sign := -1.0 if animated_sprite.flip_h else 1.0
	var lean_x := lean * facing_sign if _facing == &"side" else 0.0
	weapon.position = _weapon_rest + Vector2(lean_x, bob + stats.weapon.mount_height)


func take_damage(amount: float) -> void:
	if is_dead or _invulnerable_left > 0.0:
		return
	if is_dash_immune():
		_show_dodge()
		return
	amount *= 1.0 - stats.get_stat(Stats.Stat.ARMOR)
	current_health = maxf(0.0, current_health - amount)
	_invulnerable_left = hurt_invulnerability
	_on_health_changed()
	Events.screen_shake.emit(hurt_shake)
	Events.hit_stop(0.06)
	Events.player_hurt.emit()
	_hurt_anim_left = HURT_ANIM_TIME
	punch(Vector2(1.22, 0.8))
	Sound.play(&"player_hurt")
	_play_hurt_flash()
	var thorns := stats.get_stat(Stats.Stat.THORNS)
	if thorns > 0.0:
		Shockwave.spawn(global_position + Vector2(0, -5), SHOCKWAVE_RADIUS, thorns, 260.0)
	if current_health <= 0.0:
		if _lives_used < stats.get_int(Stats.Stat.EXTRA_LIFE):
			_revive()
		else:
			die()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(max_health(), current_health + amount)
	_on_health_changed()


## Second Chance: back up at half health with a big shove.
func _revive() -> void:
	_lives_used += 1
	current_health = max_health() * REVIVE_HEALTH
	_invulnerable_left = REVIVE_INVULNERABILITY
	_on_health_changed()
	Shockwave.spawn(global_position + Vector2(0, -5), SHOCKWAVE_RADIUS * 2.0, 50.0, 400.0)
	punch(Vector2(0.7, 1.35))
	Events.player_revived.emit()
	Sound.play(&"revive")


func _on_health_changed() -> void:
	stats.low_health = current_health < max_health() * Stats.LAST_STAND_THRESHOLD
	# Last Stand glow so the player knows the bonus is on.
	if stats.is_last_stand_active():
		animated_sprite.modulate = Color(1.25, 0.85, 0.85, animated_sprite.modulate.a)
	else:
		animated_sprite.modulate = Color(1, 1, 1, animated_sprite.modulate.a)
	health_changed.emit(current_health, max_health())


func _on_enemy_killed(_enemy: Node2D) -> void:
	heal(stats.get_stat(Stats.Stat.HEAL_ON_KILL))


func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	weapon.enabled = false
	weapon.hide()
	animated_sprite.modulate = Color.WHITE
	animated_sprite.speed_scale = 1.0
	animated_sprite.flip_h = false
	animated_sprite.scale = Vector2.ONE
	animated_sprite.position.y = -14.0
	animated_sprite.play(&"death")
	Sound.play(&"player_death")
	died.emit()


## Squash & stretch impulse; the spring settles it back to normal.
func punch(target_scale: Vector2) -> void:
	_squash = target_scale
	_squash_velocity = Vector2.ZERO


func _update_squash(delta: float) -> void:
	var force := (Vector2.ONE - _squash) * SQUASH_STIFFNESS - _squash_velocity * SQUASH_DAMPING
	_squash_velocity += force * delta
	_squash += _squash_velocity * delta
	animated_sprite.scale = _squash
	# Scale around the feet, not the sprite centre (feet sit 14 px below it).
	animated_sprite.position.y = -14.0 * _squash.y


func _footfall() -> void:
	punch(Vector2(1.06, 0.94))
	var behind := -1.0 if animated_sprite.flip_h else 1.0
	_dust(global_position + Vector2(-3.0 * behind if _facing == &"side" else 0.0, 0.0), 1)
	Sound.play(&"footstep", global_position)


## Small puffs kicked up at the feet (drawn under the characters).
func _dust(at: Vector2, count: int) -> void:
	for i in count:
		var puff := Fx.one_shot(DUST, Vector2i(12, 12), randf_range(12.0, 16.0), at + Vector2(randf_range(-3, 3), randf_range(-1, 1)), Color(1, 1, 1, 0.75), 0.0, &"decal_layer")
		puff.flip_h = randf() < 0.5
		puff.scale = Vector2.ONE * randf_range(0.7, 1.0)


func _play_hurt_flash() -> void:
	if _hurt_tween:
		_hurt_tween.kill()
	animated_sprite.self_modulate = Color(1.0, 0.35, 0.35)
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(animated_sprite, "self_modulate", Color.WHITE, 0.25)


func _on_stats_changed() -> void:
	current_health = minf(current_health, max_health())
	_on_health_changed()


static func _frames_for(sheet: Texture2D) -> SpriteFrames:
	if _frames_cache.has(sheet):
		return _frames_cache[sheet]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var hurt := SpriteSheetUtil.slice(sheet, FRAME_SIZE, 10, 6)
	for d in DIRECTIONS.size():
		SpriteSheetUtil.add_animation(frames, StringName("idle_" + DIRECTIONS[d]), SpriteSheetUtil.slice(sheet, FRAME_SIZE, d, IDLE_BOB.size()), 7.0, true)
		SpriteSheetUtil.add_animation(frames, StringName("run_" + DIRECTIONS[d]), SpriteSheetUtil.slice(sheet, FRAME_SIZE, 3 + d, RUN_BOB.size()), 14.0, true)
		SpriteSheetUtil.add_animation(frames, StringName("dash_" + DIRECTIONS[d]), SpriteSheetUtil.slice(sheet, FRAME_SIZE, 7 + d, DASH_BOB.size()), 18.0, true)
		SpriteSheetUtil.add_animation(frames, StringName("hurt_" + DIRECTIONS[d]), hurt.slice(d * 2, d * 2 + 2), 10.0, false)
	SpriteSheetUtil.add_animation(frames, &"death", SpriteSheetUtil.slice(sheet, FRAME_SIZE, 6, 6), 8.0, false)
	_frames_cache[sheet] = frames
	return frames
