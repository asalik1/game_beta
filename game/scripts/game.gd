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

# Ambient light color per zone (subtle mood shift, Soul-Knight style).
const ZONE_TINT := [
	Color(1.0, 0.98, 0.9), Color(0.82, 0.9, 0.86),
	Color(0.88, 0.92, 0.78), Color(0.82, 0.8, 0.92),
]

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
	"codex": KEY_C,
}

var quest_key := "talk"
var talked_to_elder := false
var talk_cd := 0.0
var last_zone := -1
var play_started := false

var elder: Node2D
var interactables: Array = []    # [{node, prompt, action}]
var gates: Array = []
var boss_spawned := {}
var boss_done := {}
var current_boss: Boss = null
var shop_stock := {}             # zone index -> Array of items for sale

var shake_amt := 0.0
var sounds: Dictionary = {}
var sound_pool: Array = []
var loot_rng := RandomNumberGenerator.new()


func _ready() -> void:
	loot_rng.randomize()
	load_binds()

	sounds = Sfx.build_all()
	for i in 10:
		var sp := AudioStreamPlayer.new()
		sp.volume_db = -8.0
		add_child(sp)
		sound_pool.append(sp)

	ambient = CanvasModulate.new()
	ambient.color = ZONE_TINT[0]
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
	player.add_child(camera)
	camera.make_current()

	hud = Hud.new()
	hud.game = self
	add_child(hud)
	hud.set_quest(Story.QUESTS[quest_key])

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

	# Elder Maren, the quest giver in the village.
	elder = _make_npc("elder", Vector2(520, 330), "E — Talk", func() -> void:
		if not talked_to_elder:
			talked_to_elder = true
			hud.dialogue(Story.BEATS["elder"], func() -> void:
				open_gate(0)
				quest_key = "fangmaw"
				hud.set_quest(Story.QUESTS[quest_key])
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
	spr.scale = Vector2(3, 3)
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

	var ground := Sprite2D.new()
	ground.texture = Art.ground(zone["ground"], zone["path"], TILES_W, TILES_H, zi * 1000 + 7)
	ground.centered = false
	ground.position = Vector2(zone_x, 0)
	ground.scale = Vector2(3, 3)
	ground.z_index = -10
	add_child(ground)

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
		add_enemy(Enemy.make(self, spawn[0], Vector2(zone_x + spawn[1], spawn[2])))

	if zone["boss"] != "":
		var trigger := Area2D.new()
		trigger.position = Vector2(zone_x + 1050, 360)
		trigger.collision_layer = 0
		trigger.collision_mask = 2
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(40, 560)
		cs.shape = shape
		trigger.add_child(cs)
		trigger.body_entered.connect(func(body: Node) -> void:
			if body is Player:
				_on_boss_trigger.call_deferred(zi)
		)
		add_child(trigger)


func _add_obstacle(sprite_name: String, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0 if sprite_name == "tree" else 11.0
	cs.shape = shape
	cs.position = Vector2(0, 10)
	body.add_child(cs)
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(3, 2)
	shadow.position = Vector2(0, 22)
	body.add_child(shadow)
	var spr := Sprite2D.new()
	spr.texture = Art.tex(sprite_name)
	spr.scale = Vector2(4, 4) if sprite_name == "tree" else Vector2(3, 3)
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
	sfx("roar")
	shake(6.0)
	current_boss = Boss.make_boss(self, kind, Vector2(zi * ZONE_W + 1380, 360))
	add_child(current_boss)
	hud.show_boss_bar(Story.ENEMIES[kind]["name"])


func on_boss_died(kind: String) -> void:
	boss_done[kind] = true
	var boss_pos := current_boss.global_position
	current_boss = null
	hud.hide_boss_bar()
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
				hud.set_quest(Story.QUESTS[quest_key])
			)
		"morwen":
			quest_key = "vargoth"
			hud.dialogue(Story.BEATS["post_morwen"], func() -> void:
				open_gate(2)
				hud.set_quest(Story.QUESTS[quest_key])
			)
		"vargoth":
			quest_key = "done"
			hud.set_quest(Story.QUESTS[quest_key])
			hud.dialogue(Story.BEATS["epilogue"], func() -> void:
				state = ST_VICTORY
				sfx("victory")
				hud.show_end_screen("VICTORY", "The Ember Crown is reclaimed. Thanks for playing Chapter 1!\nPress R to play again.", Color(1.0, 0.85, 0.35))
				get_tree().paused = true
			)


func on_enemy_died(e: Enemy) -> void:
	if e is Boss:
		return  # boss drops are handled in on_boss_died
	Pickup.drop_gold(self, e.gold_value, e.global_position)
	# Chance-based chest drops: mostly wood, sometimes silver.
	var roll := loot_rng.randf()
	if roll < 0.04:
		Chest.drop(self, "silver", e.global_position)
	elif roll < 0.18:
		Chest.drop(self, "wood", e.global_position)


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

func clamp_to_zone(pos: Vector2, anchor: Vector2) -> Vector2:
	var zi := clampi(int(anchor.x / ZONE_W), 0, ZONES - 1)
	return Vector2(
		clampf(pos.x, zi * ZONE_W + 80.0, (zi + 1) * ZONE_W - 80.0),
		clampf(pos.y, 90.0, WORLD_H - 90.0)
	)


func sfx(name: String) -> void:
	if not sounds.has(name):
		return
	for sp in sound_pool:
		if not sp.playing:
			sp.stream = sounds[name]
			sp.play()
			return
	sound_pool[0].stream = sounds[name]
	sound_pool[0].play()


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


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

	# Auto-aim reticle over the current target.
	var target := player.auto_aim()
	if target and not player.dead:
		reticle.visible = true
		reticle.global_position = target.global_position
	else:
		reticle.visible = false

	# Zone banner + ambient tint when crossing into a new zone.
	var zi := clampi(int(player.global_position.x / ZONE_W), 0, ZONES - 1)
	if zi != last_zone:
		if last_zone != -1 and play_started:
			hud.flash_title(Story.ZONES[zi]["name"])
		last_zone = zi
		var tween := create_tween()
		tween.tween_property(ambient, "color", ZONE_TINT[zi], 1.0)
	hud.set_zone(Story.ZONES[zi]["name"])

	# Evolution choice pops up as soon as nothing else is on screen.
	if player.pending_evolution and state == ST_PLAYING and not hud.dialogue_active and not menus.is_open():
		player.pending_evolution = false
		menus.open_evolution()

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
