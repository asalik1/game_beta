#!/usr/bin/env python
"""Install environment art into the three Track-D seams (DESIGN.md) — the code
blockers are gone, so unlocking a pack sheet is now a pure drop-in. This helper
does the ONE mechanical step each seam needs (naming + square/grid normalizing)
so the PNG lands where the engine already looks for it.

  ground    seamless floor tile / variation grid -> assets/sprites/ground_<kind>.png
            (Art.ground tiles it for that ground KIND; picks a seeded cell per
             16px tile. kinds: grass forest marsh stone dirt basalt snow
             gravedirt sand bogsoil crystalfloor stormgrass voidstone holystone
             sporesoil — see Art.GROUND)
  animprop  a horizontal strip OR a folder/list of frames -> assets/sprites/<name>_anim.png
            (Art.anim_prop plays it on any scenery prop of that name — an
             obstacle/decor/accent, or a structure part/decal in Terrains.STRUCTURES)

After installing, run the import gate ONCE so the headless engine can load it:
    tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --import

Examples:
    # a single seamless grass tile
    python install_env_asset.py ground grass.png grass
    # four grass variants in a 2x2 sheet, cut to 16px cells
    python install_env_asset.py ground grass_sheet.png grass --grid 2x2 --cell 16
    # a 4-frame torch flicker already laid out as a horizontal strip
    python install_env_asset.py animprop torch_strip.png torch --frames 4
    # a waterwheel from separate frame PNGs
    python install_env_asset.py animprop wheel_00.png wheel_01.png wheel_02.png waterwheel
"""
import os, sys, argparse
from PIL import Image

SPRITES = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "sprites"))


def _load(path):
    return Image.open(path).convert("RGBA")


def cmd_ground(args):
    src = _load(args.src)
    if args.grid:
        rows, cols = (int(x) for x in args.grid.lower().split("x"))
        cw, ch = src.width // cols, src.height // rows
        cell = args.cell or min(cw, ch)
        # Re-lay each grid cell as a clean `cell`x`cell` square so the engine's
        # shorter-axis cell inference (_ground_tileset) reads cols/rows exactly.
        out = Image.new("RGBA", (cell * cols, cell * rows), (0, 0, 0, 0))
        for r in range(rows):
            for c in range(cols):
                piece = src.crop((c * cw, r * ch, c * cw + cw, r * ch + ch))
                if piece.size != (cell, cell):
                    piece = piece.resize((cell, cell), Image.NEAREST)
                out.paste(piece, (c * cell, r * cell))
    else:
        out = src  # already a seamless single tile (any square size)
    dst = os.path.join(SPRITES, "ground_%s.png" % args.kind)
    out.save(dst)
    print("wrote %s  (%dx%d)" % (dst, out.width, out.height))


def cmd_animprop(args):
    imgs = [_load(p) for p in args.frames]
    if len(imgs) == 1 and imgs[0].width > imgs[0].height:
        # A single wide image is treated as an existing horizontal strip; only
        # re-cut if --frames says how many cells it holds.
        strip = imgs[0]
        n = args.count or max(1, strip.width // strip.height)
        cell = strip.height
        frames = [strip.crop((i * (strip.width // n), 0,
                              i * (strip.width // n) + (strip.width // n), cell)) for i in range(n)]
    else:
        frames = imgs
    # Normalize every frame to one SQUARE cell (bottom-centered — props sit on
    # the ground), so width/height gives the exact frame count in-engine.
    cell = max(max(f.width, f.height) for f in frames)
    strip = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sq = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        sq.paste(f, ((cell - f.width) // 2, cell - f.height))
        strip.paste(sq, (i * cell, 0))
    dst = os.path.join(SPRITES, "%s_anim.png" % args.name)
    strip.save(dst)
    print("wrote %s  (%d frames, %dpx cell)" % (dst, len(frames), cell))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("ground", help="install a ground tileset for a ground kind")
    g.add_argument("src")
    g.add_argument("kind")
    g.add_argument("--grid", help="RxC variation grid in the source (e.g. 2x2)")
    g.add_argument("--cell", type=int, default=0, help="output cell px (default: shorter grid-cell axis)")
    g.set_defaults(func=cmd_ground)

    a = sub.add_parser("animprop", help="install an animated scenery-prop strip")
    a.add_argument("frames", nargs="+", help="one horizontal strip, or N frame PNGs; LAST arg is the prop name")
    a.add_argument("--frames", type=int, default=0, dest="count", help="cell count if the source is a horizontal strip")
    a.set_defaults(func=cmd_animprop)

    args = ap.parse_args()
    if args.cmd == "animprop":
        # The final positional is the prop NAME, the rest are source frames.
        *args.frames, args.name = args.frames
        if not args.frames:
            ap.error("animprop needs at least one source frame before the name")
    args.func(args)


if __name__ == "__main__":
    main()
