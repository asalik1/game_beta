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
7. **Body-level dir drift (v3 north/west rotations are a different outfit) can't be
   fixed by anim re-rolls** — the anim inherits the broken rotation. Fix with
   `create_character_state` (edit + `use_color_palette_from_reference=true`), verify
   all 8 state rotations, then re-animate the broken dirs on the state character
   (frostfall hood-up state `4ecf0b0d`, 2026-07-17).
8. **Billing + API quirks (2026-07-17):** v3 anims cost `frame_count` gens PER
   direction (~0.9¢/gen on credit fallback). A repeat `animate_character` with the
   same `action_description` returns "already complete" WITHOUT generating — reword
   the text to actually re-roll. Jobs occasionally drop silently — re-fire missing
   dirs into the same `animation_group_id`.

## Cases (BAD → GOOD → outcome)

| Case | BAD prompt | GOOD prompt | Outcome |
|---|---|---|---|
| Stormforged body, sword digs floor | `…holding a large greatsword pointed downward…` | `…holding a large greatsword pointed **forward**…` | Sword aligns to facing; mostly clears the feet (v3 still leaves 1-2 dirs digging — owner-accepted) |
| Stormforged body, palette drifted gold | `spiked blue-black plate armor, glowing electric-blue accents, dark fantasy` | `spiked **matte** blue-black **steel** plate armor, glowing electric-blue accents **only, no gold or brass**, grim dark fantasy` | Stayed dark |
| Paladin Fallen Arbiter, west walk moonwalks | `walking forward with a natural leg stride` | `walking **to the left**, each foot stepping **leftward** and planting ahead, body **facing left**, **no turning**` (+ loop the good half) | Feet stopped reversing |
| Hellfire west attack, wrong-side fire burst | (frame 6 FX flipped to the wrong side) | — no regen — **dupe frame 5 over frame 6** | Wrong-side burst gone |
| Stormforged idle, sword down | `standing idle` | `standing idle, greatsword **shouldered, blade angled up and back over the shoulder, tip high, never lowered toward the ground**, wings folded` | Idle held the blade up (v3 refused the same for WALK — fix at body) |
| Paladin attack, weapon morphs mid-swing (flail→hammer→axe) | `a heavy attack with his weapon` (orig, loose) | `a single overhead smash with the chained flail-hammer, **the same chained flail-hammer held for the entire swing, chain and hammer-head visible in every frame, no weapon change**` | Weapon held identity in 8/8 dirs (drift-regen 2026-07-17) |
| "small pale impact flash" → full-body WHITE frame | `small pale impact flash at the hit` | — no reword fixes it reliably — **numeric-screen every batch** (mean-lum per frame vs f0; >+40 = bleach) and **dupe the neighbour frame over the bleach frame** | 2 bleach frames caught + patched, zero re-rolls |
| Warlock cast N/W dirs keep re-inventing FX (black rings roll 1, pink bubbles roll 2) despite explicit negatives | `...no black rings, no white fire...` (2 rolls) | — stop re-rolling — **mirror the clean e/se/nw dirs onto w/sw/ne** (`install_dirset.mirror_fill` convention) | Perfect FX consistency, 0 gens; accept the familiar/tome side-flip |
