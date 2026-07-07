# Emberfall — Class & Theme Tier List

First documented edition. Living balance document: **every number here
is MEASURED, not estimated** — both boards are output of the DPS bench
harness (`dps_bench.bat`), and the roster was tuned across round 49 (see
BALANCE_HISTORY.md, rounds 49 / 49b / 49c / 49d / 49e / 49f) until the
boards matched the player-authored target ladders reproduced in §2.
Update this file whenever a kit or tuning number changes: rerun the
bench, paste the new boards, and rewrite whatever prose stopped being
true.

**If you read one thing, read §3** — the holistic F–S ranking that
folds both boards plus survivability and utility into one grade. §4/§5
are the raw single-axis boards it rests on.

---

## 1. The instrument

`dps_bench.bat [--aoe] [--downtime] [--secs=N] [--cls=X] [--theme=Y]` —
headless, compile-gated, `--fixed-fps 60` (the simulation is decoupled
from the wall clock: CPU contention can slow a run but never change a
number). Without `--cls` it fans out to **six parallel Godot processes**
(one class each, isolated save dirs, `dps_bench_fan.ps1`) and ends with
one merged ranking — a full 18-case sweep costs roughly one class's wall
time.

**The frame (every board):**

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
  baseline identities; meta mixes are §9 and currently unmeasured.
- **180-second windows**; the damage clock starts at first blood.

**Three boards, one frame:**
- **Boss** (default): one immortal dummy that is a real `Boss` subclass
  — CC immunity, concussion conversion, boss shove factor and a
  boss-sized hitbox all behave exactly like a live boss door — carrying
  the **average defensive sheet of every registered boss at L40**
  (physres ~39, magres ~45, eva ~6%, critres ~14), so no single boss's
  matchup skews the ladder.
- **Pack** (`--aoe`): three of those pillars shoulder to shoulder
  (65px), plus **five 1200-HP adds every 10 seconds** that are supposed
  to die — kill-triggered effects (hex detonations, Starfall cascades,
  Phantom dash refunds) all fire. DPS pools **effective damage**;
  overkill on a dying add never inflates a number. The `adds x/95`
  column is the clear-speed signal.
- **Downtime** (`--downtime`): the boss board with the hero forced to
  **stop casting 1s of every 5s** — the telegraph-dodge simulation.
  DoTs keep ticking through the gap; burst specs cast nothing. It is a
  DIAGNOSTIC, not a tuning target — it exists to check the doctrine that
  DoT specs' lower stand-still numbers are partly a bench artifact
  (§4 note).

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

## 2. The board ladders (the design contract)

Both ladders are player-authored targets; round 49 tuned until they
held. **They are the contract** — if a future change breaks an
ordering, that is a regression, not drift. (The holistic §3 grade may
still differ from a spec's board rank, because it also weighs
survivability and utility the boards don't measure.)

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

## 3. Overall holistic tier (F–S)

The synthesis grade. It weighs boss output (gates progression) and pack
output (most of the playtime) roughly evenly, then adjusts for what the
raw boards CAN'T see: survivability (sustain, dodge, plate), defensive
utility (ENFEEBLE, HOBBLED, reflect), consistency under dodge pressure
(the §4 downtime finding), and how much real-play ceiling hides behind
the stand-still number (blood_amp, Aegis reflect). A one-axis monster
that is dead weight on the other axis lands lower than its headline rank.

**Scale note — the floor is compressed on purpose.** Nothing grades
below B−. The roster was tuned to a deliberately playable floor: a B−
here means "niche or matchup-dependent, but functional and fun to
pilot," not "broken." There is no C/D/F because there is no trap build
in the game — the F–S scale is used honestly, it just doesn't bottom out.

| Tier | Spec | Why here |
|---|---|---|
| **S** | Assassin · Shadow | The game's ceiling: boss #1, pack #3, and it chains Phantom refunds through kills. Docked from "untouchable" only by the squish (no plate, no free i-frames) and the dash-timing skill floor — pure power tops the roster. |
| **A+** | Assassin · Blood | Boss ~#3 **at its full-HP floor** — blood_amp pays up to +40% as you bleed, so its real ceiling brushes Shadow — and it self-heals through the surge. The most self-sufficient top-tier melee; skill and risk are the only tax. |
| **A** | Mage · Wind | Boss #3, pack #6, and Blink + Frost Nova are real defensive buttons. The versatile duelist: strong on both boards, mobile, hard to pin. |
| **A** | Warrior · Fury | Boss #5 welded to the tankiest chassis in the game (80 physres, 15% flat DR, Grit). Pack-mediocre (its own knockback scatters the pile), but survivability + a top-5 boss number carry it, and it's the lowest skill floor of the A-tier. |
| **A** | Warlock · Curse | Boss #7, pack #7, unconditional 5% lifesteal, wither on long fights, EXPOSED for the party. The insurance class — good everywhere, never dies, no bad matchup. |
| **A−** | Mage · Fire | Pack KING (#1, and packs are most of the playtime), boss-mid and mana-bound. The farm build; its boss half is capped by mana, not damage. |
| **A−** | Archer · Hunt | Boss #2 at ZERO melee risk — the couch ceiling for boss doors — but a pack liability (14/95 adds). Carried by the boss ceiling and the free re-theme; a mono-Hunt player suffers in rooms. |
| **A−** | Archer · Storm | Pack #4, boss floor — Hunt's mirror. Owns the room, coasts the boss. Same "re-theme at the door" logic. |
| **A−** | Warlock · Void | Boss #8, pack #5, the safest panic buttons in the class (shove/pull/slow). Held back only by the displacement choreography its damage demands — high skill, high safety. |
| **A−** | Mage · Ice | Boss #6, the **best downtime retention on the board** (89% — its damage doesn't care that you dodged), control + brittle + HOBBLED, and survivable. Raw damage is mid by design; consistency and safety lift the grade. |
| **A−** | Paladin · Wrath | Boss #9, pack #10, on the plate chassis with the stance game and the reflect Aegis in the kit. Consistent, tanky, and the reward curve lives in Retribution uptime. |
| **B+** | Assassin · Poison | Boss-weak on paper (~#13) but real-play higher: the fastest toxin stacker in the game, 90/95 pack clear, and now a genuine survival identity — **ENFEEBLE grants up to +10% evasion** vs the venomed foe (atop base Elusive) and slows HOBBLE the boss. A utility-and-clear DoT, not a burst spec. |
| **B+** | Warlock · Pact | Pack **#2** monster (corpse-fuelled immortality), boss floor-adjacent. The 18% HP self-cost is the live gate the bench can't feel, which keeps it out of A-tier despite the pack crown. |
| **B+** | Warrior · Earth | Boss #10, control that PAYS at boss doors now (stuns concuss, slows HOBBLE), pulls packs onto the blade — all on the plate tank chassis. Utility and survivability over raw damage. |
| **B+** | Archer · Venom | Low raw on both boards, but the **safest spec in the game**: it kites everything, and **ENFEEBLE cushions incoming damage up to 16%** — the error-margin insurance for when a hit drops Second Wind. Viable through safety and utility, not damage; a cautious player's dream, a speedrunner's pass. |
| **B** | Paladin · Holy | Absurd sustain (shield-drop heal, per-enemy mending, chains) bought with deliberately low damage. The attrition/marathon pick — grade it as a survival kit. |
| **B** | Warrior · Bulwark | The cannot-die build: every button heals and hardens, floor damage. The answer to content that out-damages you, not a farm spec. |
| **B−** | Paladin · Aegis | Bench floor on both boards — but **under-graded by construction**: the reflect only fires when the enemy swings, and both bench targets are passive. Against a melee-aggressive boss its true grade is a full tier higher; it's a matchup pick, strongest exactly where the boards can't see it. |

**How to read a mismatch with §4/§5:** a spec's holistic grade can sit
above its board rank (Poison, Venom, Ice, Aegis — survivability/utility/
downtime-retention the boards miss) or below it (Hunt, Storm, Pact — a
one-axis monster that's dead weight on the other axis). The boards are
the measurement; §3 is the judgment on top of it.

---

## 4. The boss board (single target, ~means across 180s runs)

| # | Spec | DPS | Notes |
|---|------|----:|-------|
| 1 | Assassin · Shadow | ~4150 | the ceiling: +20%/+15% cap-exempt crit riders, converging five-knife fan, true-damage execute — priced in melee proximity with no plate and no free i-frames |
| 2 | Archer · Hunt | ~3950 | the couch ceiling: 20%-deeper shots, +25% crit above the knee, near-permanent EXPOSED, all five narrow-volley arrows into one body, zero melee risk |
| 3 | Mage · Wind | ~3650 | twin echoing bolts + Starfall — the mage's duelist theme |
| 3 | Assassin · Blood | ~3630 | **tied with Wind at full HP, and that's its FLOOR**: blood_amp converts missing health into up to +40% damage — a bleeding pilot stretches toward Shadow |
| 5 | Warrior · Fury | ~3450 | wave2 backhand + 55%-echo cyclone + Berserk — which now also restores Cleave's unchained 0.45s cadence: the ult is a tempo steroid |
| 6 | Mage · Ice | ~3400 | widest variance on the board (3020–3600 observed): heavy lances, brittle self-amplification, freeze concussion — and near-permanent HOBBLED since 49d |
| 7 | Warlock · Curse | ~3180 | deep withering bolts, guaranteed EXPOSED from Hex, wither ramping +8%/6s of curse uptime to +64% — the long-fight spec |
| 8 | Warlock · Void | ~3140 | crush choreography: hex-shove opens the window, bolts spike into it (+22% crush, +25% Nightfall crit) — its bolt-slow keeps HOBBLED near-permanent |
| 9 | Paladin · Wrath | ~3110 | double Judgment hunting the gaps (+20% crit), erupting Consecration; Retribution uptime IS the skill expression |
| 10 | Warrior · Earth | ~3040 | the control spec: stuns concuss, slows HOBBLE — its whole rider budget pays at boss doors since 49d |
| 11 | Mage · Fire | ~2865 | splash is wasted solo; the deep burn (0.60 bolt dot, 2.0× meteor burn) carries it — nominally above Poison per the ladder, tie-band in practice |
| 12 | Archer · Venom | ~2805 | heavy stacking DoTs on capped-pierce arrows + slows on every slot feeding HOBBLED; ENFEEBLE cushions the archer's own damage taken — the safest solo theme |
| 13 | Assassin · Poison | ~2780 | the fastest toxin stacker in the game (0.12/stack) + HOBBLED uptime; ENFEEBLE lends the assassin evasion; bloom re-trimmed so the pair sits at Fire's shoulder, not past it |
| 14 | Archer · Storm | ~2560 | the AoE spec's solo floor: with nobody to fork to, the charge arcs BACK into the same body at 50% (`ric_back`) |
| 15 | Warlock · Pact | ~2525 | blood-priced bolts; its real identity lives on the pack board |
| 16 | Paladin · Holy | ~2020 | −20% stance damage + the Judgment cadence tax: absurd sustain, deliberately low output |
| 17 | Warrior · Bulwark | ~1875 | every button heals and hardens; the cannot-die build pays here |
| 18 | Paladin · Aegis | ~1700 | reflect identity — damage arrives only when the enemy swings, and a bench dummy never swings (see §10) |

**Reading notes:**

- **Melee > ranged at the top is intentional risk compensation**; the
  plate classes sit mid-table because round 49's cadence tax ("plate
  hits HARD, not fast") moved Cleave 0.45→0.74s and Judgment 0.5→0.8s.
- **The mage mana law (measured):** pure Firebolt spam empties the pool
  ~2 minutes in and the cast rate collapses to regen speed; Meteor sat
  unaffordable 48 of 180 seconds. Frost Nova's missing-mana refund (20%
  of missing for 15 MP, no shared lockout with Firebolt — the refill
  costs zero bolt casts) is **load-bearing** on long fights. A pilot who
  refuses it loses ~10–15% past the two-minute mark, most of it on Fire.
- **Fire ~ Poison ~ Venom** ended as a deliberate tie cluster at ~2800:
  Fire is mana-capped rather than damage-capped, and 49d's HOBBLED
  lifted the two DoT specs into its shoulder (Poison re-trimmed to keep
  Fire nominally on top).
- **The downtime finding (why the DoT specs rate above their raw rank
  in §3):** forced to dodge 1s of every 5s (a 20% cast tax), the true
  tick-banked specs keep far more of their output than the burst
  cluster — **Venom retains 90%, Ice 89%, Poison 86%**, versus
  Fury/Void/Wind ~82%. Their damage is already in the ground and doesn't
  care that you stopped casting. Under a real bullet-hell boss (30–40%
  dodging) the edge compounds. Two surprises: **Fire retains only 82%**
  — it's a burst theme wearing a DoT coat (bolt+splash+Meteor front-
  loaded, mana recovers during the gap), and **Curse retains 83%** —
  it's Shadowbolt spam with DoT amplifiers, not a true DoT. The genuine
  tick-banked trio is Venom, Poison, Ice.

---

## 5. The pack board (AoE — 3 pillars + add waves, final 180s run)

| # | Spec | DPS | adds | Notes |
|---|------|----:|-----:|-------|
| 1 | Mage · Fire | ~6300 | 90/95 | the farm king by a clear margin: 45% splash on every bolt, the flame-ring Nova, the widened burning Meteor |
| 2 | Warlock · Pact | ~5650 | 88/95 | Dark Pact is the whole story: 18% max HP buys a 3.5×-deep blast around you every ~6s, drunk back through the lifesteal surge — an engine that runs on standing inside the pack |
| 3 | Assassin · Shadow | ~5500 | 81/95 | five-knife fans at surge cadence; Phantom dash refunds chain through add kills |
| 3 | Archer · Storm | ~5200 | 85/95 | forks leaping body to body, piercing volleys, 45–75% lightning splash on everything |
| 5 | Mage · Wind | ~5100 | 90/95 | gust-splash twin bolts; Starfall executes and cascades through dying adds; its gale Nova scatters its own targets — identity kept over optimum |
| 6 | Warlock · Curse | ~4800 | 88/95 | whole-pack EXPOSED + wither + death-detonations chaining through corpses |
| 6 | Warlock · Void | ~4900 | 86/95 | hex-shove opens pack-wide crush windows; the greedy rift; capped at Storm's line by target |
| 8 | Assassin · Blood | ~4900 | 47/95 | echo carries it; the fan's pierce was removed in 49c to hold it under Shadow |
| 9 | Assassin · Poison | ~4650 | 90/95 | mist blooms + toxin on everything — a top-tier add clearer |
| 10 | Paladin · Wrath | ~4520 | 84/95 | the erupting Consecration drags the pack onto the hammer |
| 11 | Mage · Ice | ~4450 | 88/95 | brittle + freeze control; damage mid by design |
| 12 | Warrior · Fury | ~4170 | 36/95 | the 1.0× echo cyclone; Cleave's knockback scatters its own dinner — the low add count is self-inflicted juice |
| 13 | Archer · Hunt | ~3900 | 14/95 | the boss spec on the wrong board: precision riders do nothing for crowds — **14 of 95 adds** says everything |
| 14 | Warrior · Earth | ~3700 | 60/95 | drags the pack into the blade; the control tax again |
| 15 | Archer · Venom | ~3070 | 59/95 | plague-rain DoTs; above the sustain floor, below Wind — exactly the target slot |
| 16 | Paladin · Holy | ~2940 | 76/95 | hallowed ground trades fire for mending (0.7× damage) |
| 17 | Paladin · Aegis | ~2650 | 72/95 | reflect needs attackers; passive targets starve it |
| 18 | Warrior · Bulwark | ~2350 | 25/95 | the anvil, not the hammer |

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

## 6. Class deep dives

### Warrior — the juggernaut, taxed into deliberateness
Plate identity: 80 physres, 15% flat DR, Grit regen that feeds on being
hit. Round 49's cadence tax made Cleave a 0.74s decision instead of a
0.45s tremolo, and **Berserk hands the old cadence back for its
window** — the ult went from a damage steroid to a tempo one, and its
uptime is now the warrior's dps rhythm.
- **Fury** — the damage identity and the best warrior on both boards:
  wave2 backhand, 55%-echo cyclone at 1.5× radius, deeper/longer
  Berserk.
- **Earth** — control: quake lanes, stuns (concussion at boss doors),
  slows (HOBBLED at boss doors), a whirlwind that drags packs in. Mid on
  both boards; the pull is also why the AoE geometry never broke it.
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
- **Venom** — the DoT/safety spec: capped-pierce toxin arrows, the
  deepened plague rain, slows on all four slots (→ near-permanent
  HOBBLED at boss doors), and **ENFEEBLE cushions the archer's own
  damage taken up to 16%** while its toxin holds — the error-margin
  insurance when a hit would drop Second Wind. Low raw output, highest
  safety floor in the class.

### Mage — the glass engine with a fuel gauge
The measured mana law (§4) is the class's real skill axis: Nova timing
is throughput, not utility.
- **Fire** — pack king by a wide margin; boss-mid, tied with Poison
  (accepted). Its boss output is mana-capped, not damage-capped, and it
  behaves like a burst spec under dodge pressure (82% downtime retention).
- **Ice** — mid everywhere, control paid in dps; streakiest spec on the
  boss board (brittle stacks + huge lances) and the **best downtime
  retention on the roster** (89%) — its damage survives dodging.
- **Wind** — the duelist: boss #3, pack-mid with a deliberate self-sab
  (the gale Nova scatters the adds it should be eating).

### Assassin — the ceiling, paid for in proximity
Manaless, squishiest melee, no free i-frames (round 43): the top of the
boss board is rent, not a gift.
- **Shadow** — boss #1 and pack tier-3: cap-exempt crit riders,
  converging fan, Phantom refunds chaining through kills.
- **Blood** — boss ~#3 **at its full-HP floor**; blood_amp pays up to
  +40% as the pilot bleeds, so its real-fight ceiling brushes Shadow,
  and the surge self-heals. Pack-mid since the fan lost pierce (49c).
- **Poison** — the DoT/survival spec: fastest toxin stacking in the
  game, mist blooms, 90/95 adds — and **ENFEEBLE grants up to +10%
  evasion** vs the venomed foe on top of base Elusive, so the dive that
  keeps the surge alive can also dodge the bullets it dives into.
  Boss-weak on paper, real-play higher via safety + downtime retention.

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
  its number (§10).

### Warlock — the attrition engine, finally paid
Round 49 cleared it of the mana myth (min MP ~230 of 380, measured) and
fixed the real problem: cadence and ramp — bolt tax reverted, 0.5s
cadence, wither deepened to +64%.
- **Curse** — boss: the long-fight spec (wither + EXPOSED). Pack: the
  corpse-chain spec, held just under Wind per target. Unconditional
  lifesteal makes it the class's no-bad-matchup pick.
- **Pact** — the board's biggest inversion: boss floor-adjacent, **pack
  #2**. Dark Pact's 3.5×-deep self-blast makes standing inside the pack
  the class's best button; the 18% HP price is the live-play gate the
  bench can't feel (§10).
- **Void** — crush choreography on both boards; capped at Storm's line
  on packs, shoulder to shoulder with Wrath on bosses; the safest panic
  buttons in the class.

---

## 7. Mechanical ground rules the numbers rest on

- **Bosses are CC-immune.** Stuns/slows never land on bosses; they work
  fully on mobs and elites. Displacement is physics, not CC — but a
  "shove" moves a boss only 40% as far (`BOSS_SHOVE_FACTOR`).
- **Concussion:** a stun that fails on a CC-immune target converts to
  bonus damage (failed duration × `CONCUSSION_MULT` × ATK) — control
  themes keep a small uniform boss value.
- **HOBBLED (49d):** the same conversion for slows — a slow that fails
  on a CC-immune boss scuffs its footing: +`HOBBLE_MULT` (4%) damage
  taken from the player for `HOBBLE_DUR` (2.5s), refreshed per failed
  slow, DoT ticks included. Before this, the slow half of every control
  theme's budget (venom/poison/ice/void/earth) was a dead rider at boss
  doors — venom paid it on all four slots.
- **ENFEEBLE (49e/49f):** maintaining YOUR toxin on a foe turns its rot
  into your survival — the DoT specs' defensive axis, toxin-gated so
  only Poison-assassin and Venom-archer get it, and it can't be borrowed
  by slotting one green ability. Class-flavored, scaled by live toxin
  stacks: the **assassin SLIPS the blow** (up to +10% evasion, a second
  roll on top of base Elusive — dodges the bullets it dives into for the
  surge); the **archer SHRUGS it** (up to 16% less damage — the cushion
  that survives losing Second Wind). Invisible to the dps boards (the
  bench hero takes no damage) — pure survival value.
- **DoTs resolve like hits** — mitigated by target res minus caster
  pen, snapshot at application, ticks crit on the caster's SHEET crit
  shaved by target critres. No hidden true damage; true damage remains
  Death Mark's exclusive identity.
- **DoTs do not stack sources** (strongest wins, durations refresh) —
  **except toxin** (poison/venom): +12% tick depth per stack, 5 stacks.
  The no-stack rule is why buffing a second DoT source on the same kit
  often does nothing — the bench proved that twice in round 49.
- **Brittle** (ice): ice hits stack +4% ice-only amplification, 5 deep.
- **Crush** (void): +22% to targets displaced hard in the last 1.5s;
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

## 8. Buildcraft — measured, not theorized

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

## 9. Meta mixes (unmeasured — the next bench docket)

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

## 10. Standing watch items

- **Fire ~ Poison ~ Venom (boss)** is an accepted tie cluster at ~2800.
  If any of the three drifts ±5%+, re-anchor with Fire nominally above,
  per the ladder (Poison's bloom and Venom's hobble uptime are the
  knobs).
- **Void rides the TOP of its allowed band on both boards** — 49d's
  HOBBLED handed it a free lift (its slow rides every bolt) and crush
  came down 0.28→0.22 to compensate. It sits at wrath's shoulder (boss)
  and in a statistical tie with Storm (pack), and it's the noisiest
  spec measured (rift crits + crush windows compound). If it creeps
  again, crush is the knob; the "around Ice" soft target is unreachable
  without gutting the identity and has been waived.
- **Blood's real ceiling** (blood_amp at low HP) is invisible to the
  full-HP bench. Playtest reports of Blood out-pacing Shadow at boss
  doors are consistent with the design — up to the point where it does
  so while SAFE; that would be a regression.
- **Aegis is under-graded by construction** — passive bench targets
  never trigger its reflect. Judge it from `[fight]` reports against
  aggressive bosses before touching the numbers; its §3 grade already
  credits the hidden ceiling.
- **ENFEEBLE is bench-invisible** — it only reduces damage the hero
  TAKES, which the dps boards don't measure. Its value (Poison/Venom
  survivability) is a §3 judgment, not a board number; verify it in
  playtest, not the bench.
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
  at ~4170 dps; Poison kills 90 at ~4650): scatter juice trades clear
  speed for feel. Fine today; revisit if farm-speed complaints name the
  warrior.

## 11. How to update this document

1. Change a kit or tuning number.
2. `dps_bench.bat` (boss board) and `dps_bench.bat --aoe` (pack board);
   `--downtime` when a DoT-vs-burst question is in play. Sub-5% deltas
   are ties; disputes take 2–3 runs.
3. Check both board ladders in §2 (the contract) AND whether the change
   moves any §3 holistic grade — survivability/utility changes (ENFEEBLE,
   HOBBLED, sustain) move §3 without touching the boards.
4. Paste the new boards, fix the prose that stopped being true, and log
   the round in BALANCE_HISTORY.md (newest at top).
