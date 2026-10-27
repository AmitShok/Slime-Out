class_name Enemy
extends CharacterBody2D
## Slime enemy driven by EnemyData. WaveManager calls setup() (with round
## scaling) before adding it to the tree.

signal died(enemy: Enemy)
## Emitted for each child a splitter releases, before it enters the tree.
signal split_spawned(child: Enemy)

enum State { SPAWNING, CHASING, DYING }
## Sub-state used by CHARGER.
enum Charge { APPROACH, WINDUP, DASH, RECOVER }

const DIRECTIONS: Array[StringName] = [&"down", &"side", &"up"]
const SLIME_FRAME := Vector2i(32, 32)
## Pixels from the frame centre down to the slime's feet (used for y-sort).
const FEET_OFFSET := 6.0
## Pixels from the frame centre down to the middle of the slime's body.
const BODY_OFFSET := 2.0
const KNOCKBACK_DECAY := 900.0
const SEPARATION_STRENGTH := 70.0
const CONTACT_CHECK_INTERVAL := 0.1
const BURN_TICK := 0.5
const BURN_DURATION := 3.0
const CHARGE_RECOVER_TIME := 0.5
const SPIT_ANIM_TIME := 0.55
const HEART_DROP_CHANCE := 0.012
const MAGNET_DROP_CHANCE := 0.004
## Spatial hash cell for separation queries (keeps big hordes cheap).
const GRID_CELL := 24.0

static var _grid: Dictionary = {}
static var _grid_frame := -1
const CROWN_TEXTURE := preload("res://assets/floor38/ui/crown.png")
const ALERT_TEXTURE := preload("res://assets/floor38/fx/alert.png")
const FLAME_SHEET := preload("res://assets/floor38/fx/flame.png")

static var _frames_cache: Dictionary = {}

## Used only when the scene is placed by hand (no setup() call).
@export var default_data: EnemyData

var data: EnemyData
var max_health := 30.0
var health := 30.0
var speed := 40.0
var contact_damage := 10.0
var state := State.SPAWNING
## Split children skip the emerge animation and burst outwards instead.
var spawn_instantly := false

var _player: Player
var _knockback := Vector2.ZERO
var _facing: StringName = &"down"
var _touching_player := false
var _contact_timer := 0.0
var _flash_tween: Tween
var _scaling := Vector3.ONE  # health, speed, damage multipliers
var _attack_timer := 0.0
var _spit_anim_left := 0.0
var _charge_state := Charge.APPROACH
var _charge_timer := 0.0
var _charge_direction := Vector2.ZERO
var _burn_dps := 0.0
var _burn_left := 0.0
var _burn_tick := 0.0
var _alert: Sprite2D
var _flame: AnimatedSprite2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _hitbox: Area2D = $Hitbox
@onready var _hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func setup(enemy_data: EnemyData, health_mult := 1.0, speed_mult := 1.0, damage_mult := 1.0) -> void:
	data = enemy_data
	_scaling = Vector3(health_mult, speed_mult, damage_mult)
	max_health = data.max_health * health_mult
	health = max_health
	speed = data.speed * speed_mult
	contact_damage = data.contact_damage * damage_mult


func _ready() -> void:
	if data == null:
		setup(default_data)
	add_to_group(&"enemies")
	# Every enemy node, alive or dying - used to sweep leftovers between rounds.
	add_to_group(&"enemy_nodes")
	_player = get_tree().get_first_node_in_group(&"player") as Player

	var s := data.sprite_scale
	_sprite.sprite_frames = _frames_for(data.sheet)
	_sprite.scale = Vector2.ONE * s
	_sprite.position = Vector2(0.0, -FEET_OFFSET * s)

	var body_center := Vector2(0.0, (BODY_OFFSET - FEET_OFFSET) * s)
	var body := CircleShape2D.new()
	body.radius = hit_radius()
	_body_shape.shape = body
	_body_shape.position = body_center
	var reach := CircleShape2D.new()
	reach.radius = hit_radius() + 2.0
	_hitbox_shape.shape = reach
	_hitbox_shape.position = body_center

	_attack_timer = data.attack_cooldown * randf_range(0.4, 1.0)
	if data.is_boss:
		_add_crown(s)
		Events.boss_spawned.emit(self)
	if spawn_instantly:
		state = State.CHASING
	else:
		_spawn()


## Round multipliers (health, speed, damage) - stored by the run save.
func get_scaling() -> Vector3:
	return _scaling


func hit_radius() -> float:
	return data.radius * data.sprite_scale


func can_be_hit() -> bool:
	return state == State.CHASING


func take_damage(amount: float, knockback_force: Vector2, is_crit := false) -> void:
	if state != State.CHASING:
		return
	health -= amount
	_knockback += knockback_force * (1.0 - data.knockback_resistance)
	_flash()
	if is_crit:
		Sound.play(&"enemy_crit", global_position)
	elif knockback_force != Vector2.ZERO:
		Sound.play(&"enemy_hit", global_position)
	DamageNumber.spawn(global_position + Vector2(0.0, -16.0 * data.sprite_scale), amount, is_crit)
	if health <= 0.0:
		_die()


## Sets the enemy on fire; re-igniting keeps the strongest burn.
func ignite(damage_per_second: float) -> void:
	if state != State.CHASING or damage_per_second <= 0.0:
		return
	_burn_dps = maxf(_burn_dps, damage_per_second)
	_burn_left = BURN_DURATION
	if _flame == null:
		Sound.play(&"burn", global_position)
		_flame = AnimatedSprite2D.new()
		_flame.sprite_frames = SpriteSheetUtil.strip(FLAME_SHEET, Vector2i(7, 9), 10.0, true)
		_flame.position = Vector2(0.0, (BODY_OFFSET - FEET_OFFSET - 7.0) * data.sprite_scale)
		add_child(_flame)
		_flame.play()


func _spawn() -> void:
	state = State.SPAWNING
	_body_shape.disabled = true
	_hitbox.monitoring = false
	_sprite.play(&"spawn")
	await _sprite.animation_finished
	if state != State.SPAWNING:
		return
	state = State.CHASING
	_body_shape.disabled = false
	_hitbox.monitoring = true


func _physics_process(delta: float) -> void:
	if state != State.CHASING:
		return
	_tick_burn(delta)
	if state != State.CHASING:
		return
	var to_player := Vector2.ZERO
	if _player and not _player.is_dead:
		to_player = _player.global_position - global_position

	var desired: Vector2
	match data.behavior:
		EnemyData.Behavior.SPITTER:
			desired = _spitter_velocity(to_player, delta)
		EnemyData.Behavior.CHARGER:
			desired = _charger_velocity(to_player, delta)
		_:
			desired = _chase(to_player)

	velocity = desired + _separation() + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()

	_spit_anim_left -= delta
	_contact_timer -= delta
	if _contact_timer <= 0.0:
		_contact_timer = CONTACT_CHECK_INTERVAL
		_check_contact()
	# Contact can kill us this tick (Thorns); don't overwrite the death anim.
	if state != State.CHASING:
		return
	_update_animation(to_player)


func _chase(to_player: Vector2) -> Vector2:
	return to_player.normalized() * speed if to_player.length() > 2.0 else Vector2.ZERO


## Hold a firing distance, back off if crowded, lob acid on a cooldown.
func _spitter_velocity(to_player: Vector2, delta: float) -> Vector2:
	var distance := to_player.length()
	_attack_timer -= delta
	if _attack_timer <= 0.0 and distance <= data.attack_range * 1.3 and distance > 0.0:
		_attack_timer = data.attack_cooldown
		# Lead the shot so standing still isn't the only way to get hit.
		var lead := _player.velocity * 0.35
		var from := global_position + Vector2(0.0, (BODY_OFFSET - FEET_OFFSET) * data.sprite_scale)
		AcidGlob.launch(from, _player.global_position + lead, data.attack_damage * _scaling.z)
		Sound.play(&"spit", global_position)
		_sprite.play(StringName("attack_" + _facing))
		_spit_anim_left = SPIT_ANIM_TIME
	if distance > data.attack_range:
		return to_player / distance * speed
	if distance < data.attack_range * 0.6 and distance > 0.0:
		return -to_player / distance * speed
	return Vector2.ZERO


## Approach -> stop and telegraph -> straight-line dash -> recover.
func _charger_velocity(to_player: Vector2, delta: float) -> Vector2:
	_attack_timer -= delta
	_charge_timer -= delta
	match _charge_state:
		Charge.APPROACH:
			if _attack_timer <= 0.0 and to_player.length() <= data.attack_range:
				_charge_state = Charge.WINDUP
				_charge_timer = data.windup_time
				_charge_direction = to_player.normalized()
				_show_alert(true)
				Sound.play(&"charger_alert", global_position)
				return Vector2.ZERO
			return _chase(to_player)
		Charge.WINDUP:
			# Shiver while winding up.
			_sprite.position.x = sin(_charge_timer * 60.0)
			if _charge_timer <= 0.0:
				_charge_state = Charge.DASH
				_charge_timer = data.charge_duration
				_sprite.position.x = 0.0
				_show_alert(false)
				Sound.play(&"charger_dash", global_position)
			return Vector2.ZERO
		Charge.DASH:
			if _charge_timer <= 0.0:
				_charge_state = Charge.RECOVER
				_charge_timer = CHARGE_RECOVER_TIME
			return _charge_direction * data.charge_speed * _scaling.y
		Charge.RECOVER:
			if _charge_timer <= 0.0:
				_charge_state = Charge.APPROACH
				_attack_timer = data.attack_cooldown
	return Vector2.ZERO


func _tick_burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = BURN_TICK
		take_damage(_burn_dps * BURN_TICK, Vector2.ZERO)
	if _burn_left <= 0.0 and _flame:
		_flame.queue_free()
		_flame = null
		_burn_dps = 0.0


## Soft push away from overlapping enemies so the horde spreads out
## instead of collapsing into one stack.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	var my_radius := hit_radius()
	_refresh_grid()
	var cell := Vector2i((global_position / GRID_CELL).floor())
	var neighbours: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			neighbours.append_array(_grid.get(cell + Vector2i(dx, dy), []))
	for entry in neighbours:
		if entry == self or not is_instance_valid(entry):
			continue
		var other := entry as Enemy
		var offset := global_position - other.global_position
		var min_distance := my_radius + other.hit_radius()
		var distance_sq := offset.length_squared()
		if distance_sq < min_distance * min_distance and distance_sq > 0.01:
			var distance := sqrt(distance_sq)
			push += offset / distance * (1.0 - distance / min_distance)
	return push * SEPARATION_STRENGTH


## Rebuilt once per physics frame and shared by every enemy.
func _refresh_grid() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _grid_frame:
		return
	_grid_frame = frame
	_grid.clear()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		var key := Vector2i((enemy.global_position / GRID_CELL).floor())
		if _grid.has(key):
			_grid[key].append(enemy)
		else:
			_grid[key] = [enemy]


func _check_contact() -> void:
	_touching_player = false
	for body in _hitbox.get_overlapping_bodies():
		var player := body as Player
		if player:
			_touching_player = true
			player.take_damage(contact_damage)


func _update_animation(to_player: Vector2) -> void:
	if state != State.CHASING:
		return
	var look := _charge_direction if _charge_state == Charge.DASH else to_player
	if absf(look.x) > absf(look.y):
		_facing = &"side"
		_sprite.flip_h = look.x < 0.0
	else:
		_facing = &"down" if look.y >= 0.0 else &"up"
	var attacking := _touching_player or _charge_state == Charge.WINDUP or _charge_state == Charge.DASH
	var anim := StringName(("attack_" if attacking else "move_") + _facing)
	# Let a spitter finish its spit animation.
	if _spit_anim_left > 0.0:
		return
	if _sprite.animation != anim:
		_sprite.play(anim)


func _flash() -> void:
	var s := data.sprite_scale
	if _flash_tween:
		_flash_tween.kill()
	var flash_material := _sprite.material as ShaderMaterial
	flash_material.set_shader_parameter(&"flash", 1.0)
	_sprite.scale = Vector2(1.2, 0.85) * s
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_method(func(v: float) -> void: flash_material.set_shader_parameter(&"flash", v), 1.0, 0.0, 0.12)
	_flash_tween.tween_property(_sprite, "scale", Vector2.ONE * s, 0.12)


func _show_alert(visible_now: bool) -> void:
	if _alert == null:
		_alert = Sprite2D.new()
		_alert.texture = ALERT_TEXTURE
		_alert.position = Vector2(0.0, (-4.0 - FEET_OFFSET) * data.sprite_scale - 8.0)
		_alert.z_index = 5
		add_child(_alert)
	_alert.visible = visible_now
	var flash_material := _sprite.material as ShaderMaterial
	flash_material.set_shader_parameter(&"flash_color", Color("ef7d57"))
	flash_material.set_shader_parameter(&"flash", 0.45 if visible_now else 0.0)
	if not visible_now:
		flash_material.set_shader_parameter(&"flash_color", Color.WHITE)


func _die() -> void:
	state = State.DYING
	remove_from_group(&"enemies")
	_body_shape.set_deferred(&"disabled", true)
	_hitbox.set_deferred(&"monitoring", false)
	if _alert:
		_alert.hide()
	if _flame:
		_flame.hide()
	_split()
	_drop_loot()
	# Bigger slimes pop with a deeper sound.
	Sound.play(&"slime_death", global_position, 1.0 / sqrt(maxf(data.sprite_scale, 0.5)))
	died.emit(self)
	Events.enemy_killed.emit(self)
	set_physics_process(false)
	_sprite.flip_h = false
	_sprite.position.x = 0.0
	_sprite.play(&"death")
	# Free on a timer, never on animation_finished: if anything ever swaps the
	# animation, a dead slime must still not linger into the next round.
	var length := SpriteSheetUtil.duration(_sprite.sprite_frames, &"death")
	get_tree().create_timer(length + 0.05, false).timeout.connect(queue_free)


func _drop_loot() -> void:
	var s := data.sprite_scale
	var center := global_position + Vector2(0.0, (BODY_OFFSET - FEET_OFFSET) * s)
	Fx.goo_splat(global_position, data.goo_color, 3 + int(s) * 3)
	# XP grows gently with the round's health scaling.
	Pickup.drop_gem(center, data.xp_value * sqrt(_scaling.x))
	if randf() < HEART_DROP_CHANCE * s:
		Pickup.drop(Pickup.Kind.HEART, center)
	elif randf() < MAGNET_DROP_CHANCE * s:
		Pickup.drop(Pickup.Kind.MAGNET, center)
	if data.is_boss:
		Events.hit_stop(0.18)
		Events.screen_shake.emit(0.7)
	elif s >= 2.0:
		Events.hit_stop(0.04)


func _split() -> void:
	if data.split_into == null or data.split_count <= 0:
		return
	Sound.play(&"split", global_position)
	var scene := load(scene_file_path) as PackedScene
	for i in data.split_count:
		var child: Enemy = scene.instantiate()
		child.setup(data.split_into, _scaling.x, _scaling.y, _scaling.z)
		child.spawn_instantly = true
		var direction := Vector2.from_angle(TAU * i / data.split_count + randf_range(-0.3, 0.3))
		child.position = global_position + direction * 4.0
		child._knockback = direction * 220.0
		split_spawned.emit(child)
		get_parent().add_child.call_deferred(child)


func _add_crown(s: float) -> void:
	var crown := Sprite2D.new()
	crown.texture = CROWN_TEXTURE
	crown.scale = Vector2.ONE * 2.0
	# Slime body top sits 4px above the frame centre.
	crown.position = Vector2(0.0, (-4.0 - FEET_OFFSET) * s - 6.0)
	crown.name = "Crown"
	add_child(crown)


static func _frames_for(sheet: Texture2D) -> SpriteFrames:
	if _frames_cache.has(sheet):
		return _frames_cache[sheet]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# [first row, frame count, fps, loop] - rows go down / side / up.
	var layout := {
		&"idle": [0, 4, 6.0, true],
		&"move": [3, 6, 10.0, true],
		&"attack": [6, 7, 12.0, true],
	}
	for anim: StringName in layout:
		var row: int = layout[anim][0]
		for d in DIRECTIONS.size():
			var textures := SpriteSheetUtil.slice(sheet, SLIME_FRAME, row + d, layout[anim][1])
			SpriteSheetUtil.add_animation(frames, StringName(anim + "_" + DIRECTIONS[d]), textures, layout[anim][2], layout[anim][3])
	var death := SpriteSheetUtil.slice(sheet, SLIME_FRAME, 12, 5)
	SpriteSheetUtil.add_animation(frames, &"death", death, 10.0, false)
	var spawn := death.duplicate()
	spawn.reverse()
	SpriteSheetUtil.add_animation(frames, &"spawn", spawn, 9.0, false)
	_frames_cache[sheet] = frames
	return frames
