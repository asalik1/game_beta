# Verdict for a headless autotest run: the LOG is authoritative, not the exit code.
#
# Rationale (2026-07-17): the suite printed AUTOTEST PASS while a non-fatal
# "SCRIPT ERROR: Invalid access to property or key 'dmg'" sat in the log for an
# unknown number of runs (a delayed warlock ult read its class AFTER the class
# had changed). Godot does NOT fail a run for a non-fatal script error, so the
# exit code alone can never catch that class of bug. net_test.bat has greped its
# stage logs this way since MP-17; this brings the pass/fail tiers in line.
#
# A run PASSES only if its log contains <PassMarker> and none of the failure
# patterns below. autotest.gd prints its marker ONLY on success (failures quit(1)
# without printing), so the marker's absence also covers a hard crash mid-run.
#
# The exit code is now a REAL signal, not an assumed 0: the batch wrappers run
# Godot through run_suite.ps1, which preserves the engine's native exit code past
# the tee, and pass it here as -ExitCode. A nonzero engine exit fails even a
# grep-clean run (CR-008).
#
# Failure patterns (CR-008): the log grep also rejects leaked-resource lines.
# The full suite used to print "AUTOTEST PASS" and THEN leak RIDs/ObjectDB
# instances at teardown while the wrapper still exited green (CR-009 traced those
# to unfreed probe nodes and fixed them). Treating the leak lines as failures
# keeps that class of teardown regression from ever passing silently again.
param(
	[Parameter(Mandatory = $true)][string]$LogPath,
	[Parameter(Mandatory = $true)][string]$PassMarker,
	[int]$ExitCode = 0
)

if (-not (Test-Path -LiteralPath $LogPath)) {
	Write-Host "[suite] FAIL: no log at $LogPath - the run produced no output."
	exit 1
}

$txt = Get-Content -LiteralPath $LogPath -Raw -ErrorAction SilentlyContinue
if ($null -eq $txt) { $txt = "" }

# Substrings that fail a run wherever they appear in the log. SCRIPT ERROR /
# Parse Error are non-fatal to Godot but real bugs. The two leak patterns are
# the NODE / visual-resource ownership class (CR-008/CR-009): a Node removed but
# not freed prints "N RIDs of type <CanvasItem/...> were leaked" AND "N RID
# allocations of type <...> were leaked at exit" — exactly the DummyTexture leak
# the old wrapper let through.
#
# Deliberately NOT failed on: a bare "ObjectDB instances leaked at exit" WARNING
# with NO accompanying RID line. That is pure-RefCounted teardown noise — a
# couple of SceneTreeTimers left pending because the headless suite calls quit()
# while a wall-clock `await create_timer(...)` is still counting down (the timer
# never fires, so it never self-frees). It is unavoidable and harmless; a real
# leaked Node always ALSO emits the RID lines above, which still fail the run.
$failPatterns = @('SCRIPT ERROR', 'Parse Error', 'Lambda capture at index', 'were leaked at exit',
	'RIDs of type')
$bad = @()
foreach ($pat in $failPatterns) {
	if ($txt -match [regex]::Escape($pat)) { $bad += $pat }
}

if ($bad.Count -gt 0) {
	Write-Host ""
	Write-Host ("[suite] FAIL by log grep: found " + ($bad -join ', ') + " in the run log.")
	Write-Host "[suite] A non-fatal error or resource leak is still a bug - the offending lines:"
	Select-String -LiteralPath $LogPath -Pattern $failPatterns -Context 0, 1 |
		ForEach-Object { Write-Host ("  " + $_.Line.Trim()) }
	exit 1
}

if ($txt -notmatch [regex]::Escape($PassMarker)) {
	Write-Host ""
	Write-Host "[suite] FAIL: '$PassMarker' never printed - the run failed or died early."
	exit 1
}

if ($ExitCode -ne 0) {
	Write-Host ""
	Write-Host "[suite] FAIL: log is clean but the engine exited $ExitCode."
	exit $ExitCode
}

exit 0
