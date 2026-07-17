#!/usr/bin/env python3
"""Rebuild a hero's sprites from the ChatGPT UPSCALES — the smoother,
higher-detail redraws the user commissioned — normalised to drop into
Crownless's shared hero rig.

Why this is separate from build_sprites.py: the other classes are extracted
straight from the Custom sheets, but the upscaled classes are AI redraws that
(a) sit on a white background, (b) are drawn at a DIFFERENT zoom in every clip,
and (c) sometimes drop a frame. So each clip is white-keyed + de-haloed, then
rescaled + feet-anchored to match its ORIGINAL counterpart's layout. That
reference is the crux: the engine derives ONE scale from the idle frame and
applies it to every clip, so unless each clip is sized to a consistent reference
the character would grow when idle and shrink when it attacks.

Reference is regenerated on the fly, so this is fully reproducible:
  - body clips  <- Custom/<Class> (2).png   (extract_sheet)
  - directional <- art_src/heroes_clips       (the seam-filled Heroes backup)

Sources (archived):  OneDrive/Assets/Custom/<class>_upscaled/*.png
Run:  python tools/art/upscale_hero.py [class ...]   (default: every class below)
"""
import os, sys, subprocess, tempfile, shutil
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_sprites import _seam_fill_inplace          # DRY: same closing+fill

HERE    = os.path.dirname(os.path.abspath(__file__))
ROOT    = os.path.dirname(os.path.dirname(HERE))
DEST    = os.path.join(ROOT, "game", "assets", "sprites")
BACKUP  = os.path.join(ROOT, "art_src", "heroes_clips")
EXTRACT = os.path.join(HERE, "extract_sheet.py")


def _env(name, default):
    """CROWNLESS_<name>, then the legacy EMBERFALL_<name> (pre-2026-07-17
    rename), then default — a stale export keeps working."""
    return os.environ.get("CROWNLESS_" + name) or os.environ.get("EMBERFALL_" + name) or default


CUSTOM  = _env("ART_SRC", "C:/Users/asali/OneDrive/Assets/Custom")

# Per class: the (2) sheet + its clip order (extract_sheet names, "idle"->_anim),
# the body map {dest suffix: upscale-source stem}, and any 8-way directional
# strips {dest name: (source stem, 16-cell frame map, cell magnification)}.
# The upscale source stems are the archived Custom/<class>_upscaled/<stem>.png.
CLASSES = {
    "assassin": {
        "sheet": "Assassin (2).png",
        "names": "idle,walk,run,attack,attack2,dash,death",
        "flags": [],
        "m_body": 3,
        "body": {"": "static", "_anim": "idle", "_walk": "walk", "_run": "run",
                 "_attack": "attack", "_attack2": "attack2", "_dash": "dash",
                 "_death": "death"},
        # stab upscale is missing its last SE frame -> reuse fig 14 for both SE
        # cells so aim still faces right.
        "directional": {
            "assassin_stab_dir":  ("stab_dir",  [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,14], 3),
            "assassin_throw_dir": ("throw_dir", list(range(16)), 2)},
    },
    "warlock": {
        "sheet": "Warlock (2).png",
        "names": "idle,walk,run,cast,attack,ult,attack2,death",
        "flags": ["--keepall"],
        "m_body": 3,
        "body": {"": "static", "_anim": "idle", "_run": "run",
                 "_cast": "cast", "_attack": "attack", "_attack2": "attack2",
                 "_ult": "ult", "_death": "death"},
        # walk reuses the idle clip: the robe hides the legs, so the idle sway
        # reads fine while moving and dodges a blocky upscaled stride.
        "alias": {"_walk": "_anim"},
        "directional": {},
    },
    "warrior": {
        "sheet": "Warrior (2).png",
        "names": "idle,walk,run,attack,attack2,dash,ultidle,ult,death",
        "flags": [],
        "m_body": 3,
        "body": {"": "static", "_anim": "idle", "_walk": "walk", "_run": "run",
                 "_attack": "attack", "_attack2": "attack2", "_dash": "dash",
                 "_ult": "ult", "_ultidle": "ultidle", "_death": "death"},
        # the walk upscale is a separate, upright, mirror-facing source: size it
        # to the IDLE reference (its own crouched (2)-walk ref sized it small) and
        # flip it to face the same way as the rest of the roster.
        "ref_override": {"_walk": "_anim"},
        "mirror": ["_walk"],
        # the walk upscale came on white with a baked ground shadow and ~13%
        # brighter than the roster -> strip the shadow, scale luma down to match.
        "preprocess": {"_walk": {"strip_shadow": True, "brightness": 0.87}},
        "directional": {},
    },
}


def white_key(src):
    img = src if isinstance(src, Image.Image) else Image.open(src)
    im = np.asarray(img.convert("RGBA")).astype(int)
    w = (255-im[:,:,0]) + (255-im[:,:,1]) + (255-im[:,:,2])   # 0 at pure white
    o = im.copy(); o[:,:,3] = np.clip((w-30)*8, 0, 255)       # soft 1px feather
    return o.astype(np.uint8)


def preprocess(img, opts):
    """Per-clip source fixes before keying. strip_shadow removes a baked
    blue-grey ground ellipse (a light, low-saturation, bluish slab in the bottom
    band of each figure -- distinct from the neutral sword and the dark boots).
    brightness scales character pixels to match the roster's luminance."""
    arr = np.asarray(img.convert("RGB")).astype(float); H, W = arr.shape[:2]
    wd = lambda a: (255-a[:,:,0]) + (255-a[:,:,1]) + (255-a[:,:,2])
    if opts.get("strip_shadow"):
        notbg = wd(arr) > 60
        delta = arr.max(-1) - arr.min(-1)
        lum = 0.299*arr[:,:,0] + 0.587*arr[:,:,1] + 0.114*arr[:,:,2]
        col = notbg.any(0); runs = []; st = None
        for x in range(W):
            if col[x] and st is None: st = x
            elif not col[x] and st is not None: runs.append((st, x-1)); st = None
        if st is not None: runs.append((st, W-1))
        band = np.zeros((H, W), bool)
        for a, b in [(a,b) for a,b in runs if b-a > 15]:
            ys = np.where(notbg[:, a:b+1].any(1))[0]
            band[max(0, ys.max()-15):ys.max()+1, a:b+1] = True
        shadow = notbg & (lum > 145) & (delta < 42) & ((arr[:,:,2]-arr[:,:,0]) > 5) & band
        arr[shadow] = [255, 255, 255]
    if "brightness" in opts:
        nb = wd(arr) > 60
        arr[nb] = np.clip(arr[nb] * opts["brightness"], 0, 255)
    return Image.fromarray(arr.astype("uint8"), "RGB")


def clean_figure(arr):
    """Kill the white AA rim the source leaves on the moving clips. Four steps,
    mirroring extract_sheet.solidify:
      1. hard silhouette from alpha>128 (drops the semi-transparent light feather)
      2. fill only SMALL enclosed holes (anti-alias specks). A LARGE enclosed
         region is a background POCKET -- e.g. the gap between striding legs --
         and must stay transparent so the ground shows through, not a filled blob.
      3. bleed EVERY transparent pixel's RGB to its nearest opaque colour, so the
         later LANCZOS downscale blends edges with the sprite, never with white
      4. de-halo: recolour any outer-ring pixel notably LIGHTER than its inner
         neighbour to that neighbour's colour (twice, for a 2px rim)."""
    m = arr[:, :, 3] > 128
    if not m.any():
        return arr
    holes = ndimage.binary_fill_holes(m) & ~m
    lbl, nl = ndimage.label(holes)
    small = np.zeros(m.shape, bool)
    if nl:
        sizes = ndimage.sum(np.ones(lbl.shape), lbl, range(1, nl + 1))
        thr = max(40.0, m.sum() * 0.005)             # >0.5% of the figure = a pocket
        keep = [k for k in range(1, nl + 1) if sizes[k - 1] < thr]
        if keep:
            small = np.isin(lbl, keep)
    filled = m | small
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


def _normalize_clip(upscale_path, ref_clip_path, M):
    """One match ratio for the whole clip (its median char height -> the
    reference clip's), each frame feet-anchored so natural pose variation
    survives but every clip lands the character at the same on-screen size."""
    cells, s_ref = cell_metrics(ref_clip_path)
    med_h = float(np.median([h for (h, _b) in cells]))
    figs = figures(white_key(upscale_path))
    ratio = med_h / float(np.median([f.height for f in figs]))
    S = s_ref * M
    FY = round(float(np.median([b for (_h, b) in cells])) * M)
    out = Image.new("RGBA", (S*len(figs), S), (0,0,0,0))
    for j, f in enumerate(figs):
        nw, nh = max(1, round(f.width*ratio*M)), max(1, round(f.height*ratio*M))
        r = f.resize((nw, nh), Image.LANCZOS)
        cx = j*S + S//2; out.paste(r, (cx - nw//2, FY - nh), r)
    return out, len(figs)


def _mirror_strip(im):
    """Flip each cell horizontally in place (keeps frame order + centering)."""
    s = im.height; n = im.width // s
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for i in range(n):
        out.paste(im.crop((i*s, 0, (i+1)*s, s)).transpose(Image.FLIP_LEFT_RIGHT), (i*s, 0))
    return out


def build(cls):
    cfg = CLASSES[cls]
    upsrc = _env("UPSCALE_SRC", os.path.join(CUSTOM, cls + "_upscaled"))
    if not os.path.isdir(upsrc):
        sys.exit("missing upscale source dir: %s" % upsrc)

    # --- body: reference = the (2) sheet extracted into a temp dir ----------
    ref = tempfile.mkdtemp()
    subprocess.check_call([sys.executable, EXTRACT,
        "--in", os.path.join(CUSTOM, cfg["sheet"]), "--out", ref,
        "--class", cls, "--names", cfg["names"]] + cfg["flags"])
    ref_ov = cfg.get("ref_override", {})
    mirror = cfg.get("mirror", [])
    prep = cfg.get("preprocess", {})
    for suf, stem in cfg["body"].items():
        ref_clip = os.path.join(ref, cls + ref_ov.get(suf, suf) + ".png")
        src = os.path.join(upsrc, stem + ".png")
        if suf in prep:
            src = preprocess(Image.open(src), prep[suf])
        out, nf = _normalize_clip(src, ref_clip, cfg["m_body"])
        if suf in mirror:
            out = _mirror_strip(out)
        out.save(os.path.join(DEST, cls + suf + ".png"))
        print("%s%-9s %d frames  <- %s.png%s" % (cls, suf, nf, stem,
              "  (idle-sized, mirrored)" if suf in mirror else ""))
    shutil.rmtree(ref, ignore_errors=True)

    # Aliased clips reuse another built clip verbatim (e.g. walk := idle).
    for suf, src in cfg.get("alias", {}).items():
        shutil.copy(os.path.join(DEST, cls + src + ".png"),
                    os.path.join(DEST, cls + suf + ".png"))
        print("%s%-9s <- %s%s (alias)" % (cls, suf, cls, src))

    # --- directional: reference = seam-filled Heroes backup ----------------
    for name, (stem, mapping, M) in cfg["directional"].items():
        tmp = os.path.join(DEST, name + ".png")
        shutil.copy(os.path.join(BACKUP, name + ".png"), tmp)
        _seam_fill_inplace(tmp)
        cells, s_ref = cell_metrics(tmp)
        figs = figures(white_key(os.path.join(upsrc, stem + ".png")))
        _pack(figs, mapping, cells, s_ref, M).save(tmp)
        print("%-20s %d figures -> %d cells" % (name, len(figs), len(mapping)))


def main():
    which = sys.argv[1:] or list(CLASSES)
    for cls in which:
        if cls not in CLASSES:
            sys.exit("unknown class %r (have: %s)" % (cls, ", ".join(CLASSES)))
        print("=== %s ===" % cls)
        build(cls)
    print("\nDone. Re-import:  tools/Godot_*_console.exe --headless --path game --import")


if __name__ == "__main__":
    main()
