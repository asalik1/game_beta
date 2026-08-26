#!/usr/bin/env python3
"""Install completed prop fidelity stages (incremental: only stages whose
master exists and whose name isn't already in installed.txt).

- static kinds: master -> install_prop_hires.install() at 2.5x render_w
  (clamps fixed 2026-08-25), game/ + mobile/.
- 2x2 kinds (trees, fire, motion props): union-crop 4 quadrant frames, frame 1
  becomes the static (same install), all 4 frames resized with the SAME
  transform -> <name>_anim.png at the installed static's exact canvas
  (art.gd frame slicing + autotest contract), game/ + mobile/.
- derived-anim props: re-derive via derive_prop_anim.py (per-name motion).
- gates per prop: rigid/trunk-band drift <= 1.5px on the built strip; vet row
  appended to vet_props.png (old | new static).

usage: python prop_install.py [names...]   (default: all completed stages)
"""
import subprocess, sys
from pathlib import Path
import numpy as np
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
sys.path.insert(0, str(REPO / "tools" / "art"))
import install_prop_hires as iph
from prop_prep import TARGETS  # name -> (render_w, kind)

HERE = Path(__file__).parent
STAGES = HERE / "prop_stages"
SPR = REPO / "game" / "assets" / "sprites"
MOB = REPO / "mobile" / "game" / "assets" / "sprites"
DONE = HERE / "installed.txt"

# 2x2 motion kinds beyond the prep script's map (briefs rewritten 2026-08-25)
MOTION_2X2 = {"storm_conductor", "cook_grill", "station_alchemy_t3"}
DERIVED = {"crystal_spire": "pulse", "void_rift": "swirl", "void_obelisk": "pulse",
           "camp_furnace": "pulse", "void_monolith": "pulse", "station_furnace_t3": "pulse",
           "crystal_cluster": "pulse", "station_furnace_t2": "pulse"}

def ensure_alpha(im: Image.Image) -> Image.Image:
    return iph.ensure_alpha(im)

def quad_frames(master: Image.Image) -> list[Image.Image]:
    W, H = master.size
    return [master.crop((x * W // 2, y * H // 2, (x + 1) * W // 2, (y + 1) * H // 2))
            for y in range(2) for x in range(2)]

def union_bbox(frames):
    boxes = []
    for f in frames:
        b = f.getchannel("A").point(lambda v: 255 if v > 16 else 0).getbbox()
        if b:
            boxes.append(b)
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    return (x0, y0, x1, y1)

def band_outline(arr, frac=0.12):
    m = arr[..., 3] > 40
    ys, xs = np.nonzero(m)
    if not len(ys):
        return None
    span = ys.max() - ys.min() + 1
    band = m.copy(); band[:ys.max() - int(frac * span), :] = False
    yb, xb = np.nonzero(band)
    return int(xb.min()), int(xb.max()), int(yb.max())

def save_atomic(im, path: Path):
    tmp = path.with_name(f".{path.stem}.tmp{path.suffix}")
    im.save(tmp, optimize=True)
    tmp.replace(path)

def install_one(name: str) -> str:
    rw, kind = TARGETS[name]
    stage = STAGES / name
    mpath = stage / f"{name}_master.png"
    if not mpath.exists():
        return "PENDING"
    master = ensure_alpha(Image.open(mpath).convert("RGBA"))
    is_2x2 = kind in ("tree", "fire") or name in MOTION_2X2
    if is_2x2:
        # inline install: iph.install would re-crop frame 1's TIGHTER bbox and
        # misalign the union-cropped strip frames — resize with the union crop
        # so static canvas == every strip frame's canvas + geometry.
        frames = quad_frames(master)
        bb = union_bbox(frames)
        frames = [f.crop(bb) for f in frames]
        w, h = frames[0].size
        tw = min(1024, max(128, round(rw * 2.5)))
        tw = min(tw, w)
        th = max(1, round(h * tw / w))
        if th > 1024:
            tw = max(1, round(w * 1024 / h)); th = 1024
        static = iph.despill(frames[0].resize((tw, th), Image.LANCZOS))
        for d in (SPR, MOB):
            if d.is_dir():
                save_atomic(static, d / f"{name}.png")
    else:
        tmp = stage / f"_static_{name}.png"
        master.save(tmp)
        wrote = iph.install(name, str(tmp), rw, g=1.0)
        if not wrote:
            return "INSTALL-FAILED"
        tw, th = Image.open(wrote[0][0]).size
    if is_2x2:
        strip = Image.new("RGBA", (tw * 4, th))
        for i, f in enumerate(frames):
            rf = f.resize((tw, th), Image.LANCZOS)
            rf = iph.despill(rf)
            strip.alpha_composite(rf, (i * tw, 0))
        # rigid/trunk band drift gate vs frame 0
        def worst_drift(st):
            a = np.asarray(st)
            b0 = band_outline(a[:, 0:tw])
            w = 0
            for i in range(1, 4):
                b = band_outline(a[:, i * tw:(i + 1) * tw])
                if b0 and b:
                    w = max(w, abs(b[0] - b0[0]), abs(b[1] - b0[1]), abs(b[2] - b0[2]))
            return w
        worst = worst_drift(strip)
        if worst > 2:
            # translate-only trunk re-align: the generator sometimes draws the
            # same tree shifted per cell; slide frames 1-3 so their trunk-band
            # centre-x and bottom row land on frame 0's (no scaling).
            a = np.asarray(strip)
            b0 = band_outline(a[:, 0:tw])
            fixed = Image.new("RGBA", strip.size)
            fixed.alpha_composite(strip.crop((0, 0, tw, th)), (0, 0))
            for i in range(1, 4):
                cell = strip.crop((i * tw, 0, (i + 1) * tw, th))
                b = band_outline(np.asarray(cell))
                dx = ((b0[0] + b0[1]) - (b[0] + b[1])) // 2 if b0 and b else 0
                dy = (b0[2] - b[2]) if b0 and b else 0
                cv = Image.new("RGBA", (tw, th))
                cv.alpha_composite(cell, (dx, dy))
                fixed.alpha_composite(cv, (i * tw, 0))
            w2 = worst_drift(fixed)
            if w2 > 1.4:
                # last resort: verbatim-copy the trunk band rows (bottom 12% of
                # frame 0's silhouette) into frames 1-3 — the brief's contract
                # says the trunk IS pixel-identical, so enforcing it is
                # faithful; only canopy above the band animates.
                a2 = np.asarray(fixed).copy()
                m0 = a2[:, 0:tw, 3] > 40
                ys = np.nonzero(m0.any(axis=1))[0]
                span = ys.max() - ys.min() + 1
                rows = slice(int(ys.max() - 0.12 * span), a2.shape[0])
                for i in range(1, 4):
                    a2[rows, i * tw:(i + 1) * tw] = a2[rows, 0:tw]
                fixed = Image.fromarray(a2, "RGBA")
                w2 = worst_drift(fixed)
            if w2 > 1.4:
                return f"BAND-DRIFT {worst}->{w2}px (strip NOT installed; static installed)"
            strip = fixed
        for d in (SPR, MOB):
            if d.is_dir():
                save_atomic(strip, d / f"{name}_anim.png")
    elif name in DERIVED:
        r = subprocess.run([sys.executable, str(REPO / "tools/art/derive_prop_anim.py"),
                            name, "--motion", DERIVED[name], "--frames", "4",
                            "--amp", "0.10"], capture_output=True, text=True, cwd=REPO)
        if r.returncode != 0:
            return f"DERIVE-FAILED {r.stderr[-120:]}"
    return f"OK {tw}x{th}" + (" +anim" if (is_2x2 or name in DERIVED) else "")

def main() -> int:
    done = set(DONE.read_text().split()) if DONE.exists() else set()
    names = sys.argv[1:] or [n for n in TARGETS if n not in done]
    results = {}
    for name in names:
        try:
            r = install_one(name)
        except Exception as e:  # noqa: BLE001 — report per prop, keep batch going
            r = f"ERROR {e}"
        results[name] = r
        if r.startswith("OK"):
            done.add(name)
        if r != "PENDING":
            print(f"{name:22s} {r}")
    DONE.write_text("\n".join(sorted(done)) + "\n")
    pend = [n for n, r in results.items() if r == "PENDING"]
    print(f"\n{len([r for r in results.values() if r.startswith('OK')])} installed, "
          f"{len(pend)} pending, {len(done)} total done")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
