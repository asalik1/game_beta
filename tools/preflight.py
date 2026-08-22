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
  RIGS      diff-scoped: a NEW game/shot_*.gd or qa_*.gd that does not
            `extends ShotRig` FAILs (23 one-off copies of the same boot
            boilerplate already exist, none with a watchdog -- the base
            has boot/shot/sim-clock/mute/watchdog and shot.bat runs it);
            an EDITED legacy standalone rig WARNs: convert on touch.
  ARTQA     diff-scoped: runs tools/art/verify_art.py on every CHANGED sprite
            strip. Its content gates (GEOMETRY/BODYSCALE -> FAIL; ANCHOR/
            GHOST/EDGECUT/RIGIDDRIFT -> WARN) catch a prop that shifts or
            clips when it animates -- they existed but nothing ran them on a
            diff, so capital_portal_depths shipped drifting. IMPORT findings
            are left to the IMPORT check above.

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


# ------------------------------------------------------------------ RIGS
RIG_SCRIPT = re.compile(r"^game/(shot_|qa_)\w+\.gd$")


def check_rigs() -> None:
    """New rigs must extend ShotRig; edited legacy ones get the convert nudge."""
    status = subprocess.run(["git", "status", "--porcelain", "--", "game"],
                            capture_output=True, text=True, cwd=ROOT,
                            encoding="utf-8", errors="replace").stdout or ""
    for line in status.splitlines():
        code, p = line[:2], line[3:].strip().replace("\\", "/")
        if not RIG_SCRIPT.match(p):
            continue
        try:
            src = (ROOT / p).read_text(errors="replace")
        except OSError:
            continue
        m = re.search(r"^extends\s+(\w+)", src, re.M)
        base = m.group(1) if m else "?"
        if base == "ShotRig":
            continue
        is_new = code.startswith("??") or "A" in code
        name = Path(p).stem.removeprefix("shot_")
        if is_new:
            fail("RIGS", f"{p}: new rig extends {base}, not ShotRig -- another standalone copy "
                 "of the boot/shot/quit boilerplate with no mute and no watchdog",
                 f"`extends ShotRig` (game/scripts/dev/shot_rig.gd: boot/shot/sim-clock/mute/"
                 f"watchdog are in the base), then run it with `shot.bat {name}` -- see "
                 "tools/INDEX.md 'In-engine shot rigs' and shot_fx_series.gd for the shape")
        else:
            warn("RIGS", f"{p}: legacy standalone rig edited (extends {base}) -- convert on touch: "
                 f"`extends ShotRig` and drop the copied boot/_shot/quit code (shot_fx_series.gd "
                 f"is the worked example); run via `shot.bat {name}` either way")


# ----------------------------------------------------------------- ARTQA
_DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
# Clip/direction tokens that trail a strip's base name (art.gd _strip_info +
# verify_art CLIPS). Stripping them off a changed file's stem recovers the base
# name verify_art globs its whole family on.
_STRIP_TOKENS = frozenset(
    ("anim", "walk", "attack", "attack2", "attackb", "attackc", "cast", "dash",
     "hurt", "death", "spawn", "dir") + _DIR8)
VERIFY_ART = ROOT / "tools" / "art" / "verify_art.py"


def _strip_base(stem: str) -> str:
    parts = stem.split("_")
    while len(parts) > 1 and parts[-1] in _STRIP_TOKENS:
        parts.pop()
    return "_".join(parts)


def check_anim_art() -> None:
    """Run verify_art on every CHANGED sprite strip -- the geometry / anchor /
    edge / rigid-drift gates that catch a prop which shifts or clips when it
    animates (capital_portal_depths did both). Those gates already existed but
    nothing ran them on a diff, so a broken strip sailed through staging. This
    closes the loop: diff-scoped, one verify_art call, its WARN/FAIL folded in.
    Only the strip-geometry / motion gates are surfaced (see SURFACE below).
    IMPORT is left to check_imports() -- reporting it twice is noise. BLEED is
    dropped too: it fires in the tens of thousands on generated FX AA and would
    bury the shift/clip signal this check exists to raise."""
    if not VERIFY_ART.exists():
        return
    status = subprocess.run(
        ["git", "status", "--porcelain", "--", "game/assets/sprites"],
        capture_output=True, text=True, cwd=ROOT,
        encoding="utf-8", errors="replace").stdout or ""
    bases: set[str] = set()
    for line in status.splitlines():
        p = line[3:].strip().replace("\\", "/")
        if " -> " in p:            # rename: take the destination path
            p = p.split(" -> ", 1)[1]
        if not p.endswith(".png"):
            continue
        stem = Path(p).stem
        if any(stem.endswith(f"_{t}") for t in _STRIP_TOKENS):
            bases.add(_strip_base(stem))
    if not bases:
        return
    r = subprocess.run(
        [sys.executable, str(VERIFY_ART), *sorted(bases)],
        capture_output=True, text=True, cwd=ROOT,
        encoding="utf-8", errors="replace")
    # Strip-geometry and motion gates only -- the ones that mean "this animates
    # wrong". BLEED/IMPORT are handled elsewhere or too noisy (see docstring).
    surface = ("[GEOMETRY]", "[BODYSCALE]", "[DIRSTRIP]", "[DIR8]", "[ANCHOR]",
               "[GHOST]", "[EDGECUT]", "[RIGIDDRIFT]", "[CLIPSCALE]")
    for raw in (r.stdout or "").splitlines():
        if not any(tag in raw for tag in surface):
            continue
        if raw.startswith("FAIL "):
            FAIL.append(raw[5:] + "\n         (changed sprite; via tools/art/verify_art.py)")
        elif raw.startswith("WARN "):
            WARN.append(raw[5:] + "  (changed sprite; verify_art.py)")


# ------------------------------------------------------------------ main
def main() -> int:
    ap = argparse.ArgumentParser(description="Crownless preflight trap checks")
    ap.add_argument("--fast", action="store_true", help="skip the engine-backed codex data check")
    ap.add_argument("--strict", action="store_true", help="warnings also fail the run")
    args = ap.parse_args()

    check_imports()
    check_modules()
    check_diff_lints()
    check_rigs()
    check_anim_art()
    if not args.fast:
        check_codex_data()

    for f in FAIL:
        print("FAIL " + f)
    for w in WARN:
        print("WARN " + w)
    n_checks = "IMPORT MODULES BALANCE PHYSICS RIGS ARTQA" + ("" if args.fast else " CODEX")
    if not FAIL and not WARN:
        print(f"PREFLIGHT OK ({n_checks})")
    else:
        print(f"\nPREFLIGHT: {len(FAIL)} fail, {len(WARN)} warn  ({n_checks})")
    return 1 if FAIL or (args.strict and WARN) else 0


if __name__ == "__main__":
    sys.exit(main())
