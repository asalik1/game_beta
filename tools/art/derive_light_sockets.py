#!/usr/bin/env python
"""Derive `"lights"` sockets for a STRUCTURE def from its own art.

A structure that carries `"fire": true` crackles and its flame pixels bloom,
but unless the def also lists `lights` it casts NOTHING on the floor — the
Crownfall review frames are fire bowls burning over dead stone. `torch_pillar`
shows the pattern (terrains.gd): a `PointLight2D` + a `_floor_glow` pool per
socket, offsets in UNSCALED def px on the StaticBody2D.

This finds the flame cores in the sprite itself and converts them, so the
numbers stay correct across a repaint (re-run it after the art changes):

  * flame core = bright, strongly warm pixels (R high, R-B wide), clustered
    with a coarse grid label so one bowl = one socket;
  * clusters under --min-px are dropped (embers, warm trim, a lit window);
  * source (sx, sy) -> def space with `_add_structure`'s own placement:
    the sprite is width-normalised to def `w` and positioned at
    `-bh/2 + 12`, so x = (sx - w/2)/w * bw and y = -bh + 12 + sy/h * bh;
  * the socket is raised to the cluster's UPPER third (a flame lights from
    its body, not its base — matches torch_pillar's authored -62, which maps
    to the top of its flame, not the centre).

    python tools/art/derive_light_sockets.py capital_ashfire_forge [...]
    python tools/art/derive_light_sockets.py --all-capital

Prints GDScript-ready `"lights": [...]` lines to paste into terrains.gd. Eyeball
the result in a rig at 1x before shipping (owner rule: judge glows in-game).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
TERRAINS = ROOT / "game" / "scripts" / "terrains.gd"

# Structures whose light is NOT fire: the gate plasmas. Value = the Color()
# literal to emit (a story gate pools pale blue on the flagstones, a rift violet).
COOL_LIGHTS = {
    "capital_portal_story": "Color(0.45, 0.75, 1.0, 0.9)",
    "capital_portal_depths": "Color(0.62, 0.42, 1.0, 0.85)",
    "capital_wellspring": "Color(0.55, 0.85, 1.0, 0.85)",
}


def struct_defs() -> dict[str, dict]:
    """name -> {sprite, w} parsed out of Terrains.STRUCTURES."""
    src = TERRAINS.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'"([a-z0-9_]+)":\s*\{"sprite":\s*"([a-z0-9_]+)",\s*"w":\s*([0-9.]+)', src):
        out[m.group(1)] = {"sprite": m.group(2), "w": float(m.group(3))}
    return out


def flame_clusters(img: Image.Image, min_px: int, grid: int = 24, cool: bool = False):
    a = np.asarray(img.convert("RGBA")).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    if cool:
        # portal plasma: bright cyan/blue, blue clearly over red
        core = (al > 60) & (b > 190) & (b - r > 70) & (g > 120)
    else:
        # An orange FLAME, not gold trim: gold sits high in GREEN (~190) and
        # keeps blue up around 90-120, so the g<175 / b<115 pair rejects every
        # crown finial and roof crest while keeping fire (255,150,50).
        core = (al > 60) & (r > 210) & (g > 85) & (g < 175) & (b < 115) & (r - b > 130)
    if not core.any():
        return []
    ys, xs = np.nonzero(core)
    # coarse grid clustering: flame bowls on one building are far apart
    keys = {}
    for x, y in zip(xs, ys):
        keys.setdefault((x // grid, y // grid), []).append((x, y))
    # merge neighbouring grid cells
    cells = sorted(keys)
    parent = {c: c for c in cells}

    def find(c):
        while parent[c] != c:
            parent[c] = parent[parent[c]]
            c = parent[c]
        return c

    for (cx, cy) in cells:
        for d in ((1, 0), (0, 1), (1, 1), (1, -1)):
            n = (cx + d[0], cy + d[1])
            if n in parent:
                a_, b_ = find((cx, cy)), find(n)
                if a_ != b_:
                    parent[a_] = b_
    groups: dict = {}
    for c in cells:
        groups.setdefault(find(c), []).extend(keys[c])
    out = []
    for pts in groups.values():
        if len(pts) < min_px:
            continue
        px = np.array(pts)
        out.append((float(px[:, 0].mean()), float(px[:, 1].min()),
                    float(px[:, 1].max()), len(pts)))
    out.sort(key=lambda t: -t[3])
    return out


def sockets_for(name: str, defs: dict, min_px: int) -> str | None:
    d = defs.get(name)
    if not d:
        return f"# {name}: not in Terrains.STRUCTURES"
    p = SPR / f"{d['sprite']}.png"
    if not p.exists():
        return f"# {name}: no sprite {p.name}"
    img = Image.open(p)
    sw, sh = img.size
    bw = d["w"]
    bh = bw * sh / sw
    cool = name in COOL_LIGHTS
    cl = flame_clusters(img, min_px, cool=cool)
    if not cl:
        return f"# {name}: no flame core found (min_px {min_px})"
    parts = []
    for cx, y0, y1, n in cl[:4]:
        # light the flame body, not its base: a third down from the top
        sy = y0 + (y1 - y0) * 0.18
        x = (cx - sw / 2.0) / sw * bw
        y = -bh + 12.0 + sy / sh * bh
        scale = round(min(1.15, max(0.45, (bw / sw) * (y1 - y0) / 26.0)), 2)
        energy = round(min(1.0, max(0.55, n / 900.0)), 2)
        col = COOL_LIGHTS.get(name, "Color(1.0, 0.64, 0.3, 0.9)") if cool else "Color(1.0, 0.64, 0.3, 0.9)"
        parts.append(f'{{"off": Vector2({x:.0f}, {y:.0f}), '
                     f'"color": {col}, '
                     f'"energy": {energy}, "scale": {scale}}}')
    return f'\t\t"lights": [{", ".join(parts)}],   # {name}: {len(cl)} flame core(s)'


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--all-capital", action="store_true")
    ap.add_argument("--min-px", type=int, default=140)
    args = ap.parse_args()
    defs = struct_defs()
    names = args.names
    if args.all_capital:
        names = [n for n in defs if n.startswith("capital_")] + ["great_hearth"]
    for n in sorted(names):
        print(sockets_for(n, defs, args.min_px))
    return 0


if __name__ == "__main__":
    sys.exit(main())
