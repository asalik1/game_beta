#!/usr/bin/env python3
"""M2: per-mob atomic 256-metric switch for the 11 non-robe mobs.

Per mob (order matters — later strips reference earlier ones):
1. idle: generated 2x2 master -> remove_green -> 4 frames -> normalize against
   the x4/3-upscaled OLD reference (metric continuity: body/cell fraction
   preserved) -> staged `<k>_anim.png` + `<k>.png` (frame 0).
2. attack: rebuilt from its hi-res master against the NEW static (grown cell
   >= 256); orc & banshee have no trusted master -> x4/3 metric upscale.
3. flat walk (FLAT_WALK bucket, master exists): rebuilt against the NEW _anim.
   8-dir walk sets (banshee/fungus_*) are fraction-normalized -> untouched.
4. death: x4/3 hard-alpha metric upscale (Wave B may regen real detail later).
5. gates: body-fraction delta <= 0.03, no transparent frames (save_strip),
   staged only — copy to game/ happens after the visual drift review.

stone_broken follows the owner's legacy structure: static+single-frame anim =
new idle frame 0, walk = the 4 new idle frames.
"""
import io, subprocess, sys
from pathlib import Path
import numpy as np
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
sys.path.insert(0, str(REPO / "tools" / "art"))
import build_mob_walk_repairs as bmwr

HERE = Path(__file__).parent
REF256 = HERE / "references256"
OUT = HERE / "m2_staged"
SPR = REPO / "game" / "assets" / "sprites"
STAGES = HERE / "mob_stages"
UP = 4 / 3

MOBS = ["elf_druid", "bandit_scout", "elf_ranger", "orc_rogue", "royal_knight",
        "orc", "fungus_long", "vow_sentinel", "fungus_heavy", "banshee", "stone_broken"]
ATTACK_FROM_MASTER = {"elf_druid", "bandit_scout", "elf_ranger", "orc_rogue",
                      "royal_knight", "fungus_long", "vow_sentinel", "fungus_heavy",
                      "stone_broken"}
FLAT_WALK_FROM_MASTER = {"elf_druid", "bandit_scout", "elf_ranger", "orc_rogue",
                         "royal_knight", "orc", "vow_sentinel"}

def upscale(im: Image.Image, hard=True) -> Image.Image:
    im = im.resize((round(im.width * UP), round(im.height * UP)), Image.Resampling.LANCZOS)
    if hard:
        rgba = np.asarray(im.convert("RGBA")).copy()
        rgba[..., 3] = np.where(rgba[..., 3] >= 96, 255, 0).astype(np.uint8)
        im = Image.fromarray(rgba, "RGBA")
    return im

def git_orig(rel: str) -> Image.Image:
    blob = subprocess.run(["git", "-C", str(REPO), "show", f"HEAD:{rel}"],
                          capture_output=True).stdout
    return Image.open(io.BytesIO(blob)).convert("RGBA")

def body_fraction(p: Path) -> float:
    im = Image.open(p).convert("RGBA")
    cell = im.height
    a = np.asarray(im.crop((0, 0, cell, im.height)))[..., 3]
    ys = np.where((a > 24).any(axis=1))[0]
    return (ys[-1] - ys[0] + 1) / cell if len(ys) else 0.0

def ensure_ref(key: str, suffix: str = "") -> Path:
    p = REF256 / f"{key}{suffix}.png"
    if not p.exists():
        src = bmwr.SOURCE / "references" / f"{key}{suffix}.png"
        if not src.exists():
            src = SPR / f"{key}{suffix}.png"
        if not src.exists():
            raise FileNotFoundError(f"no reference source for {key}{suffix}")
        im = Image.open(src).convert("RGBA")
        p.parent.mkdir(exist_ok=True)
        upscale(im, hard=False).save(p)
    return p

def cut4(master: Image.Image) -> list[Image.Image]:
    if master.width < master.height * 1.5:
        try:
            return bmwr.four_grid_subjects_gutters(master)
        except Exception:
            return bmwr.four_grid_subjects(master)
    try:
        return bmwr.four_whole_subjects(master)
    except ValueError:
        return bmwr.four_columns(master)

def build_mob(key: str) -> str:
    mp = STAGES / f"{key}_idle" / f"{key}_idle_master.png"
    if not mp.exists():
        return "PENDING"
    old_frac = body_fraction(SPR / f"{key}_anim.png")
    ref = ensure_ref(key)
    master = bmwr.remove_green(mp)
    frames = bmwr.normalize(cut4(master), ref)
    # some originals ground on the cell's LAST row (fungus_long ground_y ==
    # cell) — normalize faithfully reproduces that and validate_motion then
    # rejects the bottom-edge touch. Lift ALL frames uniformly by the overlap
    # (1-2px, no jitter) instead of failing.
    overlap = max(bmwr.alpha_box(f)[3] - (f.height - 1) for f in frames)
    if overlap > 0:
        lifted = []
        for f in frames:
            c = Image.new("RGBA", f.size)
            c.alpha_composite(f, (0, -overlap))
            lifted.append(c)
        frames = lifted
    bmwr.validate_motion(frames, key)
    if key == "stone_broken":
        # owner-specified legacy structure: static + 1-frame anim + 4-frame walk
        bmwr.save_png(frames[0], OUT / f"{key}.png")
        bmwr.save_strip([frames[0]], OUT / f"{key}_anim.png")
        bmwr.save_strip(frames, OUT / f"{key}_walk.png")
    else:
        bmwr.save_strip(frames, OUT / f"{key}_anim.png")
        bmwr.save_png(frames[0], OUT / f"{key}.png")
    # attack
    if key in ATTACK_FROM_MASTER:
        bmwr.install_generated_attack(key)
    else:
        att = git_orig(f"game/assets/sprites/{key}_attack.png")
        bmwr.save_png(upscale(att), OUT / f"{key}_attack.png")
    # flat walk
    if key in FLAT_WALK_FROM_MASTER:
        bmwr.install_walk(key)
    # death
    death = git_orig(f"game/assets/sprites/{key}_death.png")
    bmwr.save_png(upscale(death), OUT / f"{key}_death.png")
    nf = body_fraction(OUT / f"{key}_anim.png")
    d = abs(nf - old_frac)
    cell = Image.open(OUT / f"{key}_anim.png").height
    return f"OK cell {cell} frac {old_frac:.3f}->{nf:.3f}" + ("" if d <= 0.03 else "  FRAC-DRIFT!")

def main() -> int:
    OUT.mkdir(exist_ok=True)
    # route builder output/refs to the stage
    bmwr.SPRITES = OUT
    orig_ref_path = bmwr.reference_path
    def _ref(key: str, suffix: str = "") -> Path:
        # walk/attack rebuilds must reference the NEW staged idle metric
        staged = OUT / f"{key}{suffix}.png"
        if staged.exists():
            return staged
        return ensure_ref(key, suffix)
    bmwr.reference_path = _ref
    names = sys.argv[1:] or MOBS
    for key in names:
        try:
            r = build_mob(key)
        except Exception as e:  # noqa: BLE001
            r = f"ERROR {e}"
        if r != "PENDING":
            print(f"{key:16s} {r}")
        else:
            print(f"{key:16s} pending (master not generated yet)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
