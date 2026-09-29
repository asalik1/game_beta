@echo off
setlocal enabledelayedexpansion
title Crownless Dev Launcher
color 0E

set "BASE=C:\Users\asali\Projects\MMO"
set "WT=%BASE%\.claude\worktrees"
set "CXWT=%BASE%\.codex\worktrees"

:menu
cls
echo(
echo   ================================================
echo     CROWNLESS DEV LAUNCHER
echo   ================================================
echo(
echo     Pick a worktree to launch in dev mode:
echo(

set /a n=0
set /a n+=1
set "path[!n!]=%BASE%"
set "name[!n!]=main"
echo       !n!^) main

if exist "%WT%" (
  for /d %%D in ("%WT%\*") do (
    set /a n+=1
    set "path[!n!]=%%~fD"
    set "name[!n!]=%%~nxD"
    echo       !n!^) %%~nxD
  )
)

if exist "%CXWT%" (
  for /d %%D in ("%CXWT%\*") do (
    set "cxname=%%~nxD"
    if /i not "!cxname:~0,8!"=="cw-lane-" (
      set /a n+=1
      set "path[!n!]=%%~fD"
      set "name[!n!]=!cxname! (codex)"
      echo       !n!^) !cxname! ^(codex^)
    )
  )
)

echo(
echo       Q^) Quit
echo(
set "choice="
set /p "choice=  Number (or Q): "

if not defined choice goto menu
if /i "!choice!"=="Q" exit /b 0

set "sel=!path[%choice%]!"
set "selname=!name[%choice%]!"
if not defined sel (
  echo(
  echo   ^>^> "!choice!" is not on the list.
  timeout /t 2 >nul
  goto menu
)

set "bat=!sel!\dev_mode.bat"
if not exist "!bat!" (
  echo(
  echo   ^>^> No dev_mode.bat found in "!selname!".
  timeout /t 2 >nul
  goto menu
)

echo(
echo   Launching !selname! ...
echo(
cd /d "!sel!"
call "!bat!"
exit /b 0
