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
The 2026-07-27 dps-bench round added `--uniques` (BiS named-unique passives on
every slot, `BenchBuild.BIS_UNIQUES`), `--wpassive=<id>` / `--gpassive=slot:id`
(candidate A/B overrides), and `--ttk` + `--hpmult=N` (MORTAL dummy carrying
the target boss's real pool — the honest frame for opener/execute passives,
which the immortal full-HP dummy either fakes permanently or never fires; the
L100 endgame board + the gear-power curve were tuned in this mode — see
BALANCE_HISTORY.md's dps-bench round; this file's L40 boards are unaffected).
The 2026-07-28 set-coverage round added `--setprof=A..E` (the six gear slots
wear the class's full profile SET — the set-vs-BiS probe; a `[bench] set
pieces:` line now prints each case's live set tiers), fail-fast on unknown
`--boss` ids (the Act-1 finale's KEY is `stormmouth` — "Cyrraeth" is display
name; a bad id used to error-loop the fan children forever), and a talent
trim on low `--level` runs (the preset is capped to the level's own ~1/level
budget, so TTK-band rungs measure era-honest kits).

Gem loadout under the typed-slot rule: the 4 special slots take the only three
damage specials (`dmg_pct`, `combo`, `cdr`) + `lifesteal`; every regular slot a
FLAT Ruby. Greed is farm-only (and no longer a gem — Tenacity/`flat_dr` took
its slot). `cdr` is universal — it cannot starve mana, it only speeds casts
when mana is there.

**Context anchor:** a realistic first-run kit (B gear + Lv2 gems) benches at
~52% of these numbers with the SAME ordering — the ladder shape is
gear-invariant; only the magnitude moves.

## 2. The measured order (2026-07-24 board; means where taken, singles else)

> **Boss:** Shadow > Curse > Venom ~ Hunt > Wind ~ Blood ~ Pact > Poison >
> Void > Fury > Fire ~ Ice > Storm ~ Wrath ~ Earth > Holy > Bulwark ~ Aegis
>
> **Pack:** Shadow > Pact > Curse > Fire > Poison > Void > Blood > Wind ~
> Storm > Wrath > Venom ~ Ice > Fury > Hunt > Earth > Holy > Aegis > Bulwark

The mid-board stays a healthy tie band — and this refresh measured the
variance honestly: single runs swing up to ~17% peak-to-peak (warlock/pact's
single read 3033 against a 6-run mean of 2707), so ranks inside a band are
taste, not truth. Means were taken for the movers (curse 3350, pact 2707,
holy 1413; shadow's standing mean 3574).

## 3. Overall holistic tier (F–S)

| Tier | Spec | Why |
|------|------|-----|
| **S** | Assassin · Shadow | Boss #1 (3628 this board; 3574 six-run mean) and pack #1 (6677). The lead is priced: part of the boss number is the accepted fan-spam sim tax (~4.1 of 5 knives land on a boss the sim lets you camp; real fights don't), and the crit is now EARNED (Death Mark window) + built, not free. Squishy, manaless, highest skill ceiling in the game — and Curse's mean now sits within ~6%: the first real challenger. |
| **A** | Archer · Hunt | Boss 3026 on the 4th-shot rhythm — power-neutral with the old free-crit era but the crit is a played cadence now. Pack-blind by design (2899, 21/95 adds). The single-target specialist. |
| **A** | Assassin · Poison | Pack 5175 (90/95 adds reaped) with a real boss floor (2621). The DoT tax is priced correctly and the bloom does its job in crowds. |
| **A** | Warlock · Curse | PROMOTED 2026-07-24 on a mean: boss #2 (3350 six-run mean, tight 8.4% spread — within ~6% of the flagship) and pack #3 (5859). The attrition engine arrived; wither ramps reward long fights. |
| **A−** | Mage · Wind | Boss ~2732 AND top-half pack (4094) — the best generalist mage since the mp-2/cdr era let caster cadence scale. |
| **A−** | Archer · Venom | Boss mean 3126 (same-night 6-run; the 3242 single was a high outlier), pack 3511 — quietly excellent on both boards, tie-band with Hunt; toxin uptime is trivial (see §10: Serpent's Due). |
| **A−** | Warlock · Pact | Pack #2 (6285, 90/95) once Dark Pact is point-blank; boss mean 2707. Promoted from B+ on the poison precedent (pack-top + real boss floor) — the live HP price still keeps it under Poison. |
| **B+** | Assassin · Blood | Boss 2731 at FULL HP — blood_amp stretches toward Shadow as the pilot bleeds; the most self-sufficient melee. Pack fine (4735). |
| **B+** | Mage · Fire | Pack #4 (5398, 90/95) — the farm engine; boss 2303 is its tax. |
| **B** | Archer · Storm | Pack 4023 at 23 hits/s; boss 2138 even with the ric-back floor. The AoE archer. |
| **B** | Warlock · Void | Crit-flavored burst (peak 11431 in packs) and top-half pack (5046); boss mid (2535). |
| **B** | Warrior · Fury | Boss 2413 under the Cleave floor, pack 3166 — but plate survives what squishies dodge (earned DR off physres, Grit feeds on hits). The easy-to-pilot bruiser; endgame density is where it collects. |
| **B−** | Warrior · Earth | Fury's shape (2076/2725) with control flavor; same plate credit. |
| **B−** | Mage · Ice | 2262/3442 — the control tax on a glass body; Killing Frost helps but the loop is the slowest in the class. |
| **C+** | Paladin · Wrath | 2085/3643 — the paladin's damage pole, still trailing warrior on bosses but a real pack presence now (90/95 consecration coverage). Magic-lean tank credit (wards spell), and the stance-swap shield talent adds real play. |
| **C+** | Paladin · Holy | 1413 dps (six-run mean) is the price of the game's strongest sustain stance; the safe/slow pole is deliberate — graded for players buying the floor. |
| **C** | Paladin · Aegis / Warrior · Bulwark | 1297–1350 dps tank poles (aegis mean 1350, same-night 6-run — the 1146 single was a low outlier). Post guard-trim they finally pay gear-res opportunity cost like everyone else. Easiest pilots in the game; lowest ceilings. Fine as identities, weak as mains. |

No F tier: the dominated-talent rework and the caster-cdr era pulled every
spec's floor into playable range.

## 4. The boss board (single target, 180s, verified 2026-07-24)

| # | Spec | DPS | hits/s | crit | notes |
|---|------|-----|--------|------|-------|
| 1 | assassin/shadow | 3628 | 16.8 | 24% | standing mean 3574; marked-window crits |
| 2 | warlock/curse | 3350* | 4.7 | 9% | *six-run mean (single 3343, spread 8.4%); wither ramp |
| 3 | archer/venom | 3126* | 7.4 | 15% | *six-run mean (single 3242, spread 12.5%); toxin + Serpent's Due |
| 4 | archer/hunt | 3026 | 5.5 | 35% | 4th-shot rhythm + built crit; mp-starve noted |
| 5 | mage/wind | 2732 | 7.4 | 18% | echo flurry, cdr era |
| 6 | assassin/blood | 2731 | 14.3 | 16% | full-HP floor; amp climbs as you bleed |
| 7 | warlock/pact | 2707* | 3.8 | 8% | *six-run mean (single 3033, spread 17.4%!) |
| 8 | assassin/poison | 2621 | 7.8 | 12% | DoT tax priced |
| 9 | warlock/void | 2535 | 3.6 | 26% | crush windows |
| 10 | warrior/fury | 2413 | 9.0 | 10% | Cleave floor holds the cadence |
| 11 | mage/fire | 2303 | 4.9 | 10% | splash wasted on one body |
| 12 | mage/ice | 2262 | 3.3 | 12% | control tax |
| 13 | archer/storm | 2138 | 9.8 | 16% | ric-back single-target floor; mp-starve noted |
| 14 | paladin/wrath | 2085 | 6.0 | 13% | retribution stance |
| 15 | warrior/earth | 2076 | 7.3 | 10% | quake flavor |
| 16 | paladin/holy | 1413* | 4.3 | 4% | *six-run mean (single 1620); sustain pole |
| 17 | warrior/bulwark | 1297 | 4.1 | 8% | tank pole, post guard-trim |
| 18 | paladin/aegis | 1350* | 3.1 | 6% | *six-run mean (single 1146 was a low outlier, spread 20%) |

## 5. The pack board (AoE — 3 pillars + add waves, verified 2026-07-24)

| # | Spec | DPS | adds | notes |
|---|------|-----|------|-------|
| 1 | assassin/shadow | 6677 | 29/95 | fans FOCUS pillars under sticky aim (§10) |
| 2 | warlock/pact | 6285 | 90/95 | point-blank drain |
| 3 | warlock/curse | 5859 | 90/95 | hex detonation chains |
| 4 | mage/fire | 5398 | 90/95 | the farm engine |
| 5 | assassin/poison | 5175 | 90/95 | bloom reaps the waves |
| 6 | warlock/void | 5046 | 90/95 | rift peaks 11431 |
| 7 | assassin/blood | 4735 | 27/95 | echo carries; pierce cap holds add reaping |
| 8 | mage/wind | 4094 | 84/95 | flurry |
| 9 | archer/storm | 4023 | 53/95 | 23 hits/s fork storm; mp-starve noted |
| 10 | paladin/wrath | 3643 | 90/95 | consecration coverage |
| 11 | archer/venom | 3511 | 75/95 | mist wake |
| 12 | mage/ice | 3442 | 80/95 | control, not clear |
| 13 | warrior/fury | 3166 | 43/95 | arcs reach the row, not the ring |
| 14 | archer/hunt | 2899 | 21/95 | pack-blind by design |
| 15 | warrior/earth | 2725 | 51/95 | quake |
| 16 | paladin/holy | 2550 | 90/95 | mends off every body |
| 17 | paladin/aegis | 2192 | 83/95 | |
| 18 | warrior/bulwark | 1792 | 24/95 | |

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

- **2026-07-24 board refresh findings:** the warlock family's rise is REAL
  (curse boss mean 3350 — within ~6% of shadow's 3574; if a future round
  lifts it further, the S conversation starts) and the archer/mage staleness
  flag is resolved (this board post-dates the mana-cost round). The two flagged
  singles were MEANED the same night: venom 3126 (A− stands — tie-band with
  hunt; the 3242 single was a high outlier) and aegis 1350 (C stands; the
  1146 single was a LOW outlier at 20% spread). Every §3 grade now rests on
  a mean or an in-band single. Variance lesson re-learned: pact's single
  read +27% while its mean moved +13% (17.4% spread) — never grade a mover
  off one run.
- **Paladin mp-starve across all three specs** (a1 starves ~2s in, ults 0 all
  board) — long-standing bench profile, but wrath's pack showing (3643,
  90/95) says the kit works around it; if paladin mains report dead buttons
  in real fights, Conviction's 30 mp is the first knob.
- **Shadow pack #1 at 6677** — up from ~5250: the sticky soft-target aiming
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
