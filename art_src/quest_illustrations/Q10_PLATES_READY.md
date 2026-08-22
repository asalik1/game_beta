# Q10 quest art — DONE (2026-08-21)

All Q10 quest art generated (headless Codex, off each giver's canon splash),
installed, and wired. Full suite green.

## Illustrated turn-in plates (opening/quests/)
- **quest_straight_answer.png** — Scholar Ivo reading the warden transcription
  in the Crystal Deeps. Scene `straight_answer_scene`, cue `q_straight_answer`,
  chained from both fork choices (publish / summarize).
- **quest_second_bell.png** — Sentry Piet with the split bell shard at the
  night fence. Scene `second_bell_scene`, cue `q_second_bell`, from `sp_told`.
- **quest_salt_reliquary.png** — the Choir pilgrim's hymn stops as her debt
  goes quiet. Scene `salt_reliquary_scene`, cue `q_salt_reliquary`, from her
  "the stone's quiet now" turn-in coda (`hp_done`).

## Custom sprites (assets/sprites/)
- **salt_token.png** (64px item icon) — the pilgrim's pressed grey salt disc;
  restored the QUEST_ITEMS "icon" field (the Curios codex now resolves it).
- **fallen_bell.png** (160px prop) — cracked bronze bell; replaced the
  `watch_brazier` stand-in on the Howling Fields ZONE_PROPS bell hook.
  (White-keyed from the gen's near-white background, cropped, centred.)

Staging (briefs + refs + source) under art_src/quest_illustrations/{straight_answer,
second_bell,salt_reliquary}/, art_src/item_sprites/salt_token/,
art_src/prop_sprites/fallen_bell/.

Note: the second_bell plate is a deliberately dark night scene — re-roll if the
owner wants it brighter (gen is cheap). The salt_token icon reads slightly
cream rather than grey; acceptable at icon size, re-rollable if flagged.
