# Paladin class-splash reskin — 2026-08-17

`class_splash_paladin.png` (the class-select / hero-dialogue "You" splash) was
the OLD paladin: **hooded**, blackened steel, oxblood tabard. Owner ruling
(2026-08-17): it is outdated and must match the current in-game paladin, same as
the [chapter-opener reskin](../chapter_openers_paladin_reskin_2026-08-17/README.md).

## Target (match the in-game sprite `game/assets/sprites/paladin.png`)

BARE-HEADED open bearded face (greying brown hair, short dark beard); pale
brushed steel + antique-gold plate; JUDICIAL-BLUE tabard; gold chain to a round
gold SUN medallion; gold sun-emblem shield; square reliquary-box warhammer on a
gold chain; small gold sun motifs. No hood/helm, no red cape, no halo/wings/
crown/cross, no eclipse black-gold (premium-skin only).

## Method

Built-in Codex `image_gen` **edit** flow (2 rolls, `tools/art/run_codex_batch.ps1`),
target = the old splash, design ref = the in-game sprite. Keeps the painterly
gothic-cathedral-and-moon full-body composition and pose; swaps only the paladin.
Codex returned exact 1254x1254. **roll_a** installed; **roll_b** kept as
`alt_roll_b.png` (a touch greyer/older). `originals/` holds the replaced splash.

In-engine check: `shot.bat palsplash` (`game/shot_palsplash.gd`) shows a
hero-spoken "You" line so the class splash renders full-bleed — confirmed
bare-faced. Mobile synced. No code change (same filename/dimensions).

PixelLab was not used.
