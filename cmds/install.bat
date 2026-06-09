@echo off
chcp 65001 >nul
setlocal

echo ============================================
echo  site-explorer 安装程序
echo ============================================
echo.

:: 检查 Claude Code 是否安装
where claude >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到 claude 命令。
    echo 请先安装 Claude Code：npm install -g @anthropic-ai/claude-code
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('claude --version 2^>nul') do set CLAUDE_VER=%%v
echo [OK] Claude Code 已安装：%CLAUDE_VER%

:: 确定目标目录
set COMMANDS_DIR=%USERPROFILE%\.claude\commands

echo.
echo [步骤 1] 创建命令目录...
if not exist "%COMMANDS_DIR%" (
    mkdir "%COMMANDS_DIR%"
    echo [OK] 已创建：%COMMANDS_DIR%
) else (
    echo [OK] 目录已存在：%COMMANDS_DIR%
)

:: 复制命令文件
echo.
echo [步骤 2] 安装 site-explorer 命令...
copy /y "commands\site-explorer.md" "%COMMANDS_DIR%\site-explorer.md" >nul
if %errorlevel% neq 0 (
    echo [错误] 复制失败，请检查源文件是否存在：commands\site-explorer.md
    pause
    exit /b 1
)
echo [OK] 已安装：%COMMANDS_DIR%\site-explorer.md

:: 检查 settings.json 并提示配置 Playwright
echo.
echo [步骤 3] 检查 Playwright MCP 配置...
set SETTINGS_FILE=%USERPROFILE%\.claude\settings.json

if not exist "%SETTINGS_FILE%" (
    echo [提示] 未找到 settings.json，将自动创建基础配置...
    echo {> "%SETTINGS_FILE%"
    echo   "enabledPlugins": {>> "%SETTINGS_FILE%"
    echo     "playwright@claude-plugins-official": true>> "%SETTINGS_FILE%"
    echo   }>> "%SETTINGS_FILE%"
    echo }>> "%SETTINGS_FILE%"
    echo [OK] 已创建：%SETTINGS_FILE%
    echo [注意] 请编辑该文件，填入您的 ANTHROPIC_AUTH_TOKEN
) else (
    findstr /i "playwright" "%SETTINGS_FILE%" >nul 2>&1
    if %errorlevel% equ 0 (
        echo [OK] Playwright MCP 已在 settings.json 中配置
    ) else (
        echo [提示] settings.json 中未检测到 Playwright 配置
        echo 请手动在 %SETTINGS_FILE% 的 enabledPlugins 中添加：
        echo   "playwright@claude-plugins-official": true
    )
)

:: 安装完成
echo.
echo ============================================
echo  安装完成！
echo ============================================
echo.
echo 下一步：
echo   1. 启动 Claude Code：claude
echo   2. 输入以下命令验证：
echo      /site-explorer https://example.com --pages=3 --no-screenshots
echo.
echo 详细说明请阅读：
echo   deploy-manual.md  - 部署手册
echo   user-manual.md    - 使用操作手册
echo.
pause
