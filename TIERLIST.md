# Emberfall — Class & Theme Tier List

Living balance document: **every number here is MEASURED**, not estimated
— both boards are output of the DPS bench harness (`dps_bench.bat`).

**Frame change (optimization pass, 2026-07-08):** these boards now measure
the **optimal-play CEILING** — the max-DPS build per variant (attributes,
gems, and talents all optimized; §8), not the player's save copies. The
earlier "hand-authored target ladder" the roster was tuned to (round 49)
**no longer holds** under optimized builds — the optimization reshuffled
the order substantially, most sharply by handing the **manaless assassin**
a free Haste+Ruby stack that nothing else can match. §2 is now a *measured
re-baseline*, not a design contract. This is documentation of reality; no
balance numbers were changed in this pass (findings are logged in §10).

**If you read one thing, read §3** — the holistic F–S ranking that folds
both boards plus survivability and utility into one grade. §4/§5 are the
raw single-axis boards it rests on; §8 is why the numbers look the way
they do.

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

- Hero at **level 40**. **All attribute points in the class primary** —
  primary gives the most ATK + crit per point; VIT/off-stats give no ATK,
  so all-in is optimal for every variant (paladin still STR: it builds the
  ATK number even though its hits now land as magic).
- **Full A-grade gear**, seeded rolls (identical every run), class
  signature weapon shape.
- **Lv6 gems, per-variant OPTIMAL loadout** (this is the change from the
  old save-copy frame). Every regular socket is a **Ruby (ATK%)** — at Lv6
  that's +22.8% ATK per gem, and CritDmg only overtakes it above ~50%
  *effective* crit, which no variant reaches (even Hunt/Shadow land 26–34%
  after the knee + boss critres). Special slot: **Haste ×4 → the 40% cdr
  cap** for the classes whose cooldown abilities are free (warrior /
  paladin / assassin), **Combo ×4** for the mana-bound ones (archer / mage
  / warlock) whose bigger cooldowns starve under Haste — Combo's mana
  *refund* sustains the cadence instead of draining it (§8, §10).
- **Talents: per-variant best-DPS cell per row** (10/9/10 in the DPS rows,
  the 9 landing in each class's weakest/defensive row). Notable picks:
  Venom takes Serpent's Due (+40% vs poisoned — its dots always poison),
  Ice takes Killing Frost (+40% vs chilled — always slowed), Hunt/Shadow
  take the crit_dmg row-4 cell (the only two that clear the ATK%-vs-CritDmg
  threshold on that node), everyone else atk%. All presets are consts at
  the top of `scripts/tests/dps_bench.gd`.
- **Mono themes** — every slot on one theme. These boards grade baseline
  identities; meta mixes are §9 and currently unmeasured.
- **180-second windows**; the damage clock starts at first blood.

**Three boards, one frame:**
- **Boss** (default): one immortal dummy that is a real `Boss` subclass —
  CC immunity, concussion conversion, boss shove factor and a boss-sized
  hitbox all behave like a live boss door — carrying the **average
  defensive sheet of every registered boss at L40** (physres ~39, magres
  ~45, eva ~6%, critres ~14), so no single boss's matchup skews the ladder.
- **Pack** (`--aoe`): three of those pillars shoulder to shoulder (65px),
  plus **five 1200-HP adds every 10 seconds** that are supposed to die —
  kill-triggered effects (hex detonations, Starfall cascades, Phantom dash
  refunds) all fire. DPS pools **effective damage**; overkill on a dying
  add never inflates a number. The `adds x/95` column is the clear-speed
  signal.
- **Downtime** (`--downtime`): the boss board with the hero forced to stop
  casting 1s of every 5s — the telegraph-dodge simulation. A DIAGNOSTIC,
  not a tuning target (§4 note; last measured on the pre-optimization
  builds — the qualitative finding holds).

**Rotations are playstyle-constrained**, per class (player-specified):

| Class | Boss rotation | Pack rotation (differences only) |
|---|---|---|
| Warrior | stand still; Cleave + Whirlwind + Berserk (no Shield Bash) | same |
| Archer | Quick Shot + Multishot + Arrow Storm (no Tumble) | same |
| Mage | Firebolt + Meteor; Frost Nova ONLY as an emergency refill under 55 MP | Nova on cooldown — it's real AoE in a crowd |
| Assassin | dash through the boss right before the blood surge lapses; surged Fan of Knives filler; Death Mark on cooldown, then a 5s Stab window | same |
| Paladin | one Conviction swap into RETRIBUTION, never back; Judgment + Consecration (no Aegis vs a passive target) | same |
| Warlock | Shadowbolt + Hex upkeep + Void Rift (no Dark Pact at boss range) | Dark Pact back in — in a pack you ARE point-blank |

**Measurement law: run-to-run variance is ~±5%** (physics iteration order
perturbs crit/echo rolls even under fixed seeds; ult-count quantization at
window edges adds more for the 40–50s-cd kits). Any gap under 5% is a TIE.
Ladder disputes get settled over 2–3 runs, never one.

---

## 2. The measured order (optimized builds — a re-baseline, not a contract)

Under optimized builds the old hand-tuned target ladder is gone. This is
now the *measured* order; treat it as the current baseline to check future
changes against, not a hand-authored contract. **The headline: the
assassin sweeps — three of the top four on boss** (§10 finding).

**Boss (single-target):**
> Shadow ≫ Hunt > Blood > Poison > Curse ~ Venom > Fury ~ Wind ~ Earth ~
> Pact ~ Wrath ~ Void > Ice > Fire > Storm  ·  floor: Holy ~ Bulwark ~ Aegis

**Pack (AoE):**
> Pact ~ Shadow ~ Fire > Blood ~ Poison > Curse > Storm ~ Void > Wind ~
> Wrath ~ Hunt > Ice ~ Fury ~ Earth ~ Venom  ·  floor: Holy ~ Aegis ~ Bulwark

Several specs still INVERT across boards — Hunt is boss #2 / pack #11, Fire
is boss #14 / pack #3, Pact is boss #10 / pack #1. That inversion is the
design: theme swaps are free outside combat, so the intended endgame play
is re-theming at boss doors.

---

## 3. Overall holistic tier (F–S)

The synthesis grade. It weighs boss output (gates progression) and pack
output (most of the playtime) roughly evenly, then adjusts for what the
raw boards CAN'T see: survivability (sustain, plate, ENFEEBLE), and how
much real-play ceiling hides behind the stand-still number (blood_amp,
Aegis reflect). A one-axis monster that is dead weight on the other axis
lands lower than its headline rank.

**Scale note — the floor is compressed on purpose.** Nothing grades below
B−: the roster has a deliberately playable floor, so a B− means "niche or
matchup-dependent, but functional," not "broken." No C/D/F because there
is no trap build.

| Tier | Spec | Why here |
|---|---|---|
| **S** | Assassin · Shadow | Boss #1 (5550) AND pack #2 (7122) — dominant on both, the clearest #1 in the game. Manaless → the only class that stacks Haste to the cap *and* full Rubies with zero mana tax; docked from "untouchable" only by the squish and dash-timing skill floor. |
| **A+** | Assassin · Blood | Boss #3 (4806), pack #4 (6485) — and blood_amp pays up to +40% more as you bleed, so its real ceiling brushes Shadow, while the surge self-heals. The most self-sufficient top-tier melee. |
| **A+** | Assassin · Poison | **The pass's big riser** (was B+): boss #4 (4078), pack #5 (6471, 90/95 adds) — the manaless Haste+Ruby lift plus its own DoT scaling put it in the top five of BOTH boards, on top of ENFEEBLE evasion and HOBBLED. Top-tier damage AND a survival identity. |
| **A** | Archer · Hunt | Boss #2 (4933) at ZERO melee risk — the couch ceiling for boss doors. A pack liability (#11, 16/95 adds), but boss-gating + safety carry it, and free re-theme covers the rooms. |
| **A** | Warlock · Curse | Boss #5 (3865), pack #6 (6034), unconditional 5% lifesteal, wither on long fights, EXPOSED for the party. The versatile insurance class — good everywhere, never dies, no bad matchup. |
| **A** | Warlock · Pact | Pack **#1** (7291) — the farm king outright now — boss #10 (playable). The 18% HP self-cost is the live gate the bench can't feel, but pack-#1 + a real boss floor is A-worthy. |
| **A−** | Mage · Fire | Pack #3 (6720), boss #14 — the mage's farm build, mana-capped on boss. Packs are most of the playtime, which holds the grade despite the weak boss half. |
| **A−** | Archer · Venom | Boss #6 (3843 — a real riser) with the deepest DoT + Serpent's Due, and the **safest spec in the game**: kites everything, ENFEEBLE cushions 16% of incoming. Pack-weak (#15), carried by boss + safety. |
| **A−** | Archer · Storm | Pack #7 (5536), boss floor (#15). Owns the room, coasts the boss — Hunt's mirror, same re-theme logic. |
| **A−** | Warlock · Void | Boss #12, pack #8 (5535), the safest panic buttons in the class (shove/pull/slow). Balanced-mid + high safety; held back by the displacement choreography its damage demands. |
| **A−** | Warrior · Fury | Boss #7 (3405) welded to the tankiest chassis in the game (80 physres, 15% flat DR, Grit). Pack-mediocre (its own knockback scatters the pile), but survivability + a top-7 boss carry it at the lowest skill floor of the tier. |
| **A−** | Mage · Wind | Boss #8, pack #9, Blink + Frost Nova as real defensive buttons — the mobile duelist, strong-mid on both. |
| **A−** | Paladin · Wrath | Boss #11, pack #10, on the plate chassis with the stance game; now a **magic** dealer (checks magres). Consistent, tanky, reward curve in Retribution uptime. |
| **B+** | Warrior · Earth | Boss #9, pack #14, control that PAYS at boss doors (stuns concuss, slows HOBBLE) and drags packs onto the blade — all on the plate tank chassis. |
| **B+** | Mage · Ice | Boss #13, pack #12, control + brittle + HOBBLED, and the most consistent under dodge pressure (best downtime retention pre-opt). Damage mid by design; consistency and safety lift it. |
| **B** | Paladin · Holy | Absurd sustain (shield-drop heal, per-enemy mending, chains) bought with deliberately low damage (boss #16). The attrition/marathon pick — a survival kit. |
| **B** | Warrior · Bulwark | The cannot-die build: every button heals and hardens, floor damage (pack #18). The answer to content that out-damages you, not a farm spec. |
| **B−** | Paladin · Aegis | Bench floor on both boards — but **under-graded by construction**: the reflect only fires when the enemy swings, and both bench targets are passive. Against a melee-aggressive boss its true grade is a full tier higher; a matchup pick, strongest where the boards can't see. |

**Reading a mismatch with §4/§5:** a spec's holistic grade can sit above
its board rank (Poison/Venom/Pact/Aegis — survivability/utility/pack-crown
the boards under-credit) or below it (Hunt/Storm/Fire — a one-axis monster
that's dead weight on the other axis). The boards are the measurement; §3
is the judgment on top of it.

---

## 4. The boss board (single target, optimized builds, verified 180s run)

| # | Spec | DPS | atk | Notes |
|---|------|----:|----:|-------|
| 1 | Assassin · Shadow | 5550 | 496 | the ceiling — cap-exempt crit riders, converging five-knife fan, true-damage execute; manaless, so Haste+Ruby stack free |
| 2 | Archer · Hunt | 4933 | 399 | the couch ceiling: 1.2× shots, +25% cap-exempt crit, near-permanent EXPOSED, all five narrow-volley arrows into one body, zero melee risk |
| 3 | Assassin · Blood | 4806 | 521 | full-HP FLOOR — blood_amp stretches it toward Shadow as the pilot bleeds; the surge self-heals |
| 4 | Assassin · Poison | 4078 | 521 | the riser: fastest toxin stacker + Serpent's-Due-adjacent scaling + the manaless Haste lift; also carries ENFEEBLE/HOBBLED survival |
| 5 | Warlock · Curse | 3865 | 394 | deep withering bolts, guaranteed EXPOSED from Hex, wither +8%/6s to +64% — the long-fight spec, sustained by lifesteal |
| 6 | Archer · Venom | 3843 | 417 | Serpent's Due (+40% vs poisoned, always on) + deep stacking DoT; HOBBLED on every slot; the safe ranged pick, now a real boss number |
| 7 | Warrior · Fury | 3405 | 550 | wave2 backhand + echo cyclone + Berserk-cadence; highest ATK on a plate chassis |
| 8 | Mage · Wind | 3354 | 489 | twin echoing bolts + Starfall — the duelist |
| 9 | Warrior · Earth | 3246 | 528 | control that pays at the door (concussion + HOBBLED) on the tank chassis |
| 10 | Warlock · Pact | 3221 | 413 | blood-priced bolts; its real identity is the pack board |
| 11 | Paladin · Wrath | 3202 | 491 | double Judgment hunting the gaps, erupting Consecration; **magic** damage now (magres/magpen); Retribution uptime is the skill |
| 12 | Warlock · Void | 3160 | 375 | crush choreography (+22% crush, +25% Nightfall crit); bolt-slow keeps HOBBLED near-permanent |
| 13 | Mage · Ice | 2991 | 489 | Killing Frost (+40% vs chilled, always slowed) + brittle + freeze concussion; control paid in raw dps |
| 14 | Mage · Fire | 2818 | 467 | splash wasted solo, mana-capped; the burn carries what it can — a pack theme on the wrong board |
| 15 | Archer · Storm | 2570 | 399 | the AoE spec's solo floor: nobody to fork to, charge arcs back at 50% (`ric_back`) |
| 16 | Paladin · Holy | 2113 | 585 | −20% stance + Judgment cadence tax: absurd sustain, deliberately low output (highest ATK, least of it lands) |
| 17 | Warrior · Bulwark | 2048 | 528 | every button heals and hardens; the cannot-die build pays here |
| 18 | Paladin · Aegis | 2011 | 516 | reflect identity — damage arrives only when the enemy swings, and a bench dummy never swings (§10) |

**Reading notes:**

- **The assassin sweep is the story (§10).** Being MANALESS, the assassin
  is the only class that takes Haste to the 40% cap AND four Rubies with no
  mana penalty — everyone else pays a mana tax on their cooldown abilities
  that caps how hard they can gem for cadence. That structural edge puts
  three assassin specs in the top four.
- **The DoT specs jumped.** With their real optimal talents on (Serpent's
  Due for Venom, the toxin scaling for Poison) plus 4× Ruby, Poison went
  boss #13 → #4 and Venom #12 → #6. The old "Fire ~ Poison ~ Venom tie
  cluster" is broken: both DoT archers/assassins now sit clearly above
  Fire, which fell to #14 (mana-capped, splash-wasted solo).
- **The mage mana law (measured):** pure Firebolt spam empties the pool
  ~2 minutes in; Frost Nova's missing-mana refund is load-bearing on long
  fights. It's why mage runs **Combo** (refund) over Haste — Haste would
  only deepen the starvation.
- **Downtime finding (pre-optimization builds, qualitative holds):** forced
  to dodge 1s of every 5s, the true tick-banked specs (Venom/Poison/Ice)
  keep ~86–90% of their output vs the burst cluster's ~82% — their damage
  is already in the ground. Fire retains only ~82% (a burst theme wearing a
  DoT coat). Re-running downtime on optimized builds is a future item.

---

## 5. The pack board (AoE — 3 pillars + add waves, optimized builds, verified)

| # | Spec | DPS | adds | Notes |
|---|------|----:|-----:|-------|
| 1 | Warlock · Pact | 7291 | 88/95 | the farm king: 18% max HP buys a deep blast around you every ~6s, drunk back through the lifesteal surge — an engine that runs on standing inside the pack |
| 2 | Assassin · Shadow | 7122 | 82/95 | five-knife fans at surge cadence; Phantom dash refunds chain through add kills |
| 3 | Mage · Fire | 6720 | 90/95 | 45% splash on every bolt, flame-ring Nova, widened burning Meteor — a clean 90/95 clear |
| 4 | Assassin · Blood | 6485 | 46/95 | echo carries it; low add count is the pierce cap holding it under Shadow |
| 5 | Assassin · Poison | 6471 | 90/95 | mist blooms + toxin on everything — a top clearer both in dps and bodies |
| 6 | Warlock · Curse | 6034 | 88/95 | whole-pack EXPOSED + wither + death-detonations chaining through corpses |
| 7 | Archer · Storm | 5536 | 85/95 | forks leaping body to body, piercing volleys, splash on everything |
| 8 | Warlock · Void | 5535 | 88/95 | hex-shove opens pack-wide crush windows; the greedy rift |
| 9 | Mage · Wind | 4921 | 89/95 | gust-splash twin bolts; Starfall executes and cascades through dying adds |
| 10 | Paladin · Wrath | 4807 | 83/95 | the erupting Consecration drags the pack onto the hammer |
| 11 | Archer · Hunt | 4750 | 16/95 | the boss spec on the wrong board — decent dps into the pillars but **16/95 adds**: precision riders do nothing for crowds |
| 12 | Mage · Ice | 4336 | 88/95 | brittle + freeze control; damage mid by design |
| 13 | Warrior · Fury | 4320 | 39/95 | echo cyclone; Cleave's knockback scatters its own dinner — the low add count is self-inflicted juice |
| 14 | Warrior · Earth | 4112 | 62/95 | drags the pack into the blade; the control tax again |
| 15 | Archer · Venom | 4091 | 71/95 | plague-rain DoTs; above the sustain floor, below the burst clearers |
| 16 | Paladin · Holy | 3081 | 78/95 | hallowed ground trades fire for mending (0.7× damage) |
| 17 | Paladin · Aegis | 2996 | 74/95 | reflect needs attackers; passive targets starve it |
| 18 | Warrior · Bulwark | 2630 | 33/95 | the anvil, not the hammer |

**Reading notes:**

- **Pact took the pack crown from Fire** under optimized builds (7291 vs
  6720) — its self-blast scales harder with 4× Ruby than Fire's splash,
  and Shadow slots between them. The top three are within ~8% (a tie band).
- **Structural mechanics still in force:** `DASH_RIDER_CAP` (2) stops the
  assassin dash-stab rider after two victims (Blood benched 9087 before the
  fix); `pierce_cap` gives Venom arrows 3-body pierce while Blood/Void
  bolts lost pierce entirely; the bench pins plate classes because add
  waves bulldoze a stationary body out of melee reach (footwork in real
  play).

---

## 6. Class deep dives

### Assassin — the optimization winner
Manaless, squishiest melee, no free i-frames (round 43). Being manaless is
its structural jackpot: it's the **only** class that stacks Haste to the
40% cap AND four Rubies with zero mana penalty, so under optimal builds it
takes three of the top four boss slots.
- **Shadow** — boss #1, pack #2: cap-exempt crit riders + crit_dmg row-4,
  converging fan, Phantom refunds. The clearest #1 in the game.
- **Blood** — boss #3 at its full-HP floor; blood_amp reaches toward Shadow
  as you bleed, and the surge self-heals. Pack #4 (pierce cap holds it
  under Shadow).
- **Poison** — the riser: boss #4, pack #5 (90/95), fastest toxin stacker,
  plus ENFEEBLE evasion + HOBBLED. Now genuinely top-tier on both axes, not
  just a utility DoT.

### Archer — the widest identity split
Best boss theme is its worst pack theme and vice versa; built to re-theme
at boss doors. Runs **Combo** (Multishot 12mp / Arrow Storm 20mp starve
under Haste).
- **Hunt** — boss #2 at zero risk; pack liability (16/95 adds). Correct.
- **Venom** — boss #6 now (Serpent's Due +40% vs its always-poisoned
  target is huge), the safest spec in the game, ENFEEBLE cushion. Pack-weak.
- **Storm** — pack #7, boss floor; the lone-prey fork arcs back at 50%.

### Warlock — the attrition engine, and the pack king
Runs **Combo** (Hex 16mp / Rift 35mp starve under Haste). Bolt cadence +
wither ramp + unconditional lifesteal.
- **Pact** — pack **#1** outright under optimized builds; boss #10. The
  self-blast scales hard with Ruby; the 18% HP cost is the live gate.
- **Curse** — boss #5, pack #6, the versatile no-bad-matchup spec.
- **Void** — boss #12, pack #8; crush choreography, safest panic buttons.

### Mage — the glass farm engine
The mana law is its skill axis: Nova timing is throughput. Runs **Combo**
(Firebolt 4mp bleeds the pool).
- **Fire** — pack #3, boss #14 (mana-capped). The farm build.
- **Wind** — boss #8, pack #9; the mobile duelist.
- **Ice** — boss #13, pack #12; Killing Frost (+40% vs its always-slowed
  target) + brittle + control. Consistent, survivable, mid raw dps.

### Warrior — the juggernaut with free basics
Free basics (Cleave 0mp) → runs **Haste** to the cap. Plate identity: 80
physres, 15% flat DR, Grit. Highest ATK numbers on the board (550 Fury) —
the 4× Ruby on a big STR base.
- **Fury** — boss #7, the damage identity; tanky, low skill floor.
- **Earth** — boss #9, pack #14; control that pays at the door + pack pull.
- **Bulwark** — the cannot-die floor on both boards.

### Paladin — the stance knight, now a magic dealer
Conviction makes sustain and damage mutually exclusive in time; grades
assume Retribution camping. **Now deals MAGIC** (STR-primary but holy =
magic; checks magres, scaled by magpen). Free basics → **Haste**.
- **Wrath** — boss #11, pack #10; the damage stance, magic now.
- **Holy** — the sustain-for-damage trade on both boards (highest ATK, least
  of it lands). A survival kit.
- **Aegis** — the matchup spec; under-graded by passive bench targets (§10).

---

## 7. Mechanical ground rules the numbers rest on

- **Bosses are CC-immune.** Stuns/slows never land on bosses; they work
  fully on mobs and elites. Displacement is physics, not CC — but a "shove"
  moves a boss only 40% as far (`BOSS_SHOVE_FACTOR`).
- **Concussion:** a stun that fails on a CC-immune target converts to bonus
  damage (failed duration × `CONCUSSION_MULT` × ATK).
- **HOBBLED (49d):** the same conversion for slows — a failed slow on a boss
  scuffs its footing: +4% damage taken for 2.5s, DoT ticks included. Lifts
  the slow half of every control theme's budget at boss doors.
- **ENFEEBLE (49e/49f):** maintaining YOUR toxin turns its rot into your
  survival — toxin-gated (Poison-assassin / Venom-archer only). Assassin
  SLIPS the blow (up to +10% evasion atop Elusive); archer SHRUGS it (up to
  16% less damage). Bench-invisible (hero takes no damage) — pure survival.
- **Damage types (3/3 split):** physical = warrior/archer/assassin; magic =
  **paladin**/mage/warlock. Paladin flipped to magic this era — STR stays
  its recommended primary (builds ATK), hits land as magic vs magres/magpen.
- **DoTs resolve like hits** — mitigated by target res minus caster pen,
  ticks crit on the caster's sheet crit shaved by target critres. No hidden
  true damage; true damage is Death Mark's exclusive identity.
- **DoTs don't stack sources** (strongest wins) — **except toxin**
  (poison/venom): +12% tick depth per stack, 5 stacks.
- **Brittle** (ice): +4% ice-only amplification per stack, 5 deep.
- **Crush** (void): +22% to targets displaced hard in the last 1.5s.
- **Wither** (warlock): a MAINTAINED Hex deepens +8% per 6s, cap +64%.
- **EXPOSED (vuln):** +50% damage taken, works on bosses — the premier boss
  rider.
- **Specials come from GEMS + TALENTS only** (never gear or attribute
  points). Talents can grant combo/lifesteal again as of this era's restore.
- **Ults ignore Haste** for every class; Combo never procs on ults.

## 8. Buildcraft — the optimization, measured

This is the max-DPS recipe the boards now run, and why:

- **Attributes: all-in primary.** Primary gives the most ATK + a little
  crit per point; every off-attribute (VIT included) gives no ATK. 39/39
  in STR/AGI/INT for every variant.
- **Regular gems: 4× Ruby (ATK%), universally.** At Lv6 a Ruby is +22.8%
  ATK. CritDmg (Sunstone, +45.6% crit_dmg/gem) only overtakes ATK% above
  ~50% *effective* crit, and no variant gets there — even the crit specs
  land 26–34% after the 35% knee and boss critres shaving. So ATK% wins on
  every variant, crit and non-crit alike. (Pen gems lose too: the flat
  excess-conversion is small next to a +22.8% multiplier.)
- **Special gem: Haste if your abilities are free, Combo if they're not.**
  Haste ×4 hits the 40% cdr cap and is pure cadence — but it accelerates
  your *cooldown* abilities faster than mana can feed them. Warrior /
  paladin / assassin have free basics (0–1 mp) → **Haste**. Archer
  (Multishot 12, Arrow Storm 20), mage (Firebolt 4, mana-bound), warlock
  (Hex 16, Rift 35) starve under Haste → **Combo**, whose refund sustains
  the casts. This is the single biggest build fork, and it's why the
  **manaless assassin is structurally on top** — it's the only class that
  gets Haste *and* full Ruby with zero mana tax (§10).
- **Talents: best-DPS cell per row.** Rows 1–3 take the damage cell (atk%,
  crit, pen, or the theme rider); row 4 takes atk% for everyone except
  Hunt/Shadow (crit_dmg — the two whose crit clears the node's threshold).
  Theme-specific standouts: **Serpent's Due** (Venom: +40% vs poisoned, and
  its dots always poison — a near-permanent +40%), **Killing Frost** (Ice:
  +40% vs chilled, always slowed). The unavoidable 9-point "filler" goes in
  each class's weakest/defensive row (mage/warlock row 1 has no dps cell).

## 9. Meta mixes (unmeasured — the next bench docket)

Mono grades are baselines; per-slot theme mixes are the real endgame.
Hypotheses worth measuring, in likely-strength order:
- **Archer loadout swap** — full Hunt at boss doors, full Storm in rooms.
  Both halves are measured above; free re-theming makes this the intended
  play, not really a "mix."
- **Assassin** — Blood a1/a2 + Shadow a3/ult: echo loop + crit fan/execute.
- **Mage** — Wind a1 + Fire a2/ult: duelist bolts, pack nova/meteor.
- **Warlock** — Curse a1/a2 + Pact a3: wither engine + pack blast.
Do NOT balance against mixes until measured; the mono boards are the baseline.

## 10. Standing watch items

- **THE FINDING — manaless assassin dominance.** Under optimized builds the
  assassin takes boss #1/#3/#4 and pack #2/#4/#5, because being manaless is
  the one build that pairs Haste-to-cap with full Ruby stacking at no mana
  cost. Every other class trades cadence for mana sustain (Combo) or starves
  (Haste). This is *structural*, not a number — if it's judged too strong,
  the lever is the assassin's damage multipliers or a manaless-specific
  cost, NOT the gem system. Logged as reality; no change made this pass.
- **The old target ladder no longer holds.** Round 49 tuned the roster to a
  hand-authored order under save-copy builds; optimal builds reshuffle it
  (Poison boss #13→#4, Venom #12→#6, Fire #11→#14, the Fire~Poison~Venom
  tie broken). §2 is now a measured re-baseline. Future tuning should aim at
  *this* order, or a new intentional target, not the retired round-49 one.
- **Pact vs Fire for the pack crown** — Pact overtook Fire (7291 vs 6720)
  once 4× Ruby amplified its self-blast harder than Fire's splash. Both plus
  Shadow are a ~8% tie band at the top of the pack board.
- **Blood's real ceiling** (blood_amp at low HP) is invisible to the full-HP
  bench — real-fight Blood brushes Shadow. A regression only if it out-paces
  Shadow while SAFE.
- **Aegis is under-graded by construction** — passive bench targets never
  trigger its reflect. Judge it from `[fight]` reports vs aggressive bosses.
- **Pact's HP price is free on the bench** (nothing hits the hero); live
  pack-Pact is a notch lower and riskier than its #1 suggests.
- **The mage mana law** couples half the mage column to three knobs
  (Firebolt cost, mage regen, Nova refund) — touch any and re-run both boards.
- **Downtime not re-run on optimized builds** — the DoT-retention finding
  (§4) is from the save-build era; qualitatively it still holds, but a fresh
  `--downtime` sweep would refresh the exact percentages.

## 11. How to update this document

1. Change a kit or tuning number.
2. `dps_bench.bat` (boss) and `dps_bench.bat --aoe` (pack); `--downtime`
   when a DoT-vs-burst question is in play. Sub-5% deltas are ties; disputes
   take 2–3 runs. Read the reports (they're **UTF-16** — decode, don't grep
   raw for ASCII).
3. Confirm the bench presets (`TREE_PRESETS` / `GEM_PRESETS` in
   `dps_bench.gd`) are still the per-variant optimum — a kit change can move
   the optimal build (§8).
4. Paste the new boards, re-grade §3 (survivability/utility changes move §3
   without touching the boards), update the §2 measured order, and log the
   round in BALANCE_HISTORY.md (newest at top).
