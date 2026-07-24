# 원본 아이콘 이미지에서 런처용 PNG 두 개를 만든다.
#
#   powershell -File tool/crop_icon.ps1
#   dart run flutter_launcher_icons
#
# 하는 일:
#  1. 원본 바깥의 검정 여백을 걷어내고 카드 영역만 남긴다.
#     안드로이드가 자체 마스크를 씌우기 때문에 여백이 남아 있으면
#     이중으로 둥글어지고 그림이 작아 보인다.
#  2. 적응형 아이콘 전경은 카드 모서리를 잘라내고 안전 영역 안으로 줄인다.
#     기기마다 마스크 모양이 달라 가장자리가 잘릴 수 있다.

Add-Type -AssemblyName System.Drawing

$dir = Join-Path $PSScriptRoot "..\assets\icon"
$source = Join-Path $dir "source_dog.png"

if (-not (Test-Path $source)) {
    Write-Error "원본이 없습니다: $source"
    exit 1
}

$bmp = New-Object System.Drawing.Bitmap($source)

# 순수 검정 여백과 카드를 구분해 경계를 찾는다
$minX = $bmp.Width; $maxX = 0; $minY = $bmp.Height; $maxY = 0
for ($y = 0; $y -lt $bmp.Height; $y += 3) {
    for ($x = 0; $x -lt $bmp.Width; $x += 3) {
        $c = $bmp.GetPixel($x, $y)
        if (($c.R + $c.G + $c.B) -gt 18) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

$side = [Math]::Min($maxX - $minX, $maxY - $minY)
Write-Output "카드 영역: ($minX, $minY) 크기 $side"

function Save-Icon($sx, $sy, $sw, $drawScale, $path, $transparent) {
    $out = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    if (-not $transparent) { $g.Clear([System.Drawing.Color]::Black) }

    $drawn = [int](1024 * $drawScale)
    $offset = [int]((1024 - $drawn) / 2)
    $g.DrawImage(
        $bmp,
        (New-Object System.Drawing.Rectangle($offset, $offset, $drawn, $drawn)),
        (New-Object System.Drawing.Rectangle($sx, $sy, $sw, $sw)),
        [System.Drawing.GraphicsUnit]::Pixel
    )
    $g.Dispose()
    $out.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
    Write-Output "생성: $path"
}

# 런처·iOS 용: 카드를 꽉 채운다
Save-Icon $minX $minY $side 1.0 (Join-Path $dir "app_icon.png") $false

# 적응형 전경: 카드 안쪽 6% 를 잘라내고 70% 크기로
$inset = [int]($side * 0.06)
Save-Icon ($minX + $inset) ($minY + $inset) ($side - $inset * 2) 0.70 `
    (Join-Path $dir "app_icon_foreground.png") $true

$bmp.Dispose()
