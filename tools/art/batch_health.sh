#!/bin/bash
# Batch health verdict: OK-PROGRESSING / STALLED-GATE / DEAD-ORPHAN / DONE.
# usage: batch_health.sh <runner_log> <stage_dirs...>   exits 0 only while healthy.
LOG="$1"; shift
N=$(find "$@" -name "*_master.png" -not -path "*/refs/*" 2>/dev/null | wc -l)
NEWEST=$(find "$@" -name "*_master.png" -not -path "*/refs/*" -newermt "-12 minutes" 2>/dev/null | wc -l)
ALIVE=$(tasklist //FI "IMAGENAME eq codex.exe" 2>/dev/null | grep -c codex.exe)
TAIL=$(powershell -NoProfile -Command "Get-Content '$LOG' -Tail 1" 2>/dev/null)
LOGAGE=$(( $(date +%s) - $(stat -c %Y "$LOG" 2>/dev/null || echo 0) ))
case "$TAIL" in
  *"batch complete"*) echo "DONE masters=$N"; exit 1;;
  *"wait: free RAM"*) echo "STALLED-GATE masters=$N ram-gate-waiting: $TAIL"; exit 2;;
esac
if [ "$NEWEST" -eq 0 ] && [ "$LOGAGE" -gt 720 ]; then
  echo "DEAD-ORPHAN masters=$N codex=$ALIVE log-age=${LOGAGE}s tail: $TAIL"; exit 3
fi
echo "OK masters=$N codex=$ALIVE log-age=${LOGAGE}s"; exit 0
