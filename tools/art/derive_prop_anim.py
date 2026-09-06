#!/usr/bin/env python3
"""Derive a self-animating <name>_anim.png strip FROM a prop's existing static
PNG — so the animation MATCHES the current art exactly (zero drift), unlike a
fresh generation. Frame 0 is the untouched static; the rest apply a subtle
motion. Used for the props that only need pulse/flicker/wave/shimmer (crystals,
banners, wells, firepits) — real material motion (a procedural brazier with no
PNG) still goes through Codex.

Frame layout matches anim_info(): N frames each the static's WxH, concatenated
horizontally (so the engine reads frames = anim_width / static_width).

Motions:
  pulse    brightness breathes on the GLOW ONLY: a smoothstep over the sprite's
           own luminance distribution (0 below the 45th percentile, 1 above the
           85th), so facets and cores shimmer and the stone shell holds byte-
           still — crystals, geodes, void/storm/spore/magma glow. `--warm`
           further gates the weight by the fire mask (furnaces, braziers: the
           flame breathes, the stone stack never). Before 2026-09-05 the weight
           was 0.35 + 0.65*lum and the darkest stone still swung a third of
           the amplitude (audit: darkest-30% 4.5-8.5%, same as the bright 30%).
  flicker  warm (fire) pixels flicker brighter/dimmer + the flame top wobbles
  wave     horizontal sine shear per row — a banner rippling in the wind
  sway     canopy sway: the same shear with its amplitude ramped from 0 at the
           trunk base to full at the crown, so a tree leans without sliding
  shimmer  cool (water) pixels breathe + a 1px horizontal jitter — well water
  flow     a POURING liquid: the liquid mask (cool water OR olive sludge, minus the
           2px keyed rim) scrolls its COLOUR downward and breathes; alpha untouched,
           so the silhouette stays byte-stable — sewer outfalls, spillways
  swirl    void/energy pixels churn: the whole glow breathes while rotating
           lobes + outward-traveling bright rings sweep through it. The rigid
           shell is NEVER touched (mask-gated), so it stays pixel-locked —
           for portals/rifts/arcane nodes whose stone must not wander.

Usage:
  python tools/art/derive_prop_anim.py <name> --motion pulse [--frames 4]
        [--amp 0.35] [--no-mobile]
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
DESK = REPO / "game" / "assets" / "sprites"
MOBILE = REPO / "mobile" / "game" / "assets" / "sprites"


FLOW_STEPS = 4      # scroll steps per loop for motion "flow"
FLOW_PX = 2         # px of colour scroll per step, at MASTER resolution


def _lum(rgb):  # 0..1 per-pixel luminance
    return (0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]) / 255.0


def _warm_mask(rgb):  # fire pixels: red-dominant, warm
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return ((r > 110) & (r >= g) & (g >= b) & (r - b > 40)).astype(np.float32)


def _cool_mask(rgb):  # water pixels: blue/teal-dominant
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return ((b > 90) & (b >= r) & (g + b - 2 * r > 20)).astype(np.float32)


def _liquid_mask(a):
    """Any flowing liquid, not just blue water: cool pixels OR olive/green sludge
    (green at or above red and well above blue). The 2px alpha rim is EXCLUDED --
    a keyed sprite's edge pixels read green and animating them would shimmer the
    whole outline (2026-09-05, sewer_outfall)."""
    from scipy import ndimage
    rgb = a[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    al = a[..., 3] > 40
    m = al & (((g >= r - 12) & (g > b + 28) & (g > 65)) | (_cool_mask(rgb) > 0))
    return (m & ndimage.binary_erosion(al, iterations=2)).astype(np.float32)


def _scale_rgb(a, factor):
    out = a.astype(np.float32)
    out[..., :3] = np.clip(out[..., :3] * factor[..., None], 0, 255)
    return out.astype(np.uint8)


def frame(base: np.ndarray, motion: str, phase: float, amp: float, warm_only: bool = False) -> Image.Image:
    a = base.copy()
    lum = _lum(a[..., :3])
    s = np.sin(phase)
    if motion == "pulse":
        # GLOW-ONLY (2026-09-05): the old weight 0.35 + 0.65*lum still swung the
        # darkest stone by a third of the amplitude, so a crystal's rock base
        # breathed with its facets (audit: darkest-30% pixels 4.5-8.5%, the
        # same as the bright 30%). The weight is now a smoothstep over the
        # sprite's own luminance distribution -- 0 below the 45th percentile,
        # 1 above the 85th -- so only the glow breathes and the shell holds.
        a_on = a[..., 3] > 40
        lo, hi = (np.percentile(lum[a_on], 45), np.percentile(lum[a_on], 85)) if a_on.any() else (0.4, 0.8)
        t = np.clip((lum - lo) / max(1e-3, hi - lo), 0.0, 1.0)
        weight = t * t * (3.0 - 2.0 * t)
        if warm_only:
            weight = weight * _warm_mask(a[..., :3])   # furnaces: the flame only, never the stone stack
        factor = 1.0 + amp * s * weight
        a = _scale_rgb(a, factor)
    elif motion == "flicker":
        warm = _warm_mask(a[..., :3])
        factor = 1.0 + amp * (0.6 * s + 0.4 * np.sin(phase * 2.3 + 1.1)) * warm
        a = _scale_rgb(a, factor)
        # nudge the warm flame body up/down a hair for a live flame
        shift = int(round(amp * 3.0 * s))
        if shift != 0:
            warm_layer = a.copy()
            warm_layer[..., 3] = (warm_layer[..., 3] * warm).astype(np.uint8)
            warm_layer = np.roll(warm_layer, -shift, axis=0)
            m = warm_layer[..., 3:4] > 30
            a = np.where(m, warm_layer, a)
    elif motion == "shimmer":
        cool = _cool_mask(a[..., :3])
        factor = 1.0 + amp * s * cool
        a = _scale_rgb(a, factor)
        jit = int(round(amp * 2.0 * np.sin(phase + 0.7)))
        if jit != 0:
            water = a.copy()
            water[..., 3] = (water[..., 3] * cool).astype(np.uint8)
            water = np.roll(water, jit, axis=1)
            m = water[..., 3:4] > 30
            a = np.where(m, water, a)
    elif motion == "flow":
        # A liquid that POURS (sewer outfall, spillway): the masked liquid's COLOUR
        # scrolls downward and breathes. Alpha is never touched, so the silhouette
        # stays byte-stable and the rigid-prop contract holds. `shimmer` only knows
        # BLUE water and does nothing at all on olive sludge -- hence this motion.
        liq = _liquid_mask(a)
        if liq.any():
            m = liq > 0
            # frame index from the phase (frame 0 = phase 0 = the untouched static)
            step = int(round(phase / (2.0 * np.pi) * FLOW_STEPS)) % FLOW_STEPS
            if step:
                dy = step * FLOW_PX
                src = np.roll(a, -dy, axis=0)                 # pull colour up = liquid falls
                both = m & np.roll(m, -dy, axis=0)
                a[..., :3] = np.where(both[..., None], src[..., :3], a[..., :3])
            a = _scale_rgb(a, 1.0 + amp * 0.6 * s * liq)
    elif motion == "wave":
        h, w = a.shape[:2]
        rows = np.arange(h)
        shifts = np.round(amp * 6.0 * np.sin(phase + rows * 0.05)).astype(int)
        out = np.zeros_like(a)
        for y in range(h):
            out[y] = np.roll(a[y], shifts[y], axis=0)
        a = out
    elif motion == "sway":
        # CANOPY sway for a tree or bush: a horizontal shear whose amplitude ramps
        # from 0 at the trunk base to full at the crown (quadratic), so the trunk
        # stays put while the branches lean. `wave` shears every row equally and
        # would slide the whole trunk sideways -- wrong for anything rooted.
        # Foliage MAY change silhouette (CLAUDE.md prop contract); the gate for
        # these strips is the trunk BASE band, which this leaves untouched.
        h, w = a.shape[:2]
        al = a[..., 3] > 40
        ys = np.nonzero(al.any(axis=1))[0]
        top, bot = (int(ys.min()), int(ys.max())) if len(ys) else (0, h - 1)
        span = max(1, bot - top)
        ramp = np.clip((bot - np.arange(h)) / float(span), 0.0, 1.0) ** 2
        shifts = np.round(amp * 10.0 * np.sin(phase) * ramp).astype(int)
        out = np.zeros_like(a)
        for y in range(h):
            out[y] = np.roll(a[y], int(shifts[y]), axis=0)
        a = out
    elif motion == "swirl":
        # Energy = void/arcane pixels (blue+red dominant over green). Only these
        # brighten/dim; the rigid shell is left byte-for-byte identical, so the
        # silhouette never drifts (bbox stable across every frame — the property
        # verify_art's rigid-drift gate checks). The motion is a rotating pair
        # of lobes plus rings traveling outward, so the plasma reads as churning
        # rather than merely fading.
        rgb = a[..., :3].astype(np.float32)
        energy = ((rgb[..., 0] + rgb[..., 2]) > 2.0 * rgb[..., 1] + 30.0) \
            & (a[..., 3] > 40)
        if energy.any():
            h, w = a.shape[:2]
            ys, xs = np.where(energy)
            cx, cy = float(xs.mean()), float(ys.mean())
            yy, xx = np.mgrid[0:h, 0:w]
            ang = np.arctan2(yy - cy, xx - cx)
            rad = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
            rad_n = rad / (float(rad[energy].max()) + 1e-3)
            sweep = np.cos(ang * 2.0 - phase * 2.0)
            trav = np.sin(rad_n * 3.0 - phase * 2.0)
            factor = 1.0 + 0.6 * amp * s + 0.9 * amp * (0.5 * sweep + 0.5 * trav)
            a = _scale_rgb(a, np.where(energy, factor, 1.0).astype(np.float32))
    return Image.fromarray(a, "RGBA")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--motion", required=True,
                    choices=["pulse", "flicker", "wave", "shimmer", "swirl", "flow", "sway"])
    ap.add_argument("--frames", type=int, default=4)
    ap.add_argument("--amp", type=float, default=0.35)
    ap.add_argument("--no-mobile", action="store_true")
    ap.add_argument("--warm", action="store_true",
                    help="pulse: weight the glow by the warm (fire) mask as well, so a furnace's stone stack never breathes")
    args = ap.parse_args()

    src = DESK / f"{args.name}.png"
    if not src.exists():
        print(f"ERR: no static PNG {src} (procedural prop → use Codex instead)",
              file=sys.stderr)
        return 2
    im = Image.open(src).convert("RGBA")
    base = np.asarray(im)
    w, h = im.width, im.height
    # A motion whose colour mask matches (almost) nothing produces a DEAD strip --
    # shimmer on olive sludge, flicker on an unlit pit, swirl on pale-blue light
    # (2026-09-06 corpus scan found five). Warn before writing one.
    al = base[..., 3] > 40
    cover = None
    if args.motion == "flicker":
        cover = _warm_mask(base[..., :3])[al].mean()
    elif args.motion == "shimmer":
        cover = _cool_mask(base[..., :3])[al].mean()
    elif args.motion == "flow":
        cover = _liquid_mask(base)[al].mean()
    elif args.motion == "swirl":
        rgb = base[..., :3].astype(np.float32)
        cover = float((((rgb[..., 0] + rgb[..., 2]) > 2.0 * rgb[..., 1] + 30.0) & al)[al].mean())
    if cover is not None:
        print(f"  {args.motion} mask covers {cover:.1%} of the body")
        if cover < 0.01:
            print(f"  WARNING: {args.motion} has almost nothing to animate on {args.name} -- "
                  f"this strip will be effectively STATIC. Pick a motion whose mask matches the art "
                  f"(audit_prop_anims flags DEAD strips).", file=sys.stderr)
    strip = Image.new("RGBA", (w * args.frames, h), (0, 0, 0, 0))
    for i in range(args.frames):
        phase = 2.0 * np.pi * i / args.frames    # frame 0 = static (sin 0 = 0)
        strip.paste(frame(base, args.motion, phase, args.amp, args.warm), (i * w, 0))
    print(f"{args.name}: {args.frames}x{w}x{h} ({args.motion})")
    for root, on in ((DESK, True), (MOBILE, not args.no_mobile)):
        if not on:
            continue
        out = root / f"{args.name}_anim.png"
        strip.save(out)
        print(f"  wrote {out.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
