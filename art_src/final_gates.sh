#!/usr/bin/env bash
cd "$(dirname "$0")/.."
until [ -f art_src/_import2.log ]; do sleep 20; done
sleep 30
while tasklist 2>/dev/null | grep -qi "Godot_v4"; do sleep 15; done
echo "=== import done $(date)"; tail -2 art_src/_import2.log
echo "=== test_quick $(date)"; ./test_quick.bat > art_src/_test_quick_final.log 2>&1; echo "test_quick exit $?"; grep -E "AUTOTEST (PASS|FAIL)|QUICK EXIT|FAIL" art_src/_test_quick_final.log | tail -4
echo "=== preflight $(date)"; python tools/preflight.py --fast 2>&1 | tail -2
echo "=== sync_mobile $(date)"; python tools/sync_mobile.py --apply --gate > art_src/_sync_mobile_final.log 2>&1; echo "sync exit $?"; grep -E "GATE|PASS|FAIL|drift|copied|import" art_src/_sync_mobile_final.log | tail -8
echo "=== done $(date)"
