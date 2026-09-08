extends Sprite2D
## Shared companion art: square horizontal cells keep their full height.
const ORDER := ["spore_pup", "hearth_hopper", "cinder_bat", "ash_crow", "glimmerwing", "pale_flutter"]
static var _portraits: Dictionary = {}
static var _sizes: Dictionary = {}
static var _feet: Dictionary = {}
var age := 0.0
var flying := false
var home := Vector2.ZERO
var _base_offset := Vector2.ZERO
var _motion_clip := false
var _frame_clock := 0.0
var _id := ""


func setup(id: String) -> void:
	var pet: Dictionary = Skins.find_pet(id)
	if pet.is_empty():
		return
	var base := String(pet.sprite)
	var anim: Dictionary = Art.anim_info(base)
	_id = id
	var motion_path := "res://assets/sprites/companion_%s_walk.png" % id
	_motion_clip = ORDER.has(id) and ResourceLoader.exists(motion_path)
	texture = load(motion_path) if _motion_clip else (portrait(id) if ORDER.has(id) else anim.get("tex", Art.tex(base)))
	hframes = 8 if _motion_clip else (1 if ORDER.has(id) else int(anim.get("frames", 1)))
	if not ORDER.has(id) and anim.is_empty() and texture != null and texture.get_width() > texture.get_height() * 2:
		hframes = maxi(1, texture.get_width() / texture.get_height())
	if texture == null:
		return
	if not _sizes.has(id):
		_sizes[id] = Art.scale_for_alpha_height(texture, Balance.PET_BODY_HEIGHT, hframes)
		_feet[id] = Art.alpha_feet_offset(texture, 1.0, hframes)
	scale = _sizes[id]
	_base_offset = Vector2(0, -float(_feet[id]))
	offset = _base_offset
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flying = id in ["cinder_bat", "ash_crow", "glimmerwing", "pale_flutter"]
	set_meta("pet_id", id)


func animate(delta: float, moving := false, speed := 0.0) -> void:
	age += delta
	if _motion_clip:
		if flying or moving:
			var fps: float = Balance.PET_MOTION_FPS.get(_id, Balance.PET_ANIM_FPS)
			if not flying and speed > 0.0:
				fps *= clampf(speed / Balance.PET_STRIDE_SPEED, 0.4, 1.6)
			_frame_clock += delta * fps
			frame = int(_frame_clock) % hframes
		else:
			frame = 0
			_frame_clock = 0.0
	else:
		frame = int(age * Balance.PET_ANIM_FPS) % hframes
	# The walking cycle supplies limb motion. Only hovering/breathing and the
	# frog's flight arc add a small positional offset; no moving portrait bob.
	var bob: float = sin(age * 5.0) * Balance.PET_HOVER_BOB if flying else sin(age * 3.0) * Balance.PET_REST_BOB
	if _motion_clip and moving and not flying:
		bob = -sin(float(frame) / 7.0 * PI) * Balance.PET_HOP_HEIGHT if _id == "hearth_hopper" else 0.0
	offset = _base_offset + Vector2(0, (bob - (Balance.PET_HOVER_HEIGHT if flying else 0.0)) / maxf(scale.y, 0.001))


## Both local and remote companions use the same movement and stride clock.
func follow(owner_position: Vector2, delta: float) -> void:
	var target: Vector2 = owner_position + Balance.PET_FOLLOW_OFFSET
	var delta_pos: Vector2 = target - global_position
	var previous: Vector2 = global_position
	if delta_pos.length() > Balance.PET_WARP_DISTANCE:
		global_position = target
		previous = target
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-delta * Balance.PET_FOLLOW_SPEED))
	if absf(delta_pos.x) > Balance.PET_TURN_THRESHOLD:
		flip_h = delta_pos.x < 0.0
	var speed: float = global_position.distance_to(previous) / maxf(delta, 0.001)
	animate(delta, speed > Balance.PET_STOP_SPEED, speed)


static func portrait(id: String) -> Texture2D:
	if not ORDER.has(id):
		return null
	if not _portraits.has(id):
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/sprites/companion_atlas.png")
		var cell := atlas.atlas.get_size() / Vector2(3, 2)
		var index: int = ORDER.find(id)
		atlas.region = Rect2(Vector2(index % 3, index / 3) * cell, cell)
		atlas.filter_clip = true
		_portraits[id] = atlas
	return _portraits[id]
