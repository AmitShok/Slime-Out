extends Node
## Round loop: announce -> fight -> clear -> pick an upgrade -> next round.
## XP gems collected mid-round trigger instant level-up picks on top.

const SAVE_PATH := "user://save.cfg"
const AUTOSAVE_INTERVAL := 10.0

## Every stat upgrade that can be offered.
@export var upgrades: Array[UpgradeData] = []
## Every weapon that can be offered as a swap.
@export var weapons: Array[WeaponData] = []
@export var offer_size := 3
## Fraction of max health restored when a round is cleared.
@export_range(0.0, 1.0) var round_clear_heal := 0.2
@export var intro_delay := 1.8
@export var clear_delay := 1.6

var current_round := 0
var kills := 0

var _pool: UpgradePool
var _pending_levels := 0
var _round_end_pending := false
var _next_round_after_choices := false
## Where the round is: "intro" (countdown), "fighting", "cleared" (picks owed).
var _phase := "intro"
## Which upgrade screen is open right now: "level", "round" or "".
var _open_choice := ""
var _run_over := false
var _autosave_left := AUTOSAVE_INTERVAL

@onready var player: Player = %Player
@onready var wave_manager: WaveManager = %WaveManager
@onready var hud: Hud = %HUD
@onready var upgrade_screen: UpgradeScreen = %UpgradeScreen
@onready var game_over_screen: GameOverScreen = %GameOverScreen
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var build_panel: BuildPanel = %BuildPanel
@onready var options_menu: OptionsMenu = %OptionsMenu


func _ready() -> void:
	_pool = UpgradePool.new(upgrades, weapons)
	Sound.set_menu_music(false)
	hud.bind(player, wave_manager)
	build_panel.bind(player.stats)
	pause_menu.build_requested.connect(build_panel.open)
	pause_menu.options_requested.connect(options_menu.open)
	Events.boss_spawned.connect(func(_boss: Node2D) -> void: Sound.play(&"boss_alert"))
	wave_manager.round_cleared.connect(_on_round_cleared)
	player.died.connect(_on_player_died)
	player.stats.leveled_up.connect(_on_leveled_up)
	upgrade_screen.upgrade_chosen.connect(_on_upgrade_chosen)
	Events.enemy_killed.connect(_on_enemy_killed)
	add_to_group(&"run_saver")
	if RunSave.resume_requested:
		RunSave.resume_requested = false
		var data := RunSave.load_data()
		if not data.is_empty():
			_restore.call_deferred(data)
			return
	RunSave.delete()
	_start_round(1)


func _start_round(number: int) -> void:
	current_round = number
	_phase = "intro"
	player.weapon.refill()
	var boss_round := wave_manager.is_boss_round(number)
	hud.show_round(number, boss_round)
	Sound.play_music(&"boss" if boss_round else &"gameplay")
	Sound.play(&"round_start")
	await get_tree().create_timer(intro_delay, false).timeout
	if player.is_dead:
		return
	wave_manager.start_round(number)
	_phase = "fighting"
	save_run()


func _on_round_cleared(number: int) -> void:
	_phase = "cleared"
	hud.show_banner("ROUND %d CLEARED" % number, "Collecting loot...")
	Sound.play(&"round_clear")
	player.heal(player.max_health() * round_clear_heal)
	save_run()
	# Brotato-style: everything left on the floor flies to you.
	Pickup.magnetise_all()
	await get_tree().create_timer(clear_delay, false).timeout
	if player.is_dead:
		return
	_round_end_pending = true
	_show_next_choice()


func _on_leveled_up(_level: int) -> void:
	_pending_levels += 1
	if not upgrade_screen.is_open():
		_show_next_choice()


## Level-ups are resolved first; the round-end pick (with weapon cards) last.
func _show_next_choice() -> void:
	if player.is_dead:
		return
	if _pending_levels > 0:
		_pending_levels -= 1
		var offer := _pool.roll(offer_size, current_round, player.stats, false)
		pause_menu.enabled = false
		_open_choice = "level"
		Sound.play(&"level_up")
		upgrade_screen.open(offer, "LEVEL UP!  LV %d" % (player.stats.level - _pending_levels), player.stats)
	elif _round_end_pending:
		_round_end_pending = false
		_next_round_after_choices = true
		var offer := _pool.roll(offer_size, current_round + 1, player.stats)
		pause_menu.enabled = false
		_open_choice = "round"
		upgrade_screen.open(offer, "ROUND %d CLEARED" % current_round, player.stats)


func _on_upgrade_chosen(upgrade: UpgradeData) -> void:
	player.stats.apply_upgrade(upgrade)
	_open_choice = ""
	Sound.play(&"weapon_pick" if upgrade.is_weapon() else &"upgrade_pick")
	if upgrade.heal_on_pick > 0.0:
		player.heal(upgrade.heal_on_pick)
	pause_menu.enabled = true
	if _pending_levels > 0 or _round_end_pending:
		_show_next_choice.call_deferred()
	elif _next_round_after_choices:
		_next_round_after_choices = false
		_start_round(current_round + 1)
	else:
		save_run()


func _on_enemy_killed(_enemy: Node2D) -> void:
	kills += 1
	hud.set_kills(kills)


func _on_player_died() -> void:
	# Roguelite rules: dying ends the run for good.
	_run_over = true
	RunSave.delete()
	wave_manager.stop()
	pause_menu.enabled = false
	build_panel.enabled = false
	var best := _record_best_round(current_round)
	Sound.stop_music(1.0)
	await get_tree().create_timer(1.4, false).timeout
	game_over_screen.open(current_round, kills, best)
	Sound.play(&"game_over")
	get_tree().create_timer(2.0, true, false, true).timeout.connect(Sound.set_menu_music.bind(true))


func _record_best_round(round_reached: int) -> int:
	var save := ConfigFile.new()
	save.load(SAVE_PATH)
	var best := maxi(int(save.get_value("records", "best_round", 0)), round_reached)
	save.set_value("records", "best_round", best)
	save.save(SAVE_PATH)
	return best


# --- Run save -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _phase != "fighting" or get_tree().paused or _run_over:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		save_run()


func _notification(what: int) -> void:
	# Window closed (X button / Alt+F4): keep the run.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_run()


## Called on a timer, at round milestones and (via the "run_saver" group)
## right before leaving the scene or quitting.
func save_run() -> void:
	if _run_over or player.is_dead or not is_inside_tree():
		return
	_autosave_left = AUTOSAVE_INTERVAL
	RunSave.write(_snapshot())


func _snapshot() -> Dictionary:
	var stats := player.stats
	var upgrade_paths: Array[String] = []
	for upgrade in stats.upgrades:
		upgrade_paths.append(upgrade.resource_path)
	var enemies: Array = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.state == Enemy.State.DYING or enemy.data.resource_path.is_empty():
			continue
		var scaling := enemy.get_scaling()
		enemies.append({
			"data": enemy.data.resource_path, "pos": RunSave.vec(enemy.global_position),
			"health": enemy.health, "scaling": [scaling.x, scaling.y, scaling.z],
		})
	var pickups: Array = []
	for node in get_tree().get_nodes_in_group(&"pickups"):
		var pickup := node as Pickup
		pickups.append({ "kind": pickup.kind, "value": pickup.value, "pos": RunSave.vec(pickup.global_position) })
	# Picks the player hasn't made yet, including the screen open right now.
	var pending := _pending_levels + (1 if _open_choice == "level" else 0)
	return {
		"round": current_round,
		"phase": _phase,
		"kills": kills,
		"pending_levels": pending,
		"stats": {
			"weapon": stats.weapon.resource_path,
			"upgrades": upgrade_paths,
			"level": stats.level, "xp": stats.xp, "xp_needed": stats.xp_needed,
		},
		"player": {
			"pos": RunSave.vec(player.global_position),
			"health": player.current_health,
			"lives_used": player._lives_used,
			"ammo": player.weapon.ammo,
		},
		"wave": wave_manager.get_state(),
		"enemies": enemies,
		"pickups": pickups,
	}


func _restore(data: Dictionary) -> void:
	var stats := player.stats
	var weapon := load(str(data.stats.weapon)) as WeaponData
	if weapon and weapon != stats.weapon:
		stats.apply_upgrade(UpgradeData.for_weapon(weapon))
	for path in data.stats.upgrades:
		var upgrade := load(str(path)) as UpgradeData
		if upgrade:
			stats.apply_upgrade(upgrade)
	stats.level = int(data.stats.level)
	stats.xp = float(data.stats.xp)
	stats.xp_needed = float(data.stats.xp_needed)
	stats.xp_changed.emit(stats.xp, stats.xp_needed, stats.level)

	player.global_position = RunSave.to_vec(data.player.pos)
	player._lives_used = int(data.player.lives_used)
	player.current_health = minf(float(data.player.health), player.max_health())
	player.heal(0.0)
	player.health_changed.emit(player.current_health, player.max_health())
	player.weapon.ammo = clampi(int(data.player.ammo), 0, player.weapon.max_ammo())
	player.weapon.ammo_changed.emit(player.weapon.ammo, player.weapon.max_ammo())

	current_round = int(data.round)
	kills = int(data.kills)
	hud.set_kills(kills)
	for entry in data.pickups:
		Pickup._spawn(int(entry.kind) as Pickup.Kind, RunSave.to_vec(entry.pos), float(entry.value))

	var boss_round := wave_manager.is_boss_round(current_round)
	match str(data.phase):
		"fighting":
			_phase = "fighting"
			wave_manager.restore_state(current_round, data.wave)
			for entry in data.enemies:
				var enemy_data := load(str(entry.data)) as EnemyData
				if enemy_data:
					var s: Array = entry.scaling
					wave_manager.spawn_restored(enemy_data, RunSave.to_vec(entry.pos), float(entry.health), Vector3(s[0], s[1], s[2]))
			hud.show_round(current_round, false)
			hud.show_banner("RUN RESUMED", "Round %d" % current_round)
			Sound.play_music(&"boss" if boss_round else &"gameplay")
			wave_manager.check_cleared.call_deferred()
		"cleared":
			_phase = "cleared"
			_round_end_pending = true
			hud.show_round(current_round, false)
			hud.show_banner("RUN RESUMED", "Round %d cleared" % current_round)
			Sound.play_music(&"gameplay")
		_:
			_start_round(current_round)
	_pending_levels = int(data.pending_levels)
	if _pending_levels > 0 or _round_end_pending:
		_show_next_choice.call_deferred()
