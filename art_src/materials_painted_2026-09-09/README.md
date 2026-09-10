# Painted material UI — September 9–10, 2026

Three F-grade materials were painted with the built-in ImageGen tool against each actual old material as a subject reference and `game/assets/icons/consumables/defective_health_potion.png` as the style reference. The old material masters were pixel art; increasing their resolution alone would not make them painterly. Names, grades and material identity are unchanged.

Four E/D herb and reagent siblings extend the same family on September 10. Each
uses its own inspected legacy identity reference and the same painted potion
style reference. All four v1 outputs have native RGBA and use no keying or
cleanup. Their complete original tool outputs, actual prompts, source/reference
hashes and available call timestamps are recorded in `provenance.json`.

## Approved portable sources

All source canvases remain **1254×1254**. The exporter downsamples the full square to **128×128 RGBA** with the existing `tools/art/build_gear_codex_icons.py:_resize_premultiplied` function. It does not crop by alpha bounds, normalize the silhouette, quantize, sharpen, brighten, add outlines or create a background. Sparse low-alpha master dust is retained in the source and does not control framing.

| Material | Export source, relative to this folder | Preparation |
|---|---|---|
| F Wilted Sprig | `masters/herb_f_wilted_sprig_v1.png` | Native RGBA, no keying/despill |
| F Foul Residue | `masters/reagent_f_foul_residue_v1.png` | Native RGBA, no keying/despill |
| F Rusted Scrap | `alpha/metal_f_rusted_scrap_v3_keyed.png` | Approved full-canvas RGBA keyed from the magenta v3 master |
| E Common Weed | `masters/herb_e_common_weed_v1.png` | Native RGBA; jagged leaves and exposed roots |
| E Crude Extract | `masters/reagent_e_crude_extract_v1.png` | Native RGBA; cloudy amber with sediment and rough neck tie |
| D Fresh Herb | `masters/herb_d_fresh_herb_v1.png` | Native RGBA; broad fresh leaves and clean cut stems |
| D Clean Extract | `masters/reagent_d_clean_extract_v1.png` | Native RGBA; plain clear flask and turquoise liquid |

`provenance.json` preserves exact prompts, reference identities/hashes, generation timestamps and raw master hashes. Its `ui_export` section is the portable source manifest, with approved source, encoded PNG and decoded RGBA SHA-256 values. Project paths are repository-relative. Historical `original_tool_path` values document where ImageGen first wrote each image; the exporter never reads those paths.

The approved 128 exports have >8-alpha extents of 79×115 (sprig), 105×90 (residue) and 116×101 (scrap). These reflect the authored shapes; none was forced to a common body size. The existing potion is 80×111 at the same threshold, or 84×116 counting any nonzero alpha. All three export borders are fully transparent.

## Rebuild and install

From the repository root, using Python with Pillow and NumPy:

```powershell
python tools/art/build_material_ui_icons.py
python tools/art/build_material_ui_icons.py --output build/material_ui_review
```

The default output is `build/material_ui_icons`. The tool writes seven PNGs and `export-report.json`; it validates every source and every rebuilt RGBA result before writing output. Sources with unexpected content, dimensions or color mode fail instead of being silently normalized. It rejects candidate destinations under `game`, `mobile` or `art_src`.

Runtime installation is explicit:

```powershell
python tools/art/build_material_ui_icons.py --install
python tools/art/build_material_ui_icons.py --grade-pairs --install
```

This additionally writes only the approved PNG filenames to `game/assets/icons/materials_ui`. It does not install `.import` files, modify GDScript, touch legacy `materials/`, or synchronize mobile. Root owns runtime installation, native acceptance and subsequent mobile synchronization.

The approved exports were encoded with Pillow 12.3.0 / NumPy 2.5.1. A rebuild with those installed versions reproduced all three candidate PNGs byte-for-byte. The tool always requires decoded RGBA equality. If a future PNG encoder changes compression while preserving every RGBA byte, the report explicitly distinguishes that encoding-only difference.

The seven-asset rebuild also reproduces exact PNG bytes. `--grade-pairs` requires
exactly these seven approved IDs, pins the first three PNG approvals and rejects
an install with changed encoded bytes. It changes no image-processing behavior.
The first three manifest rows and runtime PNGs remain unchanged by this extension.

## Scrap alpha preparation provenance

`key-record.json` records the original magenta master, helper path/SHA, exact call arguments, alpha statistics and archived intermediate hash. The helper was the already-installed imagegen `scripts/remove_chroma_key.py`, SHA-256 `fa2989807052b857bed08f7fee0caa2502b54c46afc0a6f28cd706c25f636630`. Its absolute historical path is recorded solely as provenance, not a runtime/export dependency. No helper was vendored.

Equivalent preparation flags were `--key-color #ff00ff --tolerance 12 --soft-matte --transparent-threshold 12 --opaque-threshold 96 --despill --edge-contract 0 --edge-feather 0`. The existing helper uses a soft matte, key-like partial-alpha despill and its internal alpha 1–8 noise floor. No contraction or feather was applied. Native RGBA sprig/residue bypassed this entire stage, preserving their existing mostly 252/253 alpha.

The archived scrap RGBA SHA-256 is `845d75ffbab6ff965f7cd093a67495f721570663df1785b702e1c560dffe5618`. It retains sparse source-border alpha up to 21; normal full-canvas downsampling yields a completely transparent output border. Its low-alpha bounding box must not be used to crop or enlarge the art. The punched hole and fragment gaps remain transparent.

## Rejected scrap generations

Metal v1 and its transparency correction v2 were RGB images with a painted checkerboard. They are excluded from `ui_export`; gray-color removal would damage the actual metal. Their generation records and exact hashes remain in `provenance.json`:

- v1: `b5facfde9c14f2f66c036939a66fa226ec06afb95fd0d6c2210820ff88745d96`
- v2: `1da7860d80a2b4b0022142c4f09ef74f0b38f9e37aa101f8ed3060ba9f298a8f`

The two rejected workspace copies are preserved separately under `build/qa/session-sept10/material-rejected/`, outside the committed source set. Original ImageGen output files remain untouched. The provenance records both the path at generation and the current rejected archive path.

The candidate contact sheet at `build/qa/session-sept10/material-export-candidate/siblings_128_64_32.png` was inspected at native 128/64/32 sizes on light and dark backgrounds beside the current potion. Identity and shading read clearly at 64px; the 32px sprig stays naturally thin and tiny scrap rivets merge. This static export review does not replace native UI acceptance.
