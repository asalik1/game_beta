#!/usr/bin/env python
"""Assemble an 8-direction action set for one Act-1 boss clip from generated
facing masters (owner 2026-08-15: attacks need a facing, not one south strip).

Scheme (owner's): generate S (front), N (back), E (right profile); this tool
builds each idle-aligned, MIRRORS E->W, and COPIES E->{ne,se}, W->{nw,sw}. N
stands alone (dir_set south-fills any facing we skip). Every strip is built to
align to the FRONT idle so size/ground stay put when the boss turns; the engine
picks the strip by facing at trigger via Art.dir_set + dir8_suffix_for.

Per-facing masters live at <dir_root>/<kind>/<clip>/<facing>/<clip>_master_2x2_v1_keyed.png
(a facing with no master is skipped; S falls back to the installed flat
<sprite>_<clip>.png so a no-projectile swing needn't be regenerated).

  python build_act1_dirset.py <kind> <clip> <dir_root> [--install]

Writes <dir_root>/<kind>/<clip>/out/<sprite>_<clip>_<dir>.png (all 8) + qa.png.
--install copies them into game/assets/sprites (then run --import + wire nothing:
the named-action dir_set lights up automatically).
"""
from __future__ import annotations
import os, subprocess, sys, shutil
from PIL import Image

REPO = r"C:\Users\asali\Projects\MMO"
SPR = os.path.join(REPO, "game", "assets", "sprites")
BUILD = os.path.join(REPO, "tools", "art", "build_codex_2x2_strip.py")
sys.path.insert(0, os.path.join(REPO, "tools", "art"))
from act1_brief_lib import BOSSES  # noqa: E402

DIRS = ["s", "n", "e", "w", "ne", "nw", "se", "sw"]


def build_facing(master: str, out: str, ref_idle: str, anchor: str = "bbox") -> bool:
    # WALK uses the head-band anchor: a walk's bbox shifts as the legs extend, so
    # centering the bbox would slide the body sideways each frame — the head/torso
    # is the stable landmark to pin instead. Aimed clips keep the body-mass bbox.
    r = subprocess.run([sys.executable, BUILD, master, "--out", out,
                        "--ref-idle", ref_idle, "--anchor", anchor,
                        "--scale-ref", "body", "--scale-frame", "1", "--valign", "hem"],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        print(f"  build FAIL {os.path.basename(out)}: {r.stdout.strip()[-200:]} {r.stderr.strip()[-200:]}")
        return False
    return True


def hflip_strip(src: str, dst: str) -> None:
    """Mirror each square cell in place (preserve frame order)."""
    im = Image.open(src).convert("RGBA")
    h = im.height
    n = im.width // h
    out = Image.new("RGBA", im.size)
    for i in range(n):
        cell = im.crop((i * h, 0, (i + 1) * h, h)).transpose(Image.FLIP_LEFT_RIGHT)
        out.paste(cell, (i * h, 0))
    out.save(dst)


def main() -> int:
    kind, clip, root = sys.argv[1], sys.argv[2], sys.argv[3]
    rest = sys.argv[4:]
    install = "--install" in rest
    # --outclip <name>: masters still read from the <clip> path, but the built +
    # installed files use <outclip> (walk -> walk_codex, keeping the legacy
    # <sprite>_walk namespace free).
    outclip = clip
    if "--outclip" in rest:
        outclip = rest[rest.index("--outclip") + 1]
    anchor = "head" if clip == "walk" else "bbox"
    if "--anchor" in rest:
        anchor = rest[rest.index("--anchor") + 1]
    sprite = BOSSES[kind][0]
    ref_idle = os.path.join(SPR, f"{sprite}_anim_codex.png")
    if not os.path.exists(ref_idle):
        ref_idle = os.path.join(SPR, f"{sprite}_anim.png")
    base = os.path.join(root, kind, clip)
    out_dir = os.path.join(base, "out")
    os.makedirs(out_dir, exist_ok=True)
    built: dict[str, str] = {}

    # S / N / E from generated masters; S falls back to the installed flat strip.
    for f in ("s", "n", "e"):
        master = os.path.join(base, f, f"{clip}_master_2x2_v1_keyed.png")
        dst = os.path.join(out_dir, f"{sprite}_{outclip}_{f}.png")
        if os.path.exists(master):
            if build_facing(master, dst, ref_idle, anchor):
                built[f] = dst
        elif f == "s":
            flat = os.path.join(SPR, f"{sprite}_{clip}.png")
            if os.path.exists(flat):
                shutil.copy(flat, dst)
                built["s"] = dst
                print(f"  s: reused installed {sprite}_{clip}.png (no-projectile swing)")
    if "s" not in built:
        print(f"FAIL {kind}/{clip}: no S facing (need a master or an installed flat strip)")
        return 2

    # W = mirror(E); diagonals copy the cardinal.
    if "e" in built:
        w = os.path.join(out_dir, f"{sprite}_{outclip}_w.png")
        hflip_strip(built["e"], w)
        built["w"] = w
    for diag, card in (("ne", "e"), ("se", "e"), ("nw", "w"), ("sw", "w")):
        if card in built:
            d = os.path.join(out_dir, f"{sprite}_{outclip}_{diag}.png")
            shutil.copy(built[card], d)
            built[diag] = d

    # QA sheet: one row per built direction, frames left->right.
    order = [d for d in DIRS if d in built]
    cells = []
    for d in order:
        im = Image.open(built[d]).convert("RGBA")
        cells.append((d, im))
    if cells:
        cellh = 150
        maxn = max(im.width // im.height for _, im in cells)
        sheet = Image.new("RGBA", (60 + maxn * cellh, len(cells) * cellh), (40, 40, 46, 255))
        from PIL import ImageDraw
        dr = ImageDraw.Draw(sheet)
        for r, (d, im) in enumerate(cells):
            h = im.height
            n = im.width // h
            for i in range(n):
                c = im.crop((i * h, 0, (i + 1) * h, h)).resize((cellh, cellh), Image.LANCZOS)
                sheet.alpha_composite(c, (60 + i * cellh, r * cellh))
            dr.text((6, r * cellh + cellh // 2), d, fill=(240, 240, 240, 255))
        sheet.save(os.path.join(out_dir, "qa.png"))

    print(f"DONE {kind}/{clip}: built {len(built)}/8 dirs [{','.join(order)}]")

    if install:
        for d in order:
            shutil.copy(built[d], os.path.join(SPR, f"{sprite}_{outclip}_{d}.png"))
        print(f"  installed {len(order)} dir strips -> game/assets/sprites for {sprite}_{clip}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
