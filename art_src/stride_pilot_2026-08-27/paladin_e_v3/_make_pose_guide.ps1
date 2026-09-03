Add-Type -AssemblyName System.Drawing

$sourcePath = 'C:\Users\asali\.codex\generated_images\01a0544d-0c84-7ad3-b9ce-3fe4ddc3d52a\exec-f45de983-b45d-4902-80f1-4d8bca3dfb9c.png'
$outputPath = Join-Path $PSScriptRoot 'refs\_pose_guide.png'
$image = [System.Drawing.Bitmap]::FromFile($sourcePath)
$graphics = [System.Drawing.Graphics]::FromImage($image)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$backPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Magenta, 14)
$frontPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Cyan, 18)
$outlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 24)

# Frame 3: far planted shin behind, camera-near swing shin in front.
$graphics.DrawLine($outlinePen, 888, 414, 815, 510)
$graphics.DrawLine($backPen, 888, 414, 815, 510)
$graphics.DrawLine($outlinePen, 825, 414, 908, 510)
$graphics.DrawLine($frontPen, 825, 414, 908, 510)

# Frame 4: camera-near planted shin behind, far-side swing shin in front.
$graphics.DrawLine($outlinePen, 1168, 414, 1260, 510)
$graphics.DrawLine($backPen, 1168, 414, 1260, 510)
$graphics.DrawLine($outlinePen, 1248, 414, 1155, 510)
$graphics.DrawLine($frontPen, 1248, 414, 1155, 510)

$graphics.Dispose()
$image.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$image.Dispose()

