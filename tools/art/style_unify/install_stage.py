"""Install vetted prop regens from a stage root: render widths from
<stage_root>/render_w.csv (name,width), tone-match recipe (-14% saturation,
gamma 1.0, install_prop_hires.ensure_alpha key + despill). Writes game + mobile
mirrors, backs the replaced asset up beside the result (_backup_<name>.png).
Animated props are installed too — run derive_stage.py right after so their
_anim strips are rebuilt from the new static (autotest's four-frame contract
wants frame == static canvas).

  python install_stage.py <stage_root> [name ...]
"""
import os, shutil, sys
from PIL import Image, ImageEnhance

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import REPO, TOOLS_ART  # noqa: E402
sys.path.insert(0, TOOLS_ART)
import install_prop_hires as iph  # noqa: E402

# props whose translucent parts soak up the green key: neutralise fully
DESAT_FULL = {"web"}


def main():
    stage_dir = sys.argv[1]
    only = set(sys.argv[2:])
    rw = {}
    for line in open(os.path.join(stage_dir, "render_w.csv")):
        if "," in line:
            n, w = line.strip().split(",")
            rw[n] = float(w)
    done, missing = [], []
    for name, w in rw.items():
        if only and name not in only:
            continue
        src = os.path.join(stage_dir, name, name + ".png")
        if not os.path.exists(src):
            missing.append(name)
            continue
        cur = os.path.join(iph.GAME, name + ".png")
        if os.path.exists(cur):
            shutil.copy(cur, os.path.join(stage_dir, name, "_backup_" + name + ".png"))
        im = iph.ensure_alpha(Image.open(src).convert("RGBA"))
        rgb = ImageEnhance.Color(im.convert("RGB")).enhance(0.0 if name in DESAT_FULL else 0.86)
        toned = Image.merge("RGBA", (*rgb.split(), im.getchannel("A")))
        tmp = os.path.join(stage_dir, name, "_toned_" + name + ".png")
        toned.save(tmp)
        for p, sz in iph.install(name, tmp, w, g=1.0):
            print("wrote %s  %dx%d" % (os.path.relpath(p, REPO), sz[0], sz[1]))
        done.append(name)
    print("installed:", len(done), done)
    print("missing:", len(missing), missing)


if __name__ == "__main__":
    main()
