#!/usr/bin/env python3
"""P7.B (POLISH_TASKS.md, 2026-08-19): install the chest OPEN rows and the coin
SPIN row generated from tools/art/style_unify/make_loot_briefs.py.

  python tools/art/build_loot.py <stage_root> [chest_a coin ...]

chest_<key>/<key>_open_master_v1.png (row of 5) ->
    game/assets/sprites/chest_<key>.png        = f1 (closed), cell CHEST_CELL wide
    game/assets/sprites/chest_<key>_open.png   = 5 cells (closed -> open at rest)
    All five frames share ONE scale (the closed frame's width -> CHEST_W) and
    ONE bottom-centre anchor, so chest.gd's per-frame swap never moves the body.
coin/coin_spin_master_v1.png (row of 6) ->
    coin.png = f1 (full face) in a COIN_CELL square; coin_anim.png = 6 cells,
    every frame CENTRED (a spinning coin turns about its centre) at one scale
    (the face frame's height -> COIN_D).
Keying/despill + gutter-safe row split reuse build_mob_walk_repairs; replaced
sprites are backed up under art_src/Custom/Loot_2026-08-19/old/; raw masters,
briefs and results are archived beside them. game/ + mobile/ mirrors written.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_mob_walk_repairs import alpha_box, hard_alpha, remove_green, save_png, whole_subjects  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
MOBILE = ROOT / "mobile" / "game" / "assets" / "sprites"
ARCHIVE = ROOT / "art_src" / "Custom" / "Loot_2026-08-19"
CHEST_W = 112        # the closed chest's rendered width inside its cell
CHEST_CELL = 128     # cell width (lid may grow upward; cell height = tallest frame + margin)
COIN_D = 56          # coin diameter inside a COIN_CELL square
COIN_CELL = 64
CHESTS = ["chest_f", "chest_e", "chest_d", "chest_c", "chest_b", "chest_a", "chest_s",
          "chest_wood", "chest_silver", "chest_gold"]


def mirror(name: str) -> None:
    if MOBILE.exists():
        shutil.copy2(SPRITES / name, MOBILE / name)


def backup(*names: str) -> None:
    old = ARCHIVE / "old"
    old.mkdir(parents=True, exist_ok=True)
    for n in names:
        p = SPRITES / n
        if p.exists() and not (old / n).exists():
            shutil.copy2(p, old / n)


def archive(stage: Path, key: str, raw_name: str) -> Path:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    raw = stage / raw_name
    if not raw.exists():
        raise FileNotFoundError(f"{raw} (see {stage / 'codex_result.md'})")
    dst = ARCHIVE / f"{key}_master.png"
    shutil.copy2(raw, dst)
    for extra, suffix in (("codex_brief.txt", "_codex_brief_2026-08-19.txt"),
                          ("codex_result.md", "_codex_result_2026-08-19.md")):
        if (stage / extra).exists():
            shutil.copy2(stage / extra, ARCHIVE / f"{key}{suffix}")
    return dst


def scaled(frame: Image.Image, box: tuple, scale: float) -> Image.Image:
    sub = frame.crop(box)
    return hard_alpha(sub.resize((max(1, round(sub.width * scale)), max(1, round(sub.height * scale))),
                                 Image.Resampling.LANCZOS))


def install_chest(stage_root: Path, key: str) -> None:
    master = archive(stage_root / key, key, f"{key}_open_master_v1.png")
    backup(f"{key}.png", f"{key}_open.png")
    source = remove_green(master)
    frames = whole_subjects(source, 5)
    boxes = [alpha_box(f) for f in frames]
    closed_w = boxes[0][2] - boxes[0][0]
    scale = CHEST_W / max(1, closed_w)
    subs = [scaled(f, b, scale) for f, b in zip(frames, boxes)]
    # One anchor: bottom-centre of the CLOSED frame; the body never moves, so
    # every frame's bottom lands on the same line. Cell height = tallest + margin.
    tallest = max(s.height for s in subs)
    cell_h = tallest + 8
    strip = Image.new("RGBA", (CHEST_CELL * 5, cell_h))
    for i, s in enumerate(subs):
        x = i * CHEST_CELL + (CHEST_CELL - s.width) // 2
        y = cell_h - 4 - s.height
        strip.alpha_composite(s, (x, y))
    save_png(strip, SPRITES / f"{key}_open.png")
    closed = strip.crop((0, 0, CHEST_CELL, cell_h))
    save_png(closed, SPRITES / f"{key}.png")
    mirror(f"{key}_open.png")
    mirror(f"{key}.png")
    print(f"{key}: closed {closed.size} open strip {strip.size} (scale {scale:.3f})")


def install_coin(stage_root: Path) -> None:
    master = archive(stage_root / "coin", "coin", "coin_spin_master_v1.png")
    backup("coin.png", "coin_anim.png")
    source = remove_green(master)
    frames = whole_subjects(source, 6)
    boxes = [alpha_box(f) for f in frames]
    face_h = boxes[0][3] - boxes[0][1]
    scale = COIN_D / max(1, face_h)
    strip = Image.new("RGBA", (COIN_CELL * 6, COIN_CELL))
    for i, (f, b) in enumerate(zip(frames, boxes)):
        s = scaled(f, b, scale)
        if s.height > COIN_CELL or s.width > COIN_CELL:
            k = min(COIN_CELL / s.height, COIN_CELL / s.width)
            s = hard_alpha(s.resize((max(1, round(s.width * k)), max(1, round(s.height * k))),
                                    Image.Resampling.LANCZOS))
        x = i * COIN_CELL + (COIN_CELL - s.width) // 2
        y = (COIN_CELL - s.height) // 2
        strip.alpha_composite(s, (x, y))
        if not (np.asarray(s.getchannel("A")) > 0).any():
            raise ValueError(f"coin frame {i} is empty")
    save_png(strip, SPRITES / "coin_anim.png")
    save_png(strip.crop((0, 0, COIN_CELL, COIN_CELL)), SPRITES / "coin.png")
    mirror("coin_anim.png")
    mirror("coin.png")
    print(f"coin: 6x{COIN_CELL} spin strip (scale {scale:.3f})")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("keys", nargs="*")
    args = ap.parse_args()
    root = Path(args.stage_root)
    keys = args.keys or (CHESTS + ["coin"])
    failed = []
    for key in keys:
        try:
            if key == "coin":
                install_coin(root)
            else:
                install_chest(root, key)
        except Exception as exc:
            failed.append(key)
            print(f"FAIL {key}: {exc}")
    print(f"done: {len(keys) - len(failed)} ok, {len(failed)} failed {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
