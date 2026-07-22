"""Normalize generated skin splash masters and install them into the game."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent / "generated"
DEST = ROOT / "game" / "assets" / "sprites"
SIZE = (1254, 1254)
NAMES = (
    "splash_skin_warrior_dreadknight",
    "splash_skin_warrior_stormforged",
    "splash_skin_warrior_stormforged_awakened",
    "splash_skin_archer_frostfall_ranger",
    "splash_skin_archer_voidwraith",
    "splash_skin_archer_voidwraith_awakened",
    "splash_skin_mage_crystal_archmage",
    "splash_skin_mage_crystal_archmage_awakened",
    "splash_skin_assassin_blade_dancer",
    "splash_skin_assassin_phantom",
    "splash_skin_assassin_phantom_awakened",
    "splash_skin_paladin_eclipse_knight",
    "splash_skin_paladin_fallen_arbiter",
    "splash_skin_paladin_fallen_arbiter_awakened",
    "splash_skin_warlock_hellfire_inquisitor",
    "splash_skin_warlock_arcane_warlock",
    "splash_skin_warlock_eldritch_warlock",
)


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        source_path = SOURCE / f"{name}.png"
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        image = Image.open(source_path).convert("RGB")
        if image.size != SIZE:
            image = image.resize(SIZE, Image.Resampling.LANCZOS)
        image.save(DEST / f"{name}.png", optimize=True)
        print(f"installed {name}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
