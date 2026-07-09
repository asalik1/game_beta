extends SceneTree
## REWARD-ECONOMY AUDIT (dev tool, headless): prints what each chapter
## actually PAYS — first run vs replay, per faucet — plus the act's gold
## sinks, so reward calibration is measurement, not vibes (doctrine:
## measure-then-correct). Rerun whenever reward numbers move.
## Run:  godot --headless --path game --script res://econ_audit.gd
##
## Estimates, clearly labeled: chest gear is valued at SELL price (the
## floor a duplicate is worth); elite level/gold approximated from its
## host room's pack. Seeded-roll faucets (elites, risk events) are
## expected values across characters.

# One place for the model's time assumptions (minutes).
const FIRST_RUN_MIN := 55.0   # mid design band (45-75)
const REPLAY_MIN := 32.0      # knows the map, skips dialogue, spine+cherry-pick


func _init() -> void:
	Story.load_content()
	print("=".repeat(78))
	print("REWARD ECONOMY AUDIT   (gold values are POST GOLD_MULT %.1f; est = estimate)" % Balance.GOLD_MULT)
	print("=".repeat(78))
	for chid in Story.CHAPTER_LIST:
		_audit_chapter(String(chid))
	_sinks()
	quit(0)


func _room_type(zone: Dictionary) -> String:
	var t := String(zone.get("type", ""))
	if t != "":
		return t
	if String(zone.get("boss", "")) != "":
		return "boss"
	return "combat" if not zone.get("enemies", []).is_empty() else "safe"


## Sell value of one +0 gear item of `grade` (SELL = intrinsic price x fraction,
## matching menus.gd: Items.price() x MERCHANT_SELL_FRACTION).
func _grade_sell(grade: String) -> float:
	return 22.0 * float(Items.GRADE_MULT[grade]) * Balance.MERCHANT_SELL_FRACTION


## Expected sell value of one gear roll from a {grade: weight} BAND. Every gear
## channel now rolls a weighted grade then sells for its intrinsic value:
## GENERAL band = chest / shop / spoils / gamble, BOSS band = the boss gear
## channel (2026-07-09 loot BANDS replaced the old chest-tier + act-cap table).
func _band_gear_value(weights: Dictionary) -> float:
	var total := 0.0
	var value := 0.0
	for g in weights:
		var w: float = float(weights[g])
		total += w
		value += w * _grade_sell(String(g))
	return value / maxf(total, 1.0)


## Chest bonus gold by tier (chest.gd: randi(3,8) x (1 + tier index), EV 5.5x).
func _chest_gold_bonus(tier: String) -> float:
	return 5.5 * float(1 + ["wood", "silver", "gold"].find(tier))


## Chest gem CHANCE by tier (chest.gd; only realized once gems drop, ch4+).
func _chest_gem_chance(tier: String) -> float:
	return {"wood": 0.25, "silver": 0.6, "gold": 1.0}[tier]


## One chest's total gold-equivalent: bonus gold + gear sell value. Gear grade no
## longer depends on the chest TIER — every chest (wood/silver/gold) rolls the
## chapter's GENERAL band via Items.roll_chapter_gear; tier only sets the bonus
## gold and gem chance (gems are counted separately). (2026-07-09)
func _chest_value(tier: String, chid: String) -> float:
	return _chest_gold_bonus(tier) + _band_gear_value(Balance.gear_weights(chid))


func _audit_chapter(chid: String) -> void:
	var ch: Dictionary = Story.chapter(chid)
	var zones: Array = ch["zones"]
	var cap := Balance.chapter_gear_ceiling(chid)  # 2026-07-09: band ceiling, for the label only
	var gems_on := Balance.regular_gems_drop(chid) # ch1-3 drop NO gems (gear + gold only)

	var kills := 0
	var lvl_sum := 0           # for the elite gem sure/early threshold (ELITE_GEM_SURE_LEVEL)
	var mob_gold := 0.0
	var xp := 0
	var rooms := {"combat": 0, "boss": 0, "social": 0, "dead_end": 0, "resonance": 0, "other": 0}
	var pack_rooms := 0        # combat rooms with authored packs (elite/curse hosts)
	var caches := 0.0          # cache chests, in gold-equivalent
	var cache_gems := 0.0      # gems from cache chests (chest gem chance)
	var pack_avg_gold := 0.0
	var bosses: Array = []

	for zone in zones:
		var zd: Dictionary = zone
		var rt := _room_type(zd)
		rooms[rt if rooms.has(rt) else "other"] += 1
		var packs: Array = zd.get("enemies", [])
		if not packs.is_empty() and String(zd.get("boss", "")) == "":
			pack_rooms += 1
		var room_gold := 0.0
		for spawn in packs:
			var kind := String(spawn[0])
			var lvl := int(spawn[4]) if spawn.size() > 4 else int(Story.ALL_ENEMIES[kind]["level"])
			var st := Story.enemy_stats_at(kind, lvl)
			kills += 1
			lvl_sum += lvl
			room_gold += float(st["gold"])
			xp += int(st["xp"])
		mob_gold += room_gold
		if not packs.is_empty():
			pack_avg_gold += room_gold / packs.size()
		var cache_tier := String(zd.get("cache", ""))
		if cache_tier != "":
			caches += _chest_value(cache_tier, chid)
			cache_gems += _chest_gem_chance(cache_tier)
		var bkind := String(zd.get("boss", ""))
		if bkind != "" and not bosses.has(bkind):
			bosses.append(bkind)
	if pack_rooms > 0:
		pack_avg_gold /= pack_rooms

	# Hidden caches (exploration premium): buried chests in some dead ends.
	caches += rooms["dead_end"] * Balance.HIDDEN_CACHE_CHANCE \
		* (Balance.HIDDEN_CACHE_GOLD_TIER * _chest_value("gold", chid)
		+ (1.0 - Balance.HIDDEN_CACHE_GOLD_TIER) * _chest_value("silver", chid))
	cache_gems += rooms["dead_end"] * Balance.HIDDEN_CACHE_CHANCE \
		* (Balance.HIDDEN_CACHE_GOLD_TIER * _chest_gem_chance("gold")
		+ (1.0 - Balance.HIDDEN_CACHE_GOLD_TIER) * _chest_gem_chance("silver"))

	# Mob chest EV: every kill rolls wood 18% / silver 4%.
	var mob_chests := kills * (Balance.MOB_WOOD_CHEST_CHANCE * _chest_value("wood", chid)
		+ Balance.MOB_SILVER_CHEST_CHANCE * _chest_value("silver", chid))
	var mob_chest_gems := kills * (Balance.MOB_WOOD_CHEST_CHANCE * _chest_gem_chance("wood")
		+ Balance.MOB_SILVER_CHEST_CHANCE * _chest_gem_chance("silver"))

	# Elite EV (seeded): social rooms 30% + pack rooms 18%.
	var elites: float = rooms["social"] * Balance.ELITE_SOCIAL_ROOM_CHANCE \
		+ pack_rooms * Balance.ELITE_COMBAT_AMBUSH_CHANCE
	var elite_gold: float = elites * (pack_avg_gold * (Balance.ELITE_GOLD_MULT - 1)
		+ Balance.ELITE_GOLD_CHEST_CHANCE * _chest_value("gold", chid)
		+ (1.0 - Balance.ELITE_GOLD_CHEST_CHANCE) * _chest_value("silver", chid))
	# Elite gems: a direct elite gem (guaranteed at ELITE_GEM_SURE_LEVEL, else
	# ELITE_GEM_EARLY_CHANCE — most Act 1 elites are below the sure level) PLUS
	# the gem from the elite's own gold/silver chest.
	var avg_lvl: float = float(lvl_sum) / maxf(1.0, float(kills))
	var elite_gem_each: float = 1.0 if avg_lvl >= float(Balance.ELITE_GEM_SURE_LEVEL) else Balance.ELITE_GEM_EARLY_CHANCE
	var elite_chest_gem: float = Balance.ELITE_GOLD_CHEST_CHANCE * _chest_gem_chance("gold") \
		+ (1.0 - Balance.ELITE_GOLD_CHEST_CHANCE) * _chest_gem_chance("silver")
	var elite_gems := elites * (elite_gem_each + elite_chest_gem)

	# Boss payouts at their story anchors: gold + the BOSS gear channel (a
	# BOSS_GEAR_CHANCE roll for a boss-band grade — no golden chest; boss gems are
	# the first_gems / replay_gems channel below, matching on_boss_died).
	var boss_gear_val := _band_gear_value(Balance.boss_weights(chid))
	var boss_gold := 0.0
	var boss_lv_sum := 0
	for bkind in bosses:
		var st := Story.enemy_stats_at(String(bkind), int(Story.ALL_ENEMIES[bkind]["level"]))
		boss_gold += float(st["gold"]) + Balance.BOSS_GEAR_CHANCE * boss_gear_val
		boss_lv_sum += int(st["level"])
	var first_gems := bosses.size() * Balance.BOSS_GEMS_FIRST_CLEAR
	var replay_gems := 0.0
	for bkind in bosses:
		replay_gems += Balance.boss_gem_chance(int(Story.ALL_ENEMIES[bkind]["level"]))

	# Risk events EV (seeded; assumes the player engages when offered). A cursed
	# room's payout is a gold chest (gem chance 1.0) PLUS a guaranteed payout gem.
	var curse_gold: float = pack_rooms * Balance.CURSED_ROOM_CHANCE * _chest_value("gold", chid)
	var curse_gems: float = pack_rooms * Balance.CURSED_ROOM_CHANCE * (1.0 + _chest_gem_chance("gold"))
	var quiet: int = rooms["social"] + rooms["dead_end"]
	# Shrine EV vs its cost: 60% bless (40% gem≈0g here, 30% 3x back, 20% silver chest, 10% elixir≈35g), 40% bane.
	var shrine_n: float = quiet * Balance.SHRINE_ROOM_CHANCE
	var scost := float(Balance.SHRINE_COST_BASE)  # L1-ish; scales with level like its rewards
	var shrine_gold: float = shrine_n * (Balance.SHRINE_BLESS_CHANCE
		* (0.3 * 3.0 * scost + 0.2 * _chest_value("silver", chid) + 0.1 * 35.0) - scost
		- (1.0 - Balance.SHRINE_BLESS_CHANCE) * 0.4 * scost)
	var shrine_gems: float = shrine_n * Balance.SHRINE_BLESS_CHANCE * 0.4

	# First-clear beat: gold in hand + mailed spoils (cap-grade item + Lv2 gem).
	var max_boss_lv := 1
	for bkind in bosses:
		max_boss_lv = maxi(max_boss_lv, int(Story.ALL_ENEMIES[bkind]["level"]))
	var fc_gold := Balance.FIRST_CLEAR_GOLD * Balance.daily_gold_mult(max_boss_lv) \
		+ _band_gear_value(Balance.gear_weights(chid))  # mailed spoils = general-band roll

	var replay_gold := mob_gold + mob_chests + caches + elite_gold + boss_gold + curse_gold + shrine_gold
	var first_gold := replay_gold + fc_gold
	# All gem faucets are gated on regular_gems_drop (ch4+); ch1-3 pay zero gems.
	# First run also mails one spoils gem (+1.0); the rest are shared with replays.
	var first_gems_total: float = (first_gems + 1.0 + elite_gems + mob_chest_gems + cache_gems + curse_gems + shrine_gems) if gems_on else 0.0
	var replay_gems_total: float = (replay_gems + elite_gems + mob_chest_gems + cache_gems + curse_gems + shrine_gems) if gems_on else 0.0

	print("")
	print("--- %s  (%s, cap %s, %d rooms: %d combat / %d boss / %d social / %d dead-end / %d res)" %
		[chid, String(ch.get("name", "?")), cap, zones.size(), rooms["combat"], rooms["boss"],
		rooms["social"], rooms["dead_end"], rooms["resonance"]])
	print("  kills %3d   XP %5d (first run only)   bosses %d (avg Lv %d)" %
		[kills, xp, bosses.size(), boss_lv_sum / maxi(1, bosses.size())])
	print("  gold/run est: mobs %4.0f | mob-chests %4.0f | caches %3.0f | elites(%0.1f) %4.0f | bosses %4.0f | risk %3.0f | 1st-clear %3.0f" %
		[mob_gold, mob_chests, caches, elites, elite_gold, boss_gold, curse_gold + shrine_gold, fc_gold])
	print("  FIRST RUN:  %4.0f gold  %4.1f gems  (+%d XP)   -> %4.1f g/min  %4.2f gems/min  @%d min" %
		[first_gold, first_gems_total, xp, first_gold / FIRST_RUN_MIN, first_gems_total / FIRST_RUN_MIN, int(FIRST_RUN_MIN)])
	print("  REPLAY:     %4.0f gold  %4.1f gems  (no XP)    -> %4.1f g/min  %4.2f gems/min  @%d min" %
		[replay_gold, replay_gems_total, replay_gold / REPLAY_MIN, replay_gems_total / REPLAY_MIN, int(REPLAY_MIN)])


## The level a player is expected to hold in a chapter (its final boss's
## story level) — potion prices are LEVEL-keyed now, so the sink table maps
## each chapter to its expected-hero price.
func _chapter_story_level(chid: String) -> int:
	var best := 1
	for z in Story.CHAPTER_LIST.get(chid, {}).get("zones", []):
		best = maxi(best, int(z.get("boss_level", 0)))
	return maxi(best, 1)


func _sinks() -> void:
	print("")
	print("--- SINKS (base prices, before haggle 0.9-1.1) ---")
	var pots: Array = []
	for pchid in Balance.CHAPTER_ECON:
		pots.append("%s %dg" % [pchid, Balance.potion_price(_chapter_story_level(String(pchid)))])
	print("  potion (LEVEL-scaled, shown at each chapter's story level): " + " | ".join(pots))
	print("  mana draught %d | elixir %d | recall %d" %
		[Balance.CONSUMABLE_PRICES["mana_potion"], Balance.CONSUMABLE_PRICES["elixir_might"],
		Balance.CONSUMABLE_PRICES["recall_scroll"]])
	var costs: Array = []
	for g in ["C", "B", "A", "S"]:
		var it := {"grade": g, "plus": 0}
		costs.append("%s +0->+3 %dg" % [g, Items.upgrade_cost(it) +
			Items.upgrade_cost({"grade": g, "plus": 1}) + Items.upgrade_cost({"grade": g, "plus": 2})])
	print("  smith upgrades: " + " | ".join(costs))
	print("  shop gear: price x2 (C %d, B %d, A %d)" %
		[44 * 2, 22 * 2 * 2, int(22 * 2.4) * 2])
	# Gamble (2026-07-09 rework): rolls the chapter's BOSS band; base price =
	# boss-table-weighted expected farm cost x GAMBLE_DISCOUNT (mirrors
	# game_base.gamble_cost, minus the per-character resonance haggle).
	var gam: Array = []
	for gchid in Balance.CHAPTER_ECON:
		gam.append("%s %dg" % [gchid, _gamble_base(String(gchid))])
	print("  gamble (boss-band pity, x%.1f expected farm cost): %s" %
		[Balance.GAMBLE_DISCOUNT, " | ".join(gam)])
	print("  reforge (sub/affix/socket): C 140/280/420 | B 220/440/660 | S 500/1000/1500")
	print("  weekly challenge pays %d g (level-scaled) + %d gems | vault: gold chest + Lv2 gem" %
		[Balance.WEEKLY_REWARD_GOLD, Balance.WEEKLY_REWARD_GEMS])


## The gamble's BASE price for a chapter (no resonance haggle) — the same
## formula as game_base.gamble_cost: sum over the chapter's boss band of
## (weight x farm cost of that grade), then x GAMBLE_DISCOUNT.
func _gamble_base(chid: String) -> int:
	var w: Dictionary = Balance.boss_weights(chid)
	var total := 0.0
	for v in w.values():
		total += float(v)
	var expected := 0.0
	for g in w:
		var probe := {"grade": String(g), "slot": "armor", "plus": 0}
		expected += (float(w[g]) / total) * float(Items.shop_buy_price(probe, chid))
	return int(ceil(expected * Balance.GAMBLE_DISCOUNT))
