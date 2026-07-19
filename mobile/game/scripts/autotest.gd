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
	if Stats.crit_curve(0.9) > 0.5 or Stats.crit_curve(0.3) != 0.3:
		return _fail("crit curve broken")  # knee at 35% (2026-07-06)
	var r := Stats.resolve(100.0, "true", 0.0, 1.5, 0.0, 0.0, 500.0, 0.9, 50.0)
	if r["miss"] or r["dmg"] != 100.0 or r["crit"]:
		return _fail("true damage should ignore everything and never crit")
	# 0b. DEX-vs-evasion GRADIENT (2026-07-17): the target rolls its own
	# evasion and the attacker's DEX tier decides what that evade costs —
	# full miss / graze / cancelled. The tier boundaries are deterministic
	# (that's the whole point: an evasive fight is a build state you can
	# read, never a dice roll), so they assert exactly.
	var parity: float = 0.30 / Balance.DEX_PER_EVA   # 75 DEX answers 30% evasion
	if Stats.dex_tier(0.0, 0.30) != 0:
		return _fail("no DEX vs evasion must be tier 0 (full miss)")
	if Stats.dex_tier(parity * 0.6, 0.30) != 1:
		return _fail("DEX past the graze ratio must be tier 1 (graze)")
	if Stats.dex_tier(parity, 0.30) != 2:
		return _fail("parity DEX must CANCEL evasion (tier 2)")
	if Stats.dex_tier(0.0, 0.0) != 2:
		return _fail("zero evasion has nothing to answer — tier 2")
	# Tier 2 never rolls at all: a parity build cannot be dodged, ever.
	for _i in 200:
		var t2 := Stats.resolve(100.0, "phys", 0.0, 1.5, 0.0, parity, 0.0, 0.30, 0.0)
		if t2["miss"] or t2["graze"]:
			return _fail("parity DEX still lost a hit to evasion")
	# Tier 1 never MISSES — it grazes, and a graze pays exactly GRAZE_DAMAGE.
	var saw_graze := false
	for _i in 400:
		var t1 := Stats.resolve(100.0, "phys", 0.0, 1.5, 0.0, parity * 0.6, 0.0, 0.30, 0.0)
		if t1["miss"]:
			return _fail("the graze tier must never MISS outright")
		if t1["graze"]:
			saw_graze = true
			if absf(float(t1["dmg"]) - 100.0 * Balance.GRAZE_DAMAGE) > 0.01:
				return _fail("a graze must pay exactly GRAZE_DAMAGE")
	if not saw_graze:
		return _fail("the graze tier never grazed across 400 rolls")
	# Tier 0 CAN erase a hit outright — the wall that asks for DEX.
	var saw_miss := false
	for _i in 400:
		if Stats.resolve(100.0, "phys", 0.0, 1.5, 0.0, 0.0, 0.0, 0.30, 0.0)["miss"]:
			saw_miss = true
			break
	if not saw_miss:
		return _fail("tier 0 never missed across 400 rolls vs 30% evasion")
	print("ok: DEX vs evasion gradient (miss / graze / cancelled tiers)")
	# Pacing retrofit + presence pass: mobs live ~2x longer (TTK) AND the
	# 2026-07-07 mob HP mult stacks on top; bosses get neither.
	var wolf_now := Story.enemy_stats_at("wolf", 2)
	if absf(wolf_now["hp"] / Story.ALL_ENEMIES["wolf"]["hp"] - Balance.TTK_HP_MULT * Balance.MOB_HP_MULT) > 0.01:
		return _fail("mob TTK/presence multiplier not applied")
	var fang_now := Story.enemy_stats_at("fangmaw", 4)
	if absf(fang_now["hp"] - Story.ALL_ENEMIES["fangmaw"]["hp"]) > 0.01:
		return _fail("boss HP should not get the mob TTK multiplier")
	# Chapter loot bands: a general roll never leaves the chapter's table.
	var caprng := RandomNumberGenerator.new()
	caprng.seed = 7
	for i in 60:
		var g1: String = Items.roll_chapter_gear("ch1", caprng)["grade"]
		if g1 != "F":
			return _fail("ch1 general roll left its F-only band (got %s)" % g1)
		if not Balance.gear_weights("ch5").has(Items.roll_chapter_gear("ch5", caprng)["grade"]):
			return _fail("ch5 general roll left its D/C/B band")
	# Level scaling is exponential: at the listed level nothing changes,
	# but a monster 10 levels up is a WALL of raw stats (no hidden rule).
	var v_at := Story.enemy_stats_at("vargoth", 10)
	var v_up := Story.enemy_stats_at("vargoth", 20)
	if absf(v_at["dmg"] - Story.ALL_ENEMIES["vargoth"]["dmg"] * Balance.ENEMY_DMG_MULT * Balance.BOSS_DMG_MULT) > 0.01:
		return _fail("at-anchor boss dmg must be base x ENEMY_DMG_MULT x BOSS_DMG_MULT")
	# Endgame-scaling pass (2026-07-09): boss growth now TRACKS THE PLAYER CURVE
	# so a scaled boss stays at PARITY with a same-level player — HP on
	# BOSS_HP_GROWTH (player DPS), dmg on BOSS_DMG_GROWTH (player EHP). +10 is a
	# gentle ~1.2x, NOT the old 1.7x "wall" that compounded into L100 one-shots.
	# Under-level difficulty comes from the PLAYER being weak; an intentional +N
	# (Nightmare) would be a SEPARATE explicit multiplier, not this growth.
	var exp_dmg: float = pow(1.0 + Balance.BOSS_DMG_GROWTH, 10)
	var exp_hp: float = pow(1.0 + Balance.BOSS_HP_GROWTH, 10)
	if absf(v_up["dmg"] / v_at["dmg"] - exp_dmg) > 0.03 or absf(v_up["hp"] / v_at["hp"] - exp_hp) > 0.03:
		return _fail("+10 boss growth should track the player curve (gentle, at-parity)")
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
	# The dialogue box lives UNDER the hud: if the menus left the hud hidden,
	# the opening plays invisibly and the game looks frozen (2fa0c82 regression).
	if not game.hud.visible:
		return _fail("opening dialogue is playing on a hidden HUD")
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

	# 3d. Wind Cuts (mage Wind talent): homing is now BASELINE wind behavior;
	# the talent instead opens a bleed — but ONLY on the wind firebolt. Verify
	# the stat wires up, the bleed rides only the wind bolt (both twins), and
	# the enemy-side DoT bites over time and REFRESHES (never stacks).
	game.player.set_class("mage")
	game.player.themes_known = 3
	game.player.tree_points = {"m02": 5}   # 5 pts -> 5 * 0.025 = 0.125 (2026-07-09 relevance buff)
	game.player.recalc()
	if absf(game.player.bolt_bleed - 0.125) > 1.0e-6:
		return _fail("Wind Cuts: 5 pts should give 0.125 bolt_bleed (got %f)" % game.player.bolt_bleed)
	game.player.facing = Vector2.RIGHT
	# Fire variant must NOT carry a bleed.
	_clear_combat()
	game.player.set_all_themes("fire")
	game.player.mp = game.player.max_mp
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await get_tree().create_timer(Balance.MAGE_BOLT_DELAY + 0.08).timeout  # bolt release frame
	var fire_bolts := 0
	for pr in get_tree().get_nodes_in_group("projectiles"):
		fire_bolts += 1
		if float(pr.fx.get("bleed", 0.0)) > 0.0:
			return _fail("Wind Cuts leaked onto the FIRE firebolt")
	if fire_bolts == 0:
		return _fail("fire firebolt never spawned (bolt-release delay?)")
	# Wind variant MUST carry a bleed on BOTH twin bolts.
	_clear_combat()
	game.player.set_all_themes("wind")
	game.player.mp = game.player.max_mp
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await get_tree().create_timer(Balance.MAGE_BOLT_DELAY + 0.08).timeout  # bolts
	# release on the cast-thrust frame now, not the input frame (wall-clock: frames race headless)
	var wind_bleeders := 0
	for pr in get_tree().get_nodes_in_group("projectiles"):
		if float(pr.fx.get("bleed", 0.0)) > 0.0:
			wind_bleeders += 1
	if wind_bleeders < 2:
		return _fail("Wind Cuts: both twin wind bolts should bleed (got %d)" % wind_bleeders)
	# Enemy-side DoT: it bites over time, and a weaker re-hit refreshes (maxf).
	var bd := _dummy(Vector2(320, 0))
	bd.hp = 100000.0
	bd.apply_bleed(200.0, 3.0)
	if bd.bleed_time <= 0.0:
		return _fail("apply_bleed did not open a wound")
	var bhp0 := bd.hp
	await get_tree().create_timer(0.6).timeout  # wall-clock: let a tick land
	if bd.hp >= bhp0:
		return _fail("bleed dealt no damage over time")
	bd.apply_bleed(10.0, 3.0)  # weaker re-hit
	if bd.bleed_dps < 200.0 or bd.bleed_time > 3.01:
		return _fail("bleed must REFRESH not stack (dps %.1f, time %.2f)" % [bd.bleed_dps, bd.bleed_time])
	_clear_combat()
	game.player.tree_points = {}
	game.player.recalc()
	print("ok: mage Wind Cuts (wind-only bleed, bites + refreshes)")

	# Assassin STAB SURGE (round 25): a connecting cut buffs lifesteal,
	# bigger the lower your health sits.
	game.player.set_class("assassin")
	game.player.pending_theme_note = ""
	var surge_dummy := _dummy(Vector2(50, 0))
	await _frames(2)
	game.player.hp = game.player.max_hp * 0.3
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	# The stab's cut lands at the lunge frame now, not the input frame.
	await get_tree().create_timer(Balance.STAB_STRIKE_DELAY + 0.06).timeout
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
	# Let the cadence-test fan's DELAYED knives (throw-release) spawn before
	# the clear below, or they leak (surged) into the base measurement.
	await get_tree().create_timer(Balance.KNIFE_THROW_RELEASE + 0.06).timeout
	# Earned knives (round 37): unsurged darts chip thin; during the
	# surge window the SAME cast bites double. Assert the ratio via the
	# projectiles' damage mult (immune to talent/gear multipliers).
	for stale in get_tree().get_nodes_in_group("projectiles"):
		stale.queue_free()
	await _frames(1)
	game.player.stab_ls_time = 0.0
	game.player.cds["a3"] = 0.0
	game.player.use_ability("a3")
	# Knives leave at the throw anim's release now, not the input frame —
	# wait it out (wall-clock; frames race ahead headless).
	await get_tree().create_timer(Balance.KNIFE_THROW_RELEASE + 0.06).timeout
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
	await get_tree().create_timer(Balance.KNIFE_THROW_RELEASE + 0.06).timeout
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
	# Ability scaling reads from the single-source dmg data (drives the selector).
	if Classes.ability_scaling("warrior", "a1") != "Physical · 100% ATK":
		return _fail("ability_scaling(warrior a1) = '%s'" % Classes.ability_scaling("warrior", "a1"))
	if Classes.ability_scaling("assassin", "ult") != "True · 130% ATK":
		return _fail("ability_scaling must honor the per-ability type override")
	if Classes.ability_scaling("warrior", "ult") != "":
		return _fail("a buff (Berserk) must produce no scaling line")
	# Rider line is generated from the single-source riders data (the same numbers
	# the kit/recalc read — no drift). Blink's DR and Death Mark's amp must appear.
	if not Classes.ability_riders("mage", "a3").contains("50% DR 0.8s"):
		return _fail("Blink riders should generate '50% DR 0.8s' from data: %s" % Classes.ability_riders("mage", "a3"))
	if not Classes.ability_riders("assassin", "ult").contains("+50% dmg taken"):
		return _fail("Death Mark riders should surface the +50%% amp")
	# The base-damage knob is dormant — every ability's base is 0 today, so the
	# refactor is a pure no-op (change one to tune a class later).
	for _sc in Classes.CLASSES:
		for _ss in ["a1", "a2", "a3", "ult"]:
			if float(Classes.CLASSES[_sc]["abilities"][_ss].get("dmg", {}).get("base", 0.0)) != 0.0:
				return _fail("ability base must be 0 (dormant): %s %s" % [_sc, _ss])
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

	# 3a2. Directional dash (player-reported 2026-07-09): a dash follows the
	# HELD move keys — down+dash goes DOWN — and the flat L/R dash art spins
	# to the travel line. No keys held keeps the old straight-ahead dash.
	await _test_dash_direction()

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
	await get_tree().create_timer(Balance.WARRIOR_SWING_DELAY + 0.06).timeout  # cut
	# lands on the swing's contact frame now (wall-clock: frames race headless)
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
	await get_tree().create_timer(Balance.PALADIN_SMITE_DELAY + 0.12).timeout  # nova
	# lands on the warhammer's slam frame now (wall-clock: frames race headless)
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
	await get_tree().create_timer(Balance.WARLOCK_CAST_DELAY + 0.06).timeout  # curse
	# lands on the sigil-projection frame now (wall-clock: frames race headless)
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

	# 3d. COMBO stat: the proc rate IS the stat (the anti-degeneracy knee
	# lives in recalc, 30% + 1/10 beyond — 2026-07-06). At 60% combo,
	# ~60% of casts skip the cooldown.
	var resets := 0
	for i in 200:
		game.player.combo = 0.6  # re-assert: recalc() from a stray level-up would reset it
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
	# Bosses now scale on the player-tracking BOSS_HP_GROWTH (2026-07-09) —
	# deliberately GENTLER per-level than trash's per-kind growth, but their huge
	# authored base keeps them far tankier than trash in absolute terms at level.
	if boss_hi["hp"] <= w_hi["hp"]:
		return _fail("a boss should out-HP trash at the same level")
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

	# 3d13b. Resonance band leans: conviction ramp, Hunger/Constancy sides.
	_test_res_lean()

	# 3d13c. Gold Rush: greed surge window + charged-coin touch trigger.
	await _test_goldrush()

	# 3d14. Gamble vendor: afford gate, cost deduction, boss-band roll + pricing.
	_test_gamble()

	# 3d14b. Merchant economy (round 50): level-scaled price ladder, gem +
	# consumable sell (incl. quest-item unsellable guard), ward/renewal elixirs.
	_test_merchant_economy()

	# 3d15. Equip / unequip: slot empties back to the bag, bag-full guard.
	_test_equip_unequip()

	# 3d15b. Stacking bags (round 52): sum-capacity, keep-best-5, act-tiered
	# drops, shop pricing, discard-throw, save round-trip + old-save migration.
	await _test_bags_discard()

	# 3d16. Retention pass: chapter grades + PBs, weekly challenge fx,
	# kill-count lore + titles, risk-event curse, loot fanfare bank.
	await _test_retention()

	# 3d17. Mob presence + identity traits (HP/dmg mults, self-heal,
	# healer pulse, lunge, frenzy damage).
	await _test_mob_traits()

	# 3d18. Environment asset seams (2026-07-18): ground PNG tilesets,
	# composite structures + wall decals, animated scenery props.
	await _test_asset_seams()

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
	var clay := Items.roll_item_of("weapon", "C", wrng, "warrior", "Claymore")
	var fang := Items.roll_item_of("weapon", "C", wrng, "assassin", "Fang")
	# Mains are class attributes now (2026-07-06): shape mults still order
	# the BUDGET (Claymore 1.4x > Fang 0.85x), just in attribute points.
	if clay["main"]["STR"] <= fang["main"]["AGI"]:
		return _fail("Claymore does not out-budget Fang")
	if not fang["subs"].has("crit"):
		return _fail("Fang has no guaranteed crit substat")
	print("ok: weapon shape identities")

	# Class-aware drops (round 15): a class only loots weapons from its own
	# arsenal. The pen half was NARROWED 2026-07-17 — only an S legendary's
	# FIRST roll is guaranteed class-usable; every lesser grade rolls the full
	# pool (a rune can reroute damage type, so the off-type pen is dormant, not
	# dead). Both pen checks below roll "S" and so still hold; the un-gate for
	# lesser grades is asserted in _test_reforge.
	var crng := RandomNumberGenerator.new()
	crng.seed = 42
	for i in 30:
		var aw := Items.roll_item_of("weapon", "A", crng, "archer")
		if not (aw["noun"] in Items.CLASS_WEAPONS["archer"]):
			return _fail("archer looted a %s (not in the archer arsenal)" % aw["noun"])
		var ai := Items.roll_item_of(Items.SLOTS[i % 4], "S", crng, "archer")
		if ai["subs"].has("magpen"):
			return _fail("an S archer first roll carried MagPen (off-type pen)")
		var mi := Items.roll_item_of(Items.SLOTS[i % 4], "S", crng, "mage")
		if mi["subs"].has("physpen"):
			return _fail("an S mage first roll carried PhysPen (off-type pen)")
		# Endgame-only stats (round 43): nothing below B may carry
		# lifesteal or combo — including shape personality stats
		# (the Wand's built-in combo, the Tome's lifesteal).
		var low := Items.roll_item_of(Items.SLOTS[i % 4], ["F", "E", "D", "C"][i % 4], crng)
		var wand_low := Items.roll_item_of("weapon", "C", crng, "", "Wand")
		if low["subs"].has("lifesteal") or low["subs"].has("combo") \
				or wand_low["subs"].has("combo") or wand_low["subs"].has("lifesteal"):
			return _fail("sub-B gear rolled an endgame-only stat (lifesteal/combo)")
	print("ok: class-aware drops (arsenal + S first-roll pen guarantee + B-gated lifesteal/combo)")

	# 4b. S weapon: legendary shape + 3 sockets; its passive is DORMANT
	# (round 51b) until the class's awakening flag is set. Wrong-class flag
	# never wakes it; describe() reflects locked vs active.
	var srng := RandomNumberGenerator.new()
	srng.seed = 7
	var s_wpn := Items.roll_item_of("weapon", "S", srng, "warrior")
	if s_wpn.get("passive", "") != "kingsblade" or s_wpn.get("cls", "") != "warrior":
		return _fail("S warrior weapon wrong passive/class")
	if not s_wpn.get("passive_dormant", false):
		return _fail("a dropped S weapon must stamp passive_dormant")
	if s_wpn.get("gem_slots", 0) != 3:
		return _fail("S gear should have 3 gem slots")
	var keep_flags: Dictionary = game.flags.duplicate(true)
	game.set_flag("s_awakened_warrior", false)
	game.set_flag("s_awakened_archer", false)
	game.player.add_item(s_wpn)
	game.player.equip(s_wpn)
	if game.player.s_passive() != "":
		return _fail("dormant S passive fired without awakening")
	game.set_flag("s_awakened_archer")  # wrong class
	if game.player.s_passive() != "":
		return _fail("wrong-class awakening woke a warrior legendary")
	if not Items.describe(s_wpn, false).contains("LOCKED"):
		return _fail("describe should show LOCKED for a dormant legendary")
	game.set_flag("s_awakened_warrior")  # right class
	if game.player.s_passive() != "kingsblade":
		return _fail("s_passive not active after awakening the class")
	if Items.describe(s_wpn, true).contains("LOCKED"):
		return _fail("describe still LOCKED after awakening")
	game.player.cds["a1"] = 0.0
	game.player.use_ability("a1")
	await _frames(15)
	game.flags = keep_flags
	print("ok: S weapon dormant passive + awakening (%s sleeps until s_awakened_warrior)" % s_wpn["name"])

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
	game.menus.open_inventory()  # the bench popover overlays the open inventory
	await _frames(1)
	game.menus.open_item_panel(s_wpn)
	await _frames(2)
	if game.menus.current != "detail":
		return _fail("item panel popover did not open")
	# All three subtabs build (Info/Gems/Reforge, 2026-07-09) — Gems renders
	# the real socket squares around the crit gem socketed above.
	game.menus.open_item_panel(s_wpn, Vector2(-1, -1), "gems")
	await _frames(2)
	game.menus.open_item_panel(s_wpn, Vector2(-1, -1), "reforge")
	await _frames(2)
	if game.menus.current != "detail":
		return _fail("item panel subtabs did not build")
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

	# 4d. Telegraph resolves — and it lands HEAVY (2026-07-09): a chip-armed
	# hurt_cd gate must not eat the telegraphed nuke (the old cheese: tank a
	# graze right before the blast and stand in the circle for free).
	var eva_save: float = game.player.eva
	game.player.eva = 0.0        # deterministic: no dodge rolls in these asserts
	game.player.shield = 0.0
	game.player.hp = game.player.max_hp
	game.player.hurt_cd = 0.0
	game.telegraph(game.player.global_position + Vector2(40, 0), 60.0, 0.3, 50.0, {"sword": true})
	game.player.take_damage(1.0, "phys")  # chip: arms the gate ahead of the blast
	if game.player.hurt_cd <= 0.0:
		return _fail("chip hit did not arm the hurt gate")
	var tele_hp: float = game.player.hp
	# Wall-clock wait: the telegraph resolves on a 0.3s timer while the 0.6s
	# chip gate is still armed — the heavy blast must pierce it.
	await get_tree().create_timer(0.45).timeout
	await _frames(2)
	if game.player.hp >= tele_hp:
		return _fail("telegraph nuke was eaten by a chip-armed hurt gate")
	# Gate semantics: chip blocked by ANY armed gate; heavy pierces a
	# chip-armed gate but is blocked by a heavy-armed one (no double-taps).
	game.player.hurt_cd = 0.0
	game.player.take_damage(1.0, "phys")
	var gate_hp: float = game.player.hp
	game.player.take_damage(1.0, "phys")               # chip vs chip gate: blocked
	if game.player.hp < gate_hp:
		return _fail("chip hit pierced the hurt gate")
	game.player.take_damage(5.0, "magic", null, true)  # heavy vs chip gate: pierces
	if game.player.hp >= gate_hp:
		return _fail("heavy hit did not pierce a chip-armed gate")
	var heavy_hp: float = game.player.hp
	game.player.take_damage(5.0, "magic", null, true)  # heavy vs heavy gate: blocked
	if game.player.hp < heavy_hp:
		return _fail("overlapping heavy hits double-tapped through the gate")
	game.player.eva = eva_save
	game.player.hurt_cd = 0.0
	game.player.hurt_was_heavy = false
	game.player.hp = game.player.max_hp
	await _frames(20)  # let the falling-sword fx finish
	print("ok: telegraph + falling sword (heavy pierces chip gate, not heavy gate)")

	# 5. Skill tree: row caps and gating. Drive it at a controlled level so
	# the assertions don't depend on how far ch1 leveled us (rows now unlock
	# at 10/20/30/40). Restore level + points afterward.
	var saved_level: int = game.player.level
	game.player.level = Skills.ROW_LEVELS[2]  # rows 0-2 open, row 3 (Lv 40) locked
	game.player.tree_points.clear()
	game.player.skill_points = 30
	var added := 0
	for i in 12:  # try to overfill row 0 (cell cap AND row cap are both 10)
		if game.player.add_tree_point("w00"):
			added += 1
	if added != Skills.MAX_PER_CELL:
		return _fail("cell cap should stop at %d (got %d)" % [Skills.MAX_PER_CELL, added])
	if game.player.add_tree_point("w01"):
		return _fail("row cap should block an 11th point in row 0")
	if game.player.dm("a1") < 1.24:
		return _fail("10 points in Heavy Cleave should give +25%")
	var high_row := Skills.TREES["warrior"][3][0]["id"]
	if game.player.add_tree_point(high_row):
		return _fail("locked row (Lv 40) accepted a point at Lv %d" % game.player.level)
	game.player.tree_points.clear()
	game.player.skill_points = 0
	game.player.level = saved_level
	game.player.recalc()
	print("ok: skill tree rows (caps + gating)")

	# 5a2. Auto-synthesize: socketed gems level first, then the bag rolls up.
	var socketed_item: Dictionary = game.player.equipment["weapon"]
	socketed_item["gems"].clear()
	game.player.gem_bag.clear()
	game.player.gem_bag.append(Items.make_gem("atk_flat", 1))
	if not game.player.embed_gem_into(socketed_item, game.player.gem_bag[0]):
		return _fail("could not socket the auto-synth test gem")
	for i in 11:
		game.player.gem_bag.append(Items.make_gem("atk_flat", 1))
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
	p.char_name = "Rowan"
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
	p.char_name = ""
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
	if p.char_name != "Rowan":
		return _fail("save did not restore character name (got '%s')" % p.char_name)
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
	print("ok: save/load roundtrip (name, gold, resonance, factions, gear, room state)")

	# 5b1. Session-local name de-dup: colliding party names get a display-only
	# "#N" suffix (case-insensitive), host/earlier ids keep the bare name.
	var NetSess := preload("res://scripts/net/net_session.gd")
	var dd: Dictionary = NetSess.dedup_roster({
		1: {"name": "Rowan"}, 4: {"name": "rowan"}, 7: {"name": "Bex"}, 9: {"name": "Rowan"}})
	if String(dd[1]["name"]) != "Rowan" or String(dd[4]["name"]) != "rowan #2" \
			or String(dd[7]["name"]) != "Bex" or String(dd[9]["name"]) != "Rowan #3":
		return _fail("name de-dup wrong: %s" % str([dd[1]["name"], dd[4]["name"], dd[7]["name"], dd[9]["name"]]))
	print("ok: session-local name de-dup (#N on collision, case-insensitive)")

	# 5b2. Chroma + skin system.
	var p_sk: Player = game.player
	var old_chroma: String = p_sk.chroma
	p_sk.set_chroma("obsidian")
	if p_sk.chroma != "obsidian":
		return _fail("set_chroma did not store the id")
	var mat_ck: ShaderMaterial = p_sk.sprite.material as ShaderMaterial
	if mat_ck == null:
		return _fail("chroma did not assign a ShaderMaterial to the sprite")
	if mat_ck.shader == null:
		return _fail("chroma ShaderMaterial has no shader")
	var active_val: float = mat_ck.get_shader_parameter("chroma_active")
	if active_val < 0.5:
		return _fail("chroma_active uniform is %.1f (should be 1.0)" % active_val)
	p_sk.set_chroma("")
	if p_sk.chroma != "" or mat_ck.get_shader_parameter("chroma_active") > 0.5:
		return _fail("clearing chroma failed")
	p_sk.chroma = old_chroma
	print("ok: chroma shader (apply, uniforms, clear)")

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
			# A choice must be a CHOICE (2026-07-09): a node whose ONLY
			# choice carries no effects (nothing beyond text/next) is a fake
			# decision — author it as a plain linear node instead. Single
			# choices WITH effects (flags/resonance/req_*/items/...) are
			# tolerated: the engine can't apply those on a linear advance,
			# so they wait on an authoring pass, not a mechanical one.
			var only_choices: Array = node2.get("choices", [])
			if only_choices.size() == 1:
				var oc: Dictionary = only_choices[0]
				var effect_free := true
				for ock in oc:
					if not (String(ock) in ["text", "next"]):
						effect_free = false
						break
				if effect_free:
					return _fail("%s/%s: single effect-free choice — fake decision, make it linear" % [cid, nid])
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
	# Inventory must survive a gem hoard (compact grid + capped scroll) —
	# and render the virtual health-potion stacks (2026-07-09 v2: potions
	# take bag slots and show as clickable stack entries).
	for i in 40:
		game.player.gem_bag.append(Items.random_gem(game.loot_rng, 1 + (i % 5)))
	var keep_pot2: int = game.player.potions
	game.player.potions = 2
	game.menus.open_inventory()
	await _frames(2)
	if not game.menus.is_open():
		return _fail("inventory did not open with a 40-gem bag")
	game.menus.close()
	game.player.gem_bag.clear()
	game.player.potions = keep_pot2
	await _frames(1)
	game.menus.open_shop(0)
	await _frames(2)
	if not game.menus.is_open() or game.shop_stock[0].size() != 3:
		return _fail("shop did not open with stock")
	# The Sell tab builds too (full-width Buy/Sell tabs, 2026-07-09).
	game.menus.open_shop(0, "sell")
	await _frames(2)
	if not game.menus.is_open() or game.menus.shop_tab != "sell":
		return _fail("shop sell tab did not open")
	game.menus.shop_tab = "buy"  # restore the default for later shop opens
	game.menus.open_codex("gear")
	await _frames(2)
	game.menus.open_codex("terrains")
	await _frames(2)
	var _dev0: bool = game.dev_mode
	game.dev_mode = true  # bestiary stays placeholder-free even in dev (2026-07-18)
	game.menus.open_codex("monsters")
	await _frames(2)
	game.menus.open_codex("bosses")
	await _frames(2)
	game.menus.open_codex("npcs")
	await _frames(2)
	# The Future bestiary shelves (unplaced mobs/bosses + review NPCs).
	game.menus.open_codex("future_mobs")
	await _frames(2)
	game.menus.open_codex("future_bosses")
	await _frames(2)
	game.menus.open_codex("future_npcs")
	await _frames(2)
	game.menus.open_codex("future_terrains")
	await _frames(2)
	game.dev_mode = _dev0
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
	# Boss detail view (mechanics & tells): every catalogued boss must
	# build without error — those WITH authored `mechanics` (e.g. sexton)
	# and those still WITHOUT (graceful omit during concurrent fan-out).
	for bk in game.menus.BOSS_KINDS:
		if not Story.ALL_ENEMIES.has(bk):
			continue
		game.menus.open_codex("monsters", bk)
		await _frames(2)
		if game.menus.current != "codex":
			return _fail("boss detail view did not open for %s" % bk)
	if Story.ALL_ENEMIES.has("sexton"):
		game.menus.open_codex("monsters", "sexton")
		await _frames(2)
		if game.menus.current != "codex":
			return _fail("boss detail view (sexton, has mechanics) did not open")
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

	# 5c. Endgame modes (ACT2_DESIGN.md §II): The Crucible + The Waking Depths.
	await _test_endgame()

	# 5d. The touch HUD's overlay gate (mobile x co-op — the suite is the ONLY
	# thing that ever mounts a TouchHud headless; see the section's header).
	await _test_touch_overlay_gate()


## Endgame arena modes end to end (headless): the Crucible spawns affixed
## bosses that carry HP over and accrue reward, the Depths builds a camp then
## descends through waves, and both settle (cash-out / death) into banked gold +
## mailed spoils. Snapshots the shared character state and rebuilds ch1 after.
func _test_endgame() -> void:
	var kept_records: Dictionary = game.boss_records.duplicate(true)
	var kept_gold: int = game.player.gold
	var kept_mail: Array = game.mailbox.duplicate(true)
	var kept_dev: bool = game.dev_mode
	# A cleared-boss roster so the arena has bosses to draw from.
	game.boss_records["fangmaw"] = {"ttk": 30.0, "dps": 100.0, "kills": 1}
	game.boss_records["morwen"] = {"ttk": 30.0, "dps": 100.0, "kills": 1}
	game.boss_records["vargoth"] = {"ttk": 30.0, "dps": 100.0, "kills": 1}
	game.dev_mode = true  # unlocks the modes; no_saves already fences meta writes

	# HUD trial icons: shown under the mailbox once unlocked (not buried in ESC).
	await _frames(2)  # let update_stats toggle them
	if not (game.hud.crucible_btn.visible and game.hud.depths_btn.visible):
		return _fail("endgame: HUD trial icons not shown when unlocked")

	# ---------------------------------------------------------- The Crucible ---
	game.enter_endgame("crucible")
	if not game.endgame_active or game.chapter_id != "crucible":
		return _fail("crucible: arena world was not entered")
	var eg: Endgame = game.endgame
	await get_tree().create_timer(0.9).timeout  # first-boss beat (0.8) + margin
	await _frames(2)
	if eg.index != 1 or game._live_bosses().is_empty():
		return _fail("crucible: first boss did not spawn")
	if game.hud.crucible_btn.visible:
		return _fail("endgame: HUD trial icons should hide during a live run")
	var b: Boss = game._live_bosses()[0]
	if not b.endgame_boss:
		return _fail("crucible: boss not tagged endgame_boss")
	if b.affix == "":
		return _fail("crucible: boss carries no elite affix")
	# Kill it: the run advances, reward accrues, and HP must NOT full-heal reset
	# (passive class regen is legitimate sustain — only the old full-heal is barred).
	game.player.hp = game.player.max_hp * 0.4
	b.hp = 0.0
	b.die()
	await _frames(4)  # deferred on_endgame_boss_died
	if eg.kills != 1:
		return _fail("crucible: kill not counted (kills=%d)" % eg.kills)
	if eg.pending_gold <= 0 or eg.pending_gems.is_empty():
		return _fail("crucible: boss reward did not accrue")
	if game.player.hp >= game.player.max_hp * 0.9:
		return _fail("crucible: HP was reset toward full between fights (should carry over)")
	await get_tree().create_timer(1.4).timeout  # next-boss beat (1.3) + margin
	await _frames(2)
	if eg.index != 2:
		return _fail("crucible: did not advance to boss 2 (index=%d)" % eg.index)
	# Cash out: gold banks, spoils mail, the run settles.
	var gold_before: int = game.player.gold
	var mail_before: int = game.mailbox.size()
	eg.cash_out()
	await _frames(2)
	if eg.active:
		return _fail("crucible: cash-out did not settle the run")
	if game.player.gold <= gold_before:
		return _fail("crucible: cash-out banked no gold")
	if game.mailbox.size() <= mail_before:
		return _fail("crucible: spoils were not mailed")
	if game.menus.is_open():
		game.menus.close()
	game.endgame_active = false
	await _frames(2)

	# ------------------------------------------------------ The Waking Depths ---
	game.enter_endgame("depths")
	await _frames(3)
	var d: Endgame = game.endgame
	if game.chapter_id != "depths" or d.depth != 0:
		return _fail("depths: prep camp was not established")
	if not is_instance_valid(d._camp_merchant):
		return _fail("depths: prep camp has no merchant")
	var terrain_before: String = game.terrain_by_zone[d.arena_room]
	d.descend()  # depth 1 is a trash wave (and the first terrain re-theme)
	await _frames(3)
	if d.depth != 1 or game.zone_alive.get(d.arena_room, 0) <= 0:
		return _fail("depths: first wave did not spawn")
	if not d.wave_active:
		return _fail("depths: wave not marked active")
	if game.terrain_by_zone[d.arena_room] == terrain_before:
		return _fail("depths: arena did not re-theme on descent")
	if is_instance_valid(d._camp_merchant):
		return _fail("depths: camp merchant was not cleared on descend")
	# Clear the wave; the per-frame tick then advances the descent.
	for node in get_tree().get_nodes_in_group("enemies"):
		var en := node as Enemy
		if en != null and en.zone_idx == d.arena_room:
			en.hp = 0.0
			en.die()
	await _frames(5)
	await get_tree().create_timer(1.5).timeout  # room-clear beat (1.3) + margin
	await _frames(2)
	if d.depth < 2:
		return _fail("depths: did not descend after clearing the wave (depth=%d)" % d.depth)
	# Player-debuff cycle (depth 37+): −healing, then −damage, then +damage-taken,
	# stacking. Exercised directly (a 37-room descent would be a slog).
	var real_depth: int = d.depth
	d.depth = Balance.DEPTHS_TIER_PRESSURE  # 37: first stack cuts healing only
	d._apply_player_debuffs()
	if game.player.debuff_heal_in >= 1.0 or game.player.debuff_dmg_out < 1.0 or game.player.debuff_dmg_in > 1.0:
		return _fail("depths: first debuff stack should cut healing only")
	d.depth = Balance.DEPTHS_TIER_PRESSURE + 2 * Balance.DEPTHS_DEBUFF_EVERY  # 45: 3 stacks
	d._apply_player_debuffs()
	if game.player.debuff_heal_in >= 1.0 or game.player.debuff_dmg_out >= 1.0 or game.player.debuff_dmg_in <= 1.0:
		return _fail("depths: three debuff stacks should apply all three penalties")
	d.depth = real_depth
	# A death settles the run at the penalty AND clears the debuffs.
	d.on_player_death()
	await _frames(2)
	if eg.active:
		return _fail("depths: a death did not settle the run")
	if game.player.debuff_heal_in != 1.0 or game.player.debuff_dmg_out != 1.0 or game.player.debuff_dmg_in != 1.0:
		return _fail("depths: player debuffs were not cleared on settle")
	if game.menus.is_open():
		game.menus.close()
	game.endgame_active = false
	game.request_pause(false)

	# Restore the shared character + rebuild ch1 for the tests that follow.
	game.boss_records = kept_records
	game.player.gold = kept_gold
	game.mailbox = kept_mail
	game.dev_mode = kept_dev
	game.state = game.ST_PLAYING
	game.switch_chapter("ch1", true)
	game.player.hp = game.player.max_hp
	game.player.mp = game.player.max_mp
	await _frames(3)
	print("ok: endgame modes (HUD trial icons; Crucible affixed boss / HP-carry / reward / cash-out; Depths camp+merchant / retheme / wave / debuff-cycle / death-settle)")


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
	await _test_side_quests()
	await _test_quest_abandonment()
	await _test_ch1_quests()
	await _test_pc_curios()
	await _test_rv_na()
	await _test_ch2_quests()
	await _test_ch3_quests()
	await _test_ch4_quests()
	await _test_ch5_quests()
	await _test_ch6_quests()
	await _test_ch7_quests()
	await _test_promises_kept()
	await _test_promises_kept_2()
	await _test_endgame_no_placeholder_bosses()
	await _test_pause_menu()
	await _test_mp_lobby_ui()
	# -----------------------------------------------------------------------
	await _test_ch2_bosses()
	await _test_chapter_progression()

	print("AUTOTEST PASS")
	get_tree().paused = false
	get_tree().quit(0)


# ---- CORE: every boss resolves to a real fight track (gameplay path) ----
# The story spawn and dev roster both go through _boss_track(); a boss that
# ---- CORE: directional dash (player-reported 2026-07-09) -----------------
# A dash travels along the HELD move keys, not the horizontal facing —
# down+dash goes DOWN, diagonals go diagonal. With 8-direction dash art the clip
# picks the travel-facing STRIP and does NOT rotate the sprite (_aim_dash_pose
# bails on _action_dir_on — rotating the already-correct strip mangled it);
# _loco_dir carries the chosen suffix. No keys held falls back to the facing.
func _test_dash_direction() -> void:
	game.player.set_class("assassin")
	game.player.pending_theme_note = ""
	var dir_dash: bool = game.player._dir_loco.has("dash")

	# Hold S, dash: must travel straight DOWN; facing RIGHT the pose spins
	# +90° (clockwise — the right-facing art pitches nose-down).
	game.player.global_position = game.room_center(game.cur_room)
	_press_key(KEY_S, true)
	await _frames(1)
	# Set the facing AFTER the awaited frame: the per-frame soft-target
	# orientation may rewrite it, and no frame runs between here and the cast.
	game.player.facing = Vector2.RIGHT
	var start: Vector2 = game.player.global_position
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	var moved: Vector2 = game.player.global_position - start
	if moved.y < 30.0 or absf(moved.x) > 0.5:
		_press_key(KEY_S, false)
		return _fail("down+dash must travel DOWN (moved %s)" % moved)
	if dir_dash and game.player._loco_dir != "s":
		_press_key(KEY_S, false)
		return _fail("down dash should pick the SOUTH strip (got %s)" % game.player._loco_dir)
	if game.player._clip_rot != 0.0:
		_press_key(KEY_S, false)
		return _fail("directional dash must NOT rotate the art (got %.2f rad)" % game.player._clip_rot)

	# Hold S+A, dash: down-LEFT diagonal; the art flips to the LEFT side
	# and spins the remaining 45° (counter-clockwise off the left facing).
	game.player.global_position = game.room_center(game.cur_room)
	_press_key(KEY_A, true)
	await _frames(1)
	start = game.player.global_position
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	moved = game.player.global_position - start
	_press_key(KEY_S, false)
	_press_key(KEY_A, false)
	if moved.y < 30.0 or moved.x > -30.0:
		return _fail("down-left dash must travel the diagonal (moved %s)" % moved)
	if dir_dash and game.player._loco_dir != "sw":
		return _fail("down-left dash should pick the SW strip (got %s)" % game.player._loco_dir)
	await _frames(1)

	# No keys held: the dash still fires straight along the facing.
	game.player.global_position = game.room_center(game.cur_room)
	await _frames(1)
	game.player.facing = Vector2.RIGHT  # after the frame — same reason as above
	start = game.player.global_position
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.use_ability("a2")
	moved = game.player.global_position - start
	if moved.x < 30.0 or absf(moved.y) > 0.5:
		return _fail("keyless dash must fall back to the facing (moved %s)" % moved)
	if dir_dash and game.player._loco_dir != "e":
		return _fail("keyless dash should pick the EAST facing strip (got %s)" % game.player._loco_dir)
	if game.player._clip_rot != 0.0:
		return _fail("a directional dash must not rotate the art (got %.2f rad)"
			% game.player._clip_rot)

	# Restore shared state the way the kit sections do.
	game.player.cds["a2"] = 0.0
	game.player.mp = game.player.max_mp
	game.player.stab_ls_time = 0.0
	game.player.set_class("warrior")
	game.player.pending_theme_note = ""
	await _frames(2)
	print("ok: directional dash (held keys steer it, L/R art spins to match)")


## Synthesize a raw key press/release (dashes read Input.is_key_pressed).
func _press_key(key: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = down
	Input.parse_input_event(ev)


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
	var keep_bags: Array = game.player.bags
	var keep_mail: Array = game.mailbox
	var keep_dropped: Array = game.dropped_loot
	game.mailbox = []
	game.dropped_loot = []

	# Overflow drops to the ground and registers — never silently sold.
	game.player.bags = [Items.make_bag("F")]
	var filler: Array = []
	while game.player.bag_used() < game.player.bag_capacity():
		var st := Items.make_reset_stone()
		# Capacity counts UNITS now (round 52b), so any consumable fills a
		# slot; distinct ids just keep each filler individually erasable.
		st["id"] = "filler_%d" % filler.size()
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
	game.player.bags = keep_bags
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

	# Per-slot reforge: swaps ONE sub for a DIFFERENT affix, same sub count.
	var rf_item := Items.roll_item_of("weapon", "A", rng, "warrior")
	var target := String(rf_item["subs"].keys()[0])
	var n_before: int = rf_item["subs"].size()
	if not Items.can_reforge_affix(rf_item, target):
		return _fail("a rolled A sub should be reforgeable")
	var new_stat := Items.reforge_affix(rf_item, target, "warrior", rng)
	if new_stat == "" or new_stat == target or rf_item["subs"].has(target):
		return _fail("reforge_affix must replace the target with a different stat")
	if rf_item["subs"].size() != n_before or not rf_item["subs"].has(new_stat):
		return _fail("reforge_affix changed the sub count")
	# Main stat is never reforgeable (quench-only).
	if Items.can_reforge_affix(rf_item, String(rf_item["main"].keys()[0])):
		return _fail("main stat must not be reforgeable")

	# Add socket: A starts at 2 -> can add to 3, then hits the cap.
	var slots0: int = int(it["gem_slots"])
	if not Items.can_add_socket(it):
		return _fail("A-grade item should allow adding a socket")
	Items.add_socket(it)
	if int(it["gem_slots"]) != slots0 + 1:
		return _fail("add_socket did not add a socket")
	if Items.can_add_socket(it):
		return _fail("socket count past cap should be rejected")

	# An S weapon starts at 3 sockets and can reforge ONE more to 4, then caps.
	var s_it := Items.roll_item_of("weapon", "S", rng, "warrior")
	if int(s_it["gem_slots"]) != 3:
		return _fail("S gear should roll with 3 gem slots")
	if not Items.can_add_socket(s_it):
		return _fail("S gear should allow its one reforged 4th socket")
	Items.add_socket(s_it)
	if int(s_it["gem_slots"]) != 4 or Items.can_add_socket(s_it):
		return _fail("S gear past its 4-socket cap should be rejected")

	# C gear (2026-07-09): rolls 1 socket, reforge can add ONE more (cap 2).
	var c_it := Items.roll_item_of("armor", "C", rng, "warrior")
	if int(c_it["gem_slots"]) != 1:
		return _fail("C gear should roll with 1 gem socket")
	if not Items.can_add_socket(c_it):
		return _fail("C gear should allow a reforged socket")
	Items.add_socket(c_it)
	if Items.can_add_socket(c_it):
		return _fail("C gear past its 2-socket cap should be rejected")

	# Pen un-gate (2026-07-17): every grade BELOW S rolls the full pool, so a mage
	# can draw physpen it can't use today (a damage-type rune makes it live). This
	# is probabilistic — physpen is 1 of 12 in an A's 2 draws, so 60 rolls missing
	# it entirely is ~1-in-60k, not flake territory.
	var saw_offtype := false
	for i in 60:
		if Items.roll_subs("A", "Staff", "mage", rng).has("physpen"):
			saw_offtype = true
			break
	if not saw_offtype:
		return _fail("non-S gear should be able to roll its off-type pen (un-gated 2026-07-17)")

	# ...but an S legendary's FIRST roll stays class-usable — never the off-type pen.
	for i in 60:
		if Items.roll_subs("S", "Staff", "mage", rng).has("physpen"):
			return _fail("an S first roll must never carry the off-type pen")

	# Transmute: swaps WHICH attribute the main feeds, KEEPS the rolled magnitude.
	var tm := Items.roll_item_of("weapon", "A", rng, "archer")
	var old_attr := String(tm["main"].keys()[0])
	if old_attr != "AGI":
		return _fail("an archer weapon should roll an AGI main, got " + old_attr)
	var old_val: float = float(tm["main"][old_attr])
	var targets := Items.transmute_targets(tm)
	if old_attr in targets or targets.size() != 3:
		return _fail("transmute targets must be the 3 attributes the main is NOT")
	var was := Items.transmute_main(tm, "STR")
	if was != old_attr or not tm["main"].has("STR") or tm["main"].has(old_attr):
		return _fail("transmute_main did not swap the main attribute")
	if absf(float(tm["main"]["STR"]) - old_val) > 0.001:
		return _fail("transmute must KEEP the rolled magnitude — it buys an attribute, not a reroll")
	if tm["main"].size() != 1:
		return _fail("transmute must leave exactly one main")
	# The band is slot/grade/shape-keyed, so a transmuted main still quenches.
	if not Items.can_quench(tm, "STR"):
		return _fail("a transmuted main must still be quenchable")
	# Junk in, "" out — never a silent partial write.
	if Items.transmute_main(tm, "STR") != "" or Items.transmute_main(tm, "NOPE") != "":
		return _fail("transmute to the current attribute (or a non-attribute) must no-op")
	print("ok: reforge bench (affix reroll, value reroll, add socket + cap incl. C, pen un-gate, transmute)")


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
	var keep_bags: Array = game.player.bags
	var keep_bp: Array = game.player.backpack
	game.stash = []
	game._stash_loaded = true          # skip the real account file
	game.player.bags = [Items.make_bag("S"), Items.make_bag("S")]  # room to withdraw into
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
	game.player.bags = keep_bags
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


# ---- CORE: resonance band leans (2026-07-09) ------------------------------
# Conviction-scaled riders: zero through the neutral band, wake PAST the
# band line (±25), max at ±100. Virtue = Constancy (potions mend deeper),
# Temptation = Hunger (execute vs wounded mobs + kill gold). Neither side
# ever gets the other's rider, and the band line itself lends nothing.
func _test_res_lean() -> void:
	var p := game.player
	var keep_res: float = p.resonance
	p.resonance = 0.0
	if p.res_lean() != 0.0 or p.hunger_gold_mult() != 1.0 or p.constancy_heal_mult() != 1.0:
		return _fail("neutral shard must lend no lean")
	p.resonance = 25.0
	if p.res_lean() != 0.0:
		return _fail("the lean wakes PAST the band line, not at it")
	p.resonance = 62.5  # halfway between the band line and full conviction
	if absf(p.res_lean() - 0.5) > 0.001:
		return _fail("lean should ramp linearly with conviction")
	p.resonance = 100.0
	if absf(p.constancy_heal_mult() - (1.0 + Balance.RES_CONSTANCY_HEAL_MAX)) > 0.001:
		return _fail("full Virtue should max Constancy")
	if p.hunger_exec_bonus() != 0.0 or p.hunger_gold_mult() != 1.0:
		return _fail("Virtue must never grant Hunger riders")
	p.resonance = -100.0
	if absf(p.hunger_exec_bonus() - Balance.RES_HUNGER_EXEC_MAX) > 0.001 \
			or absf(p.hunger_gold_mult() - (1.0 + Balance.RES_HUNGER_GOLD_MAX)) > 0.001:
		return _fail("full Temptation should max Hunger")
	if p.constancy_heal_mult() != 1.0:
		return _fail("Temptation must never grant Constancy")
	if game._kill_gold(100) <= 100:
		return _fail("kill gold should carry the Hunger bonus")
	p.resonance = keep_res
	print("ok: resonance band leans (Hunger / Constancy)")


# ---- CORE: Gold Rush surge (2026-07-09) -----------------------------------
# Greed's ONLY source since the gem retired: a charged coin that surges
# greed for a window on touch — auto-trigger, never a bag item.
func _test_goldrush() -> void:
	var p := game.player
	var keep_gold: int = p.gold
	var keep_rush: float = p.goldrush_time
	var keep_greed: float = p.greed
	p.greed = 0.0
	p.goldrush_time = 0.0
	if absf(p.current_greed()) > 0.001:
		return _fail("greed should be sourceless outside a Gold Rush")
	p.gold = 0
	p.gain_gold(100)
	var base_pay: int = p.gold
	p.goldrush_time = Balance.GOLDRUSH_DUR
	if absf(p.current_greed() - Balance.GOLDRUSH_GREED) > 0.001:
		return _fail("Gold Rush should surge greed by GOLDRUSH_GREED")
	p.gold = 0
	p.gain_gold(100)
	if p.gold <= base_pay:
		return _fail("a Gold Rush window should pay more gold")
	# The charged coin applies on TOUCH (magnets like a coin; it can never
	# enter the bag BY CONSTRUCTION — the goldrush branch frees the pickup
	# before any claim logic, so no bag assertion: idle frames in the live
	# test world let unrelated ground loot claim itself and false-fail it).
	p.goldrush_time = 0.0
	Pickup.drop_goldrush(game, p.global_position)
	await _frames(8)
	if p.goldrush_time <= 0.0:
		return _fail("charged coin did not trigger the Gold Rush on touch")
	p.gold = keep_gold
	p.goldrush_time = keep_rush
	p.greed = keep_greed
	print("ok: gold rush surge (sourceless baseline, window pay, touch trigger)")


# ---- CORE: gambling vendor (afford gate, cost deduction, delivery) -------
func _test_gamble() -> void:
	var p := game.player
	var keep_gold: int = p.gold
	var keep_bags: Array = p.bags
	var keep_bp: Array = p.backpack
	p.bags = [Items.make_bag("S")]  # room to receive
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

	# 2026-07-09 rework: the gamble is the pity machine — it ROLLS the
	# chapter's BOSS band and is PRICED at the boss-table-weighted expected
	# farm cost x GAMBLE_DISCOUNT (x the resonance haggle).
	if not Balance.boss_weights(game.chapter_id).has(String(won.get("grade", ""))):
		return _fail("gamble rolled a grade off the chapter's BOSS table (%s)" % String(won.get("grade", "")))
	var w: Dictionary = Balance.boss_weights(game.chapter_id)
	var total := 0.0
	for v in w.values():
		total += float(v)
	var expected := 0.0
	for gr in w:
		expected += (float(w[gr]) / total) * float(Items.shop_buy_price(
			{"grade": String(gr), "slot": "armor", "plus": 0}, game.chapter_id))
	var want_cost: int = int(ceil(expected * Balance.GAMBLE_DISCOUNT * game.band_price_mult()))
	if cost != want_cost:
		return _fail("gamble cost %d != boss-band expected farm price formula %d" % [cost, want_cost])

	# Restore.
	p.gold = keep_gold
	p.bags = keep_bags
	p.backpack = keep_bp
	print("ok: gamble vendor (afford gate, cost deduction, boss-band roll + pricing)")


# ---- CORE: equip / unequip (slot empties to bag, bag-full guard) ---------
func _test_equip_unequip() -> void:
	var p := game.player
	var keep_eq: Dictionary = p.equipment
	var keep_bp: Array = p.backpack
	var keep_cons: Array = p.consumables
	var keep_bags: Array = p.bags
	p.bags = [Items.make_bag("S")]
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
		# Every unit fills a slot now (round 52b); distinct ids just keep
		# fillers individually removable.
		var filler_st := Items.make_reset_stone()
		filler_st["id"] = "filler_%d" % p.consumables.size()
		p.consumables.append(filler_st)
	if p.unequip("weapon"):
		return _fail("unequip succeeded into a full bag")

	# Restore.
	p.equipment = keep_eq
	p.backpack = keep_bp
	p.consumables = keep_cons
	p.bags = keep_bags
	p.recalc()
	print("ok: equip / unequip (slot empties to bag, bag-full guard)")


# ---- CORE: stacking bags + discard-throw (round 52) --------------------
func _test_bags_discard() -> void:
	var p := game.player
	# Snapshot everything this section touches (restore, never clear).
	var keep_bags: Array = p.bags
	var keep_bp: Array = p.backpack
	var keep_gold: int = p.gold
	var keep_dropped: Array = game.dropped_loot

	# --- capacity is the SUM; a 6th bag keeps the best MAX_BAGS ------------
	p.bags = []
	for i in Balance.MAX_BAGS:
		p.bags.append(Items.make_bag("F"))
	if p.bag_capacity() != Balance.MAX_BAGS * int(Items.BAG_SLOTS["F"]):
		return _fail("bag capacity is not the sum of equipped bags")
	var cap0: int = p.bag_capacity()
	var gold0: int = p.gold
	# A bigger 6th bag displaces the smallest: kept, capacity grows, spare 1g.
	if not p.acquire_bag(Items.make_bag("D")):
		return _fail("a bigger 6th bag should be kept")
	if p.bags.size() != Balance.MAX_BAGS:
		return _fail("bag count exceeded MAX_BAGS after a 6th")
	if p.bag_capacity() <= cap0:
		return _fail("capacity did not grow when a bigger bag displaced a smaller")
	if p.gold != gold0 + Balance.BAG_SELL_GOLD:
		return _fail("displaced bag did not cash for exactly 1g")

	# --- slot curve (2026-07-09 v2): F=15 base, +5 per tier, S=45 ---------
	# (every tier +5 over round 52b to compensate health potions taking slots)
	if int(Items.BAG_SLOTS["F"]) != 15 or int(Items.BAG_SLOTS["S"]) != 45:
		return _fail("bag slot curve endpoints drifted (want F=15, S=45)")
	for gi in range(1, Items.GRADES.size()):
		var lo: int = int(Items.BAG_SLOTS[Items.GRADES[gi - 1]])
		var hi: int = int(Items.BAG_SLOTS[Items.GRADES[gi]])
		if hi - lo != 5:
			return _fail("bag curve is not +5/tier at %s" % Items.GRADES[gi])
	# Starter is exactly two F bags = 30 slots.
	if Balance.STARTER_BAGS != ["F", "F"] or Items.starter_bags().size() != 2:
		return _fail("starter is not two F bags")

	# --- capacity counts UNITS, not kinds (the big round-52b change) -------
	# Fill a known bag with MANY copies of ONE consumable id: each unit must
	# eat a slot, and a full bag must then refuse further adds.
	var cap_bags: Array = p.bags
	var cap_cons: Array = p.consumables
	var cap_gems: Array = p.gem_bag
	var cap_bp2: Array = p.backpack
	var cap_pot: int = p.potions
	var cap_potf: int = p.potions_free
	p.bags = [Items.make_bag("A")]   # 40 slots
	p.consumables = []
	p.gem_bag = []
	p.backpack = []
	# Health potions occupy slots too (2026-07-09 v2): bought stock AND the
	# free chapter potion each count as one unit.
	p.potions = 2
	p.potions_free = 1
	var used0: int = p.bag_used()    # 3 — the potions alone
	if used0 != 3:
		return _fail("owned health potions (bought + free) must count as bag units")
	for i in 30:
		var pot := Items.make_mana_potion()   # ALL the same id
		if not p.add_consumable(pot):
			return _fail("add_consumable refused a unit while the bag had room")
	if p.bag_used() != used0 + 30:
		return _fail("30 same-id consumables must consume 30 slots, not one (units!)")
	# Fill the rest with gems (also per-unit), then confirm the bag is full.
	while p.bag_used() < p.bag_capacity():
		if not p.gain_gem(Items.make_gem("crit", 1)):
			return _fail("gain_gem refused a gem while the bag had room")
	if p.bag_used() != p.bag_capacity():
		return _fail("unit-counting did not exactly fill the bag")
	if p.add_consumable(Items.make_mana_potion()):
		return _fail("a FULL bag accepted another consumable (unit cap breach)")
	if p.gain_gem(Items.make_gem("crit", 1)):
		return _fail("a FULL bag accepted another gem (unit cap breach)")
	# A full bag blocks the merchant potion buy (can_gain_potion is the
	# shop's guard); freeing the potions' own slots re-opens it.
	if p.can_gain_potion():
		return _fail("a FULL bag must block a merchant health-potion buy")
	p.potions = 0
	p.potions_free = 0
	if not p.can_gain_potion():
		return _fail("freed potion slots must re-allow a health-potion buy")
	p.bags = cap_bags
	p.consumables = cap_cons
	p.gem_bag = cap_gems
	p.backpack = cap_bp2
	p.potions = cap_pot
	p.potions_free = cap_potf

	# --- shop grey-out: no capacity gain -> buy is blocked ----------------
	p.bags = []
	for i in Balance.MAX_BAGS:
		p.bags.append(Items.make_bag("S"))   # full set of the biggest
	if p.bag_would_improve(int(Items.BAG_SLOTS["A"])):
		return _fail("a smaller bag must NOT improve a full set of S bags")
	if p.bag_would_improve(int(Items.BAG_SLOTS["S"])):
		return _fail("a tied-size bag on a full set must NOT improve capacity")
	p.bags = [Items.make_bag("F"), Items.make_bag("F")]
	if not p.bag_would_improve(int(Items.BAG_SLOTS["S"])):
		return _fail("an S bag must improve when the set is not yet full")
	p.bags = []
	for i in Balance.MAX_BAGS:
		p.bags.append(Items.make_bag("D"))
	if not p.bag_would_improve(int(Items.BAG_SLOTS["S"])):
		return _fail("a bigger bag must improve even a full set of smaller bags")

	# --- bag drops: chance stays per-act; GRADE now follows the chapter BOSS table.
	if not (is_equal_approx(Balance.bag_drop_chance(1), 0.10)
			and is_equal_approx(Balance.bag_drop_chance(2), 0.09)
			and is_equal_approx(Balance.bag_drop_chance(3), 0.08)):
		return _fail("per-act bag drop chance drifted from the design table")
	var brng := RandomNumberGenerator.new()
	brng.seed = 707
	for chid in ["ch1", "ch3", "ch5", "ch7"]:
		var weights: Dictionary = Balance.boss_weights(chid)
		for i in 300:
			if not weights.has(Balance.roll_bag_grade(chid, brng)):
				return _fail("%s bag grade left the chapter boss table" % chid)
	# ch1 bags are F; ch2 bags are E (a bag is that chapter's boss tier).
	for i in 50:
		if Balance.roll_bag_grade("ch1", brng) != "F" or Balance.roll_bag_grade("ch2", brng) != "E":
			return _fail("early bag grades not pinned to the chapter boss tier")
	# Deep chapters mint high-tier bags: ch7 bags are B/A (never below B).
	for gk in Balance.boss_weights("ch7"):
		if Items.GRADES.find(String(gk)) < Items.GRADES.find("B"):
			return _fail("ch7 bag table leaked a grade below B")

	# --- shop bags are QoL-cheap but always dwarf the 1g sell -------------
	for gk in Items.GRADES:
		if Items.bag_buy_price(gk) <= Balance.BAG_SELL_GOLD:
			return _fail("shop bag price must sit far above the 1g sell (%s)" % gk)

	# --- save round-trip + old-save migration (round 52b: slots re-derived
	# from GRADE onto the CURRENT curve, discarding inflated legacy counts).
	var nb: Array = SaveGame.load_bags({"bags": [
		{"kind": "bag", "grade": "F", "name": "a", "slots": 5.0},
		{"kind": "bag", "grade": "D", "name": "b", "slots": 15.0}]})
	if nb.size() != 2 or int(nb[0]["slots"]) != int(Items.BAG_SLOTS["F"]) \
			or int(nb[1]["slots"]) != int(Items.BAG_SLOTS["D"]):
		return _fail("bags did not re-derive slots from grade onto the new curve")
	var round_trip: Array = SaveGame.load_bags(JSON.parse_string(JSON.stringify({"bags": nb})))
	if round_trip.size() != 2 or int(round_trip[1]["slots"]) != int(Items.BAG_SLOTS["D"]):
		return _fail("bags did not survive a JSON round-trip")
	# Old single-bag save: a legacy C bag with an INFLATED slot count remaps
	# to the new C value, not the stored 55.
	var migrated: Array = SaveGame.load_bags({"bag": {"kind": "bag", "grade": "C", "name": "c", "slots": 55.0}})
	if migrated.size() != 1 or int(migrated[0]["slots"]) != int(Items.BAG_SLOTS["C"]):
		return _fail("old single-bag save did not migrate onto the new curve")
	if SaveGame.load_bags({}).size() != Balance.STARTER_BAGS.size():
		return _fail("pre-bag save did not fall back to the starter bags")

	# --- discard-throw: to the ground, no-pickup window, then collectable -
	p.bags = [Items.make_bag("S")]
	p.backpack = []
	game.dropped_loot = []
	var gear := Items.roll_item_of("charm", "B", game.loot_rng, p.cls)
	p.backpack.append(gear)
	# The UI removes it from the bag, then the game flings it out.
	p.backpack.erase(gear)
	var pk := game.discard_to_ground({"kind": "item", "item": gear})
	# NB: no `await` here — headless frames race ahead and would drain the
	# no-pickup timer before we can test it. The spawn/registry are synchronous.
	if game.dropped_loot.size() != 1:
		return _fail("discard did not register the drop (would be silently lost)")
	if pk.pickup_delay <= 0.0:
		return _fail("discarded pickup has no no-pickup window")
	if get_tree().get_nodes_in_group("loot_pickups").is_empty():
		return _fail("discard did not spawn a ground pickup")
	# Walk over it DURING the window: it must NOT re-collect.
	pk._on_body_entered(p)
	if not p.backpack.is_empty() or game.dropped_loot.size() != 1:
		return _fail("discarded item re-collected inside its no-pickup window")
	# Window elapses -> a walk-over now claims it back into the bag.
	pk.pickup_delay = 0.0
	pk._on_body_entered(p)
	if p.backpack.size() != 1 or not game.dropped_loot.is_empty():
		return _fail("discarded item did not become collectable after the window")

	# Restore.
	for node in get_tree().get_nodes_in_group("loot_pickups"):
		node.queue_free()
	p.bags = keep_bags
	p.backpack = keep_bp
	p.gold = keep_gold
	game.dropped_loot = keep_dropped
	p.recalc()
	await _frames(2)
	print("ok: stacking bags (sum-capacity, keep-best-N, +5/tier curve, UNIT-counting incl. health potions, grey-out, act drops, shop price, migration) + discard-throw")


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
	# Gems drop ch4+, so the spoils bundle is gear+gem from ch4 on, gear-only before.
	var fc_ch: String = g.chapter_id
	var mail_before: int = g.mailbox.size()
	var gold_before2: int = g.player.gold
	g.chapter_id = "ch4"
	g._first_clear_reward(12)
	if g.player.gold <= gold_before2:
		return _fail("first clear paid no gold")
	if g.mailbox.size() != mail_before + 1 or g.mailbox[-1]["items"].size() != 2:
		return _fail("first clear (ch4) did not mail the spoils (item + gem)")
	g.chapter_id = "ch1"
	g._first_clear_reward(12)
	if g.mailbox[-1]["items"].size() != 1:
		return _fail("first clear (ch1) should mail gear only, no gem")
	g.chapter_id = fc_ch
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
		for stat in Balance.SPECIAL_GEM_STATS + ["speed_pct"]:
			if it2["subs"].has(stat) or it2["main"].has(stat):
				return _fail("rolled gear carried banned stat %s" % stat)
		var main_attr: String = it2["main"].keys()[0]
		if main_attr != Items.CLASS_PRIMARY[["warrior", "mage", "archer"][i % 3]]:
			return _fail("gear main %s does not match its class" % main_attr)
	# Mains are the class primary attribute, guaranteed and class-tagged;
	# movement speed exists nowhere on gear (sovereign stat).
	var probe := Items.roll_item_of("boots", "B", grng, "mage")
	if not probe["main"].has("INT") or String(probe.get("cls", "")) != "mage":
		return _fail("gear main is not the class-tagged primary attribute")

	# --- chapter loot ceilings: loot_cap() = the chapter general-band ceiling ---
	var keep_ch: String = g.chapter_id
	g.chapter_id = "ch1"
	var cap1: String = g.loot_cap()
	g.chapter_id = "ch4"
	var cap4: String = g.loot_cap()
	g.chapter_id = "ch7"
	var cap7: String = g.loot_cap()
	g.chapter_id = keep_ch
	if cap1 != "F" or cap4 != "C" or cap7 != "B":
		return _fail("loot_cap ceilings wrong (ch1=%s ch4=%s ch7=%s)" % [cap1, cap4, cap7])

	# --- anti-degeneracy caps: no source stacks past them ---
	var keep_eq2: Dictionary = game.player.equipment
	game.player.equipment = {"charm": {"slot": "charm", "grade": "S", "name": "test",
		"noun": "Charm", "main": {}, "plus": 0, "gem_slots": 0, "gems": [],
		"subs": {"cdr": 0.9, "lifesteal": 0.9, "combo": 0.9}}}
	game.player.recalc()
	# Caps are SOFT KNEES: 0.9 raw -> cap + (0.9 - cap) * 0.1, never a wall.
	if absf(game.player.cdr - Balance.soft_cap(0.9, Balance.CAP_CDR)) > 0.001 \
			or absf(game.player.lifesteal - Balance.soft_cap(0.9, Balance.CAP_LIFESTEAL)) > 0.001 \
			or absf(game.player.combo - Balance.soft_cap(0.9, Balance.CAP_COMBO)) > 0.001:
		return _fail("special-stat soft knees are off their curve")
	game.player.equipment = keep_eq2
	game.player.recalc()

	# --- soft knees in the combat curves + the new cap values ---
	if absf(Stats.crit_curve(0.5) - (0.35 + 0.15 * 0.2)) > 0.001:
		return _fail("crit knee is not 35% + 1/5 beyond")
	# Theme crit is CAP-EXEMPT: 35% built + 15% themed = 50% flat, no knee.
	if absf(Stats.effective_crit(0.35, 0.15, 0.0) - 0.5) > 0.001:
		return _fail("theme crit bonus did not ride above the knee")
	if absf(Stats.eva_curve(0.8) - (0.50 + 0.3 * 0.1)) > 0.001:
		return _fail("evasion knee is not 50% + 1/10 beyond")
	if Stats.res_frac(9999.0) > 0.82:
		return _fail("resistance reduction exceeded its ~82% ceiling")
	if Stats.greed_loot(0.1) <= 0.0:
		return _fail("greed chest chance still has a threshold")

	# --- ults ignore haste (every class; authored talents still apply) ---
	var keep_cdr: float = game.player.cdr
	game.player.cdr = 0.4
	var ult_cd: float = game.player.ability_cd("ult")
	game.player.cdr = 0.0
	if absf(ult_cd - game.player.ability_cd("ult")) > 0.001:
		return _fail("haste compressed an ult cooldown")
	game.player.cdr = keep_cdr

	# --- gem LEVEL limits by grade: B holds Lv3 at most ---
	var b_host := {"slot": "armor", "grade": "B", "name": "t2", "noun": "Plate",
		"main": {}, "subs": {}, "plus": 0, "gem_slots": 1, "gems": []}
	var g_lv4 := Items.make_gem("hp_pct", 4)
	var g_lv3 := Items.make_gem("hp_pct", 3)
	game.player.gem_bag.append_array([g_lv4, g_lv3])
	if game.player.embed_gem_into(b_host, g_lv4):
		return _fail("B gear accepted a Lv4 gem (limit Lv3)")
	if not game.player.embed_gem_into(b_host, g_lv3):
		return _fail("B gear refused a legal Lv3 gem")
	game.player.gem_bag.erase(g_lv4)

	# --- typed gem slots + one special per stat (2026-07-08) ---
	if not ("dmg_pct" in Balance.SPECIAL_GEM_STATS):
		return _fail("dmg_pct should be a special gem stat now (gem-only)")
	# SNAPSHOT + strip equipped specials (autotest rule); RESTORE at the end.
	var _saved_gems := {}
	for eslot in game.player.equipment:
		_saved_gems[eslot] = game.player.equipment[eslot].get("gems", []).duplicate(true)
		var eg: Array = game.player.equipment[eslot].get("gems", [])
		for gi in range(eg.size() - 1, -1, -1):
			if String(eg[gi]["stat"]) in Balance.SPECIAL_GEM_STATS:
				eg.remove_at(gi)
	# C gear (2026-07-09: sockets extend down a tier) = 1 REGULAR slot,
	# gem level cap Lv2: a Lv2 regular fits, a special is refused.
	var c_item := {"slot": "charm", "grade": "C", "name": "c", "noun": "Charm",
		"main": {}, "subs": {}, "plus": 0, "gem_slots": 1, "gems": []}
	var g_c_reg := Items.make_gem("atk_flat", 2)
	var g_c_spec := Items.make_gem("dmg_pct", 2)
	game.player.gem_bag.append_array([g_c_reg, g_c_spec])
	if game.player.embed_gem_into(c_item, g_c_spec):
		return _fail("C gear accepted a special gem (it is regular-only)")
	if not game.player.embed_gem_into(c_item, g_c_reg):
		return _fail("C gear refused a legal Lv2 regular gem in its socket")
	game.player.gem_bag.erase(g_c_spec)
	# B gear is REGULAR-ONLY: a special gem is refused, a regular fits.
	var b_item := {"slot": "charm", "grade": "B", "name": "b", "noun": "Charm",
		"main": {}, "subs": {}, "plus": 0, "gem_slots": 1, "gems": []}
	var g_cd := Items.make_gem("dmg_pct", 3)
	var g_rb := Items.make_gem("atk_flat", 3)
	game.player.gem_bag.append_array([g_cd, g_rb])
	if game.player.embed_gem_into(b_item, g_cd):
		return _fail("B gear accepted a special gem (it has no special slot)")
	if not game.player.embed_gem_into(b_item, g_rb):
		return _fail("B gear refused a regular gem in its regular slot")
	# A gear = 1 regular + 1 special: one of each fits, a 2nd of either refused.
	var a_item := {"slot": "boots", "grade": "A", "name": "a", "noun": "Boots",
		"main": {}, "subs": {}, "plus": 0, "gem_slots": 2, "gems": []}
	var g_cd2 := Items.make_gem("dmg_pct", 6)
	var g_cb := Items.make_gem("combo", 6)
	var g_rb2 := Items.make_gem("atk_flat", 6)
	var g_rb3 := Items.make_gem("atk_flat", 6)
	game.player.gem_bag.append_array([g_cd2, g_cb, g_rb2, g_rb3])
	if not game.player.embed_gem_into(a_item, g_rb2):
		return _fail("A gear refused a regular gem in its regular slot")
	if not game.player.embed_gem_into(a_item, g_cd2):
		return _fail("A gear refused a special gem in its special slot")
	if game.player.embed_gem_into(a_item, g_rb3):
		return _fail("A gear accepted a 2nd regular gem (only 1 regular slot)")
	if game.player.embed_gem_into(a_item, g_cb):
		return _fail("A gear accepted a 2nd special gem (only 1 special slot)")
	# One special per STAT across gear: inject a dmg_pct into an equipped item,
	# then a fresh A item's special slot refuses another dmg_pct.
	var cross_slot := ""
	for s in game.player.equipment:
		cross_slot = s
		break
	if cross_slot != "":
		game.player.equipment[cross_slot].get("gems", []).append(Items.make_gem("dmg_pct", 6))
		var a2 := {"slot": ("armor" if cross_slot == "weapon" else "weapon"), "grade": "A",
			"name": "a2", "noun": "X", "main": {}, "subs": {}, "plus": 0, "gem_slots": 2, "gems": []}
		var g_cd3 := Items.make_gem("dmg_pct", 6)
		game.player.gem_bag.append(g_cd3)
		if game.player.embed_gem_into(a2, g_cd3):
			return _fail("a 2nd dmg_pct accepted while one is worn (one per stat across gear!)")
		game.player.gem_bag.erase(g_cd3)
	# RESTORE.
	for eslot in _saved_gems:
		game.player.equipment[eslot]["gems"] = _saved_gems[eslot]
	for gg in [g_cd, g_cb, g_rb3]:
		game.player.gem_bag.erase(gg)
	game.player.recalc()
	print("ok: typed gem slots (C/B regular-only incl. C's new socket, A = 1 regular + 1 special, one special per stat across gear)")

	# --- class lock: another class's gear refuses to be worn ---
	var other_cls: String = "mage" if game.player.cls != "mage" else "warrior"
	var locked := Items.roll_item_of("charm", "B", grng, other_cls)
	game.player.backpack.append(locked)
	game.player.equip(locked)
	if game.player.equipment.get("charm") == locked:
		return _fail("equipped another class's gear")
	game.player.backpack.erase(locked)

	# --- boss HP grows on the flat player-tracking BOSS_HP_GROWTH (2026-07-09):
	# the old per-kind hp_g + past-L32 gem ramp was folded into one dial so a
	# scaled boss's TTK stays level-invariant instead of ballooning. The per-level
	# ratio is now the SAME at every level (no ramp bump). ---
	var hi_ratio: float = float(Story.enemy_stats_at("nullwarden", 50)["hp"]) \
		/ float(Story.enemy_stats_at("nullwarden", 49)["hp"])
	var low_ratio: float = float(Story.enemy_stats_at("nullwarden", 30)["hp"]) \
		/ float(Story.enemy_stats_at("nullwarden", 29)["hp"])
	if absf(hi_ratio - (1.0 + Balance.BOSS_HP_GROWTH)) > 0.001 \
			or absf(low_ratio - (1.0 + Balance.BOSS_HP_GROWTH)) > 0.001:
		return _fail("boss HP should grow at a flat BOSS_HP_GROWTH per level")

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


func _test_mob_traits() -> void:
	# HP/dmg presence mults ride enemy_stats_at (non-boss only).
	var wolf := Story.enemy_stats_at("wolf", 2)
	var wolf_base := 34.0 * Balance.TTK_HP_MULT * Balance.MOB_HP_MULT
	if absf(float(wolf["hp"]) - wolf_base) > 1.0:
		return _fail("mob HP mult not applied (got %d, want %d)" % [int(wolf["hp"]), int(wolf_base)])
	if absf(float(wolf["dmg"]) - 12.0 * Balance.ENEMY_DMG_MULT * Balance.MOB_DMG_MULT) > 0.5:
		return _fail("mob DMG mult not applied")
	# Bosses are exempt from both.
	var fang := Story.enemy_stats_at("fangmaw", 4)
	if absf(float(fang["hp"]) - 1200.0) > 1.0:
		return _fail("boss HP wrongly caught the mob mult")

	# Channel-healer: pulse tops up a wounded neighbor (both -1, same zone).
	var healer := Enemy.make(game, "cultist", game.player.global_position + Vector2(260, 0))
	game.add_enemy(healer)
	if not healer.traits.has("channel_heal"):
		return _fail("cultist did not carry the channel_heal trait")
	var z := Enemy.make(game, "zombie", game.player.global_position + Vector2(300, 0))
	game.add_enemy(z)
	if z.mend_rate <= 0.0:
		return _fail("zombie has no mend rate (mend trait)")
	z.zone_idx = 0
	healer.zone_idx = 0
	game.cur_room = 0
	z.hp = z.max_hp * 0.3
	var hp1: float = z.hp
	healer._heal_pulse()
	if z.hp <= hp1:
		return _fail("channel-heal pulse did not mend a wounded ally")

	# WARDED: a small chip hit is guarded; a CRIT (a real blow) shatters
	# the guard for good — no status required (every build can crack it).
	var husk := Enemy.make(game, "sun_bleached", game.player.global_position + Vector2(320, 0))
	game.add_enemy(husk)
	if not husk.traits.has("warded"):
		return _fail("sun_bleached lost its warded trait")
	var chip := husk.max_hp * 0.02  # a small, non-shattering hit
	husk.hp = husk.max_hp
	husk.take_damage(chip, Vector2.ZERO, false, true)  # non-crit chip: guarded
	if husk.max_hp - husk.hp >= chip * 0.9:
		return _fail("warded guard did not reduce chip damage")
	if husk.ward_broken:
		return _fail("a chip hit wrongly shattered the ward")
	husk.take_damage(chip, Vector2.ZERO, true, true)   # a CRIT shatters it
	if not husk.ward_broken:
		return _fail("a crit did not shatter the ward")
	husk.hp = husk.max_hp
	husk.take_damage(chip, Vector2.ZERO, false, true)  # now full damage lands
	if husk.max_hp - husk.hp < chip * 0.9:
		return _fail("shattered ward still reduced damage")

	# Frenzy hardens the wounded; swift speeds the plate-less melee.
	var wt := Enemy.make(game, "skeleton", game.player.global_position + Vector2(340, 0))
	game.add_enemy(wt)
	wt.hp = wt.max_hp
	var calm: float = wt._hit_dmg()
	wt.hp = wt.max_hp * 0.2
	if wt._hit_dmg() <= calm:
		return _fail("frenzy did not raise damage below the HP threshold")
	if wt.speed <= 140.0:
		return _fail("swift speed bump not applied")

	# Pounce present; bloat spawns a hazard pool on death.
	var w := Enemy.make(game, "wolf", game.player.global_position + Vector2(360, 0))
	if not w.traits.has("pounce"):
		return _fail("wolf lost its pounce trait")
	var hz0: int = game.hazards.size()
	var bl := Enemy.make(game, "casket_creeper", game.player.global_position + Vector2(380, 0))
	game.add_enemy(bl)
	bl.zone_idx = 0
	bl.take_damage(9999999.0, Vector2.ZERO, false, true)
	await _frames(3)  # death + deferred hazard spawn
	if game.hazards.size() <= hz0:
		return _fail("bloat did not leave a hazard pool on death")

	for e in [healer, z, husk, wt, w]:
		if is_instance_valid(e):
			e.queue_free()
	game.hazards.clear()
	await _frames(2)
	game.cur_room = 0

	# Coverage + validity: every catalogued mob (ch1-7) carries at least
	# one trait, and every trait names a real behavior (typo guard).
	var untagged: Array = []
	for kind in Story.ALL_ENEMIES:
		var st: Dictionary = Story.ALL_ENEMIES[kind]
		if st.get("boss", false) or kind in game.menus.BOSS_KINDS:
			continue
		if st.get("xp", 0) <= 0 and st.get("gold", 0) <= 0:
			continue  # scenery props (censers, roots) aren't catalogue mobs
		var tr: Array = st.get("traits", [])
		if tr.is_empty():
			untagged.append(kind)
		for t in tr:
			if not Enemy.TRAIT_DESC.has(String(t)):
				return _fail("mob '%s' has unknown trait '%s'" % [kind, t])
	if not untagged.is_empty():
		return _fail("untagged mobs (need a trait): %s" % ", ".join(untagged))
	print("ok: mob mechanics (presence + pounce/web/channel/warded/bloat... all ch1-7 tagged)")


## Environment asset seams (2026-07-18): the three engine unlocks that let
## pack sheets drop in — ground PNG tilesets (Lane 1), composite structures +
## wall decals (Lane 2), animated scenery props (Lane 3). Each is verified at
## the seam so a regression that re-freezes an asset lane fails the gate.
func _test_asset_seams() -> void:
	# --- Lane 1: ground tile seam -------------------------------------
	# An absent override leaves the procedural floor untouched...
	if not Art._ground_tileset("no_such_ground_zzz").is_empty():
		return _fail("ground tileset seam: absent kind should return {}")
	# ...and the procedural ground still bakes at the right size (6*16).
	var g := Art.ground("grass", "dirt", 6, 6, 3)
	if g == null or g.get_width() != 96 or g.get_height() != 96:
		return _fail("Art.ground broke (want 96x96, got %s)" % (g.get_size() if g else "null"))
	# The tiler blits a synthetic tileset across a fresh image.
	var tile := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	tile.fill(Color(1, 0, 0))  # pure red: exactly representable in RGBA8
	var ts := {"img": tile, "cell": 16, "cols": 1, "rows": 1}
	var canvas := Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	var trng := RandomNumberGenerator.new()
	Art._tile_fill(canvas, Rect2i(0, 0, 48, 48), ts, trng)
	var laid := canvas.get_pixel(24, 24)  # middle tile
	if laid.a < 0.9 or laid.r < 0.9 or laid.g > 0.02 or laid.b > 0.02:
		return _fail("ground _tile_fill did not lay the tile (got %s)" % laid)

	# --- Lane 3: animated scenery props -------------------------------
	# A synthetic 4-frame strip becomes a looping SpriteFrames.
	var strip := Image.create_empty(64, 16, false, Image.FORMAT_RGBA8)
	var strip_tex := ImageTexture.create_from_image(strip)
	var sf := Art._prop_frames("test_synth_prop", {"tex": strip_tex, "frames": 4, "fps": 6.0})
	if sf.get_frame_count("default") != 4 or not sf.get_animation_loop("default"):
		return _fail("animated-prop SpriteFrames wrong (frames/loop)")
	if sf.get_frame_texture("default", 0).get_size() != Vector2(16, 16):
		return _fail("animated-prop frame cell should be 16x16")
	# No strip -> null, so the static Sprite2D path stays.
	if Art.anim_prop("no_such_prop_zzz") != null:
		return _fail("anim_prop should be null when no _anim strip exists")
	# The prop-visual seam falls back to a static Sprite2D for plain props.
	var pv := game._prop_visual("rock")
	if not (pv is Sprite2D):
		return _fail("_prop_visual should return a static Sprite2D for a strip-less prop")
	pv.queue_free()

	# --- Lane 2: composite structures + wall decals -------------------
	var gate := game._add_structure("ruined_gate", Vector2(-4000, -4000))
	var gate_cols := 0
	var gate_vis := 0
	for c in gate.get_children():
		if c is CollisionShape2D:
			gate_cols += 1
		elif c is Sprite2D or c is AnimatedSprite2D:
			gate_vis += 1
	if gate_cols != 2:
		return _fail("ruined_gate should have a 2-shape composite footprint (got %d)" % gate_cols)
	if gate_vis < 4:  # base arch + 2 pillars + banner decal
		return _fail("ruined_gate should composite >=4 sprites (got %d)" % gate_vis)
	gate.queue_free()
	# A lit structure carries a point light (torch glow).
	var brazier := game._add_structure("watch_brazier", Vector2(-4200, -4200))
	var has_light := false
	for c in brazier.get_children():
		if c is PointLight2D:
			has_light = true
	if not has_light:
		return _fail("watch_brazier decal should carry a PointLight2D")
	brazier.queue_free()
	# An unlisted name degrades to a single base sprite + one footprint rect.
	var fallback := game._add_structure("rock", Vector2(-4400, -4400))
	var fb_cols := 0
	for c in fallback.get_children():
		if c is CollisionShape2D:
			fb_cols += 1
	if fb_cols != 1:
		return _fail("unlisted structure should degrade to one footprint collider (got %d)" % fb_cols)
	fallback.queue_free()
	print("ok: asset seams (ground tilesets / composite structures + decals / animated props)")


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


## Side-quest engine (flag-chain wrappers, Story.SIDE_QUESTS): accept ->
## step tracking -> single payout on the last step. Drives the pilot
## quest's flags by hand; SNAPSHOT + RESTORE shared state per the rule.
func _test_side_quests() -> void:
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var gold0: int = game.player.gold
	game.set_flag("sq_on_heron_feather")
	game.set_flag("hat_taken")
	if game.get_flag("sq_paid_heron_feather", false):
		_fail("side quest paid before all steps were done")
		await get_tree().create_timer(60.0).timeout
		return
	game.set_flag("hat_given")
	if not game.get_flag("sq_paid_heron_feather", false):
		_fail("side quest did not pay on its final step")
		await get_tree().create_timer(60.0).timeout
		return
	var gained: int = game.player.gold - gold0
	if gained <= 0:
		_fail("side quest completion paid no gold")
		await get_tree().create_timer(60.0).timeout
		return
	game.set_flag("some_unrelated_flag")
	if game.player.gold != gold0 + gained:
		_fail("side quest paid more than once")
		await get_tree().create_timer(60.0).timeout
		return
	game.player.gold = gold0
	game.flags = snap_flags
	print("ok: side quests (accept, step tracking, single payout)")


## Quest ABANDONMENT + DISCOVERY (2026-07-17). Two halves of one feature:
## a quest you accept and never finish is settled at the chapter's victory
## (the pledge you were PAID for is revoked, plus the lean for keeping it),
## and a quest nobody has offered you yet is discoverable rather than
## invisible. SNAPSHOT + RESTORE shared state per the rule.
func _test_quest_abandonment() -> void:
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var res0: float = game.player.resonance
	var snap_stand: Dictionary = game.player.faction_standing.duplicate(true)
	var ch0: String = game.chapter_id
	game.chapter_id = "ch1"

	# A finished quest is never charged for.
	game.set_flag("sq_on_oslas_debt")
	game.set_flag("sq_paid_oslas_debt")
	game.player.resonance = 0.0
	if not game._expire_side_quests().is_empty():
		_fail("a COMPLETED quest was billed as abandoned")
		await get_tree().create_timer(60.0).timeout
		return
	if game.player.resonance != 0.0:
		_fail("a completed quest moved resonance at chapter end")
		await get_tree().create_timer(60.0).timeout
		return

	# An accepted-and-dropped quest: the pledge goes back, plus the penalty.
	game.flags = snap_flags.duplicate(true)
	game.set_flag("sq_on_oslas_debt")
	game.flags["sq_pledge_oslas_debt"] = 1.0   # what the accept choice paid
	game.player.resonance = 0.0
	var broken: Array = game._expire_side_quests()
	if broken.size() != 1:
		_fail("an abandoned quest was not reported to the victory card")
		await get_tree().create_timer(60.0).timeout
		return
	var want: float = -(1.0 + Balance.QUEST_ABANDON_RESONANCE)
	if absf(game.player.resonance - want) > 0.01:
		_fail("abandon cost %.2f resonance, expected %.2f (pledge + penalty)"
			% [game.player.resonance, want])
		await get_tree().create_timer(60.0).timeout
		return
	# The line must NAME the quest — an unexplained resonance drop reads as a bug.
	if not String(broken[0]).contains(String(Story.ALL_SIDE_QUESTS["oslas_debt"]["name"])):
		_fail("the broken-promise line did not name the quest")
		await get_tree().create_timer(60.0).timeout
		return

	# Another chapter's open quest is NOT settled by this chapter's victory.
	# (still_blue is ch2's; heron_feather looks like a pilot but is ch1's.)
	game.flags = snap_flags.duplicate(true)
	game.set_flag("sq_on_still_blue")
	game.player.resonance = 0.0
	game._expire_side_quests()
	if game.player.resonance != 0.0:
		_fail("ch1's victory charged for a quest belonging to another chapter")
		await get_tree().create_timer(60.0).timeout
		return

	# DISCOVERY: every quest names a giver, so a ❢ always has somewhere to sit.
	for sqid in ["oslas_debt", "hunters_rounds", "flame_at_window"]:
		if Story.quest_givers(String(sqid)).is_empty():
			_fail("side quest '%s' has no giver convo — nothing to mark" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
	# Both directions of the index agree, and MULTI-giver quests keep every
	# giver — heron_feather is offered by the boy AND by two ways of finding
	# the hat, and an index that kept only the first would leave the props
	# unmarked and test the wrong NPC for reachability.
	if Story.quest_givers("heron_feather").size() < 2:
		_fail("multi-giver quest collapsed to one giver")
		await get_tree().create_timer(60.0).timeout
		return
	for giver in Story.quest_givers("oslas_debt"):
		if not Story.quests_offered_by(String(giver)).has("oslas_debt"):
			_fail("quest_givers / quests_offered_by disagree for '%s'" % giver)
			await get_tree().create_timer(60.0).timeout
			return
	# An ACCEPTED quest stops being "available" — the ❢ and the AVAILABLE
	# section must not keep advertising a job already in your log.
	game.flags = snap_flags.duplicate(true)
	game.set_flag("sq_on_oslas_debt")
	if game.side_quest_available("oslas_debt"):
		_fail("an accepted quest still advertised itself as available")
		await get_tree().create_timer(60.0).timeout
		return
	game.set_flag("sq_paid_oslas_debt")
	if game.side_quest_available("oslas_debt"):
		_fail("a completed quest still advertised itself as available")
		await get_tree().create_timer(60.0).timeout
		return

	game.chapter_id = ch0
	game.player.resonance = res0
	game.player.faction_standing = snap_stand
	game.flags = snap_flags
	game._quest_avail_cache = -1
	print("ok: quest abandonment (pledge revoked + penalty, chapter-scoped, named) + discovery")


## Q1 — Chapter 1 side quests (ch1_quests.gd): the module's convo
## overrides merged in, and each quest chain pays once on its last step.
## Drives the flags by hand; SNAPSHOT + RESTORE shared state per the rule.
func _test_ch1_quests() -> void:
	# Override nodes must be present in the merged convo table.
	for probe in [["wander_tinker", "t_debt"], ["wander_hunter", "h_rounds"],
			["wander_pilgrim", "p_give"], ["lore_hollow_oak", "l_debt"],
			["lore_ravine", "l_mark"], ["lore_drowned_chapel", "c_sign"],
			["lore_collapsed_tower", "t_sign"]]:
		var nodes: Dictionary = Story.ALL_CONVOS[probe[0]]["nodes"]
		if not nodes.has(probe[1]):
			_fail("ch1 quests: override node %s/%s missing" % [probe[0], probe[1]])
			await get_tree().create_timer(60.0).timeout
			return
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var gold0: int = game.player.gold
	var chains := {
		"oslas_debt": ["osla_pouch_taken", "osla_debt_paid"],
		"hunters_rounds": ["hunter_mark_ravine", "hunter_mark_chapel", "hunter_mark_tower"],
		"flame_at_window": ["pine_taken", "pine_lit"],
	}
	for qid in chains:
		var sid := String(qid)
		var before: int = game.player.gold
		game.set_flag("sq_on_" + sid)
		var steps: Array = chains[qid]
		for i in steps.size() - 1:
			game.set_flag(String(steps[i]))
			if game.get_flag("sq_paid_" + sid, false):
				_fail("ch1 quest '%s' paid before all steps were done" % sid)
				await get_tree().create_timer(60.0).timeout
				return
		game.set_flag(String(steps[steps.size() - 1]))
		if not game.get_flag("sq_paid_" + sid, false):
			_fail("ch1 quest '%s' did not pay on its final step" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		if game.player.gold <= before:
			_fail("ch1 quest '%s' completion paid no gold" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		var after: int = game.player.gold
		game.set_flag(String(steps[0]), true)  # re-fire the checker
		if game.player.gold != after:
			_fail("ch1 quest '%s' paid more than once" % sid)
			await get_tree().create_timer(60.0).timeout
			return
	game.player.gold = gold0
	game.flags = snap_flags
	print("ok: ch1 side quests (oslas_debt, hunters_rounds, flame_at_window — single payouts)")


# ---- Q4: Chapter 4 side quests (scripts/content/ch4_quests.gd) ----------
# Merge + chapter binding + quest items resolve, then drive each chain's
# flags and assert pay-on-last-step-only with a single payout.
func _test_ch4_quests() -> void:
	for sqid in ["out_of_tolerance", "nix_receipts", "quench_prayer"]:
		if not Story.ALL_SIDE_QUESTS.has(sqid):
			_fail("ch4 side quest '%s' not merged" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
		if String(Story.ALL_SIDE_QUESTS[sqid].get("chapter", "")) != "ch4":
			_fail("ch4 side quest '%s' not bound to ch4" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
	for qiid in ["slag_core", "nix_refund", "harl_token"]:
		if Items.make_quest_item(qiid).is_empty():
			_fail("ch4 quest item '%s' does not resolve" % qiid)
			await get_tree().create_timer(60.0).timeout
			return
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var gold0: int = game.player.gold
	var chains := {
		"out_of_tolerance": ["ch4_core_taken", "ch4_core_returned"],
		"nix_receipts": ["ch4_refund_taken", "ch4_refund_given"],
		"quench_prayer": ["ch4_token_taken", "ch4_token_left"],
	}
	for sqid in chains:
		var before: int = game.player.gold
		game.set_flag("sq_on_" + String(sqid))
		var steps: Array = chains[sqid]
		for i in steps.size() - 1:
			game.set_flag(String(steps[i]))
			if game.get_flag("sq_paid_" + String(sqid), false):
				_fail("ch4 quest '%s' paid before its final step" % sqid)
				await get_tree().create_timer(60.0).timeout
				return
		game.set_flag(String(steps[steps.size() - 1]))
		if not game.get_flag("sq_paid_" + String(sqid), false):
			_fail("ch4 quest '%s' did not pay on its final step" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
		var gained: int = game.player.gold - before
		if gained <= 0:
			_fail("ch4 quest '%s' completion paid no gold" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
		game.set_flag(String(steps[0]), true)  # re-fire the checker
		if game.player.gold != before + gained:
			_fail("ch4 quest '%s' paid more than once" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
	game.player.gold = gold0
	game.flags = snap_flags
	print("ok: ch4 side quests (out_of_tolerance, nix_receipts, quench_prayer - single payouts)")


# ---- (Q5) ch5_quests.gd content module: Long Sleep side quests -----------
# Registration + flag-chain drive for the three ch5 quests; snapshot and
# restore shared state (flags, gold, standings) per the board's rule 9.
func _test_ch5_quests() -> void:
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var snap_standing: Dictionary = game.player.faction_standing.duplicate(true)
	var gold0: int = game.player.gold
	for sqid in ["ch5_forty_mouths", "ch5_spring_song", "ch5_count_sleepers"]:
		if not Story.ALL_SIDE_QUESTS.has(sqid):
			_fail("ch5 side quest '%s' not registered" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
	for qid in ["ch5_grain_bundle", "ch5_spring_verse"]:
		if Items.make_quest_item(qid).is_empty():
			_fail("ch5 quest item '%s' not registered" % qid)
			await get_tree().create_timer(60.0).timeout
			return
	# The module's convo overrides must have landed with their quest
	# hooks intact (each probe node exists only in the override).
	for probe in [["ch5_briefing", "sq_hub"], ["ch5_shrine_wagon", "w_road"],
			["ch5_lore_chapel", "l_count"], ["ch5_lore_vein", "l_one"],
			["ch5_wander_skald", "k_write"], ["ch5_mother", "m_song"]]:
		var conv: Dictionary = Story.ALL_CONVOS.get(probe[0], {})
		var nodes: Dictionary = conv.get("nodes", {})
		if not nodes.has(probe[1]):
			_fail("ch5 convo override '%s' lost its '%s' hook" % [probe[0], probe[1]])
			await get_tree().create_timer(60.0).timeout
			return
	# Drive each chain: no early payout, pays once on the last step.
	var chains := {
		"ch5_forty_mouths": ["ch5_grain_taken", "ch5_grain_given"],
		"ch5_spring_song": ["ch5_verse_taken", "ch5_verse_given"],
		"ch5_count_sleepers": ["ch5_census_chapel", "ch5_census_vein", "ch5_census_told"],
	}
	for sqid in chains:
		var before: int = game.player.gold
		game.set_flag("sq_on_" + String(sqid))
		var steps: Array = chains[sqid]
		for i in steps.size() - 1:
			game.set_flag(String(steps[i]))
			if game.get_flag("sq_paid_" + String(sqid), false):
				_fail("ch5 quest '%s' paid before its final step" % sqid)
				await get_tree().create_timer(60.0).timeout
				return
		game.set_flag(String(steps[steps.size() - 1]))
		if not game.get_flag("sq_paid_" + String(sqid), false):
			_fail("ch5 quest '%s' did not pay on its final step" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
		var gained: int = game.player.gold - before
		if gained <= 0:
			_fail("ch5 quest '%s' completion paid no gold" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
		game.set_flag(String(steps[0]), true)  # re-fire the checker
		if game.player.gold != before + gained:
			_fail("ch5 quest '%s' paid more than once" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
	# Forty Mouths carries the wildfang standing reward (+4).
	if int(game.player.faction_standing.get("wildfang", 0)) != int(snap_standing.get("wildfang", 0)) + 4:
		_fail("ch5 forty_mouths did not pay its wildfang standing")
		await get_tree().create_timer(60.0).timeout
		return
	game.player.gold = gold0
	game.player.faction_standing = snap_standing
	game.flags = snap_flags
	print("ok: ch5 side quests (forty_mouths, spring_song, count_sleepers - single payouts)")


## Q3 (ch3_quests.gd): the Vale's three side quests pay once each on
## their final flag. Drives each chain by hand via set_flag; SNAPSHOT +
## RESTORE shared state per the board rule.
func _test_ch3_quests() -> void:
	# Module merge sanity: quest defs, convo overrides and keepsake defs
	# must all have landed over ch3_zones (module order in CONTENT_MODULES).
	if not Story.ALL_SIDE_QUESTS.has("ch3_unfilled_row"):
		_fail("ch3 quests: SIDE_QUESTS did not merge")
		await get_tree().create_timer(60.0).timeout
		return
	if not Story.ALL_CONVOS["ch3_briefing"]["nodes"].has("q_hub"):
		_fail("ch3 quests: briefing override did not merge (module must preload AFTER ch3_zones)")
		await get_tree().create_timer(60.0).timeout
		return
	if Items.make_quest_item("vale_bread").is_empty() \
			or Items.make_quest_item("sexton_stone").is_empty():
		_fail("ch3 quests: QUEST_ITEMS did not merge")
		await get_tree().create_timer(60.0).timeout
		return
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var gold0: int = game.player.gold
	var chains := {
		"ch3_unfilled_row": ["row_copied_chapel", "row_copied_reliquary", "row_reported"],
		"ch3_bread_kneeling": ["vale_bread_left"],
		"ch3_sexton_stone": ["sexton_stone_left"],
	}
	for sqid in chains:
		var before: int = game.player.gold
		game.set_flag("sq_on_" + String(sqid))
		var steps: Array = chains[sqid]
		for i in steps.size() - 1:
			game.set_flag(String(steps[i]))
			if game.get_flag("sq_paid_" + String(sqid), false):
				_fail("ch3 quest '%s' paid before its final step" % sqid)
				await get_tree().create_timer(60.0).timeout
				return
		game.set_flag(String(steps[steps.size() - 1]))
		if not game.get_flag("sq_paid_" + String(sqid), false):
			_fail("ch3 quest '%s' did not pay on its final step" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
		var gained: int = game.player.gold - before
		if gained <= 0:
			_fail("ch3 quest '%s' completion paid no gold" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
		game.set_flag(String(steps[0]), true)  # re-fire the checker
		if game.player.gold != before + gained:
			_fail("ch3 quest '%s' paid more than once" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
	game.player.gold = gold0
	game.flags = snap_flags
	print("ok: ch3 side quests (unfilled_row, bread_kneeling, sexton_stone — single payouts)")


## Q2 — Chapter 2 side quests (ch2_quests.gd): the module's convo
## overrides merged in (over ch2_hub/ch2_zones_act2/ch2_aldric), quest
## items resolve, and each chain pays once on its last step. Drives the
## flags by hand; SNAPSHOT + RESTORE shared state per the rule.
func _test_ch2_quests() -> void:
	# Override nodes must be present in the merged convo table.
	for probe in [["ch2_refugee", "r_accept"], ["ch2_refugee", "r_after"],
			["ch2_scholar", "s_desk"], ["ch2_scholar", "s_jar"],
			["ch2_aldric", "p_ash"]]:
		var nodes: Dictionary = Story.ALL_CONVOS[probe[0]]["nodes"]
		if not nodes.has(probe[1]):
			_fail("ch2 quests: override node %s/%s missing (module must preload AFTER the ch2 modules)" % [probe[0], probe[1]])
			await get_tree().create_timer(60.0).timeout
			return
	for qiid in ["sera_loaf", "bastion_ash"]:
		if Items.make_quest_item(String(qiid)).is_empty():
			_fail("ch2 quest item '%s' does not resolve" % qiid)
			await get_tree().create_timer(60.0).timeout
			return
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var snap_standing: Dictionary = game.player.faction_standing.duplicate(true)
	var gold0: int = game.player.gold
	var chains := {
		"still_blue": ["mill_seen", "mill_told"],
		"bread_for_the_road": ["loaf_taken", "loaf_given"],
		"ash_for_aldric": ["ash_taken", "ash_given"],
	}
	for sqid in chains:
		var sid := String(sqid)
		var steps: Array = chains[sqid]
		for f in steps:  # an earlier suite walk may have left step flags set
			game.flags.erase(String(f))
		var before: int = game.player.gold
		game.set_flag("sq_on_" + sid)
		for i in steps.size() - 1:
			game.set_flag(String(steps[i]))
			if game.get_flag("sq_paid_" + sid, false):
				_fail("ch2 quest '%s' paid before its final step" % sid)
				await get_tree().create_timer(60.0).timeout
				return
		game.set_flag(String(steps[steps.size() - 1]))
		if not game.get_flag("sq_paid_" + sid, false):
			_fail("ch2 quest '%s' did not pay on its final step" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		var gained: int = game.player.gold - before
		if gained <= 0:
			_fail("ch2 quest '%s' completion paid no gold" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		game.set_flag(String(steps[0]), true)  # re-fire the checker
		if game.player.gold != before + gained:
			_fail("ch2 quest '%s' paid more than once" % sid)
			await get_tree().create_timer(60.0).timeout
			return
	# The bread courier's reward carries its Accord standing shift.
	if int(game.player.faction_standing.get("accord", 0)) != int(snap_standing.get("accord", 0)) + 2:
		_fail("ch2 quests: bread_for_the_road did not pay its Accord standing")
		await get_tree().create_timer(60.0).timeout
		return
	game.player.gold = gold0
	game.player.faction_standing = snap_standing
	game.flags = snap_flags
	print("ok: ch2 side quests (still_blue, bread_for_the_road, ash_for_aldric — single payouts)")


# ---- Q6: Chapter 6 side quests (scripts/content/ch6_quests.gd) ----------
# Merge + chapter binding + override nodes + quest item resolve, then
# drive each chain's flags and assert pay-on-last-step-only, single
# payout, and the standing rewards. SNAPSHOT + RESTORE flags, gold AND
# faction standings (two of the rewards shift standings).
func _test_ch6_quests() -> void:
	for sqid in ["ch6_far_shore", "ch6_gate_bread", "ch6_kesh_tally"]:
		if not Story.ALL_SIDE_QUESTS.has(sqid):
			_fail("ch6 side quest '%s' not merged" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
		if String(Story.ALL_SIDE_QUESTS[sqid].get("chapter", "")) != "ch6":
			_fail("ch6 side quest '%s' not bound to ch6" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
	if Items.make_quest_item("ch6_gate_loaf").is_empty():
		_fail("ch6 quest item 'ch6_gate_loaf' does not resolve")
		await get_tree().create_timer(60.0).timeout
		return
	# Override nodes must be present in the merged convo table (module
	# must preload AFTER ch6_zones so its CONVOS win the merge).
	for probe in [["ch6_fisher", "f_quest"], ["ch6_fisher", "f_report"],
			["ch6_briefing", "b_gate"], ["ch6_wildfang", "k_offer"],
			["ch6_wildfang", "k_tally2"], ["ch6_lore_gallery", "g_door"],
			["ch6_lore_shrine", "sh_mark"], ["ch6_shrine_pool", "p_mark"],
			["ch6_shrine_schism", "s_loaf"]]:
		var nodes: Dictionary = Story.ALL_CONVOS[probe[0]]["nodes"]
		if not nodes.has(probe[1]):
			_fail("ch6 quests: override node %s/%s missing" % [probe[0], probe[1]])
			await get_tree().create_timer(60.0).timeout
			return
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var snap_standing: Dictionary = game.player.faction_standing.duplicate(true)
	var gold0: int = game.player.gold
	var chains := {
		"ch6_far_shore": ["sq6_shore_seen", "sq6_shore_told"],
		"ch6_gate_bread": ["sq6_bread_taken", "sq6_bread_left"],
		"ch6_kesh_tally": ["sq6_tally_shrine", "sq6_tally_pool", "sq6_tally_told"],
	}
	for sqid in chains:
		var sid := String(sqid)
		var steps: Array = chains[sqid]
		for f in steps:  # an earlier suite walk may have left step flags set
			game.flags.erase(String(f))
		var before: int = game.player.gold
		game.set_flag("sq_on_" + sid)
		for i in steps.size() - 1:
			game.set_flag(String(steps[i]))
			if game.get_flag("sq_paid_" + sid, false):
				_fail("ch6 quest '%s' paid before its final step" % sid)
				await get_tree().create_timer(60.0).timeout
				return
		game.set_flag(String(steps[steps.size() - 1]))
		if not game.get_flag("sq_paid_" + sid, false):
			_fail("ch6 quest '%s' did not pay on its final step" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		var gained: int = game.player.gold - before
		if gained <= 0:
			_fail("ch6 quest '%s' completion paid no gold" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		game.set_flag(String(steps[0]), true)  # re-fire the checker
		if game.player.gold != before + gained:
			_fail("ch6 quest '%s' paid more than once" % sid)
			await get_tree().create_timer(60.0).timeout
			return
	# Standing rewards landed: bread -> choir +2, tally -> wildfang +3.
	var d_choir: int = int(game.player.faction_standing.get("choir", 0)) - int(snap_standing.get("choir", 0))
	var d_wf: int = int(game.player.faction_standing.get("wildfang", 0)) - int(snap_standing.get("wildfang", 0))
	if d_choir != 2 or d_wf != 3:
		_fail("ch6 quest standings wrong (choir %+d, wildfang %+d)" % [d_choir, d_wf])
		await get_tree().create_timer(60.0).timeout
		return
	game.player.gold = gold0
	game.player.faction_standing = snap_standing
	game.flags = snap_flags
	print("ok: ch6 side quests (ch6_far_shore, ch6_gate_bread, ch6_kesh_tally — single payouts + standings)")


# ---- Q7: Chapter 7 side quests (scripts/content/ch7_quests.gd) ----------
# Drives each quest's flag chain directly (steps land in any order for
# the relay rounds), asserts single payout per quest, the wildfang
# standing rider on Korrag's due, and that the module's keepsakes resolve.
func _test_ch7_quests() -> void:
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var snap_standing: Dictionary = game.player.faction_standing.duplicate(true)
	var gold0: int = game.player.gold
	for iid in ["ch7_void_letter", "ch7_korrag_token"]:
		if Items.make_quest_item(String(iid)).is_empty():
			_fail("ch7 quest item '%s' did not resolve" % iid)
			await get_tree().create_timer(60.0).timeout
			return
	var chains := {
		"ch7_relay_stands": ["sq7_relay_cairn", "sq7_relay_shelf", "sq7_relay_vowstone"],
		"ch7_void_letter": ["sq7_letter_taken", "sq7_letter_given"],
		"ch7_korrags_due": ["sq7_token_taken", "sq7_token_left"],
	}
	for sqid in chains:
		var sid := String(sqid)
		var before: int = game.player.gold
		game.set_flag("sq_on_" + sid)
		var steps: Array = chains[sqid]
		for i in steps.size() - 1:
			game.set_flag(String(steps[i]))
			if game.get_flag("sq_paid_" + sid, false):
				_fail("ch7 quest '%s' paid before its final step" % sid)
				await get_tree().create_timer(60.0).timeout
				return
		game.set_flag(String(steps[steps.size() - 1]))
		if not game.get_flag("sq_paid_" + sid, false):
			_fail("ch7 quest '%s' did not pay on its final step" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		var gained: int = game.player.gold - before
		if gained <= 0:
			_fail("ch7 quest '%s' completion paid no gold" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		game.set_flag(String(steps[0]), true)  # re-fire the checker
		if game.player.gold != before + gained:
			_fail("ch7 quest '%s' paid more than once" % sid)
			await get_tree().create_timer(60.0).timeout
			return
	# Korrag's due carries its Wildfang standing shift.
	var d_wf: int = int(game.player.faction_standing.get("wildfang", 0)) - int(snap_standing.get("wildfang", 0))
	if d_wf != 4:
		_fail("ch7 quests: korrags_due paid the wrong Wildfang standing (%+d)" % d_wf)
		await get_tree().create_timer(60.0).timeout
		return
	game.player.gold = gold0
	game.player.faction_standing = snap_standing
	game.flags = snap_flags
	print("ok: ch7 side quests (relay_stands, void_letter, korrags_due — single payouts + standing)")


## (P1, promises_kept.gd): dialogue promises now have deliveries.
## Asserts the module's merges (side quests, convo overrides, beat
## variants, zone flag/prop hooks), then drives both quest chains by
## hand via set_flag. SNAPSHOT + RESTORE shared state per the rule.
func _test_promises_kept() -> void:
	# Module merge sanity: quests, convo overrides, beats, zone hooks.
	for sqid in ["ch3_facing_home", "ch4_nine_names"]:
		if not Story.ALL_SIDE_QUESTS.has(sqid):
			_fail("promises: side quest '%s' not registered" % sqid)
			await get_tree().create_timer(60.0).timeout
			return
	# Each probe node exists only in this module's override.
	for probe in [["ch3_refugee", "r_tell"], ["ch3_lore_alder", "a_home"],
			["ch4_survivor", "s_carve"], ["ch5_wander_skald", "k_fee"]]:
		var conv: Dictionary = Story.ALL_CONVOS.get(probe[0], {})
		var nodes: Dictionary = conv.get("nodes", {})
		if not nodes.has(probe[1]):
			_fail("promises: convo override '%s' lost its '%s' hook (module must preload LAST)" % [probe[0], probe[1]])
			await get_tree().create_timer(60.0).timeout
			return
	# The mute widow's thanks now waits on the deed (vess_dead variant first).
	var mute_variants: Array = Story.ALL_CONVOS["ch3_wander_mute"]["nodes"]["m1"].get("variants", [])
	if mute_variants.is_empty() or String(mute_variants[0].get("flag", "")) != "vess_dead":
		_fail("promises: ch3_wander_mute thanks is not gated on vess_dead")
		await get_tree().create_timer(60.0).timeout
		return
	# Ansa's criers promise carries its beat flag.
	var m_kind_flags: Dictionary = Story.ALL_CONVOS["ch5_mother"]["nodes"]["m1"]["choices"][0].get("flags", {})
	if not m_kind_flags.get("chose_criers_promised", false):
		_fail("promises: ch5_mother criers choice lost chose_criers_promised")
		await get_tree().create_timer(60.0).timeout
		return
	# Beat variants resolve through beat_for (flag set -> variant; unset -> base).
	for bt in [["post_cinderhide", "ch4_petra_told"],
			["epilogue_ch5", "chose_criers_promised"],
			["epilogue_ch6", "chose_kaethra_sheathed"],
			["epilogue_ch6", "chose_kaethra_struck"],
			["pre_stormmouth", "chose_carried_lines"]]:
		var base: Array = Story.beat_for(String(bt[0]), "neutral", {})
		var flagged: Array = Story.beat_for(String(bt[0]), "neutral", {String(bt[1]): true})
		if flagged.is_empty() or flagged == base:
			_fail("promises: beat variant '%s@flag:%s' did not resolve" % [bt[0], bt[1]])
			await get_tree().create_timer(60.0).timeout
			return
	# Zone hooks: the boss rooms carry their promise flags, and the Alder
	# Row prop stands in the Misted Fields.
	var vess_ok := false
	var alder_ok := false
	for z in Story.chapter("ch3")["zones"]:
		if String(z.get("boss", "")) == "vess" and String(z.get("clear_flag", "")) == "vess_dead":
			vess_ok = true
		for npc in z.get("npcs", []):
			if String(npc.get("convo", "")) == "ch3_lore_alder":
				alder_ok = true
	if not vess_ok or not alder_ok:
		_fail("promises: ch3 zone hooks missing (vess clear_flag %s, alder prop %s)" % [vess_ok, alder_ok])
		await get_tree().create_timer(60.0).timeout
		return
	var vents_ok := false
	for z in Story.chapter("ch4")["zones"]:
		if String(z.get("boss", "")) == "cinderhide" and String(z.get("clear_flag", "")) == "ch4_vents_capped":
			vents_ok = true
	if not vents_ok:
		_fail("promises: ch4 Deep Vents clear_flag missing")
		await get_tree().create_timer(60.0).timeout
		return
	# Drive both chains: no early payout, pays once on the last step.
	var snap_flags: Dictionary = game.flags.duplicate(true)
	var gold0: int = game.player.gold
	var chains := {
		"ch3_facing_home": ["ch3_fenna_son_rested", "ch3_fenna_told"],
		"ch4_nine_names": ["ch4_vents_capped", "ch4_names_carved"],
	}
	for sqid in chains:
		var sid := String(sqid)
		var before: int = game.player.gold
		game.set_flag("sq_on_" + sid)
		var steps: Array = chains[sqid]
		for i in steps.size() - 1:
			game.set_flag(String(steps[i]))
			if game.get_flag("sq_paid_" + sid, false):
				_fail("promises: quest '%s' paid before its final step" % sid)
				await get_tree().create_timer(60.0).timeout
				return
		game.set_flag(String(steps[steps.size() - 1]))
		if not game.get_flag("sq_paid_" + sid, false):
			_fail("promises: quest '%s' did not pay on its final step" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		var gained: int = game.player.gold - before
		if gained <= 0:
			_fail("promises: quest '%s' completion paid no gold" % sid)
			await get_tree().create_timer(60.0).timeout
			return
		game.set_flag(String(steps[0]), true)  # re-fire the checker
		if game.player.gold != before + gained:
			_fail("promises: quest '%s' paid more than once" % sid)
			await get_tree().create_timer(60.0).timeout
			return
	game.player.gold = gold0
	game.flags = snap_flags
	print("ok: promises kept (facing_home, nine_names — single payouts; beat variants resolve)")


func _test_promises_kept_2() -> void:
	# (P2) Osk's count: the override must win (f_down/f_thanks exist), the
	# delivery is gated on vess_dead, and the words nudge dropped to 2.0.
	var osk: Dictionary = Story.ALL_CONVOS.get("ch3_wander_defector", {})
	var onodes: Dictionary = osk.get("nodes", {})
	if not onodes.has("f_down") or not onodes.has("f_thanks"):
		_fail("promises2: ch3_wander_defector missing f_down/f_thanks (module must preload LAST)")
		await get_tree().create_timer(60.0).timeout
		return
	var has_vess := false
	for v in onodes["f1"].get("variants", []):
		if String(v.get("flag", "")) == "vess_dead" and String(v.get("next", "")) == "f_down":
			has_vess = true
	if not has_vess:
		_fail("promises2: Osk delivery not gated on vess_dead -> f_down")
		await get_tree().create_timer(60.0).timeout
		return
	if float(onodes["f1"]["choices"][0].get("resonance", 0.0)) != 2.0:
		_fail("promises2: Osk words nudge should be 2.0 (larger shift moved to delivery)")
		await get_tree().create_timer(60.0).timeout
		return
	if float(onodes["f_down"]["choices"][0].get("resonance", 0.0)) != 3.0:
		_fail("promises2: Osk delivery choice should carry the 3.0 resonance")
		await get_tree().create_timer(60.0).timeout
		return
	# The kneeling field's claim pays off at the ch3 finale (beat variant).
	var base: Array = Story.beat_for("epilogue_ch3", "neutral", {})
	var flagged: Array = Story.beat_for("epilogue_ch3", "neutral", {"chose_told_congregation": true})
	if flagged.is_empty() or flagged == base:
		_fail("promises2: epilogue_ch3@flag:chose_told_congregation did not resolve")
		await get_tree().create_timer(60.0).timeout
		return
	print("ok: promises kept 2 (Osk's falling count on vess_dead; kneeling-field epilogue beat)")


# ---- CORE: merchant economy (round 51) — FARM-COST pricing, act-gated
# grades, upgrade curve, bag=1g, sell basis + quest-item guard --------------
func _test_merchant_economy() -> void:
	var p := game.player

	# N_runs math: ceil((1/chance)/3 bosses). B=1 run, A(1/10)=4, S=9, S-wpn=17.
	if Balance.farm_runs(1.0 / 3.0) != 1 or Balance.farm_runs(1.0 / 10.0) != 4:
		return _fail("farm_runs off for B / A")
	if Balance.farm_runs(1.0 / 25.0) != 9 or Balance.farm_runs(1.0 / 25.0 * Balance.S_WEAPON_DROP_WEIGHT) != 17:
		return _fail("farm_runs off for S / S-weapon (should be 9 / 17)")

	# Chapter boss gear odds (2026-07-09 bands): ch3 bosses drop D only; ch6+ add A.
	if Balance.boss_gear_odds("ch3").has("A") or not Balance.boss_gear_odds("ch3").has("D"):
		return _fail("ch3 boss gear table wrong (should be D only)")
	if not Balance.boss_gear_odds("ch6").has("A") or not Balance.boss_gear_odds("ch7").has("A"):
		return _fail("ch6/ch7 bosses must be able to drop A")

	# loot_cap ceilings come from the band tables now (ch1 F, ch7 B).
	if Balance.chapter_gear_ceiling("ch1") != "F" or Balance.chapter_gear_ceiling("ch7") != "B":
		return _fail("chapter_gear_ceiling wrong (ch1 should be F, ch7 B)")

	# Farm-cost formula: the chapter's boss-tier grade == (first + (N-1)*replay)*tax.
	# ch3's boss tier is D (odds 1/3 -> N=1), so D@ch3 == first*tax.
	var e3: Dictionary = Balance.CHAPTER_ECON["ch3"]
	var expect_d: int = int(round(float(e3["first"]) * Balance.FARM_TAX))
	var d3: int = Items.shop_buy_price({"grade": "D", "slot": "armor", "plus": 0}, "ch3")
	if d3 != expect_d:
		return _fail("farm-cost D@ch3 = %d, expected %d" % [d3, expect_d])
	# A commodity grade below the boss tier (F in ch3) stays cheap flat — under D.
	if Items.shop_buy_price({"grade": "F", "slot": "armor", "plus": 0}, "ch3") >= d3:
		return _fail("commodity F priced >= farm-cost D")

	# Drop-channel rolls: general/shop grade stays in the chapter band; boss gear
	# rolls a boss-table grade (or nothing); an exact-grade roll is exact.
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in 150:
		if not Balance.gear_weights("ch3").has(Items.roll_shop_grade("ch3", rng)):
			return _fail("shop stock grade left the ch3 general band")
		var bg := Items.roll_boss_gear_grade("ch7", rng)
		if bg != "" and not Balance.boss_weights("ch7").has(bg):
			return _fail("boss gear rolled a grade off the ch7 boss table")
	if String(Items.roll_gear_of_grade("A", rng, "warrior")["grade"]) != "A":
		return _fail("roll_gear_of_grade produced the wrong grade")

	# Upgrade curve: C +0->+1 = 24g; an S step is exactly 8x a C step.
	var cstep: int = Items.upgrade_cost({"grade": "C", "plus": 0})
	var sstep: int = Items.upgrade_cost({"grade": "S", "plus": 0})
	if cstep != 24 or sstep != cstep * 8:
		return _fail("upgrade curve off (C step %d, S step %d)" % [cstep, sstep])
	# Cost exponent bites: an S step at +9 must be much steeper than linear (10^1.5x base).
	if Items.upgrade_cost({"grade": "S", "plus": 9}) < sstep * 30:
		return _fail("upgrade cost exponent too shallow at high plus")
	# Grade caps and the failure curve (upgrade-rework 2026-07-13).
	if Balance.max_plus("S") != 20 or Balance.max_plus("C") != 10:
		return _fail("MAX_PLUS caps wrong (S %d, C %d)" % [Balance.max_plus("S"), Balance.max_plus("C")])
	if not Items.can_upgrade({"grade": "S", "plus": 19}) or Items.can_upgrade({"grade": "S", "plus": 20}):
		return _fail("can_upgrade ignores the S cap")
	if Balance.upgrade_success(0) < 1.0 or Balance.upgrade_success(3) < 1.0:
		return _fail("early upgrades must be guaranteed")
	if Balance.upgrade_success(19) != Balance.UPGRADE_MIN_SUCCESS:
		return _fail("S cap success should hit the floor (%.2f)" % Balance.upgrade_success(19))
	# +5% per plus, applied to EVERY rolled stat: a +10 item carries +50% of its
	# main AND +50% of each sub (gems stay flat).
	var up_item: Dictionary = Items.roll_item_of("weapon", "A", RandomNumberGenerator.new(), "warrior")
	var main_key: String = String(up_item["main"].keys()[0])
	var base_main: float = float(up_item["main"][main_key])
	var sub_key: String = String(up_item["subs"].keys()[0])
	var base_sub: float = float(up_item["subs"][sub_key])
	up_item["plus"] = 10
	var out10: Dictionary = Items.stats_of(up_item)
	if not is_equal_approx(float(out10.get(main_key, 0.0)), base_main * 1.5):
		return _fail("+plus main-stat bonus is not +5%%/plus")
	if not is_equal_approx(float(out10.get(sub_key, 0.0)), base_sub * 1.5):
		return _fail("+plus does not scale substats (should be +5%%/plus on all rolled stats)")

	# Add-socket is steep + tier-scaled (upgrade-rework 2026-07-13).
	if Items.reforge_cost({"grade": "A"}, "socket") != Balance.ADD_SOCKET_COST["A"]:
		return _fail("add-socket cost not sourced from ADD_SOCKET_COST")
	# Quench keeps the higher roll — never regresses, never exceeds the band max.
	var q_item: Dictionary = Items.roll_item_of("weapon", "A", RandomNumberGenerator.new(), "archer")
	if not Items.can_quench(q_item, main_key if q_item["main"].has(main_key) else String(q_item["main"].keys()[0])):
		return _fail("main stat should be quenchable")
	var qkey: String = String(q_item["main"].keys()[0])
	var qrng := RandomNumberGenerator.new()
	qrng.seed = 99
	q_item["main"][qkey] = float(Items.stat_band(q_item, qkey)[0])   # start at the band floor
	var qmax: float = float(Items.stat_band(q_item, qkey)[1])
	var prev: float = float(q_item["main"][qkey])
	for i in 40:
		var r: Dictionary = Items.quench_stat(q_item, qkey, qrng)
		if float(r["kept"]) < prev - 0.001 or float(r["kept"]) > qmax + 0.001:
			return _fail("quench regressed or exceeded band max")
		prev = float(r["kept"])
	if prev <= float(Items.stat_band(q_item, qkey)[0]) + 0.001:
		return _fail("40 quenches never improved the floor roll")
	# Quench cost escalates toward the band max (expensive to perfect, cheap to fix).
	var qc_item: Dictionary = Items.roll_item_of("weapon", "A", RandomNumberGenerator.new(), "archer")
	var qck: String = String(qc_item["main"].keys()[0])
	var qcb := Items.stat_band(qc_item, qck)
	qc_item["main"][qck] = float(qcb[0])   # at the floor
	var cost_lo: int = Items.quench_cost(qc_item, qck)
	qc_item["main"][qck] = float(qcb[1])   # at the max
	var cost_hi: int = Items.quench_cost(qc_item, qck)
	if cost_lo != int(Balance.QUENCH_COST_BASE["A"]) or cost_hi <= cost_lo:
		return _fail("quench cost should start at base (%d) and escalate to the max (got %d->%d)" % [int(Balance.QUENCH_COST_BASE["A"]), cost_lo, cost_hi])

	# Bags cash out for exactly 1g (anti-exploit), never the sell formula.
	if Balance.BAG_SELL_GOLD != 1:
		return _fail("bag sell gold != 1")

	# Gem BUY (farm-cost) sits well ABOVE gem SELL (0.45 x intrinsic) — no pump.
	if Balance.gem_gold_value(2) <= Balance.gem_gold_value(1):
		return _fail("gem gold value not monotonic in level")
	var gem_market: int = int(Balance.gem_gold_value(2))
	var gem_sell: int = int(Balance.gem_gold_value(2) * Balance.MERCHANT_SELL_FRACTION)
	if gem_sell <= 0 or gem_sell >= gem_market:
		return _fail("gem sell value not a sub-market fraction")
	if Items.gem_buy_price(1, "ch3") <= int(Balance.gem_gold_value(1) * Balance.MERCHANT_SELL_FRACTION):
		return _fail("gem buy (farm-cost) not above gem sell")

	# Sell-eligibility (menus.open_shop): ONLY ids in CONSUMABLE_PRICES.
	# Elite utility + quest keepsakes have no market price -> unsellable.
	for cid in ["mana_potion", "elixir_might", "elixir_ward", "renewal_draught", "recall_scroll"]:
		if not Balance.CONSUMABLE_PRICES.has(cid):
			return _fail("merchant consumable %s missing a price" % cid)
	if Balance.CONSUMABLE_PRICES.has("reset_stone") or Balance.CONSUMABLE_PRICES.has("tree_tome"):
		return _fail("elite utility became sellable")
	var qi := Items.make_quest_item("millers_hat")
	if qi.is_empty() or Balance.CONSUMABLE_PRICES.has(String(qi.get("id", ""))):
		return _fail("quest keepsake is sellable")

	# New consumables apply their effect and are consumed.
	var keep_cons: Array = p.consumables.duplicate()
	var keep_dr: float = p.dr_time
	var keep_dra: float = p.dr_amt
	var keep_hp: float = p.hp
	p.consumables = []

	p.dr_time = 0.0
	var ward := Items.make_elixir_ward()
	p.consumables.append(ward)
	p.use_consumable(ward)
	if p.dr_time <= 0.0 or not is_equal_approx(p.dr_amt, Balance.ELIXIR_WARD_AMT) or p.consumables.has(ward):
		return _fail("elixir of warding did not apply / wasn't consumed")

	p.hp = maxf(1.0, p.max_hp * 0.25)
	var before: float = p.hp
	var draught := Items.make_renewal_draught()
	p.consumables.append(draught)
	p.use_consumable(draught)
	if p.hp <= before or p.consumables.has(draught):
		return _fail("draught of renewal did not heal / wasn't consumed")

	# Restore.
	p.consumables = keep_cons
	p.dr_time = keep_dr
	p.dr_amt = keep_dra
	p.hp = keep_hp
	print("ok: merchant economy (farm-cost buy, act-gated grades, upgrade curve, bag=1g, sell + quest-item guard, ward+renewal)")


# ---- MP-08: Play Together lobby + codex co-op page (render smoke) --------
# Pre-session UI only — every screen must BUILD offline; no sockets here
# (net_test.bat owns the live-session assertions). The codex gained a
# Co-op tab in the same change (the codex-staleness rule), so it renders
# under the same eyes as the other tabs.
func _test_mp_lobby_ui() -> void:
	game.menus.open_codex("coop")
	await _frames(2)
	if game.menus.current != "codex":
		return _fail("codex Co-op page did not open")
	game.menus.open_lobby()
	await _frames(2)
	if game.menus.current != "lobby":
		return _fail("Play Together menu did not open")
	game.menus.open_lobby("join")
	await _frames(2)
	if game.menus.current != "lobby" or String(game.menus.lobby.get("stage", "")) != "join":
		return _fail("join-code screen did not open")
	# Empty roster under no_saves: the hero pick renders its fallback note.
	game.menus.open_lobby("char")
	await _frames(2)
	if game.menus.current != "lobby" or String(game.menus.lobby.get("stage", "")) != "char":
		return _fail("hero-pick screen did not open")
	game.menus.close()
	await _frames(2)
	if game.menus.is_open():
		return _fail("lobby did not close cleanly")
	print("ok: Play Together lobby screens + codex co-op page render (offline)")


## The touch HUD's OVERLAY GATE (2026-07-17). The suite runs WITHOUT --touch, so
## a TouchHud never mounts on its own and the whole touch layer had no coverage —
## which is exactly how this bug shipped. Mounts one through the real
## _apply_touch_mode path (that also puts the keyboard ability bar back on
## teardown), then asserts the controls go dead under a menu / dialogue / choice
## while the world is NOT paused.
##
## "Overlay up + world still running" is a CO-OP-only state: §5.4 makes
## request_pause(true) a no-op in a session, and the tree pause used to be the
## ONLY thing stopping this node — so the joystick (the whole left half of the
## screen) stayed live UNDER the menu's dim and a drag walked your hero
## mid-fight. Solo pauses, so the bug is unreachable unless the unpause is forced
## the way this does. It was invisible in both cheap tests too: solo-on-phone
## pauses, and co-op-on-desktop has no touch HUD.
##
## Touches go into _input() DIRECTLY on purpose: Input.parse_input_event does NOT
## reach _input headless — the throwaway rig that used it passed even with the
## gate REMOVED. The first assertion is a live-control check for that same
## reason: if the joystick ever stops writing intents for an unrelated reason,
## every "stayed still" assert below would pass vacuously.
func _test_touch_overlay_gate() -> void:
	var touch_was: bool = game.touch_mode
	var paused_was: bool = get_tree().paused
	game.touch_mode = true
	game._apply_touch_mode()
	await _frames(2)
	var th: TouchHud = game._touch_hud
	if th == null:
		return _fail("touch gate: TouchHud did not mount under touch_mode")
	var mi: Node = get_node_or_null("/root/MobileInput")
	if mi == null:
		return _fail("touch gate: MobileInput autoload missing")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var jp: Vector2 = Vector2(vp.x * 0.22, vp.y * 0.72)   # left half, below 30% = joystick zone
	var jp2: Vector2 = jp + Vector2(90.0, 0.0)

	# CONTROL: nothing open — the joystick MUST drive an intent, or the asserts
	# below prove nothing.
	if not th._enabled:
		return _fail("touch gate: HUD should be live while playing with no overlay")
	_touch_ev(th, jp, true)
	_drag_ev(th, jp2, Vector2(90.0, 0.0))
	if mi.move == Vector2.ZERO:
		return _fail("touch gate: joystick wrote no intent with nothing open — asserts would be vacuous")
	_touch_ev(th, jp2, false)
	await _frames(1)

	# 1. A MENU, with the world still running (what a session does).
	game.menus.open_pause()
	await _frames(2)
	get_tree().paused = false   # request_pause(true) no-ops online — same state, forced
	await _frames(2)
	if th._enabled or th.visible:
		return _fail("touch gate: controls stayed live under an open menu (co-op)")
	_touch_ev(th, jp, true)
	_drag_ev(th, jp2, Vector2(90.0, 0.0))
	if mi.move != Vector2.ZERO:
		return _fail("touch gate: joystick still wrote a move intent under an open menu")
	_touch_ev(th, jp2, false)
	game.menus.close()
	get_tree().paused = false
	await _frames(2)
	if not th._enabled:
		return _fail("touch gate: controls not handed back when the menu closed")

	# 2/3. Dialogue + choice prompts request_pause too, so they had the same hole.
	game.hud.dialogue_active = true
	await _frames(2)
	if th._enabled:
		return _fail("touch gate: controls stayed live under a dialogue box")
	game.hud.dialogue_active = false
	game.hud.choices_active = true
	await _frames(2)
	if th._enabled:
		return _fail("touch gate: controls stayed live under a choice prompt")
	game.hud.choices_active = false
	await _frames(2)
	if not th._enabled:
		return _fail("touch gate: controls not handed back once the overlays cleared")

	# RESTORE (sections never leave shared state moved): _apply_touch_mode(false)
	# frees the HUD and hands the keyboard ability bar back to every later section.
	mi.clear_held()
	game.touch_mode = touch_was
	game._apply_touch_mode()
	get_tree().paused = paused_was
	await _frames(2)
	print("ok: touch HUD overlay gate (menu/dialogue/choice kill the controls with the world unpaused — co-op)")


## Feed a touch/drag straight into the HUD's _input. Input.parse_input_event is
## deliberately NOT used: headless never routes it to _input (only a windowed run
## does), so a rig built on it passes with the gate removed.
func _touch_ev(th: TouchHud, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	th._input(e)


func _drag_ev(th: TouchHud, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	th._input(e)


## Endgame boss pools must never roll a PLACEHOLDER boss (pc_bosses.gd: the
## dev-only Ninja Adventure sweep, tagged "placeholder": true, unplaced, no
## mechanics). Covers the _boss_pool() thin-record fallback that leaked them,
## plus the earned-kills path (record_boss logs dev-panel placeholder kills).
func _test_endgame_no_placeholder_bosses() -> void:
	var kept_records: Dictionary = game.boss_records.duplicate(true)
	# One recorded kill (< 3) forces _boss_pool onto the full-roster fallback.
	game.boss_records = {"fangmaw": {"ttk": 30.0, "dps": 100.0, "kills": 1}}
	var eg := Endgame.new()
	eg.game = game
	var roster: Array = eg._placed_boss_roster()
	var pool: Array = eg._boss_pool()
	# Earned path: 3 real kills keep _boss_pool off the fallback, so the
	# placeholder kill would ride the record straight into the pool.
	var rec := {"ttk": 30.0, "dps": 100.0, "kills": 1}
	game.boss_records = {"fangmaw": rec, "morwen": rec, "vargoth": rec, "cyclops": rec}
	var earned: Array = eg._boss_pool()
	eg.free()
	game.boss_records = kept_records
	if roster.is_empty() or pool.is_empty():
		return _fail("endgame pools: empty (roster %d / fallback %d)" % [roster.size(), pool.size()])
	if earned.size() != 3 or "cyclops" in earned:
		return _fail("endgame pools: earned pool wrong (%s) — placeholder kill should be skipped" % [earned])
	for kind in roster + pool + earned:
		if Story.ALL_ENEMIES.get(kind, {}).get("placeholder", false):
			return _fail("endgame pools: placeholder boss '%s' leaked into the arena pool" % kind)
	print("ok: endgame boss pools exclude placeholder bosses (roster + fallback + earned kills)")


# ---- CONTENT: pc_curios — quest-item curios + codex Curios tab -----------
## Mining sweep (2026-07-18): merge + icon-resolution selftest, then a UI
## smoke — the Curios tab builds in dev mode (placeholders visible) and
## closes cleanly. Content-module hook; never touches existing sections.
func _test_pc_curios() -> void:
	var err: String = await preload("res://scripts/content/pc_curios.gd").selftest(game)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	var _dev0: bool = game.dev_mode
	game.dev_mode = true
	game.menus.open_codex("curios")
	await _frames(3)
	# The Future shelf: every placeholder category renders in dev mode.
	for ft in ["future_terrains", "future_mobs", "future_items",
			"future_armory", "future_supplies", "future_provisions", "future_relics"]:
		game.menus.open_codex(ft)
		await _frames(2)
	game.menus.close()
	game.dev_mode = _dev0
	await _frames(2)
	print("ok: pc_curios (curios shelf + Future tab: terrains/mobs/items/armory/supplies/relics)")


# ---- CONTENT: rv_na_gallery — Raven icons + Ninja animals ----------------
## Second-source sweep (2026-07-18): merge + art-resolution selftest for the
## Raven icon families (alchemy/armory/supplies/provisions curios) and the
## Ninja Adventure critter strips, then a UI smoke of the two new Future
## subtabs. Content-module hook; never touches existing sections.
func _test_rv_na() -> void:
	var err: String = await preload("res://scripts/content/rv_na_gallery.gd").selftest(game)
	if err != "":
		_fail(err)
		await get_tree().create_timer(60.0).timeout
		return
	var _dev0: bool = game.dev_mode
	game.dev_mode = true
	for ft in ["future_alchemy", "future_critters"]:
		game.menus.open_codex(ft)
		await _frames(2)
	game.menus.close()
	game.dev_mode = _dev0
	await _frames(2)
	print("ok: rv_na_gallery (145 Raven icons + 13 critters; Future: alchemy/critters)")
