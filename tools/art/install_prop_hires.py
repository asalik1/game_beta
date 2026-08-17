#!/usr/bin/env python
"""Install a HIGH-RESOLUTION regen of an existing static scenery prop.

The 24 "main-terrain" scatter props (ice_sled, coffin, the graveyard set, small
rocks/decals) shipped as tiny 8-48px sources that the game upscales 3x, so they
read blocky beside the new native-res floors. This installs a Codex hi-res regen
(silhouette/palette kept via -i reference) so the source DOWNSCALES to its render
width = crisp. Pair with a Balance.SCENERY_RENDER_WIDTH entry (= current native*3
render width) so the on-screen size is unchanged.

  python tools/art/install_prop_hires.py <name> <src.png> <render_w>

Normalizes: solid-bg chroma-key -> real alpha, crop to alpha bbox, resize to
~2.5x the render width (crisp downscale headroom), light green-rim despill, mild
gamma lift for Forward+ tonemap. Writes game/ and mobile/game/ in one shot.
"""
import os
import sys
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(REPO, "game", "assets", "sprites")
MOBILE = os.path.join(REPO, "mobile", "game", "assets", "sprites")


def load_rgba(p):
    return Image.open(p).convert("RGBA")


def ensure_alpha(im):
    """If the gen came back on a solid background, key the corner colour out."""
    lo, _hi = im.getchannel("A").getextrema()
    if lo < 250:
        return im  # already has real transparency
    w, h = im.size
    px = im.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = max(set(corners), key=corners.count)[:3]
    out = []
    for r, g, b, a in im.getdata():
        d = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
        out.append((r, g, b, 0 if d < 42 else a))
    im.putdata(out)
    return im


def alpha_bbox(im, thresh=16):
    return im.getchannel("A").point(lambda v: 255 if v > thresh else 0).getbbox()


def despill(im):
    """Kill the dark-green antialias rim ImageGen leaves on semi-alpha edges."""
    w, h = im.size
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if 0 < a < 255 and g > max(r, b) + 18:
                px[x, y] = (r, (max(r, b) + (r + b) // 2) // 2, b, a)
    return im


def gamma(im, g):
    lut = [min(255, int(((i / 255.0) ** g) * 255 + 0.5)) for i in range(256)]
    r, gc, b, a = im.split()
    return Image.merge("RGBA", (r.point(lut), gc.point(lut), b.point(lut), a))


def install(name, src, render_w, g=0.88):
    im = ensure_alpha(load_rgba(src))
    bb = alpha_bbox(im)
    if bb:
        im = im.crop(bb)
    w, h = im.size
    tw = max(128, min(320, round(render_w * 2.5)))
    nh = max(1, round(h * tw / w))
    nw = tw
    if nh > 384:  # very tall prop: fit by height instead
        nw = max(1, round(w * 384 / h))
        nh = 384
    im = im.resize((nw, nh), Image.LANCZOS)
    im = despill(im)
    im = gamma(im, g)
    wrote = []
    for d in (GAME, MOBILE):
        if os.path.isdir(d):
            p = os.path.join(d, name + ".png")
            im.save(p)
            wrote.append((p, im.size))
    return wrote


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit("usage: install_prop_hires.py <name> <src.png> <render_w>")
    name, src, rw = sys.argv[1], sys.argv[2], float(sys.argv[3])
    for p, sz in install(name, src, rw):
        print("wrote %s  %dx%d" % (p, sz[0], sz[1]))
