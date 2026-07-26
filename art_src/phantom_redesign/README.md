# Phantom redesign concepts

These files are design explorations only. They are not wired into the game and
are not animation-ready source sheets.

The latest direction is `refined_grounded_white_phantom_concept_v2.png`; its
exact edit prompts are recorded in `refined_grounded_white_phantom_prompt.md`.

## `the_unmoored_concept.png`

- Generator: built-in image generation (`image_gen`)
- Use case: static pixel-art character design concept
- References:
  - `game/assets/sprites/skins/mythic/assassin_phantom_awakened.png`
  - `game/assets/sprites/skins/elite/assassin_blade_dancer.png`

### Prompt

> Create a single static pixel-art RPG character sprite concept for Crownless,
> presented as an enlarged nearest-neighbor preview of a roughly 96x96 in-game
> sprite.
>
> USE THE TWO REFERENCES ONLY AS FOLLOWS:
> - Reference 1 (Phantom Awakened): retain only the male spectral-assassin
>   fantasy, dark indigo/black plus luminous cyan-teal palette, and dual
>   short-blade class identity. Do NOT copy its hood, conventional rogue armor,
>   straps, cape silhouette, pose, or exact weapons.
> - Reference 2 (Blade Dancer): match only its compact full-body game-sprite
>   proportions, hard pixel clusters, readable silhouette, crisp dark outlines,
>   restrained shading, and production-quality Crownless pixel-art rendering.
>   Do NOT copy its samurai armor, colors, helmet, pose, or sword.
>
> NEW DESIGN — “THE UNMOORED”:
> A lean male mythic assassin whose living body and shadow were violently
> separated. He must read as a wholly new mythic design, not a recolor or
> upgraded hooded rogue.
> - NO HOOD.
> - His head is a small floating, smooth broken funerary mask: pale cold ivory
>   with one diagonal missing fragment and a narrow cyan eye-slit; deep
>   featureless void is visible behind it. Elegant and uncanny, not a skull and
>   not skeletal.
> - Strong asymmetric silhouette: a high torn mantle covers only his left
>   shoulder, then splits into two long spectral ribbons behind him; right
>   shoulder and arm are sleek, narrow, and visibly phasing into cyan-edged
>   darkness.
> - Slim wrapped torso with a hollow diagonal “rift” across the chest, glowing
>   from inside. Avoid ordinary leather straps, belt buckles, pouches, or generic
>   rogue armor.
> - Two solid, animatable legs and boots are still clearly present, but the outer
>   edge of one shin breaks into a few controlled spectral fragments. Do not
>   replace the legs with a ghost tail.
> - Exactly two short crescent-shaped void blades, one per hand. The blades are
>   matte black at the spine with a clean cyan inner edge. They must be small
>   enough for game animation and clearly distinct from long swords.
> - A detached shadow echo appears immediately behind and offset from the
>   character as one simple dark-indigo silhouette with only two dim cyan eyes.
>   It should enhance the silhouette without obscuring the body.
> - The character’s identity should be readable at thumbnail size through the
>   pale broken mask, one-shoulder mantle, chest rift, and offset shadow echo.
> - Restrained palette: near-black, midnight indigo, desaturated blue-gray, pale
>   cold ivory, spectral cyan/teal. No gold, no red, no purple neon.
> - Front/south-facing neutral idle stance, full body visible, centered, feet
>   planted, slight predatory lean. No attack motion.
>
> PIXEL-ART REQUIREMENTS:
> Crisp intentional pixel clusters; hard aliased edges; no painterly brushwork;
> no soft airbrush gradients; no anti-aliasing; no bloom haze covering details;
> no tiny ornamental noise. Strong readable values. Looks like a finished
> premium 2D game sprite, not a splash illustration or concept painting.
>
> COMPOSITION:
> One character only plus its single attached shadow echo. Isolated on a
> perfectly flat medium charcoal-gray background. No floor, environment, frame,
> UI, labels, text, border, vignette, particles scattered across the canvas, or
> extra weapons. Square image.

## `skull_reaper_concept.png`

- Generator: built-in image generation (`image_gen`)
- Use case: static pixel-art player-character concept
- Status: concept only; no game assets or effect layers are wired
- References:
  - `game/assets/sprites/skins/mythic/assassin_phantom_awakened.png`
  - `game/assets/sprites/skins/elite/assassin_blade_dancer.png`

### Prompt

> Use case: stylized-concept
>
> Asset type: static in-game character sprite concept for Crownless
>
> Primary request: Create one original skull-faced infernal-reaper redesign for
> the male Mythic Assassin skin, intended to replace the current hooded Phantom
> conceptually. This is the PLAYER CHARACTER SPRITE ONLY. Demons, attack echoes,
> projectiles, dash trails, summoned weapons, and other effects will be separate
> assets added later.
>
> Input images:
> - Image 1 is the current Phantom Awakened sprite. Preserve only its compact
>   Assassin class proportions, dark spectral mood, dual-dagger identity, and
>   cold cyan/teal lineage. Do not copy its hood, face, armor arrangement, cape,
>   pose, or exact daggers.
> - Image 2 is the Blade Dancer sprite. Use only its production-quality
>   Crownless pixel rendering: compact full-body scale, strong readable
>   silhouette, crisp dark outline, deliberate pixel clusters, restrained
>   shading. Do not copy its samurai armor, helmet, palette, sword, or pose.
>
> Subject:
> - One lean, menacing, clearly player-controlled male assassin standing upright
>   in a controlled south/front-facing idle stance.
> - Completely exposed skull head with NO hood and NO helmet. The skull is a
>   distinctive sculpted bone-white reaper skull, sharp cheekbones and predatory
>   jaw, deep black eye sockets containing tiny cold-cyan points of light.
>   Menacing and intelligent, not a shambling skeleton mob.
> - A compact crown of cold cyan-white ghostfire rises directly from the top and
>   rear of the skull. The idle flame is restrained, clean, and readable; only a
>   few attached flame tongues, with no detached particles.
> - Tailored supernatural reaper clothing rather than monster rags: fitted
>   near-black and midnight-indigo coat armor, high structured collar behind the
>   skull, narrow armored shoulders, wrapped forearms, tapered split coat tails,
>   solid fitted trousers and boots. Elegant, deliberate, dangerous, premium
>   player-character silhouette.
> - Subtle bone rib motifs incorporated into the torso armor, but he is not an
>   exposed skeleton and not skeletal below the skull.
> - Exactly two short hooked bone daggers, one held in each hand. Each dagger is
>   ivory bone with a narrow cold-cyan hellfire edge. The weapons must remain
>   compact enough to animate and must not resemble swords or sickles.
> - A small amount of ghostfire is attached tightly to the skull and the dagger
>   edges only. Keep the rest of the body visually clean so later gameplay flames
>   can intensify dramatically.
> - Palette: near-black, midnight indigo, muted blue-gray metal, aged ivory bone,
>   cold cyan-white ghostfire. Strong light/dark value separation at thumbnail
>   size.
> - Overall impression: an original infernal assassin-reaper, regal and
>   predatory, visibly more important than a normal enemy mob.
>
> Style/medium:
> Crisp handcrafted 2D pixel art matching the references. Render as an enlarged
> nearest-neighbor preview of a compact roughly 64–80 pixel-tall game sprite.
> Large intentional square pixel clusters, hard aliased edges, limited palette,
> sharp dark outline, minimal internal detail, no anti-aliasing, no painterly
> rendering, no smooth digital illustration, no soft gradients, no airbrush.
>
> Composition/framing:
> Exactly one full-body character, centered, front/south-facing idle stance,
> generous empty margin. Character should occupy roughly the same relative
> canvas area and body proportions as the referenced sprites rather than filling
> the entire image like a portrait.
>
> Scene/backdrop:
> Perfectly flat uniform medium charcoal-gray background with no floor plane and
> no cast shadow.
>
> Constraints:
> No demons. No shadow companion. No minion. No secondary figure. No spectral
> afterimage. No scythe. No summoned floating knives. No projectiles. No dash
> trail. No ground fire. No attack pose. No environment. No frame, UI, label,
> text, logo, watermark, vignette, or background glow. Exactly two handheld bone
> daggers and no other weapons. Original design; do not imitate any named
> existing character.

## `skull_reaper_concept_v2.png`

- Generator: built-in image generation (`image_gen`)
- Use case: targeted revision of `skull_reaper_concept.png`
- Status: concept only; no game assets are wired

### Prompt

> Use case: precise-object-edit
>
> Asset type: static pixel-art game character concept revision
>
> Input image: Image 1 is the edit target.
>
> Primary request:
> Change only the skull flame treatment so the character no longer looks bald.
> Replace the small flame sitting behind the smooth bare cranium with a
> substantial swept-back mane of cold cyan-white ghostfire that functions
> visually as supernatural hair.
>
> Required head treatment:
> - Ghostfire must visibly originate across the entire upper skull: brow ridge,
>   both temples, crown, and rear cranium.
> - Flame must wrap and overlap the sides and top edge of the skull, partially
>   obscuring the smooth dome silhouette.
> - Form a dense, coherent backward-swept flame mane with a strong angular
>   silhouette, like supernatural hair made entirely of fire.
> - Keep the skull face exposed and readable from the brow downward.
> - Use a bright near-white core close to the bone, cyan middle flame, and darker
>   teal outer pixels.
> - Keep the flame controlled enough for an idle sprite, but clearly fuller and
>   more integral than the original small candle-like plume.
> - Do not add literal human hair.
>
> Invariants:
> Preserve the exact same character identity, skull face, eye sockets,
> expression, body proportions, upright pose, clothing, coat, armor, rib motif,
> colors, hands, exactly two bone daggers, dagger flames, pixel-art rendering,
> canvas, scale, centering, and charcoal background. Change only the flame around
> the skull. Do not redesign or re-render the rest of the character.
>
> Constraints:
> No demons, companions, afterimages, scythe, extra weapons, projectiles, trails,
> ground fire, attack pose, environment, text, logo, or watermark. Maintain crisp
> hard-edged pixel clusters with no painterly softness or anti-aliasing.
