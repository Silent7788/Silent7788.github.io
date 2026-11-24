# 回忆录 · 插图
# 用法一：把图片（可多张）拖到「插图.bat」图标上
# 用法二：直接双击，选图片
# 压缩完成后，Markdown 代码已复制到剪贴板，去记事本里 Ctrl+V 即可

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Files,
    [string]$Year = ""
)

$ErrorActionPreference = "Continue"
$Site = "D:\boke"
$MaxEdge = 1600
$Quality = 82
$YearState = Join-Path $env:LOCALAPPDATA "memoir-image-year.txt"

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Write-Host ""
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host "         回忆录 · 插图" -ForegroundColor DarkYellow
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host ""

# ---------- 1. 拿到图片 ----------
$list = @()
if ($Files -and $Files.Count -gt 0) {
    foreach ($f in $Files) {
        if (Test-Path -LiteralPath $f -PathType Container) {
            Write-Host "  跳过文件夹：$f" -ForegroundColor DarkGray
            continue
        }
        if (Test-Path -LiteralPath $f) { $list += (Get-Item -LiteralPath $f) }
    }
} else {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "选择要插入文章的图片（可按住 Ctrl 多选）"
    $dialog.Filter = "图片|*.jpg;*.jpeg;*.png;*.bmp;*.gif|所有文件|*.*"
    $dialog.Multiselect = $true
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 0
    }
    foreach ($n in $dialog.FileNames) { $list += (Get-Item -LiteralPath $n) }
}

$exts = @(".jpg", ".jpeg", ".png", ".bmp", ".gif")
$list = @($list | Where-Object { $exts -contains $_.Extension.ToLower() })

if ($list.Count -eq 0) {
    Write-Host "  没有可处理的图片（支持 jpg / png / bmp / gif）" -ForegroundColor Yellow
    Write-Host "  iPhone 的 HEIC 需要先用「照片」应用另存为 JPG" -ForegroundColor DarkGray
    exit 1
}

# ---------- 2. 年份 ----------
$defaultYear = (Get-Date).ToString("yyyy")
if (Test-Path -LiteralPath $YearState) {
    $saved = (Get-Content -LiteralPath $YearState -Raw).Trim()
    if ($saved -match '^\d{4}$') { $defaultYear = $saved }
}

if ([string]::IsNullOrWhiteSpace($Year)) {
    Write-Host "  这张照片属于哪一年？" -ForegroundColor White
    $Year = Read-Host "  直接回车 = $defaultYear"
}
if ([string]::IsNullOrWhiteSpace($Year)) { $Year = $defaultYear }
$Year = ($Year -replace '[^\d]', '')
if ($Year.Length -ne 4) { $Year = $defaultYear }
Set-Content -LiteralPath $YearState -Value $Year -Encoding ascii

$outDir = Join-Path $Site "source\images\$Year"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# ---------- 3. 压缩 ----------
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$snippets = @()
$ok = 0

foreach ($f in $list) {
    $img = $null
    $bmp = $null
    $g = $null
    try {
        $img = [System.Drawing.Image]::FromFile($f.FullName)

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

        # 文件名清理：空格换连字符，去掉 URL 里有歧义的符号
        $base = $f.BaseName -replace '\s+', '-'
        $base = $base -replace '[\\/:*?"<>|#%&()\[\]{}]', ''
        if ([string]::IsNullOrWhiteSpace($base)) { $base = "photo" }

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

        $name = [System.IO.Path]::GetFileName($target)
        $snippets += "![](/images/$Year/$name)"
        $ok++

        $kbBefore = [math]::Round($f.Length / 1KB, 0)
        $kbAfter = [math]::Round((Get-Item -LiteralPath $target).Length / 1KB, 0)
        Write-Host ("  {0,-24} {1,6} KB -> {2,4} KB  {3}x{4}" -f $f.Name, $kbBefore, $kbAfter, $nw, $nh) -ForegroundColor Gray
    } catch {
        Write-Host ("  {0}  失败：{1}" -f $f.Name, $_.Exception.Message) -ForegroundColor Red
    } finally {
        if ($g) { $g.Dispose() }
        if ($bmp) { $bmp.Dispose() }
        if ($img) { $img.Dispose() }
    }
}

if ($snippets.Count -eq 0) {
    Write-Host ""
    Write-Host "  没有成功处理任何图片" -ForegroundColor Red
    exit 1
}

# ---------- 4. 复制到剪贴板 ----------
$text = ($snippets -join "`r`n`r`n")
$copied = $false
try {
    Set-Clipboard -Value $text
    $copied = $true
} catch {
    try { [System.Windows.Forms.Clipboard]::SetText($text); $copied = $true } catch {}
}

Write-Host ""
Write-Host "  ================================" -ForegroundColor DarkYellow
if ($copied) {
    Write-Host "  已复制到剪贴板，去记事本里 Ctrl+V 粘贴即可" -ForegroundColor Green
} else {
    Write-Host "  自动复制失败，请手动复制下面这行：" -ForegroundColor Yellow
}
Write-Host ""
foreach ($s in $snippets) { Write-Host "    $s" -ForegroundColor Yellow }
Write-Host ""
Write-Host "  图片保存在：$outDir" -ForegroundColor DarkGray
Write-Host ""
