#!/usr/bin/env python3
"""game/ -> mobile/game/ re-sync -- the mobile/README.md ritual, mechanized.

`game/` is the source of truth; `mobile/game/` is a snapshot fork plus a
small fixed delta list (mobile/README.md "Mobile deltas"). This tool makes
the re-sync a command instead of a checklist.

Usage:
    python tools/sync_mobile.py              # CHECK (default): report drift, change nothing
    python tools/sync_mobile.py --apply      # re-copy game/ over mobile/game/, re-apply deltas
    python tools/sync_mobile.py --apply --prune   # also delete stale mobile-only files
    python tools/sync_mobile.py --apply --gate    # then run --import + compile gate + quick suite

Delta handling (mobile/README.md, "applied 2026-07-13"):
  project.godot        never copied; the desktop file is TRANSFORMED (renderer
                       mobile+gl_compatibility fallback, Mobile feature tag,
                       stretch aspect=expand, landscape, emulate_touch_from_mouse,
                       snapshot banner). Check mode diffs mobile's actual file
                       against the transform, so NEW desktop settings (e.g. a new
                       autoload) show up as drift instead of being missed.
  export_presets.cfg   never copied (mobile's holds the Android/iOS presets);
                       check mode verifies it still has them and wasn't clobbered.
  *.uid                never copied (each project mints its own; copying breaks
                       the mobile-only scenes).
  mobile-only scenes   shot_touch.* / shot_sf2.* are expected; anything else
                       mobile-only is reported (deleted only with --prune).

CRLF vs LF never counts as drift (the documented `diff -rq` blind spot).
Exit 1 when drift is found in check mode.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "game"
DST = ROOT / "mobile" / "game"
GODOT = ROOT / "tools" / "Godot_v4.4.1-stable_win64_console.exe"

MOBILE_ONLY_OK = {
    "shot_touch.gd", "shot_touch.tscn", "shot_touch.gd.uid",
    "shot_sf2.gd", "shot_sf2.tscn", "shot_sf2.gd.uid",
    "export_presets.cfg",
}

BANNER = [
    ";",
    "; ---------------------------------------------------------------------------",
    "; MOBILE SNAPSHOT — this file DIVERGES from game/project.godot on purpose.",
    "; The mobile deltas (renderer, orientation, touch, MobileInput autoload) are",
    "; listed in mobile/README.md so a re-sync can re-apply them. Do NOT copy this",
    "; back over the desktop project.",
    "; ---------------------------------------------------------------------------",
]


def norm(text: str) -> list[str]:
    return [l.rstrip() for l in text.replace("\r\n", "\n").replace("\r", "\n").split("\n")]


def transform_project_godot(desktop: str) -> list[str]:
    """Apply the README's mobile deltas to the desktop project.godot."""
    out: list[str] = []
    problems: list[str] = []
    lines = norm(desktop)
    for line in lines:
        if line.startswith(";   param=value"):
            out.append(line)
            out.extend(BANNER)
        elif line.startswith("config/features=") and "Forward Plus" in line:
            out.append(line.replace('"Forward Plus"', '"Mobile"'))
        elif line.startswith("window/stretch/mode="):
            out.append(line)
            out.append('window/stretch/aspect="expand"')
            out.append('window/handheld/orientation="landscape"')
        elif line == "[rendering]":
            out.append("[input_devices]")
            out.append("")
            out.append("pointing/emulate_touch_from_mouse=true")
            out.append("")
            out.append(line)
        elif line.startswith('renderer/rendering_method="forward_plus"'):
            out.append('renderer/rendering_method="mobile"')
            out.append('renderer/rendering_method.mobile="gl_compatibility"')
        else:
            out.append(line)
    for needle in ('"Mobile"', 'aspect="expand"', "emulate_touch_from_mouse",
                   'rendering_method="mobile"', "gl_compatibility"):
        if not any(needle in l for l in out):
            problems.append(needle)
    if problems:
        sys.exit("project.godot transform could not apply these deltas (desktop file "
                 f"format changed?): {problems} -- update tools/sync_mobile.py and "
                 "mobile/README.md together.")
    return out


def walk(base: Path) -> list[Path]:
    return sorted(p.relative_to(base) for p in base.rglob("*")
                  if p.is_file() and ".godot" not in p.parts)


def main() -> int:
    ap = argparse.ArgumentParser(description="game -> mobile/game re-sync (mobile/README.md)")
    ap.add_argument("--apply", action="store_true", help="write changes (default: check only)")
    ap.add_argument("--prune", action="store_true",
                    help="with --apply: delete unexpected mobile-only files (git-recoverable)")
    ap.add_argument("--gate", action="store_true",
                    help="with --apply: run --import + compile gate + quick suite on mobile/game")
    ap.add_argument("--full", action="store_true", help="print every finding (no aggregation cap)")
    args = ap.parse_args()

    drift, missing, extra, notes = [], [], [], []

    src_files = walk(SRC)
    dst_names = set(walk(DST))
    for rel in src_files:
        name = rel.name
        if name.endswith(".uid") or name == "export_presets.cfg":
            continue
        dst = DST / rel
        if name == "project.godot" and rel.parent == Path("."):
            want = transform_project_godot((SRC / rel).read_text(encoding="utf-8", errors="replace"))
            have = norm(dst.read_text(encoding="utf-8", errors="replace")) if dst.exists() else []
            if [l for l in want if l] != [l for l in have if l]:
                drift.append((rel, "delta-transformed desktop file != mobile's actual"))
            continue
        if not dst.exists():
            missing.append(rel)
        elif (SRC / rel).read_bytes() != dst.read_bytes():
            if norm((SRC / rel).read_text(encoding="utf-8", errors="replace")) != \
                    norm(dst.read_text(encoding="utf-8", errors="replace")):
                drift.append((rel, "content differs"))
            # else: line-endings only -- not drift (the documented diff -rq blind spot)

    for rel in sorted(dst_names - set(src_files)):
        if rel.name.endswith(".uid") and (SRC / rel.with_name(rel.name[:-4])).exists():
            continue  # uid for a synced file -- legitimately differs per project
        if rel.name in MOBILE_ONLY_OK:
            continue
        extra.append(rel)

    presets = DST / "export_presets.cfg"
    if not presets.exists():
        notes.append("export_presets.cfg MISSING in mobile/game -- the Android/iOS presets are gone")
    else:
        ptxt = presets.read_text(encoding="utf-8", errors="replace")
        if "Android" not in ptxt or "iOS" not in ptxt:
            notes.append("mobile/game/export_presets.cfg lost its Android/iOS presets -- was it "
                         "clobbered by the desktop copy? restore via git")

    # ---- report (aggregate .import churn -- it is bulk uid/param noise the
    # sync auto-fixes; a 600-line list would bury the drift that matters)
    imports = [(r, w) for r, w in drift if r.name.endswith(".import")]
    real = [(r, w) for r, w in drift if not r.name.endswith(".import")]
    cap = None if args.full else 40
    if imports:
        print(f"DRIFT   {len(imports)} .import file(s) differ (uid/params churn; sync copies "
              "game/'s -- synced scenes reference game-side uids)")
    for rel, why in real[:cap]:
        print(f"DRIFT   {rel}  ({why})")
    for rel in missing[:cap]:
        print(f"MISSING {rel}  (in game/, not in mobile/game/)")
    hidden = max(0, len(real) - (cap or len(real))) + max(0, len(missing) - (cap or len(missing)))
    if hidden:
        print(f"...     {hidden} more (re-run with --full for the complete list)")
    for rel in extra:
        print(f"EXTRA   {rel}  (mobile-only, not in the README delta list)")
    for n in notes:
        print(f"NOTE    {n}")

    if not args.apply:
        if drift or missing or notes:
            print(f"\nCHECK: {len(drift)} drift, {len(missing)} missing, {len(extra)} extra "
                  "-- run with --apply to re-sync (then re-import + gate, see mobile/README.md)")
            return 1
        print(f"CHECK OK: mobile/game is in sync with game/ ({len(src_files)} files, "
              f"{len(extra)} unexpected mobile-only)")
        return 1 if extra else 0

    # ---- apply
    dirty = subprocess.run(["git", "status", "--porcelain", "--", "game/"],
                           capture_output=True, text=True, cwd=ROOT).stdout.strip()
    if dirty:
        print("\nWARNING: game/ has uncommitted changes (below) -- this sync snapshots them "
              "into mobile/game/. If another agent is mid-edit, sync after their work lands.")
        print("\n".join("  " + l for l in dirty.splitlines()[:15]))
    copied = 0
    for rel, _ in drift:
        if rel.name == "project.godot":
            want = transform_project_godot((SRC / rel).read_text(encoding="utf-8", errors="replace"))
            (DST / rel).write_text("\n".join(want) + "\n", encoding="utf-8", newline="\n")
        else:
            (DST / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(SRC / rel, DST / rel)
        copied += 1
    for rel in missing:
        (DST / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SRC / rel, DST / rel)
        copied += 1
    pruned = 0
    for rel in extra:
        if args.prune:
            (DST / rel).unlink()
            pruned += 1
        else:
            print(f"kept    {rel}  (re-run with --prune to delete; git-recoverable)")
    print(f"\nAPPLIED: {copied} file(s) synced, {pruned} pruned.")

    if not args.gate:
        print("now run (mobile/README.md ritual):\n"
              "  tools\\Godot_v4.4.1-stable_win64_console.exe --headless --import --quit --path mobile/game\n"
              "  tools\\Godot_v4.4.1-stable_win64_console.exe --headless --path mobile/game --script res://check_compile.gd\n"
              "  then the quick suite (or re-run this tool with --gate to do all three)")
        return 0

    print("\n--gate: importing (close the Godot editor if it's open -- --import contends) ...")
    subprocess.run([str(GODOT), "--headless", "--import", "--quit", "--path", str(DST)],
                   capture_output=True, text=True, timeout=600)
    r = subprocess.run([str(GODOT), "--headless", "--path", str(DST),
                        "--script", "res://check_compile.gd"],
                       capture_output=True, text=True, timeout=300)
    print((r.stdout or "").strip())
    if "COMPILE OK" not in (r.stdout or ""):
        print("GATE FAIL: mobile compile gate did not pass")
        return 1
    env = dict(os.environ)
    env["APPDATA"] = tempfile.mkdtemp(prefix="crownless_mobile_gate_")  # isolate user:// like test_quick.bat
    r = subprocess.run([str(GODOT), "--headless", "--path", str(DST),
                        "res://scenes/test.tscn", "--", "--quick"],
                       capture_output=True, text=True, timeout=600, env=env)
    out = (r.stdout or "") + (r.stderr or "")
    shutil.rmtree(env["APPDATA"], ignore_errors=True)
    if "AUTOTEST QUICK PASS" in out:
        print("GATE OK: mobile quick suite passed")
        return 0
    print("GATE FAIL: quick suite verdict not found; last lines:")
    print("\n".join(out.strip().splitlines()[-15:]))
    return 1


if __name__ == "__main__":
    sys.exit(main())
