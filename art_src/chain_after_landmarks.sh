#!/usr/bin/env bash
# waits for the landmark batch, then runs the two death fixes + the two NPC south masters (serial, RAM-gated)
cd "$(dirname "$0")/.."
until grep -q "landmark batch done" art_src/landmark_remaster_2026-09-05/runner_log.txt 2>/dev/null; do sleep 60; done
while tasklist //FI "IMAGENAME eq codex.exe" 2>/dev/null | grep -qi codex.exe; do sleep 30; done
stages="$(tr -d '\r' < art_src/deaths3_2026-09-05/stages.txt | paste -sd,),$(tr -d '\r' < art_src/npc_remaster_2026-09-05/stages.txt | paste -sd,)"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 -Stages "$stages" -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 -ExtraArgs '--dangerously-bypass-approvals-and-sandbox' > art_src/_runner_after_landmarks.txt 2>&1
echo "after-landmarks batch done $(date)" >> art_src/_runner_after_landmarks.txt
