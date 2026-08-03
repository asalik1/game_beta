# Shared ImageGen prompt contract

Every generated file represents exactly one item. Preserve the noun and named
concept from `manifest.json`; do not add a character, hand, mannequin, second
item, scenery, UI badge, border, lettering, or rarity label.

Use this common block and change only the subject/material clauses needed for
the exact key:

```text
Use case: stylized-concept
Asset type: dual-resolution dark-fantasy RPG gear icon; detailed codex master
and separately derived 32px gameplay sprite
Primary request: one <EXACT ITEM>, designed as a complete standalone object
Scene/backdrop: perfectly flat solid <KEY COLOR> chroma background for removal;
no floor plane, shadow, gradient, texture, reflection, or lighting variation
Style/medium: cohesive Crownless high-detail sprite illustration; crisp deliberate
edges, compact dark-fantasy forms, readable silhouette, materially detailed at
128px without imitating a coarse 32px grid; tasteful pixel-art influence rather
than painterly blur or photorealism
Composition/framing: one object only, orthographic catalogue view, centered,
fully visible, generous even padding, occupying roughly 82% of the square;
weapons run lower-left to upper-right unless their identity requires otherwise
Lighting/mood: clear upper-left key light, deep but readable shadows, restrained
local magical light only where the item concept calls for it
Materials/textures: physically coherent metal, leather, cloth, bone, wood, glass,
stone or enamel; enough secondary construction detail to reward the 64px codex
view while the main shape remains unmistakable at 32px
Constraints: preserve the exact item category; strong closed silhouette; no
detached noise; no watermark; do not use <KEY COLOR> anywhere in the object
Avoid: text, letters, numbers, logos, runes that resemble readable text, UI
frame, card, pedestal, environment, person, hand, mannequin, duplicate object,
loadout, cast shadow, contact shadow, bloom fog, smoke cloud, soft painterly blur
```

## Family and grade language

- Neutral family: well-made but restrained; establishes the unmistakable shape
  used by the B/A/S ladder.
- B: same family silhouette, masterwork construction, fine inlay or etched
  ornament, one restrained local magical accent.
- A: same family identity, exotic layered material, stronger relief and
  contained energy; visibly exceptional without relying on a color wash.
- S: same family identity at legendary workmanship, richest fittings, luminous
  seams or compact sparks; dramatic but still one readable object.
- Named A/S unique: an independent object with its own silhouette details,
  construction idea and palette. It must still read immediately as its manifest
  noun and may not be a brightened generic.

Grade must remain legible in grayscale through construction and ornament. Avoid
making B blue, A brown, and S gold versions of the same drawing.

## Key-background choice

- Default to flat `#00ff00`.
- Use flat `#ff00ff` when the item contains important green, teal, cyan, foliage,
  poison, verdancy, emerald, or green magical light.
- If the item requires vivid magenta/purple as well as green, choose the field
  with the smaller semantic collision and explicitly prohibit that exact field
  color inside the subject.

After generation, preserve the untouched chroma output under `generated/` and
use the imagegen skill's installed `remove_chroma_key.py` helper to create the
candidate in `alpha/`. Inspect transparency, semantic identity, object count,
edge spill, and both intended reading sizes before accepting it.
