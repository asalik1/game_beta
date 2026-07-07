@echo off
rem Quick test tier (~15s): compile gate, then boot / one class kit /
rem all systems tests / UI smoke / pause menu. For iterating on fixes.
rem Run test.bat (the FULL suite) before staging anything.
rem
rem Each run gets its own throwaway user:// via APPDATA redirect so
rem concurrent runs can't race on shared save/meta files - see test.bat.
setlocal
:uniq
set "EF_TEST_APPDATA=%TEMP%\emberfall_tests\run_%RANDOM%%RANDOM%"
if exist "%EF_TEST_APPDATA%" goto uniq
mkdir "%EF_TEST_APPDATA%" 2>nul || goto uniq
set "APPDATA=%EF_TEST_APPDATA%"

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 goto fail

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" res://scenes/test.tscn -- --quick
set "EF_EXIT=%ERRORLEVEL%"
goto cleanup

:fail
set "EF_EXIT=1"
:cleanup
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
