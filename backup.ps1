# 回忆录 · 备份
# 双击桌面「备份.bat」即可运行

$ErrorActionPreference = "Continue"
$Site = "D:\boke"
$Dest = "D:\boke备份"
$Keep = 10

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

if (-not (Test-Path -LiteralPath $Site)) {
    Write-Host "找不到站点目录 $Site" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}

Set-Location $Site
if (-not (Test-Path -LiteralPath $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host ""
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host "         回忆录 · 备份" -ForegroundColor DarkYellow
Write-Host "  ================================" -ForegroundColor DarkYellow
Write-Host ""

# 1) 版本库快照（能回滚到任意一次）
if (Test-Path -LiteralPath "$Site\.git") {
    Write-Host "  [1/3] 记录版本快照..." -ForegroundColor Cyan
    git add -A 2>&1 | Out-Null
    $msg = "自动备份 " + $stamp
    git commit -m $msg 2>&1 | Out-Null
    Write-Host "        完成" -ForegroundColor Green
}

# 2) 打包成 zip
Write-Host "  [2/3] 打包内容..." -ForegroundColor Cyan
$items = @(
    "source", "themes", "scripts", "scaffolds", ".git",
    "_config.yml", "_config.landscape.yml",
    "package.json", "package-lock.json", ".gitignore",
    "写作指南.md", "write.ps1", "backup.ps1"
)

$stage = Join-Path $env:TEMP ("boke-stage-" + $stamp)
New-Item -ItemType Directory -Path $stage -Force | Out-Null

foreach ($it in $items) {
    $src = Join-Path $Site $it
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $stage $it) -Recurse -Force
    }
}

$zip = Join-Path $Dest ("boke-" + $stamp + ".zip")
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -Force
Remove-Item -LiteralPath $stage -Recurse -Force
Write-Host "        完成" -ForegroundColor Green

# 3) 清理旧备份
Write-Host "  [3/3] 清理旧备份（只保留最近 $Keep 份）..." -ForegroundColor Cyan
$old = Get-ChildItem -LiteralPath $Dest -Filter "boke-*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep
foreach ($f in $old) { Remove-Item -LiteralPath $f.FullName -Force }
Write-Host "        完成" -ForegroundColor Green

$sizeKB = [math]::Round((Get-Item -LiteralPath $zip).Length / 1KB, 0)
Write-Host ""
Write-Host "  备份成功" -ForegroundColor Green
Write-Host "  文件：$zip" -ForegroundColor White
Write-Host "  大小：$sizeKB KB" -ForegroundColor DarkGray
Write-Host ""

Start-Process explorer.exe "/select,`"$zip`""
