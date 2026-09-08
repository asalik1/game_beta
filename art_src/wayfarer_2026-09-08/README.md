# Tovin's road home: source and reproduction

Built-in ImageGen, September 8 2026. Identity reference: the existing
`game/assets/sprites/npc_wanderer_anim.png`. The existing warrior walk E
supplied a motion reference only; no warrior asset was altered.

Three generations: `prompt.md` produced an eight-pose shuffle; `prompt_second.md`
produced a six-pose profile with the same leading foot. Both were rejected.
`prompt_third.md` edited the second sheet to add narrow passing poses and a
clearer compact gait. The accepted six-frame master is `masters/walk_passing.png`.
Its whole figures, face, clothing, backpack and staff were inspected before use.

Reproduction (existing repo tool; no new pixel painting or limb composites):

```
python tools/art/install_gait_row.py --old game/assets/sprites/npc_wanderer_anim.png --row art_src/wayfarer_2026-09-08/masters/walk_passing.png --out art_src/wayfarer_2026-09-08/built/wayfarer_walk.png --frames 6 --gutters --anchor torso --no-tone --no-orphans --report
```

The installer keys/despills, cuts at empty gutters, applies ONE common scale
and places the complete figures at the idle's feet line. Six 256-square cells,
1536×256 RGBA; source master retained untouched. The installed sibling asset is
`game/assets/sprites/wayfarer_walk.png`, with generated mipmaps. Existing NPC
portraits are unchanged. Generated-art verification: zero failures, one benign
antialias warning. Green rim scan: zero defects.

Live engine samples show the walk at 88px body height, 96 world units/second,
8 frames/second, plus stationary rest. Final behavior and validation are in
ONE_MORE_MILE.md and AUTONOMOUS_STATUS.md. No external generation service used.
