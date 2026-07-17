@echo off
rem Rebuild Crownless for Windows, macOS, and Linux into executables\.
rem Regenerates the audio manifest first: exported builds can't scan the
rem sound/music folders, so they read assets\asset_manifest.json instead.
rem Output paths are set per-preset in game\export_presets.cfg.
setlocal
set GODOT=%~dp0tools\Godot_v4.4.1-stable_win64.exe
set PROJ=%~dp0game

echo [1/5] Regenerating asset manifest...
python "%~dp0gen_asset_manifest.py" || echo   (skipped: python not found; using existing manifest)

echo [2/5] Importing project...
"%GODOT%" --headless --path "%PROJ%" --import

echo [3/5] Exporting Windows...
"%GODOT%" --headless --path "%PROJ%" --export-release "Windows Desktop"
echo [4/5] Exporting macOS...
"%GODOT%" --headless --path "%PROJ%" --export-release "macOS"
echo [5/5] Exporting Linux...
"%GODOT%" --headless --path "%PROJ%" --export-release "Linux"

echo.
echo Done. Builds are in executables\  (see executables\README.txt)
pause
