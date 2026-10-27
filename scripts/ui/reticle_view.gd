class_name ReticleView
extends Node2D
## Draws a crosshair from the player's crosshair settings. Used by the live
## in-game Reticle and by the preview on the options screen.
##
## Pieces are pixel art. "corner" styles mirror one piece into the four
## diagonals, "axis" styles rotate one piece in 90-degree steps - both stay
## pixel-perfect. Spin (optional) rotates the pieces freely.

const STYLES := {
	"brackets": { "piece": preload("res://assets/floor38/ui/reticle_bracket.png"), "layout": "corner", "gap": 3.0 },
	"round": { "piece": preload("res://assets/floor38/ui/reticle_arc.png"), "layout": "corner", "gap": 0.0 },
	"cross": { "piece": preload("res://assets/floor38/ui/reticle_tick.png"), "layout": "axis", "gap": 3.0 },
	"chevrons": { "piece": preload("res://assets/floor38/ui/reticle_chevron.png"), "layout": "axis", "gap": 3.0 },
	"dot": { "piece": null, "layout": "none", "gap": 0.0 },
}
const STYLE_NAMES := ["brackets", "round", "cross", "chevrons", "dot"]
const CENTERS := ["none", "dot", "plus", "ring"]
## reticle_center.png frames.
const CENTER_FRAME := { "dot": 0, "plus": 3, "ring": 5 }
const MENU_FRAME := 2
const CENTER_TEX := preload("res://assets/floor38/ui/reticle_center.png")
const HIT_TEX := preload("res://assets/floor38/ui/reticle_hit.png")
const RELOAD_TEX := preload("res://assets/floor38/ui/reticle_reload.png")
const CRIT_COLOR := Color("ffcd75")

## Extra gap in art pixels (spread, recoil, breathing...).
var extra_gap := 0.0
var color := Color.WHITE
var menu_mode := false
var pulse := false
var reload_progress := -1.0

var _spinner := Node2D.new()
var _pieces: Array[Sprite2D] = []
var _center := Sprite2D.new()
var _hit := Sprite2D.new()
var _reload := Sprite2D.new()
var _style: Dictionary
var _hit_left := 0.0


func _ready() -> void:
	add_child(_spinner)
	for i in 4:
		var piece := Sprite2D.new()
		_spinner.add_child(piece)
		_pieces.append(piece)
	_center.texture = CENTER_TEX
	_center.hframes = 7
	add_child(_center)
	_hit.texture = HIT_TEX
	_hit.visible = false
	add_child(_hit)
	_reload.texture = RELOAD_TEX
	_reload.hframes = 12
	_reload.visible = false
	add_child(_reload)
	Settings.changed.connect(_on_setting_changed)
	apply_settings()


func apply_settings() -> void:
	scale = Vector2.ONE * float(Settings.value(&"crosshair_size"))
	modulate.a = Settings.value(&"crosshair_opacity")
	_style = STYLES.get(Settings.value(&"crosshair_style"), STYLES["brackets"])
	for i in 4:
		var piece := _pieces[i]
		piece.texture = _style.piece
		piece.visible = _style.piece != null
		piece.flip_h = false
		piece.flip_v = false
		piece.rotation = 0.0
		if _style.layout == "corner":
			piece.centered = false
			piece.flip_h = i % 2 == 1
			piece.flip_v = i >= 2
		else:
			piece.centered = true
			piece.rotation = i * PI * 0.5
	if not bool(Settings.value(&"crosshair_spin")):
		_spinner.rotation = 0.0


func show_hit(is_crit: bool) -> void:
	if not Settings.value(&"crosshair_hit_marker"):
		return
	_hit_left = 0.1
	_hit.modulate = CRIT_COLOR if is_crit else Color.WHITE


func _process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	if Settings.value(&"crosshair_spin") and not menu_mode:
		_spinner.rotation += deg_to_rad(float(Settings.value(&"crosshair_spin_speed"))) * real_delta
	_hit_left -= real_delta
	_hit.visible = _hit_left > 0.0 and not menu_mode
	_layout()


func _layout() -> void:
	_spinner.visible = not menu_mode
	_reload.visible = reload_progress >= 0.0 and not menu_mode
	if _reload.visible:
		_reload.frame = clampi(int(reload_progress * 12.0), 0, 11)

	var center_style: String = Settings.value(&"crosshair_center")
	if _style.layout == "none" and center_style in ["none", "dot"]:
		center_style = "ring"  # the Dot style needs a centre big enough to see
	if menu_mode:
		_center.visible = true
		_center.frame = MENU_FRAME
		_center.modulate = Color.WHITE
		return
	_center.visible = center_style != "none"
	if _center.visible:
		var frame: int = CENTER_FRAME.get(center_style, 0)
		_center.frame = frame + (1 if pulse else 0)
	_center.modulate = color

	var gap := roundf(_style.gap + extra_gap)
	if _reload.visible and _style.layout != "none":
		gap = maxf(gap, 8.0)  # frame the reload ring instead of covering it
	for piece in _pieces:
		piece.modulate = Color(color, 0.45 if _reload.visible else 1.0)
	if _style.piece == null:
		return
	var size: Vector2 = _style.piece.get_size()
	if _style.layout == "corner":
		_pieces[0].position = Vector2(-gap - size.x, -gap - size.y)
		_pieces[1].position = Vector2(gap, -gap - size.y)
		_pieces[2].position = Vector2(-gap - size.x, gap)
		_pieces[3].position = Vector2(gap, gap)
	else:
		# Piece art points down (towards the centre) at the top position.
		var reach := gap + size.y * 0.5
		_pieces[0].position = Vector2(0, -reach)
		_pieces[1].position = Vector2(reach, 0)
		_pieces[2].position = Vector2(0, reach)
		_pieces[3].position = Vector2(-reach, 0)


func _on_setting_changed(key: StringName) -> void:
	if String(key).begins_with("crosshair"):
		apply_settings()
