#!/usr/bin/env bash
cd "$(dirname "$0")/.."
until grep -q "batch complete" art_src/attack_walk_b_2026-09-05/runner_log.txt 2>/dev/null; do sleep 60; done
while tasklist //FI "IMAGENAME eq codex.exe" 2>/dev/null | grep -qi codex.exe; do sleep 30; done
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 -Stages "$(cd art_src/warrior_blade_2026-09-05/warrior__walk__e && pwd -W)" -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 -ExtraArgs '--dangerously-bypass-approvals-and-sandbox -c model_reasoning_effort="high"' > art_src/warrior_blade_2026-09-05/runner_log.txt 2>&1
echo "blade done $(date)"
