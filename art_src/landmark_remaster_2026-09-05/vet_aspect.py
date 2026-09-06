"""Landmark re-master vet: per finished stage, the keyed result's size, its height-over-width
against the current master (a landmark is scaled to its def width, so aspect drift = an
on-screen height change), and an old|new sheet for the eyes. Run from the repo root."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
STAGE = Path(__file__).resolve().parent


def keyed(p: Path) -> Image.Image:
    a = np.array(Image.open(p).convert("RGBA"))
    g = (a[:, :, 1] > 180) & (a[:, :, 0] < 110) & (a[:, :, 2] < 110)
    a[g] = 0
    im = Image.fromarray(a)
    return im.crop(im.getchannel("A").getbbox())


def bbox_wh(im: Image.Image):
    a = np.array(im)[:, :, 3] > 40
    ys, xs = np.nonzero(a)
    return xs.max() - xs.min() + 1, ys.max() - ys.min() + 1


def main() -> int:
    names = [d.name for d in sorted(STAGE.iterdir()) if d.is_dir() and (d / f"{d.name}.png").exists()]
    if len(sys.argv) > 1:
        names = [n for n in names if n in sys.argv[1:]]
    tiles = []
    H = 360
    for n in names:
        new = keyed(STAGE / n / f"{n}.png")
        old = Image.open(SPR / f"{n}.png").convert("RGBA")
        ow, oh = bbox_wh(old)
        nw, nh = bbox_wh(new)
        drift = (nh / nw) / (oh / ow) - 1
        flag = "  <-- RE-ROLL? aspect" if abs(drift) > 0.10 else ""
        print(f"{n:18s} old {ow}x{oh}  new {nw}x{nh}  height at equal width {drift:+.1%}{flag}")
        o2 = old.resize((max(1, int(old.width * H / old.height)), H), Image.LANCZOS)
        n2 = new.resize((max(1, int(new.width * H / new.height)), H), Image.LANCZOS)
        tile = Image.new("RGBA", (o2.width + n2.width + 24, H + 22), (70, 80, 60, 255))
        tile.alpha_composite(o2, (0, 22))
        tile.alpha_composite(n2, (o2.width + 24, 22))
        ImageDraw.Draw(tile).text((2, 4), f"{n}  old | new ({drift:+.0%} h)", fill=(255, 255, 255, 255))
        tiles.append(tile)
    if not tiles:
        print("no results yet")
        return 1
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    cw = max(t.width for t in tiles)
    sheet = Image.new("RGBA", (cw * cols + 12 * (cols + 1), (H + 22) * rows + 12 * (rows + 1)), (70, 80, 60, 255))
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet.alpha_composite(t, (12 + c * (cw + 12), 12 + r * (H + 22 + 12)))
    out = ROOT / "art_src" / "_qa_final" / "landmark_vet.png"
    sheet.save(out)
    print("sheet ->", out, sheet.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
