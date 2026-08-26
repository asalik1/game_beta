# Fidelity remediation 2026-08-25/26 — masters, briefs, reproduce scripts

The autonomous session that cleared the FIDELITY_AUDIT.md work list (everything except the
18 legacy skins). Results + the applied triage live in **FIDELITY_AUDIT.md** (repo root);
the working plan + per-phase log is `scripts/PLAN.md` here.

## What's here
- `mob_stages/` — 11 identity-anchored 2x2 idle masters for the 192px mob batch (+ briefs).
- `death_stages/` — 17 death 2x2 masters + banshee attack (+ the 3 boss idle anchor frames'
  first-pass stages under `boss_stages/`).
- `boss_stages/` — per-frame ~1024px remaster gens for veyx/stormmouth/vargoth idle+walk
  (+ veyx storm). Pattern: `<boss>_<clip>_f<N>` per frame, anchor = `<boss>_idle_f1`.
- `waved_stages/` — auroch/halla paired-frame LANDSCAPE masters (`_p1` = frames 1+2,
  `_p2` = 3+4), fangmaw 2x2s, stone_broken design-locked idle v2.
- `prop_stages/` — 54 prop repaint masters (trees = 2x2 canopy-rustle, statics single,
  fire/motion props 2x2 motion). `sliver_stages/` — portrait re-rolls for the tall thin
  tree variants. `misc_stages/` — critters, NPCs, choir_censer. `rerolls_stages/` — the
  drift-audit fix re-rolls (gore/continuity/FX-consistency/attire locks).
- `scripts/` — the session's build/install lane (stage prep, cutters, normalizers,
  assemblers, metric math). Boss per-frame geometry contract: re-seat each remastered
  frame to the SOURCE frame's alpha-box, uniform height scale, bottom-center anchor.

## The metric rule everything obeys
A mob/boss's strips share one body metric: idle cell change => attacks/deaths must move
by the same factor (enemy.gd renders actions at the idle cell scale); walks are
fraction-normalized by their own cell and never need to move. Boss installs therefore
pair "idle+walk remaster" with "x k metric upscale" of every action strip.
