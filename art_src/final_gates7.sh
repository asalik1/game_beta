#!/usr/bin/env bash
cd "$(dirname "$0")/.."
while tasklist //FI "IMAGENAME eq codex.exe" 2>/dev/null | grep -qi codex.exe; do sleep 20; done
echo "=== desktop import $(date)"; ./tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --import > art_src/_import12.log 2>&1; echo "import exit $?"
echo "=== full suite $(date)"; ./test.bat > art_src/_full_suite3.log 2>&1; echo "FULL EXIT $?"; grep -E "AUTOTEST (PASS|FAIL)" art_src/_full_suite3.log | tail -1; grep -c "^ok:" art_src/_full_suite3.log
echo "=== preflight $(date)"; python tools/preflight.py --fast 2>&1 | tail -1
echo "=== mobile import $(date)"; ./tools/Godot_v4.4.1-stable_win64_console.exe --headless --path mobile/game --import > art_src/_mobile_import6.log 2>&1; echo "mobile import exit $?"
echo "=== sync_mobile $(date)"; python tools/sync_mobile.py --apply --gate > art_src/_sync_mobile_final7.log 2>&1; echo "sync exit $?"; grep -E "GATE|APPLIED" art_src/_sync_mobile_final7.log | tail -3
echo "=== done $(date)"
