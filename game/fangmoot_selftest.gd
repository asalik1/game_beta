extends SceneTree
## Phase-1 correctness gate for Fangmoot (PROPOSALS/FANGMOOT.md §14).
## Run: tools\Godot..._console.exe --headless --path game --script res://fangmoot_selftest.gd
## Exits 0 all-green, 1 on any failure. Mirrored into autotest _test_fangmoot().

var fails: Array = []

func _initialize() -> void:
	_determinism()
	_no_stall()
	_fixtures()
	_bot_completes()
	_codes()
	_data_lint()
	_seam_lint()
	print("")
	if fails.is_empty():
		print("=== FANGMOOT SELFTEST: ALL GREEN ===")
		quit(0)
	else:
		print("=== FANGMOOT SELFTEST: %d FAILURE(S) ===" % fails.size())
		for f in fails:
			print("  FAIL: %s" % f)
		quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

# ------------------------------------------------------------ helpers
func _spec(kind: String, level := 1, charm := "") -> Dictionary:
	var r := FangmootData.row(kind)
	var st := FangmootData.base_stats(kind)
	var bonus := level - 1  # rough bond stats for stress bands
	return {
		"kind": kind, "name": String(r.get("name", kind)), "tribe": String(r.get("tribe", "")),
		"tier": FangmootData.tier_of(kind),
		"bite": st.x + bonus, "hide": st.y + bonus, "level": level,
		"ability": r.get("ability", {}), "charm": charm, "home_ground": String(r.get("home", "")),
	}

func _bare(bite: int, hide: int, tribe := "wild", charm := "") -> Dictionary:
	return {"kind": "wolf", "name": "dummy", "tribe": tribe, "tier": 1,
		"bite": bite, "hide": hide, "level": 1, "ability": {}, "charm": charm, "home_ground": ""}

func _ab(bite: int, hide: int, ability: Dictionary) -> Dictionary:
	return {"kind": "wolf", "name": "dummy", "tribe": "wild", "tier": 1,
		"bite": bite, "hide": hide, "level": 1, "ability": ability, "charm": "", "home_ground": ""}

func _rand_band(rng: RandomNumberGenerator) -> Array:
	var ids: Array = FangmootData.TOKENS.keys() + FangmootData.NAMED.keys()
	var n := 1 + rng.randi() % 5
	var band: Array = []
	for i in n:
		var kind := String(ids[rng.randi() % ids.size()])
		var charm := ""
		if rng.randf() < 0.25:
			charm = String(FangmootData.CHARM_ORDER[rng.randi() % FangmootData.CHARM_ORDER.size()])
		band.append(_spec(kind, 1 + rng.randi() % 3, charm))
	return band

func _log_has(log: Array, t: String, extra := {}) -> bool:
	for e in log:
		if String(e.get("t", "")) != t:
			continue
		var match_all := true
		for k in extra:
			if e.get(k) != extra[k]:
				match_all = false
				break
		if match_all:
			return true
	return false

func _first_strike_of(log: Array, uid: int) -> int:
	for e in log:
		if String(e.get("t", "")) == "strike" and int(e.get("atk", -1)) == uid:
			return int(e.get("dmg", -1))
	return -999


# ------------------------------------------------------------ 1. determinism
func _determinism() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var bad := 0
	for i in 200:
		var a := _rand_band(rng)
		var b := _rand_band(rng)
		var seed := rng.randi()
		var r1 := FangmootSim.fight(a, b, seed)
		var r2 := FangmootSim.fight(a, b, seed)
		if String(r1["result"]) != String(r2["result"]) or int(r1["strikes"]) != int(r2["strikes"]):
			bad += 1
		elif JSON.stringify(r1["log"]) != JSON.stringify(r2["log"]):
			bad += 1
	_ok(bad == 0, "determinism: %d/200 triples differed on replay" % bad)
	print("[1] determinism: %d/200 mismatches" % bad)


# ------------------------------------------------------------ 2. no stall
func _no_stall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var capped := 0
	var maxs := 0
	for i in 2000:
		var a := _rand_band(rng)
		var b := _rand_band(rng)
		var r := FangmootSim.fight(a, b, rng.randi())
		var s := int(r["strikes"])
		maxs = maxi(maxs, s)
		if s >= FangmootSim.STRIKE_CAP:
			capped += 1
	# The cap guarantees termination (no hang); it firing on a random pathological
	# band is the anti-stall working. Real-band draw rate is measured by the bench
	# (target <0.5%); random bands are harsher, so allow up to 2% here.
	_ok(maxs <= FangmootSim.STRIKE_CAP, "no-stall: a fight exceeded the strike cap (%d)" % maxs)
	_ok(capped * 50 < 2000, "no-stall: %d/2000 random-band fights capped (>2%%)" % capped)
	print("[2] no-stall: max strikes=%d, capped=%d/2000 (%.2f%%)" % [maxs, capped, 100.0 * capped / 2000.0])


# ------------------------------------------------------------ 3. fixtures
func _fixtures() -> void:
	# Frost thaws after one strike: B.spider Webs A's front at muster; A's first
	# strike deals 0 (thaw), then normal.
	var a1 := [_bare(5, 20)]
	var b1 := [_spec("spider")]  # Web: frost enemy front
	var r1 := FangmootSim.fight(a1, b1, 1)
	_ok(_log_has(r1["log"], "status_use", {"st": "frost"}), "fixture frost: no thaw event logged")
	_ok(_first_strike_of(r1["log"], 1) == 0, "fixture frost: A's first strike should deal 0 (frozen)")

	# Ward absorbs ability damage: A.blightwolf Pounces (deal 2) B.sun_bleached
	# (Bleached wards self); B front takes 0.
	var a2 := [_spec("blightwolf")]
	var b2 := [_spec("sun_bleached")]
	var r2 := FangmootSim.fight(a2, b2, 1)
	_ok(_log_has(r2["log"], "status_use", {"st": "ward"}), "fixture ward: ward not consumed by ability dmg")

	# Thorns ignores ability damage. B (bite 5) musters first and sets thorns 10;
	# A (bite 0) then nukes B for 100 ability damage at muster, killing it. No
	# strike ever happens, so the only way A could take damage is if thorns
	# wrongly retaliated on the ability damage -> A would die too and it'd be a
	# draw. Correct behaviour: A is unscathed and wins.
	var a3 := [_ab(0, 5, {"id": "nuke", "name": "Nuke", "trig": "muster",
		"ops": [{"fx": "dmg", "tgt": "enemy_front", "val": 100}]})]
	var b3 := [_ab(5, 8, {"id": "spikes", "name": "Spikes", "trig": "muster",
		"ops": [{"fx": "status", "st": "thorns", "tgt": "self", "amt": 10}]})]
	var r3 := FangmootSim.fight(a3, b3, 1)
	_ok(String(r3["result"]) == "a", "fixture thorns: ability damage must not trigger thorns")

	# Amber first-strike stops the return blow.
	var a4 := [_bare(10, 5, "wild", "amber")]
	var b4 := [_bare(10, 3)]
	var r4 := FangmootSim.fight(a4, b4, 1)
	_ok(String(r4["result"]) == "a", "fixture amber: amber holder should win unscathed")
	_ok(not _log_has(r4["log"], "dmg", {"uid": 1}), "fixture amber: holder took a return blow")

	# Preserved once: tenacity survives lethal once, dies the second time.
	var a5 := [_bare(0, 5, "wild", "tenacity")]
	var b5 := [_bare(10, 30)]
	var r5 := FangmootSim.fight(a5, b5, 1)
	_ok(_log_has(r5["log"], "status_use", {"st": "preserved"}), "fixture preserved: no preserve event")
	_ok(String(r5["result"]) == "b", "fixture preserved: should still die eventually")
	# exactly one preserve, then one fall
	var preserves := 0
	for e in r5["log"]:
		if String(e.get("t", "")) == "status_use" and String(e.get("st", "")) == "preserved":
			preserves += 1
	_ok(preserves == 1, "fixture preserved: expected exactly 1 preserve, got %d" % preserves)
	print("[3] fixtures: %d checks run" % 8)


# ------------------------------------------------------------ 4. bot completes
func _bot_completes() -> void:
	var host := FangmootHost.new()
	var personas: Array = FangmootData.CALLERS.values()
	for table in ["copper", "silver", "gold"]:
		var m := FangmootMoot.new(table, 777, host)
		var brng := RandomNumberGenerator.new()
		brng.seed = 555
		var guard := 40
		while not m.done and guard > 0:
			guard -= 1
			m.begin_turn()
			FangmootBot.take_turn(m, personas[0], brng)
			var opp := FangmootBot.build_warband(personas[1], m.turn, 42 + m.turn, host)
			m.call_moot(opp)
		_ok(m.done, "bot: %s moot did not finish" % table)
		_ok(m.turn <= int(Balance.FANGMOOT_MAX_TURNS) + 1, "bot: %s moot ran past max turns (%d)" % [table, m.turn])
		print("[4] bot %s: turn=%d crests=%d scars=%d outcome=%s" % [table, m.turn, m.crests, m.scars, m.outcome])


# ------------------------------------------------------------ 5. codes
func _codes() -> void:
	var band := [
		{"kind": "wolf", "copies": 3, "charm": "ruby"},
		{"kind": "fangmaw", "copies": 1, "charm": ""},
		{"kind": "vale_mourner", "copies": 6, "charm": "amber"},
	]
	var code := FangmootCodes.encode(band, 8, 123456)
	var dec := FangmootCodes.decode(code)
	_ok(not dec.is_empty(), "codes: decode failed")
	_ok(int(dec.get("turn", -1)) == 8 and int(dec.get("seed", -1)) == 123456, "codes: turn/seed lost")
	var db: Array = dec.get("band", [])
	_ok(db.size() == 3, "codes: band size lost (%d)" % db.size())
	if db.size() == 3:
		_ok(String(db[0]["kind"]) == "wolf" and int(db[0]["copies"]) == 3 and String(db[0]["charm"]) == "ruby",
			"codes: slot 0 round-trip wrong")
		_ok(String(db[1]["kind"]) == "fangmaw", "codes: Named round-trip wrong")
	_ok(FangmootCodes.decode("FM1-@@@garbage").is_empty(), "codes: tampered code not rejected")
	_ok(FangmootCodes.decode("nope").is_empty(), "codes: non-FM code not rejected")
	_ok(code.length() < 120, "codes: code too long (%d chars)" % code.length())
	print("[5] codes: len=%d" % code.length())


# ------------------------------------------------------------ 6. data lint
func _data_lint() -> void:
	if Story.ALL_ENEMIES.is_empty():
		Story.load_content()
	var all: Dictionary = Story.ALL_ENEMIES
	var bad_ids: Array = []
	for kind in FangmootData.TOKENS:
		if not all.has(kind):
			bad_ids.append(kind)
	for kind in FangmootData.NAMED:
		if not all.has(kind):
			bad_ids.append("named:" + kind)
		if not (kind in Menus.BOSS_KINDS):
			bad_ids.append("not-boss:" + kind)
	_ok(bad_ids.is_empty(), "data lint: ids missing from ALL_ENEMIES / BOSS_KINDS: %s" % str(bad_ids))

	# summon units must resolve to real art keys
	var bad_summon: Array = []
	for kind in FangmootData.SUMMONS:
		if not all.has(kind) and Art.tex(kind) == null:
			bad_summon.append(kind)
	_ok(bad_summon.is_empty(), "data lint: summon units unresolved: %s" % str(bad_summon))

	# homes must be real terrain ids
	var terrains: Array = Terrains.catalog_ids(false)
	var bad_home: Array = []
	for kind in FangmootData.TOKENS:
		var h := String(FangmootData.TOKENS[kind].get("home", ""))
		if h != "" and not (h in terrains):
			bad_home.append("%s:%s" % [kind, h])
	_ok(bad_home.is_empty(), "data lint: bad home terrains: %s" % str(bad_home))

	# every REAL in-play terrain has a GROUNDS row (ph_* placeholders are Act-2
	# grounds-in-waiting, §17 — moots only call on the 14 real terrains)
	var missing_ground: Array = []
	for tid in terrains:
		if String(tid).begins_with("ph_"):
			continue
		if not FangmootData.GROUNDS.has(tid):
			missing_ground.append(tid)
	_ok(missing_ground.is_empty(), "data lint: real terrains without a GROUNDS row: %s" % str(missing_ground))
	print("[6] data lint: %d tokens, %d named, %d terrains, bad_ids=%d" % [
		FangmootData.TOKENS.size(), FangmootData.NAMED.size(), terrains.size(), bad_ids.size()])


# ------------------------------------------------------------ 7. seam lint
func _seam_lint() -> void:
	var files := ["fangmoot_data", "fangmoot_sim", "fangmoot_moot", "fangmoot_bot",
		"fangmoot_codes", "fangmoot_host"]
	var forbidden := ["GameBase", "game_base", "add_renown", "SaveGame", "kill_counts", "boss_done"]
	var offenders: Array = []
	for f in files:
		var fa := FileAccess.open("res://scripts/fangmoot/%s.gd" % f, FileAccess.READ)
		if fa == null:
			offenders.append("%s (unreadable)" % f)
			continue
		var text := fa.get_as_text()
		fa.close()
		for tok in forbidden:
			if text.contains(tok):
				offenders.append("%s references %s" % [f, tok])
	_ok(offenders.is_empty(), "seam lint: %s" % str(offenders))
	print("[7] seam lint: %d offenders" % offenders.size())
