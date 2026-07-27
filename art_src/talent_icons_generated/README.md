# Generated talent medallions

These six 4x3 source sheets were produced with Codex's built-in image
generation tool for the talent/loadout UI pass. Cells map in reading order to
each class's four rows of three talents in `game/scripts/skills.gd`.

The shared brief was: original premium hand-painted fantasy action-RPG
medallions; one centered high-contrast talent symbol per circle; dark gunmetal
plus antique-gold double rim; class-colored magical lighting; no text, logos,
trademarks, or watermark; effects contained within crisp circular edges;
readable at 64x64.

The `_sheet.png` files are untouched generated sources. The
`_sheet_alpha.png` files were processed with the imagegen skill's
`remove_chroma_key.py` helper. Run:

```text
python tools/art/build_talent_icons.py
```

to normalize the medallions onto transparent 64x64 canvases in
`game/assets/icons/talent_<cell-id>.png` and rebuild the review contact sheet.
