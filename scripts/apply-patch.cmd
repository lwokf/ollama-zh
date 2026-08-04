@echo off
rem ============================================================
rem  Ollama 汉化补丁 - 一键应用(双击本文件即可)
rem  自动请求管理员权限,自动查找 Ollama 安装目录
rem ============================================================
chcp 65001 >nul

rem 检查是否已有管理员权限,没有则自动以管理员身份重新启动
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 正在请求管理员权限,请在弹窗中点击"是"...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply-patch.ps1"
echo.
echo 按任意键关闭本窗口...
pause >nul
