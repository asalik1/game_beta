# DPS BENCH REPEAT-FAN - runs ONE case N times in parallel, each with an
# independent RNG stream (--rep=i), and reports mean/min/max/spread. Use it
# to pin a single spec's TRUE central DPS (crit variance averages out) while
# tuning it. Numbers are decoupled from wall clock (--fixed-fps); parallel
# only saves time. Lives at repo root with the other launchers.
#
# Usage:  dps_bench_rep.ps1 --cls=assassin --theme=shadow [--aoe] [--runs=6] [--secs=N]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)

$root  = $PSScriptRoot
$godot = Join-Path $root 'tools\Godot_v4.4.1-stable_win64_console.exe'

# compile gate first (same as the .bat entry)
& $godot --headless --path "$root\game" --script res://check_compile.gd | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Output 'COMPILE FAILED'; exit 1 }

$runs = 6
$passthru = @()
foreach ($a in $Rest) {
    if ($a -match '^--runs=(\d+)$') { $runs = [int]$Matches[1] } else { $passthru += $a }
}
$extra = ($passthru -join ' ')
$stamp = "rep_$PID" + "_" + (Get-Random)

$jobs = @()
for ($i = 0; $i -lt $runs; $i++) {
    $dir = Join-Path $env:TEMP "emberfall_tests\$stamp`_$i"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $log = Join-Path $dir 'bench.log'
    $cmd = "set ""APPDATA=$dir"" && ""$godot"" --headless --fixed-fps 60 --path ""$root\game"" res://scenes/dps_bench.tscn -- $extra --rep=$i > ""$log"" 2>&1"
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $cmd" -WindowStyle Hidden -PassThru
    $jobs += [pscustomobject]@{i = $i; proc = $p; log = $log; dir = $dir}
}
Write-Output ("[rep] {0} parallel runs of '{1}' (pids {2})" -f $runs, $extra, (($jobs | ForEach-Object { $_.proc.Id }) -join ', '))
$jobs | ForEach-Object { $_.proc.WaitForExit() }

$vals = @()
$hdr = ''
foreach ($j in ($jobs | Sort-Object i)) {
    if ($j.proc.ExitCode -ne 0) {
        Write-Output ("[rep] FAILED run {0} (exit {1}) - log follows" -f $j.i, $j.proc.ExitCode)
        Get-Content $j.log
        continue
    }
    foreach ($line in (Get-Content $j.log)) {
        if ($line -match '^\[bench\] target' -and $hdr -eq '') { $hdr = $line; Write-Output $line }
        elseif ($line -match '^\[dps\]\s+(\S+)\s+(\d+) dps') {
            $vals += [int]$Matches[2]
            Write-Output ("  run {0}: {1}" -f $j.i, ($line -replace '^\[dps\] ', ''))
        } elseif ($line -match 'BENCH STALL|SCRIPT ERROR') { Write-Output $line }
    }
}

if ($vals.Count -gt 0) {
    $m = ($vals | Measure-Object -Average -Minimum -Maximum)
    $mean = [int][math]::Round($m.Average)
    $spread = [int]($m.Maximum - $m.Minimum)
    $pct = [math]::Round(100.0 * $spread / $m.Average, 1)
    Write-Output ''
    Write-Output ("== MEAN {0} dps  (n={1}, min {2}, max {3}, spread {4} = {5}%) ==" -f `
        $mean, $vals.Count, [int]$m.Minimum, [int]$m.Maximum, $spread, $pct)
}

foreach ($j in $jobs) { try { Remove-Item -Recurse -Force $j.dir -ErrorAction Stop } catch {} }
exit 0
