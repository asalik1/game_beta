#!/usr/bin/env bash
cd "$(dirname "$0")/.."
until grep -q "launched" art_src/warlock_profile_2026-09-04/runner_log.txt 2>/dev/null; do sleep 60; done
while tasklist //FI "IMAGENAME eq codex.exe" 2>/dev/null | grep -qi codex.exe; do sleep 30; done
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 -Stages "$(tr '\n' ',' < art_src/boss_fix3_2026-09-03/stages_rr.txt | sed 's/,$//')" -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 -ExtraArgs '--dangerously-bypass-approvals-and-sandbox -c model_reasoning_effort="high"' > art_src/boss_fix3_2026-09-03/runner_log_rr.txt 2>&1
echo "rr done $(date)"
