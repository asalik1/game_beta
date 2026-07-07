@echo off
rem FULL test suite: compile gate, then both chapters end to end
rem (several minutes). Required green before staging.
rem For quick iteration use test_quick.bat.
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

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" res://scenes/test.tscn
set "EF_EXIT=%ERRORLEVEL%"
goto cleanup

:fail
set "EF_EXIT=1"
:cleanup
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
