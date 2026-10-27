class_name BuildPanel
extends CanvasLayer
## Tab / I: inspect the current build - weapon stats with every upgrade
## applied, survivor stats, and each owned upgrade with its stack count.
## Works on top of gameplay, the pause menu and the upgrade screen.

const LABEL_COLOR := Color("94b0c2")
const UP_COLOR := Color("a7f070")
const DOWN_COLOR := Color("ef7d57")
const HEADER_COLOR := Color("ffcd75")

var enabled := true
var _stats: PlayerStats
var _was_paused := false

@onready var _root: Control = $Root
@onready var _level_label: Label = %LevelLabel
@onready var _weapon_icon: TextureRect = %WeaponIcon
@onready var _weapon_name: Label = %WeaponName
@onready var _weapon_grid: GridContainer = %WeaponGrid
@onready var _survivor_grid: GridContainer = %SurvivorGrid
@onready var _upgrade_list: VBoxContainer = %UpgradeList
@onready var _upgrade_header: Label = %UpgradeHeader


func _ready() -> void:
	_root.hide()


func bind(stats: PlayerStats) -> void:
	_stats = stats


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build"):
		if is_open():
			close()
		elif enabled and _stats:
			open()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif is_open() and event is InputEventKey:
		# Keep card hotkeys (1/2/3) from picking an upgrade underneath.
		get_viewport().set_input_as_handled()


func open() -> void:
	_was_paused = get_tree().paused
	_rebuild()
	_root.show()
	get_tree().paused = true
	Sound.play(&"ui_open")


func close() -> void:
	_root.hide()
	get_tree().paused = _was_paused


func _rebuild() -> void:
	var player := _stats.get_parent() as Player
	var who := (_stats.character.display_name + "   -   ") if _stats.character else ""
	_level_label.text = "%sLV %d   -   %d / %d XP" % [who, _stats.level, floori(_stats.xp), roundi(_stats.xp_needed)]
	var weapon := _stats.weapon
	_weapon_name.text = weapon.display_name
	PixelUI.fit_integer(_weapon_icon, weapon.icon, Vector2(240, 72))

	_clear(_weapon_grid)
	var count := _stats.get_stat(Stats.Stat.PROJECTILE_COUNT)
	var dps := _stats.get_stat(Stats.Stat.DAMAGE) * _stats.get_stat(Stats.Stat.FIRE_RATE) * count
	var base_dps := weapon.damage * weapon.fire_rate * weapon.projectile_count
	_add_row(_weapon_grid, "DPS", "%d" % roundi(dps), dps, base_dps)
	_add_stat(_weapon_grid, "Damage", Stats.Stat.DAMAGE, "%.0f")
	if weapon.is_melee():
		_add_stat(_weapon_grid, "Attack speed", Stats.Stat.FIRE_RATE, "%.1f /s")
		_add_stat(_weapon_grid, "Reach", Stats.Stat.MELEE_RANGE, "%.0f")
		_add_stat(_weapon_grid, "Swing arc", Stats.Stat.MELEE_ARC, "%.0f deg")
		_add_stat(_weapon_grid, "Crit chance", Stats.Stat.CRIT_CHANCE, "", false, 100.0, "%.0f%%")
		_add_stat(_weapon_grid, "Knockback", Stats.Stat.KNOCKBACK, "%.0f")
	else:
		_add_gun_rows(weapon)

	_build_survivor()


func _add_gun_rows(weapon: WeaponData) -> void:
	_add_stat(_weapon_grid, "Fire rate", Stats.Stat.FIRE_RATE, "%.1f /s")
	_add_stat(_weapon_grid, "Projectiles", Stats.Stat.PROJECTILE_COUNT, "%.0f")
	_add_stat(_weapon_grid, "Magazine", Stats.Stat.MAGAZINE, "%.0f")
	_add_stat(_weapon_grid, "Reload", Stats.Stat.RELOAD_TIME, "%.2f s", true)
	_add_stat(_weapon_grid, "Crit chance", Stats.Stat.CRIT_CHANCE, "", false, 100.0, "%.0f%%")
	_add_stat(_weapon_grid, "Pierce", Stats.Stat.PIERCE, "%.0f")
	_add_stat(_weapon_grid, "Ricochet", Stats.Stat.RICOCHET, "%.0f")
	_add_stat(_weapon_grid, "Bullet speed", Stats.Stat.PROJECTILE_SPEED, "%.0f")
	_add_stat(_weapon_grid, "Spread", Stats.Stat.SPREAD, "%.1f deg", true)
	_add_stat(_weapon_grid, "Knockback", Stats.Stat.KNOCKBACK, "%.0f")
	if weapon.is_explosive():
		_add_stat(_weapon_grid, "Blast radius", Stats.Stat.EXPLOSION_RADIUS, "%.0f")


func _build_survivor() -> void:
	var player := _stats.get_parent() as Player
	_clear(_survivor_grid)
	var health := "%d / %d" % [ceili(player.current_health), roundi(player.max_health())] if player else "%.0f" % _stats.get_stat(Stats.Stat.MAX_HEALTH)
	_add_row(_survivor_grid, "Health", health, _stats.get_stat(Stats.Stat.MAX_HEALTH), _stats.base_max_health)
	_add_stat(_survivor_grid, "Move speed", Stats.Stat.MOVE_SPEED, "%.0f")
	_add_stat(_survivor_grid, "Dash cooldown", Stats.Stat.DASH_COOLDOWN, "%.2f s", true)
	_add_stat(_survivor_grid, "Pickup range", Stats.Stat.PICKUP_RADIUS, "%.0f")
	_add_special(Stats.Stat.HEAL_ON_KILL, "Heal on kill", "+%.1f HP")
	_add_special(Stats.Stat.THORNS, "Thorns", "%.0f dmg")
	_add_special(Stats.Stat.BURN, "Burn", "", 100.0, "%.0f%% /s")
	_add_special(Stats.Stat.CHAIN_LIGHTNING, "Chain lightning", "%.0f hops")
	_add_special(Stats.Stat.DASH_SHOCKWAVE, "Dash shockwave", "%.0f dmg")
	_add_special(Stats.Stat.ORBITALS, "Guardian orbs", "%.0f")
	_add_special(Stats.Stat.DRONES, "Combat drones", "%.0f")
	_add_special(Stats.Stat.THUNDER, "Thunder strikes", "%.0f")
	_add_special(Stats.Stat.EXTRA_LIFE, "Extra lives", "%.0f")
	_add_special(Stats.Stat.ARMOR, "Armour", "", 100.0, "%.0f%%")
	_add_special(Stats.Stat.LIFESTEAL, "Lifesteal", "", 100.0, "%.0f%%")
	_add_special(Stats.Stat.SLASH_WAVE, "Sword waves", "%.0f")
	if _stats.get_stat(Stats.Stat.DRONES) > 0.0:
		_add_row(_survivor_grid, "Drone damage", "x%.2f" % _stats.get_stat(Stats.Stat.DRONE_DAMAGE), 0.0, 0.0)
		_add_row(_survivor_grid, "Drone fire rate", "x%.2f" % _stats.get_stat(Stats.Stat.DRONE_RATE), 0.0, 0.0)
	if _stats.get_stat(Stats.Stat.LAST_STAND) > 0.0:
		var state := "ACTIVE" if _stats.is_last_stand_active() else "below 30% HP"
		_add_row(_survivor_grid, "Last Stand", state, 0.0, 0.0)

	_clear(_upgrade_list)
	var unique := _stats.unique_upgrades()
	_upgrade_header.text = "UPGRADES  (%d picked)" % _stats.upgrades.size()
	if unique.is_empty():
		var empty := Label.new()
		empty.text = "No upgrades yet - level up or clear a round."
		empty.add_theme_color_override(&"font_color", LABEL_COLOR)
		empty.add_theme_font_size_override(&"font_size", 15)
		_upgrade_list.add_child(empty)
	for upgrade in unique:
		_upgrade_list.add_child(_make_upgrade_entry(upgrade, _stats.stack_count(upgrade)))


func _add_stat(grid: GridContainer, title: String, stat: Stats.Stat, format: String, lower_is_better := false, display_scale := 1.0, scaled_format := "") -> void:
	var value := _stats.get_stat(stat)
	var base := _stats.base_value(stat)
	var text := (scaled_format % (value * display_scale)) if not scaled_format.is_empty() else (format % value)
	_add_row(grid, title, text, value, base, lower_is_better)


## Extra-effect stats are listed only once the player owns them.
func _add_special(stat: Stats.Stat, title: String, format: String, display_scale := 1.0, scaled_format := "") -> void:
	var value := _stats.get_stat(stat)
	if value <= 0.0:
		return
	var text := (scaled_format % (value * display_scale)) if not scaled_format.is_empty() else (format % value)
	_add_row(_survivor_grid, title, text, 0.0, 0.0)


func _add_row(grid: GridContainer, title: String, text: String, value: float, base: float, lower_is_better := false) -> void:
	var name_label := _label(title, 14, LABEL_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	grid.add_child(_label(text, 15, Color.WHITE))
	var delta_label := _label("", 13, Color.WHITE)
	delta_label.custom_minimum_size.x = 58
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if base > 0.0 and absf(value - base) > 0.001:
		var change := value / base - 1.0
		var better := change < 0.0 if lower_is_better else change > 0.0
		delta_label.text = "%+d%%" % roundi(change * 100.0)
		delta_label.add_theme_color_override(&"font_color", UP_COLOR if better else DOWN_COLOR)
	grid.add_child(delta_label)


func _make_upgrade_entry(upgrade: UpgradeData, count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var icon := TextureRect.new()
	PixelUI.fit_integer(icon, upgrade.icon, Vector2(32, 32))
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 0)
	var title := upgrade.title
	if count > 1:
		title += "  x%d" % count
	if upgrade.max_stacks > 0:
		title += "  (max %d)" % upgrade.max_stacks
	text.add_child(_label(title, 16, UpgradeData.rarity_color(upgrade.rarity)))
	var description := RichTextLabel.new()
	description.bbcode_enabled = true
	description.fit_content = true
	description.scroll_active = false
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.add_theme_font_size_override(&"normal_font_size", 13)
	description.add_theme_constant_override(&"outline_size", 4)
	description.text = upgrade.description
	text.add_child(description)
	row.add_child(text)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 4)
	return label


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
