"""Build production cultist strips from the generated chroma-key source sheets."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
FRAME_SIZE = 48
SUBJECT_LIMIT = 44
ALPHA_CUTOFF = 128
PALETTE_COLORS = 22
OUTLINE = (24, 16, 12, 255)


def _source_frames(path: Path, count: int) -> list[Image.Image]:
    sheet = Image.open(path).convert("RGBA")
    frames: list[Image.Image] = []
    for index in range(count):
        left = round(index * sheet.width / count)
        right = round((index + 1) * sheet.width / count)
        cell = sheet.crop((left, 0, right, sheet.height))
        alpha = cell.getchannel("A").point(lambda value: 255 if value >= 24 else 0)
        bbox = alpha.getbbox()
        if bbox is None:
            raise RuntimeError(f"frame {index} in {path.name} has no visible subject")
        frames.append(cell.crop(bbox))
    return frames


def _shared_scale(frames: list[Image.Image]) -> float:
    widest = max(frame.width for frame in frames)
    tallest = max(frame.height for frame in frames)
    return min(SUBJECT_LIMIT / widest, SUBJECT_LIMIT / tallest)


def _normalized_frames(frames: list[Image.Image]) -> list[Image.Image]:
    scale = _shared_scale(frames)
    normalized: list[Image.Image] = []
    for source in frames:
        width = max(1, round(source.width * scale))
        height = max(1, round(source.height * scale))
        sprite = source.resize((width, height), Image.Resampling.LANCZOS)
        alpha = sprite.getchannel("A").point(
            lambda value: 255 if value >= ALPHA_CUTOFF else 0
        )
        sprite.putalpha(alpha)
        frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        x = (FRAME_SIZE - width) // 2
        y = FRAME_SIZE - 2 - height
        frame.alpha_composite(sprite, (x, y))
        normalized.append(frame)
    return normalized


def _shared_palette(frames: list[Image.Image]) -> Image.Image:
    colors: list[tuple[int, int, int]] = []
    for frame in frames:
        colors.extend(
            pixel[:3]
            for pixel in frame.get_flattened_data()
            if pixel[3] >= ALPHA_CUTOFF
        )
    sample = Image.new("RGB", (len(colors), 1))
    sample.putdata(colors)
    return sample.quantize(colors=PALETTE_COLORS, method=Image.Quantize.MEDIANCUT)


def _quantize(frames: list[Image.Image], palette: Image.Image) -> list[Image.Image]:
    output: list[Image.Image] = []
    for frame in frames:
        alpha = frame.getchannel("A")
        rgb = frame.convert("RGB").quantize(
            palette=palette, dither=Image.Dither.NONE
        ).convert("RGB")
        rgb.putalpha(alpha)
        output.append(rgb)
    return output


def _outline(frame: Image.Image) -> Image.Image:
    output = frame.copy()
    alpha = frame.getchannel("A")
    source = alpha.load()
    target = output.load()
    width, height = frame.size
    for y in range(height):
        for x in range(width):
            if source[x, y] != 0:
                continue
            if any(
                0 <= x + dx < width
                and 0 <= y + dy < height
                and source[x + dx, y + dy] != 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ):
                target[x, y] = OUTLINE
    return output


def _save_strip(frames: list[Image.Image], path: Path) -> None:
    strip = Image.new(
        "RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0)
    )
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(path, optimize=True)


def main() -> None:
    idle = _normalized_frames(
        _source_frames(ROOT / "cultist_idle_sheet_alpha.png", 4)
    )
    walk = _normalized_frames(
        _source_frames(ROOT / "cultist_walk_sheet_alpha.png", 6)
    )
    palette = _shared_palette(idle + walk)
    idle = [_outline(frame) for frame in _quantize(idle, palette)]
    walk = [_outline(frame) for frame in _quantize(walk, palette)]

    runtime = ROOT / "runtime"
    _save_strip(idle, runtime / "cultist_anim.png")
    _save_strip(walk, runtime / "cultist_walk.png")
    idle[0].save(runtime / "cultist.png", optimize=True)


if __name__ == "__main__":
    main()
