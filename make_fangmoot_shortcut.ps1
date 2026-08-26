# Create (or refresh) a "Fangmoot" shortcut on the Desktop that launches the
# standalone tavern autobattler (game.gd --fangmoot, PROPOSALS/FANGMOOT.md §18).
# Self-contained: builds a crisp .ico from game/icon.png, then writes the .lnk.
# Run from the repo root — works from a worktree now, or from main after merge.
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe  = Join-Path $root 'tools\Godot_v4.4.1-stable_win64.exe'
$game = Join-Path $root 'game'
$ico  = Join-Path $root 'tools\fangmoot.ico'

# --- build the icon from game/icon.png (PNG-in-ICO = crisp at any size) ---
$src = Join-Path $game 'icon.png'
if (Test-Path $src) {
	Add-Type -AssemblyName System.Drawing
	$img = [System.Drawing.Image]::FromFile($src)
	$bmp = New-Object System.Drawing.Bitmap(256, 256)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.InterpolationMode = 'HighQualityBicubic'
	$g.DrawImage($img, 0, 0, 256, 256)
	$g.Dispose(); $img.Dispose()
	$ms = New-Object System.IO.MemoryStream
	$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
	$bytes = $ms.ToArray(); $ms.Dispose()
	$fs = [System.IO.File]::Create($ico); $bw = New-Object System.IO.BinaryWriter($fs)
	$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]1)
	$bw.Write([Byte]0); $bw.Write([Byte]0); $bw.Write([Byte]0); $bw.Write([Byte]0)
	$bw.Write([UInt16]1); $bw.Write([UInt16]32)
	$bw.Write([UInt32]$bytes.Length); $bw.Write([UInt32]22); $bw.Write($bytes)
	$bw.Flush(); $fs.Close()
}

# --- write the desktop shortcut straight to the engine (no cmd flash) ---
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Fangmoot.lnk'
$s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$s.TargetPath = $exe
$s.Arguments = '--path "' + $game + '" -- --fangmoot'
$s.WorkingDirectory = $root
if (Test-Path $ico) { $s.IconLocation = $ico + ',0' }
$s.Description = 'Play Fangmoot standalone — the tavern autobattler'
$s.Save()
Write-Host "Created $lnk"
