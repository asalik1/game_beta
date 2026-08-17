#!/usr/bin/env python3
"""Scholar Ivo (ch2 Crystal Deeps chronicler) — build the runtime NPC sprite from
the reviewed Codex ImageGen transparent master.

Same recipe as art_src/npcs/aldric/README.md: tight-crop the alpha body, scale it
to BODY_H px tall (LANCZOS — the roster is painterly pixel-art, not hard-pixel),
centre it on a transparent 256x256 canvas with the feet at FEET_Y, and write the
static + `_anim` pair (single-frame idle, like every other named NPC).

    python art_src/npcs/scholar_ivo/build_scholar_ivo.py            # stage into ./out
    python art_src/npcs/scholar_ivo/build_scholar_ivo.py --install  # + copy to game/assets/sprites

Splash (dialogue key-art) is NOT built here — that goes through
art_src/character_splashes/install_splashes.py off the manifest row.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
MASTER = HERE / "scholar_ivo_transparent.png"
OUT = HERE / "out"

CANVAS = 256
BODY_H = 223   # visible body height on the canvas (Aldric: 223)
FEET_Y = 238   # bottom alpha row (Aldric: 238)
BASE = "scholar_ivo"


def build() -> Image.Image:
    im = Image.open(MASTER).convert("RGBA")
    bb = im.getbbox()
    if bb is None:
        raise SystemExit("master is fully transparent")
    body = im.crop(bb)
    s = BODY_H / body.height
    body = body.resize((max(1, round(body.width * s)), BODY_H), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(body, ((CANVAS - body.width) // 2, FEET_Y - BODY_H))
    return canvas


def main() -> int:
    install = "--install" in sys.argv
    OUT.mkdir(exist_ok=True)
    canvas = build()
    for name in (f"{BASE}.png", f"{BASE}_anim.png"):
        canvas.save(OUT / name, optimize=True)
        print(f"  wrote {OUT / name}  bbox={canvas.getbbox()}")
    if install:
        for name in (f"{BASE}.png", f"{BASE}_anim.png"):
            dst = SPRITES / name
            if dst.exists():
                bak = HERE / "backup" / name
                bak.parent.mkdir(exist_ok=True)
                shutil.copy2(dst, bak)
                print(f"  backed up {dst} -> {bak}")
            shutil.copy2(OUT / name, dst)
            print(f"  installed {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
