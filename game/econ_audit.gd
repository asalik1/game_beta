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


## Average sell value of one chest's gear at this act's loot cap.
func _chest_gear_value(tier: String, cap: String) -> float:
	var weights: Dictionary = Items.CHEST_TIERS[tier]["weights"]
	var cap_i: int = Items.GRADES.find(cap)
	var total := 0.0
	var value := 0.0
	for g in weights:
		var gi: int = mini(Items.GRADES.find(String(g)), cap_i)
		var w: float = float(weights[g])
		total += w
		value += w * (22.0 * float(Items.GRADE_MULT[Items.GRADES[gi]]) / 2.0)
	return value / maxf(total, 1.0)


## One chest's total gold-equivalent: bonus gold + gear sell value.
func _chest_value(tier: String, cap: String) -> float:
	var bonus := 5.5 * float(1 + ["wood", "silver", "gold"].find(tier))
	return bonus + _chest_gear_value(tier, cap)


func _audit_chapter(chid: String) -> void:
	var ch: Dictionary = Story.chapter(chid)
	var zones: Array = ch["zones"]
	var cap := String(ch.get("loot_cap", "S"))

	var kills := 0
	var mob_gold := 0.0
	var xp := 0
	var rooms := {"combat": 0, "boss": 0, "social": 0, "dead_end": 0, "resonance": 0, "other": 0}
	var pack_rooms := 0        # combat rooms with authored packs (elite/curse hosts)
	var caches := 0.0          # cache chests, in gold-equivalent
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
			room_gold += float(st["gold"])
			xp += int(st["xp"])
		mob_gold += room_gold
		if not packs.is_empty():
			pack_avg_gold += room_gold / packs.size()
		var cache_tier := String(zd.get("cache", ""))
		if cache_tier != "":
			caches += _chest_value(cache_tier, cap) + (0.25 if cache_tier == "wood" else (0.6 if cache_tier == "silver" else 1.0))  # + gem chance noted separately
		var bkind := String(zd.get("boss", ""))
		if bkind != "" and not bosses.has(bkind):
			bosses.append(bkind)
	if pack_rooms > 0:
		pack_avg_gold /= pack_rooms

	# Hidden caches (exploration premium): buried chests in some dead ends.
	caches += rooms["dead_end"] * Balance.HIDDEN_CACHE_CHANCE \
		* (Balance.HIDDEN_CACHE_GOLD_TIER * _chest_value("gold", cap)
		+ (1.0 - Balance.HIDDEN_CACHE_GOLD_TIER) * _chest_value("silver", cap))

	# Mob chest EV: every kill rolls wood 18% / silver 4%.
	var mob_chests := kills * (Balance.MOB_WOOD_CHEST_CHANCE * _chest_value("wood", cap)
		+ Balance.MOB_SILVER_CHEST_CHANCE * _chest_value("silver", cap))
	var mob_chest_gems := kills * (Balance.MOB_WOOD_CHEST_CHANCE * 0.25
		+ Balance.MOB_SILVER_CHEST_CHANCE * 0.6)

	# Elite EV (seeded): social rooms 30% + pack rooms 18%.
	var elites: float = rooms["social"] * Balance.ELITE_SOCIAL_ROOM_CHANCE \
		+ pack_rooms * Balance.ELITE_COMBAT_AMBUSH_CHANCE
	var elite_gold: float = elites * (pack_avg_gold * (Balance.ELITE_GOLD_MULT - 1)
		+ Balance.ELITE_GOLD_CHEST_CHANCE * _chest_value("gold", cap)
		+ (1.0 - Balance.ELITE_GOLD_CHEST_CHANCE) * _chest_value("silver", cap))
	var elite_gems := elites  # one guaranteed gem each (35% Lv2)

	# Boss payouts at their story anchors.
	var boss_gold := 0.0
	var boss_lv_sum := 0
	for bkind in bosses:
		var st := Story.enemy_stats_at(String(bkind), int(Story.ALL_ENEMIES[bkind]["level"]))
		boss_gold += float(st["gold"]) + _chest_value("gold", cap) + 1.0 * 0.0
		boss_lv_sum += int(st["level"])
	var boss_chest_gems := bosses.size() * 1.0  # golden chest gem chance = 100%
	var first_gems := bosses.size() * Balance.BOSS_GEMS_FIRST_CLEAR
	var replay_gems := 0.0
	for bkind in bosses:
		replay_gems += Balance.boss_gem_chance(int(Story.ALL_ENEMIES[bkind]["level"]))

	# Risk events EV (seeded; assumes the player engages when offered).
	var curse_gold: float = pack_rooms * Balance.CURSED_ROOM_CHANCE * _chest_value("gold", cap)
	var curse_gems: float = pack_rooms * Balance.CURSED_ROOM_CHANCE
	var quiet: int = rooms["social"] + rooms["dead_end"]
	# Shrine EV vs its cost: 60% bless (40% gem≈0g here, 30% 3x back, 20% silver chest, 10% elixir≈35g), 40% bane.
	var shrine_n: float = quiet * Balance.SHRINE_ROOM_CHANCE
	var scost := float(Balance.SHRINE_COST_BASE)  # L1-ish; scales with level like its rewards
	var shrine_gold: float = shrine_n * (Balance.SHRINE_BLESS_CHANCE
		* (0.3 * 3.0 * scost + 0.2 * _chest_value("silver", cap) + 0.1 * 35.0) - scost
		- (1.0 - Balance.SHRINE_BLESS_CHANCE) * 0.4 * scost)
	var shrine_gems: float = shrine_n * Balance.SHRINE_BLESS_CHANCE * 0.4

	# First-clear beat: gold in hand + mailed spoils (cap-grade item + Lv2 gem).
	var max_boss_lv := 1
	for bkind in bosses:
		max_boss_lv = maxi(max_boss_lv, int(Story.ALL_ENEMIES[bkind]["level"]))
	var fc_gold := Balance.FIRST_CLEAR_GOLD * Balance.daily_gold_mult(max_boss_lv) \
		+ _chest_gear_value("gold", cap)

	var replay_gold := mob_gold + mob_chests + caches + elite_gold + boss_gold + curse_gold + shrine_gold
	var first_gold := replay_gold + fc_gold
	var first_gems_total := first_gems + 1.0 + boss_chest_gems + elite_gems + mob_chest_gems + curse_gems + shrine_gems
	var replay_gems_total := replay_gems + boss_chest_gems + elite_gems + mob_chest_gems + curse_gems + shrine_gems

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


func _sinks() -> void:
	print("")
	print("--- SINKS (base prices, before haggle 0.9-1.1) ---")
	print("  potion 25 | mana draught %d | elixir %d | recall %d" %
		[Balance.CONSUMABLE_PRICES["mana_potion"], Balance.CONSUMABLE_PRICES["elixir_might"],
		Balance.CONSUMABLE_PRICES["recall_scroll"]])
	var costs: Array = []
	for g in ["C", "B", "A", "S"]:
		var it := {"grade": g, "plus": 0}
		costs.append("%s +0->+3 %dg" % [g, Items.upgrade_cost(it) +
			Items.upgrade_cost({"grade": g, "plus": 1}) + Items.upgrade_cost({"grade": g, "plus": 2})])
	print("  smith upgrades: " + " | ".join(costs))
	print("  shop gear: price x2 (C %d, B %d, A %d) | gamble %s" %
		[44 * 2, 22 * 2 * 2, int(22 * 2.4) * 2, str(Balance.GAMBLE_COST)])
	print("  reforge (sub/affix/socket): C 140/280/420 | B 220/440/660 | S 500/1000/1500")
	print("  weekly challenge pays %d g (level-scaled) + %d gems | vault: gold chest + Lv2 gem" %
		[Balance.WEEKLY_REWARD_GOLD, Balance.WEEKLY_REWARD_GEMS])
