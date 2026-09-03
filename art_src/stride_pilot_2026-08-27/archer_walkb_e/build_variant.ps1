Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $PSScriptRoot 'refs\ref1_current_walk.png'
$outputPath = Join-Path $PSScriptRoot 'archer_walkb_e_row.png'

$source = [System.Drawing.Bitmap]::new($sourcePath)
$width = $source.Width
$height = $source.Height
$cellWidth = [int]($width / 6)

$pixels = New-Object 'System.Drawing.Color[,]' $width, $height
$core = New-Object 'bool[,]' $width, $height
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $color = $source.GetPixel($x, $y)
        $pixels[$x, $y] = $color
        $core[$x, $y] = (($color.R + $color.G + $color.B) -gt 0)
    }
}

# Find exact-black pixels connected to the canvas boundary. Enclosed blacks are
# character detail; exterior blacks are the source sheet's old background.
$exterior = New-Object 'bool[,]' $width, $height
$queue = [System.Collections.Generic.Queue[System.Drawing.Point]]::new()
function Add-ExteriorPixel([int]$x, [int]$y) {
    if (-not $core[$x, $y] -and -not $exterior[$x, $y]) {
        $exterior[$x, $y] = $true
        $queue.Enqueue([System.Drawing.Point]::new($x, $y))
    }
}
for ($x = 0; $x -lt $width; $x++) {
    Add-ExteriorPixel $x 0
    Add-ExteriorPixel $x ($height - 1)
}
for ($y = 0; $y -lt $height; $y++) {
    Add-ExteriorPixel 0 $y
    Add-ExteriorPixel ($width - 1) $y
}
while ($queue.Count -gt 0) {
    $point = $queue.Dequeue()
    if ($point.X -gt 0) { Add-ExteriorPixel ($point.X - 1) $point.Y }
    if ($point.X + 1 -lt $width) { Add-ExteriorPixel ($point.X + 1) $point.Y }
    if ($point.Y -gt 0) { Add-ExteriorPixel $point.X ($point.Y - 1) }
    if ($point.Y + 1 -lt $height) { Add-ExteriorPixel $point.X ($point.Y + 1) }
}

# Preserve exact-black outline pixels within two pixels of colored sprite art.
$keep = New-Object 'bool[,]' $width, $height
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        if ($core[$x, $y] -or -not $exterior[$x, $y]) {
            $keep[$x, $y] = $true
            continue
        }
        $nearArt = $false
        for ($dy = -2; $dy -le 2 -and -not $nearArt; $dy++) {
            $ny = $y + $dy
            if ($ny -lt 0 -or $ny -ge $height) { continue }
            for ($dx = -2; $dx -le 2; $dx++) {
                $nx = $x + $dx
                if ($nx -ge 0 -and $nx -lt $width -and $core[$nx, $ny]) {
                    $nearArt = $true
                    break
                }
            }
        }
        $keep[$x, $y] = $nearArt
    }
}

$green = [System.Drawing.Color]::FromArgb(255, 0, 255, 0)
$result = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        if ($keep[$x, $y]) { $result.SetPixel($x, $y, ($pixels[$x, $y])) }
        else { $result.SetPixel($x, $y, $green) }
    }
}

# Retiming the cape folds: borrow only interior shading from the opposite
# half-cycle frame. The target frame's cape mask and silhouette stay untouched.
for ($frame = 0; $frame -lt 6; $frame++) {
    $sourceFrame = ($frame + 3) % 6
    $targetX0 = $frame * $cellWidth
    $sourceX0 = $sourceFrame * $cellWidth
    for ($y = 238; $y -le 309; $y++) {
        for ($localX = 158; $localX -le 211; $localX++) {
            $tx = $targetX0 + $localX
            $sx = $sourceX0 + $localX
            if (-not $keep[$tx, $y] -or -not $core[$sx, $y]) { continue }
            $interior = $true
            for ($dy = -2; $dy -le 2 -and $interior; $dy++) {
                for ($dx = -2; $dx -le 2; $dx++) {
                    if (-not $keep[$tx + $dx, $y + $dy]) {
                        $interior = $false
                        break
                    }
                }
            }
            if ($interior) { $result.SetPixel($tx, $y, ($pixels[$sx, $y])) }
        }
    }
}

# Set the head subtly forward. The shift tapers into the neck so the original
# proportions and attachment remain intact.
for ($frame = 0; $frame -lt 6; $frame++) {
    $x0 = $frame * $cellWidth
    $moves = [System.Collections.Generic.List[object]]::new()
    for ($y = 184; $y -le 232; $y++) {
        $dx = if ($y -le 214) { 2 } elseif ($y -le 225) { 1 } else { 0 }
        if ($dx -eq 0) { continue }
        for ($localX = 202; $localX -le 246; $localX++) {
            $x = $x0 + $localX
            if ($keep[$x, $y]) {
                $moves.Add(@($x, $y, $x + $dx, $y, $result.GetPixel($x, $y)))
            }
        }
    }
    foreach ($move in $moves) { $result.SetPixel($move[0], $move[1], $green) }
    foreach ($move in $moves) { $result.SetPixel($move[2], $move[3], $move[4]) }
}

# Let the bow arm breathe with the stride. A one-to-two-pixel tapered shear is
# enough to change timing side by side without changing pose language or gear.
$armSwing = @(-2, -1, 1, 2, 1, -1)
$armLift = @(0, 1, 1, 0, -1, -1)
for ($frame = 0; $frame -lt 6; $frame++) {
    $x0 = $frame * $cellWidth
    $moves = [System.Collections.Generic.List[object]]::new()
    for ($y = 230; $y -le 304; $y++) {
        $progress = ($y - 230) / 74.0
        $center = [int][Math]::Round(224 + 0.20 * ($y - 230))
        $dx = [int][Math]::Round($armSwing[$frame] * $progress)
        $dy = [int][Math]::Round($armLift[$frame] * $progress)
        if ($dx -eq 0 -and $dy -eq 0) { continue }
        for ($localX = $center - 6; $localX -le $center + 8; $localX++) {
            $x = $x0 + $localX
            if ($keep[$x, $y]) {
                $moves.Add(@($x, $y, $x + $dx, $y + $dy, $result.GetPixel($x, $y)))
            }
        }
    }
    foreach ($move in $moves) { $result.SetPixel($move[0], $move[1], $green) }
    foreach ($move in $moves) { $result.SetPixel($move[2], $move[3], $move[4]) }
}

# Hard lock the complete lower-body band to the reference. Every retained sprite
# pixel from y=310 down is byte-for-byte the reference; only background keys green.
for ($y = 310; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        if ($keep[$x, $y]) { $result.SetPixel($x, $y, ($pixels[$x, $y])) }
        else { $result.SetPixel($x, $y, $green) }
    }
}

$result.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$result.Dispose()
$source.Dispose()
Write-Output $outputPath
