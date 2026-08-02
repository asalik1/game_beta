#!/usr/bin/env python3
"""Post-install sprite verifier -- the install-README checks, as one command.

After installing/replacing sprite art, run this on the base name. It runs
the checks that are otherwise scattered snippets in tools/art/README.md
(and therefore get skipped):

  GEOMETRY   strips use square cells by default. An *_anim strip may instead
             use rectangular cells when a matching static sprite has the same
             height and evenly tiles the strip (art.gd _strip_info). -> FAIL
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
    a = np.asarray(img)[:, :, 3]

    # Authored room surfaces are deliberately rectangular, loaded directly by
    # Art._ground_room_surface(), and never pass through the square-strip
    # decoder. Do not misclassify their descriptive suffix as animation.
    is_ground_room = stem.startswith("ground_room_")
    suffixes = CLIPS + DIR8
    is_strip = not is_ground_room and any(stem.endswith(f"_{suffix}") for suffix in suffixes)
    frame_width = h
    frames = w // h if h > 0 else 0
    if stem.endswith("_anim"):
        static_png = png.with_name(f"{stem.removesuffix('_anim')}.png")
        if static_png.exists():
            static_w, static_h = Image.open(static_png).size
            if static_h == h and static_w > 0 and w % static_w == 0:
                frame_width = static_w
                frames = w // static_w
    if is_strip and (frame_width <= 0 or w % frame_width != 0):
        FAIL.append(
            f"[GEOMETRY] {rel}: {w}x{h} -- strip does not tile its "
            f"{frame_width} px frame width; art.gd _strip_info would shear frames"
        )
    if stem.endswith("_dir") and frame_width > 0 and w % frame_width == 0 and frames % 8 != 0:
        FAIL.append(f"[DIRSTRIP] {rel}: {frames} frames -- aim strips must be 8*K frames, "
                    "direction-major E,NE,N,NW,W,SW,S,SE (tools/art/README.md)")

    # A non-empty frame can still be effectively invisible when a mixed-source
    # normalizer shrinks the body to a miniature.  Catch catastrophic body-box
    # collapse on ordinary full-body clips; effects/death/dash are excluded
    # because deliberate vanish/transform frames are valid there.
    body_clips = ("anim", "walk", "run", "attack", "attack2")
    is_body_clip = any(
        re.search(rf"_{clip}(?:_|$)", stem) for clip in body_clips
    )
    if is_body_clip and frame_width > 0 and frames > 1 and w % frame_width == 0:
        heights: list[int] = []
        for frame_index in range(frames):
            region = a[:, frame_index * frame_width : (frame_index + 1) * frame_width]
            ys = np.where(region > 0)[0]
            heights.append(int(ys[-1] - ys[0] + 1) if len(ys) else 0)
        positive = [height for height in heights if height > 0]
        if positive:
            # Use the upper quartile rather than the median: a broken row can
            # contain a majority of miniature frames (the Warrior north cleave
            # had four tiny middles and three full-size bookends).
            reference_height = float(np.percentile(positive, 75))
            for frame_index, height in enumerate(heights):
                if height < max(8.0, reference_height * 0.45):
                    FAIL.append(
                        f"[BODYSCALE] {rel}: f{frame_index + 1} alpha height {height}px "
                        f"vs {reference_height:.0f}px upper-quartile reference -- "
                        "likely mixed-source shrink/cut"
                    )

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
