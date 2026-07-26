# Generated ability medallions

These six 2x2 source sheets were produced with Codex's built-in image
generation tool for the July 2026 ability-bar polish pass. Each sheet maps
cells in reading order to `a1`, `a2`, `a3`, and `ult`.

The shared brief was: original premium hand-painted fantasy action-RPG
medallions; one centered high-contrast ability silhouette per circle; dark
gunmetal plus antique-gold double rim; jewel-colored magical lighting; no
text, logos, trademarks, or watermark; effects contained within crisp circular
edges; readable at 64x64.

Class subjects:

- Warrior: Cleave, Shield Bash, Whirlwind, Berserk
- Archer: Quick Shot, Multishot, Tumble, Arrow Storm
- Mage: Firebolt, Frost Nova, Blink, Meteor
- Assassin: Stab, Shadow Dash, Fan of Knives, Death Mark
- Paladin: Judgment, Consecration, Aegis, Conviction
- Warlock: Shadowbolt, Hex, Dark Pact, Void Rift

The `_sheet.png` files are the untouched generated sources. The
`_sheet_alpha.png` files were processed with the imagegen skill's
`remove_chroma_key.py` helper. Production icons in `game/assets/icons/` are
normalized from each alpha sheet to a 60px medallion on a transparent 64x64
canvas.

`variants/` contains the matching 18 theme sheets (three themes per class),
their alpha masters, a full contact sheet, and the prompt/design mapping.
