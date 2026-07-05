# Emberfall — working practices (all agents)

## Code layout (see CODING_GUIDELINES.md §38)
- Tuning knobs → `balance.gd`; data tables stay in domain files (classes/items/story). Never inline a bare tuning number.
- Big node classes are inheritance CHAINS (verbatim moves, calls flow derived→base, all vars in the base layer):
  - Game: `game_base` (state/flags/convo/lookups/fx) ← `game_world` (graph/rooms/walls/spawning/gates) ← `game_flow` (deaths/loot/chapters/settings/terrain events) ← `game.gd` (boot + per-frame).
  - Player: `player_core` (state/stats/gear/progression) ← `player_combat` (targeting/hit/juice + 4 kits) ← `player_kits` (paladin/warlock) ← `player.gd` (dispatch/survival/per-frame).
  - Tests: `tests/test_base` (helpers) ← `tests/test_ch1` ← `tests/test_ch2` ← `autotest.gd` (entry + systems tier).
- Self-contained UI screens = static modules in `scripts/ui/` (dev_panel, codex) taking the Menus instance.
- New `class_name` script → run `--import` before any headless run.

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

## Multi-agent etiquette
- Task boards (`CH2_TASKS.md` pattern): one owner per task, claim before starting; content lands as NEW modules under `game/scripts/content/` (format: `scripts/content/README.md`) + one registration line in `Story.CONTENT_MODULES`.
- Stage with `git add` after a green full suite. No commits unless the user asks.
- Autotest additions: content modules use the marked CONTENT-MODULE TEST HOOK (one func at file end + one call line); never edit existing sections.

## Asset sourcing
- Sprites: Dungeon Crawl tileset (CC0) — probe the GitHub API, download, and LOOK at images before installing.
- Sounds/music: OpenGameArt (CC0/CC-BY; ship attribution files) — overrides drop into `assets/sounds|music|sprites/` by name.
- Audio taste: semantic fit over quality; no melodic-jingle chiptunes for ults/terrains; never human grunts on casts; never touch `ult_mage.wav` or the village/story/boss synth tracks.
