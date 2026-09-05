#!/usr/bin/env python
"""Stage a surgical EDIT-IN-PLACE re-roll of an existing strip: "reproduce this row
exactly, change ONLY <part>". The fix taxonomy behind vargoth's helm (395b156) and the
DRIFT_AUDIT WRONG-FACING PART / equipment-drift classes -- when the gait, pose and
identity of a clip are approved and one part drifts (a flaming blade that dims to a plain
sword on the E walk, a shield that blinks, a prop on the wrong side).

    python tools/art/edit_in_place_brief.py <stage_dir> --strip game/assets/sprites/warrior_walk_e.png \\
        --part-ref game/assets/sprites/warrior_anim_e.png \\
        --change "the sword: in EVERY frame it is the same flaming blade as reference 2 ..." \\
        [--keep "everything else: the walk, pose, armour, palette"]

refs/1_strip.png = the outgoing strip as a labelled row on green (frames 1..N, the
action/pose canon), refs/2_part.png = frame 0 of --part-ref (how the part must look).
Install with install_gait_row --old <strip> --row <stage>/<name>_row.png [--mirror-out].
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

GREEN = (0, 255, 0, 255)


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


BRIEF = """Reproduce this animation row EXACTLY, with ONE change.

Reference 1 is the current {n}-frame clip, laid out as a row (frame 1 at the left). Every frame's
pose, the walk/leg positions, the body height, the garment, the palette and the position of
every figure in the row are CORRECT and must be reproduced as they are -- this is a surgical
edit, not a redraw. {keep}

THE ONLY CHANGE: {change}
Reference 2 shows how that part must look (take its shape, size, colours and glow from there).
Apply the change consistently in EVERY frame: same size, same detail, same colours, only its
position/angle following the pose of that frame. Nothing else about any frame changes.

Produce ONE image: a horizontal row of EXACTLY {n} figures in the same order and spacing as
reference 1, all the same size, green margins all round, no figure touching an edge or its
neighbour. Flat solid #00ff00 GREEN background, nothing else in the image.
Generate ONE image and SAVE it to disk at the exact path
{out}
then stop.

In your final message, list per frame what changed (it should be only the part named above) and
confirm the poses, leg positions and body sizes match reference 1 frame for frame.
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage")
    ap.add_argument("--strip", required=True)
    ap.add_argument("--part-ref", required=True)
    ap.add_argument("--change", required=True)
    ap.add_argument("--keep", default="")
    args = ap.parse_args()
    stage = Path(args.stage)
    refs = stage / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    strip = Path(args.strip)
    n = strip_row(strip, refs / "1_strip.png")
    single(Path(args.part_ref), refs / "2_part.png")
    out = (stage / f"{strip.stem}_row.png").resolve()
    (stage / "codex_brief.txt").write_text(
        BRIEF.format(n=n, keep=args.keep, change=args.change, out=out), encoding="utf-8")
    (stage / "job.json").write_text(json.dumps(
        {"strip": str(strip), "part_ref": args.part_ref, "frames": n, "change": args.change},
        indent=1), encoding="utf-8")
    print(f"stage {stage} ({n} frames) -> {out.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
