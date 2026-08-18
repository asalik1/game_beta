"""Batch-C post-processing: turn vetted Codex ImageGen masters (1024x1024 on
#00FF00) into runtime sprites.

  npc_* (wanderer archetypes) — Scholar Ivo recipe (art_src/npcs/scholar_ivo/
  build_scholar_ivo.py): key the green, tight-crop the alpha body, LANCZOS to
  BODY_H 223 on a transparent 256x256 canvas with the feet at FEET_Y 238, write
  <name>.png + <name>_anim.png (single-frame idle, like every named NPC).
  The 30-33px legacy _anim/_walk strips are backed up beside the result and the
  _walk strip is removed (a 33px walk beside a 223px idle fails verify_art's
  clip-vs-idle body-scale gate; no NPC placement path plays it — WANDERERS stand).
  Add each new name to Balance.NPC_HEIGHT_BY_SPRITE + NPC_BODY_TARGETS (52.0).

  mill — a BUILDING hotspot drawn through _make_npc: key, crop, LANCZOS to
  MILL_W wide, write mill.png (Art.tex override of the 16px procedural grid).
  Its world size comes from Balance.NPC_HEIGHT_BY_SPRITE["mill"].

  python build_npcs.py <stage_root> [--install] [name ...]
"""
import os, shutil, sys
from PIL import Image, ImageEnhance

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SPR, TOOLS_ART  # noqa: E402
sys.path.insert(0, TOOLS_ART)
import install_prop_hires as iph  # noqa: E402

NPCS = ["npc_hunter", "npc_wanderer", "npc_villager_f", "npc_villager_m", "npc_bandit_tracker",
        "npc_scholar_a", "npc_scholar_b", "npc_royal_archer", "npc_elder2"]
CANVAS, BODY_H, FEET_Y = 256, 223, 238
MILL_W = 384


def keyed(root: str, name: str) -> Image.Image:
    src = os.path.join(root, name, name + ".png")
    im = iph.ensure_alpha(Image.open(src).convert("RGBA"))
    # same tone-match as the prop lanes: the ImageGen masters run a touch hot
    rgb = ImageEnhance.Color(im.convert("RGB")).enhance(0.9)
    im = Image.merge("RGBA", (*rgb.split(), im.getchannel("A")))
    bb = im.getbbox()
    if bb is None:
        raise SystemExit(name + ": fully transparent after keying")
    return im.crop(bb)


def build_npc(root: str, name: str) -> Image.Image:
    body = keyed(root, name)
    s = BODY_H / body.height
    body = body.resize((max(1, round(body.width * s)), BODY_H), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(body, ((CANVAS - body.width) // 2, FEET_Y - BODY_H))
    return canvas


def build_mill(root: str) -> Image.Image:
    body = keyed(root, "mill")
    s = MILL_W / body.width
    return body.resize((MILL_W, max(1, round(body.height * s))), Image.LANCZOS)


def backup(root: str, name: str) -> None:
    bdir = os.path.join(root, name, "_backup")
    os.makedirs(bdir, exist_ok=True)
    for suf in ("", "_anim", "_walk"):
        p = os.path.join(SPR, name + suf + ".png")
        if os.path.exists(p):
            shutil.copy2(p, os.path.join(bdir, name + suf + ".png"))


def main():
    root = sys.argv[1]
    install = "--install" in sys.argv
    only = [a for a in sys.argv[2:] if not a.startswith("--")]
    out_dir = os.path.join(root, "_out")
    os.makedirs(out_dir, exist_ok=True)
    todo = [n for n in NPCS + ["mill"] if not only or n in only]
    for name in todo:
        if not os.path.exists(os.path.join(root, name, name + ".png")):
            print("MISSING result:", name)
            continue
        if name == "mill":
            im = build_mill(root)
            outs = {"mill.png": im}
        else:
            im = build_npc(root, name)
            outs = {name + ".png": im, name + "_anim.png": im}
        for fn, img in outs.items():
            img.save(os.path.join(out_dir, fn), optimize=True)
        print(name, "built", im.size, "bbox", im.getbbox())
        if install:
            backup(root, name)
            for fn, img in outs.items():
                img.save(os.path.join(SPR, fn), optimize=True)
                print("  installed", fn)
            if name != "mill":
                walk = os.path.join(SPR, name + "_walk.png")
                if os.path.exists(walk):
                    os.remove(walk)
                    if os.path.exists(walk + ".import"):
                        os.remove(walk + ".import")
                    print("  removed legacy", os.path.basename(walk))
    print("done" + (" (installed — now sync_mobile.py --apply)" if install else " (staged in _out only)"))


if __name__ == "__main__":
    main()
