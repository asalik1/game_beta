"""Codex/ImageGen FX contact sheet (chroma-keyed RGBA master, cols x rows grid)
-> one square-cell horizontal strip for `assets/sprites/fx/` (Sprite2D hframes).

Built 2026-08-15 for the poison-mist rework (cloud/splash/pool) and the impact
pass (meteor_impact / earth_slam). Differences from the character builders:
FX cells are RADIAL (no feet line), the generator drifts each cell a little,
and a one-shot burst throws stray droplets across the nominal gutter — so
cells are found per ROW by alpha column-bands assigned to the nearest nominal
column centre (stray debris joins its column), and every frame is re-centred
on its own alpha-bbox centre. Frames are normalised as a SET: the largest
frame's bbox max-dim maps to `--fill` of the cell so a growing burst keeps
its relative size across frames.

Usage:
  python build_fx_strip.py <keyed_master.png> <out_strip.png> --cols 4 --rows 2
      --cell 256 --fill 0.75 [--gamma 0.85] [--despill magenta|green] [--qa qa.png]

Prints per-frame bbox + the scale used. Refuses to write a strip with an empty
frame. Stage first (--out in scratch), LOOK, then install.
"""
import argparse
import sys

import numpy as np
from PIL import Image


def bands(mask):
    out, s = [], None
    for i, v in enumerate(mask):
        if v and s is None:
            s = i
        if not v and s is not None:
            out.append((s, i - 1))
            s = None
    if s is not None:
        out.append((s, len(mask) - 1))
    return out


def merge_bands(bs, gap):
    if not bs:
        return bs
    out = [list(bs[0])]
    for a, b in bs[1:]:
        if a - out[-1][1] <= gap:
            out[-1][1] = b
        else:
            out.append([a, b])
    return [tuple(x) for x in out]


def find_cells(alpha, cols, rows, thresh=10, gap=6):
    """Return [(x0,y0,x1,y1)] * (cols*rows) in reading order."""
    H, W = alpha.shape
    row_mask = (alpha > thresh).any(axis=1)
    rbands = merge_bands(bands(row_mask), 24)
    # Assign row bands to nearest nominal row centre, union per row.
    row_centres = [H / rows * (j + 0.5) for j in range(rows)]
    row_ext = [None] * rows
    for r0, r1 in rbands:
        c = (r0 + r1) / 2.0
        j = min(range(rows), key=lambda k: abs(row_centres[k] - c))
        if row_ext[j] is None:
            row_ext[j] = [r0, r1]
        else:
            row_ext[j][0] = min(row_ext[j][0], r0)
            row_ext[j][1] = max(row_ext[j][1], r1)
    cells = []
    col_centres = [W / cols * (i + 0.5) for i in range(cols)]
    for j in range(rows):
        if row_ext[j] is None:
            raise SystemExit("row %d has no content" % j)
        r0, r1 = row_ext[j]
        sub = alpha[r0:r1 + 1]
        cbands = merge_bands(bands((sub > thresh).any(axis=0)), gap)
        # A peak frame's sparks can bridge the gutter into its neighbour: split
        # any band that spans a nominal column boundary at the thinnest column
        # (least alpha) within ±win px of that boundary.
        win = int(W / cols * 0.22)
        col_sum = (sub > thresh).sum(axis=0)
        for i in range(1, cols):
            bx = int(W / cols * i)
            split = []
            for c0, c1 in cbands:
                if c0 < bx - win and c1 > bx + win:
                    lo, hi = max(c0, bx - win), min(c1, bx + win)
                    cut = lo + int(np.argmin(col_sum[lo:hi + 1]))
                    split.append((c0, cut))
                    split.append((cut + 1, c1))
                else:
                    split.append((c0, c1))
            cbands = split
        col_ext = [None] * cols
        for c0, c1 in cbands:
            c = (c0 + c1) / 2.0
            i = min(range(cols), key=lambda k: abs(col_centres[k] - c))
            if col_ext[i] is None:
                col_ext[i] = [c0, c1]
            else:
                col_ext[i][0] = min(col_ext[i][0], c0)
                col_ext[i][1] = max(col_ext[i][1], c1)
        for i in range(cols):
            if col_ext[i] is None:
                raise SystemExit("row %d col %d has no content" % (j, i))
            c0, c1 = col_ext[i]
            # tighten rows to this column's own vertical extent
            colsub = alpha[r0:r1 + 1, c0:c1 + 1]
            rmask = (colsub > thresh).any(axis=1)
            rb = bands(rmask)
            y0 = r0 + rb[0][0]
            y1 = r0 + rb[-1][1]
            cells.append((c0, y0, c1, y1))
    return cells


def despill(rgba, key):
    """Pull the key hue out of translucent edge pixels (soft matte residue)."""
    a = rgba[:, :, 3].astype(int)
    r = rgba[:, :, 0].astype(int)
    g = rgba[:, :, 1].astype(int)
    b = rgba[:, :, 2].astype(int)
    edge = (a > 0) & (a < 250)
    if key == "magenta":
        # magenta = R & B high vs G: clamp R,B down toward G on edge pixels
        m = edge & (((r + b) / 2) > g + 8)
        lim = np.maximum(g + 8, 0)
        rgba[:, :, 0] = np.where(m, np.minimum(r, lim), r).astype(np.uint8)
        rgba[:, :, 2] = np.where(m, np.minimum(b, lim), b).astype(np.uint8)
    elif key == "green":
        # A warm/earthy subject never has G above both R and B — any such pixel
        # (edge OR body haze) is key spill; clamp G down.
        # Semi-transparent dust/smoke over the key comes back yellow-green
        # (R≈G); pull G under R so it reads tan/brown again.
        # A yellow-green with LOW blue is the tell (a warm pale highlight keeps
        # its blue); remap it toward tan: G under 0.84 R, B up to 0.5 R.
        top = np.maximum(r, b)
        m = (a > 0) & (g > top * 0.86) & (b < top * 0.6)
        g_lim = (top * 0.84).astype(int)
        b_lim = (top * 0.5).astype(int)
        rgba[:, :, 1] = np.where(m, np.minimum(g, g_lim), g).astype(np.uint8)
        rgba[:, :, 2] = np.where(m, np.maximum(b, b_lim), b).astype(np.uint8)
    return rgba


def widest_row(alpha_cell, thresh=10):
    """Row index (within the cell) with the widest alpha extent — the equator of
    a ground-radial burst (shockwave ring / scorch ellipse), i.e. the impact
    centre for a top-down FX even when a plume rises far above it."""
    m = alpha_cell > thresh
    best, best_w, best_cx = 0, -1, alpha_cell.shape[1] / 2.0
    for y in range(m.shape[0]):
        xs = np.flatnonzero(m[y])
        if xs.size:
            w = xs[-1] - xs[0]
            if w > best_w:
                best_w, best, best_cx = w, y, (xs[-1] + xs[0]) / 2.0
    return best, best_cx


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("master")
    ap.add_argument("out")
    ap.add_argument("--cols", type=int, required=True)
    ap.add_argument("--rows", type=int, required=True)
    ap.add_argument("--cell", type=int, required=True)
    ap.add_argument("--fill", type=float, default=0.8,
                    help="largest frame's bbox max-dim as a fraction of the cell")
    ap.add_argument("--gamma", type=float, default=0.85,
                    help="RGB gamma pre-brighten for the Forward+ tonemap (1.0 = none)")
    ap.add_argument("--despill", choices=["magenta", "green", "none"], default="none")
    ap.add_argument("--min-alpha", type=int, default=6,
                    help="alpha at or below this is zeroed (kills key haze)")
    ap.add_argument("--valign", choices=["center", "bottom", "widest"], default="center",
                    help="center = radial bursts; bottom = ground-resting mounds/pools "
                         "(a wisp that grows off the top must not lift the body); "
                         "widest = anchor each frame's WIDEST row (the ground ring's "
                         "equator = impact centre) on one shared row — for ground "
                         "bursts with a rising plume (meteor, earth slam). Prints the "
                         "anchor row so the caller can offset the sprite onto it.")
    ap.add_argument("--normalize-size", action="store_true",
                    help="LOOPS whose subject must not change size (a shield dome, a pool): "
                         "resample every frame's bbox to the largest frame's bbox so the "
                         "silhouette's top and bottom stay put — the generator drifts each "
                         "cell a few percent, which reads as the dome breathing / dipping")
    ap.add_argument("--luma-key", action="store_true",
                    help="the master is an effect made of LIGHT on pure black (no chroma key): "
                         "alpha = max(R,G,B), colour un-premultiplied — the right key for a "
                         "glow/bloom the model refuses to paint on a flat colour")
    ap.add_argument("--qa", default="")
    args = ap.parse_args()

    im = Image.open(args.master).convert("RGBA")
    rgba = np.array(im)
    if args.luma_key:
        rgb = rgba[:, :, :3].astype(np.float32)
        a = rgb.max(axis=2)
        safe = np.maximum(a, 1.0)
        rgba[:, :, :3] = np.clip(rgb / safe[:, :, None] * 255.0, 0, 255).astype(np.uint8)
        rgba[:, :, 3] = a.astype(np.uint8)
    rgba[:, :, 3] = np.where(rgba[:, :, 3] <= args.min_alpha, 0, rgba[:, :, 3])
    if args.despill != "none":
        rgba = despill(rgba, args.despill)
    alpha = rgba[:, :, 3]
    cells = find_cells(alpha, args.cols, args.rows)
    biggest = max(max(x1 - x0 + 1, y1 - y0 + 1) for (x0, y0, x1, y1) in cells)
    scale = (args.cell * args.fill) / float(biggest)
    print("master %dx%d  cells %d  biggest bbox %dpx  scale %.4f" % (
        im.size[0], im.size[1], len(cells), biggest, scale))
    tallest = int(round(max(y1 - y0 + 1 for (_, y0, _, y1) in cells) * scale))
    if args.valign == "bottom":
        bottom_row = (args.cell - tallest) // 2 + tallest
        print("bottom row (ground contact) = %d of %d  -> sprite offset.y = %d puts it on the origin" % (
            bottom_row, args.cell, args.cell // 2 - bottom_row))
    anchor_row = args.cell // 2
    anchors = []
    if args.valign == "widest":
        # Per-frame equator (in master px, relative to the frame's bbox top);
        # the shared anchor row must leave room for the tallest above-part and
        # the deepest below-part — shrink the set if the cell can't hold both.
        for (x0, y0, x1, y1) in cells:
            anchors.append(widest_row(alpha[y0:y1 + 1, x0:x1 + 1]))
        above = max(a for a, _ in anchors) * scale
        below = max((y1 - y0) - a for (_, y0, _, y1), (a, _) in zip(cells, anchors)) * scale
        need = above + below + 2
        if need > args.cell:
            scale *= args.cell / need
            above *= args.cell / need
            below *= args.cell / need
            print("  (shrunk scale to %.4f so plume + ring both fit)" % scale)
        anchor_row = int(round((args.cell - (above + below)) / 2.0 + above))
        print("anchor row (impact centre) = %d of %d  -> sprite offset.y = %d" % (
            anchor_row, args.cell, args.cell // 2 - anchor_row))
    strip = Image.new("RGBA", (args.cell * len(cells), args.cell), (0, 0, 0, 0))
    max_w = max(x1 - x0 + 1 for (x0, _, x1, _) in cells)
    max_h = max(y1 - y0 + 1 for (_, y0, _, y1) in cells)
    if args.normalize_size:
        print("normalize-size: every frame resampled to the largest bbox %dx%d" % (max_w, max_h))
    for k, (x0, y0, x1, y1) in enumerate(cells):
        crop = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1])
        w, h = crop.size
        if args.normalize_size:
            w, h = max_w, max_h
        nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
        small = crop.resize((nw, nh), Image.LANCZOS)
        if np.array(small)[:, :, 3].max() == 0:
            raise SystemExit("frame %d is empty after resize — refusing to write" % k)
        ox = k * args.cell + (args.cell - nw) // 2
        if args.valign == "bottom":
            # every frame's lowest pixel sits on the row the tallest frame's would
            oy = (args.cell - tallest) // 2 + (tallest - nh)
        elif args.valign == "widest":
            ay, acx = anchors[k]
            oy = anchor_row - int(round(ay * scale))
            # centre the equator's own midpoint, not the bbox (a leaning plume
            # would otherwise drag the ring sideways)
            ox = k * args.cell + args.cell // 2 - int(round(acx * scale))
        else:
            oy = (args.cell - nh) // 2
        strip.alpha_composite(small, (max(ox, k * args.cell), max(oy, 0)))
        print("  frame %d bbox (%d,%d)-(%d,%d) %dx%d -> %dx%d" % (k + 1, x0, y0, x1, y1, w, h, nw, nh))
    if args.gamma != 1.0:
        arr = np.array(strip).astype(np.float32)
        arr[:, :, :3] = 255.0 * np.power(arr[:, :, :3] / 255.0, args.gamma)
        strip = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    strip.save(args.out)
    print("wrote", args.out, strip.size)
    if args.qa:
        # QA: strip over dark + mid-grey checker so haze/fringe shows
        n = len(cells)
        qa = Image.new("RGB", (args.cell * n, args.cell * 2), (40, 40, 40))
        grey = Image.new("RGB", (args.cell * n, args.cell), (110, 110, 110))
        qa.paste(grey, (0, args.cell))
        qa.paste(strip, (0, 0), strip)
        qa.paste(strip, (0, args.cell), strip)
        qa.save(args.qa)
        print("qa", args.qa)


if __name__ == "__main__":
    main()
