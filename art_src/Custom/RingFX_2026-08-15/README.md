# Ring-replacement FX masters (2026-08-15)

Owner: "fix the other rings too (aegis, dark pact, arrow storm, whirlwind)" —
the four remaining ability FX that were a thin `_ring_fx` + square `game.burst`.
Five ImageGen masters generated headless via Codex (`make_briefs.py` writes the
briefs; `tools/art/run_codex_batch.ps1` ran all five in parallel, ~5 min).

| subdir | strip | cells | role / wiring |
|---|---|---|---|
| `aegis_dome/` (magenta key) | `aegis_dome.png` 2048x256 | 8 x 256, `--valign bottom` | paladin `_aegis`: `_fx_loop` for `aegis_time`, ping-pong, body under + 45% ghost over; `AEGIS_DOME_SCALE/OFFSET` (bottom row 202 → −74, +14 to the ring centre) |
| `dark_pact_burst/` (green key) | `dark_pact_burst.png` 2048x256 | 8 x 256, `--valign widest` | warlock `_dark_pact`: `_fx_flash` one-shot to the 170px reach, hue-shifted (mage_element_hue) to theme/skin colour; `DARK_PACT_OFFSET` −39; replaces collapse ring + burst + glow rays |
| `wind_vortex/` (magenta) | `wind_vortex.png` 2048x256 | 8 x 256, centre | archer Arrow Storm cast: `_fx_loop` for `storm_time` under the archer, tinted, `spin` −1.7 rad/s (the generated frames barely rotate — the turn is code) |
| `arrow_impact/` (magenta) | `arrow_impact.png` 1024x128 | 8 x 128, `--valign bottom` | each storm arrow's landing: `_fx_flash` timed to the shaft's arrival, tinted; `ARROW_IMPACT_SCALE/OFFSET` |
| `whirl_gust/` (magenta) | `whirl_gust.png` 2048x256 | 8 x 256, centre | warrior `_whirlwind`: `_fx_loop` for `spin_dur`, code-spun one full turn (reversed for Earth's inward pull), 40% ghost over; blades stay on top |

The pale strips (dome, vortex, puff, gust) are near-white on purpose: the game
tints them per theme/skin with `modulate`. The pact burst is painted blood-red
and re-hued by the shader.

Reproduce (repo root; the strips here are the installed ones):

```
python tools/art/build_fx_strip.py art_src/Custom/RingFX_2026-08-15/aegis_dome/aegis_dome_master_v1_keyed.png             <out>/aegis_dome.png      --cols 4 --rows 2 --cell 256 --fill 0.80 --despill magenta --valign bottom
python tools/art/build_fx_strip.py art_src/Custom/RingFX_2026-08-15/dark_pact_burst/dark_pact_burst_master_v1_keyed.png   <out>/dark_pact_burst.png --cols 4 --rows 2 --cell 256 --fill 0.85 --despill green   --valign widest
python tools/art/build_fx_strip.py art_src/Custom/RingFX_2026-08-15/wind_vortex/wind_vortex_master_v1_keyed.png           <out>/wind_vortex.png     --cols 4 --rows 2 --cell 256 --fill 0.82 --despill magenta
python tools/art/build_fx_strip.py art_src/Custom/RingFX_2026-08-15/arrow_impact/arrow_impact_master_v1_keyed.png         <out>/arrow_impact.png    --cols 4 --rows 2 --cell 128 --fill 0.70 --despill magenta --valign bottom
python tools/art/build_fx_strip.py art_src/Custom/RingFX_2026-08-15/whirl_gust/whirl_gust_master_v1_keyed.png             <out>/whirl_gust.png      --cols 4 --rows 2 --cell 256 --fill 0.82 --despill magenta
```

All follow the FX layering rule (DESIGN.md standing rules): body under the
actors, a ≤45% ghost over them. Verified with
`game/shot_fx_series.tscn -- --class=<c> --ability=<slot> --theme=none --pin`
(muted rig).
