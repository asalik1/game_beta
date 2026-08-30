"""Slice a generated cutout-puppet parts row into part PNGs + a draft rig.json
for shot_g2d_bake.gd (the 2D-skeletal pilot, 2026-08-30).

    python tools/art/g2d_slice_parts.py <parts_row.png> <out_dir> [--body 235]

Keys out #00ff00, splits connected x-clusters left-to-right, names them by the
fixed brief order, despills the rim, and writes rig.json with pivots at
anatomical points (fractions of each part's box) and attach offsets estimated
from standard body proportions scaled to --body. Pivots/attaches are a DRAFT —
tune by baking and looking (shot.bat g2d_bake), not by faith.
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ORDER = ["head", "torso", "cape", "near_upper_arm", "near_forearm",
         "far_arm", "near_thigh", "near_shin", "far_thigh", "far_shin"]

# pivot as (fx, fy) of the part bbox: the point that sits ON the joint.
PIVOT = {
    "head": (0.45, 0.92), "torso": (0.5, 0.55), "cape": (0.5, 0.06),
    "near_upper_arm": (0.5, 0.12), "near_forearm": (0.35, 0.10),
    "far_arm": (0.5, 0.10), "near_thigh": (0.5, 0.10), "near_shin": (0.5, 0.06),
    "far_thigh": (0.5, 0.10), "far_shin": (0.5, 0.06),
}
# parent + attach point in the parent's pivot space, as fractions of BODY height
# (x right, y down). Torso pivot = hips = rig root.
ATTACH = {
    "torso": ("", 0.0, 0.0),
    "head": ("torso", 0.02, -0.32),
    "cape": ("torso", -0.06, -0.30),
    "near_upper_arm": ("torso", 0.03, -0.28),
    "near_forearm": ("near_upper_arm", 0.0, 0.155),
    "far_arm": ("torso", -0.03, -0.28),
    "near_thigh": ("torso", 0.03, 0.0),
    "near_shin": ("near_thigh", 0.0, 0.215),
    "far_thigh": ("torso", -0.03, 0.0),
    "far_shin": ("far_thigh", 0.0, 0.215),
}
Z = {"cape": -3, "far_arm": -2, "far_thigh": -1, "far_shin": -1,
     "torso": 0, "head": 1, "near_thigh": 2, "near_shin": 2,
     "near_upper_arm": 3, "near_forearm": 4}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("row")
    ap.add_argument("out_dir")
    ap.add_argument("--body", type=float, default=235.0)
    args = ap.parse_args()
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    arr = np.array(Image.open(args.row).convert("RGBA")).astype(int)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    key = (g > 120) & (g > r + 30) & (g > b + 30)
    arr[:, :, 3] = np.where(key, 0, 255)
    spill = (~key) & (g > np.maximum(r, b) + 18)
    arr[:, :, 1] = np.where(spill, np.maximum(r, b) + 8, arr[:, :, 1])
    a = arr[:, :, 3]

    colmask = (a > 40).any(axis=0)
    xs = np.nonzero(colmask)[0]
    clusters, start = [], xs[0]
    for i in range(1, len(xs)):
        if xs[i] - xs[i - 1] > 14:
            clusters.append((start, xs[i - 1])); start = xs[i]
    clusters.append((start, xs[-1]))
    if len(clusters) != len(ORDER):
        print(f"WARN: {len(clusters)} clusters vs {len(ORDER)} expected — check the row!")
    parts = []
    for i, (x0, x1) in enumerate(clusters[:len(ORDER)]):
        name = ORDER[i]
        sub = arr[:, x0:x1 + 1]
        ys = np.nonzero(sub[:, :, 3] > 40)[0]
        y0, y1 = ys.min(), ys.max()
        crop = sub[y0:y1 + 1]
        img = Image.fromarray(crop.clip(0, 255).astype(np.uint8))
        img.save(out / f"{name}.png")
        w, h = img.size
        fx, fy = PIVOT[name]
        parent, ax, ay = ATTACH[name]
        parts.append({"name": name, "file": f"{name}.png",
                      "pivot": [round(w * fx), round(h * fy)],
                      "parent": parent,
                      "attach": [round(args.body * ax), round(args.body * ay)],
                      "z": Z[name]})
        print(f"{name}: {w}x{h}")
    spec = {"scale": 1.0, "parts": parts, "gait": {}}
    (out / "rig.json").write_text(json.dumps(spec, indent=1), encoding="utf-8")
    print(f"rig.json + {len(parts)} parts -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
