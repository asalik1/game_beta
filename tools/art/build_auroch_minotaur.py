#!/usr/bin/env python3
"""Build Auroch's runtime 8-direction sprite set from image-gen masters.

The source sheets are four-frame, chroma-key-cleaned RGBA strips stored in
backup/generated_sources/auroch_minotaur.  This script finds the gutters,
normalizes each complete silhouette, aligns the feet, and writes the flat +
directional idle, walk, melee, slam, and charge files consumed by Art.gd.
"""

from pathlib import Path

from PIL import Image, ImageDraw


DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
CELL = 128
CONTENT_SIZE = 120
FEET_Y = 124
ACTION_CELL = 160
ACTION_CONTENT_SIZE = 152
ACTION_BODY_HEIGHT = 120
ACTION_FEET_Y = 154
ALPHA_CROP_THRESHOLD = 24

REPO = Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO / "backup" / "generated_sources" / "auroch_minotaur"
ACTION_SOURCE_DIR = SOURCE_DIR / "actions"
OUTPUT_DIR = REPO / "game" / "assets" / "sprites"


def _opaque_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > ALPHA_CROP_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise RuntimeError("frame contains no visible pixels")
    return bbox


def _split_boundaries(sheet: Image.Image) -> list[int]:
    """Find the three quiet vertical gutters nearest the expected quarters."""
    alpha = sheet.getchannel("A")
    counts = [
        sum(alpha.getpixel((x, y)) > ALPHA_CROP_THRESHOLD for y in range(sheet.height))
        for x in range(sheet.width)
    ]
    boundaries: list[int] = []
    radius = max(40, sheet.width // 10)
    for quarter in (1, 2, 3):
        expected = round(sheet.width * quarter / 4)
        lo = max(1, expected - radius)
        hi = min(sheet.width - 1, expected + radius + 1)
        minimum = min(counts[lo:hi])
        candidates = [x for x in range(lo, hi) if counts[x] == minimum]

        runs: list[list[int]] = []
        for x in candidates:
            if not runs or x != runs[-1][-1] + 1:
                runs.append([x])
            else:
                runs[-1].append(x)
        run = min(runs, key=lambda values: abs((values[0] + values[-1]) / 2 - expected))
        boundaries.append(round((run[0] + run[-1]) / 2))
    if boundaries != sorted(boundaries) or len(set(boundaries)) != 3:
        raise RuntimeError(f"invalid frame boundaries: {boundaries}")
    return boundaries


def _place_crop(
    crop: Image.Image, cell: int, content_size: int, feet_y: int, scale: float
) -> Image.Image:
    size = (
        max(1, round(crop.width * scale)),
        max(1, round(crop.height * scale)),
    )
    crop = crop.resize(size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    x = (cell - crop.width) // 2
    y = feet_y - crop.height
    canvas.alpha_composite(crop, (x, y))
    # Runtime sprites use the project's crisp cutout convention. The chroma
    # helper's soft matte is valuable before downsampling, but leaving that
    # matte in the final 128 px asset creates visible dark/magenta fringes and
    # trips verify_art's bleed check.
    solid_alpha = canvas.getchannel("A").point(lambda value: 255 if value > 24 else 0)
    canvas.putalpha(solid_alpha)
    return canvas


def _normalize(frame: Image.Image) -> Image.Image:
    crop = frame.crop(_opaque_bbox(frame))
    scale = min(CONTENT_SIZE / crop.width, CONTENT_SIZE / crop.height)
    return _place_crop(crop, CELL, CONTENT_SIZE, FEET_Y, scale)


def _load_frames(direction: str) -> list[Image.Image]:
    source = SOURCE_DIR / f"auroch_minotaur_walk_{direction}_transparent.png"
    sheet = Image.open(source).convert("RGBA")
    boundaries = [0, *_split_boundaries(sheet), sheet.width]
    frames = [
        _normalize(sheet.crop((boundaries[i], 0, boundaries[i + 1], sheet.height)))
        for i in range(4)
    ]
    print(f"{direction}: {sheet.size} split at {boundaries[1:-1]}")
    return frames


def _strip(frames: list[Image.Image], cell: int = CELL) -> Image.Image:
    strip = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * cell, 0))
    return strip


def _load_action_frames(action: str, direction: str) -> list[Image.Image]:
    source = ACTION_SOURCE_DIR / f"auroch_minotaur_{action}_{direction}_transparent.png"
    sheet = Image.open(source).convert("RGBA")
    boundaries = [0, *_split_boundaries(sheet), sheet.width]
    crops: list[Image.Image] = []
    for index in range(4):
        frame = sheet.crop((boundaries[index], 0, boundaries[index + 1], sheet.height))
        crops.append(frame.crop(_opaque_bbox(frame)))

    # Frame 0 is the neutral body-scale anchor. Extended weapon poses may use
    # the rest of the 160px action cell, but never enlarge the boss relative to
    # his 128px idle body or shrink one frame independently from the others.
    max_width = max(crop.width for crop in crops)
    max_height = max(crop.height for crop in crops)
    scale = min(
        ACTION_BODY_HEIGHT / crops[0].height,
        ACTION_CONTENT_SIZE / max_width,
        ACTION_CONTENT_SIZE / max_height,
    )
    frames = [
        _place_crop(crop, ACTION_CELL, ACTION_CONTENT_SIZE, ACTION_FEET_Y, scale)
        for crop in crops
    ]
    print(f"{action}/{direction}: {sheet.size} split at {boundaries[1:-1]}")
    return frames


def _write_action(action: str) -> None:
    all_frames: dict[str, list[Image.Image]] = {}
    for direction in DIRS:
        unique_frames = _load_action_frames(action, direction)
        # The generated horizontal swing's fourth recovery pose pushes the
        # anchor beyond several source-sheet cells. The first three poses are
        # complete and land contact at ~0.16s, so ship that clean sequence.
        if action == "melee":
            unique_frames = unique_frames[:3]
        # Four held poses become an eight-frame 0.57s brace at 14fps, matching
        # _do_charge's 0.58s telegraph. Melee/slam remain snappy attack clips.
        runtime_frames = (
            [copy for frame in unique_frames for copy in (frame, frame.copy())]
            if action == "charge"
            else unique_frames
        )
        all_frames[direction] = unique_frames
        _strip(runtime_frames, ACTION_CELL).save(
            OUTPUT_DIR / f"auroch_minotaur_{action}_{direction}.png", optimize=True
        )
        if direction == "s":
            _strip(runtime_frames, ACTION_CELL).save(
                OUTPUT_DIR / f"auroch_minotaur_{action}.png", optimize=True
            )

    columns = len(all_frames["s"])
    contact = Image.new(
        "RGBA", (ACTION_CELL * columns, ACTION_CELL * len(DIRS)), (25, 28, 31, 255)
    )
    draw = ImageDraw.Draw(contact)
    for row, direction in enumerate(DIRS):
        y = row * ACTION_CELL
        for col in range(columns):
            color = (42, 46, 50, 255) if (row + col) % 2 else (55, 59, 63, 255)
            draw.rectangle(
                (col * ACTION_CELL, y, (col + 1) * ACTION_CELL - 1, y + ACTION_CELL - 1),
                fill=color,
            )
        contact.alpha_composite(_strip(all_frames[direction], ACTION_CELL), (0, y))
        draw.text((4, y + 4), direction.upper(), fill=(235, 225, 198, 255))
    contact.save(ACTION_SOURCE_DIR / f"auroch_minotaur_{action}_contact.png", optimize=True)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    all_frames: dict[str, list[Image.Image]] = {}
    for direction in DIRS:
        frames = _load_frames(direction)
        all_frames[direction] = frames
        _strip(frames).save(
            OUTPUT_DIR / f"auroch_minotaur_walk_{direction}.png", optimize=True
        )
        frames[0].save(
            OUTPUT_DIR / f"auroch_minotaur_anim_{direction}.png", optimize=True
        )

    south_walk = _strip(all_frames["s"])
    south_idle = all_frames["s"][0]
    south_walk.save(OUTPUT_DIR / "auroch_minotaur_walk.png", optimize=True)
    south_idle.save(OUTPUT_DIR / "auroch_minotaur_anim.png", optimize=True)
    south_idle.save(OUTPUT_DIR / "auroch_minotaur.png", optimize=True)

    contact = Image.new("RGBA", (CELL * 4, CELL * len(DIRS)), (25, 28, 31, 255))
    draw = ImageDraw.Draw(contact)
    for row, direction in enumerate(DIRS):
        y = row * CELL
        for col in range(4):
            tile_color = (42, 46, 50, 255) if (row + col) % 2 else (55, 59, 63, 255)
            draw.rectangle((col * CELL, y, (col + 1) * CELL - 1, y + CELL - 1), fill=tile_color)
        contact.alpha_composite(_strip(all_frames[direction]), (0, y))
        draw.text((4, y + 4), direction.upper(), fill=(235, 225, 198, 255))
    contact_path = SOURCE_DIR / "auroch_minotaur_walk_contact.png"
    contact.save(contact_path, optimize=True)
    for action in ("melee", "slam", "charge"):
        _write_action(action)
    print(f"wrote runtime sprites to {OUTPUT_DIR}")
    print(f"wrote contact sheets below {SOURCE_DIR}")


if __name__ == "__main__":
    main()
