#!/usr/bin/env bash
cd "$(dirname "$0")/.."
while tasklist //FI "IMAGENAME eq codex.exe" 2>/dev/null | grep -qi codex.exe; do sleep 30; done
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 -Stages "$(cd art_src/landmark_remaster_2026-09-05/spore_shrine_v2 && pwd -W)" -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 -ExtraArgs "--dangerously-bypass-approvals-and-sandbox" > art_src/_runner_spore_v2.txt 2>&1
echo "spore v2 done $(date)" >> art_src/_runner_spore_v2.txt
