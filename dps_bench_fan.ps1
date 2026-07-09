# DPS BENCH FAN-OUT - called by dps_bench.bat when no --cls filter is given.
# Runs SIX headless Godot processes in parallel (one class each, its own
# throwaway APPDATA so user:// never races), waits for all, replays their
# logs in class order, then prints one merged ranking. --fixed-fps keeps
# every child's simulation identical regardless of CPU contention - the
# fan-out changes wall time only, never the numbers.
# Lives at the repo root with the .bat launchers (tools/ is gitignored).
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)

$root = $PSScriptRoot
$godot = Join-Path $root 'tools\Godot_v4.4.1-stable_win64_console.exe'
$classes = @('warrior', 'archer', 'mage', 'assassin', 'paladin', 'warlock')
$stamp = "fan_$PID" + "_" + (Get-Random)
$extra = ($Rest -join ' ')

$jobs = @()
foreach ($c in $classes) {
    $dir = Join-Path $env:TEMP "emberfall_tests\$stamp`_$c"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $log = Join-Path $dir 'bench.log'
    $cmd = "set ""APPDATA=$dir"" && ""$godot"" --headless --fixed-fps 60 --path ""$root\game"" res://scenes/dps_bench.tscn -- --cls=$c $extra > ""$log"" 2>&1"
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $cmd" -WindowStyle Hidden -PassThru
    $jobs += [pscustomobject]@{cls = $c; proc = $p; log = $log; dir = $dir}
}
Write-Output ("[fan] {0} classes benched in parallel (pids {1})" -f $jobs.Count, (($jobs | ForEach-Object { $_.proc.Id }) -join ', '))
$jobs | ForEach-Object { $_.proc.WaitForExit() }

$failed = 0
$dpsLines = @()
$headerShown = $false
foreach ($j in $jobs) {
    if ($j.proc.ExitCode -ne 0) {
        Write-Output ("[fan] FAILED: {0} (exit {1}) - log follows" -f $j.cls, $j.proc.ExitCode)
        Get-Content $j.log
        $failed++
        continue
    }
    foreach ($line in (Get-Content $j.log)) {
        if ($line -match '^\[bench\]') {
            if (-not $headerShown) { Write-Output $line }
        } elseif ($line -match '^\[dps\]') {
            Write-Output $line
            $dpsLines += $line
        } elseif ($line -match '^\[def\]') {
            Write-Output $line
        } elseif ($line -match 'BENCH STALL|SCRIPT ERROR') {
            Write-Output $line
        }
    }
    if ($dpsLines.Count -gt 0) { $headerShown = $true }
}

# One merged ranking across every class (the per-class runs each printed
# their own three-row table; this is the one that matters).
Write-Output ''
Write-Output '== DPS BENCH - merged ranking (all classes, parallel run) =='
$parsed = foreach ($line in $dpsLines) {
    if ($line -match '^\[dps\]\s+(\S+)\s+(\d+) dps') {
        [pscustomobject]@{case = $Matches[1]; dps = [int]$Matches[2]; line = $line}
    }
}
$rank = 1
foreach ($row in ($parsed | Sort-Object dps -Descending)) {
    Write-Output ("{0,2}. {1}" -f $rank, ($row.line -replace '^\[dps\] ', ''))
    $rank++
}
Write-Output ("DPS BENCH DONE ({0} cases, {1} parallel classes)" -f $parsed.Count, $jobs.Count)

foreach ($j in $jobs) {
    try { Remove-Item -Recurse -Force $j.dir -ErrorAction Stop } catch {}
}
if ($failed -gt 0) { exit 1 }
exit 0
