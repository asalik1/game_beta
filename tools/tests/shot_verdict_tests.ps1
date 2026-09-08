$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../shot_verdict.ps1')
$ok = 'RIG DONE: example  shots=2  exit=0  dir=somewhere'
$cases = @(
    @{ Name='modern success'; Out=@($ok); Code=0; Expected=0; Modern=$true },
    @{ Name='runtime stderr after success'; Out=@($ok); Err=@("SCRIPT ERROR: Invalid access to property 'age' on Nil."); Code=0; Expected=1; Modern=$true },
    @{ Name='runtime stdout'; Out=@('SCRIPT ERROR: bad cast', $ok); Code=0; Expected=1; Modern=$true },
    @{ Name='missing modern finish'; Out=@('RIG START: example'); Code=0; Expected=7; Modern=$true },
    @{ Name='legacy exit allowed'; Out=@('legacy capture saved'); Code=0; Expected=0; Modern=$false },
    @{ Name='legacy script error rejected'; Err=@('SCRIPT ERROR: bad cast'); Code=0; Expected=1; Modern=$false },
    @{ Name='rig failure marker'; Out=@('RIG DONE: example shots=1 exit=1'); Code=0; Expected=1; Modern=$true },
    @{ Name='crash despite marker'; Out=@($ok); Code=9; Expected=9; Modern=$true },
    @{ Name='watchdog despite zero process exit'; Out=@('RIG TIMEOUT: example', $ok); Code=0; Expected=2; Modern=$true },
    @{ Name='malformed completion'; Out=@('RIG DONE: incomplete'); Code=0; Expected=7; Modern=$true },
    @{ Name='existing renderer shutdown diagnostic'; Out=@($ok); Err=@('WARNING: 4 RIDs of type Texture were leaked.', 'ERROR: Parameter RenderingServer::get_singleton() is null.'); Code=0; Expected=0; Modern=$true },
    @{ Name='inactive transport after success'; Out=@($ok); Err=@("ERROR: The multiplayer instance isn't currently active."); Code=0; Expected=1; Modern=$true },
    @{ Name='engine error in stdout'; Out=@('ERROR: Invalid polygon data, triangulation failed.', $ok); Code=0; Expected=1; Modern=$true },
    @{ Name='legacy engine error'; Err=@('ERROR: Physics query failed.'); Code=0; Expected=1; Modern=$false },
    @{ Name='known renderer exit RID'; Out=@($ok); Err=@("ERROR: 2 RID allocations of type 'N10RendererRD14TextureStorage7TextureE' were leaked at exit.", 'ERROR: Parameter "RenderingServer::get_singleton()" is null.'); Code=0; Expected=0; Modern=$true },
    @{ Name='unrelated leaked RID is not exempt'; Out=@($ok); Err=@("ERROR: 2 RID allocations of type 'PhysicsBody' were leaked at exit."); Code=0; Expected=1; Modern=$true },
    @{ Name='Compatibility shutdown texture detail'; Out=@($ok); Err=@("ERROR: 2 RID allocations of type 'N5GLES37TextureE' were leaked at exit.", 'ERROR: Texture with GL ID of 179: leaked 3064 bytes.'); Code=0; Expected=0; Modern=$true },
    @{ Name='GL texture error without exit report'; Out=@($ok); Err=@('ERROR: Texture with GL ID of 179: leaked 3064 bytes.'); Code=0; Expected=1; Modern=$true }
)
foreach ($case in $cases) {
    $verdict = Get-ShotVerdict -OutputLines $case.Out -ErrorLines $case.Err -EngineExit $case.Code -RequireDone $case.Modern
    if ($verdict.ExitCode -ne $case.Expected -or $verdict.Passed -ne ($case.Expected -eq 0)) {
        throw "$($case.Name): expected $($case.Expected), got $($verdict.ExitCode)"
    }
}
Write-Host "SHOT VERDICT TESTS PASS: $($cases.Count) fixtures"
