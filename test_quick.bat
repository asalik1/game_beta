@echo off
rem Quick test tier (~15s): compile gate, then boot / one class kit /
rem all systems tests / UI smoke / pause menu. For iterating on fixes.
rem Run test.bat (the FULL suite) before staging anything.
rem
rem Each run gets its own throwaway user:// via APPDATA redirect so
rem concurrent runs can't race on shared save/meta files - see test.bat.
rem
rem VERDICT: log grep (suite_verdict.ps1), not the exit code alone - see test.bat.
setlocal
:uniq
set "EF_TEST_APPDATA=%TEMP%\emberfall_tests\run_%RANDOM%%RANDOM%"
if exist "%EF_TEST_APPDATA%" goto uniq
mkdir "%EF_TEST_APPDATA%" 2>nul || goto uniq
set "APPDATA=%EF_TEST_APPDATA%"

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 goto fail

rem run_suite.ps1 tees live to the log while preserving Godot's own exit code
rem past the tee, and hands it to the verdict (CR-008 — see test.bat).
set "EF_LOG=%EF_TEST_APPDATA%\suite.out"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_suite.ps1" -Godot "%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" -GamePath "%~dp0game" -Scene "res://scenes/test.tscn" -ExtraArgs "-- --quick" -Log "%EF_LOG%"
set "EF_GODOT_RC=%ERRORLEVEL%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0suite_verdict.ps1" -LogPath "%EF_LOG%" -PassMarker "AUTOTEST QUICK PASS" -ExitCode %EF_GODOT_RC%
set "EF_EXIT=%ERRORLEVEL%"
goto cleanup

:fail
set "EF_EXIT=1"
:cleanup
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
