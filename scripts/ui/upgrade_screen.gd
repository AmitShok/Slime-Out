class_name UpgradeScreen
extends CanvasLayer
## Pauses the game and offers the post-round upgrade cards.

signal upgrade_chosen(upgrade: UpgradeData)

const CARD_SCENE := preload("res://scenes/ui/upgrade_card.tscn")
## Ignore input briefly so a held fire button can't pick a card by accident.
const INPUT_GRACE_MS := 450

var _is_open := false
var _accept_input_at := 0
var _cards: Array[UpgradeCard] = []

@onready var _root: Control = $Root
@onready var _title: Label = %Title
@onready var _card_row: HBoxContainer = %CardRow
@onready var _loadout_row: HBoxContainer = %LoadoutRow


func _ready() -> void:
	_root.hide()


func is_open() -> bool:
	return _is_open


func open(offer: Array[UpgradeData], title: String, stats: PlayerStats) -> void:
	for child in _card_row.get_children():
		child.queue_free()
	_cards.clear()
	_title.text = title

	for i in offer.size():
		var card: UpgradeCard = CARD_SCENE.instantiate()
		_card_row.add_child(card)
		card.setup(offer[i], stats, i)
		card.chosen.connect(_choose)
		_cards.append(card)
		card.modulate.a = 0.0
		var tween := card.create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(0.08 * i)

	_build_loadout(stats)
	_root.show()
	get_tree().paused = true
	_is_open = true
	_accept_input_at = Time.get_ticks_msec() + INPUT_GRACE_MS


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		var index := key.physical_keycode - KEY_1
		if index >= 0 and index < _cards.size():
			get_viewport().set_input_as_handled()
			_choose(_cards[index].upgrade)


func _choose(upgrade: UpgradeData) -> void:
	if not _is_open or Time.get_ticks_msec() < _accept_input_at:
		return
	_is_open = false
	_root.hide()
	get_tree().paused = false
	upgrade_chosen.emit(upgrade)


func _build_loadout(stats: PlayerStats) -> void:
	for child in _loadout_row.get_children():
		child.queue_free()
	var weapon_icon := TextureRect.new()
	PixelUI.fit_integer(weapon_icon, stats.weapon.icon, Vector2(96, 32))
	weapon_icon.tooltip_text = stats.weapon.display_name
	_loadout_row.add_child(weapon_icon)
	for upgrade in stats.unique_upgrades():
		_loadout_row.add_child(PixelUI.make_upgrade_badge(upgrade, stats.stack_count(upgrade)))
