# Earthen Underleggings wave prompts

Built-in ImageGen, one call per asset. The common style and isolation contract
is the repository `PROMPT_CONTRACT.md`; exact subject and edit clauses used for
this wave are recorded below.

## `p_earthen_underleggings`

```text
Use case: stylized-concept
Asset type: dual-resolution dark-fantasy RPG pants icon; detailed codex master and separately derived 32px gameplay sprite
Primary request: one complete standalone pair of Earthen Underleggings, a restrained neutral-grade mage garment
Scene/backdrop: perfectly flat solid #ff00ff chroma background for removal; no floor, shadow, gradient, texture, reflection, or lighting variation
Subject: joined underleggings of compacted charcoal-brown earthcloth and flexible clay-colored scale panels, a broad mineral-fiber waistband, layered shale-like thigh gussets, reinforced ochre knee wraps, root-fiber seams, tapered lower legs, and clearly open empty cuffs; grounded practical construction, no magic glow
Style/medium: cohesive Crownless high-detail sprite illustration; crisp deliberate edges, compact dark-fantasy form, readable silhouette, materially detailed at 128px, tasteful pixel-art influence without coarse grid imitation, painterly blur, or photorealism
Composition/framing: one garment only, orthographic front three-quarter catalogue view, centered, fully visible from waistband through both open cuffs, generous even padding, roughly 82% of the square
Lighting/mood: clear upper-left key light, deep readable shadows
Materials/textures: dense woven earthcloth, matte clay scales, rough mineral fibers; strong joined-pants silhouette readable at 32px
Constraints: exactly one connected pair of pants; open hollow cuffs with no feet, shoes, or boots; no body, wearer, mannequin, detached parts, VFX, watermark, or #ff00ff/magenta in the object
Avoid: text, letters, numbers, logos, readable runes, UI frame, card, floor, environment, person, legs, feet, duplicate garment, loadout, skirt, separate boots, cast shadow, contact shadow, sparks, smoke, blur
```

## `p_earthen_underleggings_B`

```text
Use case: precise-object-edit
Primary request: transform the neutral master into a masterwork B-grade Earthen Underleggings variant while preserving silhouette, pose, scale, open empty cuffs, and flat #ff00ff background
Subject: retain charcoal earthcloth and clay scale construction; add cleaner interlocked shale thigh plates, double root-fiber stitching, sculpted ochre knee bindings, small dull-bronze mineral clasps, and one tiny contained warm amber stone accent at the waistband
Constraints: exactly one garment; grade through construction, not recolor; no wearer, body, feet, boots, detached effects, text, shadow, or magenta in the object
```

## `p_earthen_underleggings_A`

```text
Use case: precise-object-edit
Primary request: transform the neutral master into an exceptional A-grade Earthen Underleggings variant while preserving silhouette, pose, scale, open empty cuffs, and flat #ff00ff background
Subject: layered dark basalt lamellae over rich umber geomancer cloth, articulated copper-and-stone knee guards, braided root-silk seams, faceted agate waist fittings, and restrained warm amber mineral veins contained within the knees
Constraints: exactly one garment; grade through exotic layered construction, not recolor; no wearer, body, feet, boots, detached effects, text, shadow, or magenta in the object
```

## `p_earthen_underleggings_S`

```text
Use case: precise-object-edit
Primary request: transform the neutral master into a legendary S-grade Earthen Underleggings variant while preserving silhouette, pose, scale, open empty cuffs, and flat #ff00ff background
Subject: legendary worldstone cloth, interlocking obsidian-and-bronze thigh layers, rich geode waist fittings, sculpted mountain-face knee guards, razor-clean root-gold seams, and compact luminous amber fault lines contained within plates
Constraints: exactly one garment; richest construction legible in grayscale; no wearer, body, feet, boots, detached stones or VFX, text, shadow, or magenta in the object
```

## `u_faultstone_underleggings`

```text
Use case: stylized-concept
Primary request: one complete standalone pair of Faultstone Underleggings, a named A-grade mage unique with its own silhouette and construction
Scene/backdrop: perfectly flat solid #ff00ff chroma background
Subject: asymmetrical smoky-umber stone-thread trousers; one thigh crossed by split gray faultstone held in copper staples, the other wrapped in layered clay bands; jagged tectonic-seam belt clasp; mismatched angular knees with dim amber mineral veins; tapered legs and open empty cuffs
Constraints: one independent named-unique garment; all plates attached; no wearer, body, feet, boots, detached effects, text, shadow, or magenta in the object
```

## `u_worldmantle_underleggings_beyond_the_firmament`

```text
Use case: stylized-concept
Primary request: one complete standalone pair of Worldmantle Underleggings Beyond the Firmament, a named S-grade mage unique with an independent legendary silhouette
Scene/backdrop: perfectly flat solid #ff00ff chroma background
Subject: midnight worldstone cloth and curved continental basalt plates; high horizon-arc waistband with dark-bronze meridian ribs; broad asymmetric landmass thigh mantles; deep-blue crystal knee cores in orbital stone frames; pale-cyan tectonic seams to open empty cuffs
Constraints: one independent named-unique garment; all plates and crystals attached; no wearer, body, feet, boots, globe, detached planets or VFX, text, shadow, or magenta in the object
```

The first Worldmantle output was rejected for a duplicate pixel-art pants inset
in the lower-right and preserved as
`../generated/u_worldmantle_underleggings_beyond_the_firmament_reject01_duplicate_inset.png`.
The correction removed only that inset and restored the same flat `#ff00ff`
background while preserving the large garment unchanged.
