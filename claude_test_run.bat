@echo off
rem Temporary test runner (written by Claude) — runs the compile gate,
rem the quick tier, then the FULL suite, logging to claude_test.log.
rem Safe to delete after the run. Not for staging.
cd /d "%~dp0"
set G=tools\Godot_v4.4.1-stable_win64_console.exe
echo [GATE] start > claude_test.log
%G% --headless --path game --script res://check_compile.gd >> claude_test.log 2>&1
echo [GATE] exit %ERRORLEVEL% >> claude_test.log
if errorlevel 1 goto end
echo [QUICK] start >> claude_test.log
%G% --headless --path game res://scenes/test.tscn -- --quick >> claude_test.log 2>&1
echo [QUICK] exit %ERRORLEVEL% >> claude_test.log
if errorlevel 1 goto end
echo [FULL] start >> claude_test.log
%G% --headless --path game res://scenes/test.tscn >> claude_test.log 2>&1
echo [FULL] exit %ERRORLEVEL% >> claude_test.log
:end
echo [DONE] >> claude_test.log
exit
