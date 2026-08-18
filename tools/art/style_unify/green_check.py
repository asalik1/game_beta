"""Green-cast check on keyed results: share of opaque pixels with
G > max(R,B)+20 (the rim gate from the mob-sheet lessons), plus an N-up
preview. A translucent subject (a web) can soak the key up wholesale — this
catches it before install (then DESAT_FULL in install_stage.py).
  python green_check.py <stage_root> <out.png> name...
"""
import os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import TOOLS_ART  # noqa: E402
sys.path.insert(0, TOOLS_ART)
import install_prop_hires as iph  # noqa: E402

stage, out = sys.argv[1], sys.argv[2]
names = sys.argv[3:]
cell = 300
sheet = Image.new("RGBA", (cell * max(1, len(names)), cell + 16), (60, 55, 50, 255))
for i, n in enumerate(names):
    im = iph.ensure_alpha(Image.open(os.path.join(stage, n, n + ".png")).convert("RGBA"))
    a = np.asarray(im).astype(int)
    op = a[..., 3] > 128
    g = (a[..., 1] > np.maximum(a[..., 0], a[..., 2]) + 20) & op
    print("%-16s opaque=%d greenish=%d (%.1f%%)" % (n, op.sum(), g.sum(), 100.0 * g.sum() / max(1, op.sum())))
    im.thumbnail((cell - 8, cell - 8))
    sheet.alpha_composite(im, (i * cell + 4, 4))
sheet.save(out)
