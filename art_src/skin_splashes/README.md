# Class skin splash masters

These 17 square masters were generated with the built-in `image_gen` model.
Each call used the installed skin sprite as the authoritative identity reference
and that class's existing `class_splash_<class>.png` only as the realism,
lighting, composition, and production-quality reference. Awakened calls also
included the normal skin sprite to preserve identity continuity.

## Shared prompt contract

> Create a premium square dark-fantasy character splash illustration for the
> Crownless game. One character only, full body, centered, with the skin's
> weapon clearly readable. Preserve the authoritative sprite's equipment
> silhouette, palette, class, and gender. Match the existing base-class splash
> for dark photorealistic fantasy key-art quality, cinematic lighting, grounded
> materials, and anatomical coherence, but do not reuse its outfit. Square 1:1.
> No text, logo, UI, border, watermark, extra characters, extra limbs, or
> duplicate weapons.

## Exact subject prompt set

- `splash_skin_warrior_dreadknight`: Male hulking Dreadknight in fully enclosed black-steel horned helmet, massive layered black plate, sharp pauldrons, tattered black mantle, restrained blood-red accents, skull belt ornament, and enormous broad two-handed sword; oppressive ruined gothic fortress, dim red embers, cold smoke.
- `splash_skin_warrior_stormforged`: Male Stormforged warrior in steel-blue horned open-face helm, dark blue/silver plate, shoulder fur, deep-blue cape and leather chest strap, wielding an enormous jagged greatsword charged with pale-blue lightning; rain-black mountain citadel in a blue-white thunderstorm.
- `splash_skin_warrior_stormforged_awakened`: Same Stormforged man and equipment silhouette, awakened into deep indigo, violet-blue and blackened steel with supernatural violet storm energy; shattered sky-temple with coiling lightning.
- `splash_skin_archer_frostfall_ranger`: Adult female Frostfall Ranger with pale icy-blue skin, long white hair under an ice-blue hood, layered frost-blue leather/fur armor, short mantle, crystalline-arrow quiver and ice-rimed recurved bow; moonlit frozen evergreen ruin with drifting snow.
- `splash_skin_archer_voidwraith`: Adult female Voidwraith with muted green-gray skin, violet eyes, dark-purple hood, shadow-black layered leather, torn violet cloak, purple-fletched arrows and slender void bow; ruined twilight forest with purple mist.
- `splash_skin_archer_voidwraith_awakened`: Same Voidwraith woman and equipment, awakened with intensified magenta-violet eye, bow and shadow aura; shattered void gate in a dead forest.
- `splash_skin_mage_crystal_archmage`: Adult female Crystal Archmage with long silver-white hair, clear blue eyes, icy crystal circlet, pale blue-white embroidered ceremonial robes and tall staff crowned by a faceted blue crystal spearhead; moonlit crystal observatory.
- `splash_skin_mage_crystal_archmage_awakened`: Same Crystal Archmage woman and staff, awakened into luminous white, lavender-blue and deep-violet robes with stronger crystalline radiance; shattered astral sanctum and prism halo.
- `splash_skin_assassin_blade_dancer`: Male Golden Ronin with black hood hiding his face, amber-gold eyes, ornate black lamellar armor with rich gold bindings, dark tattered cloak and exactly one slim katana held low; rain-dark abandoned shrine courtyard.
- `splash_skin_assassin_phantom`: Adult male spectral Phantom with a completely lightless hood and exactly two tiny cyan eyes; exactly two short translucent cyan spirit-blades; charcoal wrappings and light armor partially insubstantial beneath an oversized ragged shroud dissolving into blue-black vapor; lower legs and trailing cloth phasing through shallow water. Full-body asymmetric low predatory three-quarter crouch, one reverse-grip blade near the flooded crypt floor and the other guarding across his body. Ancient flooded crypt, broken grave arches, hanging burial cloth and cold moonbeam, emerging from his own reflection. Restrained icy cyan only—no green or awakened Nightfang wildfire. Avoid the base Assassin's upright frontal pose, rainy alley, brown cross-straps, large belt buckle, shiny bracers, ordinary silver daggers, conventional human solidity, or outfit silhouette.
- `splash_skin_assassin_phantom_awakened`: Same Phantom man and paired blades in awakened Nightfang form, with teal-green ghostfire streams and stronger luminous blade energy; shattered moonlit crypt.
- `splash_skin_paladin_eclipse_knight`: Male Eclipse Knight in fully enclosed black/gold sun-disc helm and heavy eclipse-emblem plate, dark cape, wielding one large hammer that cradles a radiant black sun; ruined cathedral during totality.
- `splash_skin_paladin_fallen_arbiter`: Male Fallen Arbiter in enclosed black helm with gold-lit slit and broken floating gold halo, black/silver/red plate, long black feathered wings and one ember-corrupted sword; desecrated celestial tribunal under a cold moon.
- `splash_skin_paladin_fallen_arbiter_awakened`: Same Fallen Arbiter man, wings, halo and sword, awakened with cold silver-white helm/halo and cyan judgment light clashing against restrained red corruption; shattered heavenly court.
- `splash_skin_warlock_hellfire_inquisitor`: Adult male Hellfire Inquisitor with shadowed face inside a tall flame-crowned black hood, black/crimson armored robes, skull waist emblem, fire in one hand and one gnarled skull staff; ash-choked heresy tribunal.
- `splash_skin_warlock_arcane_warlock`: Adult male Arcane Warlock with pale shadowed face, charcoal robes edged in antique gold and emerald, green throat/waist jewels and one staff crowned by a gold frame around a luminous green eye; forgotten subterranean archive with waking runes.
- `splash_skin_warlock_eldritch_warlock`: Adult male Eldritch Warlock with violet hood, pale stern face, royal-purple robes with broad antique-gold trim and one wood staff crowned by a gold ring containing a luminous purple eldritch eye; warped abandoned chapel with violet geometry.

`build_roster_review.py` recreates the sprite, base-style, and final contact
sheets. `install_skin_splashes.py` validates the 1254x1254 masters and installs
them into the desktop source-of-truth tree.
