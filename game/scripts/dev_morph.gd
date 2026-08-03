class_name DevMorph extends Node2D
## Dev-mode TRANSFORM (the codex card's "Transform" button, dev launcher
## only): wear a monster/boss body over the hero to road-test its walk/idle/
## attack strips with real movement, on real terrain. PRESENTATION ONLY —
## movement, damage intake and potions keep working; the ability keys become
## the clip test rig (player.gd suppresses real casts while `plr.dev_morph`
## is set, and walks at the creature's table speed so foot-slide reads true):
##   A1  — the basic swing (attack/melee/ability/cast, first that ships)
##   A2  — cycle to the next discovered clip and play it (name floats up)
##   A3  — replay the current cycled clip
##   ULT — the death strip, as a one-shot preview
## Revert from the same codex card; death/downed auto-reverts to the hero.
##
## The render path deliberately mirrors enemy.gd's (idle/walk swap with the
## hysteretic dead band, 8-dir strip pick, single-facing flip, oversized-
## ability-cell feet anchor, the 2x-walk anim clock) so the preview can't
## drift from what a real spawn does. One divergence, on purpose: an idle
## morph HOLDS the last walked facing instead of resting south, so all eight
## idle rotations can be reviewed — engaged enemies face their prey, so every
## facing occurs in-game anyway.

var plr: Player = null
var kind := ""           # Story.ALL_ENEMIES key (the codex toggle reads it)
var move_speed := 250.0  # the creature's table speed — player.gd walks at it
var sprite: Sprite2D = null

var _sprite_key := ""
var _art_scale := 1.0
var _face_left := false
var _base_mod := Color(1, 1, 1)
var _strip_idle := {}
var _strip_walk := {}
var _dir_idle := {}      # {DIR8: strip} idle rotations, {} when not directional
var _dir_walk := {}
var _strip_action := {}  # one-shot clip in flight ({} = locomotion)
var _action_dir := {}
var _action_t := 0.0
var _anim_frames := 0
var _anim_fps := 6.0
var _anim_t := 0.0
var _body_cell := 0.0    # square idle/walk cell px; ability strips scale off it
var _moving := false     # hysteretic walk latch (enemy.gd's dead band)
var _strip_walking := false
var _cur_dir := "s"
var _face_vx := 0.0
var _last_face := Vector2.ZERO  # idle facing memory (see header)
var _actions: Array = []
var _cursor := -1
var _held := {}          # slot -> held-last-frame (intents are held-state; edge here)


## Become `enemy_kind`. Replaces any active morph; the codex builds the button.
static func start(p: Player, enemy_kind: String) -> void:
	stop(p)
	if p == null or not Story.ALL_ENEMIES.has(enemy_kind):
		return
	var mm := DevMorph.new()
	mm.plr = p
	mm.kind = enemy_kind
	p.dev_morph = mm
	p.add_child(mm)


## Back to the hero. Safe to call when nothing is active.
static func stop(p: Player) -> void:
	if p == null or p.dev_morph == null:
		return
	if is_instance_valid(p.dev_morph):
		p.dev_morph._restore()
		p.dev_morph.queue_free()
	p.dev_morph = null


func _ready() -> void:
	var st: Dictionary = Story.ALL_ENEMIES[kind]
	_sprite_key = String(st["sprite"])
	_art_scale = float(st.get("scale", 1.0))
	move_speed = float(st.get("speed", 250.0))
	_face_left = Art.faces_left(_sprite_key)
	var def_tint: Variant = st.get("tint")
	if def_tint is Color:
		_base_mod = def_tint
	# Mob/boss art is CENTER-anchored, the hero feet-anchored — sit the morph
	# so the creature's shadow line lands on the hero's shadow (+20).
	position = Vector2(0, 20.0 - 6.0 * _art_scale * Balance.CHAR_RENDER_SCALE)
	sprite = Sprite2D.new()
	var anim := Art.anim_info(_sprite_key)
	if anim.is_empty():
		sprite.texture = Art.tex(_sprite_key)
		sprite.scale = Art.scale_for(sprite.texture, _art_scale * Balance.CHAR_RENDER_SCALE)
	else:
		_strip_idle = anim
		_strip_walk = Art.walk_info(_sprite_key)
		_dir_idle = Art.dir_set(_sprite_key + "_anim")
		_dir_walk = Art.dir_set(_sprite_key + "_walk")
		_apply_strip(anim)
	sprite.modulate = _base_mod
	add_child(sprite)
	_actions = _discover_actions(_sprite_key)
	_anim_t = randf() * 10.0
	if plr.game != null:
		plr.game.spawn_text(plr.global_position + Vector2(0, -84),
			"MORPH: " + String(st.get("name", kind)), Color(0.7, 0.95, 0.85))
		plr.game.spawn_text(plr.global_position + Vector2(0, -60),
			"A1 attack · A2 next clip · A3 replay · ULT death", Color(0.6, 0.75, 0.7))


func _restore() -> void:
	if plr == null or not is_instance_valid(plr):
		return
	if plr.sprite != null:
		plr.sprite.visible = true
	if plr._skin_ambient != null and is_instance_valid(plr._skin_ambient):
		plr._skin_ambient.visible = true


func _physics_process(delta: float) -> void:
	if plr == null or not is_instance_valid(plr):
		return
	if plr.dead or plr.downed or plr.ghost:
		DevMorph.stop(plr)  # the hero's own death/downed presentation takes over
		return
	# Re-assert every frame: set_class/set_skin retarget the hero sprite and a
	# mythic's _sync_skin_ambient can rebuild its ambient mid-morph.
	plr.sprite.visible = false
	if plr._skin_ambient != null and is_instance_valid(plr._skin_ambient):
		plr._skin_ambient.visible = false
	_poll_slots()

	_anim_t += delta
	var spd := plr.velocity.length()
	if _moving and spd < 12.0:
		_moving = false
	elif not _moving and spd > 34.0:
		_moving = true
	if spd > 20.0:
		_last_face = plr.velocity
	if not _strip_action.is_empty():
		# One-shot clip: play frames 0..N-1 once, then revert to locomotion.
		_advance_action(delta)
	elif _anim_frames > 1 or not _dir_idle.is_empty() or not _dir_walk.is_empty():
		# Walk/idle split, exactly enemy.gd's shape: single-facing art keeps the
		# flip path; 8-direction art picks the strip by facing — and runs even
		# for 1-frame idle rotations.
		var directional_loco := (_moving and not _dir_walk.is_empty()) \
			or (not _moving and not _dir_idle.is_empty())
		if not directional_loco:
			if not _strip_walk.is_empty() and _moving != _strip_walking:
				_strip_walking = _moving
				_apply_strip(_strip_walk if _moving else _strip_idle)
			if _moving:
				_anim_t += delta
			sprite.frame = int(_anim_t * _anim_fps) % _anim_frames
		else:
			var nd := Art.dir8_suffix(_facing_vec())
			var dset: Dictionary = _dir_walk if (_moving and not _dir_walk.is_empty()) else _dir_idle
			if nd != _cur_dir or _moving != _strip_walking:
				_cur_dir = nd
				_strip_walking = _moving
				_apply_strip(dset[nd])
			if _moving:
				_anim_t += delta
			sprite.frame = int(_anim_t * _anim_fps) % _anim_frames
			sprite.flip_h = false
	# Single-facing flip (enemy.gd's orientation block; the prey-facing branch
	# is dropped — the reviewer's own movement IS the facing under test).
	_face_vx = lerpf(_face_vx, plr.velocity.x, 0.2)
	var os := 0.0
	if absf(_face_vx) > 8.0:
		os = signf(_face_vx)
	var directional := (_moving and not _dir_walk.is_empty()) \
		or (not _moving and not _dir_idle.is_empty())
	if os != 0.0 and _action_dir.is_empty() and (not directional or not _strip_action.is_empty()):
		sprite.flip_h = (os > 0.0) if _face_left else (os < 0.0)
	# Mirror the hero's hurt-flash alpha so getting hit still reads.
	sprite.modulate = _base_mod
	sprite.modulate.a = 0.55 if plr.hurt_cd > 0.0 else _base_mod.a


## 2D facing for 8-direction art: the current movement while walking, else
## the last walked direction (all eight idle rotations stay reviewable).
func _facing_vec() -> Vector2:
	if plr.velocity.length() > 20.0:
		return plr.velocity
	return _last_face


# ------------------------------------------------------------ clip test rig

## Edge-detect the held ability intents (same guard game.gd's tap-to-talk
## uses: overlays gate input — the tree pause is a no-op online, §5.4).
func _poll_slots() -> void:
	if plr.game != null and (plr.game.menus.is_open()
			or plr.game.hud.dialogue_active or plr.game.hud.choices_active):
		return
	var slots := {"a1": plr.intent_a1, "a2": plr.intent_a2,
			"a3": plr.intent_a3, "ult": plr.intent_ult}
	for slot in slots:
		var held_now: bool = slots[slot]
		var was: bool = _held.get(slot, false)
		_held[slot] = held_now
		if held_now and not was:
			_on_slot(String(slot))


func _on_slot(slot: String) -> void:
	if not _strip_action.is_empty():
		return  # let the running one-shot finish; holding = continuous replay
	match slot:
		"a1":
			_play_named(_basic_action())
		"a2":
			if not _actions.is_empty():
				_cursor = (_cursor + 1) % _actions.size()
				_play_named(String(_actions[_cursor]))
		"a3":
			_play_named(String(_actions[_cursor]) if _cursor >= 0 else _basic_action())
		"ult":
			if _actions.has("death"):
				_play_named("death")


func _basic_action() -> String:
	return DevMorph.basic_of(_actions)


## The creature's "basic swing" out of its discovered clips.
static func basic_of(actions: Array) -> String:
	for pref in ["attack", "melee", "ability", "cast"]:
		if actions.has(pref):
			return pref
	return String(actions[0]) if not actions.is_empty() else ""


## Point the one-shot at <key>_<action> — the 8-direction set when it ships
## (facing locked at trigger), else the flat strip. enemy.gd's
## _try_action_strip, minus the net RPC.
func _play_named(action: String) -> void:
	if action == "" or _strip_idle.is_empty():
		return
	var dset := Art.dir_set("%s_%s" % [_sprite_key, action])
	if not dset.is_empty():
		_action_dir = dset
		var suf := Art.dir8_suffix(_facing_vec())
		_strip_action = dset[suf]
		_action_t = 0.0
		_apply_strip(_strip_action, true)
		_anim_fps = Balance.BOSS_ABILITY_FPS
		sprite.flip_h = false
	else:
		var info := Art.action_info(_sprite_key, action)
		if info.is_empty():
			return
		_strip_action = info
		_action_dir = {}
		_action_t = 0.0
		_apply_strip(info, true)
		_anim_fps = Balance.BOSS_ABILITY_FPS
	if plr.game != null:
		plr.game.spawn_text(plr.global_position + Vector2(0, -70),
			action.to_upper(), Color(0.7, 0.95, 0.85))


func _advance_action(delta: float) -> void:
	_action_t += delta
	var idx := int(_action_t * _anim_fps)
	if idx >= _anim_frames:
		_end_action()
	else:
		sprite.frame = idx


func _end_action() -> void:
	_strip_action = {}
	_action_dir = {}
	_action_t = 0.0
	_strip_walking = false
	_cur_dir = ""  # force the idle path to re-pick a directional strip next frame
	if not _strip_idle.is_empty():
		_apply_strip(_strip_idle)


## Point the Sprite2D at a strip — enemy.gd's _apply_strip with the same
## body-cell reference + feet anchor (Enemy._strip_feet_y shares its cache),
## at a fixed size_var of 1.0.
func _apply_strip(info: Dictionary, is_action := false) -> void:
	sprite.texture = info["tex"]
	var frames := int(info["frames"])
	sprite.hframes = frames
	sprite.frame = 0
	_anim_frames = frames
	_anim_fps = float(info["fps"])
	var cell := float(sprite.texture.get_height())
	if not is_action:
		_body_cell = cell
	var ref := _body_cell if _body_cell > 0.0 else cell
	var s := _art_scale * Balance.CHAR_RENDER_SCALE * 16.0 / ref
	sprite.scale = Vector2(s, s)
	var off := -(cell - ref) / 2.0
	if is_action and absf(cell - ref) > 0.5:
		var bf := Enemy._strip_feet_y(_strip_idle.get("tex", null), ref)
		var af := Enemy._strip_feet_y(sprite.texture, cell)
		if bf >= 0.0 and af >= 0.0:
			off = (bf - ref / 2.0) - (af - cell / 2.0)
	sprite.offset = Vector2(0, off)


# ---------------------------------------------------------- clip discovery

## Every one-shot clip this sprite ships, from the installed files themselves:
## assets/sprites/<key>_<action>[_<dir>].png, minus locomotion (anim/walk),
## non-clip stills, and any SUB-CHARACTER namespace (mummy -> mummy_mage_*:
## a suffix with its own _anim/_walk strip is a standalone body, not a clip).
## Dev-only, so the res:// directory scan is always the real filesystem.
static var _actions_cache := {}

static func _discover_actions(key: String) -> Array:
	if _actions_cache.has(key):
		return _actions_cache[key]
	var prefix := key + "_"
	var files := DirAccess.get_files_at("res://assets/sprites")
	var subchars := {}
	for f in files:
		var stem := String(f)
		if not stem.ends_with(".png"):
			continue
		stem = stem.trim_suffix(".png")
		var base := ""
		if stem.ends_with("_anim"):
			base = stem.trim_suffix("_anim")
		elif stem.ends_with("_walk"):
			base = stem.trim_suffix("_walk")
		if base != "" and base != key and base.begins_with(prefix):
			subchars[base] = true
	for k2 in Story.ALL_ENEMIES:
		var s2 := String(Story.ALL_ENEMIES[k2].get("sprite", ""))
		if s2 != key and s2.begins_with(prefix):
			subchars[s2] = true
	var found := {}
	for f in files:
		var stem := String(f)
		if not stem.ends_with(".png") or not stem.begins_with(prefix):
			continue
		stem = stem.trim_suffix(".png")
		var shadowed := false
		for sc in subchars:
			if stem == sc or stem.begins_with(String(sc) + "_"):
				shadowed = true
				break
		if shadowed:
			continue
		var act := stem.substr(prefix.length())
		var toks := act.split("_")
		if toks.size() > 1 and toks[toks.size() - 1] in Art.DIR8:
			toks.remove_at(toks.size() - 1)
			act = "_".join(toks)
		if act in ["", "anim", "walk", "portrait", "splash"]:
			continue
		found[act] = true
	var out: Array = found.keys()
	out.sort()
	# The basic swing family leads, in cast order; the rest stay alphabetical.
	var head: Array = []
	for pref in ["attack", "attack2", "melee", "ability", "cast"]:
		if out.has(pref):
			out.erase(pref)
			head.append(pref)
	out = head + out
	_actions_cache[key] = out
	return out
