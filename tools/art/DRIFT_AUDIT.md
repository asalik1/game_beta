# Generation-drift visual audit (the eyes-only net)

**What it is:** an exhaustive, frame-by-frame visual review of a generated character's
animation set to catch **generation drift** — the class of defect a geometric gate
(`verify_art`) structurally CANNOT see. Established 2026-08-24 auditing the 5 enhanced-base
hero skins (caught: an off-model horned helmet on one direction, off-model hood/hair/beard
heads on fire-on-move clips, a botched red-blur face, a lower-neck garment violation, an
off-palette green FX residue). Owner wants the SAME workflow reusable for bosses and mobs.

## When to run it
- After ANY skin / class / boss / mob regen, BEFORE calling it done (mandatory — CLAUDE.md).
- When auditing existing generated art for quality.
- `verify_art` is the GEOMETRIC net (size/anchor/strays/edges/8-dir/bleed/HEROBODY). This is
  the VISUAL net for what geometry can't measure. Run both; neither replaces the other.

## What it catches (that verify_art can't)
- **Face drift:** a frame's face getting fatter/rounder/thinner, BLURRIER/less-defined, or
  looking like a different person/off-model, vs the idle face.
- **Attire/equipment drift:** a held weapon / shield / cape / robe / armor detail changing
  SHAPE, amount of detail, COLOR, presence, or SIDE from frame to frame (the paladin shield
  morphing; a cape flipping/disappearing).
- **Off-model per-direction art:** one direction generated differently from the rest (warrior
  `attackc_n` horned helmet while every other dir is a smooth dome).
- **Garment/exposure violations:** a profile view redrawing a closed robe as a low-neck bodice
  or exposing skin (mage `attack_walk` E/W) — against the garment-closed contract.
- **Off-palette FX residue:** stray FX in a colour that isn't the character's (assassin
  `attackc` green on a purple-magic design) — usually a despill, not a regen.

## Method
1. **Dedup first — scope the real coverage.** Many diagonals are byte-copies of E/W; some
   clips are fully 8-dir authored (warrior's were). Hash `<base>_<clip>_<dir>.png` per clip and
   audit every UNIQUE direction; skip byte-identical copies. (Pattern:
   `scratchpad/skin_dir_dedup.py` — md5 per dir, report unique groups.)
2. **Reference = the idle.** `<base>_anim_<dir>` frame 0 is the accepted-correct look for that
   direction (it's what the owner signed off on). Compare every other frame to it.
3. **Fan out — ONE review agent per subject**, covering EVERY clip × EVERY unique direction ×
   EVERY frame. Do NOT south-only — profile (E/W) views drift while south looks fine (the trap
   that let this slip the first time). Each agent works independently and in parallel.
4. **Verify every flag yourself.** The orchestrator re-renders each flagged (clip,dir,frame)
   and confirms before calling it a defect — never trust a subagent's raw "clean" or "flag"
   (a subagent that says "clean" on a real defect reproduces the exact miss we're fixing;
   have agents OVER-flag, then you filter).

## The agent (per-subject) — instructions template
Give each agent: the subject id, its DESIGN baseline (armour/weapon/palette in words), whether
the FACE is visible (helmet/hood → attire-only), the sprite path pattern, the dedup map (which
dirs are unique), and the idle reference. Then:

- Strip layout: frame is a SQUARE, `frame_width = image height`, `frame_count = width // height`.
- Build per-direction contact sheets — a FULL-BODY sheet (feet-aligned) for attire + a HEAD-CROP
  sheet (top ~30-35% of the body, upscaled NEAREST) for face. BRIGHTEN dark sprites before
  comparing (dark coat on dark ground hides drift).
- Objective backing where possible: face sharpness = Laplacian variance (a drifted/blurry face
  reads ~half the idle's, e.g. 700-1500 vs 2400-3800); feet-baseline y per clip (anchor pop);
  off-palette pixel counts (e.g. green = `g>r+25 & g>b+25`).
- Report as DATA (final message): findings list of `clip, dir, frame#, one-line description`,
  tagged [FACE]/[ATTIRE]/[BODY], grouped CLEAR vs BORDERLINE; clean clips summarised as
  "clip <name>: clean". Err toward flagging. Audit only — never fix.

## Known drift patterns (catalogue, 2026-08-24)
- **Fire-on-move (`attack_walk`/`_b`) = the systemic weak point.** Generated separately from the
  base clips; the profile (E/W) views drift the head/garment (warlock hood-down+hair; mage
  low-neck bodice; archer blurry face + muddy palette) while south looks acceptable.
- **Un-regenerated clips carry the face-softening drift family** (archer `ult` blur) — when a
  regen fixes some clips, the ones left behind still drift; audit them too.
- **A single direction off-model** (warrior `attackc_n` horned helmet) — one dir was generated
  with different details.
- **Mechanical/borderline** (NOT this audit's target, but surfaced): per-clip feet-anchor lift
  (attack/cast "pop"), per-direction canvas padding (size pop). These are `verify_art`/HEROBODY
  territory or an in-game check — flag, don't lump with attire drift.

## Fix taxonomy — cheapest that fixes it
1. **Despill** (deterministic, no gen): off-palette FX residue, stray specks, green rim.
2. **Frame-level edit** (frame swap/reorder, despur): a single bad frame or a projectile-only cell.
3. **Single-strip regen**: one direction off-model (e.g. `attackc_n` only).
4. **Full-clip regen** (idle-anchored, all dirs): a whole clip drifts (face/garment).
   For a regen, anchor on the idle (identity/design lock) + describe motion, or use the TWO-ref
   approach (current clip = motion/facing, a locked design plate = design) when the whole
   character needs a design correction (see the paladin regen). Re-audit after (this workflow).

## Bosses & mobs — the adaptation
Same visual method, two differences:
- **Render path:** bosses/mobs go through `enemy.gd` `_apply_strip` (median-body / cell scale),
  NOT `player_core` (frame-0 content lock). So the body-size gate is `CLIPSCALE` (enemy model),
  not `HEROBODY` (hero model). The VISUAL audit (face/attire) is identical.
- **Reference:** the boss/mob idle strip (`<base>_anim...` or the codex idle
  `<base>_anim_codex` for regen'd bosses — see art.gd BOSS_IDLE_STRIP_BASE). Bosses are often
  faceless (masks/beasts) → attire/silhouette-consistency only.
- Bosses have more clips (beam/piston/slam/etc.) and larger strips — fan out one agent per boss,
  or per boss-phase if the set is huge.

## Tooling
Starting-point scripts from the 2026-08-24 run live in the session scratchpad (ephemeral):
`skin_dir_dedup.py` (dedup), `attire_audit.py` / `drift_audit.py` / `face_sheet.py` (contact
sheets), `engine_bodysize.py` (hero on-screen body math). The method above is self-contained —
an audit agent rebuilds whatever sheets it needs — so the doc, not the scripts, is the durable
artifact. Promote a script to `tools/art/` only if a lane reuses it repeatedly.
