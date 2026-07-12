"""skin_install — turn a PixelLab character's 8 rotation stills into a static
8-direction skin sprite (<name>_anim*.png) at base-class-comparable res.

Downloads the character's rotation stills from backblaze (curl, throttle-safe),
then hands them to install_dirset.install_static which feet-anchors + squares
them into <base>_<dir>.png strips + a flat <base>.png, matching the render path.

Usage: python skin_install.py <char_id> <base> <out_dir>
  <base>   e.g. warrior_stormforged_anim
  <out_dir> e.g. game/assets/sprites/skins/mythic
"""
import io, os, sys, subprocess, tempfile, shutil
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import install_dirset as ids

ACCT = "6e3973a7-b8ae-415c-b68f-db1337770a95"
DIRS = ["south", "east", "north", "west", "south-east", "north-east", "north-west", "south-west"]


def fetch(url):
    r = subprocess.run(["curl", "-s", "--fail", "--max-time", "20", "--retry", "3",
                        "--retry-delay", "2", "--retry-all-errors",
                        "-H", "User-Agent: Mozilla/5.0", url], capture_output=True)
    if r.returncode != 0 or not r.stdout:
        raise RuntimeError("curl failed (%d) %s" % (r.returncode, url))
    return Image.open(io.BytesIO(r.stdout)).convert("RGBA")


def main():
    char_id, base, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    tmp = tempfile.mkdtemp(prefix="skin_")
    try:
        import time
        for d in DIRS:
            url = "https://backblaze.pixellab.ai/file/pixellab-characters/%s/%s/rotations/%s.png" % (ACCT, char_id, d)
            fetch(url).save(os.path.join(tmp, "%s.png" % d))
            time.sleep(0.4)  # smooth rate
        cell = ids.install_static(tmp, base, out_dir)
        print("%s installed: cell=%dpx -> %s" % (base, cell, out_dir))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
