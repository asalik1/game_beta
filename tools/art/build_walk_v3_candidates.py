"""Build unwired V3 class-walk candidates from direction-specific masters.

Unlike the rejected corrective pass, this builder never uses connected-
component ownership to decide which opaque pixels belong to a frame.  Each V3
master is one regular horizontal strip with generous real gutters, so direct
cell crops preserve capes, hair, staves, bows, swords, and detached details.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import install_dirset  # noqa: E402
from build_ledgerbound_warlock import (  # noqa: E402
    _hard_alpha,
    _remove_green,
    _valley_separators,
)


PASS = ROOT / "art_src" / "class_corrective_pass_2026-07-31"
SRC = PASS / "walk_v3_sources"
QA = PASS / "qa_v3"
DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
LABELS = {
    "s": "S / front",
    "se": "SE / front-right",
    "e": "E / right profile",
    "ne": "NE / rear-right",
    "n": "N / back",
    "nw": "NW / rear-left",
    "w": "W / left profile",
    "sw": "SW / front-left",
}
SPECS = {
    "warrior": {"frames": 6, "body": 180, "contact": 3},
    "warlock": {"frames": 7, "body": 190, "contact": 3},
    "mage": {"frames": 8, "body": 180, "contact": 4},
    "archer": {"frames": 8, "body": 180, "contact": 4},
    "assassin": {"frames": 8, "body": 190, "contact": 4},
}
WARLOCK_APPROVED_CARDINALS = {"s", "e", "n", "w"}


def _font(size: int) -> ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/segoeuib.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _empty_run(occupancy: np.ndarray, edge: int) -> tuple[int, int] | None:
    """Return the inclusive empty-column run containing ``edge``."""

    if edge < 0 or edge >= len(occupancy) or int(occupancy[edge]) != 0:
        return None
    left = edge
    while left > 0 and int(occupancy[left - 1]) == 0:
        left -= 1
    right = edge
    while right + 1 < len(occupancy) and int(occupancy[right + 1]) == 0:
        right += 1
    return left, right


def _audited_x_edges(alpha: np.ndarray, columns: int, name: str) -> tuple[list[int], list[int]]:
    """Choose only broad, completely empty authored gutters.

    Equal-grid boundaries are preferred when ImageGen honored them.  When it
    did not, alpha clustering may locate the gutter, but it is used only as a
    locator: the actual cut is the midpoint of a contiguous empty run.  This
    never assigns or deletes connected components.
    """

    width = alpha.shape[1]
    occupancy = alpha.sum(axis=0)
    nominal = [round(index * width / columns) for index in range(columns + 1)]
    located = _valley_separators(alpha, columns, axis=1)
    edges = [0]
    gutter_widths: list[int] = []
    minimum_gutter = 8
    for index in range(1, columns):
        run = _empty_run(occupancy, nominal[index])
        if run is None or run[1] - run[0] + 1 < minimum_gutter:
            run = _empty_run(occupancy, located[index])
        if run is None or run[1] - run[0] + 1 < minimum_gutter:
            raise ValueError(
                f"unsafe frame boundary: {name} between f{index}/f{index + 1}; "
                "no broad transparent gutter"
            )
        split = round((run[0] + run[1]) / 2.0)
        if split <= edges[-1]:
            raise ValueError(f"non-increasing frame boundary: {name} {edges + [split]}")
        edges.append(split)
        gutter_widths.append(run[1] - run[0] + 1)
    edges.append(width)
    return edges, gutter_widths


def _write_cut_overlay(path: Path, keyed: Image.Image, edges: list[int], gutters: list[int]) -> None:
    overlay = keyed.copy()
    # A dark backing keeps transparent source gutters visible in the audit.
    backing = Image.new("RGBA", overlay.size, (24, 27, 33, 255))
    backing.alpha_composite(overlay)
    draw = ImageDraw.Draw(backing)
    for index, edge in enumerate(edges[1:-1], start=1):
        draw.line((edge, 0, edge, backing.height - 1), fill=(255, 72, 72, 255), width=2)
        draw.text(
            (max(2, edge - 28), 4),
            f"{index}|{index + 1} g{gutters[index - 1]}",
            font=_font(12),
            fill=(255, 230, 120, 255),
        )
    audit_dir = QA / "slice_overlays"
    audit_dir.mkdir(parents=True, exist_ok=True)
    backing.save(audit_dir / f"{path.stem}_cuts.png")


def _direct_strip(path: Path, columns: int) -> list[Image.Image]:
    keyed = _remove_green(Image.open(path).convert("RGBA"))
    width, height = keyed.size
    alpha = np.asarray(keyed.getchannel("A"), dtype=np.uint8) > 0
    x_edges, gutter_widths = _audited_x_edges(alpha, columns, path.name)
    _write_cut_overlay(path, keyed, x_edges, gutter_widths)
    frames: list[Image.Image] = []
    for column in range(columns):
        x0 = x_edges[column]
        x1 = x_edges[column + 1]
        frame = keyed.crop((x0, 0, x1, height))
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"empty V3 frame: {path.name} f{column + 1}")
        # A subject touching the authored cell edge means generation failed its
        # clearance requirement.  Do not silently pass it to normalization.
        if box[0] <= 1 or box[2] >= frame.width - 1 or box[1] <= 1 or box[3] >= frame.height - 1:
            raise ValueError(f"source-edge contact: {path.name} f{column + 1} {box}")
        frames.append(frame)
    # Rectangular partitioning must preserve every keyed source pixel.  This
    # catches accidental padding, overlap, and component-filter regressions.
    source_pixels = int(alpha.sum())
    sliced_pixels = sum(
        int((np.asarray(frame.getchannel("A"), dtype=np.uint8) > 0).sum())
        for frame in frames
    )
    if sliced_pixels != source_pixels:
        raise ValueError(
            f"non-lossless slice: {path.name} source={source_pixels} frames={sliced_pixels}"
        )
    return frames


def _normalize_direction(frames: list[Image.Image], target_body: int) -> list[Image.Image]:
    boxes = [frame.getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("empty frame")
    heights = [box[3] - box[1] for box in boxes if box is not None]
    scale = target_body / float(max(heights))
    stage, baseline = 512, 468
    result: list[Image.Image] = []
    for frame, box in zip(frames, boxes):
        assert box is not None
        figure = frame.crop(box)
        size = (max(1, round(figure.width * scale)), max(1, round(figure.height * scale)))
        figure = _hard_alpha(figure.resize(size, Image.Resampling.LANCZOS))
        if figure.width > stage - 12 or figure.height > baseline - 6:
            raise ValueError(f"normalized figure exceeds staging cell: {figure.size}")
        canvas = Image.new("RGBA", (stage, stage), (0, 0, 0, 0))
        canvas.alpha_composite(figure, ((stage - figure.width) // 2, baseline - figure.height))
        result.append(canvas)
    return result


def _frames(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    cell = strip.height
    return [strip.crop((i * cell, 0, (i + 1) * cell, cell)) for i in range(strip.width // cell)]


def _direction_frames(class_name: str, suffix: str, spec: dict[str, int]) -> list[Image.Image]:
    if class_name == "warlock" and suffix in WARLOCK_APPROVED_CARDINALS:
        # Owner-approved S/E/N/W are already normalized and installed.  Reuse
        # their exact candidate pixels; the old green masters are too tightly
        # packed to pass the new safe-gutter audit and must not be re-cut.
        frames = _frames(
            PASS / "warlock_candidate_runtime" / f"warlock_walk_{suffix}.png"
        )
        if len(frames) != spec["frames"]:
            raise ValueError(
                f"warlock {suffix}: expected {spec['frames']} approved frames, got {len(frames)}"
            )
        restaged: list[Image.Image] = []
        for frame in frames:
            box = frame.getbbox()
            if box is None:
                raise ValueError(f"empty approved Warlock frame: {suffix}")
            figure = frame.crop(box)
            canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            canvas.alpha_composite(
                figure,
                ((512 - figure.width) // 2, 468 - figure.height),
            )
            restaged.append(canvas)
        return restaged
    return _normalize_direction(
        _direct_strip(SRC / f"{class_name}_walk_{suffix}_v03.png", spec["frames"]),
        spec["body"],
    )


def _actual_frame(frame: Image.Image, body_height: int, canvas_size: int = 128) -> Image.Image:
    box = frame.getbbox()
    if box is None:
        raise ValueError("empty runtime frame")
    figure = frame.crop(box)
    scale = body_height / float(figure.height)
    figure = figure.resize(
        (max(1, round(figure.width * scale)), body_height), Image.Resampling.LANCZOS
    )
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (25, 28, 34, 255))
    canvas.alpha_composite(figure, ((canvas_size - figure.width) // 2, canvas_size - figure.height - 12))
    return canvas


def _write_qa(class_name: str, rows: dict[str, list[Image.Image]], contact: int) -> None:
    QA.mkdir(parents=True, exist_ok=True)
    count = len(rows["s"])
    preview, left, top = 196, 190, 44
    sheet = Image.new("RGBA", (left + count * preview, top + len(DIR8) * preview), (25, 28, 34, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 8), f"{class_name.upper()} V3 — DIRECT CELLS; OBSERVED FACING", font=_font(18), fill=(255, 224, 126, 255))
    for column in range(count):
        draw.text((left + column * preview + 5, 22), f"f{column + 1}", font=_font(13), fill=(255, 224, 126, 255))
    for row_index, suffix in enumerate(DIR8):
        y = top + row_index * preview
        draw.rectangle((0, y, left - 1, y + preview - 1), fill=(44, 48, 57, 255))
        draw.text((10, y + 82), LABELS[suffix], font=_font(15), fill=(238, 240, 244, 255))
        for frame_index, frame in enumerate(rows[suffix]):
            shown = _actual_frame(frame, 150, preview)
            sheet.alpha_composite(shown, (left + frame_index * preview, y))
            if frame_index in (0, contact):
                color = (88, 220, 142, 255) if frame_index == 0 else (90, 170, 255, 255)
                draw.rectangle((left + frame_index * preview + 2, y + 2, left + (frame_index + 1) * preview - 3, y + preview - 3), outline=color, width=3)
    sheet.save(QA / f"{class_name}_walk_v3_contact.png")

    # Simultaneous eight-direction preview at the real ~88 px hero body size.
    pages: list[Image.Image] = []
    for frame_index in range(count):
        page = Image.new("RGBA", (128 * 4, 128 * 2), (25, 28, 34, 255))
        for direction_index, suffix in enumerate(DIR8):
            page.alpha_composite(
                _actual_frame(rows[suffix][frame_index], 88),
                ((direction_index % 4) * 128, (direction_index // 4) * 128),
            )
        pages.append(page.convert("P", palette=Image.Palette.ADAPTIVE))
    pages[0].save(
        QA / f"{class_name}_walk_v3_actual_size.gif",
        save_all=True,
        append_images=pages[1:],
        duration=111,
        loop=0,
        disposal=2,
    )


def build_class(class_name: str) -> None:
    spec = SPECS[class_name]
    directions = {
        suffix: _direction_frames(class_name, suffix, spec)
        for suffix in DIR8
    }
    out = PASS / f"{class_name}_walk_v3_candidate"
    out.mkdir(parents=True, exist_ok=True)
    cell = install_dirset.assemble_clips(
        {f"{class_name}_walk": directions}, str(out), margin=4, symmetric=False
    )
    rows = {suffix: _frames(out / f"{class_name}_walk_{suffix}.png") for suffix in DIR8}
    _write_qa(class_name, rows, spec["contact"])
    print(f"unwired {class_name} V3: {spec['frames']} frames/direction, cell={cell}px")


def main() -> None:
    requested = sys.argv[1:] or list(SPECS)
    for class_name in requested:
        if class_name not in SPECS:
            raise ValueError(f"unknown class: {class_name}")
        build_class(class_name)


if __name__ == "__main__":
    main()
