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

# Chapter closers (CHAPTER_CLOSERS.md) — per-class illustrated end cutscenes.
# Each authored chapter derives three cue families the same way the openers
# derive <shared>_<class>: <ch>_finish_<class> and <ch>_reflect_<class> map to
# one class plate each, <ch>_fall to the shared fall plate. Plates live under
# closing/. Extend this list as closers are authored for later chapters.
const CLOSER_CHAPTERS := ["ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7"]
const CLOSER_ROOT := "closing/"

const FRAME_DISSOLVE := Balance.STORY_FRAME_DISSOLVE
const FRAME_HOLD := Balance.STORY_FRAME_HOLD
const CAMERA_START_SCALE := Balance.STORY_CAMERA_START_SCALE
const CAMERA_END_SCALE := Balance.STORY_CAMERA_END_SCALE
const CAMERA_TRACK_X := Balance.STORY_CAMERA_TRACK

# Normalized painting focus (zoom pivot), then camera travel toward the subject.
# Unlisted chapter/quest/closer plates retain the centered, alternating track.
const PLATE_MOTION := {
	"opening_crown_0": [Vector2(0.61, 0.62), Vector2(0.4, 0.0)], # empty throne
	"opening_crown_1": [Vector2(0.62, 0.24), Vector2(0.0, -0.7)], # hovering crown
	"opening_crown_2": [Vector2(0.62, 0.31), Vector2(0.0, -0.5)], # crowned apparition
	"opening_warrior_0": [Vector2(0.30, 0.43), Vector2(-0.7, 0.0)], # swordsman
	"opening_warrior_1": [Vector2(0.55, 0.50), Vector2(0.7, 0.0)], # strike arc
	"opening_warrior_2": [Vector2(0.34, 0.43), Vector2(-0.5, -0.2)], # survivor
	"opening_assassin_0": [Vector2(0.54, 0.59), Vector2(0.6, 0.2)], # campfire and hand
	"opening_assassin_1": [Vector2(0.43, 0.43), Vector2(-0.4, -0.3)], # tether at the chest
	"opening_assassin_2": [Vector2(0.46, 0.40), Vector2(0.4, -0.2)], # green vial
	"opening_mage_0": [Vector2(0.63, 0.55), Vector2(0.7, 0.1)], # healing hand
	"opening_mage_1": [Vector2(0.66, 0.57), Vector2(0.5, 0.1)], # sickbed glow
	"opening_mage_2": [Vector2(0.67, 0.56), Vector2(0.3, 0.0)], # altered patient
	"opening_archer_0": [Vector2(0.43, 0.30), Vector2(0.6, 0.0)], # thread between family
	"opening_archer_1": [Vector2(0.52, 0.30), Vector2(0.5, 0.0)], # taut thread
	"opening_archer_2": [Vector2(0.56, 0.43), Vector2(0.3, 0.4)], # falling severed thread
	"opening_paladin_0": [Vector2(0.37, 0.32), Vector2(-0.5, -0.2)], # listening paladin
	"opening_paladin_1": [Vector2(0.29, 0.40), Vector2(-0.6, 0.0)], # raised hammer and chain
	"opening_paladin_2": [Vector2(0.62, 0.45), Vector2(0.6, 0.1)], # chained petitioner
	"opening_warlock_0": [Vector2(0.58, 0.70), Vector2(0.5, 0.3)], # closed tome
	"opening_warlock_1": [Vector2(0.69, 0.56), Vector2(0.6, -0.2)], # opening pages
	"opening_warlock_2": [Vector2(0.69, 0.48), Vector2(0.3, -0.5)], # violet plume
}

var game: Game
var art_stack: Control
var ash: CPUParticles2D
var fade_rect: ColorRect

var _frame_cache: Dictionary = {}
var _sequence_tween: Tween = null
var _finish_started := false


func _init(g: Node2D) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.012, 0.009, 0.02)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	art_stack = Control.new()
	# Keep the authored 16:9 framing; anchors recenter it on viewport resize.
	art_stack.size = Vector2(1280, 720)
	art_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The camera push overscans the frame. Clip it here, as the screen edge
	# does at 16:9, so wider screens keep clean dark bars beside the art.
	art_stack.clip_contents = true
	add_child(art_stack)
	art_stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	# Render authored plates directly. Their source color is already correct;
	# camera tracks and cross-dissolves provide motion without color processing.
	# A few slow motes bind the painted frames together, so they share the
	# plates' centred, clipped frame instead of the full screen.
	var mote_frame := Control.new()
	mote_frame.size = art_stack.size
	mote_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mote_frame.clip_contents = true
	add_child(mote_frame)
	mote_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
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
	mote_frame.add_child(ash)

	var wash := ColorRect.new()
	wash.color = Color(0.018, 0.012, 0.035, 0.10)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vignette := TextureRect.new()
	vignette.texture = Art.tex("vignette")
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.modulate = Color(1, 1, 1, 0.62)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The last narration fades into darkness, not back to visible gameplay
	# beneath the still-open dialogue box.
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.008, 0.006, 0.014, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	modulate.a = 0.0
	var intro := create_tween()
	intro.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro.tween_property(self, "modulate:a", 1.0, 0.38)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		frame_names = _quest_frames(id)  # quest-event plates (per-class aware)
	if frame_names.is_empty():
		return
	_play_sequence(frame_names)
	_tint_motes(id)


## Quest-event illustration plates (2026-08-17): a cue `"q_<base>"` in a
## `cinematic` quest convo resolves to res://.../opening/quests/quest_<base>.png,
## and — when the quest earns per-class flavor — automatically prefers
## quests/quest_<base>_<class>.png if that file exists (the same "if the art
## exists" rule Art.has_sprite uses for optional painted overrides). Authoring a
## per-class plate is opt-in per class: drop the file and it takes over.
func _quest_frames(id: String) -> Array:
	if not id.begins_with("q_"):
		return []
	var base := id.substr(2)
	var cls := ""
	if is_instance_valid(game) and is_instance_valid(game.player):
		cls = String(game.player.cls)
	if cls != "":
		var per := "quests/quest_%s_%s" % [base, cls]
		if ResourceLoader.exists(FRAME_ROOT + per + ".png"):
			return [per]
	return ["quests/quest_" + base]


static func is_known_cue(id: String) -> bool:
	if id in KNOWN_CUES or id == "crown_hollow":
		return true
	if id.begins_with("q_") and id.length() > 2:
		return true  # quest-event plate family (quests/quest_<base>[_<class>])
	if CHAPTER_SHARED_CUES.has(id):
		return true
	for shared_cue in CHAPTER_SHARED_CUES:
		if id.begins_with(String(shared_cue) + "_") \
				and id.trim_prefix(String(shared_cue) + "_") in CHAPTER_CLASSES:
			return true
	for chapter_id in CLOSER_CHAPTERS:
		var ch := String(chapter_id)
		if id == ch + "_fall":
			return true
		for kind in ["finish", "reflect"]:
			var pfx := "%s_%s_" % [ch, kind]
			if id.begins_with(pfx) and id.trim_prefix(pfx) in CHAPTER_CLASSES:
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
	for closer_chapter in CLOSER_CHAPTERS:
		var ch := String(closer_chapter)
		if id == ch + "_fall":
			return [CLOSER_ROOT + "closing_%s_fall" % ch]
		for kind in ["finish", "reflect"]:
			var pfx := "%s_%s_" % [ch, kind]
			if id.begins_with(pfx):
				var cls := id.trim_prefix(pfx)
				if cls in CHAPTER_CLASSES:
					return [CLOSER_ROOT + "closing_%s_%s_%s" % [ch, cls, kind]]
	return []


## Fade the complete opener away after the branching conversation resolves.
func finish(cb: Callable) -> void:
	if _finish_started:
		return
	_finish_started = true
	# game.cutscene and the dialogue flags are already clear by now, so the HUD
	# needs this handle to keep menus and world input shut until the handoff.
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.cinematic_fade = self
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 0.0, 0.46)
	tw.tween_callback(func() -> void:
		queue_free()
		if cb.is_valid():
			cb.call())


## True from finish() until the fade hands off to its callback: the art still
## covers the screen and the callback (a chapter start, the victory card) has
## not run yet. Bounded by the fade, unlike cinematic mode, which a layer keeps
## until it leaves the tree.
func finishing() -> bool:
	return _finish_started and not is_queued_for_deletion()


# ---------------------------------------------------------- frame player ---

func _play_sequence(frame_names: Array) -> void:
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	# The camera continues from the painting that dominates the frozen picture.
	var anchor := _collapse_stack()

	_sequence_tween = create_tween()
	_sequence_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_sequence_tween.set_trans(Tween.TRANS_SINE)
	_sequence_tween.set_ease(Tween.EASE_IN_OUT)

	# The pose each new plate dissolves over: the retained painting's live pose,
	# then each plate's own end pose (its main move is over before the next
	# plate starts to dissolve).
	var has_prev := anchor != null
	var prev_position: Vector2 = anchor.position if has_prev else Vector2.ZERO
	var prev_pivot: Vector2 = anchor.pivot_offset if has_prev else Vector2.ZERO
	var prev_scale: Vector2 = anchor.scale if has_prev else Vector2.ONE
	var last_frame: TextureRect = null
	var last_track := Vector2.ZERO
	for frame_index in range(frame_names.size()):
		var frame_name: String = String(frame_names[frame_index])
		var texture: Texture2D = _frame_texture(String(frame_name))
		if texture == null:
			continue
		var frame := _make_frame(texture)
		frame.modulate.a = 0.0
		frame.scale = CAMERA_START_SCALE
		var rest := frame.position
		var start := rest
		var track := Vector2.ZERO
		if PLATE_MOTION.has(frame_name):
			var motion: Array = PLATE_MOTION[frame_name]
			frame.pivot_offset = frame.size * Vector2(motion[0])
			track = Vector2(motion[1]).limit_length()
		if has_prev:
			# Dissolve in register: this painting's center starts where the
			# previous pose drew its own, so a shared scene never doubles up.
			start = _registered_position(frame, prev_position, prev_pivot, prev_scale)
		if not PLATE_MOTION.has(frame_name):
			# Unlisted plates keep the centered horizontal recipe: each travels
			# back across its rest position, which alternates like the old
			# parity rule within a cue and stays bounded across cues.
			var side := signf(start.x - rest.x)
			if side == 0.0:
				side = -1.0 if frame_index % 2 == 0 else 1.0
			track = Vector2(side, 0.0)
		if not has_prev:
			start = rest + track * CAMERA_TRACK_X
		frame.position = _covering_position(frame, start, CAMERA_START_SCALE)
		var end := _covering_position(frame,
			frame.position - track * CAMERA_TRACK_X * 2.0, CAMERA_END_SCALE)
		art_stack.add_child(frame)
		last_frame = frame
		last_track = track

		# Preserve beat timing; only the painting's camera direction is authored.
		var move_duration := FRAME_DISSOLVE + FRAME_HOLD
		_sequence_tween.tween_property(frame, "modulate:a", 1.0, FRAME_DISSOLVE)
		_sequence_tween.parallel().tween_property(
			frame, "scale", CAMERA_END_SCALE, move_duration)
		_sequence_tween.parallel().tween_property(
			frame, "position", end, move_duration)
		_sequence_tween.tween_interval(FRAME_HOLD)
		has_prev = true
		prev_position = end
		prev_pivot = frame.pivot_offset
		prev_scale = CAMERA_END_SCALE

	# Continue alongside the final hold, then settle at a bounded endpoint.
	# This remains in the cue tween so advance/fade/finish cancel it together.
	if last_frame != null:
		_sequence_tween.parallel().tween_property(last_frame, "scale",
			Balance.STORY_READING_END_SCALE, Balance.STORY_READING_DRIFT_SECONDS)
		_sequence_tween.parallel().tween_property(last_frame, "position",
			_covering_position(last_frame,
				prev_position - last_track * Balance.STORY_READING_TRACK,
				Balance.STORY_READING_END_SCALE),
			Balance.STORY_READING_DRIFT_SECONDS)


## Where `frame` (pivot and scale already set) must sit so its painting center
## lands exactly where a plate at the given pose draws its own center. This is
## the registration the old alternating recipe had (end pose == next start).
func _registered_position(frame: TextureRect, at: Vector2, pivot: Vector2,
		zoom: Vector2) -> Vector2:
	var center := frame.size / 2.0
	var drawn := at + pivot + (center - pivot) * zoom
	return drawn - frame.pivot_offset - (center - frame.pivot_offset) * frame.scale


## Clamp a plate position so the painting, scaled by `zoom` about its pivot,
## still covers the clipped art frame. Position and scale tween together on
## one curve, so covering both ends of a move covers every frame between.
func _covering_position(frame: TextureRect, at: Vector2, zoom: Vector2) -> Vector2:
	var pivot := frame.pivot_offset
	return at.clamp(art_stack.size - pivot - (frame.size - pivot) * zoom,
		pivot * (zoom - Vector2.ONE))


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
	# Disable the source texture's minimum size before applying authored framing.
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# A tiny overscan leaves room for the push without exposing an edge.
	frame.position = Vector2(-10, -6)
	frame.size = Vector2(1300, 732)
	frame.pivot_offset = frame.size / 2.0
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


## A player may advance the prose before a multi-frame sequence completes.
## Freeze the picture exactly as it stands: every plate that still shows keeps
## its live position, scale, pivot and opacity, so the next cue dissolves over
## what was on screen (a half-finished blend stays a blend). Plates that cannot
## be seen, queued ones still at zero or ones fully covered from above, are
## discarded so no late tween draws over the new cue. Returns the plate that
## dominates the frozen picture, or null when nothing is showing yet.
func _collapse_stack() -> TextureRect:
	var anchor: TextureRect = null
	var anchor_weight := 0.0
	var uncovered := 1.0  # share of the picture no plate above has covered
	var children := art_stack.get_children()
	for idx in range(children.size() - 1, -1, -1):
		var child: Node = children[idx]
		var frame := child as TextureRect
		var weight := 0.0
		if frame != null and frame.texture != null:
			weight = frame.modulate.a * uncovered
		if weight < Balance.STORY_RETAIN_MIN_WEIGHT:
			art_stack.remove_child(child)
			child.queue_free()
			continue
		if weight > anchor_weight:
			anchor = frame
			anchor_weight = weight
		uncovered *= 1.0 - frame.modulate.a
	return anchor


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
