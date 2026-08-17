# Scholar Ivo sprite + splash source

- Generator: Codex built-in image generation (`image_gen`), driven headless via
  `tools/art/run_codex_batch.ps1` (brief + refs per staging dir)
- Generated: 2026-08-17
- Why: Ivo (ch2 Crystal Deeps chronicler, `ch2_scholar` convo, bread_for_the_road
  + ash-jar quests) was the last named quest NPC still wearing the shared 32px
  `villager` placeholder (rated 4.5 in `tools/art/asset_ratings.csv`: "old
  generation: blocky, baked shadow") while every other named NPC has a 256px
  authored body + a painted dialogue splash. He also had NO splash and no
  portrait fallback, so his dialogue box was faceless.
- Style references (benchmark, not design): `archivist_lene.png`, `clerk_voss.png`,
  `aldric.png` for the sprite; `portrait_archivist_lene.png` + `portrait_clerk_voss.png`
  for the splash (design ref = the finished sprite master).
- Sprite: `built_in_source.png` (raw 1024, chosen roll B), transparent master
  `scholar_ivo_transparent.png`, alternate roll `alt_candidate_gen_a_transparent.png`
  (on-contract too, darker + vials at the waist; not installed).
- Splash: `splash/portrait_scholar_ivo_source.png` (raw 1024) → 1254² master in
  `art_src/character_splashes/generated/portrait_scholar_ivo.png` (+ manifest row
  `npc / scholar_ivo / Scholar Ivo`); installed as `splash_scholar_ivo.png` — the
  dialogue frame resolves it from the speaker slug automatically.
- Build: `python art_src/npcs/scholar_ivo/build_scholar_ivo.py --install` writes
  `game/assets/sprites/scholar_ivo.png` + `scholar_ivo_anim.png` (256×256, body 223 px
  high, feet at y=238 — Aldric's export geometry; single-frame idle like the roster).
- Briefs: `codex_brief_sprite.txt`, `splash/codex_brief.txt` (verbatim, reproduce from
  these; the design contract lives in the brief, not in a screenshot).
- QA: `shot.bat ivo` (game/shot_ivo.gd) — Deeps room beside the hero at 2× and 4×,
  codex Folk row, dialogue splash.

## Design contract (short)

Old lean chronicler, late sixties, tall and slightly stooped; white-grey swept-back
hair + short beard; long faded slate-blue/grey-teal wool coat with a grey-fur collar
and a charcoal shoulder mantle; dark trousers, worn brown boots, fingerless gloves.
Ledger under the LEFT arm, small brass tuning fork raised in the RIGHT hand, chest
strap of corked vials (two glowing pale violet), brass loupe on a cord. Negatives:
no spectacles (Voss), no hood/hat, no staff/lantern/satchel/weapon, no runes, no
gold, no glow effects, no scenery/shadow/text on the sprite.

## Wiring (same change)

- `ch2_zones_act2.gd` Deeps npcs: `"sprite": "villager"` → `"scholar_ivo"`
- `balance.gd` NPC_HEIGHT_BY_SPRITE (1.00) + NPC_BODY_TARGETS (52.0)
- `hud.gd` PORTRAIT_CAST `["scholar ivo", "scholar_ivo"]` (small-portrait fallback;
  full name so a bare "ivo" never matches "Survivor")
- `codex.gd` NPC_ROLES `"scholar_ivo": "Chronicler of the Deeps"`; the Folk row +
  detail derive from the sprite/convo automatically
- `story.gd` NPC_LORE bio re-keyed `"villager"` → `"scholar_ivo"` (it was Ivo's text)

PixelLab was not used. PixelLab is not authorized for NPC generation unless the
owner explicitly authorizes it for that specific task.
