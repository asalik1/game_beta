#!/usr/bin/env python
"""Crop the six generated 4x3 talent atlases into engine-ready 64px icons.

The source sheets live in art_src/talent_icons_generated. Each cell contains
one alpha-keyed circular medallion. Reading order follows Skills.TREES.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src" / "talent_icons_generated"
DEST = ROOT / "game" / "assets" / "icons"
ICON_SIZE = 64
MEDALLION_SIZE = 60

TALENT_IDS = {
    "warrior": ["w00", "w01", "w02", "w10", "w11", "w12",
                "w20", "w21", "w22", "w30", "w31", "w32"],
    "archer": ["a00", "a01", "a02", "a10", "a11", "a12",
               "a20", "a21", "a22", "a30", "a31", "a32"],
    "mage": ["m00", "m01", "m02", "m10", "m11", "m12",
             "m20", "m21", "m22", "m30", "m31", "m32"],
    "assassin": ["s00", "s01", "s02", "s10", "s11", "s12",
                 "s20", "s21", "s22", "s30", "s31", "s32"],
    "paladin": ["p00", "p01", "p02", "p10", "p11", "p12",
                "p20", "p21", "p22", "p30", "p31", "p32"],
    "warlock": ["k00", "k01", "k02", "k10", "k11", "k12",
                "k20", "k21", "k22", "k30", "k31", "k32"],
}


def normalized_icon(cell: Image.Image) -> Image.Image:
    alpha = cell.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("atlas cell has no visible medallion")
    medallion = cell.crop(bbox)
    scale = min(MEDALLION_SIZE / medallion.width,
                MEDALLION_SIZE / medallion.height)
    size = (max(1, round(medallion.width * scale)),
            max(1, round(medallion.height * scale)))
    medallion = medallion.resize(size, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    out.alpha_composite(
        medallion,
        ((ICON_SIZE - medallion.width) // 2,
         (ICON_SIZE - medallion.height) // 2),
    )
    return out


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    contact = Image.new("RGBA", (12 * ICON_SIZE, 6 * ICON_SIZE), (16, 14, 22, 255))
    for class_row, (class_id, talent_ids) in enumerate(TALENT_IDS.items()):
        source_path = SOURCE / f"{class_id}_sheet_alpha.png"
        sheet = Image.open(source_path).convert("RGBA")
        if sheet.width % 4 or sheet.height % 3:
            raise ValueError(f"{source_path} is not an exact 4x3 atlas")
        cell_w = sheet.width // 4
        cell_h = sheet.height // 3
        for index, talent_id in enumerate(talent_ids):
            row, col = divmod(index, 4)
            cell = sheet.crop((
                col * cell_w,
                row * cell_h,
                (col + 1) * cell_w,
                (row + 1) * cell_h,
            ))
            icon = normalized_icon(cell)
            icon.save(DEST / f"talent_{talent_id}.png")
            contact.alpha_composite(icon, (index * ICON_SIZE, class_row * ICON_SIZE))
    contact.save(SOURCE / "contact_sheet_64.png")
    print(f"Installed {sum(map(len, TALENT_IDS.values()))} talent icons in {DEST}")


if __name__ == "__main__":
    main()
