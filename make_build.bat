@echo off
rem ============================================================================
rem  make_build.bat  -  MP-18: cut the friends co-op zip (Windows x86_64).
rem
rem  Pipeline (fails LOUDLY at every step - house rule):
rem    1. compile gate (check_compile.gd)   - the real parse error in ~3s
rem    2. test_quick.bat                     - gate + boot + kit + systems + UI
rem    3. regenerate the audio manifest      - exported builds read it, not the
rem                                            live sound/music folders
rem    4. headless Windows export            - single self-contained exe
rem                                            (embed_pck=true) into build\
rem    5. zip exe + FRIENDS_README + CREDITS  - build\Crownless_<ver>_win64.zip
rem
rem  The zip name's <ver> is read straight from NET_VERSION in
rem  net_manager.gd (the ONE source of truth, and the value the join
rem  handshake compares) so the filename can never drift from the gate.
rem  net_manager.gd is only ever READ here, never written.
rem
rem  Run from the repo root:  make_build.bat
rem  Output lands in build\ (gitignored). See DISTRIBUTION.md for the
rem  release checklist and the SmartScreen / noray / signing posture.
rem ============================================================================
setlocal
set "ROOT=%~dp0"
set "GODOT=%ROOT%tools\Godot_v4.4.1-stable_win64_console.exe"
set "PROJ=%ROOT%game"
set "BUILD=%ROOT%build"

if not exist "%GODOT%" (
  echo [make_build] FAILED: Godot binary not found at "%GODOT%".
  exit /b 1
)

rem --- NET_VERSION: read the const from net_manager.gd (read-only) ------------
set "NETVER="
for /f "tokens=4 delims= " %%v in ('findstr /c:"const NET_VERSION" "%PROJ%\scripts\net\net_manager.gd"') do set "NETVER=%%v"
set NETVER=%NETVER:"=%
if "%NETVER%"=="" (
  echo [make_build] FAILED: could not read NET_VERSION from net_manager.gd.
  exit /b 1
)
echo [make_build] Building Crownless  NET_VERSION = %NETVER%

rem --- 1. compile gate --------------------------------------------------------
echo [make_build] [1/5] Compile gate...
"%GODOT%" --headless --path "%PROJ%" --script res://check_compile.gd
if errorlevel 1 (
  echo [make_build] FAILED at the compile gate - fix the parse error above.
  exit /b 1
)

rem --- 2. quick test tier -----------------------------------------------------
echo [make_build] [2/5] Quick test suite...
call "%ROOT%test_quick.bat"
if errorlevel 1 (
  echo [make_build] FAILED: test_quick.bat was not green.
  exit /b 1
)

rem --- 3. audio manifest (best-effort: committed manifest is the fallback) ----
echo [make_build] [3/5] Regenerating audio manifest...
where python >nul 2>nul
if errorlevel 1 (
  echo [make_build]   python not found - using the committed asset_manifest.json.
) else (
  python "%ROOT%gen_asset_manifest.py"
  if errorlevel 1 (
    echo [make_build] FAILED: gen_asset_manifest.py errored.
    exit /b 1
  )
)
if not exist "%PROJ%\assets\asset_manifest.json" (
  echo [make_build] FAILED: assets\asset_manifest.json is missing - exported audio would be silent.
  exit /b 1
)

rem --- 4. headless export (single embedded-pck exe) into build\ ---------------
echo [make_build] [4/5] Exporting Windows Desktop (headless)...
if not exist "%BUILD%" mkdir "%BUILD%"
if exist "%BUILD%\Crownless.exe" del /q "%BUILD%\Crownless.exe"
"%GODOT%" --headless --path "%PROJ%" --export-release "Windows Desktop" "%BUILD%\Crownless.exe"
if errorlevel 1 (
  echo [make_build] FAILED at the export step.
  exit /b 1
)
if not exist "%BUILD%\Crownless.exe" (
  echo [make_build] FAILED: the export produced no Crownless.exe.
  exit /b 1
)

rem --- 5. zip: exe + FRIENDS_README + CREDITS (license notices) ---------------
echo [make_build] [5/5] Zipping...
set "ZIP=%BUILD%\Crownless_%NETVER%_win64.zip"
if exist "%ZIP%" del /q "%ZIP%"
powershell -NoProfile -Command "Compress-Archive -Force -Path '%BUILD%\Crownless.exe','%ROOT%FRIENDS_README.txt','%PROJ%\addons\CREDITS.txt' -DestinationPath '%ZIP%'"
if errorlevel 1 (
  echo [make_build] FAILED at the zip step.
  exit /b 1
)
if not exist "%ZIP%" (
  echo [make_build] FAILED: no zip was produced.
  exit /b 1
)

echo.
echo [make_build] DONE.
echo [make_build]   zip:  %ZIP%
for %%A in ("%ZIP%") do echo [make_build]   size: %%~zA bytes
echo [make_build]   Hand this zip to friends. See FRIENDS_README.txt (inside) for their steps.
exit /b 0
