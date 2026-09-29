# T52a menu frame kit — 2026-09-29

Generated serially with the authorized built-in ImageGen. Art only: no Godot, theme wiring, GDScript, imports, or mobile changes. Finals are in `game/assets/ui/frame/`.

| Piece | Final PNG size | Exact protected slice border, L/T/R/B | Prompt | Re-rolls |
|---|---:|---:|---|---|
| panel | 768 x 768 | 72 / 72 / 72 / 72 px | [panel.prompt.txt](panel.prompt.txt) | 0 |
| card | 384 x 384 | 36 / 36 / 36 / 36 px | [original](card.prompt.txt), [accepted re-roll](card.reroll-1.prompt.txt) | 1: top/bottom corner plates differed |
| tab_active | 384 x 160 | 28 / 28 / 28 / 28 px | [tab_active.prompt.txt](tab_active.prompt.txt) | 0 |
| tab_idle | 384 x 160 | 28 / 28 / 28 / 28 px | [original](tab_idle.prompt.txt), [accepted re-roll](tab_idle.reroll-1.prompt.txt) | 1: first idle was too bright |
| slot | 192 x 192 | 20 / 20 / 20 / 20 px | [slot.prompt.txt](slot.prompt.txt) | 0 |
| divider | 512 x 48 | Not a rectangular frame; nominal rail 8 px | [divider.prompt.txt](divider.prompt.txt) | 0 |

The border numbers are source-texture nine-slice margins, including the complete corner ornament and a quiet guard band. The painted metal band is somewhat narrower. Halve these numbers for the intended 2x base presentation: panel 384 square / 36px border, card 192 square / 18px border, tabs 192x80 / 14px border, slot 96 square / 10px border. Larger shells can stretch their quiet centers while retaining these display borders. Do not uniformly enlarge the corner art beyond its fidelity budget.

The generator did not obey requested canvas dimensions literally. Untouched originals are retained in `masters/`: squares 1254x1254, tabs 1942x809, divider 1774x887. `processing_metrics.json` records actual alpha crop rectangles and source slice margins. The final frames were normalized by nine-region Lanczos resizing, preserving square corner proportions, rather than distorting the entire rectangle. Only alpha cleanup, trimming and resampling were used; no new procedural painted art was substituted. Alpha <=16 was removed, alpha >=245 made opaque, other edge alpha retained. No chroma key was needed.

The divider has an explicit integration limitation: a single ordinary nine-slice cannot keep its center diamond and both endcaps fixed while extending the width. At 512x48, use it at fixed aspect, or use these horizontal regions (x, y, width, height): left cap `(0,0,16,48)`, left stretch rail `(16,0,216,48)`, fixed center `(232,0,48,48)`, right stretch rail `(280,0,216,48)`, right cap `(496,0,16,48)`. This is not an ordinary nine-slice-ready variable-width divider; the limitation is retained rather than hidden.

Every generation was visually inspected. The contact sheet places every final beside a crop of the actual painted cover crown band, on both dark and mid backgrounds, plus offline stretch previews. The five frame interiors are fully opaque; all six final PNGs have zero visible pixels satisfying `G > max(R,B)+20`. The accepted idle bronze band is about 33% dimmer than active (mean sRGB luma 47.79 versus 71.27). In-game appearance and import behavior were not tested, per the no-Godot instruction.

Weakest piece: the slot. Its extra tiny corner facets are more elaborate than the card and soften at 48–96px display. It remains neutral bronze with no baked grade colors. The panel is the strongest match to the cover's warm forged metal; all pieces deliberately use quieter gold than the focal cover crown. Very wide stretches flatten some center leather grain, visible in the offline preview, so the wiring should avoid excessive aspect changes where possible.

Full prompts, rejected raw generations and per-file hashes are retained in this directory. `provenance.json` records the exact source references, processing, acceptance and limitations.
