#!/usr/bin/env python3
"""Folder-wide KEY-COLOR RIM contamination scanner.

Leftover chroma/matte key (a magenta or bright-green background the art was
composited on) survives as a thin coloured RING on the silhouette edge. It is a
real defect -- rock2 shipped a magenta keyline that showed in 10 terrains, the
ImageGen mob walks shipped a 2px green antialias rim. This sweeps a whole asset
folder for it, for any number of key colours, and -- crucially -- tells a true
defect apart from a sprite that simply CONTAINS that colour.

THE DISCRIMINATOR (why this does not false-flag a purple mushroom or a green
bush): contamination lives ONLY on the edge. A genuinely purple/green sprite has
the colour THROUGHOUT its body. So for each key colour we measure two numbers:

    rim      = key-coloured pixels within --rim-dist px of transparency
    interior = key-coloured pixels everywhere else (the body)

and the verdict rides the RATIO rim/(rim+interior):

    DEFECT       rim large AND rim_frac >= --defect-frac   (colour is only a ring)
    SUSPECT      rim large AND rim_frac in [--suspect-frac, --defect-frac)
    INTENTIONAL  rim_frac < --suspect-frac                 (colour is real content)

A grey rock with a magenta ring -> interior~0 -> rim_frac~1 -> DEFECT.
A purple mushroom -> interior huge -> rim_frac low -> INTENTIONAL (ignored).
A green bush -> its whole body is green -> interior huge -> INTENTIONAL (ignored).

Green is inherently more false-flag-prone than magenta (foliage is green), so its
INTENTIONAL bucket is large and healthy -- trust the montage over the count.

Usage:
    python tools/art/scan_key_rim.py                       # game/assets/sprites, both keys
    python tools/art/scan_key_rim.py <dir|glob> --keys magenta
    python tools/art/scan_key_rim.py --csv out.csv --montage suspects.png
    python tools/art/scan_key_rim.py --show DEFECT,SUSPECT  # which verdicts to print/montage

Reports but never edits. To FIX a hit, use the despill in build_mob_walk_repairs
/ build_fx_strip, or the inpaint pattern (memory: terrain-prop-magenta-rim-batch)
-- and for a sprite that legitimately contains the colour, mask to the rim BAND
only or you eat real pixels.
"""
from __future__ import annotations
import argparse, csv, glob, os, sys
try:
    import numpy as np
    from PIL import Image
except ImportError:
    sys.exit("needs numpy + pillow:  pip install numpy pillow")

# Each key: predicate over int16 R,G,B planes returning a bool mask of "pure key".
# Tight enough to target the composited key, not every warm/leafy pixel; the
# rim/interior split does the rest.
KEYS = {
    # magenta matte: green crushed well below both R and B, R~B balanced, both bright
    "magenta": lambda R, G, B: (np.minimum(R, B) - G > 50) & (R > 100) & (B > 100) & (np.abs(R - B) < 60),
    # chroma green: green well above both R and B and bright (screen/key green, not foliage)
    "green":   lambda R, G, B: (G - np.maximum(R, B) > 50) & (G > 120),
}


def dilate(mask: np.ndarray, r: int) -> np.ndarray:
    """4-connected dilation by r (Manhattan radius). Pure numpy, no scipy."""
    m = mask.copy()
    for _ in range(r):
        n = m.copy()
        n[:-1, :] |= m[1:, :]; n[1:, :] |= m[:-1, :]
        n[:, :-1] |= m[:, 1:]; n[:, 1:] |= m[:, :-1]
        m = n
    return m


def scan_image(path: str, keys: list[str], rim_dist: int) -> list[dict]:
    try:
        a = np.asarray(Image.open(path).convert("RGBA"), dtype=np.int16)
    except Exception:
        return []
    R, G, B, A = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    opaque = A > 200
    opaque_total = int(opaque.sum()) or 1
    # "edge" = near transparency OR near the image border (a sprite bleeding off
    # the canvas edge has no transparent neighbour but is still an outline).
    trans = A <= 20
    trans = np.pad(trans[1:-1, 1:-1], 1, constant_values=True) if trans.size else trans
    near_edge = dilate(trans, rim_dist)
    out = []
    for k in keys:
        key = KEYS[k](R, G, B) & opaque
        tot = int(key.sum())
        if tot == 0:
            continue
        rim = int((key & near_edge).sum())
        interior = tot - rim
        rim_frac = rim / tot if tot else 0.0
        # key_share: how much of the WHOLE sprite is this colour. High share means
        # the colour IS the sprite (a purple projectile, a green slime) -- even a
        # thin shape whose every pixel is near-edge. Low share + edge-only = a rim.
        key_share = tot / opaque_total
        out.append({"key": k, "rim": rim, "interior": interior, "total": tot,
                    "rim_frac": rim_frac, "key_share": key_share})
    return out


def verdict(rim: int, rim_frac: float, key_share: float, min_rim: int,
            defect_frac: float, suspect_frac: float, share_cap: float) -> str:
    if rim < min_rim:
        return "clean"
    if key_share >= share_cap:      # colour is a major part of the sprite -> it's the sprite's own colour
        return "INTENTIONAL"
    if rim_frac >= defect_frac:
        return "DEFECT"
    if rim_frac >= suspect_frac:
        return "SUSPECT"
    return "INTENTIONAL"


def build_montage(rows: list[dict], out_path: str, cell: int = 128, cols: int = 8) -> None:
    from PIL import ImageDraw
    rows = rows[: cols * 12]
    if not rows:
        return
    n = len(rows)
    ncol = min(cols, n)
    nrow = (n + ncol - 1) // ncol
    pad, lab = 6, 26
    W = ncol * (cell + pad) + pad
    H = nrow * (cell + lab + pad) + pad
    canvas = Image.new("RGBA", (W, H), (32, 32, 36, 255))
    d = ImageDraw.Draw(canvas)
    col = {"DEFECT": (235, 90, 90), "SUSPECT": (235, 200, 90), "INTENTIONAL": (150, 150, 160)}
    for i, r in enumerate(rows):
        cx = pad + (i % ncol) * (cell + pad)
        cy = pad + (i // ncol) * (cell + lab + pad)
        try:
            im = Image.open(r["path"]).convert("RGBA")
            im.thumbnail((cell, cell))
            # checker so a transparent rim reads
            bg = Image.new("RGBA", (cell, cell), (60, 60, 66, 255))
            bg.paste(im, ((cell - im.width) // 2, (cell - im.height) // 2), im)
            canvas.paste(bg, (cx, cy))
        except Exception:
            pass
        c = col.get(r["verdict"], (200, 200, 200))
        d.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], outline=c, width=2)
        name = os.path.splitext(os.path.basename(r["path"]))[0]
        d.text((cx + 2, cy + cell + 2), f"{name[:20]}", fill=c)
        d.text((cx + 2, cy + cell + 13), f"{r['key'][:3]} {r['verdict'][:4]} f{r['rim_frac']:.2f}", fill=c)
    canvas.save(out_path)


def _erode(m: np.ndarray, k: int) -> np.ndarray:
    for _ in range(k):
        m = m & np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1)
    return m


def pale_halo_score(path: str) -> float:
    """WHITE/PALE keying-halo score (2026-08-26, snow-tree catch): the ring
    test — outermost 0-2px of the opaque silhouette vs the 4-6px band inward
    at the same spots. A keying halo = a thin BRIGHT, DESATURATED skin over
    darker content (score ~0.3-0.65 on the caught trees; clean assets ~0.0).
    JUDGED LINT — confirm on a grass composite before fixing: pale-bodied
    subjects (bone-grey bosses, stone) and thin pale DESIGN strands (hanging
    moss, frost wisps) score 0.1-0.45 legitimately; solid dark-content sprites
    with a real halo separate cleanly above ~0.25. Colour-key rims (green/
    magenta) are the classic scanner's job; this catches the colourless one
    that BLEED (colour-blind) and the key list structurally miss."""
    from PIL import ImageFilter
    im = Image.open(path).convert("RGBA")
    # strips: score the first cell (square, or static-width for _anim)
    cw = im.height if im.width % im.height == 0 and im.width // im.height > 1 else im.width
    base = os.path.basename(path)
    if base.endswith("_anim.png"):
        st = os.path.join(os.path.dirname(path), base[:-9] + ".png")
        if os.path.exists(st):
            sw, sh = Image.open(st).size
            if sh == im.height and im.width % sw == 0:
                cw = sw
    a = np.asarray(im.crop((0, 0, cw, im.height))).astype(float)
    al = a[..., 3]
    core = al > 128
    if core.sum() < 400:
        return 0.0
    e2, e4, e6 = _erode(core, 2), _erode(core, 4), _erode(core, 6)
    ring_out, ring_in = core & ~e2, e4 & ~e6
    lum = a[..., :3].mean(2)
    mx, mn = a[..., :3].max(2), a[..., :3].min(2)
    blur = lambda x: np.asarray(Image.fromarray(np.clip(x, 0, 255).astype("uint8"))
                                .filter(ImageFilter.GaussianBlur(5))).astype(float)
    wm = ring_in.astype(float)
    wb = blur(wm * 255) / 255
    inref = blur(lum * wm) / np.maximum(wb, 1e-3)
    valid = ring_out & (wb > 0.02)
    halo = valid & (lum > inref + 55) & (lum > 150) & ((mx - mn) < 50)
    ring_score = float(halo.sum()) / max(1, int(valid.sum()))
    # SEMI-ALPHA variant (2026-08-28, autumn-tree miss): the same matte can sit
    # almost entirely in the 0<a<=128 fringe — invisible to the opaque ring —
    # and be warm-TINTED, so the desat cap spared its opaque remnant too.
    # Score the fringe band with its own (slightly looser) tests and take the
    # worst of the two. Clean soft edges score ~0.0 (their fringe carries the
    # interior colour, so lum stays near inref); measured 2026-08-28:
    # autumn 0.38-0.94 vs clean tree_green2 0.01.
    semi = (al > 0) & (al <= 128) & (wb > 0.02)
    fringe = semi & (lum > inref + 40) & (lum > 150) & ((mx - mn) < 60)
    semi_score = float(fringe.sum()) / max(1, int(semi.sum())) \
        if int(semi.sum()) >= 200 else 0.0
    return max(ring_score, semi_score)


def main() -> None:
    ap = argparse.ArgumentParser(description="Folder-wide key-colour rim contamination scanner.")
    ap.add_argument("target", nargs="?", default="game/assets/sprites", help="dir or glob (default game/assets/sprites)")
    ap.add_argument("--keys", default="magenta,green", help="comma list of key colours (default magenta,green)")
    ap.add_argument("--rim-dist", type=int, default=3, help="px from transparency counted as rim (default 3)")
    ap.add_argument("--min-rim", type=int, default=60, help="min rim px to flag (default 60)")
    # 0.90: a true key rim is colour ONLY on the edge (interior~0, rim_frac~1). A
    # sprite that legitimately carries the colour in its body (Archer's green cape,
    # Warlock's purple) has real interior, so rim_frac lands 0.6-0.9 -> SUSPECT, not
    # DEFECT. Tuned on the archer_cast (0.63, cape) vs mummy_walk (1.00, rim) split.
    ap.add_argument("--defect-frac", type=float, default=0.90, help="rim_frac >= this => DEFECT, colour is edge-ONLY (default 0.90)")
    ap.add_argument("--suspect-frac", type=float, default=0.55, help="rim_frac >= this => SUSPECT, has real interior colour, eyeball it (default 0.55)")
    ap.add_argument("--share-cap", type=float, default=0.30, help="key_share >= this => INTENTIONAL, colour is the sprite (default 0.30)")
    ap.add_argument("--show", default="DEFECT,SUSPECT", help="verdicts to print/montage (default DEFECT,SUSPECT)")
    ap.add_argument("--csv", help="write full per-hit results here")
    ap.add_argument("--montage", help="write a labelled contact sheet of shown hits here")
    ap.add_argument("--pale-halo", action="store_true",
                    help="ALSO score the colourless WHITE-halo class (ring test); WARNs >= --pale-min")
    ap.add_argument("--pale-min", type=float, default=0.25,
                    help="pale_halo_score to WARN at (default 0.25; judged lint — eyeball on grass)")
    args = ap.parse_args()

    keys = [k.strip() for k in args.keys.split(",") if k.strip() in KEYS]
    show = {s.strip() for s in args.show.split(",")}
    files = sorted(glob.glob(os.path.join(args.target, "*.png"))) if os.path.isdir(args.target) else sorted(glob.glob(args.target))
    if not files:
        sys.exit(f"no PNGs at {args.target}")

    results = []
    for p in files:
        for m in scan_image(p, keys, args.rim_dist):
            m["verdict"] = verdict(m["rim"], m["rim_frac"], m["key_share"], args.min_rim,
                                   args.defect_frac, args.suspect_frac, args.share_cap)
            m["path"] = p
            results.append(m)

    from collections import Counter
    tally = Counter(r["verdict"] for r in results)
    shown = [r for r in results if r["verdict"] in show]
    shown.sort(key=lambda r: (r["verdict"] != "DEFECT", -r["rim"]))

    print(f"scanned {len(files)} files x {keys}")
    print(f"verdicts: " + "  ".join(f"{v}={tally.get(v,0)}" for v in ["DEFECT", "SUSPECT", "INTENTIONAL", "clean"]))
    print(f"\n{'verdict':11s} {'key':7s} {'rim':>6s} {'inter':>6s} {'frac':>5s} {'share':>5s}  file")
    print("-" * 82)
    for r in shown:
        print(f"{r['verdict']:11s} {r['key']:7s} {r['rim']:6d} {r['interior']:6d} {r['rim_frac']:5.2f} {r['key_share']:5.2f}  {os.path.basename(r['path'])}")

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["path", "key", "verdict", "rim", "interior", "total", "rim_frac", "key_share"])
            w.writeheader()
            for r in sorted(results, key=lambda r: -r["rim"]):
                w.writerow({k: r[k] for k in w.fieldnames})
        print(f"\ncsv -> {args.csv}  ({len(results)} hits)")
    if args.montage:
        build_montage(shown, args.montage)
        print(f"montage -> {args.montage}  ({len(shown)} cells)")

    if args.pale_halo:
        pale = []
        for p in files:
            try:
                s = pale_halo_score(p)
            except Exception:
                continue
            if s >= args.pale_min:
                pale.append((s, p))
        pale.sort(reverse=True)
        print(f"\npale-halo (>= {args.pale_min}, JUDGED — confirm on grass; pale-bodied/wispy designs false-positive):")
        for s, p in pale:
            print(f"  {s:.2f}  {os.path.basename(p)}")
        if not pale:
            print("  none")


if __name__ == "__main__":
    main()
