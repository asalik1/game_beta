"""fix_warlock_ult_e_frames — repair the warlock's Hex (ult clip) EAST strip.

Defect (owner, 2026-08-16): `warlock_ult_e.png` frames 7 and 8 were authored
FACING WEST — a 3/4 toward-camera body with the beam / dissipation ring fired
to the left — while frames 1-6 and 9 are the clean pure-east side view. In
game the warlock visibly snaps round and "attacks west" for two frames of an
east Hex.

Fix (no regen — the PIXELLAB_PROMPT_LESSONS rule-10(b) pattern): keep frame 6's
correct east body (arm extended, tome in hand) and composite the authored FX of
frames 7/8 onto it, MIRRORED so beam + ring sit on the east side and shifted so
the beam base lands on the extended hand. FX are isolated by colour (purple /
white), not by column, so no sleeve pixels ride along; frame 6's own fading
wisps are cleared first so the beam/ring don't stack on them.

Only `warlock_ult_e.png` changes (game/ + mobile/game/). Original archived to
backup/warlock_ult_e_westframes_2026-08-16/. QA sheet next to the backup.

Usage: python tools/art/fix_warlock_ult_e_frames.py [--dry-run]
"""
import os, sys, shutil
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TARGETS = [
    os.path.join(ROOT, "game", "assets", "sprites", "warlock_ult_e.png"),
    os.path.join(ROOT, "mobile", "game", "assets", "sprites", "warlock_ult_e.png"),
]
BACKUP = os.path.join(ROOT, "backup", "warlock_ult_e_westframes_2026-08-16")
CELL = 180
BODY_SRC = 5          # 0-based: frame 6 = last clean east body with the arm out
BODY_FX_CUT_X = 118   # clear frame 6's fading wisps right of the hand
# (0-based frame, xmax of the FX in the ORIGINAL west-facing cell, dx, dy) —
# dx/dy position the MIRRORED FX so its base sits on frame 6's extended hand.
PATCH = [
    (6, 66, -14, -10),  # frame 7: returning beam, wide end at the hand
    (7, 60, -10, -10),  # frame 8: dissipating ring just off the hand
]


def _frames(strip):
    n = strip.width // CELL
    return [strip.crop((i * CELL, 0, (i + 1) * CELL, CELL)) for i in range(n)]


def _fx_only(frame, xmax):
    """Keep only purple/white FX pixels left of xmax (drop robe/hand), mirrored."""
    a = np.array(frame).astype(int)
    vis = a[:, :, 3] > 0
    fx = (a[:, :, 2] > a[:, :, 1] + 30) | (a[:, :, 0] + a[:, :, 1] + a[:, :, 2] > 450)
    m = vis & fx
    m[:, xmax:] = False
    o = np.array(frame).copy()
    o[~m] = 0
    return Image.fromarray(o).transpose(Image.FLIP_LEFT_RIGHT)


def _shift(img, dx, dy):
    arr = np.array(img)
    res = np.zeros_like(arr)
    sx0, sy0 = max(0, -dx), max(0, -dy)
    dx0, dy0 = max(0, dx), max(0, dy)
    w, h = CELL - abs(dx), CELL - abs(dy)
    res[dy0:dy0 + h, dx0:dx0 + w] = arr[sy0:sy0 + h, sx0:sx0 + w]
    return Image.fromarray(res)


def build(strip):
    F = _frames(strip)
    body = np.array(F[BODY_SRC]).copy()
    body[:, BODY_FX_CUT_X:, :] = 0
    for idx, xmax, dx, dy in PATCH:
        cell = Image.fromarray(body.copy())
        cell.alpha_composite(_shift(_fx_only(F[idx], xmax), dx, dy))
        F[idx] = cell
    out = Image.new("RGBA", strip.size, (0, 0, 0, 0))
    for i, f in enumerate(F):
        out.paste(f, (i * CELL, 0))
    return out


def qa_sheet(before, after, path):
    S = 2
    n = before.width // CELL
    sheet = Image.new("RGBA", (n * CELL * S, 2 * CELL * S), (40, 40, 40, 255))
    for r, strip in enumerate((before, after)):
        z = strip.resize((strip.width * S, CELL * S), Image.NEAREST)
        sheet.paste(z, (0, r * CELL * S), z)
    sheet.save(path)


def main():
    dry = "--dry-run" in sys.argv
    src = TARGETS[0]
    before = Image.open(src).convert("RGBA")
    assert before.size == (CELL * 9, CELL), before.size
    after = build(before)
    os.makedirs(BACKUP, exist_ok=True)
    qa = os.path.join(BACKUP, "warlock_ult_e_before_after.png")
    qa_sheet(before, after, qa)
    print("QA sheet:", qa)
    if dry:
        print("dry run — nothing installed")
        return
    bak = os.path.join(BACKUP, "warlock_ult_e.png")
    if not os.path.exists(bak):
        shutil.copy2(src, bak)
        print("backed up ->", bak)
    for t in TARGETS:
        after.save(t)
        print("installed ->", os.path.relpath(t, ROOT))


if __name__ == "__main__":
    main()
