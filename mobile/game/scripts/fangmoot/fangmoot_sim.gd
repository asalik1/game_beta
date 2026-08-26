class_name FangmootSim
extends RefCounted
## Pure, deterministic Fangmoot fight resolver. PROPOSALS/FANGMOOT.md §6.
##
## fight(band_a, band_b, seed, ground) -> {result, log, strikes, perm}
##   result: "a" | "b" | "draw"
##   perm:   [side0_deltas, side1_deltas]  permanent stat gains to write back
##           to a warband (Dictionary slot -> [d_bite, d_hide]); summons excluded.
##
## No engine dependencies. A "band" is an Array (up to 5) of fully-resolved
## token specs; stats, level and the ability row are baked in by the moot layer,
## so the fight is a pure function of its inputs + seed and can be replayed from
## the log and shared as a code.
##
## A token spec (Dictionary):
##   { kind, name, tribe, tier, bite, hide, level,
##     ability:Dictionary,  charm:String,  home_ground:String,  start_ward:int }
##
## An ability row (data, never code):
##   { id, name, trig, ops:[op,...], cond?, uses? }
##     trig : muster|bite|hurt|fall|slay|ally_falls|ally_hurt|ally_ahead_bites|turn_end
##     cond : ""|"self_half"          (guard on the whole ability firing)
##     uses : int|[l1,l2,l3]          (per-fight cap on firings; omitted = infinite)
##   op, fx one of:
##     buff   {stat:bite|hide|both, val:int|[..], perm?, per?:<tribe>, tgt}
##     dmg    {val:int|[..], tgt}
##     status {st:rot|burn|frost|ward|thorns|silence|preserved,
##             amt?:int|[..], cnt?:int|[..], uses?, grants_ward?, grants_ward_lvl?, tgt}
##     heal   {amt:int|[..]|"full", tgt}
##     summon {unit, name?, tribe, num:int, stats:[[b,h]x3], cap?}
##     strike_bonus {cond:target_hurt, val:int|[..]}   # bite trig only
##     preserve_ally {uses:int|[..]}                    # armed at fight start
##   tgt: self | enemy_front | enemy_front_n | ally_ahead | ally_behind |
##     all_enemies | all_allies | ally_tribe:<t> | rand_ally_tribe:<t> |
##     top_bite_enemy | striker | target | target_and_behind | behind_target |
##     behind_target_2 | stepped_enemy | all_enemies_but_target
##     (tgt may also be an array of 3 selectors, one per level)

const STRIKE_CAP := 200
const CASCADE_CAP := 32

# ------------------------------------------------------------------ public
## want_log=false skips building the event log (the bench doesn't render it).
static func fight(band_a: Array, band_b: Array, seed: int, ground := "", want_log := true) -> Dictionary:
	var sim := FangmootSim.new()
	sim.logging = want_log
	return sim._run(band_a, band_b, seed, ground)


# =================================================================== token
class Tok extends RefCounted:
	var uid := 0
	var kind := ""
	var name := ""
	var tribe := ""
	var tier := 0
	var bite := 0
	var hide := 0
	var max_hide := 0
	var level := 1
	var ability: Dictionary = {}
	var charm := ""
	var side := 0
	var slot := -1               # index in the input band (-1 for summons)
	var summon := false
	var perm_bite := 0           # permanent gains to write back to the warband
	var perm_hide := 0
	# statuses (per fight)
	var rot := 0
	var burn := false
	var frost := false
	var ward := 0
	var thorns := 0
	var thorns_uses := -1        # -1 = infinite; some thorns retaliate once
	var silenced := false
	var preserve := 0            # remaining Preserved saves on self
	var preserve_ward := false   # a Preserved save also grants Ward
	var preserve_ally_left := 0  # saves this token can spend on a falling ally
	var dead := false
	# charm-derived
	var onyx := false
	var lapis := false
	var bloodstone := false
	var amber := false
	var vampire := false
	var topaz := false
	var topaz_used := false
	var opal := false
	# per-fight bookkeeping
	var uses_left := -1          # ability firings remaining (-1 = infinite)
	var summons_made := 0
	var last_source: Tok = null  # who last damaged it (for Slay)
	var strike_bonus := 0        # transient, set by a bite-trigger strike_bonus op


# ================================================================ fight state
var rng := RandomNumberGenerator.new()
var sides: Array = [[], []]
var log: Array = []
var logging := true              # bench runs with logging off for speed
var strikes := 0
var uid_seq := 0
var ground := ""
var budget := 0
var pending_hurt: Array = []
var pair_strikes: Array = []
var built: Array = []            # every non-summon Tok, for perm write-back


func _run(band_a: Array, band_b: Array, seed: int, grnd: String) -> Dictionary:
	rng.seed = seed
	ground = grnd
	_build(band_a, 0)
	_build(band_b, 1)
	_muster()
	while _alive(0) and _alive(1) and strikes < STRIKE_CAP:
		budget = CASCADE_CAP
		_exchange()
	var res := "draw"
	if _alive(0) and not _alive(1):
		res = "a"
	elif _alive(1) and not _alive(0):
		res = "b"
	_emit({"t": "end", "result": res, "strikes": strikes})
	return {"result": res, "log": log, "strikes": strikes, "perm": [_perm(0), _perm(1)]}

# Per-slot permanent stat deltas to write back to a warband (summons excluded).
func _perm(side: int) -> Dictionary:
	var out := {}
	for t in built:
		if t.side == side and t.slot >= 0 and (t.perm_bite != 0 or t.perm_hide != 0):
			out[t.slot] = [t.perm_bite, t.perm_hide]
	return out

func _emit(ev: Dictionary) -> void:
	if logging:
		log.append(ev)


# ---------------------------------------------------------------- setup
func _build(band: Array, side: int) -> void:
	var row: Array = []
	for i in band.size():
		var spec = band[i]
		if spec == null:
			continue
		var t := Tok.new()
		uid_seq += 1
		t.uid = uid_seq
		t.side = side
		t.slot = i
		t.kind = String(spec.get("kind", ""))
		t.name = String(spec.get("name", t.kind))
		t.tribe = String(spec.get("tribe", ""))
		t.tier = int(spec.get("tier", 1))
		t.bite = int(spec.get("bite", 1))
		t.hide = int(spec.get("hide", 1))
		t.level = clampi(int(spec.get("level", 1)), 1, 3)
		t.ability = spec.get("ability", {})
		t.charm = String(spec.get("charm", ""))
		if ground != "" and String(spec.get("home_ground", "")) == ground:
			t.bite += 1
			t.hide += 1
		t.max_hide = t.hide
		t.ward += int(spec.get("start_ward", 0))  # one-fight brews
		_apply_charm(t)
		if t.ability.has("uses"):
			t.uses_left = _lv(t.ability["uses"], t.level)
		for op in t.ability.get("ops", []):
			if String(op.get("fx", "")) == "preserve_ally":
				t.preserve_ally_left = _lv(op.get("uses", 1), t.level)
		row.append(t)
		built.append(t)
	sides[side] = row

func _apply_charm(t: Tok) -> void:
	match t.charm:
		"ruby": t.bite += 2
		"garnet": t.hide += 3
		"topaz": t.topaz = true
		"opal": t.opal = true
		"onyx": t.onyx = true
		"lapis": t.lapis = true
		"bloodstone": t.bloodstone = true
		"amber": t.amber = true
		"tenacity": t.preserve += 1
		"vampire": t.vampire = true


# --------------------------------------------------------------- muster
func _muster() -> void:
	_emit({"t": "muster"})
	var casters: Array = []
	for side in [0, 1]:
		for t in sides[side]:
			if _has_trig(t, "muster"):
				casters.append(t)
	for t in _order(casters):
		_fire(t, "muster", {})
	_drain()
	_settle()


# ------------------------------------------------------------- exchange
func _exchange() -> void:
	pair_strikes = []
	var fa: Tok = _front(0)
	var fb: Tok = _front(1)
	if fa == null or fb == null:
		return
	for t in _order([fa, fb]):
		if not t.dead:
			_fire(t, "bite", {"target": _front(1 - t.side)})
	_process_hurts()
	_resolve_falls()
	fa = _front(0)
	fb = _front(1)
	if fa == null or fb == null:
		_settle()
		return
	_strike_pair(fa, fb)
	strikes += 1
	_process_hurts()
	_apply_thorns()
	_process_hurts()
	_resolve_falls()
	_ally_ahead_bites(fa, fb)
	_drain()
	_settle()

func _strike_pair(fa: Tok, fb: Tok) -> void:
	# Amber breaks simultaneity: holder strikes first; a target that Falls
	# (hide <= 0, even before the fall is resolved) does not strike back.
	if fa.amber and not fb.amber:
		_one_strike(fa, fb)
		if not fb.dead and fb.hide > 0:
			_one_strike(fb, fa)
	elif fb.amber and not fa.amber:
		_one_strike(fb, fa)
		if not fa.dead and fa.hide > 0:
			_one_strike(fa, fb)
	else:
		var da := _strike_damage(fa)
		var db := _strike_damage(fb)
		_land_strike(fa, fb, da)
		_land_strike(fb, fa, db)

func _one_strike(atk: Tok, dfn: Tok) -> void:
	_land_strike(atk, dfn, _strike_damage(atk))

# Burn self-tick + Frost thaw resolve here; returns outgoing damage.
func _strike_damage(t: Tok) -> int:
	if t.dead:
		return 0
	if t.burn:
		t.hide -= 2
		_emit({"t": "status_use", "uid": t.uid, "st": "burn"})
		if t.hide <= 0:
			return 0
	if t.frost:
		t.frost = false
		_emit({"t": "status_use", "uid": t.uid, "st": "frost"})
		return 0
	var dmg := t.bite + t.strike_bonus
	t.strike_bonus = 0
	if t.topaz and not t.topaz_used:
		t.topaz_used = true
		dmg *= 2
	return maxi(0, dmg)

func _land_strike(atk: Tok, dfn: Tok, dmg: int) -> void:
	if atk.dead:
		return
	var dealt := _deal(dfn, dmg, atk, true)
	pair_strikes.append({"atk": atk, "dfn": dfn})
	_emit({"t": "strike", "atk": atk.uid, "dfn": dfn.uid, "dmg": dealt})
	if atk.vampire and dealt > 0 and not atk.dead:
		_heal(atk, atk.bite / 2)

func _apply_thorns() -> void:
	for pair in pair_strikes:
		var atk: Tok = pair["atk"]
		var dfn: Tok = pair["dfn"]
		if dfn.thorns > 0 and dfn.thorns_uses != 0 and not atk.dead:
			_deal(atk, dfn.thorns, dfn, false)
			if dfn.thorns_uses > 0:
				dfn.thorns_uses -= 1
			_emit({"t": "status_use", "uid": dfn.uid, "st": "thorns", "amt": dfn.thorns})

func _ally_ahead_bites(fa: Tok, fb: Tok) -> void:
	for t in [fa, fb]:
		if t == null or t.dead:
			continue
		var behind := _ally_behind(t)
		if behind != null:
			if behind.opal:
				behind.bite += 1
			_fire(behind, "ally_ahead_bites", {"ahead": t})
	_process_hurts()
	_resolve_falls()

# Fire Hurt + Rot for everyone who took damage and survived (ordered).
func _process_hurts() -> void:
	if pending_hurt.is_empty():
		return
	var batch := _order(pending_hurt)
	pending_hurt = []
	for t in batch:
		if t.dead or t.hide <= 0:
			continue
		_fire(t, "hurt", {"striker": t.last_source})
		for a in _living(t.side):
			if a != t:
				_fire(a, "ally_hurt", {"hurt": t})
		if t.rot > 0 and not t.dead and t.hide > 0:
			t.hide -= t.rot
			_emit({"t": "status_use", "uid": t.uid, "st": "rot", "amt": t.rot})

# Bounded death cascade: Fall (Preserved check), Slay, AllyFalls.
func _resolve_falls() -> void:
	while budget > 0:
		var fallers: Array = []
		for side in [0, 1]:
			for t in sides[side]:
				if not t.dead and t.hide <= 0:
					if _try_preserve(t):
						continue
					t.dead = true
					fallers.append(t)
		if fallers.is_empty():
			return
		for f in _order(fallers):
			_emit({"t": "fall", "uid": f.uid})
			_fire(f, "fall", {})
			var killer: Tok = f.last_source
			if killer != null and not killer.dead:
				_fire(killer, "slay", {"slain": f, "stepped": _front(f.side)})
			for a in _living(f.side):
				_fire(a, "ally_falls", {"fallen": f})
		budget -= 1
	for side in [0, 1]:
		for t in sides[side]:
			if not t.dead and t.hide <= 0:
				t.dead = true

func _try_preserve(t: Tok) -> bool:
	if t.preserve > 0:
		t.preserve -= 1
		t.hide = 1
		_emit({"t": "status_use", "uid": t.uid, "st": "preserved"})
		if t.preserve_ward:
			t.ward += 1
		return true
	for a in _living(t.side):
		if a == t or a.silenced:
			continue
		if a.preserve_ally_left > 0:
			a.preserve_ally_left -= 1
			t.hide = 1
			_emit({"t": "status_use", "uid": t.uid, "st": "preserved"})
			return true
	return false

# Drain any residual hurt/death after a phase (bounded).
func _drain() -> void:
	var guard := CASCADE_CAP
	while not pending_hurt.is_empty() and guard > 0:
		_process_hurts()
		_resolve_falls()
		guard -= 1


# ---------------------------------------------------------- damage/heal
func _deal(t: Tok, amount: int, source: Tok, is_strike: bool) -> int:
	if t.dead or amount <= 0:
		return 0
	var amt := amount
	if t.ward > 0 and not (is_strike and source != null and source.bloodstone):
		t.ward -= 1
		_emit({"t": "status_use", "uid": t.uid, "st": "ward"})
		return 0
	if is_strike and t.onyx:
		amt = maxi(1, amt - 1)
	t.hide -= amt
	t.last_source = source
	_emit({"t": "dmg", "uid": t.uid, "amt": amt, "hide": maxi(0, t.hide)})
	if not t.dead and t.hide > 0:
		pending_hurt.append(t)
	return amt

func _heal(t: Tok, amount: int) -> void:
	if amount <= 0:
		return
	var before := t.hide
	t.hide = mini(t.max_hide, t.hide + amount)
	if t.hide != before:
		_emit({"t": "heal", "uid": t.uid, "amt": t.hide - before, "hide": t.hide})


# --------------------------------------------------------- ability core
func _fire(t: Tok, trig: String, ctx: Dictionary) -> void:
	if t.dead and trig != "fall":
		return
	if not _has_trig(t, trig):
		return
	if t.silenced:
		return
	if String(t.ability.get("cond", "")) == "self_half" and t.hide * 2 > t.max_hide:
		return
	if t.uses_left == 0:
		return
	if t.uses_left > 0:
		t.uses_left -= 1
	_emit({"t": "ability", "uid": t.uid, "name": String(t.ability.get("name", ""))})
	for op in t.ability.get("ops", []):
		_apply_op(t, op, ctx)

func _has_trig(t: Tok, trig: String) -> bool:
	return not t.ability.is_empty() and String(t.ability.get("trig", "")) == trig

func _apply_op(t: Tok, op: Dictionary, ctx: Dictionary) -> void:
	var fx := String(op.get("fx", ""))
	match fx:
		"strike_bonus":
			if String(op.get("cond", "")) == "target_hurt":
				var tgt: Tok = ctx.get("target", null)
				if tgt != null and tgt.hide < tgt.max_hide:
					t.strike_bonus += _lv(op.get("val", 0), t.level)
			else:
				t.strike_bonus += _lv(op.get("val", 0), t.level)
			return
		"preserve_ally":
			return  # armed at fight start; nothing to do on trigger
		"summon":
			_do_summon(t, op)
			return
	var count := _lv(op.get("cnt", 1), t.level)
	for g in _targets(t, op.get("tgt", "self"), ctx, count):
		match fx:
			"buff": _op_buff(t, g, op)
			"dmg": _deal(g, _lv(op.get("val", 0), t.level), t, false)
			"status": _op_status(g, op, t.level)
			"heal":
				var av = op.get("amt", 0)
				if typeof(av) == TYPE_STRING and String(av) == "full":
					_heal(g, g.max_hide)
				else:
					_heal(g, _lv(av, t.level))

func _op_buff(src: Tok, g: Tok, op: Dictionary) -> void:
	var v := _lv(op.get("val", 0), src.level)
	var per := String(op.get("per", ""))
	if per != "":
		v *= _tribe_count(src, per)
	if v == 0:
		return
	var stat := String(op.get("stat", "bite"))
	var perm: bool = op.get("perm", false)
	if stat == "bite" or stat == "both":
		g.bite = maxi(0, g.bite + v)
		if perm:
			g.perm_bite += v
	if stat == "hide" or stat == "both":
		g.hide += v
		g.max_hide = maxi(1, g.max_hide + v)
		if perm:
			g.perm_hide += v
	_emit({"t": "stat_change", "uid": g.uid, "stat": stat, "val": v, "perm": perm})

func _op_status(g: Tok, op: Dictionary, level: int) -> void:
	var st := String(op.get("st", ""))
	var amt := _lv(op.get("amt", 1), level)
	match st:
		"rot":
			if not g.lapis and amt > 0:
				g.rot += amt
				_stat_status(g, "rot")
		"burn":
			if not g.lapis:
				g.burn = true
				_stat_status(g, "burn")
		"frost":
			if not g.lapis and not g.frost:
				g.frost = true
				_stat_status(g, "frost")
		"ward":
			if amt > 0:
				g.ward += amt
				_stat_status(g, "ward")
		"thorns":
			if amt > 0:
				g.thorns += amt
				if op.has("uses"):
					g.thorns_uses = _lv(op["uses"], level)
				_stat_status(g, "thorns")
		"silence":
			g.silenced = true
			_stat_status(g, "silence")
		"preserved":
			if amt > 0:
				g.preserve += amt
				if op.get("grants_ward", false) and level >= int(op.get("grants_ward_lvl", 1)):
					g.preserve_ward = true
				_stat_status(g, "preserved")

func _stat_status(g: Tok, st: String) -> void:
	_emit({"t": "status_add", "uid": g.uid, "st": st})

func _do_summon(owner: Tok, op: Dictionary) -> void:
	var cap := int(op.get("cap", 99))
	var num := int(op.get("num", 1))
	var stats: Array = op.get("stats", [[1, 1], [1, 1], [1, 1]])
	var pair: Array = stats[clampi(owner.level, 1, 3) - 1]
	for i in num:
		if owner.summons_made >= cap or _living(owner.side).size() >= 5:
			return
		var s := Tok.new()
		uid_seq += 1
		s.uid = uid_seq
		s.side = owner.side
		s.summon = true
		s.kind = String(op.get("unit", ""))
		s.name = String(op.get("name", s.kind))
		s.tribe = String(op.get("tribe", owner.tribe))
		s.bite = int(pair[0])
		s.hide = int(pair[1])
		s.max_hide = s.hide
		var idx: int = sides[owner.side].find(owner)
		if idx < 0:
			idx = sides[owner.side].size() - 1
		sides[owner.side].insert(idx + 1, s)
		owner.summons_made += 1
		_emit({"t": "summon", "owner": owner.uid, "uid": s.uid, "kind": s.kind})


# ------------------------------------------------------------- targeting
func _targets(t: Tok, sel_in, ctx: Dictionary, count: int) -> Array:
	var sel = sel_in
	if typeof(sel) == TYPE_ARRAY:
		sel = sel[clampi(t.level, 1, 3) - 1]
	var s := String(sel)
	var enemy := 1 - t.side
	match s:
		"self":
			return [t]
		"enemy_front":
			var f := _front(enemy)
			return [f] if f != null else []
		"enemy_front_n":
			return _front_n(enemy, count)
		"ally_ahead":
			var a := _ally_ahead(t)
			return [a] if a != null else []
		"ally_behind":
			var b := _ally_behind(t)
			return [b] if b != null else []
		"all_enemies":
			return _living(enemy)
		"all_allies":
			return _living(t.side)
		"top_bite_enemy":
			return _top_bite(enemy, count)
		"striker":
			var k: Tok = ctx.get("striker", null)
			return [k] if k != null and not k.dead else []
		"target":
			var g: Tok = ctx.get("target", null)
			if g == null or g.dead:
				g = _front(enemy)
			return [g] if g != null else []
		"target_and_behind":
			var tg3: Tok = ctx.get("target", null)
			if tg3 == null or tg3.dead:
				tg3 = _front(enemy)
			var res3: Array = []
			if tg3 != null:
				res3.append(tg3)
				var beh := _behind_of(tg3, 1)
				if not beh.is_empty():
					res3.append(beh[0])
			return res3
		"behind_target":
			return _behind_of(ctx.get("target", _front(enemy)), 1)
		"behind_target_2":
			return _behind_of(ctx.get("target", _front(enemy)), 2)
		"stepped_enemy":
			var st: Tok = ctx.get("stepped", null)
			if st == null or st.dead:
				st = _front(enemy)
			return [st] if st != null else []
		"all_enemies_but_target":
			var res: Array = []
			var tg = ctx.get("target", _front(enemy))
			for e in _living(enemy):
				if e != tg:
					res.append(e)
			return res
	if s.begins_with("ally_tribe:"):
		var tribe := s.substr("ally_tribe:".length())
		var res2: Array = []
		for a in _living(t.side):
			if a.tribe == tribe:
				res2.append(a)
		return res2
	if s.begins_with("rand_ally_tribe:"):
		var tribe2 := s.substr("rand_ally_tribe:".length())
		var pool: Array = []
		for a in _living(t.side):
			if a.tribe == tribe2:
				pool.append(a)
		if pool.is_empty():
			return []
		return [pool[rng.randi() % pool.size()]]
	return []

func _behind_of(anchor, n: int) -> Array:
	if anchor == null:
		return []
	var order := _living(anchor.side)
	var i := order.find(anchor)
	if i < 0 or i + n >= order.size():
		return []
	return [order[i + n]]


# ------------------------------------------------------------- helpers
func _lv(v, level: int) -> int:
	if typeof(v) == TYPE_ARRAY:
		return int(v[clampi(level, 1, 3) - 1])
	return int(v)

func _tribe_count(t: Tok, tribe: String) -> int:
	var n := 0
	for a in _living(t.side):
		if a != t and a.tribe == tribe:
			n += 1
	return n

func _living(side: int) -> Array:
	var res: Array = []
	for t in sides[side]:
		if not t.dead:
			res.append(t)
	return res

func _alive(side: int) -> bool:
	for t in sides[side]:
		if not t.dead:
			return true
	return false

func _front(side: int) -> Tok:
	for t in sides[side]:
		if not t.dead:
			return t
	return null

func _front_n(side: int, n: int) -> Array:
	var res: Array = []
	for t in sides[side]:
		if not t.dead:
			res.append(t)
			if res.size() >= n:
				break
	return res

func _ally_ahead(t: Tok) -> Tok:
	var row: Array = sides[t.side]
	var i := row.find(t)
	for j in range(i - 1, -1, -1):
		if not row[j].dead:
			return row[j]
	return null

func _ally_behind(t: Tok) -> Tok:
	var row: Array = sides[t.side]
	var i := row.find(t)
	for j in range(i + 1, row.size()):
		if not row[j].dead:
			return row[j]
	return null

func _top_bite(side: int, n: int) -> Array:
	return _order(_living(side)).slice(0, n)

# Ordering: Bite desc, then Hide desc, then uid asc (stable, deterministic).
func _order(toks: Array) -> Array:
	var arr := toks.duplicate()
	arr.sort_custom(func(x, y):
		if x.bite != y.bite:
			return x.bite > y.bite
		if x.hide != y.hide:
			return x.hide > y.hide
		return x.uid < y.uid)
	return arr

# Compact dead tokens out of each row (the "shift forward" step).
func _settle() -> void:
	for side in [0, 1]:
		var keep: Array = []
		for t in sides[side]:
			if not t.dead:
				keep.append(t)
		sides[side] = keep
