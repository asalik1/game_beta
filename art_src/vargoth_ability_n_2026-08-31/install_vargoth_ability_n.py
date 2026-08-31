"""Install the Vargoth N-facing ability regen rows (attack_n + blade_n).

Front-view-art-wearing-the-N-name fix (owner catch 2026-08-31, sibling of the
walk regen's helm fix): vargoth_attack_n was unique FRONT-view art and
vargoth_blade_n a byte-copy of blade_e; both regenerated as true back views
(identity ref = the fixed vargoth_walk_codex_n). Thin sibling of
install_vargoth_walk.py at each strip's own OLD geometry:

  - cell / feet line / rest-frame body measured from the OUTGOING strip
    (old_backup/) so the enemy renderer's read (CLIPSCALE median-body/cell)
    stays put;
  - scale = old rest-frame body / new rest-frame body (rest frame per action:
    attack f0, blade f3 -- the raised-sword frames make median-body scaling
    lie), capped so the tallest frame keeps >=8px cell headroom;
  - X: ONE global shift aligning the row's median DARK-pixel centroid (armor/
    cape mass, luma<100 -- immune to sword/flame swings) to the old strip's;
    per-frame anchoring would fight the gen's own composition, and the strike
    lean is intentional choreography;
  - per-frame feet pin to the old feet line;
  - orphan sweep: EDGE-ZONE components only (the sliced-blade class from the
    walk install); the walk's big+hot rule would eat blade f3's detached
    star-flare rays, so non-edge components are only REPORTED for the eye
    pass;
  - NO tone_match by default: the strips co-displayed with these are the
    (gray-caped, softer) fixed walk_n frames, not the black front strips --
    judge tone on the review sheet against walk_fixed_n_reference.png and
    pass --tone (matches vs that walk reference) only if the eye says off.

    python art_src/vargoth_ability_n_2026-08-31/install_vargoth_ability_n.py [--dry] [--tone]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

JOB = Path(__file__).resolve().parent
WT = JOB.parents[1]
sys.path.insert(0, str(WT / "tools" / "art"))
from install_gait_walk import key_and_despill, tone_match  # noqa: E402

SPRITES = WT / "game" / "assets" / "sprites"
FRAMES = 4
EDGE_ZONE = 90       # px from a cell's x-edges = slice-orphan territory
HEADROOM = 8         # min px above the tallest frame after feet-pin

STRIPS = {
    "vargoth_attack_n.png": {"row": JOB / "attack_n" / "vargoth_attack_n_row.png", "rest": 0},
    "vargoth_blade_n.png": {"row": JOB / "blade_n" / "vargoth_blade_n_row.png", "rest": 3},
}


def frame_alpha_stats(arr: np.ndarray) -> tuple[int, int, int]:
    """(top, bottom, body_h) of alpha>40 content."""
    ys = np.nonzero(arr > 40)[0]
    return int(ys.min()), int(ys.max()), int(ys.max() - ys.min() + 1)


def dark_cx(rgba: np.ndarray) -> float:
    """X-centroid of the armor/cape mass: opaque AND dark (immune to sword/flames)."""
    r, g, b, a = (rgba[:, :, i].astype(int) for i in range(4))
    luma = (299 * r + 587 * g + 114 * b) // 1000
    ys, xs = np.nonzero((a > 40) & (luma < 100))
    return float(xs.mean())


def sweep_edge_orphans(strip: Image.Image, label: str) -> Image.Image:
    """Drop non-largest components sitting in a cell's slice-edge zones; report the rest."""
    from scipy import ndimage
    arr = np.array(strip)
    cell = arr.shape[0]
    n = arr.shape[1] // cell
    for f in range(n):
        c = arr[:, f * cell:(f + 1) * cell]
        a = c[:, :, 3] > 40
        labels, count = ndimage.label(a)
        if count <= 1:
            continue
        sizes = ndimage.sum(a, labels, range(1, count + 1))
        main = int(np.argmax(sizes)) + 1
        for lab in range(1, count + 1):
            if lab == main or sizes[lab - 1] < 40:
                continue
            m = labels == lab
            ys, xs = np.nonzero(m)
            in_edge = xs.max() < EDGE_ZONE or xs.min() > cell - EDGE_ZONE
            box = f"x[{xs.min()},{xs.max()}] y[{ys.min()},{ys.max()}] {int(sizes[lab - 1])}px"
            if in_edge:
                c[:, :, 3] = np.where(m, 0, c[:, :, 3])
                print(f"  {label} f{f}: SWEPT edge-zone orphan {box}")
            else:
                print(f"  {label} f{f}: kept detached component {box} -- eye-check it")
    return Image.fromarray(arr)


def build(row_path: Path, old_path: Path, rest: int, label: str) -> Image.Image:
    old = Image.open(old_path).convert("RGBA")
    cell = old.height
    oarr = np.array(old)
    feet_y = frame_alpha_stats(oarr[:, :, 3][:, :cell])[1]
    old_rest_body = frame_alpha_stats(oarr[:, :, 3][:, rest * cell:(rest + 1) * cell])[2]
    old_cx_off = np.median([dark_cx(oarr[:, f * cell:(f + 1) * cell]) - cell / 2
                            for f in range(FRAMES)])

    rgba = key_and_despill(Image.open(row_path))
    fw = rgba.shape[1] // FRAMES
    cells = [rgba[:, f * fw:(f + 1) * fw] for f in range(FRAMES)]
    bodies = [frame_alpha_stats(c[:, :, 3])[2] for c in cells]
    S = old_rest_body / float(bodies[rest])
    S_fit = min((feet_y - HEADROOM) / b for b in bodies)
    if S_fit < S:
        print(f"  {label}: scale capped {S:.3f} -> {S_fit:.3f} (tallest frame headroom)")
        S = S_fit
    new_cx_off = np.median([dark_cx(c) * S - cell / 2 for c in cells])
    shift = int(round(old_cx_off - new_cx_off))
    print(f"  {label}: cell {cell} feet {feet_y} rest_body {old_rest_body} "
          f"scale {S:.3f} global_x_shift {shift:+d}")

    out = Image.new("RGBA", (cell * FRAMES, cell), (0, 0, 0, 0))
    for f, c in enumerate(cells):
        img = Image.fromarray(c).resize(
            (max(1, int(fw * S)), max(1, int(rgba.shape[0] * S))), Image.LANCZOS)
        a = np.array(img)[:, :, 3]
        ys, xs = np.nonzero(a > 40)
        # build each frame in its own cell canvas so content clips at ITS cell
        # edge (like the outgoing art) instead of invading the neighbour frame;
        # paste-with-mask tolerates the negative offsets alpha_composite rejects
        cellimg = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        cellimg.paste(img, (shift, feet_y - int(ys.max())), img)
        out.alpha_composite(cellimg, (f * cell, 0))
        span = f"x[{xs.min() + shift},{xs.max() + shift}] of {cell}"
        print(f"    f{f}: content_h {int(ys.max() - ys.min() + 1)} {span}")
    # post-resize fringe despill (same rule as install_gait_walk.build_strip)
    arr = np.array(out).astype(int)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    hot = (a > 0) & (a < 255) & (g > np.maximum(r, b))
    arr[:, :, 1] = np.where(hot, np.maximum(r, b), g)
    return sweep_edge_orphans(Image.fromarray(arr.clip(0, 255).astype(np.uint8)), label)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--tone", action="store_true",
                    help="tone-match vs the fixed walk_n reference (see docstring)")
    args = ap.parse_args()

    for name, spec in STRIPS.items():
        if not spec["row"].exists():
            print(f"MISSING row: {spec['row']}")
            return 1
        strip = build(spec["row"], JOB / "old_backup" / name, spec["rest"], name)
        if args.tone:
            strip = tone_match(strip, JOB / "walk_fixed_n_reference.png")
            print(f"  {name}: tone-matched vs fixed walk_n")
        dest = SPRITES / name
        if args.dry:
            print(f"DRY would write {dest.name} {strip.size}")
        else:
            strip.save(dest)
            print(f"wrote {dest.relative_to(WT)} {strip.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
