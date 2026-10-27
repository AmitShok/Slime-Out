class_name WaveManager
extends Node
## Spawns each round's horde and reports when it is cleared.
## All difficulty scaling lives here and is tunable from the inspector.

signal round_cleared(round_number: int)
signal progress_changed(killed: int, total: int)

@export var enemy_scene: PackedScene
@export var enemy_types: Array[EnemyData] = []
@export var boss: EnemyData
## Every Nth round is a boss round.
@export var boss_every := 5
## World-space rectangle enemies may spawn in (inside the arena walls).
@export var arena := Rect2(-410, -245, 845, 490)
## Spawn outside the camera view so enemies walk in rather than pop in.
@export var min_spawn_distance := 180.0
@export var max_spawn_distance := 320.0
@export var spawn_parent: Node2D

@export_group("Enemy Count")
@export var base_enemy_count := 10
@export var enemies_per_round := 6.0
@export var enemies_per_round_squared := 0.3
@export var base_max_alive := 16
@export var max_alive_per_round := 6
@export var max_alive_cap := 160

@export_group("Spawn Pacing")
@export var base_spawn_interval := 0.8
## Interval multiplier applied per round (0.91 = 9% faster each round).
@export var spawn_interval_decay := 0.91
@export var min_spawn_interval := 0.2
## Extra enemy per spawn burst every N rounds.
@export var rounds_per_burst_size := 3

@export_group("Enemy Scaling")
@export var health_growth := 0.18
@export var health_growth_squared := 0.012
@export var speed_growth := 0.02
@export var max_speed_bonus := 0.45
@export var damage_growth := 0.06

var round_number := 0
var active := false

var _to_spawn := 0
var _bosses_to_spawn := 0
var _total := 0
var _killed := 0
var _alive := 0
var _spawn_timer := 0.0


func start_round(number: int) -> void:
	_sweep_leftovers()
	round_number = number
	_bosses_to_spawn = (number / boss_every) if (boss and number % boss_every == 0) else 0
	_to_spawn = enemy_count(number)
	_total = _to_spawn + _bosses_to_spawn
	_killed = 0
	_alive = 0
	_spawn_timer = 0.5
	active = true
	progress_changed.emit(_killed, _total)


func stop() -> void:
	active = false


## Spawn bookkeeping for the run save (enemies are saved separately).
func get_state() -> Dictionary:
	return {
		"to_spawn": _to_spawn, "bosses_to_spawn": _bosses_to_spawn,
		"total": _total, "killed": _killed, "spawn_timer": _spawn_timer,
	}


## Resumes a saved round. Restored enemies are added with spawn_restored().
func restore_state(number: int, state: Dictionary) -> void:
	_sweep_leftovers()
	round_number = number
	_to_spawn = int(state.to_spawn)
	_bosses_to_spawn = int(state.bosses_to_spawn)
	_total = int(state.total)
	_killed = int(state.killed)
	_spawn_timer = float(state.spawn_timer)
	_alive = 0
	active = true
	progress_changed.emit(_killed, _total)


func spawn_restored(enemy_data: EnemyData, at: Vector2, health: float, scaling: Vector3) -> void:
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.setup(enemy_data, scaling.x, scaling.y, scaling.z)
	enemy.health = minf(health, enemy.max_health)
	enemy.spawn_instantly = true
	enemy.position = at
	_track(enemy)
	spawn_parent.add_child(enemy)


## A save can land on the frame the last slime died: finish the round then.
func check_cleared() -> void:
	if active and _to_spawn <= 0 and _bosses_to_spawn <= 0 and _alive <= 0:
		active = false
		round_cleared.emit(round_number)


## Safety net: nothing from the previous round may survive into the next.
func _sweep_leftovers() -> void:
	for node in get_tree().get_nodes_in_group(&"enemy_nodes"):
		var enemy := node as Enemy
		if enemy and enemy.state != Enemy.State.CHASING:
			enemy.queue_free()


func is_boss_round(number: int) -> bool:
	return boss != null and number % boss_every == 0


func enemy_count(number: int) -> int:
	return base_enemy_count + int(enemies_per_round * number + enemies_per_round_squared * number * number)


func health_multiplier(number: int) -> float:
	var r := float(number - 1)
	return 1.0 + health_growth * r + health_growth_squared * r * r


func speed_multiplier(number: int) -> float:
	return 1.0 + minf(max_speed_bonus, speed_growth * (number - 1))


func damage_multiplier(number: int) -> float:
	return 1.0 + damage_growth * (number - 1)


func _process(delta: float) -> void:
	if not active:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = maxf(min_spawn_interval, base_spawn_interval * pow(spawn_interval_decay, round_number - 1))

	var max_alive := mini(max_alive_cap, base_max_alive + max_alive_per_round * round_number)
	# Bosses arrive once half of the regular horde has been released.
	if _bosses_to_spawn > 0 and _to_spawn <= enemy_count(round_number) / 2:
		_bosses_to_spawn -= 1
		_spawn(boss)
	var burst := 1 + round_number / rounds_per_burst_size
	for i in burst:
		if _to_spawn <= 0 or _alive >= max_alive:
			break
		_to_spawn -= 1
		_spawn(_pick_enemy_type())


func _spawn(data: EnemyData) -> void:
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.setup(data, health_multiplier(round_number), speed_multiplier(round_number), damage_multiplier(round_number))
	enemy.position = _pick_spawn_point()
	_track(enemy)
	spawn_parent.add_child(enemy)


func _track(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.split_spawned.connect(_on_split_spawned)
	_alive += 1


## Splitter children count towards the round so it can't clear early.
func _on_split_spawned(child: Enemy) -> void:
	_track(child)
	_total += 1
	progress_changed.emit(_killed, _total)


func _pick_enemy_type() -> EnemyData:
	var total := 0.0
	var weights: Array[float] = []
	for data in enemy_types:
		var weight := 0.0
		if round_number >= data.min_round:
			weight = data.spawn_weight + data.weight_per_round * (round_number - data.min_round)
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for i in enemy_types.size():
		roll -= weights[i]
		if roll <= 0.0 and weights[i] > 0.0:
			return enemy_types[i]
	return enemy_types[0]


func _pick_spawn_point() -> Vector2:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var center := player.global_position if player else arena.get_center()
	var best := arena.get_center()
	var best_distance := -1.0
	for attempt in 16:
		var point := center + Vector2.from_angle(randf() * TAU) * randf_range(min_spawn_distance, max_spawn_distance)
		point = point.clamp(arena.position, arena.end)
		var distance := point.distance_to(center)
		if distance >= min_spawn_distance:
			return point
		if distance > best_distance:
			best_distance = distance
			best = point
	return best


func _on_enemy_died(_enemy: Enemy) -> void:
	_alive -= 1
	_killed += 1
	progress_changed.emit(_killed, _total)
	if active and _to_spawn <= 0 and _bosses_to_spawn <= 0 and _alive <= 0:
		active = false
		round_cleared.emit(round_number)
