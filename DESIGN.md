# Emberfall — Story & Design Bible
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

- Ch1: Aldric kills Vargoth; Vargoth pours his will into the Crown and shatters it. Shards root in ordinary people. Years later = the player base: every PC's shard just awakened; their power is a fragment of the tyrant.
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

### Pacing retrofit (Chapters 1–2, before anything new)
- Rooms grow to 2–3 screens; more packs per room; aggro per-pack.
- TTK at level parity ~doubles (mob HP tune, not damage). Gold/potion scarcity so merchants matter.
- **Exponential monster growth, no level-gap rule (round 4):** hp/dmg growth COMPOUNDS (`base × (1+g)^Δ`). At-level balance untouched; +10 = a wall of honest codex stats (~1 mistake dead; ~2 at +5). No hidden multipliers anywhere. Boss base damage retuned up (contact ≈ 20–25% of a squishy's at-level HP; god runs stay possible). Rewards LINEAR per level — no farm spiral. (Trigger: naked Lv4 mage soloed a Lv14 boss.)
- **Fixed chapter XP totals (round 4):** kill XP only from authored packs + bosses; event spawns/boss summons pay zero. Completed chapters pay NO XP on replay — farm gold/gear, never levels. XP curve assumes side rooms; skipping leaves you under-leveled.
- **Level parity is the XP budget (round 5):** Ch1 trash paid ~1.6× its level plan (full clear hit L15 vs the L12 boss; "outleveling by 4 is unfair"). Trash XP cut ~45% (wolf 12→7, spider 14→8, cultist 20→11, skeleton 24→13, zombie 15→8): full clear now tracks mob levels ±1, hits bosses AT level (L5 Fangmaw / L8 Morwen / enter Vargoth L11, ding 12 on kill); spine-only ~1 under. Ch2 was already on budget (L8 Choir Mother, L16 Warden Null). Rule for new chapters: sum authored pack XP through the 30+22·lvl curve; land each boss room at boss level.
- **Attributes: 1 point/level, not 5 (round 5):** same cadence as skill points. 5/level banked 30+ by L10 and silently added ~1.5 levels of ATK per level. Per-point ratios unchanged.
- **No downscaling — listed level is a MINIMUM (round 6):** (trigger: "L20 mage solos 5 L36 Warden Nulls") endgame boss in Ch1 arrives stats-as-is; early boss at endgame scales UP (stays reusable). Ch2 bosses re-anchored at story levels 8/10/16 (was 14/22/32 — floors had gutted them: story Warden Null hit for 12, softer than his trash). Rewards re-anchored; chapter XP unchanged.
- **Every substat scales with level (round 6):** monsters carry an attribute BUILD (`attrs` pts/level above anchor via `MONSTER_ATTR_SCALE`: STR→pen/critres, AGI→dex/crit/eva, INT→magpen/magres, VIT→res/critres); archetype default when unauthored (brute STR / skirmisher AGI / caster INT; bosses invest 2× trash). Boss dmg growth raised to ~hp growth (0.13–0.14). Enemy hits resolve through the SAME Stats.resolve as player hits (their crit/pen/dex vs your critres/res/eva); telegraphs/hazards stay plain — dodge by moving.
- **Talent points buy substats 1:1 (round 6):** PhysRes/MagRes/CritRes/DEX/PhysPen/MagPen (Classes.SUBSTAT_SCALE) besides class-scaled STR/AGI/INT/VIT. Combo deliberately NOT purchasable (bought cooldown-skip would snowball).
- **Room sizes vary (round 6):** quiet types (social, dead_end, resonance, merchant, elite arenas) shrink their walled playable area (`Balance.SMALL_ROOM_INSET`); corridors connect doors to cell edges; camera clamps to the playable rect.
- **ELITES (round 6):** promoted monster = ~4× HP, 1.5× dmg, +res/critres, 1.3× sprite, gold ring. Seeded per character: ~30% of social rooms hold a lone elite instead of a wanderer (wanderer moves in after the kill); ~18% of combat rooms promote one pack member. ZERO XP; loot piñata: 3× gold, guaranteed gem, guaranteed silver/gold chest, ~30% reset stone, ~15% bag. LATER CHAPTERS may spawn several at once — single-elite numbers are Ch1–2 tuning, not the system's shape.
- **Bags & consumables (round 6):** the bag = carried capacity for everything unequipped; gear, GEM STACKS and consumables share slots (F15/E20/D25/C35/B50/A70/S100, `Items.BAG_SLOTS`). Gems stack one slot per stat+level; fitting an existing stack is always free (round 7 — the hoard relief valve). One bag; bigger loot upgrades in place, smaller → gold; elites are the source. Overflow pickups auto-sell; internal gem machinery never jams on capacity. Inventory = WoW-style slot grid (gear icons, gem stacks click-×3-to-synthesize, consumables click-to-use, dark free squares). First consumable: **Stone of Unlearning** (elite ~30%) — refunds every allocated talent point.
- **Mailbox & ground overflow (round 8):** bag-full pickups DROP at your feet (tracked pickups; standing on one retries the claim) — nothing silently sells, and the shop refuses purchases into a full bag. At chapter end (victory or replay/advance teardown) unclaimed ground loot mails itself: subject "Dropped Loot", no body; the letter shows an inventory-style item grid + Claim (partial claims leave the rest). Claimed letters stay until deleted; unclaimed mail expires after `Balance.MAIL_EXPIRY_DAYS` (30). Mailbox lives in the pause menu with an unread badge; `game.send_mail(subject, body, items)` doubles as the dev/event-gift API. **Clock cheating:** players roll the OS clock to farm timed rewards — `game.trusted_now()` is a persisted monotonic anchor (never goes backwards; rolling forward only accelerates your OWN expiries). Never grant time-based anything from raw OS time.
- **Class balance doctrine (agreed post-round-17, no numbers moved):** every class splits one constant budget between FORGIVENESS (sustain/mitigation/range — passive safety that works through mistakes) and PAYOUT (damage/burst). Sustain is the strongest currency (it converts time into safety at zero attention cost), so high-forgiveness kits (warlock, paladin, warrior) sit at or slightly below the payout line; execution kits (mage, assassin) earn ~10-15% above it AT THEIR SKILL CEILING, never more — mastery is paid, others aren't invalidated. Two rules that follow: (1) execution classes' payout edge should live in BASE/ability multipliers (constant ratio at every level), NOT in growth (atk_lvl edges compound and outscale late game — round 17's growth-based edge is flagged for conversion if late-game testing shows divergence); (2) their survival tools must stay binary, timing-gated and rate-limited (ward, dash i-frames) — floors stay low, ceilings pay. Future extension candidates: perfect-play rewards (i-framing THROUGH a telegraph refunds dash cd; a consumed ward refunds mana) — raise the ceiling by paying skill, never the floor by padding health. Forgiveness classes never get these; that is their trade.
- **Convergence, second pass (round 17):** per-class L42 verdicts — Warlock "golden standard: challenging, doable, engaging" → FROZEN as the reference kit; Archer "doable but tedious, damage a little short" → 10.5/2.7 → 11.0/2.85; Mage "needs godly kiting" → glass cannon now has the highest growth (13.0/3.4 → 13.5/3.7) AND Blink 6.0 → 4.5s cd (more wards, more mobility — the ward cadence was the real wall, one absorb per 6s vs boss hits every ~1.5s); Assassin "bottom of the barrel" → 14.0/4.1 → 14.5/4.5 (highest melee growth — the squishiest melee must hit hardest), regen 1 → 1.2%/s, and **Shadow Dash gains Tumble-style i-frames** (hurt_cd 0.5 — dashing THROUGH the swing is the assassin answer to the melee uptime tax); Warrior 15.0/4.0 → 15.5/4.3 and Paladin 14.0/3.8 → 14.3/4.0 (untested this round; same pattern, verify next). Calibration rule stands: every class benchmarks against the warlock's L42 A-gear nullwarden clear.
- **Six-kit convergence (round 16):** playtest verdict — warlock was the only class on the boss line; warrior/paladin "lack damage" (the melee uptime tax vs longer, harder boss fights), assassin's 20% dodge is unreliable RNG with weak regen, mage has no sustain and sub-par damage. Philosophy: the warlock's L42-A-gear clear IS the calibration (round 13), so five come UP and warlock shaves ~10% to meet just below it. Changes: Warrior atk 14.5/3.7→15.0/4.0; Paladin 13.5/3.5→14.0/3.8; Assassin 13.5/3.8→14.0/4.1 + eva 20→25% + regen 0.6→1%/s (reliability over RNG); Mage 12.5/3.1→13.0/3.4 + **Arcane Ward** (Blink shields — the next hit within 4s fully absorbed; one absorb per Blink, 6s cd — the round-14 candidate, skill-timed sustain, not lifesteal); Warlock Shadowbolt 0.5→0.55s + lifesteal 6→5%. Every class now has identity-true sustain: regen (war), leech+regen (pal), evasion+regen (sin), leech+pact (lock), Second Wind (archer), Blink ward (mage).
- **Class-aware loot + archer damage (round 15):** playtest — archer damage lagged the warlock (both ranged, but the warlock never paid the archer's round-3 tax and carries the hex amp), and gear rolled dead stats (MagPen on phys classes; archers looting Tomes). Fixes: (1) archer atk 10→10.5, growth 2.5→2.7, Quick Shot 0.4→0.36s (attack-speed identity, ~+20% single-target — parity with warlock counting his vuln amp); (2) `Items.CLASS_WEAPONS` — weapon DROPS come only from the receiving class's arsenal (warrior Blade/Edge/Claymore, archer Bow/Crossbow, assassin Fang/Kunai, mage Staff/Wand, paladin Hammer/Blade, warlock Tome/Wand; anything still equippable from the bag); (3) rolled substat pools drop the OTHER damage type's penetration (phys never rolls MagPen, magic never rolls PhysPen; neutral stats stay shared). Chest and shop paths both pass the class already.
- **Class sustain parity without universal lifesteal (round 14):** playtest — the L42 A-gear parity nullwarden is beatable on warlock (6% lifesteal passive) but NOT on archer (pure-offense passive, zero recovery). Universal lifesteal rejected (flattens identity). Fix: **Archer — Second Wind**: untouched for 4s → +2.5% max HP/s until next hit taken (`sw_delay`/`sw_regen` passive keys; a connected hit resets the clock). Kiting discipline IS the sustain — deeply archer. Round 14b: first cut (4s/2.5%) was too weak — lifesteal is a RATE ON DPS (~35-50 hp/s for a L42 warlock) and dwarfs a flat trickle. Now 3s/6%/s ≈ ~42 hp/s while spaced: matches the leech when played well, drops to zero when tagged (the warlock heals THROUGH mistakes; the archer heals by not making them). Sustain audit: Warrior regen 1%/s, Paladin lifesteal+regen, Assassin evasion+regen, Warlock lifesteal+Pact, Archer Second Wind — **Mage remains the one sustainless class** (burst + Blink + range as defense); watch in the next boss playtest, candidate fix if needed: a Blink-timed absorb ward, NOT lifesteal.
- **Boss curve recalibrated to the gear timeline (round 13):** playtest — L42 nullwarden vs L42 full-A-gear warlock was "a bit too difficult"; it felt like S gear was required, but S only starts dropping L40-70. Diagnosis: boss damage GROWTH (round 11's rescaled 7.7%/level, and round 12's staged edge on top) still outpaced the player's ~5.5%/level, so the parity gap silently widened with level. Recalibration: the skill tilt is the CONSTANT `BOSS_DMG_MULT = 1.2` (felt equally at every level); boss damage growth is pinned to the player curve (`BOSS_DMG_GROWTH = 0.055`, replacing the compounding edge). Gear rule now explicit: **at-level bosses must be beatable in the act's top drop grade (A before L40); S-tier is comfort and difficulty-tier headroom.** L42 parity hit: ~345 plain / ~415-465 with multipliers vs ~820 A-gear HP — two connected hits kill, dodging decides, no S required.
- **Bosses out-curve the player (round 12):** feedback — post-round-11 Warden Null's HP is "perfectly in tune" but his damage still lacks, and endgame bosses SHOULD have a slightly better power curve than the player so skill, not stats, wins parity fights. Two knobs, damage only (boss HP stays on the parity curve): `Balance.BOSS_DMG_MULT = 1.2` (bosses hit above their tables at any level, stacking with ENEMY_DMG_MULT) and `Balance.BOSS_DMG_GROWTH_EDGE = 0.01` (+1%/level on top of the rescaled growth — bosses gain ~2-3%/level on the player). Resulting feel: Fangmaw at L5 bites for ~26% of a squishy (charge ~36%); Warden Null at-anchor slams for ~26-30%; at L38 parity a boss hit costs ~60-75% — two connected hits kill, dodging decides. Mobs unchanged (their damage was called right at round 10).
- **Growth matched to the player curve (round 11):** trigger — a L38 nullwarden ONE-SHOT a L38 full-S-gear player (55 x 1.14^22 = ~985 dmg vs ~900-1000 hp), while the same boss was trivial at low level. Root cause: compounded hp_g/dmg_g (~0.08-0.15/level) were tuned for GAP walls but also run along the at-level axis, where player power only grows ~5-6%/level — parity collapsed far from a monster's anchor. Fix: `Balance.GROWTH_SCALE = 0.55` rescales every authored growth rate inside enemy_stats_at (all chapters, codex-honest): effective growth ~4.5-8%/level, so at-level parity holds at ANY level. Gaps still bite: +10 = ~2x dmg (~2 mistakes), +20 Nightmare = ~3x with the round-10 dmg mult on top (near one-shot for squishies). This SUPERSEDES round 4's "+10 = one mistake" absolutism — that goal was mathematically incompatible with at-level parity across the leveling range. The autotest now guards BOTH directions (+10 must be >=1.8x dmg and <=3.5x).
- **Threat pass (round 10):** trigger — a L10 C-gear warlock facetanked a L16 Warden Null for ~6s and outran everything. Four levers, tuned together and deliberately conservative (they stack with round 9's HP): (1) `Balance.ENEMY_DMG_MULT = 1.3` — ALL monster damage, applied in enemy_stats_at so the codex stays honest (the codex monster rows now display live at-anchor stats, not raw table values); (2) ch1–2 boss speeds +~15% (Fangmaw 140→160, Morwen 105→120, Vargoth 115→132, Stormwarden 150→170, Choir Mother 105→120, Warden Null 85→100) — the player still outruns them, but kiting costs attention; (3) attack cadence/wind-ups trimmed ~10% (mob windup 0.3→0.27, bites, boss telegraph delays) — ch1–2 only, ch3's WIP untouched; (4) **no free full heal on level-up** — recalc keeps your hp/mp FRACTION as pools grow, so potions and merchants matter. Bonus fix: Vargoth's blade storm dealt a HARDCODED 30 damage at any level — now dmg×1.3, scaling like everything else (round-6 rule). Playtest the feel: every knob is one line.
- **Boss TTK budget (round 9):** trigger — Fangmaw died in <10s to a C-gear, zero-talent warlock. Root cause: boss HP pools predated gear grades/themes/skill tree and were exempted from the round-4 mob HP doubling ("already long fights" — no longer true; every class at L5 deals ~55–85 effective DPS). Rule: at level with modest gear a boss survives **~25s (chapter opener) / ~30s (mid) / ~40s (finale)** of realistic DPS — retune pools whenever player power moves. Ch1: Fangmaw 460→1200, Morwen 620→2200, Vargoth 1000→4200. Ch2: Stormwarden 750→2000, Choir Mother 1000→3200, Warden Null 2400→8000. Damage untouched (round-4 contact rule stands). Warlock verdict: NOT broken — Hex's guaranteed 3s EXPOSE on a 7s cd ≈ +21% net, strongest of six kits but within variance; watch it once fights actually last.
- **Resonance surfacing v2 (round 8):** a HUD line right under Combat Rating — golden with sparkle particles when positive (shinier/busier as it climbs), ink-black on pale outline when negative, and a pulse animation on every change (bright for gains, violet for losses). Shard choices made in quiet (non-combat) rooms now pay a token reward on ANY resonance change, up or down (gold; + a chest at |Δ|≥5) — the shard rewards conviction, not virtue. The codex gained ELITES, BAGS and CONSUMABLES entries. NPC idle emote bubbles read the band too (`IDLE_EMOTES`): hearts and song when steady, wary …/?/! when tempted.
- **Dev/rogue boss kills never touch the story (round 7):** only zone-spawned (`story_boss`) bosses drive quests/gates/dialogue/`boss_done`/endings; dev/test spawns route to `game.on_rogue_boss_died` — rewards only. (Trigger: a spare dev Vargoth died in the village and "won" Ch1.) Multi-boss music stays at its peak until the last boss falls.
- **Resonance is visible (round 6):** Stats tab shows number + band + plain explanation (haggle prices, gated dialogue, NPC reactions). The "feel it first" rule held for Phase 1; real players immediately asked what the stat was.
- **Act loot ceilings (round 4):** Ch1 caps at C, Ch2 at A, S = Act 3/endgame. Rolls above the cap collapse to it. Ch1 was implicitly balanced around lucky A/S drops — the cap + mob retune is deliberate pressure; verify in playtest.
- **Combat readability** (standing feedback): visible cooldown/resource numbers; melee risk compensation via class passives.

### Build order
1. Zone graph + room palette + pacing retrofit of Ch1–2 ← **vertical slice: retrofit Ch1 alone, human-playtest, lock numbers before authoring more**
2. Elites/affixes + difficulty tiers (instant replay hours)
3. Act 1's remaining chapters (mono-terrain)
4. The Waking Depths
5. Acts 2–3, blending terrains

**Engine note:** rooms build lazily on first entry; only the occupied room simulates. Keeps the door open for procedural Depths rooms.

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
