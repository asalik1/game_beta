# Original fishing sprites — 2026-09-07

Generated with the built-in ImageGen tool for this project. No third-party
pack or external artwork was used. Both assets are original RGBA 1254 × 1254
PNG outputs, copied without pixel edits. Godot uses linear filtering and
mipmaps. The atlas is read as four 627 × 627 `AtlasTexture` regions; opaque
fish silhouettes remain inside their cells (minimum 19px horizontal padding).
Fish visible widths are 569–588 source pixels, versus at most roughly 300
pixels per atlas cell in this UI (the fish itself is smaller), giving at
least 2.09 source pixels per screen pixel. The nook renders from 1254px to 128 world pixels tall.

Installed:

- `game/assets/sprites/fishing_fish_atlas.png`
- `game/assets/sprites/fishing_nook.png`
- Mirrored under `mobile/game/assets/sprites/`.

Generated originals (Codex image output directory):

- `exec-ba599fd9-6144-47ec-a62e-f1e58f9cba92.png` — fish atlas
- `exec-e9edcf64-7fe4-4505-8f13-71a1a5cf2652.png` — nook

Fish atlas prompt:

> Create ONE production game sprite atlas: exactly 4 fish, arranged in a precise 2 by 2 grid of equal square cells on a genuinely TRANSPARENT alpha background. This is an original asset for Crownless, a painterly dark-fantasy action RPG. All four fish are horizontal side views, head to the LEFT, body entire including every fin/tail inside their own cell with generous 15 percent clear padding, centered in each quadrant. Top left: Greyrun Dace, a small elegant silver blue river fish with teal dorsal fins. Top right: Copperfin, a sturdy warm bronze and copper carp with russet fins. Bottom left: Glass Eel, one sinuous pale lavender translucent freshwater eel with a subtle pearlescent blue highlight, gently curved horizontal silhouette. Bottom right: Crown Koi, an ivory and charcoal koi with restrained luminous golden patches and regal long delicate fins. Soft hand-painted illustration, realistic natural fish anatomy with modest fantasy accents, crisp coherent forms and textured brushwork, subtle shading, no black outlines, no pixel art, no 3D plastic. Consistent illumination from upper left. Fish all comparable visible width, each at least 600px wide. No water, no shadows outside silhouettes, no labels, letters, text, frames, grid lines or ornamental backgrounds. Four separated sprites, absolutely nothing crossing a cell boundary. Render large square atlas.

Nook prompt:

> Original single game scenery sprite, a humble fishing nook for a painterly dark fantasy RPG. Genuine transparent alpha background. A small weathered wooden tackle box and tightly woven round wicker creel on a little cluster of mossy flat stones, with one slender bent ashwood fishing rod propped diagonally against the box, rod pointing up and RIGHT, a tiny brass reel and ivory-red float tied near its tip. No fish, no people, no water, no shore, no landscape. Three-quarter elevated top-down game camera (roughly 40 degrees down), see the box top and front; grounded compact object, slightly taller than wide because of rod. Soft shaded hand painted natural materials, restrained aged browns, olive moss and dull brass, crisp brushwork, no black outline or pixel art. Entire rod including tip, box, basket and stones must fit fully inside canvas with generous clear padding. Silhouette must read at about 110px tall in game; simplify tiny clutter. One coherent prop on transparent background, no text, border, checkerboard, glow or lighting effects outside silhouette. Large square canvas.
