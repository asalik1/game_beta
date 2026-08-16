@echo off
rem Shot-rig runner: shot.bat <rig> [--timeout=N] [--no-gate] [--no-import] [rig args...]
rem   e.g.  shot.bat fx_series --class=mage --theme=ice --terrain=keep --timeout=90
rem Muted (--audio-driver Dummy), compile-gated (incl. the rig script), watchdogged
rem (in-engine RIG TIMEOUT + outer kill at N+15s), prints the shots dir at the end.
rem Details + exit codes: tools\shot_rig.ps1. Rig base class: game\scripts\dev\shot_rig.gd.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\shot_rig.ps1" %*
exit /b %ERRORLEVEL%
