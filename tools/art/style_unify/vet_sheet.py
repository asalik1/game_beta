"""Contact sheet of a stage root's finished results next to their subject refs —
the LOOK step before install (CODING_GUIDELINES §40a: judge beside siblings,
never against the asset it replaces; this sheet shows old vs new so you can
also confirm silhouette/footprint identity survived).
  python vet_sheet.py <stage_root> <out.png> [name ...]
Each cell: subject (old) | result (new, keyed on green so alpha shows) | name.
"""
import os, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import TOOLS_ART  # noqa: E402
sys.path.insert(0, TOOLS_ART)
import install_prop_hires as iph  # noqa: E402


def main():
    stage_dir, out = sys.argv[1], sys.argv[2]
    only = sys.argv[3:]
    names = [n for n in sorted(os.listdir(stage_dir))
             if os.path.isdir(os.path.join(stage_dir, n)) and os.path.exists(os.path.join(stage_dir, n, n + ".png"))]
    if only:
        names = [n for n in names if n in only]
    cell = 220
    cols = 4  # pairs per row
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (cell * 2 + 12), max(1, rows) * (cell + 18)), (105, 95, 78, 255))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        x0 = (i % cols) * (cell * 2 + 12)
        y0 = (i // cols) * (cell + 18)
        subj = None
        refs = os.path.join(stage_dir, n, "refs")
        for f in os.listdir(refs) if os.path.isdir(refs) else []:
            if f.startswith("2_"):
                subj = Image.open(os.path.join(refs, f)).convert("RGBA")
        if subj is not None:
            subj.thumbnail((cell - 6, cell - 6))
            sheet.alpha_composite(subj, (x0 + 3, y0 + 3))
        res = iph.ensure_alpha(Image.open(os.path.join(stage_dir, n, n + ".png")).convert("RGBA"))
        res.thumbnail((cell - 6, cell - 6))
        sheet.alpha_composite(res, (x0 + cell + 9, y0 + 3))
        d.text((x0 + 4, y0 + cell + 3), n, fill=(255, 255, 255, 255))
    sheet.save(out)
    print(len(names), "->", out)


if __name__ == "__main__":
    main()
