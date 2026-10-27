extends SceneTree
## Bakes the arena into editable scenes (re-run to regenerate; hand edits
## made afterwards in the editor are kept until the next bake).
##   godot --headless --path <project> --script art_src/tools/build_arena_scenes.gd
##
## Output:
##   scenes/arena/arena_ground.tscn  - floor tiles, flat decor, boundary walls
##   scenes/arena/arena_props.tscn   - y-sorted fence, forest, obstacles, fireflies

const TILE := 16
## Fence ring, in tiles (inclusive). Playable area is inside it.
const FENCE_L := -27
const FENCE_R := 27
const FENCE_T := -17
const FENCE_B := 16
const SEED := 38

const PLAINS := "res://assets/mystic forest/sprites/tilesets/plains.png"
const GRASS := "res://assets/mystic forest/sprites/tilesets/grass.png"
const TUFTS := "res://assets/mystic forest/sprites/tilesets/decor_16x16.png"
const FENCES := "res://assets/mystic forest/sprites/tilesets/fences.png"
const OBJECTS := "res://assets/mystic forest/sprites/objects/objects.png"
const DECOR := "res://assets/floor38/arena/arena_decor.png"
const FIREFLY := "res://assets/floor38/arena/firefly.png"
const SWAY := "res://shaders/wind_sway.gdshader"

enum Src { PLAINS, GRASS, TUFTS }
## Dirt autotile inside plains.png: 3x3 patch plus inner corners (the
## grass blob at the (4..5, 0..1) junction). Keys name where GRASS is.
const DIRT := {
	"tl": Vector2i(1, 0), "t": Vector2i(2, 0), "tr": Vector2i(3, 0),
	"l": Vector2i(1, 1), "c": Vector2i(2, 1), "r": Vector2i(3, 1),
	"bl": Vector2i(1, 2), "b": Vector2i(2, 2), "br": Vector2i(3, 2),
	"in_br": Vector2i(4, 0), "in_bl": Vector2i(5, 0),
	"in_tr": Vector2i(4, 1), "in_tl": Vector2i(5, 1),
}
## Dirt clearings: centre (tiles) and radii (tiles). Edges are noise-warped.
const CLEARINGS := [
	[Vector2(0, 0), Vector2(6.5, 4.5)],
	[Vector2(-18, -10), Vector2(3.5, 2.6)],
	[Vector2(16, -11), Vector2(3.2, 2.4)],
	[Vector2(-15, 10), Vector2(4.0, 2.6)],
	[Vector2(18, 9), Vector2(3.6, 2.8)],
	[Vector2(-23, 1), Vector2(2.4, 3.2)],
]
## Worn paths from the central clearing (tile coords).
const PATHS := [
	[Vector2(0, 0), Vector2(-18, -10)],
	[Vector2(0, 0), Vector2(18, 9)],
	[Vector2(0, 0), Vector2(0, -17)],
	[Vector2(0, 0), Vector2(-27, 3)],
]
## Props are copied out of objects.png into a padded atlas: the pack sheet
## packs them against opaque watermark rows that bleed in at non-integer
## window scales. "source" = rect in objects.png, "region" = rect in ours.
const PROPS_ATLAS := "res://assets/floor38/arena/forest_props.png"
const TREE := { "source": Rect2i(0, 80, 48, 64), "region": Rect2(2, 2, 48, 64), "foot": Vector2(24, 62) }
const TALL_BUSH := { "source": Rect2i(128, 96, 32, 48), "region": Rect2(54, 2, 32, 48), "foot": Vector2(16, 46) }
const BUSH := { "source": Rect2i(96, 112, 32, 32), "region": Rect2(90, 2, 32, 32), "foot": Vector2(16, 30) }
const STUMP := { "source": Rect2i(160, 112, 32, 32), "region": Rect2(126, 2, 32, 32), "foot": Vector2(16, 24) }
const ROCK := { "source": Rect2i(0, 16, 16, 16), "region": Rect2(162, 2, 16, 16), "foot": Vector2(8, 14) }

## arena_decor.png frame indices.
enum Decor { WHITE, YELLOW, PINK, BLUE, MUSHROOM, PEBBLES, TUFT, TUFT_SMALL, CLOVER, LEAVES, STONES, TWIG }

## Hand-placed obstacles inside the fence (world px).
const STUMPS := [Vector2(-296, -152), Vector2(282, -176), Vector2(-232, 168), Vector2(312, 136), Vector2(-120, -210)]
const ROCKS := [Vector2(104, 200), Vector2(-372, 40), Vector2(388, -40), Vector2(170, -120), Vector2(-150, 110)]

var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var dirt_cells := {}


func _initialize() -> void:
	rng.seed = SEED
	noise.seed = SEED
	noise.frequency = 0.08
	DirAccess.make_dir_recursive_absolute("res://scenes/arena")
	DirAccess.make_dir_recursive_absolute("res://resources/arena")
	if "--atlas" in OS.get_cmdline_user_args():
		_make_props_atlas()
		quit()
		return
	_build_ground()
	_build_props()
	print("arena baked")
	quit()


# --- Ground -----------------------------------------------------------------

func _build_ground() -> void:
	var tileset := _ground_tileset()
	var root := Node2D.new()
	root.name = "ArenaGround"

	# Forest floor fades darker in two steps away from the clearing.
	var far := _layer("ForestFloorFar", tileset, root, Color(0.55, 0.66, 0.62))
	var near := _layer("ForestFloorNear", tileset, root, Color(0.78, 0.86, 0.8))
	var ground := _layer("Ground", tileset, root, Color.WHITE)
	for x in range(-44, 45):
		for y in range(-30, 31):
			_grass(far, Vector2i(x, y))
	for x in range(FENCE_L - 2, FENCE_R + 3):
		for y in range(FENCE_T - 2, FENCE_B + 3):
			_grass(near, Vector2i(x, y))
	for x in range(FENCE_L, FENCE_R + 1):
		for y in range(FENCE_T, FENCE_B + 1):
			_grass(ground, Vector2i(x, y))
	_paint_dirt(ground)

	var decor := Node2D.new()
	decor.name = "Decor"
	root.add_child(decor)
	_scatter_decor(decor)
	_add_walls(root)
	_save(root, "res://scenes/arena/arena_ground.tscn")


func _ground_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	var plains := _atlas(PLAINS, DIRT.values())
	var grass := _atlas(GRASS, [Vector2i.ZERO])
	var tufts := _atlas(TUFTS, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	tileset.add_source(plains, Src.PLAINS)
	tileset.add_source(grass, Src.GRASS)
	tileset.add_source(tufts, Src.TUFTS)
	ResourceSaver.save(tileset, "res://resources/arena/ground_tileset.tres")
	return load("res://resources/arena/ground_tileset.tres")


func _atlas(path: String, coords: Array) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(path)
	source.texture_region_size = Vector2i(TILE, TILE)
	for c in coords:
		source.create_tile(c)
	return source


func _layer(layer_name: String, tileset: TileSet, parent: Node, tint: Color) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.modulate = tint
	parent.add_child(layer)
	return layer


## Mostly plain grass; tufted tiles cluster where the noise is high.
func _grass(layer: TileMapLayer, cell: Vector2i) -> void:
	var lush := noise.get_noise_2dv(Vector2(cell))
	if rng.randf() < 0.06 + maxf(lush, 0.0) * 0.45:
		layer.set_cell(cell, Src.TUFTS, Vector2i(rng.randi_range(0, 3), 0))
	else:
		layer.set_cell(cell, Src.GRASS, Vector2i.ZERO)


func _paint_dirt(layer: TileMapLayer) -> void:
	var cells := {}
	for clearing in CLEARINGS:
		var center: Vector2 = clearing[0]
		var radius: Vector2 = clearing[1]
		for x in range(int(center.x - radius.x) - 3, int(center.x + radius.x) + 4):
			for y in range(int(center.y - radius.y) - 3, int(center.y + radius.y) + 4):
				var d := ((Vector2(x, y) - center) / radius).length()
				if d + noise.get_noise_2d(x * 3.0, y * 3.0) * 0.35 < 1.0:
					cells[Vector2i(x, y)] = true
	for path in PATHS:
		var from: Vector2 = path[0]
		var to: Vector2 = path[1]
		var steps := int(from.distance_to(to) * 2.0)
		var normal := (to - from).normalized().orthogonal()
		for i in steps + 1:
			var t := float(i) / steps
			var p := from.lerp(to, t) + normal * sin(t * PI * 2.0 + from.x) * 2.0
			for ox in range(-1, 2):
				for oy in range(-1, 2):
					cells[Vector2i(roundi(p.x) + ox, roundi(p.y) + oy)] = true
	# Keep everything inside the fence with a grass margin.
	for cell in cells.keys():
		if cell.x <= FENCE_L + 1 or cell.x >= FENCE_R - 1 or cell.y <= FENCE_T + 1 or cell.y >= FENCE_B - 1:
			cells.erase(cell)
	cells = _open(cells)
	for cell in cells:
		layer.set_cell(cell, Src.PLAINS, DIRT[_dirt_key(cells, cell)])
		dirt_cells[cell] = true


## Morphological opening (3x3): every dirt cell ends up inside a solid 3x3
## block, so there are no 1-2 tile slivers the autotile can't draw.
func _open(cells: Dictionary) -> Dictionary:
	var eroded := {}
	for cell in cells:
		var solid := true
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				if not cells.has(cell + Vector2i(ox, oy)):
					solid = false
		if solid:
			eroded[cell] = true
	var opened := {}
	for cell in eroded:
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				opened[cell + Vector2i(ox, oy)] = true
	return opened


func _dirt_key(cells: Dictionary, c: Vector2i) -> String:
	var n := cells.has(c + Vector2i.UP)
	var s := cells.has(c + Vector2i.DOWN)
	var w := cells.has(c + Vector2i.LEFT)
	var e := cells.has(c + Vector2i.RIGHT)
	if not n:
		return "tl" if not w else ("tr" if not e else "t")
	if not s:
		return "bl" if not w else ("br" if not e else "b")
	if not w:
		return "l"
	if not e:
		return "r"
	if not cells.has(c + Vector2i(1, -1)):
		return "in_tr"
	if not cells.has(c + Vector2i(-1, -1)):
		return "in_tl"
	if not cells.has(c + Vector2i(1, 1)):
		return "in_br"
	if not cells.has(c + Vector2i(-1, 1)):
		return "in_bl"
	return "c"

func _scatter_decor(parent: Node2D) -> void:
	var texture: Texture2D = load(DECOR)
	var flowers := [Decor.WHITE, Decor.YELLOW, Decor.PINK, Decor.BLUE]
	# Inside the fence: jittered grid, flowers bunch up in lush areas.
	for gx in range(FENCE_L * TILE + 8, FENCE_R * TILE, 24):
		for gy in range(FENCE_T * TILE + 12, FENCE_B * TILE, 24):
			var pos := Vector2(gx + rng.randi_range(-8, 8), gy + rng.randi_range(-8, 8))
			if pos.distance_to(Vector2(13, 0)) < 40.0:
				continue
			var on_dirt := dirt_cells.has(Vector2i((pos / TILE).floor()))
			var lush := noise.get_noise_2dv(pos / TILE)
			var frame := -1
			if on_dirt:
				if rng.randf() < 0.22:
					frame = [Decor.PEBBLES, Decor.LEAVES, Decor.TWIG, Decor.PEBBLES][rng.randi() % 4]
			elif lush > 0.15 and rng.randf() < 0.55:
				# One flower colour per patch reads as natural growth.
				frame = flowers[int(absf(noise.get_noise_2dv(pos / 90.0) * 40.0)) % flowers.size()]
			elif rng.randf() < 0.16:
				frame = [Decor.CLOVER, Decor.LEAVES, Decor.PEBBLES, Decor.MUSHROOM, Decor.STONES, Decor.TWIG, Decor.CLOVER][rng.randi() % 7]
			if frame >= 0:
				_decor_sprite(parent, texture, frame, pos, Color.WHITE)
	# Forest floor litter, dimmed to sit in the trees' shade.
	for i in 140:
		var pos := Vector2(rng.randf_range(-560, 580), rng.randf_range(-380, 420))
		if _inside_fence(pos, 12.0):
			continue
		var frame: int = [Decor.LEAVES, Decor.TWIG, Decor.CLOVER, Decor.MUSHROOM, Decor.STONES][rng.randi() % 5]
		_decor_sprite(parent, texture, frame, pos, Color(0.6, 0.68, 0.64))


func _decor_sprite(parent: Node2D, texture: Texture2D, frame: int, pos: Vector2, tint: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.region_rect = Rect2(frame * 16, 0, 16, 16)
	sprite.position = pos.round()
	sprite.flip_h = rng.randf() < 0.5
	sprite.modulate = tint
	parent.add_child(sprite)


func _add_walls(parent: Node) -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var inner := Rect2(
		Vector2(FENCE_L * TILE + 8, FENCE_T * TILE + 10),
		Vector2((FENCE_R - FENCE_L) * TILE, (FENCE_B - FENCE_T) * TILE - 8))
	var thick := 200.0
	var rects := [
		Rect2(inner.position.x - thick, inner.position.y - thick, inner.size.x + thick * 2, thick),
		Rect2(inner.position.x - thick, inner.end.y, inner.size.x + thick * 2, thick),
		Rect2(inner.position.x - thick, inner.position.y, thick, inner.size.y),
		Rect2(inner.end.x, inner.position.y, thick, inner.size.y),
	]
	for i in rects.size():
		var shape := CollisionShape2D.new()
		shape.name = "Wall%d" % i
		var rect := RectangleShape2D.new()
		rect.size = rects[i].size
		shape.shape = rect
		shape.position = rects[i].get_center()
		body.add_child(shape)


func _inside_fence(pos: Vector2, margin: float) -> bool:
	return pos.x > FENCE_L * TILE - margin and pos.x < (FENCE_R + 1) * TILE + margin \
		and pos.y > FENCE_T * TILE - margin and pos.y < (FENCE_B + 1) * TILE + margin


# --- Props (y-sorted with the player and enemies) ---------------------------

func _build_props() -> void:
	var root := Node2D.new()
	root.name = "ArenaProps"
	root.y_sort_enabled = true
	_add_fence(root)

	var objects: Texture2D = load(PROPS_ATLAS)
	var tree_mat := _sway(64.0, 1.0, 1.1)
	var bush_mat := _sway(32.0, 0.8, 1.6)
	var tuft_mat := _sway(14.0, 1.0, 2.2)

	var forest := Node2D.new()
	forest.name = "Forest"
	forest.y_sort_enabled = true
	root.add_child(forest)
	# Bushes hug the outside of the fence, trees stand behind them.
	_bush_line(forest, objects, bush_mat)
	_forest(forest, objects, tree_mat)

	var obstacles := Node2D.new()
	obstacles.name = "Obstacles"
	obstacles.y_sort_enabled = true
	root.add_child(obstacles)
	for pos in STUMPS:
		_obstacle(obstacles, objects, STUMP, pos, 8.0)
	for pos in ROCKS:
		_obstacle(obstacles, objects, ROCK, pos, 6.0)

	var tufts := Node2D.new()
	tufts.name = "Tufts"
	tufts.y_sort_enabled = true
	root.add_child(tufts)
	_scatter_tufts(tufts, tuft_mat)

	_add_fireflies(root)
	_save(root, "res://scenes/arena/arena_props.tscn")


func _add_fence(parent: Node) -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	# fences.png: (1,0)/(3,0)/(1,2)/(3,2) corners, (2,3) horizontal, (0,1) vertical.
	var coords := [Vector2i(1, 0), Vector2i(3, 0), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(0, 1)]
	var source := _atlas(FENCES, coords)
	for c in coords:
		# Sort by the post's base rather than the cell centre.
		source.get_tile_data(c, 0).y_sort_origin = 6
	tileset.add_source(source, 0)
	ResourceSaver.save(tileset, "res://resources/arena/fence_tileset.tres")
	var layer := TileMapLayer.new()
	layer.name = "Fence"
	layer.tile_set = load("res://resources/arena/fence_tileset.tres")
	layer.y_sort_enabled = true
	parent.add_child(layer)
	for x in range(FENCE_L + 1, FENCE_R):
		layer.set_cell(Vector2i(x, FENCE_T), 0, Vector2i(2, 3))
		layer.set_cell(Vector2i(x, FENCE_B), 0, Vector2i(2, 3))
	for y in range(FENCE_T + 1, FENCE_B):
		layer.set_cell(Vector2i(FENCE_L, y), 0, Vector2i(0, 1))
		layer.set_cell(Vector2i(FENCE_R, y), 0, Vector2i(0, 1))
	layer.set_cell(Vector2i(FENCE_L, FENCE_T), 0, Vector2i(1, 0))
	layer.set_cell(Vector2i(FENCE_R, FENCE_T), 0, Vector2i(3, 0))
	layer.set_cell(Vector2i(FENCE_L, FENCE_B), 0, Vector2i(1, 2))
	layer.set_cell(Vector2i(FENCE_R, FENCE_B), 0, Vector2i(3, 2))


func _sway(height: float, strength: float, speed: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SWAY)
	mat.set_shader_parameter("height", height)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("speed", speed)
	return mat


func _prop(parent: Node, texture: Texture2D, def: Dictionary, pos: Vector2, mat: Material = null) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.region_rect = def.region
	sprite.centered = false
	sprite.offset = -def.foot
	sprite.position = pos.round()
	sprite.flip_h = rng.randf() < 0.5
	sprite.material = mat
	parent.add_child(sprite)
	return sprite


func _bush_line(parent: Node, texture: Texture2D, mat: Material) -> void:
	var left := FENCE_L * TILE - 6.0
	var right := (FENCE_R + 1) * TILE + 6.0
	var top := FENCE_T * TILE - 4.0
	var bottom := (FENCE_B + 1) * TILE + 18.0
	var x := left - 16.0
	while x < right + 16.0:
		_prop(parent, texture, BUSH if rng.randf() < 0.7 else TALL_BUSH, Vector2(x, top + rng.randf_range(-3, 2)), mat)
		_prop(parent, texture, BUSH, Vector2(x + 10.0, bottom + rng.randf_range(0, 4)), mat)
		x += rng.randf_range(18, 26)
	var y := top + 14.0
	while y < bottom:
		_prop(parent, texture, BUSH if rng.randf() < 0.6 else TALL_BUSH, Vector2(left - rng.randf_range(4, 10), y), mat)
		_prop(parent, texture, BUSH if rng.randf() < 0.6 else TALL_BUSH, Vector2(right + rng.randf_range(4, 10), y), mat)
		y += rng.randf_range(16, 22)


func _forest(parent: Node, texture: Texture2D, mat: Material) -> void:
	var row := 0
	var y := -360.0
	while y < 430.0:
		var x := -560.0 + (17.0 if row % 2 else 0.0)
		while x < 580.0:
			var pos := Vector2(x + rng.randf_range(-7, 7), y + rng.randf_range(-5, 5))
			# Clear the fence + bush line; below the arena keep canopies off it.
			var keep_out := Rect2(FENCE_L * TILE - 40, FENCE_T * TILE - 18, (FENCE_R - FENCE_L + 1) * TILE + 80, (FENCE_B - FENCE_T + 1) * TILE + 18 + 64)
			if not keep_out.has_point(pos):
				var tree := _prop(parent, texture, TREE, pos, mat)
				var shade := rng.randf_range(0.82, 1.0)
				tree.modulate = Color(shade * 0.96, shade, shade * 0.95)
			x += rng.randf_range(30, 38)
		y += rng.randf_range(22, 28)
		row += 1


func _obstacle(parent: Node, texture: Texture2D, def: Dictionary, pos: Vector2, radius: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	var sprite := _prop(body, texture, def, Vector2.ZERO)
	sprite.name = "Sprite"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = Vector2(0, -3)
	body.add_child(shape)


func _scatter_tufts(parent: Node, mat: Material) -> void:
	var texture: Texture2D = load(DECOR)
	var placed := 0
	var attempts := 0
	while placed < 70 and attempts < 2000:
		attempts += 1
		var pos := Vector2(rng.randf_range(FENCE_L * TILE + 16, FENCE_R * TILE), rng.randf_range(FENCE_T * TILE + 20, FENCE_B * TILE))
		if dirt_cells.has(Vector2i((pos / TILE).floor())) or pos.distance_to(Vector2(13, 0)) < 48.0:
			continue
		if noise.get_noise_2dv(pos / TILE) < -0.05:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_filter_clip_enabled = true
		var frame: int = Decor.TUFT if rng.randf() < 0.55 else Decor.TUFT_SMALL
		sprite.region_rect = Rect2(frame * 16, 0, 16, 16)
		sprite.centered = false
		sprite.offset = Vector2(-8, -14)
		sprite.position = pos.round()
		sprite.flip_h = rng.randf() < 0.5
		sprite.material = mat
		parent.add_child(sprite)
		placed += 1


func _add_fireflies(parent: Node) -> void:
	var particles := GPUParticles2D.new()
	particles.name = "Fireflies"
	particles.z_index = 9
	particles.position = Vector2(8, 0)
	particles.amount = 46
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.texture = load(FIREFLY)
	# HDR tint so the glow pass picks them up.
	particles.self_modulate = Color(2.4, 2.2, 1.3)
	particles.visibility_rect = Rect2(-600, -400, 1200, 800)
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.particles_animation = true
	canvas_mat.particles_anim_h_frames = 2
	canvas_mat.particles_anim_v_frames = 1
	canvas_mat.particles_anim_loop = true
	particles.material = canvas_mat

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(470, 300, 0)
	process.direction = Vector3(0, -1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 7.0
	process.gravity = Vector3.ZERO
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 3.0
	process.turbulence_noise_scale = 6.0
	process.anim_speed_min = 0.6
	process.anim_speed_max = 2.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex
	particles.process_material = process
	parent.add_child(particles)


func _make_props_atlas() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(OBJECTS))
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create_empty(180, 68, false, Image.FORMAT_RGBA8)
	for def in [TREE, TALL_BUSH, BUSH, STUMP, ROCK]:
		atlas.blit_rect(source, def.source, Vector2i(def.region.position))
	atlas.save_png(ProjectSettings.globalize_path(PROPS_ATLAS))
	print("props atlas written")


# --- Saving -----------------------------------------------------------------

func _save(root: Node, path: String) -> void:
	_own(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		push_error("pack failed for %s" % path)
	ResourceSaver.save(scene, path)
	root.free()


func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)
