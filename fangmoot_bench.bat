@echo off
rem FANGMOOT BENCH: bot-vs-bot moots, per-token/tribe win rates + length
rem distributions. A balance instrument (PROPOSALS/FANGMOOT.md §14), not a
rem test tier. Run before every tuning change.
rem
rem Usage:  fangmoot_bench.bat [--n=2000] [--table=silver] [--seed=12345]
setlocal

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 exit /b 1

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://fangmoot_bench.gd -- %*
exit /b %ERRORLEVEL%
