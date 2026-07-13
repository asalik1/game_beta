# Skin Designs — Elite & Mythic

Three cosmetic tiers: **Chroma** (shader recolor, cheapest), **Elite** (new sprite + FX), **Mythic** (reimagined sprite + FX, prestige). Chromas are defined in `skins.gd` as palette triples. Elite/Mythic skins each get a unique splash art (this directory) and game sprite (`assets/sprites/skins/`).

Art style target: dark painterly / oil painting, Dark Souls / Elden Ring concept art aesthetic. Standing pose, weapon at side. Single accent color against near-black. Each skin must read as a distinct fantasy from its base class while staying recognizably that class.

---

## Warrior

**Base identity:** Molten/lava cracked dark armor, flaming greatsword. Fire and destruction.

### Dreadknight (Elite)
- **Fantasy:** Death knight. The warrior's fire replaced with unholy frost.
- **Palette:** Black iron plate, ice-blue glow from armor joints and runes.
- **Key details:** Skull motifs and bone spurs on armor, pale blue runic greatsword, tattered dark cape, helmet with glowing ice-blue eye slits, frost wisps.
- **Accent color:** Ice blue (#4488CC)
- **Splash:** `skin_warrior_dreadknight.png`

### Stormforged (Mythic)
- **Fantasy:** Lightning incarnate. The warrior became the storm itself.
- **Palette:** Deep blue-black plate with electric white-blue arcs crackling between plates.
- **Key details:** Lightning bolt crest on helmet, warhammer with coiling electricity, storm clouds gathering behind, cape of pure storm energy, glowing veins across metal surface.
- **Accent color:** Electric blue (#3366FF)
- **Splash:** `skin_warrior_stormforged.png`

---

## Archer

**Base identity:** Gritty green-tinted hooded ranger, lightning bow, dynamic and nimble.

### Frostfall Ranger (Elite)
- **Fantasy:** Arctic hunter. The ranger traded forest for frozen wastes.
- **Palette:** Frost-white and pale blue leather, ice crystal accents.
- **Key details:** Fur-lined hood, ice-crystal bow held vertically at side, frost particles in air, pale blue eyes, frozen quiver, breath mist.
- **Accent color:** Frost white-blue (#88CCEE)
- **Splash:** `skin_archer_frostfall_ranger.png`

### Voidwraith (Mythic)
- **Fantasy:** The ranger stepped between worlds. Half-real, half-void.
- **Palette:** Deep purple-black cloak, void energy tendrils, star-field patterns.
- **Key details:** Void-energy bow with no physical string, hooded figure whose edges dissolve into dark particles, constellation patterns on cloak interior, glowing violet eyes.
- **Accent color:** Void purple (#7744BB)
- **Splash:** `skin_archer_voidwraith.png`

---

## Mage

**Base identity:** White-haired elf, white robes, green crystal staff. Elegant and scholarly.

### Void Weaver (Elite)
- **Fantasy:** The mage who studied too deep. Void magic consumed the light.
- **Palette:** Dark purple and black flowing robes with cosmic star patterns woven into fabric.
- **Key details:** White hair (still elven), ornate staff topped with swirling void orb, tendrils of void energy floating around body, deep space and nebula accents on robes.
- **Accent color:** Void purple (#8833CC)
- **Splash:** `skin_mage_void_weaver.png`

### Crystal Archmage (Mythic)
- **Fantasy:** Mastery over prismatic crystal magic. The mage transcended flesh into living crystal.
- **Palette:** Shimmering prismatic white and blue, crystalline surfaces that refract rainbow light.
- **Key details:** White hair, elven features, grand crystal staff with massive glowing diamond, floating crystal shards orbiting, crystalline shoulder pauldrons, embedded gemstones in robes.
- **Accent color:** Prismatic white-blue (#AABBFF)
- **Splash:** `skin_mage_crystal_archmage.png`

---

## Assassin

**Base identity:** Clean grey/white hooded figure, dual daggers, smoke effects. Silent and precise.

### Blade Dancer (Elite)
- **Fantasy:** The assassin as artist. Every kill is choreography.
- **Palette:** Dark grey and silver fitted armor with flowing silk sashes.
- **Key details:** Hooded with face partially visible, twin curved daggers at sides, multiple throwing knives on belt/straps, graceful stance, silver wind trails and motion blur accents.
- **Accent color:** Silver (#AAAACC)
- **Splash:** `skin_assassin_blade_dancer.png`

### Phantom (Mythic)
- **Fantasy:** Spectral assassin who phased permanently between material and spirit.
- **Palette:** Dark teal and black, partially translucent/ethereal, robes that fade into mist at edges.
- **Key details:** Glowing pale teal eyes under hood, phantom daggers made of pure spectral energy, ghostly afterimages trailing, wisps of ectoplasm, body partially see-through.
- **Accent color:** Spectral teal (#44CCAA)
- **Splash:** `skin_assassin_phantom.png`

---

## Paladin

**Base identity:** Dark crusader, heavy dark plate with gold trim and chains, chained mace. Holy but ominous.

### Eclipse Knight (Elite)
- **Fantasy:** Solar eclipse given form. Holy light bent through a dark lens.
- **Palette:** Jet black heavy plate with brilliant golden solar corona trim and engravings.
- **Key details:** Dark hood over ornate black helmet, chained mace with golden eclipse glow at head, solar eclipse symbol on chest plate radiating dark gold light, dark cape with golden sun border.
- **Accent color:** Solar gold (#DDAA33)
- **Splash:** `skin_paladin_eclipse_knight.png`

### Fallen Arbiter (Mythic)
- **Fantasy:** A holy warrior whose faith broke. Corruption fills the cracks where faith used to be.
- **Palette:** Cracked white-gold plate with crimson corruption veins spreading through fractures.
- **Key details:** Broken halo floating in pieces above head, shattered holy symbols, dark corrupted flail with chains dripping shadow, mix of fading holy gold and consuming dark red energy, once-white armor now stained grey.
- **Accent color:** Corruption crimson (#CC2222)
- **Splash:** `skin_paladin_fallen_arbiter.png`

---

## Warlock

**Base identity:** Dark occultist, robes with chains and golden accents, floating skull, grimoire. Forbidden knowledge.

### Hellfire Inquisitor (Elite)
- **Fantasy:** The warlock who serves hellfire's judgment. Burns heresy — and everything else.
- **Palette:** Dark red and black ornate robes with inquisitorial symbols and chains.
- **Key details:** Hood with glowing orange ember eyes, grimoire chained to belt engulfed in flames, staff topped with burning skull, hellfire chains floating around, embers and ash rising, flames licking at robe edges.
- **Accent color:** Hellfire orange (#DD5500)
- **Splash:** `skin_warlock_hellfire_inquisitor.png`

### Eldritch Herald (Mythic)
- **Fantasy:** The warlock who read beyond the last page. Now a vessel for something that shouldn't exist.
- **Palette:** Dark robes covered in impossible geometric patterns that seem to shift, green eldritch glow.
- **Key details:** Hood revealing glimpse of face with multiple glowing green eyes, tentacles of dark cosmic energy emerging from beneath robes, floating grimoire of forbidden knowledge, staff topped with an all-seeing eye, reality warping around the figure.
- **Accent color:** Eldritch green (#33CC55)
- **Splash:** `skin_warlock_eldritch_herald.png`

---

## File naming convention

- Base class splash: `class_<name>.png`
- Boss splash: `boss_<name>.png`
- Skin splash: `skin_<class>_<id>.png`

All splash art lives in `art_src/splash_refs/`.
Game sprites (48px, 8-direction) live in `game/assets/sprites/skins/<tier>/`.
