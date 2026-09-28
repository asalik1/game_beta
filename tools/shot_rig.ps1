# Shot-rig runner (2026-08-15)  -  the one way to run an in-engine screenshot rig.
#
#   shot.bat <rig> [--timeout=N] [--fixed-fps=N] [--mobile] [--renderer=METHOD] [--no-gate] [--no-import] [rig args...]
#
#   <rig>      fx_series | shot_fx_series | qa_skins | any game/<name>.tscn or game/shot_<name>.tscn
#   rig args   everything else is passed to the engine after `--` (a ShotRig reads them via arg()/flag()).
#              --timeout=N is read by BOTH sides: the in-engine watchdog (RIG TIMEOUT, exit 2) and this
#              outer kill at N+GRACE s (exit 3) for an engine that is wedged past its own timer. Default 120.
#              N counts from process launch (the first frame's delta includes startup), but a Godot Timer
#              can only fire ON a frame and this game's first frame comes ~15-30 s in (Vulkan/pipeline
#              startup + the synchronous boot of main.tscn) - so N below ~30 can only fire on that first
#              frame, and GRACE (60 s) exists so the outer kill never beats a slow-but-healthy boot.
#
# What it does, in order:
#   1. resolve the rig scene
#      isolate user:// from the owner's real profile: import, gate and rig all run on
#      build/qa/shot_profile (or the caller's own isolated APPDATA)  -  see "Isolation" below
#   2. ensure `ShotRig` is in game/.godot's class cache  -  a new class_name needs one --import or the
#      engine hangs silently (CLAUDE.md trap); runs it if missing (--no-import to refuse)
#   3. compile gate: check_compile.gd over res://scripts PLUS the rig script itself (a rig with a parse
#      error opens a window that idles forever  -  check_compile's default walk does not cover game/ root)
#   4. launch WINDOWED (a rig can't be --headless: viewport readback needs a real renderer) and MUTED
#      (--audio-driver Dummy  -  owner ruling 2026-08-15, rigs boot the real game with music+SFX on a
#      shared machine), tail the log live, kill at the outer deadline
#   5. print the verdict line: exit code, RIG DONE/TIMEOUT/KILLED, shots dir + how many PNGs this run wrote
#
# Exit codes: the rig's own (0 ok / 1 rig-declared defect / 2 in-engine watchdog) | 3 killed by this
# runner | 4 compile gate failed | 5 rig not found | 6 --import failed | 7 missing completion |
# 8 the rig's user:// resolved outside the isolated APPDATA (RIG SHOTS DIR elsewhere).
# Script errors in either stream fail even when the engine and rig print exit=0.
#
# Windows PowerShell 5.1 (no &&, no ternary). Invoked by shot.bat; args land in $args.

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'shot_verdict.ps1')
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root 'tools\Godot_v4.4.1-stable_win64_console.exe'
$gameDir = Join-Path $root 'game'

function Show-Rigs {
    Write-Host "[shot] available rigs (game/*.tscn with a shot_/qa_ script):"
    Get-ChildItem (Join-Path $gameDir '*.tscn') | Where-Object { $_.Name -match '^(shot_|qa_)' } | ForEach-Object {
        Write-Host ("    " + $_.BaseName)
    }
}

if ($args.Count -lt 1) {
    Write-Host "usage: shot.bat <rig> [--timeout=N] [--no-gate] [--no-import] [rig args...]"
    Show-Rigs
    exit 5
}

$rig = [string]$args[0]
$rest = @()
if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }

$timeout = 120.0
$grace = 60.0     # outer kill = timeout + grace; see the header for why 60
$gate = $true
$doImport = $true
$rigArgs = @()
$fixedFps = 0     # --fixed-fps=N: engine flag for frame-SERIES rigs (deterministic 1/N s per frame)
$renderingMethod = ''  # optional renderer override for platform QA on this host
foreach ($a in $rest) {
    $s = [string]$a
    if ($s -match '^--timeout=(.+)$') {
        $timeout = [double]$Matches[1]
        $rigArgs += $s            # the in-engine watchdog reads the same value
    } elseif ($s -match '^--fixed-fps=(\d+)$') {
        $fixedFps = [int]$Matches[1]
    } elseif ($s -eq '--mobile') {
        $gameDir = Join-Path $root 'mobile\game'
    } elseif ($s -match '^--renderer=(forward_plus|mobile|gl_compatibility)$') {
        $renderingMethod = $Matches[1]
    } elseif ($s -like '--renderer=*') {
        Write-Host '[shot] renderer must be forward_plus, mobile, or gl_compatibility'
        exit 5
    } elseif ($s -eq '--no-gate') {
        $gate = $false
    } elseif ($s -eq '--no-import') {
        $doImport = $false
    } else {
        $rigArgs += $s
    }
}

# 1. resolve
$scene = $null
foreach ($c in @("$rig.tscn", "shot_$rig.tscn")) {
    if (Test-Path (Join-Path $gameDir $c)) { $scene = $c; break }
}
if (-not $scene) {
    Write-Host "[shot] no rig named '$rig' (looked for game/$rig.tscn and game/shot_$rig.tscn)"
    Show-Rigs
    exit 5
}
$script = [IO.Path]::ChangeExtension($scene, '.gd')
Write-Host "[shot] project=$gameDir rig=$scene timeout=${timeout}s (outer kill at $($timeout + $grace)s) args=[$($rigArgs -join ' ')]"

# Isolation. The owner plays on this machine, and Godot resolves user:// from
# %APPDATA%; ShotRig's no_saves does not fence settings/keybind reads or every
# rig's persistence probes. So when APPDATA is unset or is the owner's real
# roaming profile, every engine process below (import, gate, rig) runs on this
# checkout's own profile, build/qa/shot_profile, and never touches the owner's.
# Before each run its user:// is emptied except shots/ and the shader/pipeline
# caches: settings, keybinds, saves and meta start from script defaults, the
# shots land in one stable place for tools/art/build_csdemo.py,
# gif_from_frames.py and mobqa_filmstrip.py, and boots stay warm. A run that
# finds the profile busy (a second shot.bat in this checkout) gets a throwaway
# profile under build/qa/shot_runs instead of wiping the first run's files.
# Any other APPDATA (e.g. a <name>-candidate directory) is the caller's own
# isolation and is used exactly as given. The runner's own environment is only
# changed while it launches an engine, then restored.
$callerAppData = $env:APPDATA
$shotAppData = $callerAppData
$profileLock = $null
$keepUserItems = @('shots', 'shader_cache', 'vulkan')

function Get-FullDir([string]$path) {
    if (-not $path) { return '' }
    return [IO.Path]::GetFullPath($path).TrimEnd('\')
}

function Exit-Shot([int]$code) {
    if ($script:profileLock) { $script:profileLock.Dispose(); $script:profileLock = $null }
    exit $code
}

function Invoke-Isolated([scriptblock]$body) {
    $saved = $env:APPDATA
    $env:APPDATA = $script:shotAppData
    try { & $body } finally { $env:APPDATA = $saved }
}

function Reset-ShotProfile([string]$appData) {
    # Empty every project's user:// except the keep list. Directory.Delete
    # removes a junction itself rather than following it.
    $userRoot = Join-Path $appData 'Godot\app_userdata'
    if (-not (Test-Path -LiteralPath $userRoot)) { return }
    foreach ($project in @(Get-ChildItem -LiteralPath $userRoot -Directory -Force)) {
        foreach ($item in @(Get-ChildItem -LiteralPath $project.FullName -Force)) {
            if ($keepUserItems -contains $item.Name) { continue }
            if ($item.PSIsContainer) { [IO.Directory]::Delete($item.FullName, $true) }
            else { Remove-Item -LiteralPath $item.FullName -Force }
        }
    }
}

$qaRoot = Join-Path $root 'build\qa'
$managedAppData = Get-FullDir (Join-Path $qaRoot 'shot_profile')
$requestedAppData = Get-FullDir $callerAppData
# The Known Folder, not the env var: it still names the owner's real profile
# when APPDATA has been pointed elsewhere.
$ownerAppData = Get-FullDir ([Environment]::GetFolderPath('ApplicationData'))
if ((-not $requestedAppData) -or ($requestedAppData -ieq $ownerAppData) -or ($requestedAppData -ieq $managedAppData)) {
    $shotAppData = $managedAppData
    New-Item -ItemType Directory -Force -Path $shotAppData | Out-Null
    try {
        $profileLock = [IO.File]::Open((Join-Path $shotAppData '.shot_rig.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
        Reset-ShotProfile $shotAppData
        Write-Host "[shot] isolated APPDATA=$shotAppData (settings, keybinds and saves reset; shots and shader caches kept; owner profile untouched)"
    } catch {
        $why = $_.Exception.Message
        if ($profileLock) { $profileLock.Dispose(); $profileLock = $null }
        $runsDir = Join-Path $qaRoot 'shot_runs'
        $shotAppData = Join-Path $runsDir ('run_' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $shotAppData | Out-Null
        # Keep the newest few throwaway profiles; older ones are only disk.
        $oldRuns = @(Get-ChildItem -LiteralPath $runsDir -Directory -Filter 'run_*' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5)
        foreach ($old in $oldRuns) { try { [IO.Directory]::Delete($old.FullName, $true) } catch { } }
        Write-Host "[shot] $managedAppData is busy (another shot run in this checkout?): $why"
        Write-Host "[shot] isolated APPDATA=$shotAppData (throwaway for this run; owner profile untouched)"
    }
} else {
    Write-Host "[shot] APPDATA=$callerAppData (caller-supplied isolation, used as given)"
}

# 2. class cache
$cache = Join-Path $gameDir '.godot\global_script_class_cache.cfg'
$needImport = $true
if (Test-Path $cache) {
    if (Select-String -Path $cache -Pattern '"class": &"ShotRig"' -Quiet) { $needImport = $false }
}
if ($needImport) {
    if (-not $doImport) {
        Write-Host "[shot] ShotRig is NOT in the class cache and --no-import was given; the engine would hang. Run: $godot --headless --path $gameDir --editor --import --quit"
        Exit-Shot 6
    }
    Write-Host "[shot] ShotRig not in the class cache -> running --import once (contends with an open editor; a cold import in a fresh worktree is >10 min  -  copy .godot from the main checkout first)"
    Invoke-Isolated { & $godot --headless --path $gameDir --editor --import --quit | Out-Null }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[shot] --import failed (exit $LASTEXITCODE)"
        Exit-Shot 6
    }
    if (-not (Select-String -Path $cache -Pattern '"class": &"ShotRig"' -Quiet)) {
        Write-Host "[shot] --import ran but ShotRig is still missing from $cache  -  is game/scripts/dev/shot_rig.gd present and parseable?"
        Exit-Shot 6
    }
}

# 3. compile gate (scripts/ + the rig + the base)
if ($gate) {
    Invoke-Isolated { & $godot --headless --path $gameDir --script res://check_compile.gd -- "res://$script" 'res://scripts/dev/shot_rig.gd' }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[shot] COMPILE GATE FAILED  -  fix the parse error above. (A rig with a parse error opens a window that idles forever; that is why the gate runs first.)"
        Exit-Shot 4
    }
} else {
    Write-Host "[shot] compile gate SKIPPED (--no-gate)"
}

# 4. launch
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logDir = Join-Path $env:TEMP 'crownless_shots'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$outLog = Join-Path $logDir "$($scene -replace '\.tscn$','')_$stamp.out"
$errLog = Join-Path $logDir "$($scene -replace '\.tscn$','')_$stamp.err"
$argList = @('--audio-driver', 'Dummy')
if ($renderingMethod) { $argList += @('--rendering-method', $renderingMethod) }
if ($fixedFps -gt 0) { $argList += @('--fixed-fps', "$fixedFps") }
$argList += @('--path', $gameDir, "res://$scene", '--') + $rigArgs
$quoted = @()
foreach ($a in $argList) {
    if ($a -match '\s') { $quoted += ('"' + $a + '"') } else { $quoted += $a }
}
Write-Host "[shot] $godot $($quoted -join ' ')"
$started = Get-Date
$p = Invoke-Isolated { Start-Process -FilePath $godot -ArgumentList $quoted -PassThru -NoNewWindow -RedirectStandardOutput $outLog -RedirectStandardError $errLog }
$null = $p.Handle   # cache the handle now or .ExitCode reads empty after exit (PS 5.1 quirk)
$deadline = $started.AddSeconds($timeout + $grace)
$killed = $false
$offset = 0

function Emit-New {
    # Tail the engine log while it runs (best effort  -  the writer holds the file).
    param([string]$path)
    try {
        if (-not (Test-Path $path)) { return }
        $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
        try {
            if ($fs.Length -le $script:offset) { return }
            $fs.Seek($script:offset, 'Begin') | Out-Null
            $sr = New-Object IO.StreamReader($fs)
            $chunk = $sr.ReadToEnd()
            $script:offset = $fs.Length
            if ($chunk.Length -gt 0) { Write-Host -NoNewline $chunk }
        } finally { $fs.Close() }
    } catch { }
}

while (-not $p.HasExited) {
    Start-Sleep -Milliseconds 500
    Emit-New $outLog
    if ((Get-Date) -gt $deadline) {
        Write-Host ""
        Write-Host "[shot] outer deadline ($($timeout + $grace)s) passed and the engine is still running  -  killing pid $($p.Id)"
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { }
        $killed = $true
        break
    }
}
Start-Sleep -Milliseconds 300
Emit-New $outLog
if ((Test-Path $errLog) -and ((Get-Item $errLog).Length -gt 0)) {
    Write-Host "[shot] --- stderr ---"
    Get-Content $errLog | ForEach-Object { Write-Host $_ }
}

# 5. verdict
$p.WaitForExit()
$code = $p.ExitCode
$log = @()
if (Test-Path $outLog) { $log = Get-Content $outLog }
$errors = @()
if (Test-Path $errLog) { $errors = Get-Content $errLog }
$modern = [bool](Select-String -LiteralPath (Join-Path $gameDir $script) -Pattern '^\s*extends\s+ShotRig\b' -Quiet)
$modern = $modern -or [bool]($log | Select-String -Pattern '^RIG START:' -Quiet)
$verdict = Get-ShotVerdict -OutputLines $log -ErrorLines $errors -EngineExit $code -RequireDone $modern
$shotsDir = $null
$m = $log | Select-String -Pattern '^RIG SHOTS DIR: (.+)$' | Select-Object -First 1
if ($m) { $shotsDir = $m.Matches[0].Groups[1].Value.Trim() }
# Proof on every modern run that the engine really used the isolated user://.
$breach = $false
if ($shotsDir -and $shotAppData) {
    $shotsFull = Get-FullDir $shotsDir
    if (-not $shotsFull.StartsWith((Get-FullDir $shotAppData) + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $breach = $true
        Write-Host "[shot] ISOLATION BREACH: the rig's user:// resolved to $shotsDir, outside the isolated APPDATA $shotAppData"
    }
}
$newPngs = 0
if ($shotsDir -and (Test-Path $shotsDir)) {
    $newPngs = @(Get-ChildItem $shotsDir -Filter *.png | Where-Object { $_.LastWriteTime -ge $started.AddSeconds(-2) }).Count
}
$done = ($log | Select-String -Pattern '^RIG DONE:' -Quiet)
$timedOut = ($log | Select-String -Pattern '^RIG TIMEOUT:' -Quiet)
$elapsed = [int]((Get-Date) - $started).TotalSeconds

if ($killed) {
    Write-Host "[shot] VERDICT: KILLED by the runner after ${elapsed}s  -  the engine never exited (a wedged frame - the in-engine watchdog can only fire ON a frame - or a rig that never called finish()). Last log line above; full log: $outLog"
    if ($shotsDir) { Write-Host "[shot] shots: $shotsDir ($newPngs png this run)" }
    if ($breach) { Exit-Shot 8 }
    Exit-Shot 3
}
if ($timedOut) {
    Write-Host "[shot] VERDICT: RIG TIMEOUT (in-engine watchdog) after ${elapsed}s, exit=$code  -  see the RIG TIMEOUT line for the step it was stuck on. Log: $outLog"
} elseif (-not $verdict.Passed) {
    Write-Host "[shot] VERDICT: FAIL in ${elapsed}s, exit=$($verdict.ExitCode): $($verdict.Reason). Logs: $outLog / $errLog"
} elseif ($done) {
    Write-Host "[shot] VERDICT: RIG DONE in ${elapsed}s, exit=$code. Log: $outLog"
} else {
    Write-Host "[shot] VERDICT: engine exited (code $code) in ${elapsed}s WITHOUT a RIG DONE line  -  the rig quit on its own path or crashed; read the log: $outLog"
}
if ($shotsDir) {
    Write-Host "[shot] shots: $shotsDir ($newPngs png this run)"
} else {
    Write-Host "[shot] no RIG SHOTS DIR line  -  is this rig a ShotRig subclass? (legacy rigs still work but print nothing the runner can parse)"
}
if ($breach) { Exit-Shot 8 }
Exit-Shot $verdict.ExitCode
