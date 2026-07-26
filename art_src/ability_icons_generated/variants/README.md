# Generated ability-variant medallions

These 18 source sheets were produced with Codex's built-in image generation
tool as precise edits of the six base class sheets. The outer medallion,
layout, dark inner disc, and painterly fantasy UI language were held constant;
only the ability's inner artwork changed to communicate its gameplay variant.
Each 2x2 sheet maps cells in reading order to `a1`, `a2`, `a3`, and `ult`.

Theme matrix:

- Warrior: Fury, Bulwark, Earth
- Archer: Storm, Venom, Hunt
- Mage: Fire, Ice, Wind
- Assassin: Poison, Shadow, Blood
- Paladin: Holy, Aegis, Wrath
- Warlock: Curse, Pact, Void

The per-sheet prompts described the four variant effects from
`Classes.ABILITY_THEMES` and required one bold centered symbol per cell,
64x64 readability, no text or marks, and a flat chroma background outside the
medallions. Examples include twin-hit ember effects for Warrior/Fury, electric
arrows for Archer/Storm, spatial gusts for Mage/Wind, venom-coated blades for
Assassin/Poison, protective blue wards for Paladin/Aegis, and singularity
imagery for Warlock/Void.

Files:

- `*_sheet.png`: untouched generated source.
- `*_sheet_alpha.png`: source processed with the imagegen skill's
  `remove_chroma_key.py` helper.
- `ability_variant_contact_sheet.png`: base plus all three variants for every
  class and slot.
- Production: `game/assets/icons/ability_<class>_<slot>_<theme>.png`, normalized
  to a 60px medallion on a transparent 64x64 canvas.
