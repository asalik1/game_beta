"""Build the 35 Crownless crafting-material icons from generated sources.

The source renders use a flat magenta background. This script routes them
through the project's existing clean_sprite pipeline, writes 32x32 transparent
production icons, and emits a labelled QA contact sheet.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image, ImageDraw

from clean_sprite import clean


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "art_src" / "materials_2026-07-30"
DEFAULT_OUTPUT = ROOT / "game" / "assets" / "icons" / "materials"
GRADES = ("F", "E", "D", "C", "B", "A", "S")
FAMILIES = ("Metal", "Cloth", "Bone", "Reagent", "Herb")


def build(source_root: Path, output_root: Path) -> list[dict]:
    manifest = json.loads((source_root / "manifest.json").read_text(encoding="utf-8"))
    materials: list[dict] = manifest["materials"]
    output_root.mkdir(parents=True, exist_ok=True)

    # clean_sprite's keying and blob passes are pixel-wise. Pre-shrink the
    # blocky 1024px generation sources to 256px with NEAREST so the same
    # silhouette is processed about 16x faster without softening its pixels.
    with TemporaryDirectory(prefix="crownless-material-icons-") as temp_dir:
        temp_root = Path(temp_dir)
        for material in materials:
            key = material["key"]
            src = source_root / "sources" / f"{key}.png"
            if not src.exists():
                raise FileNotFoundError(f"Missing source: {src}")
            prepared = temp_root / f"{key}.png"
            image = Image.open(src).convert("RGBA")
            image.resize((256, 256), Image.Resampling.NEAREST).save(prepared)
            out = output_root / f"{key}.png"
            clean(
                prepared,
                out,
                size=32,
                colors=16,
                thresh=78,
                gamma=0.86,
                key=(255, 0, 255),
            )
    return materials


def contact_sheet(materials: list[dict], output_root: Path, out: Path) -> None:
    scale = 4
    cell = 32 * scale
    label_h = 24
    left = 118
    top = 30
    sheet = Image.new(
        "RGBA",
        (left + len(GRADES) * cell, top + len(FAMILIES) * (cell + label_h)),
        (19, 16, 23, 255),
    )
    draw = ImageDraw.Draw(sheet)

    for column, grade in enumerate(GRADES):
        draw.text((left + column * cell + 58, 8), grade, fill=(235, 228, 213, 255))

    lookup = {(m["family"], m["grade"]): m for m in materials}
    for row, family in enumerate(FAMILIES):
        y = top + row * (cell + label_h)
        draw.text((10, y + 54), family, fill=(235, 228, 213, 255))
        for column, grade in enumerate(GRADES):
            material = lookup[(family, grade)]
            icon = Image.open(output_root / f"{material['key']}.png").convert("RGBA")
            icon = icon.resize((cell, cell), Image.Resampling.NEAREST)
            x = left + column * cell
            sheet.alpha_composite(icon, (x, y))
            label = material["name"]
            if len(label) > 20:
                label = label[:19] + "…"
            draw.text((x + 4, y + cell + 3), label, fill=(190, 181, 168, 255))

    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out, quality=95)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--sheet",
        type=Path,
        default=DEFAULT_SOURCE / "material_icons_contact_sheet.png",
    )
    args = parser.parse_args()
    materials = build(args.source, args.output)
    contact_sheet(materials, args.output, args.sheet)
    print(f"Built {len(materials)} material icons in {args.output}")
    print(f"Contact sheet: {args.sheet}")


if __name__ == "__main__":
    main()
