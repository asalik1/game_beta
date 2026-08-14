#!/usr/bin/env python3
"""Install the 2026-08-08 ImageGen mob locomotion repair pass.

The source masters are intentionally kept in ``art_src``.  This builder
removes the flat green screen, restores each live sprite's existing canvas,
scale, and ground anchor, installs only complete generated frames, and writes
compact QA contact sheets beside the masters.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src" / "Custom" / "MobWalkRepairs_2026-08-08"
REFERENCES = SOURCE / "references"
SPRITES = ROOT / "game" / "assets" / "sprites"

IDLE_ONLY = (
    "static_caller", "rat_mage", "stormcult", "mummy", "skeleton_mage",
    "skeleton_warrior", "vale_mourner", "mummy_mage", "cold_pilgrim",
)

# Robe-covered locomotion uses a full-frame glide/breathing strip instead of
# visible steps. Null Acolyte keeps its existing static design but now gets the
# same readable whole-body motion treatment as the redesigned robe identities.
ROBE_MOTION = ("null_acolyte", *IDLE_ONLY)

# The same redesigned, floor-length identities need matching complete-frame
# attacks. Null Acolyte keeps its existing identity and attack art.
ROBE_ATTACKS = IDLE_ONLY

# Owner-reviewed attack replacements whose legacy strips contained neighboring
# frame fragments or moved the body core. Every master supplies four complete
# generated subjects separated by real chroma gutters.
CONSISTENCY_ATTACKS = (
    "fungus_heavy", "skeleton", "orc_rogue", "elf_ranger", "cultist",
    "bandit_scout", "grove_horror", "spider", "blightwolf",
    "duneprowler", "null_acolyte", "skeleton_rogue", "stone_broken",
    "storm_harrier", "rat_mage", "zombie", "winterfang", "bog_lurker",
    "fungus_long", "elf_druid", "vow_sentinel", "royal_knight",
)

WALKS = (
    "wolf", "cultist", "skeleton", "zombie", "blightwolf", "orc",
    "orc_rogue", "elf_ranger", "duneprowler", "deep_stalker",
    "casket_creeper", "stone_broken", "vent_skitter", "winterfang",
    "royal_knight", "bog_lurker", "elf_druid", "vow_sentinel",
    "bandit_scout", "fungus_long",
)


def reference_path(key: str, suffix: str = "") -> Path:
    """Use the frozen art_src metric when present, otherwise the live idle/anim.

    A few later repairs target shipped sprites whose original metric snapshot
    predates the walk-repair bundle. Falling back to the unchanged live asset
    keeps those repairs reproducible without inventing a second reference.
    """
    frozen = REFERENCES / f"{key}{suffix}.png"
    return frozen if frozen.exists() else SPRITES / f"{key}{suffix}.png"

def remove_green(path: Path) -> Image.Image:
    with Image.open(path) as opened:
        image = opened.convert("RGBA")
    rgba = np.asarray(image).copy()
    rgb = rgba[..., :3].astype(np.int16)
    border = np.concatenate((
        rgb[:12].reshape(-1, 3), rgb[-12:].reshape(-1, 3),
        rgb[:, :12].reshape(-1, 3), rgb[:, -12:].reshape(-1, 3),
    ))
    key = np.median(border, axis=0)
    distance = np.max(np.abs(rgb - key), axis=2)
    green_like = ((rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2]) > 34)
                  & (rgb[..., 1] > 110))
    magenta_like = ((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1] > 34)
                    & (np.maximum(rgb[..., 0], rgb[..., 2]) > 110))
    # Most masters use green; foliage-bearing subjects use magenta so their
    # real greens survive. Select despill from the sampled border key rather
    # than leaving magenta antialias pixels around those subjects.
    key_is_magenta = min(key[0], key[2]) - key[1] > 40
    chroma_like = magenta_like if key_is_magenta else green_like
    key_like = (distance < 34) | chroma_like
    rgba[..., 3][key_like] = 0
    rgba[..., 3] = np.where(rgba[..., 3] >= 96, 255, 0).astype(np.uint8)
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def alpha_box(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A")) > 32
    ys, xs = np.where(alpha)
    if not len(xs):
        raise ValueError("empty generated sprite cell")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def four_columns(image: Image.Image) -> list[Image.Image]:
    return [image.crop((round(i * image.width / 4), 0,
                        round((i + 1) * image.width / 4), image.height))
            for i in range(4)]


def four_whole_subjects(image: Image.Image) -> list[Image.Image]:
    """Split an ImageGen strip only through transparent green gutters.

    ImageGen often spaces four complete poses evenly without landing them on
    exact quarter-width boundaries. Locate the three blank gutters nearest the
    expected separators so no body, weapon, or cloth region is ever cut.
    """
    occupied = (np.asarray(image.getchannel("A")) > 32).any(axis=0)
    gaps: list[tuple[int, int]] = []
    start: int | None = None
    for x, value in enumerate(occupied):
        if not value and start is None:
            start = x
        elif value and start is not None:
            if start > 0 and x < image.width and x - start >= 8:
                gaps.append((start, x))
            start = None
    if len(gaps) < 3:
        raise ValueError("generated strip has fewer than three safe gutters")
    separators = []
    remaining = list(gaps)
    for index in range(1, 4):
        target = image.width * index / 4
        gap = min(remaining, key=lambda item: abs((item[0] + item[1]) / 2 - target))
        separators.append(round((gap[0] + gap[1]) / 2))
        remaining.remove(gap)
    separators.sort()
    bounds = [0, *separators, image.width]
    frames = [image.crop((bounds[i], 0, bounds[i + 1], image.height))
              for i in range(4)]
    for index, frame in enumerate(frames):
        box = alpha_box(frame)
        if box[0] <= 1 or box[2] >= frame.width - 1:
            raise ValueError(f"generated frame {index} lacks a safe whole-subject gutter")
    return frames


def four_grid_subjects(image: Image.Image) -> list[Image.Image]:
    """Extract four complete padded poses from a 2x2 ImageGen source.

    A 2x2 source is used when a leftward weapon and the preceding pose have
    overlapping x extents, making any horizontal strip separator unsafe. The
    quadrant edges are accepted only when every complete subject has a real
    transparent margin, so this never cuts through a body or weapon.
    """
    xmid, ymid = image.width // 2, image.height // 2
    frames = [
        image.crop((0, 0, xmid, ymid)),
        image.crop((xmid, 0, image.width, ymid)),
        image.crop((0, ymid, xmid, image.height)),
        image.crop((xmid, ymid, image.width, image.height)),
    ]
    # A fully transparent perimeter is the actual whole-pose guarantee. Some
    # wide quadruped tails legitimately leave only one clear pixel before the
    # quadrant boundary; requiring an arbitrary wider gutter rejects complete
    # poses without making extraction safer.
    margin = 1
    for index, frame in enumerate(frames):
        box = alpha_box(frame)
        if (box[0] < margin or box[1] < margin
                or box[2] > frame.width - margin
                or box[3] > frame.height - margin):
            raise ValueError(
                f"generated grid frame {index} lacks a safe whole-pose margin")
    return frames


def grid_4x4(image: Image.Image) -> list[list[Image.Image]]:
    return [[image.crop((round(x * image.width / 4), round(y * image.height / 4),
                         round((x + 1) * image.width / 4),
                         round((y + 1) * image.height / 4)))
             for x in range(4)] for y in range(4)]


def hard_alpha(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA")).copy()
    rgba[..., 3] = np.where(rgba[..., 3] >= 96, 255, 0).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def old_metrics(path: Path) -> tuple[int, float, float, float, float]:
    with Image.open(path) as opened:
        strip = opened.convert("RGBA")
    cell = strip.height
    count = max(1, strip.width // cell)
    boxes = [alpha_box(strip.crop((i * cell, 0, (i + 1) * cell, cell)))
             for i in range(count)]
    heights = sorted(box[3] - box[1] for box in boxes)
    widths = sorted(box[2] - box[0] for box in boxes)
    centers = sorted((box[0] + box[2]) / 2 for box in boxes)
    bottoms = sorted(box[3] for box in boxes)
    mid = len(boxes) // 2
    return cell, heights[mid], widths[mid], centers[mid], bottoms[mid]


def normalize(frames: list[Image.Image], reference: Path,
              visible_height: float | None = None,
              max_width_factor: float = 1.08) -> list[Image.Image]:
    cell, old_h, old_w, center_x, ground_y = old_metrics(reference)
    boxes = [alpha_box(frame) for frame in frames]
    source_heights = sorted(box[3] - box[1] for box in boxes)
    source_widths = sorted(box[2] - box[0] for box in boxes)
    target_h = old_h if visible_height is None else cell * visible_height
    scale = min(target_h / source_heights[len(source_heights) // 2],
                min(cell * 0.92, max(old_w * max_width_factor, old_w + 4))
                / source_widths[len(source_widths) // 2])
    out = []
    for frame, box in zip(frames, boxes):
        subject = frame.crop(box)
        subject = hard_alpha(subject.resize(
            (max(1, round(subject.width * scale)),
             max(1, round(subject.height * scale))), Image.Resampling.LANCZOS))
        canvas = Image.new("RGBA", (cell, cell))
        x = round(center_x - subject.width / 2)
        y = round(ground_y - subject.height)
        canvas.alpha_composite(subject, (x, y))
        out.append(canvas)
    return out


def upper_body_anchor(image: Image.Image,
                      box: tuple[int, int, int, int]) -> float:
    alpha = np.asarray(image.getchannel("A")) > 32
    height = box[3] - box[1]
    y0 = box[1] + round(height * 0.15)
    y1 = box[1] + round(height * 0.48)
    _ys, xs = np.where(alpha[y0:y1])
    return float(np.median(xs)) if len(xs) else (box[0] + box[2]) / 2


def normalize_attack(frames: list[Image.Image], idle_reference: Path) -> list[Image.Image]:
    """Scale complete generated attack poses to the accepted idle body.

    The ready pose (frame zero) is the binding body-size reference. The square
    action cell may grow to contain raised weapons/effects; enemy.gd keeps that
    larger cell at the idle body's pixel scale and aligns the real hem line.
    No body region is cut, mirrored, pasted, or otherwise modified.
    """
    idle_cell, idle_h, _idle_w, _center_x, idle_ground = old_metrics(idle_reference)
    with Image.open(idle_reference) as opened:
        idle = opened.convert("RGBA")
    idle_box = alpha_box(idle.crop((0, 0, idle_cell, idle_cell)))
    idle_anchor = upper_body_anchor(idle, idle_box)
    boxes = [alpha_box(frame) for frame in frames]
    anchors = [upper_body_anchor(frame, box)
               for frame, box in zip(frames, boxes)]
    ready = boxes[0]
    scale = idle_h / float(ready[3] - ready[1])
    max_height = max((box[3] - box[1]) * scale for box in boxes)
    padding = max(4, round(idle_cell * 0.04))
    left = max((anchor - box[0]) * scale
               for box, anchor in zip(boxes, anchors))
    right = max((box[2] - anchor) * scale
                for box, anchor in zip(boxes, anchors))
    bias = idle_anchor - idle_cell / 2
    cell = max(idle_cell,
               int(np.ceil(2 * (left + padding - bias))),
               int(np.ceil(2 * (right + padding + bias))),
               int(np.ceil(max_height + (idle_cell - idle_ground) + padding)))
    ground_y = cell - (idle_cell - idle_ground)
    target_anchor = cell / 2 + bias
    out = []
    for frame, box, anchor in zip(frames, boxes, anchors):
        subject = frame.crop(box)
        subject = hard_alpha(subject.resize(
            (max(1, round(subject.width * scale)),
             max(1, round(subject.height * scale))), Image.Resampling.LANCZOS))
        canvas = Image.new("RGBA", (cell, cell))
        x = round(target_anchor - (anchor - box[0]) * scale)
        y = round(ground_y - subject.height)
        canvas.alpha_composite(subject, (x, y))
        out.append(canvas)
    return out


def normalize_locked_motion(frames: list[Image.Image],
                            reference: Path,
                            max_width_factor: float = 1.08) -> list[Image.Image]:
    """Normalize complete robe poses around the upper body, not loose cloth.

    Flowing hems change each frame's outer alpha bounds. Their center must not
    drag the fixed character core sideways, so every whole frame is translated
    from a robust upper-body anchor and the shared hem ground line.
    """
    cell, old_h, old_w, center_x, ground_y = old_metrics(reference)
    with Image.open(reference) as opened:
        target = opened.convert("RGBA")
    target_box = alpha_box(target.crop((0, 0, cell, cell)))
    target_anchor = upper_body_anchor(target, target_box)
    boxes = [alpha_box(frame) for frame in frames]
    anchors = [upper_body_anchor(frame, box)
               for frame, box in zip(frames, boxes)]
    heights = sorted(box[3] - box[1] for box in boxes)
    widths = sorted(box[2] - box[0] for box in boxes)
    mid = len(boxes) // 2
    scale = min(old_h / heights[mid],
                min(cell * 0.92, max(old_w * max_width_factor, old_w + 4))
                / widths[mid])

    # Preserve body height unless a complete pose truly cannot fit the frozen
    # runtime cell around the same upper-body anchor and ground line.
    for box, anchor in zip(boxes, anchors):
        extents = (
            (anchor - box[0], target_anchor - 2),
            (box[2] - anchor, cell - target_anchor - 2),
            (box[3] - box[1], ground_y - 2),
        )
        for source_extent, available in extents:
            if source_extent > 0:
                scale = min(scale, available / source_extent)

    out = []
    for frame, box, anchor in zip(frames, boxes, anchors):
        subject = frame.crop(box)
        subject = hard_alpha(subject.resize(
            (max(1, round(subject.width * scale)),
             max(1, round(subject.height * scale))), Image.Resampling.LANCZOS))
        canvas = Image.new("RGBA", (cell, cell))
        x = round(target_anchor - (anchor - box[0]) * scale)
        y = round(ground_y - subject.height)
        canvas.alpha_composite(subject, (x, y))
        out.append(canvas)
    return out


def save_png(image: Image.Image, path: Path) -> None:
    """Atomically replace a live PNG without reopening it for truncation."""
    temporary = path.with_name(f".{path.stem}.tmp{path.suffix}")
    image.save(temporary, optimize=True)
    temporary.replace(path)


def save_strip(frames: list[Image.Image], path: Path) -> None:
    cell = frames[0].width
    strip = Image.new("RGBA", (cell * len(frames), cell))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * cell, 0))
    save_png(strip, path)


def validate_motion(frames: list[Image.Image], key: str) -> None:
    """Reject a nominal animation whose complete frames are effectively static."""
    unique_frames = {frame.tobytes() for frame in frames}
    if len(unique_frames) < 3:
        raise ValueError(f"{key} robe motion has fewer than 3 distinct frames")
    for index, frame in enumerate(frames):
        box = alpha_box(frame)
        if box[0] <= 0 or box[1] <= 0 or box[2] >= frame.width or box[3] >= frame.height:
            raise ValueError(f"{key} robe motion frame {index} touches a cell edge")


def install_idle_only(key: str) -> None:
    reference = REFERENCES / f"{key}.png"
    if key != "null_acolyte":
        source = remove_green(SOURCE / f"{key}_idle_master.png")
        frame = normalize([source], reference)[0]
        save_png(frame, SPRITES / f"{key}.png")
    motion = remove_green(SOURCE / f"{key}_motion_master.png")
    frames = normalize_locked_motion(four_whole_subjects(motion), reference)
    validate_motion(frames, key)
    save_strip(frames, SPRITES / f"{key}_anim.png")


def install_walk(key: str) -> None:
    if key == "stone_broken":
        install_slagbound_locomotion()
        return
    source = remove_green(SOURCE / f"{key}_walk_master.png")
    # Locomotion must share the live idle body's cell, scale, center, and
    # ground line. Legacy walk canvases were often oversized and made a valid
    # four-frame strip shrink or jump when selected in-game.
    complete = (four_grid_subjects(source)
                if source.width < source.height * 1.5
                else four_columns(source))
    reference = reference_path(key, "_anim")
    if key == "vow_sentinel":
        frames = normalize_locked_motion(
            complete, reference, max_width_factor=1.5)
    else:
        frames = normalize(
            complete,
            reference,
            max_width_factor=1.5 if key in ("skeleton", "orc_rogue") else 1.08,
        )
    save_strip(frames, SPRITES / f"{key}_walk.png")


def install_slagbound_locomotion() -> None:
    """Use whole accepted idle frames exactly as the owner specified.

    Frame zero becomes the one-frame idle, while the original four-frame idle
    strip becomes locomotion. The known source is an exact square-cell runtime
    strip, so each extraction preserves a complete frame without body edits.
    """
    with Image.open(SOURCE / "stone_broken_idle_source.png") as opened:
        frames = four_columns(opened.convert("RGBA"))
    for index, frame in enumerate(frames):
        box = alpha_box(frame)
        if box[0] <= 1 or box[2] >= frame.width - 1:
            raise ValueError(
                f"stone_broken idle frame {index} is not a complete safe frame")
    save_png(frames[0], SPRITES / "stone_broken.png")
    save_png(frames[0], SPRITES / "stone_broken_anim.png")
    save_strip(frames, SPRITES / "stone_broken_walk.png")


def install_robe_attack(key: str) -> None:
    source = remove_green(SOURCE / f"{key}_attack_master.png")
    if source.width < source.height * 1.5:
        complete = four_grid_subjects(source)
    else:
        try:
            complete = four_whole_subjects(source)
        except ValueError:
            # Some accepted sheets were generated on exact quarter cells rather
            # than free-spaced gutters; those are safe to split geometrically.
            complete = four_columns(source)
    frames = normalize_attack(complete, REFERENCES / f"{key}.png")
    save_strip(frames, SPRITES / f"{key}_attack.png")


def install_generated_attack(key: str) -> None:
    """Install four gutter-separated complete poses; never cut through them."""
    source = remove_green(SOURCE / f"{key}_attack_master.png")
    complete = (four_grid_subjects(source)
                if source.width < source.height * 1.5
                else four_whole_subjects(source))
    frames = normalize_attack(complete, reference_path(key))
    save_strip(frames, SPRITES / f"{key}_attack.png")


def install_barrow_wight() -> None:
    rows = grid_4x4(remove_green(SOURCE / "skeleton_rogue_master.png"))
    flat = [frame for row in rows for frame in row]
    normalized = normalize(flat, REFERENCES / "skeleton_rogue_walk.png",
                           visible_height=0.70)
    rows = [normalized[i * 4:(i + 1) * 4] for i in range(4)]
    walk_source = remove_green(SOURCE / "skeleton_rogue_walk_master.png")
    walk = normalize(four_columns(walk_source),
                     REFERENCES / "skeleton_rogue_walk.png",
                     visible_height=0.70)
    opposite = normalize(
        [remove_green(SOURCE / "skeleton_rogue_walk_opposite_master.png")],
        REFERENCES / "skeleton_rogue_walk.png", visible_height=0.70)[0]
    walk[2] = opposite
    for suffix, frames in zip(("anim", "walk", "attack", "death"),
                              (rows[0], walk, rows[2], rows[3])):
        save_strip(frames, SPRITES / f"skeleton_rogue_{suffix}.png")
    save_png(rows[0][0], SPRITES / "skeleton_rogue.png")


def install_spore_directions() -> None:
    for direction in ("n", "s"):
        source = remove_green(SOURCE / f"fungus_heavy_walk_{direction}_master.png")
        target = SPRITES / f"fungus_heavy_walk_{direction}.png"
        frames = normalize(four_columns(source),
                           REFERENCES / f"fungus_heavy_walk_{direction}.png")
        save_strip(frames, target)


def install_ground_locked_source(key: str, suffix: str) -> None:
    """Translate complete legacy frames onto the idle's normalized ground."""
    source_path = SOURCE / f"{key}_{suffix}_source.png"
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
    frames = four_columns(source)
    ref_cell, _h, _w, _cx, ref_ground = old_metrics(REFERENCES / f"{key}.png")
    target_ground = round(ref_ground / ref_cell * frames[0].height)
    out = []
    for index, frame in enumerate(frames):
        box = alpha_box(frame)
        dy = target_ground - box[3]
        if box[1] + dy < 1 or box[3] + dy >= frame.height:
            raise ValueError(f"{key}_{suffix} frame {index} cannot ground-lock whole")
        canvas = Image.new("RGBA", frame.size)
        canvas.alpha_composite(frame, (0, dy))
        out.append(canvas)
    save_strip(out, SPRITES / f"{key}_{suffix}.png")


def install_consistency_repairs() -> None:
    bog = remove_green(SOURCE / "bog_lurker_walk_master.png")
    bog_frames = normalize_attack(
        four_whole_subjects(bog), reference_path("bog_lurker", "_anim"))
    save_strip(bog_frames, SPRITES / "bog_lurker_walk.png")

    for key in CONSISTENCY_ATTACKS:
        install_generated_attack(key)

    for key in ("stone_base",):
        install_ground_locked_source(key, "attack")
    install_ground_locked_source("storm_harrier", "walk")
    install_ground_locked_source("stone_base", "walk")
    for direction in ("s", "se", "e", "ne", "n", "nw", "w", "sw"):
        install_ground_locked_source("stone_base", f"walk_{direction}")


def write_qa() -> None:
    keys = list(WALKS) + ["skeleton_rogue", "fungus_heavy_n", "fungus_heavy_s"]
    thumb, label = 96, 170
    sheet = Image.new("RGBA", (label + thumb * 4, 28 + len(keys) * thumb),
                      (24, 25, 29, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 7), "Mob locomotion repair: all four runtime frames", fill="white")
    for row, key in enumerate(keys):
        if key == "fungus_heavy_n":
            path = SPRITES / "fungus_heavy_walk_n.png"
        elif key == "fungus_heavy_s":
            path = SPRITES / "fungus_heavy_walk_s.png"
        else:
            path = SPRITES / f"{key}_walk.png"
        with Image.open(path) as opened:
            strip = opened.convert("RGBA")
        cell = strip.height
        y = 28 + row * thumb
        draw.text((8, y + 8), key, fill="white")
        for column in range(4):
            frame = strip.crop((column * cell, 0, (column + 1) * cell, cell))
            frame.thumbnail((thumb, thumb), Image.Resampling.LANCZOS)
            sheet.alpha_composite(frame, (label + column * thumb +
                                           (thumb - frame.width) // 2,
                                           y + (thumb - frame.height) // 2))
    save_png(sheet, SOURCE / "qa_walk_contact.png")

    robe_keys = ["null_acolyte", *IDLE_ONLY]
    cell, columns = 180, 2
    rows = (len(robe_keys) + columns - 1) // columns
    robes = Image.new("RGBA", (cell * columns, 24 + cell * rows),
                      (24, 25, 29, 255))
    robe_draw = ImageDraw.Draw(robes)
    robe_draw.text((8, 6), "Idle-only locomotion: floor-length hems", fill="white")
    for index, key in enumerate(robe_keys):
        with Image.open(SPRITES / f"{key}.png") as opened:
            frame = opened.convert("RGBA")
        frame.thumbnail((cell - 8, cell - 28), Image.Resampling.LANCZOS)
        x = (index % columns) * cell
        y = 24 + (index // columns) * cell
        robe_draw.text((x + 6, y + 4), key, fill="white")
        robes.alpha_composite(frame, (x + (cell - frame.width) // 2,
                                      y + 24 + (cell - 24 - frame.height) // 2))
    save_png(robes, SOURCE / "qa_idle_only_contact.png")

    motion_cell, motion_columns = 170, 5
    motion_sheet = Image.new(
        "RGBA", (motion_cell * motion_columns,
                 24 + motion_cell * len(ROBE_MOTION)), (24, 25, 29, 255))
    motion_draw = ImageDraw.Draw(motion_sheet)
    motion_draw.text((8, 6),
                     "Robe identity + four readable full-frame motion poses",
                     fill="white")
    for row, key in enumerate(ROBE_MOTION):
        with Image.open(SPRITES / f"{key}.png") as opened:
            idle = opened.convert("RGBA")
        with Image.open(SPRITES / f"{key}_anim.png") as opened:
            strip = opened.convert("RGBA")
        frames = [idle]
        frames.extend(four_columns(strip))
        y = 24 + row * motion_cell
        motion_draw.text((6, y + 5), key, fill="white")
        for column, frame in enumerate(frames):
            frame.thumbnail((motion_cell - 8, motion_cell - 26),
                            Image.Resampling.LANCZOS)
            x = column * motion_cell + (motion_cell - frame.width) // 2
            motion_sheet.alpha_composite(
                frame, (x, y + 22 +
                        (motion_cell - 22 - frame.height) // 2))
    save_png(motion_sheet, SOURCE / "qa_robe_motion.png")

    attack_cell, attack_columns = 180, 5
    attacks = Image.new(
        "RGBA", (attack_cell * attack_columns,
                 24 + attack_cell * len(ROBE_ATTACKS)), (24, 25, 29, 255))
    attack_draw = ImageDraw.Draw(attacks)
    attack_draw.text((8, 6), "Robe identity + four complete attack frames",
                     fill="white")
    for row, key in enumerate(ROBE_ATTACKS):
        paths = [SPRITES / f"{key}.png", SPRITES / f"{key}_attack.png"]
        with Image.open(paths[0]) as opened:
            idle = opened.convert("RGBA")
        with Image.open(paths[1]) as opened:
            strip = opened.convert("RGBA")
        frames = [idle]
        frames.extend(four_columns(strip))
        y = 24 + row * attack_cell
        attack_draw.text((6, y + 5), key, fill="white")
        for column, frame in enumerate(frames):
            frame.thumbnail((attack_cell - 8, attack_cell - 26),
                            Image.Resampling.LANCZOS)
            x = column * attack_cell + (attack_cell - frame.width) // 2
            attacks.alpha_composite(
                frame, (x, y + 22 + (attack_cell - 22 - frame.height) // 2))
    save_png(attacks, SOURCE / "qa_robe_attacks.png")

    consistency = Image.new(
        "RGBA", (attack_cell * attack_columns,
                 24 + attack_cell * len(CONSISTENCY_ATTACKS)),
        (24, 25, 29, 255))
    consistency_draw = ImageDraw.Draw(consistency)
    consistency_draw.text(
        (8, 6), "Identity + four fragment-free anchored attack frames",
        fill="white")
    for row, key in enumerate(CONSISTENCY_ATTACKS):
        with Image.open(SPRITES / f"{key}.png") as opened:
            idle = opened.convert("RGBA")
        with Image.open(SPRITES / f"{key}_attack.png") as opened:
            strip = opened.convert("RGBA")
        frames = [idle, *four_columns(strip)]
        y = 24 + row * attack_cell
        consistency_draw.text((6, y + 5), key, fill="white")
        for column, frame in enumerate(frames):
            frame.thumbnail((attack_cell - 8, attack_cell - 26),
                            Image.Resampling.LANCZOS)
            x = column * attack_cell + (attack_cell - frame.width) // 2
            consistency.alpha_composite(
                frame, (x, y + 22 +
                        (attack_cell - 22 - frame.height) // 2))
    save_png(consistency, SOURCE / "qa_consistency_attacks.png")

    with Image.open(SPRITES / "skeleton_rogue_walk.png") as opened:
        barrow = opened.convert("RGBA")
    barrow = barrow.resize((barrow.width * 4, barrow.height * 4),
                           Image.Resampling.NEAREST)
    save_png(barrow, SOURCE / "qa_barrow_walk.png")


def main() -> int:
    missing = [SOURCE / f"{key}_idle_master.png" for key in IDLE_ONLY]
    missing += [SOURCE / f"{key}_motion_master.png" for key in ROBE_MOTION]
    missing += [SOURCE / f"{key}_attack_master.png" for key in ROBE_ATTACKS]
    missing += [SOURCE / f"{key}_walk_master.png" for key in WALKS]
    missing += [SOURCE / "skeleton_rogue_master.png",
                SOURCE / "skeleton_rogue_walk_master.png",
                SOURCE / "skeleton_rogue_walk_opposite_master.png",
                SOURCE / "fungus_heavy_walk_n_master.png",
                SOURCE / "fungus_heavy_walk_s_master.png"]
    missing += [SOURCE / f"{key}_attack_master.png"
                for key in CONSISTENCY_ATTACKS]
    missing += [
                SOURCE / "stone_broken_idle_source.png",
                SOURCE / "storm_harrier_walk_source.png",
                SOURCE / "stone_base_walk_source.png"]
    missing += [SOURCE / f"{key}_attack_source.png" for key in
                ("stone_base", "royal_knight")]
    missing += [SOURCE / f"stone_base_walk_{direction}_source.png" for direction in
                ("s", "se", "e", "ne", "n", "nw", "w", "sw")]
    missing += [REFERENCES / f"{key}.png" for key in ROBE_MOTION]
    missing += [reference_path(key, "_anim") for key in WALKS]
    missing += [REFERENCES / "skeleton_rogue_anim.png",
                REFERENCES / "skeleton_rogue_walk.png",
                REFERENCES / "fungus_heavy_walk_n.png",
                REFERENCES / "fungus_heavy_walk_s.png"]
    missing += [reference_path(key) for key in
                ("stone_base", "storm_harrier", "royal_knight",
                 *CONSISTENCY_ATTACKS)]
    missing = [path for path in missing if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing masters:\n" + "\n".join(map(str, missing)))
    for key in ROBE_MOTION:
        install_idle_only(key)
    for key in ROBE_ATTACKS:
        install_robe_attack(key)
    for key in WALKS:
        install_walk(key)
    install_barrow_wight()
    install_spore_directions()
    install_consistency_repairs()
    write_qa()
    print(f"installed {len(ROBE_MOTION)} animated floor-length robes, "
          f"{len(ROBE_ATTACKS)} matching robe attacks, "
          f"{len(WALKS)} walk cycles, "
          f"{len(CONSISTENCY_ATTACKS)} fragment-free attacks, "
          "Barrow Wight redesign, and Spore Shambler N/S repairs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
