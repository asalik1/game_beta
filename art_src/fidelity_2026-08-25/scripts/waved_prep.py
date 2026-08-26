#!/usr/bin/env python3
"""Wave D (5%-rule pull-ins): auroch_minotaur 1.79x, halla 1.87x, fangmaw 1.89x.

- auroch/halla: idle + 4 unique walk strips, remastered as PAIRED-FRAME
  LANDSCAPE gens (frames 1+2, then 3+4, side by side; ~768px cells beats the
  627 2x2 ceiling; render 350/335px -> 2.2-2.3x).
- fangmaw: renders only 259px, so a standard 2x2 at 627 clears 2.42x; its
  actions are already 544-907px cells. idle + flat walk, one gen each.
"""
import sys
from pathlib import Path
from PIL import Image

REPO = Path(r"C:\Users\asali\Projects\MMO")
SPR = REPO / "game" / "assets" / "sprites"
HERE = Path(__file__).parent
STAGES = HERE / "waved_stages"

PAIR_BOSSES = {
    "auroch_minotaur": ["anim_codex", "walk_codex_e", "walk_codex_w", "walk_codex_n", "walk_codex_s"],
    "halla": ["anim_codex", "walk_codex_e", "walk_codex_w", "walk_codex_n", "walk_codex_s"],
}

PAIR_BRIEF = """Redraw TWO CONSECUTIVE FRAMES of a game boss's animation at high resolution.
This is a FIDELITY UPGRADE of existing approved art — absolutely NOT a redesign.

The reference image shows the two frames side by side (upscaled so you can read them):
reproduce EXACTLY these two images — same poses, same silhouettes, same proportions, same
palette, same lighting, same facing — just repainted with crisp high-resolution detail.

Generate ONE image in LANDSCAPE orientation (wider than tall): the two figures side by side in
the SAME order, each filling most of its half's height, clearly separated by transparent space,
on a TRANSPARENT background (real alpha). Do NOT change the poses. Do NOT add, remove or
restyle any element. NO background, NO ground shadow.

Save the image to disk at the exact path {out} and stop.
"""

GRID_BRIEF = """Repaint an EXISTING game boss's 4-frame animation strip at high resolution.
This is a FIDELITY UPGRADE of existing approved art — absolutely NOT a redesign.

The reference image is the CURRENT in-game strip (4 frames left to right, upscaled): reproduce
the SAME creature and the SAME 4 poses in the SAME order, repainted with crisp detail.

Generate ONE image: a 2x2 grid of EXACTLY 4 complete figures on a TRANSPARENT background (real
alpha), reading top-left, top-right, bottom-left, bottom-right = frames 1-4. Same creature,
same size in every cell, same baseline. Do NOT change the poses or design. NO shadow.

Save the single image to disk at the exact path {out} and stop.
"""

def frames_of(base: str):
    im = Image.open(SPR / f"{base}.png").convert("RGBA")
    c = im.height
    return [im.crop((i * c, 0, (i + 1) * c, c)) for i in range(im.width // c)]

def main() -> int:
    STAGES.mkdir(exist_ok=True)
    names = []
    for boss, clips in PAIR_BOSSES.items():
        for clip in clips:
            fr = frames_of(f"{boss}_{clip}")
            for pi, (a, b) in enumerate([(0, 1), (2, 3)]):
                st = STAGES / f"{boss}_{clip}_p{pi + 1}"
                refs = st / "refs"
                refs.mkdir(parents=True, exist_ok=True)
                pair = Image.new("RGBA", (fr[a].width * 2 + 40, fr[a].height))
                pair.alpha_composite(fr[a], (0, 0))
                pair.alpha_composite(fr[b], (fr[a].width + 40, 0))
                pair.save(refs / f"1_source_{boss}_{clip}_f{a + 1}f{b + 1}.png")
                out = st / f"{boss}_{clip}_p{pi + 1}_master.png"
                (st / "codex_brief.txt").write_text(PAIR_BRIEF.format(out=str(out)),
                                                    encoding="utf-8")
                names.append(str(st))
    for base in ["fangmaw_anim_codex", "fangmaw_walk"]:
        st = STAGES / base
        refs = st / "refs"
        refs.mkdir(parents=True, exist_ok=True)
        im = Image.open(SPR / f"{base}.png").convert("RGBA")
        im.resize((im.width * 2, im.height * 2), Image.Resampling.NEAREST).save(
            refs / f"1_source_{base}.png")
        out = st / f"{base}_master.png"
        (st / "codex_brief.txt").write_text(GRID_BRIEF.format(out=str(out)), encoding="utf-8")
        names.append(str(st))
    (STAGES / "stages.txt").write_text("\n".join(names) + "\n", encoding="ascii")
    print(f"staged {len(names)} wave-D briefs")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
