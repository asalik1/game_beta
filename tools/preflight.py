#!/usr/bin/env python3
"""Crownless preflight -- the CLAUDE.md traps list, mechanized.

Every check here exists because an agent tripped the trap it guards
(CLAUDE.md / CODING_GUIDELINES.md #38). Run it before staging; each
finding prints the one-line fix. ~2s without the engine; the codex data
check adds a few seconds (skip with --fast).

Usage:
    preflight.bat                 (from the repo root, same as test_quick.bat)
    python tools/preflight.py [--fast] [--strict]

Checks:
  IMPORT    assets / class_name scripts newer than Godot's import cache.
            Headless runs SILENTLY use stale art and unknown classes hang
            the engine -- this is the "forgot --import" trap.
  MODULES   scripts/content/*.gd not registered in Story.CONTENT_MODULES
            (content that compiles but never loads).
  CODEX     boss-flagged enemies missing from Menus.BOSS_KINDS -- the codex
            buckets them as monsters, silently. Engine-backed (exact data,
            via game/preflight_data.gd); skipped with --fast.
  BALANCE   diff-scoped WARN: new numeric literals in combat/flow logic
            files. Tuning knobs belong in balance.gd (#38f); data tables in
            domain files are fine -- this is a review nudge, not a gate.
  PHYSICS   diff-scoped WARN: body/area_entered connected without
            CONNECT_DEFERRED. Spawning an Area2D inside such a handler hits
            the physics-flush guard (chest open + ricochet were bitten).

Exit code 1 on any FAIL. WARNs exit 0 unless --strict.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
GODOT = ROOT / "tools" / "Godot_v4.4.1-stable_win64_console.exe"
IMPORT_CMD = r"tools\Godot_v4.4.1-stable_win64_console.exe --headless --path game --import"

# Content files that are legitimately NOT in Story.CONTENT_MODULES.
MODULE_ALLOWLIST = {
    "capital_hub.gd": "resolved directly via Story.chapter() as CapitalHub, not a merge module",
}

# Logic files where a bare numeric literal is probably a tuning knob.
# Domain/data files (classes/items/story/content), UI, art and tests are
# excluded on purpose -- numbers there are data or layout, not knobs.
BALANCE_LINT_FILES = re.compile(
    r"game/scripts/(player[^/]*|enemy|boss|game[^/]*|projectile|endgame)\.gd$"
)

FAIL, WARN = [], []


def fail(tag: str, msg: str, fix: str) -> None:
    FAIL.append(f"[{tag}] {msg}\n         fix: {fix}")


def warn(tag: str, msg: str) -> None:
    WARN.append(f"[{tag}] {msg}")


# ---------------------------------------------------------------- IMPORT
def check_imports() -> None:
    """Stale/missing Godot import artifacts + unimported class_name scripts.

    Staleness compares the source's md5 against the source_md5 Godot wrote
    at import time (the .godot/imported/*.md5 sidecar). NOT mtime -- git
    checkouts touch every file and would flag the whole tree.
    """
    stale, never = [], []
    for src in (GAME / "assets").rglob("*"):
        if src.suffix.lower() not in (".png", ".wav", ".ogg", ".mp3", ".svg"):
            continue
        imp = src.with_name(src.name + ".import")
        if not imp.exists():
            never.append(src.relative_to(GAME))
            continue
        m = re.search(r'path="res://(\.godot/imported/[^"]+)"', imp.read_text(errors="replace"))
        if not m:
            continue  # importer="keep" style entries have no dest artifact
        dest = GAME / m.group(1)
        if not dest.exists():
            stale.append(src.relative_to(GAME))
            continue
        sidecar = dest.with_suffix(".md5")
        if not sidecar.exists():
            continue
        m5 = re.search(r'source_md5="([0-9a-f]+)"', sidecar.read_text(errors="replace"))
        if m5 and hashlib.md5(src.read_bytes()).hexdigest() != m5.group(1):
            stale.append(src.relative_to(GAME))
    for group, label in ((never, "never imported"), (stale, "changed since last import")):
        if group:
            listed = ", ".join(str(p) for p in group[:8]) + (" ..." if len(group) > 8 else "")
            fail("IMPORT", f"{len(group)} asset(s) {label}: {listed}",
                 f"run: {IMPORT_CMD}  (close the editor first -- --import contends with it)")

    cache_file = GAME / ".godot" / "global_script_class_cache.cfg"
    cache = cache_file.read_text(errors="replace") if cache_file.exists() else ""
    missing = []
    for gd in (GAME / "scripts").rglob("*.gd"):
        m = re.search(r"^class_name\s+([A-Za-z_]\w*)", gd.read_text(errors="replace"), re.M)
        if m and f'&"{m.group(1)}"' not in cache:
            missing.append(f"{m.group(1)} ({gd.relative_to(GAME)})")
    if missing:
        fail("IMPORT", "class_name not in Godot's class cache: " + ", ".join(missing),
             f"run: {IMPORT_CMD}  -- headless runs hang forever on an unimported class_name (#38b)")


# --------------------------------------------------------------- MODULES
def check_modules() -> None:
    """Every scripts/content/*.gd must be preloaded in Story.CONTENT_MODULES."""
    story = (GAME / "scripts" / "story.gd").read_text(errors="replace")
    m = re.search(r"const CONTENT_MODULES\s*:?\s*\w*\s*=\s*\[(.*?)\]", story, re.S)
    if not m:
        fail("MODULES", "could not locate Story.CONTENT_MODULES in story.gd",
             "the const moved or was renamed -- update tools/preflight.py")
        return
    registered = set(re.findall(r'res://scripts/content/([\w.]+\.gd)', m.group(1)))
    on_disk = {p.name for p in (GAME / "scripts" / "content").glob("*.gd")}
    for f in sorted(on_disk - registered - set(MODULE_ALLOWLIST)):
        fail("MODULES", f"scripts/content/{f} exists but is not registered -- it will never load",
             f'add  preload("res://scripts/content/{f}"),  to Story.CONTENT_MODULES (story.gd)')
    for f in sorted(registered - on_disk):
        fail("MODULES", f"Story.CONTENT_MODULES preloads scripts/content/{f} which does not exist",
             "remove the preload line or restore the file")


# ----------------------------------------------------------------- CODEX
def check_codex_data() -> None:
    """Exact boss/bucket audit via the engine (game/preflight_data.gd)."""
    if not GODOT.exists():
        warn("CODEX", f"engine not found at {GODOT} -- data check skipped")
        return
    try:
        r = subprocess.run(
            [str(GODOT), "--headless", "--path", str(GAME), "--script", "res://preflight_data.gd"],
            capture_output=True, text=True, timeout=90)
    except subprocess.TimeoutExpired:
        fail("CODEX", "preflight_data.gd hung (>90s) -- usually a parse error somewhere",
             "run the compile gate: test_quick.bat (gate runs first, prints the real error)")
        return
    out = (r.stdout or "") + (r.stderr or "")
    for line in out.splitlines():
        line = line.strip()
        if line.startswith(("BOSS_NOT_BUCKETED:", "BOSS_KINDS_DEAD:", "DATA FAIL")):
            fail("CODEX", line, "update Menus.BOSS_KINDS (menus.gd) -- the hand-maintained "
                 "list that buckets the codex bestiary (CLAUDE.md: codex goes stale silently)")
    if "DATA OK" not in out and not any(f.startswith("[CODEX]") for f in FAIL):
        warn("CODEX", "data check produced no verdict -- output was: " + out.strip()[:300])


# ------------------------------------------------------------- diff lints
def _added_lines() -> list[tuple[str, int, str]]:
    """(repo-relative posix path, line number, text) for every added/new line."""
    out: list[tuple[str, int, str]] = []
    # encoding pinned: git emits UTF-8, but text=True decodes with the Windows
    # ANSI codepage (cp1252) and a multibyte glyph in the diff crashed the run.
    diff = subprocess.run(["git", "diff", "HEAD", "--unified=0", "--", "game/scripts"],
                          capture_output=True, text=True, cwd=ROOT,
                          encoding="utf-8", errors="replace").stdout or ""
    path, lineno = "", 0
    for raw in diff.splitlines():
        if raw.startswith("+++ b/"):
            path = raw[6:]
        elif raw.startswith("@@"):
            m = re.search(r"\+(\d+)", raw)
            lineno = int(m.group(1)) if m else 0
        elif raw.startswith("+") and not raw.startswith("+++"):
            out.append((path, lineno, raw[1:]))
            lineno += 1
    status = subprocess.run(["git", "status", "--porcelain", "--", "game/scripts"],
                            capture_output=True, text=True, cwd=ROOT,
                            encoding="utf-8", errors="replace").stdout or ""
    for line in status.splitlines():
        if line.startswith("??") and line.strip().endswith(".gd"):
            p = line[3:].strip()
            try:
                for i, text in enumerate((ROOT / p).read_text(errors="replace").splitlines(), 1):
                    out.append((p.replace("\\", "/"), i, text))
            except OSError:
                pass
    return out


BENIGN = re.compile(r"Vector2i?\(|Color\(|range\(|custom_minimum_size|add_theme|font_size|--")


def check_diff_lints() -> None:
    for path, lineno, text in _added_lines():
        code = text.split("#", 1)[0]
        if re.search(r'\b(body_entered|area_entered)\b.*\bconnect\s*\(', code) \
                and "CONNECT_DEFERRED" not in code:
            warn("PHYSICS", f"{path}:{lineno}: physics signal connected without CONNECT_DEFERRED "
                 "-- spawning an Area2D from this handler hits the physics-flush guard "
                 "(CLAUDE.md trap); pass CONNECT_DEFERRED or call_deferred the spawn")
        if not BALANCE_LINT_FILES.search(path) or BENIGN.search(code):
            continue
        stripped = re.sub(r'"[^"]*"', "", code)
        nums = [n for n in re.findall(r"(?<![\w.])(\d+\.\d+|\d+)(?![\w.])", stripped)
                if n not in ("0", "1", "0.0", "1.0")]
        if nums:
            warn("BALANCE", f"{path}:{lineno}: bare number(s) {nums} in a logic file -- if this "
                 "tunes gameplay it belongs in balance.gd (#38f); ignore if it's structural")


# ------------------------------------------------------------------ main
def main() -> int:
    ap = argparse.ArgumentParser(description="Crownless preflight trap checks")
    ap.add_argument("--fast", action="store_true", help="skip the engine-backed codex data check")
    ap.add_argument("--strict", action="store_true", help="warnings also fail the run")
    args = ap.parse_args()

    check_imports()
    check_modules()
    check_diff_lints()
    if not args.fast:
        check_codex_data()

    for f in FAIL:
        print("FAIL " + f)
    for w in WARN:
        print("WARN " + w)
    n_checks = "IMPORT MODULES BALANCE PHYSICS" + ("" if args.fast else " CODEX")
    if not FAIL and not WARN:
        print(f"PREFLIGHT OK ({n_checks})")
    else:
        print(f"\nPREFLIGHT: {len(FAIL)} fail, {len(WARN)} warn  ({n_checks})")
    return 1 if FAIL or (args.strict and WARN) else 0


if __name__ == "__main__":
    sys.exit(main())
