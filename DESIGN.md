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

### Pacing & balance — standing rules
The distilled, currently-true rules. The full round-by-round history (48 rounds of triggers, numbers moved, superseded experiments) lives in **BALANCE_HISTORY.md** — new rounds get logged THERE; a rule graduates to this list only once it's durable.

**World & progression**
- Rooms 2–3 screens, per-pack aggro; TTK at parity ~2× the Phase-1 feel; gold/potion scarcity so merchants matter. No free full heal on level-up (hp/mp keep their FRACTION as pools grow).
- Monster growth COMPOUNDS (`base × (1+g)^Δ`, rescaled by `GROWTH_SCALE` 0.55): at-level parity holds at ANY level; +10 ≈ 2× damage (autotest-guarded 1.8–3.5×). No hidden multipliers — `ENEMY_DMG_MULT` 1.3 / `BOSS_DMG_MULT` 1.2 apply inside `enemy_stats_at`, so the codex stays honest.
- No downscaling: a monster's listed level is a MINIMUM; early bosses scale UP at endgame.
- Fixed chapter XP: only authored packs + bosses pay; event/summon spawns pay zero; completed chapters pay NO XP on replay (farm gold/gear, never levels). New-chapter rule: sum authored pack XP through the 30+22·lvl curve; land each boss room at boss level (full clear tracks parity ±1).
- Rewards LINEAR per level. Act loot ceilings: Ch1 C / Ch2 A / S = Act 3-endgame. Lifesteal + combo never roll below B grade; gem slots F–C = 0.
- 1 attribute point/level; talent points buy substats 1:1 (combo deliberately NOT purchasable).
- Monsters carry attribute BUILDS (`MONSTER_ATTR_SCALE`, archetype defaults, bosses invest 2×); enemy hits resolve through the SAME `Stats.resolve` as player hits; telegraphs/hazards stay plain — dodge by moving.
- Boss TTK budget: ~25s opener / ~30s mid / ~40s finale of realistic dps, at level, in the act's top drop grade (**A-gear must beat at-level bosses before L40; S is comfort + tier headroom**). Boss damage growth pinned to the player curve (`BOSS_DMG_GROWTH` 0.055) with a constant 1.2 skill tilt. Retune pools whenever player power moves.
- Gem economy: elites guarantee 1 gem/kill (35% Lv2); bosses pay a 3-gem bundle on FIRST chapter clear, then a per-kill chance scaling to guaranteed at L40+ (`boss_gem_chance`). Sockets are elite/boss-hunting payoff.
- Elites: ~4× HP / 1.5× dmg / zero-XP loot piñatas, seeded per character (~30% of social rooms, ~18% of combat packs promote one member).
- One bag; gear, gem stacks and consumables share slots (F30…S115); topping an existing gem stack is always free; bag-full pickups drop at your feet and chapter-end mail themselves. ALL timed rewards ride `game.trusted_now()` — never raw OS clock.
- Dev/rogue boss kills never touch the story — only `story_boss` spawns drive quests/gates/endings.
- Resonance is VISIBLE: HUD line under Combat Rating (golden/ink by sign, pulse on change), Stats-tab explanation, NPC idle emotes read the band; quiet-room shard choices pay a token reward for conviction, not virtue.

**Class doctrine**
- One constant budget per class, split between FORGIVENESS (sustain/mitigation/range) and PAYOUT (damage). Execution kits (mage, assassin) earn ~10–15% above the line AT THEIR SKILL CEILING only; their edge lives in base/ability multipliers, never growth; their survival tools stay binary, timing-gated, rate-limited.
- Ranged power budget: damage on a ranged class's dash/short-range slot is phantom budget — those slots carry UTILITY (Frost Nova mends, Blink wards).
- No free immunity: dashes grant NO i-frames (assassin dash = 0); only all-in ult commits do (Death Mark 0.8s; Blink's 0.3s rides its longer cd class); gap-closer landing guards ride their own ~5s cooldown (warrior Charge, paladin Judgment leap).
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
- **Gambling vendor** — gold → random item (`GAMBLE_COST` wood 60 / silver 150 / gold 400).
- **S-legendary set bonuses** (2pc/4pc) — the chase on top of S gear.
- **Utility consumables:** mana draught, might elixir, recall scroll.
- **Quest log, buff-icon timer bar, corner minimap, achievements + boss records** (codex Records tab), **mailbox** (round 8).
- **Localization string-table foundation** (`Loc`) — strings routed early so translation is a table, not a rewrite.
- Inventory QoL: unequip, bag category tabs, bigger bags (F30…S115).

### Retention roadmap (agreed 2026-07-06)
Doctrine: **no new meta systems until the content multipliers exist** — the retention layer is already ahead of the content it retains players in. Addictive = (satisfying loop) × (reasons to re-run it); the loop is built, the multipliers are build-order steps 2–4. Alongside/after those, ranked by addictiveness-per-effort:
1. **Chapter results screen + personal bests** — time, deaths, elites found, secrets found, letter grade; PBs tracked per chapter × class × tier. Extends the existing boss-records plumbing; self-competition is the cheapest stickiness in the plan. Highest leverage.
2. **Weekly challenge seed** — one fixed `wander_seed` + an affix modifier, the same for everyone that week, PB-tracked. Near-free (seeded maps exist); becomes a real leaderboard the day multiplayer arrives.
3. **Loot dopamine pass** — rarity-colored drop beams + per-grade pickup sounds. The slot-machine feel is audio-visual, not systemic; FX ship screenshot-verified per doctrine.
4. **Elective risk events** — cursed chests / shrine gambles: accept a debuff-for-the-room for a guaranteed reward. New room-palette entries; risk-for-reward is single-player gambling, and it IS the Resonance temptation fiction.
5. **Codex completion + titles** — kill-count thresholds unlock lore entries; achievement points buy displayed titles. Turns the codex from reference into collection.
6. **Deferred:** transmog/cosmetics (long-tail chase, but wants an art pipeline we don't have yet); pity timers (the gem/boss-gem curves already do implicit bad-luck protection).

Everything above compounds into multiplayer: PBs → leaderboards, weekly seeds → shared ladders, titles → social display.

### Build order
1. Zone graph + room palette + pacing retrofit of Ch1–2 ← **vertical slice: retrofit Ch1 alone, human-playtest, lock numbers before authoring more** — **DONE** (48 balance rounds and counting)
2. Elites/affixes + difficulty tiers (instant replay hours) — **elites DONE (round 6); tiers NOT BUILT — the next cheap multiplier**
3. Act 1's remaining chapters (mono-terrain) — **Ch3 in progress (bosses landed, round 45 retune; needs playtest)**
4. The Waking Depths — not started
5. Acts 2–3, blending terrains — not started

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
