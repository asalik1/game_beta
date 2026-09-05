#!/usr/bin/env python
"""Rewrite a staged Codex row brief to request a TWO-ROW GRID instead of one row.

Why: a row of N figures comes back ~2100px wide, so at cells >= ~560px the figures
get upscaled 1.4-2.2x at install (soft strips). Two rows of N/2 figures land at
~900px each. Run on a stage made by gait_briefs.py / attack_walk_briefs.py /
profile_clip_briefs.py, then flatten the result with grid_to_row.py before
install_gait_row.

    python tools/art/gridify_brief.py <stage_dir> [--frames N]
"""
import argparse
import json
import re
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage")
    ap.add_argument("--frames", type=int, default=None)
    a = ap.parse_args()
    stage = Path(a.stage)
    brief = stage / "codex_brief.txt"
    s = brief.read_text(encoding="utf-8")
    n = a.frames or json.loads((stage / "job.json").read_text(encoding="utf-8")).get("frames", 6)
    top = (n + 1) // 2
    start = s.index("Produce ONE image")
    end = s.index("Flat solid #00ff00")
    layout = (f"Produce ONE image laid out as TWO ROWS: frames 1-{top} left to right on the top row, "
              f"frames {top + 1}-{n} left to right on the bottom row. Make every figure as LARGE as the "
              "image allows (each figure roughly 900 pixels across its longest side), all at one identical "
              "scale, all feet on one shared ground line per row, each figure centred in its cell, generous "
              "green margins between figures and around the image edges -- no figure touching another figure "
              "or an edge. ")
    s = s[:start] + layout + s[end:]
    s = re.sub(r"_row\.png", "_grid.png", s)
    brief.write_text(s, encoding="utf-8")
    print(f"gridified {stage.name}: {n} frames as {top}+{n - top}; output *_grid.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
