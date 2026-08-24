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
| `tools/art/verify_art.py` | post-install sprite checks for a base name: strip geometry (engine floors frames = w/h), 8-dir completeness, `*_dir` 8·K frame count, green-bleed semi-alpha, stale `--import`, plus content-geometry gates (2026-08-13) for defects INSIDE well-tiled cells — ANCHOR (figure wanders → on-screen slide), GHOST (stray pose chunk in a cell), EDGECUT (limbs clipped at the frame cut), CLIPSCALE (clip plays smaller/larger than the idle body). Content gates are WARN-level judged lints; blobs/fliers/flames trip them legitimately. Boss ability strips (`<base>_ability` + dedicated names) are swept too — vocabulary parsed live from `play_action("...")` in boss.gd, gated as actions. `--all` sweeps the whole sprites dir (IMPORT+DIR8 only). |
| `tools/art/scan_key_rim.py` | folder-wide KEY-COLOUR RIM contamination sweep (2026-08-15): leftover magenta matte / bright-green chroma key surviving as a coloured ring on the silhouette edge (rock2's magenta line, the ImageGen mob green rim). Extensible `KEYS` dict; per hit reports `rim` vs `interior` vs `key_share` and a verdict — the discriminators that keep a genuinely purple/green sprite (mushroom, bush, purple projectile) out of the DEFECT bucket: contamination is edge-ONLY (interior≈0) and a small share of the sprite. `--keys magenta,green --csv out.csv --montage suspects.png`. Reports only; fix with the despills in build_mob_walk_repairs/build_fx_strip (rim-BAND mask for props that legitimately carry the colour). Complements `verify_art.py` (per-base BLEED/geometry) with a cross-asset sweep. |
| `tools/art/anim_sheet.py` | labeled per-clip contact sheets (8 facings × frames, 1-based) — the owner's QA format for animation review. |
| `game/shot_mobqa.gd` + `tools/art/mobqa_filmstrip.py` | in-engine mob clip QA (2026-08-15): the rig boots the real game, spawns a row of mobs (`-- --kinds a,b,c`), drives idle/walk/attack frame by frame through enemy.gd's own `_apply_strip` (body-cell reference, feet re-anchor, oversized action cells) and screenshots each; prints per strip the scale/offset + the feet row's screen y (must be identical across idle/walk/attack). The Python side crops the shots into one filmstrip PNG per mob. Catches what the sheets can't: a body that jumps on attack, a walk that vanishes (Vow Sentinel's blank walk), a clip at the wrong size. |
| `tools/art/build_mob_walk_repairs.py` | THE builder for the ImageGen mob repair masters in `art_src/Custom/MobWalkRepairs_2026-08-08/` (README there = per-mob history): green/magenta key + 2px edge despill, real-gutter splitting (`whole_subjects(n)`, per-row `four_grid_subjects_gutters`), scale/anchor normalizers (`normalize` bbox, `normalize_locked_motion` torso-locked, `normalize_attack` upper-body, `normalize_core_anchored` eroded-body for spiders/quadrupeds), refuses to write a transparent frame. Running `main()` re-installs EVERY strip — to rebuild one, call its `install_*` with `SPRITES` pointed at a scratch dir, look, then copy. |
| `tools/art/dip_check.py` | flags a character whose weapon dips below its feet per direction (anchor trouble). |
| `tools/art/recenter_strip.py` | repairs square-cell strips whose figures were assembled OFF the frame grid (mob visibly slides side to side each loop): column-band segmentation reunites cross-boundary bleed, then each figure re-centres in its cell on the feet-band centroid. `--anchor head` for hovering casters whose hem sweeps (halo/hood band is the stable landmark; Morwen's Codex strips were quadrant-sliced from a 2x2 master, so frames 1/3 vs 2/4 sat 20-29px apart); `--grow` widens the square cell instead of clipping a wide cast. No `--apply` = audit only. |
| `tools/art/act1_brief_lib.py` | Act 1 boss Codex-regen brief library: per-boss identity (sprite/archetype) + a per-verb front-facing 4-frame storyboard library (~28 verbs: enrage/bolt/ring/summon/slam/beam/storm/lash/throw/blink/freeze/hymn/wail/rain/verdict/blade/pack/charge/melee/quench/piston/surface/toll/stab/shift/arc/split…). `python act1_brief_lib.py <boss> <clip> <stage>` emits the brief + copies the boss's installed `_anim`/static as the identity reference. |
| `C:\Users\asali\Projects\CODEX_HEADLESS.md` (Projects root, all projects) + `tools/CODEX_HEADLESS.md` (MMO layer) | (2026-08-17) THE calling guide for headless Codex (`codex exec`). Root guide = machine-wide facts: binary resolution (the hashed install dir moves every app update), the canonical call (prompt on STDIN), what a run prints/returns (`-o`, `--json` event shapes, `--output-schema`, ~12.7k-token floor), the full `exec` flag table for the installed version, `resume/fork/review`, config defaults inherited, RAM/timing limits of batching on this shared box (serial + RAM-gated beside Godot), image_gen misfires, sandbox quirks. MMO layer = authorization/vet-install flow, the batch runner, brief generators/readers, prompt playbooks. Read both before writing any driver. |
| `tools/codex_bin.py` | (2026-08-17) resolve the installed `codex.exe` — config.toml `CODEX_CLI_PATH` → newest `%LOCALAPPDATA%\OpenAI\Codex\bin\<hash>\codex.exe` → PATH. `python tools/codex_bin.py [--version]` prints it (`CODEX=$(python tools/codex_bin.py)`); importable `resolve()`. Never hard-code the hash. |
| `tools/art/run_codex_batch.ps1` | fire a batch of headless Codex image_gen jobs (one per staging dir: `codex_brief.txt` on stdin + `refs/*.png` as `-i`, `-o codex_result.md` + `codex_log.txt`) and wait for all, then print OK/FAIL per stage. Resolves the binary itself (2026-08-17; was a stale hard-coded hash). `-Stages "dir1,dir2,…"`; `-MaxParallel N -MinFreeGB G` = the serial RAM-gated mode for the shared box (never parallel beside a Godot suite); `-TimeoutSec S` stops stragglers; `-ExtraArgs "…"` appends flags (`-m`, `-c model_reasoning_effort=…`, bypass). Defaults = legacy all-at-once. |
| `tools/art/build_act1_dirset.py` | assemble an 8-direction action set for one boss clip (owner: attacks need a facing). Builds S/N/E from generated masters (S falls back to the installed flat strip for a no-projectile swing), MIRRORS E→W, COPIES E→{ne,se} and W→{nw,sw}, each idle-aligned; writes `<sprite>_<clip>_<dir>.png` ×8 + a per-direction QA sheet; `--install` copies to game/. The named-action set lights up automatically via `Art.dir_set` — no wiring. |
| `tools/art/qa_anim.py` | animation-consistency triage for any character (`<sprite>` or `--all`), catching what verify_art skips on ACTION clips: SLIDE (body shifts sideways as a weapon extends — Korrag), SCALE (body renders smaller/larger than the idle — Vargoth's blade), JUMP (rest body doesn't match the idle). Isolates the BODY by shape-matching the head band (weapon-independent) and measures SCALE at the action's ENGINE-proportional size (grown cells otherwise read ~0.72x small). `--montage out.png` renders flagged clips at TRUE ENGINE SCALE with a centre line — the reliable confirm step. TRIAGE not a gate: over-flags back (n) views, floating/legless bodies (veyx), and heavy arms-up/effect poses (isolating a body from an arbitrary pose+weapon is genuinely hard) — always confirm with the montage. |
| `tools/art/DRIFT_AUDIT.md` | (2026-08-24) THE visual generation-drift audit workflow — the eyes-only net for what `verify_art`/`qa_anim` can't measure: face drift (fatter/blurrier/off-model), attire/equipment morphing (shield/cape/robe changing shape/colour/side), single-direction off-model art, garment violations, off-palette FX residue. Method = dedup-scope the unique dirs → fan out ONE review agent per subject over EVERY clip×dir×frame → orchestrator verifies each flag. Covers heroes/skins AND the boss/mob adaptation (enemy render path = CLIPSCALE not HEROBODY). Includes the known-drift catalogue + a reusable agent-prompt template + fix taxonomy (despill < frame-edit < single-strip regen < full-clip regen). |
| `tools/art/scan_drift.py` | pre-filter a directional wave for IDENTITY DRIFT by reading each job's own `codex_result.md` ("...a horned swordsman INSTEAD OF the hooded figure..."). Flags the ~5-10% that draw the wrong creature so a miss is one targeted re-roll, not a re-run. Over-flags minor rotation drift → still eyeball the flagged ones. |
| `tools/art/build_act1_boss.py` | build ALL of one Act-1 boss's strips from its generated 2x2 masters (idle `--self`, clips vs the built idle, preset `--anchor bbox --scale-ref area --valign hem`) + a combined `ALL_qa.png` contact sheet for review. Installs nothing. |
| `tools/art/install_act1_boss.py` | install a built Act-1 boss non-destructively (idle→`<sprite>_anim_codex`, clips→`<sprite>_<clip>`) + archive masters/briefs/QA under `art_src/bosses_codex_wave1/<sprite>/`. Then wire art.gd/balance.gd by hand (4 dicts + BOSS_ACTION_FPS). |
| `tools/art/build_codex_2x2_strip.py` | Codex/ImageGen 2x2 animation master (TL,TR,BL,BR) → one square-cell 4-frame strip: cuts at the REAL gutters (widest empty band; midline when it qualifies) and refuses to slice a figure, normalizes body scale to a reference idle from ONE frame (`--scale-ref body|halo`, `--scale-frame N`; the old Morwen attack was drawn 15% smaller than her idle and shrank mid-cast), anchors every frame at the IDLE's own anchor position (`--anchor halo` = template-match the idle's crown/halo — immune to motes or raised hands above the head; `hindfeet` = a quadruped's planted hind paws for howl/slam/roar/breath; `bbox` = body mass for a charge/pounce where every leg moves; `head`/`feet` bands otherwise), aligns hems (`--valign hem`), crowns (`top`) or master ROWS (`rows`: top row by f1's paws, bottom by f4's — keeps an airborne f3 in the air) to the idle, `--floor-clip` flattens anything below the idle baseline (a mist pool would fool the engine's frame-0 feet line), cuts the vertical seam PER ROW (a lunge in one row closes the gutter the other row leaves open), grows the square cell (width OR height) when a frame would clip; writes a QA sheet with onion overlay. Stage first (`--out` in scratch), look, then install. Reproduce lines per boss: `art_src/bosses_codex_wave1/<boss>/README.md`. |
| `game/qa_skins.gd` | boots the real game once per class, equips every skin (base + awakened), screenshots. |
| `game/shot_gemcodex.gd` | (2026-08-15) boots the real game, equips S/A/B gear with every socket FILLED and shoots the inventory socket row + item panel (the "gems off-centre" repro), then walks EVERY codex section (legacy tab ids) and prints a density census (controls under the detail/page scroll + ledger row count + rows that fit) before screenshotting it, drives the boss route, and probes the interactions the suites don't (chip filter, search, row select, rail, bare reopen). Windowed → run with `--audio-driver Dummy`. Re-run after any codex layout change; numbers in `PROPOSALS/CODEX_LAYOUT/CODEX_LAYOUT.md`. |
| `game/dump_codex_data.gd` | (2026-08-15) headless `--script`: writes the codex's live tables (placed monsters/bosses with live stats + traits + mechanics, folk, terrains, curios, shapes, uniques, gems, achievements) as JSON plus the exact icons the codex draws (`codex_icons/`), so a layout mock can be built on real density and real sprites (`PROPOSALS/CODEX_LAYOUT/codex_mock.html` was). `-- <out.json>`. |

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
| `tools/art/build_fx_strip.py` | (2026-08-15) Codex/ImageGen FX contact sheet (chroma-keyed RGBA master, cols×rows) → one square-cell horizontal strip for `assets/sprites/fx/`. Finds cells per ROW by alpha column-bands assigned to the nearest nominal column (stray droplets rejoin their frame; a peak that bridges the gutter is split at the thinnest column), normalises the SET so the biggest frame's bbox = `--fill` of the cell, `--valign center|bottom|widest` (widest = anchor each frame's widest row — a ground burst's ring equator = impact centre — and print the sprite offset), `--despill magenta|green` (green also remaps yellow-green dust to tan), gamma 0.85, `--qa` dark+grey sheet. Built the poison cloud/splash/pool + meteor_impact + earth_slam strips; reproduce lines in `art_src/Custom/{PoisonMistFX,ImpactFX}_2026-08-15/README.md`. |
| `tools/art/build_gem_icons.py` | lore-authored 5×2 gem masters → 140 distinct 32px stat+level icons, hard-alpha QA sheet, desktop/mobile install. Cuts each gem as its own connected BLOB and re-centres it (2026-08-15: ImageGen ignores "equal spacing and centers" — the old fixed-grid cut shipped off-centre/clipped icons with neighbour slivers; garnet even drew six gems on one row, see `ROW_DROPS`); `validate()` gates centring ±1px + a clear 1px edge. Family→stat map must track `Items.GEM_STATS` keys (garnet became `hp_flat` 2026-08-07 and silently lost its art until this was caught). |
| `tools/art/build_gear_codex_icons.py` | approved transparent gear masters → 128px codex + separately optimized 32px gameplay candidates, exact 1,260-key coverage audit, dated backups and per-slot QA sheets. |
| `tools/art/upscale_hero.py` | rebuild a dark-class hero from the ChatGPT upscales (white-key, rescale, feet-anchor to original layout). |
| `tools/art/install_preservation_class_idle_walks.py` | guarded old-design Archer/Assassin/Warlock idle+walk candidate installer; validates 277px cells/180px bodies and archives the replaced runtime PNGs. |
| `tools/art/install_preservation_warrior_states.py` | (2026-08-16) guarded restore of the archived old-design Warrior `run`/`dash`/`ult`/`ultidle` (8 dirs + S alias) + flat `death` from `backup/warrior_base_pre_emberbound_heir_2026-07-31/` (manifest-verified) at the 180px frame-1 body — the 37 Emberbound Heir strips the 08-01 rollback missed (Berserk = ult→ultidle/run, so the whole rage state showed the bare-arm Heir). ONE placement transform per strip (keeps the archived run bob + the ult's under-feet burst; per-frame bbox anchoring would hoist the body), a square cell per family (run 256 / dash 288 / ult 352 / ultidle 244 / death 288 — the engine grounds each strip from its own frame 1), hard alpha + 2px green-rim despill; audit + QA sheets/GIFs to `art_src/class_preservation_upscale_2026-08-01/warrior/states_old_normalized/`, `--apply` archives the replaced runtime under `.../runtime_pre_state_restore_2026-08-16/`. Sibling of `install_preservation_warrior_attacks.py`. |
| `tools/art/build_preservation_walk_candidate.py` | auto-detect authored figures from broad source gutters, refuse mismatched `--frames`, and build normalized preservation strips/QA. |
| `tools/art/correct_assassin_walk_hood_palette.py` | palette-only Assassin walk repair: rank-match generated f4-f6 hood/scarf colors to accepted f1-f3 without changing silhouettes, alpha, weapons, or gait. |
| `tools/art/transplant_assassin_walk_hoods.py` | exact Assassin hood/face/scarf raster transplant from accepted f1-f3 into generated f4-f6, aligned by the cyan eye while leaving the lower gait untouched. |
| `tools/art/pixellab_resize_assassin_east.py` | authorized candidate-only PixelLab Resize client for the untouched 104px Assassin east walk; uses one union crop/source palette and targets a 180px body without touching runtime assets. |
| `tools/art/pixellab_add_assassin_second_dagger.py` | authorized candidate-only PixelLab animation edit for adding one coherent off-hand dagger across the phase-aligned resized Assassin east walk. |
| `tools/art/install_assassin_approved_east_walk_mapping.py` | install the approved two-dagger Assassin east walk to E/NE/SE and its framewise mirror to W/NW/SW, preserving north/south and archiving replaced strips. |
| `tools/art/install_assassin_idle_regen.py` | build/install the full-regeneration Assassin idle set from five generated masters plus exact W/SW/NW mirrors, with runtime backups and QA GIFs. |
| `tools/art/fix_warlock_ult_e_frames.py` | in-place repair of the warlock Hex (`ult` clip) EAST strip: frames 7-8 were authored facing WEST; rebuilds them from frame 6's east body + the authored beam/ring FX colour-masked, mirrored and re-seated on the hand (no regen). Backs up to `backup/warlock_ult_e_westframes_2026-08-16/` + before/after sheet; installs game/ + mobile/. The reusable pattern for "climax frames point the wrong way" (PIXELLAB_PROMPT_LESSONS rule 10b). |
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
| `tools/art/install_ground_field.py` + `floorgen_prompts.py` | (2026-08-17) crisp native-res FLOOR fields: `floorgen_prompts.py` writes palette-anchored (from `Art.GROUND`) Codex prompts for seamless tileable floors; `install_ground_field.py` downscales + pre-brightens (`--gamma`, counters the Forward+ sink) → `assets/sprites/ground_field_<kind>.png`, GPU-tiled by `game_world._apply_ground_field` (Polygon2D) at scale 1. Renderer: `Art.ground_field`/`ground_preview`. (2026-08-18) the stored tile edge is the FEATURE SCALE (1 texel = 1 world px): `SIZE_BY_KIND` in the script pins stone/basalt/voidstone 256, crystalfloor 288, holystone 320, forest 400 (else 512) so a cobble is a third-to-half of the 88px hero, not the hero's height. **`--prefix wall_field_`** installs the WALL twin: `wall_field_<kind>.png` (kind = `Terrains.wall_for` name, 128px seamless square) that `game_world._wall_dress`/`Art.wall_field` draw at 1:1 (with the face/shadow relief) instead of the 16px tile at 3x — the 10 wall kinds shipped 2026-08-18 from a Codex batch (style ref = the matching floor field, colour ref = the old tile; edge crossfade for seams >10). |
| `tools/art/install_critter.py` | (2026-08-17) painterly Codex critter sheet → crisp pixel-art `critter_<kind>.png` animation strip: cuts N frames, aligns to a SHARED union bbox + uniform scale (per-frame trim would jitter the body), CENTER-anchored, posterize, `--alpha-cut` (low keeps thin bodies like a dragonfly abdomen). Ambience critters set hframes off it. |
| `tools/art/derive_prop_anim.py` | (2026-08-17) DERIVE a `<name>_anim.png` FROM a prop's existing static PNG (zero drift — frame 0 = the static): `--motion pulse` (luminance-weighted glow breathe — crystals/runes/molten), `flicker` (fire), `wave` (banner shear), `shimmer` (water). For GLOWING props only; mechanical props need real motion or stay static. |
| `tools/art/style_unify/` (README there) | (2026-08-18, `POLISH_TASKS.md`) the prop STYLE-UNIFY lane: `make_briefs.py` (repaint brief = painterly SIBLING as style ref + the old asset as SUBJECT), `rerolls.py` (description-led, no subject), `make_npc_briefs.py` (roster-benchmarked NPC bodies + the mill), `vet_sheet.py`/`green_check.py` (LOOK before install), `install_stage.py` (key → −14 % sat → `install_prop_hires`, game + mobile), `derive_stage.py` (rebuild `_anim` for animated statics at §40c amps), `build_npcs.py` (Ivo 256² canvas, mill 384 override). 140+ props, 9 NPCs, mill went through it (batches A–D). |
| `tools/art/audit_prop_anims.py` | (2026-08-18) the prop-strip GATE for CODING_GUIDELINES §40b/c: per `_anim` strip — frames, cell width (derived = static WxH, Codex = square), centroid drift, rigid-band OUTLINE drift in frame 0's row window (bottom 30 %, or the TOP band for hanging cloth), pulse % (glow ≤ 12, `FIRE_PROPS` ≤ 25, `ENERGY_PROPS` ≤ 18). `--fix`: a DERIVED strip (alpha identical across frames) is re-derived at `--amp`; an AUTHORED strip is re-anchored on its rigid band (scale + translate), band-locked if the outline still differs, silhouette-locked for `RIGID_MASK` — never regenerated from its static. Exit 1 while anything is flagged. |
| `tools/art/install_prop_anim.py` | (2026-08-17) Codex 4-frame prop sheet → `<name>_anim.png` for PROCEDURAL props with no static (fires, fountains, storm array, chainrig swing): shared-bbox align, BOTTOM-anchored square cells, posterize. Anim replaces the procedural look. |
| `tools/art/build_terrain_art_fix.py` | `TERRAIN_ART_FIX_TASK.md` tier 1–3 masters → 20 palette-controlled desktop/mobile replacements plus six registered full-object `_anim` strips. |
| `tools/art/build_material_icons.py` | generated crafting-material sources → 35 transparent 32x32 Metal/Cloth/Bone/Reagent/Herb icons plus a labelled QA contact sheet. |
| `tools/art/build_capital_monumental.py` | generated Crownfall Crown Spire + connected city arcade sources → production architecture and an integrated four-frame gate-fire strip. |
| `tools/art/clean_sprite.py` | FLUX/Pollinations render → clean pixel sprite (normalize). |
| `tools/art/polligen.py` / `tools/art/flux_draft.py` | free generation lanes (pollinations.ai textures/props / FLUX concept drafts — note: HF inference is dead, see memory/ART docs). |
| `tools/art/pl_anim_ids.py` | print a PixelLab character's per-direction anim ids for a clip (frame-URL gotcha). |
| `tools/content/gen_capital.py` | regenerate `capital_hub.gd` (the 9-room, 3×3 Crownfall capital content module). |
| `gen_asset_manifest.py` | regenerate `game/assets/asset_manifest.json` (exports can't scan dirs; `export_all.bat` runs it). |

## In-engine shot rigs (windowed, boot the real game, screenshot to disk)

**Runner + base class (2026-08-15) — use these for any new rig or run:**

| tool | what it does |
|---|---|
| `shot.bat <rig> [--timeout=N] [--no-gate] [--no-import] [rig args]` (`tools/shot_rig.ps1`) | THE way to run a rig: resolves `fx_series` → `game/shot_fx_series.tscn`, ensures `ShotRig` is in the class cache (`--import` once if not), runs the compile gate over `scripts/` PLUS the rig script (check_compile's default walk misses `game/` root — a rig with a parse error opens a window that idles forever), launches windowed + MUTED (`--audio-driver Dummy` injected), tails the log, kills the engine at N+15 s if its own watchdog couldn't, then prints a verdict line + the shots dir + PNG count for this run. Exit: rig's own (0/1/2=in-engine timeout) · 3 killed · 4 gate · 5 no such rig · 6 import. Rig args pass straight through after `--`. |
| `game/scripts/dev/shot_rig.gd` (`class_name ShotRig`) | base for rigs — `extends ShotRig`, then `_ready()` = `await boot(cls, chapter)` + steps + `finish()`. Free with it: Master-bus mute in `_init` (belt to the runner's flag), `--timeout=N` watchdog (pause- and time_scale-immune Timer → `RIG TIMEOUT` + last `step()` label + `_timeout.png` + `quit(2)`), `shot(name[, extra])` → `user://shots/<rig>/<name>.png` with the paused/state/frame line, `boot()`/`boot_game()`/`skip_dialogue()`/`god_mode()`, `sim_wait()`/`sim_wait_until()`/`sim_reset()` (process-delta clock), `arg()`/`flag()`, `apply_terrain()` (+tint), `spawn_enemy()`, `hide_hud()`/`zoom()`. Worked example: `shot_fx_series.gd` (converted); the other rigs are still standalone copies of the same boilerplate — convert one when you next touch it, don't fork the base. |

`shot_kit` (class FX/abilities) · `shot_loot` (loot fanfare grades) · `shot_mobs`
(mob mechanics/tells) · `shot_ui` (HUD + every menu) · `shot_audit`/`2`/`3`
(full visual surface passes) · `shot_chests` (chest grades in-world) ·
`shot_capital` (every Crownfall room + Citizen right-side facing proof + desktop/compact capital maps) ·
`shot_dirtest`/`shot_dirinstall`/`shot_actiontest` (8-direction render/install
proofs) · `shot_silence`/`shot_verdict`/`shot_readability`/`shot_wall`/
`shot_assassin_fx` (one-off readability rigs — reusable patterns) ·
`shot_fx_series` (2026-08-15, a `ShotRig`: fires ONE ability and photographs it at a list of
SIMULATION-time offsets — arrival / peak / lingering tail — per class branch:
assassin poison wake+bloom, archer venom tumble, mage meteor (any theme),
warrior earth slams; `shot.bat fx_series --class=mage --theme=ice --terrain=keep`; `--ability=<slot>`
fires one slot generically (`--theme=none` = base kit), `--pin` freezes the dummy so an
impact lands ON it (layering proof), `--hazards` repaints the room through every
patch terrain and shoots the pools wide + close; prints paused/state/strip-frame
diagnostics per shot. Time by accumulated process
delta, never wall clock: the viewport readback in `shot()` costs ~0.1s, so
wall-clock offsets came due together and were shot in ONE frame) ·
`shot_capgap` (2026-08-17, a `ShotRig`: capital PASSABILITY probe — for every
Crownfall room with a north door, teleports the hero onto the door lane and
WALKS the real route through the real input path (`Input.parse_input_event` →
`_poll_local_intents` → `move_and_slide`): south down the lane, around a hall
that stands on the road, to the centre line, then back; ray-casts name the
first blocker on the lane; a `BODIES` inventory per room lists every non-wall
collider with its rects in cell-local px (how the stray accent stand beside the
Sable Hall was found); replays the owner's exact report (hero in the spire-gate
arch walking back south); `shot.bat capgap` — exit 1 = a route is walled; the
autotest's `_capital_doors_connected` is the headless flood-fill twin) ·
`shot_polish` (2026-08-18, a `ShotRig`: the GAMEPLAY-POLISH review frames — per room a
mid-room frame with a FROZEN wolf pack that has taken three hits (numbers, framed HP bars,
reticle tag, contact shadows), a north-wall frame (wall face + floor shadow + edged road +
door torches) and a west-wall frame, then the same room painted magma for the lava light
pools; `shot.bat polish [--rooms=2,17,20] [--zoom=1.4] [--class=warrior] [--hud]`; own dir
`user://shots/polish`, never touches `shots/cine`. **`--gif` mode** = MOTION review: frame
SERIES per beat (forest/keep/HUD fights with a LIVE pack and the hero driven through the real
input path, road/magma/keep-wall walks) into `gif_<beat>/`; run with the runner's new
`--fixed-fps=30` so each frame is a deterministic 1/30 s; then
`python tools/art/gif_from_frames.py [--width 800] [--out ~/Downloads/crownless_polish_gifs]`
stitches 15 fps GIFs with one shared palette per GIF (owner review artefacts)) ·
`tools/art/pixellab_resize_soft_clips.py` (2026-08-19, owner-authorized PixelLab:
upscales the OLD-generation hero action strips — assassin/warlock/archer
run·dash·cast·ult 8-dir sets + the four flat deaths, 94 strips — through
PixelLab /v2/resize exactly like `pixellab_resize_assassin_attack.py` did for
the crisp attack strips: per frame tight-crop → identity-prompt + runtime-
palette-locked redraw at the 180 px (mage 202) body → paste back at original
coordinates in a 277 cell (auto-grows), baseline cell-22; `run` = spend
generations (resumable, frames cache), `install` = assemble + backup + write
game/+mobile/, `status` = progress) ·
`shot_csdemo` (2026-08-19, a `ShotRig`: the CLASS-SELECT ability demos — per
`--class=<id>`, casts every slot (a1/a2/a3/ult) through the REAL
`player.use_ability` at a frozen immortal wolf pack and dumps every frame
(`shot.bat csdemo --fixed-fps=30 --class=assassin`; fixed-fps is REQUIRED — the
per-frame viewport readback drops the wall-clock rate to ~7 fps, fixed-fps makes
each frame exactly 1/30 s) into `user://shots/csdemo/<class>_<slot>/f###.png`;
then `python tools/art/build_csdemo.py [class ...]` ffmpeg-encodes them (crop to
the action, scale 640x396, libtheora q6, ~130-260 KB each) into
`game/assets/videos/csdemo_<class>_<slot>.ogv` (+ mobile mirror) — the class
selector's stage plays these full in-game takes (`menus._cs_play_demo`) instead
of the bare body clip). All live in
`game/`; run via `shot.bat <name>` (legacy ones too — they just print no verdict
line) or by hand per their `.gd` docs.

**ALWAYS run windowed rigs MUTED: `shot.bat` does it; by hand add `--audio-driver Dummy`**
(`godot --audio-driver Dummy --path game res://shot_kit.tscn -- ...`). The
rigs boot the real game with its music/SFX and the owner shares the machine —
an unmuted rig blares through his speakers (owner ruling 2026-08-15). The flag
swaps the audio device for a silent one; nothing else changes. Rigs cannot be
`--headless` — the viewport readback needs a real renderer — so "unattended
windowed" is the mode, and a rig with a never-resolving `await` sits open forever
unless it has a watchdog (`ShotRig` has one; the 23 legacy rigs do not).

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
- `art/alt_swing_pipeline.py` — the melee swing-ALTERNATION lane (2026-08-16): `briefs <class>` stages Codex ImageGen briefs + refs for the alternate basic swing (`<class>_attackb_<dir>`), `build <class>` keys/slices/normalises/anchors the sources (component-based slicing — a level sword's extent may interleave the neighbour's column, so it assigns islands to the nearest body instead of cutting on gutters; cell auto-grows to fit the arc), `assassin-assemble` lays out the PixelLab Resize outputs like the base stab (E→NE/SE, W side mirrored), `install <class> [--apply]` writes the 9 runtime files with a SHA-backed backup. `pixellab_resize_assassin_attack.py --runtime-cell N` grew out of it (a wide follow-through outgrows 277).
