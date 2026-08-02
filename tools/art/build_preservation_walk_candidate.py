"""Build one unwired preservation-upscale walk direction and its QA proofs.

The input is a single ImageGen row with broad chroma-green gutters. The builder
hard-keys the source, auto-detects the authored figure count from those gutters,
proves that every cut falls inside a genuinely empty authored gutter,
normalizes the whole direction from frame 1's scale, and emits a transparent
strip plus source-size and gameplay-size QA. ``--frames`` is an optional
assertion, never an instruction to merge or discard detected figures.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_ledgerbound_warlock import (  # noqa: E402
    _hard_alpha,
    _remove_green,
    _valley_separators,
)


def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/seguisb.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _empty_run(occupancy: np.ndarray, edge: int) -> tuple[int, int] | None:
    if edge < 0 or edge >= len(occupancy) or int(occupancy[edge]) != 0:
        return None
    left = edge
    while left > 0 and int(occupancy[left - 1]) == 0:
        left -= 1
    right = edge
    while right + 1 < len(occupancy) and int(occupancy[right + 1]) == 0:
        right += 1
    return left, right


def _safe_edges(alpha: np.ndarray, columns: int) -> tuple[list[int], list[int]]:
    width = alpha.shape[1]
    occupancy = alpha.sum(axis=0)
    located = _valley_separators(alpha, columns, axis=1)
    nominal = [round(i * width / columns) for i in range(columns + 1)]
    edges = [0]
    gutters: list[int] = []
    for index in range(1, columns):
        run = _empty_run(occupancy, nominal[index])
        if run is None or run[1] - run[0] + 1 < 8:
            run = _empty_run(occupancy, located[index])
        if run is None or run[1] - run[0] + 1 < 8:
            raise ValueError(
                f"unsafe boundary between f{index} and f{index + 1}: "
                "no broad zero-occupancy gutter"
            )
        edge = round((run[0] + run[1]) / 2.0)
        if edge <= edges[-1]:
            raise ValueError(f"non-increasing frame edges: {edges + [edge]}")
        edges.append(edge)
        gutters.append(run[1] - run[0] + 1)
    edges.append(width)
    return edges, gutters


def _infer_columns(alpha: np.ndarray) -> int:
    """Count authored figures separated by broad empty vertical gutters."""

    occupancy = alpha.any(axis=0)
    used = np.flatnonzero(occupancy)
    if used.size == 0:
        raise ValueError("cannot infer frames from an empty keyed source")
    left, right = int(used[0]), int(used[-1])
    empty = ~occupancy[left : right + 1]
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for offset, is_empty in enumerate(empty):
        if is_empty and start is None:
            start = offset
        elif not is_empty and start is not None:
            runs.append((start + left, offset - 1 + left))
            start = None
    if start is not None:
        runs.append((start + left, right))
    # The preservation-source contract requires broad authored gutters. Tiny
    # holes inside a silhouette are not separators; eight empty columns is the
    # same safety floor used by _safe_edges.
    separators = [run for run in runs if run[1] - run[0] + 1 >= 8]
    columns = len(separators) + 1
    if columns < 1:
        raise ValueError("could not infer a positive frame count")
    return columns


def _crop_frames(
    keyed: Image.Image, columns: int
) -> tuple[list[Image.Image], list[int], list[int]]:
    alpha = np.asarray(keyed.getchannel("A"), dtype=np.uint8) > 0
    edges, gutters = _safe_edges(alpha, columns)
    frames: list[Image.Image] = []
    for index in range(columns):
        frame = keyed.crop((edges[index], 0, edges[index + 1], keyed.height))
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"empty generated frame f{index + 1}")
        if box[0] <= 1 or box[2] >= frame.width - 1:
            raise ValueError(f"frame f{index + 1} touches its horizontal cell edge")
        frames.append(frame)
    source_pixels = int(alpha.sum())
    sliced_pixels = sum(
        int((np.asarray(frame.getchannel("A"), dtype=np.uint8) > 0).sum())
        for frame in frames
    )
    if source_pixels != sliced_pixels:
        raise ValueError(
            f"non-lossless slice: source={source_pixels}, frames={sliced_pixels}"
        )
    return frames, edges, gutters


def _normalize(frames: list[Image.Image], body: int) -> list[Image.Image]:
    boxes = [frame.getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("empty frame")
    first = boxes[0]
    assert first is not None
    reference_height = first[3] - first[1]
    scale = body / float(reference_height)
    cell, baseline = 277, 255
    normalized: list[Image.Image] = []
    for index, (frame, box) in enumerate(zip(frames, boxes, strict=True)):
        assert box is not None
        figure = frame.crop(box)
        size = (
            max(1, round(figure.width * scale)),
            max(1, round(figure.height * scale)),
        )
        figure = _hard_alpha(figure.resize(size, Image.Resampling.LANCZOS))
        if figure.width > cell - 8 or figure.height > baseline - 4:
            raise ValueError(f"normalized f{index + 1} exceeds staging cell: {figure.size}")
        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        canvas.alpha_composite(figure, ((cell - figure.width) // 2, baseline - figure.height))
        normalized.append(canvas)
    return normalized


def _shown(frame: Image.Image, body: int, cell: int) -> Image.Image:
    box = frame.getbbox()
    if box is None:
        raise ValueError("empty normalized frame")
    figure = frame.crop(box)
    scale = body / float(figure.height)
    figure = figure.resize(
        (max(1, round(figure.width * scale)), body), Image.Resampling.LANCZOS
    )
    canvas = Image.new("RGBA", (cell, cell), (25, 28, 34, 255))
    canvas.alpha_composite(figure, ((cell - figure.width) // 2, cell - figure.height - 10))
    return canvas


def _write_cut_overlay(
    path: Path, keyed: Image.Image, edges: list[int], gutters: list[int]
) -> None:
    canvas = Image.new("RGBA", keyed.size, (25, 28, 34, 255))
    canvas.alpha_composite(keyed)
    draw = ImageDraw.Draw(canvas)
    for index, edge in enumerate(edges[1:-1], start=1):
        draw.line((edge, 0, edge, keyed.height - 1), fill=(255, 72, 72, 255), width=2)
        draw.text(
            (max(2, edge - 32), 5),
            f"{index}|{index + 1} g{gutters[index - 1]}",
            font=_font(14),
            fill=(255, 230, 120, 255),
        )
    canvas.save(path)


def _write_qa(
    output_dir: Path,
    stem: str,
    label: str,
    frames: list[Image.Image],
    fps: float,
    opposite_contact: int,
) -> None:
    source_cell, header = 220, 42
    contact = Image.new(
        "RGBA", (source_cell * len(frames), source_cell + header), (25, 28, 34, 255)
    )
    draw = ImageDraw.Draw(contact)
    draw.text((10, 8), label, font=_font(18), fill=(255, 224, 126, 255))
    source_pages: list[Image.Image] = []
    actual_pages: list[Image.Image] = []
    for index, frame in enumerate(frames):
        shown = _shown(frame, 180, source_cell)
        contact.alpha_composite(shown, (index * source_cell, header))
        draw.text(
            (index * source_cell + 7, header + 5),
            f"f{index + 1}",
            font=_font(14),
            fill=(255, 224, 126, 255),
        )
        if index in (0, opposite_contact - 1):
            color = (88, 220, 142, 255) if index == 0 else (90, 170, 255, 255)
            draw.rectangle(
                (
                    index * source_cell + 2,
                    header + 2,
                    (index + 1) * source_cell - 3,
                    header + source_cell - 3,
                ),
                outline=color,
                width=3,
            )
        source_pages.append(shown.convert("P", palette=Image.Palette.ADAPTIVE))
        actual_pages.append(_shown(frame, 88, 128).convert("P", palette=Image.Palette.ADAPTIVE))
    contact.save(output_dir / f"{stem}_contact.png")
    # GIF stores delays in 10 ms units.  Distribute rounded delays so the
    # complete loop is closer to the requested FPS than repeating one rounded
    # per-frame value (9 FPS over six frames becomes 110/110/110/110/110/120).
    target_loop_ms = 1000.0 * len(frames) / fps
    rounded_loop_ms = round(target_loop_ms / 10.0) * 10
    base_duration = (rounded_loop_ms // len(frames) // 10) * 10
    durations = [base_duration] * len(frames)
    for index in range((rounded_loop_ms - sum(durations)) // 10):
        durations[-(index + 1)] += 10
    source_pages[0].save(
        output_dir / f"{stem}_{fps:g}fps.gif",
        save_all=True,
        append_images=source_pages[1:],
        duration=durations,
        loop=0,
        disposal=2,
    )
    actual_pages[0].save(
        output_dir / f"{stem}_actual_size_{fps:g}fps.gif",
        save_all=True,
        append_images=actual_pages[1:],
        duration=durations,
        loop=0,
        disposal=2,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--stem", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument(
        "--frames",
        type=int,
        default=0,
        help="optional expected frame count; auto-detected when omitted",
    )
    parser.add_argument("--body", type=int, default=180)
    parser.add_argument("--fps", type=float, default=9.0)
    parser.add_argument("--opposite-contact", type=int, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    keyed = _hard_alpha(_remove_green(Image.open(args.source).convert("RGBA")))
    keyed.save(args.output_dir / f"{args.stem}_keyed.png")
    alpha = np.asarray(keyed.getchannel("A"), dtype=np.uint8) > 0
    detected_frames = _infer_columns(alpha)
    if args.frames < 0:
        raise ValueError("--frames cannot be negative")
    if args.frames > 0 and args.frames != detected_frames:
        raise ValueError(
            f"source contains {detected_frames} authored figures, but "
            f"--frames requested {args.frames}; refusing to merge or discard frames"
        )
    frame_count = detected_frames
    if not 1 <= args.opposite_contact <= frame_count:
        raise ValueError(
            f"--opposite-contact {args.opposite_contact} is outside 1..{frame_count}"
        )
    frames, edges, gutters = _crop_frames(keyed, frame_count)
    _write_cut_overlay(
        args.output_dir / f"{args.stem}_cuts.png", keyed, edges, gutters
    )
    normalized = _normalize(frames, args.body)
    strip = Image.new("RGBA", (277 * len(normalized), 277), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        strip.alpha_composite(frame, (index * 277, 0))
    strip.save(args.output_dir / f"{args.stem}_candidate.png")
    _write_qa(
        args.output_dir,
        args.stem,
        args.label,
        normalized,
        args.fps,
        args.opposite_contact,
    )
    print(
        f"{args.stem}: auto-detected {len(normalized)} frames, gutters={gutters}, "
        f"cell=277, body={args.body}, fps={args.fps:g}"
    )


if __name__ == "__main__":
    main()
