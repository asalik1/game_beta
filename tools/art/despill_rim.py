#!/usr/bin/env python
"""RIM-BAND green-key despill for installed sprites — the corpus-wide fixer for
the ImageGen chroma ring `scan_key_rim` reports.

Every ImageGen-keyed strip carries a dark-green antialias rim: the body colour
blended with the #00FF00 matte, surviving the key as a 1-2 px ring that is
invisible on a dark contact sheet and rings GREEN over grass (CLAUDE.md, the
2026-08-15 Wildfang catch). `despill_keyed.py` clamps green-dominant pixels
GLOBALLY, which also dulls olive/green GARMENTS (the bog lurker's hide, the
wildkin's leaf cloak, a mushroom cap) — so it is only safe pre-slice on a
master. This one:

  * touches ONLY the `--band` px next to transparency (default 2), so interior
    colour is untouchable by construction;
  * REFUSES a sprite whose green is mostly interior (that is design, not a
    halo) unless --force — the rim/interior split is the same discriminator
    scan_key_rim reports;
  * clamps a rim pixel's G toward max(R,B) and cuts the faint green crumbs
    (alpha <= --cut) that make the ring visible at all;
  * processes `_anim`/strip files whole (the band is computed on the full
    image, so a cell's inner edges are never treated as silhouette).

    python tools/art/despill_rim.py <sprite.png> [...] [--band 2] [--dry]
    python tools/art/despill_rim.py --scan game/assets/sprites   # report only

Writes atomically (Defender holds a read handle on a just-written sprite:
write .tmp then os.replace — the 2026-08-29 Errno 22 lesson). After a fix run:
--import, then verify_art / scan_key_rim to confirm the ring is gone, and look
at a grass composite (the ring, not the count, is the defect).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

THR = 20          # G over max(R,B) to count as green-dominant
CUT_A = 60        # a green-dominant rim pixel at/below this alpha is a crumb


def _rim_mask(alpha: np.ndarray, band: int) -> np.ndarray:
    """Pixels within `band` px of a transparent pixel (the silhouette edge)."""
    op = alpha > 0
    inner = op.copy()
    for _ in range(band):
        p = np.pad(inner, 1, constant_values=False)
        inner = p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:] & inner
    return op & ~inner


def measure(path: Path, band: int = 2) -> dict:
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.int16)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    op = al > 0
    rim = _rim_mask(al, band)
    green = (g - np.maximum(r, b) > THR) & op
    return {
        "path": path, "opaque": int(op.sum()), "rim": int(rim.sum()),
        "green_rim": int((green & rim).sum()),
        "green_interior": int((green & ~rim).sum()),
    }


def verdict(m: dict) -> str:
    if m["rim"] == 0 or m["green_rim"] < 60:
        return "clean"
    share = m["green_rim"] / max(1, m["rim"])
    interior_ratio = m["green_interior"] / max(1, m["green_rim"])
    if interior_ratio > 1.0:
        return "content"     # green lives mostly inside the body: it IS the design
    if share >= 0.12:
        return "HALO"
    return "trace"


def despill(path: Path, band: int, dry: bool) -> tuple[int, int]:
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).copy()
    r = a[..., 0].astype(np.int16)
    g = a[..., 1].astype(np.int16)
    b = a[..., 2].astype(np.int16)
    al = a[..., 3]
    rim = _rim_mask(al, band)
    dom = g - np.maximum(r, b)
    spill = rim & (dom > THR) & (al > 0)
    before = int(spill.sum())
    a[..., 1] = np.where(spill, np.maximum(r, b), g).astype(np.uint8)
    crumb = spill & (al <= CUT_A)
    a[..., 3] = np.where(crumb, 0, al)
    if not dry:
        out = Image.fromarray(a, "RGBA")
        tmp = path.with_name(f".{path.stem}.despill.tmp.png")
        out.save(tmp, optimize=True)
        tmp.replace(path)
    return before, int(crumb.sum())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--scan", help="report every HALO sprite under this dir")
    ap.add_argument("--band", type=int, default=2)
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--force", action="store_true", help="despill even a 'content' verdict")
    args = ap.parse_args()
    if args.scan:
        hits = []
        for p in sorted(Path(args.scan).rglob("*.png")):
            if "skins" in p.parts or p.stem.endswith(".pre_fix") or ".pre_fix" in p.name:
                continue      # owner ruling: the legacy skins are off-limits; skip our own backups
            try:
                m = measure(p, args.band)
            except Exception:
                continue
            v = verdict(m)
            if v == "HALO":
                hits.append((m["green_rim"] / max(1, m["rim"]), m))
        hits.sort(reverse=True, key=lambda x: x[0])
        for share, m in hits:
            print(f"HALO {share*100:5.1f}% of rim  green_rim={m['green_rim']:6d} "
                  f"interior={m['green_interior']:6d}  {m['path'].name}")
        print(f"\n{len(hits)} sprite(s) with a green keying ring")
        return 0
    fixed = 0
    for s in args.paths:
        p = Path(s)
        m = measure(p, args.band)
        v = verdict(m)
        if v in ("clean", "trace"):
            print(f"skip [{v}] {p.name} (green_rim {m['green_rim']})")
            continue
        if v == "content" and not args.force:
            print(f"SKIP [content] {p.name}: green is mostly interior "
                  f"({m['green_interior']} vs rim {m['green_rim']}) — use --force if sure")
            continue
        n, crumbs = despill(p, args.band, args.dry)
        after = measure(p, args.band)["green_rim"] if not args.dry else -1
        print(f"{'DRY ' if args.dry else ''}despilled {p.name}: {n} rim px "
              f"({crumbs} crumbs cut) -> green_rim {after}")
        fixed += 1
    print(f"{fixed} sprite(s) despilled")
    return 0


if __name__ == "__main__":
    sys.exit(main())
