# Crownfall capital polish — generated source record

Mode: Codex built-in image-generation tool. The generated PNGs were copied from
the built-in output directory, keyed locally with the imagegen skill's
`remove_chroma_key.py`, and converted into production assets by
`tools/art/build_capital_polish.py`.

All prompts used `capital_ashfire_forge.png` and `capital_stables.png` as
style/palette/camera references only. Every asset used a perfectly flat
`#ff00ff` background, crisp high-detail pixel art, the Crownfall charcoal /
dark-wood / muted-brass palette, a front-facing three-quarter top-down game
camera, no floor or cast shadow, no text/logo/watermark, and no magenta in the
subject.

## Generated prompts

### Animated Hearthworks hearth

> Create a new premium medieval-gothic communal hearth for The Hearthworks,
> shown in four smoothly looping flame animation phases as an exact 2x2
> storyboard. Each quadrant is one equal frame of the same substantial dark
> carved-stone firebox with iron cooking rail and hooks, broad ash lip, split
> logs, and restrained brass Crownfall trim. The large central fire changes
> shape, height, ember highlights, and warm glow; all stone and metal remains
> identical. One integrated fire only—never a small fire inside a larger static
> flame.

Production:

- `game/assets/sprites/capital_great_hearth.png`
- `game/assets/sprites/capital_great_hearth_anim.png`

### Crownfall city bench

> Create one premium Crownfall city bench for an MMO gathering hub: broad dark
> weathered hardwood seat and back, substantial carved charcoal-stone end
> supports, restrained muted-brass crown motifs, believable joinery and wear.
> It must read as one cohesive designed prop, not a tiny generic furniture tile
> or fence fragment.

Production: `game/assets/sprites/capital_city_bench.png`

### Personal vault coffer

> Create one premium personal vault coffer for Artisans' Court: a substantial
> locked dark-oak chest with layered blackened-steel bands, reinforced corners,
> muted-brass crown-shaped lock plate, restrained red enamel accents,
> believable hinges, and a heavy closed-lid silhouette. It must clearly read as
> secure player storage, not a tiny generic treasure box.

Production: `game/assets/sprites/capital_vault_chest.png`

### City directory

> Create one premium Crownfall city directory and gathering notice board:
> substantial freestanding dark carved-stone frame, broad weathered hardwood
> panel, layered pinned parchment shapes without readable writing, muted-brass
> crown crest, four small ward-color markers, and sturdy feet. It must read as
> an important interactive city map/job board, not a tiny signpost.

Production: `game/assets/sprites/capital_city_directory.png`

### Hearthworks alembic station

> Create one premium Hearthworks alembic station: one cohesive dark
> carved-stone and blackened-iron workbench with a central copper distillation
> vessel, curved condenser pipe, two restrained teal-glass reagent bottles,
> mortar and pestle, tidy herb drawers, and muted-brass Crownfall trim. It must
> read as a professional civic workstation rather than scattered tiny alchemy
> props.

Production: `game/assets/sprites/capital_alembic_station.png`

## Existing structure animation

The builder also makes four-frame full-structure strips for nine existing
512px fire-bearing capital landmarks. Their architecture and alpha remain
fixed; only authored fire-socket pixels change. This replaces the former
static baked fire plus smaller animated overlay:

- `capital_emberward_gate_anim.png`
- `capital_portal_crucible_anim.png`
- `capital_ashfire_forge_anim.png`
- `capital_ashen_tankard_anim.png`
- `capital_wildfang_fangmoot_anim.png`
- `capital_accord_longhouse_anim.png`
- `capital_sable_hall_anim.png`
- `capital_watchtower_anim.png`
- `capital_proving_gate_anim.png`
