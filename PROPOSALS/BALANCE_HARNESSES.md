# Balance Harnesses — two deferred instruments (parked 2026-07-21)

Owner call: build these AFTER Act 2 is sorted. Both are the same move as
preflight and `dps_bench --depth`: a standing principle converted into a
machine check, so it stops depending on someone remembering it during
review. Parked here with enough spec to build cold.

---

## 1. The Kiter Gate — mechanize floor-vs-ceiling

**The principle (standing boss-design rule):** every boss needs IMPOSED,
non-opt-in damage that reaches a KITER. `if dist < X` rings are opt-in
tells, not pressure. Caster-lineage bosses pass by construction;
charge-lineage bosses fail without a second threat. Today this is enforced
by taste during review — the 2026-07-09 anti-kite pass (fangmaw ground-rake,
cinderhide ember rain ungated, sexton 3-tell cluster) exists because the
rule was applied by hand, late.

**The instrument:** a headless bot fight, one per boss — `kiter_gate.bat`,
a `dps_bench`-family balance tool (never a test tier):

- Spawn the real boss (`Boss.make_boss`) in the bench arena vs a scripted
  ARCHER bot that plays perfect distance: hold `keep` range, strafe on an
  arc, sidestep telegraphs with perfect reaction — and never attacks
  (mode A: pure threat floor) or attacks on the bench rotation while
  kiting (mode B: realistic kiting DPS-vs-danger).
- Drive through the intent seam like the net suite does (synthesized held
  keys / direct intent writes) at `--fixed-fps 60`.
- Measure: **imposed damage per minute on the perfect kiter** (mode A),
  time-to-kill and damage-taken (mode B).
- **Verdict:** PASS if imposed DPM ≥ a Balance floor (knob:
  `KITER_GATE_MIN_DPM`, sized so "two mistakes of pressure per minute"
  reaches even a perfect kiter). Print the per-boss table, exit nonzero on
  any FAIL — a regression gate for every FUTURE boss.

**Self-validation on day one:** the expected verdicts are already written
down — casters pass, the three fixed chargers now pass BECAUSE of their
2026-07-09 additions (removing the fissure/rain/cluster should flip them
red; that reverse check proves the harness). Any new Act 2 boss (BOSSES.md
ch8+) runs the gate BEFORE its review, so the floor-vs-ceiling argument
happens against a number, not a hunch.

**Build timing nuance:** most valuable if it lands WITH Act 2 boss
authoring (gates each new boss as it's written), not after.

---

## 2. The Skill-Curve Sim — degraded-input bots

**The blind spot (named, standing):** tuning happens at the owner's own
skill level, with no external playtesters. The reward doctrine
("safety→skill: reward climbs with skill/risk") describes a CURVE, but only
its top point ever gets measured — the bench plays perfectly.

**The instrument:** skill PROFILES for the `dps_bench` driver — the same
player build, degraded the way real hands degrade:

| Profile | Reaction delay | Dodge success | Rotation uptime | Potion discipline |
|---|---|---|---|---|
| ceiling (today's bench) | 0ms | 100% | 100% | perfect |
| mid | ~250ms | ~70% | ~85% | drinks late |
| floor | ~500ms | ~40% | ~65% | panic-drinks |

(Numbers are first guesses — knobs in Balance, calibrated once against one
real recorded playtest of the owner playing deliberately sloppily.)

- Run class × theme × profile grids vs at-level bosses (and `--depth`
  scenarios) with damage-taken live, not just DPS: the bot actually eats
  the hits its profile fails to dodge.
- **What it answers mechanically, per fight:** does TTK stay inside budget
  ×1.5 for MID? Does FLOOR survive at all? Do the forgiveness classes
  (warrior/paladin) degrade gently while the execution classes (mage/
  assassin) lose their 10–15% ceiling edge — i.e. does the class doctrine's
  intended crossover actually happen, and at which profile?
- Output: a grid with red cells where the curve breaks — the thing a
  below-owner-skill playtester would have said, approximated for free,
  re-runnable every balance round.

**Composition:** pure extension of `dps_bench` (profiles wrap the existing
rotation driver + take_damage path; the --depth debuff/budget mirror from
2026-07-21 already proves the pattern). No game code changes — instrument
only.

---

## Shared build order

After Act 2 content exists (owner call 2026-07-21) — with the one nuance
that the Kiter Gate wants to arrive alongside ch8+ boss AUTHORING rather
than after it. Both land as balance instruments beside dps_bench in
`tools/INDEX.md` when built.
