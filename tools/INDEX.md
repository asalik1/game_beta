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
| `net_test.bat` | 11-stage multiplayer proof over localhost ENet (feature waves + soak). |
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
| `tools/art/verify_art.py` | post-install sprite checks for a base name: strip geometry (engine floors frames = w/h), 8-dir completeness, `*_dir` 8·K frame count, green-bleed semi-alpha, stale `--import`. `--all` sweeps the whole sprites dir. |
| `tools/art/anim_sheet.py` | labeled per-clip contact sheets (8 facings × frames, 1-based) — the owner's QA format for animation review. |
| `tools/art/dip_check.py` | flags a character whose weapon dips below its feet per direction (anchor trouble). |
| `game/qa_skins.gd` | boots the real game once per class, equips every skin (base + awakened), screenshots. |

## Art — generate & install

| tool | what it does |
|---|---|
| `tools/art/extract_sheet.py` | pre-keyed animation sheet → engine clip strips (the alpha-key/solidify/mirror/feet-anchor pipeline; see `tools/art/README.md`). |
| `tools/art/build_sprites.py` | rebuild every class sprite from source (per-class recipes codified), then re-import. |
| `tools/art/upscale_hero.py` | rebuild a dark-class hero from the ChatGPT upscales (white-key, rescale, feet-anchor to original layout). |
| `tools/art/install_char_anims.py` | PixelLab character download zip → installed 8-dir clip strips. |
| `tools/art/install_clip.py` | surgical per-clip strip installer (drift regens: replace ONE clip, touch nothing else). |
| `tools/art/install_dirset.py` | assemble PixelLab per-direction exports into `<base>_<dir>.png` sets. |
| `tools/art/install_death_flat.py` | assemble a grounded single-facing death strip (the L/R-flip death convention). |
| `tools/art/install_ability.py` | add a boss's `<key>_ability` one-shot strip in the same format. |
| `tools/art/skin_install.py` | PixelLab 8 rotation stills → static skin sprite set. |
| `tools/art/install_env_asset.py` | environment art into the Track-D seams: ground tilesets, animated props (grid/square normalize + naming). |
| `tools/art/clean_sprite.py` | FLUX/Pollinations render → clean pixel sprite (normalize). |
| `tools/art/polligen.py` / `tools/art/flux_draft.py` | free generation lanes (pollinations.ai textures/props / FLUX concept drafts — note: HF inference is dead, see memory/ART docs). |
| `tools/art/pl_anim_ids.py` | print a PixelLab character's per-direction anim ids for a clip (frame-URL gotcha). |
| `tools/content/gen_capital.py` | regenerate `capital_hub.gd` (the 50-room capital content module). |
| `gen_asset_manifest.py` | regenerate `game/assets/asset_manifest.json` (exports can't scan dirs; `export_all.bat` runs it). |

## In-engine shot rigs (windowed, boot the real game, screenshot to disk)

`shot_kit` (class FX/abilities) · `shot_loot` (loot fanfare grades) · `shot_mobs`
(mob mechanics/tells) · `shot_ui` (HUD + every menu) · `shot_audit`/`2`/`3`
(full visual surface passes) · `shot_chests` (chest grades in-world) ·
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
