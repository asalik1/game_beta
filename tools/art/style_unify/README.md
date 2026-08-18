# tools/art/style_unify — the prop STYLE-UNIFY lane (2026-08-18)

Repaints world props / NPC bodies / landmarks into the ONE painterly house
style with headless Codex ImageGen, then installs them at their authored world
size. Built during the "game looks beta" polish pass (`POLISH_TASKS.md`); the
contract it serves is CLAUDE.md "World props — style + motion contract" and
`CODING_GUIDELINES.md` §40. 140+ props, 9 NPC bodies and the mill went through
it (batches A–D).

## Recipe (props)

1. **Plan** — `make_briefs.py <stage_root> [--plan my_plan.py]` writes one stage
   dir per prop: `codex_brief.txt` + `refs/1_style_<sibling>.png` (a finished
   painterly sibling = the STYLE) + `refs/2_subject_<prop>.png` (the current
   asset = silhouette/footprint/colour identity only). Put the authored world
   widths in `<stage_root>/render_w.csv` (`name,width`, from
   `Balance.SCENERY_RENDER_WIDTH` — `tools/art/dump_prop_res.gd` dumps them).
   A subject that is unreadable at 16px gets a description-led brief with NO
   subject ref instead (`rerolls.py`) — else the repaint faithfully reproduces
   a shape nobody wants (clay_pot2 → shard, candelabra → cross).
2. **Generate** — `powershell tools/art/run_codex_batch.ps1 -Stages (Get-Content
   <stage_root>/stages.txt) -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 480`.
   Serial + RAM-gated on the shared box; NEVER beside a Godot suite
   (`tools/CODEX_HEADLESS.md`). ~5-8 min per prop.
3. **Look** — `vet_sheet.py <stage_root> vet.png` (old | new per prop) and
   `green_check.py <stage_root> g.png names…` (share of greenish opaque pixels;
   a translucent subject like a web soaks the key up wholesale). Judge style
   BESIDE siblings, not against the old asset.
4. **Install** — `install_stage.py <stage_root> [names]`: key (`ensure_alpha`,
   corners that are chroma green get keyed even when the PNG already carries
   alpha), −14 % saturation tone-match, gamma 1.0, `install_prop_hires.install`
   → `game/` + `mobile/` mirrors, `_backup_<name>.png` beside the result.
5. **Animated statics** — `derive_stage.py [names]` rebuilds `<name>_anim.png`
   from the new static (`derive_prop_anim.py`) at LOW amps: pulse 0.08-0.12,
   fire 0.20-0.22 (§40c). Rigid props = pulse only (autotest's four-frame
   contract: frame == static canvas, baseline ≤ 1 px, centre ≤ 2 px).
6. **Gate** — `python tools/art/audit_prop_anims.py` (0 flagged),
   `python tools/art/verify_art.py <names>` (only IMPORT-stale fails until the
   `--import`), then `--import`, compile gate, `test_quick`, full `test.bat`,
   `preflight.bat`, `sync_mobile.py --apply --gate`. Then WATCH it: `shot.bat
   polish --gif`.

## Recipe (NPC bodies + landmarks)

`make_npc_briefs.py <stage_root>` → same batch runner → `build_npcs.py
<stage_root> --install` (Scholar-Ivo canvas: 256², body 223, feet 238, static
== single-frame `_anim`; legacy `_walk` strips removed; the mill → 384px
override). Add every new NPC name to `Balance.NPC_HEIGHT_BY_SPRITE` +
`NPC_BODY_TARGETS` (52.0); a building through the NPC path gets its footprint
from `NPC_HEIGHT_BY_SPRITE` (mill 2.3) and a base shadow in `_make_npc`.

## Files

| script | job |
|---|---|
| `_common.py` | repo-relative paths (`REPO`, `SPR`), `STYLE_UNIFY_STAGES` env for the stage root |
| `make_briefs.py` | repaint briefs (style sibling + subject); default PLAN = batch D |
| `rerolls.py` | description-led briefs, no subject ref |
| `make_npc_briefs.py` | 9 wanderer NPC archetypes + the mill |
| `make_wall_briefs.py` | seamless 128px WALL fields (weathered irregular masonry — never a brick grid); install with `install_ground_field.py --prefix wall_field_` |
| `vet_sheet.py` / `green_check.py` | the LOOK step |
| `install_stage.py` | key → tone-match → install (game + mobile) |
| `derive_stage.py` | rebuild `_anim` strips for animated statics |
| `build_npcs.py` | NPC 256² bodies + mill override |

Batches A–D stage dirs (briefs, refs, results, backups) live in the 2026-08-18
session scratchpad, not in the repo; the briefs above reproduce them.
