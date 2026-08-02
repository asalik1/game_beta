"""Build consolidated review sheets/GIFs for the unwired ImageGen attack pass.

Accepted inputs are explicit so rejected experiments cannot enter a review or
runtime handoff accidentally.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path("art_src/class_attack_regen_imagegen_2026-08-02")
OUT = ROOT / "review"
DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
LABELS = {"s": "S", "se": "SE", "e": "E", "ne": "NE", "n": "N", "nw": "NW", "w": "W", "sw": "SW"}
ACCEPTED = {
    "archer": {
        "attack": {"s": 3, "se": 1, "e": 2, "ne": 2, "n": 2, "nw": 2, "w": 1, "sw": 1},
        "attack2": {"s": 2, "se": 1, "e": 3, "ne": 1, "n": 2, "nw": 2, "w": 1, "sw": 1},
    },
    "warlock": {
        "attack": {"s": 1, "se": 2, "e": 1, "ne": 1, "n": 1, "nw": 1, "w": 1, "sw": 2},
        "attack2": {"s": 2, "se": 1, "e": 3, "ne": 1, "n": 1, "nw": 1, "w": 1, "sw": 1},
    },
    "warrior": {
        "attack": {"s": 1, "se": 3, "e": 1, "ne": 2, "n": 4, "nw": 1, "w": 3, "sw": 1},
        "attack2": {"s": 2, "se": 3, "e": 3, "ne": 1, "n": 4, "nw": 1, "w": 1, "sw": 1},
    },
}
FRAMES = {"archer": 9, "warlock": 9, "warrior": 7}
CELL = 277
STABILIZED_CELL = 352


def font(size: int) -> ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/seguisb.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def accepted_path(character: str, clip: str, direction: str, version: int) -> Path:
    stem = f"{character}_{clip}_{direction}_v{version:02d}"
    return ROOT / character / f"{clip}_{direction}" / f"{stem}_candidate.png"


def stabilized_path(character: str, clip: str, direction: str, version: int) -> Path:
    stem = f"{character}_{clip}_{direction}_v{version:02d}_stabilized"
    return Path("stabilized") / character / f"{clip}_{direction}" / f"{stem}_candidate.png"


def review_source_path(character: str, clip: str, direction: str, version: int) -> Path:
    stable = ROOT / stabilized_path(character, clip, direction, version)
    return stable if stable.exists() else accepted_path(character, clip, direction, version)


def audit(path: Path, count: int) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    cell = image.height
    if cell < CELL or image.size != (cell * count, cell):
        raise ValueError(f"{path}: invalid square-cell strip {image.size}")
    histogram = image.getchannel("A").histogram()
    if any(histogram[1:255]):
        raise ValueError(f"{path}: semi-transparent pixels present")
    corners = ((0, 0), (image.width - 1, 0), (0, cell - 1), (image.width - 1, cell - 1))
    if any(image.getpixel(point)[3] for point in corners):
        raise ValueError(f"{path}: non-transparent strip corner")
    for index in range(count):
        frame = image.crop((index * cell, 0, (index + 1) * cell, cell))
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"{path}: empty frame {index + 1}")
        if box[0] <= 1 or box[2] >= cell - 1 or box[1] <= 1 or box[3] >= cell - 1:
            raise ValueError(f"{path}: frame {index + 1} touches cell edge: {box}")
    first = image.crop((0, 0, cell, cell)).getbbox()
    assert first is not None
    if first[3] - first[1] != 180:
        raise ValueError(f"{path}: frame-1 normalized height is not 180")
    return image


def frame_at(strip: Image.Image, index: int) -> Image.Image:
    cell = strip.height
    return strip.crop((index * cell, 0, (index + 1) * cell, cell))


def build_sheet(character: str, clip: str, strips: dict[str, Image.Image], count: int) -> Path:
    shown = 150
    label_w, title_h, header_h, gap = 90, 54, 30, 6
    width = label_w + count * (shown + gap) + gap
    height = title_h + header_h + len(DIRS) * (shown + gap) + gap
    canvas = Image.new("RGB", (width, height), (25, 28, 34))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, width, title_h), fill=(54, 59, 68))
    draw.text((14, 9), f"{character.title()} — {clip.upper()} — all directions", font=font(28), fill=(255, 225, 120))
    for index in range(count):
        x = label_w + index * (shown + gap)
        draw.text((x + shown // 2 - 12, title_h + 2), f"f{index + 1}", font=font(19), fill=(255, 225, 120))
    y = title_h + header_h
    for direction in DIRS:
        draw.rectangle((0, y, label_w - gap, y + shown), fill=(43, 47, 55))
        draw.text((24, y + shown // 2 - 14), LABELS[direction], font=font(25), fill=(242, 242, 246))
        for index in range(count):
            frame = frame_at(strips[direction], index).resize((shown, shown), Image.Resampling.NEAREST)
            x = label_w + index * (shown + gap)
            canvas.paste(frame, (x, y), frame)
        y += shown + gap
    path = OUT / f"{character}_{clip}_all_directions_contact.png"
    canvas.save(path, optimize=True)
    return path


def build_gif(character: str, clip: str, strips: dict[str, Image.Image], count: int) -> Path:
    shown, label_h, title_h, gap = 180, 24, 42, 8
    width = 2 * shown + 3 * gap
    height = title_h + 4 * (shown + label_h) + 5 * gap
    frames: list[Image.Image] = []
    for index in range(count):
        canvas = Image.new("RGB", (width, height), (25, 28, 34))
        draw = ImageDraw.Draw(canvas)
        draw.text((10, 7), f"{character.title()} {clip.upper()} — f{index + 1}/{count}", font=font(22), fill=(255, 225, 120))
        for slot, direction in enumerate(DIRS):
            row, col = divmod(slot, 2)
            x = gap + col * (shown + gap)
            y = title_h + gap + row * (shown + label_h + gap)
            frame = frame_at(strips[direction], index).resize((shown, shown), Image.Resampling.NEAREST)
            canvas.paste(frame, (x, y), frame)
            draw.text((x + 6, y + shown), LABELS[direction], font=font(18), fill=(242, 242, 246))
        frames.append(canvas)
    path = OUT / f"{character}_{clip}_all_directions_22fps.gif"
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=round(1000 / 22), loop=0, disposal=2, optimize=False)
    return path


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    audited = 0
    for character, clips in ACCEPTED.items():
        count = FRAMES[character]
        for clip, versions in clips.items():
            strips = {direction: audit(review_source_path(character, clip, direction, versions[direction]), count) for direction in DIRS}
            audited += len(strips)
            print("wrote", build_sheet(character, clip, strips, count))
            print("wrote", build_gif(character, clip, strips, count))
    print(f"audited {audited} accepted strips; body=180, hard alpha, edge-safe")


if __name__ == "__main__":
    main()
