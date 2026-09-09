# Pure verdict logic shared by the windowed runner and its fixture tests.
# Godot can report script/shader errors, abort work, then still quit(0).
function Get-ShotVerdict {
    param(
        [string[]]$OutputLines = @(),
        [string[]]$ErrorLines = @(),
        [int]$EngineExit = 0,
        [bool]$RequireDone = $true
    )
    $text = (@($OutputLines) + @($ErrorLines)) -join "`n"
    # Engine errors can also abort real work without a SCRIPT ERROR or nonzero
    # exit (e.g. a closed ENet peer still answering get_unique_id every frame).
    # Only established renderer shutdown diagnostics are exempt. Compatibility
    # lists each GL texture too; accept those only beside its exit RID report.
    $shutdown = '^ERROR: (?:\d+ RID allocations of type .*?(?:RendererRD|RenderingDevice|Texture).* were leaked at exit\.|Parameter "?RenderingServer::get_singleton\(\)"? is null\.)$'
    $glShutdown = $text -match "(?m)^ERROR: \d+ RID allocations of type 'N5GLES37TextureE' were leaked at exit\.$"
    $glTexture = '^ERROR: Texture with GL ID of \d+: leaked \d+ bytes\.$'
    $engineErrors = @($text -split '\r?\n' | Where-Object {
        $_ -match '^\s*ERROR:' -and $_.Trim() -notmatch $shutdown -and
            -not ($glShutdown -and $_.Trim() -match $glTexture)
    })
    $code = $EngineExit
    $reason = ''
    if ($text -match 'SCRIPT ERROR|SHADER ERROR|shader compilation failed|Parse Error|Assertion failed|(?m)^RIG FAIL:') {
        $code = 1
        $reason = 'script/shader/runtime assertion error in the engine log'
    } elseif ($text -match '(?m)^RIG TIMEOUT:') {
        $code = 2
        $reason = 'in-engine watchdog timed out'
    } elseif ($engineErrors.Count -gt 0) {
        $code = 1
        $reason = 'engine error: ' + $engineErrors[0].Trim()
    } elseif ($EngineExit -ne 0) {
        $reason = "engine exited $EngineExit"
    } else {
        $done = [regex]::Matches($text, '(?m)^RIG DONE:[^\r\n]*\bexit=(\d+)\b')
        if ($RequireDone -and $done.Count -eq 0) {
            $code = 7
            $reason = 'ShotRig exited without a valid completion marker'
        } else {
            foreach ($marker in $done) {
                if ([int]$marker.Groups[1].Value -ne 0) {
                    $code = [int]$marker.Groups[1].Value
                    $reason = 'rig completion marker reports a failure'
                    break
                }
            }
        }
    }
    # Renderer shutdown warnings are printed by the runner as before. They
    # are not script errors; the headless suite has its own stricter leak gate.
    [pscustomobject]@{ Passed = ($code -eq 0); ExitCode = $code; Reason = $reason }
}
