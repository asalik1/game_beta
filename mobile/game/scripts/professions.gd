class_name Professions
## The crafting CORE (PROPOSALS/PROFESSIONS.md): trades, the lock/swap economy,
## the mastery tier climb, blueprint gating, and the craft transaction with its
## named-A promotion. PURE static logic over a Player — the data lives on the
## player (profession/mastery/blueprints/swap_*), the knobs in balance.gd, the
## gear rolls in items.gd. The UI (ui/professions.gd) and the autotest both call
## these, so the loop is identical in and out of the panel.
##
## DEFERRED (noted, not built): trade-gated gathering NODES and universal
## SALVAGE (materials already drop), and the CONSUMABLE outputs (Alchemist
## potions / Blacksmith bench-stones / Tailor bags). This slice = GEAR only.


# ---------------------------------------------------------------- trades ---

## Every trade key in display order (Balance.PROFESSION_ORDER).
static func trades() -> Array:
	return Balance.PROFESSION_ORDER

static func trade_name(trade: String) -> String:
	return String(Balance.PROFESSION_TRADES.get(trade, {}).get("name", trade.capitalize()))

static func trainer_name(trade: String) -> String:
	return String(Balance.PROFESSION_TRADES.get(trade, {}).get("trainer", ""))

## The gear slots a trade crafts ([] for an unknown/empty trade).
static func slots_of(trade: String) -> Array:
	return Balance.PROFESSION_TRADES.get(trade, {}).get("slots", [])

## The trade that crafts a given slot ("" if none — every slot maps to one).
static func trade_of_slot(slot: String) -> String:
	for t in Balance.PROFESSION_ORDER:
		if slot in slots_of(t):
			return t
	return ""

## The slots the player's ACTIVE trade can craft ([] with no trade locked).
static func active_slots(p: Player) -> Array:
	return slots_of(p.profession)


# --------------------------------------------------------------- mastery ---

## Mastery points the player holds in a trade (0 if untouched). Persists per
## trade across swaps — locking sets the ACTIVE trade, never resets progress.
static func points(p: Player, trade := "") -> int:
	var t := trade if trade != "" else String(p.profession)
	return int(p.mastery.get(t, 0))

static func band(p: Player, trade := "") -> String:
	return Balance.mastery_band(points(p, trade))

## The highest grade the active trade may currently craft (mastery cap).
static func max_grade(p: Player) -> String:
	return Balance.mastery_max_grade(points(p))


# --------------------------------------------------------------- crafting ---

## Craftable grades for a slot RIGHT NOW: F..(mastery cap), with B/A also gated
## on owning the learned generic blueprint. S never appears (drop-only).
static func craftable_grades(p: Player, slot: String) -> Array:
	var out: Array = []
	var cap := max_grade(p)
	for g in Items.GRADES:
		if g == "S":
			break
		if Items.GRADES.find(g) > Items.GRADES.find(cap):
			break
		if g in Items.BLUEPRINT_GRADES and not p.has_blueprint(slot, g):
			continue
		out.append(g)
	return out

## Why a (slot, grade) craft can't proceed — "" means it CAN. This is the SINGLE
## gate; craft() re-checks it so the UI can only ever fire a legal craft.
static func craft_blocked(p: Player, slot: String, grade: String) -> String:
	if p.profession == "":
		return "Lock a trade first."
	if slot not in active_slots(p):
		return "Your trade doesn't craft %s." % slot
	if grade == "S" or Items.GRADES.find(grade) < 0:
		return "S-grade is drop-only — never craftable."
	if Items.GRADES.find(grade) > Items.GRADES.find(max_grade(p)):
		return "%s mastery too low for grade %s." % [band(p), grade]
	if grade in Items.BLUEPRINT_GRADES and not p.has_blueprint(slot, grade):
		return "Needs the generic %s %s blueprint." % [grade, slot.capitalize()]
	var fam := Balance.craft_material(slot)
	var need := int(Balance.CRAFT_MATERIAL_COST.get(grade, 0))
	if p.material_count(fam, grade) < need:
		return "Needs %d %s (grade %s); have %d." % [need, fam, grade, p.material_count(fam, grade)]
	var fee := int(Balance.CRAFT_GOLD_FEE.get(grade, 0))
	if p.gold < fee:
		return "Needs %d gold; have %d." % [fee, p.gold]
	return ""

## The craft transaction. Validates (craft_blocked), spends materials + the gold
## fee, grants trade mastery, then ROLLS a class-matched GENERIC gear of the
## slot/grade. On a generic A there is a small promotion chance to a random
## NAMED-A unique of the crafter's class+slot (reuses the UNIQUES table). Caps at
## A — S/S-named never craft. `force_promote` forces the A promotion attempt
## (tests). Returns {ok, item, promoted, mastery_gain, reason}. The CALLER banks
## the item (add_item, or mail on a full bag).
static func craft(p: Player, slot: String, grade: String, rng: RandomNumberGenerator,
		force_promote := false) -> Dictionary:
	var blocked := craft_blocked(p, slot, grade)
	if blocked != "":
		return {"ok": false, "item": {}, "promoted": false, "mastery_gain": 0, "reason": blocked}
	var fam := Balance.craft_material(slot)
	var need := int(Balance.CRAFT_MATERIAL_COST.get(grade, 0))
	var fee := int(Balance.CRAFT_GOLD_FEE.get(grade, 0))
	p.take_material(fam, grade, need)
	p.gold -= fee
	var gain := int(Balance.CRAFT_MASTERY_BY_GRADE.get(grade, 0))
	p.mastery[p.profession] = points(p) + gain
	# act=0 forces a plain class-matched generic (no drop-channel named roll).
	var item: Dictionary = Items.roll_item_of(slot, grade, rng, p.cls, "", 0)
	var promoted := false
	if grade == "A" and (force_promote or rng.randf() < Balance.CRAFT_PROMOTE_CHANCE):
		var pool := Items.uniques_of(p.cls, "A", slot)
		if not pool.is_empty():
			item = Items.make_unique(pool[rng.randi_range(0, pool.size() - 1)], rng)
			promoted = true
	return {"ok": true, "item": item, "promoted": promoted, "mastery_gain": gain, "reason": ""}


# ------------------------------------------------------------- blueprints ---

## Buy a generic B/A blueprint at the deterministic formula price (§5 shop path).
## Learn-on-buy. Returns {ok, cost, reason}.
static func buy_blueprint(p: Player, slot: String, grade: String) -> Dictionary:
	if grade not in Items.BLUEPRINT_GRADES:
		return {"ok": false, "cost": 0, "reason": "Only B and A blueprints exist."}
	if p.has_blueprint(slot, grade):
		return {"ok": false, "cost": 0, "reason": "Already known."}
	var cost := Balance.blueprint_price(slot, grade)
	if p.gold < cost:
		return {"ok": false, "cost": cost, "reason": "Needs %d gold." % cost}
	p.gold -= cost
	p.learn_blueprint(slot, grade)
	return {"ok": true, "cost": cost, "reason": ""}


# ----------------------------------------------------- lock / swap economy ---

## Trusted-clock week index (Vigils/renown epoch), for the swap-cost reset.
static func week_index(p: Player) -> int:
	if p.game == null:
		return 0
	return int(p.game.daily_day_index() / 7)

## Roll the swap counter over at a new week (cost back to base). Idempotent.
static func weekly_reset(p: Player) -> void:
	var week := week_index(p)
	if p.swap_week != week:
		p.swap_week = week
		p.swap_cost_step = 0

## Gold to swap the active trade RIGHT NOW (base 5k x2 per swap this week).
static func swap_cost(p: Player) -> int:
	weekly_reset(p)
	return Balance.swap_cost(p.swap_cost_step)

## Lock/switch the active trade. The FIRST lock (no trade yet) is FREE — picking
## your trade is not a swap; every later switch costs swap_cost() and bumps the
## weekly doubling step. Mastery PERSISTS per trade. Returns {ok, cost, reason}.
static func lock_trade(p: Player, trade: String) -> Dictionary:
	if not Balance.PROFESSION_TRADES.has(trade):
		return {"ok": false, "cost": 0, "reason": "Unknown trade."}
	if p.profession == trade:
		return {"ok": false, "cost": 0, "reason": "Already your trade."}
	weekly_reset(p)
	var free_lock := p.profession == ""
	var cost := 0 if free_lock else swap_cost(p)
	if not free_lock and p.gold < cost:
		return {"ok": false, "cost": cost, "reason": "Needs %d gold to swap." % cost}
	if not free_lock:
		p.gold -= cost
		p.swap_cost_step += 1
	p.profession = trade
	if not p.mastery.has(trade):
		p.mastery[trade] = 0
	return {"ok": true, "cost": cost, "reason": ""}


# ----------------------------------------------------- synthesis (Alkahest) ---
# The Alchemy capstone (PROPOSALS/CONSUMABLE_GRADES.md §9): with the Alkahest
# Codex learned, Kesh fuses a clean S + the laced A of one family into a Grand
# potion (a modest step above S, no drawback — the Codex neutralises the
# blightwater). Each synthesis eats BOTH ultra-rare bottles + a gold fee — a
# deliberately bad gold-per-power trade (the endgame flex + gold sink). Pure
# static logic over the Player, like craft(); the UI (ui/synthesis.gd) and the
# autotest both call these so the loop is identical in and out of the panel.

## The family-shape keys a Grand can be synthesised for (one per S bottle).
static func synth_families() -> Array:
	return Balance.POT_GRAND_FAMILIES

## Buy the Alkahest Codex from Kesh (~100k, learn-on-buy). It is a RECIPE, so the
## shop-caps-at-A rule does not apply. Returns {ok, cost, reason}.
static func buy_codex(p: Player) -> Dictionary:
	if p.knows_alkahest:
		return {"ok": false, "cost": 0, "reason": "The Alkahest Codex is already learned."}
	var cost := int(Balance.ALKAHEST_CODEX_PRICE)
	if p.gold < cost:
		return {"ok": false, "cost": cost, "reason": "Needs %d gold; have %d." % [cost, p.gold]}
	p.gold -= cost
	p.learn_alkahest()
	return {"ok": true, "cost": cost, "reason": ""}

## Why a family's synthesis can't proceed — "" means it CAN. synthesize()
## re-checks this so the UI can only ever fire a legal synthesis.
static func synth_blocked(p: Player, fs: String) -> String:
	if not p.knows_alkahest:
		return "Learn the Alkahest Codex first."
	if not Items.POTION_SHAPES.has(fs) or not (fs in Balance.POT_GRAND_FAMILIES):
		return "No Grand recipe for this family."
	if p.find_potion_by(fs, "S", "accord").is_empty():
		return "Needs a clean S %s." % Items.potion_name(fs, "S", "accord")
	if p.find_potion_by(fs, "A", "black").is_empty():
		return "Needs the laced A %s." % Items.potion_name(fs, "A", "black")
	var fee := int(Balance.SYNTHESIS_FEE)
	if p.gold < fee:
		return "Needs %d gold; have %d." % [fee, p.gold]
	return ""

## The synthesis transaction. Validates (synth_blocked), consumes the clean S +
## the laced A + the gold fee, then mints one Grand potion of that family.
## Returns {ok, item, fee, reason}. The CALLER banks the item (add_consumable, or
## mail on a full bag — though consuming two and adding one always frees a slot).
static func synthesize(p: Player, fs: String) -> Dictionary:
	var blocked := synth_blocked(p, fs)
	if blocked != "":
		return {"ok": false, "item": {}, "fee": 0, "reason": blocked}
	var s_pot := p.find_potion_by(fs, "S", "accord")
	var a_pot := p.find_potion_by(fs, "A", "black")
	p.consumables.erase(s_pot)
	p.consumables.erase(a_pot)
	var fee := int(Balance.SYNTHESIS_FEE)
	p.gold -= fee
	return {"ok": true, "item": Items.make_grand_potion(fs), "fee": fee, "reason": ""}
