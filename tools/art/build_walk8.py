#!/usr/bin/env python
"""Build a LEG-walker's 8-frame directional walk from Codex 1x8-row masters.

The 2x2 4-frame walk (build_act1_dirset) makes ImageGen draw a near-static
standing pose with non-alternating legs (owner 2026-08-18, Vargoth). The
CLAUDE.md-proven fix is ONE ROW of EIGHT gait-labelled figures. This builder
consumes those masters and produces the SAME runtime asset the 2x2 path did
(`<sprite>_walk_codex_<dir>.png`, feet-anchored to the idle), just 8 frames.

Per-facing keyed masters:
  <dir_root>/<kind>/walk8/<facing>/walk8_master_1x8_v1_keyed.png   (facing = s,n,e)

Scheme (owner's, same as build_act1_dirset): author S/N/E; MIRROR E->W and
COPY E->{ne,se}, W->{nw,sw}; N stands alone; S fills any missing facing.
Each frame is despilled, sliced at real gutters, scaled by ONE per-direction
factor from the standing-contact frame so the body matches the idle, then
centred on the head and dropped onto the idle's ground line (so idle<->walk
never pops). Output cell = the idle cell.

  python tools/art/build_walk8.py <kind> <dir_root> [--install]

Writes <dir_root>/<kind>/walk8/out/<sprite>_walk_codex_<dir>.png (8 dirs) + qa.png.
--install copies them into game/assets/sprites (then run --import; the
BOSS_DIRECTIONAL_WALK dir_set at <sprite>_walk_codex lights up automatically).
"""
from __future__ import annotations
import os, sys, shutil
import numpy as np
from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPR = os.path.join(REPO, "game", "assets", "sprites")
sys.path.insert(0, os.path.join(REPO, "tools", "art"))
from act1_brief_lib import BOSSES  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
ATHR = 24          # alpha considered opaque
NFRAMES = 8


def despill(im: Image.Image) -> Image.Image:
    """Drop the dark-green chroma rim remove_chroma_key leaves: clamp any
    opaque pixel whose green dominates toward max(r,b) (CLAUDE.md G>max(R,B))."""
    a = np.asarray(im.convert("RGBA")).copy()
    r, g, b, al = a[..., 0].astype(np.int16), a[..., 1].astype(np.int16), a[..., 2].astype(np.int16), a[..., 3]
    m = (al > 0) & (g > np.maximum(r, b) + 18)
    a[..., 1][m] = np.maximum(r, b)[m].astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def col_occ(mask: np.ndarray) -> np.ndarray:
    return mask.sum(axis=0)


def slice8(im: Image.Image) -> list[Image.Image]:
    """Cut 8 cells at the 7 widest empty vertical gutters near the even splits."""
    a = np.asarray(im.convert("RGBA"))[..., 3] > ATHR
    w = a.shape[1]
    occ = col_occ(a)
    cuts = [0]
    for k in range(1, NFRAMES):
        target = round(w * k / NFRAMES)
        lo, hi = max(cuts[-1] + 8, target - w // (NFRAMES * 2)), min(w - 1, target + w // (NFRAMES * 2))
        window = occ[lo:hi + 1]
        if window.size == 0:
            cut = target
        else:
            # widest empty run in the window, else the emptiest column
            empty = window == 0
            if empty.any():
                # centre of the longest zero run
                best_len, best_c, run, start = 0, target, 0, None
                for i, e in enumerate(empty):
                    if e:
                        start = i if run == 0 else start
                        run += 1
                        if run > best_len:
                            best_len, best_c = run, lo + start + run // 2
                    else:
                        run = 0
                cut = best_c
            else:
                cut = lo + int(np.argmin(window))
        cuts.append(cut)
    cuts.append(w)
    return [im.crop((cuts[i], 0, cuts[i + 1], im.height)) for i in range(NFRAMES)]


def body_box(im: Image.Image):
    a = np.asarray(im.convert("RGBA"))[..., 3] > ATHR
    ys, xs = np.where(a)
    if len(ys) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def head_cx(im: Image.Image, bb) -> float:
    """X centroid of the top 22% of the body (head band) — the stable landmark
    to centre a walk on (the bbox centre slides as the legs splay)."""
    x0, y0, x1, y1 = bb
    band_h = max(1, int((y1 - y0) * 0.22))
    a = np.asarray(im.convert("RGBA"))[..., 3] > ATHR
    band = a[y0:y0 + band_h, :]
    xs = np.where(band.any(axis=0))[0]
    return float(xs.mean()) if len(xs) else (x0 + x1) / 2.0


def build_facing(master_path: str, ref_body_h: float, ref_hem_from_floor: int,
                 cell: int) -> Image.Image | None:
    if not os.path.exists(master_path):
        return None
    im = despill(Image.open(master_path).convert("RGBA"))
    frames = slice8(im)
    boxes = [body_box(f) for f in frames]
    if any(b is None for b in boxes):
        print(f"  WARN empty frame in {os.path.basename(master_path)}")
        return None
    # ONE scale for the whole direction, from the widest-standing contact frame
    # (max body height among frames ~ a standing/contact pose, not a mid-pass).
    stand = max(range(NFRAMES), key=lambda i: boxes[i][3] - boxes[i][1])
    sb = boxes[stand]
    scale = ref_body_h / float(sb[3] - sb[1])
    out = Image.new("RGBA", (cell * NFRAMES, cell), (0, 0, 0, 0))
    ground = cell - ref_hem_from_floor          # idle feet row within the cell
    for i, (f, bb) in enumerate(zip(frames, boxes)):
        crop = f.crop(bb)
        nw, nh = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
        r = crop.resize((nw, nh), Image.LANCZOS)
        cx = (head_cx(f, bb) - bb[0]) * scale    # head centroid in the resized crop
        ox = int(round(cell / 2 - cx))
        oy = int(round(ground - nh))             # feet (crop bottom) on the ground row
        cellimg = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        cellimg.alpha_composite(r, (ox, oy))
        out.paste(cellimg, (i * cell, 0))
    return out


def hflip(strip: Image.Image, cell: int) -> Image.Image:
    out = Image.new("RGBA", strip.size, (0, 0, 0, 0))
    for i in range(NFRAMES):
        c = strip.crop((i * cell, 0, (i + 1) * cell, cell)).transpose(Image.FLIP_LEFT_RIGHT)
        out.paste(c, (i * cell, 0))
    return out


def main() -> int:
    kind, root = sys.argv[1], sys.argv[2]
    install = "--install" in sys.argv[3:]
    sprite = BOSSES[kind][0]
    ref_path = os.path.join(SPR, f"{sprite}_anim_codex.png")
    if not os.path.exists(ref_path):
        ref_path = os.path.join(SPR, f"{sprite}_anim.png")
    ref = Image.open(ref_path).convert("RGBA")
    cell = ref.height
    rb = body_box(ref.crop((0, 0, cell, cell)))
    ref_body_h = rb[3] - rb[1]
    ref_hem = cell - rb[3]
    print(f"ref {os.path.basename(ref_path)}: cell {cell}, body {ref_body_h}, hem {ref_hem} above floor")

    base = os.path.join(root, kind, "walk8")
    out_dir = os.path.join(base, "out")
    os.makedirs(out_dir, exist_ok=True)
    built: dict[str, Image.Image] = {}
    for f in ("s", "n", "e"):
        mp = os.path.join(base, f, "walk8_master_1x8_v1_keyed.png")
        strip = build_facing(mp, ref_body_h, ref_hem, cell)
        if strip is not None:
            built[f] = strip
            print(f"  {f}: built 8 frames")
        else:
            print(f"  {f}: no master")
    if "s" not in built:
        print(f"FAIL {kind}: no S facing master")
        return 2
    if "e" in built:
        built["w"] = hflip(built["e"], cell)
    for diag, card in (("ne", "e"), ("se", "e"), ("nw", "w"), ("sw", "w")):
        if card in built:
            built[diag] = built[card]
    for d in DIRS:
        if d not in built:
            built[d] = built["s"]     # dir_set south-fill parity

    for d, strip in built.items():
        strip.save(os.path.join(out_dir, f"{sprite}_walk_codex_{d}.png"))
    # QA sheet: one row per built direction
    order = [d for d in DIRS if d in built]
    qh = 130
    qa = Image.new("RGBA", (60 + NFRAMES * qh, len(order) * qh), (40, 40, 46, 255))
    dr = ImageDraw.Draw(qa)
    for r, d in enumerate(order):
        s = built[d]
        for i in range(NFRAMES):
            c = s.crop((i * cell, 0, (i + 1) * cell, cell)).resize((qh, qh), Image.LANCZOS)
            qa.alpha_composite(c, (60 + i * qh, r * qh))
        dr.text((6, r * qh + qh // 2), d, fill=(240, 240, 240, 255))
    qa.save(os.path.join(out_dir, "qa.png"))
    print(f"DONE {kind}: {len(order)}/8 dirs -> {out_dir}")
    if install:
        for d in DIRS:
            shutil.copy(os.path.join(out_dir, f"{sprite}_walk_codex_{d}.png"),
                        os.path.join(SPR, f"{sprite}_walk_codex_{d}.png"))
        print(f"  installed 8 walk_codex dir strips for {sprite}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
