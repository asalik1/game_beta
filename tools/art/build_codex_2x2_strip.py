#!/usr/bin/env python
"""Codex/ImageGen 2x2 animation master -> one square-cell horizontal strip.

The wave-1 Codex bosses (Fangmaw / Cinderhide / Morwen, 2026-08-14) were
generated as 2x2 contact sheets (reading order TL, TR, BL, BR) and quadrant-
sliced into 4-frame strips. A quadrant slice inherits whatever offset the
model gave each COLUMN, so frames 1/3 and 2/4 land at two different x
positions and the figure slides side to side every loop (Morwen: 18-29px on
a 627px cell). This builder is the deterministic replacement for that slice:

  1. split the keyed RGBA master into its four quadrants and PROVE the two
     seams are real gutters (zero opaque pixels across a broad band) so no
     figure is cut — the pipeline's hard gate (IMAGEGEN_SPRITE_PIPELINE §8.2);
  2. optionally normalize the clip's BODY SCALE to a reference idle strip
     from ONE frame (frame 1 by default), never per frame, so authored
     motion is kept and the clip plays at the idle body size (the engine
     scales an oversized ability cell off the idle reference cell, so a body
     drawn 5% taller would render 5% taller mid-cast);
  3. re-anchor every frame in a fresh square cell: x on the HEAD band (halo +
     hood — the stable landmark on a hovering caster whose hem sweeps and
     whose spell widens the bottom rows; --anchor feet for grounded bodies),
     y on the frame's lowest opaque row at the reference idle's baseline, so
     the engine's frame-0 feet line lands on the idle body unchanged;
  4. keep the reference cell size unless a centred figure would clip, in which
     case the cell grows (still square; the engine's oversized-cell path
     handles it) and the growth is reported.

Prints per-frame anchor offsets / body heights / gutter widths and writes an
optional QA sheet (strip + onion-skin overlay). Nothing is written to
game/assets unless --out points there — stage first, look, then install.

Usage:
  python tools/art/build_codex_2x2_strip.py <master_keyed.png> --out <strip.png>
      --ref-idle game/assets/sprites/<base>_anim_codex.png
      [--anchor head|feet] [--no-scale] [--scale-frame 1] [--qa <sheet.png>]
      [--key]   # master is a raw #00ff00 chroma sheet: key it here first
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

ALPHA_THR = 25          # opaque-ness for bboxes / gutters
BODY_THR = 76           # stricter alpha for body-height measurement (ignores mist haze)
# Top fraction of the figure's opaque rows used as the head anchor band. Kept
# to the halo + hood CROWN on purpose: at 0.22 the band reached chin level and
# Morwen's release burst (chest height, cast to the left) intruded into it,
# dragging frame 3's anchor ~100px toward the spell and pushing her body the
# other way — the very slide this builder exists to remove. Raised hands and
# spells never climb into the top tenth of the silhouette.
HEAD_FRAC = 0.10
FEET_FRAC = 0.25
MIN_GUTTER = 8          # columns/rows of zero occupancy demanded at each seam
SCALE_TOL = 0.03        # body-height deviation tolerated before rescaling


def key_chroma(im: Image.Image, key=(0, 255, 0), tol: int = 70) -> Image.Image:
    """Fallback keyer for a RAW master: hard-key pixels near the chroma color,
    despill the survivors' green channel toward max(r, b). Codex's own
    remove_chroma_key.py (soft matte + despill) is preferred when it ran."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    kr, kg, kb = key
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if abs(r - kr) + abs(g - kg) + abs(b - kb) <= tol:
                px[x, y] = (0, 0, 0, 0)
            elif g > max(r, b) + 24 and g > 90:
                px[x, y] = (r, max(r, b), b, a)
    return im


def alpha_mask(im: Image.Image, thr: int) -> Image.Image:
    return im.getchannel("A").point(lambda v: 255 if v > thr else 0)


# --fx-exclude green: Morwen's blight FX is olive/moss (g > r and g > b) while
# she herself is blue-grey robes, pale skin (r >= g) and a white-cyan halo
# (b >= g), so greenish pixels can be dropped from the FIGURE measurements
# (anchor, body height) without touching her. Cell sizing / gutters / pixel
# accounting still use the full alpha mask, so FX is never cropped away.
FX_EXCLUDE: str | None = None
MIN_COMPONENT = 500     # px: figure-mask blobs smaller than this are FX (motes,
                        # detached wisps), never the halo ring/hood/body — dropped
                        # from the ANCHOR measurement only (post-scale frames)
                        # when --fx-exclude is on. Body height / hem for scale and
                        # baseline stay on the plain mask: a wind-up frame has no
                        # FX above the halo, and a thin halo can fragment below
                        # any area threshold at source scale.


def _drop_small_components(m: Image.Image, min_area: int) -> Image.Image:
    """Zero every 4-connected blob below min_area. Measurement-only helper."""
    w, h = m.size
    data = bytearray(m.tobytes())
    seen = bytearray(w * h)
    for start in range(w * h):
        if not data[start] or seen[start]:
            continue
        stack = [start]
        seen[start] = 1
        comp = []
        while stack:
            p = stack.pop()
            comp.append(p)
            x, y = p % w, p // w
            for q in ((p - 1) if x > 0 else -1, (p + 1) if x + 1 < w else -1,
                      (p - w) if y > 0 else -1, (p + w) if y + 1 < h else -1):
                if q >= 0 and data[q] and not seen[q]:
                    seen[q] = 1
                    stack.append(q)
        if len(comp) < min_area:
            for p in comp:
                data[p] = 0
    return Image.frombytes("L", (w, h), bytes(data))


HALO_TEMPLATE = None    # set by --anchor halo: (np.ndarray mask, ref_center_x_in_template)


def halo_anchor_x(cell: Image.Image) -> float | None:
    """Template-match the reference idle's crown band (Morwen's halo, cut from
    frame 0 of --ref-idle) against this frame's alpha mask over the upper
    half, and return the x of the halo centre. Shape-based, so raised hands,
    motes above the head, a thin fragmented ring or a mist hem cannot skew
    it the way band/centroid anchors do. Frames are already scale-normalized
    to the idle when this runs, so one template fits every clip."""
    import numpy as np
    if HALO_TEMPLATE is None:
        return None
    tmpl, tcx = HALO_TEMPLATE
    th, tw = tmpl.shape
    a = np.asarray(alpha_mask(cell, BODY_THR), dtype=np.float32) / 255.0
    h, w = a.shape
    if h < th or w < tw:
        return None
    ys = a.any(axis=1).nonzero()[0]
    if ys.size == 0:
        return None
    # search band: from the figure's top down to ~45% of its height
    y0 = int(ys[0])
    y1 = min(h - th, y0 + int((ys[-1] - ys[0]) * 0.45))
    best = (-1.0, 0, 0)
    tsum = float(tmpl.sum())
    # coarse-to-fine: stride 4, then refine +-4 at stride 1
    for stride, cx0, cy0, rad in ((4, None, None, None), (1, None, None, 4)):
        if stride == 4:
            xr = range(0, w - tw + 1, 4)
            yr = range(y0, y1 + 1, 4)
        else:
            _, bx, by = best
            xr = range(max(0, bx - rad), min(w - tw, bx + rad) + 1)
            yr = range(max(0, by - rad), min(h - th, by + rad) + 1)
        for y in yr:
            for x in xr:
                win = a[y:y + th, x:x + tw]
                inter = float((win * tmpl).sum())
                # IoU-like score: overlap over union, penalizes solid blobs
                score = inter / (tsum + float(win.sum()) - inter + 1e-6)
                if score > best[0]:
                    best = (score, x, y)
    score, bx, _by = best
    if score < 0.25:
        return None
    return bx + tcx


def figure_mask(im: Image.Image, thr: int) -> Image.Image:
    m = alpha_mask(im, thr)
    if FX_EXCLUDE != "green":
        return m
    px = im.load()
    mp = m.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if mp[x, y]:
                r, g, b, _a = px[x, y]
                # olive/moss motes sit at g ~= r (e.g. 80,80,32) — allow a
                # small r lead; skin/hair are r >> g, robes/halo are b >= g.
                if g >= r - 8 and g > b + 8:
                    mp[x, y] = 0
    # A mote's neutral dark outline survives the colour test; motes are small
    # isolated blobs, the halo/hood/body are one large one.
    return _drop_small_components(m, MIN_COMPONENT)


def gutter_ok(mask: Image.Image, axis: str, seam: int, band: int) -> tuple[bool, int]:
    """Is there a >= band-wide run of empty columns (axis='x') / rows ('y')
    containing `seam`? Returns (ok, measured empty run around the seam)."""
    w, h = mask.size
    data = mask.load()
    def empty(i: int) -> bool:
        if axis == "x":
            return all(data[i, y] == 0 for y in range(h))
        return all(data[x, i] == 0 for x in range(w))
    limit = w if axis == "x" else h
    if not empty(seam):
        return False, 0
    lo = seam
    while lo - 1 >= 0 and empty(lo - 1):
        lo -= 1
    hi = seam
    while hi + 1 < limit and empty(hi + 1):
        hi += 1
    run = hi - lo + 1
    return run >= band, run


def head_anchor_x(cell: Image.Image) -> float | None:
    a = figure_mask(cell, ALPHA_THR)
    bbox = a.getbbox()
    if bbox is None:
        return None
    bottom = bbox[1] + max(1, round((bbox[3] - bbox[1]) * HEAD_FRAC))
    band = a.crop((0, bbox[1], cell.width, bottom)).getbbox()
    return None if band is None else (band[0] + band[2]) / 2.0


def feet_anchor_x(cell: Image.Image) -> float | None:
    a = figure_mask(cell, ALPHA_THR)
    bbox = a.getbbox()
    if bbox is None:
        return None
    top = bbox[3] - max(1, round((bbox[3] - bbox[1]) * FEET_FRAC))
    band = a.crop((0, top, cell.width, bbox[3]))
    data = band.load()
    sx = n = 0
    for y in range(band.height):
        for x in range(band.width):
            if data[x, y]:
                sx += x
                n += 1
    return sx / n if n else None


FACING_LEFT = True   # --facing: which side the REAR of a quadruped is on


def hindfeet_anchor_x(cell: Image.Image) -> float | None:
    """Centroid x of the feet band restricted to its REAR 40% (a left-facing
    beast's hind paws are on the right). The hind paws are what stays planted
    while the front of a quadruped rears (slam), lifts (howl) or reaches
    (charge stride); the whole-band centroid would drag the body toward the
    moving forepaws."""
    a = figure_mask(cell, ALPHA_THR)
    bbox = a.getbbox()
    if bbox is None:
        return None
    top = bbox[3] - max(1, round((bbox[3] - bbox[1]) * FEET_FRAC))
    band = a.crop((0, top, cell.width, bbox[3]))
    bb = band.getbbox()
    if bb is None:
        return None
    span = bb[2] - bb[0]
    if FACING_LEFT:
        x0, x1 = bb[2] - max(1, round(span * 0.40)), bb[2]
    else:
        x0, x1 = bb[0], bb[0] + max(1, round(span * 0.40))
    data = band.load()
    sx = n = 0
    for y in range(band.height):
        for x in range(x0, x1):
            if data[x, y]:
                sx += x
                n += 1
    return sx / n if n else None


def bbox_anchor_x(cell: Image.Image) -> float | None:
    """Mid x of the figure's bbox (FX excluded when --fx-exclude). The body-
    mass anchor for clips where EVERY leg moves (pounce, charge stride): a
    paw anchor there yanks the body backward as the paws tuck under it, and
    the clip rides a position tween/dash where frame-to-frame jerk shows."""
    bb = figure_mask(cell, ALPHA_THR).getbbox()
    return None if bb is None else (bb[0] + bb[2]) / 2.0


def body_box(cell: Image.Image) -> tuple[int, int, int, int] | None:
    return alpha_mask(cell, BODY_THR).getbbox()


def crown_box(cell: Image.Image) -> tuple[int, int, int, int] | None:
    """Bbox of the top HEAD_FRAC of the figure's opaque rows (Morwen: her halo).
    A stable size/position landmark for clips whose hem is mist."""
    a = alpha_mask(cell, BODY_THR)
    bbox = a.getbbox()
    if bbox is None:
        return None
    bottom = bbox[1] + max(1, round((bbox[3] - bbox[1]) * HEAD_FRAC))
    band = a.crop((0, bbox[1], cell.width, bottom)).getbbox()
    return None if band is None else (band[0], bbox[1] + band[1], band[2], bbox[1] + band[3])


def find_gutter(mask: Image.Image, axis: str, band: int) -> tuple[int, int] | None:
    """The real seam: the WIDEST zero-occupancy run of columns (axis='x') or
    rows ('y') that intersects the middle third of the sheet. Generated grids
    are not exact quadrants — Morwen's rain motes spilled 2px over the midline,
    while the true empty band between the top row's hems and those motes was
    ~70 rows wide. Returns (seam_index, run_width) or None if no run >= band."""
    w, h = mask.size
    data = mask.load()
    n = w if axis == "x" else h
    other = h if axis == "x" else w
    occ = []
    for i in range(n):
        if axis == "x":
            occ.append(any(data[i, j] for j in range(other)))
        else:
            occ.append(any(data[j, i] for j in range(other)))
    lo_lim, hi_lim = n // 3, 2 * n // 3
    mid = n // 2
    best: tuple[int, int] | None = None
    i = 0
    while i < n:
        if occ[i]:
            i += 1
            continue
        j = i
        while j + 1 < n and not occ[j + 1]:
            j += 1
        if j >= lo_lim and i <= hi_lim and (j - i + 1) >= band:
            if best is None or (j - i + 1) > best[1]:
                # Cut at the exact midline whenever the band contains it (an
                # exact quadrant slice, byte-stable across rebuilds); only an
                # off-centre band moves the cut, and then to the band's middle.
                seam = mid if i <= mid <= j else (i + j) // 2
                best = (seam, j - i + 1)
        i = j + 1
    return best


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("master", type=Path, help="2x2 master (keyed RGBA, or raw with --key)")
    ap.add_argument("--out", type=Path, required=True, help="output strip PNG")
    ap.add_argument("--ref-idle", type=Path,
                    help="installed idle strip: sets cell size, body scale, baseline. "
                         "Omit with --self to build a fresh idle from the master itself.")
    ap.add_argument("--self", dest="self_ref", action="store_true",
                    help="no external reference: the master's own --scale-frame is the "
                         "reference (scale 1.0). Use to build the very first idle strip "
                         "of a new boss; every later clip then uses --ref-idle <that idle>.")
    ap.add_argument("--anchor", choices=("head", "feet", "hindfeet", "bbox", "halo"),
                    default="head",
                    help="head: crown-band bbox mid (default); feet: feet-band "
                         "centroid; hindfeet: rear-40%% of the feet band (a "
                         "quadruped's planted hind paws — howl/slam); bbox: figure "
                         "bbox mid (body mass — pounce/charge where every leg "
                         "moves); halo: template-match the idle's crown band "
                         "(shape-based — immune to motes/hands above the head)")
    ap.add_argument("--facing", choices=("left", "right"), default="left",
                    help="which way the beast faces (hindfeet: the rear is the other side)")
    ap.add_argument("--no-scale", action="store_true", help="skip body-scale normalization")
    ap.add_argument("--scale-frame", type=int, default=1,
                    help="1-based frame whose body height sets the ONE clip scale")
    ap.add_argument("--valign", choices=("hem", "top", "rows"), default="hem",
                    help="hem: each frame's body hem on the idle baseline (default); "
                         "top: each frame's crown on the idle crown row; rows: the "
                         "TOP row (f1,f2) by frame 1's hem and the BOTTOM row (f3,f4) "
                         "by frame 4's — an airborne/reared frame keeps its authored "
                         "height (quadruped pounce/slam)")
    ap.add_argument("--scale-ref", choices=("body", "halo", "area"), default="body",
                    help="body: normalize on hood-to-hem height (default); halo: on "
                         "the crown-band width — for a clip whose hem is mist; area: "
                         "on sqrt(opaque area) of the scale frame — a standing "
                         "quadruped whose bbox changes with head/tail pose")
    ap.add_argument("--floor-clip", action="store_true",
                    help="clear pixels below the idle baseline in every frame, so the "
                         "engine's frame-0 feet line (lowest opaque row) is the hem")
    ap.add_argument("--fx-exclude", choices=("green",),
                    help="drop greenish spell pixels from anchor/body measurements "
                         "(Morwen's olive blight FX vs her blue-grey/white body)")
    ap.add_argument("--key", action="store_true", help="master is raw chroma; key it here")
    ap.add_argument("--qa", type=Path, help="write a QA sheet (strip + onion overlay)")
    args = ap.parse_args()
    global FX_EXCLUDE, FACING_LEFT
    FX_EXCLUDE = args.fx_exclude
    FACING_LEFT = args.facing == "left"

    master = Image.open(args.master)
    master = key_chroma(master) if args.key else master.convert("RGBA")
    mw, mh = master.size

    # 1. seam gate: cut at the REAL gutters (widest empty band through the
    #    middle third), and each must be broad — never through a figure.
    mask = alpha_mask(master, ALPHA_THR)
    gy = find_gutter(mask, "y", MIN_GUTTER)
    if gy is None:
        print("FAIL: no broad empty horizontal gutter through the middle third — "
              "regenerate the master with clear gutters (do not slice through a figure)")
        return 2
    qh = gy[0]
    # The vertical seam is found PER ROW: the two rows' cells are cropped
    # independently, and a lunge/tail in one row often closes the gap that the
    # other row leaves wide open (Cinderhide's breath: top-row gutter 571-637,
    # bottom-row gutter 641-664 — no single column was empty over both).
    gx_top = find_gutter(mask.crop((0, 0, mw, qh)), "x", MIN_GUTTER)
    gx_bot = find_gutter(mask.crop((0, qh, mw, mh)), "x", MIN_GUTTER)
    if gx_top is None or gx_bot is None:
        print("FAIL: no broad empty vertical gutter through the middle third of the "
              f"{'top' if gx_top is None else 'bottom'} row — regenerate the master "
              "with clear gutters (do not slice through a figure)")
        return 2
    qw_top, qw_bot = gx_top[0], gx_bot[0]
    print(f"seams: horizontal cut y={qh} (gutter {gy[1]}px, midline {mh // 2}); "
          f"vertical cut top row x={qw_top} (gutter {gx_top[1]}px), "
          f"bottom row x={qw_bot} (gutter {gx_bot[1]}px), midline {mw // 2}")
    quads = [master.crop((0, 0, qw_top, qh)), master.crop((qw_top, 0, mw, qh)),
             master.crop((0, qh, qw_bot, mh)), master.crop((qw_bot, qh, mw, mh))]
    total = sum(1 for v in mask.getdata() if v)
    parts = sum(sum(1 for v in alpha_mask(q, ALPHA_THR).getdata() if v) for q in quads)
    if total != parts:
        print(f"FAIL: opaque-pixel accounting {parts} != {total}")
        return 2

    # 2. reference idle: cell, body height, baseline row. --self uses the
    # master's own scale frame (a fresh idle defines its own reference: all four
    # breathing frames are the same pose, so it just needs internal consistency).
    if args.self_ref or args.ref_idle is None:
        ref0 = quads[args.scale_frame - 1]
        rcell = max(ref0.width, ref0.height)
        rb = body_box(ref0)
        print(f"self-reference: master frame {args.scale_frame} is the idle reference "
              f"(cell {rcell}px, scale 1.0)")
    else:
        ref = Image.open(args.ref_idle).convert("RGBA")
        rcell = ref.height
        ref0 = ref.crop((0, 0, rcell, rcell))
        rb = body_box(ref0)
    if rb is None:
        print("FAIL: reference idle frame 0 is empty")
        return 2
    ref_body_h = rb[3] - rb[1]
    baseline_from_floor = rcell - rb[3]   # rows between hem and cell floor
    print(f"reference idle: cell {rcell}px, body {ref_body_h}px, hem {baseline_from_floor}px above floor")
    if args.anchor == "halo":
        import numpy as np
        global HALO_TEMPLATE
        cb = crown_box(ref0)
        if cb is None:
            print("FAIL: reference idle crown band unreadable for --anchor halo")
            return 2
        tm = np.asarray(alpha_mask(ref0, BODY_THR).crop(cb), dtype=np.float32) / 255.0
        HALO_TEMPLATE = (tm, tm.shape[1] / 2.0)
        print(f"halo template {tm.shape[1]}x{tm.shape[0]}px from idle frame 0 "
              f"(centre x {(cb[0] + cb[2]) / 2:.1f} of {rcell})")

    # 3. one clip scale from the chosen frame.
    boxes = [body_box(q) for q in quads]
    for i, b in enumerate(boxes):
        if b is None:
            print(f"FAIL: quadrant {i + 1} is empty")
            return 2
    sf = boxes[args.scale_frame - 1]
    scale = 1.0
    if not args.no_scale:
        if args.scale_ref == "halo":
            rc = crown_box(ref0)
            cc = crown_box(quads[args.scale_frame - 1])
            if rc is None or cc is None:
                print("FAIL: crown band unreadable for --scale-ref halo")
                return 2
            ref_m, clip_m, what = rc[2] - rc[0], cc[2] - cc[0], "halo width"
        elif args.scale_ref == "area":
            def _area(im: Image.Image) -> float:
                return float(sum(1 for v in alpha_mask(im, BODY_THR).getdata() if v)) ** 0.5
            ref_m, clip_m, what = _area(ref0), _area(quads[args.scale_frame - 1]), "sqrt(area)"
        else:
            ref_m, clip_m, what = ref_body_h, sf[3] - sf[1], "body"
        dev = clip_m / ref_m - 1.0
        print(f"frame {args.scale_frame} {what} {clip_m}px vs idle {ref_m}px ({dev:+.1%})")
        if abs(dev) > SCALE_TOL:
            scale = ref_m / clip_m
            print(f"  -> normalizing clip by x{scale:.4f} (one factor, all frames)")
    if scale != 1.0:
        quads = [q.resize((max(1, round(q.width * scale)), max(1, round(q.height * scale))),
                          Image.LANCZOS) for q in quads]
        boxes = [body_box(q) for q in quads]

    # 4. anchors + cell size. The cell grows (still square) when a frame reaches
    # wider than the reference cell OR taller above its hem than the reference
    # cell allows (arms raised overhead: Morwen's rain call-down).
    anchor_fn = {"head": head_anchor_x, "feet": feet_anchor_x,
                 "hindfeet": hindfeet_anchor_x, "bbox": bbox_anchor_x,
                 "halo": halo_anchor_x}[args.anchor]
    anchors = [anchor_fn(q) for q in quads]
    # Land each frame's anchor where the IDLE keeps its own — not blindly at
    # the cell centre. Morwen's idle halo sits dead-centre (offset 0), but a
    # bbox-centred quadruped idle carries its paw centroid a little off-centre
    # (the head sticks out further than the tail), and a clip whose paws land
    # at true centre would jump sideways on entry.
    ref_anchor = anchor_fn(ref0)
    anchor_off = 0.0 if ref_anchor is None else ref_anchor - rcell / 2.0
    if abs(anchor_off) > 0.5:
        print(f"idle {args.anchor} anchor sits {anchor_off:+.1f}px off centre; clip frames target the same offset")
    bbs = [alpha_mask(q, ALPHA_THR).getbbox() for q in quads]
    for anc, bb in zip(anchors, bbs):
        if anc is None or bb is None:
            print("FAIL: an anchor could not be measured")
            return 2
    ref_top_from_floor = rcell - rb[1]
    PAD = 12  # breathing room so FX at the extreme never sits on the cell edge

    def placement(cell_px: int) -> list[tuple[int, int]]:
        """(px, py) paste offsets per frame for a given square cell.
        x: the frame's anchor lands where the idle keeps its own anchor.
        y: --valign hem = each frame's own hem on the idle baseline;
           top = each frame's crown on the idle crown row (mist-hem clip);
           rows = one dy per master ROW from that row's grounded frame (f1 for
           the top row, f4 for the bottom) — the 2x2 model drifts rows by
           ~20px like it drifts columns, but an airborne/reared frame must keep
           its authored height relative to its grounded neighbour."""
        floor = cell_px - baseline_from_floor
        row_dy = {0: floor - boxes[0][3], 1: floor - boxes[3][3]}
        out_xy = []
        for i, anc in enumerate(anchors):
            px = round(cell_px / 2.0 + anchor_off - anc)
            if args.valign == "top":
                py = round((cell_px - ref_top_from_floor) - boxes[i][1])
            elif args.valign == "rows":
                py = row_dy[i // 2]
            else:
                py = floor - boxes[i][3]
            out_xy.append((px, py))
        return out_xy

    # Size the cell from the ACTUAL placement (two passes: every offset above
    # grows 1:1 with the cell, so one measured shortfall is exact). The cell
    # grows (still square) when a frame reaches wider than the reference cell
    # or taller than it allows (arms overhead, a burst, an airborne pounce).
    cell = rcell
    MX, MY = PAD // 2, PAD   # per-side x margin, top margin
    for _pass in range(3):
        xy = placement(cell)
        short_x = 0
        short_y = 0
        for (px, py), bb in zip(xy, bbs):
            short_x = max(short_x, MX - (bb[0] + px), (bb[2] + px) - (cell - MX))
            short_y = max(short_y, MY - (bb[1] + py))
        if short_x <= 0 and short_y <= 0:
            break
        # centring splits x growth over both sides (2x); y offsets grow 1:1
        cell += max(2 * short_x, short_y)
        cell += cell % 2
    if cell != rcell:
        print(f"cell grown {rcell}->{cell}px so every frame fits with {PAD}px margin "
              f"(engine keeps body at idle scale)")
    xy = placement(cell)
    out = Image.new("RGBA", (cell * 4, cell))
    for i, (q, anc) in enumerate(zip(quads, anchors)):
        bb_all = bbs[i]
        px, py = xy[i]
        frame = Image.new("RGBA", (cell, cell))
        frame.alpha_composite(q, (max(px, 0), max(py, 0)), (max(-px, 0), max(-py, 0)))
        if args.floor_clip:
            # Anything below the idle baseline goes: the engine reads frame 0's
            # lowest opaque row as the feet line, so a mist pool spreading
            # under the hem would float the whole clip above her idle body.
            floor_row = cell - baseline_from_floor
            clipped_px = sum(1 for v in frame.crop((0, floor_row + 1, cell, cell))
                             .getchannel("A").getdata() if v > ALPHA_THR)
            frame.paste((0, 0, 0, 0), (0, floor_row + 1, cell, cell))
            if clipped_px:
                print(f"  f{i + 1}: floor-clipped {clipped_px}px below the idle baseline")
        out.alpha_composite(frame, (i * cell, 0))
        top_gap = boxes[i][1] + py
        print(f"  f{i + 1}: {args.anchor} anchor {anc:.0f} -> shift {px:+d}px x, {py:+d}px y; "
              f"body {boxes[i][3] - boxes[i][1]}px, top margin {top_gap}px, "
              f"reach L{anc - bb_all[0]:.0f}/R{bb_all[2] - anc:.0f}")
        if top_gap < 0:
            print(f"  WARN f{i + 1}: figure top clipped by {-top_gap}px")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out, optimize=True)
    print(f"wrote {args.out} ({out.width}x{out.height}, 4 frames of {cell}px)")

    if args.qa:
        sc = 0.5
        sheet = out.resize((int(out.width * sc), int(out.height * sc)), Image.LANCZOS)
        ov = Image.new("RGBA", (cell, cell), (40, 40, 40, 255))
        cols = [(255, 255, 255), (255, 80, 80), (80, 255, 120), (90, 140, 255)]
        for i, c in enumerate(cols):
            fr = out.crop((i * cell, 0, (i + 1) * cell, cell))
            a = fr.getchannel("A").point(lambda v: v // 2)
            tint = Image.new("RGBA", (cell, cell), c + (0,))
            tint.putalpha(a)
            ov.alpha_composite(tint)
        ovs = ov.resize((int(cell * sc), int(cell * sc)), Image.LANCZOS)
        canvas = Image.new("RGBA", (sheet.width + ovs.width + 10, sheet.height), (40, 40, 40, 255))
        canvas.paste(sheet, (0, 0), sheet)
        canvas.paste(ovs, (sheet.width + 10, 0))
        canvas.save(args.qa)
        print(f"wrote QA sheet {args.qa}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
