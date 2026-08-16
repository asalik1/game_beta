# Run a batch of headless Codex image_gen jobs in parallel, wait for all.
# Usage: powershell -File run_codex_batch.ps1 -Stages "dir1,dir2,dir3"
# Each <dir> must contain codex_brief.txt and a refs/ folder of PNG references.
# Writes <dir>/codex_result.md and <dir>/codex_log.txt per job.
param([string]$Stages)

$codex = 'C:\Users\asali\AppData\Local\OpenAI\Codex\bin\8e8bf206e63ac436\codex.exe'
$dirs = $Stages -split ','
$jobs = @()
foreach ($d in $dirs) {
  $d = $d.Trim()
  if (-not (Test-Path "$d\codex_brief.txt")) { Write-Output "SKIP (no brief): $d"; continue }
  $refs = Get-ChildItem "$d\refs\*.png" | ForEach-Object { $_.FullName }
  $jobs += Start-Job -ScriptBlock {
    param($codex, $d, $refs)
    $iargs = @()
    foreach ($r in $refs) { $iargs += '-i'; $iargs += $r }
    $brief = Get-Content -Raw "$d\codex_brief.txt"
    $brief | & $codex exec -C $d -s workspace-write --skip-git-repo-check @iargs -o "$d\codex_result.md" 2>&1 |
      Out-File -FilePath "$d\codex_log.txt" -Encoding utf8
  } -ArgumentList $codex, $d, $refs
}
Write-Output ("launched {0} codex jobs" -f $jobs.Count)
$jobs | Wait-Job | Out-Null
$jobs | Remove-Job
Write-Output "batch complete"
