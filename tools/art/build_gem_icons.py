#!/usr/bin/env python3
"""Build the lore-authored gem level icons from ImageGen 5x2 masters.

Each master contains levels 1-5 on the first row and levels 6-10 on the
second. The artificial green/magenta screen is removed, every gem is found as
its own connected blob, and each blob is re-centred in its cut window before
the window is sampled down to the game's native 32x32 icon size.

Why blobs and not a fixed grid (2026-08-15): ImageGen does not honour "equal
spacing and centers" — gems drift up to ~15% of a cell off the grid centre,
tall gems cross the row midline, and one master (garnet) drew SIX gems on its
second row. The original fixed-grid cut shipped icons that sat off-centre in
their sockets, clipped tips, and carried slivers of the neighbouring gem.
"""

from __future__ import annotations

import argparse
from collections import deque
import os
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "art_src" / "gems_2026-07-30"
DEFAULT_OUTPUT = ROOT / "game" / "assets" / "icons"
DEFAULT_MOBILE = ROOT / "mobile" / "game" / "assets" / "icons"
TARGET = 32
SHEET_COLS = 5
SHEET_ROWS = 2
# Every gem keeps at least this many transparent pixels to each icon edge, so
# nothing kisses the socket border. Gems whose master art is taller than the
# nominal cell (topaz/bloodstone/sunstone L9-10 and friends) are scaled down
# to honour it instead of being clipped.
EDGE_MARGIN = 1
# Coarse factor for the blob labelling pass (a 4x4 max-pool merges the gem's
# outline with any hairline-separated highlight; gem-to-gem gaps are 30+ px).
LABEL_POOL = 4

# Masters whose rows hold MORE gems than the contract. Value: per row, the
# 0-based blob indices (sorted left-to-right) to DROP so five remain.
#   garnet row 2 came back with six gems: shield-boss, plain round brilliant,
#   round brilliant with star cut, tiered dome, rayed round, ring with a lit
#   core. The plain round brilliant (index 1) is the least distinct from its
#   star-cut neighbour, so it is the one that goes.
ROW_DROPS: dict[str, dict[int, tuple[int, ...]]] = {
    "garnet": {1: (1,)},
}

# Source family -> the exact Items.GEM_STATS key used by the runtime.
FAMILIES = {
    "ruby": "atk_flat",
    "garnet": "hp_flat",  # was hp_pct until the 2026-08-07 flat-HP ruling; the icon name must track Items.GEM_STATS
    "topaz": "crit",
    "sunstone": "dmg_pct",
    "sapphire": "cdr",
    "opal": "combo",
    "onyx": "physres",
    "lapis": "magres",
    "bloodstone": "physpen",
    "amethyst": "magpen",
    "jade": "eva",
    "amber": "dex",
    "tenacity": "flat_dr",
    "vampire_eye": "lifesteal",
}


def _flood_from_border(mask: np.ndarray) -> np.ndarray:
    """Return the part of a boolean mask connected to the image border."""
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        if mask[0, x]:
            seen[0, x] = True
            queue.append((0, x))
        if mask[height - 1, x] and not seen[height - 1, x]:
            seen[height - 1, x] = True
            queue.append((height - 1, x))
    for y in range(height):
        if mask[y, 0] and not seen[y, 0]:
            seen[y, 0] = True
            queue.append((y, 0))
        if mask[y, width - 1] and not seen[y, width - 1]:
            seen[y, width - 1] = True
            queue.append((y, width - 1))

    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    return seen


def remove_connected_chroma(cell: Image.Image) -> Image.Image:
    """Remove only screen pixels connected to a cell edge.

    The Opal contains tiny rainbow pinks close to its magenta screen. A global
    color key would erase those lore-bearing inclusions. Edge-connected removal
    preserves them while clearing the backdrop.
    """
    pixels = np.asarray(cell.convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(np.int16)
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]), axis=0)
    key = np.median(border, axis=0)
    distance = np.max(np.abs(rgb - key), axis=2)
    key_max = float(np.max(key))
    spill_channels = [
        channel
        for channel, value in enumerate(key)
        if value >= key_max - 16 and value >= 128
    ]
    other_channels = [channel for channel in range(3) if channel not in spill_channels]
    if not spill_channels or not other_channels:
        raise ValueError(f"Could not identify chroma channels from border color {key}")
    key_strength = np.min(rgb[..., spill_channels], axis=2)
    non_key_strength = np.max(rgb[..., other_channels], axis=2)
    dominance = key_strength - non_key_strength

    # Generated screens are saturated and nearly uniform. The dominance arm
    # catches the small chroma variation around anti-aliased sprite edges.
    candidate = (distance <= 64) | ((dominance >= 48) & (key_strength >= 112))
    connected = _flood_from_border(candidate)
    pixels[..., 3][connected] = 0

    # Generated screen spill can survive immediately outside the black outline
    # at darker values than the main key. Remove only that narrow outer matte;
    # enclosed Opal/Vampire Eye color remains untouched.
    transparent = pixels[..., 3] == 0
    edge_zone = transparent.copy()
    for _ in range(4):
        padded = np.pad(edge_zone, 1, mode="constant", constant_values=False)
        edge_zone = np.logical_or.reduce(
            [
                padded[dy : dy + cell.height, dx : dx + cell.width]
                for dy in range(3)
                for dx in range(3)
            ]
        )
    spill_fringe = edge_zone & ~transparent & (dominance >= 12) & (key_strength >= 48)
    pixels[..., 3][spill_fringe] = 0
    if spill_channels == [1]:
        # None of the green-screen families use green in their authored
        # palette. Dark screen-shadow pixels can sit behind the black outline
        # and evade connectivity, so reject that hue globally for this lane.
        dark_green_spill = (dominance >= 8) & (key_strength >= 16)
        pixels[..., 3][dark_green_spill] = 0
        neutralize = (dominance >= 8) & (key_strength >= 8) & ~dark_green_spill
        pixels[..., 1][neutralize] = np.maximum(
            pixels[..., 0][neutralize],
            pixels[..., 2][neutralize],
        )

    # Hard alpha prevents green/magenta bleed over dark inventory slots.
    pixels[..., 3] = np.where(pixels[..., 3] >= 128, 255, 0).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def save_atomic(image: Image.Image, destination: Path) -> None:
    """Write via a sibling temp file + os.replace. A truncating open on a PNG
    that another process (editor thumbnailer, indexer) has memory-mapped fails
    with a bare EINVAL on Windows; replace succeeds and is atomic besides."""
    tmp = destination.with_name(destination.name + ".tmp")
    image.save(tmp, format="PNG", optimize=True)
    os.replace(tmp, destination)


def label_blobs(mask: np.ndarray, pool: int = LABEL_POOL) -> tuple[np.ndarray, int]:
    """8-connected component labels for a boolean mask.

    Labelling runs on a max-pooled copy (pure-Python BFS over ~100k cells is
    quick; the full 1.5M-pixel master is not) and the labels are broadcast back
    to full resolution, masked by the original alpha. Returns (labels, count)
    with labels 1..count and 0 for background.
    """
    height, width = mask.shape
    coarse_h = -(-height // pool)
    coarse_w = -(-width // pool)
    padded = np.zeros((coarse_h * pool, coarse_w * pool), dtype=bool)
    padded[:height, :width] = mask
    coarse = padded.reshape(coarse_h, pool, coarse_w, pool).any(axis=(1, 3))
    labels = np.zeros((coarse_h, coarse_w), dtype=np.int32)
    count = 0
    for y in range(coarse_h):
        for x in range(coarse_w):
            if not coarse[y, x] or labels[y, x]:
                continue
            count += 1
            labels[y, x] = count
            queue: deque[tuple[int, int]] = deque([(y, x)])
            while queue:
                cy, cx = queue.popleft()
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < coarse_h and 0 <= nx < coarse_w and coarse[ny, nx] and not labels[ny, nx]:
                            labels[ny, nx] = count
                            queue.append((ny, nx))
    fine = np.repeat(np.repeat(labels, pool, axis=0), pool, axis=1)[:height, :width]
    return np.where(mask, fine, 0), count


def find_gems(labels: np.ndarray, count: int, family: str, master_name: str) -> list[dict]:
    """Map blobs to levels 1..10: row by which half of the sheet holds the blob
    centre, level by left-to-right order, ROW_DROPS applied. Returns a list of
    ten dicts {label, x0, y0, x1, y1} indexed by level-1."""
    height = labels.shape[0]
    blobs: list[dict] = []
    for label in range(1, count + 1):
        ys, xs = np.nonzero(labels == label)
        blob = {
            "label": label,
            "x0": int(xs.min()), "x1": int(xs.max()) + 1,
            "y0": int(ys.min()), "y1": int(ys.max()) + 1,
            "area": int(xs.size),
        }
        blob["row"] = 0 if (blob["y0"] + blob["y1"]) / 2 < height / 2 else 1
        blobs.append(blob)
    largest = max(blob["area"] for blob in blobs)
    specks = [blob for blob in blobs if blob["area"] < largest * 0.01]
    if specks:
        raise ValueError(
            f"{master_name}: {len(specks)} stray speck blob(s) survived keying — "
            "inspect the master; the builder refuses to guess which gem they belong to"
        )
    ordered: list[dict] = []
    for row in range(SHEET_ROWS):
        in_row = sorted((blob for blob in blobs if blob["row"] == row), key=lambda blob: blob["x0"] + blob["x1"])
        for drop in sorted(ROW_DROPS.get(family, {}).get(row, ()), reverse=True):
            if drop < len(in_row):
                del in_row[drop]
        if len(in_row) != SHEET_COLS:
            raise ValueError(
                f"{master_name}: row {row + 1} holds {len(in_row)} gems, expected {SHEET_COLS} "
                f"(add a ROW_DROPS entry if the master drew extras)"
            )
        ordered.extend(in_row)
    return ordered


def cut_gem(keyed: np.ndarray, labels: np.ndarray, blob: dict, side: int) -> Image.Image:
    """Cut one gem into a TARGET x TARGET icon, centred on its bounding box.

    `side` is the nominal master-pixels-per-icon window (the sheet's cell
    side), shared by every gem so the level ladder keeps its size growth. A gem
    larger than the window is scaled down just enough to keep EDGE_MARGIN clear
    pixels on every side rather than being clipped.
    """
    height, width = labels.shape
    only = keyed.copy()
    only[..., 3] = np.where(labels == blob["label"], only[..., 3], 0)
    span = max(blob["x1"] - blob["x0"], blob["y1"] - blob["y0"])
    usable = TARGET - 2 * EDGE_MARGIN
    window = max(side, int(np.ceil(span * TARGET / usable)))
    cx = (blob["x0"] + blob["x1"]) / 2
    cy = (blob["y0"] + blob["y1"]) / 2
    left = int(round(cx - window / 2))
    top = int(round(cy - window / 2))
    canvas = np.zeros((window, window, 4), dtype=np.uint8)
    src_x0, src_y0 = max(left, 0), max(top, 0)
    src_x1, src_y1 = min(left + window, width), min(top + window, height)
    canvas[src_y0 - top:src_y1 - top, src_x0 - left:src_x1 - left] = only[src_y0:src_y1, src_x0:src_x1]
    frame = Image.fromarray(canvas, "RGBA").resize((TARGET, TARGET), Image.Resampling.NEAREST)
    data = np.asarray(frame).copy()
    data[..., 3] = np.where(data[..., 3] >= 128, 255, 0).astype(np.uint8)
    return Image.fromarray(data, "RGBA")


def build_family(master_path: Path, stat: str, output_dir: Path) -> list[Path]:
    master = Image.open(master_path).convert("RGBA")
    ratio = master.width / master.height
    if not 1.95 <= ratio <= 2.05:
        raise ValueError(f"{master_path.name}: expected a roughly 2:1 5x2 sheet, got {master.size}")
    side = min(round(master.width / SHEET_COLS), round(master.height / SHEET_ROWS))

    keyed = np.asarray(remove_connected_chroma(master))
    labels, count = label_blobs(keyed[..., 3] > 0)
    family = master_path.stem.removesuffix("_master")
    gems = find_gems(labels, count, family, master_path.name)

    written: list[Path] = []
    for level, blob in enumerate(gems, start=1):
        frame = cut_gem(keyed, labels, blob, side)
        data = np.asarray(frame)
        visible = int(np.count_nonzero(data[..., 3]))
        if not 20 <= visible <= TARGET * TARGET * 0.9:
            raise ValueError(
                f"{master_path.name} Lv{level}: implausible visible area {visible}/{TARGET * TARGET}"
            )
        out = output_dir / f"gem_{stat}_lv{level}.png"
        save_atomic(frame, out)
        written.append(out)
    return written


def make_contact_sheet(output_dir: Path, destination: Path) -> None:
    scale = 3
    label_width = 150
    cell = TARGET * scale
    header = 30
    row_height = cell + 24
    sheet = Image.new(
        "RGBA",
        (label_width + 10 * cell, header + len(FAMILIES) * row_height),
        (20, 18, 24, 255),
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    draw.text((8, 9), "Bands: rough 1-3 | cut 4-6 | fine 7-9 | perfected 10", fill="white", font=font)

    for row, (family, stat) in enumerate(FAMILIES.items()):
        y = header + row * row_height
        draw.text((8, y + 40), f"{family} [{stat}]", fill=(230, 220, 190, 255), font=font)
        for level in range(1, 11):
            icon = Image.open(output_dir / f"gem_{stat}_lv{level}.png").convert("RGBA")
            icon = icon.resize((cell, cell), Image.Resampling.NEAREST)
            x = label_width + (level - 1) * cell
            checker = Image.new("RGBA", (cell, cell), (39, 36, 45, 255))
            tile = 12
            checker_draw = ImageDraw.Draw(checker)
            for cy in range(0, cell, tile):
                for cx in range(0, cell, tile):
                    if (cx // tile + cy // tile) % 2:
                        checker_draw.rectangle(
                            (cx, cy, cx + tile - 1, cy + tile - 1),
                            fill=(52, 48, 59, 255),
                        )
            checker.alpha_composite(icon)
            sheet.alpha_composite(checker, (x, y))
            draw.text((x + 4, y + cell + 5), f"L{level}", fill=(190, 190, 200, 255), font=font)
        for boundary in (3, 6, 9):
            x = label_width + boundary * cell
            draw.line((x, y, x, y + cell), fill=(212, 170, 70, 255), width=2)

    destination.parent.mkdir(parents=True, exist_ok=True)
    save_atomic(sheet.convert("RGB"), destination)


def validate(output_dir: Path) -> None:
    errors: list[str] = []
    for stat in FAMILIES.values():
        hashes: set[bytes] = set()
        for level in range(1, 11):
            path = output_dir / f"gem_{stat}_lv{level}.png"
            if not path.exists():
                errors.append(f"{path.name}: missing")
                continue
            image = Image.open(path).convert("RGBA")
            if image.size != (TARGET, TARGET):
                errors.append(f"{path.name}: expected {TARGET}x{TARGET}, got {image.size}")
            alpha = np.asarray(image)[..., 3]
            if np.any((alpha != 0) & (alpha != 255)):
                errors.append(f"{path.name}: semi-transparent pixels")
            # Centring gate: the visible bbox must sit within a pixel of the
            # icon centre and never touch an edge (this is the "gems sit
            # off-centre in their sockets" defect, 2026-08-15).
            ys, xs = np.nonzero(alpha)
            if xs.size:
                off_x = (xs.min() + xs.max()) / 2 - (TARGET - 1) / 2
                off_y = (ys.min() + ys.max()) / 2 - (TARGET - 1) / 2
                if abs(off_x) > 1 or abs(off_y) > 1:
                    errors.append(f"{path.name}: content off-centre by ({off_x:+.1f}, {off_y:+.1f}) px")
                if xs.min() < EDGE_MARGIN or ys.min() < EDGE_MARGIN \
                        or xs.max() >= TARGET - EDGE_MARGIN or ys.max() >= TARGET - EDGE_MARGIN:
                    errors.append(f"{path.name}: content touches the icon edge")
            hashes.add(image.tobytes())
        if len(hashes) != 10:
            errors.append(f"{stat}: levels are not all visually distinct ({len(hashes)}/10)")
    if errors:
        raise RuntimeError("\n".join(errors))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--mobile-out", type=Path, default=DEFAULT_MOBILE)
    parser.add_argument("--no-mobile", action="store_true")
    args = parser.parse_args()

    source_dir = args.source.resolve()
    output_dir = args.out.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    missing = [source_dir / f"{family}_master.png" for family in FAMILIES]
    missing = [path for path in missing if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing gem masters:\n" + "\n".join(map(str, missing)))

    written: list[Path] = []
    for family, stat in FAMILIES.items():
        written.extend(build_family(source_dir / f"{family}_master.png", stat, output_dir))
    validate(output_dir)
    contact = source_dir / "qa_contact_sheet.png"
    make_contact_sheet(output_dir, contact)

    if not args.no_mobile:
        mobile_dir = args.mobile_out.resolve()
        mobile_dir.mkdir(parents=True, exist_ok=True)
        for path in written:
            tmp = mobile_dir / (path.name + ".tmp")
            shutil.copy2(path, tmp)
            os.replace(tmp, mobile_dir / path.name)
        validate(mobile_dir)

    print(f"Built {len(written)} lore-authored gem icons in {output_dir}")
    print(f"QA contact sheet: {contact}")
    if not args.no_mobile:
        print(f"Mirrored icons to {args.mobile_out.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
