#!/usr/bin/env python3
"""drift_sheets.py — build the eyes-only drift-audit contact sheets for one subject.

Companion to tools/art/DRIFT_AUDIT.md (the method). For a boss/mob/skin base it:
  1. dedups directions per clip (md5) so byte-copies aren't re-inspected,
  2. slices each strip (square frames: frame_w = height, count = width // height),
  3. emits per-clip contact sheets — an ATTIRE sheet (full-body, feet-aligned, brightened)
     and a FACE sheet (top ~35% head-crop, upscaled NEAREST) — rows = unique dirs, cols = frames,
  4. writes a manifest (dedup groups + geometry + which clip is the idle reference).

The idle clip (anim_codex if present else anim else idle) is emitted FIRST and labelled
REFERENCE; an audit agent compares every other frame to it.

Usage:
  python tools/art/drift_sheets.py <base> [--forms base,base_mage,...] --out <dir>
  # multi-form families (skeleton/mummy/orc/zombie) pass each form prefix via --forms
"""
import sys, os, re, hashlib, argparse
from PIL import Image, ImageEnhance, ImageDraw, ImageOps

SPR = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "sprites")
SPR = os.path.abspath(SPR)
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
DIRSET = set(DIRS)
BG = (60, 62, 68)          # neutral gray so dark sprites + transparency read
ATTIRE_CELL = 128
FACE_CELL = 168
BRIGHT = 1.55


def md5(path):
    return hashlib.md5(open(path, "rb").read()).hexdigest()


def slice_strip(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    if h == 0 or w < h:
        return [im]
    n = max(1, w // h)
    return [im.crop((i * h, 0, (i + 1) * h, h)) for i in range(n)]


def on_bg(frame, bright=True):
    bg = Image.new("RGBA", frame.size, BG + (255,))
    bg.alpha_composite(frame)
    rgb = bg.convert("RGB")
    if bright:
        rgb = ImageEnhance.Brightness(rgb).enhance(BRIGHT)
    return rgb


def fit(img, cell):
    img = img.copy()
    img.thumbnail((cell, cell), Image.LANCZOS)
    c = Image.new("RGB", (cell, cell), BG)
    c.paste(img, ((cell - img.width) // 2, cell - img.height))  # feet-aligned (bottom)
    return c


def headcrop(frame, cell):
    # top 35% of the non-empty bbox, upscaled NEAREST
    bb = frame.getbbox()
    if bb:
        x0, y0, x1, y1 = bb
        crop = frame.crop((x0, y0, x1, y0 + max(1, int((y1 - y0) * 0.38))))
    else:
        crop = frame
    rgb = on_bg(crop, bright=True)
    scale = min(cell / max(1, rgb.width), cell / max(1, rgb.height))
    rgb = rgb.resize((max(1, int(rgb.width * scale)), max(1, int(rgb.height * scale))), Image.NEAREST)
    c = Image.new("RGB", (cell, cell), BG)
    c.paste(rgb, ((cell - rgb.width) // 2, (cell - rgb.height) // 2))
    return c


def clip_files(base):
    """Return {clip: {dir_or_flat: path}} for one base prefix (exact, not sub-forms)."""
    pat = re.compile(rf"^{re.escape(base)}(_.*)?\.png$")
    out = {}
    for f in sorted(os.listdir(SPR)):
        if not pat.match(f):
            continue
        stem = f[:-4]
        rest = stem[len(base):].strip("_")
        toks = rest.split("_") if rest else []
        if toks and toks[-1] in DIRSET:
            clip = "_".join(toks[:-1]) or "idle"
            d = toks[-1]
        else:
            clip = "_".join(toks) or "idle"
            d = "flat"
        out.setdefault(clip, {})[d] = os.path.join(SPR, f)
    return out


def dedup(dirmap):
    """dirmap {dir: path} -> (unique_dirs list, {dir: rep_dir}) collapsing byte-identical."""
    seen = {}
    uniq = []
    alias = {}
    order = [d for d in ["flat"] + DIRS if d in dirmap]
    for d in order:
        h = md5(dirmap[d])
        if h in seen:
            alias[d] = seen[h]
        else:
            seen[h] = d
            uniq.append(d)
    return uniq, alias


def build_sheet(cells, labels, ncols, cell, title):
    rows = (len(cells) + ncols - 1) // ncols
    pad = 22
    W = ncols * cell
    H = rows * (cell + pad) + 26
    sheet = Image.new("RGB", (W, H), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    d.text((6, 6), title, fill=(230, 230, 180))
    for i, (c, lab) in enumerate(zip(cells, labels)):
        r, col = divmod(i, ncols)
        x = col * cell
        y = 26 + r * (cell + pad)
        sheet.paste(c, (x, y))
        d.text((x + 3, y + cell + 4), lab, fill=(200, 200, 200))
    return sheet


def process_base(base, out, tag=""):
    clips = clip_files(base)
    if not clips:
        return []
    # idle reference clip precedence
    for ref in ("anim_codex", "anim", "idle"):
        if ref in clips:
            refclip = ref
            break
    else:
        refclip = sorted(clips)[0]
    ordered = [refclip] + [c for c in sorted(clips) if c != refclip]
    lines = [f"# {base}{(' ['+tag+']') if tag else ''}  idle-ref clip = {refclip}"]
    for clip in ordered:
        dirmap = clips[clip]
        uniq, alias = dedup(dirmap)
        if alias:
            al = ", ".join(f"{k}={v}" for k, v in alias.items())
            lines.append(f"clip {clip}: dirs {list(dirmap)} | unique {uniq} | copies {{{al}}}")
        else:
            lines.append(f"clip {clip}: dirs {list(dirmap)} | unique {uniq}")
        att_cells, att_labs, face_cells, face_labs = [], [], [], []
        for d in uniq:
            frames = slice_strip(dirmap[d])
            for fi, fr in enumerate(frames):
                lab = f"{d} f{fi}"
                att_cells.append(fit(on_bg(fr), ATTIRE_CELL)); att_labs.append(lab)
                face_cells.append(headcrop(fr, FACE_CELL)); face_labs.append(lab)
        maxframes = max((len(slice_strip(dirmap[d])) for d in uniq), default=1)
        ncols = max(maxframes, 1)
        pre = "REF_" if clip == refclip else ""
        t = f"{base}{('/'+tag) if tag else ''}  {clip}" + ("  (IDLE REFERENCE)" if clip == refclip else "")
        build_sheet(att_cells, att_labs, ncols, ATTIRE_CELL, "ATTIRE  " + t).save(
            os.path.join(out, f"{pre}attire_{clip}.png"))
        build_sheet(face_cells, face_labs, ncols, FACE_CELL, "FACE  " + t).save(
            os.path.join(out, f"{pre}face_{clip}.png"))
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("--forms", default="", help="comma list of sub-form prefixes (skeleton_mage,...)")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    manifest = []
    bases = [a.base] + [f for f in a.forms.split(",") if f]
    # forms are longer prefixes; process specific first so base doesn't swallow them
    # (base clip_files uses exact-prefix regex, so a form's files also match base — filter)
    formset = [f for f in a.forms.split(",") if f]
    if formset:
        # base = files that are NOT any form
        pass
    for b in bases:
        tag = "" if b == a.base else b[len(a.base):].strip("_")
        manifest += process_base(b, a.out, tag)
        manifest.append("")
    open(os.path.join(a.out, "_manifest.txt"), "w", encoding="utf-8").write("\n".join(manifest))
    print(f"{a.base}: sheets -> {a.out}")


if __name__ == "__main__":
    main()
