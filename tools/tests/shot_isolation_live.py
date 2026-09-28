"""Opt-in LIVE check that shot.bat keeps a real rig off the owner's profile.

The fixture file next to this (shot_isolation_tests.ps1) proves the runner's
logic with a fake engine. This one boots the real game once:

  1. seeds this checkout's build/qa/shot_profile with leftover state that
     would break a keyboard rig if it were loaded (touch controls on,
     fullscreen on, interact remapped to 999),
  2. runs `shot.bat controller --keyboard-hints --timeout=240` exactly as a
     person would, with the real APPDATA,
  3. requires: the rig passes (its mode/keyboard_returns check fails in touch
     mode), the rig's user:// is build/qa/shot_profile, the seeded state is
     gone, and the owner's real settings/keybinds are byte-identical. The
     owner's files are only ever read here, never written.

Heavy (a windowed Godot, ~1-2 min): run it under the machine lock, e.g.
  python <session>/tools/glock.py --cwd <checkout> -- python tools/tests/shot_isolation_live.py
"""
from __future__ import annotations

import ctypes
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / "build" / "qa" / "shot_profile"
USER = PROFILE / "Godot" / "app_userdata" / "Crownless"
NAMES = [n + s for n in ("settings.json", "keybinds.json") for s in ("", ".bak", ".tmp")]


def owner_roaming() -> Path:
    # The Known Folder (CSIDL_APPDATA), not the env var.
    buf = ctypes.create_unicode_buffer(260)
    ctypes.windll.shell32.SHGetFolderPathW(None, 0x1A, None, 0, buf)
    return Path(buf.value)


def snapshot(user: Path) -> dict[str, bytes | None]:
    return {n: (user / n).read_bytes() if (user / n).is_file() else None for n in NAMES}


def main() -> int:
    owner = owner_roaming()
    env_appdata = os.environ.get("APPDATA", "")
    if env_appdata and os.path.normcase(os.path.abspath(env_appdata)) != os.path.normcase(str(owner)):
        print(f"APPDATA is {env_appdata}; unset it or leave it as {owner} so shot.bat picks the shot profile")
        return 2
    owner_user = owner / "Godot" / "app_userdata" / "Crownless"
    before = snapshot(owner_user)

    USER.mkdir(parents=True, exist_ok=True)
    seeded = {
        "settings.json": {"touch_controls": True, "fullscreen": True},
        "keybinds.json": {"interact": 999},
    }
    for name, data in seeded.items():
        for suffix in ("", ".bak"):
            (USER / (name + suffix)).write_text(json.dumps(data), encoding="utf-8")

    cmd = ["cmd.exe", "/d", "/c", str(ROOT / "shot.bat"), "controller", "--keyboard-hints", "--timeout=240"]
    run = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = (run.stdout or "") + (run.stderr or "")
    print(out)

    problems = []
    if run.returncode != 0:
        problems.append(f"shot.bat exited {run.returncode}")
    if "KEYBOARD HINTS mode/keyboard_returns: pass" not in out:
        problems.append("mode/keyboard_returns did not pass (the rig booted on the seeded touch settings?)")
    m = re.search(r"^RIG SHOTS DIR: (.+)$", out, re.M)
    shots = Path(m.group(1).strip()).resolve() if m else None
    if shots is None or not str(shots).lower().startswith(str(USER.resolve()).lower() + os.sep):
        problems.append(f"the rig's user:// was not the shot profile: {shots}")
    for name, data in seeded.items():
        path = USER / name
        if path.is_file():
            now = json.loads(path.read_text(encoding="utf-8") or "{}")
            if any(now.get(k) == v for k, v in data.items()):
                problems.append(f"seeded {name} survived the reset: {now}")
    if snapshot(owner_user) != before:
        problems.append("the owner's real settings/keybinds changed")

    for p in problems:
        print("FAIL: " + p)
    if problems:
        return 1
    print("SHOT ISOLATION LIVE PASS: rig passed on defaults in build/qa/shot_profile; owner files byte-identical")
    return 0


if __name__ == "__main__":
    sys.exit(main())
