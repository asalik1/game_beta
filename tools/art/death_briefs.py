#!/usr/bin/env python
"""Stage Codex DEATH-clip briefs for mobs that have none (`<base>_death.png`).

Since 2026-09-03 enemy.gd plays `<sprite>_death` (last frame held, then fade); a mob
without one collapses procedurally. This stages one row per base: identity = the
idle's frame 0 on green; storyboard = hit recoil -> stagger -> knees buckle ->
falling -> hits the ground -> lying still. Flat single facing, same facing as the
idle (the engine mirrors flat strips like the walk).

    python tools/art/death_briefs.py <stage_root> --bases wolf,cultist,... [--frames 6]

Install with tools/art/install_death_row.py (scales by FRAME 0's body to the idle's
body -- the enemy renderer plays action strips at the idle's scale -- and keeps each
frame's own extent, feet on the idle's feet line).
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

ARCH_LINES = {
    "biped": ("frame 1 the body jolts back from a hit (head snaps, arms fly up), frame 2 it staggers, "
              "one knee buckling, frame 3 it drops to its knees, frame 4 it topples sideways/forward, "
              "frame 5 it hits the ground, limbs sprawled, frame 6 it lies still, flat on the ground -- "
              "the FINAL frame is a lying body, much wider than tall, its feet where the standing feet were"),
    "quadruped": ("frame 1 the head jerks back from a hit, frame 2 the front legs buckle, frame 3 the "
                  "chest drops to the ground, hindquarters still up, frame 4 the body rolls onto its side, "
                  "frame 5 it slumps flat, legs stretched, frame 6 it lies still on its side -- the FINAL "
                  "frame is a body lying on its side, feet where the standing feet were"),
    "arachnid": ("frame 1 the body jolts from a hit, legs splaying, frame 2 the legs curl inward, frame 3 "
                 "the body sinks as the legs fold under it, frame 4 it tips onto its side/back, frame 5 "
                 "legs curl tight, frame 6 it lies still, curled -- the FINAL frame is a curled body low "
                 "on the ground"),
    "glide": ("frame 1 the figure recoils from a hit, frame 2 it sags and the robe/cloth collapses, frame 3 "
              "it sinks toward the ground, frame 4 it folds down, frame 5 it crumples onto the ground, "
              "frame 6 a still heap of cloth and body on the ground -- the FINAL frame is low and wide"),
}

BRIEF = """Draw a {n}-frame DEATH animation of THIS character (reference 1), as a horizontal row.

THE CHARACTER (reference 1 -- reproduce this exact figure, its design must not change):
{desc}
crisp hi-res dark-fantasy game sprite, muted palette, no black outlines. Same design, same
palette, same equipment in every frame; the figure faces the SAME way as reference 1.

THE ACTION, frame by frame: {story}.
Each frame is a distinct pose that reads as a continuous fall; the body stays roughly where
it stood (no sliding across the cell); the last frame is still and final -- it will be held
on screen. Draw NO blood spray, NO particles, NO ghost, NO effect -- only the body.

Produce ONE image: a horizontal row of EXACTLY {n} figures, evenly spaced, all drawn at ONE
identical scale (the standing figure in frame 1 is the same size as reference 1's figure;
later frames are the same body, just lower and wider), feet on one shared ground line,
generous green margins, no figure touching an edge or its neighbour (make the image WIDER
if a lying body needs room). Flat solid #00ff00 GREEN background, nothing else in the image.
Generate ONE image and SAVE it to disk at the exact path
{out}
then stop.

In your final message report, per frame, the pose, and confirm frame 1 is standing at the
reference size and the last frame lies on the ground.
"""


def single(path: Path, out: Path, size: int = 640) -> None:
    im = Image.open(path).convert("RGBA")
    c = im.height
    f0 = im.crop((0, 0, min(c, im.width), c))
    f0 = f0.crop(f0.getchannel("A").getbbox())
    s = size / max(f0.size)
    f0 = f0.resize((max(1, int(f0.width * s)), max(1, int(f0.height * s))), Image.LANCZOS)
    bg = Image.new("RGBA", (f0.width + 64, f0.height + 64), GREEN)
    bg.alpha_composite(f0, (32, 32))
    bg.save(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("--plan", required=True, help="json list of {base, arch, desc}")
    ap.add_argument("--frames", type=int, default=6)
    args = ap.parse_args()
    root = Path(args.stage_root)
    root.mkdir(parents=True, exist_ok=True)
    stages = []
    for job in json.loads(Path(args.plan).read_text(encoding="utf-8")):
        base = job["base"]
        idle = next((SPR / f"{base}_{k}.png" for k in ("anim", "anim_codex") if (SPR / f"{base}_{k}.png").exists()), None)
        if idle is None:
            print(f"skip {base}: no idle")
            continue
        stage = root / f"{base}__death"
        refs = stage / "refs"
        refs.mkdir(parents=True, exist_ok=True)
        single(idle, refs / "1_identity.png")
        n = job.get("frames", args.frames)
        out = (stage / f"{base}_death_row.png").resolve()
        (stage / "codex_brief.txt").write_text(BRIEF.format(
            n=n, desc=job["desc"], story=ARCH_LINES[job.get("arch", "biped")], out=out), encoding="utf-8")
        (stage / "job.json").write_text(json.dumps({"base": base, "clip": "death", "frames": n,
                                                    "idle": idle.name, "arch": job.get("arch", "biped")}, indent=1),
                                        encoding="utf-8")
        stages.append(str(stage.resolve()))
        print(f"stage {base} death ({n} frames)")
    (root / "stages.txt").write_text("\n".join(stages) + "\n", encoding="utf-8")
    print(f"{len(stages)} stages -> {root / 'stages.txt'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
