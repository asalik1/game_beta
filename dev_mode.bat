@echo off
rem DEV MODE: same game plus the F1 debug panel - change class, level,
rem gear, terrain, and bosses instantly for fast feedback loops.
rem Pass --no-audio to launch silent (engine Dummy audio driver).
set "AUDIO_ARGS="
if /i "%~1"=="--no-audio" set "AUDIO_ARGS=--audio-driver Dummy"
echo Reimporting assets...
"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --import --quit --path "%~dp0game"
if defined AUDIO_ARGS echo Launching without audio.
start "" "%~dp0tools\Godot_v4.4.1-stable_win64.exe" %AUDIO_ARGS% --path "%~dp0game" -- --dev
