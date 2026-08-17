# Paladin chapter-opener reskin — 2026-08-17

The 16 paladin opener plates were painted with the OLD paladin design (a
**red-caped, hooded** silver knight). This pass repaints the paladin in every
plate to the current in-game design while keeping each scene otherwise
untouched (composition, camera, other figures, background, lighting, grade).

## The design target (owner ruling 2026-08-17)

Match the **in-game paladin sprite** (`game/assets/sprites/paladin.png`), NOT
the class splash — the owner confirmed the splash is itself outdated and needs
its own regen. "Match the idea as closely as possible without breaking details";
pixel-exact fidelity not required. The idea:

- **BARE-HEADED, open bearded face** — greying brown hair, full short dark beard,
  stern middle-aged man. NO hood, NO helm. (This was the whole point — a first
  pass, kept in git history at the `_v1` stage, left the hoods on and was wrong.)
- Battle-worn **pale brushed steel** plate with **antique-gold** trim.
- **Judicial-blue** tabard/surcoat at the front.
- **Gold chain** across the chest to a round **gold sun medallion** at the sternum.
- A steel **shield** with a gold **sun** mark; a square **reliquary-box warhammer**
  (gold sun on the head) on a **gold chain**. Small gold sun motifs on belt/pauldron.
- No bright red cape (dark tattered cloak instead). No halo/wings/crown/cross,
  no eclipse black-gold or red corruption (those are reserved for premium skins).

## The 16 plates

`frames.txt` lists them: `opening_paladin_0/1/2` (ch1 class intro, at
`opening/`) + `opening_chN_paladin` for ch2–ch14 (at `opening/chapters/`).

## Method (reproducible)

Built-in Codex `image_gen` **edit** flow, one job per plate, via
`tools/art/run_codex_batch.ps1`. Each `<tag>_v2/` holds `codex_brief.txt`
(verbatim) + `codex_result.md`; the edit target was the backed-up original and
the design reference was `paladin_ingame_sprite_ref.png` (the in-game sprite,
alpha-cropped and 3× nearest-upscaled for legibility). The edit preserves the
scene and swaps only the figure; Codex returned exact 1672×941 frames.

- `originals/` — the replaced plates (standing rule: back up, never delete;
  also in git history before this commit).
- `<tag>_v2/opening_..._reskin.png` — the accepted reskin per plate.
- `paladin_ingame_sprite_ref.png` — the design reference handed to Codex.
- `reskin_qa.jpg` — before/after contact sheet.
- `fit_and_install.py` — center-crops to the sibling 16:9 geometry (a no-op
  here since Codex already returned 1672×941) and installs with an atomic,
  retry-on-lock write (Godot auto-reimport transiently locks the PNGs).
  `--install` copies into `game/assets/sprites/opening/`.

In-engine check: `shot.bat palopener --chapters=ch1,ch8,ch11,ch14`
(`game/shot_palopener.gd`) replays the paladin opening cinematics and shoots the
plate at each narrator beat. Mobile synced (`tools/sync_mobile.py --apply`).

PixelLab was not used.
