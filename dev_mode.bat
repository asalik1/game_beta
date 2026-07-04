@echo off
rem DEV MODE: same game plus the F1 debug panel — change class, level,
rem gear, terrain, and bosses instantly for fast feedback loops.
start "" "%~dp0tools\Godot_v4.4.1-stable_win64.exe" --path "%~dp0game" -- --dev
