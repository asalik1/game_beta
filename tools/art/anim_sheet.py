"""anim_sheet — labeled sprite-sheet contact sheets for reviewing a character's
animations, SPLIT one image per clip so each stays readable.

This is the owner's preferred format for QA-ing generated character art: instead
of one giant grid, you get a titled sheet per clip (WALK, DASH, ATTACK, ...) with
the 8 facings down the left (S/SE/E/NE/N/NW/W/SW) and the frames across the top
(f1..fN, 1-based). Big labels so you can point precisely ("dash NE f4"). The
review flow is: generate the group you want, then read the sheets one clip at a
time (e.g. "movement", then "attacks") and call out bad frames by facing+frame —
which then get fixed by frame-dupe / skin-repaint / single-direction re-roll.

The hero render lays each clip out as <base>_<clip>_<dir>.png horizontal strips
(cell = strip height, N frames = width/cell); `idle` uses the legacy `anim`
suffix. This reads those directly (no --import needed) and never touches game art.

Usage:
  python anim_sheet.py <art_base> [group|clips] [out_dir] [scale]

  art_base   sprite base under assets/sprites/, no _<clip>_<dir> suffix, e.g.
             "skins/elite/assassin_blade_dancer" or "skins/mythic/assassin_phantom_awakened"
  group      one of: movement (idle/walk/run/dash), attacks (attack/attack2/cast),
             ult (ult/ultidle), death, all (default) — OR a comma list of clip
             names, e.g. "walk,run,dash".
  out_dir    where to write the PNGs (default: ./_sheets)
  scale      integer NEAREST upscale of each frame (default 3)

Writes <out_dir>/<basename>_<clip>.png for every clip that has art on disk.

Examples:
  python tools/art/anim_sheet.py skins/elite/assassin_blade_dancer movement
  python tools/art/anim_sheet.py skins/mythic/assassin_phantom_awakened attacks
  python tools/art/anim_sheet.py archer_anim all C:/tmp/sheets 4
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ASSETS = r"C:\Users\asali\Projects\MMO\game\assets\sprites"
DIRS = [("SOUTH (S)", "s"), ("SOUTH-EAST (SE)", "se"), ("EAST (E)", "e"),
        ("NORTH-EAST (NE)", "ne"), ("NORTH (N)", "n"), ("NORTH-WEST (NW)", "nw"),
        ("WEST (W)", "w"), ("SOUTH-WEST (SW)", "sw")]
# clip name -> file suffix (idle keeps the legacy "anim" suffix)
CLIP_FILE = {"idle": "anim", "walk": "walk", "run": "run", "dash": "dash",
             "attack": "attack", "attack2": "attack2", "cast": "cast",
             "ult": "ult", "ultidle": "ultidle", "death": "death"}
GROUPS = {
    "movement": ["idle", "walk", "run", "dash"],
    "attacks":  ["attack", "attack2", "cast"],
    "ult":      ["ult", "ultidle"],
    "death":    ["death"],
    "all":      ["idle", "walk", "run", "dash", "attack", "attack2", "cast",
                 "ult", "ultidle", "death"],
}


def _font(sz):
    for f in (r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, sz)
            except Exception:
                pass
    return ImageFont.load_default()


def _frames(path):
    im = Image.open(path).convert("RGBA")
    cell = im.size[1]
    nf = max(1, im.size[0] // cell)
    a = np.asarray(im)[:, :, 3] > 40
    ys = np.where(a.any(axis=1))[0]
    y0, y1 = (max(0, ys.min() - 2), min(cell, ys.max() + 2)) if len(ys) else (0, cell)
    return [im.crop((i * cell, y0, (i + 1) * cell, y1)) for i in range(nf)]


def sheet(art_base, clip, out_dir, scale=3):
    suf = CLIP_FILE.get(clip, clip)
    rows = []
    for lab, d in DIRS:
        p = os.path.join(ASSETS, f"{art_base}_{suf}_{d}.png")
        if os.path.exists(p):
            rows.append((lab, _frames(p)))
    if not rows:
        return False
    pad, labw, colh, titleh = 8, 190, 30, 48
    maxf = max(len(f) for _, f in rows)
    fw = int(rows[0][1][0].size[0] * scale)
    fh = int(rows[0][1][0].size[1] * scale)
    W = labw + maxf * (fw + pad) + pad
    H = titleh + colh + len(rows) * (fh + pad) + pad
    cv = Image.new("RGBA", (W, H), (28, 30, 36, 255))
    dr = ImageDraw.Draw(cv)
    tf, cf, rf = _font(32), _font(24), _font(23)
    name = os.path.basename(art_base)
    dr.rectangle([0, 0, W, titleh], fill=(58, 62, 72, 255))
    dr.text((16, 8), f"{name}  —  {clip.upper()}  (rows = facing, cols = frame)",
            font=tf, fill=(255, 225, 120, 255))
    for i in range(maxf):
        dr.text((labw + i * (fw + pad) + fw // 2 - 12, titleh + 4), f"f{i + 1}",
                font=cf, fill=(255, 225, 120, 255))
    y = titleh + colh
    for lab, frames in rows:
        dr.rectangle([0, y, labw - 2, y + fh], fill=(46, 48, 56, 255))
        dr.text((10, y + fh // 2 - 11), lab, font=rf, fill=(240, 240, 245, 255))
        x = labw
        for fr in frames:
            cv.alpha_composite(fr.resize((fw, fh), Image.NEAREST), (x, y))
            x += fw + pad
        y += fh + pad
    os.makedirs(out_dir, exist_ok=True)
    outp = os.path.join(out_dir, f"{name}_{clip}.png")
    cv.convert("RGB").save(outp)
    print("wrote", outp)
    return True


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    art_base = sys.argv[1]
    group = sys.argv[2] if len(sys.argv) > 2 else "all"
    out_dir = sys.argv[3] if len(sys.argv) > 3 else "_sheets"
    scale = int(sys.argv[4]) if len(sys.argv) > 4 else 3
    clips = GROUPS.get(group) or [c.strip() for c in group.split(",") if c.strip()]
    made = sum(sheet(art_base, c, out_dir, scale) for c in clips)
    print(f"{made} sheet(s) written to {out_dir}  (clips with no art on disk are skipped)")


if __name__ == "__main__":
    main()
