#!/usr/bin/env python
"""NPC roster RE-MASTER lane (2026-09-05): bring an under-2x NPC body up to the roster
recipe (256x256 canvas, 223 px body, feet on row 237, centred) with per-facing Codex
re-masters anchored to the CURRENT still -- the elder / caged_beastkin recipe of
2026-08-25 (art_src/fidelity_2026-08-25/npc8_stages) as a tool.

Two phases, because every other facing is matched to the remastered SOUTH:

  python tools/art/npc_remaster.py stage <root> --south merchant,onna
      one stage per name: refs = the current south still (pose/identity) + elder_anim_s
      (the roster's detail level); result <root>/<name>_s/<name>_s_master.png
  python tools/art/npc_remaster.py install <root> --south merchant,onna
      writes <name>_anim_s.png (+ <name>.png / <name>_anim.png flat copies when they
      exist as south copies today) at the roster geometry; backups in art_src/_backups
  python tools/art/npc_remaster.py stage <root> --facings merchant
      seven stages (se e ne n nw w sw): refs = the current facing still + the NEW south
  python tools/art/npc_remaster.py install <root> --facings merchant

A name with only a flat <name>_anim.png (onna) is treated as south-only; its flat strip
becomes the single remastered still (the NPC path normalises by alpha height, so a
1-frame 256 canvas renders exactly like the old 2-frame 160 one, only sharper).
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
BACK = ROOT / "art_src" / "_backups" / "npc_remaster_2026-09-05"
CANVAS, BODY, FEET, CX = 256, 223, 237, 128
STYLE_REF = "elder_anim_s"   # the roster recipe's finished sibling
DIRS7 = ["se", "e", "ne", "n", "nw", "w", "sw"]
FACING_WORDS = {"s": "SOUTH (facing the camera)", "se": "SOUTH-EAST (three-quarter, facing down-right)",
                "e": "EAST (profile, facing right)", "ne": "NORTH-EAST (three-quarter, facing up-right, back mostly to camera)",
                "n": "NORTH (back to the camera)", "nw": "NORTH-WEST (three-quarter, facing up-left, back mostly to camera)",
                "w": "WEST (profile, facing left)", "sw": "SOUTH-WEST (three-quarter, facing down-left)"}

BRIEF = """Repaint an EXISTING game NPC's {facing} facing at high resolution.
This is a FIDELITY UPGRADE, not a redesign.

Reference image 1 is the CURRENT in-game {facing} still (upscaled): the authority for the
POSE, FACING and design -- reproduce this exact figure, same stance, same facing, same gear on
the same sides, same colours. Reference image 2 is {ref2_role}: match ITS painterly detail
level, rendering style and palette exactly.

Generate ONE image: the single figure, centered, filling most of the canvas, on a TRANSPARENT
background (real alpha). Painterly, soft-shaded, NO black outlines, muted palette, top-down
three-quarter game view, light from the top-left. NO text, NO ground patch, NO shadow blob.

Save the image to disk at the exact path {out} and stop. Then reply with one line: any way the
pose or gear differs from reference 1.
"""


def still(path: Path, frame: int = 0) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    c = im.height
    return im.crop((frame * c, 0, (frame + 1) * c, c))


def upscaled_ref(src: Image.Image, out: Path, target_h: int = 640) -> None:
    bb = src.getchannel("A").getbbox()
    f = src.crop(bb)
    s = target_h / f.height
    f = f.resize((max(1, int(f.width * s)), target_h), Image.LANCZOS)
    bg = Image.new("RGBA", (f.width + 64, f.height + 64), (0, 0, 0, 0))
    bg.alpha_composite(f, (32, 32))
    bg.save(out)


def south_source(name: str) -> Path:
    for k in (f"{name}_anim_s", f"{name}_anim", name):
        p = SPR / f"{k}.png"
        if p.exists():
            return p
    raise SystemExit(f"{name}: no south still")


def stage(root: Path, name: str, d: str, ref2: Path, ref2_role: str) -> Path:
    st = root / f"{name}_{d}"
    refs = st / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    src = south_source(name) if d == "s" else SPR / f"{name}_anim_{d}.png"
    upscaled_ref(still(src), refs / f"1_current_{d}.png")
    shutil.copy(ref2, refs / f"2_{ref2.stem}.png")
    out = (st / f"{name}_{d}_master.png").resolve()
    (st / "codex_brief.txt").write_text(BRIEF.format(facing=FACING_WORDS[d], ref2_role=ref2_role, out=out), encoding="utf-8")
    print("stage", st.name, "<-", src.name, "+", ref2.name)
    return st.resolve()


def key_alpha(im: Image.Image) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    green = (g > 180) & (r < 110) & (b < 110)
    if green.mean() > 0.05:        # a green-field export instead of real alpha
        a[green] = 0
    # rim despill: within the edge band, G may not exceed max(R,B)+6
    from scipy import ndimage
    al = a[:, :, 3] > 0
    rim = al & ~ndimage.binary_erosion(al, iterations=3)
    m = rim & (g > np.maximum(r, b) + 6)
    a[:, :, 1][m] = (np.maximum(r, b)[m] + 6).clip(0, 255).astype(np.uint8)
    return Image.fromarray(a)


def install_one(master: Path, dest_names: list[str]) -> None:
    im = key_alpha(Image.open(master))
    a = np.array(im)[:, :, 3] > 40
    ys, xs = np.nonzero(a)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    s = BODY / im.height
    im = im.resize((max(1, int(round(im.width * s))), BODY), Image.LANCZOS)
    if im.width > CANVAS - 8:
        s2 = (CANVAS - 8) / im.width
        im = im.resize((CANVAS - 8, max(1, int(round(im.height * s2)))), Image.LANCZOS)
    a = np.array(im)[:, :, 3] > 40
    cols = a.sum(axis=0)
    cx = (np.arange(im.width) * cols).sum() / max(1, cols.sum())
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(CX - cx)), FEET - im.height + 1))
    BACK.mkdir(parents=True, exist_ok=True)
    for dn in dest_names:
        dest = SPR / f"{dn}.png"
        if dest.exists() and not (BACK / dest.name).exists():
            shutil.copy2(dest, BACK / dest.name)
        tmp = dest.with_suffix(".tmp")
        out.save(tmp, "PNG")
        tmp.replace(dest)
        print(f"  wrote {dest.name} ({out.width}x{out.height}, body {im.height}, w {im.width})")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["stage", "install"])
    ap.add_argument("root")
    ap.add_argument("--south", default="", help="comma names: south masters (phase 1)")
    ap.add_argument("--facings", default="", help="comma names: the seven other facings (phase 2, needs the installed south)")
    args = ap.parse_args()
    root = Path(args.root)
    root.mkdir(parents=True, exist_ok=True)
    stages: list[Path] = []
    souths = [n for n in args.south.split(",") if n]
    facings = [n for n in args.facings.split(",") if n]
    if args.mode == "stage":
        for n in souths:
            stages.append(stage(root, n, "s", SPR / f"{STYLE_REF}.png", "a finished NPC of this game's roster at the target detail level"))
        for n in facings:
            south = SPR / f"{n}_anim_s.png"
            if not south.exists():
                raise SystemExit(f"{n}: install the south master first")
            for d in DIRS7:
                if (SPR / f"{n}_anim_{d}.png").exists():
                    stages.append(stage(root, n, d, south, "the SAME character's already-remastered SOUTH facing"))
        (root / "stages.txt").write_text("\n".join(str(s) for s in stages) + "\n", encoding="utf-8")
        print(len(stages), "stages ->", root / "stages.txt")
        return 0
    for n in souths:
        master = root / f"{n}_s" / f"{n}_s_master.png"
        if not master.exists():
            print(f"skip {n}: no south master yet")
            continue
        dests = [f"{n}_anim_s"] if (SPR / f"{n}_anim_s.png").exists() else []
        for flat in (f"{n}_anim", n):
            if (SPR / f"{flat}.png").exists():
                dests.append(flat)
        install_one(master, dests)
    for n in facings:
        for d in DIRS7:
            master = root / f"{n}_{d}" / f"{n}_{d}_master.png"
            if master.exists():
                install_one(master, [f"{n}_anim_{d}"])
            else:
                print(f"skip {n}_{d}: no master")
    return 0


if __name__ == "__main__":
    sys.exit(main())
