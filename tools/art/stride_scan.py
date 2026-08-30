"""Stride scan: rank EVERY walk strip by authored stride length, in BODY
HEIGHTS per cycle -- the species-agnostic marching-in-place triage (2026-08-27,
owner: bipedal bosses have it too, "vargoth ... one of the worst").

A grounded walker (biped OR quadruped) should sweep its planted contacts
backward through the cell as it strides; a normal walk covers ~0.8-1.2 body
heights per cycle. Marching-in-place art reads <0.2. Body-relative units need
no per-species speed/scale tables, so one sweep ranks heroes, mobs and bosses
together. Floaters / robed / legless bodies have no readable ground contacts
and land at ~0 -- they are SKIP-LIST material at review, not defects; this is
TRIAGE, not a gate (the install gate is verify_art --stride-min, heroes).

    python tools/art/stride_scan.py                  # whole sprites dir
    python tools/art/stride_scan.py vargoth korrag   # name filter (substring)
    options: --csv out.csv  --min-frames 3

Side-facing strips only (flat + _e/_w): front/back walks encode stride
vertically and can't be read this way.
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_art import SPRITES, _contact_centroids, _stride_sweep  # noqa: E402


def measure(png: Path, min_frames: int) -> dict | None:
    img = Image.open(png).convert("RGBA")
    a = np.asarray(img)[:, :, 3]
    fw = img.height
    n = img.width // fw
    if n < min_frames:
        return None
    cells = [a[:, f * fw:(f + 1) * fw] for f in range(n)]
    grounds = [np.nonzero(c > 40)[0].max() for c in cells if (c > 40).any()]
    if not grounds:
        return None
    ground_y = int(max(grounds))
    cents = [_contact_centroids(c, ground_y) for c in cells]
    contact_frames = sum(1 for c in cents if c)
    ys = np.nonzero(a[:, 0:fw] > 40)[0]
    body = float(ys.max() - ys.min() + 1) if len(ys) else float(fw)
    sweep = _stride_sweep(cents, n, max(45.0, 0.30 * body))
    return {
        "strip": str(png.relative_to(SPRITES)),
        "frames": n,
        "contact_frames": contact_frames,
        "sweep_px": round(sweep, 1),
        "body_px": int(body),
        "stride_bodies": round(sweep / body, 3) if body > 0 else 0.0,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="rank walk strips by stride, in body heights")
    ap.add_argument("names", nargs="*", help="substring filters (e.g. vargoth)")
    ap.add_argument("--csv", default=None)
    ap.add_argument("--min-frames", type=int, default=3)
    args = ap.parse_args()

    rows = []
    for png in sorted(SPRITES.rglob("*_walk*.png")):
        stem = png.stem
        # side-facing only: flat walk or _e/_w — including regen-suffixed
        # families (vargoth_walk_codex_e slipped a plain endswith).
        import re
        if not re.search(r"_walk(_[a-z0-9]+)?(_e|_w)?$", stem) \
                or re.search(r"_(n|s|ne|nw|se|sw)$", stem):
            continue
        if args.names and not any(nm.lower() in stem.lower() for nm in args.names):
            continue
        try:
            r = measure(png, args.min_frames)
        except Exception as ex:  # unreadable strip: report, keep sweeping
            print(f"skip {png.name}: {ex}")
            continue
        if r:
            rows.append(r)

    rows.sort(key=lambda r: r["stride_bodies"])
    print(f"{'stride(bodies)':>14}  {'sweep px':>8}  {'body':>5}  {'fr':>3}  strip")
    for r in rows:
        tag = "MARCH" if r["stride_bodies"] < 0.15 and r["contact_frames"] >= 2 else \
              ("  n/a" if r["contact_frames"] < 2 else ("  low" if r["stride_bodies"] < 0.5 else "   ok"))
        print(f"{r['stride_bodies']:>14.3f}  {r['sweep_px']:>8.1f}  {r['body_px']:>5}  "
              f"{r['frames']:>3}  {r['strip']}  [{tag.strip()}]")
    print(f"\n{len(rows)} strips. bodies/cycle: <0.15 = marching-in-place (grounded walkers), "
          f"~0.8-1.2 = a real traveling stride; n/a = no readable contacts (floaters/robed).")

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()) if rows else [])
            w.writeheader()
            w.writerows(rows)
        print(f"csv -> {args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
