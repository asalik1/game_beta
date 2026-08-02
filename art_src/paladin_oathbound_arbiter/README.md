# Oathbound Arbiter — regenerated Paladin base sprite

This is the lore-led replacement for the Paladin's old hooded/lantern design.
It presents the class as a visible, mortal magistrate: weathered open face,
pale steel and warm ivory plate, deep judicial-blue mantle and tabard, brass
chain of office over the heart, a square-headed oath hammer, and a tall
battered shield. The silhouette is protective and authoritative rather than
ecclesiastical.

## Full regeneration

The current `regen_*` family was generated from scratch with Codex's built-in
ImageGen tool on 2026-07-30. It is not an upscale or filter pass over the
earlier Oathbound assets. PixelLab was not used.

`regen_base_rotations.png` is the binding identity sheet. The old Paladin idle
and Maren's in-game sprite were supplied only as design/readability references
for this new five-view rotation. All subsequent animation masters use the new
rotation as their character reference.

Shared prompt contract:

> Premium high-resolution hand-painted pixel-art game sprite of the exact
> Oathbound Arbiter: visible weathered middle-aged face, short dark hair and
> beard, pale steel and warm ivory plate, deep judicial-blue tabard and
> one-shoulder mantle, brass oath-chain crossing a large round seal over the
> heart, square-headed war hammer in the right hand, tall battered pale shield
> on the left arm. Low top-down orthographic/isometric camera, crisp deliberate
> pixel clusters, bold readable color masses, strong selective dark outlines,
> simplified armor seams, low visual noise, consistent equipment, scale,
> baseline, and facing. Flat pure `#00ff00` background with no text, grid,
> floor, cast shadow, cropping, or overlap.

The regenerated masters are:

- `regen_idle_keyed.png`: five directions × four restrained idle frames
- `regen_walk_{s,se,e,ne,n}_keyed.png`: direction-authored eight-frame natural
  walks with low knee lift and two genuinely alternating steps
- `regen_run_keyed.png`: six-frame shield-led run; ImageGen supplied an extra
  rear-quarter row, so the builder explicitly selects S, SE, E, true NE, and N
- `regen_judgment_keyed.png`: five directions × seven-frame overhead Judgment
  slam
- `regen_judgment_n_keyed.png`: direction-locked North Judgment replacement
  that keeps the full metal hammer head visible through impact and recovery
- `regen_consecration_keyed.png`: five directions × seven-frame measured ground
  consecration
- `regen_consecration_ne_keyed.png` and
  `regen_consecration_n_keyed.png`: rear-direction timelines that prevent
  recovery-facing drift
- `regen_aegis_keyed.png`: five directions × six-frame shield raise and brace
- `regen_conviction_keyed.png`: five directions × seven-frame oath-seal surge
- `regen_death_keyed.png`: five directions × six-frame collapse and corpse

West-facing rows are controlled horizontal mirrors of E, SE, and NE, matching
Crownless's existing symmetric directional convention.

## Build and QA

Run from the repository root with the bundled Python runtime (Pillow + NumPy):

```powershell
python tools/art/build_oathbound_paladin.py
python tools/art/anim_sheet.py paladin all art_src/paladin_oathbound_arbiter/qa_regen 2
python tools/art/verify_art.py paladin
```

`tools/art/build_oathbound_paladin.py` detects the generated grids' real green
gutters, removes and despills green, hardens alpha, normalizes every facing at
a 180 px standing body and common ground line, assembles a shared 277 px
runtime cell, and installs the complete eight-direction family under
`game/assets/sprites/`. The game still renders the Paladin at the same
class-authored height; the larger masters provide the additional source detail
and cleaner downsampled readability requested for parity with Maren.
