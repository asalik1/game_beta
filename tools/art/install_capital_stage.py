#!/usr/bin/env python
"""Install vetted CAPITAL kit repaints from a style-unify stage root
(tools/art/style_unify/make_capital_briefs.py) under the capital's asset
contracts (autotest "capital fire structures" / tight-crop / water strips):

  1. key the flat #00FF00 field + despill (install_prop_hires.ensure_alpha/despill)
  2. tone-match: -14 % saturation (install_stage.py's recipe: gens come back
     hotter than the in-game-judged art)
  3. TIGHT-CROP to the alpha bbox (a padded export breaks colliders, hotspot
     stand-points, y-sort, codex portraits and portal piers -- autotest gate)
  4. size: keep the gen's detail up to FIDELITY_X * the authored world width
     (Terrains.STRUCTURES "w"; passed via --render-w csv name,width) -- never
     upscale a smaller gen
  5. write game/assets/sprites/<name>.png (backup beside the stage result)
  6. re-derive the 4-frame <name>_anim.png from the NEW static at the
     contract canvas (frame == static) with derive_prop_anim.py: flicker for
     the fire landmarks, shimmer for the two water pieces, swirl for the
     portals -- low amps per CLAUDE.md "Dim, don't strobe"

  python tools/art/install_capital_stage.py <stage_root> --render-w render_w.csv [names]

Then: --import, verify_art.py <names>, audit_prop_anims.py, test_quick, and the
shot rig (shot.bat polish --capital) to LOOK at it in the plaza.
"""
from __future__ import annotations

import argparse
import csv
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import install_prop_hires as iph  # noqa: E402

SPR = ROOT / "game" / "assets" / "sprites"
FIDELITY_X = 2.3

# _anim motion per piece (autotest: every fire landmark needs a 4-frame strip
# whose frame == the static; fountain + wellspring need a water strip).
ANIM = {
    "capital_crown_spire_gate": ("flicker", 0.20), "capital_emberward_gate": ("flicker", 0.20),
    "capital_portal_story": ("swirl", 0.12), "capital_portal_crucible": ("flicker", 0.20),
    "capital_portal_depths": ("swirl", 0.12),
    "capital_ashfire_forge": ("flicker", 0.20), "capital_ashen_tankard": ("flicker", 0.18),
    "capital_wildfang_fangmoot": ("flicker", 0.22), "capital_accord_longhouse": ("flicker", 0.18),
    "capital_sable_hall": ("flicker", 0.18), "capital_watchtower": ("flicker", 0.20),
    "capital_proving_gate": ("flicker", 0.20), "capital_great_hearth": ("flicker", 0.22),
    "capital_crown_fountain": ("shimmer", 0.10), "capital_wellspring": ("shimmer", 0.10),
    # landmark re-masters (2026-09-05, make_landmark_briefs.py): glow pulses are
    # glow-only since the same day; void_rift keeps its rigid-shell swirl; the
    # outfall's sludge shimmers; the torch pillar is an open fire.
    "crystal_spire": ("pulse", 0.10), "storm_conductor": ("pulse", 0.10), "spore_shrine": ("pulse", 0.10),
    "void_rift": ("swirl", 0.12), "sewer_outfall": ("flow", 0.12), "torch_pillar": ("flicker", 0.20),
}


def install_one(name: str, src: Path, render_w: float, stage: Path, dry: bool) -> None:
    im = iph.ensure_alpha(Image.open(src).convert("RGBA"))
    im = iph.despill(im) if hasattr(iph, "despill") else im
    rgb = ImageEnhance.Color(im.convert("RGB")).enhance(0.86)
    im = Image.merge("RGBA", (*rgb.split(), im.getchannel("A")))
    bbox = iph.alpha_bbox(im)
    if bbox is None:
        raise SystemExit(f"{name}: empty after keying")
    im = im.crop(bbox)
    target_w = int(round(render_w * FIDELITY_X))
    if im.width > target_w:
        s = target_w / im.width
        im = im.resize((target_w, max(1, int(round(im.height * s)))), Image.LANCZOS)
    # hard alpha at the rim so the tight-crop gate (used_rect == size) holds and
    # no 1-alpha fringe survives at the edge
    a = im.getchannel("A").point(lambda v: 0 if v < 12 else v)
    im.putalpha(a)
    bbox2 = iph.alpha_bbox(im, thresh=0)
    if bbox2 != (0, 0, im.width, im.height):
        im = im.crop(bbox2)
    dest = SPR / f"{name}.png"
    print(f"{name}: {im.size} (render w {render_w:.0f} -> {im.width / render_w:.2f}x)")
    if dry:
        return
    if dest.exists():
        shutil.copy2(dest, stage / f"_backup_{name}.png")
        anim_old = SPR / f"{name}_anim.png"
        if anim_old.exists():
            shutil.copy2(anim_old, stage / f"_backup_{name}_anim.png")
    tmp = dest.with_name(f".{dest.stem}.tmp.png")
    im.save(tmp, optimize=True)
    tmp.replace(dest)
    if name in ANIM:
        motion, amp = ANIM[name]
        cmd = [sys.executable, str(ROOT / "tools" / "art" / "derive_prop_anim.py"), name,
               "--motion", motion, "--frames", "4", "--amp", str(amp), "--no-mobile"]
        print("  ", " ".join(cmd[1:]))
        subprocess.run(cmd, check=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("--render-w", required=True, help="csv name,width (Terrains.STRUCTURES w)")
    ap.add_argument("names", nargs="*")
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()
    root = Path(args.stage_root)
    rw = {}
    with open(args.render_w, newline="") as f:
        for row in csv.reader(f):
            if len(row) >= 2 and row[0] != "name":
                rw[row[0]] = float(row[1])
    names = args.names or sorted(p.name for p in root.iterdir() if (p / f"{p.name}.png").exists())
    done, missing = [], []
    for name in names:
        src = root / name / f"{name}.png"
        if not src.exists():
            missing.append(name)
            continue
        if name not in rw:
            raise SystemExit(f"no render width for {name} in {args.render_w}")
        install_one(name, src, rw[name], root / name, args.dry)
        done.append(name)
    print("installed:", done)
    print("missing:", missing)
    return 0


if __name__ == "__main__":
    sys.exit(main())
