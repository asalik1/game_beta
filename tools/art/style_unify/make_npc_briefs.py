"""NPC + landmark briefs for headless Codex (2026-08-18 batch C): the nine
shared WANDERER NPC archetypes that were still 30-33px pack sprites (owner:
"Snarehand Ott seems to be using a legacy sprite") + the ch2 MILL landmark
(a 16px procedural grid: "the mill looks horrible").

NPC recipe = art_src/npcs/scholar_ivo: ImageGen 1024 on green with three roster
sprites as the style benchmark, then build_npcs.py -> 256² canvas (body 223,
feet 238, static == _anim). Mill: cottage_a as the style ref -> 384px override.

  python make_npc_briefs.py <stage_root>
"""
import os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SPR  # noqa: E402

ROSTER = ["archivist_lene", "clerk_voss", "aldric"]

NPCS = {
    "npc_hunter": ("SNAREHAND OTT-type trapper: a weathered man in his forties, lean and wiry, wind-burned face, short dark stubble, hair tied back under a soft brown leather cap; a hooded oilskin cloak (hood DOWN) in dark olive-brown over a grey wool jerkin, patched trousers, tall mud-caked boots; a coil of thin snare WIRE and a bundle of wooden pegs hanging from his belt, a small hare-skin pouch, a short knife; his hands hold a half-set snare loop of wire in front of him. Mood: watchful, dry, patient.", "olive-brown oilskin, grey wool, mud brown, dull steel"),
    "npc_wanderer": ("a road WANDERER: a middle-aged traveller of no trade, dusty grey-brown hooded travelling cloak (hood down), a rolled blanket and a battered pack on the back, a walking staff in one hand, road-worn boots, a wide-brimmed hat hanging by its cord on the shoulders. Mood: tired but friendly.", "dust grey-brown, faded blue scarf, worn leather"),
    "npc_villager_f": ("a VILLAGE WOMAN: thirties, practical, plain undyed wool dress with a faded blue apron, a linen headscarf, sleeves rolled, a wicker basket on one arm with a cloth over it, simple leather shoes. Mood: wary but decent.", "undyed wool, faded blue, wicker, linen"),
    "npc_villager_m": ("a VILLAGE MAN: forties, stocky, plain brown tunic belted over grey trousers, a wool cap, work gloves tucked in the belt, a hand-axe hanging from the belt, heavy boots. Mood: plain, tired, decent.", "brown wool, grey, dark leather"),
    "npc_bandit_tracker": ("a BANDIT TRACKER: a lean young man, sharp-faced, dark hair, in dark leathers and a soot-grey hooded scarf (hood down), a longknife at the hip, a small bow across the back, muddy wrapped boots; hands resting near the knife. Mood: cagey, quick.", "soot grey, dark leather, dull steel"),
    "npc_scholar_a": ("an elderly SCHOLAR: a small stooped old man in a long dark-blue scholar's robe with a plain grey mantle, a flat wool cap, a bundle of scrolls under one arm and a quill case at the belt, soft indoor shoes. Mood: absent, kindly.", "dark blue wool, grey, parchment"),
    "npc_scholar_b": ("a young SCHOLAR: a woman in her twenties in a plain dark-green robe with a leather satchel of books slung across the chest, ink-stained fingers, hair pinned up, small brass loupe on a cord. Mood: eager, precise.", "dark green wool, brown leather, brass"),
    "npc_royal_archer": ("a ROYAL ARCHER of the fallen crown: a woman soldier in a faded crimson-and-grey tabard over a leather jerkin, a longbow held upright at her side, a quiver at the hip, a steel skullcap, wrapped forearms, boots. Mood: disciplined, tired.", "faded crimson, grey, dark leather, dull steel"),
    "npc_elder2": ("a VILLAGE ELDER: an old man with a long white beard, a heavy dark-grey shawl over a brown wool robe, a gnarled walking staff, a leather cord with a small wooden token at the neck. Mood: grave, steady.", "dark grey, brown wool, ash-white beard"),
}

NPC_BRIEF = """Generate ONE production pixel-art NPC sprite for the existing dark-fantasy game Crownless.

STYLE BENCHMARK (the three attached reference images 1_ref_archivist_lene.png, 2_ref_clerk_voss.png, 3_ref_aldric.png are the quality/style/perspective standard, NOT the design):
- same low top-down, south-facing, full-body pixel-art perspective, feet at the bottom;
- same grounded adult proportions (roughly 7 heads tall, no chibi, no heroic bulk);
- same restrained dark-fantasy palette, painterly pixel shading, crisp readable silhouette, clear material definition;
- same framing: ONE centered standing character filling most of the canvas height, on a FLAT BRIGHT GREEN chroma-key background (pure #00FF00), nothing else in frame.

CHARACTER (design contract; do not improvise beyond it): {desc}
Palette anchor: {pal}. Everything else muted.

NEGATIVES (hard): no bright saturated colours, no gold trim, no glowing eyes, no magic effects or particles, no scenery, no ground plane, no cast shadow, no drop shadow under the feet, no text, no border, no second figure, no cropping of the head or boots.

Output size: 1024x1024, PNG. Save the PNG to exactly this path: {out}/{name}.png
Then reply with one line describing the figure you drew (hair, cloak colour, held items).
"""

MILL_BRIEF = """Generate ONE image and save it, then stop.

Image: a small country MILL for a top-down dark-fantasy action RPG — a squat round stone building with a domed slate roof and a short chimney, a bright BLUE painted wooden door (the one splash of colour; the story calls it "the blue door"), a wooden waterwheel on its LEFT side, moss on the lower stones. Painterly pixel-art in the exact style of the attached reference building 1_style_cottage_a.png (same low top-down three-quarter view, same shading and detail density, muted palette, no hard black outlines). The building fills most of the canvas, centred, seen from the same angle as the reference, on a flat solid pure-green (#00FF00) background. No ground plane, no cast shadow, no people, no text, no frame. 1024x1024.

Save the PNG to exactly this path: {out}/mill.png
Then reply with one line confirming the blue door and the waterwheel side.
"""


def main():
    root = sys.argv[1]
    for name, (desc, pal) in NPCS.items():
        stage = os.path.join(root, name)
        refs = os.path.join(stage, "refs")
        os.makedirs(refs, exist_ok=True)
        for i, r in enumerate(ROSTER, 1):
            shutil.copy(os.path.join(SPR, r + ".png"), os.path.join(refs, "%d_ref_%s.png" % (i, r)))
        with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
            f.write(NPC_BRIEF.format(desc=desc, pal=pal, out=stage.replace("\\", "/"), name=name))
    stage = os.path.join(root, "mill")
    refs = os.path.join(stage, "refs")
    os.makedirs(refs, exist_ok=True)
    shutil.copy(os.path.join(SPR, "cottage_a.png"), os.path.join(refs, "1_style_cottage_a.png"))
    with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
        f.write(MILL_BRIEF.format(out=stage.replace("\\", "/")))
    names = list(NPCS) + ["mill"]
    open(os.path.join(root, "stages.txt"), "w").write(",".join(os.path.join(root, n) for n in names))
    print("stages:", len(names))


if __name__ == "__main__":
    main()
