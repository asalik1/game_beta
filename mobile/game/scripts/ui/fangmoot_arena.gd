class_name UIFangmootArena
extends Node2D
## The moot arena (PROPOSALS/FANGMOOT.md §13/§17): both warbands stand on tinted
## pedestals on the REAL terrain floor of the ground the moot is called on (it
## swaps — grass, snow, gravedirt, basalt…), tribe emblems above, Bite/Hide chips
## below. On "Call the moot" the tokens are our real animated sprites: they lunge
## and play their attack clips on a strike, their death clips on a fall, throw FX
## and an ability banner on a trigger, and float damage numbers — the game, not a
## spreadsheet. Hosted in a SubViewport by ui/fangmoot.gd; setup() → set_bands()
## → play(); `finished` fires when a replay ends.

signal finished

const GOLD := Color(1.0, 0.85, 0.4)
const LOSS := Color(1.0, 0.45, 0.42)
const HEAL := Color(0.55, 1.0, 0.6)
const BITE_COL := Color(1.0, 0.62, 0.42)
const HIDE_COL := Color(0.62, 0.88, 1.0)
const ALLY := Color(0.42, 0.85, 0.5)     # your pedestals
const FOE := Color(0.9, 0.42, 0.42)      # the caller's pedestals
const TRIBE := {
	"wild": Color(0.86, 0.66, 0.36), "hollow": Color(0.72, 0.76, 0.82),
	"choir": Color(0.62, 0.85, 0.44), "molten": Color(0.98, 0.52, 0.30),
	"still": Color(0.55, 0.85, 0.98), "root": Color(0.5, 0.82, 0.52),
	"storm": Color(0.74, 0.58, 0.98),
}
# a light strike/status -> FX strip in assets/sprites/fx/
const HIT_FX := "fx_slash"

var _host: FangmootHost
var _ground := ""
var _size := Vector2(1280, 470)
var _toks: Array = []
var _by_uid := {}
var _banner: Label
var _speed := 1.0
var _playing := false
var _token_mat: ShaderMaterial   # shared rim-light/separation material for tokens
var _shake_t := 0.0              # screen-shake remaining (secs)
var _shake_amp := 0.0           # current shake magnitude (px)


func setup(host: FangmootHost, ground: String, size: Vector2) -> void:
	_host = host
	_ground = ground
	_size = size
	process_mode = Node.PROCESS_MODE_ALWAYS
	# shared rim-light/separation material so every token lifts off the dark board
	_token_mat = ShaderMaterial.new()
	_token_mat.shader = load("res://shaders/fangmoot_token.gdshader")
	_build_floor()
	# the ground's own light tint — the floor art is authored for it and the
	# sprites read the same way they do in that room in the world.
	var tint = Terrains.get_terrain(_ground).get("tint", Color.WHITE)
	if tint is Color:
		var cm := CanvasModulate.new()
		cm.color = (tint as Color).lightened(0.10)   # cool-ish ambient; the key pool adds the warmth
		add_child(cm)
	# a warm central key-light pool so the fight sits in a pool of light against
	# the cool, knocked-back board (warm-key-on-cool-shadow — the cinematic read).
	_add_key_pool()
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 20)
	_banner.add_theme_color_override("font_color", GOLD)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.size = Vector2(560, 34)
	_banner.position = Vector2(_size.x * 0.5 - 280, 26)
	_banner.modulate = Color(1, 1, 1, 0)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	bsb.set_corner_radius_all(8)
	bsb.set_border_width_all(1)
	bsb.border_color = Color(GOLD, 0.6)
	bsb.content_margin_top = 4
	bsb.content_margin_bottom = 4
	_banner.add_theme_stylebox_override("normal", bsb)
	add_child(_banner)


func _build_floor() -> void:
	var gk := String(Terrains.get_terrain(_ground).get("ground", "grass"))
	var tex: Texture2D = Art.ground_field(gk)
	if tex != null:
		var floor := Polygon2D.new()
		floor.texture = tex
		floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# oversized by a margin so a screen-shake offset never reveals an edge gap
		var m := 30.0
		floor.polygon = PackedVector2Array([Vector2(-m, -m), Vector2(_size.x + m, -m), Vector2(_size.x + m, _size.y + m), Vector2(-m, _size.y + m)])
		floor.uv = floor.polygon
		# knock the floor back so the fighters are the brightest thing on the
		# board — a bright, busy backdrop swallows dark sprites (research #7).
		floor.self_modulate = Color(0.66, 0.66, 0.72)
		floor.z_index = -20
		add_child(floor)
	# a soft vignette so the tokens and chips stay readable over any floor
	var vig := _Vignette.new()
	vig.arena_size = _size
	vig.z_index = -18
	add_child(vig)
	# ambient drifting motes over the floor — warm embers by default, cooled to
	# match a cold ground so the air reads alive without fighting the terrain.
	var em := _Embers.new()
	em.arena_size = _size
	if gk in ["snow", "crystalfloor", "voidstone"]:
		em.tint = Color(0.66, 0.80, 1.0)
	elif gk in ["basalt", "sporesoil"]:
		em.tint = Color(1.0, 0.6, 0.3)
	em.z_index = -16
	add_child(em)


# A big soft warm radial gradient over the fight line, added over the cool board
# so the combatants sit in a pool of key light (warm-key-on-cool-shadow).
func _add_key_pool() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.86, 0.62, 0.36))
	grad.set_color(1, Color(1.0, 0.86, 0.62, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var pool := Sprite2D.new()
	pool.texture = tex
	pool.position = Vector2(_size.x * 0.5, _size.y * 0.46)
	pool.scale = Vector2(_size.x / 256.0 * 0.95, _size.y / 256.0 * 1.05)
	pool.modulate = Color(1, 1, 1, 0.6)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pool.material = mat
	pool.z_index = -14   # above floor/embers, below the fighters
	add_child(pool)


# ------------------------------------------------------------- warbands
func set_bands(board: Array, opp: Array) -> void:
	for rec in _toks:
		if is_instance_valid(rec["node"]):
			rec["node"].queue_free()
	_toks.clear()
	_by_uid.clear()
	var uid := 0
	uid = _lay_side(board, 0, uid)
	uid = _lay_side(opp, 1, uid)
	queue_redraw()

func _lay_side(band: Array, side: int, uid: int) -> int:
	var idx := 0
	for spec in band:
		if spec == null:
			continue
		uid += 1
		_make_token(spec, side, idx, uid)
		idx += 1
	return uid

# Slot 0 is the front-liner (the sim's `_front`), so anchor it at the centre
# clash line and let the bench trail outward to each side's edge. Partial bands
# then meet in the middle instead of clustering at the walls; a full 5-a-side
# still fits the width.
const SLOT_GAP := 90.0    # front-liner's distance from centre
const SLOT_STEP := 115.0  # spacing back down the bench

func _slot_pos(side: int, idx: int) -> Vector2:
	var y := _size.y * 0.46
	var c := _size.x * 0.5
	if side == 0:
		return Vector2(c - SLOT_GAP - idx * SLOT_STEP, y)
	return Vector2(c + SLOT_GAP + idx * SLOT_STEP, y)

func _make_token(spec: Dictionary, side: int, idx: int, uid: int) -> void:
	var kind := String(spec.get("kind", ""))
	var tribe := String(spec.get("tribe", ""))
	var home := _slot_pos(side, idx)
	var node := Node2D.new()
	node.position = home
	add_child(node)

	var spr := Sprite2D.new()
	# the sprites' default facing is left, so flip YOUR band (left side) to face
	# right, and leave the caller's band (right side) facing left — they meet.
	spr.flip_h = (side == 0)
	spr.material = _token_mat   # warm top rim + cool separation halo (lifts the dark sprite)
	node.add_child(spr)

	var rec := {
		"uid": uid, "kind": kind, "tribe": tribe, "side": side, "node": node, "spr": spr,
		"home": home, "dead": false, "mode": "idle", "frame_t": 0.0, "frames": 1, "fps": 6.0,
		"idle": _host.clip(kind, "idle"), "attack": _host.clip(kind, "attack"),
		"death": _host.clip(kind, "death"), "bob": randf() * TAU,
		"hide": int(spec.get("hide", 1)), "max_hide": maxi(1, int(spec.get("hide", 1))),
		"bite": int(spec.get("bite", 0)),
	}
	# a round tribe emblem above the head
	var emblem := Panel.new()
	emblem.size = Vector2(15, 15)
	emblem.position = Vector2(-7, -104)
	var esb := StyleBoxFlat.new()
	esb.bg_color = TRIBE.get(tribe, GOLD)
	esb.set_corner_radius_all(8)
	esb.set_border_width_all(1)
	esb.border_color = Color(0, 0, 0, 0.55)
	emblem.add_theme_stylebox_override("panel", esb)
	node.add_child(emblem)
	# Bite / Hide chips below the pedestal
	var bite_chip := _pill(str(rec["bite"]), BITE_COL, Vector2(-40, 46), 15)
	node.add_child(bite_chip)
	var hide_chip := _pill(str(rec["hide"]), HIDE_COL, Vector2(8, 46), 15)
	node.add_child(hide_chip)
	rec["bite_chip"] = bite_chip
	rec["hide_chip"] = hide_chip
	rec["emblem"] = emblem
	_toks.append(rec)
	_by_uid[uid] = rec
	_set_strip(rec, rec["idle"], "idle")


func _pill(text: String, col: Color, pos: Vector2, fsize: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(32, 0)
	l.position = pos
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.94)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(1)
	sb.border_color = Color(col, 0.55)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", sb)
	return l

func _dot_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _set_strip(rec: Dictionary, info: Dictionary, mode: String) -> void:
	var spr: Sprite2D = rec["spr"]
	if info == null or info.is_empty():
		spr.texture = _host.portrait(String(rec["kind"]))
		spr.hframes = 1
		spr.frame = 0
		rec["frames"] = 1
		rec["fps"] = 1.0
	else:
		spr.texture = info["tex"]
		spr.hframes = int(info["frames"])
		spr.frame = 0
		rec["frames"] = int(info["frames"])
		rec["fps"] = float(info["fps"])
	rec["mode"] = mode
	rec["frame_t"] = 0.0
	if spr.texture != null:
		var h := float(spr.texture.get_height())
		var s := 140.0 / maxf(1.0, h)
		spr.scale = Vector2(s, s)
		rec["base_scale"] = s
		spr.offset = Vector2.ZERO
		# feet stand on the pedestal (node y = 32); the idle bob offsets this base.
		rec["base_y"] = 32.0 - (h * s) * 0.5
		spr.position = Vector2(0, float(rec["base_y"]))


const SHAKE_DUR := 0.22

func _process(delta: float) -> void:
	# screen shake: a decaying random offset on the whole board (the floor is
	# oversized so this never reveals an edge gap).
	if _shake_t > 0.0:
		_shake_t -= delta
		if _shake_t <= 0.0:
			_shake_amp = 0.0
			position = Vector2.ZERO
		else:
			var k := clampf(_shake_t / SHAKE_DUR, 0.0, 1.0)
			position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amp * k
	for rec in _toks:
		var spr: Sprite2D = rec["spr"]
		if not is_instance_valid(spr):
			continue
		rec["frame_t"] = float(rec["frame_t"]) + delta * float(rec["fps"])
		if rec["frame_t"] >= 1.0:
			var steps := int(rec["frame_t"])
			rec["frame_t"] = float(rec["frame_t"]) - steps
			var frames := int(rec["frames"])
			match String(rec["mode"]):
				"death":
					spr.frame = mini(spr.frame + steps, frames - 1)
				"attack":
					if spr.frame + steps >= frames:
						_set_strip(rec, rec["idle"], "idle")
					else:
						spr.frame += steps
				_:
					spr.frame = (spr.frame + steps) % maxi(1, frames)
		if String(rec["mode"]) == "idle" and not bool(rec["dead"]):
			# breathe: a slow phase-offset bob + a faint scale pulse so a resting
			# fighter is never a dead still frame (the #1 "beta" tell).
			rec["bob"] = float(rec["bob"]) + delta * 2.2
			var b := float(rec["bob"])
			spr.position = Vector2(0, float(rec.get("base_y", 0.0)) + sin(b) * 2.0)
			var bs := float(rec.get("base_scale", spr.scale.x))
			spr.scale = Vector2(bs * (1.0 + sin(b * 0.5) * 0.02), bs * (1.0 - sin(b * 0.5) * 0.02))


func _draw() -> void:
	# a glowing arena ring so the fighters stand in a defined pit, not on a field
	var c := Vector2(_size.x * 0.5, _size.y * 0.47)
	var rx := _size.x * 0.47
	var ry := _size.y * 0.35
	_oval(c, rx, ry, Color(GOLD, 0.06), false, 9.0)          # soft outer glow
	_oval(c, rx, ry, Color(GOLD, 0.30), false, 3.0)          # crisp gold rim
	_oval(c, rx * 0.9, ry * 0.84, Color(GOLD, 0.10), false, 2.0)   # inner ring
	draw_line(Vector2(c.x, c.y - ry * 0.6), Vector2(c.x, c.y + ry * 0.6), Color(GOLD, 0.13), 2.0)
	# per fighter: a soft ground shadow, then a glowing team-tinted pedestal
	for rec in _toks:
		if bool(rec["dead"]):
			continue
		var home: Vector2 = rec["home"]
		var p: Vector2 = home + Vector2(0, 38)
		var tint: Color = ALLY if rec["side"] == 0 else FOE
		# a soft warm backlight lifts the dark silhouette off the busy floor
		_oval(home + Vector2(0, -22), 44, 62, Color(1.0, 0.95, 0.86, 0.05), true, 0.0)
		_oval(p + Vector2(2, 5), 56, 18, Color(0, 0, 0, 0.34), true, 0.0)   # drop shadow
		_oval(p, 54, 17, Color(tint, 0.09), false, 7.0)                     # pedestal glow
		_oval(p, 52, 16, Color(tint, 0.22), true, 0.0)                      # pedestal fill
		_oval(p, 52, 16, Color(tint, 0.62), false, 2.5)                     # pedestal rim

func _oval(center: Vector2, rx: float, ry: float, col: Color, filled: bool, width: float) -> void:
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, width, true)


# --------------------------------------------------------------- replay
func play(log: Array, speed := 1.0) -> void:
	if _playing:
		return
	_playing = true
	_speed = maxf(0.5, speed)
	await _run(log)
	finished.emit()

func _run(log: Array) -> void:
	# The sim finishes a token AFTER the pre-fight spec (home-ground +1/+1, charm
	# offsets), so seed the chips from its own numbers before the board settles.
	for e in log:
		if String(e.get("t", "")) != "build":
			break
		_set_stats(int(e.get("uid", 0)), int(e.get("bite", -1)), int(e.get("hide", -1)))
	await _wait(0.55)
	for e in log:
		if not is_instance_valid(self):
			return
		match String(e.get("t", "")):
			"strike":
				await _strike(int(e.get("atk", 0)), int(e.get("dfn", 0)), int(e.get("dmg", 0)))
			"dmg":
				_set_hide(int(e.get("uid", 0)), int(e.get("hide", 0)))
			"heal":
				_heal(int(e.get("uid", 0)), int(e.get("amt", 0)), int(e.get("hide", 0)))
				await _wait(0.12)
			"ability":
				_ability(int(e.get("uid", 0)), String(e.get("name", "")))
				await _wait(0.28)
			"fall":
				_fall(int(e.get("uid", 0)))
				await _wait(0.3)
			"summon":
				_summon(e)
				await _wait(0.2)
			"status_use":
				# burn/rot/preserve move hide with no dmg event of their own; the
				# statuses that don't (ward, frost) carry no hide to read.
				if e.has("hide"):
					_set_hide(int(e["uid"]), int(e["hide"]))
			"stat_change":
				_set_stats(int(e.get("uid", 0)), int(e.get("bite", -1)), int(e.get("hide", -1)))
	await _wait(0.4)


func _strike(atk_uid: int, dfn_uid: int, dmg: int) -> void:
	var atk = _by_uid.get(atk_uid, null)
	var dfn = _by_uid.get(dfn_uid, null)
	if atk == null or not is_instance_valid(atk["node"]):
		await _wait(0.12)
		return
	_play_clip(atk, "attack")
	var an: Node2D = atk["node"]
	var target: Vector2 = dfn["home"] if dfn != null else atk["home"]
	var lunge: Vector2 = (atk["home"] as Vector2).lerp(target, 0.4)
	var tw := create_tween()
	# anticipation: a small pull-back, then a fast lunge into the target (the
	# windup that makes a strike land instead of teleport).
	var wind: Vector2 = (atk["home"] as Vector2).lerp(target, -0.08)
	tw.tween_property(an, "position", wind, 0.09 / _speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(an, "position", lunge, 0.10 / _speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _land(dfn, dmg))
	tw.tween_interval(0.05 / _speed)   # hitstop: the pair hangs at contact for a beat
	tw.tween_property(an, "position", atk["home"], 0.18 / _speed).set_trans(Tween.TRANS_QUAD)
	await tw.finished

func _land(dfn, dmg: int) -> void:
	if dfn == null or not is_instance_valid(dfn["node"]):
		return
	var dn: Node2D = dfn["node"]
	if dmg > 0:
		var big := dmg >= 5
		_float(dfn["home"] + Vector2(0, -60), "-%d" % dmg, Color(1.0, 0.78, 0.36) if big else LOSS, big)
		_fx(HIT_FX, dfn["home"] + Vector2(0, -8), 1.15 if big else 1.0)
		# the juice stack: sparks fly off the contact point + the board kicks
		_sparks((dfn["home"] as Vector2) + Vector2(0, -6), Color(1.0, 0.86, 0.55), 8 if big else 5)
		_shake(3.5 if big else 2.0)
		var spr: Sprite2D = dfn["spr"]
		# white hit-flash: the universal "it connected" cue.
		var t := create_tween()
		t.tween_property(spr, "modulate", Color(2.0, 1.9, 1.9), 0.04)
		t.tween_property(spr, "modulate", Color.WHITE, 0.18)
		# squash + a small knockback kick that decays back to the pedestal.
		var bs := float(dfn.get("base_scale", spr.scale.x))
		var sq := create_tween()
		sq.tween_property(spr, "scale", Vector2(bs * 1.18, bs * 0.84), 0.05)
		sq.tween_property(spr, "scale", Vector2(bs, bs), 0.13)
		var dir := 1.0 if dfn["side"] == 1 else -1.0
		var t2 := create_tween()
		t2.tween_property(dn, "position", (dfn["home"] as Vector2) + Vector2(dir * (14 if big else 10), 0), 0.05)
		t2.tween_property(dn, "position", dfn["home"], 0.13)

func _ability(uid: int, name: String) -> void:
	var rec = _by_uid.get(uid, null)
	if name != "" and is_instance_valid(_banner):
		_banner.text = name
		_banner.modulate = Color.WHITE
		var bt := create_tween()
		bt.tween_interval(0.9)
		bt.tween_property(_banner, "modulate", Color(1, 1, 1, 0), 0.4)
	if rec == null or not is_instance_valid(rec["spr"]):
		return
	var spr: Sprite2D = rec["spr"]
	var t := create_tween()
	t.tween_property(spr, "modulate", GOLD * 1.6, 0.09)
	t.tween_property(spr, "modulate", Color.WHITE, 0.22)
	_pulse(rec["home"])

func _fall(uid: int) -> void:
	var rec = _by_uid.get(uid, null)
	if rec == null or not is_instance_valid(rec["node"]):
		return
	rec["dead"] = true
	queue_redraw()  # drop its pedestal
	if is_instance_valid(rec["bite_chip"]):
		rec["bite_chip"].visible = false
	if is_instance_valid(rec["hide_chip"]):
		rec["hide_chip"].visible = false
	if rec.has("emblem") and is_instance_valid(rec["emblem"]):
		rec["emblem"].visible = false
	_play_clip(rec, "death")
	# a poof of dark motes + a heavier board kick — a fall should read as an
	# event, not a silent despawn.
	_burst((rec["home"] as Vector2) + Vector2(0, 6))
	_shake(6.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(rec["node"], "modulate", Color(0.5, 0.35, 0.4, 0.0), 0.5)
	t.tween_property(rec["node"], "scale", Vector2(0.7, 0.7), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _heal(uid: int, amt: int, hide: int) -> void:
	var rec = _by_uid.get(uid, null)
	if rec != null and amt > 0 and is_instance_valid(rec["node"]):
		_float((rec["home"] as Vector2) + Vector2(0, -60), "+%d" % amt, HEAL)
	_set_hide(uid, hide)

func _summon(e: Dictionary) -> void:
	var owner = _by_uid.get(int(e.get("owner", 0)), null)
	if owner == null:
		return
	var side := int(owner["side"])
	var kind := String(e.get("kind", ""))
	var spec := {
		"kind": kind, "tribe": String(owner["tribe"]),
		"bite": int(e.get("bite", 1)), "hide": int(e.get("hide", 1)),
	}
	_make_token(spec, side, _free_slot(side), int(e.get("uid", 0)))
	var last: Dictionary = _toks[_toks.size() - 1]
	last["node"].modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(last["node"], "modulate", Color.WHITE, 0.22)
	_pulse(last["home"])


# The first pedestal on this side no LIVING token stands on. Fallen tokens keep
# their record, so counting records instead walks a summon off the board edge.
func _free_slot(side: int) -> int:
	var taken := {}
	for rec in _toks:
		if int(rec["side"]) == side and not bool(rec["dead"]):
			taken[rec["home"]] = true
	var i := 0
	var slots := int(Balance.FANGMOOT_BOARD)   # the sim caps a side at the warband size
	while i < slots:
		if not taken.has(_slot_pos(side, i)):
			return i
		i += 1
	return slots


func _play_clip(rec: Dictionary, action: String) -> void:
	var info: Dictionary = rec.get(action, {})
	if info != null and not info.is_empty():
		_set_strip(rec, info, action)

func _set_hide(uid: int, hide: int) -> void:
	var rec = _by_uid.get(uid, null)
	if rec == null:
		return
	rec["hide"] = maxi(0, hide)
	if is_instance_valid(rec["hide_chip"]):
		rec["hide_chip"].text = str(rec["hide"])

func _set_bite(uid: int, bite: int) -> void:
	var rec = _by_uid.get(uid, null)
	if rec == null:
		return
	rec["bite"] = maxi(0, bite)
	if is_instance_valid(rec["bite_chip"]):
		rec["bite_chip"].text = str(rec["bite"])

# Write whichever chips the event carried; -1 = "this event didn't say".
func _set_stats(uid: int, bite: int, hide: int) -> void:
	if bite >= 0:
		_set_bite(uid, bite)
	if hide >= 0:
		_set_hide(uid, hide)

func _float(pos: Vector2, text: String, col: Color, big := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 38 if big else 26)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7 if big else 6)
	l.z_index = 8
	# a little sideways drift so stacked hits don't overlap, and it arcs, not rises.
	var drift := (float((int(pos.x) % 7) - 3)) * 6.0
	l.position = pos
	l.pivot_offset = Vector2(10, 14)
	add_child(l)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position", pos + Vector2(drift, -48), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# a scale-punch (bigger on a heavy hit), then settle.
	t.tween_property(l, "scale", Vector2(1.6, 1.6) if big else Vector2(1.28, 1.28), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(l, "scale", Vector2.ONE, 0.12)
	t.chain().tween_property(l, "modulate", Color(col, 0.0), 0.42)
	t.chain().tween_callback(l.queue_free)

func _fx(strip: String, pos: Vector2, scale: float) -> void:
	var info := _strip_info(strip)
	if info.is_empty():
		return
	var s := Sprite2D.new()
	s.texture = info["tex"]
	s.hframes = int(info["frames"])
	s.position = pos
	s.z_index = 5
	s.scale = Vector2(scale, scale)
	add_child(s)
	var fps := float(info["fps"])
	var frames := int(info["frames"])
	var t := s.create_tween()
	for f in frames:
		t.tween_callback(func() -> void: s.frame = f)
		t.tween_interval(1.0 / maxf(1.0, fps))
	t.tween_callback(s.queue_free)

func _strip_info(name: String) -> Dictionary:
	var path := "res://assets/sprites/fx/%s.png" % name
	if not ResourceLoader.exists(path):
		return {}
	var tex: Texture2D = load(path)
	if tex == null:
		return {}
	var h := tex.get_height()
	var frames := maxi(1, int(round(float(tex.get_width()) / float(maxi(1, h)))))
	return {"tex": tex, "frames": frames, "fps": 18.0}

func _pulse(pos: Vector2) -> void:
	var fx := _PulseFX.new()
	fx.position = pos
	fx.z_index = 4
	add_child(fx)

func _burst(pos: Vector2) -> void:
	var fx := _Burst.new()
	fx.position = pos
	fx.z_index = 6
	add_child(fx)

func _shake(amp: float) -> void:
	_shake_amp = maxf(_shake_amp, amp)
	_shake_t = SHAKE_DUR

func _sparks(pos: Vector2, col: Color, n: int) -> void:
	var fx := _Sparks.new()
	fx.position = pos
	fx.z_index = 7
	fx.col = col
	for i in n:
		var a := randf() * TAU
		fx.sparks.append({
			"dir": Vector2(cos(a), sin(a) * 0.7 - 0.25),   # bias upward/outward
			"spd": 70.0 + randf() * 90.0,
			"w": 1.5 + randf() * 1.5,
		})
	add_child(fx)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec / _speed, true, false, true).timeout


class _PulseFX extends Node2D:
	var t := 0.0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(delta: float) -> void:
		t += delta * 2.0
		queue_redraw()
		if t >= 1.0:
			queue_free()
	func _draw() -> void:
		var r := 10.0 + t * 54.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 44, Color(1.0, 0.85, 0.4, (1.0 - t) * 0.7), 3.0, true)


class _Sparks extends Node2D:
	# a short bright burst of streaks flying off a contact point (additive).
	var t := 0.0
	var sparks: Array = []
	var col := Color(1.0, 0.86, 0.55)
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	func _process(delta: float) -> void:
		t += delta * 2.8
		queue_redraw()
		if t >= 1.0:
			queue_free()
	func _draw() -> void:
		for s in sparks:
			var p: Vector2 = (s["dir"] as Vector2) * float(s["spd"]) * t + Vector2(0, t * t * 46.0)
			var a := (1.0 - t)
			draw_line(p * 0.82, p, Color(col, a), float(s["w"]))


class _Burst extends Node2D:
	# a short-lived puff of dark motes thrown outward when a token falls.
	var t := 0.0
	var motes: Array = []
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		for i in 10:
			var a := TAU * i / 10.0 + float(i) * 0.7
			motes.append({"dir": Vector2(cos(a), sin(a) * 0.6), "spd": 40.0 + float((i * 13) % 30)})
	func _process(delta: float) -> void:
		t += delta * 1.7
		queue_redraw()
		if t >= 1.0:
			queue_free()
	func _draw() -> void:
		for mo in motes:
			var p: Vector2 = (mo["dir"] as Vector2) * float(mo["spd"]) * t
			draw_circle(p - Vector2(0, t * 18.0), (1.0 - t) * 5.0 + 1.0, Color(0.16, 0.13, 0.16, (1.0 - t) * 0.75))


class _Embers extends Node2D:
	# slow drifting motes so the atmospheric space above the fight line is never
	# dead air (research: ambient particles read "alive").
	var arena_size := Vector2(1280, 470)
	var tint := Color(1.0, 0.72, 0.4)
	var motes: Array = []
	var t := 0.0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		for i in 26:
			motes.append({
				"x": float((i * 137) % int(arena_size.x)),
				"y": float((i * 91) % int(arena_size.y)),
				"spd": 6.0 + float((i * 7) % 12),
				"amp": 8.0 + float((i * 5) % 16),
				"ph": float(i) * 0.9,
				"r": 1.0 + float(i % 3) * 0.7,
			})
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		for mo in motes:
			var y: float = fmod(float(mo["y"]) - t * float(mo["spd"]), arena_size.y)
			if y < 0.0:
				y += arena_size.y
			var x: float = float(mo["x"]) + sin(t * 0.5 + float(mo["ph"])) * float(mo["amp"])
			var a: float = 0.12 + 0.10 * (0.5 + 0.5 * sin(t * 1.3 + float(mo["ph"])))
			draw_circle(Vector2(x, y), float(mo["r"]), Color(tint.r, tint.g, tint.b, a))


class _Vignette extends Node2D:
	var arena_size := Vector2(1280, 470)
	func _draw() -> void:
		var w := arena_size.x
		var h := arena_size.y
		var dark := Color(0.015, 0.02, 0.035, 0.9)
		var clear := Color(0.015, 0.02, 0.035, 0.0)
		var tb := 130.0
		var lr := 210.0
		_grad([Vector2(0, 0), Vector2(w, 0), Vector2(w, tb), Vector2(0, tb)], [dark, dark, clear, clear])
		_grad([Vector2(0, h - tb), Vector2(w, h - tb), Vector2(w, h), Vector2(0, h)], [clear, clear, dark, dark])
		_grad([Vector2(0, 0), Vector2(lr, 0), Vector2(lr, h), Vector2(0, h)], [dark, clear, clear, dark])
		_grad([Vector2(w - lr, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - lr, h)], [clear, dark, dark, clear])
	func _grad(pts: Array, cols: Array) -> void:
		draw_polygon(PackedVector2Array(pts), PackedColorArray(cols))
