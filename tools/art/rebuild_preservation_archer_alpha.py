#!/usr/bin/env python3
"""Rebuild Archer idle/walk candidates without deleting green costume pixels.

The original preservation builder used a global green-dominance key, which was
unsafe for Archer's green cape. This rebuild removes only key-colored pixels
that are connected to the source-image border. Enclosed green cape pixels keep
their original RGB values and become fully opaque.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_ledgerbound_warlock import _hard_alpha  # noqa: E402
from build_preservation_walk_candidate import (  # noqa: E402
    _crop_frames,
    _normalize,
    _write_cut_overlay,
    _write_qa,
)


ROOT = Path(__file__).resolve().parents[2]
ARCHER = (
    ROOT
    / "art_src"
    / "class_preservation_upscale_2026-08-01"
    / "archer"
)

JOBS = (
    ("idle_s", "archer_idle_s_v03_closed_mouth_source.png", "archer_idle_s_v03_closed_mouth_alpha_fixed", 4, 6.0),
    ("idle_se", "archer_idle_se_v03_neutral_source.png", "archer_idle_se_v03_neutral_alpha_fixed", 4, 6.0),
    ("idle_e", "archer_idle_e_v01_source.png", "archer_idle_e_v01_alpha_fixed", 4, 6.0),
    ("idle_ne", "archer_idle_ne_v01_source.png", "archer_idle_ne_v01_alpha_fixed", 4, 6.0),
    ("idle_n", "archer_idle_n_v01_source.png", "archer_idle_n_v01_alpha_fixed", 4, 6.0),
    ("idle_nw", "archer_idle_nw_v01_source.png", "archer_idle_nw_v01_alpha_fixed", 4, 6.0),
    ("idle_w", "archer_idle_w_v01_source.png", "archer_idle_w_v01_alpha_fixed", 4, 6.0),
    ("idle_sw", "archer_idle_sw_v02_neutral_source.png", "archer_idle_sw_v02_neutral_alpha_fixed", 4, 6.0),
    ("walk_s", "archer_walk_s_v02_neutral_source.png", "archer_walk_s_v02_neutral_alpha_fixed", 6, 9.0),
    ("walk_se", "archer_walk_se_v02_neutral_source.png", "archer_walk_se_v02_neutral_alpha_fixed", 6, 9.0),
    ("walk_e", "archer_walk_e_v01_source.png", "archer_walk_e_v01_alpha_fixed", 6, 9.0),
    ("walk_ne", "archer_walk_ne_v01_source.png", "archer_walk_ne_v01_alpha_fixed", 6, 9.0),
    ("walk_n", "archer_walk_n_v01_source.png", "archer_walk_n_v01_alpha_fixed", 6, 9.0),
    ("walk_nw", "archer_walk_nw_v02_source.png", "archer_walk_nw_v02_alpha_fixed", 6, 9.0),
    ("walk_w", "archer_walk_w_v02_source.png", "archer_walk_w_v02_alpha_fixed", 6, 9.0),
    ("walk_sw", "archer_walk_sw_v02_neutral_source.png", "archer_walk_sw_v02_neutral_alpha_fixed", 6, 9.0),
)


def _border_key(image: Image.Image) -> np.ndarray:
    rgb = np.asarray(image.convert("RGB"), dtype=np.uint8)
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]), axis=0)
    return np.median(border.astype(np.float32), axis=0)


def _connected_key(image: Image.Image) -> tuple[Image.Image, tuple[int, int, int], int]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = rgba[..., :3].astype(np.float32)
    key = _border_key(image)
    key_max = float(key.max())
    key_channels = [
        index
        for index, value in enumerate(key)
        if value >= key_max - 32.0 and value >= 128.0
    ]
    other_channels = [index for index in range(3) if index not in key_channels]
    distance = np.max(np.abs(rgb - key.reshape((1, 1, 3))), axis=2)
    if key_channels:
        key_strength = np.min(rgb[..., key_channels], axis=2)
        other_strength = (
            np.max(rgb[..., other_channels], axis=2)
            if other_channels
            else np.zeros(rgb.shape[:2], dtype=np.float32)
        )
        dominance = (key_strength > 72.0) & (key_strength > other_strength + 24.0)
    else:
        dominance = np.zeros(rgb.shape[:2], dtype=bool)
    close_key = distance <= 84.0

    # Flood only the key-like component connected to the outer field. Identical
    # green values enclosed by Archer's dark cape outline are never selected.
    mask = Image.fromarray(np.where(dominance, 255, 0).astype(np.uint8), "L")
    draw = ImageDraw.Draw(mask)
    width, height = mask.size
    for point in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        if mask.getpixel(point) == 255:
            ImageDraw.floodfill(mask, point, 128, thresh=0)
    connected_background = np.asarray(mask, dtype=np.uint8) == 128
    # Exact/near-exact key pixels are background even when enclosed by a bow or
    # a gap between limbs. Broader green-dominant pixels are removed only when
    # connected to the outer field, which protects the darker green cape.
    background = close_key | connected_background
    if not all((background[0, 0], background[0, -1], background[-1, 0], background[-1, -1])):
        raise ValueError("connected-key removal did not reach every source corner")

    rgba[..., 3] = np.where(background, 0, 255).astype(np.uint8)
    rgba[background, :3] = 0
    keyed = Image.fromarray(rgba, "RGBA")
    return keyed, tuple(int(round(value)) for value in key), int(background.sum())


def _write_candidate(
    output_dir: Path,
    stem: str,
    source: Path,
    frames_count: int,
    fps: float,
) -> None:
    keyed, key, removed = _connected_key(Image.open(source))
    keyed = _hard_alpha(keyed)
    keyed.save(output_dir / f"{stem}_keyed.png")
    frames, edges, gutters = _crop_frames(keyed, frames_count)
    _write_cut_overlay(output_dir / f"{stem}_cuts.png", keyed, edges, gutters)
    normalized = _normalize(frames, 180)
    strip = Image.new("RGBA", (277 * frames_count, 277), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        strip.alpha_composite(frame, (index * 277, 0))
    strip.save(output_dir / f"{stem}_candidate.png", optimize=True)
    _write_qa(
        output_dir,
        stem,
        f"Archer alpha-safe {'idle' if frames_count == 4 else 'walk'}",
        normalized,
        fps,
        3 if frames_count == 4 else 4,
    )
    print(
        f"{stem}: key={key}, removed={removed}, frames={frames_count}, "
        f"gutters={gutters}, cell=277, body=180"
    )


def main() -> None:
    for folder, source_name, stem, frames_count, fps in JOBS:
        output_dir = ARCHER / folder
        source = output_dir / source_name
        if not source.is_file():
            raise FileNotFoundError(source)
        _write_candidate(output_dir, stem, source, frames_count, fps)


if __name__ == "__main__":
    main()
