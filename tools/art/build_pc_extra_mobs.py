#!/usr/bin/env python3
"""P6.2 (POLISH_TASKS.md, 2026-08-19): install the Pixel Crawler EXTRA MOBS'
192px ImageGen bodies (briefs: tools/art/style_unify/make_pcmob_briefs.py).

Reuses the 2026-08-08 mob-repair builder's helpers (chroma key + despill,
gutter-safe 2x2 / row extraction, torso-locked normalization, hard alpha,
atomic save) so the result obeys the same contract as every repaired mob:
complete generated poses only, one ground line, the idle's body scale for
every clip. The NEW canvas is 192px; the body keeps the share of the cell the
old 32px sprite had (so the on-screen size — enemy.gd renders scale x 16 px per
cell whatever the art resolution — is unchanged).

  python tools/art/build_pc_extra_mobs.py <stage_root> --phase idle   [keys]
  python tools/art/build_pc_extra_mobs.py <stage_root> --phase action [keys]

idle   : <key>_idle/<key>_idle_master_v1.png (2x2) -> <key>.png (frame 0) + <key>_anim.png
action : <key>_walk/<key>_walk_master_v1.png (row of 8) -> <key>_walk.png
         <key>_attack/<key>_attack_master_v1.png (2x2) -> <key>_attack.png
Raw masters + briefs are archived under art_src/Custom/PcExtraMobs_2026-08-19/,
the replaced sprites under .../old/ (back up, never delete). game/ + mobile/
mirrors both written.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_mob_walk_repairs import (  # noqa: E402
    alpha_box, four_grid_subjects, four_grid_subjects_gutters, normalize_attack,
    normalize_locked_motion, remove_green, save_png, save_strip, validate_motion,
    whole_subjects,
)

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
MOBILE = ROOT / "mobile" / "game" / "assets" / "sprites"
ARCHIVE = ROOT / "art_src" / "Custom" / "PcExtraMobs_2026-08-19"
CELL = 192
KEYS = ["zombie_overweight", "mummy_rogue", "mummy_warrior", "fungus_immature",
        "elf_wild", "rat_rogue", "rat_warrior"]


def scaled_reference(key: str) -> Path:
    """A 192px reference cell carrying the OLD sprite's body share + ground line.

    normalize_* read their metrics from a reference PNG; the old 32px idle's
    first cell upscaled (nearest) to CELL keeps the same height fraction and
    ground fraction, so the new body lands at the old on-screen size.
    """
    refs = ARCHIVE / "references"
    refs.mkdir(parents=True, exist_ok=True)
    out = refs / f"{key}_ref{CELL}.png"
    if out.exists():
        return out
    src = SPRITES / f"{key}_anim.png"
    if not src.exists():
        src = SPRITES / f"{key}.png"
    with Image.open(src) as opened:
        strip = opened.convert("RGBA")
    cell = strip.height
    first = strip.crop((0, 0, cell, cell))
    # The 32px pack sprites fill their cell to the last row/column; a body that
    # touches the cell edge fails the repaired-mob contract (validate_motion), so
    # the reference keeps a 4px margin all round: ground line at CELL-4, body
    # 184/192 of the cell — a 2% smaller on-screen body, within size_var noise.
    canvas = Image.new("RGBA", (CELL, CELL))
    canvas.alpha_composite(first.resize((CELL - 8, CELL - 8), Image.Resampling.NEAREST), (4, 4))
    canvas.save(out)
    return out


def backup(key: str) -> None:
    old = ARCHIVE / "old"
    old.mkdir(parents=True, exist_ok=True)
    for suffix in ("", "_anim", "_walk", "_attack", "_death"):
        p = SPRITES / f"{key}{suffix}.png"
        if p.exists() and not (old / p.name).exists():
            shutil.copy2(p, old / p.name)


def archive_master(stage: Path, key: str, clip: str) -> Path:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    raw = stage / f"{key}_{clip}_master_v1.png"
    if not raw.exists():
        raise FileNotFoundError(f"{raw} (did the Codex job finish? see {stage / 'codex_result.md'})")
    dst = ARCHIVE / f"{key}_{clip}_master.png"
    shutil.copy2(raw, dst)
    brief = stage / "codex_brief.txt"
    if brief.exists():
        shutil.copy2(brief, ARCHIVE / f"{key}_{clip}_codex_brief_2026-08-19.txt")
    result = stage / "codex_result.md"
    if result.exists():
        shutil.copy2(result, ARCHIVE / f"{key}_{clip}_codex_result_2026-08-19.md")
    return dst


def mirror(name: str) -> None:
    if MOBILE.exists():
        shutil.copy2(SPRITES / name, MOBILE / name)


def grid4(image: Image.Image) -> list[Image.Image]:
    try:
        return four_grid_subjects_gutters(image)
    except ValueError:
        return four_grid_subjects(image)


def eight_subjects(image: Image.Image) -> list[Image.Image]:
    """A walk master is ONE ROW of eight, or (a re-roll for a crowded subject)
    a 2x4 GRID: two rows split at the widest empty row band, four per row at
    their real gutters, read left-to-right then top-to-bottom."""
    alpha = np.asarray(image.getchannel("A")) > 32
    if image.width >= image.height * 3.2:
        return row_subjects(image, 8)
    rows_empty = ~alpha.any(axis=1)
    h = alpha.shape[0]
    best = None
    start = None
    for y in range(h // 4, 3 * h // 4 + 1):
        on = y < 3 * h // 4 and bool(rows_empty[y])
        if on and start is None:
            start = y
        elif not on and start is not None:
            if best is None or y - start > best[1] - best[0]:
                best = (start, y)
            start = None
    if best is None:
        return row_subjects(image, 8)
    ycut = (best[0] + best[1]) // 2
    top = image.crop((0, 0, image.width, ycut))
    bottom = image.crop((0, ycut, image.width, image.height))
    return row_subjects(top, 4) + row_subjects(bottom, 4)


def row_subjects(image: Image.Image, count: int) -> list[Image.Image]:
    """Split a row at its real transparent gutters; a gutter only has to be
    one clean column wide (a khopesh tip two px from its neighbour is still a
    complete figure), so fall back from whole_subjects' 8 px minimum to 1 px.
    Figures that truly touch (no empty column) raise -- re-roll the master."""
    try:
        return whole_subjects(image, count)
    except ValueError:
        pass
    occupied = (np.asarray(image.getchannel("A")) > 32).any(axis=0)
    gaps = []
    start = None
    for x, value in enumerate(occupied):
        if not value and start is None:
            start = x
        elif value and start is not None:
            if start > 0:
                gaps.append((start, x))
            start = None
    if len(gaps) < count - 1:
        raise ValueError(f"generated strip has fewer than {count - 1} clean gutters (figures touch) -- re-roll")
    seps = []
    remaining = list(gaps)
    for index in range(1, count):
        target = image.width * index / count
        gap = min(remaining, key=lambda g: abs((g[0] + g[1]) / 2 - target))
        seps.append((gap[0] + gap[1]) // 2)
        remaining.remove(gap)
    seps.sort()
    bounds = [0, *seps, image.width]
    return [image.crop((bounds[i], 0, bounds[i + 1], image.height)) for i in range(count)]


def install_idle(stage_root: Path, key: str) -> None:
    master = archive_master(stage_root / f"{key}_idle", key, "idle")
    backup(key)
    ref = scaled_reference(key)
    source = remove_green(master)
    frames = normalize_locked_motion(grid4(source), ref, max_width_factor=1.15)
    validate_motion(frames, key)
    save_strip(frames, SPRITES / f"{key}_anim.png")
    save_png(frames[0], SPRITES / f"{key}.png")
    mirror(f"{key}_anim.png")
    mirror(f"{key}.png")
    box = alpha_box(frames[0])
    print(f"{key}: idle 4x{CELL} body {box[2]-box[0]}x{box[3]-box[1]} ground {box[3]}")


def install_action(stage_root: Path, key: str) -> None:
    idle_ref = SPRITES / f"{key}_anim.png"
    with Image.open(idle_ref) as opened:
        if opened.height != CELL:
            raise RuntimeError(f"{key}: install the idle phase first ({idle_ref} is {opened.height}px)")
    walk_master = archive_master(stage_root / f"{key}_walk", key, "walk")
    walk_src = remove_green(walk_master)
    walk = normalize_locked_motion(eight_subjects(walk_src), idle_ref, max_width_factor=1.5)
    save_strip(walk, SPRITES / f"{key}_walk.png")
    mirror(f"{key}_walk.png")
    attack_master = archive_master(stage_root / f"{key}_attack", key, "attack")
    attack_src = remove_green(attack_master)
    attack = normalize_attack(grid4(attack_src), idle_ref)
    save_strip(attack, SPRITES / f"{key}_attack.png")
    mirror(f"{key}_attack.png")
    print(f"{key}: walk 8x{walk[0].width} attack 4x{attack[0].width}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("--phase", choices=["idle", "action"], default="idle")
    ap.add_argument("keys", nargs="*")
    args = ap.parse_args()
    root = Path(args.stage_root)
    keys = args.keys or KEYS
    failed = []
    for key in keys:
        try:
            (install_idle if args.phase == "idle" else install_action)(root, key)
        except Exception as exc:  # report every mob, install the rest
            failed.append(key)
            print(f"FAIL {key}: {exc}")
    print(f"done: {len(keys) - len(failed)} ok, {len(failed)} failed {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
