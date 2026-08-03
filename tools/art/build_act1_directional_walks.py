#!/usr/bin/env python3
"""Build reviewed 5x4 Act 1 ImageGen masters into 8-direction walk strips."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src" / "Custom" / "Act1DirectionalWalks_2026-08-03"
CYCLE_SOURCE = ROOT / "art_src" / "Custom" / "Act1DirectionalWalkCycles_2026-08-03"
SPRITES = ROOT / "game" / "assets" / "sprites"
TARGET_CELL = 256
ROWS = ("s", "sw", "w", "nw", "n")
DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
MIRRORS = {"se": "sw", "e": "w", "ne": "nw"}


def remove_green(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA")).copy()
    rgb = rgba[..., :3].astype(np.int16)
    border = np.concatenate(
        (rgb[:12].reshape(-1, 3), rgb[-12:].reshape(-1, 3),
         rgb[:, :12].reshape(-1, 3), rgb[:, -12:].reshape(-1, 3))
    )
    key = np.median(border, axis=0)
    distance = np.max(np.abs(rgb - key), axis=2)
    green_dominance = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
    key_like = (distance < 34) | ((green_dominance > 38) & (rgb[..., 1] > 120))
    rgba[..., 3][key_like] = 0
    rgba[..., 3][rgba[..., 3] < 96] = 0
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def alpha_box(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A")) > 32
    ys, xs = np.where(alpha)
    if not len(xs):
        raise ValueError("empty generated sprite cell")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def original_metrics(key: str, sprites: Path) -> tuple[float, float]:
    walk = Image.open(sprites / f"{key}_walk.png").convert("RGBA")
    cell = walk.height
    box = alpha_box(walk.crop((0, 0, cell, cell)))
    return (box[3] - box[1]) / cell, box[3] / cell


def content_bands(active: np.ndarray, join_gap: int, min_span: int) -> list[tuple[int, int]]:
    indexes = np.where(active)[0]
    if not len(indexes):
        return []
    bands = []
    start = previous = int(indexes[0])
    for value in indexes[1:]:
        value = int(value)
        if value - previous > join_gap:
            if previous + 1 - start >= min_span:
                bands.append((start, previous + 1))
            start = value
        previous = value
    if previous + 1 - start >= min_span:
        bands.append((start, previous + 1))
    return bands


def source_cells(master: Image.Image) -> dict[str, list[Image.Image]]:
    clean = remove_green(master)
    alpha = np.asarray(clean.getchannel("A")) > 32
    y_bands = content_bands(alpha.any(axis=1), max(3, master.height // 180),
                            master.height // 20)
    if len(y_bands) != 5:
        raise ValueError(f"expected 5 sprite rows, found {len(y_bands)}")
    rows: dict[str, list[Image.Image]] = {}
    for direction, (y0, y1) in zip(ROWS, y_bands):
        x_bands = content_bands(alpha[y0:y1].any(axis=0), master.width // 32,
                                master.width // 24)
        if len(x_bands) != 4:
            raise ValueError(
                f"{direction}: expected 4 sprite columns, found {len(x_bands)}"
            )
        frames = []
        for x0, x1 in x_bands:
            frames.append(clean.crop((x0, y0, x1, y1)))
        rows[direction] = frames
    return rows


def single_row_cells(master: Image.Image) -> list[Image.Image]:
    clean = remove_green(master)
    alpha = np.asarray(clean.getchannel("A")) > 32
    y_bands = content_bands(alpha.any(axis=1), max(3, master.height // 180),
                            master.height // 5)
    if len(y_bands) != 1:
        raise ValueError(f"expected 1 override row, found {len(y_bands)}")
    y0, y1 = y_bands[0]
    x_bands = content_bands(alpha[y0:y1].any(axis=0), master.width // 32,
                            master.width // 24)
    if len(x_bands) != 4:
        raise ValueError(f"expected 4 override columns, found {len(x_bands)}")
    return [clean.crop((x0, y0, x1, y1)) for x0, x1 in x_bands]


def match_row_scale(frames: list[Image.Image], reference: list[Image.Image]) -> list[Image.Image]:
    source_heights = sorted(alpha_box(frame)[3] - alpha_box(frame)[1]
                            for frame in frames)
    reference_heights = sorted(alpha_box(frame)[3] - alpha_box(frame)[1]
                               for frame in reference)
    factor = reference_heights[len(reference_heights) // 2] / float(
        source_heights[len(source_heights) // 2]
    )
    return [frame.resize((max(1, round(frame.width * factor)),
                          max(1, round(frame.height * factor))),
                         Image.Resampling.LANCZOS)
            for frame in frames]


def normalize(rows: dict[str, list[Image.Image]], body_ratio: float,
              foot_ratio: float, derive_mirrors: bool = True) -> dict[str, list[Image.Image]]:
    boxes = [alpha_box(frame) for frames in rows.values() for frame in frames]
    heights = sorted(box[3] - box[1] for box in boxes)
    median_height = float(heights[len(heights) // 2])
    max_width = float(max(box[2] - box[0] for box in boxes))
    scale = min((TARGET_CELL * body_ratio) / median_height,
                (TARGET_CELL * 0.90) / max_width)
    ground_y = min(TARGET_CELL - 3, round(TARGET_CELL * foot_ratio))
    output: dict[str, list[Image.Image]] = {}
    for direction, frames in rows.items():
        built = []
        for frame in frames:
            subject = frame.crop(alpha_box(frame))
            size = (max(1, round(subject.width * scale)),
                    max(1, round(subject.height * scale)))
            subject = subject.resize(size, Image.Resampling.LANCZOS)
            data = np.asarray(subject).copy()
            data[..., 3] = np.where(data[..., 3] >= 96, 255, 0).astype(np.uint8)
            subject = Image.fromarray(data, "RGBA")
            canvas = Image.new("RGBA", (TARGET_CELL, TARGET_CELL))
            canvas.alpha_composite(subject,
                                   ((TARGET_CELL - subject.width) // 2,
                                    ground_y - subject.height))
            built.append(canvas)
        output[direction] = built
    if derive_mirrors:
        for target, source in MIRRORS.items():
            output[target] = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                              for frame in output[source]]
    return output


def save_strip(frames: list[Image.Image], path: Path) -> None:
    strip = Image.new("RGBA", (TARGET_CELL * len(frames), TARGET_CELL))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * TARGET_CELL, 0))
    strip.save(path, optimize=True)


def build(master_path: Path, sprites: Path, cycles: Path) -> list[Path]:
    key = master_path.stem.removesuffix("_directional_walk_master")
    cycle_paths = {direction: cycles / f"{key}_walk_{direction}_cycle.png"
                   for direction in DIRS}
    has_individual_cycles = all(path.exists() for path in cycle_paths.values())
    if has_individual_cycles:
        # A reviewed per-direction cycle is always preferred over a compound
        # master.  Each source came from its own generator call, so temporal
        # identity is scoped to one actual runtime animation.
        source = {direction: single_row_cells(Image.open(path).convert("RGBA"))
                  for direction, path in cycle_paths.items()}
    else:
        source = source_cells(Image.open(master_path).convert("RGBA"))
        north_override = master_path.with_name(f"{key}_north_walk_override.png")
        if north_override.exists():
            override = single_row_cells(Image.open(north_override).convert("RGBA"))
            source["n"] = match_row_scale(override, source["n"])
    rows = normalize(source, *original_metrics(key, SPRITES),
                     derive_mirrors=not has_individual_cycles)
    written = []
    for direction in DIRS:
        path = sprites / f"{key}_walk_{direction}.png"
        save_strip(rows[direction], path)
        written.append(path)
    return written


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--cycles", type=Path, default=CYCLE_SOURCE)
    parser.add_argument("--out", type=Path, default=SPRITES)
    parser.add_argument("--keys", nargs="*")
    args = parser.parse_args()
    masters = sorted(args.source.glob("*_directional_walk_master.png"))
    if args.keys:
        wanted = set(args.keys)
        masters = [path for path in masters
                   if path.stem.removesuffix("_directional_walk_master") in wanted]
    if not masters:
        raise FileNotFoundError(f"no directional walk masters in {args.source}")
    args.out.mkdir(parents=True, exist_ok=True)
    written = [path for master in masters for path in build(master, args.out, args.cycles)]
    print(f"built {len(masters)} Act 1 directional walks ({len(written)} strips)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
