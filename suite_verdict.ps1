# Verdict for a headless autotest run: the LOG is authoritative, not the exit code.
#
# Rationale (2026-07-17): the suite printed AUTOTEST PASS while a non-fatal
# "SCRIPT ERROR: Invalid access to property or key 'dmg'" sat in the log for an
# unknown number of runs (a delayed warlock ult read its class AFTER the class
# had changed). Godot does NOT fail a run for a non-fatal script error, so the
# exit code alone can never catch that class of bug. net_test.bat has greped its
# stage logs this way since MP-17; this brings the pass/fail tiers in line.
#
# A run PASSES only if its log contains <PassMarker> and none of "SCRIPT ERROR" /
# "Parse Error". autotest.gd prints its marker ONLY on success (failures quit(1)
# without printing), so the marker's absence also covers a hard crash mid-run.
# The exit code stays a SECONDARY signal: a known-nonzero exit fails a
# grep-clean run too.
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

$bad = @()
foreach ($pat in @('SCRIPT ERROR', 'Parse Error')) {
	if ($txt -match [regex]::Escape($pat)) { $bad += $pat }
}

if ($bad.Count -gt 0) {
	Write-Host ""
	Write-Host ("[suite] FAIL by log grep: found " + ($bad -join ', ') + " in the run log.")
	Write-Host "[suite] A non-fatal error is still a bug - the offending lines:"
	Select-String -LiteralPath $LogPath -Pattern 'SCRIPT ERROR', 'Parse Error' -Context 0, 1 |
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
