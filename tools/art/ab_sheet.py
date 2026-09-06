#!/usr/bin/env python
"""A/B sheet: one strip's frames at a git ref against the same strip now, plus the
subject's idle for identity, as a single PNG an agent (or a person) can LOOK at.

The eyes-only defect classes -- a costume part that vanishes, a palette that
drifts, a limb sliced at the cell edge, a frame that is a different drawing --
have no geometric gate and never will (CLAUDE.md, DRIFT_AUDIT.md). What they need
is the outgoing art beside the incoming art at a readable size, which is exactly
what nobody builds by hand under time pressure. So: one command.

    python tools/art/ab_sheet.py <strip> [more strips ...] --base 7fd27a4 --out sheet.png

Each row: "<name> BASE" then "<name> NOW", cells left to right, the subject's idle
frame 0 pinned at the left of both rows for identity. Cells are drawn INSIDE a red
box that marks the cell bounds, so a body touching or crossing the boundary is
visible rather than inferred.
"""
from __future__ import annotations

import argparse
import io
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
CELL_PX = 150


def _at(ref: str, rel: str) -> Image.Image | None:
    if ref in ("", "HEAD~0", "WORKTREE"):
        p = ROOT / rel
        return Image.open(p).convert("RGBA") if p.exists() else None
    data = subprocess.run(["git", "show", f"{ref}:{rel}"], capture_output=True, cwd=ROOT).stdout
    if not data:
        return None
    try:
        return Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception:
        return None


def _idle(subject: str) -> Image.Image | None:
    for k in ("anim_codex", "anim"):
        p = SPR / f"{subject}_{k}.png"
        if p.exists():
            im = Image.open(p).convert("RGBA")
            c = im.height
            return im.crop((0, 0, c, c))
    return None


def _subject_of(stem: str) -> str:
    return re.sub(r"_(anim|walk|attack\d?|attackb|attackc|cast|dash|ult|ultidle|death|stab|throw|ability|"
                  r"bolt|lash|charge|slam|melee|beam|blade)(_codex)?(_(s|se|e|ne|n|nw|w|sw))?$", "", stem)


def row(im: Image.Image | None, label: str, idle: Image.Image | None, width_cells: int) -> Image.Image:
    pad, lab_w = 6, 190
    w = lab_w + (width_cells + 1) * (CELL_PX + pad)
    out = Image.new("RGBA", (w, CELL_PX + 20), (55, 65, 50, 255))
    d = ImageDraw.Draw(out)
    d.text((3, CELL_PX // 2), label, fill=(255, 255, 255, 255))
    x = lab_w
    if idle is not None:
        out.alpha_composite(idle.resize((CELL_PX, CELL_PX), Image.LANCZOS), (x, 18))
        d.text((x + 2, 3), "idle", fill=(190, 220, 190, 255))
        d.rectangle([x, 18, x + CELL_PX - 1, 17 + CELL_PX], outline=(90, 140, 90, 255))
    x += CELL_PX + pad
    if im is not None:
        c = im.height
        n = max(1, im.width // c) if c and im.width % c == 0 else 1
        for f in range(n):
            cell = im.crop((f * c, 0, (f + 1) * c, c)).resize((CELL_PX, CELL_PX), Image.LANCZOS)
            out.alpha_composite(cell, (x, 18))
            d.rectangle([x, 18, x + CELL_PX - 1, 17 + CELL_PX], outline=(210, 70, 70, 255))
            x += CELL_PX + pad
    else:
        d.text((x, CELL_PX // 2), "(absent at this ref)", fill=(230, 180, 180, 255))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("strips", nargs="+", help="sprite basenames, e.g. vargoth_walk_codex_e")
    ap.add_argument("--base", default="7fd27a4", help="git ref for the BASE row")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    rows: list[Image.Image] = []
    for stem in args.strips:
        rel = f"game/assets/sprites/{stem}.png"
        base, now = _at(args.base, rel), _at("WORKTREE", rel)
        idle = _idle(_subject_of(stem))
        cells = max((im.width // im.height if im and im.height and im.width % im.height == 0 else 1)
                    for im in (base, now) if im) if (base or now) else 1
        rows.append(row(base, f"{stem}\n{args.base[:7]}", idle, cells))
        rows.append(row(now, f"{stem}\nNOW", idle, cells))
        rows.append(Image.new("RGBA", (10, 8), (35, 42, 32, 255)))
    if not rows:
        print("nothing to draw")
        return 1
    w = max(r.width for r in rows)
    sheet = Image.new("RGBA", (w, sum(r.height + 3 for r in rows)), (55, 65, 50, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height + 3
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"wrote {args.out} ({sheet.width}x{sheet.height}, {len(args.strips)} strip(s) vs {args.base})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
