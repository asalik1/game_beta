#!/usr/bin/env python
"""Gait-transfer walk briefs for MOBS and BOSSES (2026-09-03 batch).

Writes one Codex stage per (subject, facing) in the runner layout
(tools/CODEX_HEADLESS.md): <stage>/codex_brief.txt + <stage>/refs/*.png.
The recipe is the one the owner passed on the hero rounds (CLAUDE.md,
art_src/stride_pilot_2026-08-27, art_src/vargoth_walk_2026-08-30):

  * reference 1 = IDENTITY: the subject's own idle frame 0 (and, for a side
    facing, its current walk frame 0) upscaled -- "reproduce this exact
    character, design must not change";
  * reference 2 = the GAIT DONOR: a walk that already has knee articulation,
    a passing/overlap frame, heel-toe roll and left/right alternation,
    rendered as ONE ROW of its frames on flat #00ff00, FLIPPED to the
    subject's native facing -- "copy his leg choreography frame-for-frame";
  * (optional) reference 3 = the strip being replaced, as a row, so the
    brief can name its defects ("straight-leg scissor poses", "same leg
    leading", "only two poses").

Archetypes pick the donor + the leg-language paragraph: biped (humanoid,
undead, armored), quadruped (wolves/hounds), arachnid (spiders), and
robed/floater (idle-only in the engine -- skipped; they glide by design).

    python tools/art/gait_briefs.py <stage_root> --plan plan.json
      plan.json = [{"base": "wolf", "facing": "flat", "arch": "quadruped",
                    "old": "wolf_walk.png", "desc": "...", "frames": 6}, ...]
    python tools/art/gait_briefs.py <stage_root> --render-donors   (sheets only)

Stages are named <base>__<facing>; feed <stage_root>/stages.txt to
run_codex_batch.ps1 (-MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 on this
box). Install the rows with tools/art/install_gait_row.py.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
GREEN = (0, 255, 0, 255)

# Gait donors: side-view rows with the articulation the owner approved.
# assassin_walk_e = the hero donor of every passed gait-transfer round;
# orc_walk (8f, 2026-08-15 phase-labelled row) and spider_walk (8f) are the
# mob-native donors; wolf gets the thorn_howler gallop (stride 1.54 bodies).
DONORS = {
    "biped": {"e": "assassin_walk_e", "s": "assassin_walk_s", "n": "assassin_walk_n"},
    "biped_heavy": {"e": "skins/elite/warrior_emberbound_heir_walk_e",
                    "s": "skins/elite/warrior_emberbound_heir_walk_s",
                    "n": "skins/elite/warrior_emberbound_heir_walk_n"},
    "quadruped": {"e": "thorn_howler_walk"},
    "arachnid": {"e": "spider_walk"},
}
DONOR_FACING_RIGHT = {"assassin_walk_e": True, "skins/elite/warrior_emberbound_heir_walk_e": True,
                      "thorn_howler_walk": False, "spider_walk": False}

LEG_LANGUAGE = {
    "biped": """What every frame must carry (copy reference 2 frame-for-frame):
- KNEES BEND. The swinging leg folds at the knee as it lifts and drives forward; the
  planted leg flexes as the body passes over it. No frame has two straight legs.
- A real PASSING moment: in the middle frames the legs come close together and
  overlap, one shin in front of the other, before the stride opens again.
- FEET ROLL: the rear heel peels off the ground while the toe still touches; the
  landing foot touches heel-first.
- LEFT AND RIGHT ALTERNATE: the first half of the row is one leg's stride, the second
  half is the OTHER leg's stride -- opposite legs leading in the two halves.
FORBIDDEN (the exact defects of the strip being replaced): straight-legged scissor
poses (both knees locked, legs like open compass blades); the same leg leading in
both halves; two or more frames with an identical lower body; feet together at
attention; more than two legs or boots in a frame.""",
    "biped_front": """What every frame must carry (copy reference 2 frame-for-frame):
- KNEES BEND: the stepping leg lifts with a clearly bent knee, its foot raised toward
  the camera; the planted leg takes the weight and the hips shift over it.
- LEFT AND RIGHT ALTERNATE: the first half of the row is one leg's step, the second
  half is the OTHER leg's step.
- The shoulders and head stay the same height and width in every frame; only the
  legs, arms and hem change.
FORBIDDEN: feet together at attention; the same leg stepping in both halves; two
frames with an identical lower body; extra legs or feet.""",
    "biped_back": """What every frame must carry (copy reference 2 frame-for-frame):
- KNEES BEND: the trailing leg lifts with a bent knee, sole of the boot showing as it
  pushes off; the planted leg takes the weight.
- LEFT AND RIGHT ALTERNATE: the first half of the row is one leg's step, the second
  half is the OTHER leg's step.
- This is a BACK view: nothing that only exists on the front (face, visor, eyes,
  chest emblem, belt buckle) may appear -- only the back of the head/helm, the
  shoulders, the back of the garment.
FORBIDDEN: any front-of-body feature; feet together at attention; two frames with an
identical lower body; extra legs or feet.""",
    "quadruped": """A real four-legged TROT, storyboarded per frame (the diagonal pairs alternate):
- frame 1: the NEAR foreleg and the FAR hind leg reach forward, off the ground, knees
  and hocks clearly bent; the other diagonal pair is planted under the body and
  angled back, pushing.
- frame 2: the reaching pair lands, the body passes over it; all four legs are
  briefly under the body, the two planted legs close together (the passing moment).
- frame 3: the FAR foreleg and the NEAR hind leg reach forward, off the ground with
  bent joints, while the first pair now trails and pushes back -- the mirror of
  frame 1 with the OTHER legs.
- frame 4: that pair lands and the body passes over it (the mirror of frame 2).
(with 6 frames: insert a mid-swing frame after 1 and after 3 -- legs half-extended,
joints bending; with 8: also a full-extension frame in each half.)
- Legs BEND at every joint as they swing; the planted legs are angled under the body,
  never stiff vertical posts. The spine flexes a little with the stride, the head
  dips slightly on landing, the tail sways.
- The paws sit on ONE shared ground line; the body's height stays constant.
FORBIDDEN: all four legs straight and vertical; the same legs leading in both halves
of the row; two frames with identical legs; the body sliding up/down; extra legs.""",
    "arachnid": """What every frame must carry (copy reference 2's gait frame-for-frame):
- A real eight-legged crawl: alternating leg groups -- one tetrapod set reaches while
  the other set pushes, swapping each half of the row.
- Leg joints BEND; legs are never all splayed identically in two frames.
- The abdomen stays at one height and the body stays at one x position in its cell.
FORBIDDEN: identical leg splay in two frames; a body that bobs up and down; extra
or missing legs.""",
}


def _load_strip(name: str) -> tuple[Image.Image, int]:
    im = Image.open(SPR / (name + ".png")).convert("RGBA")
    return im, im.height


def strip_to_row(name: str, flip: bool, out: Path, max_frames: int | None = None,
                 pad: int = 24, scale: float = 1.0) -> int:
    """Render a strip's frames as one row on flat green (a donor / 'being
    replaced' reference). Returns the frame count."""
    im, c = _load_strip(name)
    n = im.width // c
    if max_frames:
        n = min(n, max_frames)
    cells = [im.crop((f * c, 0, (f + 1) * c, c)) for f in range(n)]
    if flip:
        cells = [x.transpose(Image.FLIP_LEFT_RIGHT) for x in cells]
    # tight-crop each cell to the family bbox so the row reads at a good size
    alphas = [np.array(x)[:, :, 3] > 40 for x in cells]
    ys = np.concatenate([np.nonzero(a)[0] for a in alphas])
    top, bot = int(ys.min()), int(ys.max())
    cw = int(c * scale)
    ch = int((bot - top + 1) * scale)
    row = Image.new("RGBA", (n * (cw + pad) + pad, ch + 2 * pad), GREEN)
    for f, x in enumerate(cells):
        crop = x.crop((0, top, c, bot + 1))
        if scale != 1.0:
            crop = crop.resize((cw, ch), Image.LANCZOS)
        row.alpha_composite(crop, (pad + f * (cw + pad), pad))
    row.save(out)
    return n


def identity_ref(base: str, facing: str, out: Path, size: int = 512) -> str:
    """Idle frame 0 (per-facing when a dir set exists) on green, upscaled."""
    cands = []
    if facing in ("e", "s", "n"):
        cands += [f"{base}_anim_{facing}", f"{base}_anim_codex", f"{base}_anim"]
    else:
        cands += [f"{base}_anim_codex", f"{base}_anim", base]
    for cnd in cands:
        p = SPR / (cnd + ".png")
        if p.exists():
            im = Image.open(p).convert("RGBA")
            c = im.height
            f0 = im.crop((0, 0, min(c, im.width), c))
            a = np.array(f0)[:, :, 3] > 40
            ys, xs = np.nonzero(a)
            f0 = f0.crop((max(0, xs.min() - 8), max(0, ys.min() - 8),
                          min(c, xs.max() + 9), min(c, ys.max() + 9)))
            s = size / max(f0.size)
            f0 = f0.resize((max(1, int(f0.width * s)), max(1, int(f0.height * s))), Image.LANCZOS)
            bg = Image.new("RGBA", (f0.width + 64, f0.height + 64), GREEN)
            bg.alpha_composite(f0, (32, 32))
            bg.save(out)
            return cnd
    raise SystemExit(f"no idle for {base}")


def make_brief(job: dict, stage: Path) -> None:
    base, facing, arch = job["base"], job.get("facing", "flat"), job.get("arch", "biped")
    frames = int(job.get("frames", 6))
    faces_left = bool(job.get("faces_left", True))  # mob override PNGs face LEFT (art.gd faces_left)
    refs = stage / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    # 1. identity
    idle_used = identity_ref(base, facing, refs / "1_identity.png")
    ref_n = 2
    view = {"flat": "side", "e": "side", "w": "side", "s": "front", "n": "back"}[facing]
    # 2. donor row (bipeds/arachnids). Quadrupeds are STORYBOARDED instead --
    # ImageGen handles non-bipedal gaits well on its own (CLAUDE.md) and the
    # corpus has no fluent quadruped donor (thorn_howler = 4 stiff poses).
    donor_key = {"side": "e", "front": "s", "back": "n"}[view]
    want_right = (facing == "e") or (facing in ("flat", "w") and not faces_left)
    storyboard = arch == "quadruped" or job.get("storyboard", False)
    if storyboard:
        donor, flip_donor, dn = None, False, frames
    else:
        donor = DONORS[arch].get(donor_key) or DONORS[arch]["e"]
        donor_right = DONOR_FACING_RIGHT.get(donor, True)
        flip_donor = (view == "side") and (donor_right != want_right)
        dn = strip_to_row(donor, flip_donor, refs / "2_gait_donor.png", max_frames=frames)
    # 3. the outgoing strip (optional)
    old = job.get("old")
    old_line = ""
    old_idx = 2 if storyboard else 3
    if old and (SPR / old).exists():
        strip_to_row(old[:-4], False, refs / f"{old_idx}_current_walk.png")
        old_line = (f"\nReference {old_idx} is the CURRENT walk being replaced -- use it only to see the "
                    "character from this angle and its equipment; its leg motion is the defect "
                    "(" + job.get("defect", "stiff straight-leg poses, too few poses") + ").")
        ref_n = old_idx
    facing_word = {"side": ("RIGHT" if want_right else "LEFT"), "front": "TOWARD the viewer (facing the camera)",
                   "back": "AWAY from the viewer (back to camera)"}[view]
    lang_key = {"biped": {"side": "biped", "front": "biped_front", "back": "biped_back"},
                "biped_heavy": {"side": "biped", "front": "biped_front", "back": "biped_back"},
                "quadruped": {"side": "quadruped", "front": "quadruped", "back": "quadruped"},
                "arachnid": {"side": "arachnid", "front": "arachnid", "back": "arachnid"}}[arch][view]
    heavy = "\nMake the stride HEAVY and deliberate -- weight planted, not a light quick step." \
        if job.get("heavy") else ""
    if job.get("extra"):
        heavy += "\n" + job["extra"]
    style = job.get("style", "crisp hi-res dark-fantasy game sprite, muted palette, no black outlines")
    save_path = stage / f"{base}_walk_{facing}_row.png"
    if storyboard:
        head = (f"Redraw a {frames}-frame walk cycle of THIS creature (reference 1), walking "
                f"{facing_word}, with the gait storyboarded below.")
        walk_para = f"THE WALK:\n{LEG_LANGUAGE[lang_key]}{heavy}"
    else:
        head = (f"Redraw a {frames}-frame walk cycle of THIS character (reference 1), walking "
                f"{facing_word},\nwith EXACTLY the leg choreography of reference 2. One character's "
                "body, the other\ncharacter's walk.")
        walk_para = (f"THE WALK (reference 2 -- a DIFFERENT creature drawn from this same viewing "
                     f"angle; use\nit ONLY for how the legs move): copy its {dn}-frame leg "
                     "choreography frame-for-frame\nonto this character, matching the frame count "
                     "and phase exactly (frame 1 = its frame\n1's leg positions, and so on).\n"
                     f"{LEG_LANGUAGE[lang_key]}{heavy}\nDo NOT copy anything else from reference 2: "
                     "not its clothing, weapons, build, colours or\nspecies -- only the legs' motion, "
                     "redrawn as THIS character's legs.")
    brief = f"""{head}

THE CHARACTER (reference 1 -- reproduce this exact figure, its design must not
change): {job['desc']}
{style}. Every piece of equipment stays exactly where reference 1 shows it in every
frame -- nothing swaps sides, changes shape or disappears. Same height, same width,
same palette in every frame.

{walk_para}{old_line}

Produce ONE image: a horizontal row of EXACTLY {frames} figures, equal-width cells, all
feet on one shared ground line, constant body height, the body near each cell's
horizontal centre (no drifting across the cells), green margins on all sides -- no
figure touching any image edge or its neighbour. Flat solid #00ff00 GREEN background,
nothing else in the image. Generate ONE image and SAVE it to disk at the exact path
{save_path}
then stop.

In your final message report, for each frame 1-{frames}: which leg leads / which joints are
bent and roughly how much (slight / clear / deep){'' if storyboard else ", and whether the frame matches reference 2's same frame"}.
Report any frame with all legs straight, any repeated pose, and whether the body stayed
cell-centred and at constant height.
"""
    (stage / "codex_brief.txt").write_text(brief, encoding="utf-8")
    (stage / "job.json").write_text(json.dumps({**job, "idle_ref": idle_used, "donor": donor,
                                                "donor_flipped": flip_donor, "refs": ref_n},
                                               indent=1), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("--plan", help="json list of jobs")
    ap.add_argument("--render-donors", action="store_true")
    args = ap.parse_args()
    root = Path(args.stage_root)
    root.mkdir(parents=True, exist_ok=True)
    if args.render_donors:
        for arch, d in DONORS.items():
            for k, name in d.items():
                if (SPR / (name + ".png")).exists():
                    n = strip_to_row(name, False, root / f"donor_{arch}_{k}.png")
                    print(f"donor {arch}/{k} = {name} ({n} frames)")
        return 0
    jobs = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    stages = []
    for job in jobs:
        stage = root / f"{job['base']}__{job.get('facing', 'flat')}"
        make_brief(job, stage)
        stages.append(str(stage.resolve()))
        print("stage", stage.name)
    (root / "stages.txt").write_text("\n".join(stages) + "\n", encoding="utf-8")
    print(f"{len(stages)} stages -> {root / 'stages.txt'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
