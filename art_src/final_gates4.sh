#!/usr/bin/env bash
cd "$(dirname "$0")/.."
echo "=== desktop import $(date)"; ./tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --import > art_src/_import6.log 2>&1; echo "import exit $?"
echo "=== test_quick $(date)"; ./test_quick.bat > art_src/_test_quick_final4.log 2>&1; echo "test_quick exit $?"; grep -E "AUTOTEST QUICK (PASS|FAIL)" art_src/_test_quick_final4.log | tail -1
echo "=== preflight $(date)"; python tools/preflight.py --fast 2>&1 | tail -1
echo "=== mobile import $(date)"; ./tools/Godot_v4.4.1-stable_win64_console.exe --headless --path mobile/game --import > art_src/_mobile_import3.log 2>&1; echo "mobile import exit $?"
echo "=== sync_mobile $(date)"; python tools/sync_mobile.py --apply --gate > art_src/_sync_mobile_final4.log 2>&1; echo "sync exit $?"; grep -E "GATE|APPLIED" art_src/_sync_mobile_final4.log | tail -3
echo "=== done $(date)"
