#!/usr/bin/env python
"""FACING LAYOUT scan (2026-09-06): is a copy/mirror facing family still consistent?

The owner-approved layout for a regenerated 8-direction set (hero walks, Vargoth, every
boss walk_codex family) is: author S, E and N; SE and NE are byte COPIES of E; W, NW and
SW are per-cell MIRRORS of E. That makes the family cheap to keep correct -- and easy to
half-fix, because an edit to E (a tone match, a re-seat, a re-roll) leaves the copies and
mirrors on the OLD art until someone rebuilds them. The result is a body that changes
brightness or size the moment the player turns, which is what every audit round kept
catching one subject at a time (vess was 7% brighter on its diagonals than on E after only
E/N/W were tone-matched, 2026-09-06).

This finds families that USE the convention (at least one exact copy or exact mirror pair
among the eight) and then checks it holds everywhere:

    se == e, ne == e, w == mirror(e), nw == mirror(e), sw == mirror(e)

Authored per-facing sets (the NPC roster, PixelLab ability strips) have no exact copies and
are skipped -- their facings are meant to differ. Deviations print with the measured body
and luminance gap so you can see what the player would see.

    python tools/art/facing_seam_scan.py [--only a,b] [--list]

Fix: rebuild the copies/mirrors from the edited E (copy for SE/NE, per-cell mirror for the
W family), then re-run. `--list` prints every convention family and its status.

This is a REPORT, not a gate. A family can use the copy convention for its diagonals while
its W facings are genuinely AUTHORED (the base paladin's attack2/attackb/cast/death): with
light from the top-left, a figure facing west shows its lit side and reads 15-20% brighter
than the same figure facing east, which is intentional painterly art, not stale bytes.
Judge a flag by whether the two facings are supposed to be the same drawing.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


def arr(p: Path) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGBA"))


def mirror(a: np.ndarray) -> np.ndarray:
    c = a.shape[0]
    n = a.shape[1] // c
    return np.concatenate([a[:, i * c:(i + 1) * c][:, ::-1] for i in range(n)], axis=1)


def digest(a: np.ndarray) -> str:
    return hashlib.md5(np.ascontiguousarray(a).tobytes()).hexdigest()


def stats(a: np.ndarray):
    c = a.shape[0]
    f = a[:, :c]
    m = f[:, :, 3] > 60
    if not m.any():
        return None
    ys, _ = np.nonzero(m)
    lum = (0.299 * f[:, :, 0] + 0.587 * f[:, :, 1] + 0.114 * f[:, :, 2])[m].mean()
    return (ys.max() - ys.min() + 1) / c, float(lum)


def families():
    out = {}
    for p in SPR.glob("*_e.png"):
        base = re.sub(r"_e$", "", p.stem)
        have = [d for d in DIRS if (SPR / f"{base}_{d}.png").exists()]
        if len(have) >= 7:
            out[base] = have
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--bar", type=float, default=5.0, help="%% body or luma gap vs E that counts as drift")
    args = ap.parse_args()
    only = {x for x in args.only.split(",") if x}
    conv = bad = 0
    for base, have in sorted(families().items()):
        if only and base not in only:
            continue
        try:
            a = {d: arr(SPR / f"{base}_{d}.png") for d in have}
        except Exception:
            continue
        if "e" not in a:
            continue
        e = a["e"]
        de, me = digest(e), digest(mirror(e))
        # does this family USE the convention at all?
        # Evidence of the convention: SE or NE is an EXACT byte copy of E. An
        # authored roster never is. (A MIRROR is not evidence: install lanes
        # mirror about slightly different centres, so an equivalent mirror can
        # differ byte-wise -- that is why only the copy slots are byte-checked
        # and the W family is judged on measured body/luma instead.)
        uses = any(d in a and a[d].shape == e.shape and digest(a[d]) == de
                   for d in ("se", "ne"))
        if not uses:
            continue
        conv += 1
        se_e, le_e = stats(e) or (0, 0)
        wrong = []
        for d in ("se", "ne", "w", "nw", "sw"):
            if d not in a:
                continue
            sd, ld = stats(a[d]) or (0, 0)
            dsz = (sd / max(1e-6, se_e) - 1) * 100
            dlm = (ld / max(1e-6, le_e) - 1) * 100
            exact = a[d].shape == e.shape and digest(a[d]) == (de if d in ("se", "ne") else me)
            if not exact and (abs(dsz) >= args.bar or abs(dlm) >= args.bar):
                wrong.append((d, dsz, dlm))
        if wrong:
            bad += 1
            print(f"{base}: {len(wrong)} facing(s) off the copy/mirror layout")
            for d, ds, dl in wrong:
                kind = "copy of E" if d in ("se", "ne") else "mirror of E"
                print(f"    {d:3s} should be a {kind:11s} -- body {ds:+5.1f}%  luma {dl:+5.1f}%")
        elif args.list:
            print(f"{base}: OK (copy/mirror layout holds)")
    print(f"{conv} families use the copy/mirror layout, {bad} inconsistent")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
