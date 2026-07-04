class_name Game extends Node2D
## The conductor. Builds the world as a ZONE GRAPH — rooms on a grid,
## connected N/S/E/W, built lazily on first entry — spawns the player,
## enemies, merchants and bosses, runs the story beats, and handles
## loot drops, death and victory.
##
## Rooms are the chapter's "zones" array (index = room id, still called
## zone_idx on enemies). Graph-authored rooms carry "coord"/"exits"
## (see Story.ZONES); legacy chapters without coords are auto-converted
## to a west→east chain and their positions rescaled to the room size.

const TILE := 48
const TILES_W := 44              # rooms grew: ~2 screens of walkable space
const TILES_H := 26
const ROOM_W := TILES_W * TILE   # 2112
const ROOM_H := TILES_H * TILE   # 1248
# Legacy zone-authoring space (Chapter 2 content modules): positions
# written for the old 34x15 strip get rescaled into the bigger rooms.
const LEGACY_W := 34 * TILE
const LEGACY_H := 15 * TILE
const DOOR_TILES := 3            # door gap width, in tiles
const DIRS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}

# ------------------------------------------------------------- chapters ---
# The world is data: Story.CHAPTER_LIST[chapter_id] decides the rooms,
# starting quest and final boss. switch_chapter() rebuilds everything.
var chapter_id := "ch1"
var zones: Array = []            # this chapter's room dicts
var zone_count := 0
var rooms: Array = []            # runtime graph meta per room:
                                 # {coord: Vector2i, exits: {dir: lock}, scale: Vector2, origin: Vector2}
var coord_to_room := {}          # Vector2i -> room index
var world: Node2D = null         # every world node lives under here

const ST_PLAYING := 0
const ST_DEAD := 2
const ST_VICTORY := 3

# (Zone tint and weather now come from the terrain registry — terrains.gd.)

var state := ST_PLAYING
var player: Player
var hud: Hud
var menus: Menus
var camera: Camera2D
var ambient: CanvasModulate
var reticle: Sprite2D
var reticle_label: Label

# Rebindable keys. Movement is always WASD/arrows; ESC is fixed.
var binds := {
	"a1": KEY_J, "a2": KEY_K, "a3": KEY_L, "ult": KEY_U,
	"potion": KEY_Q, "interact": KEY_E, "inventory": KEY_I, "skills": KEY_T,
	"codex": KEY_C, "target": KEY_TAB, "map": KEY_M,
}

var quest_key := "talk"
var talked_to_elder := false
var talk_cd := 0.0
var cur_room := 0                # the room the player occupies (only it simulates)
var last_room := -1              # previous frame's room (change detection)
var play_started := false

# ---------------------------------------------------------- room state ---
var built := {}                  # room idx -> true (world nodes exist)
var visited := {}                # room idx -> true (fog of war; saved)
var cleared := {}                # room idx -> true (packs dead; saved)
var door_seen := {}              # room idx -> true (its door was visible from
                                 # an adjacent visited room; boss marker on map)
var last_safe_room := 0          # death returns you here

var elder: Node2D
var interactables: Array = []    # [{node, prompt, action}]
var gates := {}                  # edge key "a_b" -> gate Node2D (locked edges only)
var zone_alive := {}             # room index -> monsters still alive
var boss_spawned := {}
var boss_done := {}
var bosses: Array = []           # every LIVE boss (endgame: up to 5 at once)
var current_boss: Boss = null    # the DISPLAYED boss: your target, else bosses[0]
var shop_stock := {}             # room index -> Array of items for sale

var shake_amt := 0.0
var sounds: Dictionary = {}
var sound_pool: Array = []
var loot_rng := RandomNumberGenerator.new()
var ambient_fx: CPUParticles2D = null
var npc_emote_t := 4.0
# Battle seals: while the current room is HOT (an aggroed pack or a live
# boss), every door of the room closes — no retreating mid-combat.
var door_seals: Array = []            # 4 pooled StaticBody2D, one per direction
var barrier_active := false

# ------------------------------------------------------ terrain system ---
var terrain_by_zone: Array = []       # terrain id per room
var zone_grounds := {}                # room idx -> ground Sprite2D (repaintable)
var zone_scenery := {}                # room idx -> decor + obstacle nodes
var hazards: Array = []               # active floor patches (lava/ice/...)
var terrain_event_t := 4.0            # countdown to the next terrain event
var hazard_tick := 0.0
var gust_vec := Vector2.ZERO          # sandstorm push applied to everyone
var gust_t := 0.0

# ---------------------------------------------------------- persistence ---
var save_slot := -1                   # active save file (-1 = none yet)
var no_saves := false                 # autotest: never touch real save files
var settings := {"music": 1.0, "sfx": 1.0, "fullscreen": false}  # user://settings.json
var music_gain_db := -16.0            # base+tune of the current track
var flags := {}                       # persistent story flags (saved)
var merchant_zones: Array = []        # rooms with a merchant present (saved)
var wander_seed := 0                  # per-character roll for seeded rooms (saved)
var cutscene: Cutscene = null         # active opening cinematic (if any)

# ------------------------------------------------------------ dev mode ---
var dev_mode := false                 # launched via dev_mode.bat (--dev)
var dev_god := false
var music_player: AudioStreamPlayer
var music_tracks: Dictionary = {}
var current_track := ""


func _ready() -> void:
	loot_rng.randomize()
	load_binds()
	Story.load_content()  # merge content modules before anything reads them
	dev_mode = "--dev" in OS.get_cmdline_user_args()
	zones = Story.chapter(chapter_id)["zones"]
	zone_count = zones.size()
	for zone in zones:
		terrain_by_zone.append(zone.get("terrain", "village"))
	_prepare_rooms()

	sounds = Sfx.build_all()
	# Sound overrides: any assets/sounds/<name>.wav or .ogg replaces the
	# synthesized effect of the same name (same idea as sprites).
	var snd_dir := DirAccess.open("res://assets/sounds")
	if snd_dir:
		for file in snd_dir.get_files():
			var full := ProjectSettings.globalize_path("res://assets/sounds/" + file)
			if file.ends_with(".wav"):
				var wav := Sfx.load_wav(full)
				if wav:
					sounds[file.get_basename()] = wav
			elif file.ends_with(".ogg"):
				var ogg := AudioStreamOggVorbis.load_from_file(full)
				if ogg:
					sounds[file.get_basename()] = ogg
	for i in 10:
		var sp := AudioStreamPlayer.new()
		sp.volume_db = -8.0
		add_child(sp)
		sound_pool.append(sp)

	# Background music: looping procedural chiptune, one per zone + boss.
	music_tracks = Music.build_all()
	# Music overrides: assets/music/<track>.ogg/.mp3/.wav replaces the
	# composed track of the same name, looped — same idea as sprites/sfx.
	var mus_dir := DirAccess.open("res://assets/music")
	if mus_dir:
		for file in mus_dir.get_files():
			var full := ProjectSettings.globalize_path("res://assets/music/" + file)
			var tune: Dictionary = MUSIC_TUNE.get(file.get_basename(), {})
			if file.ends_with(".ogg"):
				var ogg := AudioStreamOggVorbis.load_from_file(full)
				if ogg:
					ogg.loop = true
					ogg.loop_offset = float(tune.get("start", 0.0))
					music_tracks[file.get_basename()] = ogg
			elif file.ends_with(".mp3"):
				var mp3 := AudioStreamMP3.new()
				mp3.data = FileAccess.get_file_as_bytes(full)
				if not mp3.data.is_empty():
					mp3.loop = true
					mp3.loop_offset = float(tune.get("start", 0.0))
					music_tracks[file.get_basename()] = mp3
			elif file.ends_with(".wav"):
				var wav := Sfx.load_wav(full)
				if wav:
					wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
					wav.loop_end = wav.data.size() / (4 if wav.stereo else 2)
					music_tracks[file.get_basename()] = wav
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -16.0
	add_child(music_player)
	load_settings()
	apply_audio_settings()
	apply_display_settings()

	ambient = CanvasModulate.new()
	ambient.color = Terrains.get_terrain(terrain_by_zone[0])["tint"]
	add_child(ambient)

	world = Node2D.new()
	world.y_sort_enabled = true  # world children sort with the player
	add_child(world)
	_build_door_seals()

	player = Player.new()
	player.game = self
	player.global_position = _start_pos()
	add_child(player)

	reticle = Sprite2D.new()
	reticle.texture = Art.tex("reticle")
	reticle.scale = Vector2(2, 2)
	reticle.z_index = 25
	reticle.visible = false
	add_child(reticle)
	# Target's level floats above the lock-on brackets.
	reticle_label = Label.new()
	reticle_label.position = Vector2(-30, -24)
	reticle_label.size = Vector2(60, 14)
	reticle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle_label.scale = Vector2(0.5, 0.5)
	reticle_label.add_theme_font_size_override("font_size", 20)
	reticle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	reticle_label.add_theme_constant_override("outline_size", 6)
	reticle.add_child(reticle_label)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2(1.12, 1.12)  # slightly closer = chunkier pixels
	player.add_child(camera)
	camera.make_current()

	hud = Hud.new()
	hud.game = self
	add_child(hud)
	refresh_quest()

	menus = Menus.new()
	menus.game = self
	add_child(menus)

	# Build and enter the starting room (the rest of the graph is lazy).
	_enter_room(room_at_pos(player.global_position))

	# First: pick a class. Then the story begins.
	call_deferred("_start_flow")


func _start_flow() -> void:
	if no_saves or SaveGame.list().is_empty():
		menus.open_chapter_select()
	else:
		menus.open_title()


func on_class_chosen(id: String) -> void:
	player.set_class(id)
	wander_seed = randi() % 1000000  # seeds this character's layout + rolled rooms
	switch_chapter(chapter_id, true)  # lay out THIS run's world from the fresh seed
	if not no_saves:
		save_slot = SaveGame.next_free_slot()
	get_tree().paused = false
	var begin := func() -> void:
		play_started = true
		set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
		hud.flash_title(zones[cur_room]["name"], String(Story.chapter(chapter_id)["name"]))
		autosave()
	if Story.ALL_CONVOS.has("open_" + id):
		# Class openings replace the generic intro: a staged cinematic
		# plays under the words (cues in Story.CONVOS), and a choice
		# moves Resonance before Maren ever appears.
		set_flag("opened_" + id)
		cutscene = Cutscene.new(self)
		hud.add_child(cutscene)
		# Above the gameplay HUD (bars/quest/abilities), under the words.
		hud.move_child(cutscene, hud.dialogue_box.get_index())
		run_convo_id("open_" + id, func() -> void:
			if cutscene:
				var cs := cutscene
				cutscene = null
				cs.finish(begin)
			else:
				begin.call())
	else:
		hud.dialogue(Story.ALL_BEATS["intro"], begin)


## Resume a saved character: restore the player + story flags onto the
## freshly built world, then skip straight into play (no intro).
func load_save(slot: int) -> void:
	var data := SaveGame.read(slot)
	if data.is_empty():
		return
	save_slot = slot
	# The layout is a pure function of wander_seed: restore the seed
	# FIRST, then force-rebuild so the world matches the saved one.
	wander_seed = int(data.get("wander_seed", 0))
	switch_chapter(String(data.get("chapter", "ch1")), true)
	SaveGame.apply(self, data)
	get_tree().paused = false
	play_started = true
	set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.flash_title(zones[cur_room]["name"], "The tale continues")


## Rebuild the world state a save implies: mark dead bosses' rooms
## resolved and re-check every built gate against the restored flags
## and kills. (Unbuilt rooms evaluate their locks at build time.)
func reconcile_after_load() -> void:
	if talked_to_elder and not get_flag("met_elder", false):
		set_flag("met_elder")  # pre-graph saves stored only the bool
	for zi in zone_count:
		var kind: String = zones[zi].get("boss", "")
		if kind != "" and boss_done.get(kind, false):
			boss_spawned[zi] = true
			zone_alive[zi] = 0
			cleared[zi] = true
	_recheck_gates()
	refresh_quest()


## Open any built gate whose lock condition is now satisfied.
func _recheck_gates() -> void:
	for key in gates.keys():
		var parts: PackedStringArray = String(key).split("_")
		var a := int(parts[0])
		var b := int(parts[1])
		if _edge_unlocked(a, b):
			open_edge(a, b)


## The best gear grade this chapter can drop (act gating, DESIGN.md):
## Act 1 caps at C, Act 2 at A — S-tier is endgame loot only.
func loot_cap() -> String:
	return String(Story.chapter(chapter_id).get("loot_cap", "S"))


## (T7) Merchants read the shard: the steady get kinder prices, the
## tempted make the till nervous. Surfaced, never explained in numbers.
func band_price_mult() -> float:
	match Story.res_band(player.resonance):
		"steady": return 0.9
		"tempted": return 1.1
	return 1.0


## Write the current character to its slot. Called on story progress,
## zone changes, menu closes and window close — never mid-death.
func autosave() -> void:
	if save_slot > 0 and play_started and state == ST_PLAYING and not player.dead:
		SaveGame.write(self, save_slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave()


# ======================================================= conversation engine
# Branching dialogue with choices, resonance/faction shifts and story
# flags. Data format documented at Story.CONVOS.

func set_flag(flag_name: String, value = true) -> void:
	flags[flag_name] = value
	# Flag-locked gates: any built gate whose flag just got set unlocks.
	if value:
		_recheck_gates()


func get_flag(flag_name: String, def = false):
	return flags.get(flag_name, def)


func run_convo_id(id: String, on_done := Callable()) -> void:
	run_convo(Story.ALL_CONVOS[id], on_done)


func run_convo(convo: Dictionary, on_done := Callable()) -> void:
	_convo_node(convo, String(convo.get("start", "")), on_done)


func _convo_node(convo: Dictionary, node_id: String, on_done: Callable) -> void:
	var nodes: Dictionary = convo.get("nodes", {})
	if node_id == "" or not nodes.has(node_id):
		autosave()  # choices are story progress
		if on_done.is_valid():
			on_done.call()
		return
	var node: Dictionary = nodes[node_id]
	if cutscene and node.has("cue"):
		cutscene.cue(String(node["cue"]))  # stage the picture for this beat
	var who: String = node.get("who", "")
	# A matched variant can override the text AND the path: a variant
	# with its own "next" makes the node linear (choices are skipped) —
	# the short-circuit for "we already had this conversation" greetings.
	var variant := _convo_variant(node)
	var text: String = variant.get("text", node.get("text", ""))
	var next_id: String = String(variant.get("next", node.get("next", "")))
	var force_linear: bool = variant.has("next")
	if node.has("quest"):
		quest_key = String(node["quest"])
		refresh_quest()

	# Gate choices on flags / resonance band, then present or continue.
	var choices: Array = []
	for c in node.get("choices", []):
		if c.has("req_flag") and not flags.get(String(c["req_flag"]), false):
			continue
		if c.has("req_not_flag") and flags.get(String(c["req_not_flag"]), false):
			continue
		if c.has("req_band") and Story.res_band(player.resonance) != String(c["req_band"]):
			continue
		choices.append(c)
	if choices.is_empty() or force_linear:
		hud.dialogue([[who, text]], func() -> void:
			_convo_node(convo, next_id, on_done))
	else:
		var option_texts: Array = []
		for c in choices:
			option_texts.append(String(c["text"]))
		hud.dialogue_choice(who, text, option_texts, func(idx: int) -> void:
			var c: Dictionary = choices[idx]
			player.add_resonance(float(c.get("resonance", 0.0)))
			var fac_shifts: Dictionary = c.get("faction", {})
			for fac in fac_shifts:
				player.faction_standing[fac] = int(player.faction_standing.get(fac, 0)) + int(fac_shifts[fac])
			var set_flags: Dictionary = c.get("flags", {})
			for fname in set_flags:
				set_flag(fname, set_flags[fname])  # via set_flag: gates react
			if c.has("quest"):
				quest_key = String(c["quest"])
				refresh_quest()
			_convo_node(convo, String(c.get("next", "")), on_done))


## The FIRST matching variant wins (resonance band or story flag);
## empty dict = use the node's own text/next.
func _convo_variant(node: Dictionary) -> Dictionary:
	for v in node.get("variants", []):
		if v.has("band") and Story.res_band(player.resonance) == String(v["band"]):
			return v
		if v.has("flag") and flags.get(String(v["flag"]), false):
			return v
	return {}


# ==================================================================== options

## Volume settings, persisted separately from saves (they're per-player,
## not per-character).
func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for key in settings:
			if not data.has(key):
				continue
			if settings[key] is bool:
				settings[key] = bool(data[key])
			else:
				settings[key] = clampf(float(data[key]), 0.0, 1.0)


func save_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func _vol_db(linear: float) -> float:
	return -80.0 if linear <= 0.01 else linear_to_db(linear)


func apply_audio_settings() -> void:
	if music_player:
		music_player.volume_db = music_gain_db + _vol_db(float(settings["music"]))
	for sp in sound_pool:
		sp.volume_db = -8.0 + _vol_db(float(settings["sfx"]))


func apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"]
		else DisplayServer.WINDOW_MODE_WINDOWED)


## Replay a chapter from its beginning: the CHARACTER survives (build,
## gear, Resonance, opening history); the chapter's story state resets.
func replay_chapter(id: String) -> void:
	_wipe_chapter_flags()
	for fac in player.faction_standing:
		player.faction_standing[fac] = 0
	wander_seed = randi() % 1000000  # replays meet a fresh set of rolled rooms
	switch_chapter(id, true)
	play_started = true
	get_tree().paused = false
	set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.flash_title(zones[cur_room]["name"], String(Story.chapter(id)["name"]))
	autosave()


## Chapter PROGRESSION: the character who just won carries straight on
## into the next chapter — build, gear, Resonance, faction standings and
## choice history all intact. (Farming trips back go through
## replay_chapter, which resets standings; moving FORWARD keeps them.)
func advance_chapter() -> void:
	var next_ch := Story.next_chapter(chapter_id)
	if next_ch == "" or state != ST_VICTORY:
		return
	state = ST_PLAYING
	get_tree().paused = false
	hud.overlay.color = Color(0, 0, 0, 0)
	hud.title_label.modulate.a = 0.0
	hud.subtitle_label.modulate.a = 0.0
	_wipe_chapter_flags()  # last chapter's story state retires; history stays
	switch_chapter(next_ch, true)
	play_started = true
	set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.flash_title(zones[cur_room]["name"], String(Story.chapter(next_ch)["name"]))
	autosave()


# ------------------------------------------------- meta progression ---
# Account-wide unlocks that outlive characters (user://meta.json):
# finishing a chapter with ANY character opens the next one on the
# New Game chapter select.
const META_PATH := "user://meta.json"
var _meta: Dictionary = {}
var _meta_loaded := false


func _load_meta() -> void:
	if _meta_loaded:
		return
	_meta_loaded = true
	if no_saves or not FileAccess.file_exists(META_PATH):
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			_meta = data


func meta_unlock(chid: String) -> void:
	_load_meta()
	if bool(_meta.get("unlocked_" + chid, false)):
		return
	_meta["unlocked_" + chid] = true
	if no_saves:
		return  # tests never touch the real user files
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_meta))


## Progression gating for the chapter select: the first chapter is
## always open; each later one opens once the previous is finished —
## by ANY character (meta unlock) for New Game, or by THIS character
## (its completed_ flag) when replaying.
func chapter_available(chid: String, replay := false) -> bool:
	var ids: Array = Story.CHAPTER_LIST.keys()
	var i := ids.find(chid)
	if i <= 0 or dev_mode:
		return true
	_load_meta()
	if bool(_meta.get("unlocked_" + chid, false)):
		return true
	return replay and get_flag("completed_" + String(ids[i - 1]), false)


# Character history that survives a chapter replay: which opening you
# played, what you chose in it, and which chapters you have finished.
# Everything else is story state.
const KEPT_FLAG_PREFIXES := ["opened_", "chose_", "completed_"]
const KEPT_FLAGS := ["owned_the_harm", "excused_the_harm", "walked_away",
	"gave_back", "kept_taking", "fled_theft", "told_truth", "hid_truth",
	"left_silent", "said_farewell", "cut_clean", "walked_silent",
	"delivered_verdict", "spared_guilty", "recused", "closed_tome",
	"borrowed_more", "burned_pages"]

func _wipe_chapter_flags() -> void:
	var kept := {}
	for fname in flags:
		var keep: bool = String(fname) in KEPT_FLAGS
		for pre in KEPT_FLAG_PREFIXES:
			if String(fname).begins_with(pre):
				keep = true
		if keep:
			kept[fname] = flags[fname]
	flags = kept


## Back to the title screen (character select). Progress is saved; the
## whole scene reboots so every system starts clean.
func exit_to_title() -> void:
	autosave()
	get_tree().paused = false
	get_tree().reload_current_scene()


# =================================================================== keybinds

func save_binds() -> void:
	var f := FileAccess.open("user://keybinds.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(binds))


func load_binds() -> void:
	if not FileAccess.file_exists("user://keybinds.json"):
		return
	var f := FileAccess.open("user://keybinds.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for action in binds:
			if data.has(action):
				binds[action] = int(data[action])


# ==================================================================== world

## Tear the world down and rebuild it from another chapter's data.
## Only ever called before play starts (chapter select) or on load —
## dynamic entities (chests, pickups, projectiles) don't exist then.
func switch_chapter(id: String, force := false) -> void:
	if not Story.CHAPTER_LIST.has(id) or (id == chapter_id and not force):
		return
	chapter_id = id
	var chapter: Dictionary = Story.chapter(id)
	zones = chapter["zones"]
	zone_count = zones.size()

	if is_instance_valid(world):
		world.free()  # immediate: everything world-owned dies with it
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	move_child(world, player.get_index())  # draw under the hero again

	gates.clear()
	interactables.clear()
	zone_alive.clear()
	boss_spawned.clear()
	boss_done.clear()
	merchant_zones.clear()
	hazards.clear()
	zone_grounds.clear()
	zone_scenery.clear()
	shop_stock.clear()
	built.clear()
	visited.clear()
	cleared.clear()
	door_seen.clear()
	bosses.clear()
	current_boss = null
	elder = null
	barrier_active = false
	talked_to_elder = false
	last_room = -1
	gust_vec = Vector2.ZERO
	terrain_by_zone.clear()
	for zone in zones:
		terrain_by_zone.append(zone.get("terrain", "village"))
	_prepare_rooms()
	_build_door_seals()
	quest_key = String(chapter.get("start_quest", "talk"))

	player.global_position = _start_pos()
	last_safe_room = maxi(0, room_at_pos(player.global_position))
	_enter_room(last_safe_room)
	ambient.color = Terrains.get_terrain(terrain_by_zone[cur_room])["tint"]
	refresh_quest()


# ------------------------------------------------------- the room graph ---

## Build the runtime graph meta (grid coords, exits, locks, scales)
## from the chapter's room dicts. Chapters authored WITHOUT coords are
## legacy west→east strips: they become a one-row chain, and all their
## authored positions rescale from the old 34x15 zone into the room.
func _prepare_rooms() -> void:
	rooms.clear()
	coord_to_room.clear()
	edge_locks.clear()
	# Chapters with a SPINE get a seeded procedural layout instead of
	# their authored coords — every run is a different map.
	var spine: Array = Story.chapter(chapter_id).get("spine", [])
	if not spine.is_empty():
		_generate_layout(spine)
		return
	var graph := false
	for zone in zones:
		if zone.has("coord"):
			graph = true
			break
	for i in zone_count:
		var zone: Dictionary = zones[i]
		var meta := {}
		var exits := {}
		if graph:
			var c: Array = zone.get("coord", [i, 0])
			meta["coord"] = Vector2i(int(c[0]), int(c[1]))
			meta["scale"] = Vector2.ONE
			var locks: Dictionary = zone.get("locks", {})
			for dir in zone.get("exits", []):
				exits[String(dir)] = String(locks.get(dir, ""))
		else:
			meta["coord"] = Vector2i(i, 0)
			meta["scale"] = Vector2(float(ROOM_W) / LEGACY_W, float(ROOM_H) / LEGACY_H)
			if i > 0:
				exits["W"] = ""
			if i < zone_count - 1:
				# Old strip gate rule: the way east opens when this zone's
				# boss dies or its gate_flag is set.
				var lock := ""
				if String(zone.get("boss", "")) != "":
					lock = "boss"
				elif String(zone.get("gate_flag", "")) != "":
					lock = "flag:" + String(zone["gate_flag"])
				exits["E"] = lock
		meta["exits"] = exits
		meta["origin"] = Vector2(meta["coord"].x * ROOM_W, meta["coord"].y * ROOM_H)
		rooms.append(meta)
		coord_to_room[meta["coord"]] = i
	# Exits are declared one-sided; imply the reciprocal, and register
	# each locked edge with the room that owns the lock condition.
	for i in zone_count:
		var exits: Dictionary = rooms[i]["exits"]
		for dir in exits.keys():
			var nb := neighbor(i, dir)
			if nb < 0:
				push_warning("room %d: exit %s leads nowhere" % [i, dir])
				exits.erase(dir)
				continue
			var nexits: Dictionary = rooms[nb]["exits"]
			if not nexits.has(OPP[dir]):
				nexits[OPP[dir]] = ""
			var lock: String = exits[dir]
			if lock != "" and not edge_locks.has(_edge_key(i, nb)):
				edge_locks[_edge_key(i, nb)] = {"lock": lock, "own": i}


var edge_locks := {}   # edge key -> {"lock": "boss"/"clear"/"flag:x", "own": room idx}


## Seeded procedural layout (playtest round 3: "why is every run the
## same map?"). The spine (story-ordered boss path) walks the grid
## east with seeded N/S jogs — at most one vertical step per column,
## which makes the walk provably self-avoiding. Side rooms then attach
## to a seeded host of the SAME TERRAIN with a free edge (falling back
## to any placed room), so wings and dead ends land somewhere new each
## run. Pure function of wander_seed: saves reload the same world;
## replays and new characters roll a fresh one.
func _generate_layout(spine: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 31 + chapter_id.hash() % 100003
	var coord := {}                     # room idx -> Vector2i
	var room_exits: Array = []          # room idx -> {dir: lock}
	for i in zone_count:
		room_exits.append({})

	# --- the spine walk ---
	var at := Vector2i(0, 0)
	coord[int(spine[0])] = at
	var vertical_last := false
	for k in range(1, spine.size()):
		var dir := "E"
		if not vertical_last and rng.randf() < 0.45:
			dir = "N" if rng.randf() < 0.5 else "S"
		vertical_last = dir != "E"
		var prev := int(spine[k - 1])
		var cur := int(spine[k])
		at += Vector2i(DIRS[dir])
		coord[cur] = at
		room_exits[prev][dir] = String(zones[prev].get("lock_next", ""))
		room_exits[cur][OPP[dir]] = ""

	# --- side rooms attach to same-terrain hosts (then anyone) ---
	var placed: Array = spine.duplicate()
	var taken := {}
	for i in coord:
		taken[coord[i]] = true
	for i in zone_count:
		if coord.has(i):
			continue
		var cands: Array = []
		for pass_same in [true, false]:
			for p in placed:
				if pass_same and terrain_by_zone[int(p)] != terrain_by_zone[i]:
					continue
				for d in ["N", "S", "E", "W"]:
					if room_exits[int(p)].has(d):
						continue
					if not taken.has(coord[int(p)] + Vector2i(DIRS[d])):
						cands.append([int(p), d])
			if not cands.is_empty():
				break
		if cands.is_empty():
			push_warning("layout: no host found for room %d" % i)
			continue
		var pick: Array = cands[rng.randi_range(0, cands.size() - 1)]
		var host := int(pick[0])
		var host_dir := String(pick[1])
		coord[i] = coord[host] + Vector2i(DIRS[host_dir])
		taken[coord[i]] = true
		room_exits[host][host_dir] = ""
		room_exits[i][OPP[host_dir]] = ""
		placed.append(i)

	# --- write the runtime meta (same shape as the authored path) ---
	for i in zone_count:
		var meta := {"coord": coord[i], "scale": Vector2.ONE, "exits": room_exits[i],
			"origin": Vector2(coord[i].x * ROOM_W, coord[i].y * ROOM_H)}
		rooms.append(meta)
		coord_to_room[coord[i]] = i
	for i in zone_count:
		var exits: Dictionary = rooms[i]["exits"]
		for dir in exits.keys():
			var lock := String(exits[dir])
			var nb := neighbor(i, String(dir))
			if lock != "" and nb >= 0 and not edge_locks.has(_edge_key(i, nb)):
				edge_locks[_edge_key(i, nb)] = {"lock": lock, "own": i}


func _edge_key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]


func neighbor(i: int, dir: String) -> int:
	var c: Vector2i = rooms[i]["coord"]
	return int(coord_to_room.get(c + Vector2i(DIRS[dir]), -1))


func room_rect(i: int) -> Rect2:
	return Rect2(rooms[i]["origin"], Vector2(ROOM_W, ROOM_H))


# Small rooms (playtest round 6): every room still occupies one grid
# cell, but quiet rooms — a single NPC, a shrine, a lore dead end, an
# elite arena — shrink their walled playable area; short corridors
# connect the doorways to the cell edges.
const SMALL_INSET := Vector2(420.0, 246.0)


func room_inset(i: int) -> Vector2:
	if room_type(i) in ["social", "dead_end", "resonance", "merchant"]:
		return SMALL_INSET
	return Vector2.ZERO


## The walled, walkable area of a room (equals room_rect for full-size
## rooms). Cameras, spawns and clamps all use THIS rect.
func play_rect(i: int) -> Rect2:
	var ins := room_inset(i)
	return Rect2(rooms[i]["origin"] + ins, Vector2(ROOM_W, ROOM_H) - ins * 2.0)


## Map an authored in-room position into the playable rect — authored
## coordinates assume the full cell, so small rooms scale them down.
func room_pos(i: int, x: float, y: float) -> Vector2:
	var meta: Dictionary = rooms[i]
	var p: Vector2 = Vector2(x, y) * meta["scale"]
	var ins := room_inset(i)
	if ins != Vector2.ZERO:
		p = ins + p * (Vector2(ROOM_W, ROOM_H) - ins * 2.0) / Vector2(ROOM_W, ROOM_H)
	return meta["origin"] + p


func room_center(i: int) -> Vector2:
	return rooms[i]["origin"] + Vector2(ROOM_W, ROOM_H) / 2.0


## The room whose grid cell contains pos (-1 = outside the graph).
func room_at_pos(pos: Vector2) -> int:
	var c := Vector2i(floori(pos.x / ROOM_W), floori(pos.y / ROOM_H))
	return int(coord_to_room.get(c, -1))


## World position of the door on room i's `dir` edge.
func door_pos(i: int, dir: String) -> Vector2:
	var r := room_rect(i)
	match dir:
		"N": return Vector2(r.position.x + ROOM_W / 2.0, r.position.y)
		"S": return Vector2(r.position.x + ROOM_W / 2.0, r.end.y)
		"E": return Vector2(r.end.x, r.position.y + ROOM_H / 2.0)
	return Vector2(r.position.x, r.position.y + ROOM_H / 2.0)  # W


## The declared room type ("combat"/"boss"/"safe" derived when absent).
func room_type(i: int) -> String:
	var zone: Dictionary = zones[i]
	var t := String(zone.get("type", ""))
	if t != "":
		return t
	if String(zone.get("boss", "")) != "":
		return "boss"
	if not zone.get("enemies", []).is_empty():
		return "combat"
	return "safe"


## Is this room fully pacified (no living packs, boss dead or none)?
func room_pacified(i: int) -> bool:
	if built.get(i, false):
		if zone_alive.get(i, 0) > 0:
			return false
	elif not cleared.get(i, false) and not zones[i].get("enemies", []).is_empty():
		return false
	var kind: String = zones[i].get("boss", "")
	return kind == "" or boss_done.get(kind, false)


## Death returns you to rooms like these; the map can travel to them.
func room_safe(i: int) -> bool:
	return room_type(i) != "combat" and room_type(i) != "boss" and room_pacified(i)


## Map fast-travel rule: visited safe pockets, plus boss arenas after
## the kill. Combat rooms are never travel targets (DESIGN.md).
func travel_target(i: int) -> bool:
	if not visited.get(i, false) or i == cur_room:
		return false
	if room_type(i) == "boss":
		var kind: String = zones[i].get("boss", "")
		return kind != "" and boss_done.get(kind, false)
	return room_safe(i)


## Is a locked edge's condition met? (Unlocked edges return true.)
func _edge_unlocked(a: int, b: int) -> bool:
	var info: Dictionary = edge_locks.get(_edge_key(a, b), {})
	var lock := String(info.get("lock", ""))
	if lock == "":
		return true
	var own := int(info.get("own", a))
	if lock == "boss":
		var kind: String = zones[own].get("boss", "")
		return kind == "" or boss_done.get(kind, false)
	if lock == "clear":
		return room_pacified(own)
	if lock.begins_with("flag:"):
		return bool(get_flag(lock.substr(5), false))
	return true


## Where the player starts this chapter (start_pos is authored in the
## first room's local space).
func _start_pos() -> Vector2:
	var sp: Array = Story.chapter(chapter_id).get("start_pos", [280, 624])
	if rooms.is_empty():
		return Vector2(float(sp[0]), float(sp[1]))
	var meta: Dictionary = rooms[0]
	return meta["origin"] + Vector2(float(sp[0]), float(sp[1])) * meta["scale"]


# ------------------------------------------------ entering & building ---

## Make room i the live room: build it on first entry, clamp the camera
## to it, wake the mood, autosave. Only the live room simulates.
func _enter_room(i: int) -> void:
	if i < 0 or i >= zone_count:
		return
	_build_room(i)
	var first_visit: bool = not visited.get(i, false)
	visited[i] = true
	cur_room = i
	# Standing in a room, you can SEE its doors: neighbors go on the map
	# as stubs, and a seen boss door gets its marker.
	for dir in rooms[i]["exits"].keys():
		var nb := neighbor(i, dir)
		if nb >= 0:
			door_seen[nb] = true
	# Camera clamps to the PLAYABLE rect — small rooms read small, and
	# the empty margin outside their walls never shows.
	var r := play_rect(i)
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)
	if room_safe(i):
		last_safe_room = i
	var terrain := Terrains.get_terrain(terrain_by_zone[i])
	var tween := create_tween()
	tween.tween_property(ambient, "color", terrain["tint"], 1.0)
	_setup_ambient_fx(terrain_by_zone[i])
	terrain_event_t = randf_range(2.5, 5.0)
	var room_boss: Boss = null
	var rogue_boss := false
	for b in _live_bosses():
		var live_b: Boss = b
		if live_b.zone_idx == i:
			room_boss = live_b
		elif live_b.zone_idx < 0:
			rogue_boss = true
	if room_boss != null:
		# Walking back into a live arena: the fight's bar + music resume.
		current_boss = room_boss
		set_music(_boss_music())
		hud.show_boss_bar(room_boss.display_name)
	elif not rogue_boss:
		set_music(terrain.get("music", "village"))
	if play_started and first_visit:
		hud.flash_title(zones[i]["name"])
	refresh_quest()
	_try_spawn_boss(i)
	last_room = i
	autosave()  # autosave on every room transition (DESIGN.md)


## Build a room's world nodes on first entry (rooms build lazily).
func _build_room(i: int) -> void:
	if built.get(i, false):
		return
	built[i] = true
	var zone: Dictionary = zones[i]
	var meta: Dictionary = rooms[i]
	var origin: Vector2 = meta["origin"]

	var terrain := Terrains.get_terrain(terrain_by_zone[i])
	var ground := Sprite2D.new()
	ground.texture = Art.ground(terrain["ground"], terrain["path"], TILES_W, TILES_H,
		i * 1000 + 7, meta["exits"].keys())
	ground.centered = false
	ground.position = origin
	ground.scale = Vector2(3, 3)
	ground.z_index = -10
	world.add_child(ground)
	zone_grounds[i] = ground
	_spawn_patches(i)
	zone_scenery[i] = []
	_spawn_scenery(i)
	_build_room_walls(i)

	# Data-driven NPCs (content modules + Chapter 1 props/shrines):
	# {"sprite": "villager", "x": 500, "y": 330, "prompt": "E — Talk",
	#  "convo": "some_convo_id"}
	for npc_def in zone.get("npcs", []):
		var convo_id: String = npc_def["convo"]
		_make_npc(npc_def["sprite"],
			room_pos(i, npc_def["x"], npc_def["y"]),
			npc_def.get("prompt", "E — Talk"), func() -> void:
				run_convo_id(convo_id))

	# Elder Maren, the Chapter 1 quest giver in the village.
	if chapter_id == "ch1" and i == 0:
		elder = _make_npc("elder", origin + Vector2(660, 500), "E — Talk", func() -> void:
			if not talked_to_elder:
				talked_to_elder = true
				var after := func() -> void:
					set_flag("met_elder")  # unbars the village's east gate
					quest_key = "fangmaw"
					refresh_quest()
					autosave()
				if get_flag("opened_" + player.cls, false) and Story.ALL_CONVOS.has("maren_" + player.cls):
					run_convo_id("maren_" + player.cls, after)  # she read your opening choice
				else:
					hud.dialogue(Story.ALL_BEATS["elder"], after)
			else:
				hud.dialogue(Story.ALL_BEATS["elder_repeat"])
		)

	# Merchants: SAFE rooms with a merchant spot keep one from the start
	# (or one who already wandered in, restored from the save). Combat
	# rooms only get theirs through the post-clear arrival roll.
	if merchant_zones.has(i):
		_merchant_node(i)
	elif zone.has("merchant") and String(zone.get("boss", "")) == "" \
			and zone.get("enemies", []).is_empty():
		_spawn_merchant(i)

	# Room-type extras.
	var cache_tier := String(zone.get("cache", ""))
	if cache_tier != "" and not get_flag(_cache_flag(i), false):
		var cache_room := i
		var chest := Chest.drop(self, cache_tier, room_center(i) + Vector2(0, -140))
		chest.on_open = func() -> void:
			set_flag(_cache_flag(cache_room))  # once per character

	# Packs — skipped when the save already calls this room cleared.
	if not cleared.get(i, false):
		_spawn_room_enemies(i)
	else:
		zone_alive[i] = 0

	# Social rooms (after the pack pass, so zone_alive counts stick):
	# seeded per character, some hold a lone ELITE instead of a wanderer
	# — a miniboss beat between combat rooms (playtest round 6; later
	# chapters may spawn more than one). Once beaten, the room stays
	# quiet — a wanderer moves in on the next visit.
	if room_type(i) == "social":
		var erng := _social_rng(i)
		var elite_room := erng.randf() < 0.30
		if elite_room and not cleared.get(i, false):
			_spawn_elite_room(i, erng)
		elif not elite_room or cleared.get(i, false):
			_spawn_wanderer(i)


func _cache_flag(i: int) -> String:
	return "cache_%s_%d" % [chapter_id, i]


func _spawn_room_enemies(i: int) -> void:
	zone_alive[i] = 0
	var spawned: Array = []
	for spawn in zones[i].get("enemies", []):
		var lvl := int(spawn[4]) if spawn.size() > 4 else -1
		var e := Enemy.make(self, spawn[0], room_pos(i, spawn[1], spawn[2]), lvl)
		e.zone_idx = i
		e.pack_id = int(spawn[3]) if spawn.size() > 3 else 0
		zone_alive[i] = zone_alive.get(i, 0) + 1
		add_enemy(e)
		spawned.append(e)
	# Elite ambush (playtest round 6): seeded per character+room, some
	# combat rooms promote one pack member to a miniboss. Boss rooms
	# are exempt — those arenas stay as authored.
	if not spawned.is_empty() and String(zones[i].get("boss", "")) == "":
		var rng := RandomNumberGenerator.new()
		rng.seed = wander_seed * 17 + i * 337 + chapter_id.hash() % 8837
		if rng.randf() < 0.18:
			spawned[rng.randi_range(0, spawned.size() - 1)].promote_elite()


## The seeded per-character roll for social room i. ONE place for the
## formula: the room build consumes it, and social_holds_elite lets
## the autotest predict the outcome instead of guessing.
func _social_rng(i: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 23 + i * 173 + chapter_id.hash() % 7717
	return rng


## Does social room i hold a lone elite instead of a wanderer?
func social_holds_elite(i: int) -> bool:
	return _social_rng(i).randf() < 0.30


## A lone elite holds a small side room. Kind and level ride the
## nearest earlier combat room, one level above its toughest spawn —
## a miniboss that always fits the local power band.
func _spawn_elite_room(i: int, rng: RandomNumberGenerator) -> void:
	var kind := ""
	var lvl := 1
	for j in range(i - 1, -1, -1):
		var packs: Array = zones[j].get("enemies", [])
		if packs.is_empty():
			continue
		var pick: Array = packs[rng.randi_range(0, packs.size() - 1)]
		kind = String(pick[0])
		for s in packs:
			var sl := int(s[4]) if s.size() > 4 else int(Story.ALL_ENEMIES[s[0]]["level"])
			lvl = maxi(lvl, sl)
		break
	if kind == "":
		return
	var e := Enemy.make(self, kind, room_center(i) + Vector2(0, -60), lvl + 1)
	e.zone_idx = i
	e.pack_id = 0
	e.promote_elite()
	zone_alive[i] = zone_alive.get(i, 0) + 1
	add_enemy(e)


## The room you died in resets: its surviving packs despawn and respawn
## fresh (and calm) for the retry.
func _reset_room_enemies(i: int) -> void:
	if not built.get(i, false):
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == i and not (e is Boss):
			e.remove_from_group("enemies")
			e.queue_free()
	_spawn_room_enemies(i)


## One pack member noticed you: the whole pack answers (per-pack aggro —
## rooms are too big for all-at-once).
func wake_pack(room: int, pack: int) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and e.zone_idx == room and e.pack_id == pack \
				and not e.force_aggro:
			e.force_aggro = true
			if not e.alerted:
				e.alerted = true
				emote(e, "!", 0.9)


## Social rooms roll ONE wanderer from the pool, seeded per character —
## a replay meets different people (DESIGN.md room palette).
func _spawn_wanderer(i: int) -> void:
	if Story.WANDERERS.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed + i * 131 + chapter_id.hash() % 9973
	var w: Dictionary = Story.WANDERERS[rng.randi_range(0, Story.WANDERERS.size() - 1)]
	var convo_id: String = w["convo"]
	var pos := room_center(i) + Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-140.0, 140.0))
	_make_npc(w["sprite"], pos, w.get("prompt", "E — Talk"), func() -> void:
		run_convo_id(convo_id))


func _spawn_merchant(zi: int) -> void:
	if not zones[zi].has("merchant") or merchant_zones.has(zi):
		return
	merchant_zones.append(zi)
	if built.get(zi, false):
		_merchant_node(zi)


func _merchant_node(zi: int) -> void:
	var zone: Dictionary = zones[zi]
	if not zone.has("merchant"):
		return
	var pos := room_pos(zi, zone["merchant"][0], zone["merchant"][1])
	var zone_idx := zi
	_make_npc("merchant", pos, "E — Shop", func() -> void:
		menus.open_shop(zone_idx)
	)


## The post-boss arrival: a puff of travel dust and a sales pitch.
func _merchant_arrives(zi: int) -> void:
	if merchant_zones.has(zi) or not zones[zi].has("merchant"):
		return
	_spawn_merchant(zi)
	var pos := room_pos(zi, zones[zi]["merchant"][0], zones[zi]["merchant"][1])
	burst(pos, Color(0.9, 0.8, 0.5), 12)
	sfx("coin")
	spawn_text(pos + Vector2(0, -50), "A WANDERING MERCHANT ARRIVES!", Color(0.95, 0.85, 0.5))


## Teleport to a visited safe room from the map screen. Walking through
## a LIVE room is content; re-walking a cleared one is not (DESIGN.md).
func fast_travel(i: int) -> void:
	if not travel_target(i) or state != ST_PLAYING or barrier_active \
			or hud.dialogue_active or player.dead:
		return
	sfx("blink")
	burst(player.global_position, Color(0.7, 0.8, 1.0), 12)
	player.global_position = room_center(i)
	_enter_room(i)
	burst(player.global_position, Color(0.7, 0.8, 1.0), 12)


func _make_npc(sprite_name: String, pos: Vector2, prompt_text: String, action: Callable) -> Node2D:
	var npc := Node2D.new()
	npc.position = pos
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2, 2)
	shadow.position = Vector2(0, 20)
	npc.add_child(shadow)
	var spr := Sprite2D.new()
	spr.texture = Art.tex(sprite_name)
	spr.scale = Art.scale_for(spr.texture, 3.0)
	npc.add_child(spr)
	var prompt := Label.new()
	prompt.text = prompt_text
	prompt.position = Vector2(-40, -58)
	prompt.size = Vector2(96, 20)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.visible = false
	npc.add_child(prompt)
	world.add_child(npc)
	interactables.append({"node": npc, "prompt": prompt, "action": action})
	return npc


## (Re)build a room's decor + obstacles from its TERRAIN — tombstones in
## the graveyard, snowy pines on the ice, crystals in the caverns...
func _spawn_scenery(zi: int) -> void:
	for node in zone_scenery.get(zi, []):
		if is_instance_valid(node):
			node.queue_free()
	zone_scenery[zi] = []
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var pr := play_rect(zi)
	var origin: Vector2 = pr.position
	var pw := pr.size.x
	var ph := pr.size.y
	var area_frac := (pw * ph) / float(ROOM_W * ROOM_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 77 + terrain_by_zone[zi].hash() % 1000

	# Non-colliding ground decor (density scaled to the room's area —
	# small rooms get proportionally less).
	var decor_list: Array = terrain.get("decor", ["pebble"])
	for i in int(ceil(58.0 * area_frac)):
		var spr := Sprite2D.new()
		spr.texture = Art.tex(decor_list[rng.randi_range(0, decor_list.size() - 1)])
		spr.scale = Vector2(3, 3)
		spr.position = origin + Vector2(rng.randf_range(70.0, pw - 70.0), rng.randf_range(80.0, ph - 80.0))
		spr.z_index = -8
		world.add_child(spr)
		zone_scenery[zi].append(spr)

	# Colliding obstacles, kept off the road band and the door lanes.
	var obstacles: Array = terrain.get("obstacles", ["rock"])
	var placed: Array = []
	var max_x := pw - 760.0 if zones[zi].get("boss", "") != "" else pw - 90.0
	var count := int(ceil(float(terrain.get("count", 10)) * 2.2 * area_frac))
	for i in count:
		for attempt in 40:
			var pos := Vector2(rng.randf_range(90.0, max_x), rng.randf_range(100.0, ph - 100.0))
			if pos.y > ph / 2.0 - 90.0 and pos.y < ph / 2.0 + 90.0:
				continue  # the road / east-west door lane stays open
			if absf(pos.x - pw / 2.0) < 130.0:
				continue  # the north-south door lane stays open
			var ok := true
			for other in placed:
				if pos.distance_to(other) < 85.0:
					ok = false
					break
			if ok:
				placed.append(pos)
				var body := _add_obstacle(obstacles[rng.randi_range(0, obstacles.size() - 1)], origin + pos)
				zone_scenery[zi].append(body)
				break


func _add_obstacle(sprite_name: String, pos: Vector2) -> StaticBody2D:
	var is_tree := sprite_name.begins_with("tree")
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13.0 if is_tree else 11.0
	cs.shape = shape
	cs.position = Vector2(0, 10)
	body.add_child(cs)
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(4, 2.4) if is_tree else Vector2(3, 2)
	shadow.position = Vector2(0, 38 if is_tree else 22)
	body.add_child(shadow)
	var spr := Sprite2D.new()
	spr.texture = Art.tex(sprite_name)
	spr.scale = Vector2(3, 3)
	if is_tree:
		spr.position = Vector2(0, -18)  # trunk base sits at the body origin
	body.add_child(spr)
	world.add_child(body)
	return body


## A wall segment: collider + tiled wallblock visual.
func _wall(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	body.add_child(cs)
	world.add_child(body)
	var spr := Sprite2D.new()
	spr.texture = Art.tex("wallblock")
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2.ZERO, rect.size / 3.0)
	spr.centered = false
	spr.position = rect.position
	spr.scale = Vector2(3, 3)
	spr.z_index = -5
	world.add_child(spr)


## Perimeter walls for one room, with door gaps on its open edges, and
## a gate body on any locked edge that isn't already satisfied.
## Small rooms build their walls at the inset playable rect and add
## short corridor walls from each doorway out to the cell edge.
func _build_room_walls(i: int) -> void:
	var r := play_rect(i)
	var full := room_rect(i)
	var ins := room_inset(i)
	var exits: Dictionary = rooms[i]["exits"]
	var gap := DOOR_TILES * TILE
	# North/south walls (gap centered on x).
	for spec in [["N", r.position.y], ["S", r.end.y - TILE]]:
		var dir: String = spec[0]
		var y: float = spec[1]
		if exits.has(dir):
			var half := r.size.x / 2.0 - gap / 2.0
			_wall(Rect2(r.position.x, y, half, TILE))
			_wall(Rect2(r.position.x + r.size.x / 2.0 + gap / 2.0, y, half, TILE))
			_door_torches(door_pos(i, dir), false)
			if ins.y > 0.0:
				var cx := full.position.x + ROOM_W / 2.0
				var cy := full.position.y if dir == "N" else r.end.y
				_wall(Rect2(cx - gap / 2.0 - TILE, cy, TILE, ins.y))
				_wall(Rect2(cx + gap / 2.0, cy, TILE, ins.y))
		else:
			_wall(Rect2(r.position.x, y, r.size.x, TILE))
	# West/east walls (gap centered on y).
	for spec in [["W", r.position.x], ["E", r.end.x - TILE]]:
		var dir: String = spec[0]
		var x: float = spec[1]
		if exits.has(dir):
			var half := r.size.y / 2.0 - gap / 2.0
			_wall(Rect2(x, r.position.y, TILE, half))
			_wall(Rect2(x, r.position.y + r.size.y / 2.0 + gap / 2.0, TILE, half))
			_door_torches(door_pos(i, dir), true)
			if ins.x > 0.0:
				var cy2 := full.position.y + ROOM_H / 2.0
				var cx2 := full.position.x if dir == "W" else r.end.x
				_wall(Rect2(cx2, cy2 - gap / 2.0 - TILE, ins.x, TILE))
				_wall(Rect2(cx2, cy2 + gap / 2.0, ins.x, TILE))
		else:
			_wall(Rect2(x, r.position.y, TILE, r.size.y))
	# Locked edges get a gate — built once per edge, by whichever room
	# builds first, and only while the lock is still unmet.
	for dir in exits.keys():
		var nb := neighbor(i, dir)
		if nb < 0:
			continue
		var key := _edge_key(i, nb)
		if edge_locks.has(key) and not gates.has(key) and not _edge_unlocked(i, nb):
			gates[key] = _build_gate(i, String(dir))


## Flickering torches flank each doorway.
func _door_torches(pos: Vector2, vertical: bool) -> void:
	var span := DOOR_TILES * TILE / 2.0 + 26.0
	for side in [-1, 1]:
		var off := Vector2(0, side * span) if vertical else Vector2(side * span, 0)
		var torch := Sprite2D.new()
		torch.texture = Art.tex("torch")
		torch.scale = Vector2(3, 3)
		torch.position = pos + off
		torch.z_index = 2
		world.add_child(torch)
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.6, 0.2, 0.5)
		glow.position = torch.position + Vector2(0, -12)
		glow.scale = Vector2(2.5, 2.5)
		glow.z_index = 1
		world.add_child(glow)
		var tween := glow.create_tween()
		tween.set_loops()
		tween.tween_property(glow, "scale", Vector2(3.1, 3.1), 0.5 + randf() * 0.3)
		tween.tween_property(glow, "scale", Vector2(2.4, 2.4), 0.5 + randf() * 0.3)


## A gate barring the doorway on room i's `dir` edge.
func _build_gate(i: int, dir: String) -> Node2D:
	var vertical := dir in ["E", "W"]  # the barred passage runs east-west
	var gate := StaticBody2D.new()
	gate.position = door_pos(i, dir)
	gate.collision_layer = 1
	gate.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE * 2.2, DOOR_TILES * TILE) if vertical \
		else Vector2(DOOR_TILES * TILE, TILE * 2.2)
	cs.shape = shape
	gate.add_child(cs)
	for row in DOOR_TILES:
		var spr := Sprite2D.new()
		spr.texture = Art.tex("gate")
		spr.scale = Vector2(3, 3)
		var off := (row - 1) * TILE
		spr.position = Vector2(0, off) if vertical else Vector2(off, 0)
		gate.add_child(spr)
	world.add_child(gate)
	return gate


## Open a (possibly gated) edge between two rooms.
func open_edge(a: int, b: int) -> void:
	var key := _edge_key(a, b)
	if not gates.has(key):
		return
	var gate: Node2D = gates[key]
	gates.erase(key)
	if gate == null or not is_instance_valid(gate):
		return
	sfx("gate")
	gate.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(gate, "modulate:a", 0.0, 0.8)
	tween.tween_callback(gate.queue_free)


## Legacy helper: open the gate on room zi's EAST edge (old strip rule).
func open_gate(zi: int) -> void:
	var nb := neighbor(zi, "E")
	if nb >= 0:
		open_edge(zi, nb)


## Battle seals: the 4 pooled door-blockers that close the current
## room's exits while a fight is live (rebuilt with the world).
func _build_door_seals() -> void:
	door_seals.clear()
	for i in 4:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(TILE * 1.4, DOOR_TILES * TILE + 24.0)
		cs.shape = shape
		body.add_child(cs)
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.25, 0.2, 0.55)
		glow.scale = Vector2(1.4, 3.6)
		glow.z_index = 4
		body.add_child(glow)
		body.position = Vector2(-4000, -4000)  # parked (inactive)
		world.add_child(body)
		door_seals.append({"body": body, "shape": shape, "glow": glow})


# ==================================================================== bosses

func _on_boss_trigger(zi: int) -> void:
	if boss_spawned.get(zi, false):
		return
	var kind: String = zones[zi]["boss"]
	if boss_done.get(kind, false):
		return
	boss_spawned[zi] = true
	var beat: Array = Story.ALL_BEATS.get("pre_" + kind, [])
	if beat.is_empty():
		_spawn_boss(zi, kind)
	else:
		hud.dialogue(beat, func() -> void:
			_spawn_boss(zi, kind)
		)


func _spawn_boss(zi: int, kind: String) -> void:
	shake(6.0)
	# Rooms may spawn a boss off its "story" level (Act pacing).
	current_boss = Boss.make_boss(self, kind,
		rooms[zi]["origin"] + Vector2(ROOM_W - 420.0, ROOM_H / 2.0),
		int(zones[zi].get("boss_level", -1)))
	current_boss.story_boss = true  # its death advances the chapter
	current_boss.zone_idx = zi
	bosses.append(current_boss)
	world.add_child(current_boss)
	current_boss.roar()
	hud.show_boss_bar(Story.ALL_ENEMIES[kind]["name"])
	set_music(_boss_music())


## Brawl bookkeeping shared by story and rogue boss deaths: drop the
## boss from the roster, retarget the bar, and restore the terrain
## music only when the LAST one falls — while the brawl continues the
## music stays where it peaked (playtest round 7: each kill in a x5
## dev brawl used to step the track down x5 -> x4 -> ...).
func _boss_roster_update(src: Boss) -> void:
	bosses.erase(src)
	if _live_bosses().is_empty():
		current_boss = null
		hud.hide_boss_bar()
		set_music(Terrains.get_terrain(terrain_by_zone[clampi(cur_room, 0, zone_count - 1)]).get("music", "village"))
	elif current_boss == src:
		current_boss = _live_bosses()[0]
		hud.show_boss_bar(current_boss.display_name)


## A boss killed OUTSIDE the story flow (dev panel spawns, tests):
## rewards and brawl bookkeeping only — no quests, no gates, no story
## dialogue, no boss_done marks, no chapter end.
func on_rogue_boss_died(kind: String, dead: Boss = null) -> void:
	var src: Boss = dead if is_instance_valid(dead) else current_boss
	var boss_pos: Vector2 = src.global_position if is_instance_valid(src) else player.global_position
	_boss_roster_update(src)
	player.hp = player.max_hp
	player.mp = player.max_mp
	Chest.drop(self, "gold", clamp_to_zone(boss_pos + Vector2(0, 60), boss_pos))
	Pickup.drop_gold(self, Story.ALL_ENEMIES[kind].get("gold", 50), boss_pos)


func on_boss_died(kind: String, dead: Boss = null) -> void:
	boss_done[kind] = true
	var src: Boss = dead if is_instance_valid(dead) else current_boss
	var boss_pos: Vector2 = src.global_position if is_instance_valid(src) else player.global_position
	var mzi: int = clampi(src.zone_idx if is_instance_valid(src) else cur_room, 0, zone_count - 1)
	_boss_roster_update(src)
	player.hp = player.max_hp
	player.mp = player.max_mp
	player.potions = maxi(player.potions, 2)

	# Bosses always drop a golden chest + a pile of gold.
	Chest.drop(self, "gold", clamp_to_zone(boss_pos + Vector2(0, 60), boss_pos))
	Pickup.drop_gold(self, Story.ALL_ENEMIES[kind].get("gold", 50), boss_pos)

	# Now that the room is safe, a wandering merchant MAY set up camp.
	if loot_rng.randf() < 0.65 and not merchant_zones.has(mzi):
		call_deferred("_merchant_arrives", mzi)

	# Boss rooms may also carry a clear_flag (arc/act progress markers).
	var boss_cflag := String(zones[mzi].get("clear_flag", ""))
	if boss_cflag != "":
		set_flag(boss_cflag)

	# Chapter-driven progression: the final boss ends the chapter; any
	# other boss opens the gate out of its zone and points the quest at
	# the next boss down the road.
	if kind == String(Story.chapter(chapter_id).get("final_boss", "")):
		quest_key = "done_" + chapter_id if Story.ALL_QUESTS.has("done_" + chapter_id) else "done"
		refresh_quest()
		# Progression: this character has finished the chapter (kept across
		# replays), and the NEXT chapter unlocks account-wide.
		set_flag("completed_" + chapter_id, true)
		var next_ch := Story.next_chapter(chapter_id)
		if next_ch != "":
			meta_unlock(next_ch)
		# Chapter-specific epilogue beat and victory card, with the
		# Chapter 1 texts as the fallback.
		var epilogue: Array = Story.ALL_BEATS.get("epilogue_" + chapter_id,
			Story.ALL_BEATS.get("epilogue", []))
		var vtext: String
		if next_ch != "":
			# Mid-campaign victory: the road goes on.
			vtext = String(Story.chapter(chapter_id).get("victory_text",
				"The Ember Crown is reclaimed. But the shards are still out there — and years from now, they will wake."))
			vtext += "\n\nENTER — journey on to %s        ·        R — start over" \
				% String(Story.chapter(next_ch)["name"])
		else:
			vtext = String(Story.chapter(chapter_id).get("victory_text",
				"Thanks for playing!\nPress R to play again."))
		var end_it := func() -> void:
			state = ST_VICTORY
			set_music("")
			sfx("victory")
			hud.show_end_screen("VICTORY", vtext, Color(1.0, 0.85, 0.35))
			get_tree().paused = true
		if epilogue.is_empty():
			end_it.call()
		else:
			hud.dialogue(epilogue, end_it)
	else:
		quest_key = _next_quest_after(mzi)
		var beat: Array = Story.ALL_BEATS.get("post_" + kind, [])
		var proceed := func() -> void:
			_recheck_gates()  # "boss" locks on this arena's edges open
			refresh_quest()
		if beat.is_empty():
			proceed.call()
		else:
			hud.dialogue(beat, proceed)
	autosave()


## The quest key after clearing zone zi: the next boss down the road,
## or the chapter's own "done" text if it has one.
func _next_quest_after(zi: int) -> String:
	for z in range(zi + 1, zone_count):
		var kind := String(zones[z].get("boss", ""))
		if kind != "" and not boss_done.get(kind, false):
			return kind
	return "done_" + chapter_id if Story.ALL_QUESTS.has("done_" + chapter_id) else "done"


func on_enemy_died(e: Enemy) -> void:
	if e is Boss:
		return  # boss drops are handled in on_boss_died
	Pickup.drop_gold(self, e.gold_value, e.global_position)
	if e.elite and is_instance_valid(player):
		# Elite loot pinata (playtest round 6): a guaranteed gem, a
		# guaranteed good chest, and the elite-exclusive economy —
		# talent reset stones and bigger bags. XP is zero by design
		# (chapter totals stay fixed).
		var gem := Items.random_gem(loot_rng, 2 if loot_rng.randf() < 0.35 else 1)
		if player.gain_gem(gem):
			spawn_text(e.global_position + Vector2(0, -70), "+ " + Items.gem_title(gem), Items.gem_color(gem))
		Chest.drop(self, "gold" if loot_rng.randf() < 0.45 else "silver",
			e.global_position + Vector2(44, 0))
		if loot_rng.randf() < 0.30:
			if player.add_consumable(Items.make_reset_stone()):
				spawn_text(e.global_position + Vector2(0, -92), "+ Stone of Unlearning", Color(0.6, 0.9, 1.0))
		elif loot_rng.randf() < 0.18:
			var cap := String(Story.chapter(chapter_id).get("loot_cap", "S"))
			player.acquire_bag(Items.make_bag(Items.roll_grade("gold", loot_rng, cap)))
	else:
		# Chance-based chest drops (Greed above 30% nudges the odds up).
		var bonus := Stats.greed_loot(player.greed) if is_instance_valid(player) else 0.0
		var roll := loot_rng.randf()
		if roll < 0.04 + bonus * 0.3:
			Chest.drop(self, "silver", e.global_position)
		elif roll < 0.18 + bonus:
			Chest.drop(self, "wood", e.global_position)

	# Room clear tracking: the boss only appears once its room is purged.
	if e.zone_idx >= 0:
		zone_alive[e.zone_idx] = maxi(0, zone_alive.get(e.zone_idx, 0) - 1)
		refresh_quest()
		if zone_alive[e.zone_idx] == 0:
			cleared[e.zone_idx] = true  # stays cleared for the run (saved)
			_try_spawn_boss(e.zone_idx)
			_recheck_gates()  # "clear" locks on this room's edges open
			if zones[e.zone_idx].get("boss", "") == "":
				# Bossless rooms: clearing IS the objective ("clear_flag"),
				# and the wandering merchant may arrive.
				if e.zone_idx == cur_room:
					_purge_fx()  # the blight recedes; the door seals lift
				var cflag := String(zones[e.zone_idx].get("clear_flag", ""))
				if cflag != "":
					set_flag(cflag)
				if loot_rng.randf() < 0.65 and not merchant_zones.has(e.zone_idx):
					call_deferred("_merchant_arrives", e.zone_idx)
				if e.zone_idx == cur_room and room_safe(cur_room):
					last_safe_room = cur_room
			autosave()


## The room's last pack falls: a brief green cleansing pulse — the
## blight recedes — as the door seals lift (purge rule, DESIGN.md).
func _purge_fx() -> void:
	hud.flash_screen(Color(0.3, 0.85, 0.4), 0.32, 0.55)
	# A low, soft sting — noticeable, never loud (playtest round 3).
	sfx("nova", 0.65, 0.0, -9.0)
	shake(3.0)
	if is_instance_valid(player):
		spawn_text(player.global_position + Vector2(0, -70),
			"THE BLIGHT RECEDES", Color(0.55, 0.95, 0.6))
		burst(player.global_position + Vector2(0, -20), Color(0.5, 0.9, 0.55), 16)


func _try_spawn_boss(zi: int) -> void:
	if not built.get(zi, false) or zone_alive.get(zi, 0) > 0 or zi != cur_room:
		return
	var kind: String = zones[zi].get("boss", "")
	if kind == "" or boss_done.get(kind, false) or boss_spawned.get(zi, false):
		return
	_on_boss_trigger(zi)


func add_enemy(e: Enemy) -> void:
	world.add_child(e)


# ============================================================ death / respawn

## Death: back to the last safe room with gear/gold/XP intact; the room
## you died in resets. No corpse runs — the penalty is the walk.
func on_player_died() -> void:
	if state != ST_PLAYING:
		return
	state = ST_DEAD
	sfx("pdie")
	hud.dim(0.55)
	hud.flash_title("YOU DIED", "The flame endures...", 1.0)
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()
	var death_room := cur_room
	await get_tree().create_timer(2.0).timeout

	for b in _live_bosses().duplicate():
		var live_b: Boss = b
		if live_b.zone_idx < 0:
			# Rogue bosses (dev-panel spawns — no home arena) don't
			# survive your death: they'd chase and attack across rooms.
			bosses.erase(live_b)
			live_b.remove_from_group("enemies")
			live_b.queue_free()
			if current_boss == live_b:
				current_boss = null
		else:
			live_b.reset_fight()  # walks home and heals; the arena waits
	if is_instance_valid(current_boss):
		hud.update_boss_bar(1.0)
	if not cleared.get(death_room, false):
		_reset_room_enemies(death_room)
	# Nothing follows you home from a death: homeless spawns (boss adds,
	# terrain-event zombies — zone_idx -1, they never freeze with a room)
	# despawn outright, and every other survivor calms down and returns
	# to its post instead of camping your respawn.
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e is Boss or e.dying:
			continue
		if e.zone_idx < 0:
			e.remove_from_group("enemies")
			e.queue_free()
		elif e.force_aggro or e.alerted:
			e.force_aggro = false
			e.alerted = false
			e.global_position = e.home

	player.global_position = room_center(last_safe_room)
	player.revive()
	_enter_room(last_safe_room)
	# No boss serenades your respawn: unless the boss is HERE (it never
	# is — you respawn in a safe room), the bar hides and the room's own
	# music takes over. The arena boss keeps waiting where it lives.
	if not is_instance_valid(current_boss) or current_boss.zone_idx != cur_room:
		hud.hide_boss_bar()
		set_music(Terrains.get_terrain(terrain_by_zone[cur_room]).get("music", "village"))
	hud.dim(0.0)
	state = ST_PLAYING


# ================================================================== helpers

## Every boss still standing (pruned of dead/freed ones).
func _live_bosses() -> Array:
	for i in range(bosses.size() - 1, -1, -1):
		if not is_instance_valid(bosses[i]) or bosses[i].dying:
			bosses.remove_at(i)
	return bosses


## The fight's music. Multi-boss brawls use the boss_x2..boss_x5
## override tracks when present (drop them in assets/music/); until
## then, the first boss's own theme carries the fight.
func _boss_music() -> String:
	var live := _live_bosses()
	if live.is_empty():
		return Terrains.get_terrain(terrain_by_zone[clampi(cur_room, 0, zone_count - 1)]).get("music", "village")
	var multi := "boss_x%d" % mini(live.size(), 5)
	if live.size() > 1 and music_tracks.has(multi):
		return multi
	return "boss_" + String(live[0].kind)


## Is the current room HOT — ANY living pack, or a live boss that is in
## this room (or a homeless dev spawn)? Hot rooms seal their doors: the
## room must be PURGED before you move on (playtest round 2 — aggro
## stays per-pack, but no running past content).
func _room_hot(i: int) -> bool:
	for b in _live_bosses():
		if b.zone_idx == i or b.zone_idx < 0:
			return true
	return zone_alive.get(i, 0) > 0


## Seal or lift the current room's door seals based on its fight state.
func _update_barrier() -> void:
	var want := _room_hot(cur_room)
	if want and not barrier_active:
		sfx("gate")
	barrier_active = want
	var idx := 0
	if want:
		var pulse := 0.45 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
		for dir in rooms[cur_room]["exits"].keys():
			if idx >= door_seals.size():
				break
			var entry: Dictionary = door_seals[idx]
			idx += 1
			var vertical: bool = dir in ["E", "W"]
			entry["shape"].size = Vector2(TILE * 1.4, DOOR_TILES * TILE + 24.0) if vertical \
				else Vector2(DOOR_TILES * TILE + 24.0, TILE * 1.4)
			entry["glow"].scale = Vector2(1.4, 3.6) if vertical else Vector2(3.6, 1.4)
			entry["glow"].modulate.a = pulse
			# Seals sit a step OUTSIDE the room (into the doorway
			# corridor) so one never spawns on top of a player who just
			# walked in — they pass it, then it bars the way back.
			entry["body"].position = door_pos(cur_room, String(dir)) \
				+ Vector2(DIRS[dir]) * (TILE * 0.9)
	for j in range(idx, door_seals.size()):
		door_seals[j]["body"].position = Vector2(-4000, -4000)


## Quest line + live "monsters left" counter for the player's room.
func refresh_quest() -> void:
	var text: String = Story.quest_text(quest_key)
	var zi: int = clampi(cur_room, 0, zone_count - 1)
	var left: int = zone_alive.get(zi, 0)
	if left > 0:
		# Sealed doors need a visible WHY: every room with living packs
		# shows its purge counter, not just boss arenas.
		text += "   —   %d monster%s left" % [left, "" if left == 1 else "s"]
	hud.set_quest(text)


## Clamp a position into the room that contains `anchor` (dashes, drops
## and boss blinks never leave the room they started in).
func clamp_to_zone(pos: Vector2, anchor: Vector2) -> Vector2:
	var zi := room_at_pos(anchor)
	if zi < 0:
		zi = clampi(cur_room, 0, zone_count - 1)
	var r := play_rect(zi)
	return Vector2(
		clampf(pos.x, r.position.x + 80.0, r.end.x - 80.0),
		clampf(pos.y, r.position.y + 90.0, r.end.y - 90.0)
	)


## Switch the background track with a quick fade.
## Per-track mix fixes for external recordings (measured RMS): dB gain
## evens out mastering differences, start skips long quiet intros
## (loops restart from the same offset via the stream's loop_offset).
const MUSIC_TUNE := {
	"icefield": {"gain": 14.0, "start": 10.0},  # whisper-quiet master
	"rainstorm": {"start": 30.0},               # storm fades in over ~30s
	"holy": {"gain": 4.0},
	"magma": {"gain": -4.0},
	"crystalline": {"gain": -3.0},
}
const MUSIC_DB := -16.0


func set_music(name: String) -> void:
	if name == current_track or music_player == null:
		return
	current_track = name
	var tune: Dictionary = MUSIC_TUNE.get(name, {})
	music_gain_db = MUSIC_DB + float(tune.get("gain", 0.0))
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -40.0 + _vol_db(float(settings["music"])), 0.4)
	tween.tween_callback(func() -> void:
		if name == "" or not music_tracks.has(name):
			music_player.stop()
			return
		music_player.stream = music_tracks[name]
		music_player.play(float(tune.get("start", 0.0)))
	)
	tween.tween_property(music_player, "volume_db", music_gain_db + _vol_db(float(settings["music"])), 0.6)


## Play a sound. pitch shifts the base pitch (still ±6% randomized);
## cutoff > 0 fades the sound out after that many seconds — lets long
## recordings (like a real wolf howl) play only their opening.
func sfx(name: String, pitch := 1.0, cutoff := 0.0, vol_db := 0.0) -> void:
	if not sounds.has(name):
		return
	var chosen: AudioStreamPlayer = sound_pool[0]
	for sp in sound_pool:
		if not sp.playing:
			chosen = sp
			break
	# Small random pitch per play: kills the machine-gun sameness of
	# repeated samples and the phasing of near-simultaneous ones.
	# vol_db offsets the base level (e.g. quiet ambient stings).
	chosen.pitch_scale = pitch * randf_range(0.94, 1.06)
	chosen.volume_db = -8.0 + vol_db
	chosen.stream = sounds[name]
	chosen.play()
	if cutoff > 0.0:
		var this_stream: AudioStream = chosen.stream
		var tween := create_tween()
		tween.tween_interval(cutoff)
		tween.tween_property(chosen, "volume_db", -40.0, 0.4)
		tween.tween_callback(func() -> void:
			if chosen.stream == this_stream:
				chosen.stop()
			chosen.volume_db = -8.0
		)


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


## Telegraphed ground attack: a danger zone appears, pulses for `delay`
## seconds, then erupts — heavy damage if the player is still inside.
## opts: {"color": Color, "sword": true} (sword = a blade falls from the sky).
func telegraph(pos: Vector2, radius: float, delay: float, damage: float, opts := {}) -> void:
	var zone := Sprite2D.new()
	zone.texture = Art.tex("telegraph")
	zone.global_position = pos
	zone.scale = Vector2(radius / 32.0, radius / 32.0)
	zone.modulate = opts.get("color", Color(1.0, 0.2, 0.15, 0.55))
	zone.z_index = -6
	add_child(zone)
	var pulse := zone.create_tween()
	pulse.set_loops()
	pulse.tween_property(zone, "modulate:a", 0.85, 0.18)
	pulse.tween_property(zone, "modulate:a", 0.45, 0.18)

	var sword: Sprite2D = null
	if opts.get("sword", false) or opts.get("fireball", false):
		sword = Sprite2D.new()
		sword.texture = Art.tex("fireball" if opts.get("fireball", false) else "greatsword")
		sword.scale = Vector2(6, 6) if opts.get("fireball", false) else Vector2(4.5, 4.5)
		if opts.get("fireball", false):
			sword.modulate = Color(1.0, 0.55, 0.2)
		sword.global_position = pos + Vector2(0, -420)
		sword.z_index = 30
		add_child(sword)
		var fall := sword.create_tween()
		fall.tween_property(sword, "global_position", pos + Vector2(0, -20), delay).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(zone):
		return
	zone.queue_free()
	sfx("slam")
	shake(6.0)
	burst(pos, opts.get("color", Color(1.0, 0.35, 0.2)), 18)
	if sword and is_instance_valid(sword):
		var sink := sword.create_tween()
		sink.tween_property(sword, "modulate:a", 0.0, 0.35)
		sink.tween_callback(sword.queue_free)
	if is_instance_valid(player) and not player.dead \
			and player.global_position.distance_to(pos) <= radius + 8.0:
		player.take_damage(damage, "magic")


## Floating emote bubble above a character ("!", "♪", "…", "?").
func emote(target: Node2D, symbol: String, dur := 1.4) -> void:
	if not is_instance_valid(target):
		return
	var box := Node2D.new()
	box.position = Vector2(10, -52)
	box.z_index = 30
	var spr := Sprite2D.new()
	spr.texture = Art.tex("bubble")
	spr.scale = Vector2(2.4, 2.4)
	box.add_child(spr)
	var l := Label.new()
	l.text = symbol
	l.position = Vector2(-14, -22)
	l.size = Vector2(28, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.08, 0.06, 0.1))
	box.add_child(l)
	target.add_child(box)
	box.scale = Vector2(0.3, 0.3)
	var tween := box.create_tween()
	tween.tween_property(box, "scale", Vector2(1, 1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(dur)
	tween.tween_property(box, "modulate:a", 0.0, 0.25)
	tween.tween_callback(box.queue_free)


var ambient_above := true

## Weather particles driven by the terrain's ambient preset.
func _setup_ambient_fx(terrain_id: String) -> void:
	if is_instance_valid(ambient_fx):
		ambient_fx.queue_free()
	var spec: Dictionary = Terrains.AMBIENTS.get(
		Terrains.get_terrain(terrain_id).get("ambient", "leaves_green"), {})
	if spec.is_empty():
		ambient_fx = null
		return
	ambient_fx = CPUParticles2D.new()
	ambient_fx.amount = spec["amount"]
	ambient_fx.lifetime = 9.0
	ambient_fx.preprocess = 6.0
	ambient_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ambient_above = spec["above"]
	ambient_fx.emission_rect_extents = Vector2(760, 60) if ambient_above else Vector2(760, 340)
	ambient_fx.spread = 30.0
	ambient_fx.z_index = 12
	ambient_fx.color = spec["color"]
	ambient_fx.direction = spec["dir"]
	ambient_fx.gravity = spec["gravity"]
	ambient_fx.initial_velocity_min = spec["vel"][0]
	ambient_fx.initial_velocity_max = spec["vel"][1]
	ambient_fx.scale_amount_min = spec["scale"][0]
	ambient_fx.scale_amount_max = spec["scale"][1]
	add_child(ambient_fx)


# ================================================================= terrain

## Repaint a room with a different terrain (look + mechanics). Live —
## this is how dev mode lets you audition every terrain instantly.
func apply_terrain(zi: int, terrain_id: String) -> void:
	terrain_by_zone[zi] = terrain_id
	if not built.get(zi, false):
		return  # unbuilt rooms pick the new terrain up at build time
	var terrain := Terrains.get_terrain(terrain_id)
	if is_instance_valid(zone_grounds.get(zi)):
		zone_grounds[zi].texture = Art.ground(terrain["ground"], terrain["path"], TILES_W, TILES_H,
			zi * 1000 + 7, rooms[zi]["exits"].keys())
	_spawn_scenery(zi)  # tombstones, snowy pines, crystals...
	_spawn_patches(zi)
	# If the player is standing in this room, refresh mood immediately.
	if cur_room == zi:
		var tween := create_tween()
		tween.tween_property(ambient, "color", terrain["tint"], 0.6)
		_setup_ambient_fx(terrain_id)
		terrain_event_t = randf_range(2.0, 4.0)
		if not is_instance_valid(current_boss):
			set_music(terrain.get("music", "village"))


## (Re)roll a room's static hazard patches from its terrain spec.
func _spawn_patches(zi: int) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		if hazards[i]["zone"] == zi:
			if is_instance_valid(hazards[i]["sprite"]):
				hazards[i]["sprite"].queue_free()
			hazards.remove_at(i)
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var origin: Vector2 = rooms[zi]["origin"]
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 991 + terrain_by_zone[zi].hash()
	for spec in terrain.get("patches", []):
		# Patch counts were tuned for the old strip; rooms are ~2.2x the area.
		for i in int(ceil(float(spec["count"]) * 2.0)):
			var pos := origin + Vector2(rng.randf_range(120.0, ROOM_W - 120.0), rng.randf_range(120.0, ROOM_H - 120.0))
			var radius := rng.randf_range(spec["radius"][0], spec["radius"][1])
			var drift := Vector2.ZERO
			if spec.get("drift", false):
				drift = Vector2(rng.randf_range(-20, 20), rng.randf_range(-14, 14))
			_add_hazard(zi, spec["type"], pos, radius, -1.0, drift)


## Add a floor hazard (until < 0 = permanent, else expires at that time).
func _add_hazard(zi: int, type: String, pos: Vector2, radius: float, duration := -1.0, drift := Vector2.ZERO) -> void:
	var spr := Sprite2D.new()
	spr.texture = Art.tex("glow")
	spr.modulate = Terrains.PATCH_COLOR.get(type, Color(1, 1, 1, 0.4))
	spr.global_position = pos
	spr.scale = Vector2(radius / 22.0, radius / 26.0)
	spr.z_index = -7
	world.add_child(spr)
	hazards.append({"zone": zi, "type": type, "pos": pos, "radius": radius,
		"until": (Time.get_ticks_msec() / 1000.0 + duration) if duration > 0.0 else -1.0,
		"drift": drift, "sprite": spr})


## Timed terrain happenings (magma rain, zombies, gusts, lightning...).
func run_terrain_event(ev: String) -> void:
	var zi := cur_room
	match ev:
		"magma_rain":
			# Magma falls from the sky — sometimes the floor collapses
			# into a lingering lava pool instead.
			if randf() < 0.3:
				var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-200, 200), randf_range(-150, 150)), player.global_position)
				telegraph(pos, 75.0, 1.3, 10.0, {"color": Color(1.0, 0.35, 0.1, 0.5)})
				_add_hazard.call_deferred(zi, "lava", pos, 70.0, 22.0)
			else:
				for i in randi_range(1, 2):
					var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-260, 260), randf_range(-180, 180)), player.global_position)
					telegraph(pos, 65.0, 1.0, 16.0, {"color": Color(1.0, 0.35, 0.1, 0.55), "fireball": true})
		"grave_spawn":
			if zone_alive.get(zi, 0) > 0 or is_instance_valid(current_boss):
				var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-220, 220), randf_range(-160, 160)), player.global_position)
				burst(pos, Color(0.5, 0.45, 0.35), 12)
				sfx("gate", 1.4)
				var z := Enemy.make(self, "zombie", pos, player.level)  # scales with you
				z.xp_value = 0   # event spawns are mood, not a farm —
				z.gold_value = 0  # chapter XP/gold stays a fixed total
				z.force_aggro = true
				add_enemy(z)
				emote(z, "!", 0.8)
		"gust":
			gust_vec = Vector2.RIGHT.rotated(randf() * TAU) * 220.0
			gust_t = 1.8
			sfx("blink", 0.6)
			burst(player.global_position + gust_vec.normalized() * -80.0, Color(0.85, 0.72, 0.45), 16)
		"lightning":
			var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-160, 160), randf_range(-120, 120)), player.global_position)
			telegraph(pos, 60.0, 0.55, 24.0, {"color": Color(0.7, 0.85, 1.0, 0.6)})
			hud.flash_screen(Color(0.8, 0.9, 1.0), 0.25, 0.2)
		"shard":
			var pos := clamp_to_zone(player.global_position + Vector2(randf_range(-200, 200), randf_range(-150, 150)), player.global_position)
			telegraph(pos, 55.0, 0.7, 14.0, {"color": Color(0.5, 0.85, 1.0, 0.55)})
			sfx("nova", 1.3)


## Apply floor-patch effects to the player and enemies (ticked at 2.5Hz).
func _apply_hazards() -> void:
	player.hazard_speed = 1.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e:
			e.hazard_speed = 1.0
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		if h["until"] > 0.0 and now > h["until"]:
			if is_instance_valid(h["sprite"]):
				h["sprite"].queue_free()
			hazards.remove_at(i)
			continue
		if h["drift"] != Vector2.ZERO:  # wandering spore clouds
			h["pos"] += h["drift"] * 0.4
			var hr := room_rect(int(h["zone"]))
			if h["pos"].x < hr.position.x + 100 or h["pos"].x > hr.end.x - 100:
				h["drift"].x *= -1.0
			if h["pos"].y < hr.position.y + 110 or h["pos"].y > hr.end.y - 110:
				h["drift"].y *= -1.0
			if is_instance_valid(h["sprite"]):
				h["sprite"].global_position = h["pos"]
		# Player effects.
		if not player.dead and player.global_position.distance_to(h["pos"]) <= h["radius"]:
			match h["type"]:
				"lava":
					player.take_damage(12.0, "magic")
				"poison":
					player.take_damage(6.0, "true")
				"ice":
					player.hazard_speed = 1.35
				"slow":
					player.hazard_speed = 0.7
				"heal":
					if player.hp < player.max_hp:
						player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.02)
		# Enemies share physical patches (ice, slow, lava).
		if h["type"] in ["ice", "slow", "lava"]:
			for node in get_tree().get_nodes_in_group("enemies"):
				var e := node as Enemy
				if e == null or e.dying or e.global_position.distance_to(h["pos"]) > h["radius"]:
					continue
				match h["type"]:
					"ice":
						e.hazard_speed = 1.35
					"slow":
						e.hazard_speed = 0.75
					"lava":
						e.take_damage(5.0, Vector2.ZERO, false, true)


## Quick burst of particles (deaths, blinks, chest opens, meteors...).
func burst(pos: Vector2, color: Color, count := 10) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.z_index = 15
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func spawn_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-70, -10)
	l.size = Vector2(140, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 20
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	var tween := create_tween()
	tween.tween_property(l, "position:y", l.position.y - 34.0, 0.9)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tween.tween_callback(l.queue_free)


# =================================================================== per-frame

func _process(delta: float) -> void:
	talk_cd = maxf(0.0, talk_cd - delta)
	if hud.dialogue_active or menus.is_open():
		talk_cd = 0.4

	hud.update_stats(player)

	# Auto-aim reticle over the current target (orange = Tab-locked).
	var target := player.auto_aim()
	if target and not player.dead:
		reticle.visible = true
		reticle.global_position = target.global_position
		reticle.modulate = Color(1.0, 0.45, 0.2) if target == player.locked_target else Color(1, 1, 1)
		reticle_label.text = "Lv %d" % target.level
		# Color the level by threat vs your own level.
		var diff := target.level - player.level
		reticle_label.add_theme_color_override("font_color",
			Color(1, 0.35, 0.3) if diff >= 3 else (Color(1, 0.85, 0.4) if diff >= 0 else Color(0.6, 1, 0.6)))
	else:
		reticle.visible = false

	# The boss bar follows your TARGET: the locked/aimed boss if any,
	# else the first live one (endgame brawls run up to 5 at once).
	var live_bosses := _live_bosses()
	if not live_bosses.is_empty():
		var shown: Boss = player.locked_target as Boss
		if shown == null or not is_instance_valid(shown) or shown.dying:
			shown = target as Boss  # the auto-aim pick from above
		if shown == null or not live_bosses.has(shown):
			shown = live_bosses[0] if current_boss == null or not live_bosses.has(current_boss) else current_boss
		if shown != current_boss:
			current_boss = shown
			hud.show_boss_bar(shown.display_name)
		hud.update_boss_bar(current_boss.hp / current_boss.max_hp)

	# Room transitions: walking through a doorway moves you next door.
	# (Aggro is per-pack now — entering a room wakes nobody by itself.)
	var zi := room_at_pos(player.global_position)
	if zi == -1:
		# Physics glitch outside the graph: snap back into the room.
		var rr := play_rect(clampi(cur_room, 0, zone_count - 1))
		player.global_position.x = clampf(player.global_position.x, rr.position.x + 52.0, rr.end.x - 52.0)
		player.global_position.y = clampf(player.global_position.y, rr.position.y + 62.0, rr.end.y - 62.0)
		zi = cur_room
	elif zi != cur_room and state == ST_PLAYING:
		_enter_room(zi)
	hud.set_zone(zones[cur_room]["name"])

	# ------------------------------------------------ terrain mechanics ---
	var cur_terrain := Terrains.get_terrain(terrain_by_zone[cur_room])
	if cur_terrain.get("event", "") != "" and state == ST_PLAYING and not player.dead:
		terrain_event_t -= delta
		if terrain_event_t <= 0.0:
			var span: Array = cur_terrain.get("event_t", [5.0, 8.0])
			terrain_event_t = randf_range(span[0], span[1])
			run_terrain_event(cur_terrain["event"])
	if cur_terrain.get("mp_boost", false):  # crystal caverns hum with mana
		player.mp = minf(player.max_mp, player.mp + 5.0 * delta)
	hazard_tick -= delta
	if hazard_tick <= 0.0:
		hazard_tick = 0.4
		_apply_hazards()
	if gust_t > 0.0:
		gust_t -= delta
		if gust_t <= 0.0:
			gust_vec = Vector2.ZERO

	# Dev god mode: unkillable, infinite mana, no cooldowns.
	if dev_god:
		player.hp = player.max_hp
		player.mp = player.max_mp
		for key in player.cds:
			player.cds[key] = minf(player.cds[key], 0.2)

	_update_barrier()

	# Ambient particles drift around the camera; NPCs chatter idly.
	if is_instance_valid(ambient_fx):
		ambient_fx.global_position = player.global_position + Vector2(0, -380.0 if ambient_above else 0.0)
	npc_emote_t -= delta
	if npc_emote_t <= 0.0:
		npc_emote_t = randf_range(3.5, 7.0)
		if not interactables.is_empty() and state == ST_PLAYING and not hud.dialogue_active:
			var entry: Dictionary = interactables[randi() % interactables.size()]
			if is_instance_valid(entry["node"]) and player.global_position.distance_to(entry["node"].position) < 700.0:
				emote(entry["node"], ["♪", "…", "?", "♥"][randi() % 4])

	# New theme unlocked: announce it.
	if player.pending_theme_note != "" and state == ST_PLAYING and not hud.dialogue_active and not menus.is_open():
		hud.flash_title("THEME UNLOCKED: " + player.pending_theme_note,
			"Press T to assign themes to your abilities", 2.2)
		sfx("victory")
		player.pending_theme_note = ""

	# NPC interactions (elder, merchants).
	if state == ST_PLAYING and not hud.dialogue_active and not menus.is_open():
		for entry in interactables:
			var near: bool = player.global_position.distance_to(entry["node"].position) < 80.0
			entry["prompt"].visible = near
			if near and talk_cd <= 0.0 and Input.is_key_pressed(binds["interact"]):
				talk_cd = 0.6
				entry["action"].call()
				break
		# Menu hotkeys.
		if talk_cd <= 0.0:
			if Input.is_key_pressed(binds["inventory"]):
				talk_cd = 0.4
				menus.open_inventory()
			elif Input.is_key_pressed(binds["skills"]):
				talk_cd = 0.4
				menus.open_skills()
			elif Input.is_key_pressed(binds["codex"]):
				talk_cd = 0.4
				menus.open_codex()
			elif Input.is_key_pressed(binds.get("map", KEY_M)):
				talk_cd = 0.4
				menus.open_map()
			# (ESC → pause menu lives in hud._on_escape, event-driven —
			# a polled duplicate here caused double-open/close races.)

	shake_amt = move_toward(shake_amt, 0.0, 20.0 * delta)
	if camera:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	# (The room-transition check at the top of _process is the safety
	# net: any position outside the graph snaps back into the room.)
