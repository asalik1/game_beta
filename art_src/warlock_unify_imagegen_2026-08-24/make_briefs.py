"""Generate ImageGen briefs for the warlock full-unify (cast/ult/death).

Each stage = art_src/warlock_unify_imagegen_2026-08-24/<clip>_<dir>/ with a
codex_brief.txt (STDIN) + refs/ (the matching crisp idle direction as binding
identity, plus idle_s as a front identity-consistency reference). One horizontal
9-frame row per stage, keyed to match the crisp idle design.
"""
import os, shutil
FAM = os.path.dirname(os.path.abspath(__file__))
REFS = os.path.join(FAM, "refs")

FACING = {
    "s":  "FRONT / SOUTH facing (facing the viewer, looking down-screen)",
    "se": "FRONT-RIGHT THREE-QUARTER / SOUTH-EAST facing (angled toward the viewer's lower-right; we see his front-right)",
    "e":  "RIGHT PROFILE / EAST facing (turned to face the RIGHT edge of the frame; we see his right side)",
    "ne": "REAR-RIGHT THREE-QUARTER / NORTH-EAST facing (angled away toward the upper-right; we see his back-right)",
    "n":  "BACK / NORTH facing (facing away, up-screen; we see his back and the back of the hood)",
    "nw": "REAR-LEFT THREE-QUARTER / NORTH-WEST facing (angled away toward the upper-left; we see his back-left)",
    "w":  "LEFT PROFILE / WEST facing (turned to face the LEFT edge of the frame; we see his left side)",
    "sw": "FRONT-LEFT THREE-QUARTER / SOUTH-WEST facing (angled toward the viewer's lower-left; we see his front-left)",
}
REAR = {"ne", "n", "nw"}  # face hidden in the hood

# per-clip 9-frame storyboard (facing-neutral wording; the ref + facing line fix the view)
CAST_STORY = """ frame 1 neutral standing rest, identical to the idle pose, both arms low
 frame 2 both forearms begin to lift, weight settling
 frame 3 both hands raised to chest height, fingers spreading, a faint violet spark kindling between the palms
 frame 4 hands pushing apart, beginning to pull the rift open, arms bending outward
 frame 5 hands spread wider, arms opening, a small violet tear of energy pinched between the fingertips
 frame 6 PEAK: arms spread wide and slightly forward, hands pulling the rift its widest, the strongest committed pose, a compact violet glow between the hands
 frame 7 arms still wide but beginning to draw the power inward, glow condensing
 frame 8 hands drawing back toward the chest, arms folding in
 frame 9 recovery, arms lowering back toward the frame-1 rest pose"""

ULT_STORY = """ frame 1 neutral standing rest, identical to the idle pose (grimoire held in one hand, the OTHER hand low)
 frame 2 the free hand (the one NOT holding the grimoire) begins to rise
 frame 3 the free hand lifts to shoulder height, fingers curling, a faint violet hex-spark kindling at the palm
 frame 4 the free hand cocks back beside the head, gathering a compact violet hex charge
 frame 5 the arm begins to drive forward, the hex charge brightening at the hand
 frame 6 PEAK: the free hand THRUSTS forward in the facing direction, unleashing the curse, the strongest committed pose, a compact violet burst right at the fingertips
 frame 7 the arm fully extended, the hand splayed, the violet glow condensing at the fingertips
 frame 8 the casting arm begins to recoil back toward the body
 frame 9 recovery, the arm lowering back toward the frame-1 rest pose"""

DEATH_STORY = """ frame 1 standing, a sharp hit landing, the body flinching
 frame 2 staggering, head snapping back, one step off balance
 frame 3 buckling, the knees starting to give, arms flailing loose
 frame 4 dropping to one knee, torso pitching forward, the grimoire slipping from the hand
 frame 5 collapsing further, both knees down, body folding
 frame 6 falling sideways, losing all support
 frame 7 hitting the ground, body sprawling
 frame 8 settling, the violet skull-flame guttering out
 frame 9 final grounded corpse, fully collapsed and still, a suitable held death pose"""

CLIPS = {
    "cast": ("CAST (Void Rift)", CAST_STORY,
             "both hands tearing open a rift",
             "the big void-rift ring, beams and burst"),
    "ult":  ("ULT (Hex curse)", ULT_STORY,
             "one hand hurling a dark hex curse",
             "the big hex sigil ring, curse beams and burst"),
}

def identity_line(dir_):
    base = ("a LEAN, SLENDER hooded warlock with slim elegant proportions, a near-black / dark "
            "charcoal robe and cloak, a smooth VERTICAL dark-gold tabard panel down the center front "
            "with a gold crossed/V chest treatment below a gold V-neck collar and a small red gem at "
            "the throat, thin gold hem and cuff trim, a cracked bone SKULL familiar wreathed in VIOLET "
            "flame floating beside his LEFT shoulder, and an open glowing grimoire (dark red/brown cover) "
            "held in his RIGHT hand")
    if dir_ in REAR:
        base += (". This is a REAR view: the deep hood is up and the face is completely hidden in hood "
                 "shadow — no face and no eyes visible")
    return base

TEMPLATE = """You are generating ONE game sprite animation master with your built-in image_gen tool. Read $CODEX_HOME/skills/.system/imagegen/SKILL.md first, then follow this brief exactly. Work only inside the current directory (the staging dir). Do NOT touch any file under C:\\Users\\asali\\Projects\\MMO.

Two images are attached to this prompt:
- Image 1 = refs/1_identity_idle_{dir}.png : the BINDING identity, FACING, palette, pixel-art treatment AND body-scale reference. Reproduce this EXACT warlock in this EXACT facing: {identity}. Reproduce his slim proportions, gear, markings and palette. Do NOT redesign him, do NOT make him stocky or broad-shouldered, do NOT add crossed shoulder straps or an X-sash beyond the gold chest treatment already shown, do NOT change the facing.
- Image 2 = refs/2_identity_front.png : the same warlock seen from the FRONT, for identity/palette consistency ONLY. Do NOT copy its facing — keep the facing of Image 1.

TASK: generate exactly ONE new horizontal 9-frame source ROW for this warlock's {clip_label} animation, {facing}, with this image_gen prompt (adapt only if the tool's parameters require it; keep every constraint):

---
Use case: illustration-story
Asset type: high-resolution game sprite animation source, a SINGLE horizontal ROW of exactly nine equal square cells, to be cropped into a horizontal sprite strip. Wide landscape canvas.
Input images: Image 1 is the binding identity + FACING + palette + pixel-art + body-scale reference; Image 2 is a front-view identity-consistency reference only.
Scene/backdrop: a perfectly flat uniform #00ff00 chroma-key background filling every pixel, including the gutters between cells. No scenery, floor plane, ground, puddle, platform, cast shadow, contact shadow, gradient, vignette, border, grid, line, or panel divider.
Primary request: create exactly NINE separate equal square sprite cells arranged left-to-right in ONE horizontal row (reading order frame 1 through frame 9). All nine cells have identical scale, camera and framing; no cell may overlap another; no drawn separators; leave a broad band of flat green between every pair of cells.
Subject: the exact same LEAN slender warlock as Image 1 in every cell — same slim proportions, same near-black robe with the vertical gold tabard, gold chest treatment, gold V-collar with red throat-gem, the violet-flamed bone skull familiar and the open red grimoire — {facing_short} in all nine cells.
Style/medium: crisp high-resolution dark-fantasy pixel art with hard readable pixel clusters and a controlled palette, matching Image 1; not painterly, not 3D, not anime, not a smooth digital painting.
Composition/framing and ANCHOR RULE: the warlock is centred in each square cell, his standing body about 66% of the cell height, with generous green margin on every side so raised arms and small effects fit. He stays in the SAME spot in every cell — his head and his feet sit at the same coordinates in every frame; nothing slides sideways, the camera never moves, the body never changes size. Only the arms/hands, cloak and the small hand-glow move.
{clip_label} 9-frame storyboard - nine VISIBLY DIFFERENT poses of THIS character, {action}, all in the SAME {facing} facing:
{story}
IDENTITY LOCK (critical): in every cell he is EXACTLY the lean slender warlock of Image 1 in the SAME facing, with THAT slim silhouette, the vertical gold tabard and chest treatment, the gold V-collar and red throat-gem, the violet-flamed skull familiar and the red grimoire on the SAME sides as Image 1. Do NOT make him stocky, broad-shouldered or heavy; do NOT swap the skull and grimoire sides; do NOT change the face{face_note}; do NOT rotate him to a different facing between frames (the final recovery frame must still face the same way as frame 1).
FX RULE (critical, overrides any effect wording above): the game engine draws {game_fx} SEPARATELY. This sprite must show ONLY the warlock's body motion plus his PERSISTENT props already in Image 1 (the violet-flamed skull familiar and the open glowing grimoire). A small compact violet spark/glow right AT his casting hand(s) at the peak is allowed, but do NOT draw any large ring, portal, sigil, orb, beam, ray, wave, or effect leaving the body, flying, or floating detached in the cell.
Constraints: output only the nine cells on green; no text, watermark, numbers, UI, extra characters, extra limbs, duplicate props, scenery, floor artifact, shadow, or separators. Do not use #00ff00 or any bright/pure green anywhere on the character or its effects (the violet flame and gold trim are fine; just no green on him). Keep the warlock identical to Image 1 in all nine frames. Frames 1 through 9 must each have a clearly different pose from every other frame, and frame 6 must be the widest/most-committed pose.
---

AFTER generation:
1. Copy the raw generated PNG (do not resize it) to ./{stem}_v1.png in the current directory.
2. Run the skill's remove_chroma_key.py helper on it and write the keyed RGBA result to ./{stem}_v1_keyed.png (auto-key sampling, despill on).
3. Do NOT slice, do NOT install, do NOT write anywhere under the MMO project. I will do the slicing.
4. In your final message report: the raw output size in pixels; whether all NINE cells were produced in one row with visibly different poses; whether the warlock stayed LEAN/slender, on-model and in the correct {facing} facing vs Image 1 (or drifted stocky / wrong robe / wrong face / wrong facing); and any deviation you noticed (poses sliding/resizing, effect touching an edge, extra limbs, skull/grimoire swapped, fewer than 9 cells, final frame flipping facing). Be blunt about defects; do not soften them.

If image_gen is unavailable, say so and stop; do not fall back to another provider or the CLI.
"""

DEATH_TEMPLATE = TEMPLATE  # death uses the same skeleton; facing = front/3-4

def facing_short(dir_):
    return FACING[dir_].split(" (")[0]

def write_stage(clip, dir_):
    if clip == "death":
        stem = "death"
        stage = os.path.join(FAM, "death")
        label, story, action, game_fx = ("DEATH", DEATH_STORY,
            "collapsing and dying", "any death FX, blood or soul wisps")
        ref_dir = "s"
        facing = FACING["s"]
    else:
        stem = "%s_%s" % (clip, dir_)
        stage = os.path.join(FAM, stem)
        label, story, action, game_fx = CLIPS[clip]
        ref_dir = dir_
        facing = FACING[dir_]
    os.makedirs(os.path.join(stage, "refs"), exist_ok=True)
    shutil.copy(os.path.join(REFS, "idle_%s.png" % ref_dir),
                os.path.join(stage, "refs", "1_identity_idle_%s.png" % ref_dir))
    shutil.copy(os.path.join(REFS, "idle_s.png"),
                os.path.join(stage, "refs", "2_identity_front.png"))
    face_note = "" if (clip == "death" or dir_ not in REAR) else " (rear view: keep the face hidden in the hood, no face)"
    brief = TEMPLATE.format(
        dir=ref_dir, identity=identity_line(ref_dir), clip_label=label,
        facing=facing, facing_short=facing_short(ref_dir), action=action,
        story=story, game_fx=game_fx, stem=stem, face_note=face_note)
    with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
        f.write(brief)
    return stage

stages = []
for d in ["se", "e", "ne", "n", "nw", "w", "sw"]:
    stages.append(write_stage("cast", d))
for d in ["s", "se", "e", "ne", "n", "nw", "w", "sw"]:
    stages.append(write_stage("ult", d))
stages.append(write_stage("death", None))
print("wrote %d stages:" % len(stages))
for s in stages:
    print("  " + s)
