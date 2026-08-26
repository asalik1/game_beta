#!/usr/bin/env python3
"""M1a: deterministic 256-cell rebuild of the ROBE/idle-only mobs + skeleton_rogue
from their archived hi-res masters (art_src/Custom/MobWalkRepairs_2026-08-08).

Zero generation, zero drift: same masters, bigger target cell. Metric notes:
- idle `_anim` + `_walk` strips render normalized by their OWN cell -> only the
  body/cell FRACTION matters (preserved: references upscaled uniformly x4/3).
- `_attack` / `_death` render at the IDLE's absolute cell scale (enemy.gd
  _apply_strip ref=_body_cell) -> they must move to the 256 metric together
  with the idle. Attacks rebuild from masters via the upscaled references;
  deaths (no masters exist) are x4/3 LANCZOS metric-alignment upscales until
  the M2 death regen wave replaces them.
- 8-dir walk sets: dead art for these mobs (IDLE_ONLY / FLAT_WALK buckets).

Stages into OUT (never straight into game/); review sheets + fraction
assertions run before any copy.
"""
import sys, shutil
from pathlib import Path
import numpy as np
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
sys.path.insert(0, str(REPO / "tools" / "art"))
import build_mob_walk_repairs as bmwr

HERE = Path(__file__).parent
REF256 = HERE / "references256"
OUT = HERE / "m1_staged"
SPR = REPO / "game" / "assets" / "sprites"
UP = 4 / 3  # 192 -> 256

ROBE = ["mummy", "mummy_mage", "static_caller", "skeleton_mage",
        "skeleton_warrior", "null_acolyte"]

def upscale(p: Path, dst: Path) -> None:
    im = Image.open(p).convert("RGBA")
    im = im.resize((round(im.width * UP), round(im.height * UP)),
                   Image.Resampling.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)

def body_fraction(p: Path) -> float:
    im = Image.open(p).convert("RGBA")
    cell = im.height
    a = np.asarray(im.crop((0, 0, cell, im.height)))[..., 3]
    ys = np.where((a > 24).any(axis=1))[0]
    return (ys[-1] - ys[0] + 1) / cell if len(ys) else 0.0

def main() -> int:
    REF256.mkdir(exist_ok=True)
    OUT.mkdir(exist_ok=True)
    # 1. upscaled references (metric-only: values scale uniformly with the image)
    for key in ROBE:
        src = bmwr.REFERENCES / f"{key}.png"
        if not src.exists():
            src = SPR / f"{key}.png"
        upscale(src, REF256 / f"{key}.png")
    for name in ["skeleton_rogue_walk", "skeleton_rogue"]:
        src = bmwr.REFERENCES / f"{name}.png"
        if not src.exists():
            src = SPR / f"{name}.png"
        upscale(src, REF256 / f"{name}.png")

    # 2. patch the builder to read 256 references and write into the stage
    bmwr.REFERENCES = REF256
    bmwr.SPRITES = OUT
    def _ref_path(key: str, suffix: str = "") -> Path:
        p = REF256 / f"{key}{suffix}.png"
        if not p.exists():
            # build on demand from frozen ref else live sprite
            src = Path(bmwr.SOURCE / "references" / f"{key}{suffix}.png")
            if not src.exists():
                src = SPR / f"{key}{suffix}.png"
            if not src.exists():
                raise FileNotFoundError(f"no reference for {key}{suffix}")
            upscale(src, p)
        return p
    bmwr.reference_path = _ref_path

    old_frac = {}
    for key in ROBE + ["skeleton_rogue"]:
        old_frac[key] = body_fraction(SPR / f"{key}_anim.png")

    # 3. deterministic rebuilds
    for key in ROBE:
        bmwr.install_idle_only(key)          # static (not null_acolyte) + _anim
        print(f"idle+anim  {key}")
        if key in bmwr.ROBE_ATTACKS:
            bmwr.install_robe_attack(key)
            print(f"attack     {key} (robe)")
    bmwr.install_generated_attack("null_acolyte")
    print("attack     null_acolyte (generated)")
    bmwr.install_barrow_wight()              # skeleton_rogue anim/walk/attack/death + static
    print("barrow     skeleton_rogue (anim/walk/attack/death/static)")

    # 4. metric-alignment upscales (no masters): deaths + null_acolyte static
    for key in ROBE:
        upscale(SPR / f"{key}_death.png", OUT / f"{key}_death.png")
        print(f"death x4/3 {key}")
    upscale(SPR / "null_acolyte.png", OUT / "null_acolyte.png")
    print("static x4/3 null_acolyte")

    # 5. assertions: cell = 256-ish, body fraction preserved, nothing transparent
    bad = []
    for key in ROBE + ["skeleton_rogue"]:
        p = OUT / f"{key}_anim.png"
        im = Image.open(p)
        cell = im.height
        nf = body_fraction(p)
        d = abs(nf - old_frac[key])
        status = "OK" if d <= 0.03 and cell >= 255 else "BAD"
        if status == "BAD":
            bad.append(key)
        print(f"  {key:16s} cell {cell:3d}  frac {old_frac[key]:.3f} -> {nf:.3f}  {status}")
    print("STAGED ->", OUT)
    return 1 if bad else 0

if __name__ == "__main__":
    raise SystemExit(main())
