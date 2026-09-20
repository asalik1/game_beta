# Painted material UI — September 20, 2026

Two additive F-grade UI masters replace the enlarged pixel-art appearance of
Cracked Bone and Frayed Scraps. Each uses its original material as a subject
reference and the accepted painted Rusted Scrap UI icon as a style reference.
Names, grades, crafting behavior and world pickup images are unchanged.

Both masters were generated through the built-in `image_gen.imagegen` tool.
The exact prompts are in `prompts/`; original generated files are copied without
alteration into `sources/`. `provenance.json` records both locations and their
hashes. No PixelLab, external art source, keying or creative postprocessing was
used. Native transparent RGBA, including holes and fragment gaps, is retained.

The source canvases are 1254×1254. UI exports retain the whole canvas and use
`tools/art/build_gear_codex_icons.py:_resize_premultiplied` at 128×128. They are
not cropped, sharpened, recolored, outlined or normalized by alpha bounds.
Sparse low-alpha border pixels in the originals do not determine scale.

Source/export review and native acceptance are separate. Current source and
candidate evidence is under `build/qa/session-sept20/material-pilots-v1/`.
Both exact 128px exports are installed in game and mobile. Native acceptance
is recorded separately in `reviews/native-acceptance-v1.json`: 309 checks and
16 views per project, plus the existing 588-check/13-view material regression.
Desktop quick/full, mobile import/compile/strict quick and strict preflight pass.
Mobile captures are host Compatibility rendering, not device testing. These
controlled browse fixtures do not establish ordinary progression. Previous
thirteen painted UI images, all 35 world images and the September 9–10 source
archive remain byte-identical. Twenty material variants still need painted UI art.

The original source/export approval records remain unchanged. Archive-local
Git attributes preserve prompt and review bytes across Windows checkouts.
