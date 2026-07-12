"""install_ability — add a boss's "<key>_ability" one-shot strip in the SAME
shared square cell as its already-installed idle/walk (so scale_for doesn't
resize the body mid-swing). Pulls the ability frames straight from PixelLab
frame URLs (the zip export drops per-direction v3 animations), re-derives the
global union cell across idle+walk+ability, and rewrites idle/walk ONLY if the
swing pose is taller than the current cell.

Usage:
  python install_ability.py <key> <char_id> <framecount> s=<anim_id> se=<anim_id> \
      e=<id> ne=<id> n=<id> nw=<id> w=<id> sw=<id>
Any direction omitted (failed gen) is mirror-filled from its L/R opposite.
"""
import io, os, sys, urllib.request
from PIL import Image

SPR = r"C:\Users\asali\Projects\MMO\game\assets\sprites"
ACCT = "6e3973a7-b8ae-415c-b68f-db1337770a95"
UA = {"User-Agent": "Mozilla/5.0"}
DIR8 = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
MARGIN = 3
MIRROR = {"w": "e", "sw": "se", "nw": "ne", "e": "w", "se": "sw", "ne": "nw"}


def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    return Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=60).read())).convert("RGBA")


def ability_frames(char_id, anim_id, dname, count):
    base = ("https://backblaze.pixellab.ai/file/pixellab-characters/%s/%s/animations/%s/%s/"
            % (ACCT, char_id, anim_id, dname))
    frames = []
    for i in range(count + 2):  # keep_first_frame -> count+1; try one extra, stop at 404
        try:
            frames.append(fetch(base + "%d.png" % i))
        except Exception:
            break
    return frames


def split_strip(path):
    """An installed <base>_<dir>.png strip -> list of per-frame cell images."""
    im = Image.open(path).convert("RGBA")
    cell = im.height
    n = max(1, im.width // cell)
    return [im.crop((k * cell, 0, (k + 1) * cell, cell)) for k in range(n)]


def content_bbox(imgs):
    boxes = [im.getbbox() for im in imgs if im.getbbox()]
    if not boxes:
        return (0, 0, imgs[0].width, imgs[0].height)
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def place(fig, cell):
    fw, fh = fig.size
    c = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    c.alpha_composite(fig, ((cell - fw) // 2, cell - fh - MARGIN))
    return c


def write_strip(base, suf, frames, cell, bbox):
    x0, y0, x1, y1 = bbox
    cells = [place(f.crop((x0, y0, x1, y1)), cell) for f in frames]
    strip = Image.new("RGBA", (cell * len(cells), cell), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        strip.alpha_composite(c, (i * cell, 0))
    strip.save(os.path.join(SPR, "%s_%s.png" % (base, suf)))


def main():
    key = sys.argv[1]
    char_id = sys.argv[2]
    count = int(sys.argv[3])
    dirmap = {}
    for a in sys.argv[4:]:
        d, aid = a.split("=", 1)
        dirmap[d] = aid
    dname = {"s": "south", "se": "south-east", "e": "east", "ne": "north-east",
             "n": "north", "nw": "north-west", "w": "west", "sw": "south-west"}

    # 1. ability frames per dir (mirror-fill missing)
    abil = {}
    for d in DIR8:
        if d in dirmap:
            fr = ability_frames(char_id, dirmap[d], dname[d], count)
            if fr:
                abil[d] = fr
    for d in DIR8:
        mp = MIRROR.get(d)
        if d not in abil and mp and mp in abil:
            abil[d] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in abil[mp]]
    if "s" not in abil:
        raise SystemExit("no SOUTH ability frames for %s" % key)

    # 2. The boss's idle strip defines the cell; the ability CONFORMS to it —
    #    never grow it (growing would shrink the whole boss, whose scale stat
    #    was tuned to this cell). A pose taller than the cell clips at the top
    #    (a raised weapon tip), feet stay anchored, body size stays constant.
    idle_s = os.path.join(SPR, "%s_anim_s.png" % key)
    if not os.path.exists(idle_s):
        raise SystemExit("%s has no installed idle (_anim_s) to size against" % key)
    cell = Image.open(idle_s).height

    # 3. per-direction ability bbox = that direction's own frames (keeps the
    #    swing centered per facing), placed bottom-center in the fixed cell.
    for d in DIR8:
        frames = abil.get(d) or abil["s"]
        bx = content_bbox(frames)
        write_strip("%s_ability" % key, d, frames, cell, bx)
    Image.open(os.path.join(SPR, "%s_ability_s.png" % key)).save(
        os.path.join(SPR, "%s_ability.png" % key))
    print("%s ability installed: dirs=%s cell=%d (fixed to idle)"
          % (key, "".join(sorted(abil)), cell))


if __name__ == "__main__":
    main()
