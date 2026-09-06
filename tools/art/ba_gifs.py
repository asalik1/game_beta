#!/usr/bin/env python3
"""BEFORE/AFTER review GIFs for changed sprites (2026-08-26, fidelity pass).

The reusable visual-audit compiler: for every changed sprite it renders one
animated GIF with the git-BASE version and the working-tree version side by
side at the SAME display height, so a fidelity/regen change reads instantly
(soft vs crisp, motion vs static) without booting the game. The 2026-08-25
fidelity remediation was reviewed this way (111 GIFs).

  # everything that changed since a ref (the usual post-pass review)
  python tools/art/ba_gifs.py --base HEAD~1
  # explicit subjects (sprite basenames, with or without .png)
  python tools/art/ba_gifs.py --base cc114b7 --names banshee_anim,tree_green,veyx_anim_codex
  # options: --out DIR (default ~/Downloads/ba_gifs), --panel-h N (default 300)

Per subject, classification is automatic:
- multi-frame strip (square cells, width divisible by height): both versions
  LOOP side by side (BEFORE | AFTER), frame counts may differ.
- static: a labeled BEFORE/AFTER toggle; if the working tree has a matching
  `<name>_anim.png`, the AFTER side plays that loop instead (shows a prop
  that GAINED motion, e.g. the tree canopy-rustle strips).
- added files render AFTER-only; deleted files are listed and skipped.

Judging note: GIFs are palette-quantized and shown above game scale — they are
for CHANGE review, not final color/tonemap judgement (judge that in-game).
"""
import argparse
import re
import io
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
SPR_REL = "game/assets/sprites"
SPR = REPO / SPR_REL
BG = (44, 46, 54)


def git_show(ref: str, rel: str):
    blob = subprocess.run(["git", "-C", str(REPO), "show", f"{ref}:{SPR_REL}/{rel}"],
                          capture_output=True).stdout
    if not blob:
        return None
    try:
        return Image.open(io.BytesIO(blob)).convert("RGBA")
    except Exception:
        return None


def cell_w_of(stem: str, im: Image.Image):
    """Mirror art.gd's frame rule: a `<base>_anim` strip whose matching static
    shares its height and divides its width evenly uses STATIC-width cells
    (prop anims are rectangular: cell = static WxH); else square cells."""
    if stem.endswith("_anim"):
        static = SPR / (stem[:-5] + ".png")
        if static.exists():
            sw, sh = Image.open(static).size
            if sh == im.height and im.width % sw == 0 and im.width // sw > 1:
                return sw
    if im.width % im.height == 0:
        return im.height
    return im.width  # not a strip


def is_strip(stem: str, im: Image.Image) -> bool:
    cw = cell_w_of(stem, im)
    return cw < im.width


def frames_of(im: Image.Image, cell_w=None):
    c = cell_w or im.height
    return [im.crop((i * c, 0, (i + 1) * c, im.height))
            for i in range(max(1, im.width // c))]


def scale_to(im: Image.Image, h: int):
    w = max(1, round(im.width * h / im.height))
    return im.resize((w, h), Image.Resampling.NEAREST if im.height < h
                     else Image.Resampling.LANCZOS)


def panel(fr: Image.Image, w: int, h: int, label: str):
    p = Image.new("RGBA", (w, h + 22), BG + (255,))
    s = scale_to(fr, h)
    p.alpha_composite(s, ((w - s.width) // 2, 0))
    ImageDraw.Draw(p).text((w // 2 - len(label) * 3, h + 5), label, fill=(235, 235, 160))
    return p


def save_gif(path: Path, frames, durations):
    path.parent.mkdir(parents=True, exist_ok=True)
    conv = [f.convert("P", palette=Image.ADAPTIVE, colors=255) for f in frames]
    conv[0].save(path, save_all=True, append_images=conv[1:], duration=durations,
                 loop=0, disposal=2, optimize=False)


# ---------------------------------------------------------------- layout ---
# Review folders were a flat pile of 400 GIFs (owner 2026-09-05: "mob gifs and
# class gifs all in one place"). Every GIF now lands in
#   <out>/<category>/<subject>/<stem>.gif
# category = classes | bosses | mobs | npcs | capital | props, subject = the
# sprite base (mage, vargoth, wolf, ...). --flat restores the old pile.
FLAT = False
_CLIP_RE = re.compile(r"^(.*?)_(anim|walk|attack_walk_b|attack_walk|attack2|attackb|attackc|attack|death|cast|ult|ultidle|dash|ability|slam|charge|enrage|summon|bolt|beam|piston|blade|arc|ring|shift|lash|storm|leap|spit|bite|howl|burrow|emerge|spin|standing)(_codex)?(_[a-z]{1,2})?$")
_HEROES = ("warrior", "archer", "mage", "assassin", "paladin", "warlock")
_CH1_BOSSES = {"vargoth", "morwen", "fangmaw", "korrag", "choirmother", "nullwarden", "cinderhide", "stormwarden",
               "glacius", "smelter_lord_thrain", "thornfather_grael", "mother_halla"}
_sets = {}


def _content_sprites(pattern: str) -> set:
    keys = set()
    for f in (SPR.parents[2] / "game" / "scripts" / "content").glob(pattern):
        for m in re.finditer(r'"sprite"\s*:\s*"([a-z0-9_]+)"', f.read_text(encoding="utf-8", errors="ignore")):
            keys.add(m.group(1))
    return keys


def category(stem: str) -> tuple[str, str]:
    if not _sets:
        _sets["boss"] = _content_sprites("*bosses*.gd") | _content_sprites("interlude_moonfen.gd") | _CH1_BOSSES
        _sets["npc"] = _content_sprites("*hub*.gd") | _content_sprites("pc_npc_gallery.gd")
    name = stem.replace("\\", "/").split("/")[-1]
    m = _CLIP_RE.match(name)
    base = m.group(1) if m else name
    if "/skins/" in stem.replace("\\", "/") or stem.startswith("skins/"):
        return "classes", next((h for h in _HEROES if name.startswith(h + "_")), "skins")
    for h in _HEROES:
        if name == h or name.startswith(h + "_"):
            return "classes", h
    if base.startswith("capital_") or base.startswith("ground_field_"):
        return "capital", "capital"
    if base in _sets["boss"] or base.replace("_standing", "") in _sets["boss"]:
        return "bosses", base.replace("_standing", "")
    if base.startswith("npc_") or base in _sets["npc"]:
        return "npcs", base
    has_motion = any((SPR / f"{base}_{k}.png").exists() for k in ("walk", "walk_s", "walk_codex_e", "attack", "death"))
    if has_motion:
        return "mobs", base
    return "props", base


def gif_path(out_dir: Path, stem: str) -> Path:
    if FLAT:
        return out_dir / f"{stem.split('/')[-1]}.gif"
    cat, subj = category(stem)
    d = out_dir / cat / subj
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{stem.split('/')[-1]}.gif"


README = """# Crownless review GIFs (before = branch base, after = branch head)

Each GIF plays the OLD strip's frames beside the NEW strip's frames, palette-quantized and
above game scale -- for CHANGE review, not colour judgement.

- classes/<class>/   the six base heroes (and their skins), one folder per class
- bosses/<boss>/     boss idles, walk facings, deaths, ability strips
- mobs/<mob>/        placed mobs: idles, walks, attacks, deaths
- npcs/<npc>/        village / hub / quest NPCs
- capital/           the capital's buildings, props and floor
- props/             world props and scenery
- travel/            old-vs-new walks over scrolling ground at the mob's real speed

Built by tools/art/ba_gifs.py --base <ref> (--flat for the old single pile).
"""


def build(name: str, base_ref: str, out_dir: Path, panel_h: int) -> str:
    rel = name if name.endswith(".png") else name + ".png"
    stem = rel[:-4]
    old = git_show(base_ref, rel)
    new_p = SPR / rel
    new = Image.open(new_p).convert("RGBA") if new_p.exists() else None
    if new is None:
        return f"deleted  {stem} (skipped)"
    out = gif_path(out_dir, stem)
    if old is None:
        fr = frames_of(new, cell_w_of(stem, new)) if is_strip(stem, new) else [new]
        pw = max(round(f.width * panel_h / f.height) for f in fr) + 16
        frames = [panel(f, pw, panel_h, "NEW") for f in fr] or [panel(new, pw, panel_h, "NEW")]
        save_gif(out, frames, 180 if len(frames) > 1 else 1200)
        return f"new      {stem}"
    if is_strip(stem, new) and is_strip(stem, old):
        of = frames_of(old, cell_w_of(stem, old))
        nf = frames_of(new, cell_w_of(stem, new))
        n = max(len(of), len(nf))
        pw = max(max(round(f.width * panel_h / f.height) for f in of),
                 max(round(f.width * panel_h / f.height) for f in nf)) + 16
        frames = []
        for i in range(n):
            c = Image.new("RGBA", (pw * 2 + 12, panel_h + 22), BG + (255,))
            c.alpha_composite(panel(of[i % len(of)], pw, panel_h, "BEFORE"), (0, 0))
            c.alpha_composite(panel(nf[i % len(nf)], pw, panel_h, "AFTER"), (pw + 12, 0))
            frames.append(c)
        save_gif(out, frames, 180)
        return f"loop     {stem}"
    # static (or shape changed): toggle; AFTER plays the anim strip if one ships
    anim_p = SPR / f"{stem}_anim.png"
    if anim_p.exists() and not stem.endswith("_anim"):
        anim = Image.open(anim_p).convert("RGBA")
        nf = frames_of(anim, cell_w_of(f"{stem}_anim", anim))
    else:
        nf = [new]
    pw = max(round(old.width * panel_h / old.height),
             max(round(f.width * panel_h / f.height) for f in nf)) + 16
    frames = [panel(old, pw, panel_h, "BEFORE")]
    durations = [1100]
    if len(nf) > 1:
        for f in nf * 2:
            frames.append(panel(f, pw, panel_h, "AFTER"))
            durations.append(180)
    else:
        frames.append(panel(nf[0], pw, panel_h, "AFTER"))
        durations.append(1100)
    save_gif(out, frames, durations)
    return f"toggle   {stem}"


def changed_names(base_ref: str):
    txt = subprocess.run(["git", "-C", str(REPO), "diff", "--name-only", base_ref,
                          "--", SPR_REL], capture_output=True, text=True).stdout
    names = []
    for line in txt.splitlines():
        if line.endswith(".png"):
            names.append(Path(line).name)
    return sorted(set(names))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", default="HEAD", help="git ref for the BEFORE side (default HEAD)")
    ap.add_argument("--names", default="", help="comma-separated sprite basenames; default = every changed sprite vs --base")
    ap.add_argument("--out", default=str(Path.home() / "Downloads" / "ba_gifs"))
    ap.add_argument("--panel-h", type=int, default=300)
    ap.add_argument("--flat", action="store_true", help="one flat folder instead of category/subject subfolders")
    a = ap.parse_args()
    names = [n.strip() for n in a.names.split(",") if n.strip()] or changed_names(a.base)
    if not names:
        print("nothing changed vs", a.base)
        return 0
    # dedup byte-identical files (direction copies: _ne/_se = _e etc.)
    import hashlib
    seen: dict = {}
    unique = []
    for n in names:
        rel = n if n.endswith(".png") else n + ".png"
        p = SPR / rel
        if p.exists():
            hsh = hashlib.md5(p.read_bytes()).hexdigest()
            if hsh in seen:
                print(f"dup      {rel[:-4]} == {seen[hsh]} (skipped)")
                continue
            seen[hsh] = rel[:-4]
        unique.append(n)
    names = unique
    out_dir = Path(a.out)
    global FLAT
    FLAT = a.flat
    out_dir.mkdir(parents=True, exist_ok=True)
    if not FLAT:
        (out_dir / "README.md").write_text(README, encoding="utf-8")
    ok = 0
    for n in names:
        try:
            r = build(n, a.base, out_dir, a.panel_h)
            ok += 1
        except Exception as e:  # noqa: BLE001 — keep the batch going, report per file
            r = f"ERROR    {n}: {e}"
        print(r)
    print(f"{ok}/{len(names)} GIFs -> {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
