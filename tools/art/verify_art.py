#!/usr/bin/env python3
"""Post-install sprite verifier -- the install-README checks, as one command.

After installing/replacing sprite art, run this on the base name. It runs
the checks that are otherwise scattered snippets in tools/art/README.md
(and therefore get skipped):

  GEOMETRY   strip width must be an exact multiple of height. The engine
             derives frames = width/height (art.gd _strip_info) and FLOORS,
             so a mis-cut strip silently drops/shears frames.   -> FAIL
  DIR8       a directional set with SOME of the 8 facings missing. The
             engine falls back to south, so it renders -- but a partial set
             is almost always an install slip.                  -> WARN
  DIRSTRIP   *_dir.png aim strips must hold 8*K frames (E,NE,N,NW,W,SW,S,SE
             direction-major).                                  -> FAIL
  BLEED      semi-transparent pixels (0<alpha<255). The green-bleed bug:
             extracted sprites must be fully solidified. Generated/PixelLab
             art may carry a few AA pixels legitimately.        -> WARN
  IMPORT     source md5 vs Godot's import sidecar -- catches "installed the
             PNG, forgot --import" (headless then uses STALE art). -> FAIL

Intentional coverage gaps are NOT flagged: static idles, kit-matched clip
subsets and flat single-facing death strips are design decisions -- this
tool only judges the files that exist.

Usage:
    python tools/art/verify_art.py warrior [mage ...]
    python tools/art/verify_art.py skins/elite/assassin_blade_dancer
    python tools/art/verify_art.py --all          # whole sprites dir (IMPORT+DIR8 only)
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
GAME = ROOT / "game"

DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
CLIPS = ("anim", "walk", "run", "attack", "attack2", "cast", "dash", "ult",
         "ultidle", "death", "stab", "throw", "dir")

FAIL, WARN = [], []


def belongs(stem: str, base: str) -> bool:
    """warrior_attack2_ne belongs to warrior; warrior_captain_anim does not."""
    if stem == base:
        return True
    if not stem.startswith(base + "_"):
        return False
    return all(t in CLIPS or t in DIR8 for t in stem[len(base) + 1:].split("_"))


def check_import(png: Path) -> None:
    rel = png.relative_to(GAME)
    imp = png.with_name(png.name + ".import")
    if not imp.exists():
        FAIL.append(f"[IMPORT] {rel}: never imported -- headless runs will not see it")
        return
    m = re.search(r'path="res://(\.godot/imported/[^"]+)"', imp.read_text(errors="replace"))
    if not m:
        return
    dest = GAME / m.group(1)
    sidecar = dest.with_suffix(".md5")
    if not dest.exists():
        FAIL.append(f"[IMPORT] {rel}: import artifact missing -- run --import")
        return
    if sidecar.exists():
        m5 = re.search(r'source_md5="([0-9a-f]+)"', sidecar.read_text(errors="replace"))
        if m5 and hashlib.md5(png.read_bytes()).hexdigest() != m5.group(1):
            FAIL.append(f"[IMPORT] {rel}: changed since last import -- headless uses the STALE "
                        "version; run --import (close the editor first)")


def check_file(png: Path) -> None:
    rel = png.relative_to(SPRITES)
    img = Image.open(png).convert("RGBA")
    w, h = img.size
    stem = png.stem

    is_strip = "_" in stem and stem.rsplit("_", 1)[0] != stem  # anything with a suffix
    if is_strip and w % h != 0:
        FAIL.append(f"[GEOMETRY] {rel}: {w}x{h} -- width not a multiple of height; the engine "
                    f"floors frames to {w // h} and shears the rest (art.gd _strip_info)")
    if stem.endswith("_dir") and h > 0 and w % h == 0 and (w // h) % 8 != 0:
        FAIL.append(f"[DIRSTRIP] {rel}: {w // h} frames -- aim strips must be 8*K frames, "
                    "direction-major E,NE,N,NW,W,SW,S,SE (tools/art/README.md)")

    a = np.asarray(img)[:, :, 3]
    semi = int(((a > 0) & (a < 255)).sum())
    if semi:
        WARN.append(f"[BLEED] {rel}: {semi} semi-transparent pixel(s) -- extracted sprites must "
                    "be 0 (green-bleed); small counts on generated art may be benign AA")

    check_import(png)


def check_dir_sets(files: list[Path]) -> None:
    groups: dict[str, set[str]] = {}
    for f in files:
        m = re.match(r"^(.*)_(" + "|".join(DIR8) + r")$", f.stem)
        if m:
            groups.setdefault(str(f.parent / m.group(1)), set()).add(m.group(2))
    for stem, dirs in sorted(groups.items()):
        gap = [d for d in DIR8 if d not in dirs]
        if gap:
            WARN.append(f"[DIR8] {Path(stem).relative_to(SPRITES)}_*: missing facing(s) "
                        f"{gap} -- engine falls back to south; usually an install slip")


def main() -> int:
    ap = argparse.ArgumentParser(description="post-install sprite checks")
    ap.add_argument("bases", nargs="*", help="sprite base names (subpaths ok: skins/elite/...)")
    ap.add_argument("--all", action="store_true", help="IMPORT + DIR8 across the whole sprites dir")
    args = ap.parse_args()
    if not args.bases and not args.all:
        ap.error("give one or more base names, or --all")

    if args.all:
        pngs = sorted(SPRITES.rglob("*.png"))
        for p in pngs:
            check_import(p)
        check_dir_sets(pngs)
    for base in args.bases:
        base = base.replace("\\", "/").strip("/")
        parent = SPRITES / Path(base).parent
        name = Path(base).name
        mine = sorted(p for p in parent.glob("*.png") if belongs(p.stem, name))
        if not mine:
            FAIL.append(f"[FILES] no sprites found for base '{base}' under assets/sprites/")
            continue
        print(f"{base}: {len(mine)} file(s)")
        for p in mine:
            check_file(p)
        check_dir_sets(mine)

    for f in FAIL:
        print("FAIL " + f)
    for w in WARN:
        print("WARN " + w)
    if not FAIL and not WARN:
        print("VERIFY OK")
    else:
        print(f"\nVERIFY: {len(FAIL)} fail, {len(WARN)} warn")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
