@echo off
rem NET TEST: two stages, both over localhost ENet.
rem   1. NetworkManager session harness (MP-05) - the NET_VERSION auth
rem      gate and peer lifecycle (game/scripts/tests/net_test.gd).
rem   2. Session gameplay bridge (MP-07) - two REAL game instances share
rem      one seeded world: join snapshot + world rebuild, player spawn
rem      fan-out, 20 Hz movement sync, clean leave
rem      (game/scripts/tests/net_test_session.gd).
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
goto cleanup

:fail
set "EF_EXIT=1"
:cleanup
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
