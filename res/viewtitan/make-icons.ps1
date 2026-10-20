# Replaces the RustDesk icons with the ViewTitan logo (blue gradient tile + white bolt),
# keeping every file's original pixel size. Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File res\viewtitan\make-icons.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\..')).Path

function C($hex) { $h = $hex.TrimStart('#'); [Drawing.Color]::FromArgb(255, [Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16)) }
function Bolt($g, $x, $y, $s, $brush) {
    $k = $s / 48
    $pts = @(@(26,9), @(15,26), @(23,26), @(20,39), @(33,21), @(25,21)) | % { New-Object Drawing.PointF ($x + $_[0]*$k), ($y + $_[1]*$k) }
    $g.FillPolygon($brush, [Drawing.PointF[]]$pts)
}
function Tile($g, $x, $y, $s, $round) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    if ($round) { $p.AddEllipse([single]$x, [single]$y, [single]$s, [single]$s) }
    else { $r = $s * 0.27; $d = $r * 2; $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $s - $d, $y, $d, $d, 270, 90); $p.AddArc($x + $s - $d, $y + $s - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $s - $d, $d, $d, 90, 90); $p.CloseFigure() }
    $b = New-Object Drawing.Drawing2D.LinearGradientBrush (New-Object Drawing.RectangleF $x, $y, $s, $s), (C '#2563EB'), (C '#0EA5E9'), 45
    $g.FillPath($b, $p); $p.Dispose(); $b.Dispose()
}
# kind: tile | round | fg (white bolt on transparent, adaptive-icon safe zone) | mono (white bolt) | dark (black bolt)
function Draw([int]$size, $kind) {
    $bmp = New-Object Drawing.Bitmap $size, $size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.Clear([Drawing.Color]::Transparent)
    switch ($kind) {
        'tile'  { $m = [math]::Round($size * 0.04); Tile $g $m $m ($size - 2*$m) $false; Bolt $g $m $m ($size - 2*$m) ([Drawing.Brushes]::White) }
        'round' { Tile $g 0 0 $size $true; Bolt $g 0 0 $size ([Drawing.Brushes]::White) }
        'fg'    { $s = $size * 0.72; $o = ($size - $s) / 2; Bolt $g $o $o $s ([Drawing.Brushes]::White) }
        'mono'  { Bolt $g (-$size*0.1) (-$size*0.05) ($size*1.2) ([Drawing.Brushes]::White) }
        'dark'  { Bolt $g (-$size*0.1) (-$size*0.05) ($size*1.2) ([Drawing.Brushes]::Black) }
    }
    $g.Dispose(); return $bmp
}
function SavePng($bmp, $path) { $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose() }
function SizeOf($path) { $i = [Drawing.Image]::FromFile($path); $w = $i.Width; $i.Dispose(); $w }
function ReplacePng($rel, $kind) { $p = Join-Path $root $rel; $s = SizeOf $p; SavePng (Draw $s $kind) $p; "png  $s  $rel" }
# ICO with PNG-compressed frames (Windows Vista+)
function WriteIco($rel, [int[]]$sizes, $kind = 'tile') {
    $p = Join-Path $root $rel
    $frames = foreach ($s in $sizes) { $ms = New-Object IO.MemoryStream; $b = Draw $s $kind; $b.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); ,@($s, $ms.ToArray()) }
    $fs = [IO.File]::Create($p); $w = New-Object IO.BinaryWriter $fs
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$frames.Count)
    $offset = 6 + 16 * $frames.Count
    foreach ($f in $frames) { $s = $f[0]; $d = $f[1]; $w.Write([byte]($s % 256)); $w.Write([byte]($s % 256)); $w.Write([byte]0); $w.Write([byte]0); $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$d.Length); $w.Write([uint32]$offset); $offset += $d.Length }
    foreach ($f in $frames) { $w.Write([byte[]]$f[1]) }
    $w.Dispose(); "ico  $($sizes -join ',')  $rel"
}

# desktop
foreach ($f in 'res\icon.png', 'res\mac-icon.png', 'res\128x128.png', 'res\128x128@2x.png', 'res\64x64.png', 'res\32x32.png', 'fastlane\metadata\android\en-US\images\icon.png') { ReplacePng $f 'tile' }
ReplacePng 'res\mac-tray-dark-x2.png' 'mono'
ReplacePng 'res\mac-tray-light-x2.png' 'dark'
WriteIco 'res\icon.ico' @(16, 24, 32, 48, 64, 128, 256)
WriteIco 'flutter\windows\runner\resources\app_icon.ico' @(16, 24, 32, 48, 64, 128, 256)
WriteIco 'res\tray-icon.ico' @(16, 20, 24, 32, 48)

# android launcher icons
foreach ($d in 'mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi') {
    $dir = "flutter\android\app\src\main\res\mipmap-$d"
    ReplacePng "$dir\ic_launcher.png" 'tile'
    ReplacePng "$dir\ic_launcher_round.png" 'round'
    ReplacePng "$dir\ic_launcher_foreground.png" 'fg'
    ReplacePng "$dir\ic_stat_logo.png" 'mono'
}

# vector logos
$svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><defs><linearGradient id="vt" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2563EB"/><stop offset="1" stop-color="#0EA5E9"/></linearGradient></defs><rect width="48" height="48" rx="13" fill="url(#vt)"/><path d="M26 9 L15 26 h8 l-3 13 13-18 h-8 z" fill="#fff"/></svg>'
foreach ($f in 'flutter\assets\icon.svg', 'res\logo.svg', 'res\scalable.svg') { [IO.File]::WriteAllText((Join-Path $root $f), $svg, (New-Object Text.UTF8Encoding $false)); "svg  $f" }
$header = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 48"><defs><linearGradient id="vt" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2563EB"/><stop offset="1" stop-color="#0EA5E9"/></linearGradient></defs><rect width="48" height="48" rx="13" fill="url(#vt)"/><path d="M26 9 L15 26 h8 l-3 13 13-18 h-8 z" fill="#fff"/><text x="60" y="34" font-family="Segoe UI, Arial, sans-serif" font-size="27" font-weight="800" fill="#0B1220">View<tspan fill="#2563EB">Titan</tspan></text></svg>'
[IO.File]::WriteAllText((Join-Path $root 'res\logo-header.svg'), $header, (New-Object Text.UTF8Encoding $false)); "svg  res\logo-header.svg"
