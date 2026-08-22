# Q10 quest-illustration plates — STAGED, ready to generate (2026-08-21)

Two turn-in plates for the Q10 ch2 quests just built (both givers have a
canon splash, so they follow the canon-ref rule). Briefs + refs are staged;
the gen was blocked at author time only by low free RAM on this box
(0.80 GB free of 9.85; the image-gen floor is 1.3 GB — forcing risks the
documented host OOM). Run when RAM frees:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 `
  -Stages "C:/Users/asali/Projects/MMO/art_src/quest_illustrations/straight_answer,C:/Users/asali/Projects/MMO/art_src/quest_illustrations/second_bell" `
  -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 600 `
  -ExtraArgs "--dangerously-bypass-approvals-and-sandbox"
```

Then per plate: LOOK at `quest_<base>.png`, re-roll if weak (gen is cheap),
install to `game/assets/sprites/opening/quests/quest_<base>.png` (+ `--import`),
and wire the turn-in `scene`:

- **straight_answer** (Scholar Ivo reading the warden transcription in the
  Crystal Deeps): add `"scene": "straight_answer_scene"` to Ivo's fork
  choices (s_publish/s_kind precursor, or the s_fork node) in
  `content/ch2_quests.gd`, with a `{"cinematic": true, ... "cue": "q_straight_answer"}`
  convo. cue → `quest_straight_answer.png`.
- **second_bell** (Sentry Piet handed the split bell shard at the night
  fence): add `"scene": "second_bell_scene"` to Piet's `sp_told` path,
  cue `q_second_bell` → `quest_second_bell.png`.

NOT wired yet on purpose: wiring a `scene` before its plate exists shows a
broken cinematic (Cutscene loads a missing PNG). Wire only after install.

Deferred plate: **salt_reliquary** — its turn-in is an OBJECT beat (salt disc
on the boundary stone; the pilgrim isn't present), so it needs an object/
landscape plate, not a character one — lower priority.
Deferred sprite: **salt_token** item icon (currently omitted; Curios codex
shows a graceful blank). Needs a small grey-salt-disc sprite in the
sera_loaf/bastion_ash item style.
