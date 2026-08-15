# Ollama 汉化补丁应用脚本
#
# 用法:
#   1. 退出正在运行的 Ollama(托盘图标右键 -> 退出 Ollama)
#   2. 右键"以管理员身份运行 PowerShell",在解压目录执行:
#        .\apply-patch.ps1
#      或指定安装目录:
#        .\apply-patch.ps1 -InstallDir "D:\ollama"
#   3. 还原官方原版:
#        .\apply-patch.ps1 -Restore
#
# 解压位置(重要):
#   - 本脚本与汉化版 exe 可以放在【任意目录】(桌面/下载/D 盘等),无需放进 Ollama 安装目录
#   - 脚本会自动查找 Ollama 安装位置(依次检测 D:\ollama、%LOCALAPPDATA%\Programs\Ollama、C:\Program Files\Ollama)
#   - 唯一要求:apply-patch.ps1 与汉化版 "ollama app.exe" 必须保持在同一个文件夹内
#   - 若提示无法加载脚本,先执行:Set-ExecutionPolicy -Scope Process Bypass
#
# 说明:
#   - 只替换 ollama app.exe(桌面端 UI 壳),服务端 ollama.exe 保持官方原版
#   - 首次应用时自动备份官方 exe 为 "ollama app.exe.official.bak"
#   - 官方更新(自动更新/重新安装)会覆盖汉化版,更新后重新运行本脚本即可恢复中文
#   - 汉化版 exe 必须与官方安装的版本号对应
#   - 过期备份检测:备份版本与当前官方版不一致时,会提示并允许刷新备份(-Force 跳过提示自动刷新)

param(
    [string]$InstallDir = "",
    [switch]$Restore,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Find-InstallDir {
    param([string]$Hint)
    $candidates = @()
    if ($Hint) { $candidates += $Hint }
    $candidates += "D:\ollama"
    $candidates += Join-Path $env:LOCALAPPDATA "Programs\Ollama"
    $candidates += "C:\Program Files\Ollama"
    foreach ($c in $candidates | Select-Object -Unique) {
        if (Test-Path (Join-Path $c "ollama app.exe")) {
            return $c
        }
    }
    return $null
}

function Get-AppVersion {
    param([string]$ExePath)
    for ($i = 1; $i -le 3; $i++) {
        try {
            # 用 cmd 调用以兼容 .bak 等非 .exe 扩展名(PowerShell 的 & 会把它们当"文档"拒绝执行)
            $v = cmd /c ('"' + $ExePath + '" --version') 2>&1 | Out-String
            if ($v -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
        } catch {}
        Start-Sleep -Milliseconds 400
    }
    return ""
}

$dir = Find-InstallDir -Hint $InstallDir
if (-not $dir) {
    Write-Host "[错误] 未找到 Ollama 安装目录,请用 -InstallDir 指定,例如:" -ForegroundColor Red
    Write-Host '       .\apply-patch.ps1 -InstallDir "D:\ollama"' -ForegroundColor Yellow
    exit 1
}

$target = Join-Path $dir "ollama app.exe"
$backup = "$target.official.bak"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zhExe = Join-Path $scriptDir "ollama app.exe"

Write-Host "== Ollama 汉化补丁 ==" -ForegroundColor Cyan
Write-Host "安装目录 : $dir"

if (-not (Test-Path $zhExe)) {
    Write-Host "[错误] 未找到汉化版 exe,请确认它和本脚本在同一目录" -ForegroundColor Red
    exit 1
}

# 还原模式
if ($Restore) {
    if (-not (Test-Path $backup)) {
        Write-Host "[提示] 未找到官方备份文件:$backup" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "原因:你还没有应用过汉化补丁,所以没有备份。" -ForegroundColor White
        Write-Host "请先双击 apply-patch.cmd 应用汉化(应用时会自动备份官方 exe)," -ForegroundColor Cyan
        Write-Host "以后想还原时再双击 restore-official.cmd。" -ForegroundColor Cyan
        Write-Host "如果当前 exe 本来就是官方原版(界面为英文),则无需还原。" -ForegroundColor Cyan
        exit 1
    }
    Get-Process | Where-Object { $_.ProcessName -like "ollama*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    $bakV = Get-AppVersion -ExePath $backup
    $curV = Get-AppVersion -ExePath $target
    Copy-Item $backup $target -Force
    if ($bakV) {
        Write-Host "[完成] 已还原官方原版 exe,版本: $bakV" -ForegroundColor Green
    } else {
        Write-Host "[完成] 已还原官方原版 exe" -ForegroundColor Green
    }
    if ($bakV -and $curV -and ($bakV -ne $curV)) {
        Write-Host "[提示] 还原的备份版本 ($bakV) 与被替换的 exe ($curV) 不一致,请确认这是你想要还原的版本" -ForegroundColor Yellow
    }
    exit 0
}

# 检查官方版备份(处理过期备份:备份版本与当前官方版不一致时提示并允许刷新)
function Get-FileHashWithRetry {
    param([string]$Path, [int]$Attempts = 5)
    for ($i = 1; $i -le $Attempts; $i++) {
        try { return (Get-FileHash $Path -ErrorAction Stop).Hash }
        catch { if ($i -eq $Attempts) { return "" } ; Start-Sleep -Milliseconds 400 }
    }
}

$backupVer = Get-AppVersion -ExePath $backup
$curVer    = Get-AppVersion -ExePath $target
if (-not (Test-Path $backup)) {
    Copy-Item $target $backup -Force
    Write-Host "[备份] 官方 exe 已备份为 $backup" -ForegroundColor Yellow
} elseif ($backupVer -and $curVer -and ($backupVer -eq $curVer)) {
    Write-Host "[信息] 已存在官方备份,版本 ($curVer) 与当前官方版一致,无需刷新" -ForegroundColor Gray
} else {
    $targetHash = Get-FileHashWithRetry -Path $target
    $zhHash     = Get-FileHashWithRetry -Path $zhExe
    $bd  = if ($backupVer) { $backupVer } else { "未知" }
    $bdc = if ($curVer)    { $curVer }    else { "未知" }
    if ($targetHash -and $zhHash -and ($targetHash -eq $zhHash)) {
        # 当前安装的已是汉化版(重复应用),但备份版本不一致:不能把汉化版当官方版备份
        Write-Host "[警告] 当前安装的已是汉化版,但备份版本 ($bd) 与它不一致,已跳过备份刷新(避免把汉化版当成官方版备份)。" -ForegroundColor Yellow
        Write-Host "        如需正确刷新备份,请先运行 restore-official.cmd 还原官方原版,再重新运行本脚本。" -ForegroundColor Gray
    } elseif (-not $targetHash -or -not $zhHash) {
        # 读不到校验值(文件被占用等):跳过刷新,避免把汉化版误当官方版备份
        Write-Host "[警告] 暂时无法读取 exe 校验值(文件可能正被占用),已跳过备份刷新。请稍后重试,或删除 $backup 后重新运行本脚本。" -ForegroundColor Yellow
    } else {
        # 备份存在但版本与当前官方版不一致(官方更新过):提示并允许刷新
        if ($Force) {
            $refresh = $true
        } else {
            Write-Host "[警告] 备份版本 ($bd) 与当前官方版 ($bdc) 不一致,直接还原会回退到旧版。" -ForegroundColor Yellow
            try {
                $ans = Read-Host "是否用当前官方版 ($bdc) 刷新备份?[Y/n,回车默认 Y]"
            } catch {
                $ans = ""
            }
            $refresh = ($ans -eq "" -or $ans -match "^[Yy是]")
        }
        if ($refresh) {
            Copy-Item $target $backup -Force
            Write-Host "[备份] 已用当前官方版 ($bdc) 刷新备份:$backup" -ForegroundColor Yellow
        } else {
            Write-Host "[信息] 保留旧备份 ($bd),还原时将回到该版本;如需刷新请删除 $backup 后重新运行本脚本" -ForegroundColor Gray
        }
    }
}

# 关闭正在运行的 Ollama
Get-Process | Where-Object { $_.ProcessName -like "ollama*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# 替换
$before = Get-AppVersion -ExePath $backup
$zhVer = Get-AppVersion -ExePath $zhExe
Copy-Item $zhExe $target -Force

$after = Get-AppVersion -ExePath $target
if ($after -ne "") {
    Write-Host "[完成] 汉化版已安装,版本: $after" -ForegroundColor Green
    if ($before -and ($before -ne $after)) {
        Write-Host "[警告] 汉化版版本 ($after) 与官方备份 ($before) 不一致,请确认使用的是对应版本的补丁" -ForegroundColor Yellow
    }
} else {
    Write-Host "[完成] 汉化版已安装(无法读取版本号)" -ForegroundColor Green
}

Write-Host ""
Write-Host "现在可以启动 Ollama 了。官方更新后 exe 会被覆盖回英文,重新运行本脚本即可恢复中文。" -ForegroundColor Cyan
Write-Host "如需还原官方原版: .\apply-patch.ps1 -Restore" -ForegroundColor Gray
