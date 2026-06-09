@echo off
chcp 65001 >nul
setlocal

echo ============================================
echo  site-explorer 卸载程序
echo ============================================
echo.

set TARGET=%USERPROFILE%\.claude\commands\site-explorer.md

if not exist "%TARGET%" (
    echo [提示] 未找到已安装的 site-explorer 命令，无需卸载。
    pause
    exit /b 0
)

echo 将删除以下文件：
echo   %TARGET%
echo.
set /p CONFIRM=确认删除？(y/n):
if /i "%CONFIRM%" neq "y" (
    echo 已取消。
    pause
    exit /b 0
)

del "%TARGET%"
if %errorlevel% equ 0 (
    echo [OK] 已卸载 site-explorer 命令
) else (
    echo [错误] 删除失败，请手动删除：%TARGET%
)

echo.
pause
