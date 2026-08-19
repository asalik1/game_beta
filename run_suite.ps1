# Run the Godot headless suite, tee its combined output to a log, AND preserve
# the ENGINE's own exit code (CR-008). A bare `godot | tee` pipe loses Godot's
# status — cmd/PowerShell report the tee's exit, so the verdict couldn't tell a
# clean run from one where Godot exited nonzero after printing its pass marker.
#
# cmd does the stderr->stdout merge (PowerShell's own `2>&1` on a native exe
# wraps each stderr line in a NativeCommandError blob — letting cmd merge keeps
# SCRIPT ERROR lines intact for the log grep); PowerShell tees the stream live
# to the console and the log; $LASTEXITCODE then holds Godot's real code, which
# this script exits with so the caller can forward it to suite_verdict.ps1.
param(
	[Parameter(Mandatory = $true)][string]$Godot,
	[Parameter(Mandatory = $true)][string]$GamePath,
	[Parameter(Mandatory = $true)][string]$Scene,
	[Parameter(Mandatory = $true)][string]$Log,
	[string]$ExtraArgs = ""
)

$inner = '("{0}" --headless --path "{1}" {2} {3}) 2>&1' -f $Godot, $GamePath, $Scene, $ExtraArgs
& cmd /c $inner | Tee-Object -FilePath $Log
exit $LASTEXITCODE
