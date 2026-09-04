#!/usr/bin/env python
"""Redraw an existing clip in a TRUE side profile — the fix for a whole facing
column that was authored front-on (the base mage's E column, 2026-09-03: her
anim_e / walk_e / attack_e / cast_e all stand square to the camera; the W
column mirrors them, so she has no side view at all).

Per clip the stage carries three references:
  1_identity  the character's own front idle (design, palette, equipment)
  2_view      a sibling drawn in a real profile (what "side view" means here)
  3_clip      the outgoing clip as a labelled row (the ACTION per frame —
              what each frame does, how many frames, the timing)
and asks for the same clip, same frame count, same per-frame action, seen
from the RIGHT side. The engine's hero path plays E and mirrors it for W.

    python tools/art/profile_clip_briefs.py <stage_root> --base mage \\
        --view skins/elite/mage_blighted_healer_anim_e --clips anim,walk,attack,cast

Install with install_gait_row (--old = the outgoing E strip, --out the E file,
--mirror-out the W file; the idle is 'anim').
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

ACTION = {
    "anim": "a standing IDLE: the character breathes and shifts weight very slightly; feet planted, no step",
    "walk": "a WALK cycle: the legs alternate through a real stride with bent knees and a passing frame; "
            "the hem sways and the boots show alternately below it",
    "attack": "the basic ranged ATTACK: the free hand thrusts forward and a bolt is loosed from it "
              "(draw the hand gesture only -- NO bolt, spark, flame or projectile on the sprite)",
    "cast": "a spell CAST: the staff rises and the free hand sweeps up in a gathering gesture "
            "(gesture only -- NO magic effect drawn on the sprite)",
    "dash": "a DASH: a low forward lunge and recovery",
}


def strip_row(path: Path, out: Path, pad: int = 26) -> int:
    im = Image.open(path).convert("RGBA")
    c = im.height
    n = max(1, im.width // c)
    a = np.array(im)[:, :, 3] > 40
    ys = np.nonzero(a)[0]
    top, bot = int(ys.min()), int(ys.max())
    row = Image.new("RGBA", (n * (c + pad) + pad, (bot - top + 1) + 2 * pad), GREEN)
    for f in range(n):
        row.alpha_composite(im.crop((f * c, top, (f + 1) * c, bot + 1)), (pad + f * (c + pad), pad))
    row.save(out)
    return n


def single(path: Path, out: Path, size: int = 520) -> None:
    im = Image.open(path).convert("RGBA")
    c = im.height
    f0 = im.crop((0, 0, min(c, im.width), c))
    bb = f0.getchannel("A").getbbox()
    f0 = f0.crop(bb)
    s = size / max(f0.size)
    f0 = f0.resize((max(1, int(f0.width * s)), max(1, int(f0.height * s))), Image.LANCZOS)
    bg = Image.new("RGBA", (f0.width + 64, f0.height + 64), GREEN)
    bg.alpha_composite(f0, (32, 32))
    bg.save(out)


BRIEF = """Redraw this animation clip as a TRUE RIGHT-SIDE PROFILE.

Reference 1 is the character (front view): reproduce this exact design -- face,
hair, garment, palette, every held or floating item and which hand holds it.
Nothing about the design changes.
Reference 2 shows a similar character drawn in a REAL side profile: the viewer
sees the RIGHT side of the body only, one shoulder in front of the other, the
face in profile with one eye visible, the near arm in front of the torso. Draw
reference 1's character from THIS angle.
Reference 3 is the current clip, {n} frames, which was drawn front-on by mistake.
Keep its frame count and its per-frame ACTION exactly: {action}. Frame 1 of the
new row does what frame 1 of reference 3 does, and so on -- only the viewing
angle changes.

{ident}

Hard requirements:
- A genuine profile in EVERY frame: no frame turns the face or the shoulders
  back toward the camera.
- Same body height and width in every frame; feet on one shared ground line;
  the body near each cell's horizontal centre (no drift across the row).
- The robe stays CLOSED and floor-length: no slit, no bare legs; the walk reads
  through the boots below the hem and the hem's sway.
{fx_rule}

Produce ONE image: a horizontal row of EXACTLY {n} figures, evenly spaced, all the
same size (if they will not fit at full size, make the image WIDER), green margins
all round, no figure touching an edge or its neighbour. Flat solid #00ff00 GREEN
background, nothing else in the image.
Generate ONE image and SAVE it to disk at the exact path
{out}
then stop.

In your final message report, per frame, what the character is doing and confirm
every frame is a profile with no projectile or effect drawn.
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("--base", required=True)
    ap.add_argument("--view", required=True, help="a sprite drawn in true profile (view reference)")
    ap.add_argument("--identity", default=None, help="front idle to use as identity (default <base>_anim_s)")
    ap.add_argument("--clips", default="anim,walk,attack,cast")
    ap.add_argument("--desc", default="", help="identity words for the brief")
    ap.add_argument("--keep", default="", help="signature FX that ARE the design and must stay "
                    "(the warlock's floating flaming skull + glowing grimoire); default = draw no FX at all")
    args = ap.parse_args()
    if args.keep:
        fx_rule = (f"- Keep {args.keep} exactly as in reference 1, in EVERY frame -- they are part of\n"
                   "  the character. Apart from those, draw NO projectile, bolt, spark or spell\n"
                   "  effect -- the game spawns those; anything drawn here would double it.")
    else:
        fx_rule = ("- Draw NO projectile, bolt, flame, spark, glow or magic effect anywhere -- the\n"
                   "  game spawns those; anything drawn here would double it.")
    root = Path(args.stage_root)
    root.mkdir(parents=True, exist_ok=True)
    ident_sprite = args.identity or f"{args.base}_anim_s"
    stages = []
    for clip in [c.strip() for c in args.clips.split(",") if c.strip()]:
        old = SPR / f"{args.base}_{clip}_e.png"
        if not old.exists():
            print(f"skip {clip}: no {old.name}")
            continue
        stage = root / f"{args.base}__{clip}__e"
        refs = stage / "refs"
        refs.mkdir(parents=True, exist_ok=True)
        single(SPR / f"{ident_sprite}.png", refs / "1_identity.png")
        single(SPR / f"{args.view}.png", refs / "2_view.png")
        n = strip_row(old, refs / "3_clip.png")
        out = (stage / f"{args.base}_{clip}_e_row.png").resolve()
        ident = f"THE CHARACTER: {args.desc}" if args.desc else ""
        (stage / "codex_brief.txt").write_text(
            BRIEF.format(n=n, action=ACTION.get(clip, "the same action as reference 3"),
                         ident=ident, fx_rule=fx_rule, out=out), encoding="utf-8")
        (stage / "job.json").write_text(json.dumps(
            {"base": args.base, "clip": clip, "facing": "e", "frames": n,
             "old": old.name}, indent=1), encoding="utf-8")
        stages.append(str(stage.resolve()))
        print(f"stage {args.base} {clip} e ({n} frames)")
    (root / "stages.txt").write_text("\n".join(stages) + "\n", encoding="utf-8")
    print(f"{len(stages)} stages -> {root / 'stages.txt'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
