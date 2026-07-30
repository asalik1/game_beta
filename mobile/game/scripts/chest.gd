class_name Chest extends Area2D
## A loot chest lying in the world. Walk over it to open: you get one piece
## of gear plus some gold.
##
## GRADE-TELEGRAPHED (2026-07-10): the gear grade is rolled when the chest
## DROPS, not when it opens, and the chest wears that grade's art
## (assets/sprites/chest_<f..s>.png) — so spotting a B-chest across a ch7
## room is a loot moment before you ever touch it. The roll itself is
## unchanged (same chapter band, same slot weighting): only the moment of
## rolling moved. `tier` still sets the gold bonus and gem odds.

var tier := "wood"
var grade := "F"           # rolled at drop; the sprite shows it
var opened := false
var buried := false        # buried: invisible until the player comes near
var game: Game
var on_open := Callable()  # optional hook (dead-end caches set a flag)

# BOSS_LOOT.md: a chest is one of two KINDS. "gear" (default) — the classic
# grade-telegraphed gear box (world/elite/boss). "supply" — a boss-only,
# act-tiered (Bronze/Silver/Gold) crafting-materials faucet that also holds
# gems/bags/potions. Supply fields are meaningless for a gear chest and vice
# versa; drop() sets whichever the kind uses.
var kind := "gear"          # "gear" | "supply"
var gear_gem_ok := true     # gear chest may also hold a loose gem (boss gear chest sets false — gems come from supply)
var supply_tier := ""       # "bronze" | "silver" | "gold"
var supply_gem := false     # this supply chest is a GUARANTEED-gem one (§3)
var supply_first_clear := false
var supply_lv := 1          # the boss's level — leans the table toward its ceiling (§2)


# `opts` (BOSS_LOOT.md) shapes the two chest kinds — omit it for the classic
# world/elite gear box (backwards-compatible with every existing 3-arg caller):
#   {"kind": "supply", "supply_tier": "bronze|silver|gold", "supply_gem": bool,
#    "first_clear": bool, "boss_lv": int}   -> an act-tiered supply chest
#   {"grade": "B", "gem_ok": false}         -> a gear chest with a FIXED grade
#     (the boss gear chest: host-rolls the boss-band grade, telegraphs it, and
#      suppresses the loose gem since a boss's gems come from its supply chests)
static func drop(game_node: Node2D, chest_tier: String, pos: Vector2, opts := {}) -> Chest:
	var c := Chest.new()
	c.game = game_node
	c.tier = chest_tier
	c.global_position = pos
	c.kind = String(opts.get("kind", "gear"))
	if c.kind == "supply":
		c.supply_tier = String(opts.get("supply_tier", "bronze"))
		c.supply_gem = bool(opts.get("supply_gem", false))
		c.supply_first_clear = bool(opts.get("first_clear", false))
		c.supply_lv = int(opts.get("boss_lv", 1))
		c.grade = Balance.supply_chest_grade(c.supply_tier)  # ceiling grade = the halo/telegraph
	else:
		c.gear_gem_ok = bool(opts.get("gem_ok", true))
		var og := String(opts.get("grade", ""))
		if og != "":
			c.grade = og  # boss gear chest: host-rolled boss-band grade, telegraphed
		else:
			var grade_rng := RandomNumberGenerator.new()
			grade_rng.randomize()
			c.grade = Balance.roll_weighted_grade(
				Balance.gear_weights(String(game_node.loot_chapter())), grade_rng)

	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2.2, 1.6)
	shadow.position = Vector2(0, 16)
	c.add_child(shadow)

	# The TELL: B-grade and better wear a grade-coloured halo, so a rich
	# chest is legible from across the room (the loot moment). Scaled by
	# terrain luminance like every other light — additive glow blows out
	# daylight scenes otherwise.
	if Items.GRADES.find(c.grade) >= Items.GRADES.find("B"):
		var halo := Sprite2D.new()
		halo.texture = Art.tex("glow")
		var gc: Color = Items.GRADE_COLOR[c.grade]
		halo.modulate = Art.hdr(Color(gc.r, gc.g, gc.b, Balance.CHEST_HALO_ALPHA))
		halo.scale = Vector2(1.35, 1.35)
		halo.z_index = -1
		c.add_child(halo)
		var pulse := c.create_tween().set_loops()
		pulse.tween_property(halo, "scale", Vector2(1.55, 1.55), 0.9)
		pulse.tween_property(halo, "scale", Vector2(1.35, 1.35), 0.9)

	var sprite := Sprite2D.new()
	if c.kind == "supply":
		# Supply chests wear the metallic tier art (wood≈bronze); the halo above
		# already carries the ceiling-grade colour, so leave the metal untinted.
		sprite.texture = Art.tex(Balance.supply_chest_art(c.supply_tier))
	else:
		sprite.texture = Art.tex("chest_" + c.grade.to_lower())
		# A light wash of the grade colour on top of the authored material, so
		# F..C (four wooden boxes) still separate at a glance. Same colour
		# language the item names and gem icons already speak.
		sprite.modulate = Color(1, 1, 1).lerp(
			Items.GRADE_COLOR[c.grade], Balance.CHEST_GRADE_TINT)
	# Grade chests are authored at ~32px; scale_for normalizes any source
	# size back to the on-screen footprint the 16px tier art had.
	var base_scale := Art.scale_for(sprite.texture, Balance.CHEST_SCALE_16PX)
	sprite.scale = base_scale
	c.add_child(sprite)

	c.collision_layer = 0
	c.collision_mask = 2  # player
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26
	cs.shape = shape
	c.add_child(cs)
	# DEFERRED: opening can spawn new Area2Ds (bag-full Pickup drops, cache
	# hooks) — doing that inside the physics flush is a Godot error
	# (area_set_shape_disabled: "Can't change this state while flushing queries").
	c.body_entered.connect(c._on_body_entered, CONNECT_DEFERRED)
	game_node.add_child(c)

	# Little "pop" when it lands.
	sprite.scale = base_scale * 0.17
	var tween := c.create_tween()
	tween.tween_property(sprite, "scale", base_scale * 1.13, 0.15)
	tween.tween_property(sprite, "scale", base_scale, 0.1)
	return c


## Bury the chest (hidden caches, exploration premium): invisible until
## the player wanders close, then it glints awake — the reward for
## walking the dead end nobody made you walk.
func bury() -> void:
	buried = true
	visible = false
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not buried:
		set_physics_process(false)
		return
	var p: Player = game.player
	if p != null and not p.dead \
			and global_position.distance_to(p.global_position) < 150.0:
		buried = false
		visible = true
		set_physics_process(false)
		game.sfx("ward", 0.85, 0.0, -6.0)
		game.burst(global_position, Color(1.0, 0.95, 0.6), 12)
		game.spawn_text(global_position + Vector2(0, -46), "Something glints...",
			Color(1.0, 0.95, 0.7))


func _on_body_entered(body: Node) -> void:
	if opened or buried or not body is Player:
		return
	opened = true
	game.sfx("chest")
	game.burst(global_position, Color(1.0, 0.85, 0.3), 14)
	if on_open.is_valid():
		on_open.call()

	if kind == "supply":
		_open_supply(body)
	else:
		_open_gear(body)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


## The classic gear box: one grade-matched piece + gold, and (world/elite
## chests only) a chance at a loose gem. The boss GEAR chest passes gem_ok=false
## — a boss's gems ride its supply chests instead (BOSS_LOOT §3).
func _open_gear(body: Player) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# The grade was rolled (and shown) at drop time — honour it, don't re-roll.
	# Same distribution as the old roll_chapter_gear path: chapter band, then
	# _roll_slot. The chest never lies about what it holds.
	var item := Items.roll_gear_of_grade(grade, rng, body.cls, Story.act_of(game.chapter_id))
	game.give_loot({"kind": "item", "item": item}, global_position)
	game.loot_fanfare(item["grade"], global_position)  # rarity chime + beam
	var bonus_gold := rng.randi_range(3, 8) * (1 + ["wood", "silver", "gold"].find(tier))
	body.gain_gold(bonus_gold)
	game.hud.loot_banner(item, bonus_gold)

	# Chests can also hold loose gems (better chests, better odds) — but only
	# once regular gems are dropping (ch4+); ch1-3 chests are gear + gold only.
	var gem_chance: float = {"wood": 0.25, "silver": 0.6, "gold": 1.0}[tier]
	if gear_gem_ok and Balance.regular_gems_drop(game.loot_chapter()) and rng.randf() < gem_chance:
		var gem := Items.random_gem(rng, 1, Balance.special_gems_drop(game.loot_chapter()))
		if game.give_loot({"kind": "gem", "gem": gem}, global_position):
			game.spawn_text(body.global_position + Vector2(0, -66), "+ " + Items.gem_title(gem), Items.gem_color(gem))


## The boss supply chest (BOSS_LOOT §3): materials-first, plus the finished-good
## upside and — when this is the guaranteed-gem chest — one tier-level gem. Rolls
## its contents locally (per-machine, like the gear chest) and hands them to the
## owner's award machinery (bag-or-ground, mail, banner) via apply_award_events.
func _open_supply(_body: Player) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var special_ok := Balance.special_gems_drop(game.loot_chapter())
	var events := Chest.roll_supply_contents(supply_tier, supply_gem, supply_first_clear,
		special_ok, supply_lv, global_position, rng)
	game.apply_award_events(events)
	game.loot_fanfare(grade, global_position)  # chime keyed to the tier ceiling


## Roll ONE supply chest's contents into award events (BOSS_LOOT §2-§3). Static
## + rng-param so the boss loot path and autotest share the exact table:
##   * MATERIALS are the common pull (1-2 tier-windowed stacks, ceiling rare)
##   * a finished BAG is rare — otherwise the slot pays cloth (a Tailor's stock)
##   * a finished POTION is rare (small chance black-market) — otherwise herb/
##     reagent (an Alchemist's stock); laced potions CAN drop
##   * a GEM lands only when `with_gem` (the boss guarantees exactly one such
##     chest; on first clear every chest is one), at the tier level, ceiling rare
static func roll_supply_contents(tier: String, with_gem: bool, first_clear: bool,
		special_ok: bool, boss_lv: int, at: Vector2, rng: RandomNumberGenerator) -> Array:
	var evs: Array = []
	var fams: Array = Items.MATERIAL_FAMILIES
	# 1. Materials — the common pull.
	for i in rng.randi_range(Balance.SUPPLY_MAT_STACKS_MIN, Balance.SUPPLY_MAT_STACKS_MAX):
		evs.append(_mat_event(String(fams[rng.randi_range(0, fams.size() - 1)]),
			Balance.roll_supply_grade(tier, boss_lv, rng),
			rng.randi_range(Balance.SUPPLY_MAT_COUNT_MIN, Balance.SUPPLY_MAT_COUNT_MAX), at))
	# 2. Bag — rare finished bag, else cloth (§3).
	if rng.randf() < Balance.SUPPLY_FINISHED_BAG_CHANCE:
		evs.append({"k": "bag", "grade": Balance.roll_supply_grade(tier, boss_lv, rng)})
	else:
		evs.append(_mat_event("cloth", Balance.roll_supply_grade(tier, boss_lv, rng),
			rng.randi_range(Balance.SUPPLY_MAT_COUNT_MIN, Balance.SUPPLY_MAT_COUNT_MAX), at))
	# 3. Potion — rare finished potion (maybe laced), else herb/reagent (§3).
	if rng.randf() < Balance.SUPPLY_FINISHED_POTION_CHANCE:
		var laced := rng.randf() < Balance.SUPPLY_LACED_POTION_CHANCE
		var pot := _roll_supply_potion(tier, boss_lv, laced, rng)
		if not pot.is_empty():
			evs.append({"k": "potion", "potion": pot, "at": at, "ty": -70})
	else:
		var pf: Array = Balance.SUPPLY_POTION_MAT_FAMILIES
		evs.append(_mat_event(String(pf[rng.randi_range(0, pf.size() - 1)]),
			Balance.roll_supply_grade(tier, boss_lv, rng),
			rng.randi_range(Balance.SUPPLY_MAT_COUNT_MIN, Balance.SUPPLY_MAT_COUNT_MAX), at))
	# 4. Gem — exactly one of the boss's chests is guaranteed to hold one (§3).
	if with_gem:
		var lvl := Balance.roll_supply_gem_level(tier, first_clear, rng)
		evs.append({"k": "gem", "gem": Items.random_gem(rng, lvl, special_ok),
			"at": at, "ty": -88})
	return evs


static func _mat_event(family: String, grade: String, count: int, at: Vector2) -> Dictionary:
	return {"k": "material", "family": family, "grade": grade, "count": count,
		"at": at, "ty": -60}


## A finished potion inside a supply chest: a random family-shape, a tier-windowed
## grade clamped to that potion's valid ladder, clean or (small chance) laced.
## {} only if no grade is possible (never, given the ladders overlap the windows).
static func _roll_supply_potion(tier: String, boss_lv: int, laced: bool,
		rng: RandomNumberGenerator) -> Dictionary:
	var keys: Array = Items.POTION_SHAPES.keys()
	var meta: Dictionary = Items.POTION_SHAPES[String(keys[rng.randi_range(0, keys.size() - 1)])]
	var fam := String(meta["family"])
	var shp := String(meta["shape"])
	var ladder: Array
	if laced:
		ladder = Balance.POTION_GRADES_RENEWAL_LACED if fam == "renewal" else Balance.POTION_GRADES_LACED
	else:
		ladder = Balance.POTION_GRADES_RENEWAL if fam == "renewal" else Balance.POTION_GRADES
	var pgrade := Balance.roll_supply_grade_in(tier, boss_lv, ladder, rng)
	if pgrade == "":
		return {}
	return Items.make_potion(fam, shp, pgrade, "black" if laced else "accord")
