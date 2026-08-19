@echo off
rem FULL test suite: compile gate, then both chapters end to end
rem (several minutes). Required green before staging.
rem For quick iteration use test_quick.bat.
rem
rem VERDICT: the run is teed to a log and the pass/fail is a LOG GREP
rem (suite_verdict.ps1), not the exit code alone - a non-fatal SCRIPT ERROR
rem does NOT stop Godot, so it used to slip through under "AUTOTEST PASS".
rem Output still streams live, so a zombie run still looks different from a
rem slow one. See suite_verdict.ps1 for the full rationale.
rem
rem Each run gets its own throwaway user:// by redirecting APPDATA
rem (user:// = %%APPDATA%%\Godot\app_userdata\Emberfall on Windows;
rem this Godot build has no --user-data-dir flag). Without this,
rem concurrent suites race on the shared scratch save slot, daily-login
rem meta, and settings. The dir is deleted on exit; shipping save
rem behavior is untouched.
setlocal
:uniq
set "EF_TEST_APPDATA=%TEMP%\emberfall_tests\run_%RANDOM%%RANDOM%"
if exist "%EF_TEST_APPDATA%" goto uniq
mkdir "%EF_TEST_APPDATA%" 2>nul || goto uniq
set "APPDATA=%EF_TEST_APPDATA%"

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 goto fail

rem run_suite.ps1 tees the run live to the log AND preserves Godot's OWN exit
rem code past the tee (a bare "godot | tee" pipe reports the tee's exit, so a
rem nonzero engine exit after the pass marker used to slip through). It also
rem keeps the stderr->stdout merge inside cmd, so SCRIPT ERROR lines land in the
rem log unwrapped. The captured engine code is handed to the verdict (CR-008).
set "EF_LOG=%EF_TEST_APPDATA%\suite.out"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_suite.ps1" -Godot "%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" -GamePath "%~dp0game" -Scene "res://scenes/test.tscn" -Log "%EF_LOG%"
set "EF_GODOT_RC=%ERRORLEVEL%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0suite_verdict.ps1" -LogPath "%EF_LOG%" -PassMarker "AUTOTEST PASS" -ExitCode %EF_GODOT_RC%
set "EF_EXIT=%ERRORLEVEL%"
goto cleanup

:fail
set "EF_EXIT=1"
:cleanup
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
