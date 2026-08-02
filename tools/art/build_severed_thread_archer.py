"""Build the approved Severed-Thread Ranger Archer sprite family.

The built-in ImageGen masters live in
``art_src/archer_severed_thread_ranger_production``.  This builder:

* keys the bright-green generation field while preserving the dark green cloak;
* slices the real gutters in every authored source strip;
* installs authored S/SE/E/NE/N and deterministic W/SW/NW mirrors;
* applies only explicit, separately authored equipment-repair poses;
* normalizes every clip to one stable body scale and ground baseline; and
* reproduces the exact 83-file live Archer contract.

Run from the repository root with the bundled Pillow/NumPy interpreter:

    python tools/art/build_severed_thread_archer.py
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
        ROOT / "art_src" / "archer_severed_thread_ranger_production",
    )
)
OUT_DIR = Path(
    os.environ.get(
        "CROWNLESS_GAME_SPRITES",
        ROOT / "game" / "assets" / "sprites",
    )
)

TARGET_STANDING_BODY = 180.0
STAGING_CELL = 512
STAGING_BASELINE = 468
AUTHORED_DIRS = ("s", "se", "e", "ne", "n")
ALL_DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
MIRROR = {"nw": "ne", "w": "e", "sw": "se"}
FRAME_COUNTS = {
    "archer_anim": 4,
    "archer_walk": 6,
    "archer_run": 6,
    "archer_attack": 9,
    "archer_attack2": 9,
    "archer_cast": 9,
    "archer_dash": 6,
    "archer_ult": 9,
    "archer_ultidle": 5,
}


def _remove_green(image: Image.Image) -> Image.Image:
    """Hard-key neon and neutralize dim spill without erasing bow geometry.

    ImageGen occasionally paints a few of the one-pixel bowstring highlights
    with the green backing-field hue.  Deleting those pixels breaks the
    required continuous tip-to-tip string, so the dim, strongly green-dominant
    remainder is recolored as shaded tan cord instead.  The Ranger's cloak is
    deliberately excluded by the high green-dominance/low-channel test.
    """

    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = arr[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    strongest_other = np.maximum(red, blue)
    keyed = (
        (green > 72.0)
        & ((green - strongest_other) > 38.0)
        & (green > red * 1.22)
        & (green > blue * 1.22)
    )
    # LANCZOS downsampling made a few dim, nearly-pure-green slivers from
    # ImageGen's antialiased field visible beside the thin bow/string.  The
    # cloak's legitimate greens contain substantial brown/blue material
    # channels; field residue does not.  Remove that narrow low-channel class
    # explicitly while leaving the brown string and wooden stave intact.
    keyed |= (
        (green > 24.0)
        & (red < 24.0)
        & (blue < 24.0)
        & ((green - strongest_other) > 16.0)
    )
    arr[..., 3] = np.where(keyed, 0, 255).astype(np.uint8)
    arr[keyed, :3] = 0

    # Preserve thin bow/string silhouettes while removing chroma-key color.
    # These pixels are darker antialiased remnants than the field pixels
    # removed above, but markedly more green-dominant than the forest cloak.
    cord_residue = (
        (~keyed)
        & (green > 30.0)
        & (red < 70.0)
        & (blue < 70.0)
        & ((green - strongest_other) > 28.0)
    )
    luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
    cord_red = np.clip(luminance * 1.35, 28.0, 126.0)
    cord_green = np.clip(luminance, 22.0, 96.0)
    cord_blue = np.clip(luminance * 0.62, 14.0, 62.0)
    arr[..., 0] = np.where(cord_residue, cord_red, arr[..., 0]).astype(
        np.uint8
    )
    arr[..., 1] = np.where(cord_residue, cord_green, arr[..., 1]).astype(
        np.uint8
    )
    arr[..., 2] = np.where(cord_residue, cord_blue, arr[..., 2]).astype(
        np.uint8
    )
    return Image.fromarray(arr, "RGBA")


def _gutter_edges(mask: np.ndarray, count: int, axis: int) -> list[int]:
    """Find the lowest-occupancy gutter near each nominal grid boundary.

    The long bow is a detached visual mass in many cells, so weighted pose
    clustering can incorrectly treat body and bow as separate poses.  These
    ImageGen strips are regular enough to use nominal boundaries, then move
    each cut into the nearest genuinely empty/quiet gutter.
    """

    extent = mask.shape[axis]
    projection = mask.sum(axis=1 - axis)
    edges = [0]
    nominal_cell = extent / count
    radius = max(8, round(nominal_cell * 0.35))
    for index in range(1, count):
        target = round(index * nominal_cell)
        lo = max(edges[-1] + 1, target - radius)
        hi = min(extent - 1, target + radius)
        local = projection[lo : hi + 1]
        minimum = local.min()
        candidates = np.flatnonzero(local == minimum) + lo
        edges.append(int(candidates[np.argmin(np.abs(candidates - target))]))
    edges.append(extent)
    return edges


def _grid(path: Path, rows: int, columns: int) -> list[list[Image.Image]]:
    image = _remove_green(Image.open(path).convert("RGBA"))
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 0
    x_edges = _gutter_edges(alpha, columns, axis=1)
    y_edges = _gutter_edges(alpha, rows, axis=0)
    return [
        [
            image.crop(
                (
                    x_edges[column],
                    y_edges[row],
                    x_edges[column + 1],
                    y_edges[row + 1],
                )
            )
            for column in range(columns)
        ]
        for row in range(rows)
    ]


def _strip(name: str, frames: int) -> list[Image.Image]:
    return _grid(ART_SRC / name, 1, frames)[0]


def _single(name: str) -> Image.Image:
    return _grid(ART_SRC / name, 1, 1)[0][0]


def _fit_repair_like(
    repair: Image.Image, reference: Image.Image
) -> Image.Image:
    """Scale a single-pose repair to the authored strip's local figure scale."""

    repair_box = repair.getbbox()
    reference_box = reference.getbbox()
    if repair_box is None or reference_box is None:
        raise ValueError("empty repair/reference frame")
    figure = repair.crop(repair_box)
    target_height = reference_box[3] - reference_box[1]
    scale = target_height / float(figure.height)
    size = (
        max(1, round(figure.width * scale)),
        max(1, round(figure.height * scale)),
    )
    figure = figure.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", reference.size, (0, 0, 0, 0))
    x = (reference.width - figure.width) // 2
    y = reference_box[3] - figure.height
    canvas.alpha_composite(figure, (x, y))
    return canvas


def _direction_strips(
    stem: str, version: str, frames: int
) -> dict[str, list[Image.Image]]:
    return {
        suffix: _strip(
            f"regen_{stem}_{suffix}_{version}_keyed.png", frames
        )
        for suffix in AUTHORED_DIRS
    }


def _load_clips() -> tuple[
    dict[str, dict[str, list[Image.Image]]], list[Image.Image]
]:
    clips: dict[str, dict[str, list[Image.Image]]] = {}

    # The accepted idle master returned real rows in S/E/NE/SE/N order.
    idle_rows = _grid(
        ART_SRC / "regen_idle_v01_keyed_rows_s_e_ne_se_n.png", 5, 4
    )
    idle = {
        "s": idle_rows[0],
        "se": idle_rows[3],
        "e": idle_rows[1],
        "ne": idle_rows[2],
        "n": idle_rows[4],
    }
    clips["archer_anim"] = idle

    clips["archer_walk"] = {
        "s": _strip("regen_walk_s_v01_keyed.png", 6),
        "se": _strip("regen_walk_se_v01_keyed.png", 6),
        "e": _strip("regen_walk_e_v02_keyed.png", 6),
        "ne": _strip("regen_walk_ne_v01_keyed.png", 6),
        "n": _strip("regen_walk_n_v01_keyed.png", 6),
    }
    clips["archer_run"] = {
        "s": _strip("regen_run_s_v02_keyed.png", 6),
        "se": _strip("regen_run_se_v02_keyed.png", 6),
        "e": _strip("regen_run_e_v02_keyed.png", 6),
        "ne": _strip("regen_run_ne_v02_keyed.png", 6),
        "n": _strip("regen_run_n_v02_keyed.png", 6),
    }

    attack = {
        "s": _strip(
            "regen_attack_s_v02_keyed_f9_replace_f1.png", 9
        ),
        "se": _strip("regen_attack_se_v02_keyed.png", 9),
        "e": _strip("regen_attack_e_v03_keyed.png", 9),
        "ne": _strip(
            "regen_attack_ne_v03_keyed_needs_f7_repair.png", 9
        ),
        "n": _strip(
            "regen_attack_n_v02_keyed_f7_replace_f6.png", 9
        ),
    }
    # South's generated f9 omitted the bow.  Reusing f1 only as the final
    # relaxed recovery bookend is an intentional loop closure, not a hidden
    # mid-action duplicate.
    attack["s"][8] = attack["s"][0].copy()
    # Release poses are separately authored repairs, never adjacent copies.
    attack["ne"][6] = _fit_repair_like(
        _single("regen_attack_ne_f7_release_repair_v01_keyed.png"),
        attack["ne"][6],
    )
    attack["n"][6] = _fit_repair_like(
        _single("regen_attack_n_f7_release_repair_v01_keyed.png"),
        attack["n"][6],
    )
    clips["archer_attack"] = attack

    attack2 = {
        "s": _strip("regen_attack2_s_v01_keyed.png", 9),
        "se": _strip("regen_attack2_se_v02_keyed.png", 9),
        "e": _strip("regen_attack2_e_v01_keyed.png", 9),
        "ne": _strip(
            "regen_attack2_ne_v01_keyed_needs_f8_repair.png", 9
        ),
        "n": _strip("regen_attack2_n_v01_keyed.png", 9),
    }
    attack2["ne"][7] = _fit_repair_like(
        _single("regen_attack2_ne_f8_recoil_repair_v01_keyed.png"),
        attack2["ne"][7],
    )
    clips["archer_attack2"] = attack2

    clips["archer_dash"] = {
        suffix: _strip(f"regen_dash_{suffix}_v01_keyed.png", 6)
        for suffix in AUTHORED_DIRS
    }
    clips["archer_cast"] = {
        suffix: _strip(f"regen_cast_{suffix}_v01_keyed.png", 9)
        for suffix in AUTHORED_DIRS
    }

    ultimate = {
        "s": _strip(
            "regen_ult_s_v01_keyed_f9_recovery_from_f1.png", 9
        ),
        "se": _strip("regen_ult_se_v01_keyed.png", 9),
        "e": _strip("regen_ult_e_v01_keyed.png", 9),
        "ne": _strip(
            "regen_ult_ne_v01_keyed_needs_f8_repair.png", 9
        ),
        "n": _strip("regen_ult_n_v01_keyed.png", 9),
    }
    ultimate["s"][8] = ultimate["s"][0].copy()
    ultimate["ne"][7] = _fit_repair_like(
        _single("regen_ult_ne_f8_release_repair_v01_keyed.png"),
        ultimate["ne"][7],
    )
    clips["archer_ult"] = ultimate

    # Archer has no ability mapping to ultidle, but the loader-compatible live
    # contract contains it.  Derive a distinct five-phase restrained loop from
    # the accepted idle master rather than inventing an optional powered form.
    clips["archer_ultidle"] = {
        suffix: [
            idle[suffix][0],
            idle[suffix][1],
            idle[suffix][2],
            idle[suffix][3],
            idle[suffix][1],
        ]
        for suffix in AUTHORED_DIRS
    }

    death = _strip("regen_death_s_v01_keyed.png", 9)
    return clips, death


def _hard_alpha(image: Image.Image) -> Image.Image:
    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    opaque = arr[..., 3] > 24
    arr[..., 3] = np.where(opaque, 255, 0).astype(np.uint8)
    arr[~opaque, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _neutralize_thin_green(image: Image.Image) -> Image.Image:
    """Recolor resampled green fringe on narrow bow/string silhouettes.

    This runs *after* LANCZOS normalization because that resampling step can
    blend a keyed green edge back into an otherwise brown one-pixel cord.  A
    5x5 occupancy guard limits the operation to narrow/outward details; broad
    opaque cloak material is therefore not selected.
    """

    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = arr[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    opaque = arr[..., 3] > 24
    height, width = opaque.shape
    padded = np.pad(opaque, 2, mode="constant", constant_values=False)
    occupancy = np.zeros_like(opaque, dtype=np.uint8)
    for dy in range(5):
        for dx in range(5):
            occupancy += padded[dy : dy + height, dx : dx + width]

    strongest_other = np.maximum(red, blue)
    thin_cord_residue = (
        opaque
        & (occupancy <= 14)
        & (green > 25.0)
        & ((green - strongest_other) > 14.0)
    )
    luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
    arr[..., 0] = np.where(
        thin_cord_residue, np.clip(luminance * 1.35, 28.0, 126.0), red
    ).astype(np.uint8)
    arr[..., 1] = np.where(
        thin_cord_residue, np.clip(luminance, 22.0, 96.0), green
    ).astype(np.uint8)
    arr[..., 2] = np.where(
        thin_cord_residue, np.clip(luminance * 0.62, 14.0, 62.0), blue
    ).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def _normalize_frames(
    frames: list[Image.Image], scale: float
) -> list[Image.Image]:
    out: list[Image.Image] = []
    for index, frame in enumerate(frames):
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"empty generated frame {index}")
        figure = frame.crop(box)
        size = (
            max(1, round(figure.width * scale)),
            max(1, round(figure.height * scale)),
        )
        figure = _hard_alpha(
            _neutralize_thin_green(
                figure.resize(size, Image.Resampling.LANCZOS)
            )
        )
        if figure.width > STAGING_CELL - 8:
            raise ValueError(
                f"normalized frame too wide: {figure.width}px"
            )
        if figure.height > STAGING_BASELINE - 4:
            raise ValueError(
                f"normalized frame too tall: {figure.height}px"
            )
        canvas = Image.new(
            "RGBA", (STAGING_CELL, STAGING_CELL), (0, 0, 0, 0)
        )
        canvas.alpha_composite(
            figure,
            (
                (STAGING_CELL - figure.width) // 2,
                STAGING_BASELINE - figure.height,
            ),
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
            reference = frames[0].getbbox()
            if reference is None:
                raise ValueError(f"empty reference frame: {clip} {suffix}")
            scale = TARGET_STANDING_BODY / float(
                reference[3] - reference[1]
            )
            normalized[clip][suffix] = _normalize_frames(frames, scale)

    death_reference = death[0].getbbox()
    if death_reference is None:
        raise ValueError("empty death reference frame")
    death_scale = TARGET_STANDING_BODY / float(
        death_reference[3] - death_reference[1]
    )
    return normalized, _normalize_frames(death, death_scale)


def _mirror_fill(
    directions: dict[str, list[Image.Image]]
) -> dict[str, list[Image.Image]]:
    for destination, source in MIRROR.items():
        directions[destination] = [
            frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            for frame in directions[source]
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
    frame_width, frame_height = ux1 - ux0, uy1 - uy0
    cell = max(frame_width, frame_height) + margin * 2
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    def place(frame: Image.Image) -> Image.Image:
        figure = frame.crop((ux0, uy0, ux1, uy1))
        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        canvas.alpha_composite(
            figure,
            (
                (cell - frame_width) // 2,
                cell - frame_height - margin,
            ),
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
        Image.open(OUT_DIR / f"{base}_s.png").save(
            OUT_DIR / f"{base}.png"
        )

    death_strip = Image.new(
        "RGBA", (cell * len(death), cell), (0, 0, 0, 0)
    )
    for index, frame in enumerate(death):
        death_strip.alpha_composite(place(frame), (index * cell, 0))
    death_strip.save(OUT_DIR / "archer_death.png")

    idle_s = Image.open(OUT_DIR / "archer_anim_s.png").convert("RGBA")
    idle_s.crop((0, 0, cell, cell)).save(OUT_DIR / "archer.png")
    return cell


def _validate(cell: int) -> None:
    expected: list[tuple[Path, int]] = [(OUT_DIR / "archer.png", 1)]
    for base, count in FRAME_COUNTS.items():
        expected.append((OUT_DIR / f"{base}.png", count))
        expected.extend(
            (OUT_DIR / f"{base}_{suffix}.png", count)
            for suffix in ALL_DIRS
        )
    expected.append((OUT_DIR / "archer_death.png", 9))
    if len(expected) != 83:
        raise AssertionError(f"internal contract error: {len(expected)}")

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
        semi = int(((alpha > 0) & (alpha < 255)).sum())
        if semi:
            raise ValueError(
                f"semi-transparent pixels: {path.name} ({semi})"
            )
        for index in range(count):
            if not image.crop(
                (index * cell, 0, (index + 1) * cell, cell)
            ).getbbox():
                raise ValueError(
                    f"empty frame {path.name}:{index + 1}"
                )

    installed = sorted(OUT_DIR.glob("archer*.png"))
    if len(installed) != 83:
        raise ValueError(
            f"unexpected Archer runtime inventory: {len(installed)} PNGs"
        )


def build() -> None:
    clips, death = _load_clips()
    normalized, normalized_death = _normalize(clips, death)
    cell = _assemble(normalized, normalized_death)
    _validate(cell)
    print(
        "installed Severed-Thread Ranger Archer: "
        "9 clips x 8 directions + static + 9-frame base death; "
        f"83 files, shared cell={cell}px -> {OUT_DIR}"
    )


if __name__ == "__main__":
    build()
