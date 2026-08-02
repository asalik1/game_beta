"""Build and install the approved Erased Name base-Assassin sprite family.

Run from the repository root with the bundled/runtime Python:

    python tools/art/build_erased_name_assassin.py

The builder hard-keys the ImageGen green masters, slices authored gutters,
normalizes every clip onto one baseline/body scale, mirrors the approved east
half into the west half, installs the exact legacy filenames, and emits QA
GIFs/contact sheets. CROWNLESS_ART_SRC and CROWNLESS_GAME_SPRITES can override
the default source and output directories.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from build_ledgerbound_warlock import (
    _grid,
    _hard_alpha,
    _remove_green,
    _valley_separators,
)


ROOT = Path(__file__).resolve().parents[2]
ART_SRC = Path(
    os.environ.get(
        "CROWNLESS_ART_SRC", ROOT / "art_src" / "assassin_erased_name"
    )
)
OUT_DIR = Path(
    os.environ.get(
        "CROWNLESS_GAME_SPRITES", ROOT / "game" / "assets" / "sprites"
    )
)
QA_DIR = ART_SRC / "qa"
DIR5 = ("s", "se", "e", "ne", "n")
DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
FRAMES = {
    "anim": 4,
    "walk": 6,
    "run": 6,
    "attack": 7,
    "attack2": 7,
    "dash": 7,
    "ult": 9,
    "ultidle": 7,
    "death": 9,
}
FPS = {
    "anim": 6,
    "walk": 9,
    "run": 12,
    "attack": 18,
    "attack2": 16,
    "dash": 18,
    "ult": 12,
    "ultidle": 7,
    "death": 9,
}
TARGET_BODY = 190.0
STAGING_CELL = 448
STAGING_BASELINE = 410


def _component_grid(
    path: Path, rows: int, cols: int
) -> list[list[Image.Image]]:
    """Assign every keyed connected component to its nearest authored body.

    ImageGen's irregular gutters let long blades and cloak tips cross nominal
    cell midpoints. Cropping rectangles alone therefore contaminates adjacent
    runtime frames. This run-length 8-connected labeller identifies the
    `cols` largest body components in each row, then assigns each detached
    blade/knife/cloth component to the nearest body center before cropping.
    Tiny one-pixel key noise is discarded.
    """

    image = _remove_green(Image.open(path).convert("RGBA"))
    rgba = np.asarray(image, dtype=np.uint8)
    alpha = rgba[..., 3] > 0
    y_edges = _valley_separators(alpha, rows, axis=0)
    result: list[list[Image.Image]] = []

    for row_index in range(rows):
        y0, y1 = y_edges[row_index], y_edges[row_index + 1]
        row_mask = alpha[y0:y1]
        parent: list[int] = []
        runs: list[tuple[int, int, int, int]] = []
        previous: list[tuple[int, int, int]] = []

        def find(label: int) -> int:
            while parent[label] != label:
                parent[label] = parent[parent[label]]
                label = parent[label]
            return label

        def union(left: int, right: int) -> None:
            root_left, root_right = find(left), find(right)
            if root_left != root_right:
                parent[root_right] = root_left

        for local_y, scanline in enumerate(row_mask):
            padded = np.pad(scanline.astype(np.int8), (1, 1))
            changes = np.diff(padded)
            starts = np.flatnonzero(changes == 1)
            ends = np.flatnonzero(changes == -1) - 1
            current: list[tuple[int, int, int]] = []
            for x0, x1 in zip(starts.tolist(), ends.tolist()):
                label = len(parent)
                parent.append(label)
                runs.append((local_y, x0, x1, label))
                current.append((x0, x1, label))
                for prev_x0, prev_x1, prev_label in previous:
                    if prev_x1 + 1 < x0:
                        continue
                    if prev_x0 - 1 > x1:
                        break
                    union(label, prev_label)
            previous = current

        stats: dict[int, dict[str, float | int | list[int]]] = {}
        for run_index, (local_y, x0, x1, label) in enumerate(runs):
            root = find(label)
            width = x1 - x0 + 1
            item = stats.setdefault(
                root,
                {
                    "area": 0,
                    "sum_x": 0.0,
                    "sum_y": 0.0,
                    "x0": x0,
                    "x1": x1,
                    "y0": local_y,
                    "y1": local_y,
                    "runs": [],
                },
            )
            item["area"] = int(item["area"]) + width
            item["sum_x"] = float(item["sum_x"]) + (x0 + x1) * width / 2.0
            item["sum_y"] = float(item["sum_y"]) + local_y * width
            item["x0"] = min(int(item["x0"]), x0)
            item["x1"] = max(int(item["x1"]), x1)
            item["y0"] = min(int(item["y0"]), local_y)
            item["y1"] = max(int(item["y1"]), local_y)
            cast_runs = item["runs"]
            assert isinstance(cast_runs, list)
            cast_runs.append(run_index)

        components = [
            (root, item)
            for root, item in stats.items()
            if int(item["area"]) >= 4
        ]
        bodies = sorted(
            sorted(
                components,
                key=lambda pair: int(pair[1]["area"]),
                reverse=True,
            )[:cols],
            key=lambda pair: float(pair[1]["sum_x"])
            / float(pair[1]["area"]),
        )
        if len(bodies) != cols:
            raise ValueError(
                f"{path.name} row {row_index}: found {len(bodies)} bodies, "
                f"expected {cols}"
            )
        body_centers = [
            float(item["sum_x"]) / float(item["area"]) for _, item in bodies
        ]
        groups: list[list[int]] = [[] for _ in range(cols)]
        body_roots = {root: index for index, (root, _) in enumerate(bodies)}
        for root, item in components:
            if root in body_roots:
                target = body_roots[root]
            else:
                center = float(item["sum_x"]) / float(item["area"])
                target = min(
                    range(cols), key=lambda index: abs(center - body_centers[index])
                )
            groups[target].append(root)

        row_frames: list[Image.Image] = []
        for group in groups:
            x_min = min(int(stats[root]["x0"]) for root in group)
            x_max = max(int(stats[root]["x1"]) for root in group)
            local_y_min = min(int(stats[root]["y0"]) for root in group)
            local_y_max = max(int(stats[root]["y1"]) for root in group)
            crop = np.zeros(
                (
                    local_y_max - local_y_min + 1,
                    x_max - x_min + 1,
                    4,
                ),
                dtype=np.uint8,
            )
            roots = set(group)
            for local_y, x0, x1, label in runs:
                if find(label) not in roots:
                    continue
                crop[
                    local_y - local_y_min,
                    x0 - x_min : x1 - x_min + 1,
                ] = rgba[y0 + local_y, x0 : x1 + 1]
            row_frames.append(Image.fromarray(crop, "RGBA"))
        result.append(row_frames)
    return result


def _equal_grid_preserve_all(
    path: Path, rows: int, cols: int
) -> list[list[Image.Image]]:
    """Slice a genuinely regular authored grid without component deletion.

    The knife-fan masters have clean, equal gutters.  Their cape is made from
    several deliberately disconnected dark strips and the airborne knives are
    detached by definition, so connected-component filtering is destructive:
    it can throw away cape panels that are plainly present in the master.
    Direct cells preserve the complete authored silhouette and all projectiles.
    """

    image = _remove_green(Image.open(path).convert("RGBA"))
    width, height = image.size
    result: list[list[Image.Image]] = []
    for row in range(rows):
        y0 = round(row * height / rows)
        y1 = round((row + 1) * height / rows)
        frames: list[Image.Image] = []
        for col in range(cols):
            x0 = round(col * width / cols)
            x1 = round((col + 1) * width / cols)
            frame = image.crop((x0, y0, x1, y1))
            if frame.getbbox() is None:
                raise ValueError(f"empty authored cell: {path.name} r{row} c{col}")
            frames.append(frame)
        result.append(frames)
    return result


def _clean_frame(
    frame: Image.Image, *, keep_detached_props: bool = False
) -> Image.Image:
    """Keep the complete pose union while dropping neighbour-frame slivers.

    Slicing is done first using audited pose-center gutters, so original
    relative offsets remain untouched. A lightly bridged mask joins legitimate
    one/two-pixel gaps between hand and blade. For ordinary clips only the
    body's bridged union survives; Fan of Knives also retains substantial
    detached projectile components inside that pose's audited cell.
    """

    rgba = frame.convert("RGBA")
    source = np.asarray(rgba, dtype=np.uint8)
    alpha = source[..., 3] > 0
    bridge = Image.fromarray(alpha.astype(np.uint8) * 255).filter(
        ImageFilter.MaxFilter(5)
    )
    bridged = np.asarray(bridge, dtype=np.uint8) > 0
    height, width = bridged.shape
    pooled_h = (height + 1) // 2
    pooled_w = (width + 1) // 2
    padded = np.pad(
        bridged,
        ((0, pooled_h * 2 - height), (0, pooled_w * 2 - width)),
        constant_values=False,
    )
    pooled = padded.reshape(pooled_h, 2, pooled_w, 2).max(axis=(1, 3))
    labels = np.zeros(pooled.shape, dtype=np.int32)
    components: list[tuple[int, int]] = []
    label = 0
    for start_y, start_x in zip(*np.where(pooled)):
        if labels[start_y, start_x] != 0:
            continue
        label += 1
        labels[start_y, start_x] = label
        queue = [(int(start_y), int(start_x))]
        pixels = 0
        for y, x in queue:
            pixels += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    ny, nx = y + dy, x + dx
                    if (
                        0 <= ny < pooled_h
                        and 0 <= nx < pooled_w
                        and pooled[ny, nx]
                        and labels[ny, nx] == 0
                    ):
                        labels[ny, nx] = label
                        queue.append((ny, nx))
        components.append((pixels, label))
    if not components:
        raise ValueError("empty keyed frame")
    main_pixels, main_label = max(components)
    keep_labels = {main_label}
    if keep_detached_props:
        threshold = max(8, round(main_pixels * 0.002))
        maximum_prop = max(threshold, round(main_pixels * 0.10))
        brightness = source[..., :3].max(axis=2)
        for pixels, component_label in components:
            if not threshold <= pixels <= maximum_prop:
                continue
            component_coarse = labels == component_label
            component_mask = np.repeat(
                np.repeat(component_coarse, 2, axis=0), 2, axis=1
            )[:height, :width]
            visible = brightness[component_mask & alpha]
            # The intentional thrown knives contain a strong silver highlight.
            # Adjacent cloak shards are dark even when similarly small.
            if visible.size and float(np.percentile(visible, 90)) >= 120.0:
                keep_labels.add(component_label)
    coarse = np.isin(labels, list(keep_labels))
    mask = np.repeat(np.repeat(coarse, 2, axis=0), 2, axis=1)[:height, :width]
    cleaned = source.copy()
    cleaned[~mask, :] = 0
    return Image.fromarray(cleaned, "RGBA")


def _clean_grid(
    path: Path,
    rows: int,
    cols: int,
    *,
    keep_detached_props: bool = False,
    equal_x: bool = False,
    x_edges_override: list[int] | None = None,
) -> list[list[Image.Image]]:
    sliced = _grid(
        path,
        rows,
        cols,
        equal_x=equal_x,
        body_x=not equal_x,
        x_edges_override=x_edges_override,
    )
    return [
        [
            _clean_frame(frame, keep_detached_props=keep_detached_props)
            for frame in row
        ]
        for row in sliced
    ]


def _append_matched(
    base: list[Image.Image], additions: list[Image.Image]
) -> list[Image.Image]:
    """Match separately authored recovery frames to the base source scale."""

    base_boxes = [frame.getbbox() for frame in base]
    if any(box is None for box in base_boxes):
        raise ValueError("empty base frame while matching recovery")
    target_height = max(
        box[3] - box[1] for box in base_boxes if box is not None
    )
    matched: list[Image.Image] = []
    for frame in additions:
        box = frame.getbbox()
        if box is None:
            raise ValueError("empty recovery frame")
        figure = frame.crop(box)
        scale = target_height / float(figure.height)
        matched.append(
            figure.resize(
                (
                    max(1, round(figure.width * scale)),
                    target_height,
                ),
                Image.Resampling.LANCZOS,
            )
        )
    return base + matched


def _idle() -> dict[str, list[Image.Image]]:
    front = _clean_grid(ART_SRC / "v02_idle_front_keyed.png", 5, 4)
    rear = _clean_grid(ART_SRC / "v03_idle_rear_keyed.png", 2, 4)
    return {
        "s": front[0],
        "se": front[1],
        "e": front[2],
        "ne": rear[0],
        "n": rear[1],
    }


def _load_clips() -> dict[str, dict[str, list[Image.Image]]]:
    idle = _idle()
    walk_paths = {
        "s": "v04_walk_s_keyed.png",
        "se": "v05_walk_se_keyed.png",
        "e": "v06_walk_e_keyed.png",
        "ne": "v07_walk_ne_keyed.png",
        "n": "v08_walk_n_keyed.png",
    }
    walk = {
        suffix: _clean_grid(ART_SRC / name, 1, 6)[0]
        for suffix, name in walk_paths.items()
    }
    run_rows = _clean_grid(ART_SRC / "v09_run_keyed.png", 5, 6)
    run = {suffix: run_rows[index] for index, suffix in enumerate(DIR5)}

    stab_paths = {
        "s": "v10_attack_stab_s_keyed.png",
        "se": "v11_attack_stab_se_keyed.png",
        "e": "v12_attack_stab_e_keyed.png",
        "ne": "v13_attack_stab_ne_keyed.png",
        "n": "v14_attack_stab_n_keyed.png",
    }
    attack = {
        suffix: _clean_grid(ART_SRC / name, 1, 7)[0]
        for suffix, name in stab_paths.items()
    }

    dash_rows = _clean_grid(
        ART_SRC / "v15_dash_frames1-6_keyed.png", 5, 6
    )
    # The rejected generated recovery had the wrong knife count. The accepted
    # direction-authored normal-idle f1 is a distinct, clean seventh recovery,
    # not a duplicate/padded dash frame.
    dash = {
        suffix: _append_matched(
            dash_rows[index], [idle[suffix][0].copy()]
        )
        for index, suffix in enumerate(DIR5)
    }

    fan_paths = {
        "s": "v17_attack2_s_frames1-6_keyed.png",
        "se": "v18_attack2_se_frames1-6_keyed.png",
        "e": "v19_attack2_e_frames1-6_keyed.png",
        "ne": "v20_attack2_ne_frames1-6_keyed.png",
        "n": "v21_attack2_n_frames1-6_keyed.png",
    }
    attack2: dict[str, list[Image.Image]] = {}
    for suffix, name in fan_paths.items():
        # The poses are not on exact equal-width boundaries. Assign every
        # meaningful authored component (body, disconnected cape panels,
        # sword, and thrown knives) to its nearest pose center, without the
        # destructive _clean_frame brightness/main-blob filtering.
        fan = _component_grid(ART_SRC / name, 1, 6)[0]
        attack2[suffix] = _append_matched(
            fan, [idle[suffix][0].copy()]
        )

    ult_rows = _clean_grid(
        ART_SRC / "v22_ult_frames1-6_keyed.png", 5, 6
    )
    # Three accepted authored idle breaths provide distinct unfold/settle
    # frames 7-9 after the generated six-pose cloak compression.
    ult = {
        suffix: _append_matched(
            ult_rows[index],
            [
                idle[suffix][1].copy(),
                idle[suffix][2].copy(),
                idle[suffix][3].copy(),
            ],
        )
        for index, suffix in enumerate(DIR5)
    }

    active_main = _clean_grid(
        ART_SRC / "v23_ultidle_s_se_e_n_frames1-6_keyed.png",
        4,
        6,
    )
    active = {
        "s": _append_matched(active_main[0], [idle["s"][3].copy()]),
        "se": _append_matched(active_main[1], [idle["se"][3].copy()]),
        "e": _append_matched(active_main[2], [idle["e"][3].copy()]),
        "ne": _clean_grid(
            ART_SRC / "v24_ultidle_ne_7frames_keyed.png",
            1,
            7,
        )[0],
        "n": _append_matched(active_main[3], [idle["n"][3].copy()]),
    }
    death = _clean_grid(
        ART_SRC / "v25_death_9frames_keyed.png",
        1,
        9,
        x_edges_override=[
            0,
            167,
            336,
            514,
            690,
            879,
            1075,
            1274,
            1481,
            1717,
        ],
    )[0]
    return {
        "assassin_anim": idle,
        "assassin_walk": walk,
        "assassin_run": run,
        "assassin_attack": attack,
        "assassin_attack2": attack2,
        "assassin_dash": dash,
        "assassin_ult": ult,
        "assassin_ultidle": active,
        "assassin_death": {"s": death},
    }


def _normalize_clip(
    directions: dict[str, list[Image.Image]],
) -> dict[str, list[Image.Image]]:
    """Normalize by the tallest authored pose, not blindly by frame one.

    Dash begins crouched and Death Mark begins cloak-compressed in some rear
    facings. Using their first pose as a standing-height proxy would enlarge
    the separately authored recovery and break the shared staging cell.
    """

    normalized: dict[str, list[Image.Image]] = {}
    for suffix, frames in directions.items():
        boxes = [frame.getbbox() for frame in frames]
        if any(box is None for box in boxes):
            raise ValueError(f"empty frame in {suffix}")
        heights = [box[3] - box[1] for box in boxes if box is not None]
        scale = TARGET_BODY / float(max(heights))
        output: list[Image.Image] = []
        for index, (frame, box) in enumerate(zip(frames, boxes)):
            assert box is not None
            figure = frame.crop(box)
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
            canvas.alpha_composite(
                figure,
                ((STAGING_CELL - width) // 2, STAGING_BASELINE - height),
            )
            output.append(canvas)
        normalized[suffix] = output
    return normalized


def _expected() -> set[Path]:
    expected = {OUT_DIR / "assassin.png", OUT_DIR / "assassin_death.png"}
    for stem in (
        "anim",
        "walk",
        "run",
        "attack",
        "attack2",
        "dash",
        "ult",
        "ultidle",
    ):
        expected.add(OUT_DIR / f"assassin_{stem}.png")
        expected.update(
            OUT_DIR / f"assassin_{stem}_{suffix}.png" for suffix in DIR8
        )
    return expected


def _validate(cell: int) -> None:
    expected = _expected()
    if len(expected) != 74:
        raise AssertionError(f"internal Assassin contract error: {len(expected)}")
    missing = sorted(path for path in expected if not path.exists())
    if missing:
        raise ValueError(f"missing Assassin runtime files: {missing}")
    for path in sorted(expected):
        image = Image.open(path).convert("RGBA")
        if image.height != cell or image.width % cell:
            raise ValueError(f"bad strip geometry: {path.name} {image.size}")
        actual = image.width // cell
        wanted = 1 if path.name == "assassin.png" else None
        for stem, frames in FRAMES.items():
            if path.name == f"assassin_{stem}.png" or path.name.startswith(
                f"assassin_{stem}_"
            ):
                wanted = frames
                break
        if wanted is not None and actual != wanted:
            raise ValueError(
                f"bad frame count {path.name}: expected={wanted} actual={actual}"
            )
        alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
        if int(((alpha > 0) & (alpha < 255)).sum()):
            raise ValueError(f"semi-transparent pixels: {path.name}")
        for index in range(actual):
            if not alpha[:, index * cell : (index + 1) * cell].any():
                raise ValueError(f"empty frame: {path.name} f{index + 1}")


def _frames(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    cell = strip.height
    return [
        strip.crop((index * cell, 0, (index + 1) * cell, cell))
        for index in range(strip.width // cell)
    ]


def _write_qa(cell: int) -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    preview = max(96, cell // 2)
    for stem in (
        "anim",
        "walk",
        "run",
        "attack",
        "attack2",
        "dash",
        "ult",
        "ultidle",
    ):
        rows = {
            suffix: _frames(OUT_DIR / f"assassin_{stem}_{suffix}.png")
            for suffix in DIR8
        }
        pages: list[Image.Image] = []
        for frame_index in range(len(rows["s"])):
            page = Image.new(
                "RGBA", (preview * 4, preview * 2), (28, 30, 36, 255)
            )
            draw = ImageDraw.Draw(page)
            for direction_index, suffix in enumerate(DIR8):
                x = direction_index % 4 * preview
                y = direction_index // 4 * preview
                page.alpha_composite(
                    rows[suffix][frame_index].resize(
                        (preview, preview), Image.Resampling.LANCZOS
                    ),
                    (x, y),
                )
                draw.text((x + 5, y + 4), suffix.upper(), fill=(255, 225, 120))
            pages.append(page.convert("P", palette=Image.Palette.ADAPTIVE))
        pages[0].save(
            QA_DIR / f"assassin_{stem}.gif",
            save_all=True,
            append_images=pages[1:],
            duration=round(1000 / FPS[stem]),
            loop=0,
            disposal=2,
        )

        label = 34
        contact = Image.new(
            "RGBA",
            (label + len(rows["s"]) * preview, label + len(DIR8) * preview),
            (28, 30, 36, 255),
        )
        draw = ImageDraw.Draw(contact)
        for frame_index in range(len(rows["s"])):
            draw.text(
                (label + frame_index * preview + 5, 8),
                f"f{frame_index + 1}",
                fill=(255, 225, 120),
            )
        for direction_index, suffix in enumerate(DIR8):
            y = label + direction_index * preview
            draw.text((6, y + 5), suffix.upper(), fill=(255, 225, 120))
            for frame_index, frame in enumerate(rows[suffix]):
                contact.alpha_composite(
                    frame.resize(
                        (preview, preview), Image.Resampling.LANCZOS
                    ),
                    (label + frame_index * preview, y),
                )
        contact.save(QA_DIR / f"assassin_{stem}.png")

    death = _frames(OUT_DIR / "assassin_death.png")
    death_gif = [
        frame.resize((preview, preview), Image.Resampling.LANCZOS).convert(
            "P", palette=Image.Palette.ADAPTIVE
        )
        for frame in death
    ]
    death_gif[0].save(
        QA_DIR / "assassin_death.gif",
        save_all=True,
        append_images=death_gif[1:],
        duration=round(1000 / FPS["death"]),
        loop=0,
        disposal=2,
    )
    title = 44
    contact = Image.new(
        "RGBA", (cell * len(death), cell + title), (28, 30, 36, 255)
    )
    draw = ImageDraw.Draw(contact)
    draw.text(
        (12, 8),
        "assassin - DEATH (directionless, columns = frame)",
        fill=(255, 225, 120),
    )
    for index, frame in enumerate(death):
        contact.alpha_composite(frame, (index * cell, title))
        draw.text(
            (index * cell + 6, title + 5),
            f"f{index + 1}",
            fill=(255, 225, 120),
        )
    contact.save(QA_DIR / "assassin_death.png")


def build() -> None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import install_dirset

    clips = {
        name: _normalize_clip(directions)
        for name, directions in _load_clips().items()
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cell = install_dirset.assemble_clips(
        clips, str(OUT_DIR), margin=3, symmetric=True
    )
    for suffix in DIR8:
        temporary = OUT_DIR / f"assassin_death_{suffix}.png"
        if temporary.exists():
            temporary.unlink()
    idle_s = Image.open(OUT_DIR / "assassin_anim_s.png").convert("RGBA")
    idle_s.crop((0, 0, cell, cell)).save(OUT_DIR / "assassin.png")
    _validate(cell)
    _write_qa(cell)
    print(
        "installed Erased Name Assassin: 8 directional clips + "
        f"directionless death, shared cell={cell}px -> {OUT_DIR}"
    )


if __name__ == "__main__":
    build()
