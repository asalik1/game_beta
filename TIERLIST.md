# Emberfall — Class & Theme Tier List

First documented edition. Living balance document: **every number here
is MEASURED, not estimated** — both boards are output of the DPS bench
harness (`dps_bench.bat`), and the roster was tuned in round 49 (see
BALANCE_HISTORY.md, rounds 49/49b/49c) until the boards matched the
player-authored target ladders reproduced in §2. Update this file
whenever a kit or tuning number changes: rerun the bench, paste the new
boards, and rewrite whatever prose stopped being true.

---

## 1. The instrument

`dps_bench.bat [--aoe] [--secs=N] [--cls=X] [--theme=Y]` — headless,
compile-gated, `--fixed-fps 60` (the simulation is decoupled from the
wall clock: CPU contention can slow a run but never change a number).
Without `--cls` it fans out to **six parallel Godot processes** (one
class each, isolated save dirs, `dps_bench_fan.ps1`) and ends with one
merged ranking — a full 18-case sweep costs roughly one class's wall
time.

**The frame (both boards):**

- Hero at **level 40**, all attribute points in the class primary.
- **Full A-grade gear**, seeded rolls (identical every run), class
  signature weapon shape.
- **Lv6 gems** (the A-socket cap), uniform loadout — one special + one
  regular per piece: **Combo ×4** specials for archer/assassin/mage/
  warlock, **Haste ×4** for warrior/paladin (Haste's 0.40 knee out-rates
  Combo's 0.30 on the plate kits' basics); regulars are **ATK% ×2 +
  class-matched pen ×2**. CritDmg regulars were tried on the crit
  variants and measured WORSE than Rubies at their real 23–34%
  effective crit — uniform gems also keep variant comparisons honest.
- **Skill trees:** assassin/archer/mage use the player's live builds;
  warrior/paladin/warlock use DPS-optimal picks (per-variant for
  warlock). All presets are consts at the top of
  `scripts/tests/dps_bench.gd`.
- **Mono themes** — every slot on one theme. These boards grade
  baseline identities; meta mixes are §8 and currently unmeasured.
- **180-second windows**; the damage clock starts at first blood.

**Boss board target:** one immortal dummy that is a real `Boss`
subclass — CC immunity, concussion conversion, boss shove factor and a
boss-sized hitbox all behave exactly like a live boss door — carrying
the **average defensive sheet of every registered boss at L40**
(physres ~39, magres ~45, eva ~6%, critres ~14), so no single boss's
matchup skews the ladder.

**Pack board target (`--aoe`):** three of those boss pillars standing
shoulder to shoulder (65px apart), plus **five 1200-HP adds every 10
seconds** that are supposed to die — kill-triggered effects (hex
detonations, Starfall cascades, Phantom dash refunds) all fire for
real. DPS pools **effective damage** across every target: overkill on a
dying add never inflates a number. The `adds x/95` column is the
clear-speed signal.

**Rotations are playstyle-constrained**, per class (player-specified):

| Class | Boss rotation | Pack rotation (differences only) |
|---|---|---|
| Warrior | stand still; Cleave + Whirlwind + Berserk (no Shield Bash) | same |
| Archer | Quick Shot + Multishot + Arrow Storm (no Tumble) | same |
| Mage | Firebolt + Meteor; Frost Nova ONLY as an emergency refill under 55 MP | Nova on cooldown — it's real AoE in a crowd |
| Assassin | dash through the boss right before the blood surge lapses; surged Fan of Knives filler; Death Mark on cooldown, then a 5s Stab window | same |
| Paladin | one Conviction swap into RETRIBUTION, never back; Judgment + Consecration (no Aegis vs a passive target) | same |
| Warlock | Shadowbolt + Hex upkeep + Void Rift (no Dark Pact at boss range) | Dark Pact back in — in a pack you ARE point-blank |

**Measurement law: run-to-run variance is ~±5%** (physics iteration
order perturbs crit/echo rolls even under fixed seeds; ult-count
quantization at window edges adds more for the 40–50s-cd kits). Any gap
under 5% is a TIE. Ladder disputes get settled over 2–3 runs, never one.

---

## 2. The two boards and their design-intent ladders

Both ladders are player-authored targets; round 49 tuned until they
held. **They are the contract** — if a future change breaks an
ordering, that is a regression, not drift.

**Boss (single-target) ladder:**
> Shadow > Hunt > Wind > Curse ~ Fury ≥ Wrath ~ Void > Fire ~ Poison ≥
> Venom > Storm ~ Pact  ·  floor: Bulwark ~ Aegis ~ Holy

**Pack (AoE) ladder:**
> Fire king > Pact 2nd > Shadow ~ Storm 3rd > Fury ~ Wrath 4th tier ·
> Blood < Shadow · Wind < Fire and ≤ Storm · Curse ≤ Wind but ≥ Ice ·
> Void ≤ Storm, near Ice · Venom / Poison / Ice above the floor, below
> Wind  ·  floor: Holy ~ Bulwark ~ Aegis

The boards deliberately INVERT several specs — Hunt is 2nd on bosses
and bottom-third on packs; Fire is boss-mid and pack king; Pact is
boss-floor-adjacent and pack #2. **The inversion is the design**: theme
swaps are free outside combat, so the intended endgame play is
re-theming at boss doors.

---

## 3. The boss board (single target, ~means across 180s runs)

| # | Spec | DPS | Notes |
|---|------|----:|-------|
| 1 | Assassin · Shadow | ~4150 | the ceiling: +20%/+15% cap-exempt crit riders, converging five-knife fan, true-damage execute — priced in melee proximity with no plate and no free i-frames |
| 2 | Archer · Hunt | ~3900 | the couch ceiling: 20%-deeper shots, +25% crit above the knee, near-permanent EXPOSED, all five narrow-volley arrows into one body, zero melee risk |
| 3 | Mage · Wind | ~3650 | twin echoing bolts + Starfall — the mage's duelist theme |
| 3 | Assassin · Blood | ~3650 | **tied with Wind at full HP, and that's its FLOOR**: blood_amp converts missing health into up to +40% damage — a bleeding pilot stretches toward Shadow |
| 5 | Warrior · Fury | ~3380 | wave2 backhand + 55%-echo cyclone + Berserk — which now also restores Cleave's unchained 0.45s cadence: the ult is a tempo steroid |
| 6 | Mage · Ice | ~3300 | widest variance on the board (3020–3600 observed): heavy lances, brittle self-amplification, freeze-rider concussion |
| 7 | Warlock · Curse | ~3170 | deep withering bolts, guaranteed EXPOSED from Hex, wither ramping +8%/6s of curse uptime to +64% — the long-fight spec |
| 8 | Paladin · Wrath | ~3040 | double Judgment hunting the gaps (+20% crit), erupting Consecration; Retribution uptime IS the skill expression |
| 8 | Warlock · Void | ~3040 | crush choreography: hex-shove opens the window, bolts spike into it (+28% crush, +25% Nightfall crit) |
| 10 | Assassin · Poison | ~2870 | the fastest toxin stacker in the game (0.12/stack); pays the deliberate DoT tax against its burst siblings |
| 10 | Warrior · Earth | ~2860 | the control spec paying its CC budget at CC-immune doors; concussion repays part |
| 12 | Mage · Fire | ~2800 | **statistically tied with Poison — an accepted tie.** Splash is wasted solo; the deep burn (0.60 bolt dot, 2.0× meteor burn) carries it |
| 13 | Warlock · Pact | ~2690 | blood-priced bolts; its real identity lives on the pack board |
| 13 | Archer · Venom | ~2690 | heavy stacking DoTs on capped-pierce arrows; the archer's safest solo theme |
| 15 | Archer · Storm | ~2610 | the AoE spec's solo floor: with nobody to fork to, the charge arcs BACK into the same body at 50% (`ric_back`) |
| 16 | Paladin · Holy | ~2090 | −20% stance damage + the Judgment cadence tax: absurd sustain, deliberately low output |
| 17 | Warrior · Bulwark | ~1840 | every button heals and hardens; the cannot-die build pays here |
| 18 | Paladin · Aegis | ~1710 | reflect identity — damage arrives only when the enemy swings, and a bench dummy never swings (see §9) |

**Reading notes:**

- **Melee > ranged at the top is intentional risk compensation**; the
  plate classes sit mid-table because round 49's cadence tax ("plate
  hits HARD, not fast") moved Cleave 0.45→0.74s and Judgment 0.5→0.8s.
- **The mage mana law (measured):** pure Firebolt spam empties the pool
  ~2 minutes in and the cast rate collapses to regen speed; Meteor sat
  unaffordable 48 of 180 seconds. Frost Nova's missing-mana refund (20%
  of missing for 15 MP, no shared lockout with Firebolt — the refill
  costs zero bolt casts) is **load-bearing** on long fights. A pilot who
  refuses it loses ~10–15% past the two-minute mark, most of it on
  Fire.
- **Fire ~ Poison** is the one relation tuning left as a tie: Poison has
  no room down (Venom sits just beneath it) and Fire is mana-capped,
  not damage-capped.

---

## 4. The pack board (AoE — 3 pillars + add waves, final 180s run)

| # | Spec | DPS | adds | Notes |
|---|------|----:|-----:|-------|
| 1 | Mage · Fire | 6256 | 90/95 | the farm king by a clear margin: 45% splash on every bolt, the flame-ring Nova, the widened burning Meteor |
| 2 | Warlock · Pact | 5615 | 88/95 | Dark Pact is the whole story: 18% max HP buys a 3.5×-deep blast around you every ~6s, drunk back through the lifesteal surge — an engine that runs on standing inside the pack |
| 3 | Assassin · Shadow | 5373 | 81/95 | five-knife fans at surge cadence; Phantom dash refunds chain through add kills |
| 3 | Archer · Storm | 5208 | 85/95 | forks leaping body to body, piercing volleys, 45–75% lightning splash on everything |
| 5 | Mage · Wind | 5038 | 90/95 | gust-splash twin bolts; Starfall executes and cascades through dying adds; its gale Nova scatters its own targets — identity kept over optimum |
| 6 | Warlock · Curse | 4836 | 88/95 | whole-pack EXPOSED + wither + death-detonations chaining through corpses |
| 6 | Warlock · Void | 4823 | 86/95 | hex-shove opens pack-wide crush windows; the greedy rift; capped at Storm's line by target |
| 8 | Assassin · Blood | 4775 | 47/95 | echo carries it; the fan's pierce was removed in 49c to hold it under Shadow |
| 9 | Assassin · Poison | 4576 | 90/95 | mist blooms + toxin on everything — a top-tier add clearer |
| 9 | Paladin · Wrath | 4534 | 84/95 | the erupting Consecration drags the pack onto the hammer |
| 11 | Mage · Ice | 4423 | 88/95 | brittle + freeze control; damage mid by design |
| 12 | Warrior · Fury | 4180 | 36/95 | the 1.0× echo cyclone; Cleave's knockback scatters its own dinner — the low add count is self-inflicted juice |
| 13 | Archer · Hunt | 3739 | 14/95 | the boss spec on the wrong board: precision riders do nothing for crowds — **14 of 95 adds** says everything |
| 14 | Warrior · Earth | 3656 | 61/95 | drags the pack into the blade; the control tax again |
| 15 | Archer · Venom | ~3030 | 59/95 | plague-rain DoTs; above the sustain floor, below Wind — exactly the target slot (rides the tie band with Holy; means put it above) |
| 16 | Paladin · Holy | ~2950 | 76/95 | hallowed ground trades fire for mending (0.7× damage) |
| 17 | Paladin · Aegis | 2674 | 72/95 | reflect needs attackers; passive targets starve it |
| 18 | Warrior · Bulwark | 2367 | 28/95 | the anvil, not the hammer |

**Reading notes:**

- **Structural finding — the dash rider cap:** one Shadow Dash through a
  pack used to land the full stab rider on *every* body in the 150px
  corridor; Blood benched **9087** before the fix, ahead of everything.
  `Balance.DASH_RIDER_CAP` (2) now stops the rider after two victims per
  pass. Boss fights (one victim) never notice.
- **Pierce caps:** `pierce_cap` in the projectile fx payload is the new
  mid-tier coverage tool — Venom arrows punch three bodies deep; Blood
  knives and Void bolts lost pierce entirely to hold their slots.
  Unlimited pierce (Storm volleys, Ice lances) is now a deliberate
  grant, not a default.
- **Melee vs. wave geometry:** the bench pins the plate classes in place
  because each add wave physically bulldozes a stationary body out of
  melee reach — the first warrior AoE bench read 83 dps because he'd
  been shoved off and was swinging at air. In real play that's footwork.

---

## 5. Class deep dives

### Warrior — the juggernaut, taxed into deliberateness
Plate identity: 80 physres, 15% flat DR, Grit regen that feeds on being
hit. Round 49's cadence tax made Cleave a 0.74s decision instead of a
0.45s tremolo, and **Berserk hands the old cadence back for its
window** — the ult went from a damage steroid to a tempo one, and its
uptime is now the warrior's dps rhythm.
- **Fury** — the damage identity and the best warrior on both boards:
  wave2 backhand, 55%-echo cyclone at 1.5× radius, deeper/longer
  Berserk.
- **Earth** — control: quake lanes, stuns (concussion at boss doors), a
  whirlwind that drags packs in. Mid on both boards; that self-feeding
  pull is also why the AoE geometry never broke it.
- **Bulwark** — floor on both boards by design; every cast hardens,
  every hit mends. Grade it as a survival kit, not a dps kit.

### Archer — the widest identity split in the game
Its best boss theme is its worst pack theme and vice versa; the class
is built to re-theme at boss doors.
- **Hunt** — boss #2: 1.2× shots, cap-exempt +25% crit, EXPOSED procs,
  the converging five-arrow volley. Kills 14 adds in three minutes on
  the pack board. Correct.
- **Storm** — pack tier-3 (forks, unlimited pierce, splash everywhere)
  with a real solo floor since 49: the lone-prey fork arcs back at 50%.
- **Venom** — the DoT spec: capped-pierce toxin arrows, the deepened
  plague rain. Just under Poison on bosses, just above the sustain
  floor on packs — both per target.

### Mage — the glass engine with a fuel gauge
The measured mana law (§3) is the class's real skill axis: Nova timing
is throughput, not utility.
- **Fire** — pack king by a wide margin; boss-mid, tied with Poison
  (accepted). Its boss output is mana-capped, not damage-capped.
- **Ice** — mid everywhere, control paid in dps; streakiest spec on the
  boss board (brittle stacks + huge lances).
- **Wind** — the duelist: boss #3, pack-mid with a deliberate self-sab
  (the gale Nova scatters the adds it should be eating).

### Assassin — the ceiling, paid for in proximity
Manaless, squishiest melee, no free i-frames (round 43): the top of the
boss board is rent, not a gift.
- **Shadow** — boss #1 and pack tier-3: cap-exempt crit riders,
  converging fan, Phantom refunds chaining through kills.
- **Blood** — boss ~#3 **at its full-HP floor**; blood_amp pays up to
  +40% as the pilot bleeds, so its real-fight ceiling brushes Shadow.
  Pack-mid since the fan lost pierce (49c).
- **Poison** — the DoT tax collector: fastest toxin stacking in the
  game, mist blooms, 90/95 adds. Boss-mid, pack-strong.

### Paladin — the stance knight
Conviction (Holy ↔ Retribution) makes sustain and damage mutually
exclusive in time. Every grade here assumes Retribution camping — the
correct dps line and the risk the class sells.
- **Wrath** — the damage stance done right: mid-high on both boards.
- **Holy** — deliberately the sustain-for-damage trade on BOTH boards
  (−20% stance, 0.7× hallowed ground, the Judgment tax). If Holy ever
  climbs a dps board again, that's a regression per the ladder.
- **Aegis** — the matchup spec: strongest into fights that attack you
  relentlessly, floor against anything passive. Both benches use
  passive targets, so its true grade against real bosses is HIGHER than
  its number (§9).

### Warlock — the attrition engine, finally paid
Round 49 cleared it of the mana myth (min MP ~230 of 380, measured) and
fixed the real problem: cadence and ramp — bolt tax reverted, 0.5s
cadence, wither deepened to +64%.
- **Curse** — boss: the long-fight spec (wither + EXPOSED). Pack: the
  corpse-chain spec, held just under Wind per target.
- **Pact** — the board's biggest inversion: boss floor-adjacent, **pack
  #2**. Dark Pact's 3.5×-deep self-blast makes standing inside the pack
  the class's best button; the 18% HP price is the live-play gate the
  bench can't feel (§9).
- **Void** — crush choreography on both boards; capped at Storm's line
  on packs, shoulder to shoulder with Wrath on bosses.

---

## 6. Mechanical ground rules the numbers rest on

- **Bosses are CC-immune.** Stuns/slows never land on bosses; they work
  fully on mobs and elites. Displacement is physics, not CC — but a
  "shove" moves a boss only 40% as far (`BOSS_SHOVE_FACTOR`).
- **Concussion:** a stun that fails on a CC-immune target converts to
  bonus damage (failed duration × `CONCUSSION_MULT` × ATK) — control
  themes keep a small uniform boss value.
- **DoTs resolve like hits** — mitigated by target res minus caster
  pen, snapshot at application, ticks crit on the caster's SHEET crit
  shaved by target critres. No hidden true damage; true damage remains
  Death Mark's exclusive identity.
- **DoTs do not stack sources** (strongest wins, durations refresh) —
  **except toxin** (poison/venom): +12% tick depth per stack, 5 stacks.
  The no-stack rule is why buffing a second DoT source on the same kit
  often does nothing — the bench proved that twice in round 49.
- **Brittle** (ice): ice hits stack +4% ice-only amplification, 5 deep.
- **Crush** (void): +28% to targets displaced hard in the last 1.5s;
  void's own shoves and pulls open the windows.
- **Wither** (warlock base kit): a MAINTAINED Hex deepens +8% per 6s of
  uptime, cap +64%; a lapsed curse resets the ramp — upkeep IS the
  rotation.
- **EXPOSED (vuln)** is a debuff, not CC: +50% damage taken, works on
  bosses — the premier boss rider and the warlock's pack engine.
- **Plate cadence tax (49):** Cleave 0.74s (0.45 under Berserk),
  Judgment 0.8s — plate hits hard, not fast.
- **Dash rider cap (49c):** the assassin's dash-stab rider lands on at
  most `DASH_RIDER_CAP` (2) victims per pass.
- **Pierce caps (49c):** projectiles carrying `pierce_cap` stop after N
  bodies.
- **Ults ignore Haste** for every class, and Combo never procs on ults.

## 7. Buildcraft — measured, not theorized

- **Gems:** ATK% + pen regulars beat CritDmg regulars **even on the
  crit specs** (Hunt at 31–34% effective crit still preferred Rubies) —
  boss critres shaves effective crit well below what the sheet
  suggests. Combo (~31.6% effective) for the four spam kits; Haste
  (~40.6%) out-rates it on warrior/paladin basics. Lifesteal and Greed
  are never dps gems.
- **Penetration** relieves hits AND dot ticks, and excess past target
  res converts to flat bonus on hits — at this frame (~57 pen with
  talents vs ~39–45 boss res) pen gems run just past the excess point
  and keep paying.
- **Cap-exempt theme crit is king:** sheet crit past the 35% knee pays
  1/5 and boss critres shaves ~30% off the top; the themed crit riders
  (Shadow/Hunt/Wrath) ride ABOVE the knee at full value. They top both
  boards for a reason.

## 8. Meta mixes (unmeasured — the next bench docket)

Mono grades are baselines; per-slot theme mixes are the real endgame.
Hypotheses worth measuring, in likely-strength order:
- **Archer loadout swap** — full Hunt at boss doors, full Storm in
  rooms. Both halves are already measured above; free re-theming makes
  this the class's intended play, not really a "mix".
- **Assassin** — Blood a1/a2 + Shadow a3/ult: echo loop plus the crit
  fan and execute.
- **Mage** — Wind a1 + Fire a2/ult: duelist bolts, pack nova/meteor.
- **Warlock** — Curse a1/a2 + Pact a3: the wither engine plus the pack
  blast.
Do NOT balance against mixes until they're measured; the mono ladders
are the contract.

## 9. Standing watch items

- **Fire ~ Poison (boss)** is an accepted tie. If either drifts ±5%+,
  re-anchor with Fire nominally above, per the ladder.
- **Void ~ Storm (pack)** holds as a tie at Storm's line; Void has no
  AoE-pure knob left short of touching crush (shared with its boss
  identity). If it creeps, trim the rift.
- **Blood's real ceiling** (blood_amp at low HP) is invisible to the
  full-HP bench. Playtest reports of Blood out-pacing Shadow at boss
  doors are consistent with the design — up to the point where it does
  so while SAFE; that would be a regression.
- **Aegis is under-graded by construction** — passive bench targets
  never trigger its reflect. Judge it from `[fight]` reports against
  aggressive bosses before touching the numbers.
- **Pact's HP price is free on the bench** (nothing hits the hero); live
  pack-Pact is a notch below its #2 and far riskier. The bench number
  is the ceiling, not a lie.
- **The mage mana law** couples half the mage column to three knobs
  (Firebolt cost, mage regen, Nova refund) — touch any of them and both
  boards must be re-run.
- **Hunt on packs (14/95 adds)** is intended, but a new player who never
  learns to re-theme will bounce off the archer — that's onboarding
  material (hint text), not a balance knob.
- **Add-count vs dps** disagree for knockback kits (Fury kills 36 adds
  at 4180 dps; Poison kills 90 at 4576): scatter juice trades clear
  speed for feel. Fine today; revisit if farm-speed complaints name the
  warrior.

## 10. How to update this document

1. Change a kit or tuning number.
2. `dps_bench.bat` (boss board) and `dps_bench.bat --aoe` (pack board).
   Sub-5% deltas are ties; disputes take 2–3 runs.
3. Check both target ladders in §2 — they are the contract.
4. Paste the new boards, fix the prose that stopped being true, and log
   the round in BALANCE_HISTORY.md (newest at top).
