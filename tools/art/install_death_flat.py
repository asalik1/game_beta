"""install_death_flat — assemble a v3 grounded-death animation (SOUTH only)
into the FLAT single-facing strip the death beat reads.

Unlike install_char_anims (8-direction sets + auto-computed shared cell), the
death beat for every base class is FLAT: play_death_anim -> _play_clip("death")
draws _clips["death"] = <class>_death.png at the IDLE scale/offset, and the
render flips L/R to match the facing you died in (owner call 2026-07-17: a
plain death, no 8-dir, archer included).

Because the render measures scale/offset off IDLE only (player_core
_measure_hero_frame), the death cell MUST equal the class's locomotion cell —
otherwise the corpse scales or floats. So we FORCE the cell instead of
computing it: crop each frame to the shared death union-bbox, bottom-center
anchor into the given square cell (same _place path as install_dirset, margin
3), lay the frames into one horizontal strip, and write <art>_death.png.

Usage: python install_death_flat.py <frames_dir> <art> <cell> [out_dir]
       (frames_dir holds the SOUTH death frames, sorted by name = frame order)
"""
import os, sys
from PIL import Image
import install_dirset as ids


def _frames(folder):
    fs = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    return [Image.open(os.path.join(folder, f)).convert("RGBA") for f in fs]


def install(frames_dir, art, cell, out_dir, margin=3):
    frames = _frames(frames_dir)
    if not frames:
        raise SystemExit("no frames in " + frames_dir)
    ux0, uy0, ux1, uy1 = ids._union_bbox(frames)
    fw, fh = ux1 - ux0, uy1 - uy0
    if fw > cell or fh > cell:
        print("  ! WARNING %s death content %dx%d exceeds cell %d — clipping"
              % (art, fw, fh, cell))
    cells = []
    for im in frames:
        fig = im.crop((ux0, uy0, ux1, uy1))
        cells.append(ids._place(fig, cell, fw, fh, margin))
    strip = Image.new("RGBA", (cell * len(cells), cell), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        strip.alpha_composite(c, (i * cell, 0))
    out = os.path.join(out_dir, "%s_death.png" % art)
    strip.save(out)
    print("  + %s_death  frames=%d  cell=%dpx  content=%dx%d -> %s"
          % (art, len(frames), cell, fw, fh, out))
    return len(frames)


if __name__ == "__main__":
    frames_dir = sys.argv[1]
    art = sys.argv[2]
    cell = int(sys.argv[3])
    out_dir = sys.argv[4] if len(sys.argv) > 4 else \
        r"C:\Users\asali\Projects\MMO\game\assets\sprites"
    install(frames_dir, art, cell, out_dir)
