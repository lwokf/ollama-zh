@echo off
rem ============================================================
rem  Ollama 汉化补丁 - 还原官方原版(双击本文件即可)
rem  使用打补丁时自动保存的官方备份恢复原版 exe
rem ============================================================
chcp 65001 >nul

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 正在请求管理员权限,请在弹窗中点击"是"...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply-patch.ps1" -Restore
echo.
echo 按任意键关闭本窗口...
pause >nul
