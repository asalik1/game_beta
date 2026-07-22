# Masterwork Gear — the post-campaign power chase (proposed 2026-07-21)

**UNLOCK RULING (owner, 2026-07-21, same day):** Masterwork unlocks on
**Act 3 completion**, and is designed for the 100+ game — the Depths blocks
and the Nightmare/Torment tiers. It is deliberately NOT a campaign system:
the campaign never has to price it in (powercreep curbed at the root), and
the deep game's identity becomes exactly three questions — masterwork
progress, gem grind, and whether you assembled a cohesive build. The final
piece of the puzzle, unlocked when the puzzle's edge is complete.

This re-frames the original hole this doc opened on: under the RUNES.md
2026-07-21 revision, **L41–70 is the rune/vessel arc (Act 2) and L71–100 is
the named-S passive chase (Act 3)** — the campaign bands are filled by
itemization breadth, not masterwork. Masterwork owns what comes after the
cap, where nothing else grows. Each band teaches ONE new system; the five
crafting axes never arrive as simultaneous open questions.

**The idea in one line: the reforge bench learns to EVOLVE an S piece —
Masterwork +1..+5 — consuming gold and a sacrificed duplicate S piece per
step, raising the piece's magnitudes (never its stat types).**

*(Same-day companion: the RUNES.md 2026-07-21 revision — generic S is the
shared VESSEL of both systems: extracted rune = behavior, masterwork =
magnitude, gems = stats. Build your legendary, or find Act 3's named one.)*

## Why this shape

- **A chase, not an income.** 71–100's hole isn't missing stats — it's missing
  *acquisition events*. Masterwork makes every S drop after your first a
  MATERIAL (hunt), and every step a bench decision (craft). Four slots × five
  steps = 20 chase events across 30 levels — a meaningful step every ~1.5
  levels, matching the "build step ≈ 2–4 runs" doctrine.
- **No new currency.** Costs are gold (the deliberate sink, extended into the
  band where gold bloat was flagged) + a duplicate S piece of the same slot
  (the dupe that used to be a 31g sell). The Depths' checkpoint S-rolls
  (depth 70+) and Torment's S band become the material faucets — the mode
  that exposed the hole feeds its fix.
- **No new grade letter.** F→S stays the whole alphabet the player ever
  learns; Masterwork is a visible `MW+n` on an S piece (name glint + border
  notch per step, full glow at +5 — cosmetics are free). Legibility survives.
- **Identity law unchanged:** Masterwork raises MAGNITUDES only. It never adds
  stat types, never touches specials (gem-only, no exemptions), never grants
  speed. The S weapon's signature passive is untouched (awakening stays its
  own quest-gate); if a passive ever scales with Masterwork it's a separate,
  explicit decision per weapon.
- **MT4 guard, structural:** Masterwork results are CHARACTER-BOUND —
  unsellable, untradeable, forever. When the social layer's market lands,
  masterwork can never become sold power; only the raw S materials circulate.

## Numbers (first cut — measure-then-correct against real Act 2/3 enemies)

- **Magnitude:** +4% of the piece's stat budget per step → a full MW+5 set
  ≈ **+20% total power**, spread across the 30-level band (~0.7%/level —
  comfortably under the ~5.5%/level ceiling rule, and roughly one A→S step's
  worth of growth re-earned). Knob: `MW_STEP_BUDGET := 0.04`.
- **Cost curve (per step, per piece):** rides the upgrade-curve precedent
  (each tier doubles; S upgrade step = 192g base): MW+n costs
  `MW_GOLD_BASE × 2^(n-1)` with MW_GOLD_BASE ≈ 2× the S+3 total (~2.3k) →
  ~2.3k / 4.6k / 9.2k / 18.4k / 36.8k, plus one same-slot S dupe each.
  At frontier farm rates (~180+ g/min) the +5 step alone ≈ 3–4 runs — the
  late steps are the long-tail chase, the early ones the on-ramp.
- **Full journey:** 4 slots × (5 dupes + ~71k gold) ≈ 20 S dupes + ~285k gold
  — sized as the primary 71–100 arc alongside Lv10 gems. Dupe supply-rate is
  the real pacing dial: tune `S` faucet rates so a slot's dupe arrives every
  ~2–3 sessions, gold never the binding constraint before +4.
- **Boss-curve interaction (resolved by the unlock ruling):** the 2-minute
  ruling at depth 100 is benched against a max-spec, masterwork-FREE build —
  and that's now definitionally correct, since MW unlocks at Act 3
  completion and ramps only inside the 100+ blocks, where the overcap rails
  + debuff stacks absorb the growth. The knob to watch instead: the spread
  between a fresh-100 build and a full MW+5 roster inside the SAME
  Nightmare-block ladder — that's what per-tier records are for.

## Companion lever — the L80 soft-cap lift (already in doctrine)

The itemization doctrine notes "late-game cap-lift by level (~L80), NOT
built." Ship it WITH masterwork: soft-cap knees (crit 35 / eva 50 / haste 40
/ lifesteal 35 / combo 30) rise ~+1 point every 2 levels past 80 (+10 at
100). Masterwork gives the magnitudes; the lift gives them somewhere to go —
without it, MW points past a knee pay 1/10th and the chase feels like a lie.
Knob: `SOFTCAP_LIFT_PER_LEVEL := 0.5` past `SOFTCAP_LIFT_START := 80`.

## What stays deliberately untouched

- **Gems** remain the marathon currency (slow is correct for the glue) and
  the Depths' quality curve keeps feeding them.
- **Mastery/keystones** stay the 41+ BUILD layer per the locked 2026-07-08
  design (rule-flips + potency riders) — masterwork is the treadmill,
  keystones are the identity. (If the standing ruling is now "mastery grants
  zero power," the locked spec's riders need an explicit revisit — flagged.)
- **Attribute points** unchanged.

## Build order

Act 2/3 era, alongside the difficulty-tier Torment decision — the S-band
faucet (Torment loot shift, DIFFICULTY_TIERS.md) and masterwork's material
economy are one design conversation. Prereqs: none technically (the reforge
bench, dupe detection, and bound-flag plumbing all exist); the gate is
calibration content, per measure-then-correct. When built: bench presets gain
`--mw=N`, econ_audit gains the dupe faucet, and the codex gear card teaches
the bench recipe.
