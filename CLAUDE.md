# Emberfall — working practices (all agents)

## Mobile version — kept in sync (unfrozen 2026-07-15)
- `mobile/` (repo root) holds the iOS/Android version: a snapshot fork of `game/` plus a small, fixed set of mobile deltas (Mobile renderer, touch HUD, export presets — the exact list lives in `mobile/README.md`). Deployment is proven end to end — GitHub Actions **"Mobile builds"** produces a signed-debug APK and an unsigned iOS `.ipa`; both install/run on-device (sideload).
- **Policy change (was "frozen, do not touch"):** keep `mobile/game/` in sync with `game/`. `game/` is still the **source of truth** — never edit `mobile/` to fix a desktop issue; fix it in `game/` and re-sync. To re-sync: re-copy `game/` over `mobile/game/`, re-apply the mobile deltas from `mobile/README.md`, then run the compile gate + `test_quick` against `mobile/game` before committing. Keep the delta list small and current.

## Code layout (see CODING_GUIDELINES.md §38)
- Tuning knobs → `balance.gd`; data tables stay in domain files (classes/items/story). Never inline a bare tuning number.
- Docs split (2026-07-06): balance/pacing round narratives go in `BALANCE_HISTORY.md` (newest at TOP of the tuning list); `DESIGN.md` holds only current decisions + distilled standing rules — never append round-by-round history there.
- Big node classes are inheritance CHAINS (verbatim moves, calls flow derived→base, all vars in the base layer):
  - Game: `game_base` (state/flags/convo/lookups/fx) ← `game_world` (graph/rooms/walls/spawning/gates) ← `game_flow` (deaths/loot/chapters/settings/terrain events) ← `game.gd` (boot + per-frame).
  - Player: `player_core` (state/stats/gear/progression) ← `player_combat` (targeting/hit/shared juice + shared primitives) ← `player_kit_{warrior,archer,mage,assassin,paladin,warlock}` (one file per class: `_use_<class>` dispatch + its abilities) ← `player.gd` (dispatch/survival/per-frame). Primitives shared by several kits (`_dash_strike`, `_melee_arc`, `_mist`, `_beam_fx`, `_grant_stab_surge`) stay in `player_combat` — calls only flow derived→base.
  - Tests: `tests/test_base` (helpers) ← `tests/test_ch1` ← `tests/test_ch2` ← `autotest.gd` (entry + systems tier).
- Self-contained UI screens = static modules in `scripts/ui/` (dev_panel, codex) taking the Menus instance.
- New `class_name` script → run `--import` before any headless run.
- The in-game **codex** (`scripts/ui/codex.gd`) is the player-facing reference for monsters/bosses/terrains/gear — it goes stale silently. Whenever you add player-facing content or a feature, ask whether the codex should reflect it, and if so update it in the same change. It reads `Story.ALL_ENEMIES`/data tables directly, but a few hand-maintained parallel lists still gate it (e.g. `menus.gd` `BOSS_KINDS` decides monster-vs-boss bucketing) — update those too, or a new boss lands in the wrong bucket.

## Testing — ALWAYS in this order
1. Compile gate first, every time (`test_quick.bat`/`test.bat` run `check_compile.gd` first). Never invoke the test scene directly: one parse error anywhere makes the suite script fail to compile and the headless engine idles FOREVER (a zombie that looks like a slow run). The gate catches it in ~3s with the real error.
2. Iterate with `test_quick.bat` (~15s): gate → boot → one class kit → systems → UI smoke → pause menu.
3. `test.bat` (full suite, minutes; plays both chapters end to end) must be green before staging.

## GDScript traps (each has bitten us)
- `var x := obj.method()` on a loosely-typed obj (or any Variant expression, e.g. `Dictionary.get`) = PARSE ERROR "cannot infer type". Annotate: `var x: float = ...`.
- New `class_name` → `--import` first or headless silently hangs.
- Labels inside HBoxContainer collapse to one char per line without `custom_minimum_size`.
- Multiline lambda: following call args must sit on the SAME line as the lambda's last statement.
- Tests waiting on timed effects must poll wall-clock (`await create_timer(0.2)`) — frames race ahead headless.
- Autotest sections SNAPSHOT + RESTORE shared state (flags, resonance, standings); never `.clear()`.
- Spawning an Area2D + CollisionShape2D (Chest/Pickup/Projectile) from inside a `body_entered`/`area_entered` handler = non-fatal "Can't change this state while flushing queries" engine error (`area_set_shape_disabled`) — the new shape's enter-tree hits the physics-flush guard. Connect physics signals with `CONNECT_DEFERRED` or `call_deferred` the spawn (chest open + projectile ricochet were bitten).

## Multi-agent etiquette
- Task boards (`CH2_TASKS.md` pattern): one owner per task, claim before starting; content lands as NEW modules under `game/scripts/content/` (format: `scripts/content/README.md`) + one registration line in `Story.CONTENT_MODULES`.
- Stage with `git add` after a green full suite. No commits unless the user asks.
- **Commits are SERIALIZED (2026-07-07):** a commit sweeps the WHOLE index, and sibling agents stage concurrently — so immediately before committing, run `git status` and look at what's actually staged. If the index holds another agent's work, either fold it into an accurate combined message or stop and say so — never commit a message that describes only your slice. (Trigger: an itemization pass got swallowed into a commit labeled "cover + boot flow" by exactly this race.)
- Commit messages: NO author/co-author trailers (no `Co-Authored-By`, no attribution lines) — this project keeps commits authorless; credit lives in a separate credits file.
- Autotest additions: content modules use the marked CONTENT-MODULE TEST HOOK (one func at file end + one call line); never edit existing sections.

## Asset sourcing
- **Allowed — and that's the whole list:** ONLY these two, or anything we generate ourselves (must be up to par: semantic fit + reads clean in-game).
  1. **CC0 / public domain** — zero obligations, ideal.
  2. **CC-BY / MIT / Apache / OFL** — fine; ship the attribution file (we already do, in `assets/*/CREDITS.txt`).
  No pre-approval needed for these. Source from anywhere — OpenGameArt, Kenney, itch.io, the Dungeon Crawl tileset (CC0), etc.
- **Everything else is off-limits** — do not use, don't even ask: share-alike (CC-BY-SA, GPL), non-commercial (CC-NC), proprietary/paid asset-store packs, and anything with no stated license (default = all rights reserved). This game ships commercially on Steam; these licenses either forbid selling it or can force us to open-source the whole project.
- Install flow: probe/download, and LOOK at the image (or listen to the audio) before installing; overrides drop into `assets/sounds|music|sprites/` by name (a PNG/wav there overrides the procedural version of the same name).
- Audio taste: semantic fit over quality; no melodic-jingle chiptunes for ults/terrains; never human grunts on casts; never touch `ult_mage.wav` or the village/story/boss synth tracks.

## PixelLab characters — regenerating an EXISTING one
- **RULE: before you regenerate, re-roll, or tweak an existing PixelLab character (boss/hero/skin), ALWAYS read its export metadata FIRST.** Download the zip (`curl -H "Authorization: Bearer $PIXELLAB_SECRET" https://api.pixellab.ai/mcp/characters/<id>/download -o out.zip`) and read `metadata.json` — it stores the ORIGINAL creation `prompt` (plus size, `template_id`, view). Regenerate from that EXACT prompt and change ONLY the clause the owner flagged.
- **Never invent a fresh description from a screenshot or memory** — it silently drifts the design (proportions, palette, silhouette) even when the fix was one word. `get_character` does NOT return the creation prompt; the zip's `metadata.json` is the only source of truth.

## PixelLab characters — new generation workflow
- **CHECK ALL 8 ROTATIONS before generating animations.** After a character body is created, visually inspect every direction (S, SE, E, NE, N, NW, W, SW) for consistency — same proportions, same gear, same silhouette. v3 mode frequently produces inconsistent north/west directions (wrong body shape, missing equipment, different outfit). If any direction is broken, re-roll the body first. Generating animations on a broken body wastes hundreds of generations.
- **Heroes use v3 mode (NOT pro).** The gold-standard assassin and warlock were both v3. Pro mode produces stocky proportions for visible-face characters. The `style: -, -, -` field in `get_character` appears in BOTH v3 and pro — it cannot distinguish modes.
- **Standard mode is useless for proportions testing.** Its template skeleton produces chibi proportions regardless of description. Only useful for testing color palette and design elements.
- **Description formula (proven on assassin):** archetype first → every piece of gear described precisely → body type ("lean and gaunt" / "lean and tall") → art mood ("muted dark palette, somber dark fantasy") → explicit negatives ("no hood", "no smoke"). Leave no room for the model to improvise.
- Worked example (2026-07-12): owner said Vess should have "no smoke from mouth". The metadata prompt literally contained `faint blue-white keening light at the mouth` — the fix was deleting that one clause from the original prompt, not writing a new banshee description.
