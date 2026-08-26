@echo off
rem Play FANGMOOT standalone — the tavern autobattler, without the Crownless
rem campaign. Boots straight into the Carver's Circle. (PROPOSALS/FANGMOOT.md §18)
rem Double-click this file, or use the Desktop shortcut from make_fangmoot_shortcut.bat.
start "" "%~dp0tools\Godot_v4.4.1-stable_win64.exe" --path "%~dp0game" -- --fangmoot
