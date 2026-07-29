class_name Cutscene extends Control
## Crownless' illustrated storybook player.
##
## Ordinary quests keep using Hud.dialogue() exactly as before. Class and
## first-entry chapter openers mount this full-screen layer beneath the existing
## CQ dialogue chrome. Story cues play authored, identity-locked paintings as
## living storybook plates with a slow camera track and cross-dissolves.

const FRAME_ROOT := "res://assets/sprites/opening/"
const FRAME_SEQUENCES := {
	"crown": [
		"opening_crown_0",
		"opening_crown_1",
		"opening_crown_2",
	],
	"road": [
		"opening_warrior_0",
		"opening_warrior_1",
	],
	"aftermath": ["opening_warrior_2"],
	"camp": [
		"opening_assassin_0",
		"opening_assassin_1",
	],
	"camp_cold": ["opening_assassin_2"],
	"sickbed": [
		"opening_mage_0",
		"opening_mage_1",
	],
	"sickbed_wrong": ["opening_mage_2"],
	"homestead": [
		"opening_archer_0",
		"opening_archer_1",
	],
	"severed": ["opening_archer_2"],
	"hearing": [
		"opening_paladin_0",
		"opening_paladin_1",
	],
	"verdict": ["opening_paladin_2"],
	"tome": [
		"opening_warlock_0",
		"opening_warlock_1",
	],
	"tome_open": ["opening_warlock_2"],
}

const CHAPTER_CLASSES := [
	"warrior", "assassin", "mage", "archer", "paladin", "warlock",
]
const CHAPTER_SHARED_CUES := {
	"shatter": "ch2",
	"vale": "ch3",
	"foundry": "ch4",
	"sledge": "ch5",
	"bloom": "ch6",
	"relay": "ch7",
	"ashfall": "ch8",
	"drowned": "ch9",
	"singing_ice": "ch10",
	"two_fires": "ch11",
	"roothold": "ch12",
	"storm_scar": "ch13",
	"convergence": "ch14",
}

# Every cue Story.CONVOS may reference (autotest validates against this).
const KNOWN_CUES := [
	"crown", "road", "aftermath", "camp", "camp_cold",
	"sickbed", "sickbed_wrong", "homestead", "severed", "hearing", "verdict",
	"tome", "tome_open", "fade",
]

const FRAME_DISSOLVE := 0.82
const FRAME_HOLD := 1.55
const CAMERA_START_SCALE := Vector2(1.012, 1.012)
const CAMERA_END_SCALE := Vector2(1.042, 1.042)
const CAMERA_TRACK_X := 7.0

var game: Game
var art_stack: Control
var ash: CPUParticles2D
var fade_rect: ColorRect

var _frame_cache: Dictionary = {}
var _frame_material: ShaderMaterial
var _sequence_tween: Tween = null
var _finish_started := false


func _init(g: Node2D) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.012, 0.009, 0.02)
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	art_stack = Control.new()
	art_stack.size = size
	art_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_stack)

	# Generated painted plates are authored in display-referred sRGB. This
	# Forward+ canvas is intentionally linear, which otherwise crushes them to
	# near-black in-game even though the source PNG previews correctly. Sample
	# the texture once, lift it back to display space, and reuse ONLY COLOR.a
	# (COLOR already contains the texture sample; multiplying it would square
	# the image and darken it again — see the canvas-item shader trap).
	var frame_shader := Shader.new()
	frame_shader.code = """
shader_type canvas_item;

void fragment() {
	// Keep every plate subtly alive even after its authored camera move ends.
	// The built-in overscan prevents the breathing crop from exposing an edge.
	float breath = 1.016 + sin(TIME * 0.31) * 0.003;
	vec2 drift = vec2(sin(TIME * 0.17), cos(TIME * 0.13)) * 0.0018;
	vec2 story_uv = (UV - vec2(0.5)) / breath + vec2(0.5) + drift;
	vec4 source = texture(TEXTURE, story_uv);
	vec3 display_rgb = min(pow(max(source.rgb, vec3(0.0)), vec3(0.48)) * 1.04, vec3(1.0));
	float light_breathe = 0.985 + 0.018 * sin(TIME * 0.41 + UV.x * 2.7);
	COLOR = vec4(display_rgb * light_breathe, COLOR.a);
}
"""
	_frame_material = ShaderMaterial.new()
	_frame_material.shader = frame_shader

	# A few slow motes bind the painted frames together. Plate progression,
	# opposing camera tracks, cross-dissolves, and the shader's near-imperceptible
	# breathing crop make this opener feel illustrated rather than slideshow-like.
	ash = CPUParticles2D.new()
	ash.amount = 24
	ash.lifetime = 4.2
	ash.position = Vector2(640, 390)
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(650, 330)
	ash.direction = Vector2(0, -1)
	ash.spread = 34.0
	ash.gravity = Vector2(4, -7)
	ash.initial_velocity_min = 4.0
	ash.initial_velocity_max = 13.0
	ash.scale_amount_min = 0.7
	ash.scale_amount_max = 1.6
	ash.color = Color(0.95, 0.72, 0.34, 0.38)
	add_child(ash)

	var wash := ColorRect.new()
	wash.color = Color(0.018, 0.012, 0.035, 0.10)
	wash.size = size
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var vignette := TextureRect.new()
	vignette.texture = Art.tex("vignette")
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.size = size
	vignette.modulate = Color(1, 1, 1, 0.62)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# The last narration fades into darkness, not back to visible gameplay
	# beneath the still-open dialogue box.
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.008, 0.006, 0.014, 0.0)
	fade_rect.size = size
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)

	modulate.a = 0.0
	var intro := create_tween()
	intro.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro.tween_property(self, "modulate:a", 1.0, 0.38)


func _ready() -> void:
	game.hud.set_cinematic(true)


func _exit_tree() -> void:
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.set_cinematic(false)


func cue(id: String) -> void:
	if id == "fade":
		_fade_out()
		return
	var frame_names: Array = _frames_for_cue(id)
	if frame_names.is_empty():
		return
	_play_sequence(frame_names)
	_tint_motes(id)


static func is_known_cue(id: String) -> bool:
	if id in KNOWN_CUES or id == "crown_hollow":
		return true
	if CHAPTER_SHARED_CUES.has(id):
		return true
	for shared_cue in CHAPTER_SHARED_CUES:
		if id.begins_with(String(shared_cue) + "_") \
				and id.trim_prefix(String(shared_cue) + "_") in CHAPTER_CLASSES:
			return true
	return false


static func _frames_for_cue(id: String) -> Array:
	if FRAME_SEQUENCES.has(id):
		return FRAME_SEQUENCES[id]
	if id == "crown_hollow":
		return ["chapters/opening_ch14_2"]
	if CHAPTER_SHARED_CUES.has(id):
		var chapter_id: String = String(CHAPTER_SHARED_CUES[id])
		return [
			"chapters/opening_%s_0" % chapter_id,
			"chapters/opening_%s_1" % chapter_id,
		]
	for shared_cue in CHAPTER_SHARED_CUES:
		var prefix := String(shared_cue) + "_"
		if id.begins_with(prefix):
			var class_id := id.trim_prefix(prefix)
			if class_id in CHAPTER_CLASSES:
				var chapter_id: String = String(CHAPTER_SHARED_CUES[shared_cue])
				return ["chapters/opening_%s_%s" % [chapter_id, class_id]]
	return []


## Fade the complete opener away after the branching conversation resolves.
func finish(cb: Callable) -> void:
	if _finish_started:
		return
	_finish_started = true
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 0.0, 0.46)
	tw.tween_callback(func() -> void:
		queue_free()
		if cb.is_valid():
			cb.call())


# ---------------------------------------------------------- frame player ---

func _play_sequence(frame_names: Array) -> void:
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	_collapse_stack()

	_sequence_tween = create_tween()
	_sequence_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_sequence_tween.set_trans(Tween.TRANS_SINE)
	_sequence_tween.set_ease(Tween.EASE_IN_OUT)

	for frame_index in range(frame_names.size()):
		var frame_name: String = String(frame_names[frame_index])
		var texture: Texture2D = _frame_texture(String(frame_name))
		if texture == null:
			continue
		var frame := _make_frame(texture)
		frame.modulate.a = 0.0
		var track_direction := -1.0 if frame_index % 2 == 0 else 1.0
		frame.position.x += CAMERA_TRACK_X * track_direction
		frame.scale = CAMERA_START_SCALE
		art_stack.add_child(frame)

		# Each authored plate dissolves over its predecessor while tracking in the
		# opposite direction. Shared chapter cues therefore read as two connected
		# story beats; one-plate class cues still have a deliberate moving hold.
		var move_duration := FRAME_DISSOLVE + FRAME_HOLD
		_sequence_tween.tween_property(frame, "modulate:a", 1.0, FRAME_DISSOLVE)
		_sequence_tween.parallel().tween_property(
			frame, "scale", CAMERA_END_SCALE, move_duration)
		_sequence_tween.parallel().tween_property(
			frame, "position:x",
			frame.position.x - CAMERA_TRACK_X * track_direction * 2.0,
			move_duration)
		_sequence_tween.tween_interval(FRAME_HOLD)


func _frame_texture(frame_name: String) -> Texture2D:
	if _frame_cache.has(frame_name):
		return _frame_cache[frame_name]
	var path := FRAME_ROOT + frame_name + ".png"
	if not ResourceLoader.exists(path):
		push_warning("Opening frame missing: " + path)
		_frame_cache[frame_name] = null
		return null
	var texture: Texture2D = load(path)
	_frame_cache[frame_name] = texture
	return texture


func _make_frame(texture: Texture2D) -> TextureRect:
	var frame := TextureRect.new()
	frame.texture = texture
	# A tiny overscan leaves room for the push without exposing an edge.
	frame.position = Vector2(-10, -6)
	frame.size = Vector2(1300, 732)
	frame.pivot_offset = frame.size / 2.0
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.material = _frame_material
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


## A player may advance the prose before a multi-frame sequence completes.
## Freeze the most-visible plate as the next dissolve's base and discard the
## unfinished stack, preventing a late tween from drawing over the new cue.
func _collapse_stack() -> void:
	var keep_texture: Texture2D = null
	var children := art_stack.get_children()
	for idx in range(children.size() - 1, -1, -1):
		var frame := children[idx] as TextureRect
		if frame != null and frame.texture != null and frame.modulate.a >= 0.45:
			keep_texture = frame.texture
			break
	if keep_texture == null and not children.is_empty():
		var fallback := children.back() as TextureRect
		if fallback != null:
			keep_texture = fallback.texture
	for child in children:
		child.queue_free()
	if keep_texture != null:
		var base := _make_frame(keep_texture)
		base.modulate.a = 1.0
		base.scale = CAMERA_END_SCALE
		art_stack.add_child(base)


func _tint_motes(id: String) -> void:
	if id in ["camp", "camp_cold", "sickbed", "sickbed_wrong"]:
		ash.color = Color(0.48, 0.92, 0.55, 0.34)
	elif id in ["tome", "tome_open"]:
		ash.color = Color(0.68, 0.43, 1.0, 0.34)
	elif id in ["homestead", "severed"]:
		ash.color = Color(1.0, 0.88, 0.55, 0.32)
	else:
		ash.color = Color(0.95, 0.62, 0.28, 0.36)


func _fade_out() -> void:
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade_rect, "color:a", 0.88, 0.9)
	tw.parallel().tween_property(art_stack, "modulate:a", 0.22, 0.9)
	tw.parallel().tween_property(ash, "modulate:a", 0.0, 0.7)
