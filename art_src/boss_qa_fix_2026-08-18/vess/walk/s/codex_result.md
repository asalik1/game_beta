Generated once with built-in ImageGen.

Files:

- [walk_master_2x2_v1.png](C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\vess\walk\s\walk_master_2x2_v1.png) — raw, byte-identical copy, **1254×1254 RGB**
- [walk_master_2x2_v1_keyed.png](C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\vess\walk\s\walk_master_2x2_v1_keyed.png) — **1254×1254 RGBA**, auto-keyed with despill

All four visibly different: **No, not sufficiently.**

| Frame | Result |
|---|---|
| 1 | Narrow, symmetrical neutral pose. |
| 2 | Clearly different raised pose with wide cloth streaming. |
| 3 | Clearly different strong leftward cloth sweep. It remains raised rather than returning to mid-height. |
| 4 | Too similar to frame 1 and is not a proper downward settle. Its hem is 16 px higher than frame 1. |

Blunt defects:

- Raw background is not uniform `#00ff00`; auto-sampling found `#05f808`. Only six pixels are exact `#00ff00`.
- Anchor drift is substantial: head tops vary by 39 px and horizontal centers by about 13 px.
- Body heights vary from 394–414 px, roughly 63–66% of each cell rather than 68%.
- Visible shoe/foot shapes protrude beneath the gown, violating “no feet.”
- Identity is recognizable and close, but facial pixels, hands, veil folds, and silhouette change between frames.
- No wrong facing, extra limbs, extra heads, weapons, effects, shadows, or edge contact.
- The final prompt retained the supplied constraints; only the corrupted `???` separators were normalized to em dashes.