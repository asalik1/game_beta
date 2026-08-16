#!/usr/bin/env python
"""Scan a directional wave's Codex self-reports for IDENTITY DRIFT.

Codex reports its own output bluntly ("the character is a horned armored
swordsman instead of the hooded choir-robed figure"), so its codex_result.md
is a reliable pre-filter for the ~5-10% of generations that draw the wrong
creature — far faster than eyeballing every sheet. Flagged stages get a
hardened-identity re-roll; unflagged still get a visual QA pass.

  python scan_drift.py <stage_list_file | dir_root>
prints one line per flagged stage: <stage_dir>  <<< reason
"""
from __future__ import annotations
import os, sys, glob

# Phrases that signal the wrong CHARACTER was drawn (not a mere pose nit).
DRIFT = [
    "instead of the", "instead of a", "instead of an",
    "off-model", "off model", "not the requested character",
    "different character", "wrong character", "wrong creature",
    "redesigned the character", "redesigned it", "substitut",
    "a horned armored swordsman", "generic knight", "generic mage",
    "does not match image 1", "doesn't match image 1", "not the same character",
    "resembles a different", "looks like a different",
]
# Don't flag on these (benign uses of "instead of ...").
BENIGN = ["instead of touching", "instead of a projectile", "instead of the edge",
          "instead of the cell edge", "instead of one"]


def flagged(md: str) -> str | None:
    low = md.lower()
    for b in BENIGN:
        low = low.replace(b, "")
    for d in DRIFT:
        i = low.find(d)
        if i >= 0:
            seg = md[max(0, i - 40): i + 80].replace("\n", " ")
            return f"'{d}' -> ...{seg.strip()}..."
    return None


def main() -> int:
    arg = sys.argv[1]
    if os.path.isfile(arg):
        stages = [s.strip() for s in open(arg).read().split(",") if s.strip()]
        reports = [os.path.join(s, "codex_result.md") for s in stages]
    else:
        reports = glob.glob(os.path.join(arg, "**", "codex_result.md"), recursive=True)
    n_flag = 0
    for r in sorted(reports):
        if not os.path.exists(r):
            print(f"MISSING  {os.path.dirname(r)}")
            continue
        why = flagged(open(r, encoding="utf-8", errors="replace").read())
        if why:
            n_flag += 1
            print(f"DRIFT    {os.path.dirname(r)}  <<< {why}")
    print(f"--- {n_flag} flagged of {len(reports)} reports")
    return 0


if __name__ == "__main__":
    sys.exit(main())
