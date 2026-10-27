class_name Hud
extends CanvasLayer
## In-game HUD: health, round progress, weapon/ammo, loadout, boss bar and
## round banners.

const BANNER_HOLD := 1.4

var _player: Player
var _boss: Enemy
var _banner_tween: Tween
var _xp_tween: Tween
var _shown_level := 1

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _round_label: Label = %RoundLabel
@onready var _round_progress: ProgressBar = %RoundProgress
@onready var _progress_label: Label = %ProgressLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _weapon_icon: TextureRect = %WeaponIcon
@onready var _weapon_name: Label = %WeaponName
@onready var _ammo_label: Label = %AmmoLabel
@onready var _reload_bar: ProgressBar = %ReloadBar
@onready var _dash_bar: ProgressBar = %DashBar
@onready var _upgrade_row: HFlowContainer = %UpgradeRow
@onready var _boss_panel: Control = %BossPanel
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: ProgressBar = %BossBar
@onready var _xp_bar: ProgressBar = %XPBar
@onready var _level_label: Label = %LevelLabel
@onready var _xp_label: Label = %XPLabel
@onready var _xp_shine: ColorRect = %XPShine
@onready var _banner: Control = %Banner
@onready var _banner_title: Label = %BannerTitle
@onready var _banner_subtitle: Label = %BannerSubtitle


func _ready() -> void:
	var bullet_icon: TextureRect = $Root/WeaponPanel/HBox/Info/AmmoRow/BulletIcon
	PixelUI.fit_integer(bullet_icon, bullet_icon.texture, Vector2(16, 16))
	_boss_panel.hide()
	_banner.modulate.a = 0.0
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.player_revived.connect(show_banner.bind("SECOND CHANCE", "Back on your feet!"))


func bind(player: Player, waves: WaveManager) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.weapon.ammo_changed.connect(_on_ammo_changed)
	player.stats.weapon_changed.connect(_on_weapon_changed)
	player.stats.changed.connect(_refresh_upgrades)
	waves.progress_changed.connect(_on_progress_changed)
	player.stats.xp_changed.connect(_on_xp_changed)
	_on_xp_changed(player.stats.xp, player.stats.xp_needed, player.stats.level)
	_on_health_changed(player.current_health, player.max_health())
	_on_weapon_changed(player.stats.weapon)
	_on_ammo_changed(player.weapon.ammo, player.weapon.max_ammo())
	_refresh_upgrades()
	set_kills(0)


func _process(_delta: float) -> void:
	if _player:
		_reload_bar.visible = _player.weapon.is_reloading()
		_reload_bar.value = _player.weapon.reload_progress()
		_dash_bar.value = _player.dash_cooldown_progress()
	if _boss:
		if is_instance_valid(_boss) and _boss.state != Enemy.State.DYING:
			_boss_bar.value = _boss.health / _boss.max_health
		else:
			_boss = null
			_boss_panel.hide()


func show_round(number: int, boss_round: bool) -> void:
	_round_label.text = "ROUND %d" % number
	_round_progress.value = 0.0
	_progress_label.text = "Get ready..."
	if boss_round:
		show_banner("ROUND %d" % number, "The Slime King approaches!")
	else:
		show_banner("ROUND %d" % number, "Survive the horde")


func show_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner_subtitle.visible = not subtitle.is_empty()
	if _banner_tween:
		_banner_tween.kill()
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 1.3
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.set_parallel()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.35).set_delay(BANNER_HOLD)


func set_kills(kills: int) -> void:
	_kills_label.text = str(kills)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [ceili(current), roundi(maximum)]


func _on_ammo_changed(current: int, maximum: int) -> void:
	_ammo_label.text = "%d / %d" % [current, maximum]
	_ammo_label.modulate = Color("ef7d57") if current == 0 else Color.WHITE


func _on_weapon_changed(weapon: WeaponData) -> void:
	_weapon_name.text = weapon.display_name
	PixelUI.fit_integer(_weapon_icon, weapon.icon, Vector2(84, 36))


func _on_progress_changed(killed: int, total: int) -> void:
	_round_progress.value = float(killed) / float(maxi(total, 1))
	_progress_label.text = "%d slimes left" % (total - killed)


func _on_xp_changed(xp: float, needed: float, level: int) -> void:
	var target := xp / maxf(needed, 1.0)
	_level_label.text = "LV %d" % level
	_xp_label.text = "%d / %d XP" % [floori(xp), roundi(needed)]
	if _xp_tween:
		_xp_tween.kill()
	# Keeps animating while an upgrade screen has the game paused.
	_xp_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if level > _shown_level:
		# Fill to the end, flash, then roll over into the new level.
		_shown_level = level
		_xp_tween.tween_property(_xp_bar, "value", 1.0, 0.12)
		_xp_tween.tween_property(_xp_shine, "color:a", 0.85, 0.05)
		_xp_tween.tween_property(_xp_shine, "color:a", 0.0, 0.3)
		_xp_tween.tween_property(_xp_bar, "value", 0.0, 0.0)
	_xp_tween.tween_property(_xp_bar, "value", target, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_boss_spawned(enemy: Node2D) -> void:
	_boss = enemy as Enemy
	_boss_name.text = _boss.data.display_name.to_upper()
	_boss_bar.value = 1.0
	_boss_panel.show()


func _refresh_upgrades() -> void:
	for child in _upgrade_row.get_children():
		child.queue_free()
	for upgrade in _player.stats.unique_upgrades():
		_upgrade_row.add_child(PixelUI.make_upgrade_badge(upgrade, _player.stats.stack_count(upgrade)))
