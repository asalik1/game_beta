#!/usr/bin/env bash
# Second half of the art queue: waits for chain 1 (boss + capital) to finish,
# then runs fire-on-move and the two re-rolls. One Codex job at a time, ever.
cd "$(dirname "$0")/.."
until grep -q "all batches done" art_src/chain_log.txt 2>/dev/null; do sleep 60; done
run() {
  echo "=== $1 $(date)"
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/run_codex_batch.ps1 \
    -Stages "$(tr '\n' ',' < "$2" | sed 's/,$//')" \
    -MaxParallel 1 -MinFreeGB 1.3 -TimeoutSec 900 \
    -ExtraArgs '--dangerously-bypass-approvals-and-sandbox -c model_reasoning_effort="high"' \
    > "$3" 2>&1
}
run attack_walk art_src/attack_walk_2026-09-03/stages.txt art_src/attack_walk_2026-09-03/runner_log.txt
run rerolls     art_src/mob_gait_reroll_2026-09-03/stages.txt art_src/mob_gait_reroll_2026-09-03/runner_log.txt
echo "=== chain2 done $(date)"
