#!/usr/bin/env python
"""Normalize sexton_surface.png so the Sexton emerges at IDLE body scale.

Bug (owner 2026-08-18): "when sexton appears from underground his size
changes -- he turns way larger for a brief moment." The surface strip draws
his risen body at ~1.7-1.85x the idle body (torso width 490-510 vs idle 291),
and enemy.gd::_apply_strip scales an action strip by CELL height (ref = idle
cell), not body size -- so the oversized drawing renders ~2x for that beat.

Frames 1-3 are internally consistent (~1.7x idle); frame 0 is just the head
breaking the surface. So a single uniform downscale that lands the standing
pose on idle scale fixes every frame while preserving the head-first rise and
the raised-scythe flourish. All frames are then aligned to one ground row so
the emerge reads as rising in place (no vertical pop; the engine still
feet-anchors frame 0).

Reads the installed strip, backs it up to art_src/fixes/, writes the fixed
strip to the staging dir given (default: scratchpad). Install + --import +
test happen separately (do NOT run a Godot suite beside a Codex batch).

  python tools/art/fix_sexton_surface.py [out_dir]
"""
import os
import sys
import tempfile
import numpy as np
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPR = os.path.join(REPO, "game", "assets", "sprites")
SRC = os.path.join(SPR, "sexton_surface.png")
IDLE = os.path.join(SPR, "sexton_anim_codex.png")
BACKUP = os.path.join(REPO, "art_src", "fixes", "sexton_surface_orig.png")


def frames(path):
    im = Image.open(path).convert("RGBA")
    h = im.height
    n = im.width // h
    return [im.crop((i * h, 0, (i + 1) * h, h)) for i in range(n)], h


def torso_width(im):
    """Median opaque width across the torso band (40-75% down the body) -- a
    scale measure robust to the raised scythe/arms and the wide hat brim."""
    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 16)
    if len(ys) == 0:
        return 0.0
    top, bot = ys.min(), ys.max()
    bh = bot - top + 1
    band = a[top + int(bh * 0.40):top + int(bh * 0.75)]
    ws = [(row > 16).sum() for row in band if (row > 16).sum() > 0]
    return float(np.median(ws)) if ws else 0.0


def content_bottom(im):
    a = np.array(im)[:, :, 3]
    ys, _ = np.where(a > 16)
    return int(ys.max()) if len(ys) else im.height - 1


def main():
    # Default staging dir: a portable OS-temp folder (the old hard-coded path
    # was one session's ephemeral Claude scratchpad UUID — dead on any other
    # machine or run). Pass an explicit out_dir to override (CR-011).
    out_dir = sys.argv[1] if len(sys.argv) > 1 else \
        os.path.join(tempfile.gettempdir(), "crownless_staging")
    os.makedirs(out_dir, exist_ok=True)
    surf, cell = frames(SRC)
    idle, _ = frames(IDLE)
    idle_tw = torso_width(idle[0])
    # Uniform factor: land the STANDING pose (last frame) on idle torso width.
    factor = idle_tw / torso_width(surf[-1])
    # Common ground row = the lowest original content bottom, so nothing clips.
    ground = max(content_bottom(im) for im in surf)
    out = Image.new("RGBA", (cell * len(surf), cell), (0, 0, 0, 0))
    for i, im in enumerate(surf):
        nw = max(1, int(round(im.width * factor)))
        nh = max(1, int(round(im.height * factor)))
        r = im.resize((nw, nh), Image.LANCZOS)
        # place bottom-center, content-bottom -> common ground row
        cb = int(round(content_bottom(im) * factor))
        ox = (cell - nw) // 2
        oy = ground - cb
        cellimg = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        cellimg.alpha_composite(r, (ox, oy))
        out.paste(cellimg, (i * cell, 0))
    os.makedirs(os.path.dirname(BACKUP), exist_ok=True)
    if not os.path.exists(BACKUP):
        Image.open(SRC).convert("RGBA").save(BACKUP)
    os.makedirs(out_dir, exist_ok=True)
    dst = os.path.join(out_dir, "sexton_surface.png")
    out.save(dst)
    print("idle torso=%.0f  factor=%.3f  ground_row=%d  cell=%d" % (
        idle_tw, factor, ground, cell))
    print("backup:", BACKUP if os.path.exists(BACKUP) else "(exists, kept)")
    print("wrote :", dst)


if __name__ == "__main__":
    main()
