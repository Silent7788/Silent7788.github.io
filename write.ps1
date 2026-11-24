# 回忆录 · 写作助手
# 双击桌面「写文章.bat」即可运行

param([string]$Action = "")

$ErrorActionPreference = "Continue"
$Site = "D:\boke"
$Editor = "notepad"

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
if (-not (Test-Path -LiteralPath $Site)) {
    Write-Host "找不到站点目录 $Site" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}
Set-Location $Site

function Show-Head {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================" -ForegroundColor DarkYellow
    Write-Host "         回忆录 · 写作助手" -ForegroundColor DarkYellow
    Write-Host "  ================================" -ForegroundColor DarkYellow
    Write-Host ""
}

function Open-Editor([string]$Path) {
    Write-Host ""
    Write-Host "  正在打开记事本..." -ForegroundColor Cyan
    Start-Process -FilePath $script:Editor -ArgumentList ('"' + $Path + '"')
    Write-Host ""
    Write-Host "  写完后先【保存】(Ctrl+S)，再回到这个窗口按回车。" -ForegroundColor Yellow
    Read-Host "  按回车继续" | Out-Null
}

function Test-Server {
    try {
        $null = Invoke-WebRequest "http://localhost:4000/" -UseBasicParsing -TimeoutSec 2
        return $true
    } catch { return $false }
}

function Start-ServerIfNeeded {
    if (Test-Server) { return $true }
    Write-Host "  正在启动本地预览服务器（第一次会慢几秒）..." -ForegroundColor Cyan
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "hexo server -p 4000" -WorkingDirectory $Site -WindowStyle Hidden
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Server) { Write-Host "  服务器已就绪" -ForegroundColor Green; return $true }
    }
    Write-Host "  服务器启动超时，请稍后手动运行 hexo s" -ForegroundColor Red
    return $false
}

function Wait-ForContent([string]$Title) {
    Start-Sleep -Seconds 2
    if ([string]::IsNullOrWhiteSpace($Title)) { return }
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $r = Invoke-WebRequest "http://localhost:4000/timeline.json" -UseBasicParsing -TimeoutSec 2
            if ($r.Content.Contains($Title)) { return }
        } catch {}
    }
}

function Show-Preview([string]$Title) {
    if (-not (Start-ServerIfNeeded)) { return }
    Write-Host "  正在生成页面..." -ForegroundColor Cyan
    Wait-ForContent $Title
    Start-Process "http://localhost:4000/timeline/"
    Write-Host ""
    Write-Host "  已在浏览器打开时间轴。" -ForegroundColor Green
    Write-Host "  如果没看到新内容，刷新一下页面即可。" -ForegroundColor DarkGray
}

function New-Post {
    Show-Head
    Write-Host "  新的一篇记忆" -ForegroundColor White
    Write-Host ""
    $title = Read-Host "  文章标题（例如：第一次搬家）"
    if ([string]::IsNullOrWhiteSpace($title)) { return }

    $safe = $title -replace '[\\/:*?"<>|]', ' '
    $safe = $safe.Trim()

    Write-Host ""
    Write-Host "  正在创建 $safe.md ..." -ForegroundColor Cyan
    & hexo new $safe 2>&1 | Out-Null

    $expected = Join-Path "$Site\source\_posts" ($safe + ".md")
    if (Test-Path -LiteralPath $expected) {
        $file = Get-Item -LiteralPath $expected
    } else {
        $file = Get-ChildItem "$Site\source\_posts\*.md" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }

    if (-not $file) {
        Write-Host "  创建失败，可能是标题里含有特殊字符。" -ForegroundColor Red
        return
    }

    Write-Host "  已创建：$($file.Name)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  提示：把日期改成真实日期，时间轴就会排到正确的位置。" -ForegroundColor DarkGray

    Open-Editor $file.FullName
    Show-Preview $safe
}

function Edit-Post {
    Show-Head
    Write-Host "  继续写哪一篇？" -ForegroundColor White
    Write-Host ""
    $posts = @(Get-ChildItem "$Site\source\_posts\*.md" | Sort-Object Name)
    if ($posts.Count -eq 0) {
        Write-Host "  还没有任何文章，先选 1 新建一篇吧。" -ForegroundColor Yellow
        return
    }
    for ($i = 0; $i -lt $posts.Count; $i++) {
        Write-Host ("  {0,2}. {1}" -f ($i + 1), $posts[$i].BaseName)
    }
    Write-Host ""
    $sel = Read-Host "  输入编号（直接回车返回）"
    if ([string]::IsNullOrWhiteSpace($sel)) { return }
    $idx = 0
    if (-not [int]::TryParse($sel, [ref]$idx)) { return }
    if ($idx -lt 1 -or $idx -gt $posts.Count) { return }

    $target = $posts[$idx - 1]
    Open-Editor $target.FullName
    Show-Preview $target.BaseName
}

function Add-Shuo {
    Show-Head
    Write-Host "  记录一条 QQ 空间说说" -ForegroundColor White
    Write-Host "  （只是登记一条索引，内容还是存在 QQ 空间）" -ForegroundColor DarkGray
    Write-Host ""

    $today = Get-Date -Format "yyyy-MM-dd"
    $d = Read-Host "  日期（回车 = $today）"
    if ([string]::IsNullOrWhiteSpace($d)) { $d = $today }
    $d = $d.Trim()
    if ($d -notmatch '^\d{4}-\d{1,2}-\d{1,2}$') {
        Write-Host "  日期格式不对，应该是 2015-06-08 这样。" -ForegroundColor Red
        return
    }

    $text = Read-Host "  一句话摘要（回车跳过）"
    $link = Read-Host "  QQ空间链接（必填）"
    if ([string]::IsNullOrWhiteSpace($link)) {
        Write-Host "  没有链接，已取消。" -ForegroundColor Yellow
        return
    }
    $imgs = Read-Host "  几张图（回车跳过）"

    $file = Join-Path $Site "source\_data\shuoshuo.yml"
    if (-not (Test-Path -LiteralPath $file)) {
        New-Item -ItemType File -Path $file -Force | Out-Null
    }

    function YamlQuote([string]$s) {
        return "'" + ($s.Trim() -replace "'", "''") + "'"
    }

    $nl = "`r`n"
    $block = $nl + "- date: " + $d + $nl
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        $block += "  text: " + (YamlQuote $text) + $nl
    }
    $block += "  link: " + (YamlQuote $link) + $nl
    if ($imgs -and $imgs.Trim() -match '^\d+$') {
        $block += "  images: " + $imgs.Trim() + $nl
    }

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText($file, $block, $utf8)

    Write-Host ""
    Write-Host "  已记录。记得回菜单选 5 发布，别人才看得到。" -ForegroundColor Green
}

function Publish-Site {
    Set-Location $Site
    Write-Host ""
    Write-Host "  [1/3] 提交本地修改..." -ForegroundColor Cyan
    git add -A 2>&1 | Out-Null
    $msg = "更新 " + (Get-Date -Format "yyyy-MM-dd HH:mm")
    git commit -m $msg 2>&1 | Out-Null
    Write-Host "        完成" -ForegroundColor Green

    Write-Host "  [2/3] 推送到 GitHub..." -ForegroundColor Cyan
    git push 2>&1 | Out-Null
    $code = $LASTEXITCODE

    if ($code -eq 0) {
        Write-Host "        完成" -ForegroundColor Green
        Write-Host "  [3/3] 正在自动部署..." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  大约 1 分钟后生效：https://silent7788.github.io/" -ForegroundColor White
        Start-Process "https://silent7788.github.io/"
    } else {
        Write-Host "        推送失败（网络或登录问题）" -ForegroundColor Red
    }
}

# ---------- 入口 ----------

if ($Action -eq "build") {
    Show-Preview ""
    exit 0
}

while ($true) {
    Show-Head
    Write-Host "  1  写新的一篇"
    Write-Host "  2  继续修改已有的一篇"
    Write-Host "  3  只看预览（打开时间轴）"
    Write-Host "  4  打开图片文件夹（放照片用）"
    Write-Host "  5  发布到网上（朋友就能看到）"
    Write-Host "  6  记录一条 QQ 空间说说（贴链接）"
    Write-Host "  0  退出"
    Write-Host ""

    $choice = Read-Host "  请选择"

    switch ($choice) {
        "1" { New-Post; Write-Host ""; Read-Host "  按回车返回菜单" | Out-Null }
        "2" { Edit-Post; Write-Host ""; Read-Host "  按回车返回菜单" | Out-Null }
        "3" {
            if (Start-ServerIfNeeded) { Start-Process "http://localhost:4000/timeline/" }
            Write-Host ""
            Read-Host "  按回车返回菜单" | Out-Null
        }
        "4" { Start-Process explorer.exe "/select,`"$Site\source\images`""; }
        "5" { Publish-Site; Write-Host ""; Read-Host "  按回车返回菜单" | Out-Null }
        "6" { Add-Shuo; Write-Host ""; Read-Host "  按回车返回菜单" | Out-Null }
        "0" { return }
        default { }
    }
}
