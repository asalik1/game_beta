@echo off
rem DEV MODE: same game plus the F1 debug panel — change class, level,
rem gear, terrain, and bosses instantly for fast feedback loops.
echo Reimporting assets...
"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --import --quit --path "%~dp0game"
start "" "%~dp0tools\Godot_v4.4.1-stable_win64.exe" --path "%~dp0game" -- --dev
