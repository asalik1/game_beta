#!/usr/bin/env python
"""Install one Act 1 boss's built Codex strips into game/assets/sprites and
archive its masters/briefs/QA under art_src/bosses_codex_wave1/<sprite>/.

Non-destructive: the idle installs as <sprite>_anim_codex.png (wired via
Art.BOSS_IDLE_STRIP_BASE), so the legacy <sprite>_anim.png and directional
PixelLab sheets stay in the tree. Clip strips are new <sprite>_<clip>.png files.

Usage: python tools/art/install_act1_boss.py <boss_kind> <staging_root> [clip ...]
"""
import os, sys, shutil, glob
sys.path.insert(0, os.path.dirname(__file__))
from act1_brief_lib import BOSSES
from build_act1_boss import CLIPS

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPR = os.path.join(REPO, "game", "assets", "sprites")


def main():
    boss, root = sys.argv[1], sys.argv[2]
    clips = sys.argv[3:] or CLIPS[boss].split()
    sprite = BOSSES[boss][0]
    bdir = os.path.join(root, boss)
    built = os.path.join(bdir, "built")
    arch = os.path.join(REPO, "art_src", "bosses_codex_wave1", sprite)
    os.makedirs(arch, exist_ok=True)
    n = 0
    for clip in clips:
        if clip == "idle":
            src = os.path.join(built, f"{sprite}_anim.png")
            dst = os.path.join(SPR, f"{sprite}_anim_codex.png")
        else:
            src = os.path.join(built, f"{sprite}_{clip}.png")
            dst = os.path.join(SPR, f"{sprite}_{clip}.png")
        if not os.path.exists(src):
            print(f"  SKIP {clip}: not built")
            continue
        shutil.copy(src, dst)
        n += 1
        # archive the keyed master + brief
        for m in glob.glob(os.path.join(bdir, clip, "*_keyed.png")):
            shutil.copy(m, os.path.join(arch, os.path.basename(m)))
        b = os.path.join(bdir, clip, "codex_brief.txt")
        if os.path.exists(b):
            shutil.copy(b, os.path.join(arch, f"{clip}_brief.txt"))
    for extra in ("ALL_qa.png",):
        p = os.path.join(bdir, extra)
        if os.path.exists(p):
            shutil.copy(p, os.path.join(arch, extra))
    print(f"installed {sprite}: {n} strips -> game/assets/sprites, archived under {arch}")


if __name__ == "__main__":
    main()
