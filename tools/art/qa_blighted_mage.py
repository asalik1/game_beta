"""Generate motion-preview GIFs and the base-death contact sheet for Mage QA."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
OUT = ROOT / "art_src" / "mage_blighted_healer_production" / "qa"
DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
CLIPS = {
    "idle": ("anim", 5, 167),
    "walk": ("walk", 8, 111),
    "run": ("run", 7, 91),
    "dash": ("dash", 7, 38),
    "attack": ("attack", 7, 45),
    "cast": ("cast", 7, 100),
}


def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        Path(r"C:\Windows\Fonts\arialbd.ttf"),
        Path(r"C:\Windows\Fonts\arial.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _strip(path: Path) -> tuple[list[Image.Image], int]:
    image = Image.open(path).convert("RGBA")
    cell = image.height
    return [
        image.crop((index * cell, 0, (index + 1) * cell, cell))
        for index in range(image.width // cell)
    ], cell


def _motion_gif(name: str, stem: str, frames: int, duration: int) -> None:
    rows = [_strip(SPRITES / f"mage_{stem}_{suffix}.png")[0] for suffix in DIRS]
    source_cell = rows[0][0].width
    display = 148
    label = 48
    pad = 8
    width = label + display * 4 + pad * 5
    height = display * 2 + pad * 3 + 32
    font = _font(19)
    rendered: list[Image.Image] = []
    for index in range(frames):
        canvas = Image.new("RGBA", (width, height), (28, 30, 36, 255))
        draw = ImageDraw.Draw(canvas)
        draw.text((pad, 5), f"MAGE {name.upper()}  f{index + 1}", font=font,
                  fill=(255, 225, 120, 255))
        for direction_index, suffix in enumerate(DIRS):
            row, col = divmod(direction_index, 4)
            x = pad + col * (display + pad)
            y = 30 + pad + row * (display + pad)
            draw.text((x, y + 4), suffix.upper(), font=font,
                      fill=(235, 235, 240, 255))
            frame = rows[direction_index][index].resize(
                (display, display), Image.Resampling.NEAREST
            )
            canvas.alpha_composite(frame, (x, y))
        rendered.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE))
    rendered[0].save(
        OUT / f"mage_{name}_8dir.gif",
        save_all=True,
        append_images=rendered[1:],
        duration=duration,
        loop=0,
        disposal=2,
    )


def _death_qa() -> None:
    frames, cell = _strip(SPRITES / "mage_death.png")
    display = 220
    pad = 12
    font = _font(22)
    sheet = Image.new(
        "RGBA", (display * 3 + pad * 4, display * 3 + pad * 4 + 36),
        (28, 30, 36, 255),
    )
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 6), "MAGE DEATH — 9-frame base contract", font=font,
              fill=(255, 225, 120, 255))
    gif_frames: list[Image.Image] = []
    for index, frame in enumerate(frames):
        resized = frame.resize((display, display), Image.Resampling.NEAREST)
        row, col = divmod(index, 3)
        x = pad + col * (display + pad)
        y = 36 + pad + row * (display + pad)
        sheet.alpha_composite(resized, (x, y))
        draw.text((x + 6, y + 4), f"f{index + 1}", font=font,
                  fill=(255, 225, 120, 255))
        gif_frames.append(resized.convert("P", palette=Image.Palette.ADAPTIVE))
    sheet.convert("RGB").save(OUT / "mage_death.png")
    gif_frames[0].save(
        OUT / "mage_death.gif",
        save_all=True,
        append_images=gif_frames[1:],
        duration=111,
        loop=0,
        disposal=2,
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (stem, frames, duration) in CLIPS.items():
        _motion_gif(name, stem, frames, duration)
    _death_qa()
    print(f"wrote {len(CLIPS) + 1} motion GIFs + death contact -> {OUT}")


if __name__ == "__main__":
    main()
