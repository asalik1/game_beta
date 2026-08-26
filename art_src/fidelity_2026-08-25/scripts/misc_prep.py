#!/usr/bin/env python3
"""Misc fidelity stages: critters (all 7), NPC bodies/props needing regen
(elder, caged_beastkin, mill, bones, rock), choir_censer. Faithful re-render
briefs; subject ref = current asset (identity), NEAREST-upscaled so the pixels
read. Green key for creature sheets (established mob contract), transparent
for props/NPCs."""
import sys
from pathlib import Path
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
SPR = REPO / "game" / "assets" / "sprites"
HERE = Path(__file__).parent
STAGES = HERE / "misc_stages"

CRITTERS = {  # name -> (current strip, frames, target cell)
    "hawk": 256, "crow": 128, "bird": 128, "bird_perched": 128,
    "bat": 128, "butterfly": 96, "dragonfly": 128,
}

CRITTER_BRIEF = """Repaint an EXISTING tiny game creature's 4-frame animation strip at higher resolution.
This is a FIDELITY UPGRADE, not a redesign.

The reference image is the CURRENT in-game strip (4 frames left to right, heavily upscaled so
you can read the pixels): reproduce the SAME creature, SAME colors, SAME 4 poses in the SAME
order (for a flyer: the wingbeat cycle; for a perched bird: the same subtle pose changes).

Generate ONE image: a single horizontal ROW of EXACTLY 4 frames on a flat solid #00ff00 green
background with clear gutters — each frame one complete creature, same size, same position
height in its cell, top-down three-quarter game view like the reference. Crisp detail, muted
natural palette, no outlines, NO shadow.

Save the image to disk at the exact path {out} and stop.
"""

NPCS = {
    # name -> (kind, note-for-brief)
    "elder": ("npc", "an elderly village elder, standing, front-facing south like the reference"),
    "caged_beastkin": ("npc", "a caged beastkin prisoner — keep the cage bars, posture and palette exactly"),
    "mill": ("building", "a working windmill building; keep footprint, roof, sail angles and palette exactly"),
    "bones": ("prop", "a small scatter of old bones on the ground; keep the exact arrangement"),
    "rock": ("prop", "a mineable rock; keep the exact shape and palette"),
}

NPC_BRIEF = """Repaint an EXISTING game asset at high resolution. This is a FIDELITY UPGRADE, not a redesign.

The reference image is the CURRENT in-game asset ({note}): reproduce its exact design,
silhouette, proportions, clothing/materials and palette — the same subject drawn with more
painterly detail. House style: painterly, soft-shaded, NO black outlines, muted palette,
top-down three-quarter view, light from the top-left.

Generate ONE image: the single subject, centered, filling most of the canvas, on a TRANSPARENT
background (real alpha). NO text, NO ground patch, NO extra characters or objects.

Save the image to disk at the exact path {out} and stop.
"""

CENSER_BRIEF = """Repaint an EXISTING game object's idle at high resolution as a 4-frame animation.
This is a FIDELITY UPGRADE, not a redesign.

The reference image is the CURRENT in-game asset: a blighted ritual censer (a standing incense
burner the Hollow Choir plants in boss arenas — "scenery that bleeds"). Reproduce its exact
silhouette, design and palette.

Generate ONE image: a 2x2 grid of EXACTLY 4 cells on a flat solid #00ff00 green background with
clear gutters — each cell the COMPLETE censer at the same size and position:
- Cell 1: the censer exactly as the reference.
- Cells 2-4: ONLY the incense glow and smoke wisps change (a slow smoulder-pulse loop); the
  censer body, chains and base stay PIXEL-IDENTICAL across all 4 cells, same baseline.
Painterly dark-fantasy, muted palette, NO outlines, NO shadow.

Save the single image to disk at the exact path {out} and stop.
"""

def stage_one(name: str, brief: str, src: Path, upscale: int) -> str:
    stage = STAGES / name
    refs = stage / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    im = Image.open(src).convert("RGBA")
    im.resize((im.width * upscale, im.height * upscale), Image.Resampling.NEAREST).save(
        refs / f"1_subject_{src.stem}.png")
    out = stage / f"{name}_master.png"
    (stage / "codex_brief.txt").write_text(brief.format(out=str(out)), encoding="utf-8")
    return str(stage)

def main() -> int:
    only = set(sys.argv[1:])
    STAGES.mkdir(exist_ok=True)
    names = []
    for name in CRITTERS:
        if only and name not in only: continue
        names.append(stage_one(f"critter_{name}", CRITTER_BRIEF,
                               SPR / f"critter_{name}.png", 6))
    for name, (_kind, note) in NPCS.items():
        if only and name not in only: continue
        brief = NPC_BRIEF.replace("{note}", note)
        names.append(stage_one(name, brief, SPR / f"{name}.png", 3))
    if not only or "choir_censer" in only:
        names.append(stage_one("choir_censer", CENSER_BRIEF, SPR / "choir_censer.png", 6))
    (STAGES / "stages.txt").write_text("\n".join(names) + "\n", encoding="utf-8")
    print(f"staged {len(names)} briefs -> {STAGES}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
