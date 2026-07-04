class_name Game extends Node2D
## The conductor. Builds the world (4 zones in a row), spawns the player,
## enemies, merchants and bosses, runs the story beats, and handles
## loot drops, death and victory.
##
## World layout (each zone is ZONE_W wide, gates between them):
##   [ Village ] | [ Darkwood ] | [ Blightmarsh ] | [ Vargoth's Keep ]

const TILE := 48
const TILES_W := 34
const TILES_H := 15
const ZONE_W := TILES_W * TILE
const WORLD_H := TILES_H * TILE
const ZONES := 4

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

# Rebindable keys. Movement is always WASD/arrows; ESC is fixed.
var binds := {
	"a1": KEY_J, "a2": KEY_K, "a3": KEY_L, "ult": KEY_U,
	"potion": KEY_Q, "interact": KEY_E, "inventory": KEY_I, "skills": KEY_T,
	"codex": KEY_C, "target": KEY_TAB,
}

var quest_key := "talk"
var talked_to_elder := false
var talk_cd := 0.0
var last_zone := -1
var play_started := false

var elder: Node2D
var interactables: Array = []    # [{node, prompt, action}]
var gates: Array = []
var zone_alive := {}             # zone index -> monsters still alive
var boss_spawned := {}
var boss_done := {}
var current_boss: Boss = null
var shop_stock := {}             # zone index -> Array of items for sale

var shake_amt := 0.0
var sounds: Dictionary = {}
var sound_pool: Array = []
var loot_rng := RandomNumberGenerator.new()
var ambient_fx: CPUParticles2D = null
var npc_emote_t := 4.0
var barrier: StaticBody2D = null      # seals the entrance mid-combat
var barrier_glow: Sprite2D = null
var barrier_active := false

# ------------------------------------------------------ terrain system ---
var terrain_by_zone: Array = []       # terrain id per zone
var zone_grounds: Array = []          # ground Sprite2D per zone (repaintable)
var hazards: Array = []               # active floor patches (lava/ice/...)
var terrain_event_t := 4.0            # countdown to the next terrain event
var hazard_tick := 0.0
var gust_vec := Vector2.ZERO          # sandstorm push applied to everyone
var gust_t := 0.0

# ------------------------------------------------------------ dev mode ---
var dev_mode := false                 # launched via dev_mode.bat (--dev)
var dev_god := false
var music_player: AudioStreamPlayer
var music_tracks: Dictionary = {}
var current_track := ""

const ZONE_TRACKS := ["village", "darkwood", "marsh", "keep"]


func _ready() -> void:
	loot_rng.randomize()
	load_binds()
	dev_mode = "--dev" in OS.get_cmdline_user_args()
	for zone in Story.ZONES:
		terrain_by_zone.append(zone.get("terrain", "village"))

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
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -16.0
	add_child(music_player)

	ambient = CanvasModulate.new()
	ambient.color = Terrains.get_terrain(terrain_by_zone[0])["tint"]
	add_child(ambient)

	_build_world()

	player = Player.new()
	player.game = self
	player.global_position = Vector2(180, 360)
	add_child(player)

	reticle = Sprite2D.new()
	reticle.texture = Art.tex("reticle")
	reticle.scale = Vector2(2, 2)
	reticle.z_index = 25
	reticle.visible = false
	add_child(reticle)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = ZONE_W * ZONES
	camera.limit_top = 0
	camera.limit_bottom = WORLD_H
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

	# First: pick a class. Then the story begins.
	call_deferred("_start_flow")


func _start_flow() -> void:
	menus.open_class_select()


func on_class_chosen(id: String) -> void:
	player.set_class(id)
	get_tree().paused = false
	hud.dialogue(Story.BEATS["intro"], func() -> void:
		play_started = true
		set_music("village")
		hud.flash_title("Emberfall Village", "Chapter 1: The Hollow King")
	)


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

func _build_world() -> void:
	for zi in ZONES:
		_build_zone(zi)

	_wall(Rect2(0, 0, ZONE_W * ZONES, TILE))
	_wall(Rect2(0, WORLD_H - TILE, ZONE_W * ZONES, TILE))
	_wall(Rect2(-TILE, 0, TILE, WORLD_H))
	_wall(Rect2(ZONE_W * ZONES, 0, TILE, WORLD_H))

	for i in ZONES - 1:
		gates.append(_build_gate(ZONE_W * (i + 1)))

	# Battle barrier: while a zone still has monsters (or its boss),
	# a glowing wall seals the way BACK — no retreating mid-combat.
	barrier = StaticBody2D.new()
	barrier.collision_layer = 1
	barrier.collision_mask = 0
	var bshape := CollisionShape2D.new()
	var brect := RectangleShape2D.new()
	brect.size = Vector2(TILE, 160)
	bshape.shape = brect
	barrier.add_child(bshape)
	barrier_glow = Sprite2D.new()
	barrier_glow.texture = Art.tex("glow")
	barrier_glow.modulate = Color(1.0, 0.25, 0.2, 0.55)
	barrier_glow.scale = Vector2(1.4, 3.6)
	barrier_glow.z_index = 4
	barrier.add_child(barrier_glow)
	barrier.position = Vector2(-2000, -2000)  # parked (inactive)
	add_child(barrier)

	# Elder Maren, the quest giver in the village.
	elder = _make_npc("elder", Vector2(520, 330), "E — Talk", func() -> void:
		if not talked_to_elder:
			talked_to_elder = true
			hud.dialogue(Story.BEATS["elder"], func() -> void:
				open_gate(0)
				quest_key = "fangmaw"
				refresh_quest()
			)
		else:
			hud.dialogue(Story.BEATS["elder_repeat"])
	)

	# One merchant per zone.
	for zi in ZONES:
		var zone: Dictionary = Story.ZONES[zi]
		if zone.has("merchant"):
			var pos: Vector2 = Vector2(zi * ZONE_W, 0) + Vector2(zone["merchant"][0], zone["merchant"][1])
			var zone_idx := zi
			_make_npc("merchant", pos, "E — Shop", func() -> void:
				menus.open_shop(zone_idx)
			)


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
	add_child(npc)
	interactables.append({"node": npc, "prompt": prompt, "action": action})
	return npc


func _build_zone(zi: int) -> void:
	var zone: Dictionary = Story.ZONES[zi]
	var zone_x := zi * ZONE_W

	# Ground texture comes from the zone's TERRAIN (repaintable in dev
	# mode via apply_terrain, so keep a reference).
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var ground := Sprite2D.new()
	ground.texture = Art.ground(terrain["ground"], terrain["path"], TILES_W, TILES_H, zi * 1000 + 7)
	ground.centered = false
	ground.position = Vector2(zone_x, 0)
	ground.scale = Vector2(3, 3)
	ground.z_index = -10
	add_child(ground)
	zone_grounds.append(ground)
	_spawn_patches(zi)

	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 77 + 3

	# Non-colliding ground decor (flowers, bones, cracks...).
	var decor_list: Array = zone.get("decor", ["pebble"])
	for i in 26:
		var spr := Sprite2D.new()
		spr.texture = Art.tex(decor_list[rng.randi_range(0, decor_list.size() - 1)])
		spr.scale = Vector2(3, 3)
		spr.position = Vector2(zone_x + rng.randf_range(70.0, ZONE_W - 70.0), rng.randf_range(80.0, 640.0))
		spr.z_index = -8
		add_child(spr)

	# Colliding obstacles, kept off the central road.
	var placed: Array = []
	var max_x := 1000.0 if zone["boss"] != "" else 1400.0
	for i in zone["obstacle_count"]:
		for attempt in 40:
			var pos := Vector2(rng.randf_range(90.0, max_x), rng.randf_range(100.0, 630.0))
			if pos.y > 260.0 and pos.y < 460.0:
				continue
			var ok := true
			for other in placed:
				if pos.distance_to(other) < 85.0:
					ok = false
					break
			if ok:
				placed.append(pos)
				_add_obstacle(zone["obstacles"][rng.randi_range(0, zone["obstacles"].size() - 1)], Vector2(zone_x, 0) + pos)
				break

	for spawn in zone["enemies"]:
		var e := Enemy.make(self, spawn[0], Vector2(zone_x + spawn[1], spawn[2]))
		e.zone_idx = zi
		zone_alive[zi] = zone_alive.get(zi, 0) + 1
		add_enemy(e)


func _add_obstacle(sprite_name: String, pos: Vector2) -> void:
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
	add_child(body)


func _wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _build_gate(x: float) -> Node2D:
	var gap_top := 6 * TILE
	var gap_bottom := 9 * TILE

	for row in TILES_H:
		if row >= 6 and row <= 8:
			continue
		var spr := Sprite2D.new()
		spr.texture = Art.tex("wallblock")
		spr.scale = Vector2(3, 3)
		spr.position = Vector2(x, row * TILE + TILE / 2.0)
		spr.z_index = -5
		add_child(spr)
	_wall(Rect2(x - TILE / 2.0, 0, TILE, gap_top))
	_wall(Rect2(x - TILE / 2.0, gap_bottom, TILE, WORLD_H - gap_bottom))

	# Flickering torches flank each gate.
	for side in [-1, 1]:
		var torch := Sprite2D.new()
		torch.texture = Art.tex("torch")
		torch.scale = Vector2(3, 3)
		torch.position = Vector2(x, (gap_top if side == -1 else gap_bottom) + side * -26.0)
		torch.z_index = 2
		add_child(torch)
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.6, 0.2, 0.5)
		glow.position = torch.position + Vector2(0, -12)
		glow.scale = Vector2(2.5, 2.5)
		glow.z_index = 1
		add_child(glow)
		var tween := glow.create_tween()
		tween.set_loops()
		tween.tween_property(glow, "scale", Vector2(3.1, 3.1), 0.5 + randf() * 0.3)
		tween.tween_property(glow, "scale", Vector2(2.4, 2.4), 0.5 + randf() * 0.3)

	var gate := StaticBody2D.new()
	gate.position = Vector2(x, (gap_top + gap_bottom) / 2.0)
	gate.collision_layer = 1
	gate.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, gap_bottom - gap_top)
	gate.add_child(cs)
	cs.shape = shape
	for row in 3:
		var spr := Sprite2D.new()
		spr.texture = Art.tex("gate")
		spr.scale = Vector2(3, 3)
		spr.position = Vector2(0, (row - 1) * TILE)
		gate.add_child(spr)
	add_child(gate)
	return gate


func open_gate(index: int) -> void:
	var gate: Node2D = gates[index]
	if gate == null:
		return
	gates[index] = null
	sfx("gate")
	gate.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(gate, "modulate:a", 0.0, 0.8)
	tween.tween_callback(gate.queue_free)


# ==================================================================== bosses

func _on_boss_trigger(zi: int) -> void:
	if boss_spawned.get(zi, false):
		return
	var kind: String = Story.ZONES[zi]["boss"]
	if boss_done.get(kind, false):
		return
	boss_spawned[zi] = true
	hud.dialogue(Story.BEATS["pre_" + kind], func() -> void:
		_spawn_boss(zi, kind)
	)


func _spawn_boss(zi: int, kind: String) -> void:
	shake(6.0)
	current_boss = Boss.make_boss(self, kind, Vector2(zi * ZONE_W + 1380, 360))
	add_child(current_boss)
	current_boss.roar()
	hud.show_boss_bar(Story.ENEMIES[kind]["name"])
	set_music("boss_" + kind)


func on_boss_died(kind: String) -> void:
	boss_done[kind] = true
	var boss_pos := current_boss.global_position
	current_boss = null
	hud.hide_boss_bar()
	set_music(ZONE_TRACKS[clampi(last_zone, 0, 3)])
	player.hp = player.max_hp
	player.mp = player.max_mp
	player.potions = maxi(player.potions, 3)

	# Bosses always drop a golden chest + a pile of gold.
	Chest.drop(self, "gold", clamp_to_zone(boss_pos + Vector2(0, 60), boss_pos))
	Pickup.drop_gold(self, Story.ENEMIES[kind].get("gold", 50), boss_pos)

	match kind:
		"fangmaw":
			quest_key = "morwen"
			hud.dialogue(Story.BEATS["post_fangmaw"], func() -> void:
				open_gate(1)
				refresh_quest()
			)
		"morwen":
			quest_key = "vargoth"
			hud.dialogue(Story.BEATS["post_morwen"], func() -> void:
				open_gate(2)
				refresh_quest()
			)
		"vargoth":
			quest_key = "done"
			refresh_quest()
			hud.dialogue(Story.BEATS["epilogue"], func() -> void:
				state = ST_VICTORY
				set_music("")
				sfx("victory")
				hud.show_end_screen("VICTORY", "The Ember Crown is reclaimed. Thanks for playing Chapter 1!\nPress R to play again.", Color(1.0, 0.85, 0.35))
				get_tree().paused = true
			)


func on_enemy_died(e: Enemy) -> void:
	if e is Boss:
		return  # boss drops are handled in on_boss_died
	Pickup.drop_gold(self, e.gold_value, e.global_position)
	# Chance-based chest drops (Greed above 30% nudges the odds up).
	var bonus := Stats.greed_loot(player.greed) if is_instance_valid(player) else 0.0
	var roll := loot_rng.randf()
	if roll < 0.04 + bonus * 0.3:
		Chest.drop(self, "silver", e.global_position)
	elif roll < 0.18 + bonus:
		Chest.drop(self, "wood", e.global_position)

	# Zone clear tracking: the boss only appears once the zone is purged.
	if e.zone_idx >= 0:
		zone_alive[e.zone_idx] = maxi(0, zone_alive.get(e.zone_idx, 0) - 1)
		refresh_quest()
		if zone_alive[e.zone_idx] == 0:
			_try_spawn_boss(e.zone_idx)


func _try_spawn_boss(zi: int) -> void:
	if zone_alive.get(zi, 0) > 0:
		return
	var kind: String = Story.ZONES[zi]["boss"]
	if kind == "" or boss_done.get(kind, false) or boss_spawned.get(zi, false):
		return
	_on_boss_trigger(zi)


func add_enemy(e: Enemy) -> void:
	add_child(e)


# ============================================================ death / respawn

func on_player_died() -> void:
	if state != ST_PLAYING:
		return
	state = ST_DEAD
	sfx("pdie")
	hud.dim(0.55)
	hud.flash_title("YOU DIED", "The flame endures...", 1.0)
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()
	await get_tree().create_timer(2.0).timeout

	if is_instance_valid(current_boss) and not current_boss.dying:
		current_boss.reset_fight()
		hud.update_boss_bar(1.0)

	var zi := clampi(int(player.global_position.x / ZONE_W), 0, ZONES - 1)
	player.global_position = Vector2(zi * ZONE_W + 180.0, 360.0)
	player.revive()
	hud.dim(0.0)
	state = ST_PLAYING


# ================================================================== helpers

## Is this zone fully pacified (no monsters, boss dead or none)?
func zone_pacified(zi: int) -> bool:
	if zone_alive.get(zi, 0) > 0:
		return false
	var kind: String = Story.ZONES[zi]["boss"]
	return kind == "" or boss_done.get(kind, false)


## Seal or lift the entrance barrier based on the player's zone state.
func _update_barrier() -> void:
	var zi := clampi(int(player.global_position.x / ZONE_W), 0, ZONES - 1)
	var want := zi > 0 and not zone_pacified(zi)
	if want and not barrier_active:
		sfx("gate")
	barrier_active = want
	if want:
		# Slightly inside the previous boundary so the player is never
		# spawned overlapping it when crossing the gate.
		barrier.position = Vector2(zi * ZONE_W - 26.0, 360.0)
		barrier_glow.modulate.a = 0.45 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
	else:
		barrier.position = Vector2(-2000, -2000)


## Quest line + live "monsters left" counter for the player's zone.
func refresh_quest() -> void:
	var text: String = Story.QUESTS[quest_key]
	var zi := clampi(int(player.global_position.x / ZONE_W), 0, ZONES - 1) if player else 0
	var left: int = zone_alive.get(zi, 0)
	if left > 0 and Story.ZONES[zi]["boss"] != "" and not boss_done.get(Story.ZONES[zi]["boss"], false):
		text += "   —   %d monster%s left" % [left, "" if left == 1 else "s"]
	hud.set_quest(text)


func clamp_to_zone(pos: Vector2, anchor: Vector2) -> Vector2:
	var zi := clampi(int(anchor.x / ZONE_W), 0, ZONES - 1)
	return Vector2(
		clampf(pos.x, zi * ZONE_W + 80.0, (zi + 1) * ZONE_W - 80.0),
		clampf(pos.y, 90.0, WORLD_H - 90.0)
	)


## Switch the background track with a quick fade.
func set_music(name: String) -> void:
	if name == current_track or music_player == null:
		return
	current_track = name
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -40.0, 0.4)
	tween.tween_callback(func() -> void:
		if name == "" or not music_tracks.has(name):
			music_player.stop()
			return
		music_player.stream = music_tracks[name]
		music_player.play()
	)
	tween.tween_property(music_player, "volume_db", -16.0, 0.6)


## Play a sound. pitch shifts the base pitch (still ±6% randomized);
## cutoff > 0 fades the sound out after that many seconds — lets long
## recordings (like a real wolf howl) play only their opening.
func sfx(name: String, pitch := 1.0, cutoff := 0.0) -> void:
	if not sounds.has(name):
		return
	var chosen: AudioStreamPlayer = sound_pool[0]
	for sp in sound_pool:
		if not sp.playing:
			chosen = sp
			break
	# Small random pitch per play: kills the machine-gun sameness of
	# repeated samples and the phasing of near-simultaneous ones.
	chosen.pitch_scale = pitch * randf_range(0.94, 1.06)
	chosen.volume_db = -8.0
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

## Repaint a zone with a different terrain (look + mechanics). Live —
## this is how dev mode lets you audition every terrain instantly.
func apply_terrain(zi: int, terrain_id: String) -> void:
	terrain_by_zone[zi] = terrain_id
	var terrain := Terrains.get_terrain(terrain_id)
	if zi < zone_grounds.size() and is_instance_valid(zone_grounds[zi]):
		zone_grounds[zi].texture = Art.ground(terrain["ground"], terrain["path"], TILES_W, TILES_H, zi * 1000 + 7)
	_spawn_patches(zi)
	# If the player is standing in this zone, refresh mood immediately.
	if last_zone == zi:
		var tween := create_tween()
		tween.tween_property(ambient, "color", terrain["tint"], 0.6)
		_setup_ambient_fx(terrain_id)
		terrain_event_t = randf_range(2.0, 4.0)


## (Re)roll a zone's static hazard patches from its terrain spec.
func _spawn_patches(zi: int) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		if hazards[i]["zone"] == zi:
			if is_instance_valid(hazards[i]["sprite"]):
				hazards[i]["sprite"].queue_free()
			hazards.remove_at(i)
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 991 + terrain_by_zone[zi].hash()
	for spec in terrain.get("patches", []):
		for i in spec["count"]:
			var pos := Vector2(zi * ZONE_W + rng.randf_range(120.0, ZONE_W - 120.0), rng.randf_range(120.0, WORLD_H - 120.0))
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
	add_child(spr)
	hazards.append({"zone": zi, "type": type, "pos": pos, "radius": radius,
		"until": (Time.get_ticks_msec() / 1000.0 + duration) if duration > 0.0 else -1.0,
		"drift": drift, "sprite": spr})


## Timed terrain happenings (magma rain, zombies, gusts, lightning...).
func run_terrain_event(ev: String) -> void:
	var zi := last_zone
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
				var z := Enemy.make(self, "zombie", pos)
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
			var zi_h: int = h["zone"]
			if h["pos"].x < zi_h * ZONE_W + 100 or h["pos"].x > (zi_h + 1) * ZONE_W - 100:
				h["drift"].x *= -1.0
			if h["pos"].y < 110 or h["pos"].y > WORLD_H - 110:
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

	if is_instance_valid(current_boss) and not current_boss.dying:
		hud.update_boss_bar(current_boss.hp / current_boss.max_hp)

	# Auto-aim reticle over the current target (orange = Tab-locked).
	var target := player.auto_aim()
	if target and not player.dead:
		reticle.visible = true
		reticle.global_position = target.global_position
		reticle.modulate = Color(1.0, 0.45, 0.2) if target == player.locked_target else Color(1, 1, 1)
	else:
		reticle.visible = false

	# Zone banner + ambient tint when crossing into a new zone.
	var zi := clampi(int(player.global_position.x / ZONE_W), 0, ZONES - 1)
	if zi != last_zone:
		if last_zone != -1 and play_started:
			hud.flash_title(Story.ZONES[zi]["name"])
		last_zone = zi
		var terrain := Terrains.get_terrain(terrain_by_zone[zi])
		var tween := create_tween()
		tween.tween_property(ambient, "color", terrain["tint"], 1.0)
		# Entering a combat zone wakes up EVERY monster in it.
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e and e.zone_idx == zi:
				e.force_aggro = true
		refresh_quest()
		_setup_ambient_fx(terrain_by_zone[zi])
		terrain_event_t = randf_range(2.5, 5.0)
		if not is_instance_valid(current_boss):
			set_music(ZONE_TRACKS[zi])
		_try_spawn_boss(zi)
	hud.set_zone(Story.ZONES[zi]["name"])

	# ------------------------------------------------ terrain mechanics ---
	var cur_terrain := Terrains.get_terrain(terrain_by_zone[zi])
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

	shake_amt = move_toward(shake_amt, 0.0, 20.0 * delta)
	if camera:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt

	# Safety net: no dash, knockback or physics glitch may ever leave the
	# hero stranded outside the world walls.
	player.global_position.x = clampf(player.global_position.x, 44.0, ZONE_W * ZONES - 44.0)
	player.global_position.y = clampf(player.global_position.y, 64.0, WORLD_H - 64.0)
