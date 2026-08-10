@echo off
rem PVP TIERS: the FAITHFUL, real-kit PvP class-tier instrument. Drives each
rem class's ACTUAL kit (dps_bench driver) to MEASURE throttled DPS (riders live)
rem + siege sustain + eHP, then composes a matchup matrix + tiers. The real-kit
rem counterpart to pvp_bench (lean kit-math) and pvp_duel_sim (1D lane).
rem Not a test tier - a balance instrument (see PROPOSALS/PVP_BALANCE.md).
rem
rem Usage:  pvp_tiers.bat [--secs=N] [--siege=N] [--cls=mage] [--trace]
rem --fixed-fps decouples the simulation from the wall clock.
setlocal

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 exit /b 1

:uniq
set "EF_TEST_APPDATA=%TEMP%\emberfall_tests\pvptiers_%RANDOM%%RANDOM%"
if exist "%EF_TEST_APPDATA%" goto uniq
mkdir "%EF_TEST_APPDATA%" 2>nul || goto uniq
set "APPDATA=%EF_TEST_APPDATA%"

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --fixed-fps 60 --path "%~dp0game" res://scenes/pvp_tiers.tscn -- %*
set "EF_EXIT=%ERRORLEVEL%"
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%
