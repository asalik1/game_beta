#!/usr/bin/env python3
"""Assemble boss per-frame remasters into runtime strips.

Geometry contract: each remastered frame is re-seated to reproduce the SOURCE
strip's per-frame alpha-box geometry scaled by k = new_cell / old_cell —
uniform scale from the source box HEIGHT (no aspect distortion), anchored at
the source box's bottom-center. The original animation's motion, feet line and
body fraction survive exactly; only the pixel density changes.

usage: python boss_install.py <boss> <clip> <source_strip_base> [--cell N]
       (assembles boss_stages/<boss>_<clip>_f1..f4 -> boss_staged/<target>.png)
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
SPR = REPO / "game" / "assets" / "sprites"
HERE = Path(__file__).parent
STAGES = HERE / "boss_stages"
OUT = HERE / "boss_staged"

def alpha_box(im, t=24):
    a = np.asarray(im.convert("RGBA"))[..., 3]
    ys, xs = np.nonzero(a > t)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)

def hard_edge(im, t=8):
    rgba = np.asarray(im.convert("RGBA")).copy()
    rgba[..., 3] = np.where(rgba[..., 3] < t, 0, rgba[..., 3])
    return Image.fromarray(rgba, "RGBA")


def auto_key(im):
    """A master that came back OPAQUE has a baked background (white or
    checkerboard fake-transparency — the documented image_gen misfire).
    Border-connected flood over near-background tones -> real alpha."""
    a = np.asarray(im.convert("RGBA"))
    if (a[..., 3] < 250).mean() > 0.02:      # already has real transparency
        return im
    h, w = a.shape[:2]
    rgb = a[..., :3].astype(int)
    corners = [rgb[2, 2], rgb[2, w - 3], rgb[h - 3, 2], rgb[h - 3, w - 3],
               rgb[2, w // 2], rgb[h - 3, w // 2]]
    tones = []
    for s in corners:
        if not any(np.abs(s - t).sum() < 30 for t in tones):
            tones.append(s)
    bg = np.zeros((h, w), bool)
    for t in tones:
        bg |= (np.abs(rgb - t).sum(2) < 46)
    from collections import deque
    seen = np.zeros((h, w), bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg[y, x] and not seen[y, x]:
                seen[y, x] = True; dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bg[y, x] and not seen[y, x]:
                seen[y, x] = True; dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and bg[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; dq.append((ny, nx))
    out = a.copy()
    out[..., 3] = np.where(seen, 0, out[..., 3])
    # 1px erode kills the keyed fringe
    al = out[..., 3]
    er = np.minimum.reduce([np.roll(al, s, ax) for s in (-1, 1) for ax in (0, 1)] + [al])
    out[..., 3] = er
    return Image.fromarray(out, "RGBA")

def assemble(boss: str, clip: str, source_base: str, cell: int = 1024) -> str:
    src = Image.open(SPR / f"{source_base}.png").convert("RGBA")
    oc = src.height
    n = src.width // oc
    k = cell / oc
    strip = Image.new("RGBA", (cell * n, cell))
    for i in range(n):
        mp = STAGES / f"{boss}_{clip}_f{i + 1}" / f"{boss}_{clip}_f{i + 1}_master.png"
        if not mp.exists():
            return f"PENDING f{i + 1}"
        sb = alpha_box(src.crop((i * oc, 0, (i + 1) * oc, oc)))
        master = hard_edge(auto_key(Image.open(mp).convert("RGBA")))
        mb = alpha_box(master)
        subj = master.crop(mb)
        s = (sb[3] - sb[1]) * k / subj.height          # uniform: source box height * k
        subj = subj.resize((max(1, round(subj.width * s)),
                            max(1, round(subj.height * s))), Image.Resampling.LANCZOS)
        cx = (sb[0] + sb[2]) / 2.0 * k                  # source bottom-center, scaled
        by = sb[3] * k
        x = i * cell + round(cx - subj.width / 2)
        y = round(by - subj.height)
        x = max(i * cell, min(x, (i + 1) * cell - subj.width))
        y = max(0, min(y, cell - subj.height))
        strip.alpha_composite(subj, (x, y))
    OUT.mkdir(exist_ok=True)
    strip.save(OUT / f"{source_base}.png")
    return f"OK {cell}x{n}"

if __name__ == "__main__":
    boss, clip, base = sys.argv[1:4]
    cell = int(sys.argv[sys.argv.index("--cell") + 1]) if "--cell" in sys.argv else 1024
    print(assemble(boss, clip, base, cell))
