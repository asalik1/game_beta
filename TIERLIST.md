# Crownless — Class & Theme Tier List

**Re-baselined 2026-07-09** against the post-review systems. Everything below is
MEASURED on the DPS bench at this date's HEAD (after: the typed-gem/flat-Ruby
overhaul, the shadow marked-crit rework, plate earned-DR + res→damage log curve,
the late-boss damage ramp, the Cleave floor, the hunt 4th-shot rhythm, the
Bulwark/Aegis guard trim, the dominated-talent rework, and the sticky
soft-target aiming change). The previous edition described two retired eras
(4×Haste stacking, Ruby-as-%, hunt's free +25% crit) — treat any older copy as
historical.

Grades weigh three axes, in the project's order: **loop first** (does the spec's
minute-to-minute play express skill?), **ladder second** (where it lands on the
measured boards), **numbers last**. Survivability counts — the endgame thesis is
bullet-hell, where plate's earned DR and the new capstone defense talents are
worth real ladder places.

**If you read one thing, read §3** — the holistic F–S ranking. §4/§5 are the
raw boards it rests on; §8 is why the numbers look the way they do.

---

## 1. The instrument

`dps_bench.bat` — L40 hero, full A gear (seeded rolls), Lv6 gems, mono-theme,
DPS-optimal talents, playstyle-constrained rotations, 180s vs an immortal
average-L40-boss dummy (CC-immune, boss hitbox, real res sheet). `--aoe` swaps
in the 3-pillar pack + expendable add waves (effective damage, pooled).
Since the last edition the bench gained: `--level/--grade/--gemlvl` (arbitrary
kit), `--boss=<kind>` (a specific boss's sheet), `--defense` (EHP/damage-taken
readout), and `--rep=N` + `dps_bench_rep.ps1` (N parallel independent-RNG runs
→ a clean mean; crit specs swing ±15% run-to-run — never trust one roll).

Gem loadout under the typed-slot rule: the 4 special slots take the only three
damage specials (`dmg_pct`, `combo`, `cdr`) + `lifesteal`; every regular slot a
FLAT Ruby. Greed is farm-only (and no longer a gem — Tenacity/`flat_dr` took
its slot). `cdr` is universal — it cannot starve mana, it only speeds casts
when mana is there.

**Context anchor:** a realistic first-run kit (B gear + Lv2 gems) benches at
~52% of these numbers with the SAME ordering — the ladder shape is
gear-invariant; only the magnitude moves.

## 2. The measured order (single runs; shadow's 6-run mean is 3574)

> **Boss:** Shadow ≫ Hunt > Venom ~ Wind ~ Curse ~ Blood > Poison > Pact ~
> Void > Fire > Storm ~ Fury ~ Earth > Ice > Wrath ≫ Aegis ~ Holy ~ Bulwark
>
> **Pack:** Shadow > Poison > Fire ~ Pact > Storm ~ Curse ~ Void ~ Wind >
> Blood > Venom > Hunt ~ Ice > Fury ~ Wrath ~ Earth > Holy ~ Aegis ~ Bulwark

The mid-board is a healthy tie band: ranks 3–7 on the boss board sit within
~5% of each other — matchup and pilot taste decide, not the sheet.

## 3. Overall holistic tier (F–S)

| Tier | Spec | Why |
|------|------|-----|
| **S** | Assassin · Shadow | Boss #1 (3837; 3574 six-run mean) and pack #1 (6554). The lead is priced: part of the boss number is the accepted fan-spam sim tax (~4.1 of 5 knives land on a boss the sim lets you camp; real fights don't), and the crit is now EARNED (Death Mark window) + built, not free. Squishy, manaless, highest skill ceiling in the game. |
| **A** | Archer · Hunt | Boss #2 (3129) on the new 4th-shot rhythm — power-neutral with the old free-crit era but the crit is a played cadence now. Pack-blind by design (3184, 14/95 adds). The single-target specialist. |
| **A** | Assassin · Poison | Pack #2 (5619, 90/95 adds reaped) with a real boss floor (2708). The DoT tax is priced correctly and the bloom does its job in crowds. |
| **A−** | Mage · Wind | Boss #4 (2957) AND top-half pack (4359) — the best generalist mage since the mp-2/cdr era let caster cadence scale. |
| **A−** | Warlock · Curse | Boss #5 (2881), pack 4520 — the attrition engine holds both boards; wither ramps reward long fights. |
| **A−** | Archer · Venom | Boss #3 (2958), pack 3996 — quietly excellent on both boards; toxin uptime is trivial (see §10: Serpent's Due). |
| **B+** | Assassin · Blood | Boss 2838 at FULL HP — blood_amp stretches toward Shadow as the pilot bleeds; the most self-sufficient melee. Pack fine (4277). |
| **B+** | Mage · Fire | Pack #3 (5231, 90/95) — the farm engine; boss 2261 is its tax. |
| **B+** | Warlock · Pact | Pack #4 (5126) once Dark Pact is point-blank; boss mid (2392). The HP price is free on the bench — live Pact runs a notch riskier. |
| **B** | Archer · Storm | Pack 4693 at 26 hits/s; boss 2186 even with the ric-back floor. The AoE archer. |
| **B** | Warlock · Void | Crit-flavored burst (peak 5270 in packs) but mid on both boards (2363/4487). |
| **B** | Warrior · Fury | Boss 2167 under the Cleave floor, pack 2832 — but plate survives what squishies dodge (earned DR off physres, Grit feeds on hits). The easy-to-pilot bruiser; endgame density is where it collects. |
| **B−** | Warrior · Earth | Fury's numbers (2139/2681) with control flavor; same plate credit. |
| **B−** | Mage · Ice | 2021/3075 — the control tax on a glass body; Killing Frost helps but the loop is the slowest in the class. |
| **C+** | Paladin · Wrath | 1879/2831 — the paladin's damage pole, still trailing warrior. Magic-lean tank credit (wards spell), and the stance-swap shield talent adds real play. |
| **C+** | Paladin · Holy | 1323 dps is the price of the game's strongest sustain stance; the safe/slow pole is deliberate — graded for players buying the floor. |
| **C** | Paladin · Aegis / Warrior · Bulwark | 1269–1334 dps tank poles. Post guard-trim they finally pay gear-res opportunity cost like everyone else. Easiest pilots in the game; lowest ceilings. Fine as identities, weak as mains. |

No F tier: the dominated-talent rework and the caster-cdr era pulled every
spec's floor into playable range.

## 4. The boss board (single target, 180s, verified this date)

| # | Spec | DPS | hits/s | crit | notes |
|---|------|-----|--------|------|-------|
| 1 | assassin/shadow | 3837 | 17.0 | 23% | mean 3574 over 6 runs; marked-window crits |
| 2 | archer/hunt | 3129 | 5.7 | 36% | 4th-shot rhythm + built crit |
| 3 | archer/venom | 2958 | 6.7 | 13% | toxin stack + Serpent's Due |
| 4 | mage/wind | 2957 | 7.4 | 10% | echo flurry, cdr era |
| 5 | warlock/curse | 2881 | 4.6 | 8% | wither ramp, peak 3641 |
| 6 | assassin/blood | 2838 | 14.8 | 18% | full-HP floor; amp climbs as you bleed |
| 7 | assassin/poison | 2708 | 7.5 | 10% | DoT tax priced |
| 8 | warlock/pact | 2392 | 3.6 | 11% | no Dark Pact at boss range |
| 9 | warlock/void | 2363 | 3.6 | 21% | crush windows |
| 10 | mage/fire | 2261 | 4.9 | 5% | splash wasted on one body |
| 11 | archer/storm | 2186 | 9.3 | 22% | ric-back single-target floor |
| 12 | warrior/fury | 2167 | 8.6 | 14% | Cleave floor holds the cadence |
| 13 | warrior/earth | 2139 | 7.6 | 8% | quake flavor |
| 14 | mage/ice | 2021 | 3.4 | 11% | control tax |
| 15 | paladin/wrath | 1879 | 7.4 | 11% | retribution stance |
| 16 | paladin/aegis | 1334 | 4.1 | 6% | tank pole |
| 17 | paladin/holy | 1323 | 5.4 | 5% | sustain pole |
| 18 | warrior/bulwark | 1269 | 4.2 | 9% | tank pole, post guard-trim |

## 5. The pack board (AoE — 3 pillars + add waves, verified this date)

| # | Spec | DPS | adds | notes |
|---|------|-----|------|-------|
| 1 | assassin/shadow | 6554 | 29/95 | fans FOCUS pillars under sticky aim (§10) |
| 2 | assassin/poison | 5619 | 90/95 | bloom reaps the waves |
| 3 | mage/fire | 5231 | 90/95 | the farm engine |
| 4 | warlock/pact | 5126 | 87/95 | point-blank drain |
| 5 | archer/storm | 4693 | 88/95 | 26 hits/s fork storm |
| 6 | warlock/curse | 4520 | 87/95 | hex detonation chains |
| 7 | warlock/void | 4487 | 89/95 | rift peaks 5270 |
| 8 | mage/wind | 4359 | 87/95 | flurry |
| 9 | assassin/blood | 4277 | 19/95 | echo carries; pierce cap holds add reaping |
| 10 | archer/venom | 3996 | 70/95 | mist wake |
| 11 | archer/hunt | 3184 | 14/95 | pack-blind by design |
| 12 | mage/ice | 3075 | 87/95 | control, not clear |
| 13 | warrior/fury | 2832 | 36/95 | arcs reach the row, not the ring |
| 14 | paladin/wrath | 2831 | 68/95 | consecration coverage |
| 15 | warrior/earth | 2681 | 51/95 | quake |
| 16 | paladin/holy | 2049 | 75/95 | mends off every body |
| 17 | paladin/aegis | 1981 | 61/95 | |
| 18 | warrior/bulwark | 1717 | 24/95 | |

## 6. Class deep dives

### Assassin — the earned-crit flagship
Shadow's crit story is the doctrine's showcase: **marked/EXPOSED prey always
crits** (fires on bosses via vuln — unlike the old dead stun/slow condition),
Phantom Step refunds off ANY kill within 2s of the dash, and the flat theme
crit is gone — what's left comes from gear and the Death Mark window. Poison
owns crowds; Blood is the low-HP bruiser whose ceiling brushes Shadow when
piloted on the edge. Manaless remains the class's quiet superpower.

### Archer — one specialist per job
Hunt is the boss surgeon: every 4th Quick Shot is a guaranteed crit (white-hot
muzzle tell), so the DPS is a rhythm you play plus crit you build — benched
power-neutral with the retired free-crit era. Storm owns crowds, Venom owns
attrition, and the reworked Windrunner finally gives the glass body a capstone
floor: +15% DR for 3s **after a roll** — defense collected by dodging.

### Warlock — the attrition engine
Curse holds both boards mid-high; wither pays on long fights and hex
detonations chain in packs. Pact wants bodies in arm's reach. Void's crush-crit
line lands the biggest single hits in the class. Mana is deliberately the
tightest in the game — the drain-tank fantasy has a real budget.

### Mage — cadence unlocked
The mp-2 Firebolt + universal-cdr era ended the mage's turret age: Wind is a
top-half generalist, Fire remains the pack farm engine, Ice pays the control
tax. Permafrost now sheathes Nova/Blink casts in a max-HP shield — the glass
cannon's purchasable floor.

### Warrior — hits hard, not fast
The Cleave floor caps how far haste can spin the basic (Berserk alone breaks
it — the ult IS the tempo window), and plate's 15% DR is EARNED off physres,
so the tankiness is built, not granted. Fury/Earth sit mid-board on damage and
collect their real pay in density: at endgame hit sizes plate takes ~20–30%
per hit where squishies take 90%+.

### Paladin — the mirror tank
Magic-lean (50/75 res — wards spell as warrior wards steel), DR earned off
magres. Wrath is the damage pole, Holy the strongest sustain stance in the
game at a deliberate −20% damage, Aegis the wall. Unwavering Conviction now
shields every stance swap — the class finally has a reason to dance.

## 7. Mechanical ground rules the numbers rest on

- **Hit gate:** all incoming damage shares a 0.6s `hurt_cd` window — but
  telegraphed nukes are HEAVY and pierce a chip-armed gate (heavy-vs-heavy
  still gates). Timed i-frames (Tumble, dash-strike, Judgment leap, Death
  Mark) block heavies: a played dodge is absolute; a stray chip hit is not.
- **Crit:** 35% soft knee; past it a point pays ~1/5. Themed crit is
  cap-exempt only where it's EARNED (marked prey, 4th-shot rhythm, Nightfall's
  crush-only line) — no flat theme crit remains anywhere.
- **Ults ignore cdr** (every class); authored ult-cd talents still apply
  (Falcon's Patience is the only big one — watch-listed).
- **Plate DR is earned:** 0→15% as the signature res climbs to 130 (warrior
  physres, paladin magres); res→damage rides a log curve capped at 15%.
- **DoT tax:** attrition specs trail burst on boss TTK and repay on length
  and crowds — priced, not accidental.
- **Boss ramp:** worst hit ~30% of a squishy's HP at the intro → ~74% at the
  finale; nothing one-shots at baseline. Nightmare ×2 restores the old lethal
  read as opt-in difficulty.
- **Scaled bosses stay at parity:** above native level, boss HP tracks player
  DPS and boss damage tracks player EHP — TTK and hit-danger are
  level-invariant (an L100 finale is ~32s at BiS, not 30 minutes).

## 8. Buildcraft — the current optimum

- **Specials (one per stat, 4 slots):** `dmg_pct` + `combo` + `cdr` +
  `lifesteal`, every class. Only three specials add damage; lifesteal is the
  least-dead fourth. Tenacity (`flat_dr`, the old greed slot) is the survival
  swap for players buying the floor.
- **Regulars:** flat Ruby everywhere at the DPS optimum; Topaz (crit) becomes
  correct for shadow/hunt now that themed crit stopped saturating the stat.
  C-grade gear carries 1 regular socket (≤Lv2 gems) — the build system starts
  in ch4, not ch5.
- **Attributes:** all-in primary remains unchallenged.
- **Talents:** best damage cell per row; the row-2 utility rows are the
  designated filler dump — and the capstone rows now sell real defense
  (Windrunner / Permafrost / Unwavering Conviction) for anyone who'd rather
  buy a floor than a ceiling.

## 9. Meta mixes (unmeasured — the next bench docket)

Mixed-theme loadouts (e.g. Shadow a1/a2 + Poison a3, Fury Cleave + Earth
Quake) remain unbenched; the mono-theme constraint is the documented frame.
The `--downtime` telegraph-tax mode also hasn't been re-run since the boss
damage ramp — the DoT-vs-burst gap under forced movement is the next
interesting number.

## 10. Standing watch items

- **Shadow pack #1 at 6554** — up from ~5250: the sticky soft-target aiming
  change makes fans FOCUS the committed target, so more knives pool into
  pillars (hits/s 21→29) while add-reaping collapsed (81→29 of 95). Real
  current-game behavior, not a bench artifact — but it widened shadow's pack
  lead to ~17% over poison. If it grows or feels dominant in play, the fan
  spread is the shadow-only lever (0.15 today).
- **Melee add-reaping fell across the board** under sticky aim (blood 19/95,
  fury 36/95): kill-triggered loops (Phantom refund, hex chains) fire less
  for melee. Watch whether blood/fury AoE feel starved in real packs.
- **Serpent's Due**: +40% on all hits gated only by "target is poisoned,"
  which venom trivially maintains — priced as venom's payoff today; the
  largest trivially-satisfied multiplier in the trees.
- **Falcon's Patience**: −50% Arrow Storm cd at max — the game's only ult-cd
  lever; the optimizer doesn't take it, but it's the first suspect if storm
  archer ever spikes.
- **Hunt rhythm vs reality**: the bench's stationary boss lets every 4th shot
  land; in dodge-heavy fights the rhythm stretches in wall time. If hunt sags
  in play, the shot counter (4) is the knob.
- **Gold bloat late** (faucets scale ×5.68 by L40, sinks flat) — deferred to
  Act 2, where the mastery/keystone layer wants the sink anyway.
- **S-weapon parity is INTENTIONAL** (player ruling 2026-07-09): plate
  legendaries out-damage the others because plate scales less from damage
  stats — do not re-flag.
- **The mage mana law** still couples the mage column to three knobs
  (Firebolt cost, mage regen, Nova refund) — touch any and re-run both boards.

## 11. How to update this document

1. Change a kit or tuning number.
2. `dps_bench.bat` (boss) and `dps_bench.bat --aoe` (pack); for any spec a
   change targets, take a 6-run mean (`dps_bench_rep.ps1 --cls=X --theme=Y
   --runs=6`) — single runs on crit specs swing ±15%. `--downtime` when a
   DoT-vs-burst question is in play. Reports are **UTF-16** — decode, don't
   grep raw for ASCII.
3. Confirm the bench presets (`TREE_PRESETS` / `GEM_PRESETS` in
   `dps_bench.gd`) are still the per-variant optimum — a kit change can move
   the optimal build (§8).
4. Paste the new boards, re-derive §2, and only then re-grade §3
   (survivability/utility changes move §3 without touching the boards). Log
   the round in BALANCE_HISTORY.md (newest at top).
