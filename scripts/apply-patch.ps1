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
    try {
        $v = & $ExePath --version 2>&1 | Out-String
        if ($v -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
    } catch {}
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
        Write-Host "[错误] 未找到官方备份文件,无法还原" -ForegroundColor Red
        exit 1
    }
    Get-Process | Where-Object { $_.ProcessName -like "ollama*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    Copy-Item $backup $target -Force
    Write-Host "[完成] 已还原官方原版 exe" -ForegroundColor Green
    exit 0
}

# 检查官方版备份
if (-not (Test-Path $backup)) {
    Copy-Item $target $backup -Force
    Write-Host "[备份] 官方 exe 已备份为 $backup" -ForegroundColor Yellow
} else {
    Write-Host "[信息] 已存在官方备份(如需覆盖请删除 $backup)" -ForegroundColor Gray
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
