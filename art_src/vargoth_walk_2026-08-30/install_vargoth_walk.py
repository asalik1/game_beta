"""Install the Vargoth gait-transfer walk rows over vargoth_walk_codex_<dir>.png.

Thin caller over tools/art/install_gait_walk.py's functions (key/anchor/scale/
tone/mirror) at BOSS geometry: 800px cells, per-direction feet/body measured
from the outgoing strips (backed up in old_backup/). Layout mirrors the
owner-approved hero walk layout: authored S, E, N; SE/NE = copy of E;
W/NW/SW = per-cell mirror of the E family. No flat (the dir_set is complete;
idle anim is the flat).

    python art_src/vargoth_walk_2026-08-30/install_vargoth_walk.py [--dry]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "art"))
from install_gait_walk import build_strip, tone_match, mirror_strip  # noqa: E402

SPRITES = ROOT / "game" / "assets" / "sprites"
JOB = Path(__file__).resolve().parent
ROWS = {"s": JOB / "walk_s_v2" / "vargoth_walk_s_row.png",
        "e": JOB / "walk_e" / "vargoth_walk_e_row.png",
        "n": JOB / "walk_n_v3" / "vargoth_walk_n_row.png"}
COPIES = {"se": "e", "ne": "e"}          # E-side diagonals ride the E strip
MIRRORS = {"w": "e", "nw": "e", "sw": "e"}  # W side = mirrored E strip


def sweep_orphans(strip: Image.Image) -> Image.Image:
    """Remove sliced-off sword-tip fragments: the gen rows let the flaming
    greatsword cross cell boundaries, so equal-width slicing orphans a
    flame-crowned blade tip into the neighbouring frame (E f1-f4, 2026-08-31).
    Rule: drop any connected component that is NOT the largest, is >=150px,
    and is >=30% flame/blade coloured (bright orange or white). Dark cape
    tatters and tiny flame licks are spared."""
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
        r, g, b = c[:, :, 0].astype(int), c[:, :, 1].astype(int), c[:, :, 2].astype(int)
        hot = ((r > 150) & (g > 70) & (b < 110)) | ((r > 200) & (g > 200) & (b > 200))
        for lab in range(1, count + 1):
            if lab == main or sizes[lab - 1] < 40:
                continue
            m = labels == lab
            xs = np.nonzero(m)[1]
            edge = xs.max() < 90 or xs.min() > cell - 90  # sits in a slice-edge zone
            big_hot = sizes[lab - 1] >= 100 and hot[m].mean() >= 0.40
            if edge or big_hot:
                c[:, :, 3] = np.where(m, 0, c[:, :, 3])
    return Image.fromarray(arr)


def old_geometry(d: str) -> tuple[int, int, int]:
    ref = Image.open(JOB / "old_backup" / f"vargoth_walk_codex_{d}.png")
    cell = ref.height
    a = np.array(ref.convert("RGBA"))[:, :, 3][:, :cell]
    ys = np.nonzero(a > 40)[0]
    return cell, int(ys.max() - ys.min() + 1), int(ys.max())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()

    strips: dict[str, Image.Image] = {}
    for d, row in ROWS.items():
        if not row.exists():
            print(f"MISSING row for {d}: {row}")
            return 1
        cell, body, feet = old_geometry(d)
        built = sweep_orphans(build_strip(row, cell, body, feet))
        strips[d] = tone_match(built, JOB / "old_backup" / f"vargoth_walk_codex_{d}.png")
        print(f"built {d}: cell {cell} body {body} feet {feet}")
    for dst, src in COPIES.items():
        strips[dst] = strips[src].copy()
        print(f"copied {dst} <- {src}")
    for dst, src in MIRRORS.items():
        strips[dst] = mirror_strip(strips[src], strips[src].height)
        print(f"mirrored {dst} <- {src}")

    for d, strip in strips.items():
        dest = SPRITES / f"vargoth_walk_codex_{d}.png"
        if args.dry:
            print(f"DRY would write {dest.name} {strip.size}")
        else:
            strip.save(dest)
            print(f"wrote {dest.relative_to(ROOT)} {strip.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
