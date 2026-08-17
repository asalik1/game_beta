extends ShotRig
## TRAILER CAPTURE RIG (temporary, 2026-08-17): boots the real game and records
## frame SEQUENCES of LIVE gameplay for a marketing trailer. Frames land in
## user://shots/cine/<clip>/f_%05d.png (one subfolder per clip); ffmpeg stitches
## + grades + scores them later from the game's own licensed music.
##
## TWO CAPTURE MODES:
##   SCRIPTED  — the rig drives the hero (obstacle-aware kite, casts, ults) and
##               captures every frame. Run under `--fixed-fps 30` for a smooth,
##               deterministic 1/30 s timestep, MUTED (`--audio-driver Dummy`).
##                 godot --audio-driver Dummy --fixed-fps 30 --path game \
##                   res://shot_cine.tscn -- --scene=hero --class=mage
##   --play    — YOU drive; the rig only records. Real keyboard controls the
##               hero (no injection). Run REAL-TIME (NO --fixed-fps). Sets up the
##               scene, holds enemies frozen through a 3-2-1-GO countdown, then
##               records `--secs` seconds at ~30 fps wall-clock. God-HP + infinite
##               mana so a showcase never dies. Human play = authentic footage.
##                 godot --path game res://shot_cine.tscn -- \
##                   --scene=hero --class=mage --play --secs=16
##
## SCENES (--scene=): cycle | hero | bossfight | biomes | bosses | capital | horde
##   hero      --class=<c>              mob-kite: a semicircle swarm presses from
##                                       one side, hero kites out the open side
##   bossfight --class=<c> --boss=<k>   kite a boss with the full kit + ult
##   cycle     --list=a,b,boss:c:k,...  PLAY many scenes back-to-back in ONE
##                                       launch (no engine restart between them);
##                                       default list = the six classes
##   biomes | bosses | capital | horde  world/reveal reels (scripted)
##
## FLAGS: --secs=N (play length) · --nocd (zero cooldowns) · --hud (keep HUD) ·
##        --watch (no capture, just watch it) · --boss=<kind> · --list=<csv>

const FPS := 30

var _clip := ""
var _fn := 0
var _mobs: Array = []
var _watch := false          # --watch: skip capture, run real-time + audio to WATCH it


# ---------------------------------------------------------------- capture ----

func _begin(clip: String) -> void:
	_clip = clip
	_fn = 0
	var dir := ProjectSettings.globalize_path("%s/%s" % [shot_dir, clip])
	DirAccess.make_dir_recursive_absolute(dir)
	# Wipe an earlier take so re-records never mix with stale frames.
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if f.begins_with("f_") and f.ends_with(".png"):
				d.remove(f)
	step("clip " + clip)


func _cap() -> void:
	if _watch:
		return                   # watch mode: no disk I/O, just play it smooth
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s/f_%05d.png" % [
		ProjectSettings.globalize_path(shot_dir), _clip, _fn])
	_fn += 1


## Record `seconds` of frames at FPS (chatter frozen every frame).
func _record(seconds: float) -> void:
	var n := int(seconds * FPS)
	for i in n:
		_quiet()
		await get_tree().process_frame
		_cap()


# ----------------------------------------------------------------- input ----

func _key(k: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _walk(k: Key, seconds: float) -> void:
	_key(k, true)
	await _record(seconds)
	_key(k, false)


func _cast(slot: String) -> void:
	var p := game.player
	p.cds[slot] = 0.0
	p.mp = p.max_mp
	p.use_ability(slot)


# ----------------------------------------------------------------- world ----

func _quiet() -> void:
	if game != null:
		game.npc_emote_t = 1.0e9   # freeze NPC idle-chatter bubbles


func _clear_mobs() -> void:
	for m in _mobs:
		if is_instance_valid(m):
			m.queue_free()
	_mobs.clear()


## Freeze / release every enemy's AI (movement + attacks) — held during the
## play countdown so the fight starts exactly on GO, not before.
func _freeze_enemies(frozen: bool) -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.set_physics_process(not frozen)
			n.set_process(not frozen)


## Free EVERY enemy in the room (native spawns included) for controlled staging.
func _clear_field() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.queue_free()
	_mobs.clear()


## Jump the hero into overworld room `i` (bypasses the fast-travel unlock gate),
## build/enter it, then clear its native mobs so the staged fight is clean.
func _goto(i: int) -> void:
	game.player.global_position = game.room_center(i)
	game._enter_room(i)
	await frames(10)
	_clear_field()
	await frames(2)


# Per-class combat arena — an authentic, varied ch1 zone for each class.
const HERO_ROOM := {
	"mage": 2,       # The Darkwood Road (forest)
	"archer": 4,     # Wolfpaths (forest)
	"assassin": 7,   # The Deep Darkwood
	"warrior": 17,   # The Outer Bailey (ruined keep)
	"paladin": 20,   # The Inner Ward (keep)
	"warlock": 22,   # The Throne Approach (keep) — open stone, no tall props to bury him
}


## Ring of mobs around `center`. Immortal by default so they persist as targets
## for the whole ability combo (deaths empty the frame in ~1 s under god-mode);
## hits still flinch and damage numbers still fly.
func _swarm(kinds: Array, center: Vector2, radius := 110.0, immortal := true) -> void:
	var i := 0
	for k in kinds:
		var ang := TAU * float(i) / float(maxi(kinds.size(), 1)) - PI / 2.0
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * radius
		var e := spawn_enemy(String(k), pos, immortal)
		if e != null and is_instance_valid(e):
			e.alerted = true
			_mobs.append(e)
		i += 1
	await frames(4)


## A tight PACK at `center` (3-wide jittered grid). Immortal by default so the
## pack stays intact through the whole combo — the horde scene is where they die.
func _cluster(kinds: Array, center: Vector2, spread: float, immortal := true) -> void:
	var i := 0
	for k in kinds:
		var off := Vector2(float(i % 3 - 1), float(i / 3 - 1)) * spread
		off += Vector2(float((i * 37) % 20 - 10), float((i * 53) % 20 - 10))  # jitter
		var e := spawn_enemy(String(k), center + off, immortal)
		if e != null and is_instance_valid(e):
			e.alerted = true
			_mobs.append(e)
		i += 1
	await frames(4)


## Mobs SURROUNDING the hero on every side (two staggered rings) — the swarm
## that closes in and forces the squishy to keep moving. Immortal by default so
## the pressure never lets up through the whole kite (the "fear" beat).
func _ring_surround(kinds: Array, center: Vector2, radius: float, immortal := true) -> void:
	var n := kinds.size()
	for i in n:
		var ang := TAU * float(i) / float(maxi(n, 1))
		var r := radius + float(i % 2) * 55.0
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * r
		var e := spawn_enemy(String(kinds[i]), pos, immortal)
		if e != null and is_instance_valid(e):
			e.alerted = true          # skip the "!" tell + chase immediately
			_mobs.append(e)
	await frames(4)


## A SEMI-CIRCLE of mobs pressing in from `dir_deg` across `arc_deg` degrees —
## the threat comes from one side and the far side stays OPEN, so the hero can
## actually kite out of it (a full ring body-blocks the escape). Immortal so the
## pursuit never lets up.
func _arc_surround(kinds: Array, center: Vector2, radius: float,
		dir_deg: float, arc_deg: float, immortal := true) -> void:
	var n := kinds.size()
	for i in n:
		var frac := (float(i) / float(maxi(n - 1, 1))) - 0.5       # -0.5..0.5
		var ang := deg_to_rad(dir_deg + frac * arc_deg)
		var r := radius + float(i % 2) * 55.0
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * r
		var e := spawn_enemy(String(kinds[i]), pos, immortal)
		if e != null and is_instance_valid(e):
			e.alerted = true
			_mobs.append(e)
	await frames(4)


## The KITE — the whole point of playing a squishy. Move the hero along `legs`
## ([[key, secs], ...]; key 0 = stand) while SPAMMING the low-CD basic every
## `a1_dt`s the entire time, and firing scheduled signature/ultimate abilities
## from `extras` ([[t_seconds, slot], ...]). Auto-aim keeps every basic and the
## ult landing on the swarm that chases. Captures every frame.
func _kite_run(legs: Array, extras: Array, a1_dt := 0.26) -> void:
	var plan: Array = []                    # one movement key per frame
	for l in legs:
		for i in int(float(l[1]) * FPS):
			plan.append(int(l[0]))
	var cur := -1
	var ei := 0
	var last_a1 := -99.0
	for f in plan.size():
		var t := float(f) / float(FPS)
		var k: int = plan[f]
		if k != cur:
			if cur > 0:
				_key(cur as Key, false)
			if k > 0:
				_key(k as Key, true)
			cur = k
		while ei < extras.size() and float(extras[ei][0]) <= t:
			_cast(String(extras[ei][1])); ei += 1
		if t - last_a1 >= a1_dt:
			_cast("a1"); last_a1 = t
		_quiet()
		await get_tree().process_frame
		_cap()
	if cur > 0:
		_key(cur as Key, false)


## Press the 8-way key combo closest to direction `v` (releasing the rest).
func _press_dir(v: Vector2, pressed: Dictionary) -> void:
	var want := {}
	if v.y < -0.38: want[KEY_W] = true
	if v.y > 0.38:  want[KEY_S] = true
	if v.x < -0.38: want[KEY_A] = true
	if v.x > 0.38:  want[KEY_D] = true
	for k in pressed.keys():
		if not want.has(k):
			_key(k as Key, false)
			pressed.erase(k)
	for k in want.keys():
		if not pressed.has(k):
			_key(k as Key, true)
			pressed[k] = true


func _release_keys(pressed: Dictionary) -> void:
	for k in pressed.keys():
		_key(k as Key, false)
	pressed.clear()


## SMART kite: every frame steer away from (or, if `approach`, toward) the live
## threat point `threat_fn`, bias off the room walls, and — the fix for getting
## stuck — when the hero STALLS against terrain, rotate the heading to slide
## around it. Basic fires nonstop; `extras` schedules the signature/ult casts.
func _kite_smart(seconds: float, threat_fn: Callable, extras: Array,
		a1_dt := 0.24, approach := false) -> void:
	var p := game.player
	var rr := game.room_rect(game.cur_room)
	var inset := 130.0
	var lo := rr.position + Vector2(inset, inset)
	var hi := rr.end - Vector2(inset, inset)
	var total := int(seconds * FPS)
	var ei := 0
	var last_a1 := -99.0
	var last_pos := p.global_position
	var stuck := 0.0
	var steer := 0.0
	var pressed := {}
	for f in total:
		var t := float(f) / float(FPS)
		var threat: Vector2 = threat_fn.call()
		var v := (threat - p.global_position) if approach else (p.global_position - threat)
		if v.length() < 1.0:
			v = Vector2.RIGHT
		v = v.normalized()
		# Steer back inside the room when hugging a wall.
		var center_pull := Vector2.ZERO
		if p.global_position.x < lo.x: center_pull.x += 1.0
		if p.global_position.x > hi.x: center_pull.x -= 1.0
		if p.global_position.y < lo.y: center_pull.y += 1.0
		if p.global_position.y > hi.y: center_pull.y -= 1.0
		if center_pull != Vector2.ZERO:
			v = (v * 0.4 + center_pull.normalized() * 1.3).normalized()
		v = v.rotated(steer)
		_press_dir(v, pressed)
		while ei < extras.size() and float(extras[ei][0]) <= t:
			_cast(String(extras[ei][1])); ei += 1
		if t - last_a1 >= a1_dt:
			_cast("a1"); last_a1 = t
		_quiet()
		await get_tree().process_frame
		_cap()
		var moved := p.global_position.distance_to(last_pos)
		last_pos = p.global_position
		if moved < 1.5:
			stuck += 1.0 / float(FPS)
			if stuck > 0.15:
				steer += deg_to_rad(50.0)     # rotate to slide around the obstacle
				stuck = 0.0
		else:
			stuck = 0.0
			steer = lerpf(steer, 0.0, 0.12)   # relax back to straight flight
	_release_keys(pressed)


## Centre of mass of the living staged swarm (falls back to the hero).
func _swarm_centroid() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for m in _mobs:
		if is_instance_valid(m):
			sum += (m as Node2D).global_position
			n += 1
	return sum / float(n) if n > 0 else game.player.global_position


## Fire the ultimate at the DENSEST part of the swarm for max-AoE payoff — never
## a lone straggler (auto-aim picks nearest, which the trailer must not rely on).
func _ult_on_swarm() -> void:
	var p := game.player
	var c := _swarm_centroid()
	p.cds["ult"] = 0.0
	p.mp = p.max_mp
	p.facing = (c - p.global_position).normalized()
	if p.cls == "mage":
		p._meteor_at(c)              # aim the meteor exactly on the pack
	else:
		p.use_ability("ult")         # archer/warlock AoE auto-aims the tight blob


## Pin the camera to the hero (no smoothing lag) for stable trailer framing.
func _lock_cam() -> void:
	game.camera.position_smoothing_enabled = false


## Slide the camera by lerping its local offset while recording — a dolly/pan
## that does not need the hero to walk (used for city vistas).
func _pan(seconds: float, from_off: Vector2, to_off: Vector2) -> void:
	var n := int(seconds * FPS)
	for i in n:
		_quiet()
		var t := float(i) / float(maxi(n - 1, 1))
		game.camera.offset = from_off.lerp(to_off, t)
		await get_tree().process_frame
		_cap()
	game.camera.offset = Vector2.ZERO


# ----------------------------------------------------------------- scenes ----

var _play := false           # --play: YOU drive the hero; the rig only records

## Human-play recording: set up done, now hand control to the player and capture
## real-time for `secs`. No input injection — real keyboard drives the hero.
## Infinite mana (and --nocd zeroes cooldowns) for a clean showcase; captures at
## ~30 fps of WALL-CLOCK time so playback is real-speed regardless of render fps.
func _play_record(secs: float) -> void:
	var nocd := flag("nocd")
	DisplayServer.window_move_to_foreground()       # focused window renders full-speed
	_freeze_enemies(true)                           # HOLD the fight until GO
	print("========================================")
	print("  PLAY '%s' — %.0f s after GO" % [_clip, secs])
	print("========================================")
	# On-screen 3-2-1-GO so you know exactly when the capture starts (HUD hidden).
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 120)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 10)
	layer.add_child(lbl)
	for c in ["3", "2", "1", "GO"]:
		lbl.text = c
		await get_tree().create_timer(0.6).timeout
	layer.queue_free()
	_freeze_enemies(false)                          # RELEASE the swarm on GO
	var start := Time.get_ticks_msec()
	var last := -100
	while Time.get_ticks_msec() - start < int(secs * 1000.0):
		var p := game.player
		if p != null:
			p.mp = p.max_mp
			p.hp = p.max_hp
			if nocd:
				for s in ["a1", "a2", "a3", "ult"]:
					p.cds[s] = 0.0
		_quiet()
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if now - last >= 33:            # ~30 fps wall-clock cadence
			last = now
			_cap()
	print("=== RECORDING DONE: %d frames (%s) ===" % [
		_fn, ProjectSettings.globalize_path("%s/%s" % [shot_dir, _clip])])


func _ready() -> void:
	_watch = flag("watch")
	_play = flag("play")
	if _watch or _play:
		AudioServer.set_bus_mute(0, false)   # you're driving it — let it sing
	var scene := arg("scene", "hero")
	var cls := arg("class", "mage")
	match scene:
		"cycle":     await _scene_cycle()
		"hero":      await _scene_hero(cls)
		"horde":     await _scene_horde(cls)
		"biomes":    await _scene_biomes()
		"bosses":    await _scene_bosses()
		"bossfight": await _scene_bossfight(cls, arg("boss", "vargoth"))
		"capital":   await _scene_capital()
		_:           await _scene_hero(cls)
	print("CINE DONE scene=%s frames_last_clip=%d" % [scene, _fn])
	finish()


## PLAYLIST — one launch, many scenes back-to-back (no engine restart between
## them, just a fast world rebuild). Each entry gets its own 3-2-1-GO + record.
## `--list=` is comma-separated; an entry is a class ("mage") for the mob-kite
## scene, or "boss:<class>:<kind>" for a boss fight. Default = the six classes.
func _scene_cycle() -> void:
	_play = true
	AudioServer.set_bus_mute(0, false)   # you're playing it — sound on (unless Dummy)
	var entries := arg("list",
		"mage,warrior,archer,assassin,paladin,warlock").split(",", false)
	for idx in entries.size():
		var e := entries[idx].strip_edges()
		print("######## CYCLE %d/%d : %s ########" % [idx + 1, entries.size(), e])
		if game != null:
			game.queue_free()
			game = null
			await frames(6)
		var parts := e.split(":")
		if parts.size() >= 2 and parts[0] == "boss":
			var bk := parts[2] if parts.size() > 2 else "vargoth"
			await _scene_bossfight(parts[1], bk)
		else:
			await _scene_hero(parts[0])


## Per-class combat combo: walk in, basics, then the two signature abilities and
## the ultimate — one flowing take, camera locked on the hero.
func _scene_hero(cls: String) -> void:
	await boot(cls, "ch1")
	_quiet(); _lock_cam()
	if not flag("hud"):
		hide_hud()
	await get_tree().create_timer(1.2 if _play else 2.5).timeout   # title card clears
	var p := game.player
	var room := int(arg("room", str(HERO_ROOM.get(cls, 2))))
	await _goto(room)
	zoom(1.4)
	var rr := game.room_rect(room)
	# Melee-only roster so the swarm CLUMPS tightly behind the kiting hero (a
	# ranged straggler kept pulling the auto-aimed ult off the pack).
	var kinds := ["wolf", "beastkin_raider", "blightwolf", "skeleton", "spider",
		"beastkin_howler", "zombie", "blightwolf"]
	var horde := kinds + kinds                 # 16 — a wall pressing from one side
	# Mobs press from the RIGHT; the hero sits left-of-centre with open room to
	# flee LEFT. A brief beat — mobs only show the per-class danger of running
	# and shooting; the ULT is saved for the boss fights.
	p.global_position = rr.position + Vector2(rr.size.x * 0.62, rr.size.y * 0.5)
	game.camera.global_position = p.global_position
	_begin("hero_" + cls)
	await _arc_surround(horde, p.global_position, 200.0, 0.0, 200.0)   # right-facing arc

	if _play:
		await _play_record(float(arg("secs", "14")))
		_clear_mobs(); return

	var swarm_at := func() -> Vector2: return _swarm_centroid()
	if cls in ["mage", "archer", "warlock"]:
		# SQUISHY KITE: smart-flee the pack (obstacle-aware) while the basic fires
		# nonstop back at it; weave the mobility/AoE. No ult (that's for bosses).
		await _kite_smart(3.0, swarm_at, [[0.9, "a2"], [1.9, "a3"]], 0.22)
	elif cls == "assassin":
		# DASH DANCE: dart around the pack (short-CD dash), fan knives between
		# dashes, basics stab. No ult here.
		await _kite_smart(3.0, swarm_at,
			[[0.15, "a2"], [0.6, "a3"], [1.2, "a2"], [1.7, "a3"], [2.2, "a2"]], 0.38)
	else:
		# MELEE WADE (warrior/paladin): push INTO the pack — gap-close, cleave,
		# ground-AoE. Aggressive, not a retreat. No ult here.
		await _kite_smart(2.8, swarm_at, [[0.3, "a2"], [1.2, "a3"], [2.0, "a2"]], 0.3, true)
	await _record(0.3)
	_clear_mobs()


## Denser swarm, AoE-forward: for the "outnumbered" beat.
func _scene_horde(cls: String) -> void:
	await boot(cls, "ch1")
	_quiet(); _lock_cam()
	if not flag("hud"):
		hide_hud()
	await get_tree().create_timer(2.5).timeout
	var p := game.player
	p.global_position += Vector2(-30, -80)
	game.camera.global_position = p.global_position
	zoom(1.35)
	await frames(4)

	_begin("horde_" + cls)
	var kinds := ["wolf", "beastkin_raider", "blightwolf", "beastkin_howler", "wildkin_ranger",
		"skeleton", "spider", "blightwolf", "beastkin_raider", "wolf"]
	_swarm(kinds, p.global_position, 170.0, false)   # active + mortal: the ult wipes them
	await _record(0.6)
	_cast("a2"); await _record(1.0)
	_cast("ult"); await _record(2.6)
	_cast("a3"); await _record(1.4)
	_clear_mobs()


## World-variety reel: repaint an open room through each biome, with a couple
## of terrain-native mobs as life, and drop a meteor for a payoff per biome.
func _scene_biomes() -> void:
	await boot("mage", "ch1")
	_quiet(); _lock_cam()
	if not flag("hud"):
		hide_hud()
	await get_tree().create_timer(2.0).timeout
	await _goto(6)                                  # Ravine Edge: open, no NPCs
	var p := game.player
	var rr := game.room_rect(6)
	p.global_position = rr.position + Vector2(rr.size.x * 0.45, rr.size.y * 0.45)
	game.camera.global_position = p.global_position
	zoom(1.35)
	var native := {"magma": "cinder_whelp", "icefield": "frost_husk", "void": "void_husk",
		"holy": "sun_bleached", "graveyard": "gravewalker", "crystalline": "void_shade"}
	for t in ["magma", "icefield", "void", "holy", "graveyard", "crystalline"]:
		_clear_mobs()
		game.apply_terrain(6, t)
		game.ambient.color = Terrains.get_terrain(t)["tint"]
		_quiet()
		await frames(10)
		var mk := String(native[t])
		await _cluster([mk, mk, mk], p.global_position + Vector2(280, 20), 60.0)
		_begin("biome_" + t)
		p.facing = Vector2.RIGHT
		_cast("ult")
		await _record(2.4)
	_clear_mobs()


## Boss reveals: spawn each through the real dev-spawn path and hold on it, in
## the ruined-keep for a consistently epic backdrop.
func _scene_bosses() -> void:
	await boot("mage", "ch1")
	_quiet(); _lock_cam()
	if not flag("hud"):
		hide_hud()
	await get_tree().create_timer(2.0).timeout
	await _goto(17)                                 # The Outer Bailey (keep ruins)
	var p := game.player
	var rr := game.room_rect(17)
	p.global_position = rr.position + Vector2(rr.size.x * 0.32, rr.size.y * 0.52)
	game.camera.global_position = p.global_position + Vector2(120, -10)
	zoom(1.05)
	for k in ["vargoth", "fangmaw", "stormdrake_veyx", "morwen", "cinderhide", "choirmother"]:
		_clear_field()
		game.dev_spawn({"what": "boss", "kind": k,
			"pos": p.global_position + Vector2(230, 0)})
		await frames(10)
		_begin("boss_" + k)
		# Hero engages: casting auto-aims at the boss, so the sprite faces it
		# (a bare `facing =` never flips the idle) — a confrontation, not a stare.
		_cast("a1"); await _record(1.1)
		_cast("a1"); await _record(1.6)
	_clear_field()


## A real BOSS FIGHT (not a stare): the chosen class KITES the boss — running the
## keep while the basic peppers it nonstop — and unloads the FULL kit, the ULT as
## the finale (single target, so it always lands). Fear + spectacle + the ult
## showcase. `--class=<c> --boss=<kind>`.
func _scene_bossfight(cls: String, boss_kind: String) -> void:
	await boot(cls, "ch1")
	_quiet(); _lock_cam()
	if not flag("hud"):
		hide_hud()
	await get_tree().create_timer(1.2 if _play else 2.0).timeout
	await _goto(17)                                 # The Outer Bailey (keep ruins)
	var p := game.player
	var rr := game.room_rect(17)
	p.global_position = rr.position + Vector2(rr.size.x * 0.46, rr.size.y * 0.5)
	game.camera.global_position = p.global_position
	zoom(1.12)
	game.dev_spawn({"what": "boss", "kind": boss_kind,
		"pos": p.global_position + Vector2(-320, 0)})   # boss looms on the LEFT
	await frames(10)
	_begin("bossfight_%s_%s" % [cls, boss_kind])

	if _play:
		await _play_record(float(arg("secs", "16")))
		_clear_field(); return

	var melee := cls in ["warrior", "paladin", "assassin"]
	if melee:
		# Melee closes on the boss, weaving in and out; full kit + ult.
		await _kite_run(
			[[KEY_A, 0.55], [KEY_W, 0.4], [KEY_A, 0.5], [KEY_S, 0.4], [KEY_D, 0.4]],
			[[0.4, "a2"], [1.3, "a3"], [2.1, "a2"], [3.0, "ult"]], 0.28)
	else:
		# Ranged kites RIGHT into the open, basic peppering the boss; full kit + ult.
		await _kite_run(
			[[KEY_D, 0.75], [KEY_W, 0.5], [KEY_D, 0.65], [KEY_S, 0.5], [KEY_D, 0.5]],
			[[1.0, "a2"], [2.1, "a3"], [3.2, "ult"]], 0.24)
	await _record(2.0)                              # hold the ult on the boss
	_clear_field()


## Crownfall city vistas: enter the capital and slow-pan a few authored rooms.
func _scene_capital() -> void:
	await boot("warrior", "ch1")
	hide_hud(); _quiet()
	await get_tree().create_timer(1.5).timeout
	game.enter_capital()
	await frames(14)
	await skip_dialogue()          # dismiss the arrival convo — it blocks fast_travel
	await frames(6)
	_lock_cam()
	zoom(0.82)
	var rooms := [0, 1, 2, 3, 4, 5]
	for i in rooms:
		if i >= game.zone_count:
			break
		game.fast_travel(i)
		await get_tree().create_timer(1.4).timeout   # travel vignette settles
		_quiet()
		_begin("capital_%02d" % i)
		await _pan(3.0, Vector2(-150, 0), Vector2(150, 0))
