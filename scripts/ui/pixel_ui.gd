class_name PixelUI
extends RefCounted
## Helpers for showing pixel art in UI at whole-number scales only.


static var _cropped: Dictionary = {}


## Sizes `rect` to the largest integer multiple of `texture` that fits in
## `max_size`, so pixel art never gets uneven pixels. Transparent padding
## (the gun pack ships generous canvases) is trimmed first.
static func fit_integer(rect: TextureRect, texture: Texture2D, max_size: Vector2) -> void:
	texture = cropped(texture)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	if texture == null:
		rect.custom_minimum_size = Vector2.ZERO
		return
	var tex_size := texture.get_size()
	var factor := maxf(1.0, floorf(minf(max_size.x / tex_size.x, max_size.y / tex_size.y)))
	rect.custom_minimum_size = tex_size * factor


## Returns `texture` trimmed to its opaque pixels (cached).
static func cropped(texture: Texture2D) -> Texture2D:
	if texture == null or texture is AtlasTexture:
		return texture
	if _cropped.has(texture):
		return _cropped[texture]
	var used := texture.get_image().get_used_rect()
	var result: Texture2D = texture
	if used.size != Vector2i(texture.get_size()) and used.size != Vector2i.ZERO:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(used)
		result = atlas
	_cropped[texture] = result
	return result


## Small icon with a stack counter, used for the upgrade loadout rows.
static func make_upgrade_badge(upgrade: UpgradeData, count: int, icon_scale := 2) -> Control:
	var badge := TextureRect.new()
	fit_integer(badge, upgrade.icon, Vector2.ONE * 16.0 * icon_scale)
	badge.tooltip_text = upgrade.title
	if count > 1:
		var label := Label.new()
		label.text = "x%d" % count
		label.add_theme_font_size_override(&"font_size", 13)
		label.add_theme_constant_override(&"outline_size", 5)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		label.position += Vector2(4, 4)
		badge.add_child(label)
	return badge
