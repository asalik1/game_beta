#!/usr/bin/env python
"""Rebuild every class sprite from source, then re-import in Godot.

    python tools/art/build_sprites.py        # writes into game/assets/sprites/
    # then: tools/Godot_..._console.exe --headless --path game --import

This is the exact recipe used to process the class sheets — it documents the
per-class SOURCE MAP and re-runs extract_sheet.py so the whole set is
reproducible. See README.md for the pipeline and the contrast rule behind the
source choice.

SOURCE MAP — pick the sheet that CONTRASTS the character:
  * LIGHT classes (paladin, mage, archer)  -> the navy ORIGINAL sheets
    Custom/<Class>.png. A dark bg keys a light figure cleanly (extract_sheet
    auto-keys it). Their (2) variants are the wrong art / lossy for them.
  * DARK classes (assassin, warlock, warrior) -> the pre-keyed transparent
    Custom/<Class> (2).png. On a navy bg a colour-key would eat ~half the
    figure (assassin ~53%, warlock ~46%) — so they ship pre-keyed instead.
  * Assassin STAB/THROW directional -> restored from the committed backup
    art_src/heroes_clips/ (padded seam-fill re-applied). The Heroes source
    sheets it came from no longer exist, so the extracted strips ARE the master.

Source sheets live in the asset library, NOT the repo. Point at them with
CROWNLESS_ART_SRC (defaults to the maintainer's OneDrive path).
"""
import os, sys, subprocess, tempfile, shutil, glob
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SRC  = os.environ.get("CROWNLESS_ART_SRC", r"C:/Users/asali/OneDrive/Assets/Custom")
DEST = os.path.join(REPO, "game", "assets", "sprites")
BACKUP = os.path.join(REPO, "art_src", "heroes_clips")
EXTRACT = os.path.join(HERE, "extract_sheet.py")

# class -> (source sheet, --names per row, extra flags). Order of --names must
# match the sheet's rows top-to-bottom. --drop cuts FX-only frames (a projectile
# with no character); --keepall keeps frame 0 on label-free sheets.
JOBS = {
    # NOTE: the three DARK classes (assassin, warlock, warrior) are NOT built
    # here -- they come from the ChatGPT upscales via tools/art/upscale_hero.py.
    # Left out of JOBS so a rebuild can't clobber the upscaled sprites. Only the
    # LIGHT classes below still extract from the navy ORIGINAL sheets (auto bg-key).
    "archer":   ("Archer.png",  "idle,walk,run,cast,attack,attack2,dash,death", ["--drop", "attack2:3", "--key", "30"]),  # tighter key spares the dark boot soles the default 45 ate
    "mage":     ("Mage.png",    "idle,walk,run,cast,attack,attack2,dash,death", ["--drop", "attack2:3,attack2:4"]),
    "paladin":  ("Paladin.png", "idle,walk,run,attack2,attack,dash,death", []),
}

# Classes whose idle loop is trimmed to a subset of <class>_anim.png frames
# (parts of the extracted loop read worse than a shorter cut). value = the list
# of frame indices to keep, in order. A single index == a frozen static idle.
IDLE_KEEP = {
    "archer":   [3],           # freeze to the upright, bow-forward resting stance
}


def _install(out_dir):
    n = 0
    for f in glob.glob(os.path.join(out_dir, "*.png")):
        b = os.path.basename(f)
        if "_row" in b or "_QA" in b:
            continue
        shutil.copy(f, os.path.join(DEST, b)); n += 1
    return n


def _seam_fill_inplace(path):
    """Padded morphological closing + nearest-colour fill, per frame — the same
    seam/hole fix extract_sheet applies, for strips we only have pre-extracted
    (the assassin directional). Padding keeps the erosion off the cell edge."""
    im = np.asarray(Image.open(path).convert("RGBA")).copy()
    s = im.shape[0]; nf = im.shape[1] // s
    for i in range(nf):
        cell = im[:, i*s:(i+1)*s]; a = cell[:, :, 3] > 0
        P = 3
        closed = ndimage.binary_closing(np.pad(a, P), iterations=2)[P:-P, P:-P]
        need = closed & ~a
        if need.any():
            iy, ix = ndimage.distance_transform_edt(~a, return_distances=False, return_indices=True)
            cell[need] = cell[iy[need], ix[need]]
        cell[:, :, 3] = np.where(closed, 255, 0).astype(np.uint8)
        im[:, i*s:(i+1)*s] = cell
    Image.fromarray(im, "RGBA").save(path)


def _trim_idle(path, keep):
    """Rebuild a horizontal <class>_anim.png strip from the `keep` frame indices,
    in order. art._strip_info sets frames = width/height, so the trimmed strip
    plays exactly those cells (a single index == a frozen static idle)."""
    im = Image.open(path).convert("RGBA")
    s = im.height
    out = Image.new("RGBA", (s * len(keep), s))
    for j, f in enumerate(keep):
        out.paste(im.crop((f * s, 0, (f + 1) * s, s)), (j * s, 0))
    out.save(path)


def main():
    if not os.path.isdir(SRC):
        sys.exit("source dir not found: %s  (set CROWNLESS_ART_SRC)" % SRC)
    for cls, (sheet, names, extra) in JOBS.items():
        inp = os.path.join(SRC, sheet)
        out = tempfile.mkdtemp()
        subprocess.check_call([sys.executable, EXTRACT, "--in", inp, "--out", out,
                               "--class", cls, "--names", names] + extra)
        print("%-9s %d clips  <- %s" % (cls, _install(out), sheet))
        shutil.rmtree(out, ignore_errors=True)
        if cls in IDLE_KEEP:
            _trim_idle(os.path.join(DEST, cls + "_anim.png"), IDLE_KEEP[cls])
            print("%-9s idle kept frames %s" % (cls, IDLE_KEEP[cls]))
    # The assassin (body + directional) is built by upscale_assassin.py, not
    # here -- see the NOTE in JOBS. _seam_fill_inplace still lives in this module
    # because that tool imports it.
    print("\nDone. Re-import:  tools/Godot_*_console.exe --headless --path game --import")


if __name__ == "__main__":
    main()
