#!/usr/bin/env python3
"""Prop fidelity regen: stage prep (briefs + refs) for the under-2x prop rows.

Faithful re-render: subject ref = the CURRENT approved asset (identity+style),
style anchor = a hi-res painterly sibling. Leafy trees = 2x2 master (cell 1 =
rest/static, cells 2-4 = canopy rustle, trunk pixel-locked). Everything else =
single subject. Stage layout follows tools/art/run_codex_batch.ps1.
"""
import csv, sys
from pathlib import Path
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
SPR = REPO / "game" / "assets" / "sprites"
HERE = Path(__file__).parent
STAGES = HERE / "prop_stages"

# name -> family render_w (from Balance.SCENERY_RENDER_WIDTH; variants use family width)
TARGETS = {
    # leafy trees (2x2 rustle master)              render_w  kind
    "tree_green": (190, "tree"),  "tree_green2": (190, "tree"),
    "tree_green3": (190, "tree"), "tree_green4": (190, "tree"),
    "tree_autumn": (190, "tree"), "tree_autumn2": (190, "tree"), "tree_autumn3": (190, "tree"),
    "tree_teal": (195, "tree"),   "tree_teal2": (195, "tree"),   "tree_teal3": (195, "tree"),
    "tree_snow": (175, "tree"),   "tree_snow2": (175, "tree"),   "tree_snow3": (175, "tree"),
    "tree_winter": (185, "tree"), "tree_winter2": (185, "tree"), "tree_winter3": (185, "tree"),
    "tree_spore": (195, "tree"),  "tree_spore2": (195, "tree"),  "tree_spore3": (195, "tree"),
    "topiary": (104, "tree"),     "bush3": (112, "tree"),
    # bare/dead trees + everything else (single subject, static)
    "tree_gnarled": (230, "static"), "tree_gnarled2": (230, "static"), "tree_gnarled3": (230, "static"),
    "deadtree": (180, "static"),  "grave_deadtree": (175, "static"),
    "garden_statue": (94, "static"), "storm_conductor": (108, "static"),
    "crypt": (150, "static"), "crystal_spire": (110, "static"), "void_rift": (94, "static"),
    "ruin_pillar": (98, "static"), "castle_statue": (94, "static"), "signpost": (62, "static"),
    "magma_chainrig": (145, "static"), "station_anvil_t3": (170, "static"),
    "grave_angel": (100, "static"), "keep_arch": (168, "static"), "pillar": (82, "static"),
    "log": (130, "static"), "cook_grill": (128, "static"), "station_alchemy_t3": (160, "static"),
    "void_obelisk": (108, "static"), "camp_furnace": (123, "static"),
    "void_monolith": (108, "static"), "tombstone3": (150, "static"),
    "camp_bonfire": (90, "fire"), "hideout_table": (120, "static"),
    "station_furnace_t3": (114, "static"), "crystal_cluster": (118, "static"),
    "forge_statue": (108, "static"), "station_furnace_t2": (108, "static"),
    "ice_sled": (144, "static"), "grave_statue": (92, "static"),
}

STYLE_REF = {  # hi-res painterly sibling per bucket
    "tree": SPR / "deadtree2.png",     # 512x512, 2.54x — painterly tree sibling
    "static": SPR / "boulder.png",     # 512x331, 5.86x — painterly prop benchmark
    "fire": SPR / "boulder.png",
}

TREE_BRIEF = """Repaint an EXISTING game prop at high resolution. This is a FIDELITY UPGRADE, not a redesign.

Reference image 2 (subject) is the CURRENT in-game tree: reproduce its exact silhouette, canopy
shape, species, proportions and palette. Reference image 1 shows the game's painterly house
style: soft-shaded, NO black outlines, muted palette, top-down three-quarter view, light from
the top-left.

Generate ONE image: a 2x2 grid of EXACTLY 4 cells on a TRANSPARENT background (real alpha),
each cell containing the COMPLETE tree, same size, centered at the same position in its cell:
- Cell 1 (top-left): the tree at REST — this exact tree, faithfully repainted at high detail.
- Cells 2, 3, 4: the SAME tree with ONLY the leaf canopy stirred by a gentle breeze — leaf
  clusters shift subtly (a few percent of canopy width), canopy edges rustle. Motion order:
  cell 2 = slight stir right, cell 3 = settled (near rest, different leaf detail), cell 4 =
  slight stir left, so cells 1-2-3-4 LOOP smoothly.
- The TRUNK and every visible branch stay PIXEL-IDENTICAL across all 4 cells: same position,
  same outline, same shading. The base of the trunk sits on the SAME baseline in every cell.
- NO whole-tree lean, NO trunk sway, NO moving shadow, NO background, NO ground patch.

Save the single 2x2 image to disk at the exact path {out} and stop.
"""

STATIC_BRIEF = """Repaint an EXISTING game prop at high resolution. This is a FIDELITY UPGRADE, not a redesign.

Reference image 2 (subject) is the CURRENT in-game asset: reproduce its exact silhouette,
proportions, design, materials and palette — the same object, drawn with more detail. Reference
image 1 shows the game's painterly house style: soft-shaded, NO black outlines, muted palette,
top-down three-quarter view, light from the top-left.

Generate ONE image: the single prop, centered, filling most of the canvas, on a TRANSPARENT
background (real alpha). NO characters, NO creatures, NO text, NO ground patch, NO shadow blob
beyond what the current asset itself carries.

Save the image to disk at the exact path {out} and stop.
"""

FIRE_BRIEF = """Repaint an EXISTING game prop at high resolution. This is a FIDELITY UPGRADE, not a redesign.

Reference image 2 (subject) is the CURRENT in-game campfire: reproduce its exact log
arrangement, silhouette, proportions and palette. Reference image 1 shows the game's painterly
house style: soft-shaded, NO black outlines, muted palette, top-down three-quarter view.

Generate ONE image: a 2x2 grid of EXACTLY 4 cells on a TRANSPARENT background (real alpha),
each cell the COMPLETE campfire at the same position and size:
- Cell 1: the campfire exactly as the reference (this becomes the rest frame).
- Cells 2-4: ONLY the flames and embers change (natural fire flicker loop); the LOGS and
  stones stay PIXEL-IDENTICAL across all 4 cells, on the same baseline.
NO background, NO ground patch, NO smoke column leaving the canvas.

Save the single 2x2 image to disk at the exact path {out} and stop.
"""

def main() -> int:
    only = set(sys.argv[1:])
    STAGES.mkdir(exist_ok=True)
    rows, names = [], []
    for name, (rw, kind) in TARGETS.items():
        if only and name not in only:
            continue
        src = SPR / f"{name}.png"
        if not src.exists():
            print("MISSING", name); continue
        stage = STAGES / name
        refs = stage / "refs"
        refs.mkdir(parents=True, exist_ok=True)
        # style ref + subject ref (subject upscaled 2x NEAREST so codex sees pixels clearly)
        style = STYLE_REF[kind]
        Image.open(style).convert("RGBA").save(refs / f"1_style_{style.stem}.png")
        im = Image.open(src).convert("RGBA")
        im.resize((im.width * 2, im.height * 2), Image.Resampling.NEAREST).save(
            refs / f"2_subject_{name}.png")
        out = stage / f"{name}_master.png"
        brief = {"tree": TREE_BRIEF, "static": STATIC_BRIEF, "fire": FIRE_BRIEF}[kind]
        (stage / "codex_brief.txt").write_text(brief.format(out=str(out)), encoding="utf-8")
        rows.append((name, rw)); names.append(str(stage))
    with open(STAGES / "render_w.csv", "w", newline="") as f:
        csv.writer(f).writerows([("name", "width"), *rows])
    (STAGES / "stages.txt").write_text("\n".join(names) + "\n", encoding="utf-8")
    print(f"staged {len(rows)} briefs -> {STAGES}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
