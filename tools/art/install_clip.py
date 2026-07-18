"""Surgical per-clip strip installer for the drift regen.

Unlike install_char_anims.py (which re-assembles EVERY clip and would clobber
hand-fixed strips like the death flats and upscaled statics), this installs
ONLY the named clip's named directions, at the character's EXISTING shared
cell (taken from a reference on-disk strip), bottom-center feet-anchored with
margin 3 to match install_dirset geometry. Originals are backed up first;
installs are mirrored to mobile/.

Usage (as a library from driver scripts; see main() examples at bottom).
"""
import os, shutil
from PIL import Image

GAME = r"C:\Users\asali\Projects\MMO\game\assets\sprites"
MOBILE = r"C:\Users\asali\Projects\MMO\mobile\game\assets\sprites"
BACKUP = r"C:\Users\asali\Projects\MMO\backup\drift_regen_2026-07-17"
MARGIN = 3


def load_dir_frames(folder):
    fs = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    return [Image.open(os.path.join(folder, f)).convert("RGBA") for f in fs]


def union_bbox(frames):
    boxes = [f.getbbox() for f in frames if f.getbbox()]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def backup(rel):
    """Copy game+mobile originals of rel (e.g. 'warrior_attack_e.png') into
    the backup tree once; skip if already backed up."""
    for root, tag in ((GAME, "game"), (MOBILE, "mobile")):
        src = os.path.join(root, rel)
        if not os.path.exists(src):
            continue
        dst = os.path.join(BACKUP, tag, rel)
        if os.path.exists(dst):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)


def install_strip(rel, frames, cell, crop=None):
    """Assemble frames into a strip at the forced cell and write to game+mobile
    (backing up originals). crop = shared union box; None = union of frames.
    Oversized figures are trimmed (top first for height, centered for width) —
    never scaled."""
    if crop is None:
        crop = union_bbox(frames)
    x0, y0, x1, y1 = crop
    fw, fh = x1 - x0, y1 - y0
    maxdim = cell - 2 * MARGIN
    # trim overflow: keep the BOTTOM (feet) and horizontal center
    if fh > maxdim:
        y0 = y1 - maxdim
        fh = maxdim
    if fw > maxdim:
        cx = (x0 + x1) // 2
        x0 = cx - maxdim // 2
        x1 = x0 + maxdim
        fw = maxdim
    strip = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        fig = f.crop((x0, y0, x1, y1))
        c = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        c.alpha_composite(fig, ((cell - fw) // 2, cell - fh - MARGIN))
        strip.alpha_composite(c, (i * cell, 0))
    backup(rel)
    for root in (GAME, MOBILE):
        out = os.path.join(root, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        strip.save(out)
    print("installed", rel, f"cell={cell} frames={len(frames)} fig={fw}x{fh}")


def cell_of(rel):
    return Image.open(os.path.join(GAME, rel)).height


def mirror(frames):
    return [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]
