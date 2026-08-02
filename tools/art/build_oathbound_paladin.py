"""Build the Oathbound Arbiter base-Paladin animation family.

The built-in image generator authored chroma-key source grids under
art_src/paladin_oathbound_arbiter/. This builder:

1. slices the fixed grids;
2. removes/despills the green field with hard alpha;
3. normalizes every clip to one body scale and ground line;
4. mirrors the approved east half into W/SW/NW using the existing hero
   direction convention; and
5. installs the complete directional runtime family.

Run from the repository root:

    python tools/art/build_oathbound_paladin.py

Use CROWNLESS_ART_SRC or CROWNLESS_GAME_SPRITES to override the default source
or output directories.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ART_SRC = Path(
    os.environ.get(
        "CROWNLESS_ART_SRC",
        ROOT / "art_src" / "paladin_oathbound_arbiter",
    )
)
OUT_DIR = Path(
    os.environ.get(
        "CROWNLESS_GAME_SPRITES",
        ROOT / "game" / "assets" / "sprites",
    )
)

# Preserve the regenerated masters near their native standing-body resolution.
# The game still normalizes the Paladin to the same 52px hero height, so this
# changes texel density rather than gameplay size. The final GPU downsample
# consolidates painted micro-texture and softens the hard chroma silhouette.
TARGET_STANDING_BODY = 180.0
# The final death pose is intentionally wider than a standing figure. The
# runtime scales from painted alpha height, so this extra transparent staging
# room preserves the grounded silhouette without making the hero smaller.
STAGING_CELL = 384
STAGING_BASELINE = 350
DIRS = ("s", "se", "e", "ne", "n")


def _valley_separators(mask: np.ndarray, count: int, axis: int) -> list[int]:
    """Find real green gutters near the generator's implied grid lines.

    Image generation keeps the requested row/column order, but it does not
    guarantee mathematically equal cells. Large shields and capes can cross an
    equal-width boundary. Search around every nominal split and place the cut
    in the longest fully empty gutter instead.
    """

    extent = mask.shape[axis]
    if count == 1:
        return [0, extent]

    projection = mask.sum(axis=1 - axis).astype(np.float64)
    coords = np.arange(extent, dtype=np.float64)
    total = projection.sum()
    if total <= 0:
        return [round(index * extent / count) for index in range(count + 1)]

    # Weighted 1-D k-means finds the visual center of every requested pose.
    # Quantile seeding remains stable when the generator leaves asymmetric
    # outer margins (which is why nominal equal cells are not sufficient).
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
            np.abs(coords[:, None] - centers[None, :]),
            axis=1,
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
            # Prefer the empty gutter nearest the midpoint between the two
            # visual pose centers; length breaks ties in favor of more room.
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
            minimum = local.min()
            candidates = np.flatnonzero(local == minimum) + lo
            split = int(candidates[np.argmin(np.abs(candidates - target))])
        separators.append(split)
    separators.append(extent)
    return separators


def _grid(path: Path, rows: int, cols: int) -> list[list[Image.Image]]:
    image = _remove_green(Image.open(path).convert("RGBA"))
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 0
    y_edges = _valley_separators(alpha, rows, axis=0)
    # Column placement is shared by every requested facing. Pooling all rows
    # prevents a wide late pose (especially the death corpse) from pulling a
    # single row's weighted centers away from the authored timeline.
    x_edges = _valley_separators(alpha, cols, axis=1)
    out: list[list[Image.Image]] = []
    for row in range(rows):
        y0, y1 = y_edges[row], y_edges[row + 1]
        cells: list[Image.Image] = []
        for col in range(cols):
            x0, x1 = x_edges[col], x_edges[col + 1]
            cells.append(image.crop((x0, y0, x1, y1)))
        out.append(cells)
    return out


def _remove_green(image: Image.Image) -> Image.Image:
    """Hard-key the generated green field and remove green edge spill.

    The Oathbound palette intentionally has no green. A hue-dominance test is
    therefore safer than distance from one sampled RGB value: it catches the
    generator's lighter/darker green variation and the mixed anti-aliased rim
    without erasing brass, blue cloth, skin, or pale steel.
    """

    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = arr[..., :3].astype(np.float32)
    red = rgb[..., 0]
    green = rgb[..., 1]
    blue = rgb[..., 2]
    keyed = (
        (green > 72.0)
        & (green > red * 1.14 + 12.0)
        & (green > blue * 1.14 + 12.0)
    )
    arr[..., 3] = np.where(keyed, 0, 255).astype(np.uint8)

    # The sprite has no intentional green accents. Clamp surviving green
    # dominance so the downsampled hard edge cannot carry a neon fringe.
    visible = ~keyed
    neutral_green = np.maximum(arr[..., 0], arr[..., 2]).astype(np.uint16) + 10
    arr[..., 1] = np.where(
        visible,
        np.minimum(arr[..., 1].astype(np.uint16), neutral_green),
        0,
    ).astype(np.uint8)
    arr[keyed, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _rows_to_dirs(rows: list[list[Image.Image]]) -> dict[str, list[Image.Image]]:
    if len(rows) != len(DIRS):
        raise ValueError(f"expected {len(DIRS)} direction rows, got {len(rows)}")
    return {suffix: rows[index] for index, suffix in enumerate(DIRS)}


def _load_clips() -> dict[str, dict[str, list[Image.Image]]]:
    clips: dict[str, dict[str, list[Image.Image]]] = {}

    clips["paladin_anim"] = _rows_to_dirs(
        _grid(ART_SRC / "regen_idle_keyed.png", 5, 4)
    )
    # Walk is authored one direction at a time to lock its true alternating
    # two-step gait and keep the rear quarters from drifting or inverting.
    # Controlled mirroring derives W/SW/NW from E/SE/NE.
    clips["paladin_walk"] = {
        suffix: _grid(ART_SRC / f"regen_walk_{suffix}_keyed.png", 1, 8)[0]
        for suffix in DIRS
    }
    # ImageGen supplied two rear-quarter rows in the otherwise approved run
    # master. Select its stronger true-NE row and final centered-N row instead
    # of merging both into one cell.
    run_rows = _grid(ART_SRC / "regen_run_keyed.png", 6, 6)
    clips["paladin_run"] = _rows_to_dirs(
        [run_rows[index] for index in (0, 1, 2, 4, 5)]
    )

    judgment = _rows_to_dirs(
        _grid(ART_SRC / "regen_judgment_keyed.png", 5, 7)
    )
    # The combined master's North impact hid the hammer head behind the body.
    # This direction-locked row keeps the complete head and shaft readable.
    judgment["n"] = _grid(
        ART_SRC / "regen_judgment_n_keyed.png", 1, 7
    )[0]
    clips["paladin_attack"] = judgment

    consecration = _rows_to_dirs(
        _grid(ART_SRC / "regen_consecration_keyed.png", 5, 7)
    )
    # The combined sheet's two rear rows drifted during recovery, so those
    # entire timelines are replaced with direction-locked authored strips.
    consecration["ne"] = _grid(
        ART_SRC / "regen_consecration_ne_keyed.png", 1, 7
    )[0]
    consecration["n"] = _grid(
        ART_SRC / "regen_consecration_n_keyed.png", 1, 7
    )[0]
    clips["paladin_attack2"] = consecration

    clips["paladin_cast"] = _rows_to_dirs(
        _grid(ART_SRC / "regen_aegis_keyed.png", 5, 6)
    )
    clips["paladin_ult"] = _rows_to_dirs(
        _grid(ART_SRC / "regen_conviction_keyed.png", 5, 7)
    )

    clips["paladin_death"] = _rows_to_dirs(
        _grid(ART_SRC / "regen_death_keyed.png", 5, 6)
    )
    return clips


def _hard_alpha(image: Image.Image) -> Image.Image:
    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    opaque = arr[..., 3] > 24
    arr[..., 3] = np.where(opaque, 255, 0).astype(np.uint8)
    arr[~opaque, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _normalize_clip(
    directions: dict[str, list[Image.Image]],
) -> dict[str, list[Image.Image]]:
    """Normalize one generated grid while preserving its authored motion."""

    scales: dict[str, float] = {}
    for suffix in DIRS:
        bbox = directions[suffix][0].getbbox()
        if bbox is None:
            raise ValueError(f"empty first frame in {suffix}")
        scales[suffix] = TARGET_STANDING_BODY / float(bbox[3] - bbox[1])

    normalized: dict[str, list[Image.Image]] = {}
    for suffix, frames in directions.items():
        scale = scales[suffix]
        out_frames: list[Image.Image] = []
        for index, frame in enumerate(frames):
            bbox = frame.getbbox()
            if bbox is None:
                raise ValueError(f"empty frame {suffix}:{index}")
            figure = frame.crop(bbox)
            width = max(1, round(figure.width * scale))
            height = max(1, round(figure.height * scale))
            figure = _hard_alpha(
                figure.resize((width, height), Image.Resampling.LANCZOS)
            )
            if width > STAGING_CELL - 8 or height > STAGING_BASELINE - 4:
                raise ValueError(
                    f"frame {suffix}:{index} does not fit staging cell: "
                    f"{width}x{height}"
                )
            canvas = Image.new(
                "RGBA", (STAGING_CELL, STAGING_CELL), (0, 0, 0, 0)
            )
            x = (STAGING_CELL - width) // 2
            y = STAGING_BASELINE - height
            canvas.alpha_composite(figure, (x, y))
            out_frames.append(canvas)
        normalized[suffix] = out_frames
    return normalized


def _validate_output(paths: list[Path], cell: int) -> None:
    required = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
    for path in paths:
        image = Image.open(path).convert("RGBA")
        if image.height != cell or image.width % cell != 0:
            raise ValueError(f"bad strip geometry: {path} {image.size}")
        alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
        semi = int(((alpha > 0) & (alpha < 255)).sum())
        if semi:
            raise ValueError(f"semi-transparent pixels remain: {path} ({semi})")

    for base in (
        "paladin_anim",
        "paladin_walk",
        "paladin_run",
        "paladin_attack",
        "paladin_attack2",
        "paladin_cast",
        "paladin_ult",
        "paladin_death",
    ):
        for suffix in required:
            path = OUT_DIR / f"{base}_{suffix}.png"
            if not path.exists():
                raise ValueError(f"missing direction strip: {path}")


def build() -> None:
    # Import beside the script so this builder stays usable without turning
    # tools/art into a Python package.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import install_dirset

    clips = {
        name: _normalize_clip(directions)
        for name, directions in _load_clips().items()
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cell = install_dirset.assemble_clips(
        clips,
        str(OUT_DIR),
        margin=3,
        symmetric=True,
    )

    # Class-select/codex static: first south idle frame in the same normalized
    # cell as every runtime strip.
    idle_s = Image.open(OUT_DIR / "paladin_anim_s.png").convert("RGBA")
    idle_s.crop((0, 0, cell, cell)).save(OUT_DIR / "paladin.png")

    paths = sorted(OUT_DIR.glob("paladin_*.png"))
    _validate_output(paths, cell)
    print(
        f"installed Oathbound Arbiter: {len(clips)} clips, "
        f"8 directions, shared cell={cell}px -> {OUT_DIR}"
    )


if __name__ == "__main__":
    build()
