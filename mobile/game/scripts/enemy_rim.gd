extends Sprite2D
## Independent light pass: never replace the body's flash/tell/status material.
## Child transform + inherited alpha preserve squash, spawn/death fades and
## visibility. RGB modulation is deliberately ignored by the additive shader.

const RIM_SHADER := preload("res://shaders/enemy_rim.gdshader")
var actor: Node2D
var source: Sprite2D
var boss_rim := false
var _terrain := ""
var _strength_ready := false
# Last values pushed to the material: each push is a RenderingServer update.
var _uv_rect := Vector4(-1.0, -1.0, -1.0, -1.0)
var _width_px := -1.0
# kind -> wears the boss rim without being a Boss (see wears_boss_rim).
static var _decoy_kinds := {}


static func attach(entity: Node2D, body: Sprite2D) -> Sprite2D:
	# Explicit hostile opt-in: NPCs, pets, allies, critters and training dummies
	# cannot acquire a rim even if a caller offers their sprite here.
	if not entity is Enemy or entity is Dummy:
		return null
	var rim := new()
	rim.name = "EnemyRim"
	rim.actor = entity
	rim.source = body
	rim.boss_rim = wears_boss_rim(entity)
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = RIM_SHADER
	mat.set_shader_parameter("rim_color", Balance.ENEMY_RIM_COLOR)
	rim.material = mat
	body.add_child(rim)
	rim.sync()
	return rim


static func strength(terrain: String, boss: bool) -> float:
	# Same per-room tint luminance proxy as Game._zone_light_mult. Do not use
	# cur_room: an adjacent room's enemy and a guest mirror need their own floor.
	var tint: Color = Terrains.get_terrain(terrain)["tint"]
	var lum := (tint.r + tint.g + tint.b) / 3.0
	var response := 1.0 - smoothstep(Balance.ENEMY_RIM_DARK_LUMA, Balance.ENEMY_RIM_BRIGHT_LUMA, lum)
	return Balance.ENEMY_RIM_STRENGTH * response * (Balance.ENEMY_RIM_BOSS_MULT if boss else 1.0)


## Bosses get the stronger rim, and so do their look-alike decoys: a kind that
## a boss def lists in "summons" while wearing that boss's own sprite (Echo's
## Unnaming copies). A dimmer edge on the copies would point out the real one.
static func wears_boss_rim(entity: Node2D) -> bool:
	if entity is Boss:
		return true
	var kind := String(entity.kind)
	if not _decoy_kinds.has(kind):
		var own: Dictionary = Story.ALL_ENEMIES.get(kind, {})
		var decoy := false
		for def: Dictionary in Story.ALL_ENEMIES.values():
			if own.has("sprite") and bool(def.get("boss", false)) \
					and kind in def.get("summons", []) and def.get("sprite") == own["sprite"]:
				decoy = true
				break
		_decoy_kinds[kind] = decoy
	return _decoy_kinds[kind]


func _ready() -> void:
	# Pure presentation: a headless world (the --server authority, test suites)
	# never draws it, so it skips the per-frame follow; tests call sync(). Set
	# here, after the engine's READY step turns processing on for _process.
	set_process(not Enemy._is_headless())


func _process(_delta: float) -> void:
	# A hidden body (burrowed, dev-morph driver) hides this child as well.
	if source.is_visible_in_tree():
		sync()


func sync() -> void:
	texture = source.texture
	# Guarded copies: these setters redraw/relayout even when nothing changed.
	if hframes != source.hframes:
		hframes = source.hframes
	if vframes != source.vframes:
		vframes = source.vframes
	if frame != source.frame:
		frame = source.frame
	if flip_h != source.flip_h:
		flip_h = source.flip_h
	if flip_v != source.flip_v:
		flip_v = source.flip_v
	if centered != source.centered:
		centered = source.centered
	if offset != source.offset:
		offset = source.offset
	region_enabled = source.region_enabled
	region_rect = source.region_rect
	# self_modulate is not inherited, unlike modulate (whose alpha comes through
	# the parent). A body hidden this way must not leave a floating luminous edge.
	self_modulate = Color(1, 1, 1, source.self_modulate.a)
	var uv_size := Vector2.ONE / Vector2(hframes, vframes)
	var uv_start := Vector2(frame_coords) * uv_size
	if region_enabled and texture != null:
		uv_start = (region_rect.position + Vector2(frame_coords) * region_rect.size * uv_size) / texture.get_size()
		uv_size *= region_rect.size / texture.get_size()
	var uv_rect := Vector4(uv_start.x, uv_start.y, uv_start.x + uv_size.x, uv_start.y + uv_size.y)
	if uv_rect != _uv_rect:
		_uv_rect = uv_rect
		material.set_shader_parameter("frame_uv_rect", uv_rect)
	# The shader measures in framebuffer pixels. canvas_items stretch draws the
	# 1280x720 canvas at the window's own resolution, so scale the Balance width
	# by the stretch (1.5 at 1080p, 2 at 1440p) to keep it the same share of the
	# body at every window size. Camera zoom stays out of it on purpose.
	var vp := get_viewport()  # null outside the tree
	var stretch: float = 1.0 if vp == null else vp.get_final_transform().get_scale().y
	var width := Balance.ENEMY_RIM_OFFSET_PX * stretch
	if width != _width_px:
		_width_px = width
		material.set_shader_parameter("rim_offset_px", width)
	var terrain := ""
	if actor.game != null:
		var zi: int = actor.game.room_at_pos(actor.global_position)
		if zi < 0:
			zi = actor.zone_idx
		if zi >= 0 and zi < actor.game.terrain_by_zone.size():
			terrain = actor.game.terrain_by_zone[zi]
	if terrain != _terrain or not _strength_ready:
		_terrain = terrain
		_strength_ready = true
		material.set_shader_parameter("rim_strength", strength(terrain, boss_rim))
