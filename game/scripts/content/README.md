# Content modules (Chapter 2+)

Each Chapter 2 task ships its content as a MODULE in this folder:
a plain GDScript (**no `class_name`** — avoids the import-hang trap)
exposing any of these constants:

```gdscript
const CONVOS := {...}          # merged into Story.ALL_CONVOS
const ENEMIES := {...}         # merged into Story.ALL_ENEMIES
const QUESTS := {...}          # merged into Story.ALL_QUESTS
const CHAPTER_ZONES := {       # zones APPENDED to a chapter, in order
	"ch2": [ {zone dict}, ... ],
}
```

Zone dicts use the same shape as `Story.ZONES`. Chapters WITHOUT
`"coord"` keys are **legacy strips**: the engine converts them to a
west→east chain of rooms and rescales every authored position from the
old 34x15 zone space (1632x720) into the bigger rooms — keep authoring
in the old coordinate space and it Just Works. Optional keys:
- `"npcs"`: [{"sprite": "villager", "x": 500, "y": 330,
             "prompt": "E — Talk", "convo": "convo_id"}] — spawned
  automatically, talking runs the convo.
- `"gate_flag"`: "story_flag" — the gate out of this zone opens when
  that flag is set (bossless zones; setting it via `game.set_flag`
  opens the door live — reconcile_after_load handles reloads).

Graph-authored chapters (see `Story.ZONES` for Chapter 1) lay rooms
out on a grid instead: `"coord": [gx, gy]`, `"exits": ["N", "E"]`
(one-sided; reciprocals are implied), `"locks": {"E": "boss" | "clear"
| "flag:x"}`, `"type"` (combat / boss / safe / social / resonance /
dead_end / merchant), `"cache"` (dead-end chest tier), `"shop_tier"`,
and per-spawn `[kind, x, y, pack, level]` enemy entries — positions in
room space (~2112x1248, road band y≈552..696), `pack` groups spawns
for per-pack aggro, `level` optionally overrides the kind's level.

**Register the module with ONE line** in `Story.CONTENT_MODULES`
(story.gd) — that is the only shared-file edit a content task makes:

```gdscript
const CONTENT_MODULES: Array = [
	preload("res://scripts/content/ch2_hub.gd"),
]
```

Autotest: append one `_test_yourthing()` func at the end of autotest.gd
and one call line at the marked hook point — never edit existing
sections.
