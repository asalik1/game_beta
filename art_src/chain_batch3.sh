#!/usr/bin/env bash
cd "$(dirname "$0")/.."
while tasklist //FI "IMAGENAME eq codex.exe" 2>/dev/null | grep -qi codex.exe; do sleep 30; done
stages="$(cd art_src/landmark_remaster_2026-09-05/spore_shrine_v2 && pwd -W),$(tr -d '\r' < art_src/npc_remaster_2026-09-05/stages.txt | paste -sd,)"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 -Stages "$stages" -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 -ExtraArgs '--dangerously-bypass-approvals-and-sandbox' > art_src/_runner_batch3.txt 2>&1
echo "batch3 done $(date)" >> art_src/_runner_batch3.txt
