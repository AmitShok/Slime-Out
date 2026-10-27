class_name SpriteSheetUtil
extends RefCounted
## Builds SpriteFrames from the pack's sprite sheets at runtime, so each
## weapon/enemy is configured by data instead of hand-made frame lists.


static var _strip_cache: Dictionary = {}


## SpriteFrames with a single "default" animation from a horizontal strip.
static func strip(texture: Texture2D, frame_size: Vector2i, fps: float, loop: bool) -> SpriteFrames:
	var key := [texture, fps, loop]
	if _strip_cache.has(key):
		return _strip_cache[key]
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	frames.set_animation_loop(&"default", loop)
	for texture_frame in slice(texture, frame_size):
		frames.add_frame(&"default", texture_frame)
	_strip_cache[key] = frames
	return frames


static func slice(texture: Texture2D, frame_size: Vector2i, row := 0, count := -1) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if texture == null:
		return frames
	var columns := texture.get_width() / frame_size.x
	if count < 0:
		count = columns
	for i in mini(count, columns):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(i * frame_size.x, row * frame_size.y), frame_size)
		frames.append(atlas)
	return frames


static func add_animation(frames: SpriteFrames, anim: StringName, textures: Array[Texture2D], fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for texture in textures:
		frames.add_frame(anim, texture)


static func duration(frames: SpriteFrames, anim: StringName) -> float:
	if not frames.has_animation(anim):
		return 0.0
	var total := 0.0
	for i in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	return total / frames.get_animation_speed(anim)
