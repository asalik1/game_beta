extends CharacterBody2D
## PLAYER, layer 1 of 3 — state, stats, themes, gear/bag and
## progression. The class is split across an inheritance chain so each
## file stays readable while code and `self` semantics stay verbatim:
##   player_core.gd  <- player_combat.gd <- player.gd (class_name Player)
## The hero. Classes scale on a primary attribute (STR/AGI/INT), fight
## with 3 basics + 1 ultimate (keyboard, auto-aimed), and customize via:
##  - THEMES: each ability can be assigned any unlocked elemental theme,
##    which changes its behavior (poison DoTs, shadow crits, ice roots...)
##  - the row-based skill tree (see skills.gd)
##  - gear with gem sockets
## All combat math (crit curves, resistances, penetration, evasion,
## true damage) lives in stats.gd.

const SPEED_BASE_REF := 260.0

var game: Game  # set by game.gd

# --- identity ---
var cls := "warrior"
var ability_theme := {"a1": "", "a2": "", "a3": "", "ult": ""}
var themes_known := 0

# --- Phase 1 story trackers (persisted with the save from day one) ---
var resonance := 0.0     # -100 (Temptation) .. +100 (Virtue), per DESIGN.md
var faction_standing := {"accord": 0, "cinderborn": 0, "wildfang": 0, "choir": 0}


## Nudge Resonance. The world reacts through dialogue and haggle bands
## (Story.res_band); the Stats tab surfaces the number and a one-line
## explanation (playtest round 6: "I can't even SEE this stat").
func add_resonance(delta: float) -> void:
	resonance = clampf(resonance + delta, -100.0, 100.0)

# --- progression ---
var level := 1
var xp := 0
var skill_points := 0
var tree_points := {}    # skill cell id -> points (0..5)
# The four attributes convert at CLASS ratios (Classes.ATTR_SCALE);
# the substats convert 1:1 for everyone (Classes.SUBSTAT_SCALE).
var attr_points := {"STR": 0, "AGI": 0, "INT": 0, "VIT": 0,
	"PhysRes": 0, "MagRes": 0, "CritRes": 0, "DEX": 0, "PhysPen": 0, "MagPen": 0}
var unspent_attr := 0    # +1 per level, allocate in the skills menu
var gold := 15           # scarcity pass: merchants and haggling matter
var potions := 2

# --- gear ---
var equipment := {}      # slot -> item Dictionary
var backpack: Array = []
var gem_bag: Array = []  # loose gems
# The BAG is carried capacity for everything not equipped: gear
# (backpack), gem STACKS and consumables share its slots. Bigger bags
# drop from elites (Items.BAG_SLOTS: F 15 ... S 100).
var bag: Dictionary = Items.make_bag(Balance.STARTER_BAG_GRADE)
var consumables: Array = []   # reset stones etc. ({"kind": "stone", ...})

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
var regen_pct := 0.0     # % of max HP regenerated per second (melee passives)
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
	# The curve assumes side rooms: skipping the optional wings of the
	# zone graph leaves you under-leveled for the boss doors (DESIGN.md).
	return Balance.XP_BASE + level * Balance.XP_PER_LEVEL


## Rebuild every derived stat: class base + passive + gear (incl. gems)
## + skill tree points.
func recalc() -> void:
	var base: Dictionary = Classes.CLASSES[cls]
	var b := {"atk_flat": 0.0, "atk_pct": 0.0, "hp_flat": 0.0, "hp_pct": 0.0,
		"mp_flat": 0.0, "speed_pct": 0.0, "crit": 0.0, "crit_dmg": 0.0,
		"cdr": 0.0, "lifesteal": 0.0, "regen_pct": 0.0, "physres": 0.0, "magres": 0.0,
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
	# Allocated attribute points: the four attributes convert at CLASS
	# scaling ratios (an assassin gets far more from AGI than from STR);
	# substat points (PhysRes, DEX, pens...) convert 1:1 for everyone.
	var attr_scale: Dictionary = Classes.ATTR_SCALE[cls]
	for attr in attr_points:
		var pts: int = attr_points[attr]
		if pts <= 0:
			continue
		var conv: Dictionary = Classes.SUBSTAT_SCALE.get(attr, attr_scale.get(attr, {}))
		for stat in conv:
			b[stat] = b.get(stat, 0.0) + conv[stat] * pts

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
	regen_pct = b["regen_pct"]
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

func bag_capacity() -> int:
	return int(bag.get("slots", Items.BAG_SLOTS[Balance.STARTER_BAG_GRADE]))


## Gems STACK: one bag slot per stat+level kind, however many you hold
## (playtest round 7 — the relief valve for gem hoards).
func gem_stacks() -> int:
	var kinds := {}
	for gem in gem_bag:
		kinds["%s_%d" % [gem["stat"], gem["lvl"]]] = true
	return kinds.size()


func bag_used() -> int:
	return backpack.size() + gem_stacks() + consumables.size()


func add_item(item: Dictionary) -> bool:
	if bag_used() >= bag_capacity():
		strip_gems(item)
		gold += maxi(1, Items.price(item) / 2)
		game.spawn_text(global_position + Vector2(0, -50), "Bag full! Sold for gold", Color(1, 0.9, 0.4))
		return false
	backpack.append(item)
	return true


## Loose gem pickup (chests, elites). A gem that fits an EXISTING
## stack is always free; only a brand-new stack needs a free slot.
## Internal gem machinery (synthesize, socket removal, sell-stripping)
## bypasses capacity entirely so it never jams.
func gain_gem(gem: Dictionary) -> bool:
	var stacks := false
	for g in gem_bag:
		if g["stat"] == gem["stat"] and g["lvl"] == gem["lvl"]:
			stacks = true
			break
	if not stacks and bag_used() >= bag_capacity():
		gold += 2 + int(gem["lvl"]) * 3
		game.spawn_text(global_position + Vector2(0, -50), "Bag full! Gem sold", Color(1, 0.9, 0.4))
		return false
	gem_bag.append(gem)
	return true


func add_consumable(c: Dictionary) -> bool:
	if bag_used() >= bag_capacity():
		gold += 25
		game.spawn_text(global_position + Vector2(0, -50), "Bag full! Sold for gold", Color(1, 0.9, 0.4))
		return false
	consumables.append(c)
	return true


## Use a consumable from the bag (the bag UI calls this).
func use_consumable(c: Dictionary) -> void:
	if not consumables.has(c):
		return
	match str(c.get("id", "")):
		"reset_stone":
			var refunded := 0
			for attr in attr_points:
				refunded += int(attr_points[attr])
				attr_points[attr] = 0
			unspent_attr += refunded
			consumables.erase(c)
			recalc()
			game.sfx("levelup")
			game.spawn_text(global_position + Vector2(0, -56),
				"TALENTS RESET — %d points refunded (press T)" % refunded, Color(0.6, 0.9, 1.0))


## A looted bag: bigger than the current one upgrades in place,
## anything else converts to gold.
func acquire_bag(b: Dictionary) -> bool:
	if int(b.get("slots", 0)) > bag_capacity():
		bag = b
		game.sfx("levelup")
		game.spawn_text(global_position + Vector2(0, -56),
			"BAG UPGRADED: %s (%d slots)" % [b["name"], int(b["slots"])], Color(0.95, 0.85, 0.5))
		return true
	gold += Items.bag_price(str(b.get("grade", "F")))
	game.spawn_text(global_position + Vector2(0, -50), "Spare bag sold for gold", Color(1, 0.9, 0.4))
	return false


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
	# A finished chapter pays NO XP on replays — farm gold and gear,
	# never levels (playtest round 3: "clear ch1 2000 times, come out
	# max level"). Dev mode keeps its level buttons for testing.
	if game.get_flag("completed_" + game.chapter_id, false) and not game.dev_mode:
		return
	xp += amount
	game.spawn_text(global_position + Vector2(0, -56), "+%d XP" % amount, Color(1.0, 0.9, 0.4))
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += Balance.SKILL_POINTS_PER_LEVEL
		unspent_attr += Balance.ATTR_POINTS_PER_LEVEL
		recalc()
		hp = max_hp
		mp = max_mp
		game.sfx("levelup")
		game.spawn_text(global_position + Vector2(0, -72), "LEVEL UP!  Lv %d  (+1 skill, +1 attribute point — press T)" % level, Color(0.5, 0.9, 1.0))
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


