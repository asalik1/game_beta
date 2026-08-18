"""Prop STYLE-UNIFY lane — build headless-Codex stage dirs that REPAINT a prop
in the painterly house style (2026-08-18 gameplay-polish pass; contract in
CLAUDE.md "World props" + CODING_GUIDELINES.md §40).

Each stage = codex_brief.txt + refs/1_style_<sibling>.png + refs/2_subject_<prop>.png
(refs go to `codex exec -i` in alphabetical order). The STYLE ref is a finished
painterly sibling; the SUBJECT is the current asset — silhouette / footprint /
colour identity only. Results land as <stage>/<name>.png on solid #00FF00.

  python make_briefs.py <stage_root> [--plan PLAN.py] [name ...]

PLAN maps name -> (style_sibling, description). The default PLAN below is the
batch-D list (props that passed the resolution audit but still read as
outlined cartoon). For a resolution-flagged batch, generate the plan from
tools/art/dump_prop_res.gd's csv instead (see the 2026-08-18 memory).
render widths come from Balance.SCENERY_RENDER_WIDTH via <stage_root>/render_w.csv
(name,width) — install_stage.py reads it; run tools/art/dump_prop_res.gd to
produce one, or pass a csv with --render-w.

Then: powershell tools/art/run_codex_batch.ps1 -Stages <dirs> -MaxParallel 1 -MinFreeGB 1.3
      python vet_sheet.py <stage_root> vet.png     # LOOK before installing
      python install_stage.py <stage_root>          # key -> tone-match -> install (game + mobile)
      python derive_stage.py [names]                # animated statics: rebuild _anim strips
      python ../audit_prop_anims.py ; python ../verify_art.py <names>
"""
import argparse, os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SPR  # noqa: E402

# name -> (painterly style sibling, description)  — batch D (2026-08-18)
PLAN = {
    "cactus": ("deadtree2", "a tall many-armed desert cactus, ribbed dusty green with pale spines, growing from bare sand"),
    "cactus2": ("deadtree2", "a stout saguaro-type cactus: one thick ribbed trunk with two short arms, dusty muted green, pale spines"),
    "dead_shrub": ("deadtree2", "a low dead desert shrub of bare twisted grey-brown twigs"),
    "sand_drift": ("rock_pale", "a low wind-blown drift of pale sand lying FLAT on the ground, a soft curved streak with feathered edges (a ground decal, seen from above)"),
    "sand_drift2": ("rock_pale", "a long low wind-blown drift of pale sand lying FLAT on the ground, a soft curved streak with feathered edges (a ground decal, seen from above)"),
    "sandstone": ("rock3", "a weathered sandstone hoodoo: layered ochre and rust rock in a stepped column, sand at its foot"),
    "bush2": ("bush", "a round leafy green shrub"),
    "cattail2": ("cattail", "a clump of tall marsh reeds with brown cattail heads"),
    "cattail3": ("cattail", "a clump of tall marsh reeds with brown cattail heads"),
    "grass2": ("grass", "a tuft of tall wild grass"),
    "grass3": ("grass", "a tuft of tall wild grass with pale seed heads"),
    "tree_green3": ("tree_green", "a broad leafy deciduous tree, deep green canopy"),
    "tree_green4": ("tree_green", "a slender young deciduous tree with a small green canopy"),
    "tree_snow2": ("tree_snow", "a bare-branched deciduous tree with heavy snow caps on its limbs"),
    "tree_snow3": ("tree_snow", "a tall snow-laden conifer"),
    "tree_spore2": ("tree_spore", "a giant fungal tree: pale mauve caps on a fibrous trunk, faint spots"),
    "tree_spore3": ("tree_spore", "a tall twisted fungal growth of stacked mauve-pink shelves"),
    "tree_teal2": ("tree_teal", "a broad tree with a muted teal-green canopy"),
    "tree_teal3": ("tree_teal", "a wind-bent tree with a muted teal-green canopy"),
    "tree_winter2": ("tree_winter", "a bare frost-white dead tree with spreading branches"),
    "tree_winter3": ("tree_winter", "a slender bare frost-white tree"),
    "stump_snow": ("tree_stump", "a cut tree stump with roots, capped and dusted with snow"),
    "log2": ("log", "a fallen log with a broken end, dark bark, a little moss"),
    "rock_ice": ("rock", "a flat grey boulder rimed with ice and frost"),
    "grave_cross": ("tombstone", "a plain weathered wooden grave cross"),
    "grave_cross2": ("tombstone", "a heavy weathered stone grave cross, moss in the joints"),
    "grave_crack": ("crack", "a jagged crack in dry earth with a dark hollow, seen from above (a ground decal)"),
    "camp_furnace": ("magma_furnace", "a small field furnace of stacked grey stones with a glowing ember mouth and a short flue"),
    "forge_brazier": ("keep_brazier", "a small iron brazier bowl on three legs with glowing coals"),
    "forge_cauldron": ("magma_furnace", "a squat iron smelting cauldron on a stone base with a glowing molten mouth"),
    "station_furnace_t1": ("magma_furnace", "a crude smelting furnace of stacked stones with a glowing mouth (tier 1)"),
    "station_furnace_t2": ("magma_furnace", "a brick smelting furnace with an arched glowing firebox and a chimney (tier 2)"),
    "station_furnace_t3": ("magma_furnace", "a heavy iron-banded master furnace with a bright molten mouth and pipework (tier 3) — keep it a medieval forge, not a machine"),
}

BRIEF = """Repaint a game prop in the rendering style of a reference. This is for a top-down dark-fantasy action RPG; the world's props are painterly and this one still reads as outlined cartoon pixel-art, so it must be brought in line with its siblings.

Reference image 1_style_{ref}.png (STYLE): a finished prop from this game — painterly, softly shaded, fine natural detail, NO black outlines, muted somber palette, light from the top-left, top-down three-quarter view. Match this rendering style exactly.

Reference image 2_subject_{name}.png (SUBJECT): the current cartoon version of the prop to replace — "{desc}". Keep ITS silhouette, footprint, proportions, view angle, parts and colour identity. Only the rendering style changes: from outlined cartoon pixel-art to the painterly style of reference 1. If the subject is a multi-part or wide object, keep every part in the same place.

Generate ONE image: the SUBJECT prop repainted in the STYLE of reference 1. Same object, same shape and orientation, filling most of the canvas, centred, on a flat solid pure-green (#00FF00) background. No cast shadow on the ground, no ground plane, no other objects, no text, no frame. Square 1024x1024. Muted saturation (a somber world): no cartoon outlines, no neon, no glow beyond what the subject itself emits.

Save the PNG to exactly this path: {out}/{name}.png
Then reply with one line: which reference you matched the style to, and any way the silhouette differs from the subject.
"""


def load_plan(path):
    ns = {}
    exec(open(path, encoding="utf-8").read(), ns)  # noqa: S102 — a local plan file
    return ns["PLAN"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("--plan", help="python file defining PLAN = {name: (style_sibling, description)}")
    ap.add_argument("--render-w", help="csv name,width (default: <stage_root>/render_w.csv must already exist)")
    ap.add_argument("names", nargs="*")
    a = ap.parse_args()
    plan = load_plan(a.plan) if a.plan else PLAN
    rw = {}
    src_csv = a.render_w or os.path.join(a.stage_root, "render_w.csv")
    if os.path.exists(src_csv):
        for line in open(src_csv):
            if "," in line:
                n, w = line.strip().split(",")
                rw[n] = float(w)
    stages = []
    os.makedirs(a.stage_root, exist_ok=True)
    for name, (ref, desc) in plan.items():
        if a.names and name not in a.names:
            continue
        src = os.path.join(SPR, name + ".png")
        if not os.path.exists(src):
            print("no png for", name)
            continue
        if name not in rw:
            print("WARNING no render_w for", name, "- install_stage.py will skip it until render_w.csv has it")
        stage = os.path.join(a.stage_root, name)
        refs = os.path.join(stage, "refs")
        os.makedirs(refs, exist_ok=True)
        shutil.copy(os.path.join(SPR, ref + ".png"), os.path.join(refs, "1_style_%s.png" % ref))
        shutil.copy(src, os.path.join(refs, "2_subject_%s.png" % name))
        with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
            f.write(BRIEF.format(ref=ref, name=name, desc=desc, out=stage.replace("\\", "/")))
        stages.append(stage)
    with open(os.path.join(a.stage_root, "stages.txt"), "w") as f:
        f.write(",".join(stages))
    print("stages:", len(stages), "->", os.path.join(a.stage_root, "stages.txt"))


if __name__ == "__main__":
    main()
