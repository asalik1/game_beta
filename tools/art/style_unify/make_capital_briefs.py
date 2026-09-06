"""Capital (Crownfall) kit STYLE-UNIFY briefs (2026-09-03 visual overhaul).

The 26 capital_* structures were authored in Jul 2026 as crisp hard-outlined
pixel art with saturated red/gold trim; every other building and prop in the
world was repainted painterly in the Aug 2026 polish pass (batches A-D), so
the capital reads as a different game beside the cast. This writes one Codex
stage per piece that REPAINTS it in the painterly house style while keeping
its silhouette, footprint, parts and colour identity (the landmark tight-crop
contract, hotspot stand-points and the fire/water _anim sockets all key off
the shape).

  python tools/art/style_unify/make_capital_briefs.py <stage_root> [name ...]

Stage = codex_brief.txt + refs/1_style_<sibling>.png + refs/2_subject_<name>.png.
Wide pieces (arcade, spire gate) ask for a landscape canvas. Then:
  powershell tools/art/run_codex_batch.ps1 -Stages (Get-Content <root>/stages.txt) -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 -ExtraArgs "--dangerously-bypass-approvals-and-sandbox"
  python tools/art/style_unify/vet_sheet.py <root> vet.png      # LOOK
  python tools/art/install_capital_stage.py <root> [names]       # key, tone, tight-crop, anim re-derive
"""
import os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SPR  # noqa: E402

# name -> (painterly style sibling, description, canvas hint)
PLAN = {
    "capital_crown_spire_gate": ("keep_arch", "a monumental city gate: one tall crown-shaped central spire over an OPEN traversable central arch, lower flanking towers with conical caps, stairs and buttresses, charcoal ironstone, brass trim, two dark-red banners, small civic fire bowls at the foot", "wide"),
    "capital_city_arcade": ("keep_arch", "a very wide continuous arcade of connected stone arches and low towers with peaked roofs, a shallow base strip, charcoal ironstone with brass and dark-red accents", "wide"),
    "capital_crown_fountain": ("garden_fountain", "a tiered stone plaza fountain with a crown-and-spires finial on top, three basins, pale water falling into the lowest basin, four small red banners on posts around the rim", "square"),
    "capital_emberward_gate": ("keep_arch", "a heavy stone city gatehouse: a wide open arch with a raised portcullis, two flanking towers with brass-crowned caps, dark-red banners, a burning brazier at each foot", "square"),
    "capital_market_stall": ("stall", "a merchant's market stall: a dark-red canvas awning on carved dark-wood posts, shelves of crates, sacks, bottles and bolts of cloth, two hanging lanterns, a chest at the foot", "square"),
    "capital_ashfire_forge": ("cottage_b", "a smithy: a squat stone workshop with an open front showing a glowing forge hearth, an anvil, hanging tongs and chains, a stone chimney, dark-red banners on the corner posts", "square"),
    "capital_grand_archive": ("cottage_b", "a civic stone hall: a broad two-storey grey-stone facade with a crowned pediment, tall arched double doors up a short stair, arched windows, dark-red banners either side", "square"),
    "capital_ashen_tankard": ("cottage_a", "a tavern: a two-storey timber-and-stone inn with a red-tiled roof, stone chimney, a hanging tankard sign, warm lit windows and a lantern by the door", "square"),
    "capital_chartered_hall": ("cottage_b", "a guild hall: a wide grey-stone facade with a steep dark slate roof, a crowned gable, an arched door, a red banner and a notice board on the wall", "square"),
    "capital_great_hearth": ("keep_brazier", "a large open communal hearth: a carved dark-stone firebox with an iron cooking rail and hooks, a broad ash lip, split logs and one large integrated fire, brass trim, a small crown over the mantle", "square"),
    "capital_alembic_station": ("camp_workbench", "an alchemist's workbench: a dark-wood bench with a copper alembic still, glass retorts and bottles, a mortar, drawers below, shelves of jars above, brass crown crest", "square"),
    "capital_city_directory": ("signpost", "a freestanding city directory board: a carved dark-stone frame around a weathered wooden panel pinned with parchment notes, a brass crown crest on top, four small ward-colour markers", "square"),
    "capital_city_bench": ("hideout_table", "a broad city bench: dark weathered hardwood seat and back on carved charcoal-stone end supports with small brass crown motifs", "square"),
    "capital_vault_chest": ("hideout_barrel", "a heavy locked vault coffer: a dark-oak chest with layered blackened-steel bands, reinforced corners, a brass crown lock plate and red enamel accents, closed lid", "square"),
    "capital_portal_story": ("keep_arch", "a stone portal frame: a tall crowned arch of grey stone on a round dais, a column of pale blue-white light rising inside the arch, blue rune trim on the dais steps (muted, no neon)", "square"),
    "capital_portal_crucible": ("keep_arch", "a martial stone portal: two square flanking towers joined by a pointed arch, dark-red banners, small fire bowls at the feet, a faint ember glow inside the arch (muted, no neon)", "square"),
    "capital_portal_depths": ("keep_arch", "a narrow black-stone doorway with a jagged frame, a dark violet void swirling inside it, a red banner on one side, cracked steps (muted, no neon)", "square"),
    "capital_proving_gate": ("keep_arch", "a martial arena gate: a wide stone arch with an iron portcullis raised, two flanking towers, dark-red banners, hanging shields and lanterns, chains", "square"),
    "capital_rot_chapel": ("grave_statue", "a grim chapel of the Hollow Choir: a dark-stone chapel facade with a peaked gable, skull and bone ornaments, iron candle racks with many candles, a low fenced forecourt", "square"),
    "capital_sable_hall": ("cottage_b", "a noble hall: a tall dark-stone hall with a steep black slate roof, a crowned gable, a red carpet up a short stair to arched double doors, dark-red banners and lanterns", "square"),
    "capital_stables": ("cottage_a", "a stable: a low open-fronted timber stable with a red-tiled roof, hay bales, a water trough, a wooden fence, hanging tack", "square"),
    "capital_undercroft": ("keep_arch", "a stone undercroft entrance: a heavy arched doorway in a low stone wall opening onto a descending mossy passage, a lantern on each side, a crown keystone", "square"),
    "capital_watchtower": ("keep_arch", "a square stone watchtower: a tall grey-stone tower with a crowned brass cap, a burning brazier on top, an arched doorway at the base, a ladder and a red banner", "square"),
    "capital_wellspring": ("old_well", "a stone wellspring shrine: a round pool of pale water in a low stone rim under a domed iron-and-stone canopy on pillars, a small spout of water rising in the middle, flowers and moss at the foot (muted, no cyan glow)", "square"),
    "capital_wildfang_fangmoot": ("camp_bonfire", "a beast-tribe moot circle: a round stone dais with a central fire pit, ringed by carved wooden totem posts with antler and skull tops, red hide banners, a few log seats", "square"),
    "capital_accord_longhouse": ("cottage_a", "a longhouse: a long timber hall with a moss-green thatched roof, carved gable beams, a wide open front showing a hearth and benches, hanging green and gold banners", "square"),
}

BRIEF = """Repaint a game BUILDING / STRUCTURE in the rendering style of a reference. This is for a top-down dark-fantasy action RPG. All of the world's buildings, props and characters are PAINTERLY; this one still reads as hard-outlined pixel-art with saturated trim, so it must be brought in line with its siblings.

Reference image 1_style_{ref}.png (STYLE): a finished structure from this game — painterly, softly shaded, fine natural detail, NO black outlines, muted somber palette, weathered stone and wood, light from the top-left, top-down three-quarter view. Match this rendering style exactly (brushwork, edge softness, material shading, saturation level).

Reference image 2_subject_{name}.png (SUBJECT): the current pixel-art version to replace — "{desc}". Keep ITS silhouette, footprint, proportions, view angle, every architectural part in the same place (doors, windows, arches, stairs, banners, fires, towers), and its colour identity, but desaturate the reds/golds to the muted palette of reference 1. Only the rendering style changes: from outlined pixel-art to the painterly style of reference 1. Keep any open arch or doorway OPEN (it is walked through). Fire, embers and water may glow softly, nothing else glows; no neon, no cyan/magenta lights.

Generate ONE image: the SUBJECT repainted in the STYLE of reference 1. Same object, same shape and orientation, filling most of the canvas, centred, on a flat solid pure-green (#00FF00) background. No cast shadow on the ground, no ground plane, no people, no other objects, no text, no frame. {canvas}. Painterly, no cartoon outlines.

Save the PNG to exactly this path: {out}/{name}.png
Then reply with one line: which reference you matched the style to, and any way the silhouette or part placement differs from the subject.
"""

CANVAS = {"square": "Square 1024x1024", "wide": "Landscape 1536x640 (the subject is very wide)"}


def stage_plan(root, plan, names=None, brief=None):
    """Write one Codex stage per plan entry (refs + brief) and <root>/stages.txt.
    Shared by the capital lane and the landmark re-master lane
    (make_landmark_briefs.py, 2026-09-05), which passes its own brief text."""
    names = names or list(plan)
    BRIEF_ = brief or BRIEF
    os.makedirs(root, exist_ok=True)
    stages = []
    for name in names:
        ref, desc, canvas = plan[name]
        stage = os.path.join(root, name)
        refs = os.path.join(stage, "refs")
        os.makedirs(refs, exist_ok=True)
        shutil.copy(os.path.join(SPR, ref + ".png"), os.path.join(refs, f"1_style_{ref}.png"))
        shutil.copy(os.path.join(SPR, name + ".png"), os.path.join(refs, f"2_subject_{name}.png"))
        with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
            f.write(BRIEF_.format(ref=ref, name=name, desc=desc, out=os.path.abspath(stage),
                                  canvas=CANVAS[canvas]))
        stages.append(os.path.abspath(stage))
        print("stage", name, "<-", ref)
    with open(os.path.join(root, "stages.txt"), "w") as f:
        f.write("\n".join(stages) + "\n")
    print(len(stages), "stages ->", os.path.join(root, "stages.txt"))
    return stages


def main():
    ap = sys.argv[1:]
    if not ap or ap[0] in ("-h", "--help"):
        print(__doc__); return 1
    root = ap[0]
    names = ap[1:] or list(PLAN)
    stage_plan(root, PLAN, names)
    return 0


if __name__ == "__main__":
    sys.exit(main())
