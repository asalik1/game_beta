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
EMBERFALL_ART_SRC (defaults to the maintainer's OneDrive path).
"""
import os, sys, subprocess, tempfile, shutil, glob
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SRC  = os.environ.get("EMBERFALL_ART_SRC", r"C:/Users/asali/OneDrive/Assets/Custom")
DEST = os.path.join(REPO, "game", "assets", "sprites")
BACKUP = os.path.join(REPO, "art_src", "heroes_clips")
EXTRACT = os.path.join(HERE, "extract_sheet.py")

# class -> (source sheet, --names per row, extra flags). Order of --names must
# match the sheet's rows top-to-bottom. --drop cuts FX-only frames (a projectile
# with no character); --keepall keeps frame 0 on label-free sheets.
JOBS = {
    # DARK -> pre-keyed (2) sheets
    "warrior":  ("Warrior (2).png",  "idle,walk,run,attack,attack2,dash,ultidle,ult,death", []),
    "assassin": ("Assassin (2).png", "idle,walk,run,attack,attack2,dash,death", []),
    "warlock":  ("Warlock (2).png",  "idle,walk,run,cast,attack,ult,attack2,death", ["--keepall"]),
    # LIGHT -> navy ORIGINAL sheets (auto bg-key)
    "archer":   ("Archer.png",  "idle,walk,run,cast,attack,attack2,dash,death", ["--drop", "attack2:3", "--key", "30"]),  # tighter key spares the dark boot soles the default 45 ate
    "mage":     ("Mage.png",    "idle,walk,run,cast,attack,attack2,dash,death", ["--drop", "attack2:3,attack2:4"]),
    "paladin":  ("Paladin.png", "idle,walk,run,attack2,attack,dash,death", []),
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


def main():
    if not os.path.isdir(SRC):
        sys.exit("source dir not found: %s  (set EMBERFALL_ART_SRC)" % SRC)
    for cls, (sheet, names, extra) in JOBS.items():
        inp = os.path.join(SRC, sheet)
        out = tempfile.mkdtemp()
        subprocess.check_call([sys.executable, EXTRACT, "--in", inp, "--out", out,
                               "--class", cls, "--names", names] + extra)
        print("%-9s %d clips  <- %s" % (cls, _install(out), sheet))
        shutil.rmtree(out, ignore_errors=True)
    # Assassin directional: source gone -> restore the backup + re-seam-fill.
    for name in ("assassin_stab_dir", "assassin_throw_dir"):
        dst = os.path.join(DEST, name + ".png")
        shutil.copy(os.path.join(BACKUP, name + ".png"), dst)
        _seam_fill_inplace(dst)
        print("%-9s <- backup (art_src/heroes_clips)" % name)
    print("\nDone. Re-import:  tools/Godot_*_console.exe --headless --path game --import")


if __name__ == "__main__":
    main()
