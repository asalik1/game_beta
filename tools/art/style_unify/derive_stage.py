"""After an animated prop's new STATIC is installed, rebuild <name>_anim.png from
it with tools/art/derive_prop_anim.py — same frame count as the strip it
replaces (anim_info() reads the same shape, game + mobile). Amplitudes are LOW
on purpose (CODING_GUIDELINES §40c: glows <= 10-12%, fire <= 25%). Rigid
furnaces use pulse (colour-only, zero silhouette drift — the autotest
four-frame contract checks baseline + centre).

  python derive_stage.py [name ...]      # default: every name in PLAN
"""
import os, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import REPO  # noqa: E402

PLAN = {
    # batch B (2026-08-18)
    "castle_banner": ("wave", 4, 0.35),
    "station_alchemy_t1": ("pulse", 4, 0.10),
    "station_alchemy_t2": ("pulse", 4, 0.10),
    "hideout_firepit": ("flicker", 4, 0.22),
    "forge_hearth": ("flicker", 4, 0.22),
    "flame": ("flicker", 4, 0.20),
    "cook_pan": ("shimmer", 12, 0.20),
    "node_crystal": ("pulse", 4, 0.08),
    # batch D — all six are in autotest's rigid four-frame contract
    "camp_furnace": ("pulse", 4, 0.12),
    "forge_brazier": ("pulse", 4, 0.12),
    "forge_cauldron": ("pulse", 4, 0.12),
    "station_furnace_t1": ("pulse", 4, 0.12),
    "station_furnace_t2": ("pulse", 4, 0.12),
    "station_furnace_t3": ("pulse", 4, 0.12),
}
only = set(sys.argv[1:])
for name, (motion, frames, amp) in PLAN.items():
    if only and name not in only:
        continue
    r = subprocess.run([sys.executable, os.path.join(REPO, "tools", "art", "derive_prop_anim.py"), name,
                        "--motion", motion, "--frames", str(frames), "--amp", str(amp)],
                       capture_output=True, text=True, cwd=REPO)
    tail = (r.stdout.strip().splitlines() or [""])[-1]
    print(name, motion, frames, "->", tail if r.returncode == 0 else ("ERR " + r.stderr.strip()[-200:]))
