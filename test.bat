@echo off
rem FULL test suite: compile gate, then both chapters end to end
rem (several minutes). Required green before staging.
rem For quick iteration use test_quick.bat.
"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 exit /b 1
"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" res://scenes/test.tscn
