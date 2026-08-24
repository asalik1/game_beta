#!/usr/bin/env python3
"""Build the gem level icons DUAL-RES from single painterly masters (2026-08-21).

Owner fidelity ruling: gems must match GEAR — a 128px codex/detail master + a
32px bag copy, both from a high-fidelity source (the old 32px-only gems turned
to mush; a 512px painterly Codex gem downscales to a crisp 128/32). Levels are
derived procedurally (level is also shown as text): a subtle brightness ramp, a
soft glint at lv4/7, and a gold crown at lv10.

Outputs, mirroring gear:
  128px -> game/assets/icons/codex/gem_<stat>_lvN.png   (+ mobile)   codex/detail
   32px -> game/assets/icons/gem_<stat>_lvN.png          (+ mobile)   bag

  python build_gem_single.py [--source DIR] [--only ruby,jade] [--qa OUT] [--install]
"""
from __future__ import annotations
import argparse
from collections import deque
import os
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "art_src" / "Custom" / "GemsRegen_2026-08-21"
OUT = ROOT / "game" / "assets" / "icons"
MOBILE = ROOT / "mobile" / "game" / "assets" / "icons"
CODEX_PX, BAG_PX = 128, 32

FAMILIES = {
    "ruby": "atk_flat", "garnet": "hp_flat", "topaz": "crit",
    "sunstone": "dmg_pct", "sapphire": "cdr", "opal": "combo",
    "onyx": "physres", "lapis": "magres", "bloodstone": "physpen",
    "amethyst": "magpen", "jade": "eva", "amber": "dex",
    "tenacity": "flat_dr", "vampire_eye": "lifesteal",
}


def _border_magenta(a: np.ndarray) -> np.ndarray:
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    mag = (r > 175) & (b > 175) & (g < 90)
    h, w = mag.shape
    seen = np.zeros_like(mag)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if mag[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if mag[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mag[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    return seen


def _keyed_square(path: Path) -> Image.Image:
    """Magenta-keyed, despilled, tight-cropped, square-padded RGBA master."""
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.uint8).copy()
    a[_border_magenta(a), 3] = 0
    soft = (a[..., 3] > 0) & (a[..., 3] < 255)
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    a[..., 0] = np.where(soft & (r > g + 40), np.minimum(r, g + 40), r)
    a[..., 2] = np.where(soft & (b > g + 40), np.minimum(b, g + 40), b)
    img = Image.fromarray(a, "RGBA")
    box = img.getbbox()
    if box:
        img = img.crop(box)
    s = max(img.size) + max(6, img.width // 40)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(img, ((s - img.width) // 2, (s - img.height) // 2), img)
    return sq


def prep(master_sq: Image.Image, target: int) -> Image.Image:
    """Downscale the keyed master to `target` px. Gentle (painterly) at 128;
    a light unsharp at 32 so it stays crisp in a tiny socket."""
    small = master_sq.resize((target, target), Image.LANCZOS)
    if target <= 48:
        small = small.filter(ImageFilter.UnsharpMask(radius=1.0, percent=70, threshold=2))
    return small


def level_variant(base: Image.Image, lvl: int, target: int) -> Image.Image:
    """Bake the ramp: brightness step + soft glint (lv4/7) + gold crown (lv10)."""
    a = np.asarray(base).astype(np.float32).copy()
    opaque = a[..., 3] > 0
    mult = 0.88 + 0.031 * (lvl - 1)          # 0.88 (L1) .. 1.16 (L10)
    a[opaque, :3] = np.clip(a[opaque, :3] * mult, 0, 255)
    img = Image.fromarray(a.astype(np.uint8), "RGBA").copy()
    px = img.load()
    u = max(1, target // 32)                 # marker unit scales with resolution
    # Level reads from the TEXT beside the gem; the art stays pristine — only a
    # subtle brightness climb (above) and, at max level, a small gold crown.
    if lvl >= 10:
        cy, cw = u, int(target * 0.14)        # small gold crown centred at top
        cx = target // 2
        for k, gx in enumerate(range(cx - cw, cx + cw + 1)):
            gy = cy + (u if (k % 2 == 0) else 0)
            for yy in range(u, gy + u + 1):
                if 0 <= gx < target and 0 <= yy < target:
                    px[gx, yy] = (255, 224, 110, 255)
    return img


def build(source: Path, only: set[str] | None, qa_path: Path | None, install: bool):
    fams = [f for f in FAMILIES if (not only or f in only)]
    built: dict[str, dict[int, tuple[Image.Image, Image.Image]]] = {}
    for fam in fams:
        m = source / fam / f"{fam}_master_v1_keyed.png"
        if not m.exists():
            print(f"  SKIP {fam}: no master")
            continue
        sq = _keyed_square(m)
        base128, base32 = prep(sq, CODEX_PX), prep(sq, BAG_PX)
        built[fam] = {lv: (level_variant(base128, lv, CODEX_PX),
                           level_variant(base32, lv, BAG_PX)) for lv in range(1, 11)}
        print(f"  built {fam} -> gem_{FAMILIES[fam]}_lv1..10  (128 codex + 32 bag)")
    if install:
        for d in (OUT, MOBILE):
            if d.exists():
                (d / "codex").mkdir(exist_ok=True)
        for fam, lvls in built.items():
            stat = FAMILIES[fam]
            for lv, (big, small) in lvls.items():
                for d in (OUT, MOBILE):
                    if not d.exists():
                        continue
                    big.save(d / "codex" / f"gem_{stat}_lv{lv}.png")
                    small.save(d / f"gem_{stat}_lv{lv}.png")
        print(f"installed {len(built)} families x10 (128+32) -> {OUT}" + (" (+mobile)" if MOBILE.exists() else ""))
    if qa_path and built:
        cell, pad = CODEX_PX, 8
        rows, cols = len(built), 10
        sheet = Image.new("RGBA", (pad + cols * (cell + pad), pad + rows * (cell + pad + 14)), (34, 34, 40, 255))
        for r, (fam, lvls) in enumerate(built.items()):
            for c in range(10):
                sheet.alpha_composite(lvls[c + 1][0], (pad + c * (cell + pad), pad + r * (cell + pad + 14)))
        sheet.save(qa_path)
        print("QA sheet (128px):", qa_path)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    ap.add_argument("--only", default="")
    ap.add_argument("--qa", type=Path, default=None)
    ap.add_argument("--install", action="store_true")
    args = ap.parse_args()
    only = {s.strip() for s in args.only.split(",") if s.strip()} or None
    build(args.source, only, args.qa, args.install)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
