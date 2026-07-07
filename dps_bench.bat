@echo off
rem DPS BENCH: measured max sustained DPS per class/theme, constrained
rem to each class's real boss playstyle, vs an immortal average-L40-boss
rem dummy. Not a test tier - a balance instrument (see TIERLIST.md).
rem
rem Usage:  dps_bench.bat [--secs=N] [--cls=assassin] [--theme=blood]
rem Full run is 18 cases x 180 sim-seconds; --fixed-fps decouples the
rem simulation from the wall clock so it runs as fast as the CPU allows.
rem
rem Same isolation as the test suites: a throwaway user:// via APPDATA
rem redirect so it can never touch (or race on) real save files.
setlocal
:uniq
set "EF_TEST_APPDATA=%TEMP%\emberfall_tests\bench_%RANDOM%%RANDOM%"
if exist "%EF_TEST_APPDATA%" goto uniq
mkdir "%EF_TEST_APPDATA%" 2>nul || goto uniq
set "APPDATA=%EF_TEST_APPDATA%"

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 goto fail

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --fixed-fps 60 --path "%~dp0game" res://scenes/dps_bench.tscn -- %*
set "EF_EXIT=%ERRORLEVEL%"
goto cleanup

:fail
set "EF_EXIT=1"
:cleanup
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
