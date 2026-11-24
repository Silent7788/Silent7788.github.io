# 回忆录 · 图片压缩
# 双击桌面「压缩图片.bat」，或用 -Source / -Year 参数直接指定

param([string]$Source = "", [string]$Year = "", [switch]$NoPause)

$ErrorActionPreference = "Continue"
$Site = "D:\boke"
$MaxEdge = 1600      # 长边最大像素
$Quality = 82        # JPEG 质量
$Prefix = ""

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Write-Host ""
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host "         回忆录 · 图片压缩" -ForegroundColor DarkYellow
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "  规则：长边压到 $MaxEdge 像素，JPEG 质量 $Quality（肉眼几乎无差别）" -ForegroundColor DarkGray
Write-Host ""

# ---------- 选文件夹 ----------
if ([string]::IsNullOrWhiteSpace($Source)) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "选择要压缩的照片所在文件夹（建议一次选一年的）"
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "  已取消" -ForegroundColor Yellow
        Read-Host "  按回车退出"
        exit 0
    }
    $Source = $dialog.SelectedPath
}

if (-not (Test-Path -LiteralPath $Source)) {
    Write-Host "  找不到文件夹：$Source" -ForegroundColor Red
    Read-Host "  按回车退出"
    exit 1
}

# ---------- 选年份 ----------
if ([string]::IsNullOrWhiteSpace($Year)) {
    Write-Host "  这些照片属于哪一年？" -ForegroundColor White
    Write-Host "  （例如 2010，直接回车 = 当前年份 $(Get-Date -Format 'yyyy')）" -ForegroundColor DarkGray
    $Year = Read-Host "  年份"
    if ([string]::IsNullOrWhiteSpace($Year)) { $Year = (Get-Date).ToString("yyyy") }
}
$Year = ($Year -replace '[^\d]', '')

$outDir = Join-Path $Site "source\images\$Year"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# ---------- 收集图片 ----------
$exts = @(".jpg", ".jpeg", ".png", ".bmp", ".gif")
$files = @(Get-ChildItem -LiteralPath $Source -File | Where-Object { $exts -contains $_.Extension.ToLower() })

if ($files.Count -eq 0) {
    Write-Host "  这个文件夹里没有找到图片（支持 jpg / png / bmp）" -ForegroundColor Yellow
    Write-Host "  如果是 iPhone 的 HEIC 格式，请先用「照片」应用另存为 JPG。" -ForegroundColor DarkGray
    Read-Host "  按回车退出"
    exit 0
}

Write-Host ""
Write-Host "  找到 $($files.Count) 张，开始处理..." -ForegroundColor Cyan
Write-Host ""

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$totalBefore = 0
$totalAfter = 0
$okCount = 0
$failCount = 0

foreach ($f in $files) {
    $totalBefore += $f.Length
    $img = $null
    $bmp = $null
    $g = $null
    try {
        $img = [System.Drawing.Image]::FromFile($f.FullName)

        # 手机照片的方向标记
        try {
            if ($img.PropertyIdList -contains 274) {
                $ori = [int]$img.GetPropertyItem(274).Value[0]
                switch ($ori) {
                    3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
                    6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
                    8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
                }
            }
        } catch {}

        $w = $img.Width
        $h = $img.Height
        $ratio = [Math]::Min($MaxEdge / $w, $MaxEdge / $h)
        if ($ratio -gt 1) { $ratio = 1 }
        $nw = [int][Math]::Round($w * $ratio)
        $nh = [int][Math]::Round($h * $ratio)
        if ($nw -lt 1) { $nw = 1 }
        if ($nh -lt 1) { $nh = 1 }

        $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::White)
        $g.DrawImage($img, 0, 0, $nw, $nh)

        $base = $f.BaseName
        $target = Join-Path $outDir ($base + ".jpg")
        $n = 2
        while (Test-Path -LiteralPath $target) {
            $target = Join-Path $outDir ($base + "-" + $n + ".jpg")
            $n++
        }

        $eps = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $eps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
        $bmp.Save($target, $codec, $eps)

        $eps.Dispose()
        $newSize = (Get-Item -LiteralPath $target).Length
        $totalAfter += $newSize
        $okCount++

        $kbBefore = [math]::Round($f.Length / 1KB, 0)
        $kbAfter = [math]::Round($newSize / 1KB, 0)
        Write-Host ("  {0,-28} {1,6} KB  ->  {2,5} KB   {3}x{4}" -f $f.Name, $kbBefore, $kbAfter, $nw, $nh) -ForegroundColor Gray
    } catch {
        $failCount++
        Write-Host ("  {0}  失败：{1}" -f $f.Name, $_.Exception.Message) -ForegroundColor Red
    } finally {
        if ($g) { $g.Dispose() }
        if ($bmp) { $bmp.Dispose() }
        if ($img) { $img.Dispose() }
    }
}

Write-Host ""
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host ("  成功 {0} 张，失败 {1} 张" -f $okCount, $failCount) -ForegroundColor Green
if ($totalBefore -gt 0) {
    $saved = $totalBefore - $totalAfter
    Write-Host ("  总体积 {0} MB  ->  {1} MB，省了 {2} MB" -f [math]::Round($totalBefore/1MB,1), [math]::Round($totalAfter/1MB,1), [math]::Round($saved/1MB,1)) -ForegroundColor White
}
Write-Host "  输出到：$outDir" -ForegroundColor White
Write-Host ""
Write-Host "  在文章里这样插图片：" -ForegroundColor DarkGray
Write-Host ("    ![](/images/{0}/照片名.jpg)" -f $Year) -ForegroundColor Yellow
Write-Host ""

if (-not $NoPause) {
    Start-Process explorer.exe "/select,`"$outDir`""
    Read-Host "  按回车退出" | Out-Null
}
