#!/usr/bin/env python3
"""Boss per-frame remaster prep (veyx 0.94x, stormmouth 1.37x, vargoth 1.58x).

Scope (owner-triage documented in FIDELITY_AUDIT rewrite): idle + walk sets
for all three + veyx storm(=ring). Everything else stays 627 (documented).

Per-frame lane (the ONLY way past the ~627px multi-frame ceiling):
each frame of each 4-frame strip becomes one gen at ~1024. Two steps:
  --anchors : stage just idle FRAME 1 per boss (ref = source frame crop).
              Review those 3 results, then run --rest.
  --rest    : stage every remaining frame; refs = source frame crop + the
              REMASTERED idle f1 (style/identity anchor, chained).
Install (boss_install.py) re-seats each output to the source frame's bbox
geometry scaled to the new cell, preserving the exact original motion.
"""
import sys
from pathlib import Path
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
SPR = REPO / "game" / "assets" / "sprites"
HERE = Path(__file__).parent
STAGES = HERE / "boss_stages"

# boss -> list of (strip file base, out clip id). walk dedup: e-family/w-family/n/s.
CLIPS = {
    "veyx": [
        ("veyx_anim_codex", "idle"),
        ("veyx_walk_codex_e", "walk_e"), ("veyx_walk_codex_w", "walk_w"),
        ("veyx_walk_codex_n", "walk_n"), ("veyx_walk_codex_s", "walk_s"),
        ("veyx_storm", "storm"),
    ],
    "stormmouth": [
        ("stormmouth_anim_codex", "idle"),
        ("stormmouth_walk_codex_e", "walk_e"), ("stormmouth_walk_codex_w", "walk_w"),
        ("stormmouth_walk_codex_s", "walk_s"),   # n = e-family (dedup)
    ],
    "vargoth": [
        ("vargoth_anim_codex", "idle"),
        ("vargoth_walk_codex_e", "walk_e"), ("vargoth_walk_codex_w", "walk_w"),
        ("vargoth_walk_codex_n", "walk_n"), ("vargoth_walk_codex_s", "walk_s"),
    ],
}

BRIEF = """Redraw ONE FRAME of a game boss's animation at high resolution.
This is a FIDELITY UPGRADE of existing approved art — absolutely NOT a redesign.

Reference image 1 is the frame to redraw (upscaled so you can read it): reproduce this EXACT
image — same pose, same silhouette, same proportions, same palette, same lighting, same energy
and FX shapes, same facing — just repainted with crisp high-resolution detail.
{anchor_line}

Generate ONE image: the single figure filling most of a square canvas, on a TRANSPARENT
background (real alpha). Do NOT change the pose. Do NOT add, remove, resize or restyle any
element. NO background, NO ground shadow.

Save the image to disk at the exact path {out} and stop.
"""

ANCHOR_LINE = ("Reference image 2 is frame 1 of this character's already-remastered idle: match "
               "THIS rendering style and detail level exactly, so every remastered frame reads "
               "as the same animation.")

def frames_of(base: str) -> list[Image.Image]:
    im = Image.open(SPR / f"{base}.png").convert("RGBA")
    c = im.height
    return [im.crop((i * c, 0, (i + 1) * c, c)) for i in range(im.width // c)]

def stage_frame(boss: str, clip: str, base: str, fi: int, anchor: Path | None) -> str:
    st = STAGES / f"{boss}_{clip}_f{fi + 1}"
    refs = st / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    fr = frames_of(base)[fi]
    fr.resize((fr.width * 2, fr.height * 2), Image.Resampling.NEAREST).save(
        refs / f"1_source_{base}_f{fi + 1}.png")
    line = ""
    if anchor is not None and anchor.exists():
        Image.open(anchor).convert("RGBA").save(refs / "2_anchor_idle_f1.png")
        line = ANCHOR_LINE
    out = st / f"{boss}_{clip}_f{fi + 1}_master.png"
    (st / "codex_brief.txt").write_text(
        BRIEF.format(anchor_line=line, out=str(out)), encoding="utf-8")
    return str(st)

def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "--anchors"
    STAGES.mkdir(exist_ok=True)
    names = []
    if mode == "--anchors":
        for boss, clips in CLIPS.items():
            base = clips[0][0]
            names.append(stage_frame(boss, "idle", base, 0, None))
        listing = "stages_anchors.txt"
    else:
        for boss, clips in CLIPS.items():
            anchor = STAGES / f"{boss}_idle_f1" / f"{boss}_idle_f1_master.png"
            for base, clip in clips:
                for fi in range(4):
                    if clip == "idle" and fi == 0:
                        continue
                    names.append(stage_frame(boss, clip, base, fi, anchor))
        listing = "stages_rest.txt"
    (STAGES / listing).write_text("\n".join(names) + "\n", encoding="utf-8")
    print(f"staged {len(names)} -> {STAGES}/{listing}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
