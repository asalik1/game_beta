@echo off
rem NET TEST: eleven stages, all over localhost ENet. Stages 1-9 prove the MP
rem feature waves (MP-05/07/09/10/11/12/13/14/16); stage 10 is the MP-17 soak
rem (host + guest, ~4 min: combat, transitions, down+revive, wipe, flag churn,
rem a disconnect+fresh-rejoin) asserting session stability over time; stage 11
rem is the Wave-1 co-op world-consistency fix (boss gates open for guests).
rem Stages 12-13 are the MMO steps A/B: 12 boots a DEDICATED headless world
rem authority (no host-player) and lands 2 guests on it — the world survives
rem every client leaving; 13 proves that world PERSISTS across a full server
rem restart (a throwaway server saves, a new server restores + a joiner reads it).
rem
rem VERDICT (MP-17 flake 1): each stage's stdout+stderr is captured to a log
rem and the AUTHORITATIVE pass/fail is a LOG GREP, not the process exit code.
rem A stage PASSES only if its log contains "NET TEST PASS" and contains none
rem of "NET TEST FAIL" / "previously freed" / "SCRIPT ERROR" / "Parse Error".
rem The exit code is only a SECONDARY signal: a KNOWN-nonzero exit also fails
rem the stage, but a $null/unreadable exit code (Start-Process -PassThru often
rem returns $null) defers entirely to the grep. The old wrapper did
rem `exit $p.ExitCode`, which read $null and MASKED a real failure as exit 0
rem (MP-13 finding). The director spawns its client processes as CHILDREN, so
rem their freed-object errors land in the same captured log.
rem
rem Compile gate FIRST, always (test.bat pattern): one parse error anywhere
rem makes a headless run idle forever. The PowerShell wrapper is the LAST-
rem RESORT kill: a top-level timeout taskkills /T by PID (director + the
rem client Godots it spawned, all its child processes).
rem
rem Throwaway user:// via APPDATA redirect, same as test.bat, so runs can't
rem race other suites on shared save/meta files.
setlocal
:uniq
set "EF_TEST_APPDATA=%TEMP%\emberfall_tests\run_%RANDOM%%RANDOM%"
if exist "%EF_TEST_APPDATA%" goto uniq
mkdir "%EF_TEST_APPDATA%" 2>nul || goto uniq
set "APPDATA=%EF_TEST_APPDATA%"

"%~dp0tools\Godot_v4.4.1-stable_win64_console.exe" --headless --path "%~dp0game" --script res://check_compile.gd
if errorlevel 1 goto fail

call :stage 1  120000 "res://scenes/net_test.tscn"          ""
if errorlevel 1 goto cleanup
call :stage 2  180000 "res://scenes/net_test_session.tscn"  "--net-stage=2"
if errorlevel 1 goto cleanup
call :stage 3  240000 "res://scenes/net_test_session.tscn"  "--net-stage=3"
if errorlevel 1 goto cleanup
call :stage 4  240000 "res://scenes/net_test_session.tscn"  "--net-stage=4"
if errorlevel 1 goto cleanup
call :stage 5  240000 "res://scenes/net_test_session.tscn"  "--net-stage=5"
if errorlevel 1 goto cleanup
call :stage 6  240000 "res://scenes/net_test_session.tscn"  "--net-stage=6"
if errorlevel 1 goto cleanup
call :stage 7  240000 "res://scenes/net_test_session.tscn"  "--net-stage=7"
if errorlevel 1 goto cleanup
call :stage 8  240000 "res://scenes/net_test_session.tscn"  "--net-stage=8"
if errorlevel 1 goto cleanup
call :stage 9  360000 "res://scenes/net_test_session.tscn"  "--net-stage=9"
if errorlevel 1 goto cleanup
call :stage 10 420000 "res://scenes/net_test_session.tscn"  "--net-stage=10"
if errorlevel 1 goto cleanup
call :stage 11 240000 "res://scenes/net_test_session.tscn"  "--net-stage=11"
if errorlevel 1 goto cleanup
call :stage 12 300000 "res://scenes/net_test_session.tscn"  "--net-stage=12"
if errorlevel 1 goto cleanup
call :stage 13 300000 "res://scenes/net_test_session.tscn"  "--net-stage=13"
if errorlevel 1 goto cleanup

set "EF_EXIT=0"
goto cleanup

:fail
set "EF_EXIT=1"
goto done

:cleanup
if not defined EF_EXIT set "EF_EXIT=%ERRORLEVEL%"
:done
rmdir /s /q "%EF_TEST_APPDATA%" 2>nul
exit /b %EF_EXIT%

rem ---- :stage <label> <timeout-ms> <scene> <user-args> -----------------
rem Runs one stage headless, captures its log, and returns the GREP verdict
rem in ERRORLEVEL (0 pass, nonzero fail). Env vars carry the parameters into
rem PowerShell so no path/arg needs cmd-side quoting inside the -Command body.
rem No setlocal here: the powershell exit code must reach the caller directly
rem via `exit /b %ERRORLEVEL%` (an endlocal on the same line would swallow it).
:stage
set "EF_SNAME=%~1"
set "EF_TMO=%~2"
set "EF_SCENE=%~3"
set "EF_UARGS=%~4"
set "EF_GODOT=%~dp0tools\Godot_v4.4.1-stable_win64_console.exe"
set "EF_GAME=%~dp0game"
set "EF_SLOG=%EF_TEST_APPDATA%\stage%~1.out"
set "EF_SERR=%EF_TEST_APPDATA%\stage%~1.err"
powershell -NoProfile -Command "$al=@('--headless','--path',$env:EF_GAME,$env:EF_SCENE); if ($env:EF_UARGS) { $al+='--'; $al+=$env:EF_UARGS }; $p=Start-Process -FilePath $env:EF_GODOT -ArgumentList $al -NoNewWindow -PassThru -RedirectStandardOutput $env:EF_SLOG -RedirectStandardError $env:EF_SERR; if (-not $p.WaitForExit([int]$env:EF_TMO)) { Write-Host ('NET TEST FAIL  stage '+$env:EF_SNAME+' timeout ('+$env:EF_TMO+'ms) - taskkill /T on PID '+$p.Id); taskkill /PID $p.Id /T /F | Out-Null; exit 124 }; $p.WaitForExit(); $txt=(Get-Content -Path $env:EF_SLOG,$env:EF_SERR -ErrorAction SilentlyContinue) -join [Environment]::NewLine; Write-Host $txt; $code=$p.ExitCode; $bad=($txt -match 'NET TEST FAIL') -or ($txt -match 'previously freed') -or ($txt -match 'SCRIPT ERROR') -or ($txt -match 'Parse Error'); $pass=$txt -match 'NET TEST PASS'; if ($bad -or (-not $pass)) { Write-Host ('NET TEST FAIL  stage '+$env:EF_SNAME+' verdict by log grep'); exit 1 }; if (($null -ne $code) -and ($code -ne 0)) { Write-Host ('NET TEST FAIL  stage '+$env:EF_SNAME+' grep PASS but nonzero exit '+$code); exit $code }; Write-Host ('[net_test] stage '+$env:EF_SNAME+' PASS (grep-verified)'); exit 0"
exit /b %ERRORLEVEL%
