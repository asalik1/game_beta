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
	return lifesteal + (0.15 if berserk_time > 0.0 else 0.0)


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
	mp = minf(max_mp, mp + (6.0 if cls == "mage" else 4.0) * delta)
	anim_t += delta

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

	# Buff aura pulse (berserk = red, guard = blue).
	if berserk_time > 0.0 or theme_guard_time > 0.0:
		aura.visible = true
		aura.modulate = Color(1.0, 0.25, 0.15, 0.7) if berserk_time > 0.0 else Color(0.4, 0.6, 1.0, 0.6)
		var pulse := 2.2 + sin(anim_t * 9.0) * 0.25
		aura.scale = Vector2(pulse, pulse)
	else:
		aura.visible = false


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
			if _tfx.get("end_slam", 0):
				# Earth: the charge ends in a ground-shattering slam.
				game.shake(5.0)
				game.sfx("slam", 0.8)
				game.burst(global_position, _tcolor, 14)
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


## Melee strike. style "swing" = crescent arc; "stab" = straight thrust
## (a piercing streak, and the held weapon lunges instead of swiping).
func _melee_arc(mult: float, reach: float, fx_name: String, effects := {}, style := "swing", snd := "slash") -> void:
	game.sfx(snd)
	melee_swing = 0.16
	melee_style = style
	var dir := aim_dir(220.0)
	melee_dir = dir
	if style == "stab":
		# Thrust streak: a stretched flash of light along the stab line.
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
	else:
		var spr := Sprite2D.new()
		spr.texture = Art.tex(fx_name)
		spr.rotation = dir.angle()
		spr.scale = Vector2(2.8, 2.8) * (reach / 78.0)
		spr.position = dir * reach * 0.5
		if _themed:
			spr.modulate = _tcolor
		spr.z_index = 6
		add_child(spr)
		var tween := spr.create_tween()
		tween.tween_property(spr, "modulate:a", 0.0, 0.14)
		tween.tween_callback(spr.queue_free)
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
	var p := _proj(dir, mult, "arrow", 520.0)
	if s_passive() == "ricochet":
		p.fx["ric"] = 1


func _cast_bolt(dir: Vector2, mult: float) -> void:
	game.sfx("fireball")  # a breathy fire fwoosh, not an arcane laser
	var p := _proj(dir, mult, "fireball", 440.0 * float(_tfx.get("proj_speed", 1.0)))
	p.pierce = p.pierce or bool(_tfx.get("pierce", 0))
	if s_passive() == "phoenix":
		p.fx["splash"] = maxf(p.fx.get("splash", 0.0), 0.5)
		p.fx["burn"] = current_atk() * 0.35


func _whirlwind(f := 1.0) -> void:
	game.sfx("sword")
	var radius := 115.0 * float(_tfx.get("radius_mult", 1.0))
	var spr := Sprite2D.new()
	spr.texture = Art.tex("glow")
	spr.modulate = Color(_tcolor, 0.8) if _themed else Color(1, 1, 1, 0.8)
	spr.scale = Vector2(4.5, 4.5)
	add_child(spr)
	var tween := spr.create_tween()
	tween.tween_property(spr, "scale", Vector2(6, 6) * (radius / 115.0), 0.2)
	tween.parallel().tween_property(spr, "modulate:a", 0.0, 0.2)
	tween.tween_callback(spr.queue_free)
	var eff := {"stagger": 0.3, "aoe": true}
	if not _tfx.get("pull", 0):  # Earth drags them in instead of flinging
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
	var eff := storm_fx.duplicate()
	eff["aoe"] = true
	hit_enemy(e, 0.8, eff)


func _frost_nova(f := 1.0) -> void:
	game.sfx("nova")
	game.shake(5.0)
	var spr := Sprite2D.new()
	spr.texture = Art.tex("glow")
	spr.modulate = Color(_tcolor, 0.9) if _themed else Color(0.4, 0.7, 1.0, 0.9)
	spr.scale = Vector2(3, 3)
	add_child(spr)
	var tween := spr.create_tween()
	tween.tween_property(spr, "scale", Vector2(8.5, 8.5), 0.25)
	tween.parallel().tween_property(spr, "modulate:a", 0.0, 0.3)
	tween.tween_callback(spr.queue_free)
	# A real panic button: big damage, shove everything away, slow it.
	# (Fire ring burns instead of shoving; Wind implodes them INTO you.)
	var radius := 160.0 * float(_tfx.get("radius_mult", 1.0))
	var eff := {"slow": 0.5, "slow_dur": 2.5, "aoe": true}
	if not (_tfx.get("no_knock", 0) or _tfx.get("pull", 0)):
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
	_dash_strike(190.0 * float(_tfx.get("dash_mult", 1.0)), 0.8, eff)


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
func _mist(pos: Vector2, radius: float, dps_mult: float, color: Color, dur := 2.5) -> void:
	var cloud := Sprite2D.new()
	cloud.texture = Art.tex("glow")
	cloud.modulate = Color(color, 0.45)
	cloud.global_position = pos
	cloud.scale = Vector2(1.2, 1.2)
	cloud.z_index = 4
	game.add_child(cloud)
	var grow := cloud.create_tween()
	grow.tween_property(cloud, "scale", Vector2(radius / 24.0, radius / 24.0), 0.5)
	var puff := CPUParticles2D.new()
	puff.amount = 18
	puff.lifetime = 0.8
	puff.spread = 180.0
	puff.initial_velocity_min = 10.0
	puff.initial_velocity_max = 40.0
	puff.gravity = Vector2(0, -10)
	puff.scale_amount_min = 2.0
	puff.scale_amount_max = 4.0
	puff.color = Color(color, 0.7)
	cloud.add_child(puff)
	var ticks := int(dur / 0.4)
	for i in ticks:
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(cloud) or dead:
			return
		for e in _enemies_within(pos, radius):
			e.apply_burn(current_atk() * dps_mult, 1.2, Color(color, 1.0))
	var fade := cloud.create_tween()
	fade.tween_property(cloud, "modulate:a", 0.0, 0.5)
	fade.tween_callback(cloud.queue_free)


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


func revive() -> void:
	dead = false
	hp = max_hp
	mp = max_mp
	hurt_cd = 1.5
