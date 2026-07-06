extends "res://scripts/tests/test_ch2.gd"
## Automated smoke test (not part of the game).
## Covers: class select, dialogue, all class kits, target lock, the stat
## engine (curves, combo), themes, the row-based skill tree, gear + gems
## (socket/synthesize/sell-return), chests, S weapons, telegraphs,
## THE ZONE GRAPH (rooms, doors, gates, per-pack aggro, door seals,
## lazy building, fog-of-war map, fast travel, death-to-safe-room),
## room-clear boss flow, and victory.
## Run with:  godot --headless --path game res://scenes/test.tscn
## Helpers + chapter modules live in tests/ (see test_base.gd).


# --quick: core-systems tier (~20s) for iterating on small fixes.
# It runs boot → one class kit → every systems test → UI smoke → pause
# menu, then exits BEFORE the content playthroughs (terrains, both
# chapters, opening E2Es, boss selftests). Full suite before staging.


func _ready() -> void:
	quick = "--quick" in OS.get_cmdline_user_args()
	_run()



func _run() -> void:
	await _run_systems()
	if _failed:
		return
	# --quick tier ends here, after one last check that the system menu
	# behaves (it works from ch1 state: replay lands in ch2 and exits).
	if quick:
		await _test_pause_menu()
		if _failed:
			return  # quit(1) is already queued — do not print PASS over it
		print("AUTOTEST QUICK PASS  (core systems only — run the FULL suite before staging)")
		get_tree().paused = false
		get_tree().quit(0)
		return

	await _run_campaign_ch1()
	if _failed:
		return
	await _run_campaign_ch2()


## The core-systems tier (everything the --quick run covers before the
## pause-menu check): engine math, boot, kits, gear, gems, saves, UI.
func _run_systems() -> void:
	# 0. Stat-engine math sanity.
	if absf(Stats.res_frac(120.0) - 0.5) > 0.01:
		return _fail("res curve broken")
	if Stats.crit_curve(0.9) > 0.95 or Stats.crit_curve(0.5) != 0.5:
		return _fail("crit curve broken")
	var r := Stats.resolve(100.0, "true", 0.0, 1.5, 0.0, 0.0, 500.0, 0.9, 50.0)
	if r["miss"] or r["dmg"] != 100.0 or r["crit"]:
		return _fail("true damage should ignore everything and never crit")
	# Pacing retrofit: mobs live ~2x longer at level parity; bosses don't.
	var wolf_now := Story.enemy_stats_at("wolf", 2)
	if absf(wolf_now["hp"] / Story.ALL_ENEMIES["wolf"]["hp"] - Balance.TTK_HP_MULT) > 0.01:
		return _fail("mob TTK multiplier not applied")
	var fang_now := Story.enemy_stats_at("fangmaw", 4)
	if absf(fang_now["hp"] - Story.ALL_ENEMIES["fangmaw"]["hp"]) > 0.01:
		return _fail("boss HP should not get the mob TTK multiplier")
	# Act loot ceilings: a gold chest under a C cap never pays above C.
	var caprng := RandomNumberGenerator.new()
	caprng.seed = 7
	for i in 40:
		var g := Items.roll_grade("gold", caprng, "C")
		if Items.GRADES.find(g) > Items.GRADES.find("C"):
			return _fail("loot cap leaked an %s from a gold chest" % g)
	# Level scaling is exponential: at the listed level nothing changes,
	# but a monster 10 levels up is a WALL of raw stats (no hidden rule).
	var v_at := Story.enemy_stats_at("vargoth", 10)
	var v_up := Story.enemy_stats_at("vargoth", 20)
	if absf(v_at["dmg"] - Story.ALL_ENEMIES["vargoth"]["dmg"] * Balance.ENEMY_DMG_MULT * Balance.BOSS_DMG_MULT) > 0.01:
		return _fail("at-anchor boss dmg must be base x ENEMY_DMG_MULT x BOSS_DMG_MULT")
	# Rounds 11+13: growth tracks the player curve (~5.5%/level for boss
	# dmg, per-kind rescaled hp) — +10 bites (~1.7x dmg on a base that
	# already sits 20% above parity, ~2.2x hp) without ever running away
	# into the one-shot wall that collapsed at-level parity at L38.
	if v_up["dmg"] < v_at["dmg"] * 1.55 or v_up["hp"] < v_at["hp"] * 2.0:
		return _fail("+10 growth lost its bite (want ~1.7x dmg / ~2.2x hp)")
	if v_up["dmg"] > v_at["dmg"] * 3.0:
		return _fail("+10 growth is runaway again (at-level parity collapses)")
	print("ok: stat curves + true damage + TTK retune")

	main_scene = load("res://scenes/main.tscn")
	game = main_scene.instantiate()
	game.no_saves = true  # never touch (or list) the player's real save files
	add_child(game)
	await _frames(10)

	# 1. Chapter select -> class select -> opening.
	if not (game.menus.is_open() and game.menus.current == "chapter_select"):
		return _fail("chapter select did not open")
	game.menus.pick_chapter("ch1")
	await _frames(2)
	if not (game.menus.is_open() and game.menus.current == "class_select"):
		return _fail("class select did not open")
	game.menus.pick_class("warrior")
	await _frames(5)
	if not game.hud.dialogue_active:
		return _fail("warrior opening scene did not start after class select")
	await _skip_dialogue()  # narration up to Bren's question
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("warrior opening offered no decision")
	var res_before := game.player.resonance
	game.hud._choose(0)  # kneel: own the harm
	await _frames(2)
	if game.player.resonance <= res_before or not game.get_flag("owned_the_harm", false):
		return _fail("opening choice did not move resonance / set its flag")
	await _skip_dialogue()  # Bren's reply + closing narration
	print("ok: class select + warrior opening (owned the harm)")
	if game.merchant_zones != [0]:
		return _fail("only the village should start with a merchant (got %s)" % str(game.merchant_zones))
	_buff()

	# 1b. The room graph itself: shape, reciprocity, reachability, and
	# the DESIGN.md structure rules for Chapter 1.
	await _test_room_graph()

	# Completed chapters pay no XP on replay (anti max-level farming).
	game.set_flag("completed_ch1", true)
	var xp_gate_before: int = game.player.xp
	game.player.gain_xp(50)
	if game.player.xp != xp_gate_before:
		return _fail("completed-chapter replay still paid XP")
	game.flags.erase("completed_ch1")

	# 2. Talk to the elder (simulated E keypress) -> the village gate.
	# (Room 2 is the spine's second stop wherever the seeded walk put it.)
	var village_exit := 2
	if _dir_between(0, village_exit) == "":
		return _fail("village is not linked to the road")
	if game._edge_unlocked(0, village_exit):
		return _fail("village east gate should be barred before the elder talk")
	if not game.gates.has(game._edge_key(0, village_exit)):
		return _fail("village east gate body was not built")
	game.player.global_position = game.elder.position + Vector2(40, 0)
	await _frames(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	var held := 0
	while not game.hud.dialogue_active and held < 60:
		await _frames(1)
		held += 1
	var ev_up := InputEventKey.new()
	ev_up.keycode = KEY_E
	ev_up.physical_keycode = KEY_E
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	if not game.hud.dialogue_active:
		return _fail("elder dialogue did not open")
	# Maren's greeting must READ the road choice (flag-gated variant).
	if not ("KNELT" in game.hud.text_label.text):
		return _fail("Maren did not react to the opening choice (got '%s')" % game.hud.text_label.text)
	await _skip_dialogue()
	await _frames(2)
	if not game.get_flag("met_elder", false):
		return _fail("elder talk did not set met_elder")
	if not game._edge_unlocked(0, village_exit) or game.gates.has(game._edge_key(0, village_exit)):
		return _fail("village east gate did not open after elder talk")
	print("ok: elder talk reads opening choice + village gate opens")

	# 3. Fire every ability of every class against dummy wolves.
	var anchor := game.room_center(0)
	game.player.global_position = anchor
	await _frames(5)
	var kit_classes: Array = ["warrior"] if quick else Classes.CLASSES.keys()
	for cls in kit_classes:
		game.player.set_class(cls)
		# Re-anchor every class: dashes drift the hero ~300-500px per kit
		# — six kits would carry it through the village doorway into the
		# Darkwood, where the loop's ults would slaughter calm packs.
		game.player.global_position = anchor
		game.player.locked_target = null
		_buff()
		for i in 3:
			_dummy(Vector2(90 + i * 50, i * 40 - 40))
		await _frames(3)
		for slot in ["a1", "a2", "a3", "ult"]:
			game.player.cds[slot] = 0.0
			game.player.mp = game.player.max_mp
			game.player.use_ability(slot)
			await _frames(10)
		await _frames(30)
		print("ok: %s abilities" % cls)
	game.player.set_class("warrior")
	_buff()
	# Hard reset: clear leftover dummies, projectiles and lingering ult
	# effects (arrow storm, delayed meteor) so later steps are clean.
	_clear_combat()
	game.player.locked_target = null
	game.player.global_position = anchor
	await _frames(45)

	# 3a2. Melee risk compensation: the plated classes regenerate.
	if game.player.regen_pct <= 0.0:
		return _fail("warrior passive regen missing")
	game.player.recalc()
	game.player.hp = game.player.max_hp * 0.5
	var regen_from := game.player.hp
	await get_tree().create_timer(0.5).timeout
	if game.player.hp <= regen_from:
		return _fail("passive regen did not tick")
	_buff()
	print("ok: melee passive regen")

	# Archer SECOND WIND (round 14): the no-lifesteal ranged kit heals
	# only while untouched — spacing is the sustain.
	game.player.set_class("archer")
	game.player.pending_theme_note = ""
	game.player.hp = game.player.max_hp * 0.5
	game.player.since_hurt = 0.0
	var sw_hp0: float = game.player.hp
	await get_tree().create_timer(0.5).timeout
	if game.player.hp > sw_hp0 + game.player.max_hp * 0.006:
		return _fail("second wind healed before its delay")
	game.player.since_hurt = 99.0
	var sw_hp1: float = game.player.hp
	await get_tree().create_timer(1.0).timeout
	if game.player.hp < sw_hp1 + game.player.max_hp * 0.012:
		return _fail("archer second wind did not regenerate")
	game.player.set_class("warrior")
	game.player.pending_theme_note = ""
	print("ok: archer second wind (untouched -> recovery)")

	# Mage ARCANE WARD (round 45): Blink cloaks the mage in a brief, strong
	# damage-reduction window — it SOFTENS the next hits, no longer erases one.
	game.player.set_class("mage")
	game.player.pending_theme_note = ""
	_buff()
	game.player.mp = game.player.max_mp
	game.player.cds["a3"] = 0.0  # earlier kit tests may have left it hot
	game.player.use_ability("a3")
	await _frames(3)
	if game.player.dr_time <= 0.0 or game.player.dr_amt <= 0.0:
		return _fail("blink did not raise the arcane ward DR window")
	# A hit inside the window lands, but heavily cut (magic damage, no
	# attacker: eva/res are zeroed by _buff, so ~dr_amt is the reduction).
	game.player.hurt_cd = 0.0
	var pre_hp: float = game.player.hp
	game.player.take_damage(1000.0, "magic")
	var taken: float = pre_hp - game.player.hp
	if taken <= 0.0:
		return _fail("warded hit dealt nothing (ward must soften, not absorb)")
	if taken > 1000.0 * (1.0 - game.player.dr_amt) + 1.0:
		return _fail("arcane ward DR did not cut the incoming hit")
	# True damage pierces the cloak (like plate DR).
	game.player.dr_time = 5.0
	game.player.hurt_cd = 0.0
	var pre_true: float = game.player.hp
	game.player.take_damage(200.0, "true")
	if absf((pre_true - game.player.hp) - 200.0) > 0.5:
		return _fail("arcane ward DR must not reduce true damage")
	game.player.dr_time = 0.0
	game.player.set_class("warrior")
	game.player.pending_theme_note = ""
	if game.player.flat_dr <= 0.0:
		return _fail("warrior plate DR missing (round 21)")
	print("ok: mage arcane ward (blink DR softens hits, pierced by true) + plate DR")

	# Assassin STAB SURGE (round 25): a connecting cut buffs lifesteal,
	# bigger the lower your health sits.
	game.player.set_class("assassin")
	game.player.pending_theme_note = ""
	var surge_dummy := _dummy(Vector2(50, 0))
	await _frames(2)
	game.player.hp = game.player.max_hp * 0.3
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(2)
	if game.player.stab_ls_time <= 0.0:
		return _fail("connecting stab did not raise the lifesteal surge")
	# Assert the surge STATE, not a current_lifesteal() delta — other
	# timed buffs (warlock pact from the kit loop) can expire between a
	# baseline capture and the check and poison the comparison.
	if game.player.stab_ls_amt < 0.2:
		return _fail("low-health stab surge too small (missing-hp scaling broken)")
	# Shadow Dash carries the knife (round 26): dashing through an
	# enemy stabs it in stride and grants the same surge.
	game.player.stab_ls_time = 0.0
	game.player.facing = Vector2.RIGHT
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	await _frames(2)
	if game.player.stab_ls_time <= 0.0:
		return _fail("shadow dash through an enemy did not grant the stab surge")
	# Dash refund (round 37): a CONNECTING dash-stab refunds part of the
	# cooldown — the cd must sit clearly below the full price.
	if game.player.cds["a2"] > game.player.ability_cd("a2") * (1.0 - Balance.DASH_REFUND) + 0.05:
		return _fail("connecting dash-stab did not refund the dash cooldown")
	# Graze corridor (round 29): passing NEXT to an enemy (~85px off the
	# dash line, outside the 55px damage lane) still lands the stab.
	var graze_dummy := _dummy(Vector2(100, 85))
	await _frames(2)
	game.player.stab_ls_time = 0.0
	game.player.facing = Vector2.RIGHT
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	await _frames(2)
	if game.player.stab_ls_time <= 0.0:
		return _fail("graze-pass dash did not land the stab (105px corridor broken)")
	# Blade cadence (round 35): Stab and Fan of Knives share a lockout —
	# casting either floors the twin's cooldown (no point-blank weave).
	game.player.cds["a1"] = 0.0
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a1")
	if game.player.cds["a3"] <= 0.0:
		return _fail("stab did not lock Fan of Knives (blade cadence broken)")
	game.player.cds["a1"] = 0.0
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	if game.player.cds["a1"] <= 0.0:
		return _fail("Fan of Knives did not lock Stab (blade cadence broken)")
	await _frames(3)
	# Earned knives (round 37): unsurged darts chip thin; during the
	# surge window the SAME cast bites double. Assert the ratio via the
	# projectiles' damage mult (immune to talent/gear multipliers).
	for stale in get_tree().get_nodes_in_group("projectiles"):
		stale.queue_free()
	await _frames(1)
	game.player.stab_ls_time = 0.0
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	await _frames(1)
	var knife_base := 0.0
	for node in get_tree().get_nodes_in_group("projectiles"):
		if node is Projectile and node.tex_kind == "dart":
			knife_base = maxf(knife_base, node.hit_player_mult)
		node.queue_free()
	await _frames(1)
	game.player.stab_ls_time = 4.0
	game.player.cds["a3"] = 0.0
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a3")
	await _frames(1)
	var knife_surged := 0.0
	for node in get_tree().get_nodes_in_group("projectiles"):
		if node is Projectile and node.tex_kind == "dart":
			knife_surged = maxf(knife_surged, node.hit_player_mult)
		node.queue_free()
	await _frames(1)
	if knife_base <= 0.0 or absf(knife_surged / knife_base - Balance.KNIFE_SURGE_MULT) > 0.05:
		return _fail("surge did not double the knives (base %.2f, surged %.2f)" %
			[knife_base, knife_surged])
	game.player.stab_ls_time = 0.0
	# Fixed execution (round 38): Death Mark's cooldown ignores haste
	# and cd talents — the authored cd is the floor at any build.
	var cdr_save: float = game.player.cdr
	game.player.cdr = 0.45
	var ult_cd_data: float = Classes.ability("assassin", "ult")["cd"]
	var ult_cd_now := game.player.ability_cd("ult")
	game.player.cdr = cdr_save
	if absf(ult_cd_now - ult_cd_data) > 0.01:
		return _fail("Death Mark cd must be FIXED (haste leaked in: %.1fs vs %.1fs)" %
			[ult_cd_now, ult_cd_data])
	graze_dummy.take_damage(9999999.0)
	surge_dummy.take_damage(9999999.0)
	await _frames(2)
	# Sweep the corpses' droppings: the dashes carried the player out of
	# magnet range, so stray coins linger and later magnet into the
	# save-roundtrip's exact gold assertion.
	for drop in game.get_children():
		if drop is Pickup or drop is Chest:
			drop.queue_free()
	await _frames(1)
	game.player.hp = game.player.max_hp
	game.player.stab_ls_time = 0.0
	game.player.set_class("warrior")
	game.player.pending_theme_note = ""
	print("ok: assassin stab surge (stab + dash-stab, scales with missing health)")

	# 3b. Target lock cycling.
	var d1 := _dummy(Vector2(120, 0))
	var d2 := _dummy(Vector2(-160, 30))
	await _frames(3)
	game.player.cycle_target()
	var first := game.player.locked_target
	if first == null:
		return _fail("cycle_target did not lock anything")
	game.player.cycle_target()
	if game.player.locked_target == first:
		return _fail("cycle_target did not switch targets")
	d1.take_damage(999999.0)
	d2.take_damage(999999.0)
	await _frames(5)
	print("ok: target lock cycling")

	# 3c. Themes: level up until one unlocks, assign it, verify the DoT.
	while game.player.themes_known < 1 and game.player.level < 10:
		game.player.gain_xp(game.player.xp_needed())
		await _frames(2)
	if game.player.themes_known < 1:
		return _fail("no theme unlocked by level %d" % game.player.level)
	game.player.pending_theme_note = ""
	if game.player.ability_theme["a1"] == "":
		return _fail("first theme was not auto-assigned")
	# Warrior theme column 1 = Fury; switch a1 to Earth (index 2) for a testable stun/slow.
	game.player.set_ability_theme("a1", "fury")
	var probe := _dummy(Vector2(70, 0))
	await _frames(3)
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(8)
	if is_instance_valid(probe) and not probe.dying:
		probe.take_damage(999999.0)
	print("ok: themes unlock + assignment (%s on Cleave)" % game.player.ability_theme["a1"])

	# All-in loadout (round 18 QoL): one call themes every ability.
	game.player.set_all_themes("fury")
	for ai_slot in ["a1", "a2", "a3", "ult"]:
		if game.player.ability_theme[ai_slot] != "fury":
			return _fail("set_all_themes left %s unthemed" % ai_slot)
	game.player.set_all_themes("")
	if game.player.ability_theme["a1"] != "":
		return _fail("set_all_themes could not reset to base")
	print("ok: all-in theme loadout")

	# 3c2. Per-ability variants: one theme, different behavior per skill.
	game.player.themes_known = 3  # test cheat: open all three columns
	# Earth Cleave launches a stone shockwave (a piercing projectile).
	game.player.set_ability_theme("a1", "earth")
	var proj_before := get_tree().get_nodes_in_group("projectiles").size()
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(2)
	if get_tree().get_nodes_in_group("projectiles").size() <= proj_before:
		return _fail("earth Cleave did not launch a quake wave")
	# Fury Berserk: deeper rage tuning (+55% for 10s).
	game.player.set_ability_theme("ult", "fury")
	game.player.cds["ult"] = 0.0
	game.player.use_ability("ult")
	if absf(game.player.berserk_bonus - 0.55) > 0.001 or game.player.berserk_time < 9.5:
		return _fail("fury Berserk tuning not applied (bonus %.2f, dur %.1f)" %
			[game.player.berserk_bonus, game.player.berserk_time])
	game.player.berserk_time = 0.0

	# Poison Fan of Knives: ONE blade that blooms into a poison mist.
	game.player.set_class("assassin")
	game.player.themes_known = 3
	game.player.set_ability_theme("a3", "poison")
	var vic := _dummy(Vector2(130, 0))
	vic.max_hp = 100000.0
	vic.hp = vic.max_hp
	vic.speed = 0.0  # pin it: a chasing wolf can slip inside the knife's spawn offset
	await _frames(3)
	game.player.cds["a3"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a3")
	# Poll in REAL time, not frames: headless frames run uncapped while
	# the mist ticks on wall-clock timers (0.4s), so frame counts race
	# far ahead of the poison. One retry in case the throw whiffed.
	var bloom_waited := 0.0
	while is_instance_valid(vic) and not vic.dying and vic.burn_time <= 0.0 and bloom_waited < 4.0:
		await get_tree().create_timer(0.2).timeout
		bloom_waited += 0.2
		if absf(bloom_waited - 2.0) < 0.01:
			game.player.cds["a3"] = 0.0
			game.player.mp = game.player.max_mp
			game.player.use_ability("a3")
	if not is_instance_valid(vic) or vic.burn_time <= 0.0:
		return _fail("venom bloom mist did not poison the target")
	_clear_combat()

	# Hunt Tumble: lines up a guaranteed crit on the next hit.
	game.player.set_class("archer")
	game.player.themes_known = 3
	game.player.set_ability_theme("a3", "hunt")
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	if not game.player.next_crit:
		return _fail("hunt Tumble did not line up a guaranteed crit")
	game.player.next_crit = false
	game.player.set_class("warrior")  # restore for the combo test
	game.player.pending_theme_note = ""
	await _frames(3)
	print("ok: per-ability theme variants (quake / berserk tune / venom bloom / lined shot)")

	# 3c3. Paladin kit: Aegis guard + redirect smite, Consecration
	# heal-on-hit, Chains of Wrath drag.
	game.player.set_class("paladin")
	game.player.themes_known = 3
	_buff()
	game.player.eva = 0.0
	game.player.cds["a3"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a3")
	if game.player.aegis_time <= 0.0:
		return _fail("Aegis did not raise the shield")
	var smite_probe := _dummy(Vector2(60, 0))
	smite_probe.max_hp = 100000.0
	smite_probe.hp = smite_probe.max_hp
	smite_probe.speed = 0.0
	await _frames(3)
	game.player.hurt_cd = 0.0
	game.player.take_damage(10.0, "phys")
	await _frames(3)
	if smite_probe.hp >= smite_probe.max_hp:
		return _fail("Aegis did not smite the attacker")
	# Holy Consecration: every enemy struck mends you.
	game.player.set_ability_theme("a2", "holy")
	game.player.regen_pct = 0.0  # isolate the on-hit mend from passive regen
	game.player.hp = game.player.max_hp * 0.5
	var pal_hp := game.player.hp
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	await _frames(10)
	if game.player.hp <= pal_hp:
		return _fail("holy Consecration did not mend on hit")
	game.player.recalc()  # restore the passive regen
	# Chains of Wrath: the pack is dragged to the hammer. The drag tween
	# (0.28s) and the verdict timer (0.34s) run on WALL clock, so poll in
	# real time — headless frames race far ahead of timers.
	var dragged := _dummy(Vector2(240, 0))
	dragged.max_hp = 100000.0
	dragged.hp = dragged.max_hp
	dragged.speed = 0.0
	await _frames(3)
	game.player.cds["ult"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("ult")
	var chains_waited := 0.0
	while is_instance_valid(dragged) and not dragged.dying \
			and dragged.hp >= dragged.max_hp and chains_waited < 3.0:
		await get_tree().create_timer(0.2).timeout
		chains_waited += 0.2
	if is_instance_valid(dragged) and not dragged.dying:
		if dragged.hp >= dragged.max_hp:
			return _fail("Chains of Wrath dealt no damage")
		if dragged.global_position.distance_to(game.player.global_position) > 200.0:
			return _fail("Chains of Wrath did not drag the enemy in")
	_clear_combat()
	game.player.aegis_time = 0.0
	await _frames(3)
	print("ok: paladin kit (aegis smite, holy mend, chains drag)")

	# 3c4. Warlock kit: hex death-detonation, Dark Pact blood price,
	# Void Rift delayed burst.
	game.player.set_class("warlock")
	game.player.themes_known = 3
	_buff()
	var hexed_a := _dummy(Vector2(90, 0))
	hexed_a.max_hp = 100000.0
	hexed_a.hp = hexed_a.max_hp
	hexed_a.speed = 0.0
	var hexed_b := _dummy(Vector2(150, 0))
	hexed_b.max_hp = 100000.0
	hexed_b.hp = hexed_b.max_hp
	hexed_b.speed = 0.0
	await _frames(3)
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	await _frames(3)
	if game.player.hexed.size() < 2:
		return _fail("Hex did not curse the pack (%d cursed)" % game.player.hexed.size())
	# Zero the hex's own DoT first so the only damage left to observe is
	# the death-detonation itself.
	hexed_b.burn_time = 0.0
	hexed_b.burn_dps = 0.0
	var b_hp: float = hexed_b.hp
	hexed_a.take_damage(999999.0)
	var boom_wait := 0.0
	while is_instance_valid(hexed_b) and hexed_b.hp >= b_hp and boom_wait < 2.0:
		await get_tree().create_timer(0.1).timeout
		boom_wait += 0.1
	if not is_instance_valid(hexed_b) or hexed_b.hp >= b_hp:
		return _fail("hex death-detonation did not hit the neighbor")
	# Dark Pact: HP is the cost, a lifesteal surge is the recovery.
	game.player.regen_pct = 0.0  # the blood price must stay visible
	game.player.hp = game.player.max_hp
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	if game.player.hp >= game.player.max_hp:
		return _fail("Dark Pact did not take its blood price")
	if game.player.pact_time <= 0.0:
		return _fail("Dark Pact did not start the lifesteal surge")
	game.player.recalc()
	# Void Rift: pulls for ~0.9s of WALL time, then bursts — poll.
	hexed_b.burn_time = 0.0
	hexed_b.burn_dps = 0.0
	var rift_hp: float = hexed_b.hp
	game.player.cds["ult"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("ult")
	var rift_wait := 0.0
	while is_instance_valid(hexed_b) and not hexed_b.dying \
			and hexed_b.hp >= rift_hp and rift_wait < 4.0:
		await get_tree().create_timer(0.2).timeout
		rift_wait += 0.2
	if is_instance_valid(hexed_b) and not hexed_b.dying and hexed_b.hp >= rift_hp:
		return _fail("Void Rift burst dealt no damage")
	_clear_combat()
	game.player.hexed.clear()
	game.player.pact_time = 0.0
	game.player.set_class("warrior")  # restore for the combo test
	game.player.pending_theme_note = ""
	_buff()
	await _frames(3)
	print("ok: warlock kit (hex detonation, dark pact, void rift)")

	# 3d. COMBO stat: at the 60% cap, ~60% of casts skip the cooldown
	# (cds left at 0 by a proc, or set to the full cooldown otherwise).
	var resets := 0
	for i in 200:
		game.player.combo = 1.0  # re-assert: recalc() from a stray level-up would reset it
		game.player.cds["a2"] = 0.0
		game.player.mp = game.player.max_mp
		game.player.use_ability("a2")
		if game.player.cds["a2"] <= 0.0:
			resets += 1
	if resets < 60 or resets > 180:
		return _fail("combo reset rate out of range: %d/200 (expected ~120)" % resets)
	game.player.recalc()  # restore real combo value
	print("ok: combo stat (%d/200 resets)" % resets)

	# 3d2. Attributes: +1/level, class-scaled conversion, CR responds.
	if game.player.unspent_attr < 1:
		return _fail("no attribute points after leveling (has %d)" % game.player.unspent_attr)
	var cr_before := game.player.combat_rating()
	var atk_b := game.player.atk
	var primary_attr: String = Classes.CLASSES[game.player.cls]["primary"]
	if not game.player.add_attr_points(primary_attr, 5):
		return _fail("could not spend attribute points")
	if game.player.atk <= atk_b:
		return _fail("primary attribute points did not raise ATK")
	if game.player.combat_rating() <= cr_before:
		return _fail("combat rating did not rise with attributes")
	print("ok: attributes + combat rating (CR %d -> %d)" % [cr_before, game.player.combat_rating()])

	# 3d2b. Substats: points can go STRAIGHT into a substat (1:1 for
	# every class — combo deliberately not purchasable).
	game.player.unspent_attr += 1  # grant one point for the check
	var pres_b: float = game.player.physres
	if game.player.attr_points.has("combo") or Classes.SUBSTAT_SCALE.has("combo"):
		return _fail("combo must not be purchasable with attribute points")
	if not game.player.add_attr_points("PhysRes", 1):
		return _fail("could not spend a substat point")
	if game.player.physres <= pres_b:
		return _fail("PhysRes point did not raise physres")
	print("ok: substat allocation (PhysRes %d -> %d)" % [int(pres_b), int(game.player.physres)])

	# 3d3. Monster levels: a Lv 30 wolf out-stats a story-level wolf.
	var w_lo := Story.enemy_stats_at("wolf", 2)
	var w_hi := Story.enemy_stats_at("wolf", 30)
	var boss_hi := Story.enemy_stats_at("fangmaw", 30)
	if w_hi["hp"] <= w_lo["hp"] or w_hi["dmg"] <= w_lo["dmg"]:
		return _fail("wolf did not scale with level")
	if boss_hi["hp"] / Story.ALL_ENEMIES["fangmaw"]["hp"] <= w_hi["hp"] / (Story.ALL_ENEMIES["wolf"]["hp"] * Balance.TTK_HP_MULT):
		return _fail("boss growth should outpace trash growth")
	# 3d3b. NO DOWNSCALING: the listed level is a MINIMUM — asking for
	# less clamps UP (an endgame boss in chapter 1 arrives as-is) — and
	# every substat climbs with level via the monster attribute build.
	var v_lo := Story.enemy_stats_at("vargoth", 1)
	if v_lo["level"] != int(Story.ALL_ENEMIES["vargoth"]["level"]) \
			or absf(v_lo["hp"] - Story.ALL_ENEMIES["vargoth"]["hp"]) > 0.01:
		return _fail("boss below its anchor should clamp UP to its listed level/stats")
	var v_30 := Story.enemy_stats_at("vargoth", 30)
	if v_30["physpen"] <= v_lo["physpen"] or v_30["physres"] <= v_lo["physres"] \
			or v_30["critres"] <= v_lo["critres"]:
		return _fail("boss substats did not scale with level")
	var lv_wolf := _dummy(Vector2(120, 40))
	var lv_wolf30 := Enemy.make(game, "wolf", game.player.global_position + Vector2(-140, 40), 30)
	game.add_enemy(lv_wolf30)
	await _frames(3)
	if lv_wolf30.max_hp <= lv_wolf.max_hp or lv_wolf30.level != 30:
		return _fail("spawned enemy did not honor its level")
	lv_wolf.take_damage(9999999.0)
	lv_wolf30.take_damage(9999999.0)
	await _frames(3)
	# Boss gem chance curve (round 44): 1/25 at the early floor, rising
	# with level, guaranteed at the L40 cap.
	if absf(Balance.boss_gem_chance(5.0) - Balance.BOSS_GEM_CHANCE_MIN) > 0.001 \
			or Balance.boss_gem_chance(40.0) < 1.0 \
			or Balance.boss_gem_chance(20.0) <= Balance.boss_gem_chance(10.0):
		return _fail("boss gem chance curve broken (%.2f / %.2f / %.2f)" %
			[Balance.boss_gem_chance(5.0), Balance.boss_gem_chance(20.0), Balance.boss_gem_chance(40.0)])
	print("ok: monster levels + growth scaling")

	# 3d3b. Every catalogued boss must resolve to a real FIGHT track through
	# the gameplay path (_boss_music -> _boss_track), not just the dev/selftest
	# spawn helper. Guards the ch3 "declared music, silent in-game" regression.
	_test_boss_music()

	# 3d4. Elites, bags, reset stones, small rooms (playtest round 6).
	await _test_elites_bags_smallrooms()

	# 3d5. Mailbox: ground overflow, flush, claim, expiry, trusted clock.
	await _test_mailbox()

	# 3d6. Daily login reward: new-day claim, streak advance + reset.
	_test_daily()

	# 3d7. Records + achievements: best-time keeping and idempotent unlock.
	_test_records()

	# 3d8. Bounties + weekly vault: roll, progress reward, vault claim.
	_test_bounties()

	# 3d9. Reforge bench: affix reroll, value reroll, add socket + cap.
	_test_reforge()

	# 3d10. Set bonuses: piece counting, cross-class isolation, recalc.
	_test_set_bonus()

	# 3d11. Account stash: deposit, withdraw to bag, capacity cap.
	_test_stash()

	# 3d12. Localization: lookup, key fallback, format, language swap.
	_test_loc()

	# 3d13. Consumables: mana draught, might elixir, recall scroll.
	_test_consumables()

	# 3d14. Gamble vendor: afford gate, cost deduction, item delivered.
	_test_gamble()

	# 3d15. Equip / unequip: slot empties back to the bag, bag-full guard.
	_test_equip_unequip()

	# 3d16. Retention pass: chapter grades + PBs, weekly challenge fx,
	# kill-count lore + titles, risk-event curse, loot fanfare bank.
	await _test_retention()

	# 3e. Kill XP.
	var xp_probe := _dummy(Vector2(80, 0))
	await _frames(3)
	var xp_before := game.player.xp + game.player.level * 100000
	xp_probe.take_damage(999999.0)
	await _frames(5)
	if game.player.xp + game.player.level * 100000 <= xp_before:
		return _fail("kill gave no xp")
	print("ok: kill xp")

	# 4. Chest -> loot -> equip.
	var bag_before := game.player.backpack.size()
	Chest.drop(game, "gold", game.player.global_position)
	await _frames(10)
	if game.player.backpack.size() <= bag_before:
		return _fail("chest gave no item")
	var got: Dictionary = game.player.backpack[-1]
	game.player.equip(got)
	if not game.player.equipment.has(got["slot"]):
		return _fail("equip failed")
	print("ok: chest loot + equip (%s)" % Items.title(got))

	# 4a. Weapon shape identities.
	var wrng := RandomNumberGenerator.new()
	wrng.seed = 3
	var clay := Items.roll_item_of("weapon", "C", wrng, "", "Claymore")
	var fang := Items.roll_item_of("weapon", "C", wrng, "", "Fang")
	if clay["main"]["atk_flat"] <= fang["main"]["atk_flat"]:
		return _fail("Claymore does not out-damage Fang")
	if not fang["subs"].has("crit"):
		return _fail("Fang has no guaranteed crit substat")
	print("ok: weapon shape identities")

	# Class-aware drops (round 15): a class only loots weapons from its
	# own arsenal and never rolls the other damage type's penetration.
	var crng := RandomNumberGenerator.new()
	crng.seed = 42
	for i in 30:
		var aw := Items.roll_item_of("weapon", "A", crng, "archer")
		if not (aw["noun"] in Items.CLASS_WEAPONS["archer"]):
			return _fail("archer looted a %s (not in the archer arsenal)" % aw["noun"])
		var ai := Items.roll_item_of(Items.SLOTS[i % 4], "S", crng, "archer")
		if ai["subs"].has("magpen"):
			return _fail("archer gear rolled MagPen (dead stat)")
		var mi := Items.roll_item_of(Items.SLOTS[i % 4], "S", crng, "mage")
		if mi["subs"].has("physpen"):
			return _fail("mage gear rolled PhysPen (dead stat)")
		# Endgame-only stats (round 43): nothing below B may carry
		# lifesteal or combo — including shape personality stats
		# (the Wand's built-in combo, the Tome's lifesteal).
		var low := Items.roll_item_of(Items.SLOTS[i % 4], ["F", "E", "D", "C"][i % 4], crng)
		var wand_low := Items.roll_item_of("weapon", "C", crng, "", "Wand")
		if low["subs"].has("lifesteal") or low["subs"].has("combo") \
				or wand_low["subs"].has("combo") or wand_low["subs"].has("lifesteal"):
			return _fail("sub-B gear rolled an endgame-only stat (lifesteal/combo)")
	print("ok: class-aware drops (arsenal + no dead pen stats + B-gated lifesteal/combo)")

	# 4b. S weapon: class shape, 3 gem slots, passive.
	var srng := RandomNumberGenerator.new()
	srng.seed = 7
	var s_wpn := Items.roll_item_of("weapon", "S", srng, "warrior")
	if s_wpn.get("passive", "") != "kingsblade" or s_wpn.get("cls", "") != "warrior":
		return _fail("S warrior weapon wrong passive/class")
	if s_wpn.get("gem_slots", 0) != 3:
		return _fail("S gear should have 3 gem slots")
	game.player.add_item(s_wpn)
	game.player.equip(s_wpn)
	if game.player.s_passive() != "kingsblade":
		return _fail("s_passive not active after equipping")
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(15)
	print("ok: S weapon + passive (%s)" % s_wpn["name"])

	# 4c. Gems: targeted socket, removal, stat change, synthesize, sell-return.
	var cg := Items.make_gem("crit", 1)
	game.player.gem_bag.append(cg)
	var crit_before := game.player.crit
	if not game.player.embed_gem_into(s_wpn, cg):
		return _fail("gem did not socket into chosen S weapon")
	if game.player.crit <= crit_before:
		return _fail("socketed crit gem did not raise crit")
	# Remove it and re-socket (player-controlled swap).
	game.player.remove_gem(s_wpn, 0)
	if s_wpn["gems"].size() != 0 or absf(game.player.crit - crit_before) > 0.001:
		return _fail("remove_gem did not restore stats")
	game.player.embed_gem_into(s_wpn, cg)
	game.menus.open_item_panel(s_wpn)
	await _frames(2)
	if game.menus.current != "item_panel":
		return _fail("item panel did not open")
	game.menus.close()
	await _frames(2)
	for i in 3:
		game.player.gem_bag.append(Items.make_gem("crit", 1))
	if not game.player.synthesize("crit", 1):
		return _fail("synthesize failed with 3 same gems")
	var has_lv2 := false
	for gem in game.player.gem_bag:
		if gem["stat"] == "crit" and gem["lvl"] == 2:
			has_lv2 = true
	if not has_lv2:
		return _fail("synthesis did not produce a Lv2 gem")
	# Selling returns embedded gems.
	var bag_gems := game.player.gem_bag.size()
	game.player.strip_gems(s_wpn)
	if game.player.gem_bag.size() != bag_gems + 1:
		return _fail("strip_gems did not return the socketed gem")
	game.player.recalc()
	print("ok: gems (socket, synthesize, sell-return)")

	# 4d. Telegraph resolves.
	game.telegraph(game.player.global_position + Vector2(40, 0), 60.0, 0.3, 5.0, {"sword": true})
	await _frames(45)
	print("ok: telegraph + falling sword")

	# 5. Skill tree: row caps and gating.
	game.player.skill_points = 12
	if game.player.level < Skills.ROW_LEVELS[1]:
		return _fail("test expects level >= row 2 by now")
	var added := 0
	for i in 6:  # try to overfill row 0
		if game.player.add_tree_point("w00"):
			added += 1
	if added != 5:
		return _fail("cell cap should stop at 5 (got %d)" % added)
	if game.player.add_tree_point("w01"):
		return _fail("row cap should block a 6th point in row 0")
	if game.player.dm("a1") < 1.24:
		return _fail("5 points in Heavy Cleave should give +25%")
	var high_row := Skills.TREES["warrior"][3][0]["id"]
	if game.player.level < Skills.ROW_LEVELS[3] and game.player.add_tree_point(high_row):
		return _fail("locked row accepted a point")
	print("ok: skill tree rows (caps + gating)")

	# 5a2. Auto-synthesize: socketed gems level first, then the bag rolls up.
	var socketed_item: Dictionary = game.player.equipment["weapon"]
	socketed_item["gems"].clear()
	game.player.gem_bag.clear()
	game.player.gem_bag.append(Items.make_gem("atk_pct", 1))
	if not game.player.embed_gem_into(socketed_item, game.player.gem_bag[0]):
		return _fail("could not socket the auto-synth test gem")
	for i in 11:
		game.player.gem_bag.append(Items.make_gem("atk_pct", 1))
	# 1 socketed L1 + 11 bag L1: socketed eats 2 (->L2), bag 9 -> 3xL2,
	# socketed eats 2 L2 (->L3), 1 L2 remains. 5 upgrades total.
	var ups: int = game.player.auto_synthesize()
	var socketed_lvl: int = socketed_item["gems"][0]["lvl"]
	if ups != 5 or socketed_lvl != 3:
		return _fail("auto-synthesize wrong result: %d upgrades, socketed L%d (want 5, L3)" % [ups, socketed_lvl])
	if game.player.gem_bag.size() != 1 or game.player.gem_bag[0]["lvl"] != 2:
		return _fail("auto-synthesize bag remainder wrong (%d gems)" % game.player.gem_bag.size())
	game.player.gem_bag.clear()
	socketed_item["gems"].clear()
	game.player.recalc()
	print("ok: auto-synthesize (equipped-first, %d upgrades)" % ups)

	# 5b. Save / load roundtrip on a scratch slot (now with room state).
	var p: Player = game.player
	p.gold = 4321
	p.resonance = -37.0
	p.faction_standing["cinderborn"] = 12
	var flags_keep: Dictionary = game.flags.duplicate(true)  # restore after — later tests need the opening flags
	game.set_flag("rt_flag", true)
	var kept_quest: String = game.quest_key
	var kept_level: int = p.level
	var kept_weapon: String = p.equipment["weapon"]["name"] if p.equipment.has("weapon") else ""
	var kept_atk: float = p.atk
	var kept_seed: int = game.wander_seed
	var kept_visited: int = game.visited.size()
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	p.gold = 0
	p.resonance = 0.0
	p.faction_standing["cinderborn"] = 0
	game.quest_key = "talk"
	game.flags.clear()
	game.wander_seed = 0
	var loaded := SaveGame.read(SaveGame.MAX_SLOTS)
	if loaded.is_empty():
		return _fail("save file did not write/read")
	if String(loaded.get("chapter", "")) != "ch1":
		return _fail("save did not record its chapter")
	if int(loaded.get("version", 0)) != SaveGame.VERSION:
		return _fail("save version wrong")
	SaveGame.apply(game, loaded)
	await _frames(2)
	if p.gold != 4321 or p.resonance != -37.0 or p.faction_standing["cinderborn"] != 12:
		return _fail("save did not restore gold/resonance/faction")
	if game.quest_key != kept_quest or p.level != kept_level:
		return _fail("save did not restore quest/level")
	var got_weapon: String = p.equipment["weapon"]["name"] if p.equipment.has("weapon") else ""
	if got_weapon != kept_weapon:
		return _fail("save did not restore equipment")
	if absf(p.atk - kept_atk) > 0.01:
		return _fail("stats after load differ from before save (atk %.2f vs %.2f)" % [p.atk, kept_atk])
	if not game.get_flag("rt_flag", false):
		return _fail("story flags did not survive the save roundtrip")
	if game.wander_seed != kept_seed:
		return _fail("wander seed did not survive the roundtrip")
	if game.visited.size() != kept_visited or not game.visited.get(0, false):
		return _fail("visited rooms did not survive the roundtrip")
	if game.cur_room != 0:
		return _fail("cur_room did not survive the roundtrip (got %d)" % game.cur_room)
	game.flags = flags_keep  # never strand the run without its opening flags
	game.flags["met_elder"] = true
	SaveGame.delete(SaveGame.MAX_SLOTS)
	if SaveGame.exists(SaveGame.MAX_SLOTS):
		return _fail("save delete failed")
	print("ok: save/load roundtrip (gold, resonance, factions, gear, room state)")

	# 5c. Choice dialogue + flag engine: choices apply resonance/flags,
	# and both flag- and band-gated text variants resolve.
	var convo := {
		"start": "n1",
		"nodes": {
			"n1": {"who": "Tester", "text": "Neutral opener.",
				"variants": [{"band": "tempted", "text": "Tempted opener."}],
				"choices": [
					{"text": "Dark path", "resonance": -40.0,
						"flags": {"chose_dark": true}, "faction": {"choir": 3}, "next": "n2"},
					{"text": "Light path", "resonance": 10.0, "next": "n2"},
				]},
			"n2": {"who": "Tester", "text": "Default reply.",
				"variants": [{"flag": "chose_dark", "text": "Flagged reply."}]},
		},
	}
	var convo_state := {"done": false}
	game.player.resonance = 0.0
	game.run_convo(convo, func() -> void: convo_state["done"] = true)
	await _frames(2)
	if not game.hud.choices_active or game.hud.choice_count != 2:
		return _fail("choice dialogue did not present 2 options")
	if game.hud.text_label.text != "Neutral opener.":
		return _fail("neutral variant not chosen at resonance 0")
	game.hud._choose(0)
	await _frames(2)
	if game.player.resonance != -40.0 or not game.get_flag("chose_dark", false):
		return _fail("choice did not apply resonance/flag")
	if game.player.faction_standing["choir"] != 3:
		return _fail("choice did not shift faction standing")
	if game.hud.text_label.text != "Flagged reply.":
		return _fail("flag-gated variant not shown (got '%s')" % game.hud.text_label.text)
	await _skip_dialogue()
	if not convo_state["done"]:
		return _fail("convo completion callback did not fire")
	# Resonance is now -40 = "tempted" band: the opener must change.
	game.run_convo(convo, Callable())
	await _frames(2)
	if game.hud.text_label.text != "Tempted opener.":
		return _fail("band-gated variant not shown for tempted resonance")
	game.hud._choose(1)
	await _frames(2)
	await _skip_dialogue()
	game.player.resonance = 0.0
	game.player.faction_standing["choir"] = 0
	game.flags.erase("chose_dark")  # cleanup — but keep the opening flags
	print("ok: choice dialogue engine (choices, flags, factions, resonance bands)")

	# 5d. Opening-convo data integrity: every node resolves, every cue
	# has a staged scene, every opening has a Maren counterpart.
	for cid in Story.ALL_CONVOS:
		var convo2: Dictionary = Story.ALL_CONVOS[cid]
		var nodes2: Dictionary = convo2["nodes"]
		if not nodes2.has(convo2["start"]):
			return _fail("%s: start node missing" % cid)
		for nid in nodes2:
			var node2: Dictionary = nodes2[nid]
			var nxt: String = String(node2.get("next", ""))
			if nxt != "" and not nodes2.has(nxt):
				return _fail("%s/%s: next '%s' missing" % [cid, nid, nxt])
			if node2.has("cue") and not (String(node2["cue"]) in Cutscene.KNOWN_CUES):
				return _fail("%s/%s: unknown cue '%s'" % [cid, nid, node2["cue"]])
			for c2 in node2.get("choices", []):
				var cnxt: String = String(c2.get("next", ""))
				if cnxt != "" and not nodes2.has(cnxt):
					return _fail("%s/%s: choice next '%s' missing" % [cid, nid, cnxt])
			for v2 in node2.get("variants", []):
				var vnxt: String = String(v2.get("next", ""))
				if vnxt != "" and not nodes2.has(vnxt):
					return _fail("%s/%s: variant next '%s' missing" % [cid, nid, vnxt])
		if cid.begins_with("open_") and not Story.ALL_CONVOS.has("maren_" + cid.substr(5)):
			return _fail("%s has no matching Maren convo" % cid)
	# The wanderer pool's convos must all exist.
	for w in Story.WANDERERS:
		if not Story.ALL_CONVOS.has(String(w["convo"])):
			return _fail("wanderer convo '%s' missing" % w["convo"])
	print("ok: opening convo data integrity (%d convos)" % Story.ALL_CONVOS.size())

	# 6. Shop + codex + map still open fine.
	game.player.gold = 500
	# Inventory must survive a gem hoard (compact grid + capped scroll).
	for i in 40:
		game.player.gem_bag.append(Items.random_gem(game.loot_rng, 1 + (i % 5)))
	game.menus.open_inventory()
	await _frames(2)
	if not game.menus.is_open():
		return _fail("inventory did not open with a 40-gem bag")
	game.menus.close()
	game.player.gem_bag.clear()
	await _frames(1)
	game.menus.open_shop(0)
	await _frames(2)
	if not game.menus.is_open() or game.shop_stock[0].size() != 3:
		return _fail("shop did not open with stock")
	game.menus.open_codex("gear")
	await _frames(2)
	game.menus.open_codex("terrains")
	await _frames(2)
	game.menus.open_codex("monsters")
	await _frames(2)
	game.menus.open_codex("status")
	await _frames(2)
	game.menus.open_skills()
	await _frames(2)
	game.menus.open_theme_picker("a1")
	await _frames(2)
	if game.menus.current != "theme_pick":
		return _fail("theme picker did not open")
	game.menus.open_inventory("stats")
	await _frames(2)
	game.menus.open_skills("attributes")
	await _frames(2)
	game.menus.open_map()
	await _frames(2)
	if game.menus.current != "map":
		return _fail("map screen did not open")
	game.menus.open_codex("records")
	await _frames(2)
	if game.menus.current != "codex":
		return _fail("codex Records tab did not open")
	game.menus.open_journal()
	await _frames(2)
	if game.menus.current != "journal":
		return _fail("quest log did not open")
	game.menus.open_stash()
	await _frames(2)
	if game.menus.current != "stash":
		return _fail("stash did not open")
	game.menus.open_daily()
	await _frames(2)
	if game.menus.current != "daily":
		return _fail("daily reward screen did not open")
	game.menus.open_dev()
	await _frames(2)
	game.menus.close()
	await _frames(2)
	print("ok: shop, codex, records, journal, daily, skill tree, theme, stats, map, dev UI")


## Chapter 1 end to end: terrains, the darkwood walk, all three bosses.
func _run_campaign_ch1() -> void:
	# 6c. Terrains: apply every terrain to the (safe) outskirts room,
	# fire its event, tick hazards — none of it may crash.
	await _goto_room(1)
	game.player.global_position = game.rooms[1]["origin"] + Vector2(1900.0, 1100.0)
	await _frames(3)
	for tid in Terrains.DATA:
		game.apply_terrain(1, tid)
		await _frames(3)
		var terrain_ev: String = Terrains.DATA[tid].get("event", "")
		if terrain_ev != "":
			game.run_terrain_event(terrain_ev)
		await _frames(12)
	# The grave_spawn zombie path needs a "live" room: fake one monster.
	game.apply_terrain(1, "graveyard")
	game.zone_alive[1] = 1  # snapshot: outskirts are empty, restore below
	game.run_terrain_event("grave_spawn")
	await _frames(10)
	game.zone_alive[1] = 0
	game.apply_terrain(1, "village")  # restore for the story flow
	await _frames(60)  # let stray telegraphs resolve
	_clear_combat()    # remove event-spawned zombies
	game.gust_vec = Vector2.ZERO
	await _frames(5)
	_buff()
	print("ok: all %d terrains applied + events fired" % Terrains.DATA.size())

	# 7. The zone graph in play: lazy building, per-pack aggro, door
	# seals, room clears, and the fog-of-war map state.
	await _test_graph_walk_darkwood()
	if _failed:
		return

	# 7b. Fangmaw's Hollow: adds, pre-boss beat, act-scaled boss, the
	# locked east door, loot.
	await _test_fangmaw()
	if _failed:
		return

	# 7c. Marsh: merchant camp, fast travel, death -> last safe room +
	# death-room reset.
	await _test_marsh_death_and_travel()
	if _failed:
		return

	# 8. Morwen.
	await _test_morwen()
	if _failed:
		return

	# 9-10. Vargoth: enrage, death/boss-reset, victory.
	await _test_vargoth_victory()
	if _failed:
		return


## Fresh-boot resume, then Chapter 2: hub, factions, acts, progression.
func _run_campaign_ch2() -> void:
	# 11. Title screen + resume on a fresh boot. Uses only the scratch
	# slot — real saves on this machine are listed but never touched.
	get_tree().paused = false
	SaveGame.write(game, SaveGame.MAX_SLOTS)
	var visited_at_save := game.visited.size()
	game.queue_free()
	await _frames(3)
	game = main_scene.instantiate()
	add_child(game)
	# Poll WALL-CLOCK for the fresh boot: frames race ahead headless, so a
	# fixed _frames() count is flaky — the title menu may not be up yet.
	var boot_t := 0.0
	while not (game.menus != null and game.menus.is_open() and game.menus.current == "title") and boot_t < 5.0:
		await get_tree().create_timer(0.1).timeout
		boot_t += 0.1
	if not (game.menus != null and game.menus.is_open() and game.menus.current == "title"):
		return _fail("title screen did not open when saves exist")
	game.menus.close()
	game.load_save(SaveGame.MAX_SLOTS)
	# Poll for the restored character — load_save rebuilds the world across
	# frames, so the state isn't ready the instant the call returns.
	var load_t := 0.0
	while (game.player == null or game.player.cls != "warrior" or game.quest_key != "done") and load_t < 5.0:
		await get_tree().create_timer(0.1).timeout
		load_t += 0.1
	if game.player == null or game.player.cls != "warrior" or game.quest_key != "done":
		return _fail("resume did not restore the finished character")
	if not game.boss_done.get("vargoth", false):
		return _fail("resume lost boss progress")
	if not game.merchant_zones.has(0):
		return _fail("village merchant missing after resume")
	if game.visited.size() != visited_at_save:
		return _fail("resume lost the charted map (%d vs %d rooms)" % [game.visited.size(), visited_at_save])
	if not game.cleared.get(2, false):
		return _fail("resume lost cleared-room state")
	if game.room_at_pos(game.player.global_position) != game.cur_room:
		return _fail("resume put the hero outside the saved room")
	SaveGame.delete(SaveGame.MAX_SLOTS)
	print("ok: title screen + resume from save (map + clears intact)")

	# 12. A second class opening end-to-end: assassin, temptation path.
	game.queue_free()
	await _frames(3)
	game = main_scene.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(2)
	game.menus.pick_class("assassin")
	await _frames(5)
	await _skip_dialogue()  # narration up to the carter's question
	await _frames(2)
	if not game.hud.choices_active:
		return _fail("assassin opening offered no decision")
	game.hud._choose(1)  # keep what you took
	await _frames(2)
	if game.player.resonance != -12.0 or not game.get_flag("kept_taking", false):
		return _fail("assassin choice did not apply (res %.0f)" % game.player.resonance)
	await _skip_dialogue()
	print("ok: assassin opening (temptation path)")

	# 13. The Paladin and Warlock openings — live now that the classes are.
	for spec in [["paladin", "delivered_verdict"], ["warlock", "closed_tome"]]:
		game.queue_free()
		await _frames(3)
		game = main_scene.instantiate()
		game.no_saves = true
		add_child(game)
		await _frames(10)
		game.menus.pick_chapter("ch1")
		await _frames(2)
		game.menus.pick_class(spec[0])
		await _frames(5)
		await _skip_dialogue()
		await _frames(2)
		if not game.hud.choices_active:
			return _fail("%s opening offered no decision" % spec[0])
		game.hud._choose(0)  # the virtue path
		await _frames(2)
		if not game.get_flag(spec[1], false):
			return _fail("%s opening flag '%s' not set" % [spec[0], spec[1]])
		await _skip_dialogue()
		print("ok: %s opening (virtue path)" % spec[0])

	# 14. Chapter 2 boots into its hub — as a legacy chapter it converts
	# to a west→east chain of rooms.
	game.queue_free()
	await _frames(3)
	game = main_scene.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch2")
	await _frames(3)
	if game.chapter_id != "ch2" or game.zone_count < 1:
		return _fail("chapter 2 did not build (chapter=%s zones=%d)" % [game.chapter_id, game.zone_count])
	game.menus.pick_class("warrior")
	await _frames(5)
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(0)
		await _frames(2)
		await _skip_dialogue()
	if game.zones[0]["name"] != "Maren's Camp":
		return _fail("chapter 2 hub zone missing")
	# Legacy conversion: a one-row chain with east/west doors.
	if Vector2i(game.rooms[0]["coord"]) != Vector2i(0, 0) or game.neighbor(0, "E") != 1:
		return _fail("legacy chapter did not convert to a chain")
	var hub_hostiles := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == 0:
			hub_hostiles += 1
	if hub_hostiles != 0:
		return _fail("chapter 2 hub should be safe (found %d hostiles)" % hub_hostiles)
	if not game.merchant_zones.has(0):
		return _fail("chapter 2 hub merchant missing")
	print("ok: chapter 2 hub boots as a legacy chain (%d room[s])" % game.zone_count)

	# ---- CONTENT-MODULE TEST HOOK ----------------------------------------
	# T1/T2/T3/T5/T6: append your _test_*() func at the END of this file
	# and add exactly ONE `await _test_yourthing()` line here.
	await _test_ch2_hub()
	await _test_ch2_factions()
	await _test_ch2_aldric()
	await _test_ch2_act1()
	await _test_ch2_act2()
	await _test_ch2_resonance()
	await _test_ch3_bosses()
	await _test_ch4_bosses()
	await _test_ch5_bosses()
	await _test_ch6_bosses()
	await _test_ch7_bosses()
	await _test_ch3_chapter()
	await _test_ch4_chapter()
	await _test_ch5_chapter()
	await _test_ch6_chapter()
	await _test_ch7_chapter()
	await _test_pause_menu()
	# -----------------------------------------------------------------------
	await _test_ch2_bosses()
	await _test_chapter_progression()

	print("AUTOTEST PASS")
	get_tree().paused = false
	get_tree().quit(0)


# ---- CORE: every boss resolves to a real fight track (gameplay path) ----
# The story spawn and dev roster both go through _boss_track(); a boss that
# declares music with no installed track (and no valid fallback) plays SILENT.
# Assert every catalogued boss lands on an actual boss_* track.
func _test_boss_music() -> void:
	for kind in Menus.BOSS_KINDS:
		var track: String = game._boss_track(kind)
		if not track.begins_with("boss_") or not game.music_tracks.has(track):
			return _fail("boss '%s' has no fight track via the gameplay path (resolved '%s')" % [kind, track])
	print("ok: boss music (every BOSS_KINDS entry resolves to a real fight track)")


# ---- CORE: mailbox, ground overflow, trusted clock (round 8) ------------
func _test_mailbox() -> void:
	var keep_bag: Dictionary = game.player.bag
	var keep_mail: Array = game.mailbox
	var keep_dropped: Array = game.dropped_loot
	game.mailbox = []
	game.dropped_loot = []

	# Overflow drops to the ground and registers — never silently sold.
	game.player.bag = Items.make_bag("F")
	var filler: Array = []
	while game.player.bag_used() < game.player.bag_capacity():
		var st := Items.make_reset_stone()
		game.player.consumables.append(st)
		filler.append(st)
	var gold_before: int = game.player.gold
	var it := Items.roll_item_of("charm", "C", game.loot_rng, game.player.cls)
	if game.give_loot({"kind": "item", "item": it}, game.player.global_position + Vector2(400, 0)):
		return _fail("give_loot claimed into a FULL bag")
	if game.dropped_loot.size() != 1 or game.player.gold != gold_before:
		return _fail("bag-full loot did not drop to the ground registry (or sold)")
	await _frames(2)
	if get_tree().get_nodes_in_group("loot_pickups").is_empty():
		return _fail("no ground pickup spawned for dropped loot")

	# Chapter-end flush -> one "Dropped Loot" letter, empty body.
	game.flush_dropped_loot()
	await _frames(2)
	if game.mailbox.size() != 1:
		return _fail("flush did not send the Dropped Loot mail")
	var mail: Dictionary = game.mailbox[0]
	if String(mail["subject"]) != "Dropped Loot" or String(mail["body"]) != "":
		return _fail("Dropped Loot mail has wrong subject/body")
	if not game.dropped_loot.is_empty() or not get_tree().get_nodes_in_group("loot_pickups").is_empty():
		return _fail("flush left ground loot behind")

	# Claim: with space the loot lands in the bag; the letter stays.
	for st in filler:
		game.player.consumables.erase(st)
	var bp_before: int = game.player.backpack.size()
	for pl in mail["items"].duplicate():
		if game._try_receive(pl):
			mail["items"].erase(pl)
	if game.player.backpack.size() != bp_before + 1 or not mail["items"].is_empty():
		return _fail("claiming the mail did not deliver the loot")
	if game.mailbox.size() != 1:
		return _fail("claimed letter must stay until deleted")

	# Expiry: unclaimed letters die after MAIL_EXPIRY_DAYS; claimed stay.
	game.send_mail("Old Loot", "", [{"kind": "gem", "gem": Items.make_gem("crit", 1)}])
	var old_mail: Dictionary = game.mailbox[-1]
	old_mail["sent_at"] = int(old_mail["sent_at"]) - (Balance.MAIL_EXPIRY_DAYS + 1) * 86400
	mail["sent_at"] = int(mail["sent_at"]) - (Balance.MAIL_EXPIRY_DAYS + 1) * 86400
	game.prune_mail()
	if game.mailbox.size() != 1 or not game.mailbox[0]["items"].is_empty():
		return _fail("expiry pruned the wrong letters (claimed must survive)")

	# Trusted clock: never goes backwards, even if the OS clock does.
	var t1: int = game.trusted_now()
	game.clock_anchor = t1 + 99999  # "highest time ever seen" from a rolled clock
	if game.trusted_now() < t1 + 99999:
		return _fail("trusted clock went backwards")
	game.clock_anchor = 0  # back to the real OS clock

	# Restore.
	game.player.backpack.erase(it)
	game.player.bag = keep_bag
	game.mailbox = keep_mail
	game.dropped_loot = keep_dropped
	print("ok: mailbox (ground overflow, flush, claim, 30d expiry, trusted clock)")


# ---- CORE: daily login reward (new-day claim, streak advance/reset) -----
func _test_daily() -> void:
	var keep_last: int = game.daily_last_day
	var keep_streak: int = game.daily_streak
	var keep_gold: int = game.player.gold
	var keep_pot: int = game.player.potions
	var today: int = game.daily_day_index()

	# A new day since the last claim: reward is available.
	game.daily_last_day = today - 1
	game.daily_streak = 3
	if not game.daily_available():
		return _fail("daily reward not available on a new day")
	var lines: Array = game.claim_daily()
	if game.daily_streak != 4:
		return _fail("consecutive-day claim did not advance the streak (%d)" % game.daily_streak)
	if game.daily_available():
		return _fail("daily still claimable the same day")
	if game.player.gold <= keep_gold or lines.is_empty():
		return _fail("daily claim granted nothing")

	# A missed day resets the streak to 1.
	game.player.gold = keep_gold
	game.daily_last_day = today - 3
	game.daily_streak = 9
	game.claim_daily()
	if game.daily_streak != 1:
		return _fail("a missed day did not reset the streak to 1 (%d)" % game.daily_streak)

	# Restore.
	game.daily_last_day = keep_last
	game.daily_streak = keep_streak
	game.player.gold = keep_gold
	game.player.potions = keep_pot
	print("ok: daily login reward (new-day claim, streak advance + reset)")


# ---- CORE: records + achievements (best-time keeping, idempotent unlock) -
func _test_records() -> void:
	var keep_ach: Dictionary = game.achievements.duplicate()
	var keep_rec: Dictionary = game.boss_records.duplicate(true)

	# record_boss keeps the FASTEST time and the BEST dps, counting kills.
	game.boss_records = {}
	game.record_boss("fangmaw", 30.0, 100.0)
	game.record_boss("fangmaw", 20.0, 80.0)   # faster clear, weaker dps
	var r: Dictionary = game.boss_records["fangmaw"]
	if int(r["kills"]) != 2:
		return _fail("boss record did not count both kills")
	if absf(float(r["ttk"]) - 20.0) > 0.01:
		return _fail("boss record did not keep the fastest time")
	if absf(float(r["dps"]) - 100.0) > 0.01:
		return _fail("boss record did not keep the best dps")

	# unlock_achievement is idempotent and rejects unknown ids.
	game.achievements = {}
	game.unlock_achievement("first_boss")
	game.unlock_achievement("first_boss")
	game.unlock_achievement("not_a_real_id")
	if not game.achievements.has("first_boss") or game.achievements.size() != 1:
		return _fail("achievement unlock not idempotent / accepted a bad id")

	# Restore.
	game.achievements = keep_ach
	game.boss_records = keep_rec
	print("ok: records + achievements (best-time keeping, idempotent unlock)")


# ---- CORE: bounties + weekly vault (roll, progress reward, vault claim) --
func _test_bounties() -> void:
	var keep_b: Array = game.bounties
	var keep_bd: int = game.bounty_day
	var keep_bw: int = game.bounty_week
	var keep_vw: int = game.vault_week
	var keep_vp: int = game.vault_progress
	var keep_vc: int = game.vault_claimed_week
	var keep_gold: int = game.player.gold
	var keep_gems: Array = game.player.gem_bag.duplicate()
	var keep_dropped: Array = game.dropped_loot
	game.dropped_loot = []

	# A deterministic roll fills the roster and is stable for a given seed
	# (so relogging can't reroll for a kinder objective).
	game.bounties = []
	game._roll_bounties("daily", 2, 12345)
	if game._bounty_count("daily") != 2:
		return _fail("daily bounty roll did not produce 2 objectives")
	var first_type: String = String(game.bounties[0]["type"])
	game.bounties = []
	game._roll_bounties("daily", 2, 12345)
	if String(game.bounties[0]["type"]) != first_type:
		return _fail("bounty roll is not deterministic for a given seed")

	# Progress completes a matching bounty, pays once, and ignores extra.
	game.player.gold = 0
	game.bounties = [{"scope": "daily", "type": "boss_kills", "target": 1, "progress": 0,
		"desc": "Slay a boss", "gold": 100, "gems": 0, "gem_lvl": 1, "done": false}]
	game.bounty_progress("boss_kills")
	if not game.bounties[0]["done"] or game.player.gold <= 0:
		return _fail("bounty did not complete + pay at target")
	var gold_after: int = game.player.gold
	game.bounty_progress("boss_kills")
	if game.player.gold != gold_after:
		return _fail("completed bounty paid out twice")

	# Weekly vault: reaching the boss goal unlocks one claim per week.
	game.vault_week = -1
	game.vault_progress = 0
	game.vault_claimed_week = -1
	for i in Balance.VAULT_BOSS_GOAL:
		game.vault_note_boss()
	if not game.vault_ready():
		return _fail("vault not ready after reaching the boss goal")
	if game.claim_vault().is_empty():
		return _fail("vault claim returned nothing while ready")
	if game.vault_ready():
		return _fail("vault still claimable after this week's claim")

	# Clean up the vault's spawned pickups + restore.
	for n in get_tree().get_nodes_in_group("loot_pickups"):
		n.queue_free()
	game.bounties = keep_b
	game.bounty_day = keep_bd
	game.bounty_week = keep_bw
	game.vault_week = keep_vw
	game.vault_progress = keep_vp
	game.vault_claimed_week = keep_vc
	game.player.gold = keep_gold
	game.player.gem_bag = keep_gems
	game.dropped_loot = keep_dropped
	print("ok: bounties + weekly vault (deterministic roll, progress reward, vault claim)")


# ---- CORE: reforge bench (affix reroll, value reroll, add socket) -------
func _test_reforge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var it := Items.roll_item_of("weapon", "A", rng, "warrior")

	# Affix reroll keeps a grade-appropriate, non-empty sub set.
	Items.reforge_affixes(it, "warrior", rng)
	if it["subs"].is_empty():
		return _fail("reforge_affixes wiped all substats")

	# Value reroll changes one stat's magnitude (over a few tries).
	var stat := String(it["subs"].keys()[0])
	var v0: float = it["subs"][stat]
	var changed := false
	for i in 8:
		Items.reforge_sub(it, stat, rng)
		if absf(float(it["subs"][stat]) - v0) > 0.001:
			changed = true
			break
	if not changed:
		return _fail("reforge_sub never changed the value in 8 tries")

	# Add socket: A starts at 2 -> can add to 3, then hits the cap.
	var slots0: int = int(it["gem_slots"])
	if not Items.can_add_socket(it):
		return _fail("A-grade item should allow adding a socket")
	Items.add_socket(it)
	if int(it["gem_slots"]) != slots0 + 1:
		return _fail("add_socket did not add a socket")
	if Items.can_add_socket(it):
		return _fail("socket count past cap should be rejected")

	# An S weapon starts at 3 sockets and is already at the cap.
	var s_it := Items.roll_item_of("weapon", "S", rng, "warrior")
	if Items.can_add_socket(s_it):
		return _fail("S item (3 sockets) should be at the socket cap")
	print("ok: reforge bench (affix reroll, value reroll, add socket + cap)")


# ---- CORE: set bonuses (count, cross-class isolation, recalc) ------------
func _test_set_bonus() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cls: String = game.player.cls
	var other := "warrior" if cls != "warrior" else "mage"

	# Counting: two class S pieces + one wrong-class piece.
	var eq := {
		"weapon": Items.roll_item_of("weapon", "S", rng, cls),
		"armor": Items.roll_item_of("armor", "S", rng, cls),
		"boots": Items.roll_item_of("boots", "S", rng, other),
	}
	if Items.count_set_pieces(eq, cls) != 2:
		return _fail("count_set_pieces miscounted this class's S pieces")
	if Items.count_set_pieces(eq, other) != 1:
		return _fail("count_set_pieces leaked across classes")

	# recalc detects 2 vs 4 pieces without error, and a full set beats none.
	var keep_eq: Dictionary = game.player.equipment
	game.player.equipment = {}
	game.player.recalc()
	var atk_bare: float = game.player.atk
	game.player.equipment = {}
	for slot in Items.SLOTS:
		game.player.equipment[slot] = Items.roll_item_of(slot, "S", rng, cls)
	game.player.recalc()
	if Items.count_set_pieces(game.player.equipment, cls) != 4:
		return _fail("full S set not detected as 4 pieces")
	if game.player.atk <= atk_bare:
		return _fail("full S set did not raise ATK")

	# Restore.
	game.player.equipment = keep_eq
	game.player.recalc()
	print("ok: set bonuses (piece count, cross-class isolation, 2/4 detection)")


# ---- CORE: account stash (deposit, withdraw, capacity) ------------------
func _test_stash() -> void:
	var keep_stash: Array = game.stash
	var keep_bag: Dictionary = game.player.bag
	var keep_bp: Array = game.player.backpack
	game.stash = []
	game._stash_loaded = true          # skip the real account file
	game.player.bag = Items.make_bag("S")  # 100 slots — room to withdraw into
	game.player.backpack = []

	# Deposit puts a payload into the stash.
	var it := Items.roll_item_of("charm", "C", game.loot_rng, game.player.cls)
	if not game.stash_deposit({"kind": "item", "item": it}):
		return _fail("stash_deposit failed with room to spare")
	if game.stash.size() != 1:
		return _fail("deposit did not land in the stash")

	# Withdraw moves it to the bag and clears it from the stash.
	if not game.stash_withdraw(game.stash[0]):
		return _fail("stash_withdraw failed with an empty bag")
	if game.stash.size() != 0 or game.player.backpack.size() != 1:
		return _fail("withdraw did not move the item back to the bag")

	# Capacity: a full stash rejects further deposits.
	game.stash = []
	for i in Balance.STASH_SLOTS:
		game.stash.append({"kind": "gem", "gem": Items.make_gem("crit", 1)})
	if game.stash_deposit({"kind": "item", "item": it}):
		return _fail("stash accepted a deposit past capacity")

	# Restore.
	game.stash = keep_stash
	game.player.bag = keep_bag
	game.player.backpack = keep_bp
	print("ok: account stash (deposit, withdraw to bag, capacity cap)")


# ---- CORE: localization string table (lookup, fallback, format, swap) ---
func _test_loc() -> void:
	var keep := Loc.lang
	Loc.lang = "en"
	if Loc.t("resume") != "Resume":
		return _fail("Loc.t did not return the English string")
	if Loc.t("__nope__") != "__nope__":
		return _fail("Loc.t did not fall back to the key for a missing entry")
	if Loc.t("gold_amount", [42]) != "42 gold":
		return _fail("Loc.t did not format positional args")
	# Language swap uses the active table, with per-key English fallback.
	Loc.lang = "es"
	if Loc.t("resume") != "Reanudar":
		return _fail("Loc.t did not use the active language")
	if Loc.t("stash") != String(Loc.STRINGS["en"]["stash"]):
		return _fail("Loc.t did not fall back to en for a key missing in es")
	Loc.lang = keep
	print("ok: localization (lookup, key fallback, format, language swap)")


# ---- CORE: utility consumables (mana, might elixir, recall) --------------
func _test_consumables() -> void:
	var p := game.player
	var keep_cons: Array = p.consumables.duplicate()
	var keep_mp: float = p.mp
	var keep_elix: float = p.elixir_time
	var keep_barrier: bool = game.barrier_active
	var keep_pos: Vector2 = p.global_position
	var keep_safe: int = game.last_safe_room
	p.consumables = []

	# Mana Draught restores mana and is consumed.
	p.mp = 0.0
	var mana := Items.make_mana_potion()
	p.consumables.append(mana)
	p.use_consumable(mana)
	if p.mp <= 0.0 or p.consumables.has(mana):
		return _fail("mana draught did not restore mana / wasn't consumed")

	# Elixir of Might raises current_atk while it holds.
	p.elixir_time = 0.0
	var atk0 := p.current_atk()
	var elix := Items.make_elixir_might()
	p.consumables.append(elix)
	p.use_consumable(elix)
	if p.elixir_time <= 0.0 or p.current_atk() <= atk0:
		return _fail("elixir of might did not buff damage")

	# Recall: refused mid-combat (scroll survives), allowed otherwise.
	var scroll := Items.make_recall_scroll()
	p.consumables.append(scroll)
	game.barrier_active = true
	p.use_consumable(scroll)
	if not p.consumables.has(scroll):
		return _fail("recall scroll consumed while doors were sealed")
	game.barrier_active = false
	game.last_safe_room = game.cur_room  # recall in place — no cross-room churn
	p.use_consumable(scroll)
	if p.consumables.has(scroll):
		return _fail("recall scroll not consumed out of combat")

	# Restore.
	p.consumables = keep_cons
	p.mp = keep_mp
	p.elixir_time = keep_elix
	game.barrier_active = keep_barrier
	game.last_safe_room = keep_safe
	p.global_position = keep_pos
	print("ok: consumables (mana draught, might elixir, recall scroll)")


# ---- CORE: gambling vendor (afford gate, cost deduction, delivery) -------
func _test_gamble() -> void:
	var p := game.player
	var keep_gold: int = p.gold
	var keep_bag: Dictionary = p.bag
	var keep_bp: Array = p.backpack
	p.bag = Items.make_bag("S")  # room to receive
	p.backpack = []

	# Can't afford -> nothing won, no gold spent.
	p.gold = 0
	if not game.gamble("silver").is_empty():
		return _fail("gamble paid out with no gold")
	if p.gold != 0:
		return _fail("gamble charged gold on a failed roll")

	# Afford -> an item is delivered and the cost is deducted.
	p.gold = 100000
	var cost := game.gamble_cost("silver")
	var won := game.gamble("silver")
	if won.is_empty():
		return _fail("gamble returned nothing despite gold + bag room")
	if p.gold != 100000 - cost:
		return _fail("gamble did not deduct exactly the cost")
	if p.backpack.size() != 1:
		return _fail("gamble did not add the item to the bag")

	# Restore.
	p.gold = keep_gold
	p.bag = keep_bag
	p.backpack = keep_bp
	print("ok: gamble vendor (afford gate, cost deduction, item delivered)")


# ---- CORE: equip / unequip (slot empties to bag, bag-full guard) ---------
func _test_equip_unequip() -> void:
	var p := game.player
	var keep_eq: Dictionary = p.equipment
	var keep_bp: Array = p.backpack
	var keep_cons: Array = p.consumables
	var keep_bag: Dictionary = p.bag
	p.bag = Items.make_bag("S")
	p.equipment = {}
	p.backpack = []
	p.consumables = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var w := Items.roll_item_of("weapon", "B", rng, p.cls)
	p.backpack.append(w)

	# Equip from bag -> slot filled, item left the bag.
	p.equip(w)
	if p.equipment.get("weapon") != w or p.backpack.has(w):
		return _fail("equip did not move the item from bag to slot")

	# Unequip -> slot empties, item back in bag.
	if not p.unequip("weapon"):
		return _fail("unequip failed with bag room")
	if p.equipment.has("weapon") or not p.backpack.has(w):
		return _fail("unequip did not empty the slot / return to bag")

	# Unequip is refused into a full bag (item stays worn).
	p.equip(w)
	while p.bag_used() < p.bag_capacity():
		p.consumables.append(Items.make_reset_stone())
	if p.unequip("weapon"):
		return _fail("unequip succeeded into a full bag")

	# Restore.
	p.equipment = keep_eq
	p.backpack = keep_bp
	p.consumables = keep_cons
	p.bag = keep_bag
	p.recalc()
	print("ok: equip / unequip (slot empties to bag, bag-full guard)")


func _test_retention() -> void:
	var g := game
	# Snapshot everything this section touches (autotest etiquette).
	var keep_run: Array = [g.run_time, g.run_deaths, g.run_elites, g.run_secrets]
	var keep_weekly: Array = [g.weekly_active, g.weekly_week]
	var keep_kc: Dictionary = g.kill_counts.duplicate()
	var keep_title: String = g.player_title
	var keep_ach: Dictionary = g.achievements.duplicate()

	# --- chapter grade: clean+thorough = S; sloppy sprint grades lower ---
	if Balance.chapter_grade(0, 1.0, 1.0) != "S":
		return _fail("perfect run did not grade S")
	if Balance.grade_rank("S") <= Balance.grade_rank(Balance.chapter_grade(3, 0.4, 0.0)):
		return _fail("grades do not order by play quality")

	# --- run stats -> results block -> account PB (in-memory when no_saves) ---
	g.run_time = 65.0
	g.run_deaths = 1
	g.run_elites = 2
	g.run_secrets = 1
	var res: Dictionary = g.run_results()
	if int(res["deaths"]) != 1 or String(res["grade"]) == "":
		return _fail("run_results dropped the counters")
	g.record_chapter_result(res)
	g.run_time = 42.0
	var pb2: Dictionary = g.record_chapter_result(g.run_results())
	if not bool(pb2["new_time"]):
		return _fail("a faster clear did not register as a new best")
	if absf(float(g.chapter_pb(g.chapter_id, g.player.cls).get("time", 0.0)) - 42.0) > 0.01:
		return _fail("chapter PB did not keep the fastest time")

	# --- weekly challenge: deterministic + fx only while live ---
	if g.weekly_seed() != g.weekly_seed():
		return _fail("weekly seed not deterministic")
	g.weekly_active = false
	if absf(g.weekly_fx("dmg") - 1.0) > 0.001:
		return _fail("weekly fx leaked outside a challenge run")
	g.weekly_active = true
	g.weekly_week = g._week_index()
	var mod: Dictionary = g.weekly_mod()
	for key in ["hp", "dmg", "speed", "gold", "elite"]:
		if mod.has(key) and absf(g.weekly_fx(key) - float(mod[key])) > 0.001:
			return _fail("weekly fx does not serve the live modifier")
	# A spawn rides the live modifier (compare against a clean spawn).
	var probe_on := _dummy(Vector2(150, 0))
	g.weekly_active = false
	var probe_off := _dummy(Vector2(180, 0))
	var want_hp: float = float(mod.get("hp", 1.0))
	if absf(probe_on.max_hp / probe_off.max_hp - want_hp) > 0.01:
		return _fail("weekly modifier did not ride the spawn (hp x%.2f expected)" % want_hp)

	# --- risk events: the curse buffs the pack once, never twice ---
	var cursed := _dummy(Vector2(210, 0))
	cursed.zone_idx = 0
	var dmg_before: float = cursed.dmg
	g._apply_room_curse(0)
	if absf(cursed.dmg - dmg_before * Balance.CURSE_DMG_MULT) > 0.01:
		return _fail("room curse did not buff the pack's damage")
	g._apply_room_curse(0)
	if absf(cursed.dmg - dmg_before * Balance.CURSE_DMG_MULT) > 0.01:
		return _fail("re-applying the curse double-buffed")
	cursed.zone_idx = -1  # hand the dummy back to _clear_combat
	_clear_combat()
	await _frames(2)

	# --- kill counts -> lore -> titles ---
	g.kill_counts = {}
	for i in Lore.threshold("wolf"):
		g.note_kill("wolf")
	if g.lore_unearthed() != 1:
		return _fail("the kill threshold did not unearth lore")
	if not g.title_available("wanderer"):
		return _fail("the free title is locked")
	if g.title_available("reaper"):
		return _fail("Reaper unlocked early")
	g.kill_counts["wolf"] = 500
	if not g.title_available("reaper"):
		return _fail("Reaper locked at 500 kills")
	g.achievements = {"flawless": true, "first_boss": true}
	if g.achievement_points() != 30:
		return _fail("achievement points miscounted (20 + default 10 expected)")
	if not g.title_available("untouchable"):
		return _fail("feat title locked despite the feat")
	g.player_title = "wanderer"
	if not Achievements.TITLES.has(g.player_title):
		return _fail("worn title missing from the registry")

	# --- loot fanfare: every grade has a chime; the beam call survives ---
	for grade in Items.GRADES:
		if not g.sounds.has(Items.loot_sound(grade)):
			return _fail("no loot chime for grade %s" % grade)
	g.loot_fanfare("S", g.player.global_position)  # beam + flash, no crash

	# --- reward calibration: gem quality chases the frontier ---
	if absf(Balance.gem_lv2_chance(5) - Balance.ELITE_GEM_LV2_CHANCE) > 0.001:
		return _fail("gem quality floor moved")
	if Balance.gem_lv2_chance(30) <= Balance.gem_lv2_chance(15):
		return _fail("gem quality does not climb with level")
	if Balance.gem_lv2_chance(99) > Balance.GEM_LV2_CAP + 0.001:
		return _fail("gem quality blew past its cap")

	# --- first-clear beat: gold in hand + a mailed spoils package ---
	var mail_before: int = g.mailbox.size()
	var gold_before2: int = g.player.gold
	g._first_clear_reward(12)
	if g.player.gold <= gold_before2:
		return _fail("first clear paid no gold")
	if g.mailbox.size() != mail_before + 1 or g.mailbox[-1]["items"].size() != 2:
		return _fail("first clear did not mail the spoils (item + gem)")
	g.player.gold = gold_before2
	g.mailbox.resize(mail_before)

	# --- gear stat doctrine (2026-07-06): special stats are gem-only ---
	var grng := RandomNumberGenerator.new()
	grng.seed = 99
	for i in 40:
		# F..A rolls (S legendaries keep their AUTHORED specials — the
		# sanctioned exception; the recalc caps guard the ceiling).
		var it2 := Items.roll_item_of(Items.SLOTS[i % 4], Items.GRADES[i % 6], grng,
			["warrior", "mage", "archer"][i % 3])
		for stat in Balance.SPECIAL_GEM_STATS:
			if it2["subs"].has(stat) or it2["main"].has(stat):
				return _fail("rolled gear carried special stat %s" % stat)
	if not Items.SLOT_MAIN["charm"].has("crit"):
		return _fail("charm main did not move to crit")

	# --- act loot ceilings: Act 1 clamps to B over authored caps ---
	if Story.act_of("ch1") != 1 or Story.act_of("ch7") != 1:
		return _fail("act_of misplaces Act 1 chapters")
	var keep_ch: String = g.chapter_id
	g.chapter_id = "ch3"   # authored cap A -> act clamp B
	var clamped: String = g.loot_cap()
	g.chapter_id = keep_ch
	if clamped != "B":
		return _fail("Act 1 loot cap did not clamp to B (got %s)" % clamped)
	if g.chapter_id == "ch1" and g.loot_cap() != "C":
		return _fail("ch1 authored C cap did not survive the clamp")

	# --- anti-degeneracy caps: no source stacks past them ---
	var keep_eq2: Dictionary = game.player.equipment
	game.player.equipment = {"charm": {"slot": "charm", "grade": "S", "name": "test",
		"noun": "Charm", "main": {}, "plus": 0, "gem_slots": 0, "gems": [],
		"subs": {"cdr": 0.9, "lifesteal": 0.9, "combo": 0.9}}}
	game.player.recalc()
	if game.player.cdr > Balance.CAP_CDR + 0.001 \
			or game.player.lifesteal > Balance.CAP_LIFESTEAL + 0.001 \
			or game.player.combo > Balance.CAP_COMBO + 0.001:
		return _fail("a special stat stacked past its cap")
	game.player.equipment = keep_eq2
	game.player.recalc()

	# --- one special gem per item ---
	var host := {"slot": "weapon", "grade": "S", "name": "t", "noun": "Blade",
		"main": {}, "subs": {}, "plus": 0, "gem_slots": 3, "gems": []}
	var g_ls := Items.make_gem("lifesteal", 1)
	var g_cb := Items.make_gem("combo", 1)
	var g_rb := Items.make_gem("atk_pct", 1)
	game.player.gem_bag.append_array([g_ls, g_cb, g_rb])
	if not game.player.embed_gem_into(host, g_ls):
		return _fail("first special gem was refused")
	if game.player.embed_gem_into(host, g_cb):
		return _fail("second special gem was accepted (one per item!)")
	if not game.player.embed_gem_into(host, g_rb):
		return _fail("a normal gem was refused by the special-gem rule")
	game.player.gem_bag.erase(g_cb)

	# --- boss gem-expectation ramp: bosses out-grow pure growth past L32 ---
	var nw_g: float = float(Story.ALL_ENEMIES["nullwarden"]["hp_g"]) * Balance.GROWTH_SCALE
	var hi_ratio: float = float(Story.enemy_stats_at("nullwarden", 50)["hp"]) \
		/ float(Story.enemy_stats_at("nullwarden", 49)["hp"])
	if hi_ratio <= 1.0 + nw_g:
		return _fail("boss gem ramp missing above L%d" % Balance.BOSS_GEM_RAMP_START)
	var low_ratio: float = float(Story.enemy_stats_at("nullwarden", 30)["hp"]) \
		/ float(Story.enemy_stats_at("nullwarden", 29)["hp"])
	if absf(low_ratio - (1.0 + nw_g)) > 0.001:
		return _fail("boss gem ramp leaked below its start level")

	# --- hidden caches: buried chest stays invisible, reveals near ---
	var hc := Chest.drop(g, "silver", g.player.global_position + Vector2(400, 0))
	hc.bury()
	if hc.visible or not hc.buried:
		return _fail("buried chest is not hidden")
	hc.global_position = g.player.global_position + Vector2(60, 0)
	await _frames(3)
	if hc.buried or not hc.visible:
		return _fail("buried chest did not glint awake near the player")
	hc.queue_free()
	await _frames(2)

	# Restore.
	g.run_time = keep_run[0]
	g.run_deaths = keep_run[1]
	g.run_elites = keep_run[2]
	g.run_secrets = keep_run[3]
	g.weekly_active = keep_weekly[0]
	g.weekly_week = keep_weekly[1]
	g.kill_counts = keep_kc
	g.player_title = keep_title
	g.achievements = keep_ach
	print("ok: retention pass (grades + PBs, weekly fx, lore titles, curse, fanfare)")


# ---- CONTENT: Chapter 3 bosses — the Unburied Vale (BOSSES.md) ----------
## Spawn, signature, per-boss phase mechanic, and story-neutral death
## for each ch3 boss (the module's own kill-flow selftest — runs in the
## ch2 hub the earlier hook sections booted into).
func _test_ch3_bosses() -> void:
	_buff()
	await _goto_room(0)
	await _frames(5)
	var err: String = await preload("res://scripts/content/ch3_bosses.gd").selftest(game)
	if err != "":
		_fail(err)
		# quit(1) lands at frame end; never resume, or _run would print
		# AUTOTEST PASS and quit(0) over the failure.
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch3 bosses (spawn / signature / phase / story-neutral death) — sexton, vess, saint_varo")


func _test_ch4_bosses() -> void:
	_buff()
	await _goto_room(0)
	await _frames(5)
	var err: String = await preload("res://scripts/content/ch4_bosses.gd").selftest(game)
	if err != "":
		_fail(err)
		# quit(1) lands at frame end; never resume, or _run would print
		# AUTOTEST PASS and quit(0) over the failure.
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch4 bosses (spawn / signature / phase / story-neutral death) — forgemistress, cinderhide, ashpriest")


func _test_ch5_bosses() -> void:
	_buff()
	await _goto_room(0)
	await _frames(5)
	var err: String = await preload("res://scripts/content/ch5_bosses.gd").selftest(game)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch5 bosses (spawn / signature / phase / story-neutral death) — whitepelt, icebound, sleepkeeper")


func _test_ch6_bosses() -> void:
	_buff()
	await _goto_room(0)
	await _frames(5)
	var err: String = await preload("res://scripts/content/ch6_bosses.gd").selftest(game)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch6 bosses (spawn / signature / phase / story-neutral death) — auroch, gardener, curetwisted")


func _test_ch7_bosses() -> void:
	_buff()
	await _goto_room(0)
	await _frames(5)
	var err: String = await preload("res://scripts/content/ch7_bosses.gd").selftest(game)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch7 bosses (spawn / signature / phase / story-neutral death) — veyx, echo, cyrraeth")


# ---- Act 1 back-half chapters (ch3-ch7): the shared spine walk ----------
# One walker for all five: boot the chapter, integrity-check every zone
# (enemy kinds resolve, npc convos exist, boss quests exist), run the
# camp briefing (gate + first quest), then walk the spine killing packs
# and bosses through to the victory card. Returns "" or a failure text.
func _walk_act1_chapter(chid: String, briefing_prompt: String, gate_flag: String,
		want_zones: int) -> String:
	game.replay_chapter(chid)
	await _frames(10)
	if game.chapter_id != chid:
		return "%s did not boot" % chid
	if game.zone_count != want_zones:
		return "%s zones did not append (zones=%d, want %d)" % [chid, game.zone_count, want_zones]
	# Structural integrity: every authored reference must resolve.
	for zi in game.zone_count:
		var zone: Dictionary = game.zones[zi]
		for spawn in zone.get("enemies", []):
			if not Story.ALL_ENEMIES.has(spawn[0]):
				return "%s room %d: unknown enemy kind '%s'" % [chid, zi, spawn[0]]
		for npc in zone.get("npcs", []):
			if not Story.ALL_CONVOS.has(npc["convo"]):
				return "%s room %d: unknown convo '%s'" % [chid, zi, npc["convo"]]
		var bkind := String(zone.get("boss", ""))
		if bkind != "":
			if not Story.ALL_ENEMIES.has(bkind):
				return "%s room %d: unknown boss '%s'" % [chid, zi, bkind]
			if not Story.ALL_QUESTS.has(bkind):
				return "%s: boss '%s' has no quest line" % [chid, bkind]
	for w in Story.wanderers_for(chid):
		if not Story.ALL_CONVOS.has(w["convo"]):
			return "%s wanderer convo '%s' missing" % [chid, w["convo"]]
	_buff()
	# The camp briefing opens the gate and points the quest at boss #1.
	var brief := _find_action(briefing_prompt)
	if not brief.is_valid():
		return "%s briefing NPC missing ('%s')" % [chid, briefing_prompt]
	brief.call()
	await _frames(2)
	await _skip_dialogue()
	await _frames(2)
	if game.hud.choices_active:
		game.hud._choose(0)
		await _frames(2)
		await _skip_dialogue()
	if not game.get_flag(gate_flag, false):
		return "%s briefing did not set %s" % [chid, gate_flag]
	if not game._edge_unlocked(0, game.neighbor(0, game.rooms[0]["exits"].keys()[0])):
		return "%s camp gate did not open on the briefing" % chid
	# Walk the spine: purge packs, meet each boss at its authored level.
	var spine: Array = Story.chapter(chid)["spine"]
	for si in range(1, spine.size()):
		var zi := int(spine[si])
		await _goto_room(zi)
		await _kill_room(zi)
		var bkind := String(game.zones[zi].get("boss", ""))
		if bkind == "":
			continue
		var guard := 0
		while not is_instance_valid(game.current_boss) and guard < 200:
			await _frames(5)
			guard += 5
			if game.hud.dialogue_active:
				await _skip_dialogue()
		if not is_instance_valid(game.current_boss) or game.current_boss.kind != bkind:
			return "%s: boss '%s' did not spawn in room %d" % [chid, bkind, zi]
		if game.current_boss.level != int(game.zones[zi].get("boss_level", -1)):
			return "%s: %s not story-scaled (level %d)" % [chid, bkind, game.current_boss.level]
		# Kaethra's fight ENDS at 10%: the strike-or-sheathe convo is the
		# killing blow — exercise the real flow instead of a one-shot.
		if bkind == "curetwisted":
			game.current_boss.take_damage(game.current_boss.max_hp * 0.95, Vector2.ZERO, false, true)
			var cguard := 0
			while not game.hud.choices_active and cguard < 200:
				await _frames(5)
				cguard += 5
				if game.hud.dialogue_active and not game.hud.choices_active:
					game.hud._advance_dialogue()
			if not game.hud.choices_active:
				return "ch6: Kaethra's ending offered no choice"
			game.hud._choose(0)
			await _frames(2)
			await _skip_dialogue()
		else:
			game.current_boss.take_damage(99999999.0)
		# Final boss -> victory card; mid boss -> quest advances.
		if bkind == String(Story.chapter(chid).get("final_boss", "")):
			var vguard := 0
			while game.state != Game.ST_VICTORY and vguard < 200:
				if game.hud.dialogue_active:
					await _skip_dialogue()
				await _frames(5)
				vguard += 5
			if game.state != Game.ST_VICTORY:
				return "%s did not reach victory" % chid
			if game.quest_key != "done_" + chid:
				return "%s done quest wrong (got %s)" % [chid, game.quest_key]
			get_tree().paused = false
			game.state = Game.ST_PLAYING
			await _goto_room(0)
			await _frames(5)
		else:
			await _frames(10)
			if game.hud.dialogue_active:
				await _skip_dialogue()
			await _frames(5)
	return ""


func _test_ch3_chapter() -> void:
	var err: String = await _walk_act1_chapter("ch3", "E — Cantor Ilse", "ch3_briefed", 21)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch3 chapter (Vale spine end-to-end — briefing, packs, sexton/vess/varo, victory)")


func _test_ch4_chapter() -> void:
	var err: String = await _walk_act1_chapter("ch4", "E — Overseer Brann", "ch4_briefed", 21)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch4 chapter (Slagfields spine end-to-end — calda/cinderhide/ordo, victory)")


func _test_ch5_chapter() -> void:
	var err: String = await _walk_act1_chapter("ch5", "E — Tracker Yri", "ch5_briefed", 21)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch5 chapter (Long Sleep spine end-to-end — whitepelt/serane/halla, victory)")


func _test_ch6_chapter() -> void:
	var err: String = await _walk_act1_chapter("ch6", "E — Deacon Vela", "ch6_briefed", 21)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	# The strike-or-sheathe must have landed its flag (choice 0 = sheathe).
	if not game.get_flag("chose_kaethra_sheathed", false):
		_fail("ch6: Kaethra's ending did not set its choice flag")
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch6 chapter (Blooming Deep spine — auroch/rotmaw/kaethra strike-or-sheathe, victory)")


func _test_ch7_chapter() -> void:
	var err: String = await _walk_act1_chapter("ch7", "E — Elder Maren", "ch7_briefed", 21)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: ch7 chapter (Breaking Sky spine — veyx/echo/cyrraeth, ACT 1 COMPLETE)")
