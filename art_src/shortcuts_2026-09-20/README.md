# Painted shortcut mechanisms — September 20, 2026

Built-in ImageGen produced the transparent winch and front/side gate masters
under `sources/`; exact prompts and source/export hashes are retained in the
two provenance JSON files. Whole-canvas premultiplied Lanczos exports retain
alpha without cropping, keying, sharpening, recoloring or compositing. Runtime
winch is256px; front768×512 and side512×768 are3.84×/3.2× their display sizes.
The game supplies contact shadows, footing collision and terrain-matched returns.

Accepted after actual desktop and host Compatibility mobile original-image
review, required game gates and three zero-FAIL art checks. Soft-alpha BLEED
warnings are retained; no silhouette rim was found in reviewed originals.
Ground support and hero/prompt readability are accepted in interaction/crossing
poses. Supplemental upper gate caps can still sit under HUD; this is not every
pose or whole-game visual acceptance. No physical-device test was performed.

Evidence: `build/qa/session-sept20/shortcuts-checkpoint-validation.json` and
`EARNED_SHORTCUTS.md`. Historical candidate export folder names are preserved;
the final provenance status records acceptance. Rejected under2× exports remain
under `rejected_exports/`, and earlier failed visual trials remain in session QA.
Original candidate documentation is archived in that QA's `finalization-before-docs/`.
