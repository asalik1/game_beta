# Runner isolation fixtures, no Godot required (a compiled fake engine stands in):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/shot_isolation_tests.ps1
# preflight runs this and shot_verdict_tests.ps1 whenever the runner or its tests change.
# -RunnerPath checks another runner copy (for example a pre-fix one) the same way.
#
# The owner cases hand a copy of the runner the REAL roaming APPDATA, exactly as
# shot.bat gets it. The fake engine refuses to write anywhere under the real
# profile (it only records that it was pointed there), and this script only
# reads the owner's settings/keybinds to prove they are unchanged.
param([string]$RunnerPath = (Join-Path $PSScriptRoot '../shot_rig.ps1'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fixture = Join-Path $root ('build\qa\si_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$project = Join-Path $fixture 'p q'
$toolDir = Join-Path $project 'tools'
$gameDir = Join-Path $project 'game'
$cacheDir = Join-Path $gameDir '.godot'
$classCache = Join-Path $cacheDir 'global_script_class_cache.cfg'
$runner = Join-Path $toolDir 'shot_rig.ps1'
New-Item -ItemType Directory -Path $toolDir, $cacheDir -Force | Out-Null
Copy-Item -LiteralPath $RunnerPath -Destination $runner
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../shot_verdict.ps1') -Destination $toolDir
Set-Content -LiteralPath (Join-Path $gameDir 'shot_fixture.tscn') -Value '[gd_scene format=3]'

$ownerAppData = [Environment]::GetFolderPath('ApplicationData').TrimEnd('\')
$managed = Join-Path $project 'build\qa\shot_profile'
$managedUser = Join-Path $managed 'Godot\app_userdata\Crownless'
$candidate = Join-Path $fixture 'elsewhere\save-feedback-candidate\appdata'
$escaped = Join-Path $fixture 'escaped\shots\fixture'

# The outer kill fires at timeout + the runner's grace; aim it 8 s after launch
# whatever the grace is, so the fake engine has time to write its evidence.
$runnerText = Get-Content -LiteralPath $RunnerPath -Raw
if ($runnerText -notmatch '(?m)^\$grace = ([0-9.]+)') { throw 'runner has no "$grace = N" line to derive the kill timing from' }
$killTimeout = 8 - [double]$Matches[1]

# Import, gate and rig phases, like the real engine's command lines. Every
# phase records which APPDATA it saw and whether state seeded earlier (a
# SENTINEL outside shots/ and the caches) was still readable, then does what a
# rig does to user://: rewrites settings/keybinds/sidecars, saves, caches.
$engine = @'
using System;
using System.IO;
using System.Threading;
public class ShotIsolationEngine {
    public static int Main(string[] args) {
        string profile = Environment.GetEnvironmentVariable("APPDATA") ?? "";
        string mode = Environment.GetEnvironmentVariable("SHOT_TEST_MODE");
        string trace = Environment.GetEnvironmentVariable("SHOT_TEST_TRACE");
        string phase = Array.IndexOf(args, "--import") >= 0 ? "import" :
            Array.IndexOf(args, "--script") >= 0 ? "gate" : "rig";
        string owner = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData).TrimEnd('\\');
        string full = profile.Length > 0 ? Path.GetFullPath(profile).TrimEnd('\\') : "";
        if (full.Length == 0 || full.Equals(owner, StringComparison.OrdinalIgnoreCase) ||
                full.StartsWith(owner + "\\", StringComparison.OrdinalIgnoreCase)) {
            // Never write to the owner's real profile, even under a broken runner.
            File.AppendAllText(trace, phase + "|OWNER|" + profile + "\n");
            return 97;
        }
        string user = Path.Combine(full, "Godot", "app_userdata", "Crownless");
        Directory.CreateDirectory(user);
        bool stale = false;
        foreach (string file in Directory.GetFiles(user, "*", SearchOption.AllDirectories)) {
            string top = file.Substring(user.Length + 1).Split('\\')[0];
            if (top == "shots" || top == "shader_cache" || top == "vulkan") continue;
            stale |= File.ReadAllText(file).Contains("SENTINEL");
        }
        foreach (string name in new[] { "settings.json", "keybinds.json", "meta.json" }) {
            foreach (string suffix in new[] { "", ".bak", ".tmp" }) {
                File.WriteAllText(Path.Combine(user, name + suffix), "{\"probe\":\"" + phase + "\"}");
            }
        }
        Directory.CreateDirectory(Path.Combine(user, "saves"));
        File.WriteAllText(Path.Combine(user, "saves", "slot_1.json"), "{\"probe\":1}");
        Directory.CreateDirectory(Path.Combine(user, "shader_cache"));
        File.WriteAllText(Path.Combine(user, "shader_cache", phase + ".bin"), "cache");
        File.AppendAllText(trace, phase + "|" + full + "|" + stale + "\n");
        if (phase == "import") {
            string game = args[Array.IndexOf(args, "--path") + 1];
            File.WriteAllText(Path.Combine(game, ".godot", "global_script_class_cache.cfg"),
                "\"class\": &\"ShotRig\"");
            return 0;
        }
        if (phase == "gate") {
            Console.WriteLine("COMPILE OK");
            return mode == "gate-fail" ? 1 : 0;
        }
        string shots = mode == "escape" ? Environment.GetEnvironmentVariable("SHOT_TEST_ESCAPE") :
            Path.Combine(user, "shots", "fixture");
        Directory.CreateDirectory(shots);
        File.WriteAllText(Path.Combine(shots, "evidence.png"), "fixture artifact");
        Console.WriteLine("RIG SHOTS DIR: " + shots.Replace('\\', '/'));
        Console.Out.Flush();
        if (mode == "killed") { Thread.Sleep(120000); return 0; }
        if (mode == "watchdog") { Console.WriteLine("RIG TIMEOUT: fixture"); return 2; }
        if (mode == "nonzero") { return 9; }
        if (mode != "legacy") { Console.WriteLine("RIG DONE: fixture shots=1 exit=0"); }
        return 0;
    }
}
'@
Add-Type -TypeDefinition $engine -OutputAssembly (Join-Path $toolDir 'Godot_v4.4.1-stable_win64_console.exe') -OutputType ConsoleApplication

function Write-Seed([string]$user, [string]$marker) {
    # Leftover state a previous rig (or the caller) could have left in user://.
    New-Item -ItemType Directory -Path (Join-Path $user 'saves') -Force | Out-Null
    foreach ($name in @('settings.json', 'keybinds.json')) {
        foreach ($suffix in @('', '.bak', '.tmp')) {
            $json = if ($name -eq 'settings.json') { '{"touch_controls":true,"fullscreen":true,"lang":"fr"' } else { '{"interact":999' }
            Set-Content -LiteralPath (Join-Path $user ($name + $suffix)) -Value ($json + ',"' + $marker + '":"' + $suffix + '"}')
        }
    }
    Set-Content -LiteralPath (Join-Path $user 'saves\slot_1.json') -Value ('{"' + $marker + '":1}')
}

function Get-OwnerState {
    # Read-only fingerprint of the owner's real settings/keybinds and sidecars.
    $user = Join-Path $ownerAppData 'Godot\app_userdata\Crownless'
    $state = @()
    foreach ($name in @('settings.json', 'keybinds.json')) {
        foreach ($suffix in @('', '.bak', '.tmp')) {
            $path = Join-Path $user ($name + $suffix)
            if (Test-Path -LiteralPath $path) {
                $item = Get-Item -LiteralPath $path
                $state += "$path|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)|$((Get-FileHash -LiteralPath $path).Hash)"
            } else {
                $state += "$path|absent"
            }
        }
    }
    return ($state -join "`n")
}

function Test-Under([string]$path, [string]$parent) {
    return [IO.Path]::GetFullPath($path).StartsWith([IO.Path]::GetFullPath($parent).TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
}

$cases = @(
    @{ Name='owner profile: success including import'; AppData='owner'; Mode='success'; Expected=0; Phases='import,gate,rig'; Import=$true },
    @{ Name='owner profile: nonzero exit'; AppData='owner'; Mode='nonzero'; Expected=9; Phases='gate,rig' },
    @{ Name='owner profile: watchdog exit'; AppData='owner'; Mode='watchdog'; Expected=2; Phases='gate,rig' },
    @{ Name='owner profile: outer kill'; AppData='owner'; Mode='killed'; Expected=3; Phases='gate,rig'; Args=@("--timeout=$killTimeout") },
    @{ Name='owner profile: compile gate failure'; AppData='owner'; Mode='gate-fail'; Expected=4; Phases='gate' },
    @{ Name='owner profile: legacy rig without gate'; AppData='owner'; Mode='legacy'; Expected=0; Phases='rig'; Args=@('--no-gate', '--no-import'); Legacy=$true },
    @{ Name='APPDATA unset'; AppData='unset'; Mode='success'; Expected=0; Phases='gate,rig' },
    @{ Name='caller candidate outside this checkout'; AppData='candidate'; Mode='success'; Expected=0; Phases='gate,rig' },
    @{ Name='shot profile busy'; AppData='owner'; Mode='success'; Expected=0; Phases='gate,rig'; Busy=$true },
    @{ Name='user:// outside the isolated APPDATA'; AppData='owner'; Mode='escape'; Expected=8; Phases='gate,rig' },
    @{ Name='two runs in one PowerShell session'; AppData='owner'; Mode='success'; Expected=0; Phases='gate,rig,gate,rig'; Twice=$true }
)

$savedEnvironment = @{}
foreach ($name in @('APPDATA', 'SHOT_TEST_MODE', 'SHOT_TEST_TRACE', 'SHOT_TEST_ESCAPE')) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$ownerBefore = Get-OwnerState
$busyLock = $null
$index = 0
$passed = $false
try {
    foreach ($case in $cases) {
        $index++
        # Preconditions are set per case, never inherited from an earlier one.
        if ($case.Import) { Remove-Item -LiteralPath $classCache -Force -ErrorAction SilentlyContinue }
        else { Set-Content -LiteralPath $classCache -Value '"class": &"ShotRig"' }
        Set-Content -LiteralPath (Join-Path $gameDir 'shot_fixture.gd') -Value $(if ($case.Legacy) { 'extends Node' } else { 'extends ShotRig' })
        Write-Seed $managedUser 'SENTINEL'
        foreach ($keep in @('shots\older\keep.png', 'shader_cache\keep.bin', 'vulkan\keep.bin')) {
            $path = Join-Path $managedUser $keep
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
            Set-Content -LiteralPath $path -Value 'KEEP'
        }
        Remove-Item -LiteralPath (Join-Path $managedUser 'shots\fixture') -Recurse -Force -ErrorAction SilentlyContinue
        $candidateUser = Join-Path $candidate 'Godot\app_userdata\Crownless'
        if (Test-Path -LiteralPath $candidate) { [IO.Directory]::Delete($candidate, $true) }
        Write-Seed $candidateUser 'SENTINEL'

        $expectedProfile = $managed
        if ($case.AppData -eq 'owner') { $env:APPDATA = $ownerAppData }
        elseif ($case.AppData -eq 'unset') { $env:APPDATA = $null }
        else { $env:APPDATA = $candidate; $expectedProfile = $candidate }
        $env:SHOT_TEST_MODE = $case.Mode
        $env:SHOT_TEST_TRACE = Join-Path $fixture ("$index" + '_trace.txt')
        $env:SHOT_TEST_ESCAPE = $escaped
        if ($case.Busy) {
            $busyLock = [IO.File]::Open((Join-Path $managed '.shot_rig.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
        }
        $extra = @($case.Args)
        if ($case.Twice) {
            $command = "& '$runner' fixture; `$first = `$LASTEXITCODE; & '$runner' fixture; Write-Output ('TWICE RC=' + `$first + ',' + `$LASTEXITCODE + ' APPDATA=' + `$env:APPDATA)"
            $output = & powershell -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1
        } else {
            $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $runner fixture @extra 2>&1
        }
        $code = $LASTEXITCODE
        foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
        if ($busyLock) { $busyLock.Dispose(); $busyLock = $null }
        $output | Set-Content -LiteralPath (Join-Path $fixture ("$index" + '_runner.log'))
        $text = $output -join "`n"

        if ((Get-OwnerState) -cne $ownerBefore) { throw "$($case.Name): the owner's real settings/keybinds changed" }
        $tracePath = Join-Path $fixture ("$index" + '_trace.txt')
        if (-not (Test-Path -LiteralPath $tracePath)) { throw "$($case.Name): the engine never ran (exit $code)`n$text" }
        $trace = @(Get-Content -LiteralPath $tracePath | ForEach-Object { ,($_ -split '\|') })
        foreach ($entry in $trace) {
            if ($entry[1] -eq 'OWNER') { throw "$($case.Name): the $($entry[0]) phase was handed the owner's real profile ($($entry[2]))`n$text" }
        }
        if ($case.Twice) {
            if ($text -notmatch ('TWICE RC=0,0 APPDATA=' + [regex]::Escape($ownerAppData) + '(\r|\n|$)')) { throw "$($case.Name): exit codes or restored APPDATA wrong`n$text" }
        } elseif ($code -ne $case.Expected) {
            throw "$($case.Name): expected exit $($case.Expected), got $code`n$text"
        }
        if ((($trace | ForEach-Object { $_[0] }) -join ',') -ne $case.Phases) { throw "$($case.Name): engine phases were $(($trace | ForEach-Object { $_[0] }) -join ',')" }

        $seen = $trace[0][1]
        if ($case.Busy) {
            if (-not (Test-Under $seen (Join-Path $project 'build\qa\shot_runs'))) { throw "$($case.Name): busy profile should fall back to build\qa\shot_runs, got $seen" }
            if (-not ((Get-Content -LiteralPath (Join-Path $managedUser 'settings.json') -Raw) -match 'SENTINEL')) { throw "$($case.Name): wiped the busy profile" }
        } elseif ($seen -ine [IO.Path]::GetFullPath($expectedProfile).TrimEnd('\')) {
            throw "$($case.Name): engine used $seen, expected $expectedProfile"
        }
        foreach ($entry in $trace) {
            if ($entry[1] -ine $seen) { throw "$($case.Name): engine profile changed between phases" }
        }
        # Managed runs start clean except shots/ and the caches; a caller's
        # own APPDATA is used exactly as given, leftovers included.
        $wantStale = if ($case.AppData -eq 'candidate') { 'True' } else { 'False' }
        if ($trace[0][2] -ne $wantStale) { throw "$($case.Name): first engine phase saw leftover state=$($trace[0][2]), expected $wantStale" }
        if ($expectedProfile -eq $managed -and -not $case.Busy) {
            foreach ($keep in @('shots\older\keep.png', 'shader_cache\keep.bin', 'vulkan\keep.bin')) {
                if (-not (Test-Path -LiteralPath (Join-Path $managedUser $keep))) { throw "$($case.Name): reset removed $keep" }
            }
        }
        if ($case.Mode -eq 'escape') {
            if ($text -notmatch 'ISOLATION BREACH') { throw "$($case.Name): no ISOLATION BREACH line`n$text" }
        } elseif ($case.Mode -ne 'gate-fail') {
            $evidence = Join-Path $seen 'Godot\app_userdata\Crownless\shots\fixture\evidence.png'
            if (-not (Test-Path -LiteralPath $evidence)) { throw "$($case.Name): screenshot evidence not at $evidence" }
            if ($text -notmatch [regex]::Escape('shots: ' + (Split-Path -Parent $evidence).Replace('\', '/'))) { throw "$($case.Name): runner did not print the shots dir`n$text" }
        }
        Write-Host "ok: $($case.Name)"
    }
    $passed = $true
} finally {
    if ($busyLock) { $busyLock.Dispose() }
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    if (-not $passed) { Write-Host "SHOT ISOLATION TESTS FAILED (artifacts kept: $fixture)" }
}
try { [IO.Directory]::Delete($fixture, $true) } catch { Write-Host "note: could not remove $fixture ($($_.Exception.Message))" }
Write-Host "SHOT ISOLATION TESTS PASS: $($cases.Count) fixtures"
