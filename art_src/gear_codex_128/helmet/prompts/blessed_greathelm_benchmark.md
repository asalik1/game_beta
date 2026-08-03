# Blessed Greathelm benchmark prompts

Generator: built-in ImageGen only. PixelLab was not used. All prompts used the
default green key. The generated field showed mild radial brightness variation,
but remained border-connected and was removed cleanly by the shared helper.

## Neutral — `h_blessed_greathelm`

```text
Use case: stylized-concept
Asset type: Crownless dark-fantasy RPG helmet icon; 128x128 codex master with a separately derived 32x32 gameplay export
Primary request: Create one isolated neutral-family Blessed Greathelm, a paladin greathelm associated with magical warding and resistance. It is a sober fully enclosed steel greathelm with an architectural chapel-vault silhouette, narrow cross-shaped visor slit, reinforced brow, ivory-enamel panels, restrained aged-brass edging, and one small sun-oath relief on the forehead. Plain excellent construction, no damage, no magical glow, no rarity-color wash.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key field for removal
Style/medium: authentic crisp hand-pixelled dark-fantasy RPG item art, genuinely detailed at an intended 128x128 master; deliberate square pixel clusters, limited cohesive palette, selective dark outline, hard material edges, no smooth digital painting, no vector rendering, no 3D render
Composition/framing: single helmet only, three-quarter front view, centered, upright, fully visible, generous even padding; bold clean silhouette that remains unmistakably a greathelm at 32x32
Lighting/mood: controlled upper-left forge light, somber heroic mood, restrained contrast
Color palette: cold worn steel, warm ivory enamel, muted aged brass, deep charcoal visor; do not use #00ff00 in the object
Materials/textures: readable hammered steel, enamel, subtle brass wear; avoid noisy microtexture
Constraints: helmet only with hollow dark interior; no wearer, no head, no face, no eyes, no neck, no torso, no shoulders, no plume, no weapon, no shield, no pedestal, no border, no UI frame, no text, no watermark. Background must be exactly one uniform #00ff00 with no shadow, gradient, texture, reflections, floor plane, or lighting variation. No cast shadow, contact shadow, glow spill, or reflection on the background.
```

## B — `h_blessed_greathelm_B`

Edit reference: the neutral generated source.

```text
Use case: precise-object-edit
Asset type: dual-resolution Crownless dark-fantasy RPG gear icon; B-grade detailed codex master and separately derived 32px gameplay sprite
Input image: Image 1 is the exact neutral Blessed Greathelm family, composition, palette, and material-layout anchor.
Primary request: Create the B-grade masterwork version by making a restrained surface-quality edit to Image 1. Preserve exactly the same helmet silhouette, proportions, orientation, crop, cross-shaped visor, pointed chapel-vault crown, panel layout, and—critically—the same broad warm ivory front panels, bright cold-steel side/crown panels, aged-gold bands, and black visor. Do not replace ivory with gray. Add only precise shallow prayer-scroll engraving inside the gold structural bands, cleaner polished edges, finer fasteners, one small faceted amber ward crystal replacing the plain round center of the existing forehead sun, and a few tiny contained amber highlights. It should read as better made and slightly magical while remaining closer to neutral than A.
Scene/backdrop: retain the removable flat solid #00ff00 chroma background from Image 1; no floor, shadow, gradient, texture, reflection, or lighting variation
Style/medium: preserve the cohesive Crownless high-detail sprite illustration and exact edge character of Image 1; crisp deliberate edges, compact dark-fantasy form, materially detailed at 128px, readable at 32px; no painterly blur, vector art, 3D render, or photorealism
Composition/framing invariant: one empty helmet only, same three-quarter orthographic catalogue view, centered, fully visible, same generous padding and scale
Lighting/mood: preserve the same clear upper-left key light and readable shadows; only restrained local amber magic in the forehead crystal
Constraints: change only band engraving, finish quality, small fasteners, and the central ward crystal. Do not darken the helmet, redesign panels, add filigree across the ivory or steel faces, add new structural pieces, readable text, detached ornament, plume, wings, halo, person, head, face, eyes, neck, torso, shoulders, second item, environment, UI, pedestal, border, watermark, cast shadow, contact shadow, or glow spill. Do not use #00ff00 in the helmet.
```

## A — `h_blessed_greathelm_A`

Edit reference: the neutral generated source.

```text
Use case: precise-object-edit
Asset type: Crownless dark-fantasy RPG helmet icon; A-grade 128x128 codex master
Input image: Image 1 is the exact Blessed Greathelm family and composition anchor.
Primary request: Upgrade only the helmet's construction from neutral to A-grade Dragonforged exceptional quality. Preserve the exact greathelm silhouette, proportions, orientation, crop, cross-shaped visor, pointed chapel-vault crown, panel layout, and ivory/steel/brass family identity from Image 1. Replace ordinary steel with subtly scale-patterned pale dragonsteel, deepen the ivory enamel relief, refine the structural bands into sculpted sun-ray ridges, set a bright faceted amber-white wardstone in the existing forehead sun, and add contained luminous prayer channels following the existing brass geometry. Make it unmistakably richer and more powerful than B through exotic material, relief depth, contrast, and controlled energy—not an overall recolor.
Style/medium: preserve authentic crisp hand-pixelled dark-fantasy item art and pixel scale from Image 1; deliberate square clusters, selective dark outline, no smooth painting, vector, or 3D
Constraints: change only surface materials, construction relief, ornament, and contained ward energy. Do not redesign, enlarge, add wings, horns, or a halo. Keep a single empty helmet with hollow black interior. No wearer, head, face, eyes, neck, torso, shoulders, plume, weapon, shield, extra object, pedestal, border, UI, text, or watermark.
Backdrop invariant: retain a removable flat solid #00ff00 chroma-key background, one uniform color with no shadow, gradient, texture, floor, reflection, or glow spill; do not use #00ff00 in the helmet.
```

## S — `h_blessed_greathelm_S`

Edit reference: the neutral generated source.

```text
Use case: precise-object-edit
Asset type: Crownless dark-fantasy RPG helmet icon; S-grade 128x128 codex master
Input image: Image 1 is the exact Blessed Greathelm family and composition anchor.
Primary request: Upgrade only the helmet's construction from neutral to S-grade Emberforged legendary quality. Preserve the exact greathelm silhouette, proportions, orientation, crop, cross-shaped visor, pointed chapel-vault crown, panel layout, and ivory/steel/brass family identity from Image 1. Forge the shell from immaculate dark-silver celestial steel with deep sculpted ivory enamel, make the structural bands richly worked pale gold, set a brilliant sunrise wardstone in the existing forehead sun, and run a small number of strong ember-white oath channels through the existing geometry. Add the richest relief and fittings in the family with unmistakable contained legendary radiance, but keep hard material surfaces and a clean readable shape. It must clearly exceed A through workmanship, luminous depth, and finest material—not an overall color wash.
Style/medium: preserve authentic crisp hand-pixelled dark-fantasy item art and pixel scale from Image 1; deliberate square clusters, selective dark outline, no smooth painting, vector, or 3D
Constraints: change only surface materials, construction relief, ornament, and contained ward energy. Do not redesign, enlarge, add wings, horns, external flames, floating particles, or halo. Keep a single empty helmet with hollow black interior. No wearer, head, face, eyes, neck, torso, shoulders, plume, weapon, shield, extra object, pedestal, border, UI, text, or watermark.
Backdrop invariant: retain a removable flat solid #00ff00 chroma-key background, one uniform color with no shadow, gradient, texture, floor, reflection, or glow spill; do not use #00ff00 in the helmet.
```

## Named A — `u_saintglass_greathelm`

```text
Use case: stylized-concept
Asset type: Crownless dark-fantasy RPG named-unique helmet icon; 128x128 codex master with separately derived 32x32 gameplay export
Primary request: Create Saintglass Greathelm, the named A-grade unique associated with the Blessed Greathelm family. It must be a completely independent greathelm design, not a brighter generic: a tall fully enclosed paladin helm constructed like a miniature cathedral reliquary, with a distinctive lancet-arch crown, narrow dark visor shaped like a chapel window, pale silver-gold structural ribs, and several large fitted panes of luminous saintglass in ruby red, sapphire blue, amber, and restrained violet. A small rose-window medallion crowns the brow. The colored panes form the armor shell itself rather than floating decorations. Exceptional A-grade workmanship and contained holy ward light, but no external halo.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key field for removal
Style/medium: authentic crisp hand-pixelled dark-fantasy RPG item art, genuinely detailed at an intended 128x128 master; deliberate square pixel clusters, limited cohesive palette, selective dark outline, hard readable material edges, no smooth digital painting, no vector rendering, no 3D render
Composition/framing: exactly one helmet, three-quarter front view, centered, upright, fully visible, generous even padding; distinctive silhouette that remains unmistakably a greathelm at 32x32
Lighting/mood: controlled upper-left light plus contained jewel-like illumination inside the glass, solemn sacred mood
Color palette: pale silver, muted antique gold, ruby, sapphire, amber, restrained violet, deep charcoal visor; do not use green or #00ff00 in the object
Materials/textures: leaded stained saintglass panels, engraved silver-gold ribs, dark steel interior; a few large graphic panes rather than noisy mosaic fragments
Constraints: helmet only with hollow dark interior; no wearer, head, face, eyes, neck, torso, shoulders, plume, wings, weapon, shield, extra object, pedestal, border, UI frame, text, or watermark. Background must be exactly one uniform #00ff00 with no shadow, gradient, texture, reflections, floor plane, or lighting variation. No cast shadow, contact shadow, floating particles, glow spill, or reflection on the background.
```

## Named S — `u_unshadowed_greathelm_of_the_final_oath`

```text
Use case: stylized-concept
Asset type: dual-resolution Crownless dark-fantasy RPG named-unique helmet icon; detailed codex master and separately derived 32px gameplay sprite
Primary request: one Unshadowed, Greathelm of the Final Oath, the independent named S-grade unique associated with the Blessed Greathelm family, designed as a complete standalone object. It is a fully enclosed legendary paladin greathelm forged from seamless dawn-white celestial metal: a broad low cathedral dome, a single razor-clean horizontal black visor, an integrated seven-ray sunrise crest sculpted directly into the brow and crown, thick pale-gold oath bindings, and one compact white-amber heartlight recessed above the visor. Its own powerful silhouette must differ clearly from the generic Blessed Greathelm and Saintglass while remaining immediately recognizable as a protective greathelm. Legendary workmanship, richest fittings, and luminous seams contained inside the metal; no external halo or flames.
Scene/backdrop: perfectly flat solid #00ff00 chroma background for removal; no floor plane, shadow, gradient, texture, reflection, or lighting variation
Style/medium: cohesive Crownless high-detail sprite illustration; crisp deliberate edges, compact dark-fantasy form, readable silhouette, materially detailed at 128px without imitating a coarse 32px grid; tasteful pixel-art influence rather than painterly blur, vector art, 3D render, or photorealism
Composition/framing: one helmet only, empty and freestanding, three-quarter orthographic catalogue view, centered, fully visible, generous even padding, occupying roughly 82% of the square
Lighting/mood: clear upper-left key light, deep but readable shadows, solemn final-oath severity, restrained local white-amber light only in the recessed seams and brow heartlight
Color palette: dawn-white celestial metal, pale antique gold, charcoal-black visor, compact white-amber radiance; do not use green or #00ff00 in the object
Materials/textures: physically coherent seamless celestial steel, engraved gold oath bindings, hard enamel-like highlights; enough secondary construction detail to reward the 64px codex view while the main shape remains unmistakable at 32px
Constraints: preserve the exact greathelm category; strong closed silhouette; no detached noise; no wearer, head, face, eyes, neck, torso, shoulders, plume, wings, second item, scenery, UI badge, border, lettering, rarity label, readable runes, logo, pedestal, watermark, floating particles, cast shadow, contact shadow, bloom fog, smoke, or soft painterly blur.
```

## Rejections and QA

- `generated/rejected_h_blessed_greathelm_B_silhouette_drift.png`: independent
  generation changed the family silhouette too far.
- `generated/rejected_h_blessed_greathelm_B_dark_material_pass.png`: reference
  edit preserved shape but replaced too much ivory with gray, making B look
  cheaper than neutral at 128px.
- Approved alpha masters are 1254px RGBA sources. The builder emits 128px codex
  candidates and optimized 32px gameplay candidates without touching runtime.
- `tmp/gear_codex_128/helmet/qa_codex.png`: approved; detail, family ladder,
  distinct uniques, and chroma edges pass on a dark field.
- `tmp/gear_codex_128/helmet/qa_gameplay.png`: approved; all six remain readable
  greathelms at 32px with no visible green fringe.
