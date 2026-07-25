# CH2_RETROFIT_TASKS — the reward-hole graph retrofit (board, 2026-07-24)

One owner per task; claim before starting (the MP_TASKS/CH2_TASKS etiquette;
CLAUDE.md multi-agent section governs). Content lands as edits to ch2's zone
data + this board's checkpoints — NOT by inflating reward numbers
(DESIGN.md open item #1, verbatim: "fix by graph-retrofit").

## Why (measured, econ_audit 2026-07-24 — the numbers that make the case)

| | ch2 today | ch3 (the reference) |
|---|---|---|
| Rooms | **10** (6 combat / 3 boss / **0 social / 0 dead-end / 0 res**) | 21 (10 / 3 / 2 / 2 / 2) |
| Replay g/min | **36.5 — worst in the game, now UNDER ch1's 38.8** | 70.7 |
| Caches | **0 g** | 41 g |
| Elites/run | **1.1** | 2.6 |
| Kills/run | 66 | 117 |

The hole is STRUCTURAL: social/dead-end/resonance rooms carry the premium
path (elites ≈ 60% of run gems, hidden caches ~25% of dead ends, shrine ~22%
of quiet rooms, cursed chest ~15% of combat rooms — ALL seeded automatically
by room TYPE), and ch2 has none of those room types. Add the rooms and the
economy heals itself through existing seeding; no knob touches.

## Constraints (standing rules that bind every task)

- **Fixed chapter XP:** ch2's first-run total is **2963** (audit) — the
  retrofit must land within ±3% of it. New packs use the spawn tuple's 6th
  param (authored XP override, the mob-distribution-round tool) to
  redistribute the SAME budget across more rooms; replays pay 0 XP anyway.
- **Room banding** (mob-distribution round): ~3 melee-heavy (openers keep
  the teaching role) / mixed 25–45% core / 2–3 ranged-heavy artillery rooms.
  **Howling Fields is THE beastkin skirmish line** (wildkin_ranger +
  beastkin_howler) — keep its identity; cross-chapter imports at level
  overrides for ranged variety (the established pattern).
- **Maren's Camp (content/ch2_hub.gd) is untouched** — it is already the
  social anchor (13 NPCs, faction recruiters). The retrofit adds SIDE
  geography, not hub changes.
- Terrain: ch2's authored terrain families only; forest stays building-free
  (zone-authored scenery rules).
- Target after retrofit: ~19–21 rooms in the ch3 shape; replay g/min lands
  ~55–65 (between ch1 38.8 and ch3 70.7, on the level curve) — MEASURED,
  not assumed (task 4).

## Tasks

### CR-1: Test-coupling inventory — status: PENDING (do FIRST, read-only)
Files read: `tests/test_ch2.gd`, `autotest.gd` (ch2 campaign sections)
Only 3 room-coupling greps in test_ch2.gd (light — the runner appears to
navigate by quest/boss flow, not room indices), but inventory EVERY
assumption (room counts, boss zone indices, named-room references) before
any authoring. Deliverable: a list appended to this board of exactly which
assertions the new graph will move. FLAG for the orchestrator/owner: fixes
to existing test sections need a ruling against the "never edit existing
sections" rule (precedent: the ch1 retrofit adapted its tests — this is the
same situation, but get the ruling first).

### CR-2: Graph re-author (the mechanical half) — status: PENDING (after CR-1)
Files: ch2 zone data (story.gd or its content module — locate first), spawn rows
Expand 10 → ~19–21 rooms: +2 social, +2 dead-end (cache-eligible), +2
resonance, +2–3 combat (banded per the constraints). Positions/pack
structure follow the ch3 idiom; kind-swap + import for ranged variety.
Placeholder room names OK at this stage ("Waking Side-Path A") — CR-5 is
the naming/fiction pass. XP overrides pin the 2963 budget as rooms land.

### CR-3: XP-budget probe — status: PENDING (with CR-2, iterative)
Before/after probe per the mob-distribution round: sum authored pack XP
through the 30+22·lvl curve; land within ±3% of 2963. Rerun per authoring
iteration — never once at the end.

### CR-4: Econ re-measure + table update — status: PENDING (after CR-2 settles)
`econ_audit.gd` on the new graph → ch2 replay g/min in the 55–65 band →
update `Balance.CHAPTER_ECON` ch2 row + BALANCE_HISTORY round entry +
DESIGN open-item #1 closure. If the number lands OUTSIDE the band, report —
don't tune knobs to force it (the room mix is the lever).

### CR-5: Fiction + naming pass — status: PENDING — **OWNER-TASTE: propose, don't finalize**
Room names, any convo beats for the new social rooms, resonance-room shard
choices (one-time, grounded-only rule, symmetric ranges per the 33-choices
round). Deliverable: a proposal list on this board for the owner's review —
agents draft, the owner picks. The 6-point content-authoring checklist +
codex zone audit apply to whatever ships.

### CR-6: Gates + suites — status: PENDING (last)
Full ladder: compile → test_quick → **full test.bat (it PLAYS ch2 end to
end — the real gate)** → preflight → sync_mobile --apply --gate →
path-scoped commit. CR-1's ruling governs any test edits.
