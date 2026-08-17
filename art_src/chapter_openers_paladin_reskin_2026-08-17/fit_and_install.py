#!/usr/bin/env python3
"""Fit reskinned paladin opener plates back to the sibling geometry and install.

Codex's built-in image edit outputs a 3:2-ish frame; the opener plates are
1672x941 (16:9) and the in-game frame center-crops to 16:9 anyway
(STRETCH_KEEP_ASPECT_COVERED into 1300x732). So we center-crop each reskin to
16:9 and resize to the exact original dimensions, keeping the horizontal
composition and trimming only vertical margin.

    python fit_and_install.py            # stage fitted PNGs into ./fitted, build QA sheet
    python fit_and_install.py --install  # + copy fitted PNGs over game/assets/sprites/opening/

Backups of the originals already live in ./originals (made at stage time).
"""
import os
import sys
import time
from pathlib import Path

from PIL import Image


def robust_save(im: Image.Image, dst: Path, retries: int = 8, delay: float = 1.5) -> bool:
    """Save via a temp file + atomic replace, retrying transient Windows locks
    (Godot auto-reimport briefly holds the PNG). Returns True on success."""
    tmp = dst.with_suffix(".tmp.png")
    for attempt in range(retries):
        try:
            im.save(tmp, "PNG")
            os.replace(tmp, dst)
            return True
        except OSError as e:
            if tmp.exists():
                try:
                    tmp.unlink()
                except OSError:
                    pass
            if attempt == retries - 1:
                print(f"    LOCKED after {retries} tries ({e}): {dst.name}")
                return False
            time.sleep(delay)
    return False

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]   # MMO repo root (this staging dir is art_src/<name>/)
OPEN_DIR = ROOT / "game" / "assets" / "sprites" / "opening"
FITTED = HERE / "fitted"

# frame-name (relative to opening/) -> reskin source (staging dir / file)
# ch1 plates live at opening/<name>.png; chN plates at opening/chapters/<name>.png
TARGET_W, TARGET_H = 1672, 941  # sibling plate geometry (16:9)


def frame_paths():
    """Map each staging tag -> (reskin_png, install_path) using frames.txt."""
    out = []
    for line in (HERE / "frames.txt").read_text().split():
        line = line.strip()
        if not line:
            continue
        name = line.split("/")[-1]              # opening_ch8_paladin
        tag = name.replace("opening_", "").replace("_paladin", "")  # ch8 / _0
        if name.startswith("opening_paladin_"):
            tag = name.replace("opening_paladin_", "ch1_")          # ch1_0/1/2
        # Prefer the corrected v2 (open bearded face) over the v1 (hooded) roll.
        reskin = HERE / f"{tag}_v2" / f"{name}_reskin.png"
        if not reskin.exists():
            reskin = HERE / tag / f"{name}_reskin.png"
        install = OPEN_DIR / (line + ".png")
        out.append((tag, name, reskin, install))
    return out


def fit(im: Image.Image) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    target_ar = TARGET_W / TARGET_H
    ar = w / h
    if ar > target_ar:            # too wide -> crop sides
        new_w = round(h * target_ar)
        left = (w - new_w) // 2
        im = im.crop((left, 0, left + new_w, h))
    else:                         # too tall -> crop top/bottom
        new_h = round(w / target_ar)
        top = (h - new_h) // 2
        im = im.crop((0, top, w, top + new_h))
    return im.resize((TARGET_W, TARGET_H), Image.LANCZOS)


def main() -> int:
    install = "--install" in sys.argv
    FITTED.mkdir(exist_ok=True)
    rows = []
    failed = []
    for tag, name, reskin, install_path in frame_paths():
        if not reskin.exists():
            print(f"  SKIP {tag}: no reskin at {reskin}")
            continue
        fitted = fit(Image.open(reskin))
        out = FITTED / (name + ".png")
        fitted.save(out)
        print(f"  fitted {tag}: {reskin.name} {Image.open(reskin).size} -> {fitted.size} {out.name}")
        rows.append((name, install_path, out))
        if install:
            if robust_save(fitted, install_path):
                print(f"    installed -> {install_path.name}")
            else:
                failed.append(name)
    # QA before/after sheet
    if rows:
        from PIL import ImageDraw
        cw = 520
        sheet = Image.new("RGB", (cw * 2 + 24, (len(rows)) * (150 + 18) + 8), (24, 24, 30))
        d = ImageDraw.Draw(sheet)
        for i, (name, install_path, out) in enumerate(rows):
            y = i * (150 + 18) + 18
            before = Image.open(HERE / "originals" / (name + ".png")).convert("RGB")
            before.thumbnail((cw - 8, 150 - 8))
            after = Image.open(out).convert("RGB"); after.thumbnail((cw - 8, 150 - 8))
            sheet.paste(before, (8, y)); sheet.paste(after, (cw + 16, y))
            d.text((8, y - 14), f"{name}  BEFORE", fill=(210, 180, 150))
            d.text((cw + 16, y - 14), "AFTER (reskin)", fill=(150, 210, 180))
        qa = HERE / "reskin_qa.jpg"
        sheet.save(qa, quality=88)
        print(f"\nQA sheet: {qa}")
    if failed:
        print(f"\n{len(failed)} file(s) still LOCKED (rerun once Godot releases them): {', '.join(failed)}")
        return 1
    if install:
        print(f"\nInstalled {len(rows)} plate(s) OK.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
