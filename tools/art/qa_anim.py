#!/usr/bin/env python
"""Animation-consistency QA for any character (boss / mob / hero).

Catches the class of action-clip bugs `verify_art.py` misses: its ANCHOR gate
is exempted on one-shots ("limbs legitimately move") and its CLIPSCALE uses
bbox HEIGHT, which a raised weapon inflates. We hit both by hand:

  * SLIDE  the BODY shifts sideways across an action's frames (Korrag "shifts to
           make room for his weapon"): the build centred the weapon-inclusive
           bbox, so the body slid as the chain/sword extended.
  * SCALE  the body renders much SMALLER than the idle (Vargoth's blade: frame-1
           silhouette was mostly raised sword, so the body was shrunk to fit) —
           invisible to a bbox-height check because the sword filled the box.
  * JUMP   the action's rest body doesn't sit where the idle's does, so it pops
           sideways the instant the action starts.

The measure that stays robust while a weapon/limb swings: correlate the clip's
own frame-0 TORSO (the middle body band) against every frame by SHAPE, not mass.
A thin sword / chain / trailing cape adds unmatched pixels that lower the match
SCORE but never move the correlation PEAK off the torso — so the peak x is the
body's true position regardless of where the weapon is. (A row-width/centroid
measure fails here: a chain lashed to one side or an arms-up pose widens a row
and drags a centroid, false-flagging a perfectly planted body.) Single-scale,
x-only, at a small work resolution, so an --all sweep is seconds.

Facing-aware (the idle is only front-facing, so it can't judge a back/profile
clip): SLIDE is self-referenced within each facing (frame-0 torso vs the rest);
SCALE is checked only where there IS a same-facing reference — the front (s)
clip's rest body vs the idle, multi-scale — so it stays reliable instead of
guessing across mismatched silhouettes.

TRIAGE, not pass/fail — flags are ranked, eyeball with --montage. A deep crouch
or full lunge can trip SCALE/JUMP legitimately; the note says which.

  python qa_anim.py <sprite>
  python qa_anim.py --all
  python qa_anim.py <sprite> --montage out.png
"""
from __future__ import annotations
import argparse, os, sys
import numpy as np
from PIL import Image

SPR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "sprites"))

THR = 76
WORK = 80               # correlate at this cell resolution (speed)
SLIDE_F = 0.08          # frame-to-frame body-x range across an action (fraction of cell)
JUMP_F = 0.07           # s-facing frame-0 body-x vs the idle body-x
SCALE_LO = 0.80         # s-facing rest body vs the idle body
SCALE_HI = 1.25
MIN_SCORE = 0.45        # a torso match below this is ambiguous (symmetric back,
                        # arms/effect dominating the frame) — don't trust its x
SKIP = {"anim", "walk", "run", "portrait", "splash", "ability", "idle", "death"}
DIRS = {"s", "n", "e", "w", "ne", "nw", "se", "sw"}


def frames(path: str, work=None):
    im = Image.open(path).convert("RGBA")
    c = im.height
    n = max(1, im.width // c)
    out = []
    for i in range(n):
        a = im.crop((i * c, 0, (i + 1) * c, c)).getchannel("A")
        if work:
            a = a.resize((work, work), Image.BILINEAR)
        out.append((np.asarray(a, dtype=np.float32) > THR).astype(np.float32))
    return out, c


def torso_band(mask: np.ndarray):
    """The HEAD+shoulders band (top 6-34% of the body bbox) as a 2D float patch,
    plus (top_y, x0, cx). The head is the most weapon-independent landmark — a
    sword/chain held at the side or extended forward never touches it, so
    matching on it tracks the true body even mid-swing. (A whole-torso template
    catches the chain that crosses the belly and drifts; the head does not.)"""
    ys, xs = np.where(mask > 0)
    if ys.size == 0:
        return None
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    a = y0 + int((y1 - y0) * 0.06)
    b = y0 + int((y1 - y0) * 0.34)
    # crop x to the head/shoulder extent at those rows (not the full-body width)
    band = mask[a:b + 1]
    bxs = np.where(band > 0)[1]
    hx0, hx1 = (bxs.min(), bxs.max()) if bxs.size else (x0, x1)
    return band[:, hx0:hx1 + 1], (a, hx0, (hx0 + hx1) / 2.0)


def _ncc_x(templ: np.ndarray, frame: np.ndarray, y_hint: int, scales=(1.0,)):
    """Best (score, cx_px, scale): slide templ across frame in x (small y band),
    optionally over scales. Shape correlation — unmatched weapon mass lowers the
    score but does not move the peak off the torso."""
    fh, fw = frame.shape
    best = (-2.0, fw / 2.0, 1.0)
    for s in scales:
        th, tw = max(3, int(round(templ.shape[0] * s))), max(3, int(round(templ.shape[1] * s)))
        if th >= fh or tw >= fw:
            continue
        T = np.asarray(Image.fromarray((templ * 255).astype(np.uint8)).resize((tw, th), Image.BILINEAR),
                       dtype=np.float32) / 255.0
        Tz = T - T.mean()
        Tn = float(np.sqrt((Tz * Tz).sum())) + 1e-6
        for dy in range(max(0, y_hint - 3), min(fh - th, y_hint + 3) + 1):
            row = frame[dy:dy + th]
            for dx in range(0, fw - tw + 1):
                win = row[:, dx:dx + tw]
                wz = win - win.mean()
                wn = float(np.sqrt((wz * wz).sum())) + 1e-6
                sc = float((Tz * wz).sum()) / (Tn * wn)
                if sc > best[0]:
                    best = (sc, dx + tw / 2.0, s)
    return best


def sub_characters(sprite: str) -> set[str]:
    """Stems that are their OWN character (have <stem>_anim / _walk) — a clip
    scan on `sprite` must not swallow them (korrag -> korrag_reborn_*)."""
    out = set()
    pre = f"{sprite}_"
    for f in os.listdir(SPR):
        for suf in ("_anim.png", "_anim_codex.png", "_walk.png"):
            if f.startswith(pre) and f.endswith(suf):
                base = f[:-len(suf)]
                if base != sprite:
                    out.add(base)
    return out


def qa_sprite(sprite: str):
    idle_p = os.path.join(SPR, f"{sprite}_anim_codex.png")
    if not os.path.exists(idle_p):
        idle_p = os.path.join(SPR, f"{sprite}_anim.png")
    if not os.path.exists(idle_p):
        return None
    icells, cell = frames(idle_p, WORK)
    itb = torso_band(icells[0])
    if itb is None:
        return None
    idle_templ, (_, _, idle_cx_px) = itb
    idle_cx = idle_cx_px / WORK

    subs = sub_characters(sprite)
    pre = f"{sprite}_"
    clips: dict[str, dict[str, str]] = {}
    for f in os.listdir(SPR):
        if not f.endswith(".png") or not f.startswith(pre):
            continue
        stem = f[len(pre):-4]
        if any(f[:-4] == s or f[:-4].startswith(s + "_") for s in subs):
            continue
        d = "s"
        toks = stem.split("_")
        if len(toks) > 1 and toks[-1] in DIRS:
            d, stem = toks[-1], "_".join(toks[:-1])
        if stem in SKIP or stem == "" or stem.endswith("_codex") or "_walk_codex" in f:
            continue
        clips.setdefault(stem, {})[d] = os.path.join(SPR, f)

    findings = []
    for clip, facings in sorted(clips.items()):
        worst = None
        for d, path in facings.items():
            cells, c = frames(path, WORK)
            if len(cells) < 2:
                continue
            tb = torso_band(cells[0])
            if tb is None:
                continue
            templ, (ty, _, _) = tb
            # SLIDE: self-referenced — frame-0 torso shape-matched into each frame.
            # Only trust frames with a CONFIDENT match (a weak peak on a symmetric
            # back view / an arms-dominated frame is noise, not a real shift).
            xs = []
            for m in cells:
                score, cx_px, _ = _ncc_x(templ, m, ty)
                if score >= MIN_SCORE:
                    xs.append(cx_px / WORK)
            slide = (max(xs) - min(xs)) if len(xs) >= 2 else 0.0
            issues = []
            if slide >= SLIDE_F:
                issues.append(("SLIDE", slide, f"body shifts {slide*100:.0f}% of cell across frames"))
            # SCALE + JUMP only for the front facing (the idle is front-only).
            # The engine draws idle and action at the SAME 16/idle_cell, so the
            # action body must be measured at its ENGINE-proportional size: a
            # grown action cell squished to WORK would look ~0.72x smaller than
            # it renders (this false-flagged every hero attack). Re-load the
            # action frame-0 at (action_cell/idle_cell)*WORK so scale 1.0 == the
            # idle body size, and the NCC best-scale is the TRUE render ratio.
            if d == "s":
                work_a = max(12, round(c / cell * WORK))
                fa = frames(path, work_a)[0][0]
                y_a = int(round(ty / WORK * work_a))
                sc, cx0_px, best_s = _ncc_x(idle_templ, fa, y_a,
                                            scales=(0.68, 0.76, 0.84, 0.92, 1.0, 1.1, 1.22, 1.36))
                if sc > 0.5 and (best_s <= SCALE_LO or best_s >= SCALE_HI):
                    issues.append(("SCALE", abs(best_s - 1), f"rest body {best_s:.2f}x the idle"))
                jump = abs(cx0_px / work_a - idle_cx)
                if jump >= JUMP_F:
                    issues.append(("JUMP", jump, f"rest body {jump*100:.0f}% off the idle position"))
            if issues:
                sev = max(i[1] for i in issues)
                if worst is None or sev > worst[0]:
                    worst = (sev, d, issues)
        if worst:
            findings.append((clip, worst[1], worst[2], worst[0]))
    findings.sort(key=lambda x: -x[3])
    return {"sprite": sprite, "cell": cell, "clips": len(clips), "findings": findings}


def all_sprites():
    out = set()
    for f in os.listdir(SPR):
        if f.endswith("_anim_codex.png"):
            out.add(f[:-len("_anim_codex.png")])
        elif f.endswith("_anim.png"):
            b = f[:-len("_anim.png")]
            if not os.path.exists(os.path.join(SPR, b + "_anim_codex.png")):
                out.add(b)
    return sorted(out)


def montage(sprite: str, res: dict, out_path: str):
    """Render idle + every flagged clip at TRUE ENGINE SCALE (the engine draws
    all action cells at 16/idle_cell, so a cell drawn at cell*K shows the body's
    real relative size) with a centre reference line — a shrunk body reads small,
    a sliding body crosses the line inconsistently. This is the confirm step."""
    from PIL import ImageDraw
    idle = os.path.join(SPR, f"{sprite}_anim_codex.png")
    if not os.path.exists(idle):
        idle = os.path.join(SPR, f"{sprite}_anim.png")
    rows = [("idle", idle)]
    for clip, d, issues, _ in res["findings"][:14]:
        p = os.path.join(SPR, f"{sprite}_{clip}_{d}.png")
        rows.append((f"{clip}/{d} " + ",".join(i[0] for i in issues),
                     p if os.path.exists(p) else os.path.join(SPR, f"{sprite}_{clip}.png")))
    idle_cell = Image.open(idle).height
    biggest = max(Image.open(p).height for _, p in rows)
    K = 150.0 / idle_cell            # idle renders ~150px tall
    rh = int(biggest * K) + 8
    cw = int(idle_cell * K) + 8
    cv = Image.new("RGBA", (180 + cw * 4, rh * len(rows)), (28, 28, 34, 255))
    dr = ImageDraw.Draw(cv)
    for r, (lbl, p) in enumerate(rows):
        im = Image.open(p).convert("RGBA")
        c = im.height
        disp = int(c * K)
        y0 = r * rh
        for i in range(min(4, im.width // c)):
            cell = im.crop((i * c, 0, (i + 1) * c, c)).resize((disp, disp), Image.LANCZOS)
            x0 = 180 + i * cw
            cv.alpha_composite(cell, (x0 + (cw - disp) // 2, y0 + rh - disp - 2))  # bottom-align
            dr.line((x0 + cw // 2, y0, x0 + cw // 2, y0 + rh), fill=(255, 60, 60, 110))
        dr.line((176, y0 + rh - 2, cv.width, y0 + rh - 2), fill=(80, 80, 90, 255))
        dr.text((4, y0 + rh // 2), lbl, fill=(240, 240, 240, 255))
    cv.save(out_path)
    print(f"  wrote montage {out_path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sprite", nargs="?")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--montage")
    args = ap.parse_args()
    targets = all_sprites() if args.all else [args.sprite]
    if targets == [None]:
        ap.error("give a sprite base name or --all")
    total = 0
    for sp in targets:
        res = qa_sprite(sp)
        if res is None:
            if not args.all:
                print(f"{sp}: no idle strip")
            continue
        if res["findings"]:
            total += len(res["findings"])
            print(f"\n{sp} ({res['clips']} action clips):")
            for clip, d, issues, _ in res["findings"]:
                print(f"  {clip}/{d}:  " + "  ".join(f"[{k}] {m}" for k, _, m in issues))
            if args.montage:
                montage(sp, res, args.montage)
        elif not args.all:
            print(f"{sp}: {res['clips']} action clips, all clean")
    if args.all:
        print(f"\n=== {total} flagged clips ===")


if __name__ == "__main__":
    main()
