"""WALL-FIELD briefs (the wall twin of the floor fields): seamless 128px
top-down wall caps drawn 1:1 by game_world._wall_dress / Art.wall_field.

History: the 2026-08-18 round-2 batch asked for "close-fitted rectangular blocks
in courses" and got uniform brick grids for wallblock / wall_castle / wall_sand /
wall_sewer — the owner flagged the capital's south wall as "cartoonish bricks"
that evening. This brief asks for WEATHERED, IRREGULAR masonry (varied block
sizes, chipped soft edges, low-contrast mortar, faint stains) — a surface, not a
grid. wall_grave / wall_moss / wall_hedge / wall_ice / wall_volcanic / wall_wood
were already organic and keep their round-2 tiles.

  python make_wall_briefs.py <stage_root> [kind ...]
  ...run_codex_batch.ps1 -Stages (Get-Content <stage_root>/stages.txt) -MaxParallel 1 -MinFreeGB 1.3
  python tools/art/install_ground_field.py <kind> <stage_root>/<kind>/<kind>.png --prefix wall_field_ --gamma 0.82   (sand 0.88, ice 0.88, volcanic 0.85)
"""
import os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SPR  # noqa: E402

# kind -> (style ref floor field kind, description, palette words)
JOBS = {
    "wallblock":     ("stone", "the top surface of an old dressed-stone wall: worn grey ashlar of VARIED block sizes and lengths (never a uniform brick grid), soft chipped edges, hairline cracks, faint water stains and a little lichen in a few joints, mortar the same value family as the stone", "cool mid grey, slightly darker joints"),
    "wall_castle":   ("stone", "the top surface of castle masonry: large weathered ashlar blocks of VARIED length in loose courses (never a uniform brick grid), tooling marks, chipped corners, faint soot and damp stains, low-contrast tight mortar", "iron grey, slate shadow"),
    "wall_sand":     ("sand", "the top surface of a sun-bleached sandstone wall: soft-edged blocks of VARIED size worn nearly smooth by wind (never a uniform brick grid), fine grain, faint ochre banding, sand caught in the joints", "warm tan, ochre shadow"),
    "wall_sewer":    ("stone", "the top surface of an old sewer wall: dark irregular stones and half-bricks of VARIED size (never a uniform brick grid), dark grout, wet green-black grime streaks and slime in the low joints", "near-black stone, sickly green grime"),
    "wall_grave":    ("gravedirt", "an old graveyard wall from above: weathered uneven dark grey stones with patches of lichen and moss in the joints", "dark grey, muted green-yellow lichen"),
    "wall_hedge":    ("forest", "a dense clipped hedge seen straight from above: small dark green leaves packed tight, a few twigs showing", "deep green, dark shadow"),
    "wall_ice":      ("snow", "a wall of pale glacial ice from above: translucent blue-white slabs with fine cracks and frost bloom", "pale blue-white, deeper blue cracks"),
    "wall_moss":     ("forest", "an old forest stone wall from above, dark grey stones overgrown with moss cushions and thin creeping roots", "grey-green, mossy green, dark shadow"),
    "wall_volcanic": ("basalt", "black basalt blocks from above with a few thin glowing orange cracks between them, scorched edges", "charcoal black, ember orange"),
    "wall_wood":     ("grass", "a wooden palisade wall seen from above: dark weathered planks laid side by side with visible grain and a few iron nails", "dark walnut brown, iron"),
}

BRIEF = """Generate ONE image and save it, then stop. Do not write any other files, do not run any other commands.

Image: a SEAMLESS, TILEABLE top-down (orthographic, viewed straight from above) painterly pixel-art WALL texture for a dark-fantasy action game — {desc}. It MUST tile seamlessly on all four edges (left edge matches right, top matches bottom).

Reference image 1_style_{ref}.png is one of this game's FLOOR tiles: match its rendering style, softness and pixel density exactly (painterly, soft shading, NO hard black outlines, muted, weathered). Reference image 2_old_{name}.png is the current wall tile this replaces: keep ITS material and colour identity ({pal}) but NOT any regular brick pattern — that pattern is the defect: it reads as a cartoon grid. Blocks vary in size and length, edges are worn and chipped, joints are low-contrast (mortar close in value to the stone), and there is gentle surface variation (stains, wear, a hairline crack) so no two blocks look alike.

Flat even lighting with NO directional light and NO cast shadows, NO props or objects, NO creatures, NO border or frame, NO text — the texture fills the entire frame edge to edge and repeats seamlessly with no single obvious landmark. Muted, slightly desaturated, cohesive. 1024x1024.

Save the PNG to exactly this path: {out}/{name}.png
Then reply with one line confirming it tiles on all four edges and that the blocks are irregular.
"""


def main():
    root = sys.argv[1]
    only = sys.argv[2:]
    stages = []
    for name, (ref, desc, pal) in JOBS.items():
        if only and name not in only:
            continue
        stage = os.path.join(root, name)
        refs = os.path.join(stage, "refs")
        os.makedirs(refs, exist_ok=True)
        shutil.copy(os.path.join(SPR, "ground_field_%s.png" % ref), os.path.join(refs, "1_style_%s.png" % ref))
        cur = os.path.join(SPR, "wall_field_%s.png" % name)
        if not os.path.exists(cur):
            cur = os.path.join(SPR, name + ".png")
        if os.path.exists(cur):
            shutil.copy(cur, os.path.join(refs, "2_old_%s.png" % name))
        with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
            f.write(BRIEF.format(ref=ref, name=name, desc=desc, pal=pal, out=stage.replace("\\", "/")))
        stages.append(stage)
    open(os.path.join(root, "stages.txt"), "w").write(",".join(stages))
    print("stages:", len(stages))


if __name__ == "__main__":
    main()
