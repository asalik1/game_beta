# Hazard pools + Berserk rage burst (2026-08-15)

Owner: "do the berserk squares and hazard pools too". Every floor hazard patch
(`game_world._add_hazard` — the terrain `patches` rolls, mob drops, the boss
lava/churned floors, MP relays) was one tinted procedural glow blob; the base
Berserk cast was a ring + 20 square particles.

Six ImageGen masters generated headless via Codex (`make_briefs.py` — imports
the RingFX brief skeleton; `tools/art/run_codex_batch.ps1` ran all six in
parallel, ~9 min at six-wide):

| subdir | strip | cells | role / wiring |
|---|---|---|---|
| `hazard_lava/` (green key) | `hazard_lava.png` 768x192 | 4 x 192, `--valign widest` | `lava` patch (magma terrain, mob magma sow, ch4 boss floor) — crusted molten pool, bubbles pop |
| `hazard_ice/` (magenta) | `hazard_ice.png` | 4 x 192 | `ice` patch — glare-ice sheet, glints + frost wisp |
| `hazard_heal/` (magenta) | `hazard_heal.png` | 4 x 192 | `heal` patch (holy terrain springs) — golden ripples + motes |
| `hazard_slow/` (green) | `hazard_slow.png` | 4 x 192 | `slow` patch (void terrain) — void sludge, swirl + bubbles |
| `hazard_churned/` (green) | `hazard_churned.png` | 4 x 192 | `churned` (Sexton's grave-earth, boss-only) — heaving soil + bones |
| — | `fx/poison_pool.png` (PoisonMistFX, re-cut `--valign widest`) | 4 x 192 | `poison` patch (bog / spore / drifting spore clouds) — the assassin mist's venom pool |
| `rage_burst/` (green) | `rage_burst.png` 2048x256 | 8 x 256, `--valign widest` | warrior Berserk cast (base kit; hue-shifted per theme via `ELEMENT_HUE_SHADER`) — ring of fury-flame + heat shockwave, body under + 45% ghost over; skins keep their own sequences |

`game_world.HAZARD_STRIP` maps type → strip; `HAZARD_STRIP_OFFSET` holds each
strip's equator offset (the builder's "anchor row" line: lava +3, ice −3,
poison −16, heal −23, slow 0, churned −10) so the pool's centre is the hazard
circle's centre; scale = 2R / (192 × 0.8); frames step at a random 0.16–0.22 s
from a random start so neighbouring pools don't bubble in lockstep. Any type
without a shipped strip falls back to the old tinted glow.

Reproduce (repo root):

```
python tools/art/build_fx_strip.py art_src/Custom/HazardFX_2026-08-15/hazard_<t>/hazard_<t>_master_v1_keyed.png <out>/hazard_<t>.png --cols 2 --rows 2 --cell 192 --fill 0.80 --despill <green|magenta> --valign widest
python tools/art/build_fx_strip.py art_src/Custom/HazardFX_2026-08-15/rage_burst/rage_burst_master_v1_keyed.png   <out>/rage_burst.png --cols 4 --rows 2 --cell 256 --fill 0.85 --despill green --valign widest
```
(lava/slow/churned/rage = green key; ice/heal = magenta.)

Verified with `game/shot_fx_series.tscn -- --hazards` (repaints the room through
magma / ice / bog / holy / void and shoots wide + close) and
`-- --class=warrior --ability=ult --theme=none --pin` (muted rig).
