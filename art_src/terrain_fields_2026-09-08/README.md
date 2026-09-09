# Painted terrain fields — September 8, 2026

Historical source record: the grass runtime was revised on September 9 with
the untouched master under `art_src/grass_focus_2026-09-09/`. This folder's
original grass, prompt and manifest remain unchanged. Other fields below
retain their existing sources. Read GRASS_FOCUS.md for the later validation.

Four original 1254×1254 square textures, generated with the built-in OpenAI
ImageGen tool. Existing game fields provide their material/palette; the
previously accepted stone_painterly field supplies brushwork only.

- `masters/<kind>.png`: intact generated originals.
- `prompts/<kind>.txt`: exact prompts used.
- `manifest.json`: generator file paths, SHA-256, seam measurements, runtime
  paths, world periods and review status.
- Runtime: `game/assets/sprites/ground_field_{sand,snow,grass,forest}_painterly.png`,
  mirrored to mobile. No image edits, cropping, recoloring or resizing. Mipmaps
  are built by Godot, and the runtime samples the source at the material scale.

Outgoing texture siblings are retained. Mean RGB edge differences are below
12/255 on both axes for all four fields. Desktop same-scene comparisons
reviewed at native and 2× zoom; sand/grass smoother, forest litter quieter,
snow's diamond checkerboard gone. Red/green attack rings remain distinguishable.
No visible border or brightness seam. Calibrated Forward+, Forward Mobile and Compatibility renderer reviews passed.

Reproduce the review: `shot.bat floorfield --compare --timeout=180` (add
`--mobile` for the mobile project). The rig uses unchanged scenery/geometry
between each before/after pair; it also captures real warning effects, touch
HUD and the Codex. Art code caches the shared field rather than baking native
high-resolution copies for every room.

Final renderer/capture corrections and validation: PAINTED_TERRAINS.md.
