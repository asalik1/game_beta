#!/usr/bin/env python3
"""M2: idle-regen briefs for the 11 non-robe 192px mobs (no idle masters exist).

Identity anchoring: ref 1 = the CURRENT 192 idle strip (2x NEAREST, the pose +
design authority), ref 2 = the mob's own hi-res walk/attack master (the same
character at 443-732px/frame — the DETAIL authority). Green-key 2x2 contract
(the 08-08 mob-repair pipeline: remove_green + real-gutter split + normalize).
"""
import sys
from pathlib import Path
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
SPR = REPO / "game" / "assets" / "sprites"
SRC = REPO / "art_src" / "Custom" / "MobWalkRepairs_2026-08-08"
HERE = Path(__file__).parent
STAGES = HERE / "mob_stages"

# mob -> hi-res detail master (None = current strips only)
IDLE_TARGETS = {
    "elf_druid": "elf_druid_walk_master.png",
    "bandit_scout": "bandit_scout_attack_master.png",
    "elf_ranger": "elf_ranger_attack_master.png",
    "orc_rogue": "orc_rogue_attack_master.png",
    "royal_knight": "royal_knight_attack_master.png",
    "orc": "orc_attack_master.png",
    "fungus_long": "fungus_long_attack_master.png",
    "vow_sentinel": "vow_sentinel_attack_master.png",
    "fungus_heavy": "fungus_heavy_attack_master.png",
    "banshee": None,
    "stone_broken": None,   # owner-specified legacy design: current strips ARE the identity
}

IDLE_BRIEF = """Repaint an EXISTING game monster's 4-frame breathing idle at high resolution.
This is a FIDELITY UPGRADE, not a redesign.

Reference image 1 is the CURRENT in-game idle strip (4 frames, left to right): it is the
authority for the creature's design, gear, colors, stance and facing — reproduce it EXACTLY.
{detail_line}

Generate ONE image: a 2x2 grid of EXACTLY 4 complete figures on a flat solid #00ff00 green
background, with clear green gutters between the cells (no figure touches a cell edge):
- The 4 cells are the 4 frames of the SAME subtle breathing idle as the reference strip, in
  order (top-left = frame 1's rest pose, then top-right, bottom-left, bottom-right).
- Same creature, same gear and weapon in every cell, same size in every cell, feet planted on
  the same baseline. Motion is BREATHING ONLY: shoulders/chest/cloth move a few pixels; the
  feet never move, the silhouette stays recognizably identical.
- Crisp hi-res dark-fantasy style matching the reference detail level. NO black outlines
  around the figure beyond what the reference art itself has. NO shadow on the ground.

Save the single image to disk at the exact path {out} and stop.
"""

def main() -> int:
    only = set(sys.argv[1:])
    STAGES.mkdir(exist_ok=True)
    names = []
    for name, detail in IDLE_TARGETS.items():
        if only and name not in only:
            continue
        stage = STAGES / f"{name}_idle"
        refs = stage / "refs"
        refs.mkdir(parents=True, exist_ok=True)
        im = Image.open(SPR / f"{name}_anim.png").convert("RGBA")
        im.resize((im.width * 2, im.height * 2), Image.Resampling.NEAREST).save(
            refs / f"1_idle_{name}.png")
        if detail:
            src = SRC / detail
            Image.open(src).convert("RGBA").save(refs / f"2_detail_{detail}")
            detail_line = ("Reference image 2 is the SAME creature at high resolution "
                           "(from its walk/attack art): match THIS level of crisp detail "
                           "and rendering quality.")
        else:
            detail_line = ("Render at crisp high-resolution detail while staying totally "
                           "faithful to the reference design.")
        out = stage / f"{name}_idle_master.png"
        (stage / "codex_brief.txt").write_text(
            IDLE_BRIEF.format(detail_line=detail_line, out=str(out)), encoding="utf-8")
        names.append(str(stage))
    (STAGES / "stages_idle.txt").write_text("\n".join(names) + "\n", encoding="utf-8")
    print(f"staged {len(names)} idle briefs -> {STAGES}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
