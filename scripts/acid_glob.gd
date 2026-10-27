class_name AcidGlob
extends Node2D
## Spitter attack. The node sits at the landing point (where the warning
## marker is drawn); the glob itself arcs in from the spitter.

const GLOB := preload("res://assets/floor38/fx/acid_glob.png")
const SPLAT := preload("res://assets/floor38/fx/acid_splat.png")
const MARKER := preload("res://assets/floor38/fx/target_marker.png")
const FLIGHT_TIME := 0.9
const ARC_HEIGHT := 26.0
const SPLASH_RADIUS := 11.0

var damage := 12.0
var _start_offset := Vector2.ZERO
var _elapsed := 0.0
var _landed := false

var _marker: AnimatedSprite2D
var _glob: AnimatedSprite2D


static func launch(from: Vector2, to: Vector2, splash_damage: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var parent := tree.get_first_node_in_group(&"projectile_layer")
	if parent == null:
		parent = tree.current_scene
	var glob := AcidGlob.new()
	glob.damage = splash_damage
	glob._start_offset = from - to
	parent.add_child(glob)
	glob.global_position = to


func _ready() -> void:
	_marker = AnimatedSprite2D.new()
	_marker.sprite_frames = SpriteSheetUtil.strip(MARKER, Vector2i(16, 8), 8.0, true)
	_marker.play()
	add_child(_marker)
	_glob = AnimatedSprite2D.new()
	_glob.sprite_frames = SpriteSheetUtil.strip(GLOB, Vector2i(8, 8), 8.0, true)
	_glob.play()
	_glob.position = _start_offset
	_glob.z_index = 5
	add_child(_glob)


func _process(delta: float) -> void:
	if _landed:
		return
	_elapsed += delta
	var t := minf(1.0, _elapsed / FLIGHT_TIME)
	_glob.position = _start_offset.lerp(Vector2.ZERO, t) + Vector2(0.0, -ARC_HEIGHT * 4.0 * t * (1.0 - t))
	if t >= 1.0:
		_land()


func _land() -> void:
	_landed = true
	Sound.play(&"acid_splat", global_position)
	_glob.queue_free()
	_marker.queue_free()
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player and player.global_position.distance_to(global_position) <= SPLASH_RADIUS + 4.0:
		player.take_damage(damage)
	var splat := AnimatedSprite2D.new()
	splat.sprite_frames = SpriteSheetUtil.strip(SPLAT, Vector2i(16, 8), 8.0, false)
	add_child(splat)
	splat.play()
	splat.animation_finished.connect(queue_free)
