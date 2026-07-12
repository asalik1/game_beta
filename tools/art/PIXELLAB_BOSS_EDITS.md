# Editing an EXISTING PixelLab boss — lessons (2026-07-12)

Hard-won during the Vess / Nullwarden / Hrolgar / Kaethra playtest-note fixes.
Read this **before** touching an already-shipped PixelLab character. The short
version: to *change one thing* about a boss, **edit its existing character with
`create_character_state` — never regenerate from a fresh prompt.**

---

## 1. `create_character` from a new prompt = a REDESIGN, not an edit
A fresh `create_character(mode=v3, description=...)` re-rolls the whole body from
text. Even a one-word change (remove smoke / add an axe) silently **drifts the
palette, silhouette, proportions, and even gender** — the result is a *different
character* that happens to share a theme. This burned an entire round: the first
pass "fixed" three bosses by redesigning them (Vess went light-robed/skull-faced,
Nullwarden gained a cape + orange trim + lost its sigil, Hrolgar became a blue
demon). All of it had to be reverted (`441e418`).

**Instead:** `create_character_state(<original_id>, edit_description,
use_color_palette_from_reference=true)`. It keeps the source's identity,
skeleton, proportions, and palette, and applies **only** the edit across all 8
rotations. This is the drift-free path and the whole reason the second attempt
worked.

## 2. Read the export metadata FIRST (the standing rule)
`get_character` does **not** return the creation prompt. Download the zip
(`curl -H "Authorization: Bearer $PIXELLAB_SECRET" .../characters/<id>/download`)
and read `metadata.json` — it holds the ORIGINAL prompt. Change only the clause
the owner flagged. Worked example: Vess's prompt literally contained
`faint blue-white keening light at the mouth`; the fix was deleting that one
clause, not writing a new banshee description. Never invent a prompt from a
screenshot or memory.

## 3. Confirm you have the RIGHT source character
The account accumulates many drifted re-rolls per boss. Before editing, fetch
each candidate's south rotation and eyeball it against the committed
`<key>_anim_s.png`. The canonical installed bodies are the **"r2"** characters:
- Vess `4224dc5f` · Nullwarden `7bfca42a` · Hrolgar r2 `f04e4988` · Kaethra r2 `9f4449ad`

## 4. Verify all 8 rotations of the STATE before animating
A state is 3 gens; an animation is ~48. **Always** montage the 8 rotations and
inspect before spending animation gens. v3 states drift the **non-front views**:
- Vess kept the mouth-glow on **NE only** (7/8 clean).
- Hrolgar dual-wielded two axes in the **back (N/NE/NW)** views.
- Nullwarden dropped the sword entirely in the **SOUTH (front)** view — the
  single most-seen direction in-game. **Front-facing held items are v3's
  weakest spot;** emphasise "clearly gripped and visible in the front-facing
  view" and re-roll if it's missing.

## 5. v3 animate BAKES action-FX into attacks — strip them in post
`animate_character` adds swing-arc motion trails and energy bursts to any attack,
and **ignores** "character only / no FX / no glow / no shockwave" in the prompt.
The engine spawns real FX separately, so ability strips must be **character-only.**
Post-strip recipe (`scipy.ndimage`, see the FX-strip block in scratchpad):
- Color-key off-palette FX: saturated **cyan** (`g>r+30 & b>r+30`), **yellow**,
  **green** → alpha 0. These strip cleanly (bosses are desaturated).
- **Bright-white** (`min>200`) only for DARK bosses (Nullwarden); **skip for
  white-fur** ones (Hrolgar) or you erode the fur.
- Keep the **largest connected component + any fragment ≥25% of it** (drops
  detached bursts/orbs/blobs while preserving a swung weapon that's separated
  from the body by a thin gap).
- Residue: faint **white motion-arcs** attached to a light weapon/fur survive
  colour-key and component-filter — the hard case; offer the owner an
  erosion-based pass (remove bright-white outside a dilated body core) only if
  they want it.

## 6. Motion wording drives the pose v3 picks
"slam down" → v3 produced a **sideways jab** ending. The owner wanted a
wound-up overhead arc that drives the blade into the ground. Two levers fixed it:
1. **Idle holds the weapon POINT-UP** (a raised guard) so the attack transitions
   cleanly into a downward strike. (Owner's insight, not mine.)
2. **Describe the END STATE:** "ends with the blade driven straight down into the
   ground, not a sideways slash or side jab."

## 7. Tooling & mechanics
- `pl_anim_ids.py <char> <word>` — per-dir anim_ids via JSON-RPC, keeps the huge
  `get_character` dump out of context. Match an **early** word; PixelLab truncates
  anim names to ~32 chars.
- `install_ability.py <key> <char> <framecount> [act=<name>] s=<id> se=<id> ...`
  — cuts an 8-dir strip **reconciled to the boss's installed idle cell**.
  `act=stab` installs `<key>_stab` (a distinct action) beside the `_ability`.
- `skin_install.py <char> <key>_anim game/assets/sprites` — static idle from the
  8 rotations. **Idle doubles as walk:** delete `<key>_walk*` (armored/robed/
  hulking bosses) so it falls back to the idle — never ship a stale walk with the
  old body.
- Wire: `play_action("<action>")` at the boss's ability/contact site in
  `boss.gd`. Kaethra's stab went on both `_kaethra_huntress` melee-contact sites.
- **Job queue:** state = 3 gens; animation = framecount×8 ≈ 40–48. The ~20-slot
  cap is SHARED with sibling agents — an animation may bounce ("need 8 slots");
  pace and retry. MCP transport can drop mid-call; the job usually still fires
  (a dropped Kaethra stab left 7/8 dirs — re-fire only the missing one with
  `directions=["south"]`, don't redo all 8).

## 8. QA discipline (owner demanded "weapon in every frame, no artifacts")
- Build per-direction × per-frame contact sheets and inspect **every** cell. v3
  drops or mangles the weapon in north/west directions especially.
- Delegate the exhaustive pass to a subagent (keeps the orchestrator's context
  free for review) — but **zoom-check the SOUTH/front idle yourself**; the
  missing-sword front view was subtle at contact-sheet scale and the owner caught
  it in-game, not the sheet. In-game review is the owner's; make the most-seen
  directions crisp.

## 9. Commit discipline
Path-scoped (`git commit -- <paths>`) so a shared index full of sibling work
isn't swept. **New untracked files** (e.g. `kaethra_stab*`) must be `git add`-ed
first — a pathspec `git commit --` skips untracked files and aborts the whole
commit if a pathspec matches nothing.

---
Related: `boss-sprite-pipeline` + `read-metadata-before-regen` memories;
CLAUDE.md "PixelLab characters" sections; `tools/art/README.md` (the older
OneDrive 5-row-sheet cutting path).
