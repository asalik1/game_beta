# Ser Aldric sprite source

- Generator: Codex built-in image generation (`image_gen`)
- Generated: 2026-07-25
- Reference images: previous `aldric.png`, `callis.png`, `old_hunter.png`, and
  `vessa.png`
- Source: `built_in_source.png`
- Transparent master: `aldric_transparent.png`
- Approved game exports: `game/assets/sprites/aldric.png` and
  `game/assets/sprites/aldric_anim.png`

## Prompt

Create a genuinely new, high-quality production pixel-art sprite of Ser Aldric
for the existing Crownless game. Use the current Aldric image only as a design
reference and the three newer named NPC images as the quality/style benchmark.
He is a lean older veteran with short graying hair and beard, a dulled steel
breastplate beneath a charcoal travel mantle, a modest amber tabard worn thin,
one visibly stiff injured arm held close to his torso, and a sheathed old sword.
His silhouette should communicate spent cost and weary duty, not a royal knight
or heroic champion. Match the newer NPCs' low top-down, south-facing full-body
pixel-art perspective, restrained dark-fantasy palette, readable silhouette,
material definition, and grounded proportions. No crown, no helmet, no shield,
no dramatic pose, no scenery, no cast shadow, and no text. Place one centered
character on a flat bright green chroma-key background.

## Export notes

The chroma background was removed with the built-in imagegen skill's
`remove_chroma_key.py` helper using border auto-key, soft matte, and despill.
The visible body was reduced to 223 pixels high and placed on a transparent
256×256 canvas with its feet at y=238, matching the authored scale and baseline
of the newer named NPC sprites.

PixelLab was not used. PixelLab is not authorized for NPC generation unless the
owner explicitly authorizes it for that specific task.
