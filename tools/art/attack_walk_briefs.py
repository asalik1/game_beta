#!/usr/bin/env python
"""FIRE-ON-MOVE (`<base>_attack_walk[_b]_<dir>`) briefs for the BASE classes.

`player.gd`'s walk_fire plays a walk cycle that fires the basic mid-stride, so
spamming a low-cooldown ranged basic WHILE MOVING does not lock the standing
pose sliding over the floor. It is art-driven: no strip, no feature. As of
2026-09-03 every one of the 72 attack_walk PNGs in the tree lives under
`skins/elite/` -- the six BASE classes ship none, so the feature has been dark
for every default character since it shipped.

THE TECHNIQUE (CLAUDE.md, owner 2026-08-23 -- the one that finally worked):
it is the WALK clip plus a firing arm. Do NOT author a walk from scratch; a
from-scratch brief, however detailed the storyboard, kept gliding or failing to
cross the legs. Hand over the character's OWN `<base>_walk_<dir>` strip and say
"reproduce this exact walk, change ONLY the free hand". Keep the brief SHORT --
the walk reference IS the leg specification.

    python tools/art/attack_walk_briefs.py <stage_root> [--classes mage,warlock] [--b]

Per CLAUDE.md's manifest the feature is wanted by the ranged spammables only:
mage Firebolt, warlock Shadowbolt, archer Quick Shot (a1) and assassin Fan of
Knives (a3). The archer gets NO `_b` variant (a bow draw has one proper form).
Author S/E/N; the installer copies E to SE/NE and mirrors it for W/NW/SW, and
flat = S.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
GREEN = (0, 255, 0, 255)

ROBE = (
    "- The robe stays CLOSED and floor-length: no slit, no exposed legs, no bare\n"
    "  skin. The walk reads through the BOOTS alternating below the hem and the\n"
    "  hem swaying -- exactly as reference 1 shows it."
)
OUTFIT = (
    "- The outfit stays exactly as reference 1 shows it: same cloak/coat length,\n"
    "  same straps and buckles in the same places, no bare skin the reference\n"
    "  does not have."
)

# class -> (identity words, PRIMARY fire motion, _b motion or None, garment clause)
CLASSES = {
    "mage": (
        "a slender woman in a deep-blue hooded mage's robe with gold trim and a gold sash, "
        "a long dark staff with a glowing blue-white crystal head held in one hand, "
        "dark boots below a CLOSED floor-length hem",
        "the FREE hand (not the staff hand) thrusts forward at chest height, palm open, "
        "as if pushing a bolt away",
        "the FREE hand sweeps upward in a rising flick, fingers spread, ending above the "
        "shoulder -- keep it clearly separate from the staff hand so the two never read as one",
        ROBE,
    ),
    "warlock": (
        "a gaunt man in a heavy black hooded robe with a gold-edged collar and a red gem clasp, "
        "a small floating flaming skull companion beside his shoulder, "
        "dark boots below a CLOSED floor-length hem",
        "the FREE hand thrusts forward at chest height, palm open and fingers splayed",
        "BOTH hands shove forward together at chest height, palms out",
        ROBE,
    ),
    "archer": (
        "a woman in a green hooded cloak over brown leather armour, a quiver on her back, "
        "a wooden recurve bow held in one hand, dark boots",
        "the bow comes up and the free hand draws the string back to the cheek and releases -- "
        "NO arrow is drawn on the sprite",
        None,   # a bow draw has ONE proper form (owner 2026-08-23)
        OUTFIT,
    ),
    "assassin": (
        "a lean hooded figure in a dark layered coat with leather straps and buckles, "
        "a dagger at the belt, dark boots",
        "the free hand throws a knife overhand, arm coming over the shoulder and snapping "
        "forward -- NO knife is drawn in the air",
        "the free hand flicks a knife sidearm, arm sweeping low across the body -- "
        "NO knife is drawn in the air",
        OUTFIT,
    ),
}

VIEW = {"s": "toward the viewer", "e": "in profile, facing RIGHT",
        "n": "away from the viewer (back to camera)"}


def walk_row(base: str, facing: str, out: Path) -> int:
    """The character's own walk strip as a labelled row on flat green — the leg spec."""
    for cand in [f"{base}_walk_{facing}", f"{base}_walk"]:
        p = SPR / f"{cand}.png"
        if not p.exists():
            continue
        im = Image.open(p).convert("RGBA")
        c = im.height
        n = max(1, im.width // c)
        a = np.array(im)[:, :, 3] > 40
        ys = np.nonzero(a)[0]
        top, bot = int(ys.min()), int(ys.max())
        pad = 26
        row = Image.new("RGBA", (n * (c + pad) + pad, (bot - top + 1) + 2 * pad), GREEN)
        for f in range(n):
            row.alpha_composite(im.crop((f * c, top, (f + 1) * c, bot + 1)),
                                (pad + f * (c + pad), pad))
        row.save(out)
        return n
    raise SystemExit(f"no walk strip for {base} {facing}")


BRIEF = """Redraw this EXACT walk cycle (reference 1) with one change: the character fires
its basic attack once during the stride.

Reference 1 is the character's own {n}-frame walk, {view}, frame by frame. Reproduce
it EXACTLY: the same {n} frames, the same leg cycle and stride, the same crossing,
the same garment, the same held equipment in the same hand, the same body height
and width, the same palette. The legs are already correct -- do not redesign them.

THE ONLY CHANGE: {motion}. Spread the motion across the {n} frames so it starts,
peaks around the middle and returns by the end, while the legs keep walking
through their unchanged cycle.

THE CHARACTER (unchanged from reference 1): {ident}.

Hard requirements:
- The feet stay PLANTED on the shared ground line exactly as reference 1 has them;
  the body does not slide sideways within its cell.
{garment}
- Draw NO projectile, arrow, knife, flame, bolt, spark or muzzle flash anywhere.
  The game spawns the projectile itself; anything drawn here would double it.
- Same body height and width in every frame; no frame is a copy of another.

Produce ONE image: a horizontal row of EXACTLY {n} figures, evenly spaced, all feet
on one shared ground line, each body near its cell's horizontal centre, green
margins all round -- no figure touching an image edge or its neighbour. EVERY FIGURE
IS THE SAME SIZE; if they will not fit at full size, make the image WIDER. Flat solid
#00ff00 GREEN background, nothing else in the image.
Generate ONE image and SAVE it to disk at the exact path
{out}
then stop.

In your final message, report for each frame: which leg leads, and where the firing
hand is. Confirm no projectile was drawn and the hem stayed closed.
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("--classes", default="mage,warlock,archer,assassin")
    ap.add_argument("--facings", default="e,s,n")
    ap.add_argument("--b", action="store_true", help="the alternate _b variant instead")
    args = ap.parse_args()
    root = Path(args.stage_root)
    root.mkdir(parents=True, exist_ok=True)
    stages = []
    for base in [c.strip() for c in args.classes.split(",") if c.strip()]:
        ident, prim, alt, garment = CLASSES[base]
        motion = alt if args.b else prim
        if motion is None:
            print(f"skip {base}: no _b variant by design")
            continue
        clip = "attack_walk_b" if args.b else "attack_walk"
        for facing in [f.strip() for f in args.facings.split(",") if f.strip()]:
            stage = root / f"{base}__{clip}__{facing}"
            refs = stage / "refs"
            refs.mkdir(parents=True, exist_ok=True)
            n = walk_row(base, facing, refs / "1_walk.png")
            out = (stage / f"{base}_{clip}_{facing}_row.png").resolve()
            (stage / "codex_brief.txt").write_text(
                BRIEF.format(n=n, view=VIEW[facing], motion=motion, ident=ident,
                             garment=garment, out=out),
                encoding="utf-8")
            (stage / "job.json").write_text(json.dumps(
                {"base": base, "clip": clip, "facing": facing, "frames": n}, indent=1),
                encoding="utf-8")
            stages.append(str(stage.resolve()))
            print(f"stage {base} {clip} {facing} ({n} frames)")
    (root / "stages.txt").write_text("\n".join(stages) + "\n", encoding="utf-8")
    print(f"{len(stages)} stages -> {root / 'stages.txt'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
