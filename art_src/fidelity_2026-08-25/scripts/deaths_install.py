#!/usr/bin/env python3
"""Wave B death installs: green 2x2 collapse masters -> 4-frame 256-metric strips.

Anchoring: a death goes standing -> lying, so per-frame height normalization
would blow up the prone frames. ONE shared scale comes from frame 1 (standing)
vs the INSTALLED death strip's frame-1 body height (the proven in-game
geometry, already at the 256 metric via the x4/3 alignment upscales); every
frame's bottom lands on the installed strip's ground line. Cell grows past 256
if a prone frame is wider (deaths are action strips: enemy.gd renders them at
the idle cell scale, grown cells just buy headroom).
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
sys.path.insert(0, str(REPO / "tools" / "art"))
import build_mob_walk_repairs as bmwr

HERE = Path(__file__).parent
SPR = REPO / "game" / "assets" / "sprites"
STAGES = HERE / "death_stages"
OUT = HERE / "deaths_staged"

def cut4(master):
    # grid-first: death masters come back as 2x2 even at wide aspects
    # (elf_ranger 1564x1006 fooled the row heuristic into column bands).
    if master.width < master.height * 1.9:
        try:
            return bmwr.four_grid_subjects_gutters(master)
        except Exception:
            return bmwr.four_grid_subjects(master)
    try:
        return bmwr.four_whole_subjects(master)
    except ValueError:
        return bmwr.four_columns(master)

def build(mob: str) -> str:
    mp = STAGES / f"{mob}_death" / f"{mob}_death_master.png"
    if not mp.exists():
        return "PENDING"
    cur = Image.open(SPR / f"{mob}_death.png").convert("RGBA")
    cell = cur.height
    n = cur.width // cell
    boxes = [bmwr.alpha_box(cur.crop((i * cell, 0, (i + 1) * cell, cell))) for i in range(n)]
    ref_h1 = boxes[0][3] - boxes[0][1]              # standing frame body height
    ground = max(b[3] for b in boxes)               # proven ground line
    cx = (boxes[0][0] + boxes[0][2]) / 2.0
    frames = cut4(bmwr.remove_green(mp))
    nb = [bmwr.alpha_box(f) for f in frames]
    scale = ref_h1 / max(1, nb[0][3] - nb[0][1])
    subjects = []
    for f, b in zip(frames, nb):
        s = f.crop(b)
        s = s.resize((max(1, round(s.width * scale)), max(1, round(s.height * scale))),
                     Image.Resampling.LANCZOS)
        rgba = np.asarray(s.convert("RGBA")).copy()
        rgba[..., 3] = np.where(rgba[..., 3] >= 96, 255, 0).astype(np.uint8)
        subjects.append(Image.fromarray(rgba, "RGBA"))
    ncell = max(cell, max(s.width for s in subjects) + 4)
    out = []
    for s in subjects:
        canvas = Image.new("RGBA", (ncell, ncell))
        x = round(cx + (ncell - cell) / 2.0 - s.width / 2)
        y = round(ground + (ncell - cell) - s.height)   # keep ground at same offset from bottom
        y = min(y, ncell - s.height - 1)
        x = max(0, min(x, ncell - s.width))
        canvas.alpha_composite(s, (x, max(0, y)))
        out.append(canvas)
    OUT.mkdir(exist_ok=True)
    bmwr.save_strip(out, OUT / f"{mob}_death.png")
    return f"OK cell {ncell} scale {scale:.2f}"

def main() -> int:
    mobs = sys.argv[1:] or [d.name[:-6] for d in sorted(STAGES.iterdir())
                            if d.is_dir() and d.name.endswith("_death")]
    for mob in mobs:
        try:
            r = build(mob)
        except Exception as e:  # noqa: BLE001
            r = f"ERROR {e}"
        if r != "PENDING":
            print(f"{mob:18s} {r}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
