#!/usr/bin/env python3
"""Wave B: death-regen briefs for the 17 under-bar mobs (+ banshee attack —
the one attack with no master). Refs: the NEW 256 idle (identity authority —
staged or installed) + the OLD death strip (pose-sequence authority).
Green-key 2x2 contract, same as the idle wave."""
import sys
from pathlib import Path
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
SPR = REPO / "game" / "assets" / "sprites"
HERE = Path(__file__).parent
STAGES = HERE / "death_stages"
M2 = HERE / "m2_staged"

MOBS = ["mummy", "mummy_mage", "static_caller", "skeleton_mage", "skeleton_warrior",
        "null_acolyte", "elf_druid", "bandit_scout", "elf_ranger", "orc_rogue",
        "royal_knight", "orc", "fungus_long", "vow_sentinel", "fungus_heavy",
        "banshee", "stone_broken"]

DEATH_BRIEF = """Repaint an EXISTING game monster's 4-frame DEATH animation at high resolution.
This is a FIDELITY UPGRADE, not a redesign.

Reference image 1 is the creature's CURRENT hi-res idle strip: the authority for its design,
gear, colors and level of detail. Reference image 2 is the CURRENT low-res death strip (4
frames left to right): the authority for the death MOTION — reproduce the same 4-stage
collapse (same direction of fall, same final resting pose) with the creature from reference 1.

Generate ONE image: a 2x2 grid of EXACTLY 4 complete figures on a flat solid #00ff00 green
background with clear gutters (no figure touches a cell edge), reading in order top-left,
top-right, bottom-left, bottom-right = death frames 1-4. Same creature and gear in every cell,
same scale; the ground line stays constant so the body falls TO the same baseline. Crisp
dark-fantasy detail matching reference 1. NO shadow, NO blood pools beyond what reference 2
itself shows.

Save the single image to disk at the exact path {out} and stop.
"""

ATTACK_BRIEF = """Repaint an EXISTING game monster's 4-frame ATTACK animation at high resolution.
This is a FIDELITY UPGRADE, not a redesign.

Reference image 1 is the creature's CURRENT hi-res idle strip: the authority for its design and
detail level. Reference image 2 is the CURRENT low-res attack strip (4 frames left to right):
the authority for the attack MOTION — reproduce the same ready / wind-up / strike /
follow-through with the creature from reference 1, striking in the SAME direction.

Generate ONE image: a 2x2 grid of EXACTLY 4 complete figures on a flat solid #00ff00 green
background with clear gutters, reading top-left, top-right, bottom-left, bottom-right = attack
frames 1-4. Same creature and gear in every cell, same scale, feet on a constant baseline.
Crisp dark-fantasy detail matching reference 1. NO shadow, NO projectiles baked into the art.

Save the single image to disk at the exact path {out} and stop.
"""

def new_idle(mob: str) -> Path:
    for p in (M2 / f"{mob}_anim.png", SPR / f"{mob}_anim.png"):
        if p.exists():
            return p
    raise FileNotFoundError(mob)

def stage(name: str, brief: str, ref1: Path, ref2: Path) -> str:
    st = STAGES / name
    refs = st / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    Image.open(ref1).convert("RGBA").save(refs / f"1_idle_{ref1.stem}.png")
    im = Image.open(ref2).convert("RGBA")
    im.resize((im.width * 2, im.height * 2), Image.Resampling.NEAREST).save(
        refs / f"2_motion_{ref2.stem}.png")
    out = st / f"{name}_master.png"
    (st / "codex_brief.txt").write_text(brief.format(out=str(out)), encoding="utf-8")
    return str(st)

def main() -> int:
    only = set(sys.argv[1:])
    STAGES.mkdir(exist_ok=True)
    names = []
    for mob in MOBS:
        if only and mob not in only:
            continue
        # old death from git HEAD-equivalent: current file may already be the
        # x4/3 upscale — fine as a pose ref either way.
        names.append(stage(f"{mob}_death", DEATH_BRIEF, new_idle(mob),
                           SPR / f"{mob}_death.png"))
    if not only or "banshee" in only:
        names.append(stage("banshee_attack", ATTACK_BRIEF, new_idle("banshee"),
                           SPR / "banshee_attack.png"))
    (STAGES / "stages.txt").write_text("\n".join(names) + "\n", encoding="utf-8")
    print(f"staged {len(names)} wave-B briefs -> {STAGES}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
