class_name Endgame extends Node
## The two post-Act-1 endgame combat modes (ACT2_DESIGN.md §II), driven in ONE
## reused arena world. Owned by the game (game.endgame), created on demand by
## game_flow.enter_endgame and torn down when the run settles back to title.
##
## THE CRUCIBLE (Boss Rush): ten seeded cleared-roster bosses back to back, each
## wearing one random elite affix, scaled to your level. HP/MP CARRY OVER — no
## heal between fights; potions are the only sustain. Milestone spoils at 3/6/10.
##
## THE WAKING DEPTHS (Marathon): an endless descent. A prep camp, then combat
## only — each room's mobs scale +1 level, a boss guards every 4th room, and
## affixes/pressure escalate by depth band. How far can you go?
##
## Both modes ACCRUE rewards through the run (nothing granted mid-run) and pay at
## the END: a voluntary cash-out (pause menu) pays in full, a death pays at a
## penalty. Neither pays XP — the chapter-replay rule. Spoils are MAILED and gold
## banked into the character save (write_character_home) so the throwaway arena
## world never overwrites the campaign position the save names.

var game: Game

var mode := ""                 # "crucible" | "depths" | ""
var active := false            # a run is live (guards deferred advance timers)
var arena_room := 0            # the single arena zone index

# progress
var index := 0                 # crucible: bosses spawned so far
var depth := 0                 # depths: current room (0 = the prep camp)
var kills := 0                 # bosses slain this run (both modes)
var boss_room := false         # depths: is the current room a boss checkpoint?
var wave_active := false       # depths: a trash wave is live (tick watches for the clear)

# seeded content
var _rng := RandomNumberGenerator.new()
var boss_queue: Array = []     # crucible: the shuffled ten kinds
var _last_boss := ""           # depths: avoid spawning the same boss twice running

# accrued, unbanked rewards (paid at settle; a death applies the gold penalty)
var pending_gold := 0
var pending_gems: Array = []   # gem LEVELS queued for the spoils mail
var pending_gear: Array = []   # gear GRADES queued for the spoils mail
var reached_milestones := {}   # milestone mark -> true (once each)

var _camp_prompt: Node2D = null    # depths: the "descend" interactable, freed on the first dive
var _camp_merchant: Node2D = null  # depths: the prep merchant, freed on the first dive


# ------------------------------------------------------------------- start ---

## Begin a run. Builds the arena world, resets the run clock, and kicks off the
## first fight (Crucible) or the prep camp (Depths).
func start(m: String) -> void:
	mode = m
	active = true
	index = 0
	depth = 0
	kills = 0
	boss_room = false
	wave_active = false
	pending_gold = 0
	pending_gems = []
	pending_gear = []
	reached_milestones = {}
	_last_boss = ""
	_rng.randomize()
	_clear_player_debuffs()        # a fresh run starts unburdened

	game.switch_chapter(m, true)   # tear down the campaign world, build the arena
	arena_room = game.cur_room
	game.run_time = 0.0            # this run's clock feeds the leaderboard PB
	game.run_deaths = 0

	if m == "crucible":
		_seed_boss_queue()
		game.spawn_text(game.player.global_position + Vector2(0, -110),
			"THE CRUCIBLE — ten bosses, no mercy", Color(1.0, 0.6, 0.45), 3.5)
		_advance_after(0.8, _spawn_next_boss)
	else:
		_make_camp()


# --------------------------------------------------------------- per-frame ---

## Called from game.gd _process while a run is live. Watches for a Depths trash
## wave finishing (bosses drive themselves through on_boss_cleared).
func tick(_delta: float) -> void:
	if not active or mode != "depths":
		return
	if wave_active and not boss_room and game.zone_alive.get(arena_room, 0) <= 0:
		wave_active = false
		_on_room_cleared(false)


# ------------------------------------------------------- crucible flow ---

func _seed_boss_queue() -> void:
	var pool := _boss_pool()
	boss_queue = pool.duplicate()
	_shuffle(boss_queue)
	# Fewer than ten cleared bosses? Refill with repeats so a run is always full.
	while boss_queue.size() < Balance.CRUCIBLE_BOSSES:
		var extra := pool.duplicate()
		_shuffle(extra)
		boss_queue.append_array(extra)
	boss_queue.resize(Balance.CRUCIBLE_BOSSES)

func _spawn_next_boss() -> void:
	if not active:
		return
	var kind: String = boss_queue[index]
	index += 1
	game.spawn_text(game.player.global_position + Vector2(0, -110),
		"BOSS %d / %d" % [index, Balance.CRUCIBLE_BOSSES], Color(1.0, 0.7, 0.5), 2.5)
	_spawn_boss(kind, game.player.level, 1)


# ---------------------------------------------------------- depths flow ---

## The prep camp (depth 0): a descend prompt. Stash and loadout are in the pause
## menu; the first dive frees the prompt and combat-only begins.
func _make_camp() -> void:
	var c := game.room_center(arena_room)
	game.spawn_text(c + Vector2(0, -210),
		"THE WAKING DEPTHS", Color(0.78, 0.82, 1.0), 4.0)
	game.spawn_text(c + Vector2(0, -176),
		"Stock up, then descend — this is the last safe ground. Rewards pay when you fall or cash out.",
		Color(0.7, 0.74, 0.86), 5.0)
	# The prep merchant: potions, consumables and gear. The ONLY shop of the run
	# — once you descend it's combat all the way down (freed on the first dive).
	_camp_merchant = game._make_npc("merchant", c + Vector2(-220, 20),
		"E — Shop", func() -> void: game.menus.open_shop(arena_room))
	_camp_prompt = game._make_npc("tombstone", c + Vector2(0, -40),
		"E — Descend into the dark", func() -> void: descend())

## Drop one room deeper: mob room, or a boss every 4th.
func descend() -> void:
	if not active:
		return
	if is_instance_valid(_camp_prompt):
		_camp_prompt.queue_free()
		_camp_prompt = null
	if is_instance_valid(_camp_merchant):
		_camp_merchant.queue_free()   # no restocking mid-descent — the camp is one-time
		_camp_merchant = null
	depth += 1
	_maybe_retheme()
	var new_debuff := _apply_player_debuffs()   # the depth-37+ stacking curse
	boss_room = (depth % Balance.DEPTHS_BOSS_EVERY == 0)
	game.spawn_text(game.player.global_position + Vector2(0, -110),
		"DEPTH %d" % depth, Color(0.8, 0.84, 1.0), 2.5)
	if new_debuff != "":
		game.spawn_text(game.player.global_position + Vector2(0, -152),
			"THE DARK PRESSES IN — %s" % new_debuff, Color(0.85, 0.5, 0.9), 3.5)
		game.sfx("nova", 0.6)
	if boss_room:
		_spawn_boss(_pick_depth_boss(), game.player.level + depth, _boss_affix_count())
	else:
		_spawn_wave(Balance.DEPTHS_WAVE_SIZE, game.player.level + depth - 1, _mob_affix_count())

## A Depths room fell (trash cleared, or its boss died). Award, then dive on.
func _on_room_cleared(was_boss: bool) -> void:
	if was_boss:
		_award_boss(game.player.level + depth)   # boss rooms pay the boss reward
	else:
		_award_depth(game.player.level + depth - 1)
	_check_milestones()
	game.spawn_text(game.player.global_position + Vector2(0, -92),
		"Depth %d cleared" % depth, Color(0.7, 0.95, 0.75), 2.0)
	_advance_after(1.3, descend)

## Re-theme every few depths: a full terrain swap — ground, walls, scenery,
## hazard patches, ambient and music (apply_terrain clears the old props first,
## so repeated swaps never accumulate). Visual variety as the dark deepens.
func _maybe_retheme() -> void:
	if depth % Balance.DEPTHS_TERRAIN_ROTATE != 1:
		return
	var terrains: Array = Balance.ENDGAME_ARENA_TERRAINS
	var t: String = terrains[(depth / Balance.DEPTHS_TERRAIN_ROTATE) % terrains.size()]
	game.apply_terrain(arena_room, t)


# ---------------------------------------------------- shared boss/mob spawn ---

func _spawn_boss(kind: String, level: int, affix_n: int) -> void:
	var c := game.room_center(arena_room)
	var pos := game.clamp_to_zone(c + Vector2(300, -40), c)
	var b := Boss.make_boss(game, kind, pos, level)
	b.endgame_boss = true
	b.zone_idx = arena_room
	# Affixes: pick distinct keys, mutate stats, and wear the names on the bar.
	var names: Array = []
	for key in _pick_affixes(affix_n):
		_apply_affix(b, key)
		names.append(String(Balance.AFFIXES[key]["name"]))
	if not names.is_empty():
		b.affix = " ".join(names)
		b.display_name = b.affix + " " + b.display_name
	game.bosses.append(b)
	game.current_boss = b
	game.world.add_child(b)
	b.roar()
	game.hud.show_boss_bar(b.display_name)
	game.hud.boss_banner(b.display_name)
	game.set_music(game._boss_music())
	game.shake(6.0)

func _spawn_wave(count: int, level: int, affix_n: int) -> void:
	game.zone_alive[arena_room] = 0
	var pool := _mob_pool()
	var c := game.room_center(arena_room)
	for i in count:
		var kind: String = pool[_rng.randi() % pool.size()]
		var ang := TAU * float(i) / float(count) + _rng.randf_range(-0.3, 0.3)
		var pos := game.clamp_to_zone(c + Vector2.from_angle(ang) * 300.0, c)
		var e := Enemy.make(game, kind, pos, level)
		e.zone_idx = arena_room
		e.pack_id = 0
		for key in _pick_affixes(affix_n):
			_apply_affix(e, key)
		game.zone_alive[arena_room] = game.zone_alive.get(arena_room, 0) + 1
		game.add_enemy(e)
	wave_active = true
	game.wake_pack(arena_room, 0)   # the whole room comes at you at once


# ------------------------------------------------------------- boss death ---

## Routed here from Boss.die (endgame_boss) via game_flow.on_endgame_boss_died.
func on_boss_cleared(_kind: String, _boss: Boss) -> void:
	if not active:
		return
	game.hud.hide_boss_bar()
	if mode == "crucible":
		_award_boss(game.player.level)
		_check_milestones()
		if kills >= Balance.CRUCIBLE_BOSSES:
			_grant_clear_bonus()
			game.spawn_text(game.player.global_position + Vector2(0, -110),
				"THE CRUCIBLE CONQUERED", Color(1.0, 0.85, 0.4), 4.0)
			_advance_after(1.4, func() -> void: settle(false, true))
		else:
			game.spawn_text(game.player.global_position + Vector2(0, -92),
				"Boss down — %d / %d" % [kills, Balance.CRUCIBLE_BOSSES],
				Color(0.7, 0.95, 0.75), 2.0)
			_advance_after(1.3, _spawn_next_boss)
	else:
		_on_room_cleared(true)


# --------------------------------------------------------------- settle ---

## Player fell: settle at the death penalty (the death gold tithe, extended).
func on_player_death() -> void:
	game.run_deaths += 1
	game.fight_wipe()
	game.sfx("pdie")
	game.hud.dim(0.55)
	settle(true, false)

## Voluntary cash-out from the pause menu: pays in full.
func cash_out() -> void:
	settle(false, false)

## Pay out the run and return to title. `died` applies the gold penalty;
## `completed` marks a full Crucible clear (10 bosses).
func settle(died: bool, completed: bool) -> void:
	if not active:
		return
	active = false
	_clear_player_debuffs()        # never carry a Depths curse back to the campaign
	var p := game.player
	var gold := int(pending_gold * (Balance.ENDGAME_DEATH_PENALTY if died else 1.0))
	p.gold += gold
	# Gems + gear MAIL themselves (reliable across the return-to-title, where a
	# ground drop would be lost and a full bag would drop it).
	var rewards: Array = []
	for lv in pending_gems:
		rewards.append({"kind": "gem", "gem": game.drop_gem(int(lv))})
	for grade in pending_gear:
		rewards.append({"kind": "item",
			"item": Items.roll_gear_of_grade(String(grade), game.loot_rng, p.cls)})
	if not rewards.is_empty():
		game.send_mail("Spoils of %s" % _mode_name(),
			_spoils_body(died, completed), rewards)
	# Records (account-wide, meta.json) — the brag numbers.
	var rec := game.record_endgame(mode, p.cls, kills, depth, game.run_time)
	# Bank the character NOW: the results card flips state to ST_VICTORY, after
	# which autosave no-ops — so persist the take-home before the card shows.
	if game.save_slot > 0 and not game.no_saves:
		SaveGame.write_character_home(game, game.save_slot)
	var summary := {
		"mode": mode, "name": _mode_name(), "kills": kills, "depth": depth,
		"gold": gold, "gems": pending_gems.size(), "gear": pending_gear.size(),
		"died": died, "completed": completed, "record": rec,
	}
	game.state = game.ST_VICTORY
	game.set_music("")
	game.sfx("victory" if not died else "hurt")
	game.request_pause(true)
	if is_instance_valid(game.menus):
		game.menus.open_endgame_result(summary)


# ------------------------------------------------------------ reward math ---

func _award_boss(level: int) -> void:
	kills += 1
	var g: int
	if mode == "crucible":
		g = int(Balance.CRUCIBLE_GOLD_BASE * (1.0 + Balance.CRUCIBLE_GOLD_STEP * float(kills - 1)))
	else:
		g = int(Balance.DEPTHS_GOLD_PER_DEPTH * depth)
	pending_gold += int(float(g) * Balance.daily_gold_mult(level))
	pending_gems.append(Balance.endgame_gem_level(maxi(kills, depth)))   # a gem per boss

func _award_depth(level: int) -> void:
	# A cleared trash room pays a slice of the depth gold (bosses pay the rest).
	var g := int(float(Balance.DEPTHS_GOLD_PER_DEPTH) * float(depth) * 0.5)
	pending_gold += int(float(g) * Balance.daily_gold_mult(level))

## Crossing a milestone (kills 3/6/10, or depth 12/24/36/48) banks a bonus gem
## bundle + a boss-band gear roll — kept even through a death (you reached it).
func _check_milestones() -> void:
	var marks: Array = Balance.CRUCIBLE_MILESTONES if mode == "crucible" else Balance.DEPTHS_MILESTONES
	var reached: int = kills if mode == "crucible" else depth
	for m in marks:
		var mark := int(m)
		if reached >= mark and not reached_milestones.get(mark, false):
			reached_milestones[mark] = true
			for _i in 2:
				pending_gems.append(Balance.endgame_gem_level(reached) + 1)
			pending_gear.append(_reward_gear_grade())
			game.spawn_text(game.player.global_position + Vector2(0, -128),
				"MILESTONE — bonus spoils banked", Color(1.0, 0.85, 0.4), 3.0)
			game.sfx("chest")

## The 10-boss Crucible clear pays the headline reward on top of milestones.
func _grant_clear_bonus() -> void:
	pending_gear.append(Balance.CRUCIBLE_CLEAR_GEAR_GRADE)
	for _i in 3:
		pending_gems.append(Balance.endgame_gem_level(Balance.CRUCIBLE_BOSSES) + 1)

## Reward gear grade: the Act-1 boss band by default, richer on a deep run.
func _reward_gear_grade() -> String:
	var reached: int = kills if mode == "crucible" else depth
	if mode == "depths" and reached >= Balance.DEPTHS_MILESTONES[2]:
		return "S"
	return Balance.CRUCIBLE_CLEAR_GEAR_GRADE


# --------------------------------------------------------- escalation dials ---

## The Depths player-debuff band (depth 37+, ACT2 §II): one stacking debuff every
## 4 rooms, cycling −healing received → −damage dealt → +damage taken, forever.
## Recomputed each descent and written straight onto the player's debuff knobs
## (reset to 1.0 off-run). Returns a short label of the newest stack, or "".
func _apply_player_debuffs() -> String:
	var heal := 1.0
	var dmg_out := 1.0
	var dmg_in := 1.0
	var stacks := 0
	if mode == "depths" and depth >= Balance.DEPTHS_TIER_PRESSURE:
		stacks = (depth - Balance.DEPTHS_TIER_PRESSURE) / Balance.DEPTHS_DEBUFF_EVERY + 1
		for s in stacks:
			match s % 3:
				0: heal -= Balance.DEPTHS_DEBUFF_STEP
				1: dmg_out -= Balance.DEPTHS_DEBUFF_STEP
				2: dmg_in += Balance.DEPTHS_DEBUFF_STEP
	game.player.debuff_heal_in = maxf(Balance.DEPTHS_DEBUFF_FLOOR, heal)
	game.player.debuff_dmg_out = maxf(Balance.DEPTHS_DEBUFF_FLOOR, dmg_out)
	game.player.debuff_dmg_in = dmg_in
	# Announce a stack only on the depth that ADDED it (the cycle line).
	if stacks > 0 and (depth - Balance.DEPTHS_TIER_PRESSURE) % Balance.DEPTHS_DEBUFF_EVERY == 0:
		return ["weakened healing", "weakened strikes", "exposed — you take more"][(stacks - 1) % 3]
	return ""

## Reset the player's debuff knobs to neutral (run end / new run).
func _clear_player_debuffs() -> void:
	game.player.debuff_heal_in = 1.0
	game.player.debuff_dmg_out = 1.0
	game.player.debuff_dmg_in = 1.0

func _mob_affix_count() -> int:
	if mode != "depths":
		return 0
	if depth >= Balance.DEPTHS_TIER_MAX:
		return 3
	if depth >= Balance.DEPTHS_TIER_2AFFIX:
		return 2
	if depth >= Balance.DEPTHS_TIER_1AFFIX:
		return 1
	return 0

func _boss_affix_count() -> int:
	if mode == "crucible":
		return 1
	if depth >= Balance.DEPTHS_TIER_MAX:
		return 2
	if depth >= Balance.DEPTHS_TIER_2AFFIX:
		return 1
	return 0


# --------------------------------------------------------------- affixes ---

## Distinct affix keys, up to n (capped at the roster size).
func _pick_affixes(n: int) -> Array:
	if n <= 0:
		return []
	var keys: Array = Balance.AFFIX_KEYS.duplicate()
	_shuffle(keys)
	keys.resize(mini(n, keys.size()))
	return keys

## Apply an affix's stat mutation once, at spawn (no per-frame hook needed).
func _apply_affix(e: Enemy, key: String) -> void:
	var a: Dictionary = Balance.AFFIXES.get(key, {})
	if a.is_empty():
		return
	if a.has("hp"):
		e.max_hp *= float(a["hp"])
		e.hp = e.max_hp
	if a.has("dmg"):
		e.dmg *= float(a["dmg"])
	if a.has("speed"):
		e.speed *= float(a["speed"])
	for t in a.get("traits", []):
		e.traits[String(t)] = true


# ----------------------------------------------------------------- pools ---

## Bosses this character has actually defeated (the "cleared roster"). Falls
## back to the full placed Act-1 roster if the record is somehow thin.
func _boss_pool() -> Array:
	var pool: Array = []
	for kind in Menus.BOSS_KINDS:
		if not Story.ALL_ENEMIES.get(kind, {}).get("boss", false):
			continue
		if int(game.boss_records.get(kind, {}).get("kills", 0)) > 0:
			pool.append(kind)
	if pool.size() < 3:
		pool = _placed_boss_roster()
	return pool

## Every real (non-placeholder) boss placed in a chapter — the Act-1 roster.
func _placed_boss_roster() -> Array:
	var pool: Array = []
	for kind in Menus.BOSS_KINDS:
		if Story.ALL_ENEMIES.get(kind, {}).get("boss", false):
			pool.append(kind)
	return pool

## A random Depths boss, avoiding an immediate repeat.
func _pick_depth_boss() -> String:
	var pool := _boss_pool()
	var kind: String = pool[_rng.randi() % pool.size()]
	if pool.size() > 1 and kind == _last_boss:
		kind = pool[(pool.find(kind) + 1) % pool.size()]
	_last_boss = kind
	return kind

## Non-boss enemy kinds — the Depths trash pool.
func _mob_pool() -> Array:
	var pool: Array = []
	for kind in Story.ALL_ENEMIES:
		var d: Dictionary = Story.ALL_ENEMIES[kind]
		if not d.get("boss", false) and d.has("sprite"):
			pool.append(kind)
	if pool.is_empty():
		pool = ["wolf"]   # never spawn an empty wave
	return pool


# ----------------------------------------------------------------- utils ---

## Deferred advance, cancelled if the run ends (cash-out/death) mid-delay.
func _advance_after(delay: float, fn: Callable) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if active and is_instance_valid(game):
			fn.call())

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _mode_name() -> String:
	return "The Crucible" if mode == "crucible" else "The Waking Depths"

func _spoils_body(died: bool, completed: bool) -> String:
	if completed:
		return "Ten bosses fell to you in the Crucible. These are the spoils of a perfect run."
	if died:
		return "You fell, but not before you earned this. The dark keeps a tithe; the rest is yours."
	return "You walked out with your winnings. Wise. The spoils are yours."
