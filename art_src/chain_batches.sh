#!/usr/bin/env bash
# Serialize the remaining Codex art batches behind the running one (the box
# never runs two image jobs at once -- CLAUDE.md RAM rule).
cd "$(dirname "$0")/.."
while tasklist //FI "IMAGENAME eq codex.exe" 2>/dev/null | grep -qi codex.exe; do sleep 30; done
echo "=== boss batch $(date)"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 \
  -Stages "$(tr '\n' ',' < art_src/boss_gait_2026-09-03/stages.txt | sed 's/,$//')" \
  -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 \
  -ExtraArgs '--dangerously-bypass-approvals-and-sandbox -c model_reasoning_effort="high"' \
  > art_src/boss_gait_2026-09-03/runner_log.txt 2>&1
echo "=== capital batch $(date)"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 \
  -Stages "$(tr '\n' ',' < art_src/capital_painterly_2026-09-03/stages.txt | sed 's/,$//')" \
  -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 \
  -ExtraArgs '--dangerously-bypass-approvals-and-sandbox -c model_reasoning_effort="high"' \
  > art_src/capital_painterly_2026-09-03/runner_log.txt 2>&1
echo "=== all batches done $(date)"
