# Crownless — Story & Design Bible
(Compressed for token economy — every decision/number kept, prose trimmed.)

## Phase Plan (agreed 2026-07)

**Phase 1 — launch (solo, Ch2) — SHIPPED 2026-07-04:**
- Six classes: Warrior, Assassin, **Paladin** (new melee) / Archer, Mage, **Warlock** (new ranged). LoL balance rule extends: Paladin = bruiser base stats; Warlock pays the ranged damage tax like Mage.
- Two joinable factions (Ember Accord, Cinderborn) carry politics/recruitment/endings. **Wildfang + Hollow Choir are ambient**: standing tracked, world reacts, no pledging. Lore fully canon — justifies repeatable beastkin/blight zones.
- Resonance ships whole. All four legacy classes got their openings retrofitted.
- Next arc: **Content Architecture — Road to 100 Hours** (below).

**Phase 2:** co-op, then the Hollow Throne raid.

**Expansion (deferred by design, not cut):**
- **Death Knight** — cheap mechanically but crowds Warrior/Assassin at launch; grave opening is the expansion marketing beat; co-op gives its Hollow Choir alignment people to argue with.
- **Summoner** — most expensive class (pet AI/pathing/netcode). Headline addition later.
- Promoting an ambient faction to joinable = an expansion's political plot.

## Setting: Vaelscar

Vaelscar was held together by a lie: 600 years ago the **Concord of Ash** bound five warring god-kings into mortal vessels, ending the War of Cinders. The gods weren't gone — old, weak, hiding inside people. The Concord is failing: **Mórwyn, the Hollow Flame** has reawakened inside her vessel (a peasant blacksmith), cracking the other four seals.

**The five god-kings (canon 2026-07-04, roster detail in BOSSES.md):** Mórwyn the Hollow Flame (blight/decay), the **Molten Judge** (fire/verdicts — magma), the **Still Queen** (ice/sleep/preservation — ice), the **Pale Root** (growth-without-death — bog+spore), the **Storm Tongue** (storm/the unkept word — storm+void). The other four are known ONLY by epithet: 600 years of the Concord meant 600 years of not speaking their names. Mórwyn's name survives precisely because her seal broke first. Learning a true name is an Act 2/3 reveal beat — one quest shape per god-king. Act 1 (L1–40) fights their heralds and casualties, never the god-kings themselves.

## The Ember Crown — Origin of Classes

The Crown was four Embers — primal fragments carried by the Ember Guard's founders — forced by Vargoth to burn as one inside him. Aldric's killing blow scattered them; each rooted in people of old Guard bloodlines. A shard-bearer doesn't choose a class — they discover which Ember caught in them, inheriting its virtue, temptation, and dead founder's sins.

## Bridge From Solo to Multiplayer

- **Backstory (~30 years before play, never playable):** Aldric kills Vargoth; Vargoth pours his will into the Crown and shatters it. Shards root in ordinary people of old Guard bloodlines. This beat is TOLD (Aldric's ch2 conversation), never played — the player is never Aldric. (2026-07-17: this line used to read "Ch1: Aldric kills Vargoth", which was shorthand for the backstory but got implemented as ch1's script — the PC spoke as "Ser Aldric" while the class system underneath said otherwise. Retconned; ch1's beats now speak as "You".)
- **Ch1 (playable):** every PC's shard has just awakened; their power is a fragment of the tyrant, and Vargoth is climbing out of his keep a SECOND time. You put him back down — the same kill Aldric made, made again by a nobody. Ch2's Aldric is the man who did it first: he knows it doesn't take.
- **Aldric**: spent his ember on the killing blow; burned-out legend, can't fight, knows what's coming. Late-game lore NPC / "what I never told you" quest / optional superboss homage.
- **Elder Maren**: trained under Aldric; finds newly-awakened bearers before the factions do. Onboarding NPC for all eight classes, reading each recruit differently.
- **Fangmaw & Mórwyn** were corrupted Guard commanders (Stormwarden beastmaster; Emberwright battle-healer whose fire-healing curdled into blight). Killing them cut off the head — warbands and blight-plague still spread years later, justifying repeatable zones and the 14 terrains.

## Progression Trackers

- **Resonance** (per character, −100..+100): every major choice nudges toward your Ember's Virtue or Temptation. Not good/evil — how you relate to the power that destroyed your founder. Stored on the player object (survives solo→co-op).
- **Faction Standing** (four independent values, per character): personal reputation solo; in co-op the group's mixed standings ARE the table tension.
- These six numbers gate all major branches and ending eligibility. Resonance is felt through dialogue before (or beyond) any number.

## The Four Factions

- **Ember Accord** (joinable): Maren's loyalists — gather the shards, destroy the throne; no one wears the Crown again. Asking bearers to voluntarily become less. Not wrong; asking a hard thing.
- **Cinderborn** (joinable): old-regime nobles who prospered under Vargoth — find a worthy heir, re-crown, restore empire. Order requires a crown; the Waking proves it. Not cartoon villains — people who lived well under tyranny and told themselves it wasn't.
- **Wildfang Tribes** (ambient): Fangmaw's beastkin descendants, fractured — one camp seeks a cure and Accord alliance; the other made peace with what they are and reads "curing" as conquest in mercy's clothes. Player choices tilt which camp dominates.
- **Hollow Choir** (ambient): Mórwyn's blight survivors turned faithful. The rot is the land's honest truth. Some grieving people who found meaning in horror; some genuinely dangerous; the line is hard to find.

## The Three-Act Player Journey

- **Act 1 (low):** something personal triggers your shard; Ember activates → consequence you live with → Maren finds you.
- **Act 2 (mid):** factions recruit because they sense you. Alignment chosen — consequential, not locked. Map opens as the Waking spreads.
- **Act 3 (endgame):** confront the awakening god-kings. Solo: assemble the pieces via NPC shard-bearer questlines. Co-op: four players bring classes + Resonance into the Hollow Throne raid.

## Content Architecture — The Road to 100 Hours (agreed 2026-07-04)

Context: first human playthroughs — Ch1 ~5 min, Ch2 ~8. Target **100 hours across three acts**, without pretending to hand-author it.

### Hour budget
| Source | Hours | Cost |
|---|---|---|
| Authored campaign (3 acts, ~7 chapters each) | 25–35 | The expensive part — bespoke zones/bosses/cutscenes. Budget raised from 15–20 (2026-07-04): deliver content that matches the design; get the baseline right even if it takes time |
| Difficulty tiers / NG+ | ×2–3 on the above | Nearly free — level scaling to 100 exists |
| Endless mode ("the Waking Depths") | open-ended | Cheap once zone graph + room palette exist |
| Build & loot chase (gems→10, S-gear, 6 classes × 3 themes × Resonance) | the glue | Built — needs tiers for a reason |

### Acts vs chapters
Acts = narrative superstructure AND level thirds (agreed 2026-07-04): **Act 1 = early game L1–40, Act 2 = mid game ~40–70, Act 3 = endgame ~70–100**. Chapters = the playable unit (own world/bosses/save-replay): **~7 per act, 45–75 min first run**. Ch1–2 re-slot as Act 1 openers after the retrofit; nothing thrown away. Act 1's full chapter/boss roster (Ch3–Ch7, L16→41) lives in **BOSSES.md**.

### Mono-terrain chapters
One terrain family per early chapter; later chapters blend (the corruption merging is itself a story beat). Mechanics escalate across the chapter; cheaper to author depth than breadth. **Mono-family, not mono-look** — a graveyard chapter drifts misty fields → barrows → crypt stone → boss cathedral; literal tile repetition reads as monotony.

### The zone graph
Rooms declare **N/S/E/W exits** on a grid: branches, loops, wings, dead ends.
- Exploration time is content — the map may spend the player's steps.
- **20–30 rooms per chapter** (floor kills corridor sprints; ceiling bounds authoring and terrain fatigue).
- **Map (M):** fog-of-war grid, only entered rooms revealed; unexplored exits show as stubs (you see THAT there's more, not what). Visited state saves.
- ~40–50% of rooms off the boss path.
- **Every run lays a different map (round 4):** the boss path (*spine*) is an ordered room list walked east with seeded N/S jogs; side rooms attach to seeded same-terrain hosts. Seed = character's wander_seed (saves reload their world; replays/new characters reroll). Content authored; only geography rolls.

### Room-type palette
| Type | Contents |
|---|---|
| Combat | mob packs (default) |
| Boss | arena, story-gated |
| Social | pooled wanderer NPCs, rolled per character |
| Resonance | shrine/stranger with a genuine band-shifting choice (moves Resonance between story beats) |
| Elite | one named elite, 1–2 affixes, better loot |
| Event | the terrain hazard amplified (magma-rain gauntlet, lightning field) |
| Dead end | scenery, lore prop, small cache — sometimes deliberately nothing |
| Secret | rare; hidden/flag-gated; the best caches |
| Merchant camp | safe pocket; ties into the post-boss wanderer roll |

Rolled rooms (social/elite/caches) are seeded per character — spatial variety for the replay matrix for free.

### UX rules the bigger maps force
- **Fast travel:** from the map, instantly to any **visited safe room** only. Combat rooms never — the space between stays real.
- **Purge seals (round 2):** rooms with living packs seal all doors; per-pack aggro inside; quest line shows "monsters left" as the WHY; last kill = green cleansing pulse ("the blight recedes"), seals lift. Critical path bends N/S and passes ≥1 merchant camp per chapter.
- **Room-state persistence:** cleared stays cleared for the run (and save/load). Elites/socials/caches don't respawn once resolved. Chapter replay rerolls seeded rooms.
- **Death:** return to last visited safe room, gear/gold/XP intact; death room resets. No corpse runs. Nothing follows you home: homeless spawns (boss adds, event zombies) despawn; aggroed survivors calm and walk back (round 3 — a chaser once camped the respawn).
- **Autosave on every room transition** (45–75 min chapters can't assume one sitting).
- **Objective clarity:** quest line always on screen; once the boss door is SEEN the map marks it; before that, stubs are the only hint.
- **Audio fatigue:** each terrain family needs ≥ explore + combat/boss music layers (or deliberate silence), not one loop.

### Elites & affixes
Small affix pool (Frenzied, Bulwark, Vampiric, Stormtouched, Splitting…) on existing monsters with scale/tint + loot bump. Double-feeds tiers and endless.

### Difficulty tiers / NG+
**Normal / Nightmare (+20 levels) / Torment (+40)**, loot-grade floors rising per tier. Reuses replay + level scaling — the cheapest multiplier in the plan.

### Endless mode — the Waking Depths
Procedural chapter: terrain-family rooms chained, rising levels + affix density, checkpoints every N rooms, depth counter as the brag. Built from zone graph + palette + elites (why those come first). Hours 30–100 live here.

### Pacing & balance — standing rules
The distilled, currently-true rules. The full round-by-round history (48 rounds of triggers, numbers moved, superseded experiments) lives in **BALANCE_HISTORY.md** — new rounds get logged THERE; a rule graduates to this list only once it's durable.

**World & progression**
- Rooms 2–3 screens, per-pack aggro; TTK at parity ~2× the Phase-1 feel; gold/potion scarcity so merchants matter. No free full heal on level-up (hp/mp keep their FRACTION as pools grow).
- **Potions are an INVESTMENT (2026-07-09):** health-potion stock is BOUGHT (price chapter-scaled, `Balance.potion_price` 25g ch1 → 125g ch7 — potions heal % HP so value scales; sell basis stays the flat ch1 price, no haul-forward arbitrage), never granted — no starting stock, no boss-kill restock, nothing re-grants on death. The ONE freebie: entering ch1/2/3 grants a single teaching potion that EXPIRES on leaving the chapter (`FREE_POTION_CHAPTERS`, `player.potions_free` — drunk first, never sellable, can't be farmed by revisits). Per-room drink budget is CHAPTER-banded (`Balance.potion_slots`: ch1-2 = 1, ch3-4 = 2, ch5-7 = 3; act 2 = 4, act 3 = 5 latent).
- Monster growth COMPOUNDS (`base × (1+g)^Δ`, rescaled by `GROWTH_SCALE` 0.55): at-level parity holds at ANY level; +10 ≈ 2× damage (autotest-guarded 1.8–3.5×). No hidden multipliers — `ENEMY_DMG_MULT` 1.3 / `BOSS_DMG_MULT` 1.2 apply inside `enemy_stats_at`, so the codex stays honest.
- No downscaling: a monster's listed level is a MINIMUM; early bosses scale UP at endgame.
- Fixed chapter XP: only authored packs + bosses pay; event/summon spawns pay zero; completed chapters pay NO XP on replay (farm gold/gear, never levels). New-chapter rule: sum authored pack XP through the 30+22·lvl curve; land each boss room at boss level (full clear tracks parity ±1).
- Rewards LINEAR per level. **Chapter loot BANDS (2026-07-09, replaces the act-keyed ceilings):** every gear/bag drop is a weighted roll from the chapter's table (`Balance.CHAPTER_GEAR_WEIGHTS` general / `CHAPTER_BOSS_WEIGHTS` boss), no more roll-high-then-clamp. Tiers phase in/out on a sliding window — **F ch1-3 · E ch2-4 · D ch3-7 · C ch4-11 · B ch5-∞ · A ch6-∞ · S ch12-∞**. GENERAL faucets (mobs/chests/shop/spoils/gamble) skew low-mid; the BOSS channel reaches the ceiling (~1/3 per boss, `BOSS_GEAR_CHANCE`); bags follow the boss table everywhere (drop/elite/shop). `loot_cap()` = the chapter general-band ceiling. Regular gems drop **ch4+**, special gems **ch6+** (`regular_/special_gems_drop`). Gem slots F–D = 0; **C = 1 regular socket, gem cap Lv2** (2026-07-09 — sockets extend down a tier so ch4's first gem drops land on ch4's C-band gear). Per-chapter weights hand-authored ch1-11; ch12+ set when built. **Econ re-measure PENDING** (`CHAPTER_ECON` still reflects the old tiers).
- **Itemization doctrine (player-designed, 2026-07-06):** every piece's MAIN is the wearer-class's PRIMARY attribute (STR/AGI/INT), guaranteed, slot-budgeted (`SLOT_MAIN_BUDGET` weapon 5 > armor 3 > charm 2.5 > boots 2, × grade × shape), converting through `ATTR_SCALE` exactly like allocated points — and primaries convert SUB-1 by design (0.9 ATK per point; STR pays 1.2 HP: "100 STR = 90 ATK + 120 HP"). Attribute identities are UNIFORM across classes, only per-class RATES differ — **STR = ATK + HP · AGI = ATK + CRIT (crit lean) · INT = ATK + CRIT + small DEX (no mana — pools live in class bases) · VIT = HP first + phys/mag/crit res secondaries**, with budgets sized so the L42 full-B benchmark stays within ~2% of the calibrated envelope (gear attributes must never outrun the ~5.5%/level player curve bosses are pinned to) — a dagger literally cannot carry INT. Gear is **class-LOCKED at equip** (`item["cls"]`; a mage can't wear an assassin's boots; unclassed legacy/dev items pass). Sub pool: ATK%/HP%/Crit/CritDmg/**VIT**/EVA/DEX/pens/resists/MP — duplicates impossible (draw-without-replacement). **Movement speed is SOVEREIGN**: on no gear, no gem, no talent — only terrain and abilities touch it (dodging is life or death). **Special stats (Haste/Lifesteal/Combo/Greed) are GEM-only, with NO exemptions** — S legendaries and set bonuses purged too; S differs by MAGNITUDE + weapon passive + 3 sockets (A: 2), never by stat types. One special gem per item. ALL caps are SOFT KNEES (`Balance.soft_cap`: full value to the cap, ~1/10 beyond, never a dead stop; CRIT alone diminishes gentler at 1/5 — payoff stat, not a system-breaker; THEME bonuses are cap-EXEMPT, added above the knee at full value): Crit 35% / Evasion 50% / Haste 40% / Lifesteal 35% (on the TOTAL — surges are additive: 2% + 26% surge = 28%) / Combo 30% / Greed 40% (chest bonus from the first point) / resistance-reduction 80%. **Ults ignore Haste, every class** (authored ult-cd talents still apply; assassin's stays fully fixed). Gem LEVEL limits by grade: C ≤ Lv2, B ≤ Lv3, A ≤ Lv6, S ≤ Lv10. Talent points can never buy the specials or speed (tree nodes purged). Legacy saves: banned stats stripped on load, old ATK/HP mains still count. Late-game cap-lift by level (~L80) noted, NOT built. Supersedes round 43's B-gate.
- **Boss gem-expectation ramp (2026-07-06):** UPSCALED bosses gain +1.2%/level HP and +0.6%/level damage for levels above max(L32, their anchor) (`BOSS_GEM_*`, inside `enemy_stats_at` — codex-honest): the benchmark player is no longer gemless, so scaling budgets what the player actually has, per the round-45 pattern. Anchor stats stay exactly as authored — high-anchor bosses get their gem allowance at authoring/budget time, not from a hidden multiplier. Sized for the B-cap Act 1 world; revisit when Act 2 anchors land.
- 1 attribute point/level; talent points buy substats 1:1 (combo deliberately NOT purchasable).
- **Talent tree (levels 1–40):** row-based, 3 theme columns × 4 rows unlocking every 10 levels (10/20/30/40); ≤10 points per row, ≤10 per cell (binary talents cap lower via a per-cell `max` field). 1 talent point/level and **points == level**, so the tree fills EXACTLY at 40 — the close of Act 1, with no points wasted early or late. Per-cell values are HALF the old 5-point tuning so a maxed cell lands the same total; specials/speed can never be bought here. Past 40 the tree is DONE — see the Mastery layer below.
- Monsters carry attribute BUILDS (`MONSTER_ATTR_SCALE`, archetype defaults, bosses invest 2×); enemy hits resolve through the SAME `Stats.resolve` as player hits; telegraphs/hazards stay plain — dodge by moving.
- Boss TTK budget: ~25s opener / ~30s mid / ~40s finale of realistic dps, at level, in the act's top drop grade (**A-gear must beat at-level bosses before L40; S is comfort + tier headroom**). Boss damage growth pinned to the player curve (`BOSS_DMG_GROWTH` 0.055) with a constant 1.2 skill tilt. Retune pools whenever player power moves.
- Gem economy: elites guarantee 1 gem/kill (35% Lv2); bosses pay a 3-gem bundle on FIRST chapter clear, then a per-kill chance scaling to guaranteed at L40+ (`boss_gem_chance`). Sockets are elite/boss-hunting payoff.
- Elites: ~4× HP / 1.5× dmg / zero-XP loot piñatas, seeded per character (~30% of social rooms, ~18% of combat packs promote one member).
- Up to 5 stacking bags whose slots SUM; gear, gems, consumables AND health potions share the slots, every UNIT counting (stacks are display-only; potions stay counters internally but occupy slots and render in the bag — 2026-07-09 v2, curve compensated +5/tier to F15…S45 per bag); topping an existing gem stack is always free; bag-full pickups drop at your feet and chapter-end mail themselves. ALL timed rewards ride `game.trusted_now()` — never raw OS clock.
- Dev/rogue boss kills never touch the story — only `story_boss` spawns drive quests/gates/endings.
- Resonance is VISIBLE: HUD line under Combat Rating (golden/ink by sign, pulse on change), Stats-tab explanation, NPC idle emotes read the band; quiet-room shard choices pay a token reward for conviction, not virtue.
- **Resonance band leans (2026-07-09):** a small passive rider whose STRENGTH scales with |resonance| (zero through the neutral band, wakes past the band line ±25, full at ±100) and whose FLAVOR is the sign — Virtue = **Constancy** (potions mend up to +25%, on top of the steady 0.9 haggle: the spend-side perk), Temptation = **Hunger** (up to +10% damage to mobs below 25% HP — NEVER bosses, their execute windows stay design-owned, and only prey that PAYS: `gold_value > 0`, which auto-excludes boss summons / spawner sprouts / event mood spawns — and up to +15% kill gold: the earn-side mirror). No correct band; staying undecided is the only way to get nothing. All sources of resonance are one-time (no farm loop); autotest + dps_bench PIN resonance to 0 so the leans never skew a benchmark. Numbers in `Balance.RES_LEAN_*` / `RES_HUNGER_*` / `RES_CONSTANCY_*`.
- **Greed is a FARM-EVENT stat, never a build stat (2026-07-09):** since the greed gem retired for Tenacity, the stat's ONLY source is the **GOLD RUSH charged coin** — a rare spill from paying trash kills (`GOLDRUSH_DROP_CHANCE` 0.01, ~1/replay run) that surges greed +30% for 150s on touch (auto-trigger, never a bag item, refresh-don't-stack, buff-bar chip). Drop-only, NEVER merchant-sold (buying gold% with gold is a dead loop). Summons/mood spawns (`gold_value` 0) can't spill one. ~+2-3% run income — a felt slot-machine beat, not an economy dial. Distinct from the weekly "Gilded Blood" modifier (which scales kill gold at the drop).

**Class doctrine**
- One constant budget per class, split between FORGIVENESS (sustain/mitigation/range) and PAYOUT (damage). Execution kits (mage, assassin) earn ~10–15% above the line AT THEIR SKILL CEILING only; their edge lives in base/ability multipliers, never growth; their survival tools stay binary, timing-gated, rate-limited.
- Ranged power budget: damage on a ranged class's dash/short-range slot is phantom budget — those slots carry UTILITY (Frost Nova mends, Blink wards).
- No free immunity: dashes grant NO i-frames (assassin dash = 0); only all-in ult commits do (Death Mark 0.8s; Blink's 0.3s rides its longer cd class); gap-closer landing guards ride their own ~5s cooldown (warrior Charge, paladin Judgment leap).
- Dashes steer by the HELD move keys, all 8 ways (no keys held = straight along the facing); the authored L/R dash art flips to the travel side and ROTATES the rest of the way (up/down = 90°, diagonals = 45° — `player_combat._aim_dash_pose`, 2026-07-09).
- Sustain is identity-true, lives in the BASE kit, and is never doubled by themes: warrior GRIT (hits-TAKEN stacks — facetanking feeds him, kiting starves him), paladin Conviction stance (Holy mends −20% dmg ↔ Retribution +25% dmg no mend — never both at once), assassin blood surge (12–26%, melee-earned, missing-HP-scaled), warlock leech + Pact, archer Second Wind (heals by NOT being hit), mage Blink ward. No universal lifesteal, ever.
- Calibration bench: the warlock's L42 A-gear nullwarden clear ≈ ~1200 boss dps; every class benchmarks there. The assassin ult's cd is FIXED (immune to haste).
- Combat readability: visible cooldown/resource numbers; persistent state (stances, stacks) needs persistent HUD, not just floating text.
- Ability FX ship only after being SEEN in a screenshot (`game/shot_kit.gd` rig) — tuning invisible effects is guesswork.
- Levers held in reserve: healing-reduction boss mechanics (the mid/endgame check on all-in lifesteal builds); perfect-play rewards (e.g. i-framing THROUGH a telegraph refunds dash cd) as execution-class ceiling raisers — forgiveness classes never get these.

### Meta systems — the retention layer (built 2026-07)
Solo-now, shaped to seed the future multiplayer backend (account/economy boundaries drawn where a server would sit). All timed rewards ride `game.trusted_now()` (round 8 clock rule).
- **Daily login rewards** (`Balance.DAILY_REWARDS`) with the HUD daily-star shine.
- **Bounties + weekly vault:** 2 daily + 1 weekly from `BOUNTY_POOL`; the vault pays out at `VAULT_BOSS_GOAL` (5) boss kills that week.
- **Account-wide stash** (`STASH_SLOTS` 200) — cross-character storage; the glue for the 6-class replay matrix.
- **Reforge bench** — gold-cost gear crafting (the deliberate gold sink).
- **Gambling vendor** — the pity machine (reworked 2026-07-09): gold → a roll from the chapter's BOSS band (`CHAPTER_BOSS_WEIGHTS` — the B/A piece the general faucets can't reach), priced at the boss-table-weighted expected farm cost × `GAMBLE_DISCOUNT` 0.8 (`game_base.gamble_cost`; ch2 ≈ 1.3k, ch5 ≈ 7.4k, ch7 ≈ 13.3k before haggle).
- **S-legendary set bonuses** (2pc/4pc) — the chase on top of S gear.
- **Utility consumables:** mana draught, might elixir, recall scroll.
- **Quest log, buff-icon timer bar, corner minimap, achievements + boss records** (codex Records tab), **mailbox** (round 8).
- **Localization string-table foundation** (`Loc`) — strings routed early so translation is a table, not a rewrite.
- Inventory QoL: unequip, bag category tabs, bigger stacking bags (F15…S45 each, slots sum).

### Retention roadmap (agreed 2026-07-06; items 1–5 BUILT 2026-07-06)
Doctrine: **no new meta systems until the content multipliers exist** — the retention layer is already ahead of the content it retains players in. Addictive = (satisfying loop) × (reasons to re-run it); the loop is built, the multipliers are build-order steps 2–4 (tiers/Depths deliberately AFTER the difficulty-tuning pass, per the player).
1. **Chapter results screen + personal bests — BUILT.** Victory card: time / deaths / elites / secrets / rooms charted + a letter grade in gear-grade colors, with ★ NEW BEST callouts. Grade (`Balance.chapter_grade`) scores deaths + exploration + thoroughness; **time is deliberately ungraded** — it's the PB race instead (grading speed would punish the exploration the zone graph exists to reward). PBs are ACCOUNT-wide in meta.json, keyed chapter × class (`pb_<ch>_<cls>`: best time/grade/runs) — a leaderboard row's shape. Codex Records tab lists them. Run counters ride the save (runs span sessions); replay/advance/new-game resets them.
2. **Weekly challenge seed — BUILT.** One fixed `wander_seed` + one modifier per trusted-clock week (`Balance.WEEKLY_MODS`: Ironhide / Cruelty / Swiftfoot / Gilded Blood / Elite Legion), same for everyone; the chapter rotates weekly. Lives in the Quest Log: the mod, the week's account best, a Begin button (mechanically a replay). Fx apply via `game.weekly_fx()` at spawn/drop sites; completion pays gold+gems once per week; the week's fastest clear persists in meta (`wk_<week>`). Any seed reroll (replay/advance) drops the challenge flag — a stale seed races nobody.
3. **Loot dopamine pass — BUILT, screenshot-verified.** Every gear drop plays a per-grade chime (`Sfx` loot_low→loot_s; S is a bell-and-shimmer jackpot nothing else sounds like); B+ raises a grade-colored light beam (`Art.tex("lootbeam")`) that grows with rarity; S adds screen flash + shake. Rig: `game/shot_loot.tscn` (sibling of shot_kit).
4. **Elective risk events — BUILT.** Seeded per character like elites, both walk-past-able: **CURSED CHEST** (~15% of combat rooms) — accept and the living pack gains +30% dmg / +15% speed (violet cast) until the purge, which pays a golden chest + guaranteed gem; the accepted curse persists via flag through saves and death-resets, payout only on the purge. **GAMBLE SHRINE** (~22% of quiet rooms, once each) — feed it level-scaled gold; 60% blessing (gem / threefold gold / chest / elixir), 40% it drinks deeper (30% current-HP blood, never lethal, or the same coin again). Codex "TEMPTATIONS" card documents both.
5. **Codex completion + titles — BUILT.** `game.kill_counts` tallies every real kill (scenery props / zero-reward event spawns don't count); a kind's threshold (25 mobs / 3 bosses, `lore.gd`) unearths its authored lore line on the codex card (fallback text for unauthored kinds — the codex never shows a hole). Achievements carry POINTS (hard feats pay more); **titles** (`Achievements.TITLES`) unlock off points, feats, lore count and lifetime kills, equip from the Records tab, and ride beside the class name on the HUD.
6. **Deferred:** transmog/cosmetics (long-tail chase, but wants an art pipeline we don't have yet); pity timers (the gem/boss-gem curves already do implicit bad-luck protection).

Everything above compounds into multiplayer: PBs → leaderboards, weekly seeds → shared ladders, titles → social display.

### Endgame progression — the Mastery layer (designed 2026-07-08, DEFERRED to Act 2)
NOT built — a locked design, to implement alongside Act 2 so keystones tune against real enemies (measure-then-correct; nothing past L40 grants XP today, so the points don't yet go dead). The 1–40 talent tree is COMPLETE at 40; levels 41→100 stop granting talent points and grant **Mastery points** instead (~60 by L100). Solves the same dead-point problem the 1–40 retune closed, one tier up.
- **Keystones — build-DEFINING, 3 per class.** Each flips a RULE (immovable; can't-be-healed; both stances at once), never a stat, and carries a scaling **potency rider** that eats Mastery points (~20-pt cap each; 3 × 20 = 60 = the post-40 income, so the board fills with no dead points — same income==capacity symmetry as the 1–40 tree). You **equip ONE at a time**; points invested persist per keystone, so re-slotting never wastes them. Every keystone needs a scalable rider — a pure binary flip with nothing to grow doesn't fit the model.
- **Alignment-gated — the Resonance hook.** A class's 3 keystones map to a Resonance STANCE — Dark / Balanced / Radiant — matching each keystone's moral flavor (ruthless / measured / righteous). Neutral band = **−10..+10**; the poles are the outer bands. Your CURRENT stance gates which keystone is equippable (**must-maintain**, not a one-time unlock) — so Resonance stays mechanically meaningful long past the campaign that first set it.
- **The Resonance Altar — the faucet.** Unlocked at/after the cap: pick a stance → snaps Resonance into that band, **locked for a week** (rides `trusted_now()`, the same clock as the weekly vault). During 1–40 Resonance is still earned organically through choices and sets your starting stance; the altar is the deliberate, weekly-committed override — "hate the NPCs? join the dark side," by choice you live with, not a per-fight toggle. Optional later: repeatable resonance-quests as an organic secondary faucet — but choices are one-time today (`chose_` flags are kept), so that needs re-grantable quest resonance. Build order when Act 2 lands: Mastery-point grant + altar + 3 keystones for ONE class as a vertical slice, before spec'ing all six.

### Reward economy — calibration doctrine (agreed 2026-07-06)
The player's frame: early progression SMOOTH (no farm walls); later the player farms because they WANT to (build + exploration), not because a wall demands it. Over-reward and farming is pointless; under-reward and they quit — calibrate the in-between. **Instrument first: `game/econ_audit.gd`** (headless) prints what every chapter actually pays, first run vs replay, per faucet — rerun it whenever reward numbers move; calibration is measurement, not vibes.

**The model (each faucet has ONE job):**
- **XP = story currency.** First run only, fixed totals, parity-budgeted (rounds 4/5). Quests/spine pay XP + beats, NEVER repeatable income — so the story can't be farmed and farming can't outlevel the story.
- **Gold = the farm currency.** Linear per level, so the frontier always out-pays: measured replay rates climb ~47 → 77 → 105 → 180 g/min across ch1→ch7 (audit 2026-07-06). Replay naturally earns ~1.5× first-run g/min (same faucets, shorter run) — farming is VIABLE by default; the first run pays in XP + the first-clear beat instead.
- **Gems = the build currency.** COUNT stays flat per run (~17 replay); **QUALITY chases the frontier** — the guaranteed-gem Lv2 chance climbs with content level (`Balance.gem_lv2_chance`: 35% floor ≤L10, +1%/level, 65% cap), because the no-downscaling rule makes old content safe and the premium must live in the payout, not the risk. Boss replay gems already scale to guaranteed at L40+ (round 44).
- **First clear = the event.** XP to parity + 3 gems/boss + achievement + the NEW first-clear beat: `FIRST_CLEAR_GOLD` (150 × level mult ≈ 15–25% of the run's own gold, deliberately shrinking as a share late) in hand, plus a mailed spoils package (one act-cap gear roll + a Lv2 gem). Felt, legible (results card + mailbox), never worth chasing over the farm loop itself.
- **Exploration = the premium path.** Off-spine rooms carry the gem economy (elites ≈ 60% of a run's gems) plus caches, risk events, resonance tokens — and now **hidden caches**: ~25% of dead ends bury a chest that only glints awake when the player wanders NEAR (`Chest.bury()`); counts as a secret on the results card. Walking the room nobody made you walk is what finds it.
- **Time-gated faucets can't be farmed, only collected:** daily, bounties, vault, weekly challenge — they answer "why log in today", never "how do I grind".
- **Achievements/titles pay IDENTITY, never currency.** By construction unfarmable.

**Sink sizing (frontier farm minutes per purchase, from the audit):** potion ≈ 30–40s (price is chapter-scaled, `Balance.potion_price`: 25g ch1 → 125g ch7, tracking the g/min climb) · smith +3 ≈ 1–2 min · one reforge sub-roll ≈ 2–3 min (RNG craft, rolled many times — cheap singles by design) · gamble ≈ 0.8× the boss-band expected farm cost (ch7 ≈ 13.3k ≈ 2+ replays — it pays a boss-band piece, so it prices like one) · S-socket 1500 ≈ 8–10 min. A meaningful BUILD STEP (gem tier via synthesis, a reforge pass, an A-piece hunt) ≈ 2–4 replays — the "farm a chapter a few more times" sweet spot, by construction.

**Endless mode rule (for when the Depths land):** a depth band pays like a REPLAY of a chapter at that level band — same g/min curve, same flat-count/rising-quality gems — with checkpoint chests as boss-equivalents and depth records as the identity payout. No new currency, no separate economy to calibrate.

**Open items:** (1) **Ch2 is a reward hole** — legacy 10-room chain, zero social/dead-end/resonance rooms, worst g/min in the game (42 vs ch3's 77): fix by graph-retrofit, not by inflating its numbers. (2) The 15–25% first-clear share and the 65% gem-quality cap are first guesses — confirm in the difficulty-tuning playtest. (3) Replay time assumption (32 min vs 55 first) is the audit's weakest estimate — check against real replays.

### Build order
1. Zone graph + room palette + pacing retrofit of Ch1–2 ← **vertical slice: retrofit Ch1 alone, human-playtest, lock numbers before authoring more** — **DONE** (48 balance rounds and counting)
2. Elites/affixes + difficulty tiers (instant replay hours) — **elites DONE (round 6); tiers NOT BUILT — the next cheap multiplier**
3. Act 1's remaining chapters (mono-terrain) — **Ch3 in progress (bosses landed, round 45 retune; needs playtest)**
4. The Waking Depths — not started
5. Acts 2–3, blending terrains — not started

**Engine note:** rooms build lazily on first entry; only the occupied room simulates. Keeps the door open for procedural Depths rooms.

## Graphics & Ambience — the polish pipeline (agreed 2026-07-06)

Diagnosis: the game reads as a "pixel composite" next to market peers. The gap, in impact order — **(1) no character animation** (every creature is a single static frame; all motion is tweens), **(2) style incoherence** (procedural 16px art + static 32px Crawl tiles + procedural terrain = three art voices per frame), **(3) flat lighting** (one CanvasModulate tint; no lights, shadows, or bloom), **(4) source resolution**. Raising resolution alone is the weakest lever — a 64px static sprite still reads unfinished. `Art.scale_for()` already normalizes any texture size on screen, so higher-res art drops in with no code changes; animation does need a render-path change (Sprite2D → AnimatedSprite2D in player/enemy + codex thumbnails).

Licenses per CLAUDE.md asset rules (CC0 / CC-BY-family only; share-alike and NC are banned). Vetted candidates: **Ninja Adventure** (CC0, largest cohesive animated top-down set — characters/monsters/bosses + CC0 music/SFX; style softer than our tone), **Tiny Swords** (free commercial, 64px, market-quality but bright RTS flavor, thin monster coverage), **Pixel Crawler** (best tonal fit; license text must be read on the itch page before adoption). Roster gaps (unique bosses, six classes) get self-generated art matched to the adopted pack's style — allowed under "anything we generate ourselves," held to the same quality bar.

### Three tracks (A unlocks B/C's best look; B is parallelizable garnish; C is the heavyweight)
- **Track A — renderer & light. SHIPPED 2026-07-06:** Forward+ + 2D HDR (`viewport/hdr_2d`); WorldEnvironment glow in game boot (threshold 1.1 — only deliberate emissives bloom). `Art.hdr(color)` = THE emissive pattern (projectile glows, impact rings, loot beams, shared FX helpers `_ring_fx/_muzzle/_beam_fx`, kit payoffs). `Art.light()` = PointLight2D factory; player halo + hot bolts + loot beams carry light, **scaled by `game.light_mult`** (terrain-tint luminance: near-zero in daylight, full in void/grave — unscaled additive lights bloom daylight scenes into white blobs; screenshot-documented failure mode). Telegraphs stay LDR by doctrine. Still open: LightOccluder2D wall shadows, GPUParticles2D migration.
- **Track B — ambient life. FIRST WAVE SHIPPED 2026-07-06:** `ambience.gd` (Ambience.populate keyed off terrain, spawned with the scenery, zero gameplay weight) — village/wood birds that peck and FLEE the player, graveyard/desert crows, drifting butterflies; foliage **wind-sway shader** (`Art.wind_material()`, one shared material, phase from world position) on trees/flowers/mushrooms; **per-biome ambient audio beds** (`Sfx.make_ambient`: birds/wind/cold/crickets/drone, seamless 8s loops; `game.refresh_ambience()` per-frame hook switches on terrain and also sets light_mult). Still open: chimney smoke, cat/chickens, snow footprints, rustle-on-walkthrough, dash dust.
- **Track C — animated character art. SEAM SHIPPED 2026-07-06, pack adoption OPEN:** drop `assets/sprites/<name>_anim.png` (horizontal strip of square frames, count auto-detected from width/height) and that creature animates — `Art.anim_info()` + `Sprite2D.hframes`, render path unchanged (flips/tints/scale all still work; `Art.scale_for` gained a frames param). Enemies + player wired; idle pace, double-time on the move. Pilot installed: `wolf_anim.png` (2-frame breath, self-generated from the CC0 Crawl wolf). Next: adopt a pack (full packs are itch downloads — needs a human click), migrate the roster, self-generate gap art. 48/64px source resolution rides this step.

### The Greyrun river (Track B's one real feature) — SHIPPED 2026-07-06
Terrain-config water (`Terrains.DATA[tid]["river"]`: chance + color — the bog Greyrun runs BLACK per ch2 mill canon, marsh murky teal). Seeded per room, built with the scenery, skips boss arenas and the center door lane; animated pixel-water shader (`Art.water_material`) + plank bridge carrying the road across. **Wading slows everyone** (`Balance.RIVER_WADE_MULT` 0.72; the bridge is dry — terrain mechanic, codex'd) with entry splash + wading ripples; enemies wade too. Ladder still open: drink/quest-water flavor interactions → fishing (deferred; MMO retention seed).

### Boot flow (agreed 2026-07-06)
Cover → roster → creation, like a grown-up RPG: **stage 1 = the COVER** (`ui/cover.gd`: procedural night set — starfield, rising embers, the Ember Crown in a bloom halo, the four founders' Embers orbiting; `assets/sprites/cover.png` overrides the whole set; any key advances), **stage 2 = the character roster** (`menus.open_slots`: saved heroes with class icon/level/timestamp + delete, "New Character" on top, Settings) — class select only appears when forging a new hero. Both stages report `menus.current == "title"` (one boot state, two looks — autotest contract). All boot menus keep the cover's night backdrop until play starts. Boot music: `"title"` (somber bell theme) on the cover → `"roster"` (hushed hearth theme) from the roster through chapter/class select → terrain music at play start; both synthesized in music.gd, overridable via `assets/music/title|roster.*`. Music player + set_music crossfade run PAUSE-IMMUNE (boot menus pause the tree). Autotest path (`no_saves`) still boots straight to chapter select.

### Standing rules
- **Distributions are CURVES, never uniform (env doctrine, 2026-07-17).** Any numeric roll that shapes the environment — clump size, accent repeats, per-spawn mob size, room density, prop counts — must follow a probability curve that mimics real conditions (a decaying tail or a bell), NOT a flat `randi_range`. Average is common, extremes are rare, and there's a hard cap where "any more" would break immersion. Encoded in `Balance.SCENERY_*` (cluster-size decay `GROW`/`GROW_DECAY`, accent-repeat `CHANCE`/`DECAY`, density `JITTER` band, `MOB_SIZE_VAR` bell). A uniform distribution in placement/scale code is a bug to fix, not a default. (Discrete prop *choice* is still fine as a weighted pool — the weighting via list duplicates IS the curve.) The rule reaches INTO textures: organic growth (moss, rust, cracks) is authored as clustered per-feature blobs with coverage varying across variant tiles on the same curve (clean rare → heavily-overgrown the rare extreme; multi-tile textures like the 64x64 wall_moss grid — `_wall` tiles them for free). And organic mess beats sterile legibility: not every tile must read cleanly, so long as resolution holds and it fits the concept.
- FX doctrine applies to all of this: nothing ships until SEEN in a `shot_kit.gd` screenshot.
- Ambient life carries zero gameplay weight (no XP, no drops, no aggro) — critters are scenery that reacts, not entities.
- Any ambient detail that gains mechanics (river slow, hazard weather) graduates to a terrain mechanic: codex entry + telegraph-readability rules apply.
- Transmog/cosmetics (retention roadmap №6) unblocks after Track C — it's the art pipeline it was waiting on.

## The Eight Classes

Six ship Phase 1; Death Knight + Summoner are expansion. All openings share one scaffold: combat encounter → consequence scene → Maren recruitment (branch on class, then `first_choice_flag` from the consequence scene — it shapes Maren's tone all game).

### Warrior — Melee — STR — Sword/Axe — live
Ember: Vargoth's own. Virtue: Protection. Temptation: Tyranny ("I'll control them for their own good"). Themes: Fury (rage burst), Bulwark (DR/reflect), Earth (CC/zone).
Opening: wake mid-blackout having hurt someone while protecting them; the quest is the aftermath. Maren: brisk, professional — she's trained Vargoth's bloodline before; doesn't say it until Act 2.

### Paladin — Melee — STR/INT — Hammer — NEW at launch
Ember: a fragment of the Concord's binding magic itself — the only Ember that resists corruption rather than embodying it. Virtue: Defiance (refusing what the Ember demands). Temptation: Righteousness ("I know what you need saving from"). Themes: Holy (heal-on-hit, Consecration stacks), Aegis (redirect/reflect charges), Wrath (tethers that root/drag into melee).
Opening: village arbitrator mid-hearing when raiders hit; picks up a dead guard's hammer, Ember ignites — then goes back inside and finishes the trial. The man is guilty; the Ember says he's yours to shield. Deliver the verdict? Maren recruits for the CHOICE, not the fight. Her read: quietly hopeful — the chain producing a bearer is new.

### Assassin — Melee — AGI — Daggers — live
Ember: the unnamed founder who betrayed the Guard before Vargoth rose; name erased. Virtue: Sacrifice. Temptation: Consumption ("take what keeps you strong"). Themes: Poison (attrition), Shadow (mobility/stealth burst), Blood (lifesteal, low-HP power).
Opening: the Ember activates by taking from someone to survive — gray, not evil; the quest is the unseen price. Maren: careful, not suspicious — wants to know what they took before offering trust.

### Death Knight — Melee — STR — Greatsword — EXPANSION
Ember: a bearer who died holding it and came back wrong. Virtue: Persistence. Temptation: Consumption ("I'm already dead; taking costs me nothing"). Themes: Plague (spreading kill-DoTs), Ruin (temporary max-HP shrink + lifesteal), Frost (stack Brittle → shatter crit).
Opening: opens on your grave, three days buried. Claw out; family bars the door; clear the farm raid alone; then choose — knock again or walk away. Maren watches from the treeline and recruits on that choice.

### Mage — Ranged — INT — Staff — live
Ember: Mórwyn's — the battle-healer whose perfectionism curdled into blight. Virtue: Clarity. Temptation: Cruelty ("I'll perfect them whatever it costs"). Themes: Fire (burst/ignite), Ice (roots/shatter), Wind (mobility/echo chains).
Opening: the Ember activates mid-heal and it doesn't heal clean — impossible to undo. The quest: do you tell the truth? Maren finds you either way; her read depends. Collegial but watchful — she knew Mórwyn's record.

### Archer — Ranged — AGI — Bow — live
Ember: Fangmaw's — beastkin corruption is this temptation at its end. Virtue: Freedom. Temptation: Severance ("cut ties; owe no one"). Themes: Storm (chain lightning), Venom (stacking poison/slow fields), Hunt (marks, attack-speed scaling).
Opening: the Ember severs something before you understand why — a bond snaps, home feels wrong. The quest is that immediate cost. Maren: most casual — archers run; she doesn't chase; the door stays open.

### Warlock — Ranged — INT — Tome — NEW at launch
Ember: borrowed, not inherited — a pact with something outside the world's edge. There is a debt. Virtue: Accountability. Temptation: the debt spiral (borrow more to fix the last borrowing). Themes: Curse (amplify-hexes, death explosions), Pact (HP-fueled casts, lifesteal-only recovery), Void (delayed-burst rifts, high ceiling).
Opening: you wake knowing you already made the pact — no memory, tome in hand, debt real. Piece together what you traded (you haven't lost it YET). Maren recruits with a warning, not hope; watches Warlocks closest.

### Summoner — Ranged — INT — Orb — EXPANSION
Ember: fractured across the summons; losing them weakens you mechanically AND narratively. Virtue: Communion. Temptation: Hollowing (offload yourself until nothing remains). Themes: Beasts (melee companions; losing one costs HP), Spirits (phasing shades, mana drain, debuffs), Constructs (slow tanky channels; preparation over reaction).
Opening: a wounded wolf died near you and stayed. Fight the tutorial alongside a summon you learn to work WITH, not command. Maren asks the wolf's name: named = she smiles; unnamed = worried.

## Class × Faction Natural Pull
(Ambient factions pull through side quests/standing. DK/Summoner rows apply at expansion.)

| Class | Natural pull | Against-type |
|---|---|---|
| Warrior | Accord (atone for Vargoth's bloodline) | Cinderborn — "maybe the empire was right" |
| Paladin | Accord (the chain binds, not rules) | Hollow Choir — "maybe decay is honest" |
| Assassin | Unaligned | Accord — choosing to trust, first time |
| Death Knight | Hollow Choir (already dead) | Wildfang — kinship of the corrupted |
| Mage | Accord (correct Mórwyn's mistake) | Cinderborn — the empire valued knowledge |
| Archer | Wildfang (no masters) | Accord — choosing accountability |
| Warlock | Hollow Choir (the debt marks them) | Accord — repay rather than borrow |
| Summoner | Wildfang (creatures, not kingdoms) | Cinderborn — constructs as imperial engineering |

## Endgame: The Hollow Throne

The throne sits cursed in the ruined capital, calling to whoever is powerful or greedy enough. It will crown someone; it doesn't care who.
**Raid:** four players; an echo of Vargoth forms from the shard-power they brought. Same 30% enrage as Ch1 — deliberate callback. **Solo:** the echo forms from your Resonance + NPC allies built through Act 2; same resolution paths, different inputs.

**Resolution paths:**
- **Destroy the throne** (Accord): shatter it before the echo forms. Everyone present permanently loses significant power. Safer world; lesser you.
- **Claim the throne** (Cinderborn at launch; Hollow Choir variant when joinable): a champion sits, the empire returns. Mechanically a win; morally the next expansion's problem.
- **Council ending** (high positive Resonance; co-op: multiple bloodlines in the group; solo: high Resonance + ≥2 other bloodlines' NPC questlines done): multiple bloodlines refuse the pull and fuse fragments to seal it. Hardest; the only ending where something new exists after.
- **Hollow ending** (deeply negative Resonance): the echo crowns itself with your shard-power. A loss state — rare, brutal, sets up the recovery expansion. **Loudly signposted in advance** — diegetically (Maren withdraws, NPCs recoil, gleeful whispers), never a surprise at hour 40.

## Technical Notes for story.gd

- Resonance + Faction Standing live on the **player object** (survive solo→co-op with no migration).
- Openings reuse one scaffold; branch class → `first_choice_flag`.
- Author dialogue by Resonance **band** (tempted/neutral/steady), never per-value — three tagged variants is enough to feel watched.
- Morwen/Mórwyn RESOLVED (2026-07-04): two entities, deliberately near-identical names. Morwen the Blightcaller (Ch1 boss) was the Hollow Flame's chosen vessel-candidate — she heard Mórwyn first and took her goddess's name (Choir tradition: cultists take the name). Killing her is why the god-king woke in an unprepared blacksmith; one Aldric line delivers this, and Act 2 gets to tell the player it was their doing. "Ashvale" = Ch1 region vs "Vaelscar" = world (suggested).
- The Ch1 bosses + Throne echo share mechanical DNA (telegraphs, enrage thresholds) — boss.gd scales to multiplayer by numbers, not architecture.
- Faction Standing in co-op stays per-character; the disagreement is the content, no consensus mechanic.
- The raid is designed for exactly four players, ideally one per Ember bloodline; composition affects available resolutions.
