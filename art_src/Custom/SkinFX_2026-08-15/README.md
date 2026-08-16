# Skin-FX pass masters (2026-08-15/16)

Owner, after the skin review (`PROPOSALS/SKIN_FX_REVIEW_2026-08-15/`): "fix them
starting from the top — quality too, not just the overlap; Umbral Phantom and
Arcane Warlock are prototypes" (noted in `skins.gd`; both skipped — Arcane still
inherits the shared warlock paths, so it picks up the pact/rift strips for free).

Five ImageGen masters generated headless via Codex (`make_briefs.py` — imports the
RingFX skeleton; `tools/art/run_codex_batch.ps1`):

| subdir | strip | cells | wiring |
|---|---|---|---|
| `void_contact/` (green key) | `void_contact.png` 1024x128 | 8 x 128 | Voidwraith `_void_tentacle_contact_fx`: `_fx_flash` z −1 / ghost 0.5 on the victim's torso (`VOID_CONTACT_SCALE`) — replaces burst + ring 34 |
| `storm_conduct/` (magenta) | `storm_conduct.png` 1024x128 | 8 x 128 | Stormforged `_storm_conduct` (blade-tip snap) + `_storm_charge_break` (snap at both ends; the body phase-out now goes through `skin_vanish_t/alpha`) — replaces glow beads + square bursts |
| `gilded_iai/` (magenta) | `gilded_iai.png` 2048x256 | 8 x 256 | Golden Ronin `_gilded_iai_strike`: cross-cut over the prey, z −1 / ghost 0.55; round gold glints via `_soft_burst` — replaces 4 slashline strokes + square burst |
| `consecration_bloom_v2/` (**black, luma-keyed** — v1 on magenta came back on a brown gradient and keyed to a bare spiky ring) | `consecration_bloom.png` 2048x256 | 8 x 256 | every paladin's `_consecration_pulse`: `_fx_loop` 0.7 s ping-pong z −1 / ghost 0.35, tinted by theme/skin light — replaces ring + square burst + 8 glow shards; motes textured; `_light_pillar` shaft 0.5 alpha + round bloom, no ring |
| `void_rift_burst/` (green) | `void_rift_burst.png` 2048x256 | 8 x 256, `--valign widest` (offset +1) | warlock `_void_rift` collapse for base + Hellfire (Eldritch keeps its thread scene): `_fx_flash` z −1 / ghost 0.45, hue-shifted to `col` — replaces 2 square bursts + rings + white core + 10 glow rays |

Code-only fixes in the same pass (no art): Voidwraith tentacles body under
actors + ghost copy (`VoidTentacle.GHOST_*`), root z −3±2; dismiss timer bound
to a cast serial (`void_storm_serial`); Crystal Archmage prism court z −1 +
ghost 9 for the convene, and its landing now calls `_meteor_impact_fx` (crystal
hue); Dreadknight/Stormforged Berserk ride `rage_burst` (dread-red /
storm-blue, 150 px) and their live aura/tint wear the skin colour
(`player.gd`); Eclipse Aegis ward + Conviction disc split body-under /
ghost-over; `_staged_segment_ring` gained a `z` param; `skin_owned_dash` covers
Phantom + Ronin; base dash + Ronin/Dreadknight motes use the new `_soft_burst`
(round) instead of `game.burst` squares; base Shield Bash landing = tinted
`arrow_impact` puff instead of the arrival ring.

Reproduce (repo root):

```
python tools/art/build_fx_strip.py art_src/Custom/SkinFX_2026-08-15/void_contact/void_contact_master_v1_keyed.png         <out>/void_contact.png       --cols 4 --rows 2 --cell 128 --fill 0.70 --despill green
python tools/art/build_fx_strip.py art_src/Custom/SkinFX_2026-08-15/storm_conduct/storm_conduct_master_v1_keyed.png       <out>/storm_conduct.png      --cols 4 --rows 2 --cell 128 --fill 0.75 --despill magenta
python tools/art/build_fx_strip.py art_src/Custom/SkinFX_2026-08-15/gilded_iai/gilded_iai_master_v1_keyed.png             <out>/gilded_iai.png         --cols 4 --rows 2 --cell 256 --fill 0.85 --despill magenta
python tools/art/build_fx_strip.py art_src/Custom/SkinFX_2026-08-15/consecration_bloom_v2/consecration_bloom_master_v2.png <out>/consecration_bloom.png --cols 4 --rows 2 --cell 256 --fill 0.82 --luma-key --gamma 1.0
python tools/art/build_fx_strip.py art_src/Custom/SkinFX_2026-08-15/void_rift_burst/void_rift_burst_master_v1_keyed.png   <out>/void_rift_burst.png    --cols 4 --rows 2 --cell 256 --fill 0.85 --despill green --valign widest
```

Verified with `shot.bat fx_series --class=<c> --skin=<s> --ability=<slot> --theme=none --terrain=keep --pin`
and `--call=_gilded_iai_strike` (fires one helper directly — the iai lands
inside a 3-frame window the ability series can't bracket).
