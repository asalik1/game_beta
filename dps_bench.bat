@echo off
rem DPS BENCH: measured max sustained DPS per class/theme, constrained
rem to each class's real boss playstyle, vs an immortal average-L40-boss
rem dummy. Not a test tier - a balance instrument (see TIERLIST.md).
rem
rem Usage:  dps_bench.bat [--secs=N] [--cls=assassin] [--theme=blood]
rem Without --cls the six classes run as SIX PARALLEL Godot processes
rem (tools\dps_bench_fan.ps1) and the output ends with one merged
rem ranking - a full 18-case sweep costs one class's wall time.
rem --fixed-fps decouples the simulation from the wall clock, so the
rem numbers are identical either way; only wall time changes.
rem
rem Same isolation as the test suites: throwaway user:// via APPDATA
rem redirect (one per parallel child) so real saves are never touched.
setlocal

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 exit /b 1

echo %* | findstr /c:"--cls=" >nul
if not errorlevel 1 goto single

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dps_bench_fan.ps1" %*
exit /b %ERRORLEVEL%

:single
:uniq
set "EF_TEST_APPDATA=%TEMP%\emberfall_tests\bench_%RANDOM%%RANDOM%"
if exist "%EF_TEST_APPDATA%" goto uniq
mkdir "%EF_TEST_APPDATA%" 2>nul || goto uniq
set "APPDATA=%EF_TEST_APPDATA%"

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --fixed-fps 60 --path "%~dp0game" res://scenes/dps_bench.tscn -- %*
set "EF_EXIT=%ERRORLEVEL%"
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
