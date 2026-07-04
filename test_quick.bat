@echo off
rem Quick test tier (~15s): compile gate, then boot / one class kit /
rem all systems tests / UI smoke / pause menu. For iterating on fixes.
rem Run test.bat (the FULL suite) before staging anything.
"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 exit /b 1
"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" res://scenes/test.tscn -- --quick
