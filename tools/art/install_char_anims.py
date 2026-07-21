"""install_char_anims — turn a PixelLab character download zip into the
8-direction hero clip strips the render path reads.

PixelLab zip layout:
  <Name>/rotations/<pixellab_dir>.png
  <Name>/animations/<anim_folder>/<pixellab_dir>/frame_NNN.png

We map each anim_folder to a render clip base (HERO_CLIP_FILES suffix),
read the 5 generated directions (south/south-east/east/north-east/north),
and hand them to install_dirset.assemble_clips with symmetric=True — which
computes ONE shared square cell across every clip and mirrors the east half
onto the missing west half. Output: assets/sprites/<art>_<clip>_<dir>.png
(+ flat) for every clip, all the same cell so the hero never resizes when
it switches clip. Also refreshes the flat <art>.png static from south.

Usage: python install_char_anims.py <zip> <art_name> [out_dir]
"""
import os, sys, zipfile, tempfile, shutil
from PIL import Image
import install_dirset as ids

# PixelLab animation folder -> render clip base (art.gd HERO_CLIP_FILES value).
# Template anims land under their engine name (breathing-idle -> "animating",
# walk -> "walking", running-6-frames -> "running"); v3 customs keep the
# animation_name we passed (attack/attack2/dash/ult/ultidle).
NAME_MAP = {
    "animating": "anim", "breathing-idle": "anim", "idle": "anim", "hover": "anim",
    "walking": "walk", "walk": "walk",
    "running": "run", "run": "run",
    "dash": "dash", "dodge_roll": "dash",
    "attack": "attack", "bow_shot": "attack",
    # A PixelLab re-fire can rename an existing group to the latest custom
    # action description instead of preserving its requested animation_name.
    # This mage group is still the runtime's basic attack.
    "a_clean_down-left_staff_jab_while_facing_down-left": "attack",
    "attack2": "attack2", "bow_bash": "attack2",
    "cast": "cast", "channel_cast": "cast",
    "ult": "ult", "ultidle": "ultidle",
    "death": "death", "falling_backward": "death",
}
# render suffix -> PixelLab direction folder name. All 8 so asymmetric
# characters (weapon on one hand) install their REAL west-half art; the
# symmetric mirror path only fires for the missing sides (5-dir symmetric gens).
DIR_NAME = {"s": "south", "se": "south-east", "e": "east",
            "ne": "north-east", "n": "north",
            "nw": "north-west", "w": "west", "sw": "south-west"}


def _frames(folder):
    fs = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    return [Image.open(os.path.join(folder, f)).convert("RGBA") for f in fs]


def install(zip_path, art, out_dir, symmetric=True):
    tmp = tempfile.mkdtemp(prefix="pxl_")
    try:
        with zipfile.ZipFile(zip_path) as z:
            z.extractall(tmp)
        root = next(os.path.join(tmp, d) for d in os.listdir(tmp)
                    if os.path.isdir(os.path.join(tmp, d)))
        anim_root = os.path.join(root, "animations")
        # Accumulate per clip, MERGING split folders: a single-direction
        # re-fire lands under "<clip>-<hash>" (e.g. ult-f7021451) — fold its
        # direction back into the base clip so a repaired direction counts.
        merged = {}  # clip -> {suffix: [frames]}
        for folder in sorted(os.listdir(anim_root)):
            is_repair = folder not in NAME_MAP  # "<clip>-<hash>" single-dir re-fire
            clip = NAME_MAP.get(folder)
            if clip is None and "-" in folder:
                clip = NAME_MAP.get(folder.rsplit("-", 1)[0])
            if clip is None:
                print("  ? unmapped animation folder:", folder); continue
            df = merged.setdefault(clip, {})
            for suf, dname in DIR_NAME.items():
                d = os.path.join(anim_root, folder, dname)
                # Repeated single-direction re-fires can export sibling
                # directories such as "south-west-02856b1b" inside the same
                # animation folder. Prefer a repair directory when the plain
                # direction is absent so the repaired facing is not dropped.
                if not os.path.isdir(d):
                    repairs = sorted(
                        n for n in os.listdir(os.path.join(anim_root, folder))
                        if n.startswith(dname + "-") and
                        os.path.isdir(os.path.join(anim_root, folder, n)))
                    if repairs:
                        d = os.path.join(anim_root, folder, repairs[0])
                # A repair folder ALWAYS wins (it re-rolled a bad direction);
                # a base folder only fills a direction not already present.
                if os.path.isdir(d) and (is_repair or suf not in df):
                    df[suf] = _frames(d)
        clips = {}
        for clip, df in merged.items():
            if "s" not in df:
                print("  ! %s missing SOUTH — skipped" % clip); continue
            clips["%s_%s" % (art, clip)] = df
            print("  + %-8s dirs=%s frames=%d"
                  % (clip, "".join(sorted(df)), len(df["s"])))
        cell = ids.assemble_clips(clips, out_dir, symmetric=symmetric)
        # refresh the flat static from the south rotation (class-select / codex)
        south = os.path.join(root, "rotations", "south.png")
        if os.path.exists(south):
            Image.open(south).convert("RGBA").save(os.path.join(out_dir, "%s.png" % art))
        print("installed %d clips, shared cell=%dpx -> %s" % (len(clips), cell, out_dir))
        return cell
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    zip_path = sys.argv[1]
    art = sys.argv[2]
    out_dir = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith("-") else \
        r"C:\Users\asali\Projects\MMO\game\assets\sprites"
    # pass "all8" (or --all8) for asymmetric chars that generated all 8 dirs
    symmetric = not any(a.lstrip("-") == "all8" for a in sys.argv[3:])
    install(zip_path, art, out_dir, symmetric=symmetric)
