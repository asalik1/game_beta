"""Build warlock cast/ult/death runtime strips from ImageGen source rows.

Full-unify 2026-08-24: the warlock's cast/ult/death were stocky PixelLab-r2 art
while idle/walk/attack are the crisp ImageGen generation. This builder turns the
keyed ImageGen source rows (art_src/warlock_unify_imagegen_2026-08-24/<stage>/
<stem>_v1_keyed.png) into engine strips that match the crisp idle: detect the 9
figures, crop, normalize on ONE frame-0-derived scale (preserve motion),
feet-anchor to a common baseline, pack to a shared square cell, hard-alpha +
despill, then install to game/ + mobile/ (originals backed up).

Each direction is engine-normalized independently (player_core _measure_hero_frame),
so absolute cell size is not critical; we match the idle's frame-0 content height
(~205px) so on-screen size + HEROBODY line up with idle/attack.

Usage:
  python tools/art/build_warlock_unify.py            # build + QA sheets to art_src, no install
  python tools/art/build_warlock_unify.py --install  # also install to game/ + mobile/ (backs up)
"""
from __future__ import annotations
import os, sys, shutil
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FAM = os.path.join(ROOT, "art_src", "warlock_unify_imagegen_2026-08-24")
SPR = os.path.join(ROOT, "game", "assets", "sprites")
MOB = os.path.join(ROOT, "mobile", "game", "assets", "sprites")
BACKUP = os.path.join(ROOT, "backup", "warlock_unify_2026-08-24")
QA = os.path.join(FAM, "qa")

TARGET_CONTENT = 205.0   # frame-0 content bbox height (matches crisp idle ~205)
CELL = 277               # shared square cell (matches idle/attack); grown if needed
PAD = 10                 # transparent margin (keeps verify_art EDGECUT clear)
ALPHA_T = 60

DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
STAGES = ([("cast", d) for d in DIRS] + [("ult", d) for d in DIRS] + [("death", None)])


def _keyed_path(clip, dir_):
    if clip == "death":
        return os.path.join(FAM, "death", "death_v1_keyed.png")
    return os.path.join(FAM, "%s_%s" % (clip, dir_), "%s_%s_v1_keyed.png" % (clip, dir_))


def _despill_hard(im):
    """Zero the green key-rim, hard binary alpha, zero RGB under transparent."""
    a = np.array(im.convert("RGBA")).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    # green-rim pixels (leftover chroma spill): drop to transparent
    rim = (g > np.maximum(r, b) + 20) & (al > 0)
    al = np.where(rim, 0, al)
    al = np.where(al >= 128, 255, 0)
    out = np.zeros_like(a)
    out[:, :, 3] = al
    m = al > 0
    for c in range(3):
        out[:, :, c] = np.where(m, a[:, :, c], 0)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def _columns(im, want=9):
    """Detect figure column runs by alpha occupancy; return exactly `want`
    (x0,x1) spans. Clean gutters give `want` runs directly; when animation
    frames touch (spread arms / a sprawled collapse close a gutter), assign a
    frame count to each over-wide run (proportional to width) and split it at
    internal occupancy valleys so no frame is lost."""
    a = np.array(im); col = (a[:, :, 3] > ALPHA_T).sum(axis=0)
    occ = col > 3
    runs = []; s = None
    for x, v in enumerate(occ):
        if v and s is None: s = x
        if (not v) and s is not None: runs.append((s, x)); s = None
    if s is not None: runs.append((s, len(occ)))
    runs = [r for r in runs if (r[1] - r[0]) > 30]
    if len(runs) == want or not runs:
        return runs
    if len(runs) > want:
        # too many: merge the narrowest runs into their nearest neighbour
        while len(runs) > want:
            i = min(range(len(runs)), key=lambda k: runs[k][1] - runs[k][0])
            j = i - 1 if i == len(runs) - 1 else i + 1
            lo, hi = min(runs[i][0], runs[j][0]), max(runs[i][1], runs[j][1])
            runs[min(i, j)] = (lo, hi); del runs[max(i, j)]
        return runs
    # fewer runs than frames: distribute the missing frames to the widest runs
    ks = [1] * len(runs); rem = want - len(runs)
    while rem > 0:
        i = max(range(len(runs)), key=lambda k: (runs[k][1] - runs[k][0]) / ks[k])
        ks[i] += 1; rem -= 1
    out = []
    for (x0, x1), k in zip(runs, ks):
        if k == 1:
            out.append((x0, x1)); continue
        w = (x1 - x0) / k; prev = x0
        for j in range(1, k):
            b = int(x0 + round(j * w))
            lo = max(x0 + 5, int(b - w * 0.28)); hi = min(x1 - 5, int(b + w * 0.28))
            if hi > lo:
                b = lo + int(np.argmin(col[lo:hi]))
            out.append((prev, b)); prev = b
        out.append((prev, x1))
    return out


def _bbox(im):
    a = np.array(im); m = a[:, :, 3] > ALPHA_T
    ys, xs = np.where(m)
    return xs.min(), ys.min(), xs.max(), ys.max()


def build_strip(clip, dir_):
    src = _keyed_path(clip, dir_)
    if not os.path.exists(src):
        return None, "MISSING source %s" % os.path.relpath(src, ROOT)
    im = _despill_hard(Image.open(src))
    runs = _columns(im, 9)
    if len(runs) != 9:
        return None, "could not resolve 9 figures, got %d (%s)" % (len(runs), os.path.basename(src))
    figs = []
    for (x0, x1) in runs:
        sub = im.crop((x0, 0, x1, im.height))
        bx = _bbox(sub)
        figs.append(sub.crop((bx[0], bx[1], bx[2] + 1, bx[3] + 1)))
    # one scale from frame 0 content height -> TARGET_CONTENT (preserve motion)
    scale = TARGET_CONTENT / figs[0].height
    scaled = [f.resize((max(1, round(f.width * scale)), max(1, round(f.height * scale))),
                       Image.LANCZOS) for f in figs]
    scaled = [_despill_hard(s) for s in scaled]  # LANCZOS reintroduces edge alpha
    # cell size: fit tallest/widest + margin, floor at CELL
    max_h = max(s.height for s in scaled); max_w = max(s.width for s in scaled)
    rc = max(CELL, max_h + 2 * PAD, max_w + 2 * PAD)
    strip = Image.new("RGBA", (rc * 9, rc), (0, 0, 0, 0))
    feet_target = rc - PAD
    for i, s in enumerate(scaled):
        dx = i * rc + (rc - s.width) // 2
        dy = feet_target - s.height     # feet (bottom of bbox) -> common baseline
        strip.alpha_composite(s, (dx, dy))
    return strip, "ok scale=%.3f cell=%d" % (scale, rc)


def qa_sheet(strip, name):
    os.makedirs(QA, exist_ok=True)
    from PIL import ImageEnhance
    n = strip.width // strip.height; h = strip.height; cell = 200
    sh = Image.new("RGBA", (n * (cell + 3) + 3, cell + 3), (40, 50, 40, 255))
    for i in range(n):
        f = strip.crop((i * h, 0, (i + 1) * h, h))
        b = ImageEnhance.Brightness(f).enhance(1.7)
        bg = Image.new("RGBA", (h, h), (64, 80, 64, 255)); bg.alpha_composite(b)
        sh.paste(bg.resize((cell, cell), Image.NEAREST), (3 + i * (cell + 3), 3))
    sh.convert("RGB").save(os.path.join(QA, name + ".png"))


def main():
    install = "--install" in sys.argv
    os.makedirs(QA, exist_ok=True)
    built = {}
    for clip, dir_ in STAGES:
        strip, msg = build_strip(clip, dir_)
        stem = "warlock_%s" % clip if clip == "death" else "warlock_%s_%s" % (clip, dir_)
        if strip is None:
            print("SKIP %-20s %s" % (stem, msg)); continue
        built[stem] = strip
        qa_sheet(strip, stem)
        print("BUILT %-20s %s (%dx%d)" % (stem, msg, strip.width, strip.height))
    # Flat south-alias bases (Art.hero_clips fallback): cast/ult flat strips were
    # still stocky r2. death is already flat. Alias the new south strip to the base.
    for clip in ("cast", "ult"):
        s = "warlock_%s_s" % clip
        if s in built:
            built["warlock_%s" % clip] = built[s]
    print("built %d strips (incl flat cast/ult aliases); QA sheets in %s" % (len(built), os.path.relpath(QA, ROOT)))
    if not install:
        print("(dry run — pass --install to write game/ + mobile/)"); return
    os.makedirs(BACKUP, exist_ok=True)
    for stem, strip in built.items():
        for tree in (SPR, MOB):
            dst = os.path.join(tree, stem + ".png")
            if os.path.exists(dst):
                bak = os.path.join(BACKUP, ("game_" if tree == SPR else "mobile_") + stem + ".png")
                if not os.path.exists(bak):
                    shutil.copy2(dst, bak)
            strip.save(dst)
        print("installed %s -> game/ + mobile/" % stem)


if __name__ == "__main__":
    main()
