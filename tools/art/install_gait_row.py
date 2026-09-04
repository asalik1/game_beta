#!/usr/bin/env python
"""Install a Codex gait ROW (N figures on flat #00ff00) as an engine walk strip
at the OUTGOING strip's geometry -- generic over heroes, mobs and bosses, and
frame-count agnostic (the row's N need not match the old strip's N; the
engine reads frames = width // height).

Generalizes install_gait_walk.py (heroes, 6 frames, measures walk_s) and the
Vargoth boss installer (art_src/vargoth_walk_2026-08-30/install_vargoth_walk.py)
into one tool for the 2026-09 mob/boss walk regen batch:

  1. key the green + despill the 2 px rim band (install_gait_walk.key_and_despill)
  2. slice the row: equal-width cells (default) or at REAL gutters (--gutters:
     the N-1 widest empty column bands; --frames N when a row is not obviously
     N figures)
  3. ONE scale for the whole row = old median body height / row median body
     height (never per frame -- per-frame scaling breathes)
  4. anchor each frame's x: torso band (upper 40 % of the body -- gait-donor
     gens bake canvas travel), whole-body centroid, or bbox centre (--anchor)
  5. pin each frame's lowest opaque row to the old strip's feet line
  6. sweep slice-edge orphans (a limb/blade tip cut off into the neighbour
     cell by equal-width slicing; --no-orphans to skip)
  7. tone-match to the outgoing strip (install_gait_walk.tone_match, the
     3-regime luma/chroma match; --no-tone to skip)
  8. write --out (+ per-cell mirrored --mirror-out, byte copies --copy-out);
     back the outgoing files up into --backup-dir first.

    python tools/art/install_gait_row.py --old game/assets/sprites/wolf_walk.png \
        --row art_src/mob_gait_2026-09-03/wolf/wolf_walk_row.png \
        --out game/assets/sprites/wolf_walk.png --backup-dir art_src/.../old_backup
    python tools/art/install_gait_row.py --old game/assets/sprites/korrag_walk_codex_e.png \
        --row .../korrag_walk_e_row.png --out .../korrag_walk_codex_e.png \
        --copy-out .../korrag_walk_codex_se.png --copy-out .../korrag_walk_codex_ne.png \
        --mirror-out .../korrag_walk_codex_w.png ... [--dry] [--report]

--flip mirrors the ROW before install (a gen that came back facing the wrong
way). --old may also be an idle strip when no walk exists yet (geometry =
cell / median body / feet of that strip). After install: --import, then
tools/art/verify_art.py <base>, ba_gifs / travel_gif review, gates.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from install_gait_walk import key_and_despill, tone_match, mirror_strip  # noqa: E402

A_SOLID = 40
WIDTH_FIT_FLOOR = 0.95   # never give up more than 5% of the body to fit the cell


def _bbox(alpha: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.nonzero(alpha > A_SOLID)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def old_geometry(old: Path) -> tuple[int, int, int]:
    """(cell, median body height, feet row) of the outgoing strip.

    Feet = frame 0's lowest opaque row -- the exact row enemy.gd's
    _strip_feet_y reads for idle<->walk alignment. Body = median over frames
    (one frame with a raised weapon must not set the target)."""
    im = Image.open(old).convert("RGBA")
    a = np.array(im)[:, :, 3]
    cell = im.height
    n = max(1, im.width // cell)
    bodies, feet0 = [], None
    for f in range(n):
        bb = _bbox(a[:, f * cell:(f + 1) * cell])
        if bb is None:
            continue
        bodies.append(bb[3] - bb[1] + 1)
        if feet0 is None:
            feet0 = bb[3]
    if not bodies:
        raise SystemExit(f"{old} has no opaque content")
    return cell, int(np.median(bodies)), int(feet0)


def slice_row(rgba: np.ndarray, frames: int | None, gutters: bool, gap: int = 4) -> list[np.ndarray]:
    a = rgba[:, :, 3] > A_SOLID
    cols = a.any(axis=0)
    if gutters:
        # figures = runs of content columns; merge runs separated by < 4 px
        runs, start = [], None
        for x, c in enumerate(cols):
            if c and start is None:
                start = x
            elif not c and start is not None:
                runs.append([start, x - 1]); start = None
        if start is not None:
            runs.append([start, len(cols) - 1])
        merged = []
        for r in runs:
            if merged and r[0] - merged[-1][1] <= gap:
                merged[-1][1] = r[1]
            else:
                merged.append(r)
        if frames and len(merged) != frames:
            # keep the N widest runs, drop specks
            merged = sorted(sorted(merged, key=lambda r: r[1] - r[0], reverse=True)[:frames])
        if not merged:
            raise SystemExit("row has no content")
        # cell boundaries = midpoints of the gaps
        bounds = [0]
        for i in range(len(merged) - 1):
            bounds.append((merged[i][1] + merged[i + 1][0]) // 2)
        bounds.append(rgba.shape[1])
        return [rgba[:, bounds[i]:bounds[i + 1]] for i in range(len(merged))]
    n = frames or _count_figures(cols)
    fw = rgba.shape[1] // n
    return [rgba[:, f * fw:(f + 1) * fw] for f in range(n)]


def _count_figures(cols: np.ndarray) -> int:
    runs, start = 0, None
    for x, c in enumerate(cols):
        if c and start is None:
            start = x
        elif not c and start is not None:
            if x - start > 8:
                runs += 1
            start = None
    if start is not None:
        runs += 1
    return max(1, runs)


def anchor_x(alpha: np.ndarray, mode: str) -> float:
    ys, xs = np.nonzero(alpha > A_SOLID)
    if len(ys) == 0:
        return alpha.shape[1] / 2.0
    if mode == "bbox":
        return (xs.min() + xs.max()) / 2.0
    if mode == "centroid":
        return float(xs.mean())
    top, bot = ys.min(), ys.max()
    band = ys <= top + int((bot - top) * 0.40)
    return float(xs[band].mean())


def sweep_orphans(cell_rgba: np.ndarray, edge_zone: int) -> np.ndarray:
    """Drop connected components that sit entirely inside a slice-edge zone and
    are not the largest component (sliced-off limb/blade tips from the
    neighbouring figure). Everything else -- detached FX, cloth tatters,
    projectiles the brief allowed -- is kept."""
    try:
        from scipy import ndimage
    except Exception:
        return cell_rgba
    a = cell_rgba[:, :, 3] > A_SOLID
    labels, count = ndimage.label(a)
    if count <= 1:
        return cell_rgba
    sizes = ndimage.sum(a, labels, range(1, count + 1))
    main = int(np.argmax(sizes)) + 1
    main_size = float(sizes[main - 1])
    w = a.shape[1]
    out = cell_rgba.copy()
    for lab in range(1, count + 1):
        if lab == main or sizes[lab - 1] < 12:
            continue
        m = labels == lab
        xs = np.nonzero(m)[1]
        # a sliced-off neighbour fragment: small (< 15 % of the body) and
        # touching a slice edge zone; a big detached part (a thrown weapon the
        # brief allowed, a long tail) is left alone
        small = sizes[lab - 1] < 0.15 * main_size
        at_edge = xs.min() < edge_zone or xs.max() > w - edge_zone
        if small and at_edge:
            out[:, :, 3] = np.where(m, 0, out[:, :, 3])
    return out


def build(row: Path, cell: int, body_target: int, feet_y: int, frames: int | None,
          gutters: bool, anchor: str, flip: bool, orphans: bool,
          report: bool, gap: int = 4) -> Image.Image:
    im = Image.open(row)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    rgba = key_and_despill(im)
    cells = slice_row(rgba, frames, gutters, gap)
    if orphans:
        zone = max(6, int(cells[0].shape[1] * 0.14))
        cells = [sweep_orphans(c, zone) for c in cells]
    bodies, reach = [], []
    for i, c in enumerate(cells):
        bb = _bbox(c[:, :, 3])
        if bb is None:
            raise SystemExit("a sliced cell is empty -- wrong --frames or gutters?")
        h = bb[3] - bb[1] + 1
        w = bb[2] - bb[0] + 1
        # A gutter split can hand back a SPECK as its own cell (a stray fleck
        # between two figures), which would ship as a near-empty frame that
        # blinks in game. Refuse rather than install it.
        if h < 0.35 * max(bodies or [h]):
            raise SystemExit(f"sliced cell {i} is a {w}x{h} speck, not a figure "
                             f"-- pass --frames N (or drop --gutters)")
        bodies.append(h)
        # How far the figure reaches from its ANCHOR (the point that lands on
        # the cell centre) -- not its bbox width. A hound's tail streams to one
        # side of the torso, so the bbox fits the cell while the tail still
        # runs off the edge once the torso is centred.
        ax = anchor_x(c[:, :, 3], anchor)
        reach.append(max(ax - bb[0], bb[2] - ax))
    S = body_target / float(np.median(bodies))
    need = 2.0 * max(reach) * S
    if need > cell - 10:
        # Give up at most WIDTH_FIT_FLOOR of the body to fit the cell. Shrinking
        # further would trade a clipped tail tip for a body that visibly pops
        # smaller the moment the creature moves (the enemy renderer normalises a
        # locomotion strip by its own cell) -- a worse defect than a cropped
        # tail, which the outgoing strips carried anyway.
        S *= max(WIDTH_FIT_FLOOR, (cell - 10) / need)
        if report:
            print(f"  width-fit: reach needs {need:.0f}px of a {cell}px cell, scale -> {S:.3f}")
    n = len(cells)
    out = Image.new("RGBA", (cell * n, cell), (0, 0, 0, 0))
    for f, c in enumerate(cells):
        img = Image.fromarray(c)
        sw, sh = max(1, int(round(c.shape[1] * S))), max(1, int(round(c.shape[0] * S)))
        img = img.resize((sw, sh), Image.LANCZOS)
        a = np.array(img)[:, :, 3]
        bb = _bbox(a)
        bottom = bb[3] if bb else sh - 1
        cx = anchor_x(a, anchor)
        px, py = int(round(f * cell + cell / 2 - cx)), feet_y - bottom
        out.alpha_composite(img, (px, py)) if px >= f * cell - sw and py > -sh else None
        if report:
            print(f"  f{f}: body {bodies[f]}->{int(bodies[f]*S)} px, feet {bottom}->{feet_y}, "
                  f"anchor x {cx:.1f} -> cell centre")
    # post-resize fringe despill (LANCZOS re-blends key green into the new edge)
    arr = np.array(out).astype(int)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    hot = (a > 0) & (a < 255) & (g > np.maximum(r, b))
    arr[:, :, 1] = np.where(hot, np.maximum(r, b), g)
    # clip anything that ran past the cell (a wide row figure at a small cell)
    strip = Image.fromarray(arr.clip(0, 255).astype(np.uint8))
    if report:
        print(f"  row frames {n}, scale {S:.3f}, cell {cell}, body target {body_target}, feet {feet_y}")
    return strip


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--old", required=True, help="outgoing strip (geometry + tone source)")
    ap.add_argument("--row", required=True, help="Codex row master on flat green")
    ap.add_argument("--out", action="append", default=[], help="strip destination(s)")
    ap.add_argument("--mirror-out", action="append", default=[], help="per-cell mirrored destination(s)")
    ap.add_argument("--copy-out", action="append", default=[], help="byte-copy destination(s)")
    ap.add_argument("--frames", type=int, default=None)
    ap.add_argument("--gutters", action="store_true", help="slice at real gutters, not equal width")
    ap.add_argument("--gutter-gap", type=int, default=4, help="content runs closer than this merge into one figure (a shield held off the body)")
    ap.add_argument("--anchor", choices=["torso", "centroid", "bbox"], default="torso")
    ap.add_argument("--flip", action="store_true", help="mirror the row before install")
    ap.add_argument("--no-tone", action="store_true")
    ap.add_argument("--no-orphans", action="store_true")
    ap.add_argument("--backup-dir", default=None)
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()

    old = Path(args.old)
    cell, body, feet = old_geometry(old)
    print(f"old {old.name}: cell {cell} body {body} feet {feet}")
    strip = build(Path(args.row), cell, body, feet, args.frames, args.gutters, args.anchor,
                  args.flip, not args.no_orphans, args.report, args.gutter_gap)
    if not args.no_tone:
        strip = tone_match(strip, old)
    mirrored = mirror_strip(strip, cell)
    outs = [(Path(p), strip) for p in args.out] + [(Path(p), mirrored) for p in args.mirror_out] \
        + [(Path(p), strip) for p in args.copy_out]
    if not outs:
        outs = [(old, strip)]
    for dest, img in outs:
        if args.dry:
            print(f"DRY would write {dest} {img.size}")
            continue
        if args.backup_dir and dest.exists():
            bd = Path(args.backup_dir)
            bd.mkdir(parents=True, exist_ok=True)
            if not (bd / dest.name).exists():
                shutil.copy2(dest, bd / dest.name)
        tmp = dest.with_name(f".{dest.stem}.tmp{dest.suffix}")
        img.save(tmp)
        tmp.replace(dest)
        print(f"wrote {dest} {img.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
