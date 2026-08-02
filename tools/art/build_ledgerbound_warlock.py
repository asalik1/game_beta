"""Build the approved Ledgerbound Debtor base-Warlock sprite family.

The built-in ImageGen masters live under art_src/warlock_ledgerbound_debtor/.
This deterministic builder keys their green backdrop, slices real visual
gutters, maps the visually approved rows, normalizes every clip to one body
scale/ground line, derives the west facings from the approved east half, and
installs the existing Warlock runtime filename contract.

Run from the repository root:

    python tools/art/build_ledgerbound_warlock.py

Use CROWNLESS_ART_SRC or CROWNLESS_GAME_SPRITES to override the defaults.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
ART_SRC = Path(
    os.environ.get(
        "CROWNLESS_ART_SRC",
        ROOT / "art_src" / "warlock_ledgerbound_debtor",
    )
)
OUT_DIR = Path(
    os.environ.get(
        "CROWNLESS_GAME_SPRITES",
        ROOT / "game" / "assets" / "sprites",
    )
)

TARGET_STANDING_BODY = 190.0
STAGING_CELL = 448
STAGING_BASELINE = 410
DIRS = ("s", "se", "e", "ne", "n")
CLIP_FRAMES = {
    "warlock_anim": 5,
    "warlock_walk": 7,
    "warlock_run": 7,
    "warlock_attack": 9,
    "warlock_attack2": 9,
    "warlock_cast": 9,
    "warlock_ult": 9,
    "warlock_death": 9,
}
QA_DIR = ART_SRC / "qa"
DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
QA_FPS = {
    "anim": 6,
    "walk": 9,
    "run": 11,
    "attack": 22,
    "attack2": 22,
    "cast": 10,
    "ult": 11,
    "death": 9,
}


def _remove_green(image: Image.Image) -> Image.Image:
    """Hard-key ImageGen's green field and neutralize surviving green spill."""

    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = arr[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    keyed = (
        (green > 72.0)
        & (green > red * 1.14 + 12.0)
        & (green > blue * 1.14 + 12.0)
    )
    arr[..., 3] = np.where(keyed, 0, 255).astype(np.uint8)
    visible = ~keyed
    neutral_green = np.maximum(arr[..., 0], arr[..., 2]).astype(np.uint16) + 10
    arr[..., 1] = np.where(
        visible,
        np.minimum(arr[..., 1].astype(np.uint16), neutral_green),
        0,
    ).astype(np.uint8)
    arr[keyed, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _valley_separators(
    mask: np.ndarray,
    count: int,
    axis: int,
    weight_power: float = 1.0,
) -> list[int]:
    """Place cuts in real empty gutters rather than nominal equal cells."""

    extent = mask.shape[axis]
    if count == 1:
        return [0, extent]
    projection = mask.sum(axis=1 - axis).astype(np.float64)
    coords = np.arange(extent, dtype=np.float64)
    weights = np.power(projection, weight_power)
    total = weights.sum()
    if total <= 0:
        return [round(index * extent / count) for index in range(count + 1)]

    cumulative = np.cumsum(weights)
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
            weight = weights[selected].sum()
            if weight > 0:
                updated[index] = (
                    coords[selected] * weights[selected]
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
            minimum = local.min()
            candidates = np.flatnonzero(local == minimum) + lo
            split = int(candidates[np.argmin(np.abs(candidates - target))])
        separators.append(split)
    separators.append(extent)
    return separators


def _grid(
    path: Path,
    rows: int,
    cols: int,
    *,
    equal_x: bool = False,
    body_x: bool = False,
    x_centers: list[int] | None = None,
    x_edges_override: list[int] | None = None,
) -> list[list[Image.Image]]:
    image = _remove_green(Image.open(path).convert("RGBA"))
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 0
    y_edges = _valley_separators(alpha, rows, axis=0)
    # Detached bolt/rift/sigil marks are intentional parts of their frame, but
    # alpha-clustering can mistake them for an extra pose center. ImageGen kept
    # those timelines on an even authored cadence, so effect-bearing strips use
    # nominal column cuts while body-only sheets retain real-gutter detection.
    if x_edges_override is not None:
        if len(x_edges_override) != cols + 1:
            raise ValueError(
                f"{path.name}: expected {cols + 1} explicit edges, "
                f"got {len(x_edges_override)}"
            )
        x_edges = x_edges_override
    elif x_centers is not None:
        if len(x_centers) != cols:
            raise ValueError(
                f"{path.name}: expected {cols} explicit centers, "
                f"got {len(x_centers)}"
            )
        x_edges = [0]
        x_edges.extend(
            round((left + right) / 2)
            for left, right in zip(x_centers, x_centers[1:])
        )
        x_edges.append(image.width)
    elif equal_x:
        x_edges = [
            round(index * image.width / cols) for index in range(cols + 1)
        ]
    else:
        # Squared alpha-column occupancy makes tall character bodies dominate
        # the center fit while small detached bolts/runes remain inside the
        # nearest body's gutter interval instead of becoming false poses.
        x_edges = _valley_separators(
            alpha,
            cols,
            axis=1,
            weight_power=2.0 if body_x else 1.0,
        )
    out: list[list[Image.Image]] = []
    for row in range(rows):
        cells: list[Image.Image] = []
        y0, y1 = y_edges[row], y_edges[row + 1]
        for col in range(cols):
            x0, x1 = x_edges[col], x_edges[col + 1]
            cells.append(image.crop((x0, y0, x1, y1)))
        out.append(cells)
    return out


def _load_clips() -> dict[str, dict[str, list[Image.Image]]]:
    idle_main = _grid(ART_SRC / "v02_idle_main_keyed.png", 5, 5)
    idle_n_source = _grid(ART_SRC / "v03_idle_n_source_keyed.png", 4, 5)
    idle = {
        "s": idle_main[0],
        "se": idle_main[1],
        "e": idle_main[2],
        "ne": idle_main[3],
        # v02's fifth row touched the canvas edge. The accepted full N row is
        # the fourth row of the earlier four-row source.
        "n": idle_n_source[3],
    }

    walk = {
        suffix: _grid(ART_SRC / f"v0{index}_walk_{suffix}_keyed.png", 1, 7)[0]
        for index, suffix in zip(range(4, 9), DIRS)
    }

    run_rows = _grid(ART_SRC / "v09_run_keyed.png", 5, 7)
    run = {suffix: run_rows[index] for index, suffix in enumerate(DIRS)}

    # The multi-row Shadowbolt and Hex generations visibly authored eight
    # columns despite the nine-column request. Their eighth frame is the full
    # closed-book recovery, so duplicate that held recovery as runtime f9
    # instead of cutting eight real poses into nine broken cells.
    shadowbolt_rows = _grid(
        ART_SRC / "v10_attack_shadowbolt_main_keyed.png", 4, 8, body_x=True
    )
    shadowbolt_main = [row + [row[-1].copy()] for row in shadowbolt_rows]
    shadowbolt = {
        "s": shadowbolt_main[0],
        "se": shadowbolt_main[1],
        "e": shadowbolt_main[2],
        "ne": _grid(
            ART_SRC / "v11_attack_shadowbolt_ne_keyed.png",
            1,
            9,
            body_x=True,
        )[0],
        "n": shadowbolt_main[3],
    }

    # ImageGen returned the Pact main rows as E, SE, S, N. Keep the visual
    # mapping explicit; never infer direction from requested row order.
    pact_main = _grid(
        ART_SRC / "v12_attack2_pact_main_keyed.png", 4, 9, body_x=True
    )
    pact = {
        "s": pact_main[2],
        "se": pact_main[1],
        "e": pact_main[0],
        "ne": _grid(
            ART_SRC / "v13_attack2_pact_ne_keyed.png", 1, 9, body_x=True
        )[0],
        "n": pact_main[3],
    }

    hex_rows = _grid(
        ART_SRC / "v14_ult_hex_main_keyed.png", 4, 8, body_x=True
    )
    hex_main = [row + [row[-1].copy()] for row in hex_rows]
    hex_clip = {
        "s": hex_main[0],
        "se": hex_main[1],
        "e": hex_main[2],
        "ne": _grid(
            ART_SRC / "v15_ult_hex_ne_keyed.png", 1, 9, body_x=True
        )[0],
        "n": hex_main[3],
    }

    rift_main = _grid(
        ART_SRC / "v16_cast_rift_main_keyed.png", 4, 9, body_x=True
    )
    rift = {
        "s": rift_main[0],
        "se": rift_main[1],
        "e": rift_main[2],
        "ne": _grid(
            ART_SRC / "v17_cast_rift_ne_keyed.png", 1, 9, body_x=True
        )[0],
        "n": rift_main[3],
    }

    death_s = _grid(
        ART_SRC / "v19_death_visible_ledger_keyed.png",
        1,
        9,
        # Verified full-height empty gutters from the direction-locked repair.
        # It keeps the closed ledger visibly outside the anatomical-left hip
        # through the held corpse instead of hiding it beneath the coat.
        x_edges_override=[0, 171, 366, 574, 790, 1010, 1249, 1493, 1732, 1983],
    )[0]
    return {
        "warlock_anim": idle,
        "warlock_walk": walk,
        "warlock_run": run,
        "warlock_attack": shadowbolt,
        "warlock_attack2": pact,
        "warlock_cast": rift,
        "warlock_ult": hex_clip,
        "warlock_death": {"s": death_s},
    }


def _hard_alpha(image: Image.Image) -> Image.Image:
    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    opaque = arr[..., 3] > 24
    arr[..., 3] = np.where(opaque, 255, 0).astype(np.uint8)
    arr[~opaque, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _normalize_clip(
    directions: dict[str, list[Image.Image]],
) -> dict[str, list[Image.Image]]:
    scales: dict[str, float] = {}
    for suffix, frames in directions.items():
        bbox = frames[0].getbbox()
        if bbox is None:
            raise ValueError(f"empty first frame in {suffix}")
        scales[suffix] = TARGET_STANDING_BODY / float(bbox[3] - bbox[1])

    normalized: dict[str, list[Image.Image]] = {}
    for suffix, frames in directions.items():
        out_frames: list[Image.Image] = []
        for index, frame in enumerate(frames):
            bbox = frame.getbbox()
            if bbox is None:
                raise ValueError(f"empty frame {suffix}:{index}")
            figure = frame.crop(bbox)
            width = max(1, round(figure.width * scales[suffix]))
            height = max(1, round(figure.height * scales[suffix]))
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


def _expected_character_paths() -> set[Path]:
    dirs = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
    expected = {OUT_DIR / "warlock.png", OUT_DIR / "warlock_death.png"}
    for stem in ("anim", "walk", "run", "attack", "attack2", "cast", "ult"):
        expected.add(OUT_DIR / f"warlock_{stem}.png")
        expected.update(OUT_DIR / f"warlock_{stem}_{suffix}.png" for suffix in dirs)
    return expected


def _validate_output(cell: int) -> None:
    expected = _expected_character_paths()
    if len(expected) != 65:
        raise AssertionError(f"internal contract error: {len(expected)} files")
    missing = sorted(path for path in expected if not path.exists())
    if missing:
        raise ValueError(f"missing Warlock runtime files: {missing}")
    for path in sorted(expected):
        image = Image.open(path).convert("RGBA")
        if image.height != cell or image.width % cell != 0:
            raise ValueError(f"bad strip geometry: {path} {image.size}")
        expected_frames = 1 if path.name == "warlock.png" else None
        for stem, frames in CLIP_FRAMES.items():
            if path.name == f"{stem}.png" or path.name.startswith(f"{stem}_"):
                expected_frames = frames
                break
        actual_frames = image.width // image.height
        if expected_frames is not None and actual_frames != expected_frames:
            raise ValueError(
                f"bad frame count: {path.name} "
                f"expected={expected_frames} actual={actual_frames}"
            )
        alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
        if int(((alpha > 0) & (alpha < 255)).sum()):
            raise ValueError(f"semi-transparent pixels remain: {path}")
        for frame_index in range(actual_frames):
            x0 = frame_index * cell
            if not alpha[:, x0 : x0 + cell].any():
                raise ValueError(f"empty frame: {path.name} f{frame_index + 1}")


def _strip_frames(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    cell = strip.height
    return [
        strip.crop((index * cell, 0, (index + 1) * cell, cell))
        for index in range(strip.width // cell)
    ]


def _write_qa(cell: int) -> None:
    """Write motion GIFs plus the directionless death contact sheet."""

    QA_DIR.mkdir(parents=True, exist_ok=True)
    preview_cell = max(96, cell // 2)
    for stem in ("anim", "walk", "run", "attack", "attack2", "cast", "ult"):
        rows = {
            suffix: _strip_frames(OUT_DIR / f"warlock_{stem}_{suffix}.png")
            for suffix in DIR8
        }
        frame_count = len(rows["s"])
        gif_frames: list[Image.Image] = []
        for frame_index in range(frame_count):
            canvas = Image.new(
                "RGBA",
                (preview_cell * 4, preview_cell * 2),
                (28, 30, 36, 255),
            )
            draw = ImageDraw.Draw(canvas)
            for dir_index, suffix in enumerate(DIR8):
                frame = rows[suffix][frame_index].resize(
                    (preview_cell, preview_cell),
                    Image.Resampling.LANCZOS,
                )
                x = (dir_index % 4) * preview_cell
                y = (dir_index // 4) * preview_cell
                canvas.alpha_composite(frame, (x, y))
                draw.text((x + 5, y + 4), suffix.upper(), fill=(255, 225, 120))
            gif_frames.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE))
        gif_frames[0].save(
            QA_DIR / f"warlock_{stem}.gif",
            save_all=True,
            append_images=gif_frames[1:],
            duration=round(1000 / QA_FPS[stem]),
            loop=0,
            disposal=2,
        )

    death_frames = _strip_frames(OUT_DIR / "warlock_death.png")
    gif_death = [
        frame.convert("RGBA").resize(
            (preview_cell, preview_cell),
            Image.Resampling.LANCZOS,
        ).convert("P", palette=Image.Palette.ADAPTIVE)
        for frame in death_frames
    ]
    gif_death[0].save(
        QA_DIR / "warlock_death.gif",
        save_all=True,
        append_images=gif_death[1:],
        duration=round(1000 / QA_FPS["death"]),
        loop=0,
        disposal=2,
    )

    title_height = 44
    contact = Image.new(
        "RGBA",
        (cell * len(death_frames), cell + title_height),
        (28, 30, 36, 255),
    )
    draw = ImageDraw.Draw(contact)
    draw.text(
        (12, 8),
        "warlock - DEATH (directionless, cols = frame)",
        fill=(255, 225, 120),
    )
    for index, frame in enumerate(death_frames):
        contact.alpha_composite(frame, (index * cell, title_height))
        draw.text(
            (index * cell + 6, title_height + 5),
            f"f{index + 1}",
            fill=(255, 225, 120),
        )
    contact.save(QA_DIR / "warlock_death.png")


def build() -> None:
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

    # The existing Warlock runtime contract has one directionless death strip,
    # not directional death files. assemble_clips creates the temporary
    # direction family solely to keep death inside the shared geometry.
    for suffix in ("s", "se", "e", "ne", "n", "nw", "w", "sw"):
        death_direction = OUT_DIR / f"warlock_death_{suffix}.png"
        if death_direction.exists():
            death_direction.unlink()

    idle_s = Image.open(OUT_DIR / "warlock_anim_s.png").convert("RGBA")
    idle_s.crop((0, 0, cell, cell)).save(OUT_DIR / "warlock.png")
    _validate_output(cell)
    _write_qa(cell)
    print(
        "installed Ledgerbound Debtor: "
        f"7 directional clips + directionless death, shared cell={cell}px "
        f"-> {OUT_DIR}"
    )


if __name__ == "__main__":
    build()
