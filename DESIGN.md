# Emberfall — Story & Design Bible

## Phase Plan (agreed 2026-07)

This document is the north star; not all of it ships at once.

**Phase 1 — launch (solo, Chapter 2):**
- **Six classes**: Warrior, Assassin, **Paladin** (new melee) / Archer, Mage,
  **Warlock** (new ranged). Three melee, three ranged. The LoL balance rule
  extends: Paladin gets bruiser base stats, Warlock pays the ranged damage tax
  like Mage.
- **Two joinable factions**: Ember Accord and Cinderborn carry the political
  questlines, recruitment arcs, and ending stakes. **Wildfang Tribes and Hollow
  Choir become ambient factions** — standing is tracked and they react to you
  through zone and side content, but you cannot pledge to them at launch. Their
  lore stays fully canon; it is what justifies repeatable beastkin/blight zones.
- **Resonance ships whole.** It is the hook. Nothing about the trim touches it.
- All four existing classes get their openings retrofitted from this document.

**Phase 1 shipped 2026-07-04.** The next arc is the content build-out — see
**Content Architecture — The Road to 100 Hours** below.

**Phase 2:** co-op, then the Hollow Throne raid.

**Expansion (deferred by design, not cut):**
- **Death Knight** — mechanically cheap but crowds the Warrior/Assassin
  identities at launch; the grave opening is the expansion's marketing beat
  ("the update where you claw out of your own grave"), and by then co-op gives
  its Hollow Choir alignment people to argue with.
- **Summoner** — the most expensive class in the book (pet AI, pet pathing,
  eventually pet netcode). Headline addition later, not launch class #6.
- Promoting an ambient faction to joinable is an expansion's political plot.

---

## Setting: Vaelscar

Vaelscar was never at peace — it was held together by a lie. Six hundred years
ago, the **Concord of Ash** bound five warring god-kings into mortal vessels,
stripping them of divinity to end the War of Cinders. The world spent centuries
pretending those gods were gone. They weren't. They were old, weak, and hiding
inside people.

The Concord is failing. One of the five — **Mórwyn, the Hollow Flame** — has
fully reawakened inside her vessel, a peasant blacksmith who never asked for any
of this. Her reawakening is cracking the seals on the other four.

---

## The Ember Crown — Origin of Classes

The Ember Crown wasn't one artifact. It was four Embers — primal fragments
carried by the founders of the original Ember Guard — bound together inside
whoever wore the crown. Vargoth didn't steal a crown. He stole four Embers and
forced them to burn as one inside him. When Aldric's killing blow shattered it,
the Embers scattered separately, each reverting to its own nature and rooting in
people with old Guard bloodlines.

A shard-bearer isn't choosing a class at character creation. They're discovering
which Ember caught in them. That Ember comes with its own virtue, its own
temptation, and its own dead founder whose sins they inherited along with their
power.

---

## Bridge From Solo to Multiplayer

In Chapter 1 (solo), Aldric kills Vargoth and reclaims the Ember Crown. That
ending stands. The twist: Vargoth, in his final enrage, pours his own will into
the Crown and shatters it rather than let anyone else wear it. The shards scatter
across Ashvale and root in ordinary people with Guard bloodlines.

Years later, that's the player base. Every player character is someone whose
shard just awakened. The power they carry literally comes from a fragment of the
tyrant the Guard died fighting.

**Aldric** survived but spent his own ember in the killing blow. He's a
burned-out legend who can't fight anymore but knows exactly what's coming. He
functions as a late-game lore NPC, a "here's what I never told you" quest, or
optionally a superboss homage fight.

**Elder Maren** survives into the multiplayer era. She trained under Aldric,
watched the Guard fall, and now spends her days finding newly-awakened
shard-bearers before the factions do. She's the onboarding NPC across all eight
classes — same role, aged into a mentor, but reading each new recruit
differently depending on what she sees in them.

**Fangmaw and Mórwyn** weren't just monsters. They were corrupted Guard
commanders — Fangmaw a Stormwarden beastmaster, Mórwyn an Emberwright
battle-healer whose fire-healing curdled into blight. Killing them didn't cure
the corruption. It cut off the head. The beastkin warbands and blight-plague are
still spreading years later — justification for repeatable zone content and the
game's 14 terrain types.

---

## Progression Trackers

**Resonance** (per character, -100 to +100): every major choice nudges toward
your Ember's Virtue or its Temptation. Not a good/evil meter — specifically
tracks how you relate to the same power that destroyed your class's founder.
Stored on the player object (not world state) so it persists when a solo
character enters co-op.

**Faction Standing** (four independent values, one per faction): shifts
independently of Resonance. In single player, functions as a personal reputation
system. In co-op, the group's combined standings create table tension — two
Accord players and one Cinderborn player will not agree on everything. Also
stored per character.

These six numbers together gate all major story branches and ending eligibility.
Resonance should be felt in NPC dialogue and reactions before the player ever
sees a number, if they see one at all.

---

## The Four Factions

Two are joinable at launch (Accord, Cinderborn); two are ambient at launch
(Wildfang, Hollow Choir) — standing tracked, reactions real, no pledging.

### Ember Accord — joinable (Phase 1)
Maren's loyalists. Goal: gather the shards, destroy the hollow throne for good.
No one should ever wear the Crown again. They are asking shard-bearers to
voluntarily become less than they are. They are not wrong, but they are asking a
hard thing.

### Cinderborn — joinable (Phase 1)
Old regime nobles who prospered under Vargoth. Goal: find a worthy heir,
re-crown the throne, restore the empire. They believe order requires a crown and
that the chaos of the Waking proves it. Not cartoonishly evil — people who lived
well under tyranny and convinced themselves it wasn't tyranny.

### Wildfang Tribes — ambient at launch
Fangmaw's broken beastkin descendants. Internally fractured: one camp wants the
blight cured and seeks alliance with the Accord; the other has made peace with
what they are and sees "curing" as conquest dressed in mercy. Player choices can
influence which camp gains dominance.

### Hollow Choir — ambient at launch
Mórwyn's blight-plague survivors turned cultists. They don't see the rot as a
curse — they see it as the land's honest truth. Some are grieving people who
found meaning in horror. Some are genuinely dangerous. The line is hard to find.

---

## The Three-Act Player Journey

**Act 1 (low level):** Something personal triggers your shard. You don't know
what you are yet. Every class has a different emotional entry point but the same
structural shape: Ember activates → consequence you have to live with → Maren
finds you.

**Act 2 (mid level):** Factions start recruiting because they can sense what you
are. You choose alignment — not permanently locked, but consequential. The world
map opens as the Waking spreads: corrupted zones, refugee crises, old ruins
reactivating.

**Act 3 (endgame):** Direct confrontation with the awakening god-kings. In
single player, you assemble the pieces through NPC shard-bearer questlines. In
co-op, four players bring their own classes and Resonance scores into the Hollow
Throne raid together.

---

## Content Architecture — The Road to 100 Hours (agreed 2026-07-04)

Context: the first full human playthroughs clocked Chapter 1 at ~5 minutes and
Chapter 2 at ~8. The target is **100 hours of play across the three acts**. This
section is how we get there without pretending we can hand-author 100 hours.

### The hour budget

No solo-built game hand-authors 100 hours. The games that deliver it ship a
15–30 hour campaign and let **systems** own the rest (Hades: ~25h to credits,
hundreds via runs; Diablo/PoE: ~25h campaigns, thousands via rifts and loot).
Emberfall's budget:

| Source | Hours | What it costs us |
|---|---|---|
| Authored campaign (3 acts × 3–4 chapters) | 15–20 | The expensive part — bespoke zones, bosses, cutscenes |
| Difficulty tiers / NG+ | ×2–3 on everything above | Nearly free — monster level scaling to 100 already exists |
| Endless mode ("the Waking Depths") | open-ended | Cheap once the zone graph + room palette exist |
| Build & loot chase (gems to 10, S-gear per class, 6 classes × 3 themes × Resonance paths) | the glue | Already built — needs difficulty tiers to give it a *reason* |

### Acts vs chapters

- **Acts** are the narrative superstructure — the three-act journey above.
- **Chapters** are the playable unit we already built (own world, bosses,
  save/replay support): **3–4 chapters per act**, each 45–75 minutes first run.
- Existing Chapters 1 and 2 re-slot as Act 1's openers after the pacing
  retrofit. Nothing is thrown away.

### Mono-terrain chapters

Early chapters use **one terrain family each**; later chapters blend. Why:

- Each terrain's *mechanics* get room to escalate across a chapter (magma rain
  intensifying zone by zone) instead of appearing once and vanishing.
- The fiction supports it — the Waking corrupts one region at a time. Terrain
  blending in Act 3 is itself a story beat: the corruption is merging.
- Cheaper to author depth in one mood than breadth across six.

**Mono-family, not mono-look.** A graveyard chapter drifts misty fields →
zombie barrows → crypt stone → boss cathedral: one family, varied palettes,
patches, and events. Literal repetition of one tile for 6 zones reads as
monotony, not identity.

### The zone graph — the map grows in two dimensions

Zones stop being a single west→east corridor. Each room declares exits
(**N/S/E/W**) and chapters lay rooms out on a grid: branches, loops, optional
wings, and dead ends. Design intents:

- **Exploration time is content.** Walking down a wrong turn that pays off with
  a mood, an NPC, or nothing at all is pacing texture, not waste. The map is
  allowed to spend the player's steps — that's what makes it a place.
- **Chapter size: minimum 20 rooms, maximum 30.** The floor guarantees a
  chapter can't be a corridor sprint again; the ceiling keeps a mono-terrain
  family from overstaying its welcome and keeps authoring per chapter bounded.
- **The map (M key)** replaces the linear zone counter: a fog-of-war grid that
  reveals **only rooms the player has entered**, with a marker for the current
  room. Unexplored exits show as stubs off visited rooms, so the player can see
  *that* there's somewhere left to go without being shown *what's there*.
  Visited-room state saves with the character.
- The critical path stays readable; side rooms are where the optional density
  lives. Roughly 40–50% of rooms should be off the boss path.
- **Every run lays a different map (playtest round 4).** A chapter's boss
  path (the *spine*) is authored as an ordered room list, not coordinates;
  each run walks it onto the grid eastward with seeded N/S jogs, then
  attaches side rooms to seeded same-terrain hosts. The seed is the
  character's wander_seed — saves reload their exact world; replays and new
  characters roll a fresh one. Content stays authored; only the geography
  rolls.

### The room-type palette

Every room declares a type; combat is only one of them:

| Type | What happens |
|---|---|
| **Combat** | Mob packs (the default) |
| **Boss** | Arena, story-gated |
| **Social** | Wanderer NPC encounters — traders, pilgrims, refugees, deserters. Pool-based, rolled per character, so replays meet different people |
| **Resonance** | A shrine or stranger offering a genuine band-shifting choice — more chances to move Resonance *between* story beats, where it's currently starved |
| **Elite** | A single named elite with 1–2 affixes roaming the room; better loot |
| **Event** | The terrain's hazard amplified — a magma-rain gauntlet, a lightning field |
| **Dead end** | Scenery, maybe a lore prop or small cache — sometimes **nothing**. Deliberate |
| **Secret** | Rare; hidden exit or flag-gated; the best caches |
| **Merchant camp** | Safe pocket; ties into the post-boss wanderer roll |

Rooms that roll their contents (social, elite, dead-end caches) are seeded per
character — the replay matrix (class × theme × Resonance) gets spatial variety
for free.

### UX rules the bigger maps force us to decide

Consequences of 20–30-room graphs that need answers *before* coding, not after:

- **Backtracking & fast travel.** Dead ends and wings mean walking back.
  Walking through a *live* room is content; re-walking a cleared one is not.
  Rule: from the map screen, travel instantly to any **visited safe room**
  (hub, merchant camp, boss arena after the kill). Combat rooms are never
  travel targets — the space between safe rooms stays real.
- **Purge seals (playtest round 2).** Any room with living packs seals every
  door while they live — no running past content, no naked corridor sprints.
  Aggro stays per-pack inside the room; the quest line shows the room's
  "monsters left" counter as the visible WHY. The last kill fires a brief
  green cleansing pulse — *the blight recedes* — and the seals lift. The
  critical path also bends N/S and routes through at least one merchant
  camp per chapter, so the grid reads as a place, not a corridor.
- **Room-state persistence.** Cleared combat rooms stay cleared for the
  chapter run (and through save/load). Elites, socials, and caches do not
  respawn once resolved. Chapter replay re-rolls the seeded rooms — replays
  meet a fresh map, not a memorized one.
- **Death & checkpoints.** Death returns you to the last visited safe room
  with gear/gold/XP intact; the room you died in resets. No corpse runs, no
  loot loss — the penalty is the walk and the retry, which the bigger maps
  now make meaningful on their own. Nothing follows you home: boss adds and
  terrain-event spawns despawn on death, and every aggroed survivor calms
  and walks back to its post (playtest round 3 — a chaser once camped the
  respawn room).
- **Autosave on every room transition.** A 45–75 minute chapter cannot
  assume one sitting. Room granularity means quitting anywhere costs at most
  one room of progress.
- **Objective clarity.** Nonlinear maps must not mean lost players: the quest
  line stays on screen, and once the player has *seen* the boss door, the map
  marks it. Before that, unexplored-exit stubs are the only hint — finding
  the door is gameplay, remembering where it was is not.
- **Audio fatigue.** Mono-terrain chapters mean one music mood for up to an
  hour. Each terrain family needs at least an **explore layer and a
  combat/boss layer** (or deliberate silence between), not one looped track.

### Elites & affixes

A small affix pool (Frenzied, Bulwark, Vampiric, Stormtouched, Splitting…)
applied to existing monsters with a scale/tint and a loot bump. One system,
variety in every combat room, and it double-feeds difficulty tiers and the
endless mode.

### Difficulty tiers / NG+

Chapter replay already keeps the character; tiers reuse the existing level
scaling: **Normal / Nightmare (+20 levels) / Torment (+40)**, with loot-grade
floors rising per tier. This is the cheapest multiplier in the plan — it
triples the value of every zone already built.

### Endless mode — the Waking Depths

A procedural chapter: rooms chained from the terrain families with rising
monster levels and affix density, checkpoints every N rooms, depth counter as
the bragging stat. Built entirely from the zone graph + room palette + elites —
which is why those come first. This is where hours 30–100 live.

### Pacing retrofit (applies to Chapters 1–2 before anything new)

The 13-minute clear isn't only a content-volume problem:

- Rooms grow to 2–3 screens of walkable space, more mob packs per room.
- Time-to-kill at level parity roughly doubles (mob HP tune, not damage).
- **Exponential monster growth — no level-gap combat rule (round 4).**
  Monster HP/damage growth COMPOUNDS per level (`base × (1+g)^Δ`) instead
  of adding, matching the player's own compounding power curve. At the
  authored level nothing changes, so parity balance is untouched — but a
  monster 10 levels up is a wall of honest, codex-visible stats: ~1 mistake
  and you're done, ~2 mistakes at +5. No hidden combat multipliers, no
  exemptions — mobs, bosses, and every attack type follow one rule: the
  stat sheet. Boss base damage was retuned up alongside (bosses were
  authored gentle: a contact hit now costs a squishy ~20-25% of at-level
  HP; dodge-everything god runs stay possible). Rewards still scale
  LINEARLY with level — no farm spiral. (Found in dev mode: a naked Lv4
  mage soloed a Lv14 boss. Never again.)
- The XP curve assumes side rooms — skipping them leaves you under-leveled.
- Gold/potion scarcity pass so merchants and haggling matter.
- **The chapter XP total is FIXED (playtest round 4).** Kill XP comes only
  from authored room packs and bosses — terrain-event spawns and boss
  summons pay zero — so every run yields the same total. Replaying a
  chapter you have already COMPLETED pays no XP at all: farm gold and
  gear, never levels.
- **Level parity is the XP budget (playtest round 5).** Chapter 1 trash
  XP paid ~1.6× what its level plan supported: a full clear hit L15
  against the L12 final boss, and the player was L10 farming L6 marsh
  mobs ("outleveling by 4 is unfair"). Trash XP was cut ~45% (wolf
  12→7, spider 14→8, cultist 20→11, skeleton 24→13, zombie 15→8) so a
  full clear now tracks room mob levels within ±1 and reaches each boss
  AT its level (L5 Fangmaw / L8 Morwen / enter Vargoth L11, ding 12 on
  the kill); spine-only runs sit ~1 under, as intended. Chapter 2 was
  already on budget (L8 at the Choir Mother, L16 at Warden Null) and is
  untouched. Rule for new chapters: sum the authored pack XP, walk it
  through the 30+22·lvl curve, and land each boss room at boss level.
- **Attributes: 1 point per level, not 5 (playtest round 5).** Same
  cadence as skill points. 5/level buried the player in unspent points
  (30+ banked by L10) and silently added ~1.5 extra levels of ATK per
  level on top of natural growth — half the reason mobs died in a few
  hits. Per-point conversion ratios are unchanged.
- **No downscaling — a monster's listed level is its MINIMUM (playtest
  round 6).** Trigger: "a L20 mage solos 5 L36 Warden Nulls." Spawn an
  endgame boss in chapter 1 and it arrives with its stats as-is; spawn
  an early boss at endgame and it scales UP — early bosses stay
  reusable, lesser threats forever. The Ch2 bosses were re-anchored at
  their story spawn levels (8/10/16, was 14/22/32): the down-scaling
  floors had gutted them — story-level Warden Null hit for 12, softer
  than his own trash. Kill rewards were re-anchored to what they
  actually paid, so chapter XP totals are unchanged.
- **Every monster substat scales with level (playtest round 6).**
  Monsters carry an attribute BUILD — `attrs` points per level above
  anchor, converted through one `MONSTER_ATTR_SCALE` table (STR→pen/
  critres, AGI→dex/crit/eva, INT→magpen/magres, VIT→res/critres) — so
  physres/magres/critres/crit/dex/pen all climb, not just hp/dmg.
  Kinds without an authored build get an archetype default (brute STR,
  skirmisher AGI, caster INT; bosses invest at double the trash rate).
  Boss dmg growth was raised to ~hp growth (0.13–0.14): a +16 boss now
  one-shots what it should one-shot. Enemy hits resolve through the
  SAME Stats.resolve math as player hits (their crit vs your critres,
  their pen vs your res, their dex vs your eva) — attacker-less damage
  (telegraphs, hazards) stays plain, dodging by movement.
- **Talent points can buy substats directly (playtest round 6).**
  Besides STR/AGI/INT/VIT (class-scaled), points go 1:1 into PhysRes,
  MagRes, CritRes, DEX, PhysPen, MagPen (Classes.SUBSTAT_SCALE). Combo
  is deliberately NOT purchasable — a cooldown-skip chance you could
  buy every level would snowball.
- **Rooms are not all one size (playtest round 6).** Every room still
  occupies one grid cell, but quiet types — social, dead_end,
  resonance, merchant, elite arenas — shrink their walled playable
  area (`Game.SMALL_INSET`); short corridors connect the doorways to
  the cell edges, and the camera clamps to the playable rect. A room
  where you talk to one NPC should not be a three-screen hike.
- **ELITES (playtest round 6).** A promoted monster (`promote_elite`):
  ~4× HP, 1.5× damage, +res/critres, 1.3× sprite, gold ring underfoot
  — reads as a miniboss. Two seeded spawn paths (per character, like
  the wanderer rolls): ~30% of social side rooms hold a lone elite
  instead of a wanderer (small arena; a wanderer moves in after you
  beat it), and ~18% of combat rooms promote one pack member. Elites
  pay ZERO XP (chapter totals stay fixed) but are loot pinatas: 3×
  gold, a guaranteed gem, a guaranteed silver/gold chest, ~30% a
  talent reset stone, ~15% a bag. LATER CHAPTERS: elite rooms and
  combat rooms may spawn SEVERAL elites at once — the single-elite
  numbers above are the chapter 1–2 tuning, not the system's shape.
- **Bags & consumables (playtest round 6).** The bag is carried
  capacity for everything not equipped — gear, gem STACKS and
  consumables share its slots (F 15 / E 20 / D 25 / C 35 / B 50 /
  A 70 / S 100, `Items.BAG_SLOTS`). Gems stack: one slot per
  stat+level kind however many you hold, and a gem that fits an
  existing stack is always a free pickup (round 7 — the relief valve
  for gem hoards). One bag at a time: looting a bigger one upgrades
  in place, smaller ones convert to gold; elites are the bag source.
  Overflow pickups auto-sell (gems included); internal gem machinery
  (synthesize, socket removal) never jams on capacity. The inventory
  is a WoW-style slot grid: icons for gear, colored gem stacks
  (click a x3 stack to synthesize), consumables click-to-use, dark
  squares for free space. First consumable: the **Stone of
  Unlearning** (elite drop, ~30%) — refunds every allocated talent
  point for reallocation.
- **Dev/rogue boss kills never touch the story (playtest round 7).**
  Only zone-spawned bosses (`story_boss`) drive quests, gates,
  dialogue, `boss_done` and chapter endings; any boss spawned by the
  dev panel or tests routes to `game.on_rogue_boss_died` — rewards
  and brawl bookkeeping only (found when a spare dev-spawned Vargoth
  died in the village and "won" chapter 1). Multi-boss music no
  longer steps down per kill: it stays where it peaked until the last
  boss falls, then the terrain track returns.
- **Resonance is visible now (playtest round 6).** The Stats tab shows
  the number, its band, and a plain explanation of what moves it and
  what it affects (haggle prices, gated dialogue, NPC reactions). The
  "feel it before any UI exposes it" rule (below) held for Phase 1;
  actual players immediately asked what the stat even was.
- **Act loot ceilings (playtest round 4).** Chapter 1 never drops above C;
  Chapter 2 caps at A; S-tier is Act 3 / endgame loot. Chest tier weights
  are unchanged — rolls above the ceiling collapse to it. Power-curve
  note: ch1 was implicitly balanced around lucky A/S drops; the cap plus
  the mob retune is deliberate pressure — verify in the next playtest.
- Aggro becomes per-pack, not per-room — rooms are too big for all-at-once.
- **Combat readability** (standing playtest feedback): cooldowns and resource
  costs get visible numbers on screen, and melee classes get risk
  compensation through their class passives. Longer fights make both
  non-negotiable — you can't ask players to eat hits for 2× longer without
  telling them what their kit is doing.

### Build order

1. Zone graph + room-type palette + pacing retrofit of Chapters 1–2
2. Elites/affixes + difficulty tiers (instant replay hours on existing content)
3. Act 1's remaining chapters (mono-terrain, new structure)
4. The Waking Depths
5. Acts 2–3 chapters, blending terrains as the Waking merges

Step 1 is the **vertical slice**: retrofit Chapter 1 alone first, human-playtest
it, and lock the numbers (room size, TTK, density, map feel) before touching
Chapter 2 or authoring anything new. Every tuning mistake found there is one we
don't replicate across eleven more chapters.

**Engine note:** a 30-room chapter should not build all 30 rooms at load. Rooms
build lazily on first entry and only the occupied room (plus, later, its
neighbors) simulates. This also keeps the door open for procedural room
generation in the Waking Depths, where the "chapter" has no fixed size at all.

---

## The Eight Classes

Eight are designed; **six ship in Phase 1** (Warrior, Paladin, Assassin, Archer,
Mage, Warlock). Death Knight and Summoner are expansion classes.

All classes share the same tutorial structure: combat encounter →
consequence scene → Maren recruitment. Only the dialogue trees and consequence
scene content differ per class. Reuse the same quest scaffolding in `story.gd`.

### Warrior — Melee — STR — Sword/Axe — Phase 1 (live)
**Ember:** Vargoth's own.
**Virtue:** Protection — standing between harm and those who can't protect
themselves.
**Temptation:** Tyranny — "I'll control them for their own good."
**Themes:** Fury (rage-stacking burst), Bulwark (damage reduction and reflect),
Earth (CC and zone control).
**Opening:** You wake mid-blackout having hurt someone while protecting them. The
first quest is the aftermath — not the fight. Maren finds you scared of your own
hands.
**Maren's read:** Brisk and professional. She's trained people carrying Vargoth's
Ember before. She doesn't say it out loud until Act 2.

---

### Paladin — Melee — STR/INT — Hammer — Phase 1 (NEW at launch)
**Ember:** Not a god's power. A fragment of the Concord's binding magic itself —
the force that chained the gods. The only class whose Ember resists corruption
rather than embodying it.
**Virtue:** Defiance — the power to refuse what the Ember demands of you.
**Temptation:** Righteousness — "I know better than you what you need saving
from."
**Themes:** Holy (heal-on-hit, Consecration stacks that burst-heal allies or
cleanse debuffs), Aegis (Bulwark charges that redirect incoming damage as
reflected magic), Wrath (tether abilities that root, slow, or drag enemies into
melee range — high damage, low sustain).
**Opening:** You're a village arbitrator mid-hearing on a grain-hoarding case
when blight-touched raiders attack. You pick up a fallen guard's hammer, the
Ember ignites, the raiders flee. Then you go back inside and finish the trial.
The man is guilty. The Ember wants you to let him go — you protected him, the
chain says he's yours to shield. Do you deliver the verdict? Maren recruits you
not because you fought well, but because you chose correctly when the Ember told
you not to.
**Maren's read:** Quietly hopeful in a way she doesn't show with others. The
Concord's chain producing a shard-bearer is new. She thinks it might be good.

---

### Assassin — Melee — AGI — Daggers — Phase 1 (live)
**Ember:** The unnamed founder. Betrayed the Guard before Vargoth even rose. The
histories buried their name entirely.
**Virtue:** Sacrifice — giving up something of yourself so others don't have to.
**Temptation:** Consumption — "Take what keeps you strong."
**Themes:** Poison (DoTs and attrition), Shadow (mobility, evasion, burst from
stealth), Blood (lifesteal-centric, self-harming abilities that hit harder the
lower your HP).
**Opening:** Your Ember activates by taking something from someone else to
survive — morally gray rather than outright evil. The first quest is finding out
your survival had a price you didn't see coming.
**Maren's read:** Careful, not suspicious. She knows this bloodline produces
people who survive by taking. She wants to know what they took before she offers
trust.

---

### Death Knight — Melee — STR — Greatsword — EXPANSION
**Ember:** A shard-bearer who died holding their fragment and came back wrong.
What happens when a Warrior's Ember refuses to let them stay dead.
**Virtue:** Persistence — continuing despite having already paid the highest
price.
**Temptation:** Consumption — "I am already dead. What I take from others costs
me nothing."
**Themes:** Plague (blight-rot DoTs that spread on kill, farming kills for
stacking buffs), Ruin (abilities reduce enemy max HP temporarily — they shrink,
not just take damage; pairs with lifesteal), Frost (layer Frost stacks until the
enemy goes Brittle, then shatter with an amplified crit — rhythm-based burst).
**Opening:** The game opens on your grave, three days after burial. You claw out.
Your family bars the door — they think you're a blight-creature. You clear the
raid hitting the farm alone (tutorial combat), then choose: knock on the door
again, or walk away to spare them? Maren is watching from the treeline. She
recruits you based on which choice you made at the door.
**Maren's read:** Waits until they've made their choice, then steps out of the
treeline. She needs to see the choice first.

---

### Mage — Ranged — INT — Staff — Phase 1 (live)
**Ember:** Mórwyn's. The battle-healer whose desire for perfection curdled into
blight.
**Virtue:** Clarity — seeing what is true without forcing it to be what you want.
**Temptation:** Cruelty — "I'll perfect them whatever it costs."
**Themes:** Fire (burst damage, ignite DoTs), Ice (roots, slow, shatter combos),
Wind (mobility, pushback, echo hits that chain to nearby enemies).
**Opening:** Your Ember activates while trying to heal someone, and it doesn't
heal clean. Something goes wrong in a way that's hard to explain and impossible
to undo. The first quest is whether you tell the truth about what happened.
Maren finds you either way, but her read depends on what you chose.
**Maren's read:** Collegial but watchful. She knew Mórwyn's record. She's looking
for early signs of the same pattern.

---

### Archer — Ranged — AGI — Bow — Phase 1 (live)
**Ember:** Fangmaw's. The beastkin corruption is this Ember's temptation taken
all the way to its end.
**Virtue:** Freedom — moving through the world without owing it anything.
**Temptation:** Severance — "Cut ties. Owe no one."
**Themes:** Storm (lightning-infused arrows, chain lightning on crit), Venom
(stacking poison, slowing fields), Hunt (tracking mechanics, damage bonuses
against marked targets, attack speed scaling).
**Opening:** Your Ember activates by cutting you off from something before you
understand why — a bond snaps, a home feels wrong, a person you loved looks at
you like a stranger. The first quest is about what that severance cost,
immediately, before you have any framework for what's happening.
**Maren's read:** Most casual of the eight. Archers tend to run. She doesn't
chase. She makes sure they know the door is open.

---

### Warlock — Ranged — INT — Tome — Phase 1 (NEW at launch)
**Ember:** Not inherited — borrowed. A pact with something ancient that exists
just outside the edge of what the world is made of. The Ember is on loan. There
is a debt.
**Virtue:** Accountability — knowing exactly what you owe and to whom.
**Temptation:** Debt spiral — borrowing more power to solve the problems the last
borrowing caused.
**Themes:** Curse (hex enemies so all damage they take is amplified; stacks
explode on death for AoE), Pact (sacrifice HP to empower spells; lifesteal is
your only recovery), Void (open brief rifts that deal delayed burst damage when
they close — high skill ceiling).
**Opening:** You wake up knowing you already made the pact. You don't remember
doing it. The tome is in your hands and the debt is real. Your first quest is
figuring out what you agreed to, pieced together through journal fragments and
conversations with people who knew you before. The picture: you traded something
you haven't lost yet. You don't know what. Maren recruits you with a warning,
not hope.
**Maren's read:** Says yes and then immediately says she's not sure she should
have. Watches Warlocks more closely than any other class.

---

### Summoner — Ranged — INT — Orb — EXPANSION
**Ember:** Fractured — split across their summons. The Summoner's power doesn't
live inside them. A Summoner who loses their summons is mechanically and
narratively weakened at the same moment.
**Virtue:** Communion — sharing power genuinely rather than wielding others as
tools.
**Temptation:** Hollowing — offloading so much of yourself into your summons that
nothing remains inside.
**Themes:** Beasts (feral animal companions in melee range; losing a beast deals
a small HP penalty to the Summoner as the Ember fragment recalls), Spirits
(ethereal shades that phase through terrain, drain enemy mana, apply debuffs),
Constructs (ember-automatons — slow, tanky, abilities channelled through them;
rewards preparation over reaction).
**Opening:** A wounded wolf died near you and didn't leave. Not alive — but
stayed. Tutorial combat is fought alongside your first summon, who has its own
behavior you have to learn to work with rather than command. Maren doesn't tell
you what you are. She asks what the wolf's name is. If you named it, she smiles.
If you didn't, she looks worried.
**Maren's read:** Asks about the wolf.

---

## Class × Faction Natural Pull

Ambient factions still exert pull — it surfaces through side quests and
standing, not pledged membership. Death Knight and Summoner rows apply at
expansion.

| Class | Natural pull | Dramatic against-type |
|---|---|---|
| Warrior | Ember Accord (atone for Vargoth's bloodline) | Cinderborn — "maybe the empire was right" |
| Paladin | Ember Accord (the chain was made to bind, not rule) | Hollow Choir — "maybe decay is honest" |
| Assassin | Unaligned (owes nothing, trusts no one) | Ember Accord — choosing to trust for the first time |
| Death Knight | Hollow Choir (already dead, already past caring) | Wildfang Tribes — kinship with others who were corrupted |
| Mage | Ember Accord (Mórwyn's mistake was caring too much; correct it) | Cinderborn — the empire valued knowledge |
| Archer | Wildfang Tribes (freedom, no masters) | Ember Accord — choosing to be accountable to something |
| Warlock | Hollow Choir (the debt already makes them dangerous) | Ember Accord — trying to repay rather than borrow more |
| Summoner | Wildfang Tribes (creatures, not kingdoms) | Cinderborn — constructs as imperial engineering |

---

## Endgame: The Hollow Throne

Vargoth's throne sits in the ruined capital — cursed, empty, and quietly calling
to whichever shard-bearer is powerful or greedy enough to sit in it. The throne
will crown someone eventually. It doesn't care who.

**The raid:** Four players enter the ruined capital. An echo of Vargoth forms
from the throne using the shard-power the players brought with them. He carries
the same 30% enrage mechanic as the Chapter 1 boss — a deliberate callback.
This is what he always did when he was losing.

**In single player:** The echo forms from your Resonance score and the
shard-power of NPC allies you've built relationships with through Act 2
questlines. The resolution paths are the same; the inputs are different.

### Resolution Paths

**Destroy the throne** (Ember Accord ending): Shatter the throne before the echo
fully forms. Cost: all shard-bearers present lose a significant portion of their
power permanently. The world is safer. You are less.

**Claim the throne** (Cinderborn ending at launch; the Hollow Choir variant —
the rot becomes sovereign — arrives when the Choir becomes joinable): A chosen
champion sits. The empire returns. Mechanically successful. Morally
catastrophic in ways that become the next expansion's problem.

**The council ending** (requires high positive Resonance; in co-op, requires
multiple Ember bloodlines represented in the raid group): Shard-bearers from
multiple bloodlines simultaneously refuse the throne's pull and fuse just enough
of their fragments to seal it without destroying themselves. The hardest to
achieve. The only ending where something genuinely new exists afterward. In
single player, triggered by high Resonance plus completing questlines for at
least two other Ember bloodlines through NPC shard-bearers.

**The hollow ending** (requires deeply negative Resonance across the group, or
solo): The echo fully forms and crowns itself using the shard-power the players
brought with them. A loss state. Rare. Brutal. Sets up a recovery arc for the
next expansion. **Must be loudly signposted well in advance** — diegetically
(Maren withdraws, NPCs recoil, the Ember's whispers get gleeful), never as a
surprise at hour 40. Players who lose a campaign finale without warning refund;
players who watched themselves earn it tell stories about it.

---

## Technical Notes for story.gd

- Resonance and Faction Standing are stored on the **player object**, not world
  state. They must survive the transition from local single player to networked
  co-op without requiring migration.
- The opening sequence for all eight classes reuses the same quest scaffolding:
  combat encounter → consequence scene → Maren recruitment dialogue. Branch on
  class first, then check `first_choice_flag` set during the consequence scene.
  This flag shapes Maren's tone for the entire game.
- Resonance should surface in NPC dialogue and reactions before the player sees
  a number — ideally they feel it for a full act before any UI exposes it.
- To keep that affordable, author dialogue variants by Resonance **band**, not
  value: three bands (tempted / neutral / steady) tagged per line is enough for
  the player to feel watched. Per-value variants are a cost explosion.
- Canon spelling pass needed when Chapter 2 is authored: the shipped game says
  "Morwen"; this bible says "Mórwyn" (same character — standardize), and
  "Ashvale" vs "Vaelscar" need a settled relationship (suggest: Ashvale is the
  Chapter 1 region, Vaelscar the world).
- The four Chapter 1 bosses (Fangmaw, Mórwyn, Vargoth, Hollow Throne echo) share
  mechanical DNA: telegraphed red danger zones, enrage thresholds. The boss.gd
  architecture doesn't need to change for the multiplayer versions — just scale
  the numbers.
- Faction Standing in co-op is per-character. The group's combined standings
  create natural tension. No forced consensus mechanic needed — the disagreement
  is the content.
- The Hollow Throne raid is designed for exactly four players, one per Ember
  bloodline ideally. Class composition affects which resolution paths are
  available to the group.