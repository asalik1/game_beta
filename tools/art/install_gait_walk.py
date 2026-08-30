"""Install a gait-transfer walk batch: green-keyed Codex rows -> engine strips.

The extraction half of the gait-transfer walk recipe (stride pilot 2026-08-28,
severed_thread archer; reusable for the warrior/paladin rounds). Per row:
key out the #00ff00 background, despill the green RIM BAND only (2 px from the
alpha edge -- a global green clamp dulled the archer's olive cloak in review),
TORSO-BAND ANCHOR each frame (x-centroid of the upper 40% of the body to cell
center -- gait-donor gens bake canvas travel: roll 3 drifted 73 px and played
as side-to-side wobble until anchored), scale the row's MEDIAN body height to
the old strip's body, pin each frame's lowest opaque pixel to the old feet
line. Then write the mirror facings (w/nw/sw = per-cell mirror of e/ne/se) and
flat = copy of s -- the conventions measured off the existing set.

    python tools/art/install_gait_walk.py --base skins/elite/archer_severed_thread \
        --row e=art_src/.../walk_e_v3/walk_e_v3_row.png \
        --row s=art_src/.../walk_s/walk_s_row.png [--row n=... --row se=... --row ne=...]
        [--dry]

Geometry (cell/body/feet) is MEASURED from the existing <base>_walk_s strip.
After install: --import, verify_art <base> --stride-min 0.45, test_quick,
ba_gifs + travel_gif review, full suite before staging.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"

MIRRORS = {"w": "e", "nw": "ne", "sw": "se"}


def key_and_despill(im: Image.Image) -> np.ndarray:
    arr = np.array(im.convert("RGBA")).astype(int)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    key = (g > 120) & (g > r + 30) & (g > b + 30)
    arr[:, :, 3] = np.where(key, 0, arr[:, :, 3])
    # rim-band despill: green-dominant pixels within 2 px of transparency
    a = arr[:, :, 3] > 40
    near_edge = np.zeros_like(a)
    inv = ~a
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            near_edge |= np.roll(np.roll(inv, dy, 0), dx, 1)
    band = a & near_edge & (g > np.maximum(r, b) + 18)
    arr[:, :, 1] = np.where(band, np.maximum(r, b) + 8, g)
    return arr.clip(0, 255).astype(np.uint8)


def torso_cx(alpha: np.ndarray) -> float:
    ys, xs = np.nonzero(alpha > 40)
    top, bot = ys.min(), ys.max()
    band = (ys >= top) & (ys <= top + int((bot - top) * 0.40))
    return float(xs[band].mean())


def build_strip(row_png: Path, cell: int, body_target: int, feet_y: int) -> Image.Image:
    im = Image.open(row_png)
    rgba = key_and_despill(im)
    n = 6
    fw = rgba.shape[1] // n
    cells = [rgba[:, f * fw:(f + 1) * fw] for f in range(n)]
    bodies = []
    for c in cells:
        ys = np.nonzero(c[:, :, 3] > 40)[0]
        bodies.append(ys.max() - ys.min() + 1)
    S = body_target / float(np.median(bodies))
    out = Image.new("RGBA", (cell * n, cell), (0, 0, 0, 0))
    for f, c in enumerate(cells):
        img = Image.fromarray(c)
        sw, sh = max(1, int(fw * S)), max(1, int(rgba.shape[0] * S))
        img = img.resize((sw, sh), Image.LANCZOS)
        a = np.array(img)[:, :, 3]
        ys = np.nonzero(a > 40)[0]
        bottom = int(ys.max()) if len(ys) else sh - 1
        cx = torso_cx(a)
        out.alpha_composite(img, (int(f * cell + cell / 2 - cx), feet_y - bottom))
    # Post-resize fringe despill: LANCZOS re-blends keyed-adjacent green into
    # the new semi-alpha edge (the pre-resize rim despill can't prevent it —
    # ~1.3k green-rim px/strip on the severed batch, 2026-08-28). Neutralize
    # any green-dominant semi pixel.
    arr = np.array(out).astype(int)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    hot = (a > 0) & (a < 255) & (g > np.maximum(r, b))
    arr[:, :, 1] = np.where(hot, np.maximum(r, b), g)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def tone_match(strip: Image.Image, old_path: Path) -> Image.Image:
    """Match the built strip's palette to the strip it replaces (per-channel
    mean/std over opaque pixels). Kills the TONE/BRIGHTNESS-SHIFT drift class
    (owner catch 2026-08-29: a regen ~10% brighter than its siblings passes
    per-strip review and flashes at clip transitions / walk_b alternation —
    see DRIFT_AUDIT.md catalogue). Matching against the outgoing strip keeps
    the family's established tone; a reinstall over an already-matched strip
    is a near no-op."""
    if not old_path.exists():
        return strip
    old = np.array(Image.open(old_path).convert("RGBA")).astype(float)
    new = np.array(strip).astype(float)
    om, nm = old[:, :, 3] > 128, new[:, :, 3] > 128
    if om.sum() < 500 or nm.sum() < 500:
        return strip
    # LUMINANCE-ONLY match with CHROMA PROTECTION. Per-channel RGB matching
    # shifted hue (+10 blue) and any global darkening shrinks absolute channel
    # gaps — both bleach saturated accents (the paladin's gold cross fell
    # below verify_art's SIGPART r>b+50 detector: a false "emblem vanishes").
    # So: scale each pixel's RGB jointly by the luma correction, but ramp the
    # correction OFF for strongly-saturated pixels — emblems, ember edges and
    # glows keep their authored pop while armor/cloth take the match.
    # Three pixel regimes (v3, 2026-08-29 — the owner saw the flash the v2
    # chroma-protection left: exempting ALL saturated pixels kept the tabard
    # and shield tints at the gen's +23%, so the body pulsed at every
    # alternation flip):
    #   low-chroma (armor/plates/cloth bulk): full per-channel match — fixes
    #     brightness AND the warm/cool cast a luma factor can't touch;
    #   saturated colors (tabard, tints): LUMA-only — brightness matches, hue
    #     survives;
    #   gold-emblem pixels only: authored values kept (verify_art SIGPART
    #     reads absolute r-b margins; darkening bleaches the cross).
    def luma(px):
        return 0.299 * px[:, :, 0] + 0.587 * px[:, :, 1] + 0.114 * px[:, :, 2]
    lo, ln = luma(old)[om], luma(new)[nm]
    if abs(lo.mean() - ln.mean()) / max(lo.mean(), 1e-6) < 0.04 \
            and 0.94 < lo.std() / max(ln.std(), 1e-6) < 1.06:
        return strip  # tone already agrees; don't touch margins for nothing
    a = lo.std() / max(ln.std(), 1e-6)
    b = lo.mean() - a * ln.mean()
    full_l = np.maximum(luma(new), 1e-6)
    lfac = np.clip((a * full_l + b) / full_l, 0.5, 2.0)
    chroma = new[:, :, :3].max(axis=2) - new[:, :, :3].min(axis=2)
    r, g, bl = new[:, :, 0], new[:, :, 1], new[:, :, 2]
    gold = (r >= 100) & (r > bl + 35) & (g > bl + 10)
    def lowc(px):
        c = px[:, :, :3].max(axis=2) - px[:, :, :3].min(axis=2)
        return c < 40
    blend = np.clip((chroma - 30.0) / 40.0, 0.0, 1.0)  # 0 = per-channel, 1 = luma-only
    for c in range(3):
        oc = old[:, :, c][om & lowc(old)]
        nc = new[:, :, c][nm & lowc(new)]
        if len(oc) > 500 and len(nc) > 500:
            ac = oc.std() / max(nc.std(), 1e-6)
            bc = oc.mean() - ac * nc.mean()
        else:
            ac, bc = 1.0, 0.0
        ch = new[:, :, c]
        matched = np.clip((ac * ch + bc) * (1.0 - blend) + ch * lfac * blend, 0, 255)
        new[:, :, c] = np.where(nm & ~gold, matched, ch)
    return Image.fromarray(new.clip(0, 255).astype(np.uint8))


def mirror_strip(strip: Image.Image, cell: int) -> Image.Image:
    n = strip.width // cell
    out = Image.new("RGBA", strip.size, (0, 0, 0, 0))
    for f in range(n):
        out.paste(strip.crop((f * cell, 0, (f + 1) * cell, cell)).transpose(
            Image.FLIP_LEFT_RIGHT), (f * cell, 0))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="install gait-transfer walk rows as engine strips")
    ap.add_argument("--base", required=True, help="e.g. skins/elite/archer_severed_thread")
    ap.add_argument("--row", action="append", required=True,
                    help="<facing>=<row.png>, facing in s/n/e/se/ne")
    ap.add_argument("--dry", action="store_true", help="write nothing, print plan")
    args = ap.parse_args()

    base = SPRITES / args.base.replace("\\", "/")
    ref = Image.open(f"{base}_walk_s.png")
    cell = ref.height
    a = np.array(ref.convert("RGBA"))[:, :, 3][:, :cell]
    ys = np.nonzero(a > 40)[0]
    body_target, feet_y = int(ys.max() - ys.min() + 1), int(ys.max())
    print(f"target geometry: cell {cell}  body {body_target}  feet {feet_y}")

    strips: dict[str, Image.Image] = {}
    for spec in args.row:
        d, _, p = spec.partition("=")
        strips[d] = tone_match(build_strip(ROOT / p, cell, body_target, feet_y),
                               Path(f"{base}_walk_{d}.png"))
        print(f"built {d} from {Path(p).name} (tone-matched to outgoing strip)")
    for m, src in MIRRORS.items():
        if src in strips:
            strips[m] = mirror_strip(strips[src], cell)
            print(f"mirrored {m} <- {src}")
    if "s" in strips:
        strips["flat"] = strips["s"]
        print("flat = copy of s")

    for d, strip in strips.items():
        dest = Path(f"{base}_walk.png") if d == "flat" else Path(f"{base}_walk_{d}.png")
        if args.dry:
            print(f"DRY would write {dest.name} {strip.size}")
        else:
            strip.save(dest)
            print(f"wrote {dest.relative_to(ROOT)} {strip.size}")
    if not args.dry:
        print("\nnow run: --import, then verify_art + gates (see docstring)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
