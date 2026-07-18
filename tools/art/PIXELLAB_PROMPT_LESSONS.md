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
   direction (~0.9¢/gen on credit fallback; larger canvases cost more — a 252px
   char ran ~5.7¢/gen). A repeat `animate_character` with the
   same `action_description` returns "already complete" WITHOUT generating — reword
   the text to actually re-roll. Jobs occasionally drop silently — re-fire missing
   dirs into the same `animation_group_id`. **Downloading the result:** frame URLs
   use the per-DIRECTION animation id shown inside `get_character`'s frame-URL list
   (`animations/<per-dir-id>/<dir>/N.png`), NOT the `[group: …]` id — polling the
   group id 404s forever. `get_character` also caches ~2-4 min, so a just-finished
   group won't appear until the cache refreshes (watch the response size change);
   the API reports the anim complete while the CDN still 404s briefly.

9. **"Correct" for a direction = CONSISTENT with the other 7, not whatever that
   direction's rotation happens to hold.** The warrior's NE rotation had empty hands,
   so a plain idle re-roll came out weaponless — but every other facing holds the
   molten greatsword, so weaponless was WRONG. Infer the target from the SET, not one
   rotation. Corollary: an animation that *invents* a weapon (a silver scimitar on
   warrior idle-NE) is usually a rotation MISSING the element, not a bad animation —
   fix by seeding from a clip that has it, prompting the prop in (rule 10), or fixing
   the rotation (rule 7).
10. **Directional held props (sword, bow) point the way the body faces.** Two payoffs:
    (a) *generation* — if a held-prop pose keeps failing (empty rotation invents;
    run-seed drags a walking lean), prompt the prop **extended OUTWARD in the facing
    direction, clearly out to the side away from the torso** — an unambiguous visible
    target the model renders cleanly. (b) *cheap fix for a wrong-facing prop* — if the
    loose/climax frames point it the WRONG way, **mirror the last N frames in place**;
    a back-facing cloak body is symmetric enough the flip is invisible.
11. **Mirror ONLY for symmetric designs (this supersedes the blanket "mirror wins" in
    the Warlock case below).** Asymmetric (one-handed weapon/staff/shield/skull) →
    REGEN. Severity scales: an off-hand PROP (book/orb) swapping sides is soft and can
    slide; a PRIMARY/dominant weapon (warrior sword, archer bow) swapping hands is a
    hard no. Two things still FORCE a mirror even on asymmetric: the native rotation
    for that dir is broken, or v3 keeps re-inventing the FX/pose past all negatives.
12. **Hue-remapping FX: gate on VALUE, not hue+sat alone.** When the off-palette FX
    shares a hue band with a legit but DARK character element (Ronin cyan combat FX vs
    its blue-grey cape — both cyan-band, but the cape is high-sat / low-value), add
    `val ≥ 0.55` so only the bright FX shifts and the dark element is spared.
13. **Awakened mythics are PLACEHOLDER recolors — except Phantom.** Only the assassin
    Phantom has a true, bespoke awakened sprite; every other mythic's awakened is a
    stopgap HSV recolor of its base, meant to be replaced by real awakened art later.
    So when you regen a base direction, KEEP the placeholder consistent (derive the
    HSV shift from the OLD base→OLD awakened pair — median dHue/dSat/dVal — and reapply
    to the NEW base frames), but don't treat the recolor as final: a true awakened
    regen supersedes it. Don't sink effort polishing a placeholder recolor.
14. **Face rules.** Pure cardinals (W/E) must NEVER show a face; back-3/4 views hide it
    in the hood. A design with a real face (voidwraith, void weaver) WILL leak it on
    toward-camera climax frames no matter the negative — re-roll once for hood/pose,
    then shadow the residual with a spatial (head-zone) + saturation-capped (spare the
    gold trim) repaint to the hood-interior colour.
15. **Confirm which clip/STATE before diagnosing.** "Berserk stormforged NE" was the
    ULT, not the base Cleave attack — chasing the wrong clip burned time. Pin clip +
    state (base / ult / awakened) and its source char up front.

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
| Warlock cast N/W dirs keep re-inventing FX (black rings roll 1, pink bubbles roll 2) despite explicit negatives | `...no black rings, no white fire...` (2 rolls) | — stop re-rolling — **mirror the clean e/se/nw dirs onto w/sw/ne** (`install_dirset.mirror_fill` convention) | Perfect FX consistency, 0 gens; accept the familiar/tome side-flip. **REFINED 2026-07-18 (rule 11):** the warlock is asymmetric (skull/tome), so W/SW were re-done with NATIVE-hand generation; only NE stays mirrored (its body rotation is broken + it's "just a book", owner-accepted) |
| Warrior idle-NE invents a silver scimitar (empty NE rotation → v3 fills the hand) | `standing idle` (invents a curved silver blade) | seed the v3 from a run frame that HOLDS the molten sword + `…molten glowing greatsword blade extended OUTWARD to the right in the direction he faces, clearly out to the side away from the torso, no silver blade, no curved scimitar…` | Upright + visible molten blade out east (curved-vs-straight drift owner-accepted) |
| Archer bows point EAST on W/NW shots | (loose frames were drawn aiming east) | — no regen — **mirror the last N loose frames in place** (frostfall attack_nw last-3, voidwraith attack_w/nw last-4, multishot attack2_nw last-5) | Bow points the facing dir; back-cloak flip invisible |
| Voidwraith NW quickshot shows a chibi face | `…draws the bow…` | `…seen from behind at a north-west angle, the deep hood stays up the whole time with the face completely hidden in shadow, no face and no eyes ever visible, bow and arrow point up-left…` | Hood/no-face + bow points NW |
| Voidwraith SE quickshot draws too shallow | `…draws and looses an arrow…` | `…nocks and draws the bowstring **all the way back to a full deep draw with the drawing arm pulled right back to the cheek**, holds the tension, then looses…` | Proper full-draw archery form |
| Stormforged ult-NE weird curled hook FX | (v3 storm FX came out as C-hooks / floating blobs) | follow the good SW dir + `…smooth tall vertical streamers of pale-blue storm lightning rise straight upward around the blade, clean flowing streamers, no hooks, no curled loops, no scribbles…` | Clean vertical storm streamers (matches SW) |
