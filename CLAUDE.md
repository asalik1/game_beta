# Emberfall — working practices (all agents)

## Testing — ALWAYS in this order
1. **Compile gate first, every time**: `test_quick.bat` and `test.bat`
   both run `check_compile.gd` before the suite. Never invoke the test
   scene directly — a single parse error anywhere makes the suite's own
   script fail to compile, and the headless engine then idles FOREVER
   (looks like a 16-minute "slow run"; it is a zombie). The gate catches
   it in ~3 seconds and prints the actual parse error.
2. **Iterate with `test_quick.bat`** (~15s): compile gate → boot → one
   class kit → all systems tests → UI smoke → pause menu.
3. **`test.bat` (full suite, minutes) must be green before staging.**
   It plays both chapters end to end.

## GDScript traps that have each bitten us multiple times
- `var x := obj.method()` where `obj` is loosely typed (e.g.
  `game: Node2D`) is a PARSE ERROR ("cannot infer type") that breaks the
  whole dependency chain. Always annotate: `var x: float = ...`.
- New `class_name` script → run `--import` before any headless run, or
  everything silently hangs.
- Labels inside HBoxContainer collapse to one char per line without
  `custom_minimum_size`.
- Multiline lambda: further call args must sit on the SAME line as the
  lambda's last statement (`, arg)` on a new line is a parse error).
- Tests that wait on timed effects (mist ticks, meteors) must poll real
  time (`await create_timer(0.2)`) — frame counts race far ahead of the
  wall clock in headless runs.
- Autotest sections must SNAPSHOT + RESTORE shared state (flags,
  resonance, standings), never `.clear()` it — later sections (and the
  quick tier especially) reuse the same game.

## Multi-agent etiquette
- Task boards (`CH2_TASKS.md` pattern): one owner per task, claim on
  the board before starting, content lands as NEW modules under
  `game/scripts/content/` (format: `scripts/content/README.md`) plus a
  one-line registration in `Story.CONTENT_MODULES`.
- Stage with `git add` after a green full suite. No commits unless the
  user asks.
- Autotest additions go through the marked CONTENT-MODULE TEST HOOK —
  one func at file end + one call line; never edit existing sections.

## Asset sourcing
- Sprites: Dungeon Crawl tileset (CC0) — probe the GitHub API for
  candidates, download them, and LOOK at the images before installing.
- Sounds/music: OpenGameArt (CC0/CC-BY; attribution files must ship) —
  overrides drop into `assets/sounds|music|sprites/` by name.
- The user's audio taste: semantic fit over quality; no melodic-jingle
  chiptunes for ults/terrains; never human grunts on ability casts;
  never touch `ult_mage.wav` or the village/story/boss synth tracks.
