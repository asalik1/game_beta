#!/usr/bin/env python
"""Turn a front/back walk 2x2 master into a GUARANTEED-alternating cycle by the
mirror trick — for SYMMETRIC bosses only (owner 2026-08-18: mirror-walk
Nullwarden). ImageGen reliably draws leg MOTION but not clean left/right
alternation on a front figure; a symmetric body's horizontal mirror of a
contact pose IS a valid opposite-lead contact, so we build the cycle from two
real frames + their mirrors.

Picks the widest-stance frame (CONTACT, feet apart) and the narrowest
(PASSING, feet together) from the 4 generated frames, then writes a new 2x2
master in reading order [contact, pass, mirror(contact), mirror(pass)] =
frames 1,2,3,4 -> left-contact, pass, right-contact, pass. build_act1_dirset
then slices/normalizes it unchanged.

ONLY valid where the body is left/right symmetric (no weapon/insignia that
must not flip). Do NOT use on a boss holding a weapon to one side.

  python tools/art/mirror_cycle_master.py <walk_master_2x2_keyed.png> [out.png]
  (out defaults to overwriting the input)
"""
import sys
import numpy as np
from PIL import Image

ATHR = 24


def quads(im: Image.Image):
    w, h = im.size
    hw, hh = w // 2, h // 2
    return [im.crop((0, 0, hw, hh)), im.crop((hw, 0, w, hh)),
            im.crop((0, hh, hw, h)), im.crop((hw, hh, w, h))]


def foot_spread(q: Image.Image) -> int:
    """Opaque width in the bottom 28% of the body (the feet band)."""
    a = np.asarray(q.convert("RGBA"))[..., 3] > ATHR
    ys, xs = np.where(a)
    if len(ys) == 0:
        return 0
    top, bot = ys.min(), ys.max()
    band = a[bot - int((bot - top) * 0.28):bot + 1]
    return int(band.any(axis=0).sum())


def main() -> int:
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else src
    im = Image.open(src).convert("RGBA")
    qs = quads(im)
    spreads = [foot_spread(q) for q in qs]
    contact = int(np.argmax(spreads))       # feet widest apart
    pas = int(np.argmin(spreads))            # feet closest together
    if pas == contact:                       # degenerate: pick a different pass
        pas = int(np.argsort(spreads)[1])
    c, p = qs[contact], qs[pas]
    cm = c.transpose(Image.FLIP_LEFT_RIGHT)
    pm = p.transpose(Image.FLIP_LEFT_RIGHT)
    # canvas = 2x2 of the ORIGINAL quadrant size (so downstream geometry is unchanged)
    qw, qh = qs[0].size
    canvas = Image.new("RGBA", (qw * 2, qh * 2), (0, 0, 0, 0))
    canvas.paste(c, (0, 0))            # TL frame1: left-contact
    canvas.paste(p, (qw, 0))           # TR frame2: pass
    canvas.paste(cm, (0, qh))          # BL frame3: right-contact (mirror)
    canvas.paste(pm, (qw, qh))         # BR frame4: pass (mirror)
    canvas.save(out)
    print(f"  {src.split(chr(92))[-1]}: contact=f{contact + 1}(spread {spreads[contact]}) "
          f"pass=f{pas + 1}(spread {spreads[pas]}) -> [contact,pass,mirror,mirror]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
