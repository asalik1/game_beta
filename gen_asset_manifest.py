#!/usr/bin/env python3
"""Regenerate game/assets/asset_manifest.json.

The sound/music override systems (game.gd) scan assets/sounds and
assets/music for drop-in files. DirAccess can scan those folders live when
the game runs from source, but an EXPORTED build can't enumerate imported
audio (each file is remapped inside the .pck, not a loose file). So the
export bakes this manifest in (via each preset's include_filter) and the
runtime reads it instead. Run this before exporting whenever the override
audio set changes:  python gen_asset_manifest.py
"""
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(ROOT, "game", "assets")
DIRS = ("sounds", "music")
EXTS = (".wav", ".ogg", ".mp3")

manifest = {}
for d in DIRS:
    path = os.path.join(ASSETS, d)
    manifest[d] = sorted(
        f for f in os.listdir(path) if f.lower().endswith(EXTS)
    )

out = os.path.join(ASSETS, "asset_manifest.json")
with open(out, "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, indent=0)

print("wrote %s  (sounds: %d, music: %d)"
      % (out, len(manifest["sounds"]), len(manifest["music"])))
