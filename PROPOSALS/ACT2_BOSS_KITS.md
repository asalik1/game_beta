# Act 2 Combat — boss kits, mob rosters, terrain mechanics (2026-07-27)

Deepening pass on `ACT2_DESIGN.md` §V–§VII: every chapter-8-through-14 boss taken
from sketch to implementable kit, plus each chapter's mob roster and terrain
mechanics as engine specs. Nothing here is installed and no game files were
touched — this is a decision document; the bible's fiction and boss names are
kept, the mechanics are trued up against the standing combat doctrine.

WoW touchstones are cited per fight where they apply (the bible already anchors
each chapter to one). The rule used throughout: steal the *decision* the WoW
mechanic forces, never its raid-scale choreography — everything below is
readable solo at 1 player and merely denser at 4.

---

## 1. Ground rules every kit below honors

- **TTK budgets** (`DESIGN.md`, `story.gd:498`): ~25s chapter opener / ~30s mid
  / ~40s finale at realistic at-level DPS in the act's top drop grade. Act 2's
  top grade is A (generic S from ch12) — pools get benched against that, not S.
  All magnitudes below are placeholders; the dps-bench phase owns numbers, and
  every number lands as a `balance.gd` knob (§38).
- **Threat-speed grammar** (`balance.gd:699-728`): aimed volleys 420→480 px/s
  by the finale; radial rings 300 (never under walk speed); standing melee
  plays the swing then re-checks reach on the contact frame; blinks land
  outside contact reach (the Varo rule); charge/pounce contact instant.
- **Floor vs ceiling**: every boss carries imposed, non-opt-in damage that
  reaches a KITER. `if dist<X` rings are opt-in tells, not a floor.
  Caster-lineage fights auto-pass; charge/melee-lineage fights need a second
  threat. §2 audits all 21 against this.
- **CC-immunity conversions**: bosses stay CC-immune; failed stun →
  `CONCUSSION_MULT` damage, failed slow → hobble mark. New Act 2 CC (silence,
  deep_freeze) never applies to bosses either — mobs only.
- **No-healer covenant** (2026-07-27): no fight assumes a dedicated healer in
  co-op. Sustain checks are per-head (auras, DoTs); burst checks are dodgeable
  per-head. Revive channels stay damage-interruptible — several finales below
  deliberately create revive windows (Recess, Verdict gaps) instead of safe
  downtime.
- **Party scaling** (`PARTY_*` in balance.gd): the 4-player threat is boss
  *cadence*, never mob one-shots. Kits below note which dial their cadence
  rides (cast interval, add count — never damage-per-hit).
- **DoT TTK tax**: any kit leaning on DoTs (Mórwyn P2 trails, toxic webs) pays
  the tax in its pool budget — DoT pressure shortens the benched TTK target,
  it doesn't stack on top of it.
- **Blight (healing reduction)** debuts ch12 per the bible: −50% healing
  received for 8s, applied by per-class abilities (~12s cd) or arena Blight
  Bomb pickups. Every healing boss from ch12 on is benched at ~60% Blight
  uptime and must be beatable (slower) at 0%.

---

## 2. Floor-vs-ceiling audit of the bible's 21 bosses

| Boss | Lineage | Floor (reaches a kiter) | Verdict |
|---|---|---|---|
| Thrain (ch8) | melee brute | Cast Metal aims at your run-to position | PASS |
| Verdant Anvil (ch8) | caster | auto-pass | PASS |
| Vassik (ch8) | caster | magma rain + lava wave | PASS |
| Yskara (ch9) | spawner | spiderlings chase; Venom Spit at range | PASS |
| Gatewarden (ch9) | stationary | Vine Reach tracks at range | PASS |
| Pale Nursery (ch9) | caster | auto-pass | PASS |
| Choir of Frost (ch10) | council casters | auto-pass | PASS |
| **Glacius (ch10)** | charge golem | charge + proximity stomp only | **FAIL → add Shardfall (§ch10)** |
| Elara (ch10) | caster | auto-pass | PASS |
| Drayce (ch11) | warrior kit | tracking charge + NPC squad (2nd threat) | PASS |
| Maeven (ch11) | caster | auto-pass | PASS |
| Shattered Vow (ch11) | environmental | terrain events reach everywhere | PASS |
| **Aldric (ch11)** | mundane duelist | melee only — a kiter never gets touched | **FAIL → add the Thrown Parry-Dagger + dueling-ring arena (§ch11)** |
| Rootweaver (ch12) | caster | auto-pass | PASS |
| **Grael (ch12)** | tank/healer melee | melee sweeps only; kiting = free Regrowth | **FAIL → add Thorn Flail (§ch12)** |
| Heart of the Root (ch12) | environmental | Pulse is arena-wide | PASS |
| Unfinished Sentence (ch13) | caster | auto-pass | PASS |
| Korrag Reborn (ch13) | storm warrior | storm wolves + spoken shockwaves | PASS |
| Mouth of the Storm (ch13) | environmental | storm cycle is arena-wide | PASS |
| Choir Ascendant (ch14) | caster | auto-pass | PASS |
| Burned King's Echo (ch14) | duelist + caster vocab | sampled verdicts/freezes are arena-scale | PASS |
| Mórwyn (ch14) | caster / aura | P3 aura + P2 bolts | PASS |

Three fixes, all specified in place below. Everything else ships as the bible
wrote it, with kits filled in.

---

## 3. Chapter 8 — The Ashfall Foundries (magma + castle blend, L40–46)

**WoW ref:** Blackrock Foundry. The decision stolen: *machinery is a weapon
for whoever reads it first* (Blast Furnace's operator logic, player-side).

### Terrain engine spec
- **Slag Vents** — floor grates on a per-room seeded layout. Cycle: 2.0s
  telegraph glow → erupt → leave a `lava` patch for 8s. Interval curve per
  room (curve, not uniform: average ~9s, rare 5s bursts). Grates are visible
  when cold — the floor is readable before it's hot.
- **Forge machinery** (castle-hall rooms only, authored not scattered —
  zone-authored-scenery rule): a pull-chain prop; activating dumps a
  telegraphed slag line across a marked lane (heavy damage to enemies AND
  player). 2 uses per room. This is the player's first environmental weapon.
- **New hazard patch `molten_metal`**: −30% enemy AND player speed (cooling
  metal grabs at feet). Visually distinct from lava (dull orange, no glow).
  Engine cost: one new patch type in the `_apply_hazards` table.

### Mob roster (traits per `enemy.gd` vocabulary; NEW = new engine verb)
| Kind | R/M | Type | Traits | Note |
|---|---|---|---|---|
| Foundry Thrall | melee | phys | sower, warded | walked into the furnace, came out "improved" |
| Slag Hound | melee | phys | pounce, frenzy | pack unit |
| Bellows Imp | ranged | magic | skirmish, swift | annoyance layer |
| Forge Zealot | melee | phys | **empowered** (NEW) | stacking +dmg every 5s; a heavy hit resets stacks |
| Verdict Drone | ranged | magic | **sentry** (NEW) | deploys a stationary turret, retreats while it lives |
| Cindersmith | melee | magic | channel_heal, empowered | priority stack: heals AND ramps |

**New engine verbs:** `empowered` (a timer + stack counter + the existing
"heavy hit" classification from the warded shatter check), `sentry` (spawn a
0-speed turret enemy + a retreat behavior reusing skirmish movement).

### Smelter-Lord Thrain — mid boss, L42, TTK ~25s
*"He wanted the perfect alloy. The Judge whispered the temperature. It's still climbing."*
Lineage: Calda's heat, matured. Melee brute, phys.

- **Heat (core stat):** climbs passively 0→10 over ~40s. Each point: +4%
  attack speed. At heat ≥7 his swings leave lava trails (sower logic, wider).
- **Quench (the decision):** three water troughs ring the arena. Luring him
  across one resets heat to 0 but grants a permanent +10% attack-speed stack
  (cap 4). Quench often = safer now, faster forever; never quench = race a
  lava-painting berserker. This is Calda's deny-the-dip inverted: now the dip
  is YOURS to offer.
- **Foundry Slam:** ring shockwave (300 px/s, opt-in tell) that also triggers
  every slag vent in the room at once — the room-wide layer that makes the
  ring matter beyond melee range.
- **Cast Metal (floor):** aimed molten boulder at the player's run-to
  position (aimed-class 430 px/s), leaves a lava pool. Fires on cooldown
  regardless of range — the kiter's tax.
- **30% — Meltdown:** heat pins at 10, quenching disabled (troughs flash to
  steam), trails every step. Race.
- Co-op: cadence dial = Cast Metal interval; troughs are shared (one player
  can quench-bait while others burn — the intended split).

### The Verdant Anvil — mid boss, L44, TTK ~30s
*"The anvil speaks the Judge's verdicts now. It doesn't need a hand to swing the hammer."*
Lineage: Ashpriest verdicts + the ch6 tether pair. Stationary caster, magic.
**WoW ref:** Iron Maidens' simultaneous-kill discipline.

- **Verdict Echo (signature):** arena divides into thirds; two GUILTY, one
  SAFE, rotating every 4s (telegraph paints 1.5s ahead). Guilty detonation is
  heavy, not lethal — one miss is a lesson, two is a death spiral.
- **Forge Constructs:** two weapon-adds — the Sword (glass cannon, chases,
  aimed lunges) and the Shield (warded tank, body-blocks your shots at the
  Anvil). While both live the Anvil channels a self-heal (~1.5%/s). At 40% of
  either construct's HP the OTHER enrages (+25% speed). If one dies and the
  other survives 2s, the dead one is RE-FORGED at half HP. Kill them within
  2s of each other or fight the rebuild. Solo tuning: their combined pool ≈
  35% of the Anvil's; the sync window is generous (2s) because one player is
  syncing their own two damage streams, not two players coordinating.
- **Hammer Fall:** telegraphed slam onto the current SAFE third's center —
  the safe zone is safe from verdicts, never from attention. (Floor: this
  plus the constructs reach any kiter; the Anvil itself never moves.)
- Co-op: constructs gain the party HP dial; verdict thirds are per-arena, not
  per-player (shared safe ground forces stacking — deliberate, it feeds boss
  cleaves nothing since the Anvil has none).

### Archon Vassik, Vessel of the Molten Judge — chapter finale, L46, TTK ~40s
*"He opened the foundry to prove the Cinderborn could master the old fire. The fire agreed — on its terms."*
Two-phase caster, magic + phys. Lineage: Ashpriest → god-king filter.

- **P1 The Forge-Lord (100–50%):** Ashpriest DNA at speed — half-arena
  verdicts (2.2s cadence), 4-bolt brand fans (aimed 440), two Sons-style
  interceptor adds at 75%. The fight you know, faster, at L46. Deliberate
  nostalgia before the turn.
- **P2 The Vessel Speaks (50–0%):**
  - **Binding Verdict:** 2.0s cast; on completion, root + ticking fire (4s)
    unless you are in LOS-break behind a pillar. 4 pillars; each use cracks
    the pillar you hid behind (3 uses → rubble). Pillar budget IS the enrage
    timer: ~12 Verdicts of cover if you never waste one.
  - **The Judge's Attention (floor):** continuous magma rain (random
    telegraphed impacts, room-wide) + a slow lava wave that sweeps one arena
    half, alternating halves — imposed movement between Verdicts.
  - Interceptors continue at 35%/15%.
- **On death:** faction-divergent beat per the bible (Accord rebinding
  volunteer / Vassik's partial containment). Both write kept flags Act 3
  reads (`chose_` prefix).
- Co-op: each player draws their own Binding Verdict (staggered 0.5s), so
  pillar assignment is the party conversation; pillar count stays 4 at any
  head count — the scarcity is the mechanic.

---

## 4. Chapter 9 — The Drowned Reaches (bog + sewer blend, L46–51)

**WoW ref:** Underbog / Vashj'ir. Decision stolen: *the water level is a
clock everyone reads.*

### Terrain engine spec
- **Rising Water** — room-wide cycle: LOW (60s) → rising telegraph (5s,
  gurgle + shoreline glow) → HIGH (25s) → drains. At HIGH: all low ground
  becomes `poison`-class water (slow 0.8× + DoT tick); authored platforms
  (elevated, zone-authored per room) stay dry. Enemies wade at the same
  penalty (`RIVER_WADE_MULT` reuse). Engine cost: a room-level timer that
  swaps a hazard patch set on/off + a platform prop class; reuses the river
  wading plumbing.
- **New hazard `spore_cloud`:** drifting cloud (drift:true reuse) applying
  **Drowse** (Mother Halla's meter — stand-still detection) instead of
  poison. Drowse at cap = 2s sleep stun (mobs only apply it to players;
  never applies to bosses).
- Sewer rooms (imperial undercity): no weather, tight corridors — the
  chapter alternates open bog (water clock) and tunnels (chokepoints), so
  both movement disciplines get exam time.

### Mob roster
| Kind | R/M | Type | Traits | Note |
|---|---|---|---|---|
| Sluice Lurker | melee | phys | **burrow** (NEW) | Sexton tech on trash: submerge → reposition → eruption telegraph |
| Cistern Mimic | melee | phys | **mimic** (NEW) | disguised as a chest/crate; shimmer tell every 3s; heavy ambush hit |
| Root-Spiderling | melee | phys | web, tether | Yskara's brood, paired |
| Drowned Warden | melee | phys | warded, martyr | imperial dead, still on post |
| Cure-Seeker Heretic | ranged | magic | channel_heal | Wildfang schism made flesh |
| Bloat Leech | melee | phys | bloat, swift | pops into water-poison |

**New engine verbs:** `burrow` (untargetable submerge + eruption telegraph —
port of the Sexton's move to `enemy.gd`), `mimic` (spawn-as-prop state +
proximity trigger + the 3s shimmer tell; ranged hits reveal safely). Mimic
also feeds the Depths and a cursed-chest variant later — build once.

### Broodmother Yskara — mid boss, L48, TTK ~25s
*"She was a sewer spider before the Root found her. Now her web is made of roots, and her eggs hatch flowers."*
Spawner / zone control, phys. **WoW ref:** Beauty's pathing discipline.

- **Root Web (signature):** 6–8 web-lines strung across the arena (visible,
  breakable at ~3 hits each). Player contact = 1.2s root (Serane lineage).
  Yskara ignores them. The pattern reshuffles every 20s (old lines wither,
  new ones grow — 2s grow telegraph).
- **Egg Sacs:** 2 sacs on a 15s timer; each hatches 3 spiderlings
  (tether-paired + one loose) after 6s unless destroyed. Destroyed sacs
  splash poison — kill them from range or eat the splash.
- **Venom Spit (floor):** 3-patch poison cone at any range, aimed-class.
- **25%:** all webs turn TOXIC (proximity poison aura per line) and stop
  reshuffling — the final maze is fixed; pathfinding it while she chases IS
  the burn phase.
- Co-op: sac count rides the party dial; web layout is shared.

### The Overgrown Gatewarden — mid boss, L50, TTK ~30s
*"The empire built a gate. The Root grew through it. Now the gate guards the Root's side."*
Stationary siege tank, phys + magic. First verticality exam.

- **Immovable:** speed 0, fills the gate arch. The arena is a siege yard
  with 3 elevated platforms (rising-water platforms, reused dry).
- **Root-Anchors ×3:** destructible (each ~8% of boss pool). Each destroyed:
  boss loses 25% damage AND one denial pattern from its rotation. All 3 down
  = **Exposed** (+30% damage taken, 10s) then the final burn.
- **Root Slam:** arena-wide ground shockwave on a 14s beat — DODGED BY
  ELEVATION (stand a platform). Telegraph 2.5s. The platforms are the answer
  the water cycle already taught.
- **Vine Reach (floor):** tracking root-lash at any range, aimed-class; fires
  faster at whichever target is on a platform (elevation is safe from Slam,
  taxed by Reach — no free perch).
- **Area denial:** lobbed thorn volleys onto marked patches (density scales
  down as anchors die).
- Co-op: anchors gain HP on the party dial; Slam beat is shared — the party
  platform-shuffle is the spectacle.

### The Pale Nursery — Kaethra's Echo — chapter finale, L51, TTK ~40s
*"If you spared her, she kneels here still. If you killed her, the Root found another shape — and this one doesn't talk back."*
Conditional two-form caster, magic. The `chose_`-flag divergence flagship.

- **Kaethra spared (`kaethra_spared`):** she IS the boss — the ch6 Huntress/
  Bloom two-form at L51 weight. Every 30s: **Lucidity** — 5s, she stops,
  speaks, takes +50% damage (the mercy window is also the DPS window — the
  fight rewards not wasting her clarity). Mid-fight resonance choice at 40%:
  end her now (fight ends early; resonance shift; the Root keeps the relay)
  or cut the root-tether (fight continues harder — tether-cut spawns
  root-adds — but she survives powerless; Wildfang standing shift).
- **Kaethra killed:** the Nursery is a root-construct. No dialogue, pure
  mechanics, +10% pool: bloom-form volleys (spiral + fan), dreamer-adds
  (Halla lineage) that pave slow-patches, poison-cloud drift.
- **Both forms:** **Spore Burst** (Halla sleep pulse on a beat — move to
  shed Drowse), **Root Eruption** (line telegraphs leaving permanent
  root-walls; the arena shrinks over the fight — soft enrage), Venom volleys
  (floor, aimed-class).
- Co-op: Lucidity is one shared window; the resonance choice goes to the
  host's prompt with the party watching (party-choice precedent from
  dialogue gating).

---

## 5. Chapter 10 — The Singing Ice (ice + crystal blend, L51–56)

**WoW ref:** Icecrown approach + Illidari Council. Decisions stolen: *the
council kill-order problem* and *positioning as a buff you rent.*

### Terrain engine spec
- **Resonance Crystals** — authored crystal props: within ~140px, +15% spell
  damage dealt AND +15% magic damage taken (both sides of the trade visible
  as an aura ring). Enemies benefit too — a caster mob parked on a crystal
  is a priority problem the room hands you.
- **New hazard `deep_freeze`:** darker-blue patches; standing on one 1.0s
  arms it (crackle telegraph), then 3s frozen-solid stun unless you step
  off. Distinct from ice (which stays the +35% speed lane). Never applies to
  bosses; mobs CAN freeze (bait-able — the counterplay gift).
- Ice-shelf rooms reuse the platform prop as tiered shelves (verticality
  continuity from ch9).

### Mob roster
| Kind | R/M | Type | Traits | Note |
|---|---|---|---|---|
| Chorister of Frost | ranged | magic | **resonance_pulse** (NEW) | periodic pulse: heals allies + damages player; amplified near crystals |
| Glasshide Stalker | melee | phys | **crystallize** (NEW) | corpse becomes a 10s crystal obstacle (blocks movement + projectiles) |
| Rime Wolf | melee | phys | pounce, frost_aura | pack + chill |
| Sleepwalker | melee | magic | snare, mend | Long Sleep cultist; drops snare rings |
| Shardcaller | ranged | magic | skirmish | crystal-bolt artillery |

**New engine verbs:** `resonance_pulse` (radial heal/damage tick + a
crystal-proximity amp check), `crystallize` (death → obstacle StaticBody with
a TTL; kill-order and doorway discipline — don't crystallize the choke).

### The Choir of Frost — mid boss (council ×3), L53, TTK ~30s combined
*"Three Long Sleep acolytes who sang the Queen's lullaby so long they became part of it. They harmonize."*
Council fight framework debut. Three casters, one shared arena.

- **Harmony (signature):** while all three live, every cast CHAINS — each
  sister's spell triggers a half-strength copy from the other two (three
  origins, one pattern language). Kill one: chains stop, survivors go
  **Discordant** (+25% cast speed each). Kill two: the last is fastest and
  angriest. The kill-order problem: each sister has a different kit —
  **Vespers** (aimed ice lances — the floor), **Matins** (Lullaby channel:
  Halla sleep pulse every 12s, rotating singer), **Compline** (Flash Freeze:
  arena ices except thawed vents, and each LIVING sister projects a frozen
  zone at her feet). Which threat you can live with longest is a build
  question — there is no canonical order, and the codex says so.
- Shared pool split 3 ways; sisters resurrect nothing (council, not
  hydra).
- Co-op: the classic split — one player per sister collapses Harmony's
  value; chains still fire on a shared cadence so spread positioning is the
  counterplay, not just assignment.
- **Engine:** council framework = N enemies sharing a boss bar + a
  chain-cast relay + per-member death escalations. Built once here; Act 3
  raids and a Vigil boss reuse it.

### Glacius, the Unmelting — mid boss, L55, TTK ~30s
*"It was a cave. Then the Queen dreamed of a guard, and the cave stood up."*
Armored golem, phys. Cinderhide's plate INVERTED.

- **Crystal Armor (signature):** ~70% damage reduction while within any
  crystal cluster's regen radius. 4 clusters in the arena; each takes ~8s of
  focused DPS to destroy, permanently removing that regen zone. The resource
  question: destroy all 4 (slow, then fight him naked anywhere) or destroy 2
  and kite him into the dead half (faster, tighter space discipline).
- **Avalanche:** telegraphed charge (instant contact per grammar) that
  leaves a `deep_freeze` trail. On crystal-free ground: no trail — the
  reward for cluster work compounds.
- **Shatter Stomp:** on each plate-break (leaving a regen zone's radius with
  armor up), radial crystal burst + **10s vulnerability** (+25% damage
  taken) — the burn windows the fight is built around.
- **Shardfall (floor — the audit fix):** when no player is within melee
  band for >4s, lobbed crystal shards rain at the kiter's position
  (aimed-class telegraph rain). Kiting is legal, never free.
- Co-op: cluster HP on the party dial; Avalanche targets the farthest
  player (anti-stack).

### Elara, Vessel of the Still Queen — chapter finale, L56, TTK ~40s
*"She is fifteen. She walked into the ice because everything warm had been taken from her."*
Three-phase tragedy, magic. The act's emotional centerpiece.

- **P1 The Dream (100–65%):** Elara sleeps in a crystal cocoon (the boss
  bar). Nightmare projections — shadow-copies of Act 1 bosses (Fangmaw,
  Morwen, Serane at reduced kits, one at a time, ~25% pool each as gates) —
  manifest while resonance crystals channel healing INTO the cocoon
  (~1%/s per intact crystal). Destroy crystals to slow the heal; each
  destroyed crystal spawns a permanent `deep_freeze` zone — the arena you
  are building P3 in. Spend the floor now or fight the heal all night.
- **P2 The Waking (65–25%):** the cocoon cracks. Elara half-wakes and casts
  Serane's kit BADLY — wider, slower telegraphs (deliberately generous: the
  player recognizes mastery by its absence). A Long Sleep cultist runs in
  singing her back down: **protect him** (fight stays P2-gentle 15s longer;
  resonance toward Constancy) or **kill him** (skip to P3 sooner; Hunger).
- **P3 The Queen Attends (25–0%):** full god-king filter. Arena crystallizes
  from the edges inward (Serane P2 callback, faster); **Flash Freeze with
  one DECOY safe zone** (Vess Keening callback — the flickering one is the
  lie); aimed ice lances at 460 px/s (floor). The deep_freeze zones you made
  in P1 are still here.
- **On death:** Elara wakes permanently; the ice does not stop. True Name
  payoff: if the Queen's name was learned (ch10 quest), a speak-prompt
  pauses the ice — the seal holds longer (Act 3 state flag).
- Co-op: projections retarget per aggro; the cultist choice is a host
  prompt; decoy safe zones are per-arena (shared read).

---

## 6. Chapter 11 — The Ember Crusade (holy + storm blend, L56–60)

**WoW ref:** Battle for Light's Hope / Wrathgate. Decision stolen: *your
side's champions are somebody else's boss fight.*

### Terrain engine spec
- No new hazard patch. The chapter's terrain identity is the **battlefield
  overlay**: authored NPC skirmish lines (Accord vs Cinderborn soldiers
  fighting each other as ambient scenery-with-HP at room edges — pure
  theater, no XP/gold, the promises-kept staging rules), banner props, and
  the holy terrain's `heal` patches contested — several rooms put the only
  heal patch inside the enemy line.
- 4 faction-divergent rooms (the act's highest ratio) — same coords, the
  room's cast and quest overlay swap on `faction_chosen`.

### Mob roster
| Kind | R/M | Type | Traits | Note |
|---|---|---|---|---|
| Bannerman | melee | phys | **banner** (NEW) | plants a standard: +25% dmg + CC-immunity to allies in radius; the banner is destructible |
| Crusade Zealot | melee | phys | **zealot** (NEW) | charges the LOWEST-HP player, ignoring aggro; wall impact = self-stun (Whitepelt lineage) |
| Field Chirurgeon | ranged | magic | channel_heal, mend | both armies brought medics |
| Storm Adept | ranged | magic | skirmish | the sky is already broken here |
| Oathbound Knight | melee | phys | counter, warded | the other faction's line trooper (skin swaps by allegiance) |

**New engine verbs:** `banner` (a placed prop-buff with an aura + HP),
`zealot` (target-selection override + wall-collision self-stun). Zealot is
the co-op-facing mob of the act: it hunts the squishiest head.

### Commander Drayce / High Artificer Maeven — faction champion, L58, TTK ~30s
*"You fight the other side's best. Both of you are right."*
Faction-dependent kit — you fight the champion of the side you did NOT join.

- **Drayce (Cinderborn players fight him):** warrior-kit boss — Grit-style
  ramping DR while attacked (his bar visibly hardens under sustained fire;
  swap-off windows reset it — the anti-tunnel lesson), shockwave rings,
  tracking charge (floor). An Accord field squad (2 chirurgeons + 2 knights)
  supports him: kill the healers or out-DPS the mend.
- **Maeven (Accord players fight her):** mage-kit boss — fire/ice
  alternation (fire = aimed bursts, ice = deep_freeze zones), Blink (lands
  outside contact reach), Frost Nova on melee crowding. Two Cinderborn
  construct-adds with `reflect` windows (the ch4 lesson, elite-grade).
- **Both at 30% — Parley:** they lower their guard and offer terms.
  **Accept** (fight ends; they retreat; +standing with THEIR faction,
  −standing with yours — mercy toward the enemy reads as softness to your
  own) or **refuse** (the kill; the inverse swing). First boss where the
  moral fork is also a rewards fork.
- Co-op note: allegiance can differ across a party. Rule: the HOST's
  allegiance picks the champion; guests with the opposite flag get the
  spectator-side dialogue variants. Flag this in the co-op sync notes.

### The Shattered Vow — mid boss, L59, survival ~90s
*"A piece of the Storm Tongue's seal. It speaks in incomplete sentences. Each sentence is a lightning bolt."*
Environmental survival — the Act 1 vocabulary exam. Unkillable seal fragment.

- **The Recitation:** an NPC ritualist channels the rebinding for 90s. The
  fragment cycles Act 1's terrain-event vocabulary at hostile density:
  lightning volleys → magma rain → shard bursts → grave-spawn wave → void
  slow-field, 15s per stanza (order seeded per attempt). Every event uses
  its existing engine implementation at an elevated interval — this fight is
  literally `run_terrain_event` on a metronome.
- **Whisper-adds:** Echo-lineage wisps spawn at the arena edge and walk at
  the ritualist (not you). Body-block or kill them — they ignore taunts and
  you (zealot targeting inverted).
- **Failure is persistent:** if the ritualist dies, the fragment detonates,
  the fight ends, the run continues — but the chapter's remaining spawns
  gain +1 affix-grade menace (`vow_failed` flag; the first persistent
  failure state). Retry never offered this run. The victory card names it.
- Co-op: add pressure rides the party dial; the ritualist's HP does not
  (protect duty scales naturally).

### Aldric, the Burned-Out Ember — chapter finale, L60, TTK ~60s duel
*"He burned his Ember killing Vargoth. No power, no fire — just forty years of knowing exactly how you fight."*
Scripted duel, phys. The anti-boss. **WoW ref:** none — this one is ours.

- **The Ledger (signature):** he tracks your ability usage this fight.
  An ability he has NOT yet seen: he eats it fully and **staggers** (2s,
  +30% damage taken). An ability he's seen 3+ times: he **parries** it (50%
  reflect, brief riposte). Between those: normal. The kit rewards breadth —
  every class has enough verbs to stagger him 4–6 times if they play their
  whole hand, and a one-button rotation gets parried into the dirt.
- **The Dueling Ring (audit fix, part 1):** the arena is a tight cordon
  (~60% standard size) — corners are close and he cuts them efficiently.
- **The Thrown Parry-Dagger (audit fix, part 2 — floor):** at range >300px
  he throws a mundane dagger (aimed-class, 440) that applies a 1.5s hobble
  on hit — kiting is possible but it hands him board control, and he walks
  you down at a fencer's pace.
- **Fatigue:** his move/attack speed decays ~15% across the fight (no
  enrage; the duel gets more winnable, never less). No phases. No adds. No
  telegraphs beyond his shoulders — the tell IS the animation (give him the
  full 8-dir treatment; this fight is an animation showcase).
- **At 10% — he yields.** Teaches the Storm Tongue's *partial* true name.
  "I never finished the sentence. That's why it woke."
- Co-op: the Ledger tracks per-player; his target swaps on parry (the duel
  becomes a round-robin of whoever got predictable). Pool rides the party
  dial modestly — this fight should stay a duel, not a mugging.

---

## 7. Chapter 12 — The Roothold (spore + bog + forest triple blend, L60–64)

**WoW ref:** Emerald Nightmare / Val'sharah. Decision stolen: *the arena is
alive and its floor plan is a rotation you learn.* Generic S begins dropping.
Blight (healing reduction) debuts here and is load-bearing for two bosses.

### Terrain engine spec
- **Living Growth:** cleared combat rooms regrow a root-wall across ONE exit
  after ~90s (telegraphed by creeping vines 10s ahead; one melee hit cuts a
  regrown wall). Backtracking costs a swing, never a fight — pure pressure
  texture, no reward attached (it must not gate the premium path).
- **New hazard `entangle`:** standing within a patch >2.0s arms root-grab
  (0.8s telegraph crackle → 2s root). Halla's stillness-detection put on the
  floor. Movement discipline as terrain.
- **Blight Bomb pickups:** arena props in boss rooms (2–3 per fight, respawn
  ~20s): thrown consumable applying Blight (−50% healing, 8s) — the
  no-class-source fallback so every build can answer healing bosses.

### Mob roster
| Kind | R/M | Type | Traits | Note |
|---|---|---|---|---|
| Rootspawn | melee | phys | **parasite** (NEW) | death → 2 half-stat copies (which don't split again) |
| Anchor Vine | ranged | magic | **root_anchor** (NEW) | immobile; extends entangle patches across the floor while alive |
| Thorn Howler | melee | phys | martyr, sower | death-wail + burning trail |
| Grove Tender | ranged | magic | regen, channel_heal | the Blight tutorial mob — un-killable-feeling until Blighted |
| Pollen Drifter | ranged | magic | bloat | drifts with the spore clouds |

**New engine verbs:** `parasite` (on-death split spawn), `root_anchor`
(stationary + a patch-painting tick). Both cheap; both reused by the Vigils.

### The Rootweaver — mid boss, L62, TTK ~30s
*"A Wildfang druid who communed with the Root and didn't flinch."*
Summoner/puzzle caster, magic.

- **Living Arena (signature):** root-walls grow/retreat on a 20s cycle
  through 3 authored layouts (corridors → spiral → open). Walls block
  movement and projectiles both ways; the boss phases through them. The
  cycle is announced (ground shimmer 3s ahead) — track it and you're never
  caught in a dead end.
- **Thorn Barrage (floor):** rapid aimed volleys fired through wall gaps —
  the current layout defines the firing lanes; reading the layout IS the
  dodge.
- **Bloom Trap:** seeds the player's position; 4s later a healing bloom
  sprouts FOR THE BOSS (~4%/bloom). Kill the seed, kite the bloom radius, or
  Blight her during bloom uptake.
- **25%:** walls turn toxic (proximity aura) and the cycle rate doubles.
- Co-op: seeds target all players (bloom garden risk scales — spread).

### Thornfather Grael — mid boss, L63, TTK ~30s benched at 60% Blight uptime
*"Cure-seekers asked the Root to undo their beast-blood. It replaced it with something that grows instead of howling."*
Tank/healer hybrid, phys. The Blight final exam.

- **Regrowth (signature):** passive 3% max-HP/s regen, always on. Un-Blighted
  he out-heals mid gear; Blighted (−50%) he dies on budget. The bench pins:
  0% uptime beatable at +50% TTK on A-gear; 60% uptime hits the 30s target.
- **Thorn Shield:** 30% reflect while up; he DROPS it to channel a Regrowth
  surge (8s, +3%/s more) — the window where he is shieldless AND healing
  hardest. Blight + burst there is the whole fight.
- **Root Lash:** melee sweeps painting `entangle` behind them.
- **Thorn Flail (floor — the audit fix):** beyond melee band, a swung chain
  of thorns arcs at the kiter (aimed-class), applying 1 stack of hobble.
  Kite him and he still reaches you — and every second kiting is a second of
  free Regrowth. The kit punishes disengaging twice, by design.
- Co-op: reflect uptime rides the party dial DOWN (more players = more shield
  drops = more windows); regen never scales up (no-healer covenant — the
  party brings more Blight sources, the check stays flat).

### The Heart of the Root — chapter finale, L64, TTK ~45s (multi-target)
*"There is no vessel. The land IS the vessel. You're standing inside the god-king."*
Environmental multi-target, magic. **WoW ref:** the many-bars fight
(Assembly/Kel'Thuzad's phylactery logic) at Crownless scale.

- **Five Root-Hearts** embedded in walls/floor, each its own bar (each ~20%
  of budget) and defense: **the Warder** (spawns rootspawn parasites), **the
  Archer** (thorn volleys — the floor while it lives), **the Gardener**
  (grows poison clouds), **the Mender** (heals the others ~2%/s — the Blight
  target), **the Jailer** (periodic entangle cast at your feet). Priority
  order is the puzzle; there are two defensible orders (Mender-first slow
  and Archer-first safe) and the codex hints at neither.
- **Pulse:** every 30s, all SURVIVING hearts pulse arena-wide damage
  (n_hearts × per-heart tick — five-heart pulses hurt, two-heart pulses are
  a tax). The soft timer that punishes even splitting.
- **The Garden:** between pulses, poison and entangle patches fill
  unoccupied floor (decaying oldest-first — the arena breathes; standing
  still is the only losing position).
- **True Name payoff:** the Pale Root's name (ch12 quest) puts one chosen
  heart dormant 20s — effectively a free sequencing joker, once.
- Co-op: hearts gain the party dial; Pulse does not (it counts hearts, not
  heads) — splitting five ways is finally correct here, and the fight is
  the act's co-op showcase.

---

## 8. Chapter 13 — The Storm Scar (storm + void + desert triple blend, L64–68)

**WoW ref:** Throne of Thunder + N'Zoth breaches. Decision stolen: *the
mechanic teaches you the lore — dodging IS reading.*

### Terrain engine spec
- **Void Tears:** ground rifts (authored + event-spawned): stepping in
  teleports you to another tear in the same room (paired doors, not random —
  random teleports in combat are deaths nobody authored; the pairing is
  learnable). 1s disorient shimmer on exit, no damage. Enemies never use
  them (the asymmetry is the player's toy).
- **New hazard/event `storm_word`:** a telegraphed line strike that renders
  a glowing WORD along its length (0.8s). Hit = 3s **silence** (abilities
  locked, basic attack free). Never applies to bosses. The words are
  Concord-recitation fragments — the True Name quest collects them by
  witnessing (dodge it and you still read it; the quest counter ticks on
  SEEING a word, not eating it).
- Desert rooms bring `gust` back at elevated interval; storm rooms run
  `lightning` at ch7 density. The triple blend rotates by room.

### Mob roster
| Kind | R/M | Type | Traits | Note |
|---|---|---|---|---|
| Word-Wisp | ranged | magic | **storm_word** (NEW), swift | channels a word-line; vulnerable during channel; interrupt = DPS window |
| Riftling | melee | phys | **phase_shift** (NEW) | 1.5s targetable / 1.0s untargetable flicker; DoTs tick through |
| Sand Revenant | melee | phys | burrow, warded | ch9's verb in a new coat |
| Conductor Acolyte | ranged | magic | skirmish, sentry | plants a rod-turret |
| Void Hound | melee | phys | blinker, frenzy | ch7 alumni, meaner |

**New engine verbs:** `phase_shift` (targetability flicker + DoT
passthrough), `storm_word` (line telegraph + silence debuff + the
witness-counter hook). Silence needs one new player debuff channel
(ability lockout with a visible chip — NO SILENT EFFECTS applies doubly to
a silence).

### The Unfinished Sentence — mid boss, L65, TTK ~30s
*"Cyrraeth died mid-sentence. The sentence didn't."*
Storm elemental caster, magic. Veyx matured.

- **Six conductor rods**, arcs CHAIN rod-to-rod (Veyx's redirect at scale):
  each Arc redirects to the nearest rod, then chains to the next-nearest
  (2 hops). Three redirects overload a rod — it detonates and leaves a
  **permanent void tear** (paired with the arena-edge tear). The arena's
  teleport network is built out of your rod management, fight-long.
- **The Word (floor):** storm_word lines on cadence, aimed at players.
  Each is a recitation fragment — the True Name quest counts them
  witnessed.
- **Squall:** radial bolt ring (300, opt-in) on rod overloads.
- **20%:** all remaining rods shatter at once (their tears open); pure
  storm — aimed forks at 460 with no redirect cover. Save rods or spend
  them; entering the last fifth with 3 rods is a different fight than with
  zero.
- Co-op: arcs target per-player; rod overload counters are shared.

### Korrag Reborn — mid boss, L67, TTK ~30s
*"The storm that broke him in Ch2 was the seal straining. The seal is open now. The storm put him back together — with extras."*
Storm warrior, phys + magic. The act's callback fight.

- **Base layer:** his ch2 kit (Lightning Lash sequential lines, Whip Snap,
  wolf calls) at L67 weight and double tempo — the nostalgia is the tell:
  you know this half already.
- **The Storm Tongue's Gift (signature):** every 20s he SPEAKS (2.0s
  channel, interrupt-immune, big tell). The word reshapes the arena — one
  of: a void tear pair opens · a sand dune rises (LOS blocker + high
  ground) · two lightning rods materialize (his lashes now chain off them).
  Seeded order per attempt; the fight never plays the same twice, but every
  word's consequence is a system you already know.
- **Storm Wolves:** lightning-aura'd pack (2 at 66%, 2 at 33%). Two wolf
  corpses within ~120px chain lightning between them for 6s (corpse-bloom
  logic) — kill them apart, the Sexton's lesson with teeth.
- **15% — he falls to his knees; the Storm Tongue speaks through him.**
  LISTEN for 10s (no combat; the true-name fragment count jumps) or ATTACK
  (the last 15% fights back, faster). Resonance-shaded, and the True Name
  quest cares which you chose.
- Floor: lashes chain to rods at any range; wolves chase.

### The Mouth of the Storm — chapter finale, L68, TTK ~45s
*"There is no vessel. The crack in the seal IS the boss. You are fighting a hole in the world."*
Environmental raid boss, magic. **WoW ref:** anchor-defense (Wrathion gate /
Stormwall logic) compressed to one room.

- **The Scar (boss bar):** the exposed seal-edge, damageable only while at
  least 2 of 3 **Stormwarden relic anchors** stand. Anchors have HP; the
  Scar attacks THEM with tear-tendrils between cycles. A broken anchor:
  +1 hazard family joins every cycle permanently. All 3 broken = the breach
  wins (wipe — retry at the door).
- **Storm Cycle (15s stanzas):** LIGHTNING (Veyx-density strikes + aimed
  forks — the floor) → VOID (slow-field creep + tear pairs go volatile:
  entering one now costs a hit) → SAND (gust shoves + visibility haze,
  ranged telegraphs shortened). Each stanza favors a different position;
  the rotation is announced by the sky.
- **Speakers:** two Stormwarden NPCs chant at anchors (healing them ~2%/s).
  Word-adds (Word-Wisp elites) spawn walking at the speakers to silence
  them. Intercept — a silenced speaker means net anchor decay.
- **On victory:** the breach NARROWS, doesn't close. The full true name
  assembles from words witnessed across the chapter; speaking it is the
  ch13 epilogue beat.
- Co-op: tendril count and word-add cadence ride the party dial; anchor HP
  does not. Assignment (who holds which anchor lane) is the fight.

---

## 9. Chapter 14 — The Hollow Crown (all terrains blend, L68–70, ACT 2 FINALE)

**WoW ref:** Icecrown Citadel + Broken Shore. Decision stolen: *the final
approach re-examines the whole game, then the last fight breaks its own
rules.*

### Terrain engine spec
- **Waking Flux:** mid-combat terrain shift — every ~45s a room re-themes
  live (magma→ice→bog→storm sets, seeded): ground/wall art swaps, hazard
  patches TRANSFORM in place (lava→deep_freeze→poison→slow at the same
  coordinates), the ambient event follows. Engine: the Depths re-theme
  plumbing (`_maybe_retheme`) promoted to run DURING combat with a 3s
  sky-flash telegraph. Patch positions persisting across the swap is the
  learnable half; the type roulette is the pressure.

### Mob roster — the compound exam
Ch14 mobs are **Waking**: each spawns with TWO mechanics drawn from the full
Act 1+2 verb pool (seeded pairs, exclusion table keeps degenerate stacks
out — no spawner+parasite, no banner+banner). Named skins over the compound:
| Kind | Base | Note |
|---|---|---|
| Choir Radical | channel_heal + martyr | the radical wing militant |
| Hollow Knight | counter + empowered | throne-guard dead |
| Waking Shard | crystallize + phase_shift | reality splinter |
| Flux Hound | pounce + storm_word | it barks sentences |
| The Converted | zealot + bloat | they run at the weakest and burst |

### The Choir Ascendant — mid boss, L69, TTK ~30s
*"The Choir's radical wing has a leader now. She has seen the Hollow Flame walking and decided this is what holiness looks like."*
Ranged support + adds, magic. The Choir Mother kit fully realized.

- **Requiem rings** (expanding blight rings — move inward, the ch2 lesson at
  finale tempo), **verse volleys** (aimed 460 — the floor), **Hymn of
  Hunger** (marked ground heals her per hit taken while you stand it).
- **The Singers:** 2 Choir adds channel healing hymns toward her —
  INVULNERABLE while singing; a singer's circle is broken by STANDING IN IT
  (body-block the hymn, 2s). Solo: you can only hold one circle — kill
  priority alternates; the fight is a positional juggle. Co-op: one player
  per singer trivializes the hymn and the boss's other dials ride the party
  scale to compensate — the intended co-op contrast.
- **50%:** she reveals Mórwyn's position (story beat); remaining chapter
  rooms shift permanently to blight-flux.

### The Burned King's Echo — mid boss, L70, TTK ~30s
*"The Hollow Throne remembers the man who sat on it."*
Shadow duelist, phys + magic. The curriculum exam.

- **Vargoth's ch1 kit** (Blade Storm tracking greatswords, slam ring,
  enrage) at L70 weight and double tempo — the first boss you ever beat,
  returned as the bar to clear.
- **The Sampling:** every 15s he borrows one god-king verb, seeded rotation:
  a half-arena verdict (Judge) · a flash-freeze with thawed vents (Queen) ·
  a root-wall line (Root) · a storm_word volley (Tongue). One verb at a
  time, full telegraph grammar — Act 2's whole vocabulary, re-examined in
  one fight.
- **50% — the Mirror:** manifests a shadow-copy of the PLAYER (Echo
  lineage, Aldric's ledger reversed): it casts YOUR three most-used
  abilities this run (tracked the way Aldric tracks) at reduced weight.
  Killing it drops a void zone (don't cleave it into the boss).
- Floor: Blade Storm tracks at any range; sampled verdicts are arena-scale.

### Mórwyn, the Hollow Flame — ACT 2 FINALE, L70, TTK ~50s across four phases
*"She was a battle-healer who believed in perfection. Six hundred years of imprisonment refined her argument."*
Four-phase god-king, magic. The act's thesis fight: **she heals; the Blight
you learned is the language she invented.**

- **P1 The Healer (100–75%):** she doesn't attack YOU at all at first — she
  heals the ARENA: blight patches bloom into healing zones for her Choir
  minions (streaming in), her bolts are Morwen's ch1 fans (nostalgia,
  gentle). Kill adds, or destroy the healing zones (targetable, Varo censer
  logic), or Blight the zones (they wither — the system speaks her
  language). Deliberately soft — showing what she was.
- **P2 The Perfectionist (75–40%):** zones invert to blight; adds rise as
  blight-zombies (grave_spawn logic); her bolt fans gain DoT trails (the
  DoT tax is in the budget); triple-blink sequences, each blink leaving a
  blight pool at the departure point (blinks land outside contact reach).
  Class-targeted dialogue lands here ("You know exactly what I mean,
  spellwright.").
- **P3 The Hollow Flame (40–10%):** she stops talking, stops blinking, and
  WALKS at you — an expanding death aura (ticking ~5% max-HP/s inside; the
  radius grows through the phase) while the arena itself decays behind her
  (scenery crumbles into permanent blight floor — the room is a shrinking
  candle). No other abilities. She IS the mechanic: sustain math + a
  shrinking track + your whole movement kit. Kite and burn before the arena
  runs out. (Floor: the aura reaches everyone by construction.)
- **P4 The Remnant (10–0%):** she falls; the blacksmith's face shows
  through; "I remember the forge." No attacks — the last 10% is walked in
  and the CHOICE lands: **End her** (blight lingers; power scatters) or
  **Seal her** — requires the Accord rebinding rite or the Cinderborn
  binding text (faction-gated), and a vessel; the strongest candidate in
  the room is you. Kept flags either way; Act 3's inciting state.
- Co-op: add streams and blink counts ride the party dial; the P3 aura
  radius does NOT (it's a geometry exam, not a stat check). P4's choice is
  the host's, witnessed.

---

## 10. New engine primitives — build once, reuse (consolidated)

| Primitive | Debuts | Also used by |
|---|---|---|
| `empowered`, `sentry` mob verbs | ch8 | Vigils (Smolder Court), Depths |
| Room machinery prop (player-fired hazard) | ch8 | Vigil arenas, side chapters |
| `molten_metal`, `deep_freeze`, `entangle`, `spore_cloud`, `storm_word` hazards | ch8–13 | Vigils, Depths re-themes |
| Rising-water room cycle + platforms | ch9 | ch10 shelves, Gatewarden, Vigils |
| `burrow`, `mimic` mob verbs | ch9 | Depths, cursed-chest variant |
| Drowse-on-terrain | ch9 | ch12 Nursery, White Vigil |
| `resonance_pulse`, `crystallize` verbs | ch10 | White Vigil |
| Council fight framework | ch10 | Vigil finales, Act 3 raids |
| `banner`, `zealot` verbs | ch11 | Vigils, Torment elite packs |
| Persistent failure state (`vow_failed`) | ch11 | side chapters |
| Player-ability ledger (track + react) | ch11 Aldric | ch14 Mirror |
| Blight debuff + per-class sources + Bomb pickup | ch12 | every healing boss ch12+ |
| `parasite`, `root_anchor` verbs | ch12 | Green Dark Vigil |
| Multi-heart boss (N bars, one fight) | ch12 finale | Act 3 |
| `phase_shift` verb + silence debuff channel | ch13 | Speaking Spire Vigil |
| Void-tear paired teleporters | ch13 | Depths flavor rooms |
| Anchor-defense fight frame | ch13 finale | Act 3 sieges |
| Mid-combat re-theme (Waking Flux) | ch14 | Depths waking bosses |
| Compound-trait mob spawner | ch14 | Torment, deep Depths |

---

## 11. Difficulty levers beyond the chapters

**Act 2 affix additions** (endgame/incursion pool; campaign stays affix-free
per the standing rule):
- **Plaguebearer** — on death, a 15s blight zone at the corpse. The room gets
  dangerous after you win.
- **Warded (elite-grade)** — the ward regenerates 10s after shattering.
- **Commanding** — +15% damage to all trash while it lives. Kill-priority.
- **Volatile** — 3s-telegraph death explosion. Punishes melee execute range.
- **Splitting** — the never-shipped Act 1 name, now the `parasite` verb as an
  affix (dies into two halves). Ships with the verb.
- Exclusions: Commanding never co-rolls with Savage (damage-scalar cap
  precedent); Volatile never with Plaguebearer (double death-punish).

**Torment-exclusive levers** (tier 2 only, per the bible §VII):
- Elite ambush chance ×1.5 (`ELITE_COMBAT_AMBUSH_CHANCE` tier scalar).
- Bullet-hell density: boss aimed-volley bolt counts +1 at Torment (the
  cap-speed grammar is untouched — MORE bolts, never faster than 480).
- Compound mobs (the ch14 two-trait spawner) appear from ch8 onward at
  Torment.

**Not proposed:** damage-taken auras, healing debuffs by tier, or hidden
multipliers of any kind — tiers stay "levels only, no hidden multipliers,"
and sustain is never taxed (the Depths precedent).

---

## 12. Open questions for the owner

1. **Aldric's Ledger scope** — track ability IDs only (cheap), or also
   dodge-direction patterns (expensive, spookier)? Proposal: IDs only at v1.
2. **Faction champion in mixed co-op** — host's allegiance picks the
   champion (proposed) vs. always-Drayce for simplicity. Needs a ruling
   before ch11 net work.
3. **The Parley / Lucidity / Listen choices in co-op** — host-prompt with
   party spectating (proposed, matches dialogue gating) or majority vote?
4. **Mórwyn P3 aura at Torment** — the geometry exam gets +40 levels of
   damage but the same radius curve. Playtest flag: does Torment P3 need its
   own radius curve, or is level pressure enough?
5. **Waking Flux frequency** (~45s proposed) — half the Depths' 3-room
   cadence, live. Too churny? Bench with motion sickness in mind (full-room
   art swaps mid-fight).

## 13. Implementation map

- `balance.gd` — every magnitude above lands as a knob; new blocks: ACT2
  hazards, Blight, silence, per-boss sections (the ch3–ch7 boss-block
  pattern).
- `enemy.gd` — 13 new trait verbs (§10); trait table entries in the
  per-chapter mob blocks.
- `boss.gd` — per-boss `match kind` blocks, ch8–ch14 sections; council /
  multi-heart / anchor-defense frames as shared funcs.
- `terrains.gd` — new patch types + `ashfall`/`drowned`/`singing_ice`/
  `crusade`/`roothold`/`stormscar`/`hollowcrown` terrain profiles (blend
  profiles reference existing families; the ph_* gallery already previews
  several looks).
- `game_flow.gd` — rising-water cycle, Waking Flux, storm_word event,
  vow_failed escalation.
- `game/scripts/content/ch8_*.gd` … `ch14_*.gd` — zones/bosses/quests/beats
  modules per the content README format + `Story.CONTENT_MODULES`
  registration; codex + `BOSS_KINDS` updates in the same change.
- Tests: per-chapter content-module hooks; boss floor assertions (a
  stationary player at 600px must take damage within 10s from every boss —
  the kiter-floor as an autotest).

> The Act 2 combat thesis: Act 1 taught the vocabulary; Act 2 speaks in
> sentences. Every new verb is a decision, every boss is built from verbs
> the player has already read once, and the three fights that broke the
> floor rule now pay their kiter tax.
