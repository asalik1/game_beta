#!/usr/bin/env python3
"""Audit every animated PROP strip for frame drift and pulse strength.

Owner (2026-08-18) saw a purple mushroom "shifting position" and the well next
to it "dimming and brightening significantly" — animation the design never
asked for. This walks assets/sprites/*_anim.png for props (a strip with a
matching static <base>.png, or one of the known Codex procedural props), reads
frame width the way Art.anim_info does (a derived strip = the static's WxH,
rectangular; a Codex strip = square cells), and prints per strip:
  drift      max centroid shift of the whole silhouette vs frame 0 (px)
  base_drift the same for the bottom 30% rows (the rigid base a prop stands on)
  pulse%     (max - min) / max of the mean silhouette luminance across frames
Thresholds (flag): base_drift >= 1.5px, pulse >= 12% (open fire, FIRE_PROPS: >= 25%,
the CLAUDE.md prop contract). --fix re-derives the
flagged DERIVED strips in place from their static (frame 0 stays the static)
with a gentle amp, and re-anchors Codex strips on their frame-0 base.

  python tools/art/audit_prop_anims.py [--fix] [--only a,b]
"""
import argparse
import glob
import os
import subprocess
import sys

import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPR = os.path.join(REPO, "game", "assets", "sprites")
MOBILE = os.path.join(REPO, "mobile", "game", "assets", "sprites")
TERRAINS = os.path.join(REPO, "game", "scripts", "terrains.gd")


def prop_names():
    """Every sprite name the terrain layer can place: scatter tiers + families,
    structure base/parts/decals sprites, capital landmark kit. Mobs/heroes/
    bosses have _anim strips too and must not be judged as props."""
    import re
    src = open(TERRAINS, encoding="utf-8").read()
    names = set(re.findall(r'"sprite":\s*"([a-z0-9_]+)"', src))
    for key in ("obstacles", "decor", "accents", "structures", "landmarks", "buildings"):
        for lst in re.findall(r'"%s":\s*\[([^\]]*)\]' % key, src):
            names.update(re.findall(r'"([a-z0-9_]+)"', lst))
    if "PROP_VARIANT_GROUPS" in src:
        block = src.split("PROP_VARIANT_GROUPS", 1)[1][:4000]
        names.update(re.findall(r'"([a-z0-9_]+)"', block))
    names.update(re.findall(r'"(capital_[a-z0-9_]+)"', src))
    return names
CODEX_PROPS = {"signal_fire", "torch_pillar", "watch_brazier", "great_hearth", "cook_hearth", "guild_forge",
               "town_fountain", "bog_rootwell", "storm_array", "camp_bonfire", "magma_chainrig", "fountain_flow"}
# Motion class per DERIVED prop (from the 2026-08-17 batch): what --fix re-derives with.
MOTION = {
    "old_well": "shimmer", "sewer_outfall": "flow", "castle_banner": "wave", "hideout_firepit": "flicker", "flame": "flicker",
    "forge_hearth": "flicker", "cook_pan": "shimmer",
    # 2026-08-18 style-unify re-derives (batch B/D statics): pulse = colour-only, rigid-safe.
    "station_alchemy_t1": "pulse", "station_alchemy_t2": "pulse", "node_crystal": "pulse",
    "camp_furnace": "pulse", "forge_brazier": "pulse", "forge_cauldron": "pulse",
    "station_furnace_t1": "pulse", "station_furnace_t2": "pulse", "station_furnace_t3": "pulse",
}
BASE_DRIFT_MAX = 1.5
BASE_BAND = 0.5   # the rigid part = the lower half of the silhouette (basin, ring, bowl + legs)
PULSE_MAX = 12.0
# OPEN FIRE may swing harder (CLAUDE.md prop contract: glows <= 10-12%, fire <= 25%):
# the whole silhouette IS the flame, so the mean-luminance swing reads as fire, not strobe.
FIRE_PROPS = {"flame", "camp_bonfire", "signal_fire", "torch_pillar", "watch_brazier", "cook_hearth",
              "hideout_firepit", "forge_hearth", "guild_forge"}
PULSE_MAX_FIRE = 25.0
# Churning ENERGY (a void rift's plasma) sits between a glow and a fire: the
# shell is byte-locked (RIGID_MASK) and only the plasma swings.
ENERGY_PROPS = {"void_rift"}
PULSE_MAX_ENERGY = 18.0
# FOLIAGE (2026-08-25, tree fidelity+wind pass): authored canopy-rustle strips.
# The canopy MAY change silhouette (CLAUDE.md: "only fire, cloth and foliage");
# the rigid contract is the TRUNK BASE, so the band narrows to the bottom 12%
# of the silhouette (the default 30% window reaches low canopy and would flag
# legitimate leaf motion). --fix NEVER realigns/band-locks these: scaling
# frames by canopy width would mangle an authored sway — a flagged foliage
# strip is fixed by regen only. Mirrors autotest's silhouette_motion_anims.
FOLIAGE_PROPS = {
    "tree_green", "tree_green2", "tree_green3", "tree_green4",
    "tree_autumn", "tree_autumn2", "tree_autumn3",
    "tree_teal", "tree_teal2", "tree_teal3",
    "tree_snow", "tree_snow2", "tree_snow3",
    "tree_winter", "tree_winter2", "tree_winter3",
    "tree_spore", "tree_spore2", "tree_spore3",
    "topiary", "bush", "bush2", "bush3",
}
FOLIAGE_BAND = 0.12
# DEAD strips (2026-09-06). The gate only ever asked "does this move TOO MUCH".
# A corpus scan found the opposite failure: a derived strip whose motion mask
# matched (almost) nothing, so the prop ships a 4-frame animation that never
# changes -- shimmer on olive sludge (sewer_outfall), swirl on pale-blue light
# (capital_portal_story), a canopy strip that is four copies of the static
# (tree_winter2, tree_autumn2), a pulse on a station whose glow it missed
# (station_alchemy_t3). All five are fixed; this keeps them fixed.
DEAD_PCT = 0.5     # under this share of the body changing on EVERY frame = dead
# Props with nothing to animate by design: an empty copper pan, a well whose
# water is not visible (a swinging bucket needs authored frames -- owner ruling),
# an UNLIT firepit ring. Their strips are inert on purpose.
NO_MOTION_OK = {"cook_pan", "old_well", "hideout_firepit"}


def frame_w(strip_path, base):
    im = Image.open(strip_path)
    W, H = im.size
    static = os.path.join(SPR, base + ".png")
    if os.path.exists(static):
        sw, sh = Image.open(static).size
        if sh == H and W % sw == 0 and W // sw > 1:
            return sw
    if W % H == 0 and W // H > 1:
        return H
    return 0


def measure(strip_path, fw):
    """drift = whole-silhouette centroid shift; bdrift = the rigid band's OUTLINE
    shift (left edge, right edge, anchor row of the bottom 30% — or the top 30%
    for hanging cloth) vs frame 0. Outline, not centroid: a flame licking into
    the basin band changes the band's centroid without moving the basin, and
    "shifts position" is about the outline (2026-08-18)."""
    a = np.asarray(Image.open(strip_path).convert("RGBA")).astype(float)
    n = a.shape[1] // fw
    base_name = os.path.basename(strip_path)[:-9]
    top_anchor = base_name in TOP_ANCHOR
    band_frac = FOLIAGE_BAND if base_name in FOLIAGE_PROPS else 0.3
    cents, bases, lums = [], [], []
    band_rows = None   # the band is FRAME 0's rows, reused for every frame (a
    # taller water jet in frame 3 must not move the window up the basin)
    for f in range(n):
        cell = a[:, f * fw:(f + 1) * fw]
        m = cell[..., 3] > 40
        if not m.any():
            continue
        ys, xs = np.nonzero(m)
        cents.append((xs.mean(), ys.mean()))
        if band_rows is None:
            span = ys.max() - ys.min() + 1
            if top_anchor:
                band_rows = (0, ys.min() + int(0.3 * span))
            else:
                band_rows = (ys.max() - int(band_frac * span), a.shape[0])
        mb = m.copy()
        mb[:band_rows[0], :] = False
        mb[band_rows[1]:, :] = False
        yb2, xb2 = np.nonzero(mb)
        if len(xb2):
            anchor = yb2.min() if top_anchor else yb2.max()
            bases.append((xb2.min(), xb2.max(), anchor))
        else:
            bases.append((xs.min(), xs.max(), ys.min() if top_anchor else ys.max()))
        lum = (0.2126 * cell[..., 0] + 0.7152 * cell[..., 1] + 0.0722 * cell[..., 2])[m].mean()
        lums.append(lum)
    if len(cents) < 2:
        return None
    drift = max(max(abs(c[0] - cents[0][0]), abs(c[1] - cents[0][1])) for c in cents)
    bdrift = max(max(abs(b[0] - bases[0][0]), abs(b[1] - bases[0][1]), abs(b[2] - bases[0][2])) for b in bases)
    pulse = (max(lums) - min(lums)) / max(1e-6, max(lums)) * 100.0
    return n, drift, bdrift, pulse


def motion_pct(strip_path, fw):
    """Largest share of the body (%) that CHANGES on any frame vs frame 0 --
    alpha or colour. Near 0 = a dead strip (the animation does nothing)."""
    a = np.asarray(Image.open(strip_path).convert("RGBA")).astype(int)
    n = a.shape[1] // fw
    if n < 2:
        return 100.0
    fr = [a[:, i * fw:(i + 1) * fw] for i in range(n)]
    al0 = fr[0][..., 3] > 40
    if not al0.any():
        return 100.0
    best = 0.0
    for f in fr[1:]:
        alpha_d = int(((f[..., 3] > 40) ^ al0).sum())
        rgb_d = int((np.abs(f[..., :3] - fr[0][..., :3]).sum(2) > 20).sum())
        best = max(best, max(alpha_d, rgb_d) / al0.sum() * 100.0)
    return best


def is_derived(strip_path, fw):
    """A DERIVED strip (derive_prop_anim.py) is colour-only: every frame's alpha
    equals frame 0's. An AUTHORED (Codex-drawn) strip changes silhouette. Only
    derived strips may be re-derived from their static; authored ones are
    re-anchored, never regenerated (that killed the campfire once, 2026-08-18)."""
    a = np.asarray(Image.open(strip_path).convert("RGBA"))
    n = a.shape[1] // fw
    a0 = a[:, 0:fw, 3]
    return all(np.array_equal(a0, a[:, f * fw:(f + 1) * fw, 3]) for f in range(1, n))


# Cloth hangs from a rod: its rigid part is the TOP band, not the base.
TOP_ANCHOR = {"banner_blue", "banner_green", "banner_red"}
# Rigid shells whose silhouette must be byte-stable (the autotest four-frame
# contract): after re-anchoring, every frame takes frame 0's alpha, so plasma
# may churn inside but the shell never grows a sliver (void_rift frame 3 carried
# a spill of the next cell's floating rocks).
RIGID_MASK = {"void_rift"}


def realign_codex(strip_path, fw, band="base", rigid_mask=False):
    """Normalise frames 1..N onto frame 0's RIGID part: the generator drew each
    frame at a slightly different size/offset (a campfire ring 8% smaller in
    frame 4, a fountain basin wider in frame 1, a banner taller in frame 2), so
    the whole prop breathed and slid. Per frame: measure the rigid band (bottom
    BASE_BAND of the silhouette rows, or the TOP band for hanging cloth), SCALE
    the frame so the band width matches frame 0, then translate so the band's
    centre-x and anchor row land on frame 0's. Flames/water/cloth still move;
    the thing they hang from or stand on is now pixel-locked."""
    im = Image.open(strip_path).convert("RGBA")
    a = np.asarray(im).copy()
    H = a.shape[0]
    n = a.shape[1] // fw

    def band_box(cell):
        m = cell[..., 3] > 40
        ys, xs = np.nonzero(m)
        if not len(xs):
            return None
        span = ys.max() - ys.min() + 1
        mb = m.copy()
        if band == "top":
            mb[ys.min() + int(0.3 * span):, :] = False
            anchor_row = ys.min()
        else:
            mb[:ys.max() - int(BASE_BAND * span), :] = False
            anchor_row = ys.max()
        yb2, xb2 = np.nonzero(mb)
        if not len(xb2):
            return None
        return (xb2.min(), xb2.max(), anchor_row)   # band left, right, anchor row

    b0 = band_box(a[:, 0:fw])
    if b0 is None:
        return
    w0 = max(1, b0[1] - b0[0])
    cx0 = (b0[0] + b0[1]) / 2.0
    out = a.copy()
    for f in range(1, n):
        cell = a[:, f * fw:(f + 1) * fw]
        b = band_box(cell)
        if b is None:
            continue
        w = max(1, b[1] - b[0])
        sc = w0 / float(w)
        sc = min(1.35, max(0.74, sc))
        cim = Image.fromarray(cell, "RGBA")
        nw, nh = max(1, int(round(fw * sc))), max(1, int(round(H * sc)))
        cim = cim.resize((nw, nh), Image.LANCZOS)
        cx = (b[0] + b[1]) / 2.0 * sc
        by = b[2] * sc
        # place so band centre-x -> cx0 and anchor row -> b0[2]
        ox = int(round(cx0 - cx))
        oy = int(round(b0[2] - by))
        canvas = Image.new("RGBA", (fw, H), (0, 0, 0, 0))
        canvas.paste(cim, (ox, oy), cim)
        cellout = np.asarray(canvas).copy()
        if rigid_mask:
            # Silhouette lock: outside frame 0's alpha nothing survives; where
            # frame 0 is opaque and this frame went transparent, frame 0 shows.
            a0 = a[:, 0:fw]
            outside = a0[..., 3] <= 40
            cellout[outside] = 0
            hole = (a0[..., 3] > 40) & (cellout[..., 3] <= 40)
            cellout[hole] = a0[hole]
            cellout[..., 3] = a0[..., 3]
        out[:, f * fw:(f + 1) * fw] = cellout
    Image.fromarray(out, "RGBA").save(strip_path)


def lock_band(strip_path, fw, band="base", frac=0.3):
    """Pixel-lock the rigid band: rows in the bottom (or top) `frac` of frame 0's
    silhouette are copied VERBATIM from frame 0 into every frame — a basin, log
    pile or pillar cannot differ by a pixel between frames after this; only what
    rises above (or hangs below) it animates. Applied after realign_codex when
    the outline still differs (the generator drew a 4px-narrower basin in one
    cell — nothing a scale/translate can hide)."""
    im = Image.open(strip_path).convert("RGBA")
    a = np.asarray(im).copy()
    n = a.shape[1] // fw
    a0 = a[:, 0:fw]
    m0 = a0[..., 3] > 40
    ys, xs = np.nonzero(m0)
    if not len(ys):
        return
    span = ys.max() - ys.min() + 1
    if band == "top":
        rows = slice(0, ys.min() + int(frac * span))
    else:
        rows = slice(ys.max() - int(frac * span), a.shape[0])
    for f in range(1, n):
        a[rows, f * fw:(f + 1) * fw] = a0[rows]
    Image.fromarray(a, "RGBA").save(strip_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--amp", type=float, default=0.10, help="re-derive amplitude for flagged derived strips (glow-only pulse since 2026-09-05: the bright 30%% swings by this, the shell by 0)")
    a = ap.parse_args()
    only = set(x for x in a.only.split(",") if x)
    rows = []
    props = prop_names() | CODEX_PROPS
    for p in sorted(glob.glob(os.path.join(SPR, "*_anim.png"))):
        base = os.path.basename(p)[:-9]
        static = os.path.join(SPR, base + ".png")
        if base not in props:
            continue
        if not (os.path.exists(static) or base in CODEX_PROPS):
            continue
        if only and base not in only:
            continue
        fw = frame_w(p, base)
        if not fw:
            continue
        m = measure(p, fw)
        if not m:
            continue
        n, drift, bdrift, pulse = m
        dead = base not in NO_MOTION_OK and motion_pct(p, fw) < DEAD_PCT
        pulse_max = PULSE_MAX_FIRE if base in FIRE_PROPS else (
            PULSE_MAX_ENERGY if base in ENERGY_PROPS else PULSE_MAX)
        flag = bool(bdrift >= BASE_DRIFT_MAX or pulse >= pulse_max or dead)
        rows.append((base, n, fw, round(drift, 1), round(bdrift, 1), round(pulse), flag, os.path.exists(static), dead))
    rows.sort(key=lambda r: (0 if r[6] else 1, -r[5], -r[4]))
    print("%-24s %2s %4s %6s %6s %6s %s" % ("base", "n", "fw", "drift", "bdrft", "pulse%", "flag"))
    for r in rows:
        print("%-24s %2d %4d %6.1f %6.1f %6d %s" % (r[0], r[1], r[2], r[3], r[4], r[5],
              ("FLAG DEAD" if r[8] else "FLAG") if r[6] else ""))
    flagged = [r for r in rows if r[6]]
    print("%d prop strips, %d flagged" % (len(rows), len(flagged)))
    if not a.fix:
        return 1 if flagged else 0
    for r in flagged:
        base, n, fw, drift, bdrift, pulse, _, has_static, dead = r
        if dead:
            print("dead     ", base, "-- its motion mask matches nothing in the art; pick a motion that fits "
                  "(derive_prop_anim warns when a mask covers <1%) or add it to NO_MOTION_OK")
            continue
        p = os.path.join(SPR, base + "_anim.png")
        if base in FOLIAGE_PROPS and not (has_static and is_derived(p, fw)):
            print("foliage  ", base, "— authored canopy sway: never realigned/band-locked; fix by regen only")
            continue
        if has_static and is_derived(p, fw):
            motion = MOTION.get(base, "pulse")
            cmd = [sys.executable, os.path.join(REPO, "tools", "art", "derive_prop_anim.py"), base,
                   "--motion", motion, "--frames", str(n), "--amp", str(a.amp)]
            rr = subprocess.run(cmd, capture_output=True, text=True, cwd=REPO)
            print("re-derived", base, motion, "amp", a.amp, "->", "ok" if rr.returncode == 0 else rr.stderr[-160:])
        else:
            band = "top" if base in TOP_ANCHOR else "base"
            realign_codex(p, fw, band=band, rigid_mask=base in RIGID_MASK)
            note = "(top band)" if base in TOP_ANCHOR else ""
            m1 = measure(p, fw)
            if m1 and m1[2] >= BASE_DRIFT_MAX and base not in RIGID_MASK:
                lock_band(p, fw, band=band)   # outline still off: pixel-lock the band
                note += " (band locked)"
            mp = os.path.join(MOBILE, base + "_anim.png")
            if os.path.isdir(MOBILE):
                Image.open(p).save(mp)
            print("re-anchored", base, note, "(rigid mask)" if base in RIGID_MASK else "")
        m2 = measure(p, fw)
        if m2:
            print("   now: drift %.1f base %.1f pulse %d%%" % (m2[1], m2[2], m2[3]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
