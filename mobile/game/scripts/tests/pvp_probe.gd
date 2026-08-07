extends Node
## PVP PROBE — throwaway balance instrument (NOT a test tier). Builds the
## dev-roster "Perfect L100" god-roll for every class (BenchBuild.perfect100:
## L100, S gear, Lv10 gems, +20 smith, reforge-chased, flagship weapon passive,
## NO armor uniques — byte-identical to the roster the owner benches with), then
## reports, through the REAL pvp damage flow (duel refactor 2026-08-02:
## player_combat._hit_rival -> net_session.pvp_strike -> defender take_damage):
##   - each class's max HP, current_atk, basic-attack (a1) hit (non-crit + crit)
##   - each class's defensive sheet (physres/magres/eva/flat_dr) and effective HP
##   - the full attacker->defender basic-attack one-shot matrix
##
## Run: godot --headless --path game res://scenes/pvp_probe.tscn

const CLS_ORDER := ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]

var game: Game


func _ready() -> void:
	Story.load_content()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	game = main_scene.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(2)
	game.menus.pick_class("warrior")
	await _frames(5)
	await _skip_opening()

	var rows := {}
	for cls in CLS_ORDER:
		rows[cls] = _build_and_read(cls)

	_print_report(rows)
	_verify_live_conversion(rows)
	_pve_pen_check()
	_boss_roster_dump()
	get_tree().quit(0)


## The boss roster in STORY ORDER (by anchor level) with authored BASE res + type
## — the design surface for the "later bosses, higher base" tiering pass.
func _boss_roster_dump() -> void:
	print("")
	print("BOSS ROSTER (story order) — EFFECTIVE base res at anchor (authored -> floored), type")
	var rows: Array = []
	for kind in Menus.BOSS_KINDS:
		var b: Dictionary = Story.ALL_ENEMIES[String(kind)]
		var lvl := int(b.get("level", 1))
		var eff: Dictionary = Story.enemy_stats_at(String(kind), lvl)   # d=0 -> floored base, no growth
		rows.append({
			"kind": String(kind), "lvl": lvl,
			"apr": float(b.get("physres", 0.0)), "amr": float(b.get("magres", 0.0)),
			"pr": float(eff["physres"]), "mr": float(eff["magres"]),
			"dt": String(b.get("dmg_type", "phys"))})
	rows.sort_custom(func(x, y): return int(x["lvl"]) < int(y["lvl"]))
	for r in rows:
		print("  L%-3d %-16s  %-6s  authored %4.0f/%-4.0f  ->  floored %4.0f/%-4.0f" % [
			int(r["lvl"]), r["kind"], r["dt"],
			r["apr"], r["amr"], r["pr"], r["mr"]])
	print("BOSS ROSTER DONE")


## PvE armor/pen sanity: how much resistance bosses actually carry vs the most
## penetration a god-roll player can stack. If boss res >> max pen, pen is a
## normal stat in PvE (unlike the ~0-90-res PvP case).
func _pve_pen_check() -> void:
	print("")
	print("PVE ARMOR vs PEN — boss resistances vs max player penetration")
	print("%-14s %14s %14s" % ["boss", "L40 phys/mag", "L100 phys/mag"])
	var kinds: Array = Menus.BOSS_KINDS
	var s40 := Vector2.ZERO
	var s100 := Vector2.ZERO
	for kind in kinds:
		var a: Dictionary = Story.enemy_stats_at(String(kind), 40)
		var b: Dictionary = Story.enemy_stats_at(String(kind), 100)
		s40 += Vector2(float(a.get("physres", 0.0)), float(a.get("magres", 0.0)))
		s100 += Vector2(float(b.get("physres", 0.0)), float(b.get("magres", 0.0)))
		print("  %-12s %7.0f/%-6.0f %7.0f/%-6.0f" % [kind,
			float(a.get("physres", 0.0)), float(a.get("magres", 0.0)),
			float(b.get("physres", 0.0)), float(b.get("magres", 0.0))])
	var n := float(maxi(1, kinds.size()))
	print("  %-12s %7.0f/%-6.0f %7.0f/%-6.0f" % ["AVERAGE",
		s40.x / n, s40.y / n, s100.x / n, s100.y / n])
	print("")
	print("Max god-roll L100 pen (dps sockets carry gear-sub pen only; all-pen fills every regular slot):")
	for cls in ["warrior", "archer", "mage", "warlock"]:
		var pen_dps := _pen_of(cls, false)
		var pen_max := _pen_of(cls, true)
		var key := "magpen" if Classes.CLASSES[cls]["dmg_type"] == "magic" else "physpen"
		print("  %-9s (%s)  dps-gems %5.0f   all-pen %5.0f" % [cls, key, pen_dps, pen_max])
	print("")
	print("PVE PEN CHECK DONE")


## Build the god-roll for `cls`; if all_pen, re-socket every regular slot to the
## class's pen gem. Return the relevant pen value.
func _pen_of(cls: String, all_pen: bool) -> float:
	var p: Player = game.player
	var tid: String = String(BenchBuild.DEFAULT_THEME[cls])
	p.level = 100
	p.resonance = 0.0
	p.set_class(cls)
	p.set_all_themes(tid)
	p.tree_points = BenchBuild.preset_lookup(BenchBuild.TREE_PRESETS, cls, tid).duplicate()
	p.skill_points = 0
	for attr in p.attr_points:
		p.attr_points[attr] = 0
	p.attr_points[String(Classes.CLASSES[cls]["primary"])] = 99
	p.unspent_attr = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = BenchBuild.GEAR_SEED
	p.equipment = BenchBuild.equip_dict(cls, tid, {"grade": "S", "gemlvl": 10, "plus": 20, "godroll": true}, rng)
	var magic := String(Classes.CLASSES[cls]["dmg_type"]) == "magic"
	if all_pen:
		var penstat := "magpen" if magic else "physpen"
		for slot in p.equipment:
			var item: Dictionary = p.equipment[slot]
			var nn := int(item.get("gem_slots", 0))
			if nn <= 0:
				continue
			var gl := []
			for _i in nn:
				gl.append(Items.make_gem(penstat, 10))
			item["gems"] = gl
	p._update_weapon_visual()
	p.recalc()
	return p.magpen if magic else p.physpen


## Prove the SHIPPED code path (not the model): flip game.pvp_active and rebuild
## through the real recalc — max_hp must ×PVP_TOUGHNESS and melee-res must land on
## physres/magres for the bruisers only.
func _verify_live_conversion(rows: Dictionary) -> void:
	print("")
	print("LIVE-CODE CHECK — real recalc under game.pvp_active (tough %.0f):" % Balance.PVP_TOUGHNESS)
	game.pvp_active = true
	for cls in CLS_ORDER:
		var r: Dictionary = _build_and_read(cls)
		var base_hp: float = float(rows[cls]["max_hp"])
		var grant: float = Balance.PVP_MELEE_RES.get(cls, 0.0)
		print("  %-9s maxHP %6.0f -> %7.0f (x%.1f)   physres %3.0f (+%.0f)   magres %3.0f (+%.0f)" % [
			cls, base_hp, r["max_hp"], r["max_hp"] / base_hp,
			r["physres"], grant, r["magres"], grant])
	game.pvp_active = false


## Build the perfect100 god-roll for `cls` onto game.player, recalc, and read
## the combat-relevant numbers back out.
func _build_and_read(cls: String) -> Dictionary:
	var p: Player = game.player
	var tid: String = String(BenchBuild.DEFAULT_THEME[cls])
	p.level = 100
	p.resonance = 0.0
	p.set_class(cls)
	p.set_all_themes(tid)
	p.tree_points = BenchBuild.preset_lookup(BenchBuild.TREE_PRESETS, cls, tid).duplicate()
	p.skill_points = 0
	for attr in p.attr_points:
		p.attr_points[attr] = 0
	p.attr_points[String(Classes.CLASSES[cls]["primary"])] = 99
	p.unspent_attr = 0
	# perfect100, no armor uniques (matches the dev roster's save_dict path).
	var cfg := {"grade": "S", "gemlvl": 10, "plus": 20, "godroll": true}
	var rng := RandomNumberGenerator.new()
	rng.seed = BenchBuild.GEAR_SEED
	p.equipment = BenchBuild.equip_dict(cls, tid, cfg, rng)
	p._update_weapon_visual()
	p.recalc()
	p.hp = p.max_hp
	p.mp = p.max_mp

	var coeff := p.ability_coeff("a1")
	var base_amt := p.current_atk() * coeff + p.ability_base_flat("a1")
	# _hit_rival (duel refactor) forwards the class's REAL dmg_type (the same
	# read hit_enemy makes); the defender's take_damage buckets non-phys as
	# magres. The old proxy's mage/warlock-only "magic" mapping is gone.
	var out_type := String(Classes.CLASSES[cls]["dmg_type"])
	var eff_crit: float = Stats.crit_curve(p.crit)  # a1 carries no theme crit_bonus exempt
	return {
		"cls": cls,
		"max_hp": p.max_hp,
		"atk": p.atk,
		"catk": p.current_atk(),
		"coeff": coeff,
		"basic": base_amt,
		"basic_crit": base_amt * p.crit_dmg,
		"crit_dmg": p.crit_dmg,
		"eff_crit": eff_crit,
		"out_type": out_type,
		"physres": p.physres,
		"magres": p.magres,
		"eva": p.eva,
		"eva_frac": Stats.eva_curve(p.eva),
		"flat_dr": p.flat_dr,
		"dmg_type_real": String(Classes.CLASSES[cls]["dmg_type"]),
	}


## Defender mitigation multiplier the attacker-less take_damage path applies to a
## connecting hit of `dtype` (res curve + plate flat_dr; no active windows).
func _mitig(defender: Dictionary, dtype: String) -> float:
	# take_damage's bucket rule: phys reads physres, EVERYTHING else magres.
	var res: float = defender["physres"] if dtype == "phys" else defender["magres"]
	var m := 1.0 - Stats.res_frac(res)
	if float(defender["flat_dr"]) > 0.0 and dtype != "true":
		m *= 1.0 - float(defender["flat_dr"])
	return m


func _print_report(rows: Dictionary) -> void:
	print("")
	print("==================================================================")
	print(" PVP PROBE — Perfect L100 god-roll roster (PVP_DMG_MULT = %.2f)" % Balance.PVP_DMG_MULT)
	print("==================================================================")
	print("")
	print("%-9s %7s %7s %7s  %6s  %8s %8s  crit%%  x%-4s" % [
		"class", "maxHP", "ATK", "cATK", "a1coef", "basic", "basicCrit", "dmg"])
	for cls in CLS_ORDER:
		var r: Dictionary = rows[cls]
		print("%-9s %7.0f %7.0f %7.0f  %6.2f  %8.0f %8.0f  %4.0f   %.2f" % [
			cls, r["max_hp"], r["atk"], r["catk"], r["coeff"],
			r["basic"], r["basic_crit"], r["eff_crit"] * 100.0, r["crit_dmg"]])
	print("")
	print("Defensive sheets (god-roll subs are offense-only -> resistances ~0):")
	print("%-9s %8s %8s %7s %8s   realDmgType  fwdDmgType" % [
		"class", "physres", "magres", "eva%", "flatDR"])
	for cls in CLS_ORDER:
		var r: Dictionary = rows[cls]
		print("%-9s %8.0f %8.0f %6.0f %7.1f%%   %-11s  %s" % [
			cls, r["physres"], r["magres"], r["eva_frac"] * 100.0, r["flat_dr"] * 100.0,
			r["dmg_type_real"], r["out_type"]])
	print("")
	print("BASIC-ATTACK ONE-SHOT MATRIX  (attacker a1 -> defender)")
	print("  cell = post-mitigation basic hit as %% of defender max HP")
	print("  [non-crit / crit]   *** = one-shot (>=100%%)   crit hits gated by attacker crit%%")
	print("")
	var header := "%-9s" % "atk\\def"
	for d in CLS_ORDER:
		header += "%14s" % d
	print(header)
	for a in CLS_ORDER:
		var ra: Dictionary = rows[a]
		var line := "%-9s" % a
		for d in CLS_ORDER:
			var rd: Dictionary = rows[d]
			var mit := _mitig(rd, String(ra["out_type"]))
			var hit: float = float(ra["basic"]) * mit * Balance.PVP_DMG_MULT
			var hitc: float = float(ra["basic_crit"]) * mit * Balance.PVP_DMG_MULT
			var pct := hit / float(rd["max_hp"]) * 100.0
			var pctc := hitc / float(rd["max_hp"]) * 100.0
			var tag := "***" if pctc >= 100.0 else ("**" if pct >= 100.0 else "")
			line += "%13s" % ("%.0f/%.0f%s" % [pct, pctc, tag])
		print(line)
	print("")
	print("Hits-to-kill from full HP (non-crit basic, connecting):")
	for a in CLS_ORDER:
		var ra: Dictionary = rows[a]
		var parts := []
		for d in CLS_ORDER:
			if d == a:
				continue
			var rd: Dictionary = rows[d]
			var mit := _mitig(rd, String(ra["out_type"]))
			var hit: float = float(ra["basic"]) * mit * Balance.PVP_DMG_MULT
			var n := int(ceil(float(rd["max_hp"]) / maxf(1.0, hit)))
			parts.append("%s:%d" % [d, n])
		print("  %-9s -> %s" % [a, ", ".join(parts)])
	print("")
	print("PVP PROBE DONE")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _skip_opening() -> void:
	await _frames(3)
	var guard := 0
	while guard < 200:
		if game.hud.choices_active:
			game.hud._choose(0)
		elif game.hud.dialogue_active:
			game.hud._advance_dialogue()
		else:
			break
		await _frames(1)
		guard += 1
	await _frames(5)
