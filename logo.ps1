# Generates an original project logo for CurseForge.
#
# Nothing here is a Blizzard asset: it is a ring and a chevron drawn from
# primitives. The gold is the same value the addon uses for the turn indicator
# in game (|cffffd100), so the icon and the board read as one thing.

param([string]$OutPath, [int]$Size = 512)

Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap $Size, $Size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$bg      = [System.Drawing.Color]::FromArgb(255, 23, 23, 29)
$gold    = [System.Drawing.Color]::FromArgb(255, 255, 209, 0)
$dimGold = [System.Drawing.Color]::FromArgb(90, 255, 209, 0)

$g.Clear($bg)

$centre = $Size / 2.0
$radius = $Size * 0.34
$rect = New-Object System.Drawing.RectangleF(
    ($centre - $radius), ($centre - $radius), ($radius * 2), ($radius * 2))

# Faint full ring: the rotation as a whole.
$penDim = New-Object System.Drawing.Pen($dimGold, ($Size * 0.035))
$penDim.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$penDim.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawEllipse($penDim, $rect)

# Bright arc: the part of the rotation that has come round to you.
$penGold = New-Object System.Drawing.Pen($gold, ($Size * 0.035))
$penGold.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$penGold.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawArc($penGold, $rect, -125, 160)

# Marker dot sitting on the ring, at the head of the bright arc.
$dotAngle = -125 * [Math]::PI / 180.0
$dotR = $Size * 0.055
$dotX = $centre + $radius * [Math]::Cos($dotAngle)
$dotY = $centre + $radius * [Math]::Sin($dotAngle)
$brushGold = New-Object System.Drawing.SolidBrush($gold)
$g.FillEllipse($brushGold, ($dotX - $dotR), ($dotY - $dotR), ($dotR * 2), ($dotR * 2))

# The turn chevron, the same glyph the board draws next to whoever is up.
$fontSize = $Size * 0.36
$font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$textRect = New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)
$g.DrawString([char]0x00BB, $font, $brushGold, $textRect, $format)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Output "Written: $OutPath ($Size x $Size)"
