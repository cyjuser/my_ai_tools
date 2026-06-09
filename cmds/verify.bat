@echo off
chcp 65001 >nul
setlocal

echo ============================================
echo  site-explorer 安装验证
echo ============================================
echo.

set PASS=0
set FAIL=0

:: 检查 1：Claude Code
echo [检查 1] Claude Code 是否安装...
where claude >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%v in ('claude --version 2^>nul') do set VER=%%v
    echo   [PASS] %VER%
    set /a PASS+=1
) else (
    echo   [FAIL] claude 命令未找到
    echo          请运行：npm install -g @anthropic-ai/claude-code
    set /a FAIL+=1
)

:: 检查 2：命令文件
echo [检查 2] site-explorer 命令文件...
if exist "%USERPROFILE%\.claude\commands\site-explorer.md" (
    echo   [PASS] %USERPROFILE%\.claude\commands\site-explorer.md
    set /a PASS+=1
) else (
    echo   [FAIL] 命令文件不存在，请运行 install.bat
    set /a FAIL+=1
)

:: 检查 3：settings.json
echo [检查 3] settings.json 配置...
if exist "%USERPROFILE%\.claude\settings.json" (
    echo   [PASS] settings.json 存在
    set /a PASS+=1
    findstr /i "playwright" "%USERPROFILE%\.claude\settings.json" >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [PASS] Playwright MCP 已启用
        set /a PASS+=1
    ) else (
        echo   [WARN] settings.json 中未检测到 Playwright 配置
        echo          请手动添加："playwright@claude-plugins-official": true
    )
) else (
    echo   [FAIL] settings.json 不存在，请运行 install.bat 或手动创建
    set /a FAIL+=1
)

:: 检查 4：Node.js
echo [检查 4] Node.js 版本...
where node >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%v in ('node --version') do set NODE_VER=%%v
    echo   [PASS] Node.js %NODE_VER%
    set /a PASS+=1
) else (
    echo   [FAIL] Node.js 未安装
    set /a FAIL+=1
)

:: 汇总
echo.
echo ============================================
echo  验证结果：%PASS% 项通过，%FAIL% 项失败
echo ============================================

if %FAIL% equ 0 (
    echo.
    echo 所有检查通过！可以启动 Claude Code 使用 /site-explorer 命令。
) else (
    echo.
    echo 请根据上方提示修复失败项后重新验证。
)

echo.
pause
