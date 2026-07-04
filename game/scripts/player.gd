class_name Player extends CharacterBody2D
## The hero. Classes scale on a primary attribute (STR/AGI/INT), fight
## with 3 basics + 1 ultimate (keyboard, auto-aimed), and customize via:
##  - THEMES: each ability can be assigned any unlocked elemental theme,
##    which changes its behavior (poison DoTs, shadow crits, ice roots...)
##  - the row-based skill tree (see skills.gd)
##  - gear with gem sockets
## All combat math (crit curves, resistances, penetration, evasion,
## true damage) lives in stats.gd.

const SPEED_BASE_REF := 260.0

var game: Node2D  # set by game.gd

# --- identity ---
var cls := "warrior"
var ability_theme := {"a1": "", "a2": "", "a3": "", "ult": ""}
var themes_known := 0

# --- Phase 1 story trackers (persisted with the save from day one) ---
var resonance := 0.0     # -100 (Temptation) .. +100 (Virtue), per DESIGN.md
var faction_standing := {"accord": 0, "cinderborn": 0, "wildfang": 0, "choir": 0}


## Nudge Resonance. No number is ever shown — the world reacts through
## dialogue (Story.res_band) long before any UI would.
func add_resonance(delta: float) -> void:
	resonance = clampf(resonance + delta, -100.0, 100.0)

# --- progression ---
var level := 1
var xp := 0
var skill_points := 0
var tree_points := {}    # skill cell id -> points (0..5)
var attr_points := {"STR": 0, "AGI": 0, "INT": 0, "VIT": 0}
var unspent_attr := 0    # +5 per level, allocate in the skills menu
var gold := 30
var potions := 3

# --- gear ---
var equipment := {}      # slot -> item Dictionary
var backpack: Array = []
var gem_bag: Array = []  # loose gems
const BACKPACK_MAX := 15

# --- vitals ---
var max_hp := 100.0
var hp := 100.0
var max_mp := 50.0
var mp := 50.0
var dead := false

# --- derived stats (recalc() builds these; never write directly) ---
var primary := 12.0      # STR / AGI / INT value
var atk := 12.0
var speed := 250.0
var crit := 0.05
var crit_dmg := 1.5
var cdr := 0.0
var lifesteal := 0.0
var physres := 0.0
var magres := 0.0
var critres := 0.0
var eva := 0.0
var dex := 0.0
var physpen := 0.0
var magpen := 0.0
var combo := 0.0
var greed := 0.0

# --- combat state ---
var cds := {"a1": 0.0, "a2": 0.0, "a3": 0.0, "ult": 0.0}
var potion_cd := 0.0
var hurt_cd := 0.0
var berserk_time := 0.0
var berserk_bonus := 0.4       # damage bonus while berserk (theme-tunable)
var next_crit := false         # Hunt: the next hit is a guaranteed crit
var storm_time := 0.0
var storm_tick := 0.0
var storm_fx := {}
var theme_speed_time := 0.0
var theme_speed_amt := 0.0
var theme_guard_time := 0.0
var theme_guard_amt := 0.0
var hazard_speed := 1.0        # terrain patch effect (ice boosts, void slows)
var aegis_time := 0.0          # paladin Aegis: the shield is up
var aegis_amt := 110.0         # resistances granted while it holds
var aegis_reflect := 0.6       # smite multiplier on attackers
var aegis_fx := {}             # theme payload captured at cast
var pact_time := 0.0           # warlock Dark Pact: lifesteal surge window
var pact_ls := 0.15
var hexed := {}                # warlock Hex: Enemy -> seconds left (explodes on death)
var hex_fx := {}               # theme payload captured when the curse landed
var melee_swing := 0.0         # held-weapon attack animation timer
var melee_style := "swing"     # "swing" (arc) or "stab" (thrust)
var melee_dir := Vector2.RIGHT
var facing := Vector2.RIGHT
var look_sign := 1.0           # which way the hero visually faces (+1 right)
var face_left := false         # does the sprite's art natively face left?
var anim_t := 0.0
var locked_target: Enemy = null
var pending_theme_note := ""   # set when a new theme unlocks (game shows it)

# per-cast theme payload (set by use_ability, read by ability helpers)
var _tfx := {}
var _tcolor := Color(1, 1, 1)
var _themed := false

var sprite: Sprite2D
var weapon_spr: Sprite2D
var weapon_glow: Sprite2D
var aura: Sprite2D


## Passive granted by an equipped S-grade weapon ("" if none).
func s_passive() -> String:
	var w = equipment.get("weapon")
	if w != null and w.has("passive"):
		return w["passive"]
	return ""


func _update_weapon_visual() -> void:
	if weapon_spr == null:
		return
	var w = equipment.get("weapon")
	if w == null:
		weapon_spr.visible = false
		weapon_glow.visible = false
		return
	weapon_spr.texture = Art.weapon_tex(w.get("noun", "Blade"), w["grade"])
	weapon_spr.visible = true
	var fancy: bool = w["grade"] in ["A", "S"]
	weapon_glow.visible = fancy
	if fancy:
		weapon_glow.modulate = Color(Items.GRADE_COLOR[w["grade"]], 0.55)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13
	cs.shape = shape
	add_child(cs)

	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2, 2)
	shadow.position = Vector2(0, 20)
	add_child(shadow)

	# Buff aura: red while Berserk, blue while a guard buff is up.
	aura = Sprite2D.new()
	aura.texture = Art.tex("glow")
	aura.visible = false
	add_child(aura)

	sprite = Sprite2D.new()
	sprite.texture = Art.tex(Classes.CLASSES[cls]["sprite"])
	sprite.scale = Art.scale_for(sprite.texture, 3.0)
	face_left = Art.faces_left(Classes.CLASSES[cls]["sprite"])
	sprite.flip_h = face_left  # start facing right regardless of art
	add_child(sprite)

	weapon_spr = Sprite2D.new()
	weapon_spr.scale = Vector2(2.4, 2.4)
	weapon_spr.visible = false
	weapon_spr.z_index = 1
	add_child(weapon_spr)
	weapon_glow = Sprite2D.new()
	weapon_glow.texture = Art.tex("glow")
	weapon_glow.visible = false
	weapon_glow.scale = Vector2(1.1, 1.1)
	weapon_glow.z_index = 0
	add_child(weapon_glow)

	recalc()
	hp = max_hp
	mp = max_mp


func set_class(id: String) -> void:
	cls = id
	ability_theme = {"a1": "", "a2": "", "a3": "", "ult": ""}
	aegis_time = 0.0
	pact_time = 0.0
	hexed.clear()
	themes_known = Classes.themes_unlocked(level)
	if themes_known > 0:
		var first: String = Classes.THEMES[cls][0]["id"]
		for slot in ability_theme:
			ability_theme[slot] = first
	if sprite:
		sprite.texture = Art.tex(Classes.CLASSES[cls]["sprite"])
		sprite.scale = Art.scale_for(sprite.texture, 3.0)
		face_left = Art.faces_left(Classes.CLASSES[cls]["sprite"])
		sprite.flip_h = face_left if look_sign > 0.0 else not face_left
	recalc()
	hp = max_hp
	mp = max_mp


# ================================================================== themes

func unlocked_theme_ids() -> Array:
	var out: Array = []
	for i in themes_known:
		out.append(Classes.THEMES[cls][i]["id"])
	return out


func set_ability_theme(slot: String, id: String) -> void:
	if id == "" or id in unlocked_theme_ids():
		ability_theme[slot] = id


func _theme_fx(slot: String) -> Dictionary:
	var id: String = ability_theme.get(slot, "")
	if id == "":
		return {}
	# Per-ability variant package — each (ability, theme) pair is unique.
	return Classes.ability_fx(cls, slot, id)


func _theme_color(slot: String) -> Color:
	var id: String = ability_theme.get(slot, "")
	if id == "":
		return Color(1, 1, 1)
	return Classes.theme_by_id(cls, id).get("color", Color(1, 1, 1))


# ================================================================== stats

func xp_needed() -> int:
	return 20 + level * 15


## Rebuild every derived stat: class base + passive + gear (incl. gems)
## + skill tree points.
func recalc() -> void:
	var base: Dictionary = Classes.CLASSES[cls]
	var b := {"atk_flat": 0.0, "atk_pct": 0.0, "hp_flat": 0.0, "hp_pct": 0.0,
		"mp_flat": 0.0, "speed_pct": 0.0, "crit": 0.0, "crit_dmg": 0.0,
		"cdr": 0.0, "lifesteal": 0.0, "physres": 0.0, "magres": 0.0,
		"critres": 0.0, "eva": 0.0, "dex": 0.0, "physpen": 0.0, "magpen": 0.0,
		"combo": 0.0, "greed": 0.0}

	var passive: Dictionary = base.get("passive", {})
	for stat in passive:
		if stat != "text":
			b[stat] = b.get(stat, 0.0) + passive[stat]
	for slot in equipment:
		var stats := Items.stats_of(equipment[slot])
		for stat in stats:
			b[stat] = b.get(stat, 0.0) + stats[stat]
	for id in tree_points:
		var cell := Skills.find_cell(cls, id)
		if cell.is_empty():
			continue
		var pts: int = tree_points[id]
		for stat in cell.get("bonus", {}):
			b[stat] = b.get(stat, 0.0) + cell["bonus"][stat] * pts
	# Allocated attribute points, converted at CLASS scaling ratios
	# (an assassin gets far more from AGI than from STR).
	var attr_scale: Dictionary = Classes.ATTR_SCALE[cls]
	for attr in attr_points:
		var pts: int = attr_points[attr]
		if pts <= 0:
			continue
		for stat in attr_scale.get(attr, {}):
			b[stat] = b.get(stat, 0.0) + attr_scale[attr][stat] * pts

	var hp_frac := hp / max_hp if max_hp > 0 else 1.0
	var mp_frac := mp / max_mp if max_mp > 0 else 1.0
	# Primary attribute (STR/AGI/INT) drives attack and a little crit.
	primary = base["atk"] + base["atk_lvl"] * (level - 1)
	atk = (primary + b["atk_flat"]) * (1.0 + b["atk_pct"])
	max_hp = (base["hp"] + base["hp_lvl"] * (level - 1) + b["hp_flat"]) * (1.0 + b["hp_pct"])
	max_mp = base["mp"] + base["mp_lvl"] * (level - 1) + b["mp_flat"]
	speed = base["speed"] * (1.0 + b["speed_pct"])
	crit = 0.05 + b["crit"] + primary * 0.0006
	crit_dmg = 1.5 + b["crit_dmg"]
	cdr = clampf(b["cdr"], 0.0, 0.45)
	lifesteal = b["lifesteal"]
	physres = b["physres"]
	magres = b["magres"]
	critres = b["critres"]
	eva = b["eva"]
	dex = b["dex"]
	physpen = b["physpen"]
	magpen = b["magpen"]
	combo = b["combo"]
	greed = b["greed"]
	hp = clampf(max_hp * hp_frac, 1.0, max_hp)
	mp = clampf(max_mp * mp_frac, 0.0, max_mp)


func current_atk() -> float:
	if berserk_time > 0.0:
		return atk * (1.0 + berserk_bonus)
	return atk


func current_lifesteal() -> float:
	return lifesteal + (0.15 if berserk_time > 0.0 else 0.0) \
		+ (pact_ls if pact_time > 0.0 else 0.0)


## An attribute's TOTAL: everyone has a base of 5, allocation adds to it,
## and the class primary also carries the class's natural level growth.
func attr_total(attr: String) -> int:
	var total: int = 5 + attr_points.get(attr, 0)
	if Classes.CLASSES[cls]["primary"] == attr:
		total += int(primary)
	return total


## Summary block (attributes tab / quick views).
func stat_sheet() -> String:
	var unspent := "  (%d unspent — press T)" % unspent_attr if unspent_attr > 0 else ""
	return "STR %d  AGI %d  INT %d  VIT %d%s\nATK %d (%s)\nCrit %d%% (x%.1f)   Combo %d%%\nPhysRes %d   MagRes %d   CritRes %d\nEVA %d%%   DEX %d\nPen %d phys / %d mag\nHaste %d%%   Speed %d   Lifesteal %d%%   Greed %d%%" % [
		attr_total("STR"), attr_total("AGI"), attr_total("INT"), attr_total("VIT"), unspent,
		int(atk), Classes.CLASSES[cls]["dmg_type"],
		int(Stats.crit_curve(crit) * 100), crit_dmg, int(Stats.combo_curve(combo) * 100),
		int(physres), int(magres), int(critres),
		int(Stats.eva_curve(eva) * 100), int(dex),
		int(physpen), int(magpen),
		int(cdr * 100), int(speed), int(lifesteal * 100), int(Stats.greed_gold(greed) * 100)]


# ==================================================================== gear

func add_item(item: Dictionary) -> bool:
	if backpack.size() >= BACKPACK_MAX:
		strip_gems(item)
		gold += maxi(1, Items.price(item) / 2)
		game.spawn_text(global_position + Vector2(0, -50), "Bag full! Sold for gold", Color(1, 0.9, 0.4))
		return false
	backpack.append(item)
	return true


func equip(item: Dictionary) -> void:
	backpack.erase(item)
	var slot: String = item["slot"]
	if equipment.has(slot):
		backpack.append(equipment[slot])
	equipment[slot] = item
	recalc()
	_update_weapon_visual()
	game.sfx("equip")


## Pull all gems out of an item back into the gem bag (used when selling).
func strip_gems(item: Dictionary) -> void:
	for gem in item.get("gems", []):
		gem_bag.append(gem)
	item["gems"] = []


## Socket a specific gem into a specific item (the player chooses both).
func embed_gem_into(item: Dictionary, gem: Dictionary) -> bool:
	if item.get("gems", []).size() >= item.get("gem_slots", 0):
		return false
	item["gems"].append(gem)
	gem_bag.erase(gem)
	recalc()
	game.sfx("levelup")
	return true


## Pop one gem out of an item's socket back into the bag.
func remove_gem(item: Dictionary, index: int) -> void:
	var gems: Array = item.get("gems", [])
	if index < 0 or index >= gems.size():
		return
	gem_bag.append(gems[index])
	gems.remove_at(index)
	recalc()
	game.sfx("potion")


## One click, zero tedium: repeatedly synthesize everything possible.
## Socketed gems on equipped gear are upgraded FIRST (a socketed gem +
## two matching bag gems levels up in place), then the bag combines
## 3-of-a-kind until nothing can be merged any more. Returns the number
## of upgrades performed.
func auto_synthesize() -> int:
	var upgrades := 0
	while true:
		# Equipped gems always get first pick of the bag — even of gems
		# the bag itself just merged into existence.
		if _upgrade_equipped_once():
			upgrades += 1
			continue
		if _bag_merge_once():
			upgrades += 1
			continue
		break
	if upgrades > 0:
		recalc()
		game.sfx("levelup")
	return upgrades


## Level up ONE socketed gem in place (eats two matching bag gems).
func _upgrade_equipped_once() -> bool:
	for slot in equipment:
		for gem in equipment[slot].get("gems", []):
			if gem["lvl"] < Items.GEM_MAX_LEVEL and _take_from_bag(gem["stat"], gem["lvl"], 2):
				gem["lvl"] += 1
				return true
	return false


## Merge ONE 3-of-a-kind in the bag, lowest levels first.
func _bag_merge_once() -> bool:
	for lvl in range(1, Items.GEM_MAX_LEVEL):
		for stat in Items.GEM_STATS:
			if synthesize(stat, lvl, true):
				return true
	return false


## Remove `count` bag gems matching stat+level. All or nothing.
func _take_from_bag(stat: String, lvl: int, count: int) -> bool:
	var found: Array = []
	for gem in gem_bag:
		if gem["stat"] == stat and gem["lvl"] == lvl:
			found.append(gem)
			if found.size() == count:
				break
	if found.size() < count:
		return false
	for gem in found:
		gem_bag.erase(gem)
	return true


## 3 gems of the same stat & level -> 1 gem of the next level.
## quiet: skip the sound (auto-synthesize merges dozens in one frame —
## overlapping copies of the same sample phase into digital mush).
func synthesize(stat: String, lvl: int, quiet := false) -> bool:
	if lvl >= Items.GEM_MAX_LEVEL:
		return false
	if not _take_from_bag(stat, lvl, 3):
		return false
	gem_bag.append(Items.make_gem(stat, lvl + 1))
	if not quiet:
		game.sfx("levelup")
	return true


# =============================================================== progression

func gain_xp(amount: int) -> void:
	xp += amount
	game.spawn_text(global_position + Vector2(0, -56), "+%d XP" % amount, Color(1.0, 0.9, 0.4))
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 1
		unspent_attr += 5
		recalc()
		hp = max_hp
		mp = max_mp
		game.sfx("levelup")
		game.spawn_text(global_position + Vector2(0, -72), "LEVEL UP!  Lv %d  (+1 skill point, press T)" % level, Color(0.5, 0.9, 1.0))
		var unlocked := Classes.themes_unlocked(level)
		if unlocked > themes_known:
			themes_known = unlocked
			var theme: Dictionary = Classes.THEMES[cls][unlocked - 1]
			pending_theme_note = theme["name"]
			if unlocked == 1:
				for slot in ability_theme:
					ability_theme[slot] = theme["id"]


## Spend unallocated attribute points (STR/AGI/INT/VIT).
func add_attr_points(attr: String, n: int) -> bool:
	if unspent_attr <= 0 or not attr_points.has(attr):
		return false
	var spend := mini(n, unspent_attr)
	attr_points[attr] += spend
	unspent_attr -= spend
	recalc()
	game.sfx("levelup")
	return true


## One number that approximates total power (gear + gems + level +
## attributes + tree). Shown under the gold display.
func combat_rating() -> int:
	var crit_eff := Stats.crit_curve(crit)
	var offense := atk * (1.0 + crit_eff * (crit_dmg - 1.0)) * 3.0
	offense *= 1.0 + (physpen + magpen) * 0.01
	offense *= 1.0 + Stats.combo_curve(combo) * 0.5
	offense *= 1.0 + cdr * 0.6
	var defense := max_hp * 0.35 + (physres + magres) * 1.2 + critres * 0.8
	defense *= 1.0 + Stats.eva_curve(eva) * 0.8
	var utility := max_mp * 0.3 + speed * 0.2 + lifesteal * 250.0 + dex * 1.0
	return int(round(offense + defense + utility))


func add_tree_point(id: String) -> bool:
	if skill_points <= 0 or not Skills.can_add(cls, id, tree_points, level):
		return false
	skill_points -= 1
	tree_points[id] = tree_points.get(id, 0) + 1
	recalc()
	game.sfx("levelup")
	return true


## Sum of ability modifiers for one slot from tree points.
func _amod(slot: String, field: String) -> float:
	var total := 0.0
	for id in tree_points:
		var cell := Skills.find_cell(cls, id)
		if cell.is_empty():
			continue
		total += cell.get("amod", {}).get(slot, {}).get(field, 0.0) * tree_points[id]
	return total


func dm(slot: String) -> float:
	return 1.0 + _amod(slot, "dmg")


func ability_cd(slot: String) -> float:
	var ab := Classes.ability(cls, slot)
	var cd: float = ab["cd"] * (1.0 + _amod(slot, "cd"))
	return maxf(0.1, cd * (1.0 - cdr))


func ability_cost(slot: String) -> float:
	var ab := Classes.ability(cls, slot)
	return maxf(0.0, ab["mp"] * (1.0 + _amod(slot, "mp")))


func gain_gold(amount: int) -> void:
	gold += int(amount * (1.0 + Stats.greed_gold(greed)))


# ================================================================= per frame

func _physics_process(delta: float) -> void:
	for key in cds:
		cds[key] = maxf(0.0, cds[key] - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	berserk_time = maxf(0.0, berserk_time - delta)
	theme_speed_time = maxf(0.0, theme_speed_time - delta)
	theme_guard_time = maxf(0.0, theme_guard_time - delta)
	aegis_time = maxf(0.0, aegis_time - delta)
	pact_time = maxf(0.0, pact_time - delta)
	mp = minf(max_mp, mp + (6.0 if cls == "mage" else 4.0) * delta)
	anim_t += delta

	# Hex watch: cursed enemies EXPLODE on death (chains: a detonation
	# that kills another cursed enemy sets IT off next frame).
	if not hexed.is_empty():
		var booms: Array = []
		for e in hexed.keys():
			if not is_instance_valid(e):
				hexed.erase(e)  # despawned without dying — no detonation
				continue
			if e.dying or e.hp <= 0.0:
				booms.append(e.global_position)
				hexed.erase(e)
				continue
			hexed[e] -= delta
			if hexed[e] <= 0.0:
				if e.has_node("hex_rune"):
					e.get_node("hex_rune").queue_free()
				hexed.erase(e)
		for pos in booms:
			_hex_detonate(pos)

	if storm_time > 0.0:
		storm_time -= delta
		storm_tick -= delta
		if storm_tick <= 0.0:
			storm_tick = 0.15
			_storm_strike()

	if dead:
		velocity = Vector2.ZERO
		return

	# ------------------------------------------------------------ movement
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	dir = dir.normalized()
	if dir != Vector2.ZERO:
		facing = dir
	var spd := speed * (1.25 if berserk_time > 0.0 else 1.0)
	if theme_speed_time > 0.0:
		spd *= 1.0 + theme_speed_amt
	spd *= hazard_speed  # ice patches boost, void rifts slow
	velocity = dir * spd + game.gust_vec  # sandstorm gusts shove everyone
	move_and_slide()

	# Walk bob + face the aim target (or move direction).
	# NOTE: movement facing is normalized (max 1.0) while target facing is
	# in pixels — the threshold must be small enough for BOTH.
	var target := auto_aim()
	var look_x := target.global_position.x - global_position.x if target else facing.x
	if absf(look_x) > 0.4:
		look_sign = signf(look_x)
		# Left-facing art (Crawl sprites) flips the opposite way.
		sprite.flip_h = (look_x > 0.0) if face_left else (look_x < 0.0)
	if dir != Vector2.ZERO:
		sprite.position.y = -absf(sin(anim_t * 11.0)) * 3.0
		sprite.rotation = sin(anim_t * 11.0) * 0.06
	else:
		sprite.position.y = 0.0
		sprite.rotation = 0.0

	# Held weapon follows the facing side, with a light idle sway.
	if weapon_spr and weapon_spr.visible:
		var side := look_sign
		weapon_spr.position = Vector2(20.0 * side, 8.0 + sprite.position.y)
		weapon_spr.flip_h = side < 0.0
		if melee_swing > 0.0:
			melee_swing = maxf(0.0, melee_swing - delta)
			var prog := 1.0 - melee_swing / 0.16
			if melee_style == "stab":
				# Blade points along the stab line and lunges out-and-back.
				weapon_spr.rotation = melee_dir.angle() + PI / 2.0
				weapon_spr.position += melee_dir * sin(prog * PI) * 20.0
			else:
				weapon_spr.rotation = side * lerpf(-1.4, 0.9, melee_swing / 0.16)
		else:
			weapon_spr.rotation = side * (0.35 + sin(anim_t * 2.0) * 0.05)
		weapon_glow.position = weapon_spr.position

	# ------------------------------------------------------------- actions
	var binds: Dictionary = game.binds
	if Input.is_key_pressed(binds["a1"]):
		use_ability("a1")
	if Input.is_key_pressed(binds["a2"]):
		use_ability("a2")
	if Input.is_key_pressed(binds["a3"]):
		use_ability("a3")
	if Input.is_key_pressed(binds["ult"]):
		use_ability("ult")
	if Input.is_key_pressed(binds["potion"]):
		drink_potion()

	sprite.modulate.a = 0.55 if hurt_cd > 0.0 else 1.0

	# Buff aura pulse (berserk = red, Aegis = gold, Pact = crimson,
	# guard = blue).
	if berserk_time > 0.0 or theme_guard_time > 0.0 or aegis_time > 0.0 or pact_time > 0.0:
		aura.visible = true
		if berserk_time > 0.0:
			aura.modulate = Color(1.0, 0.25, 0.15, 0.7)
		elif aegis_time > 0.0:
			aura.modulate = Color(1.0, 0.85, 0.4, 0.65)
		elif pact_time > 0.0 and theme_guard_time <= 0.0:
			aura.modulate = Color(0.9, 0.15, 0.35, 0.55)
		else:
			aura.modulate = Color(0.4, 0.6, 1.0, 0.6)
		var pulse := 2.2 + sin(anim_t * 9.0) * 0.25
		aura.scale = Vector2(pulse, pulse)
	else:
		aura.visible = false
	# The rage is visible ON the hero, not just around them.
	if sprite:
		sprite.modulate = Color(1.45, 0.55, 0.5) if berserk_time > 0.0 else Color(1, 1, 1)


# ================================================================ targeting

func auto_aim(rng := 520.0) -> Enemy:
	if is_instance_valid(locked_target) and not locked_target.dying \
			and global_position.distance_to(locked_target.global_position) <= rng * 1.4:
		return locked_target
	locked_target = null
	var best: Enemy = null
	var best_d := rng
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func cycle_target() -> void:
	var list: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and global_position.distance_to(e.global_position) <= 560.0:
			list.append(e)
	if list.is_empty():
		locked_target = null
		return
	list.sort_custom(func(a, b) -> bool:
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	var idx := list.find(locked_target)
	locked_target = list[(idx + 1) % list.size()]
	game.sfx("talk")


func aim_dir(rng := 520.0) -> Vector2:
	var target := auto_aim(rng)
	if target:
		return (target.global_position - global_position).normalized()
	return facing


# ================================================================= abilities

func use_ability(slot: String) -> void:
	if dead or cds[slot] > 0.0:
		return
	var cost := ability_cost(slot)
	if mp < cost:
		return
	cds[slot] = ability_cd(slot)
	mp -= cost
	var f := dm(slot)

	# Theme payload for this cast (behavior modifiers + tint).
	_tfx = _theme_fx(slot).duplicate()
	_tcolor = _theme_color(slot)
	_themed = not _tfx.is_empty()
	f *= float(_tfx.get("dmg_mult", 1.0))
	if _tfx.has("speed_buff"):
		theme_speed_time = 2.5
		theme_speed_amt = _tfx["speed_buff"]
	if _tfx.has("guard_buff"):
		theme_guard_time = 2.5
		theme_guard_amt = _tfx["guard_buff"]

	# Weapon "punch" on any cast: the held weapon pops for a beat.
	if weapon_spr and weapon_spr.visible:
		var wp := weapon_spr.create_tween()
		wp.tween_property(weapon_spr, "scale", Vector2(3.0, 3.0), 0.06)
		wp.tween_property(weapon_spr, "scale", Vector2(2.4, 2.4), 0.10)

	match [cls, slot]:
		["warrior", "a1"]:
			_melee_arc(1.0 * f, 96.0, "slash", {"stagger": 0.35, "knock": 330.0}, "swing", "sword")
			if _tfx.get("quake", 0):
				# Earth: a stone shockwave rolls down the lane.
				var qdir := aim_dir(220.0)
				var quake := Projectile.spawn(game, global_position + qdir * 26.0, qdir * 300.0, 0.0, true, "slash")
				quake.hit_player_mult = 0.7 * f
				quake.source_player = self
				quake.fx = _tfx.duplicate()
				quake.pierce = true
				quake.life = 0.5
				quake.modulate = Color(0.85, 0.65, 0.35)
			if _tfx.get("wave2", 0):
				# Fury: a second backhand swing follows.
				var f2 := f
				get_tree().create_timer(0.13).timeout.connect(func() -> void:
					if not dead:
						_melee_arc(0.6 * f2, 96.0, "slash", {"stagger": 0.2}, "swing", "sword"))
			if s_passive() == "kingsblade":
				var wave := Projectile.spawn(game, global_position + aim_dir(220.0) * 30.0, aim_dir(220.0) * 400.0, 0.0, true, "slash")
				wave.hit_player_mult = 0.6 * f
				wave.source_player = self
				wave.fx = _tfx.duplicate()
				wave.pierce = true
				wave.life = 0.6
		["warrior", "a2"]:
			# Charge: ram through everything in your path, stunning it.
			melee_swing = 0.16
			game.sfx("slam")
			_dash_strike(170.0 * float(_tfx.get("dash_mult", 1.0)), 1.3 * f, {"stun": 1.3, "knock": 220.0})
			_ring_fx(global_position, _tcolor if _themed else Color(0.85, 0.85, 0.95), 80.0)
			if _tfx.get("end_slam", 0):
				# Earth: the charge ends in a ground-shattering slam.
				game.shake(5.0)
				game.sfx("slam", 0.8)
				game.burst(global_position, _tcolor, 14)
				_ring_fx(global_position, _tcolor, 130.0)
				for e in _enemies_within(global_position, 120.0):
					hit_enemy(e, 0.7 * f, {"stun": 1.0, "aoe": true})
		["warrior", "a3"]: _whirlwind(f)
		["warrior", "ult"]:
			berserk_time = float(_tfx.get("berserk_dur", 8.0))
			berserk_bonus = float(_tfx.get("berserk_dmg", 0.4))
			if _tfx.has("berserk_heal"):
				hp = minf(max_hp, hp + max_hp * float(_tfx["berserk_heal"]))
			if _tfx.has("berserk_guard"):
				theme_guard_time = berserk_time
				theme_guard_amt = float(_tfx["berserk_guard"])
			if _tfx.get("awaken_slam", 0):
				# Earth: the roar itself is seismic.
				for e in _enemies_within(global_position, 150.0):
					hit_enemy(e, 0.8 * f, {"stun": 2.0, "aoe": true})
			_ring_fx(global_position, _tcolor if _themed else Color(1.0, 0.3, 0.2),
				150.0 if _tfx.get("awaken_slam", 0) else 110.0)
			_ult_sfx()
			game.shake(6.0)
			game.hud.flash_screen(Color(1.0, 0.25, 0.15), 0.4, 0.4)
			game.burst(global_position, Color(1.0, 0.3, 0.2), 20)
			game.spawn_text(global_position + Vector2(0, -60), "BERSERK!", Color(1, 0.4, 0.3))
		["archer", "a1"]: _shoot(aim_dir(), 0.85 * f)
		["archer", "a2"]: _multishot(f)
		["archer", "a3"]: _tumble()
		["archer", "ult"]:
			storm_time = 3.0
			storm_fx = _tfx.duplicate()
			_ult_sfx()
			_ring_fx(global_position, _tcolor if _themed else Color(0.6, 1.0, 0.6), 190.0)
			game.hud.flash_screen(Color(0.6, 1.0, 0.6), 0.3, 0.35)
			game.spawn_text(global_position + Vector2(0, -60), "ARROW STORM!", Color(0.6, 1, 0.6))
		["mage", "a1"]:
			if _tfx.get("twin", 0):
				# Wind: split the bolt.
				_cast_bolt(aim_dir().rotated(0.09), 0.7 * f)
				_cast_bolt(aim_dir().rotated(-0.09), 0.7 * f)
			else:
				_cast_bolt(aim_dir(), 1.1 * f)
		["mage", "a2"]: _frost_nova(f)
		["mage", "a3"]: _blink()
		["mage", "ult"]: _meteor()
		["assassin", "a1"]: _melee_arc(0.8 * f, 84.0, "slash", {"stagger": 0.3, "knock": 260.0}, "stab", "stab")
		["assassin", "a2"]: _shadow_dash(f)
		["assassin", "a3"]: _fan_of_knives(f)
		["assassin", "ult"]: _death_mark()
		["paladin", "a1"]:
			var jeff := {"stagger": 0.3, "knock": 280.0}
			if s_passive() == "dawnbreaker":
				# A pillar of light falls with the hammer.
				jeff["splash"] = maxf(float(_tfx.get("splash", 0.0)), 0.5)
				jeff["burn"] = current_atk() * 0.3
				_light_pillar(global_position + aim_dir(220.0) * 70.0,
					_tcolor if _themed else Color(1.0, 0.95, 0.6))
			_melee_arc(1.0 * f, 92.0, "slash", jeff, "swing", "sword")
			# The hammer lands with weight: a golden shock at the impact.
			var jdir := aim_dir(220.0)
			_ring_fx(global_position + jdir * 58.0,
				_tcolor if _themed else Color(1.0, 0.9, 0.55), 34.0)
			if _tfx.get("wave2", 0):
				# Wrath: a burning backswing follows.
				var jf2 := f
				get_tree().create_timer(0.13).timeout.connect(func() -> void:
					if not dead:
						_melee_arc(0.6 * jf2, 92.0, "slash", {"stagger": 0.2}, "swing", "sword"))
		["paladin", "a2"]: _consecration(f)
		["paladin", "a3"]: _aegis()
		["paladin", "ult"]: _chains_of_wrath(f)
		["warlock", "a1"]: _cast_shadowbolt(aim_dir(), 1.0 * f)
		["warlock", "a2"]: _hex(f)
		["warlock", "a3"]: _dark_pact(f)
		["warlock", "ult"]: _void_rift(f)

	# COMBO: chance the ability doesn't go on cooldown and refunds mana.
	if slot != "ult" and randf() < Stats.combo_curve(combo):
		cds[slot] = 0.0
		mp = minf(max_mp, mp + cost)
		game.spawn_text(global_position + Vector2(0, -66), "COMBO!", Color(0.5, 1.0, 1.0))


## Deal damage to one enemy through the full stat pipeline.
## effects: stagger/stun/knock/pull/slow/burn (guaranteed), plus theme fx
## (dot/slow/stun_chance/echo/heal/vuln/crit_bonus/splash),
## "type": "true" for true damage, "aoe": lifesteal at 33%.
func hit_enemy(e: Enemy, mult: float, effects := {}) -> void:
	for key in _tfx:
		if not effects.has(key):
			effects[key] = _tfx[key]
	var dmg_type: String = effects.get("type", Classes.CLASSES[cls]["dmg_type"])
	var pen := 0.0
	var e_res := 0.0
	if dmg_type == "phys":
		pen = physpen
		e_res = e.physres
	elif dmg_type == "magic":
		pen = magpen
		e_res = e.magres

	var result := Stats.resolve(current_atk() * mult, dmg_type,
		crit + effects.get("crit_bonus", 0.0), crit_dmg, pen, dex, e_res, e.eva, e.critres)
	if result["miss"]:
		game.spawn_text(e.global_position + Vector2(0, -30), "MISS", Color(0.7, 0.7, 0.7))
		return
	var dmg: float = result["dmg"]
	var is_crit: bool = result["crit"]
	# Nightfang passive / Shadow opportunist: stunned or slowed prey always crits.
	if (s_passive() == "nightfang" or effects.get("opportunist", 0)) and dmg_type != "true" \
			and not is_crit and (e.stun_time > 0.0 or e.slow_time > 0.0):
		is_crit = true
		dmg *= crit_dmg
	# Hunt: a lined-up shot cannot fail to crit.
	if next_crit and dmg_type != "true":
		next_crit = false
		if not is_crit:
			is_crit = true
			dmg *= crit_dmg

	# ------------------------------------------------ theme / rider effects
	if effects.has("dot"):
		var dot_color := Color(0.5, 1.2, 0.5) if _tcolor.g > _tcolor.r else Color(1.4, 0.8, 0.6)
		e.apply_burn(current_atk() * effects["dot"], 3.0, dot_color)
	if effects.has("burn"):
		e.apply_burn(effects["burn"], 3.0)
	if s_passive() == "phoenix" and cls == "mage":
		pass  # phoenix burn rides on the projectile fx instead
	if effects.has("slow"):
		e.apply_slow(1.0 - effects["slow"] if effects["slow"] < 1.0 else 0.5, effects.get("slow_dur", 2.0))
	if effects.has("stun"):
		e.apply_stun(effects["stun"])
	if effects.has("stagger"):
		e.apply_stun(effects["stagger"])
	if effects.has("stun_chance") and randf() < effects["stun_chance"]:
		e.apply_stun(0.5)
	if effects.has("vuln") and randf() < effects["vuln"]:
		e.vuln_time = 3.0
		game.spawn_text(e.global_position + Vector2(0, -44), "EXPOSED", Color(1, 0.5, 0.3))
	if effects.has("heal"):
		hp = minf(max_hp, hp + max_hp * effects["heal"])

	# Lifesteal (AoE hits only steal a third).
	var ls := current_lifesteal() * (0.33 if effects.get("aoe", false) else 1.0)
	if ls > 0.0:
		hp = minf(max_hp, hp + dmg * ls)

	var dir := (e.global_position - global_position).normalized()
	e.take_damage(dmg, dir, is_crit)
	if effects.has("knock") and not e.dying:
		e.knock = dir * effects["knock"]
	if effects.has("pull") and not e.dying:
		e.knock = -dir * 380.0
	if effects.has("splash"):
		game.burst(e.global_position, _tcolor if _themed else Color(1.0, 0.6, 0.2), 8)
		for e2 in _enemies_within(e.global_position, 80.0):
			if e2 != e and not e2.dying:
				e2.take_damage(dmg * effects["splash"], (e2.global_position - e.global_position).normalized())
	# Echo: the hit strikes again at half strength.
	if effects.has("echo") and not effects.has("_echoed") and randf() < effects["echo"] and not e.dying:
		var again := effects.duplicate()
		again["_echoed"] = true
		hit_enemy(e, mult * 0.5, again)


func _enemies_within(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and center.distance_to(e.global_position) <= radius:
			out.append(e)
	return out


# ------------------------------------------------------ shared juice ---

## A shockwave ring at pos: expands outward, or collapses inward.
func _ring_fx(pos: Vector2, color: Color, radius: float, collapse := false) -> void:
	var ring := Sprite2D.new()
	ring.texture = Art.tex("ring")
	ring.modulate = Color(color, 0.9)
	ring.global_position = pos
	ring.z_index = 7
	game.add_child(ring)
	var big := radius / 24.0
	ring.scale = Vector2(big, big) if collapse else Vector2(0.3, 0.3)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(0.3, 0.3) if collapse else Vector2(big, big), 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if collapse else Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)


## Ghost copies of the hero along a dash path, fading in sequence.
func _afterimages(start: Vector2, end: Vector2, color: Color, count := 3) -> void:
	if sprite == null:
		return
	for i in count:
		var t := float(i + 1) / float(count + 1)
		var ghost := Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.flip_h = sprite.flip_h
		ghost.scale = sprite.scale
		ghost.global_position = start.lerp(end, t) + sprite.position
		ghost.modulate = Color(color, 0.5)
		ghost.z_index = 5
		game.add_child(ghost)
		var tw := ghost.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.26)
		tw.tween_callback(ghost.queue_free)


## A glowing scorch/frost line left on the ground along a dash path.
func _floor_streak(start: Vector2, end: Vector2, color: Color) -> void:
	var streak := Sprite2D.new()
	streak.texture = Art.tex("glow")
	streak.modulate = Color(color, 0.5)
	streak.global_position = (start + end) / 2.0
	streak.rotation = (end - start).angle()
	streak.scale = Vector2(maxf(1.0, start.distance_to(end) / 40.0), 0.8)
	streak.z_index = -5
	game.add_child(streak)
	var tw := streak.create_tween()
	tw.tween_property(streak, "modulate:a", 0.0, 1.1)
	tw.tween_callback(streak.queue_free)


## Release flash at the weapon: shots visibly leave YOU, not thin air.
func _muzzle(dir: Vector2, color: Color) -> void:
	var fl := Sprite2D.new()
	fl.texture = Art.tex("glow")
	fl.modulate = Color(color, 0.85)
	fl.position = dir * 26.0
	fl.scale = Vector2(0.5, 0.5)
	fl.z_index = 6
	add_child(fl)
	var tw := fl.create_tween()
	tw.tween_property(fl, "scale", Vector2(1.05, 1.05), 0.08)
	tw.parallel().tween_property(fl, "modulate:a", 0.0, 0.11)
	tw.tween_callback(fl.queue_free)


## Melee strike. style "swing" = crescent arc; "stab" = straight thrust
## (a piercing streak, and the held weapon lunges instead of swiping).
func _melee_arc(mult: float, reach: float, fx_name: String, effects := {}, style := "swing", snd := "slash") -> void:
	game.sfx(snd)
	melee_swing = 0.16
	melee_style = style
	var dir := aim_dir(220.0)
	melee_dir = dir
	if style == "stab":
		# Thrust streak: a stretched flash of light along the stab line,
		# with a white-hot core and an impact flash at the point.
		var streak := Sprite2D.new()
		streak.texture = Art.tex("glow")
		streak.modulate = Color(_tcolor if _themed else Color(1, 1, 1), 0.9)
		streak.rotation = dir.angle()
		streak.scale = Vector2(reach / 26.0, 0.45)
		streak.position = dir * reach * 0.55
		streak.z_index = 6
		add_child(streak)
		var tw := streak.create_tween()
		tw.tween_property(streak, "scale:y", 0.1, 0.12)
		tw.parallel().tween_property(streak, "modulate:a", 0.0, 0.12)
		tw.tween_callback(streak.queue_free)
		var core := Sprite2D.new()
		core.texture = Art.tex("glow")
		core.modulate = Color(1, 1, 1, 0.95)
		core.rotation = dir.angle()
		core.scale = Vector2(reach / 34.0, 0.16)
		core.position = dir * reach * 0.55
		core.z_index = 7
		add_child(core)
		var ct := core.create_tween()
		ct.tween_property(core, "scale:y", 0.04, 0.1)
		ct.parallel().tween_property(core, "modulate:a", 0.0, 0.1)
		ct.tween_callback(core.queue_free)
		var tip := Sprite2D.new()
		tip.texture = Art.tex("glow")
		tip.modulate = Color(_tcolor if _themed else Color(1, 1, 1), 0.9)
		tip.position = dir * reach
		tip.scale = Vector2(0.3, 0.3)
		tip.z_index = 7
		add_child(tip)
		var tt := tip.create_tween()
		tt.tween_property(tip, "scale", Vector2(1.1, 1.1), 0.11)
		tt.parallel().tween_property(tip, "modulate:a", 0.0, 0.12)
		tt.tween_callback(tip.queue_free)
	else:
		# The crescent SWEEPS across the arc instead of fading in place —
		# a pivot at the hero swings the blade sprite through ~100°.
		var pivot := Node2D.new()
		pivot.rotation = dir.angle() - 0.9
		pivot.z_index = 6
		add_child(pivot)
		var spr := Sprite2D.new()
		spr.texture = Art.tex(fx_name)
		spr.position = Vector2(reach * 0.5, 0)
		spr.scale = Vector2(2.8, 2.8) * (reach / 78.0)
		if _themed:
			spr.modulate = _tcolor
		pivot.add_child(spr)
		var tween := pivot.create_tween()
		tween.tween_property(pivot, "rotation", dir.angle() + 0.9, 0.13) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(pivot, "modulate:a", 0.0, 0.17)
		tween.tween_callback(pivot.queue_free)
	for e in _enemies_within(global_position + dir * reach * 0.55, reach * 0.55):
		hit_enemy(e, mult, effects.duplicate())


func _proj(dir: Vector2, mult: float, tex: String, speed_px: float) -> Projectile:
	var p := Projectile.spawn(game, global_position + dir * 24.0, dir * speed_px, 0.0, true, tex)
	p.hit_player_mult = mult
	p.source_player = self
	p.fx = _tfx.duplicate()
	if _themed:
		p.modulate = Color(1, 1, 1).lerp(_tcolor, 0.55)
	return p


func _shoot(dir: Vector2, mult: float) -> void:
	game.sfx("bow")
	_muzzle(dir, _tcolor if _themed else Color(0.9, 1.0, 0.6))
	var p := _proj(dir, mult, "arrow", 520.0)
	if s_passive() == "ricochet":
		p.fx["ric"] = 1


func _cast_bolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball")  # a breathy fire fwoosh, not an arcane laser
	_muzzle(dir, _tcolor if _themed else Color(1.0, 0.6, 0.2))
	# The Ice variant flies as a crystal lance, not a ball of fire.
	var tex := "icelance" if _tfx.get("pierce", 0) else "fireball"
	var p := _proj(dir, mult, tex, 440.0 * float(_tfx.get("proj_speed", 1.0)))
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if s_passive() == "phoenix":
		p.fx["splash"] = maxf(p.fx.get("splash", 0.0), 0.5)
		p.fx["burn"] = current_atk() * 0.35


func _whirlwind(f := 1.0) -> void:
	game.sfx("sword")
	var radius := 115.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(1, 1, 1)
	var inward: bool = _tfx.get("pull", 0)

	# Three blades sweep a full revolution around the hero (reversed
	# when Earth drags enemies in — the vortex visibly turns inward).
	var pivot := Node2D.new()
	pivot.z_index = 6
	add_child(pivot)
	for i in 3:
		var ang := TAU * i / 3.0
		var blade := Sprite2D.new()
		blade.texture = Art.tex("slash")
		blade.modulate = Color(col, 0.9)
		blade.rotation = ang
		blade.position = Vector2.from_angle(ang) * radius * 0.55
		blade.scale = Vector2(2.6, 2.6)
		pivot.add_child(blade)
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation", TAU * (-1.0 if inward else 1.0), 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pivot, "modulate:a", 0.0, 0.34)
	tw.tween_callback(pivot.queue_free)
	_ring_fx(global_position, col, radius, inward)

	var eff := {"stagger": 0.3, "aoe": true}
	if not inward:  # Earth drags them in instead of flinging
		eff["knock"] = 380.0
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, 0.9 * f, eff.duplicate())


## Per-class ultimate activation sound, falling back to the generic one.
func _ult_sfx() -> void:
	var key := "ult_" + cls
	game.sfx(key if game.sounds.has(key) else "ult")


func _multishot(f := 1.0) -> void:
	# ONE release sound for the whole volley — five overlapping copies of
	# the same sample phase into a nasty digital flanging artifact.
	# Pitched lower than Quick Shot so the two are distinguishable.
	game.sfx("slash", 0.85)
	var dir := aim_dir()
	_muzzle(dir, _tcolor if _themed else Color(0.9, 1.0, 0.6))
	var count := int(_tfx.get("knives", 5))
	var step := 0.05 if _tfx.get("narrow", 0) else float(_tfx.get("spread", 0.16))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), 0.55 * f, "arrow", 520.0)
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
		if s_passive() == "ricochet":
			p.fx["ric"] = 1


func _tumble() -> void:
	game.sfx("blink")
	hurt_cd = maxf(hurt_cd, 0.5)
	var origin := global_position
	global_position = game.clamp_to_zone(global_position + facing * 130.0, global_position)
	# The roll reads as motion: ghost trail + kicked-up dust behind you.
	_afterimages(origin, global_position, _tcolor if _themed else Color(0.9, 0.95, 1.0), 2)
	game.burst(origin, Color(0.75, 0.7, 0.6), 6)
	if _tfx.has("burst_origin"):
		# Storm: discharge where you left.
		game.sfx("nova", 1.2)
		game.burst(origin, _tcolor, 12)
		for e in _enemies_within(origin, 110.0):
			hit_enemy(e, float(_tfx["burst_origin"]), {"aoe": true})
	if _tfx.get("mist_origin", 0):
		# Venom: leave a toxin cloud behind.
		_mist(origin, 95.0, 0.35, _tcolor, 2.5)
	if _tfx.get("next_crit", 0):
		# Hunt: line up the next shot.
		next_crit = true
		game.spawn_text(global_position + Vector2(0, -60), "LINED UP", Color(1, 0.7, 0.3))


func _storm_strike() -> void:
	var e: Enemy = null
	if storm_fx.get("focus", 0):
		# Hunt: every arrow hunts YOUR target.
		e = auto_aim(560.0)
	else:
		var targets := _enemies_within(global_position, 560.0)
		if not targets.is_empty():
			e = targets[randi() % targets.size()]
	if e == null:
		return
	# Falling-arrow whoosh (deep-pitched), NOT the synth laser zap.
	game.sfx("knife", 0.75)
	# An arrow visibly falls out of the sky onto the target.
	var arrow := Sprite2D.new()
	arrow.texture = Art.tex("arrow")
	arrow.rotation = PI / 2.0
	arrow.scale = Vector2(3, 3)
	arrow.global_position = e.global_position + Vector2(randf_range(-10, 10), -160)
	arrow.z_index = 30
	game.add_child(arrow)
	var tween := arrow.create_tween()
	tween.tween_property(arrow, "global_position:y", e.global_position.y, 0.11)
	tween.tween_callback(arrow.queue_free)
	game.burst(e.global_position, Color(0.7, 1.0, 0.7))
	var storm_col := _theme_color("ult") if ability_theme.get("ult", "") != "" else Color(0.7, 1.0, 0.7)
	_ring_fx(e.global_position, storm_col, 42.0)
	var eff := storm_fx.duplicate()
	eff["aoe"] = true
	hit_enemy(e, 0.8, eff)


func _frost_nova(f := 1.0) -> void:
	game.sfx("nova")
	game.shake(6.0)
	var radius := 160.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(0.45, 0.8, 1.0)
	var inward: bool = _tfx.get("pull", 0)
	var fiery: bool = _tfx.get("no_knock", 0)

	# Shockwave RING — expands for the blast, COLLAPSES for the implosion.
	var r_scale := radius / 24.0
	for delay in ([0.0, 0.07] if not inward else [0.0]):
		var ring := Sprite2D.new()
		ring.texture = Art.tex("ring")
		ring.modulate = Color(col, 0.95)
		ring.z_index = 7
		add_child(ring)
		var tw := ring.create_tween()
		if delay > 0.0:
			ring.scale = Vector2(0.1, 0.1)
			tw.tween_interval(delay)
		if inward:
			ring.scale = Vector2(r_scale, r_scale)
			tw.tween_property(ring, "scale", Vector2(0.3, 0.3), 0.26) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tw.tween_property(ring, "scale", Vector2(r_scale * (1.0 - delay), r_scale * (1.0 - delay)), 0.26) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.32)
		tw.tween_callback(ring.queue_free)

	# Radial shards: icicles fly OUT, embers for the flame ring, and the
	# implosion sucks them IN instead.
	for i in 10:
		var ang := TAU * i / 10.0 + randf_range(-0.15, 0.15)
		var shard := Sprite2D.new()
		shard.texture = Art.tex("fireball" if fiery else "icelance")
		shard.modulate = col
		shard.rotation = ang + (PI if inward else 0.0)
		shard.scale = Vector2(1.5, 1.5)
		shard.z_index = 7
		shard.position = Vector2.from_angle(ang) * (radius if inward else 6.0)
		add_child(shard)
		var st := shard.create_tween()
		st.tween_property(shard, "position",
			Vector2.ZERO if inward else Vector2.from_angle(ang) * radius, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if inward else Tween.EASE_OUT)
		st.parallel().tween_property(shard, "modulate:a", 0.0, 0.26)
		st.tween_callback(shard.queue_free)

	# Lingering ground frost / scorch where the blast happened.
	var floor_glow := Sprite2D.new()
	floor_glow.texture = Art.tex("glow")
	floor_glow.modulate = Color(col, 0.4)
	floor_glow.scale = Vector2(radius / 24.0, radius / 32.0)
	floor_glow.global_position = global_position
	floor_glow.z_index = -5
	game.add_child(floor_glow)
	var ft := floor_glow.create_tween()
	ft.tween_property(floor_glow, "modulate:a", 0.0, 0.9)
	ft.tween_callback(floor_glow.queue_free)

	game.hud.flash_screen(Color(col, 1.0), 0.2, 0.25)
	game.burst(global_position, col, 18)
	game.burst(global_position, Color(1, 1, 1), 8)

	# A real panic button: big damage, shove everything away, slow it.
	# (Fire ring burns instead of shoving; Wind implodes them INTO you.)
	var eff := {"slow": 0.5, "slow_dur": 2.5, "aoe": true}
	if not (fiery or inward):
		eff["knock"] = 340.0
	for e in _enemies_within(global_position, radius):
		hit_enemy(e, 1.4 * f, eff.duplicate())


## Dash `dist` pixels in the move direction, damaging every enemy along
## the path. Used by mage Blink and assassin Shadow Dash — and because
## it HITS things, ability themes fully apply to it. Returns kill count
## (Phantom step refunds cooldown on kills).
func _dash_strike(dist: float, mult: float, effects := {}) -> int:
	game.sfx("blink")
	var color := _tcolor if _themed else Color(0.6, 0.7, 1.0)
	var start := global_position
	global_position = game.clamp_to_zone(start + facing * dist, start)
	var end := global_position
	hurt_cd = maxf(hurt_cd, 0.3)  # brief immunity while dashing
	game.burst(start, color, 8)
	game.burst(end, color, 8)
	_afterimages(start, end, color)

	# Light trail between the two points.
	var mid := (start + end) / 2.0
	var trail := Sprite2D.new()
	trail.texture = Art.tex("glow")
	trail.modulate = Color(color, 0.7)
	trail.global_position = mid
	trail.rotation = (end - start).angle()
	trail.scale = Vector2(maxf(1.0, start.distance_to(end) / 44.0), 1.1)
	trail.z_index = 6
	game.add_child(trail)
	var tween := trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.25)
	tween.tween_callback(trail.queue_free)

	var kills := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, start, end)
		if e.global_position.distance_to(closest) <= 55.0:
			hit_enemy(e, mult, effects.duplicate())
			if e.dying or e.hp <= 0.0:
				kills += 1
	return kills


func _blink() -> void:
	var eff := {"aoe": true}
	if _tfx.has("freeze_path"):
		eff["stun"] = float(_tfx["freeze_path"])  # Frostwalk
	var start := global_position
	_dash_strike(190.0 * float(_tfx.get("dash_mult", 1.0)), 0.8, eff)
	# Fire leaves a burning wake on the ground; Ice a frozen one.
	if _themed and (_tfx.has("dot") or _tfx.has("freeze_path")):
		_floor_streak(start, global_position, _tcolor)


func _meteor() -> void:
	_ult_sfx()
	# Starfall (wind): several smaller comets across several targets.
	var count := int(_tfx.get("meteors", 1))
	var spots: Array = []
	if count > 1:
		for e in _enemies_within(global_position, 560.0):
			spots.append(e.global_position)
			if spots.size() >= count:
				break
	if spots.is_empty():
		var target := auto_aim()
		spots.append(target.global_position if target else global_position + facing * 150.0)
	for pos in spots:
		_meteor_at(pos)


func _meteor_at(pos: Vector2) -> void:
	var fx_copy := _tfx.duplicate()
	var col := _tcolor if _themed else Color(1.0, 0.6, 0.2)

	# Growing impact shadow on the ground — you can feel it coming.
	var mark := Sprite2D.new()
	mark.texture = Art.tex("telegraph")
	mark.global_position = pos
	mark.modulate = Color(col, 0.5)
	mark.scale = Vector2(1, 1)
	mark.z_index = -6
	game.add_child(mark)
	var mark_tw := mark.create_tween()
	mark_tw.tween_property(mark, "scale", Vector2(4.6, 4.6), 0.62)

	# The meteor itself: big, burning, with a particle trail.
	var spr := Sprite2D.new()
	spr.texture = Art.tex("fireball")
	spr.scale = Vector2(11, 11)
	spr.modulate = col
	spr.global_position = pos + Vector2(90, -460)
	spr.z_index = 30
	game.add_child(spr)
	var trail := CPUParticles2D.new()
	trail.amount = 26
	trail.lifetime = 0.5
	trail.spread = 20.0
	trail.direction = Vector2(-0.2, -1)
	trail.initial_velocity_min = 60.0
	trail.initial_velocity_max = 140.0
	trail.scale_amount_min = 2.5
	trail.scale_amount_max = 5.0
	trail.color = col
	spr.add_child(trail)

	var tween := spr.create_tween()
	tween.tween_property(spr, "global_position", pos, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		spr.queue_free()
		if is_instance_valid(mark):
			mark.queue_free()
		game.sfx("meteor")
		game.shake(14.0)
		game.hud.flash_screen(Color(1.0, 0.75, 0.4), 0.55, 0.35)
		game.burst(pos, col, 30)
		game.burst(pos, Color(1.0, 0.9, 0.5), 16)
		_ring_fx(pos, col, 150.0 * float(fx_copy.get("radius_mult", 1.0)))
		# Scorched ground lingers for a moment.
		var scorch := Sprite2D.new()
		scorch.texture = Art.tex("glow")
		scorch.modulate = Color(col, 0.6)
		scorch.global_position = pos
		scorch.scale = Vector2(4.2, 4.2)
		scorch.z_index = -5
		game.add_child(scorch)
		var s_tw := scorch.create_tween()
		s_tw.tween_property(scorch, "modulate:a", 0.0, 1.3)
		s_tw.tween_callback(scorch.queue_free)
		var radius := 150.0 * float(fx_copy.get("radius_mult", 1.0))
		for e in _enemies_within(pos, radius):
			var eff := fx_copy.duplicate()
			eff["burn"] = current_atk() * 0.4 * float(fx_copy.get("burn_mult", 1.0))
			eff["aoe"] = true
			if fx_copy.has("freeze"):
				eff["stun"] = float(fx_copy["freeze"])  # glacial comet
			hit_enemy(e, 3.5 * float(fx_copy.get("dmg_mult", 1.0)), eff)
	)


func _shadow_dash(f := 1.0) -> void:
	melee_swing = 0.16
	melee_style = "stab"
	melee_dir = facing
	game.sfx("stab")
	var start := global_position
	var kills := _dash_strike(210.0 * float(_tfx.get("dash_mult", 1.0)), 1.2 * f, {"stagger": 0.4})
	if _tfx.get("trail_mist", 0):
		# Poison: the dash line blooms into a toxic wake.
		_mist((start + global_position) / 2.0, 110.0, 0.3, _tcolor, 2.5)
	if kills > 0 and _tfx.has("kill_refund"):
		# Shadow: a kill refunds most of the cooldown.
		cds["a2"] *= 1.0 - float(_tfx["kill_refund"])
		game.spawn_text(global_position + Vector2(0, -60), "PHANTOM", Color(0.7, 0.5, 1.0))


func _fan_of_knives(f := 1.0) -> void:
	game.sfx("knife", 1.25)  # lighter/faster than the archer sounds
	var dir := aim_dir()
	_muzzle(dir, _tcolor if _themed else Color(0.8, 0.85, 1.0))
	if _tfx.get("bloom", 0):
		# Poison: ONE heavy venom blade that detonates into a toxin cloud
		# (on its first hit, or at the end of its flight).
		var p := _proj(dir, 1.0 * f, "knife", 500.0)
		p.scale = Vector2(1.5, 1.5)
		p.life = 0.55
		p.fx["bloom_mist"] = 1
		p.fx["bloom_color"] = _tcolor
		return
	var count := int(_tfx.get("knives", 3))
	var step := float(_tfx.get("spread", 0.13))
	for i in count:
		var spread := (float(i) - (count - 1) / 2.0) * step
		var p := _proj(dir.rotated(spread), 0.7 * f, "knife", 560.0)
		p.pierce = p.pierce or bool(_tfx.get("pierce", 0))


## An expanding cloud that ticks poison on everything inside — the mist
## primitive behind Venom Bloom, Toxic Wake and the archer's toxin cloud.
## Not a flat glow: a ROILING mass of drifting blobs, rising toxic motes,
## a burst ring on arrival, and venom bubbles on everything it eats.
func _mist(pos: Vector2, radius: float, dps_mult: float, color: Color, dur := 2.5) -> void:
	var root := Node2D.new()
	root.global_position = pos
	root.z_index = 4
	game.add_child(root)
	_ring_fx(pos, color, radius)
	game.burst(pos, color, 10)

	# Overlapping blobs, each swelling to its own size and slowly churning
	# around the center — the cloud visibly boils instead of sitting still.
	for i in 6:
		var blob := Sprite2D.new()
		blob.texture = Art.tex("glow")
		var shade := randf_range(0.55, 1.0)
		blob.modulate = Color(color.r * shade, color.g * shade, color.b * shade, 0.0)
		var off := Vector2.from_angle(TAU * i / 6.0 + randf_range(-0.4, 0.4)) \
			* randf_range(radius * 0.15, radius * 0.45)
		blob.position = off
		blob.scale = Vector2(0.6, 0.6)
		root.add_child(blob)
		var grow := blob.create_tween()
		grow.tween_property(blob, "modulate:a", randf_range(0.4, 0.6), 0.35)
		var target := randf_range(radius / 30.0, radius / 20.0)
		grow.parallel().tween_property(blob, "scale", Vector2(target, target), 0.5)
		var churn := blob.create_tween()
		churn.set_loops()
		churn.tween_property(blob, "position", off.rotated(0.9), randf_range(0.8, 1.3)) \
			.set_trans(Tween.TRANS_SINE)
		churn.tween_property(blob, "position", off, randf_range(0.8, 1.3)) \
			.set_trans(Tween.TRANS_SINE)

	# Toxic motes bubbling up out of the whole area for the cloud's life.
	var motes := CPUParticles2D.new()
	motes.amount = 30
	motes.lifetime = 1.1
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = radius * 0.8
	motes.direction = Vector2(0, -1)
	motes.spread = 25.0
	motes.gravity = Vector2(0, -26)
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 28.0
	motes.scale_amount_min = 1.6
	motes.scale_amount_max = 3.4
	motes.color = Color(color, 0.85)
	root.add_child(motes)

	var ticks := int(dur / 0.4)
	for i in ticks:
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(root):
			return
		if dead:
			root.queue_free()
			return
		for e in _enemies_within(pos, radius):
			e.apply_burn(current_atk() * dps_mult, 1.2, Color(color, 1.0))
			game.burst(e.global_position + Vector2(0, -10), color, 4)  # venom bubbles
	motes.emitting = false
	var fade := root.create_tween()
	fade.tween_property(root, "modulate:a", 0.0, 0.6)
	fade.tween_callback(root.queue_free)


func _death_mark() -> void:
	var target := auto_aim()
	if target == null:
		cds["ult"] = 1.0
		return
	# EXECUTION: the world darkens, you appear on top of the target,
	# a giant death mark rises, then a 3-hit true-damage flurry lands.
	_ult_sfx()
	game.hud.flash_screen(Color(0.35, 0.0, 0.1), 0.5, 0.45)
	game.burst(global_position, Color(0.5, 0.2, 0.5), 12)
	var dir := (target.global_position - global_position).normalized()
	global_position = game.clamp_to_zone(target.global_position + dir * 42.0, target.global_position)
	target.vuln_time = 5.0
	target.apply_stun(0.6)
	if _tfx.has("mark_dot"):
		# Poison: the mark itself rots the target.
		target.apply_burn(current_atk() * float(_tfx["mark_dot"]), 5.0, Color(0.5, 1.2, 0.5))
	game.spawn_text(target.global_position + Vector2(0, -60), "DEATH MARK", Color(1, 0.25, 0.3))

	var skull := Sprite2D.new()
	skull.texture = Art.glyph_tex("ab_skull", Color(1.0, 0.25, 0.35))
	skull.scale = Vector2(3.5, 3.5)
	skull.global_position = target.global_position + Vector2(0, -40)
	skull.z_index = 30
	game.add_child(skull)
	var tween := skull.create_tween()
	tween.tween_property(skull, "global_position:y", skull.global_position.y - 46.0, 0.7)
	tween.parallel().tween_property(skull, "modulate:a", 0.0, 0.7)
	tween.tween_callback(skull.queue_free)

	_death_mark_flurry(target, float(_tfx.get("flurry_heal", 0.0)), float(_tfx.get("execute", 0.0)))


func _death_mark_flurry(target: Enemy, flurry_heal := 0.0, execute := 0.0) -> void:
	for i in 3:
		if not is_instance_valid(target) or target.dying:
			return
		melee_swing = 0.16
		melee_style = "stab"
		game.sfx("stab")
		game.shake(3.5)
		game.burst(target.global_position, Color(1.0, 0.2, 0.3), 10)
		# A visible slash rips across the target with every hit.
		var rip := Sprite2D.new()
		rip.texture = Art.tex("glow")
		rip.modulate = Color(1.0, 0.35, 0.45, 0.95)
		rip.global_position = target.global_position
		rip.rotation = randf_range(0.0, TAU)
		rip.scale = Vector2(2.4, 0.14)
		rip.z_index = 8
		game.add_child(rip)
		var rt := rip.create_tween()
		rt.tween_property(rip, "scale:y", 0.03, 0.12)
		rt.parallel().tween_property(rip, "modulate:a", 0.0, 0.14)
		rt.tween_callback(rip.queue_free)
		hit_enemy(target, 0.7 if i < 2 else 1.3, {"type": "true"})
		if flurry_heal > 0.0:
			hp = minf(max_hp, hp + max_hp * flurry_heal)  # Blood: the flurry feeds
		await get_tree().create_timer(0.09).timeout
	# Shadow: if they survived under 30%, the executioner finishes it.
	if execute > 0.0 and is_instance_valid(target) and not target.dying \
			and target.hp < target.max_hp * 0.3:
		game.shake(6.0)
		game.spawn_text(target.global_position + Vector2(0, -70), "EXECUTED", Color(1, 0.15, 0.25))
		game.burst(target.global_position, Color(0.6, 0.2, 0.6), 16)
		hit_enemy(target, execute, {"type": "true"})


# ============================================================ paladin kit

## A shaft of light stabs down from the sky and blooms where it lands.
## The Dawnbreaker pillar, Consecration's judgment on each victim.
func _light_pillar(pos: Vector2, col := Color(1.0, 0.95, 0.6), width := 0.9) -> void:
	var shaft := Sprite2D.new()
	shaft.texture = Art.tex("glow")
	shaft.modulate = Color(col, 0.0)
	shaft.global_position = pos + Vector2(0, -120)
	shaft.scale = Vector2(width, 5.5)
	shaft.z_index = 8
	game.add_child(shaft)
	var tw := shaft.create_tween()
	tw.tween_property(shaft, "modulate:a", 0.85, 0.06)
	tw.parallel().tween_property(shaft, "global_position:y", pos.y - 95.0, 0.06)
	tw.tween_property(shaft, "modulate:a", 0.0, 0.24)
	tw.tween_callback(shaft.queue_free)
	_ring_fx(pos, col, 46.0 * width)
	game.burst(pos, col, 6)


## A bright slash rips across a smitten enemy (Aegis retaliation).
func _smite_rip(pos: Vector2, col: Color) -> void:
	var rip := Sprite2D.new()
	rip.texture = Art.tex("glow")
	rip.modulate = Color(col, 0.95)
	rip.global_position = pos
	rip.rotation = randf_range(0.0, TAU)
	rip.scale = Vector2(2.0, 0.13)
	rip.z_index = 8
	game.add_child(rip)
	var tw := rip.create_tween()
	tw.tween_property(rip, "scale:y", 0.03, 0.12)
	tw.parallel().tween_property(rip, "modulate:a", 0.0, 0.14)
	tw.tween_callback(rip.queue_free)


## A thin beam of light/darkness between two points, fading fast
## (hex tendrils, quick magical connections).
func _beam_fx(from: Vector2, to: Vector2, col: Color, width := 0.18) -> void:
	var seg := Sprite2D.new()
	seg.texture = Art.tex("glow")
	seg.modulate = Color(col, 0.85)
	seg.global_position = (from + to) / 2.0
	seg.rotation = (to - from).angle()
	seg.scale = Vector2(maxf(0.5, from.distance_to(to) / 44.0), width)
	seg.z_index = 7
	game.add_child(seg)
	var tw := seg.create_tween()
	tw.tween_property(seg, "scale:y", 0.03, 0.22)
	tw.parallel().tween_property(seg, "modulate:a", 0.0, 0.24)
	tw.tween_callback(seg.queue_free)


## Consecration: sanctify the ground where you stand — two waves of holy
## fire, and every enemy struck MENDS you (heal-on-hit is the identity).
func _consecration(f := 1.0) -> void:
	var radius := 150.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(1.0, 0.9, 0.5)
	var pos := global_position
	var fx_copy := _tfx.duplicate()
	var fmul := f
	_consecration_pulse(pos, radius, 0.9 * f, col, fx_copy)
	# The ground stays sanctified: a second wave erupts moments later.
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if dead:
			return
		var saved := _tfx
		_tfx = fx_copy
		_consecration_pulse(pos, radius, 0.7 * fmul, col, fx_copy)
		_tfx = saved)


func _consecration_pulse(pos: Vector2, radius: float, mult: float, col: Color, fx: Dictionary) -> void:
	game.sfx("nova", 0.75)
	_ring_fx(pos, col, radius)
	game.burst(pos, col, 12)
	# Hallowed floor glow that lingers a moment.
	var floor_glow := Sprite2D.new()
	floor_glow.texture = Art.tex("glow")
	floor_glow.modulate = Color(col, 0.45)
	floor_glow.scale = Vector2(radius / 24.0, radius / 32.0)
	floor_glow.global_position = pos
	floor_glow.z_index = -5
	game.add_child(floor_glow)
	var ft := floor_glow.create_tween()
	ft.tween_property(floor_glow, "modulate:a", 0.0, 0.8)
	ft.tween_callback(floor_glow.queue_free)
	# Rising motes of light.
	var motes := CPUParticles2D.new()
	motes.amount = 18
	motes.lifetime = 0.7
	motes.one_shot = true
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = radius * 0.8
	motes.direction = Vector2(0, -1)
	motes.spread = 15.0
	motes.gravity = Vector2(0, -60)
	motes.initial_velocity_min = 20.0
	motes.initial_velocity_max = 60.0
	motes.scale_amount_min = 1.5
	motes.scale_amount_max = 3.0
	motes.color = Color(col, 0.9)
	motes.global_position = pos
	game.add_child(motes)
	get_tree().create_timer(1.2).timeout.connect(motes.queue_free)

	# A halo of light shards sweeps around the sanctified ring.
	var halo := Node2D.new()
	halo.global_position = pos
	halo.z_index = 5
	game.add_child(halo)
	for i in 8:
		var shard := Sprite2D.new()
		shard.texture = Art.tex("glow")
		shard.modulate = Color(col, 0.75)
		shard.position = Vector2.from_angle(TAU * i / 8.0) * radius * 0.85
		shard.rotation = TAU * i / 8.0 + PI / 2.0
		shard.scale = Vector2(0.9, 0.26)
		halo.add_child(shard)
	var ht := halo.create_tween()
	ht.tween_property(halo, "rotation", TAU * 0.4, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ht.parallel().tween_property(halo, "modulate:a", 0.0, 0.6)
	ht.tween_callback(halo.queue_free)

	var eff := {"aoe": true}
	eff["heal"] = maxf(0.025, float(fx.get("heal", 0.0)))
	if fx.get("pull", 0):
		eff["pull"] = 1
	for e in _enemies_within(pos, radius):
		# Judgment answers each sinner personally: a small light shaft.
		_light_pillar(e.global_position, col, 0.5)
		hit_enemy(e, mult, eff.duplicate())


## Aegis: raise the shield — massive resistances for a beat, and whoever
## strikes you is smitten in return (see take_damage).
func _aegis() -> void:
	game.sfx("equip")
	aegis_time = float(_tfx.get("aegis_dur", 2.5))
	aegis_amt = float(_tfx.get("aegis_amt", 110.0))
	aegis_reflect = float(_tfx.get("aegis_reflect", 0.6))
	aegis_fx = _tfx.duplicate()
	var col := _tcolor if _themed else Color(0.7, 0.85, 1.0)
	_ring_fx(global_position, col, 95.0)
	game.burst(global_position, col, 10)
	game.spawn_text(global_position + Vector2(0, -60), "AEGIS", col)
	# The ward is VISIBLE: four motes of light orbit the hero while the
	# shield holds, then gutter out.
	var orbit := Node2D.new()
	orbit.z_index = 6
	add_child(orbit)
	for i in 4:
		var mote := Sprite2D.new()
		mote.texture = Art.tex("glow")
		mote.modulate = Color(col, 0.85)
		mote.position = Vector2.from_angle(TAU * i / 4.0) * 34.0
		mote.scale = Vector2(0.42, 0.42)
		orbit.add_child(mote)
	var spin := orbit.create_tween()
	spin.set_loops()
	spin.tween_property(orbit, "rotation", TAU, 1.1).as_relative()
	get_tree().create_timer(aegis_time).timeout.connect(func() -> void:
		if is_instance_valid(orbit):
			spin.kill()
			var fade := orbit.create_tween()
			fade.tween_property(orbit, "modulate:a", 0.0, 0.25)
			fade.tween_callback(orbit.queue_free))
	if _tfx.has("aegis_heal"):
		# Holy: lowering the shield releases the blessing.
		var frac: float = _tfx["aegis_heal"]
		get_tree().create_timer(aegis_time).timeout.connect(func() -> void:
			if not dead:
				hp = minf(max_hp, hp + max_hp * frac)
				game.sfx("potion")
				game.burst(global_position, Color(1.0, 0.95, 0.6), 12)
				game.spawn_text(global_position + Vector2(0, -50), "+%d" % int(max_hp * frac), Color(0.5, 1.0, 0.5)))


## Chains of Wrath: tether every nearby enemy, DRAG them to the hammer,
## then the verdict lands on the pile.
func _chains_of_wrath(f := 1.0) -> void:
	var radius := 320.0 * float(_tfx.get("radius_mult", 1.0))
	var targets := _enemies_within(global_position, radius)
	if targets.is_empty():
		cds["ult"] = 1.0
		return
	_ult_sfx()
	game.shake(7.0)
	game.hud.flash_screen(Color(1.0, 0.85, 0.4), 0.4, 0.35)
	var col := _tcolor if _themed else Color(1.0, 0.85, 0.45)
	_ring_fx(global_position, col, radius, true)
	game.spawn_text(global_position + Vector2(0, -64), "CHAINS OF WRATH", Color(1, 0.8, 0.4))
	if _tfx.has("chain_guard"):
		# Aegis: the chains anchor YOU.
		theme_guard_time = 3.0
		theme_guard_amt = float(_tfx["chain_guard"])
	var fx_copy := _tfx.duplicate()
	var heal_frac := float(_tfx.get("chain_heal", 0.0))
	var fmul := f
	for node in targets:
		var e := node as Enemy
		_chain_link_fx(e.global_position, col)
		e.apply_stun(1.2)
		var dir := (e.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var dest: Vector2 = game.clamp_to_zone(global_position + dir * 70.0, e.global_position)
		var tw := e.create_tween()
		tw.tween_property(e, "global_position", dest, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The hammer of verdict falls from the sky while the chains reel in.
	var hammer := Sprite2D.new()
	hammer.texture = Art.tex("w_hammer")
	hammer.modulate = Color(1.0, 0.95, 0.7)
	hammer.scale = Vector2(7, 7)
	hammer.global_position = global_position + Vector2(0, -320)
	hammer.z_index = 30
	game.add_child(hammer)
	var htw := hammer.create_tween()
	htw.tween_property(hammer, "global_position", global_position + Vector2(0, -18), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The verdict lands once the drag finishes.
	get_tree().create_timer(0.34).timeout.connect(func() -> void:
		if is_instance_valid(hammer):
			hammer.queue_free()
		if dead:
			return
		game.sfx("slam")
		game.shake(9.0)
		game.hud.flash_screen(Color(1.0, 0.9, 0.5), 0.35, 0.3)
		_light_pillar(global_position, col, 1.4)
		game.burst(global_position, col, 24)
		game.burst(global_position, Color(1, 1, 1), 10)
		_ring_fx(global_position, col, 150.0)
		var saved := _tfx
		_tfx = fx_copy
		for e2 in _enemies_within(global_position, 150.0):
			_smite_rip(e2.global_position, col)
			hit_enemy(e2, 2.2 * fmul, {"aoe": true, "stun": 0.5})
			if heal_frac > 0.0:
				hp = minf(max_hp, hp + max_hp * heal_frac)
		_tfx = saved)


## A taut chain of REAL links snapping from the hero to a tethered enemy,
## then reeling inward with the drag.
func _chain_link_fx(to: Vector2, col: Color) -> void:
	var span := to - global_position
	var links := maxi(3, int(span.length() / 26.0))
	for i in links:
		var t := (i + 0.5) / float(links)
		var link := Sprite2D.new()
		link.texture = Art.tex("ring")
		link.modulate = Color(col, 0.95)
		link.global_position = global_position + span * t
		link.rotation = span.angle()
		link.scale = Vector2(0.24, 0.15)  # a squashed ring reads as a link
		link.z_index = 7
		game.add_child(link)
		var tw := link.create_tween()
		# Links reel in with the catch, vanishing as they arrive.
		tw.tween_property(link, "global_position", global_position + span * t * 0.2, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(link, "modulate:a", 0.0, 0.3)
		tw.tween_callback(link.queue_free)
	# The taut line itself flashes once as the chain snaps home.
	_beam_fx(global_position, to, col, 0.14)


# ============================================================ warlock kit

func _cast_shadowbolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball", 0.7)  # deeper, hungrier whoosh than the mage's
	_muzzle(dir, _tcolor if _themed else Color(0.75, 0.4, 1.0))
	var p := _proj(dir, mult, "shadowbolt", 460.0)
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if s_passive() == "hollowchoir":
		p.fx["ric"] = 1  # the choir answers: a second bolt leaps onward


## Hex: curse everything around your target — withered, EXPOSED, and
## primed to EXPLODE on death (the class identity).
func _hex(f := 1.0) -> void:
	game.sfx("gate", 1.6)
	var target := auto_aim()
	var center := target.global_position if target else global_position
	var radius := 140.0
	var col := _tcolor if _themed else Color(0.75, 0.4, 1.0)
	# The curse arrives: a collapsing ring — power drawn INTO the victims.
	_ring_fx(center, col, radius, true)
	game.burst(center, col, 12)
	# Void wisps seep up out of the cursed ground.
	var wisps := CPUParticles2D.new()
	wisps.amount = 24
	wisps.lifetime = 0.9
	wisps.one_shot = true
	wisps.explosiveness = 0.6
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = radius * 0.7
	wisps.direction = Vector2(0, -1)
	wisps.spread = 20.0
	wisps.gravity = Vector2(0, -70)
	wisps.initial_velocity_min = 15.0
	wisps.initial_velocity_max = 45.0
	wisps.scale_amount_min = 1.6
	wisps.scale_amount_max = 3.2
	wisps.color = Color(col, 0.9)
	wisps.global_position = center
	game.add_child(wisps)
	get_tree().create_timer(1.4).timeout.connect(wisps.queue_free)
	hex_fx = _tfx.duplicate()
	var eff := {"aoe": true, "vuln": 1.0}  # the curse always EXPOSES
	eff["dot"] = maxf(0.25, float(_tfx.get("dot", 0.0)))
	for e in _enemies_within(center, radius):
		# A dark tendril lashes from the curse's heart to each victim.
		_beam_fx(center, e.global_position, col, 0.16)
		hit_enemy(e, 0.5 * f, eff.duplicate())
		if not e.dying:
			_hex_mark(e)


func _hex_mark(e: Enemy) -> void:
	hexed[e] = 8.0
	if e.has_node("hex_rune"):
		return
	var rune := Sprite2D.new()
	rune.name = "hex_rune"
	rune.texture = Art.glyph_tex("ab_hex", Color(0.8, 0.45, 1.0))
	rune.position = Vector2(0, -30)
	rune.scale = Vector2(0.9, 0.9)
	e.add_child(rune)


## A cursed enemy died: the hex detonates onto its neighbors.
func _hex_detonate(pos: Vector2) -> void:
	var col := Color(0.8, 0.45, 1.0)
	game.sfx("nova", 0.65)
	game.burst(pos, col, 14)
	game.burst(pos, Color(1, 1, 1), 6)
	_ring_fx(pos, col, 110.0)
	# The soul tears open: a white-hot core swells and pops.
	var core := Sprite2D.new()
	core.texture = Art.tex("glow")
	core.modulate = Color(0.95, 0.85, 1.0, 0.95)
	core.global_position = pos
	core.scale = Vector2(0.4, 0.4)
	core.z_index = 8
	game.add_child(core)
	var ct := core.create_tween()
	ct.tween_property(core, "scale", Vector2(2.6, 2.6), 0.16)
	ct.parallel().tween_property(core, "modulate:a", 0.0, 0.2)
	ct.tween_callback(core.queue_free)
	var mult := 1.1 * float(hex_fx.get("hex_boom", 1.0)) * dm("a2")
	var saved := _tfx
	_tfx = {}
	for e in _enemies_within(pos, 110.0):
		hit_enemy(e, mult, {"aoe": true})
	_tfx = saved
	if hex_fx.has("hex_heal"):
		# Pact: every cursed death feeds you.
		var frac: float = hex_fx["hex_heal"]
		hp = minf(max_hp, hp + max_hp * frac)
		game.spawn_text(global_position + Vector2(0, -50), "+%d" % int(max_hp * frac), Color(0.5, 1.0, 0.5))


## Dark Pact: pay in blood for a soul-drain blast, then drink it back
## through a lifesteal surge.
func _dark_pact(f := 1.0) -> void:
	var cost_frac := float(_tfx.get("pact_cost", 0.12))
	var sacrifice := max_hp * cost_frac
	if hp <= sacrifice + 1.0:
		cds["a3"] = 0.5  # you cannot pay in blood you don't have
		return
	hp -= sacrifice
	game.spawn_text(global_position + Vector2(0, -44), "-%d" % int(sacrifice), Color(1.0, 0.3, 0.4))
	pact_time = 5.0
	pact_ls = float(_tfx.get("pact_ls", 0.15))
	var col := _tcolor if _themed else Color(1.0, 0.3, 0.45)
	game.sfx("nova", 0.6)
	game.shake(5.0)
	game.hud.flash_screen(Color(0.6, 0.05, 0.15), 0.35, 0.3)
	# The price is PAID on screen: blood streams INTO the caster...
	var blood := CPUParticles2D.new()
	blood.amount = 26
	blood.lifetime = 0.4
	blood.one_shot = true
	blood.explosiveness = 0.9
	blood.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	blood.emission_sphere_radius = 90.0
	blood.gravity = Vector2.ZERO
	blood.radial_accel_min = -900.0
	blood.radial_accel_max = -600.0
	blood.scale_amount_min = 1.4
	blood.scale_amount_max = 2.6
	blood.color = Color(0.9, 0.15, 0.25)
	add_child(blood)
	get_tree().create_timer(0.8).timeout.connect(blood.queue_free)
	_ring_fx(global_position, col, 170.0, true)
	game.burst(global_position, col, 18)
	# ...then the blast: dark rays lash outward from the pact's heart.
	for i in 8:
		var ang := TAU * i / 8.0 + randf_range(-0.1, 0.1)
		var ray := Sprite2D.new()
		ray.texture = Art.tex("glow")
		ray.modulate = Color(col, 0.85)
		ray.rotation = ang
		ray.position = Vector2.from_angle(ang) * 60.0
		ray.scale = Vector2(0.4, 0.22)
		ray.z_index = 7
		add_child(ray)
		var rt := ray.create_tween()
		rt.tween_property(ray, "position", Vector2.from_angle(ang) * 165.0, 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_property(ray, "scale:x", 2.6, 0.2)
		rt.parallel().tween_property(ray, "modulate:a", 0.0, 0.26)
		rt.tween_callback(ray.queue_free)
	game.spawn_text(global_position + Vector2(0, -64), "DARK PACT", col)
	var eff := {"aoe": true}
	if _tfx.get("pull", 0):
		eff["pull"] = 1
	for e in _enemies_within(global_position, 170.0):
		hit_enemy(e, 1.5 * f, eff.duplicate())


## Void Rift: a rift tears open under the target, drags everything
## inward for a breath, then BURSTS — the delay IS the ability.
func _void_rift(f := 1.0) -> void:
	_ult_sfx()
	var target := auto_aim()
	var pos: Vector2 = target.global_position if target else global_position + facing * 180.0
	var radius := 160.0 * float(_tfx.get("radius_mult", 1.0))
	var col := _tcolor if _themed else Color(0.55, 0.45, 1.0)
	var fx_copy := _tfx.duplicate()
	var fmul := f
	# The growing maw on the ground — you can feel it coming.
	var mark := Sprite2D.new()
	mark.texture = Art.tex("telegraph")
	mark.modulate = Color(col, 0.55)
	mark.global_position = pos
	mark.scale = Vector2(0.6, 0.6)
	mark.z_index = -6
	game.add_child(mark)
	var mt := mark.create_tween()
	mt.tween_property(mark, "scale", Vector2(radius / 32.0, radius / 32.0), 0.3)
	# Indrawn particles: the rift visibly EATS light.
	var indraw := CPUParticles2D.new()
	indraw.amount = 30
	indraw.lifetime = 0.5
	indraw.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	indraw.emission_sphere_radius = radius
	indraw.radial_accel_min = -700.0
	indraw.radial_accel_max = -500.0
	indraw.gravity = Vector2.ZERO
	indraw.scale_amount_min = 1.4
	indraw.scale_amount_max = 2.6
	indraw.color = Color(col, 0.9)
	indraw.global_position = pos
	game.add_child(indraw)
	# The vortex itself: dark blades wheeling INWARD over a swelling
	# void heart — the rift is a thing on the field, not a decal.
	var vortex := Node2D.new()
	vortex.global_position = pos
	vortex.z_index = 5
	game.add_child(vortex)
	for i in 3:
		var ang := TAU * i / 3.0
		var blade := Sprite2D.new()
		blade.texture = Art.tex("slash")
		blade.modulate = Color(col, 0.85)
		blade.rotation = ang + PI
		blade.position = Vector2.from_angle(ang) * radius * 0.45
		blade.scale = Vector2(2.3, 2.3)
		vortex.add_child(blade)
	var vt := vortex.create_tween()
	vt.set_loops()
	vt.tween_property(vortex, "rotation", -TAU, 0.8).as_relative()
	var heart := Sprite2D.new()
	heart.texture = Art.tex("glow")
	heart.modulate = Color(col.r * 0.35, col.g * 0.2, col.b * 0.6, 0.85)
	heart.global_position = pos
	heart.scale = Vector2(0.6, 0.6)
	heart.z_index = 6
	game.add_child(heart)
	var heart_tw := heart.create_tween()
	heart_tw.tween_property(heart, "scale", Vector2(3.2, 3.2), 0.85) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Four pull ticks, then the burst.
	var hard: bool = fx_copy.get("hard_pull", 0)
	for i in 4:
		await get_tree().create_timer(0.22).timeout
		if dead:
			break
		_ring_fx(pos, col, radius, true)
		for e in _enemies_within(pos, radius * 1.3):
			var to_rift: Vector2 = pos - e.global_position
			if to_rift.length() > 20.0:
				e.knock = to_rift.normalized() * (520.0 if hard else 300.0)
	if is_instance_valid(mark):
		mark.queue_free()
	if is_instance_valid(vortex):
		vortex.queue_free()
	if is_instance_valid(heart):
		heart.queue_free()
	indraw.emitting = false
	get_tree().create_timer(0.8).timeout.connect(indraw.queue_free)
	if dead:
		return
	game.sfx("meteor")
	game.shake(12.0)
	game.hud.flash_screen(Color(col, 1.0), 0.5, 0.35)
	game.burst(pos, col, 26)
	game.burst(pos, Color(1, 1, 1), 10)
	_ring_fx(pos, col, radius)
	_ring_fx(pos, Color(1, 1, 1), radius * 0.6)
	# The collapse blows back out: void rays and a popping white core.
	var vcore := Sprite2D.new()
	vcore.texture = Art.tex("glow")
	vcore.modulate = Color(0.95, 0.9, 1.0, 0.95)
	vcore.global_position = pos
	vcore.scale = Vector2(0.5, 0.5)
	vcore.z_index = 8
	game.add_child(vcore)
	var vct := vcore.create_tween()
	vct.tween_property(vcore, "scale", Vector2(3.4, 3.4), 0.18)
	vct.parallel().tween_property(vcore, "modulate:a", 0.0, 0.22)
	vct.tween_callback(vcore.queue_free)
	for i in 10:
		var rang := TAU * i / 10.0 + randf_range(-0.12, 0.12)
		var ray := Sprite2D.new()
		ray.texture = Art.tex("glow")
		ray.modulate = Color(col, 0.9)
		ray.rotation = rang
		ray.global_position = pos + Vector2.from_angle(rang) * 30.0
		ray.scale = Vector2(0.5, 0.2)
		ray.z_index = 7
		game.add_child(ray)
		var rt := ray.create_tween()
		rt.tween_property(ray, "global_position", pos + Vector2.from_angle(rang) * radius, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_property(ray, "scale:x", 2.4, 0.22)
		rt.parallel().tween_property(ray, "modulate:a", 0.0, 0.26)
		rt.tween_callback(ray.queue_free)
	# Scarred space lingers where the rift fed.
	var scar := Sprite2D.new()
	scar.texture = Art.tex("glow")
	scar.modulate = Color(col.r * 0.4, col.g * 0.25, col.b * 0.7, 0.5)
	scar.global_position = pos
	scar.scale = Vector2(radius / 26.0, radius / 34.0)
	scar.z_index = -5
	game.add_child(scar)
	var sct := scar.create_tween()
	sct.tween_property(scar, "modulate:a", 0.0, 1.2)
	sct.tween_callback(scar.queue_free)
	var heal_frac := float(fx_copy.get("rift_heal", 0.0))
	var saved := _tfx
	_tfx = fx_copy
	for e in _enemies_within(pos, radius):
		hit_enemy(e, 3.0 * fmul, {"aoe": true})
		if heal_frac > 0.0:
			hp = minf(max_hp, hp + max_hp * heal_frac)
	_tfx = saved


# ================================================================== survival

func drink_potion() -> void:
	if potion_cd > 0.0 or potions <= 0 or hp >= max_hp or dead:
		return
	potion_cd = 0.6
	potions -= 1
	hp = minf(max_hp, hp + max_hp * 0.6)
	game.sfx("potion")
	game.spawn_text(global_position + Vector2(0, -40), "+HP", Color(0.4, 1.0, 0.4))


func take_damage(amount: float, dmg_type := "phys") -> void:
	if dead or hurt_cd > 0.0:
		return
	if randf() < Stats.eva_curve(eva):
		game.spawn_text(global_position + Vector2(0, -40), "DODGE!", Color(0.7, 0.9, 1.0))
		game.sfx("blink")
		return
	hurt_cd = 0.6
	var res := physres if dmg_type == "phys" else magres
	if theme_guard_time > 0.0:
		res += theme_guard_amt
	if aegis_time > 0.0:
		res += aegis_amt
	if dmg_type != "true":
		amount *= (1.0 - Stats.res_frac(res))
	hp -= amount
	game.sfx("hurt")
	game.shake(4.0)
	game.spawn_text(global_position + Vector2(0, -40), "-%d" % int(amount), Color(1.0, 0.35, 0.3))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		game.on_player_died()
		return
	# Aegis redirect: while the shield is up, whoever strikes you is
	# smitten in return (everything in arm's reach pays for the blow).
	if aegis_time > 0.0:
		var near := _enemies_within(global_position, 100.0)
		if not near.is_empty():
			game.sfx("nova", 1.3)
			game.burst(global_position, Color(1.0, 0.9, 0.5), 10)
			_ring_fx(global_position, Color(1.0, 0.9, 0.5), 90.0)
			var saved := _tfx
			_tfx = aegis_fx
			for e in near:
				# The shield answers: light rips across the attacker.
				_smite_rip(e.global_position, Color(1.0, 0.92, 0.55))
				var eff := {"aoe": true}
				if aegis_fx.get("aegis_knock", 0):
					eff["knock"] = 320.0
				hit_enemy(e, aegis_reflect, eff)
			_tfx = saved


func revive() -> void:
	dead = false
	hp = max_hp
	mp = max_mp
	hurt_cd = 1.5
