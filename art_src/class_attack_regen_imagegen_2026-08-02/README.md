# Archer, Warlock, and Warrior attack regeneration — 2026-08-02

The owner-approved manifest is installed in both `game/assets/sprites/` and
`mobile/game/assets/sprites/`.

## Production contract

- Built-in ImageGen sources, generated one class/direction at a time.
- Eight independently authored directions: S, SE, E, NE, N, NW, W, SW.
- `attack` and `attack2` for every class.
- Archer and Warlock: 9 frames per strip. Warrior: 7 frames per strip.
- 22 FPS review timing.
- Standing body normalized to exactly 180 px from frame 1.
- Accepted source cells are 277 x 277 px; runtime strips use 352 x 352 px
  transparent cells after the body-anchor correction pass.
- Hard binary alpha, transparent corners, and edge-safe nonempty frames.
- Archer sources use magenta chroma to protect the green cape; Warlock and
  Warrior sources use green chroma. Border-connected keying protects costume
  colors in every case.
- Rejected experiments are retained for provenance and excluded from the
  accepted review manifest.

## Attack identities

- Archer `attack`: deliberate bow shot.
- Archer `attack2`: faster evasive bow shot.
- Warlock `attack`: compact hand-attached Shadowbolt flare; no detached
  projectile. The old-design black/gold robe, one violet skull, and one open
  violet grimoire are preserved.
- Warlock `attack2`: compact Dark Pact chest/book pulse; no cross-cell effect.
- Warrior `attack`: heavy Cleave.
- Warrior `attack2`: compact Whirlwind expressed through changing body/blade
  poses rather than oversized detached rings.

## Accepted versions

| Class / clip | S | SE | E | NE | N | NW | W | SW |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Archer attack | v03 | v01 | v02 | v02 | v02 | v02 | v01 | v01 |
| Archer attack2 | v02 | v01 | v03 | v01 | v02 | v02 | v01 | v01 |
| Warlock attack | v01 | v02 | v01 | v01 | v01 | v01 | v01 | v02 |
| Warlock attack2 | v02 | v01 | v03 | v01 | v01 | v01 | v01 | v01 |
| Warrior attack | v01 | v03 | v01 | v02 | v04 | v01 | v03 | v01 |
| Warrior attack2 | v02 | v03 | v03 | v01 | v04 | v01 | v01 | v01 |

The authoritative mapping is also encoded in
`tools/art/build_attack_regen_review.py`; consolidated review outputs are in
`review/`.

## QA status

`tools/art/stabilize_attack_anchors.py` first translates each complete frame
onto a fixed dense-body X anchor. It ignores thin weapon/effect columns, does
not resample or repaint the artwork, and expands the transparent cell so wide
attack effects are not cropped. `tools/art/build_attack_regen_review.py` then
audits all 48 stabilized strips and builds six all-direction contact sheets
plus six synchronized 22 FPS GIFs.
The final audit passed:

- 48/48 accepted strips found.
- Correct frame counts and 352 px stabilized runtime cells.
- Frame-1 standing body = 180 px in every strip.
- All 400 frame body centers are within 0.6 px of the fixed 176 px anchor.
- Every figure/effect retains at least 8 px of transparent cell margin.
- No semi-transparent pixels.
- Transparent strip corners.
- Every frame nonempty and clear of its cell edges.
- Final all-direction visual sweep passed identity, direction, equipment, and
  attack-readability checks.

## Runtime installation

- Installed 2026-08-02 with `tools/art/install_attack_regen.py --apply`.
- 48 directional strips plus 6 South flat aliases were installed in each
  runtime: 108 atomic, hash-verified writes total.
- Previous desktop and mobile runtime files are recoverable under
  `runtime_pre_install_2026-08-02/`, with `SHA256SUMS.txt`.
- Desktop/mobile parity passed for all 54 installed filenames.
- Desktop and mobile Godot imports completed.
- `verify_art.py archer warlock warrior`: `VERIFY OK`.
- Desktop compile gate and quick suite passed.
- Mobile compile gate and quick suite passed.

The per-frame measurements are recorded in `stabilized/ANCHOR_AUDIT.txt`.
