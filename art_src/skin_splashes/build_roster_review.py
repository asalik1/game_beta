"""Build an enlarged contact sheet of every installed skin identity source."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from install_skin_splashes import NAMES


ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ENTRIES = [
    ("Dreadknight", "skins/elite/warrior_dreadknight"),
    ("Stormforged", "skins/mythic/warrior_stormforged"),
    ("Stormforged Awakened", "skins/mythic/warrior_stormforged_awakened"),
    ("Frostfall Ranger", "skins/elite/archer_frostfall_ranger"),
    ("Voidwraith", "skins/mythic/archer_voidwraith"),
    ("Voidwraith Awakened", "skins/mythic/archer_voidwraith_awakened"),
    ("Crystal Archmage", "skins/mythic/mage_crystal_archmage"),
    ("Crystal Archmage Awakened", "skins/mythic/mage_crystal_archmage_awakened"),
    ("Golden Ronin", "skins/elite/assassin_blade_dancer"),
    ("Phantom", "skins/mythic/assassin_phantom"),
    ("Nightfang (Awakened)", "skins/mythic/assassin_phantom_awakened"),
    ("Eclipse Knight", "skins/elite/paladin_eclipse_knight"),
    ("Fallen Arbiter", "skins/mythic/paladin_fallen_arbiter"),
    ("Fallen Arbiter Awakened", "skins/mythic/paladin_fallen_arbiter_awakened"),
    ("Hellfire Inquisitor", "skins/elite/warlock_hellfire_inquisitor"),
    ("Arcane Warlock", "skins/mythic/warlock_eldritch_herald"),
    ("Eldritch Warlock", "skins/elite/mage_void_weaver"),
]


def main() -> None:
    cols = 4
    cell_w, cell_h = 300, 300
    rows = (len(ENTRIES) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (20, 20, 26))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)

    for index, (label, rel) in enumerate(ENTRIES):
        source = Image.open(ROOT / "game" / "assets" / "sprites" / f"{rel}.png").convert("RGBA")
        bbox = source.getbbox()
        if bbox:
            source = source.crop(bbox)
        scale = min(230 / source.width, 230 / source.height)
        source = source.resize(
            (max(1, round(source.width * scale)), max(1, round(source.height * scale))),
            Image.Resampling.NEAREST,
        )
        col, row = index % cols, index // cols
        x0, y0 = col * cell_w, row * cell_h
        checker = Image.new("RGB", (cell_w - 16, 246), (38, 38, 48))
        sheet.paste(checker, (x0 + 8, y0 + 8))
        sheet.paste(
            source,
            (x0 + (cell_w - source.width) // 2, y0 + 12 + (230 - source.height)),
            source,
        )
        draw.text((x0 + 12, y0 + 264), label, fill=(235, 220, 170), font=font)

    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / "roster_review.png", optimize=True)

    base_classes = ("warrior", "archer", "mage", "assassin", "paladin", "warlock")
    base_sheet = Image.new("RGB", (3 * 420, 2 * 420), (17, 18, 24))
    for index, cls in enumerate(base_classes):
        image = Image.open(
            ROOT / "game" / "assets" / "sprites" / f"class_splash_{cls}.png"
        ).convert("RGB")
        image.thumbnail((400, 400), Image.Resampling.LANCZOS)
        x = (index % 3) * 420 + 10
        y = (index // 3) * 420 + 10
        base_sheet.paste(image, (x, y))
    base_sheet.save(OUT / "base_style_review.png", optimize=True)

    generated_sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (20, 20, 26))
    generated_draw = ImageDraw.Draw(generated_sheet)
    for index, ((label, _rel), name) in enumerate(zip(ENTRIES, NAMES)):
        source = Image.open(OUT / "generated" / f"{name}.png").convert("RGB")
        source.thumbnail((284, 246), Image.Resampling.LANCZOS)
        col, row = index % cols, index // cols
        x0, y0 = col * cell_w, row * cell_h
        generated_sheet.paste(source, (x0 + (cell_w - source.width) // 2, y0 + 8))
        generated_draw.text((x0 + 12, y0 + 264), label, fill=(235, 220, 170), font=font)
    generated_sheet.save(OUT / "generated_review.png", optimize=True)


if __name__ == "__main__":
    main()
