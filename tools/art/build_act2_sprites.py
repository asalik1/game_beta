#!/usr/bin/env python3
"""Build the approved Act 2 creature art into Crownless sprite families.

Every source master is a strict 4x4 grid:
  row 1 idle, row 2 walk/drift, row 3 attack/ability, row 4 defeat.

The shared extraction code removes the green/magenta screen, slices four
192px frames per row, and installs the base + idle/walk/attack/death files.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

from build_mob_redesigns import (
    ANIMATIONS,
    TARGET_CELL,
    extract_grid,
    remove_chroma,
)


SPRITES = (
    # Chapter 8 — Ashen Verdict.
    "foundry_thrall", "slag_hound", "bellows_imp", "forge_zealot",
    "verdict_drone", "cindersmith", "smelter_lord_thrain",
    "verdant_anvil", "archon_vassik",
    # Chapter 9 — Verdant Cure.
    "sluice_lurker", "cistern_mimic", "root_spiderling",
    "drowned_warden", "cure_seeker_heretic", "bloat_leech",
    "broodmother_yskara", "overgrown_gatewarden", "pale_nursery",
    # Chapter 10 — Frozen Chorus.
    "chorister_of_frost", "glasshide_stalker", "rime_wolf",
    "sleepwalker", "shardcaller", "choir_of_frost", "glacius",
    "elara_vessel",
    # Chapter 11 — Shattered Vow.
    "bannerman", "crusade_zealot", "field_chirurgeon", "storm_adept",
    "oathbound_knight", "commander_drayce", "high_artificer_maeven",
    "shattered_vow", "aldric_burned_out",
    # Chapter 12 — Rootbound.
    "rootspawn", "anchor_vine", "thorn_howler", "grove_tender",
    "pollen_drifter", "rootweaver", "thornfather_grael",
    "heart_of_the_root",
    # Chapter 13 — The Unfinished Sentence.
    "word_wisp", "riftling", "sand_revenant", "conductor_acolyte",
    "void_hound", "unfinished_sentence", "korrag_reborn",
    "mouth_of_the_storm",
    # Chapter 14 — Hollow Flame.
    "choir_radical", "hollow_knight", "waking_shard", "flux_hound",
    "converted", "choir_ascendant", "burned_kings_echo",
    "morwyn_hollow_flame",
)


def default_source_dir() -> Path:
    return (
        Path(__file__).resolve().parents[2]
        / "art_src" / "Custom" / "Act2_2026-07-29"
    )


def validate(output_dir: Path, keys: tuple[str, ...] = SPRITES) -> None:
    errors: list[str] = []
    for key in keys:
        base = output_dir / f"{key}.png"
        if not base.exists() or Image.open(base).size != (TARGET_CELL, TARGET_CELL):
            errors.append(f"{base.name}: expected {TARGET_CELL}x{TARGET_CELL}")
        for animation in ANIMATIONS:
            strip = output_dir / f"{key}_{animation}.png"
            expected = (TARGET_CELL * 4, TARGET_CELL)
            if not strip.exists() or Image.open(strip).size != expected:
                errors.append(f"{strip.name}: expected {expected[0]}x{expected[1]}")
    if errors:
        raise RuntimeError("\n".join(errors))


def _components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    """Return 4-connected alpha components for one normalized frame."""
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    found: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            seen[y, x] = True
            queue = deque([(y, x)])
            component: list[tuple[int, int]] = []
            while queue:
                cy, cx = queue.popleft()
                component.append((cy, cx))
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if (
                        0 <= ny < height and 0 <= nx < width
                        and mask[ny, nx] and not seen[ny, nx]
                    ):
                        seen[ny, nx] = True
                        queue.append((ny, nx))
            found.append(component)
    return found


def _bbox(component: list[tuple[int, int]]) -> tuple[int, int, int, int]:
    ys = [point[0] for point in component]
    xs = [point[1] for point in component]
    return min(xs), min(ys), max(xs), max(ys)


def _box_gap(
    left: tuple[int, int, int, int],
    right: tuple[int, int, int, int],
) -> int:
    dx = max(left[0] - right[2] - 1, right[0] - left[2] - 1, 0)
    dy = max(left[1] - right[3] - 1, right[1] - left[3] - 1, 0)
    return max(dx, dy)


def clean_neighbor_bleed(frame: Image.Image) -> Image.Image:
    """Remove small, remote components leaked from an adjacent grid row.

    ImageGen occasionally lets the tip of a boot, robe, or weapon cross a
    nominal cell boundary. Those fragments land at an edge of the neighboring
    animation cell. Keep the main figure, nearby particles, orbiting pieces,
    and any substantial detached prop; discard only clipped minor components.
    """
    pixels = np.asarray(frame.convert("RGBA")).copy()
    components = _components(pixels[..., 3] > 0)
    if len(components) <= 1:
        return frame
    main = max(components, key=len)
    main_box = _bbox(main)
    main_area = len(main)
    keep = np.zeros(pixels.shape[:2], dtype=bool)
    for component in components:
        box = _bbox(component)
        touches_neighbor_entry = (
            box[0] == 0 or box[1] == 0 or box[2] == frame.width - 1
        )
        touches_bottom = box[3] == frame.height - 1
        nearby = _box_gap(main_box, box) <= 18
        substantial = len(component) >= max(24, int(main_area * 0.05))
        major_prop = len(component) >= max(48, int(main_area * 0.12))
        # Spill from any neighboring cell enters through one of the four cell
        # edges. Drop clipped fragments there unless the component is large
        # enough to be a deliberate detached prop (for example Korrag's flail
        # head). This also catches side-to-side row bleed and bottom-edge boot
        # or weapon scraps that a top-edge-only check missed.
        if component is not main:
            if touches_neighbor_entry:
                continue
            if touches_bottom and not major_prop:
                continue
        if component is main or nearby or (
            substantial and not touches_neighbor_entry and not touches_bottom
        ) or major_prop:
            for y, x in component:
                keep[y, x] = True
    pixels[~keep] = 0
    return Image.fromarray(pixels, "RGBA")


def clean_installed_family(key: str, output_dir: Path) -> None:
    """Clean every installed cell, then refresh the canonical static frame."""
    for animation in ANIMATIONS:
        path = output_dir / f"{key}_{animation}.png"
        strip = Image.open(path).convert("RGBA")
        cleaned = Image.new("RGBA", strip.size)
        for index in range(4):
            cell = strip.crop((
                index * TARGET_CELL, 0, (index + 1) * TARGET_CELL, TARGET_CELL
            ))
            cleaned.alpha_composite(clean_neighbor_bleed(cell), (index * TARGET_CELL, 0))
        cleaned.save(path, optimize=True)
    Image.open(output_dir / f"{key}_anim.png").crop(
        (0, 0, TARGET_CELL, TARGET_CELL)
    ).save(output_dir / f"{key}.png", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=default_source_dir())
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "game" / "assets" / "sprites",
    )
    parser.add_argument(
        "--keys",
        nargs="+",
        choices=SPRITES,
        help="rebuild only these canonical keys",
    )
    args = parser.parse_args()
    source_dir = args.source.resolve()
    output_dir = args.out.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    selected = tuple(args.keys) if args.keys else SPRITES

    missing = [
        source_dir / f"{key}_master.png"
        for key in selected
        if not (source_dir / f"{key}_master.png").exists()
    ]
    if missing:
        raise FileNotFoundError("Missing source masters:\n" + "\n".join(map(str, missing)))

    for key in selected:
        extract_grid(remove_chroma(source_dir / f"{key}_master.png"), key, output_dir)
        clean_installed_family(key, output_dir)

    validate(output_dir, selected)
    print(
        f"Built {len(selected)} Act 2 visuals x {len(ANIMATIONS)} strips "
        f"plus base sprites in {output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
