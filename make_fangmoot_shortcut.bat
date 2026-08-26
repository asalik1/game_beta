@echo off
rem Puts a "Fangmoot" shortcut on your Desktop (launches the standalone).
rem Re-run this after merging Fangmoot to main to re-point the shortcut.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_fangmoot_shortcut.ps1"
pause
