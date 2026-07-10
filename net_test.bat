@echo off
rem NET TEST: three stages, all over localhost ENet.
rem   1. NetworkManager session harness (MP-05) - the NET_VERSION auth
rem      gate and peer lifecycle (game/scripts/tests/net_test.gd).
rem   2. Session gameplay bridge (MP-07) - two REAL game instances share
rem      one seeded world: join snapshot + world rebuild, player spawn
rem      fan-out, 20 Hz movement sync, clean leave
rem      (game/scripts/tests/net_test_session.gd).
rem   3. Combat over the wire (MP-09) - same harness, --net-stage=3: the
rem      host spawns wolves + a boss and the guest must SEE them (mirror
rem      census + gating, position tracking, hp sync, play_action strip,
rem      boss bar, telegraph event, a kill frees the mirror).
rem   4. Hit resolution over the wire (MP-10) - same harness, --net-stage=4:
rem      the guest FIGHTS. Real-intent ability on a mirror (host hp drops by
rem      the RPC'd amount, mirror converges), burn rider ticks host-side,
rem      host hit on the shell drops the guest's REAL hp (vitals follow),
rem      guest projectiles kill a mob (death event + kill XP), hostile
rem      projectile event renders, boss phase flag round-trips.
rem   5. Loot instancing (MP-11) - same harness, --net-stage=5: a solo kill
rem      pays exactly once (regression), a party kill grows BOTH wallets
rem      from their OWN piles (shells can't eat the other's coins), a boss
rem      chest opens per player (the guest opening its copy leaves the
rem      host's shut), a crafted award package lands in the guest's bags,
rem      and a guest-side ground drop flushes to the GUEST's mailbox.
rem
rem Compile gate FIRST, always (test.bat pattern): one parse error anywhere
rem makes a headless run idle forever. The orchestrator instance spawns and
rem reaps its own client processes with wall-clock timeouts (OS.kill on any
rem failure path); the PowerShell wrapper below is the LAST-RESORT kill:
rem if the orchestrator itself wedges, taskkill /T by PID sweeps it plus
rem any client Godots it spawned (they are its child processes).
rem
rem Throwaway user:// via APPDATA redirect, same as test.bat, so runs
rem can't race other suites on shared save/meta files.
setlocal
:uniq
set "EF_TEST_APPDATA=%TEMP%\emberfall_tests\run_%RANDOM%%RANDOM%"
if exist "%EF_TEST_APPDATA%" goto uniq
mkdir "%EF_TEST_APPDATA%" 2>nul || goto uniq
set "APPDATA=%EF_TEST_APPDATA%"

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 goto fail

powershell -NoProfile -Command "$p = Start-Process -FilePath '%~dp0tools\Godot_v4.4.1-stable_win64_console.exe' -ArgumentList '--headless','--path','%~dp0game','res://scenes/net_test.tscn' -NoNewWindow -PassThru; if ($p.WaitForExit(120000)) { exit $p.ExitCode } else { Write-Host ('NET TEST FAIL  top-level timeout (120s) - taskkill /T on PID ' + $p.Id); taskkill /PID $p.Id /T /F | Out-Null; exit 124 }"
set "EF_EXIT=%ERRORLEVEL%"
if not "%EF_EXIT%"=="0" goto cleanup

powershell -NoProfile -Command "$p = Start-Process -FilePath '%~dp0tools\Godot_v4.4.1-stable_win64_console.exe' -ArgumentList '--headless','--path','%~dp0game','res://scenes/net_test_session.tscn' -NoNewWindow -PassThru; if ($p.WaitForExit(180000)) { exit $p.ExitCode } else { Write-Host ('NET TEST FAIL  session-stage timeout (180s) - taskkill /T on PID ' + $p.Id); taskkill /PID $p.Id /T /F | Out-Null; exit 124 }"
set "EF_EXIT=%ERRORLEVEL%"
if not "%EF_EXIT%"=="0" goto cleanup

powershell -NoProfile -Command "$p = Start-Process -FilePath '%~dp0tools\Godot_v4.4.1-stable_win64_console.exe' -ArgumentList '--headless','--path','%~dp0game','res://scenes/net_test_session.tscn','--','--net-stage=3' -NoNewWindow -PassThru; if ($p.WaitForExit(240000)) { exit $p.ExitCode } else { Write-Host ('NET TEST FAIL  combat-stage timeout (240s) - taskkill /T on PID ' + $p.Id); taskkill /PID $p.Id /T /F | Out-Null; exit 124 }"
set "EF_EXIT=%ERRORLEVEL%"
if not "%EF_EXIT%"=="0" goto cleanup

powershell -NoProfile -Command "$p = Start-Process -FilePath '%~dp0tools\Godot_v4.4.1-stable_win64_console.exe' -ArgumentList '--headless','--path','%~dp0game','res://scenes/net_test_session.tscn','--','--net-stage=4' -NoNewWindow -PassThru; if ($p.WaitForExit(240000)) { exit $p.ExitCode } else { Write-Host ('NET TEST FAIL  hit-resolution-stage timeout (240s) - taskkill /T on PID ' + $p.Id); taskkill /PID $p.Id /T /F | Out-Null; exit 124 }"
set "EF_EXIT=%ERRORLEVEL%"
if not "%EF_EXIT%"=="0" goto cleanup

powershell -NoProfile -Command "$p = Start-Process -FilePath '%~dp0tools\Godot_v4.4.1-stable_win64_console.exe' -ArgumentList '--headless','--path','%~dp0game','res://scenes/net_test_session.tscn','--','--net-stage=5' -NoNewWindow -PassThru; if ($p.WaitForExit(240000)) { exit $p.ExitCode } else { Write-Host ('NET TEST FAIL  loot-stage timeout (240s) - taskkill /T on PID ' + $p.Id); taskkill /PID $p.Id /T /F | Out-Null; exit 124 }"
set "EF_EXIT=%ERRORLEVEL%"
goto cleanup

:fail
set "EF_EXIT=1"
:cleanup
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
