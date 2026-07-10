"""install_dirset — assemble PixelLab per-direction exports into the
<base>_<dir>.png strips the 8-direction render path (art.gd dir_set) reads.

PixelLab gives, per character:
  - create_character   -> 8 static rotation stills (south/east/north/...),
                          already feet-anchored in a fixed square canvas.
  - animate_character  -> one animation per direction (K frames each).

This trims the shared padding (union bbox across ALL frames of ALL
directions, so the feet stay aligned and the character neither bobs nor
resizes when it turns), pads to one common square cell, lays each
direction's frames into a horizontal strip, and writes:
  - <base>_<dir>.png   (K-frame strip per direction; K=1 for static idle)
  - <base>.png         (flat SOUTH copy: setup + the net-mirror path need
                        a plain strip, and dir_set's anchor is the south file)

`base` is the render-path base: enemy idle = "<sprite>_anim", walk =
"<sprite>_walk"; hero = "<class>_<clipfile>" (anim/walk/run/attack/...).

CLI:  python install_dirset.py <rotations_dir> <base> [out_dir] [margin]
      (rotations_dir holds rot_<dir>.png or <dir>.png stills)
"""
import os, sys
from PIL import Image

# PixelLab rotation name -> DIR8 suffix. South = facing the camera (down).
ROT_MAP = {
    "south": "s", "south-east": "se", "east": "e", "north-east": "ne",
    "north": "n", "north-west": "nw", "west": "w", "south-west": "sw",
    "s": "s", "se": "se", "e": "e", "ne": "ne",
    "n": "n", "nw": "nw", "w": "w", "sw": "sw",
}
DIR8 = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


def _union_bbox(images):
    boxes = [im.getbbox() for im in images if im.getbbox() is not None]
    if not boxes:
        w, h = images[0].size
        return (0, 0, w, h)
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def _cell(fw, fh, margin):
    return max(fw, fh) + margin * 2


def _place(fig, cell, fw, fh, margin):
    """Bottom-center anchor a union-cropped figure into a square cell."""
    c = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    c.alpha_composite(fig, ((cell - fw) // 2, cell - fh - margin))
    return c


def assemble(dir_frames, base, out_dir, margin=3):
    """dir_frames: {suffix: [PIL frames]} (1 frame = static). Writes the
    eight <base>_<dir>.png strips + flat <base>.png. Returns the cell px."""
    all_frames = [f for frames in dir_frames.values() for f in frames]
    ux0, uy0, ux1, uy1 = _union_bbox([f.convert("RGBA") for f in all_frames])
    fw, fh = ux1 - ux0, uy1 - uy0
    cell = _cell(fw, fh, margin)
    os.makedirs(out_dir, exist_ok=True)
    for suf in DIR8:
        frames = dir_frames.get(suf) or dir_frames["s"]  # missing side -> south
        cells = []
        for im in frames:
            fig = im.convert("RGBA").crop((ux0, uy0, ux1, uy1))
            cells.append(_place(fig, cell, fw, fh, margin))
        strip = Image.new("RGBA", (cell * len(cells), cell), (0, 0, 0, 0))
        for i, c in enumerate(cells):
            strip.alpha_composite(c, (i * cell, 0))
        strip.save(os.path.join(out_dir, "%s_%s.png" % (base, suf)))
    # flat south copy for setup / net mirror
    Image.open(os.path.join(out_dir, "%s_s.png" % base)).save(
        os.path.join(out_dir, "%s.png" % base))
    return cell


def _load_rotations(rot_dir):
    """rot_<dir>.png or <dir>.png stills -> {suffix: [single frame]}."""
    out = {}
    for f in os.listdir(rot_dir):
        if not f.endswith(".png"):
            continue
        stem = f[:-4]
        if stem.startswith("rot_"):
            stem = stem[4:]
        suf = ROT_MAP.get(stem)
        if suf:
            out[suf] = [Image.open(os.path.join(rot_dir, f))]
    return out


def install_static(rot_dir, base, out_dir, margin=3):
    frames = _load_rotations(rot_dir)
    if "s" not in frames:
        raise SystemExit("no south rotation found in " + rot_dir)
    cell = assemble(frames, base, out_dir, margin)
    print("installed %d-dir set '%s_*' cell=%dpx -> %s" %
          (len(frames), base, cell, out_dir))
    return cell


if __name__ == "__main__":
    rot_dir = sys.argv[1]
    base = sys.argv[2]
    out_dir = sys.argv[3] if len(sys.argv) > 3 else \
        r"C:\Users\asali\Projects\MMO\game\assets\sprites"
    margin = int(sys.argv[4]) if len(sys.argv) > 4 else 3
    install_static(rot_dir, base, out_dir, margin)
