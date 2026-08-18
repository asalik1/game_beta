# Run a batch of headless Codex image_gen jobs, wait for all.
# Usage: powershell -File tools/art/run_codex_batch.ps1 -Stages "dir1,dir2,dir3" [-MaxParallel N] [-MinFreeGB G] [-TimeoutSec S] [-ExtraArgs "..."]
# Each <dir> must contain codex_brief.txt (the prompt, piped on STDIN) and may contain a refs/
# folder of PNG references (each attached with -i). Writes <dir>/codex_result.md (agent's final
# message, -o) and <dir>/codex_log.txt (full stdout+stderr) per job.
#
# The docs for everything below: C:\Users\asali\Projects\CODEX_HEADLESS.md (machine-wide: flags,
# binary drift, batching limits, image_gen quirks) + tools/CODEX_HEADLESS.md (the MMO layer).
#
#   -MaxParallel 0  = launch everything at once (legacy behaviour). On the shared 9.8GB box a
#                     parallel image batch + a Godot suite OOM-crashed the host (2026-08-17); use
#                     -MaxParallel 1 -MinFreeGB 1.3 when anything else is running.
#   -MinFreeGB 0    = no RAM gate. >0 = do not launch the next job until free RAM clears it.
#   -TimeoutSec 0   = wait forever. >0 = stop stragglers after S seconds (a hung image job
#                     otherwise blocks the batch; ~5 min is a normal single image).
#   -ExtraArgs      = appended verbatim to every `codex exec` (e.g. "-m gpt-5.6-luna",
#                     "-c model_reasoning_effort=`"high`"", "--dangerously-bypass-approvals-and-sandbox").
param(
  [string]$Stages,
  [int]$MaxParallel = 0,
  [double]$MinFreeGB = 0,
  [int]$TimeoutSec = 0,
  [string]$ExtraArgs = ""
)

# codex.exe lives under a HASHED dir that changes on every Codex app update; never hard-code it.
# Order: ~/.codex/config.toml CODEX_CLI_PATH (the app writes it, single-quoted TOML) ->
#        newest %LOCALAPPDATA%\OpenAI\Codex\bin\<hash>\codex.exe -> `codex` on PATH.
# Same order as tools/codex_bin.py (Python/bash callers).
function Resolve-Codex {
  $cfg = Join-Path $env:USERPROFILE ".codex\config.toml"
  if (Test-Path $cfg) {
    $m = Select-String -Path $cfg -Pattern '^\s*CODEX_CLI_PATH\s*=\s*[''"]([^''"]+)[''"]' | Select-Object -First 1
    if ($m) {
      $p = $m.Matches[0].Groups[1].Value
      if (Test-Path $p) { return $p }
      Write-Output "WARN: config CODEX_CLI_PATH is stale ($p) -- falling back to newest install"
    }
  }
  $bin = Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin"
  if (Test-Path $bin) {
    $c = Get-ChildItem $bin -Recurse -Filter codex.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($c) { return $c.FullName }
  }
  $cmd = Get-Command codex -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw "codex.exe not found: no CODEX_CLI_PATH in $cfg, nothing under $bin, nothing on PATH"
}

function Get-FreeGB {
  $os = Get-CimInstance Win32_OperatingSystem
  return [math]::Round($os.FreePhysicalMemory / 1MB, 2)   # FreePhysicalMemory is in KB
}

$codex = Resolve-Codex
Write-Output "codex = $codex"
$extra = @()
if ($ExtraArgs.Trim() -ne "") { $extra = $ExtraArgs.Trim() -split '\s+' }

$dirs = $Stages -split ','
$jobs = @()
foreach ($d in $dirs) {
  $d = $d.Trim()
  if ($d -eq "") { continue }
  if (-not (Test-Path "$d\codex_brief.txt")) { Write-Output "SKIP (no brief): $d"; continue }
  # throttle: slots + RAM gate
  while ($true) {
    $running = @($jobs | Where-Object { $_.State -eq 'Running' }).Count
    $slotOk = ($MaxParallel -le 0) -or ($running -lt $MaxParallel)
    $ramOk = $true
    if ($MinFreeGB -gt 0) { $free = Get-FreeGB; $ramOk = ($free -ge $MinFreeGB) }
    if ($slotOk -and $ramOk) { break }
    if (-not $ramOk) { Write-Output ("wait: free RAM {0}GB < {1}GB gate ({2} running)" -f $free, $MinFreeGB, $running) }
    Start-Sleep -Seconds 15
  }
  $refs = @()
  if (Test-Path "$d\refs") { $refs = @(Get-ChildItem "$d\refs\*.png" | ForEach-Object { $_.FullName }) }
  Write-Output ("launch: {0} ({1} refs)" -f $d, $refs.Count)
  $jobs += Start-Job -ScriptBlock {
    param($codex, $d, $refs, $extra)
    $iargs = @()
    foreach ($r in $refs) { $iargs += '-i'; $iargs += $r }
    $brief = Get-Content -Raw "$d\codex_brief.txt"
    # Prompt on STDIN (a positional prompt silently failed inside loops: "No prompt provided").
    $brief | & $codex exec -C $d -s workspace-write --skip-git-repo-check @iargs @extra -o "$d\codex_result.md" 2>&1 |
      Out-File -FilePath "$d\codex_log.txt" -Encoding utf8
  } -ArgumentList $codex, $d, $refs, $extra
}
Write-Output ("launched {0} codex jobs" -f $jobs.Count)
if ($jobs.Count -gt 0) {
  if ($TimeoutSec -gt 0) {
    $jobs | Wait-Job -Timeout $TimeoutSec | Out-Null
    $hung = @($jobs | Where-Object { $_.State -eq 'Running' })
    if ($hung.Count -gt 0) {
      Write-Output ("TIMEOUT: stopping {0} job(s) still running after {1}s" -f $hung.Count, $TimeoutSec)
      $hung | Stop-Job
    }
  } else {
    $jobs | Wait-Job | Out-Null
  }
  $jobs | Remove-Job -Force
}
# per-stage verdict: did the agent's final message land?
foreach ($d in $dirs) {
  $d = $d.Trim()
  if ($d -eq "" -or -not (Test-Path "$d\codex_brief.txt")) { continue }
  $res = "$d\codex_result.md"
  if (Test-Path $res) { Write-Output ("OK   {0}  (result {1} bytes)" -f $d, (Get-Item $res).Length) }
  else { Write-Output ("FAIL {0}  (no codex_result.md -- read codex_log.txt)" -f $d) }
}
Write-Output "batch complete"
