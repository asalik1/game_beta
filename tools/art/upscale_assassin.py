#!/usr/bin/env python3
"""Rebuild the assassin's sprites from the ChatGPT UPSCALES — the smoother,
higher-detail redraws the user commissioned — normalised to drop into
Emberfall's shared hero rig.

Why this is separate from build_sprites.py: the other five classes are extracted
straight from the Custom sheets, but the assassin's frames are AI upscales that
(a) sit on a white background, (b) are drawn at a DIFFERENT zoom in every clip,
and (c) the stab strip is missing its final SE frame. So each clip is
white-keyed, then rescaled + feet-anchored to match its ORIGINAL counterpart's
layout. That reference is the crux: the engine derives ONE scale from the idle
frame and applies it to every clip, so unless each clip is sized to a consistent
reference the character would grow when idle and shrink when it attacks.

Reference is regenerated on the fly, so this is fully reproducible:
  - body clips  <- Custom/Assassin (2).png  (extract_sheet)
  - directional <- art_src/heroes_clips      (the seam-filled Heroes backup)

Source (archived):  OneDrive/Assets/Custom/assassin_upscaled/*.png
Run:  python tools/art/upscale_assassin.py
"""
import os, sys, subprocess, tempfile, shutil
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_sprites import _seam_fill_inplace          # DRY: same closing+fill

HERE   = os.path.dirname(os.path.abspath(__file__))
ROOT   = os.path.dirname(os.path.dirname(HERE))
DEST   = os.path.join(ROOT, "game", "assets", "sprites")
BACKUP = os.path.join(ROOT, "art_src", "heroes_clips")
EXTRACT = os.path.join(HERE, "extract_sheet.py")
CUSTOM = os.environ.get("EMBERFALL_ART_SRC", "C:/Users/asali/OneDrive/Assets/Custom")
UPSRC  = os.environ.get("EMBERFALL_UPSCALE_SRC", os.path.join(CUSTOM, "assassin_upscaled"))

M_BODY = 3                       # body output cell = 69 * 3
M_STAB = 3                       # stab reference cell 59 -> 177
M_THROW = 2                      # throw reference cell 94 -> 188

# body: clip suffix -> (upscale file, reference clip produced by extract_sheet)
BODY = {
    "":         ("static.png",  "assassin.png"),
    "_anim":    ("idle.png",    "assassin_anim.png"),
    "_walk":    ("walk.png",    "assassin_walk.png"),
    "_run":     ("run.png",     "assassin_run.png"),
    "_attack":  ("attack.png",  "assassin_attack.png"),
    "_attack2": ("attack2.png", "assassin_attack2.png"),
    "_dash":    ("dash.png",    "assassin_dash.png"),
    "_death":   ("death.png",   "assassin_death.png"),
}
# 8 dirs x 2 frames. The stab upscale has 15 figures (its SE second frame is
# missing) -> reuse fig 14 for both SE cells so that aim still faces right.
DIR_MAP_STAB  = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,14]
DIR_MAP_THROW = list(range(16))


def white_key(path):
    im = np.asarray(Image.open(path).convert("RGBA")).astype(int)
    w = (255-im[:,:,0]) + (255-im[:,:,1]) + (255-im[:,:,2])   # 0 at pure white
    o = im.copy(); o[:,:,3] = np.clip((w-30)*8, 0, 255)       # soft 1px feather
    return o.astype(np.uint8)


def clean_figure(arr):
    """Kill the white AA rim the source left on the moving clips (the idle was
    clean, the rest weren't). Three steps, mirroring extract_sheet.solidify:
      1. hard silhouette from alpha>128 (drops the semi-transparent light feather)
      2. bleed EVERY transparent pixel's RGB to its nearest opaque colour, so the
         later LANCZOS downscale blends edges with the sprite, never with white
      3. de-halo: recolour any outer-ring pixel notably LIGHTER than its inner
         neighbour to that neighbour's colour (twice, for a 2px rim)."""
    m = arr[:, :, 3] > 128
    if not m.any():
        return arr
    filled = ndimage.binary_fill_holes(m)
    out = arr.copy()
    idx = ndimage.distance_transform_edt(~m, return_distances=False, return_indices=True)
    non = ~m
    out[non] = arr[idx[0][non], idx[1][non]]        # no white left to bleed
    solid = filled
    for _ in range(2):
        inner = ndimage.binary_erosion(solid); ring = solid & ~inner
        if not (ring.any() and inner.any()):
            break
        iy, ix = ndimage.distance_transform_edt(~inner, return_distances=False, return_indices=True)
        ry, rx = np.where(ring); nb = out[iy[ry, rx], ix[ry, rx]]
        lighter = out[ry, rx][:, :3].astype(int).sum(1) > nb[:, :3].astype(int).sum(1) + 55
        out[ry[lighter], rx[lighter], :3] = nb[lighter, :3]
        solid = inner
    out[:, :, 3] = np.where(filled, 255, 0).astype(np.uint8)
    return out


def figures(keyed):
    """Left-to-right character crops, split on empty columns, each de-haloed."""
    fg = keyed[:,:,3] > 40; col = fg.any(0); runs=[]; s=None
    for x in range(len(col)):
        if col[x] and s is None: s = x
        elif not col[x] and s is not None: runs.append((s, x-1)); s = None
    if s is not None: runs.append((s, len(col)-1))
    crops=[]
    for a, b in [(a,b) for a,b in runs if b-a > 15]:
        sub = keyed[:, a:b+1]; ys = np.where(sub[:,:,3] > 40)[0]
        c = clean_figure(sub[ys.min():ys.max()+1].copy())
        m = c[:,:,3] > 0                              # tight-crop the hard mask
        yy = np.where(m.any(1))[0]; xx = np.where(m.any(0))[0]
        crops.append(Image.fromarray(c[yy.min():yy.max()+1, xx.min():xx.max()+1], "RGBA"))
    return crops


def cell_metrics(path):
    """Per-frame (char height, feet-bottom) of an already-clean strip."""
    im = Image.open(path).convert("RGBA"); s = im.height; n = im.width // s
    out=[]
    for i in range(n):
        a = np.asarray(im.crop((i*s,0,(i+1)*s,s)))[:,:,3] > 40
        ys = np.where(a.any(1))[0]; out.append((ys.max()-ys.min()+1, ys.max()))
    return out, s


def _pack(figs, mapping, ref_cells, s_ref, M):
    """Scale each mapped figure to its reference cell's char height, feet on a
    shared baseline, centred in an M*s_ref square cell."""
    S = s_ref * M
    FY = round(float(np.median([b for (_h, b) in ref_cells])) * M)
    out = Image.new("RGBA", (S*len(mapping), S), (0,0,0,0))
    for c, fi in enumerate(mapping):
        fig = figs[fi]; charh = ref_cells[c][0]
        scale = (charh * M) / fig.height
        nw, nh = max(1, round(fig.width*scale)), max(1, round(fig.height*scale))
        r = fig.resize((nw, nh), Image.LANCZOS)
        cx = c*S + S//2
        out.paste(r, (cx - nw//2, FY - nh), r)
    return out


def main():
    for p in (UPSRC, CUSTOM):
        if not os.path.isdir(p): sys.exit("missing dir: %s" % p)

    # --- body reference: extract the (2) sheet into a temp dir --------------
    ref = tempfile.mkdtemp()
    subprocess.check_call([sys.executable, EXTRACT,
        "--in", os.path.join(CUSTOM, "Assassin (2).png"), "--out", ref,
        "--class", "assassin",
        "--names", "idle,walk,run,attack,attack2,dash,death"])
    for suf, (upf, reff) in BODY.items():
        cells, _s = cell_metrics(os.path.join(ref, reff))
        med_h = float(np.median([h for (h, _b) in cells]))
        figs = figures(white_key(os.path.join(UPSRC, upf)))
        up_h = float(np.median([f.height for f in figs]))
        # one match ratio for the whole clip (its median char height -> the
        # reference clip's), each frame feet-anchored so natural pose variation
        # survives but every clip lands the character at the same on-screen size.
        ratio = med_h / up_h
        S = 69 * M_BODY
        FY = round(float(np.median([b for (_h, b) in cells])) * M_BODY)
        out = Image.new("RGBA", (S*len(figs), S), (0,0,0,0))
        for j, f in enumerate(figs):
            nw, nh = max(1, round(f.width*ratio*M_BODY)), max(1, round(f.height*ratio*M_BODY))
            r = f.resize((nw, nh), Image.LANCZOS)
            cx = j*S + S//2; out.paste(r, (cx - nw//2, FY - nh), r)
        out.save(os.path.join(DEST, "assassin" + suf + ".png"))
        print("assassin%-9s %d frames  <- %s" % (suf, len(figs), upf))
    shutil.rmtree(ref, ignore_errors=True)

    # --- directional reference: seam-filled Heroes backup ------------------
    for upf, name, mapping, M in [
        ("stab_dir.png",  "assassin_stab_dir",  DIR_MAP_STAB,  M_STAB),
        ("throw_dir.png", "assassin_throw_dir", DIR_MAP_THROW, M_THROW)]:
        tmp = os.path.join(DEST, name + ".png")
        shutil.copy(os.path.join(BACKUP, name + ".png"), tmp)
        _seam_fill_inplace(tmp)
        cells, s_ref = cell_metrics(tmp)
        figs = figures(white_key(os.path.join(UPSRC, upf)))
        _pack(figs, mapping, cells, s_ref, M).save(tmp)
        print("%-20s %d figures -> 16 cells" % (name, len(figs)))

    print("\nDone. Re-import:  tools/Godot_*_console.exe --headless --path game --import")


if __name__ == "__main__":
    main()
