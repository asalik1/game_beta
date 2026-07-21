#!/usr/bin/env python3
"""Install generated NPC splashes into the game.

Copies art_src/character_splashes/generated/portrait_<key>.png ->
game/assets/sprites/splash_<name-slug>.png, keyed on the manifest NAME so the
dialogue frame's _splash_slug(speaker) resolves to it. The 1254^2 masters stay
here in art_src; only the installed copies ship.

Run: python art_src/character_splashes/install_splashes.py [--downscale N]
  --downscale N  save at NxN (default: full 1254 res, no resize)
"""
import csv
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GENERATED = HERE / "generated"
MANIFEST = HERE / "manifest.tsv"
DEST = HERE.parents[1] / "game" / "assets" / "sprites"


def slug(s: str) -> str:
    """Mirror of hud.gd _splash_slug: lower, non-alnum runs -> one '_', trimmed."""
    out, prev_us = [], True  # leading true so a leading separator can't open with '_'
    for ch in s.lower():
        if ("a" <= ch <= "z") or ("0" <= ch <= "9"):
            out.append(ch)
            prev_us = False
        elif not prev_us:
            out.append("_")
            prev_us = True
    r = "".join(out)
    return r[:-1] if r.endswith("_") else r


def main() -> int:
    downscale = 0
    if "--downscale" in sys.argv:
        downscale = int(sys.argv[sys.argv.index("--downscale") + 1])

    key_to_name = {}
    with open(MANIFEST, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            key_to_name[row["sprite"]] = row["name"]

    installed, skipped = 0, []
    for png in sorted(GENERATED.glob("portrait_*.png")):
        key = png.stem[len("portrait_"):]
        name = key_to_name.get(key)
        if not name:
            skipped.append(f"{png.name} (no manifest row for key '{key}')")
            continue
        out_name = f"splash_{slug(name)}.png"
        out_path = DEST / out_name
        if downscale:
            from PIL import Image
            im = Image.open(png).convert("RGB")
            im = im.resize((downscale, downscale), Image.LANCZOS)
            im.save(out_path, optimize=True)
        else:
            out_path.write_bytes(png.read_bytes())
        installed += 1
        print(f"  {png.name:34s} -> {out_name}   [{name}]")

    print(f"\nInstalled {installed} splash(es) into {DEST}")
    if skipped:
        print("Skipped:")
        for s in skipped:
            print(f"  - {s}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
