#!/usr/bin/env python
"""OLD-vs-NEW review sheet for gait-transfer walk ROWS, before install.

The vet step of the mob/boss walk lane (tools/art/gait_briefs.py ->
run_codex_batch -> THIS -> install_gait_row.py). For each generated row it
lays the OUTGOING strip's frames above the NEW row's figures at a shared
scale, feet on one line, so the two gaits can be compared pose for pose —
the knee-articulation / passing-frame / leg-alternation read that decides
whether a row installs (CLAUDE.md: judge on a sheet, and the eyes are the
only gate for this defect class).

    python tools/art/gait_row_sheet.py <out.png> <row.png> [row.png ...]
    python tools/art/gait_row_sheet.py <out.png> --all <stage_root>

Rows are the raw Codex masters on flat #00FF00 (keyed here for display only).
The old strip is resolved from the row's stage name: <base>_walk[_<dir>].png.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
CELL = 190


def key_green(im: Image.Image) -> Image.Image:
    a = np.array(im.convert("RGBA")).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    bg = (g >= 150) & (r <= 140) & (b <= 140) & (g > r + 50) & (g > b + 50)
    a[:, :, 3] = np.where(bg, 0, a[:, :, 3])
    return Image.fromarray(a.clip(0, 255).astype("uint8"), "RGBA")


def row_figures(path: Path) -> list[Image.Image]:
    """Split a generated row at its real gutters, cropped to a shared baseline."""
    im = key_green(Image.open(path))
    a = np.array(im)[:, :, 3] > 40
    cols = a.any(axis=0)
    runs, st = [], None
    for x, c in enumerate(cols):
        if c and st is None:
            st = x
        elif not c and st is not None:
            if x - st > 8:
                runs.append([st, x - 1])
            st = None
    if st is not None:
        runs.append([st, len(cols) - 1])
    merged: list[list[int]] = []
    for r in runs:
        if merged and r[0] - merged[-1][1] <= 4:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    ys = np.nonzero(a)[0]
    if not len(ys):
        return []
    top, bot = int(ys.min()), int(ys.max())
    return [im.crop((x0, top, x1 + 1, bot + 1)) for x0, x1 in merged]


def strip_frames(path: Path) -> list[Image.Image]:
    im = Image.open(path).convert("RGBA")
    c = im.height
    out = [im.crop((f * c, 0, (f + 1) * c, c)) for f in range(max(1, im.width // c))]
    # crop the family to one shared baseline so the feet line up with the row
    a = np.array(im)[:, :, 3] > 40
    ys = np.nonzero(a)[0]
    if len(ys):
        top, bot = int(ys.min()), int(ys.max())
        out = [f.crop((0, top, c, bot + 1)) for f in out]
    return out


def old_for(row: Path) -> Path | None:
    """<stage>/<base>_walk_<facing>_row.png -> the strip it replaces."""
    stem = row.stem[: -len("_row")] if row.stem.endswith("_row") else row.stem
    cand = [stem.replace("_flat", ""), stem]
    for c in cand:
        p = SPR / f"{c}.png"
        if p.exists():
            return p
    base = stem.split("_walk")[0]
    p = SPR / f"{base}_walk.png"
    return p if p.exists() else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("rows", nargs="*")
    ap.add_argument("--all", dest="stage_root")
    args = ap.parse_args()
    rows = [Path(r) for r in args.rows]
    if args.stage_root:
        rows += sorted(Path(args.stage_root).glob("*/*_row.png"))
    if not rows:
        print("no rows")
        return 1
    blocks = []
    for r in rows:
        old = old_for(r)
        blocks.append((r.stem[: -len("_row")], strip_frames(old) if old else [], row_figures(r)))
    w = max(max(len(o), len(n)) for _, o, n in blocks)
    sheet = Image.new("RGBA", (w * CELL + 190, len(blocks) * 2 * CELL + 20), (58, 66, 52, 255))
    d = ImageDraw.Draw(sheet)
    y = 10
    for name, oldf, newf in blocks:
        for label, frames in (("OLD", oldf), ("NEW", newf)):
            d.text((6, y + CELL // 2), f"{name}\n{label} {len(frames)}f", fill=(255, 255, 255, 255))
            for i, c in enumerate(frames):
                if c.width < 1 or c.height < 1:
                    continue
                s = min((CELL - 14) / c.width, (CELL - 14) / c.height)
                t = c.resize((max(1, int(c.width * s)), max(1, int(c.height * s))), Image.LANCZOS)
                sheet.paste(t, (190 + i * CELL + (CELL - t.width) // 2, y + (CELL - t.height)), t)
            d.line([(190, y + CELL - 1), (sheet.width, y + CELL - 1)], fill=(120, 130, 110, 255))
            y += CELL
    sheet.save(args.out)
    print("wrote", args.out, sheet.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
