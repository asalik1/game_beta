# Tool index — every script an agent might need, one line each

The map for `tools/`, the root `.bat`s, and the in-engine dev rigs. If you are
about to write a helper script, check here first — it probably exists.
Details live in each tool's `--help` / doc comment; deep pipelines have their
own docs (`tools/art/README.md`, `mobile/README.md`).

Engine binary for every headless command: `tools\Godot_v4.4.1-stable_win64_console.exe`.

## Gates & suites (run these, in this order — CLAUDE.md "Testing")

| tool | what it does |
|---|---|
| `preflight.bat` (`tools/preflight.py`) | mechanized trap checks: stale/missing `--import`, unregistered content modules, codex/BOSS_KINDS staleness, diff-scoped balance-number + CONNECT_DEFERRED lints. Run before staging; prints the fix per finding. `--fast` skips the engine data check. |
| `test_quick.bat` | ~15s: compile gate → boot → one class kit → systems → UI smoke → pause menu. The iteration loop. |
| `test.bat` | full suite (minutes, both chapters end to end). Required green before staging. |
| `game/check_compile.gd` | the compile gate itself (both bats run it FIRST — never invoke the test scene directly; a parse error makes the headless engine idle forever). |
| `suite_verdict.ps1` | log-grep verdict helper the bats use (exit code alone lies). |
| `net_test.bat` | 16-stage multiplayer proof over localhost ENet (feature waves + soak). |
| `dps_bench.bat` (`game/scripts/tests/dps_bench.gd`) | per-class max sustained DPS vs an average-L40 immortal dummy; parallel 6-process, ±5% variance. |
| `game/econ_audit.gd` | reward-economy audit: what each chapter actually pays, first run vs replay, per faucet. Run before touching reward numbers. |

## Git & multi-agent

| tool | what it does |
|---|---|
| `tools/safe_commit.py` | path-scoped commit guard: declare YOUR paths, it stages/commits only those and lists sibling-staged work instead of swallowing it. `--all-staged --confirm` for a deliberate full-index commit. Refuses attribution trailers. (No commits unless the user asks — CLAUDE.md.) |

## Mobile

| tool | what it does |
|---|---|
| `tools/sync_mobile.py` | game/ → mobile/game/ re-sync. Default = drift report (CRLF-blind, delta-aware); `--apply` re-copies + re-applies the README deltas (incl. the project.godot transform); `--apply --gate` then runs import + compile gate + quick suite on mobile/game. |

## Art — verify

| tool | what it does |
|---|---|
| `tools/art/asset_gallery.py` (+ `game/asset_dump.gd`) | THE visual catalogue: walks every data table in the real engine, assembles each key's file family, measures it, and writes one HTML page showing every wired visual asset with a 0–10 rating. Ratings live in `tools/art/asset_ratings.csv` (hand-managed, preserved across runs; the page can also rate inline and export it). `--sheets` writes labelled per-category contact sheets. Also reports art wired-but-absent and files nothing resolves. |
| `tools/art/verify_art.py` | post-install sprite checks for a base name: strip geometry (engine floors frames = w/h), 8-dir completeness, `*_dir` 8·K frame count, green-bleed semi-alpha, stale `--import`. `--all` sweeps the whole sprites dir. |
| `tools/art/anim_sheet.py` | labeled per-clip contact sheets (8 facings × frames, 1-based) — the owner's QA format for animation review. |
| `tools/art/dip_check.py` | flags a character whose weapon dips below its feet per direction (anchor trouble). |
| `tools/art/recenter_strip.py` | repairs square-cell strips whose figures were assembled OFF the frame grid (mob visibly slides side to side each loop): column-band segmentation reunites cross-boundary bleed, then each figure re-centres in its cell on the feet-band centroid. No `--apply` = audit only. |
| `game/qa_skins.gd` | boots the real game once per class, equips every skin (base + awakened), screenshots. |

## Art — generate & install

| tool | what it does |
|---|---|
| `tools/art/IMAGEGEN_SPRITE_PIPELINE.md` | zero-context, end-to-end built-in ImageGen playbook: lore/identity contract, prompts, timelines, source preservation, deterministic extraction, directional repairs, runtime wiring, visual QA, Godot tests, and mobile sync. |
| `tools/art/extract_sheet.py` | pre-keyed animation sheet → engine clip strips (the alpha-key/solidify/mirror/feet-anchor pipeline; see `tools/art/README.md`). |
| `tools/art/install_preservation_archer_walk_mirrors.py` | historical guarded Archer mirror installer; superseded by the owner's later direction-copy mapping. |
| `tools/art/install_preservation_owner_walk_copies.py` | exact owner-directed walk copies for Archer/Warlock plus the corrected seven-frame Warlock South install. |
| `tools/art/rebuild_preservation_archer_alpha.py` | rebuild Archer preservation idle/walk candidates with a border-connected key that preserves the green cape. |
| `tools/art/build_sprites.py` | rebuild every class sprite from source (per-class recipes codified), then re-import. |
| `tools/art/build_act1_directional_walks.py` | reviewed ImageGen sources -> grounded 8-direction Act 1 strips; prefers independent per-direction cycles when all eight exist, otherwise builds the reviewed 5x4 master. |
| `tools/art/enforce_act1_gait_alternation.py` | enforce and audit A/B lower-limb contact swaps while keeping generated upper bodies and low-hanging gear fixed. |
| `tools/art/build_gem_icons.py` | lore-authored 5×2 gem masters → 140 distinct 32px stat+level icons, hard-alpha QA sheet, desktop/mobile install. |
| `tools/art/build_gear_codex_icons.py` | approved transparent gear masters → 128px codex + separately optimized 32px gameplay candidates, exact 1,260-key coverage audit, dated backups and per-slot QA sheets. |
| `tools/art/upscale_hero.py` | rebuild a dark-class hero from the ChatGPT upscales (white-key, rescale, feet-anchor to original layout). |
| `tools/art/install_preservation_class_idle_walks.py` | guarded old-design Archer/Assassin/Warlock idle+walk candidate installer; validates 277px cells/180px bodies and archives the replaced runtime PNGs. |
| `tools/art/build_preservation_walk_candidate.py` | auto-detect authored figures from broad source gutters, refuse mismatched `--frames`, and build normalized preservation strips/QA. |
| `tools/art/correct_assassin_walk_hood_palette.py` | palette-only Assassin walk repair: rank-match generated f4-f6 hood/scarf colors to accepted f1-f3 without changing silhouettes, alpha, weapons, or gait. |
| `tools/art/transplant_assassin_walk_hoods.py` | exact Assassin hood/face/scarf raster transplant from accepted f1-f3 into generated f4-f6, aligned by the cyan eye while leaving the lower gait untouched. |
| `tools/art/pixellab_resize_assassin_east.py` | authorized candidate-only PixelLab Resize client for the untouched 104px Assassin east walk; uses one union crop/source palette and targets a 180px body without touching runtime assets. |
| `tools/art/pixellab_add_assassin_second_dagger.py` | authorized candidate-only PixelLab animation edit for adding one coherent off-hand dagger across the phase-aligned resized Assassin east walk. |
| `tools/art/install_assassin_approved_east_walk_mapping.py` | install the approved two-dagger Assassin east walk to E/NE/SE and its framewise mirror to W/NW/SW, preserving north/south and archiving replaced strips. |
| `tools/art/install_assassin_idle_regen.py` | build/install the full-regeneration Assassin idle set from five generated masters plus exact W/SW/NW mirrors, with runtime backups and QA GIFs. |
| `tools/art/build_pixellab_assassin_attack_review.py` | build candidate-only five-direction contact sheets/GIFs for the canonical PixelLab Assassin `attack` and `attack2` groups before resizing or installation. |
| `tools/art/pixellab_repair_assassin_attack_daggers.py` | authorized candidate-only PixelLab temporal edit for restoring exactly two short daggers in a selected one-to-four-frame Assassin attack segment. |
| `tools/art/install_char_anims.py` | PixelLab character download zip → installed 8-dir clip strips. |
| `tools/art/install_clip.py` | surgical per-clip strip installer (drift regens: replace ONE clip, touch nothing else). |
| `tools/art/install_dirset.py` | assemble PixelLab per-direction exports into `<base>_<dir>.png` sets. |
| `tools/art/install_death_flat.py` | assemble a grounded single-facing death strip (the L/R-flip death convention). |
| `tools/art/install_ability.py` | add a boss's `<key>_ability` one-shot strip in the same format. |
| `tools/art/skin_install.py` | PixelLab 8 rotation stills → static skin sprite set. |
| `tools/art/install_env_asset.py` | environment art into the Track-D seams: ground tilesets, animated props (grid/square normalize + naming). |
| `tools/art/build_capital_water_anim.py` | generated 2×2 capital water storyboard + locked static landmark → geometry-stable horizontal animation strip (only blue/cyan water pixels may change). |
| `tools/art/build_capital_polish.py` | generated Crownfall furniture/hearth sources → normalized production props, plus integrated four-frame fire strips for every fire-bearing capital landmark (no nested flame decals). |
| `tools/art/build_terrain_prop_anims.py` | generated four-frame full-object terrain props → shared-crop, footprint-anchored static + `_anim` strips (fountains, furnaces, rifts, vents, conductor, sewer outfall; no motion stickers). |
| `tools/art/build_terrain_art_fix.py` | `TERRAIN_ART_FIX_TASK.md` tier 1–3 masters → 20 palette-controlled desktop/mobile replacements plus six registered full-object `_anim` strips. |
| `tools/art/build_material_icons.py` | generated crafting-material sources → 35 transparent 32x32 Metal/Cloth/Bone/Reagent/Herb icons plus a labelled QA contact sheet. |
| `tools/art/build_capital_monumental.py` | generated Crownfall Crown Spire + connected city arcade sources → production architecture and an integrated four-frame gate-fire strip. |
| `tools/art/clean_sprite.py` | FLUX/Pollinations render → clean pixel sprite (normalize). |
| `tools/art/polligen.py` / `tools/art/flux_draft.py` | free generation lanes (pollinations.ai textures/props / FLUX concept drafts — note: HF inference is dead, see memory/ART docs). |
| `tools/art/pl_anim_ids.py` | print a PixelLab character's per-direction anim ids for a clip (frame-URL gotcha). |
| `tools/content/gen_capital.py` | regenerate `capital_hub.gd` (the 9-room, 3×3 Crownfall capital content module). |
| `gen_asset_manifest.py` | regenerate `game/assets/asset_manifest.json` (exports can't scan dirs; `export_all.bat` runs it). |

## In-engine shot rigs (windowed, boot the real game, screenshot to disk)

`shot_kit` (class FX/abilities) · `shot_loot` (loot fanfare grades) · `shot_mobs`
(mob mechanics/tells) · `shot_ui` (HUD + every menu) · `shot_audit`/`2`/`3`
(full visual surface passes) · `shot_chests` (chest grades in-world) ·
`shot_capital` (every Crownfall room + Citizen right-side facing proof + desktop/compact capital maps) ·
`shot_dirtest`/`shot_dirinstall`/`shot_actiontest` (8-direction render/install
proofs) · `shot_silence`/`shot_verdict`/`shot_readability`/`shot_wall`/
`shot_assassin_fx` (one-off readability rigs — reusable patterns). All live in
`game/`, run via `--path game res://<name>.tscn` or their `.gd` docs.

Owner reviews visuals in-game himself — rigs are for YOUR verification, not a
substitute for his pass.

## Play / build

| tool | what it does |
|---|---|
| `run_game.bat` / `dev_mode.bat` | play normally / play with the F1 debug panel (class, level, gear, terrain, bosses instantly). |
| `open_editor.bat` | open the Godot editor (beware: `--import` contends with an open editor). |
| `export_all.bat` | rebuild Win/macOS/Linux into `executables\` (regenerates the asset manifest first). |
| `make_build.bat` | cut the friends co-op zip (Windows x86_64). |
- `art/pixellab_resize_assassin_attack.py` — candidate-only PixelLab Resize pass for approved 8-frame Assassin attack directions; preserves original 212px motion coordinates while normalizing native-resolution output into 277px runtime cells.
- `art/build_assassin_stab_direction_set.py` — assembles approved PixelLab Assassin Stab clips into a candidate-only 8-direction set using the accepted side-copy/mirror policy and writes combined motion QA.
- `art/build_imagegen_attack_candidate.py` — keys, losslessly slices, normalizes, and QA-renders one candidate-only ImageGen attack row without touching runtime sprites.
- `art/build_attack_regen_review.py` — audits the 48 accepted Archer/Warlock/Warrior ImageGen attack strips and builds six consolidated all-direction review sheets/GIFs.
- `art/install_attack_regen.py` — guarded dry-run/apply installer for the approved attack manifest; archives and atomically updates desktop/mobile runtime strips and South aliases.
- `art/stabilize_attack_anchors.py` — reframe all approved attack candidates around a dense body-column X anchor in crop-safe 352px cells, eliminating weapon-padding side drift without resampling.
