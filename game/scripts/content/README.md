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

Zone dicts use the same shape as `Story.ZONES`, plus two optional keys:
- `"npcs"`: [{"sprite": "villager", "x": 500, "y": 330,
             "prompt": "E — Talk", "convo": "convo_id"}] — spawned
  automatically, talking runs the convo.
- `"gate_flag"`: "story_flag" — the gate out of this zone opens when
  that flag is set (bossless zones; call `game.open_gate(zi)` when you
  set it at runtime — reconcile_after_load handles reloads).

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
