#!/usr/bin/env python
"""Despill the colourless WHITE/PALE keying halo (the 2026-08-26 defect class:
ImageGen regens paint a thin bright desaturated fringe out to the whole
silhouette — canopy AND trunk ring white over dark ground). IN PLACE, same
recipe as the snow/winter fix (fb604d2) and tree_green (b4b2b1c), which lived
only in a scratchpad until the autumn family shipped the same class (2026-08-28).

Two-pass, deterministic, no regen:
  1. OPAQUE ring (outermost 2px of the a>128 silhouette): pixels clearly
     brighter than the local interior get retoned to the Gaussian-blurred
     interior colour (alpha kept). Legit lit edges survive — their local
     interior is itself bright, so they never clear the +LUM_OVER margin.
  2. SEMI-ALPHA fringe (0<a<=128): fully recoloured to the interior colour
     (the fringe is where the white matte concentrates; recolouring keeps the
     soft antialiased edge in the sprite's own palette), then a<ALPHA_FLOOR
     crumbs are cut.

_anim strips are processed PER CELL (cell width = the static sibling's width,
else height-square) so every frame gets the same rule — frame==static contract.

  python tools/art/despill_pale_halo.py <sprite.png> [...]

Prints retoned/recoloured/cut pixel counts per file. Verify with
scan_key_rim.py --pale-halo + a grass composite; gate anims with
audit_prop_anims.py afterwards.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

LUM_OVER = 40      # opaque-ring px this much brighter than local interior = halo
LUM_MIN = 150      # ...and at least this bright in absolute terms
ALPHA_FLOOR = 60   # semi-alpha crumbs at/below this are cut entirely
BLUR = 5           # interior-reference blur radius (px)


def _erode(mask: np.ndarray, n: int) -> np.ndarray:
    im = Image.fromarray((mask * 255).astype("uint8"))
    return np.asarray(im.filter(ImageFilter.MinFilter(2 * n + 1))) > 128


def _blur(x: np.ndarray) -> np.ndarray:
    return np.asarray(Image.fromarray(np.clip(x, 0.0, 255.0).astype("uint8"))
                      .filter(ImageFilter.GaussianBlur(BLUR))).astype(float)


def _cell_width(path: str, im: Image.Image) -> int:
    base = os.path.basename(path)
    if base.endswith("_anim.png"):
        st = os.path.join(os.path.dirname(path), base[:-9] + ".png")
        if os.path.exists(st):
            sw, sh = Image.open(st).size
            if sh == im.height and im.width % sw == 0:
                return sw
    if im.width % im.height == 0 and im.width // im.height > 1:
        return im.height
    return im.width


def despill_cell(a: np.ndarray) -> tuple:
    """a: HxWx4 float array, edited in place. Returns (retoned, recoloured, cut)."""
    al = a[..., 3]
    lum = a[..., :3].mean(2)
    core = al > 128
    if int(core.sum()) < 400:
        return 0, 0, 0
    interior = _erode(core, 2)
    w = interior.astype(float)
    wb = _blur(w * 255) / 255
    valid = wb > 0.02
    ref_lum = _blur(lum * w) / np.maximum(wb, 1e-3)
    ref_rgb = np.stack([_blur(a[..., c] * w) / np.maximum(wb, 1e-3)
                        for c in range(3)], axis=-1)

    ring = core & ~interior
    halo = ring & valid & (lum > ref_lum + LUM_OVER) & (lum > LUM_MIN)
    a[..., :3][halo] = ref_rgb[halo]

    semi = (al > 0) & (al <= 128)
    recol = semi & valid
    a[..., :3][recol] = ref_rgb[recol]
    # semi-alpha with no interior nearby (detached matte wisps): bright = cut
    stray = semi & ~valid & (lum > LUM_MIN)
    a[..., 3][stray] = 0

    crumbs = (al > 0) & (al <= ALPHA_FLOOR)
    a[..., 3][crumbs] = 0
    return int(halo.sum()), int(recol.sum()), int(stray.sum() + crumbs.sum())


def despill(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(float)
    cw = _cell_width(path, im)
    tot = [0, 0, 0]
    for x0 in range(0, im.width, cw):
        cell = a[:, x0:x0 + cw].copy()
        r = despill_cell(cell)
        a[:, x0:x0 + cw] = cell
        tot = [t + v for t, v in zip(tot, r)]
    Image.fromarray(np.clip(a, 0, 255).astype("uint8"), "RGBA").save(path)
    print(f"  {os.path.basename(path)}: retoned {tot[0]}  fringe-recoloured {tot[1]}  cut {tot[2]}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        despill(p)
