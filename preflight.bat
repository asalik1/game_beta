@echo off
rem Preflight trap checks (CLAUDE.md traps, mechanized) -- see tools/preflight.py.
rem Run before staging. Fast (~2s + a few s for the codex data check);
rem add --fast to skip the engine, --strict to fail on warnings.
python "%~dp0tools\preflight.py" %*
exit /b %ERRORLEVEL%
