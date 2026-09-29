# T52a round 2: painted bronze menu frame kit

Final PNGs: `game/assets/ui/frame/`. Generated with built-in ImageGen, strictly one call at a time, with visual inspection after every result. 16 calls total. Round 1, including its untouched masters, prompts, provenance and shipped PNGs, is archived in `rejected_v1/`. Its old main-checkout provenance is historical; every round-2 project operation used the `codex/crownless-wayfinder` worktree.

## Shipped pixel contract

Margins below are actual texture pixels for Godot StyleBoxTexture, L/T/R/B. Do not halve them. Large panel/card textures retain center detail; their rails have already been reduced independently to the intended display scale.

| Piece | PNG size | Margins L/T/R/B | Approx. painted rail | Re-rolls this round |
|---|---|---|---|---|
| panel | 768 x 768 | 16 / 16 / 16 / 16 | 10-12 px; corner points contained in 16 px | 1 |
| card | 256 x 128 | 9 / 9 / 9 / 9 | 7-8 px | 2 |
| tab_active | 160 x 32 | 5 / 5 / 5 / 5 | 4-5 px top/bottom | 1 |
| tab_idle | 160 x 32 | 5 / 5 / 5 / 5 | 4-5 px top/bottom | 3 |
| slot | 48 x 48 | 6 / 6 / 6 / 6 | about 6 px | 1 |
| divider | 512 x 32 | Not an ordinary nine-slice | about 6 px rail, 28 px central ornament | 2 |

The tab margins total 10 px vertically, leaving 15 px inside a 25 px control. Slot margins leave a 36 x 36 center, 56.25% of the total area. Slot and panel share painted umber/leather grounds; no mesh or carbon texture. Only the panel has small crown-derived gothic point finials. Other frame corners are simple miters. Bars contain no intermediate ornament.

Divider width changes require five horizontal regions, preserving the center ornament and both endcaps: `(x,width)` = `(0,16)`, `(16,216)`, `(232,48)`, `(280,216)`, `(496,16)`, all at full 32 px height. Stretch only the second and fourth regions. One conventional nine-slice would stretch the center diamond; use fixed size or the five-region method.

## Prompts and my critique

All prompts below are the exact tool prompts, not retrospective summaries. Re-roll counts include color correction edits, not cropping/resampling.

| Piece | Exact prompts | Re-roll reason and final critique |
|---|---|---|
| panel | [initial](panel.prompt.txt), [re-roll 1](panel.reroll-1.prompt.txt) | First finials projected too far beyond the rails; compacted them. Final points read at 16 px and the saturated paint is much closer to the crown. The protected border mean includes dark recess/guard pixels, so its mean V 0.38 is darker than the crown's cited 0.47. Leather brushwork is visible across the large panel and should be judged behind real content during integration. |
| card | [initial](card.prompt.txt), [re-roll 1](card.reroll-1.prompt.txt), [re-roll 2](card.reroll-2.prompt.txt) | Initial S 0.87; first edit overshot to 0.69; final S 0.83. Clean mitered corners, compact bars. Final V 0.53 is the brightest family member; the long horizontal leather stretch is visibly directional. |
| tab_active | [initial](tab_active.prompt.txt), [re-roll 1](tab_active.reroll-1.prompt.txt) | Initial S 0.91 reduced to 0.81. First generation returned two separated tab variants; upper tab was cleanly cropped as the selected reference. Brighter top lip and thin inner light line survive at 25 px height, although the extra cue is necessarily only about a pixel. |
| tab_idle | [initial](tab_idle.prompt.txt), [re-roll 1](tab_idle.reroll-1.prompt.txt), [re-roll 2](tab_idle.reroll-2.prompt.txt), [re-roll 3](tab_idle.reroll-3.prompt.txt) | Corrected saturation, rejected a too-pale brightness edit, then darkened it. Final is brown bronze, with saturation 37% and value 39% below active. Generator edits introduce small brushwork differences; this is the same shape/material family, not pixel-identical paint. |
| slot | [initial](slot.prompt.txt), [re-roll 1](slot.reroll-1.prompt.txt) | Initial S 0.94 reduced to 0.81. Plain corners and 36 px clear center solve the crowding problem. At 48 px most individual brush facets merge into the material; silhouette and rim light carry the read. |
| divider | [initial](divider.prompt.txt), [re-roll 1](divider.reroll-1.prompt.txt), [re-roll 2](divider.reroll-2.prompt.txt) | Two saturation edits brought S 0.93 to 0.85. Accepted diamond/endcap composition retained and warmer than round 1. Five-region integration remains necessary if its width changes. |

## Contact sheet and reproduction

[Contact sheet v2](contact_sheet_v2.png) is 2520 x 1130. It includes actual shipped PNGs composited at 1:1 using their nine-slice margins: panel 900 x 620, card 500 x 90, both tabs 160 x 32 and 160 x 25, and slot 48 x 48. Each backdrop has the cover crown beside it. View at 100% to assess the thin controls; a browser may shrink the entire sheet. Separate [dark](stretch_preview_dark.png) and [mid](stretch_preview_mid.png) halves preserve the same native pixels.

Run `python art_src/ui_frame_2026-09-29/build_v2.py` to reproduce shipped PNGs, metrics and previews. It uses only alpha cleanup, trimming and nine-region Lanczos resampling (divider uses full-image resampling). No procedural material, added bevel, color grading, mirroring or replacement paint is synthesized by Python. Raw originals, including unused attempts, remain in `masters/`. `processing_metrics.json` records crops, source/destination margins, SHA-256 hashes and border HSV. Border samples are every nearly opaque pixel outside the protected center, including recesses; no hue/value filtering cherry-picks gold pixels.

These are asset-kit previews, not screenshots of wired production menus. No theme/GDScript/mobile integration is included in this art-only commit. Test results and generation lineage are recorded in `provenance.json`.
