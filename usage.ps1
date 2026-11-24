# 回忆录 · 查看站点占用
# 双击桌面「查看占用.bat」

$ErrorActionPreference = "Continue"
$Site = "D:\boke"
$Limit = 1GB   # GitHub Pages 站点上限

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Fmt([double]$bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    return "{0:N0} KB" -f ($bytes / 1KB)
}

function Bar([double]$pct) {
    $n = [Math]::Min(40, [Math]::Max(0, [Math]::Round($pct * 40)))
    return ("[" + ("#" * $n) + ("-" * (40 - $n)) + "]")
}

Clear-Host
Write-Host ""
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host "         回忆录 · 站点占用" -ForegroundColor DarkYellow
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host ""

# ---------- 图片 ----------
$imgDir = Join-Path $Site "source\images"
$imgs = @(Get-ChildItem -LiteralPath $imgDir -Recurse -File -ErrorAction SilentlyContinue)
$imgBytes = 0
if ($imgs.Count -gt 0) {
    $imgBytes = ($imgs | Measure-Object -Property Length -Sum).Sum
}

# ---------- 整站（不含 node_modules / .git / public） ----------
$all = @(Get-ChildItem -LiteralPath $Site -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\node_modules\\' -and $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\public\\' })
$repoBytes = 0
if ($all.Count -gt 0) {
    $repoBytes = ($all | Measure-Object -Property Length -Sum).Sum
}

$pct = $repoBytes / $Limit

Write-Host ("  图片占用    {0,10}   ({1} 张)" -f (Fmt $imgBytes), $imgs.Count)
Write-Host ("  站点总计    {0,10}   (文章 + 图片 + 主题 + 脚本)" -f (Fmt $repoBytes))
Write-Host ("  上限        {0,10}   (GitHub Pages 的 1 GB)" -f (Fmt $Limit))
Write-Host ""
Write-Host ("  {0}  {1:N1}%" -f (Bar $pct), ($pct * 100)) -ForegroundColor Green
Write-Host ""

# ---------- 按年份 ----------
if ($imgs.Count -gt 0) {
    Write-Host "  各年份图片：" -ForegroundColor Cyan
    $byYear = $imgs | Group-Object { $_.Directory.Name } | Sort-Object Name
    foreach ($g in $byYear) {
        $b = ($g.Group | Measure-Object -Property Length -Sum).Sum
        Write-Host ("    {0,-8} {1,10}   {2,4} 张" -f $g.Name, (Fmt $b), $g.Count)
    }
    Write-Host ""
}

# ---------- 最大的图 ----------
$big = @($imgs | Sort-Object Length -Descending | Select-Object -First 5)
if ($big.Count -gt 0) {
    Write-Host "  最大的 5 张：" -ForegroundColor Cyan
    foreach ($f in $big) {
        $flag = ""
        if ($f.Length -gt 800KB) { $flag = "  ← 偏大，建议重新压缩" }
        elseif ($f.Length -gt 400KB) { $flag = "  ← 略大" }
        Write-Host ("    {0,-32} {1,9}{2}" -f $f.Name, (Fmt $f.Length), $flag) -ForegroundColor Gray
    }
    Write-Host ""
}

# ---------- 估算还能放多少 ----------
$avg = 0
if ($imgs.Count -gt 0) { $avg = $imgBytes / $imgs.Count }
$remain = $Limit - $repoBytes
if ($avg -gt 0) {
    $room = [Math]::Floor($remain / $avg)
    Write-Host ("  按平均每张 {0} 算，大约还能再放 {1:N0} 张图" -f (Fmt $avg), $room) -ForegroundColor Cyan
}

# ---------- 提醒 ----------
Write-Host ""
if ($pct -ge 0.8) {
    Write-Host "  已经超过 80%，建议把老照片转存到图床，或降低压缩尺寸。" -ForegroundColor Red
} elseif ($pct -ge 0.5) {
    Write-Host "  过半了，注意一下图片体积。" -ForegroundColor Yellow
} else {
    Write-Host "  空间很充裕，放心写。" -ForegroundColor Green
}
Write-Host ""
Write-Host "  提示：觉得图片太大，改 insert-image.ps1 里的 `$MaxEdge（现在是 1600）" -ForegroundColor DarkGray
Write-Host "        或在 themes/landscape/source/css/_partial/article.styl 里调 max-height" -ForegroundColor DarkGray
Write-Host ""
