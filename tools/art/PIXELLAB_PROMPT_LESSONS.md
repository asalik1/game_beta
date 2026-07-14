# PixelLab prompt lessons — before/after of what fixed each failure

Loose prompts cost re-rolls (and tokens). **Tighten from the first shot**: name the
exact pose/motion, anchor the palette, and add explicit negatives. This file is the
running library of BAD → GOOD prompts that actually fixed a real failure, so future
work starts from the good version. Add a row every time a tightening fixes something.

## Standing rules (distilled)
1. **Appearance lives in the BODY, motion in the animation.** A v3 *animation* inherits
   the character's look from its rotations — fix a weapon pose / palette at
   `create_character` (the body), not in the animation description.
2. **Anchor the palette + add negatives** on body prompts, or a fresh v3 roll drifts
   (e.g. → gold). "matte blue-black steel, electric-blue accents only, **no gold or brass**".
3. **Weapon "pointed downward" in a body prompt = weapon below the feet in every
   rotation** → it digs into the floor in-game. Use "pointed forward" (aligns with facing).
4. **v3 has no compass.** For directional walks use **screen-relative** words ("walking
   to the left, feet stepping leftward, facing left, no turning"), not "west".
5. **v3 re-poses idles but LOCKS walks/runs to the reference pose** — it won't hold a
   "shouldered sword" through a walk. Fix that at the body level.
6. **Salvage before re-rolling:** one bad frame → dupe the neighbouring good frame; a
   reversing tail → keep the good half and loop it (frames 0-4, then 5←0 6←1 …);
   a pose won't hold → `custom_start_frame_base64` seed (but a >~a-few-KB base64
   corrupts passed as a tool arg — downscale the seed first).

## Cases (BAD → GOOD → outcome)

| Case | BAD prompt | GOOD prompt | Outcome |
|---|---|---|---|
| Stormforged body, sword digs floor | `…holding a large greatsword pointed downward…` | `…holding a large greatsword pointed **forward**…` | Sword aligns to facing; mostly clears the feet (v3 still leaves 1-2 dirs digging — owner-accepted) |
| Stormforged body, palette drifted gold | `spiked blue-black plate armor, glowing electric-blue accents, dark fantasy` | `spiked **matte** blue-black **steel** plate armor, glowing electric-blue accents **only, no gold or brass**, grim dark fantasy` | Stayed dark |
| Paladin Fallen Arbiter, west walk moonwalks | `walking forward with a natural leg stride` | `walking **to the left**, each foot stepping **leftward** and planting ahead, body **facing left**, **no turning**` (+ loop the good half) | Feet stopped reversing |
| Hellfire west attack, wrong-side fire burst | (frame 6 FX flipped to the wrong side) | — no regen — **dupe frame 5 over frame 6** | Wrong-side burst gone |
| Stormforged idle, sword down | `standing idle` | `standing idle, greatsword **shouldered, blade angled up and back over the shoulder, tip high, never lowered toward the ground**, wings folded` | Idle held the blade up (v3 refused the same for WALK — fix at body) |
