"""Build the approved Blighted Healer Mage sprite family.

The built-in ImageGen masters live in
``art_src/mage_blighted_healer_production``.  This builder keys their green
field, slices the real generated gutters, normalizes every clip to one body
scale/baseline, derives the west facings from the approved east facings, and
installs the existing Mage runtime contract without touching ancillary
``mage_crystal_*`` / ``mage_void_*`` effect art.

Run from the repository root with the bundled Pillow/NumPy interpreter:

    python tools/art/build_blighted_mage.py
"""

from __future__ import annotations

import os
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ART_SRC = Path(
    os.environ.get(
        "CROWNLESS_ART_SRC",
        ROOT / "art_src" / "mage_blighted_healer_production",
    )
)
OUT_DIR = Path(
    os.environ.get(
        "CROWNLESS_GAME_SPRITES",
        ROOT / "game" / "assets" / "sprites",
    )
)

TARGET_STANDING_BODY = 180.0
STAGING_CELL = 384
STAGING_BASELINE = 350
AUTHORED_DIRS = ("s", "se", "e", "ne", "n")
ALL_DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
MIRROR = {"nw": "ne", "w": "e", "sw": "se"}
FRAME_COUNTS = {
    "mage_anim": 5,
    "mage_walk": 8,
    "mage_run": 7,
    "mage_attack": 7,
    "mage_cast": 7,
    "mage_dash": 7,
    "mage_death": 9,
}


def _remove_green(image: Image.Image) -> Image.Image:
    """Hard-key the neon field while preserving the dark blighted greens."""

    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = arr[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    strongest_other = np.maximum(red, blue)
    keyed = (
        (green > 64.0)
        & ((green - strongest_other) > 32.0)
        & (green > red * 1.18)
        & (green > blue * 1.18)
    )
    arr[..., 3] = np.where(keyed, 0, 255).astype(np.uint8)
    arr[keyed, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _valley_separators(mask: np.ndarray, count: int, axis: int) -> list[int]:
    """Place cuts in real empty gutters instead of ideal equal cells."""

    extent = mask.shape[axis]
    if count == 1:
        return [0, extent]
    projection = mask.sum(axis=1 - axis).astype(np.float64)
    coords = np.arange(extent, dtype=np.float64)
    total = projection.sum()
    if total <= 0:
        return [round(index * extent / count) for index in range(count + 1)]

    cumulative = np.cumsum(projection)
    centers = np.array(
        [
            np.searchsorted(cumulative, total * (index + 0.5) / count)
            for index in range(count)
        ],
        dtype=np.float64,
    )
    for _ in range(24):
        assignment = np.argmin(
            np.abs(coords[:, None] - centers[None, :]), axis=1
        )
        updated = centers.copy()
        for index in range(count):
            selected = assignment == index
            weight = projection[selected].sum()
            if weight > 0:
                updated[index] = (
                    coords[selected] * projection[selected]
                ).sum() / weight
        if np.max(np.abs(updated - centers)) < 0.05:
            centers = updated
            break
        centers = updated

    separators = [0]
    for index in range(1, count):
        target = round((centers[index - 1] + centers[index]) / 2.0)
        lo = max(separators[-1] + 1, round(centers[index - 1]))
        hi = min(extent - 1, round(centers[index]))
        empty = projection[lo : hi + 1] == 0
        runs: list[tuple[int, int]] = []
        start: int | None = None
        for offset, is_empty in enumerate(empty):
            if is_empty and start is None:
                start = offset
            elif not is_empty and start is not None:
                runs.append((lo + start, lo + offset - 1))
                start = None
        if start is not None:
            runs.append((lo + start, hi))
        if runs:
            a, b = max(
                runs,
                key=lambda run: (
                    -abs(((run[0] + run[1]) / 2.0) - target),
                    run[1] - run[0] + 1,
                ),
            )
            split = round((a + b) / 2.0)
        else:
            local = projection[lo : hi + 1]
            candidates = np.flatnonzero(local == local.min()) + lo
            split = int(candidates[np.argmin(np.abs(candidates - target))])
        separators.append(split)
    separators.append(extent)
    return separators


def _grid(path: Path, rows: int, cols: int) -> list[list[Image.Image]]:
    image = _remove_green(Image.open(path).convert("RGBA"))
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 0
    y_edges = _valley_separators(alpha, rows, axis=0)
    x_edges = _valley_separators(alpha, cols, axis=1)
    return [
        [
            image.crop(
                (
                    x_edges[col],
                    y_edges[row],
                    x_edges[col + 1],
                    y_edges[row + 1],
                )
            )
            for col in range(cols)
        ]
        for row in range(rows)
    ]


def _nominal_grid(
    path: Path, rows: int, cols: int
) -> list[list[Image.Image]]:
    """Slice a regular generator grid without letting a tall staff become a pose.

    The combined cast master has wide raised-staff frames whose separate visual
    mass confuses weighted pose-center clustering.  Its rows/columns are
    regular, so search for the lowest-occupancy gutter around each nominal
    boundary instead.
    """

    image = _remove_green(Image.open(path).convert("RGBA"))
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 0

    def edges(count: int, axis: int) -> list[int]:
        extent = alpha.shape[axis]
        projection = alpha.sum(axis=1 - axis)
        out = [0]
        radius = max(8, round(extent / count * 0.45))
        for index in range(1, count):
            target = round(index * extent / count)
            lo = max(out[-1] + 1, target - radius)
            hi = min(extent - 1, target + radius)
            local = projection[lo : hi + 1]
            minimum = local.min()
            candidates = np.flatnonzero(local == minimum) + lo
            out.append(
                int(candidates[np.argmin(np.abs(candidates - target))])
            )
        out.append(extent)
        return out

    x_edges = edges(cols, axis=1)
    y_edges = _valley_separators(alpha, rows, axis=0)
    return [
        [
            image.crop(
                (
                    x_edges[col],
                    y_edges[row],
                    x_edges[col + 1],
                    y_edges[row + 1],
                )
            )
            for col in range(cols)
        ]
        for row in range(rows)
    ]


def _rows(path: str, count: int, frames: int) -> list[list[Image.Image]]:
    return _grid(ART_SRC / path, count, frames)


def _load_clips() -> tuple[
    dict[str, dict[str, list[Image.Image]]], list[Image.Image]
]:
    clips: dict[str, dict[str, list[Image.Image]]] = {}

    clips["mage_anim"] = dict(
        zip(AUTHORED_DIRS, _rows("regen_idle_v1.png", 5, 5))
    )

    walk = dict(
        zip(
            AUTHORED_DIRS[:4],
            _rows("regen_walk_s_se_e_ne_v1.png", 4, 8),
        )
    )
    north_walk_grid = _grid(ART_SRC / "regen_walk_n_v3_2x4.png", 2, 4)
    walk["n"] = north_walk_grid[0] + north_walk_grid[1]
    clips["mage_walk"] = walk

    run = dict(
        zip(
            AUTHORED_DIRS[:4],
            _rows("regen_run_s_se_e_ne_v1.png", 4, 7),
        )
    )
    run["n"] = _rows("regen_run_n_v1.png", 1, 7)[0]
    clips["mage_run"] = run

    attack = dict(
        zip(
            AUTHORED_DIRS[:4],
            _rows("regen_attack_s_se_e_ne_v1.png", 4, 7),
        )
    )
    attack["n"] = _rows("regen_attack_n_v1.png", 1, 7)[0]
    clips["mage_attack"] = attack

    # The first cast master returned only six bodies per row and is rejected.
    # Its replacement is a counted 3x7 S/SE/E grid; rear directions remain
    # direction-locked repairs to prevent recovery-facing drift.
    cast_rows = _rows("regen_cast_s_se_e_v2.png", 3, 7)
    cast = dict(zip(AUTHORED_DIRS[:3], cast_rows))
    cast["ne"] = _rows("regen_cast_ne_v2.png", 1, 7)[0]
    cast["n"] = _rows("regen_cast_n_v1_row2.png", 2, 7)[1]
    clips["mage_cast"] = cast

    # The combined dash master is approved only for SE and E: its S staff
    # floated and its NE facing drifted.  Every other direction is repaired.
    dash_rows = _rows(
        "regen_dash_se_e_v1_rows1_4_rejected.png", 4, 7
    )
    dash = {"se": dash_rows[1], "e": dash_rows[2]}
    dash["s"] = _rows("regen_dash_s_v3.png", 1, 7)[0]
    dash["ne"] = _rows("regen_dash_ne_v2_row2.png", 2, 7)[1]
    north_dash_grid = _grid(
        ART_SRC / "regen_dash_n_v2_4plus3.png", 2, 4
    )
    dash["n"] = north_dash_grid[0] + north_dash_grid[1][:3]
    clips["mage_dash"] = dash

    death_grid = _grid(ART_SRC / "regen_death_v1_3x3.png", 3, 3)
    death = death_grid[0] + death_grid[1] + death_grid[2]
    return clips, death


def _hard_alpha(image: Image.Image) -> Image.Image:
    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    opaque = arr[..., 3] > 24
    arr[..., 3] = np.where(opaque, 255, 0).astype(np.uint8)
    arr[~opaque, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _normalize_frames(
    frames: list[Image.Image], scale: float
) -> list[Image.Image]:
    out: list[Image.Image] = []
    for index, frame in enumerate(frames):
        bbox = frame.getbbox()
        if bbox is None:
            raise ValueError(f"empty generated frame {index}")
        figure = frame.crop(bbox)
        width = max(1, round(figure.width * scale))
        height = max(1, round(figure.height * scale))
        figure = _hard_alpha(
            figure.resize((width, height), Image.Resampling.LANCZOS)
        )
        if width > STAGING_CELL - 8 or height > STAGING_BASELINE - 4:
            raise ValueError(
                f"normalized frame does not fit staging: {width}x{height}"
            )
        canvas = Image.new(
            "RGBA", (STAGING_CELL, STAGING_CELL), (0, 0, 0, 0)
        )
        canvas.alpha_composite(
            figure, ((STAGING_CELL - width) // 2, STAGING_BASELINE - height)
        )
        out.append(canvas)
    return out


def _normalize(
    clips: dict[str, dict[str, list[Image.Image]]],
    death: list[Image.Image],
) -> tuple[dict[str, dict[str, list[Image.Image]]], list[Image.Image]]:
    normalized: dict[str, dict[str, list[Image.Image]]] = {}
    for clip, directions in clips.items():
        normalized[clip] = {}
        for suffix, frames in directions.items():
            bbox = frames[0].getbbox()
            if bbox is None:
                raise ValueError(f"empty reference frame: {clip} {suffix}")
            scale = TARGET_STANDING_BODY / float(bbox[3] - bbox[1])
            normalized[clip][suffix] = _normalize_frames(frames, scale)
    death_bbox = death[0].getbbox()
    if death_bbox is None:
        raise ValueError("empty death reference frame")
    death_scale = TARGET_STANDING_BODY / float(death_bbox[3] - death_bbox[1])
    return normalized, _normalize_frames(death, death_scale)


def _mirror_fill(
    directions: dict[str, list[Image.Image]]
) -> dict[str, list[Image.Image]]:
    for dst, src in MIRROR.items():
        directions[dst] = [
            frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            for frame in directions[src]
        ]
    return directions


def _assemble(
    clips: dict[str, dict[str, list[Image.Image]]],
    death: list[Image.Image],
    margin: int = 3,
) -> int:
    for directions in clips.values():
        _mirror_fill(directions)
    all_frames = [
        frame
        for directions in clips.values()
        for frames in directions.values()
        for frame in frames
    ] + death
    boxes = [frame.getbbox() for frame in all_frames]
    visible = [box for box in boxes if box is not None]
    ux0 = min(box[0] for box in visible)
    uy0 = min(box[1] for box in visible)
    ux1 = max(box[2] for box in visible)
    uy1 = max(box[3] for box in visible)
    fw, fh = ux1 - ux0, uy1 - uy0
    cell = max(fw, fh) + margin * 2
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    def place(frame: Image.Image) -> Image.Image:
        figure = frame.crop((ux0, uy0, ux1, uy1))
        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        canvas.alpha_composite(
            figure, ((cell - fw) // 2, cell - fh - margin)
        )
        return canvas

    for base, directions in clips.items():
        for suffix in ALL_DIRS:
            frames = directions[suffix]
            strip = Image.new(
                "RGBA", (cell * len(frames), cell), (0, 0, 0, 0)
            )
            for index, frame in enumerate(frames):
                strip.alpha_composite(place(frame), (index * cell, 0))
            strip.save(OUT_DIR / f"{base}_{suffix}.png")
        Image.open(OUT_DIR / f"{base}_s.png").save(OUT_DIR / f"{base}.png")

    death_strip = Image.new(
        "RGBA", (cell * len(death), cell), (0, 0, 0, 0)
    )
    for index, frame in enumerate(death):
        death_strip.alpha_composite(place(frame), (index * cell, 0))
    death_strip.save(OUT_DIR / "mage_death.png")

    idle_s = Image.open(OUT_DIR / "mage_anim_s.png").convert("RGBA")
    idle_s.crop((0, 0, cell, cell)).save(OUT_DIR / "mage.png")
    return cell


def _validate(cell: int) -> None:
    expected: list[tuple[Path, int]] = [(OUT_DIR / "mage.png", 1)]
    for base, count in FRAME_COUNTS.items():
        if base == "mage_death":
            expected.append((OUT_DIR / "mage_death.png", count))
            continue
        expected.append((OUT_DIR / f"{base}.png", count))
        expected.extend(
            (OUT_DIR / f"{base}_{suffix}.png", count)
            for suffix in ALL_DIRS
        )
    for path, count in expected:
        if not path.exists():
            raise ValueError(f"missing output: {path}")
        image = Image.open(path).convert("RGBA")
        if image.size != (cell * count, cell):
            raise ValueError(
                f"bad geometry {path.name}: {image.size}, "
                f"expected {(cell * count, cell)}"
            )
        alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
        if int(((alpha > 0) & (alpha < 255)).sum()):
            raise ValueError(f"semi-transparent pixels: {path}")
        for index in range(count):
            if not image.crop(
                (index * cell, 0, (index + 1) * cell, cell)
            ).getbbox():
                raise ValueError(f"empty frame {path.name}:{index + 1}")


def build() -> None:
    clips, death = _load_clips()
    normalized, normalized_death = _normalize(clips, death)
    cell = _assemble(normalized, normalized_death)
    _validate(cell)
    print(
        "installed Blighted Healer Mage: "
        "6 clips x 8 directions + static + 9-frame base death; "
        f"shared cell={cell}px -> {OUT_DIR}"
    )


if __name__ == "__main__":
    build()
