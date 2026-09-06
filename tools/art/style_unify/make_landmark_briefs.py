"""Landmark RE-MASTER briefs (2026-09-05, the fidelity rule applied to STRUCTURE bases).

`fidelity_audit.py` scores a prop at its scatter width, but `_add_structure` scales
the same PNG to the structure def's "w" (145-190 px) when it is an ecology landmark,
so thirteen painterly masters that pass as scatter (2.2-2.5x) render at 1.02-1.65x as
landmarks -- under the owner's >=2x bar (<1.90x MUST FIX). This stages one Codex
job per piece that reproduces the piece at a larger canvas with finer detail: same
painterly style (a family sibling as the style reference), same silhouette,
footprint, parts and palette (the piece itself is the SUBJECT reference).
sewer_outfall is the one STYLE fix in the set (a 160 px pixel-art pipe beside
painterly wells and braziers).

  python tools/art/style_unify/make_landmark_briefs.py <stage_root> [name ...]
  powershell tools/art/run_codex_batch.ps1 -Stages (Get-Content <root>/stages.txt) -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 ...
  python tools/art/style_unify/vet_sheet.py <root> vet.png                 # LOOK
  python tools/art/install_capital_stage.py <root> --render-w <root>/render_w.csv   # key, tone, tight-crop, size cap, anim re-derive

The installer caps the master at FIDELITY_X (2.3) x the def width, so pass the
LANDMARK width (the larger of a piece's uses) in render_w.csv; the scatter use
just downsamples further.
"""
import csv, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_capital_briefs import stage_plan  # noqa: E402

# name -> (painterly style sibling, description FROM the current art, canvas)
PLAN = {
    "castle_statue": ("grave_statue", "a weathered grey-stone statue of an armoured knight standing on a square stepped plinth, a great helm, both hands resting on the pommel of a tall sword held point-down before him, a tabard and a cloak falling to the plinth, moss in the seams", "square"),
    "forge_statue": ("grave_statue", "a dark basalt statue of a seated forge deity on a stepped throne-plinth, a horned helm, arms on the armrests, small orange fires burning in bowls on both sides of the throne and a glowing ember chest, soot and heat-cracks in the stone", "square"),
    "grave_angel": ("grave_statue", "a pale weathered marble mourning angel on a square pedestal, head bowed, hands clasped low, large wings folded behind and down to the pedestal, lichen and water stains", "square"),
    "ice_cairn": ("rock3", "a tall stacked cairn of grey and blue-grey stones, wider at the base and tapering to a single stone on top, snow capping every ledge, pale blue ice between the stones", "square"),
    "sandstone": ("boulder", "a tall stepped desert hoodoo of layered orange-tan sandstone, a broad base narrowing in uneven horizontal strata to a flat top, wind-carved undercuts, sand at the foot", "square"),
    "crystal_spire": ("crystal_cluster", "a cluster of tall translucent cyan-blue crystal shards rising from a dark rock base, one dominant central spire flanked by smaller angled shards, glowing pale-blue facets, small crystals at the foot", "square"),
    "storm_conductor": ("storm_standing_stone", "a tall dark-stone tower-obelisk with a ring of glowing blue runes near its top and a bright blue-white lightning bolt running down its face to the ground, small crackling arcs, a stepped stone base", "square"),
    "void_rift": ("void_monolith", "a tall jagged frame of dark violet-black stone standing upright, a swirling purple-violet void of light churning inside it, faint purple glow spilling on the ground at its foot, small floating shards", "square"),
    "spore_shrine": ("spore_vent", "a low round stone well overgrown by thick pale roots that climb over its rim, clusters of pink-purple mushrooms growing on the roots and stones, a soft violet glow from the well mouth, purple spores drifting", "square"),
    "pillar": ("keep_arch", "a tall square grey-stone pillar with a plain capital and a stepped base, chipped edges, moss and water stains on the lower blocks", "square"),
    "sewer_outfall": ("old_well", "a sewer outfall: a large rusted dark-iron pipe with riveted bands jutting from a short mossy brick-and-stone wall segment, thick green-brown sludge pouring from the pipe mouth into a spreading puddle at its foot", "square"),
    "signpost": ("camp_workbench", "a weathered wooden signpost: a single dark post with three arrow-shaped signboards pointing different ways, worn carved lettering, a small stone footing", "square"),
    # 2026-09-06 wave 2: found by the NEW structures lane in fidelity_audit.py
    "keep_arch": ("crypt", "a freestanding ruined stone gate arch: two thick weathered grey-stone piers carrying a wide round arch with a keystone, blocks chipped and mossy at the base, the opening walkable and empty", "square"),
    "torch_pillar": ("keep_brazier", "a square grey-stone pillar brazier: a stepped stone base and column with an iron-rimmed bowl on top holding a bright orange-yellow flame, soot on the bowl, a warm glow on the upper stones", "square"),
}

# landmark def widths (Terrains.STRUCTURES "w", the larger use) for the installer's size cap
RENDER_W = {
    "castle_statue": 145, "forge_statue": 155, "grave_angel": 150, "ice_cairn": 150, "sandstone": 185,
    "crystal_spire": 175, "storm_conductor": 170, "void_rift": 180, "spore_shrine": 190, "pillar": 120,
    "sewer_outfall": 140, "signpost": 84, "torch_pillar": 80, "keep_arch": 200,
}


BRIEF = """Re-master a game LANDMARK prop at a higher resolution. This is for a top-down dark-fantasy action RPG in which every prop is PAINTERLY: softly shaded, fine natural detail, NO black outlines, muted somber palette, weathered materials, light from the top-left, top-down three-quarter view.

Reference image 2_subject_{name}.png (SUBJECT): the current version — "{desc}". It was painted at a small size and renders soft in-game. Reproduce it LARGE with finer, crisper detail: the SAME object, same silhouette, footprint, proportions and view angle, every part in the same place, the same palette and material reads. Do not redesign it, add parts, or change its colours; only resolve more detail (stone grain, edge wear, moss, glow gradients) at the larger size. If the subject is pixel-art, repaint it painterly to match reference 1 while keeping everything else.

Reference image 1_style_{ref}.png (STYLE): a finished sibling prop from this game at the target level of detail and brushwork. Match its rendering (edge softness, material shading, saturation level).

Generate ONE image: the subject re-painted large, filling most of the canvas, centred, on a flat solid pure-green (#00FF00) background. No ground shadow beyond what the subject itself carries, no text, no frame, nothing else in the image. {canvas}.

Save the PNG to exactly this path: {out}/{name}.png
Then reply with one line: any way the silhouette or part placement differs from the subject.
"""


def main():
    ap = sys.argv[1:]
    if not ap or ap[0] in ("-h", "--help"):
        print(__doc__); return 1
    root = ap[0]
    names = ap[1:] or list(PLAN)
    stage_plan(root, PLAN, names, brief=BRIEF)
    with open(os.path.join(root, "render_w.csv"), "w", newline="") as f:
        w = csv.writer(f)
        for n in names:
            w.writerow([n, RENDER_W[n]])
    print("render widths ->", os.path.join(root, "render_w.csv"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
