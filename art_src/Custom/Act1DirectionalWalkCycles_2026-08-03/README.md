# Act 1 gait correction v4 (2026-08-03)

The first directional pass used compound 5x4 ImageGen sheets.  Those sheets
were good direction/identity references, but several four-frame rows repeated
the same leading foot.  Visual inspection alone did not catch enough of them.

The spider sources in this directory replace that workflow completely: every
`spider_walk_<dir>_cycle.png` is one four-frame animation cycle produced by its
own built-in ImageGen call.  No east/west cycle is a mirrored reuse.  Prompts
spell out opposing diagonal contact groups, lifted passing legs, eight visible
legs, a fixed torso, and a fixed ground line.  The west cycle received one
targeted identity-only edit to remove a purple head cast without restaging the
legs.

For two-legged, rooted, and quadruped mobs, repeated single-cycle prompt tests
still occasionally repeated one leading limb—even with a colored motion
storyboard.  Production therefore uses a deterministic follow-up:

```powershell
python tools/art/build_act1_directional_walks.py
python tools/art/enforce_act1_gait_alternation.py --source game/assets/sprites --out game/assets/sprites
python tools/art/enforce_act1_gait_alternation.py --source game/assets/sprites --audit-only
```

For north/south cycles, the enforcement pass preserves each generated upper
body exactly and derives opposite contact/passing phases only inside an
anatomy-specific lower-limb mask. For east/west and diagonal cycles, it keeps
all four authored poses in their original order; a full lower-body reflection
is forbidden because it can make a foot travel opposite the torso. Only the
lowest toe/boot band may be corrected toward the body's facing direction.

The audit rejects four-frame strips unless frames 1/3 and 2/4 have measurably
different lower silhouettes. QA contact sheets include all eight directions,
not a three-direction sample. Banshee is intentionally excluded: it floats and
animates its arms/tattered hem rather than pretending to have feet.
