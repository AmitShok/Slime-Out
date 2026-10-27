class_name UpgradeCard
extends PanelContainer
## One selectable card on the upgrade screen.

signal chosen(upgrade: UpgradeData)

const STAT_COLOR := "#94b0c2"
const UP_COLOR := "#a7f070"
const DOWN_COLOR := "#ef7d57"

var upgrade: UpgradeData

var _hover_tween: Tween

@onready var _rarity: Label = %Rarity
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _description: RichTextLabel = %Description
@onready var _footer: Label = %Footer
@onready var _hotkey: Label = %Hotkey


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_entered.connect(Sound.play.bind(&"ui_hover"))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func setup(card_upgrade: UpgradeData, stats: PlayerStats, index: int) -> void:
	upgrade = card_upgrade
	var color := UpgradeData.rarity_color(upgrade.rarity)
	self_modulate = color
	_rarity.text = UpgradeData.rarity_name(upgrade.rarity)
	_rarity.add_theme_color_override(&"font_color", color)
	_title.text = upgrade.title
	_hotkey.text = "[%d]" % (index + 1)
	if upgrade.is_weapon():
		PixelUI.fit_integer(_icon, upgrade.icon, Vector2(200, 96))
		_description.text = "[center]%s\n\n%s[/center]" % [upgrade.description, _weapon_stats(upgrade.weapon, stats)]
		var owned := stats.upgrades.size()
		_footer.text = "Keeps all %d upgrades" % owned if owned > 0 else "Upgrades carry over"
	else:
		PixelUI.fit_integer(_icon, upgrade.icon, Vector2(200, 96))
		_description.text = "[center]%s[/center]" % upgrade.description
		var count := stats.stack_count(upgrade)
		if count == 0:
			_footer.text = "New"
		elif upgrade.max_stacks > 0:
			_footer.text = "Owned %d / %d" % [count, upgrade.max_stacks]
		else:
			_footer.text = "Owned %d" % count


## Weapon stats *with the player's current upgrades applied*, compared to
## the gun they hold now.
func _weapon_stats(weapon: WeaponData, stats: PlayerStats) -> String:
	var damage := stats.get_stat(Stats.Stat.DAMAGE, weapon)
	var rate := stats.get_stat(Stats.Stat.FIRE_RATE, weapon)
	var pellets := stats.get_stat(Stats.Stat.PROJECTILE_COUNT, weapon)
	var new_dps := damage * rate * pellets
	var old_dps := stats.get_stat(Stats.Stat.DAMAGE) * stats.get_stat(Stats.Stat.FIRE_RATE) * stats.get_stat(Stats.Stat.PROJECTILE_COUNT)
	var delta := new_dps - old_dps
	var delta_text := "[color=%s]%+d[/color]" % [UP_COLOR if delta >= 0.0 else DOWN_COLOR, roundi(delta)]
	if weapon.is_melee():
		return "\n".join(PackedStringArray([
			"[color=%s]DPS[/color] %d (%s)" % [STAT_COLOR, roundi(new_dps), delta_text],
			"[color=%s]DMG[/color] %d   [color=%s]SPEED[/color] %.1f/s" % [STAT_COLOR, roundi(damage), STAT_COLOR, rate],
			"[color=%s]REACH[/color] %d   [color=%s]ARC[/color] %d" % [STAT_COLOR, roundi(stats.get_stat(Stats.Stat.MELEE_RANGE, weapon)), STAT_COLOR, roundi(stats.get_stat(Stats.Stat.MELEE_ARC, weapon))],
		]))
	var lines := PackedStringArray([
		"[color=%s]DPS[/color] %d (%s)" % [STAT_COLOR, roundi(new_dps), delta_text],
		"[color=%s]DMG[/color] %d   [color=%s]RATE[/color] %.1f/s" % [STAT_COLOR, roundi(damage), STAT_COLOR, rate],
		"[color=%s]MAG[/color] %d   [color=%s]RELOAD[/color] %.1fs" % [STAT_COLOR, stats.get_int(Stats.Stat.MAGAZINE, weapon), STAT_COLOR, stats.get_stat(Stats.Stat.RELOAD_TIME, weapon)],
	])
	if weapon.is_explosive():
		lines.append("[color=%s]BLAST[/color] %d" % [STAT_COLOR, roundi(stats.get_stat(Stats.Stat.EXPLOSION_RADIUS, weapon))])
	elif stats.get_int(Stats.Stat.PIERCE, weapon) > 0:
		lines.append("[color=%s]PIERCE[/color] %d" % [STAT_COLOR, stats.get_int(Stats.Stat.PIERCE, weapon)])
	return "\n".join(lines)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		chosen.emit(upgrade)


func _set_hovered(hovered: bool) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel()
	_hover_tween.tween_property(self, "scale", Vector2.ONE * (1.05 if hovered else 1.0), 0.1)
	_hover_tween.tween_property(self, "modulate", Color(1.15, 1.15, 1.15) if hovered else Color.WHITE, 0.1)
