#!/usr/bin/env python
"""Despill the dark/neon-green chroma rim that remove_chroma_key leaves on some
Codex masters, IN PLACE, before build_act1_dirset / build_codex_2x2_strip slice
them (those trust an already-keyed master and don't re-despill; a LANCZOS resize
would only spread the fringe). CLAUDE.md rule: clamp any visible pixel whose
green dominates toward max(R,B), and drop the faint green edge crumbs.

  python tools/art/despill_keyed.py <keyed.png> [<keyed.png> ...]

Reports the green-dominant pixel count before/after per file.
"""
import sys
import numpy as np
from PIL import Image

THR = 18          # green-dominance over max(r,b) to treat as spill
EDGE_A = 40       # alpha at/below this on a green-dominant pixel -> cut


def despill(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).copy()
    r = a[..., 0].astype(np.int16)
    g = a[..., 1].astype(np.int16)
    b = a[..., 2].astype(np.int16)
    al = a[..., 3]
    dom = g - np.maximum(r, b)
    before = int(((dom > THR) & (al > 0)).sum())
    # clamp green on visible pixels
    spill = (dom > THR) & (al > 0)
    a[..., 1][spill] = np.maximum(r, b)[spill].astype(np.uint8)
    # cut faint green edge crumbs entirely
    crumbs = (dom > THR) & (al > 0) & (al <= EDGE_A)
    a[..., 3][crumbs] = 0
    im2 = Image.fromarray(a, "RGBA")
    a2 = np.asarray(im2)
    dom2 = a2[..., 1].astype(np.int16) - np.maximum(a2[..., 0], a2[..., 2]).astype(np.int16)
    after = int(((dom2 > THR) & (a2[..., 3] > 0)).sum())
    im2.save(path)
    print(f"  {path.split(chr(92))[-1]}: green {before} -> {after}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        despill(p)
