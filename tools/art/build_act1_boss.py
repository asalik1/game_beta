#!/usr/bin/env python
"""Build all of one Act 1 boss's Codex strips from its generated 2x2 masters.

Reads the keyed masters under <staging>/<boss>/<clip>/<clip>_master_2x2_v1*.png,
builds the idle self-referentially, then every other clip against that idle
(front-facing preset: --anchor bbox --scale-ref area --valign hem), writes the
finished strips to <staging>/<boss>/built/<sprite>_<clip>.png, and a combined
contact sheet <staging>/<boss>/ALL_qa.png for review. Installs nothing.

Usage: python tools/art/build_act1_boss.py <boss_kind> <staging_root> [clip ...]
       (clips default to the boss's full Act-1 list)
"""
import os, sys, subprocess, glob
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from act1_brief_lib import BOSSES

CLIPS = {
    "vargoth": "idle attack enrage slam blade",
    "stormwarden": "idle attack pack storm lash",
    "choirmother": "idle enrage summon bolt cast blink ring",
    "nullwarden": "idle attack enrage beam slam piston",
    "sexton": "idle attack summon slam surface",
    "vess": "idle enrage ring blink bolt wail",
    "saint_varo": "idle attack enrage slam blade summon toll",
    "forgemistress": "idle attack throw lash quench",
    "ashpriest": "idle enrage rain bolt summon verdict",
    "whitepelt": "idle attack pack slam melee charge",
    "icebound": "idle enrage bolt blink freeze beam",
    "sleepkeeper": "idle enrage bolt freeze hymn summon",
    "auroch": "idle attack melee slam charge",
    "gardener": "idle enrage bolt summon lash",
    "curetwisted": "idle ring bolt stab throw slam shift",
    "veyx": "idle enrage ring storm arc summon",
    "echo": "idle attack enrage blink throw split",
    "stormmouth": "idle enrage cast bolt",
}
TOOL = os.path.join(os.path.dirname(__file__), "build_codex_2x2_strip.py")


def keyed(stage_clip):
    ks = glob.glob(os.path.join(stage_clip, "*_keyed.png"))
    if ks:
        return ks[0]
    ms = glob.glob(os.path.join(stage_clip, "*_master_2x2_v1.png"))
    return ms[0] if ms else None


def build(master, out, ref, anchor="bbox", extra=None, keyflag=False):
    cmd = ["python", TOOL, master, "--out", out, "--anchor", anchor,
           "--scale-ref", "area", "--scale-frame", "1", "--valign", "hem"]
    if ref == "self":
        cmd.append("--self")
    else:
        cmd += ["--ref-idle", ref]
    if keyflag:
        cmd.append("--key")
    if extra:
        cmd += extra
    r = subprocess.run(cmd, capture_output=True, text=True)
    ok = os.path.exists(out)
    tag = [l for l in (r.stdout + r.stderr).splitlines() if "FAIL" in l or "grown" in l or "seams" in l]
    return ok, tag


def main():
    boss, root = sys.argv[1], sys.argv[2]
    clips = sys.argv[3:] or CLIPS[boss].split()
    sprite = BOSSES[boss][0]
    bdir = os.path.join(root, boss)
    built = os.path.join(bdir, "built")
    os.makedirs(built, exist_ok=True)
    idle_out = os.path.join(built, f"{sprite}_anim.png")
    results = {}
    # idle first (self reference)
    if "idle" in clips:
        m = keyed(os.path.join(bdir, "idle"))
        ok, tag = build(m, idle_out, "self") if m else (False, ["no master"])
        results["idle"] = ok
        print(f"  idle: {'ok' if ok else 'FAIL'} {tag}")
    ref = idle_out if os.path.exists(idle_out) else os.path.join(
        "game/assets/sprites", f"{sprite}_anim.png")
    for clip in clips:
        if clip == "idle":
            continue
        m = keyed(os.path.join(bdir, clip))
        if not m:
            print(f"  {clip}: FAIL (no master)")
            results[clip] = False
            continue
        anchor = "bbox"
        extra = ["--valign", "rows"] if clip in ("leap",) else None
        out = os.path.join(built, f"{sprite}_{clip}.png")
        ok, tag = build(m, out, ref, anchor, extra)
        results[clip] = ok
        print(f"  {clip}: {'ok' if ok else 'FAIL'} {tag}")
    # combined contact sheet: one row per clip, 4 frames scaled to 150px tall
    rows = []
    for clip in clips:
        p = idle_out if clip == "idle" else os.path.join(built, f"{sprite}_{clip}.png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        c = im.height
        sc = 150 / c
        rows.append((clip, im.resize((int(im.width * sc), 150), Image.LANCZOS)))
    if rows:
        W = max(r[1].width for r in rows) + 70
        H = sum(r[1].height + 6 for r in rows)
        from PIL import ImageDraw
        cv = Image.new("RGBA", (W, H), (40, 40, 40, 255))
        d = ImageDraw.Draw(cv)
        y = 0
        for clip, im in rows:
            cv.alpha_composite(im, (70, y))
            d.text((4, y + 60), clip, fill=(240, 240, 240, 255))
            y += im.height + 6
        cv.save(os.path.join(bdir, "ALL_qa.png"))
        print(f"  wrote {bdir}/ALL_qa.png")
    print(f"DONE {boss}: {sum(results.values())}/{len(results)} built")


if __name__ == "__main__":
    main()
