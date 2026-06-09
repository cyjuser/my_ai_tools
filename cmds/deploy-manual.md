# site-explorer 部署手册

> 版本：2026-05-27 | 适用平台：Windows 11

---

## 前提条件

在部署前，确认新机器满足以下条件：

| 条件 | 检查命令 | 要求 |
|------|---------|------|
| Node.js | `node --version` | v18+ |
| npm | `npm --version` | v9+ |
| 网络可访问 npm registry | `npm ping` | OK |
| Windows 版本 | `winver` | Windows 10/11 |

---

## 第一步：安装 Claude Code

```powershell
npm install -g @anthropic-ai/claude-code
```

验证安装：

```powershell
claude --version
```

预期输出示例：`Claude Code 1.x.x`

> **注意**：如遇到 Bun 段错误（`Segmentation fault`），请对 `claude.exe` 及 npm 全局路径加安全软件白名单，或改用 WSL 环境运行。

---

## 第二步：配置 Claude Code API

编辑（或创建）`%USERPROFILE%\.claude\settings.json`，填入 API 配置：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "<your-api-base-url>",
    "ANTHROPIC_AUTH_TOKEN": "<your-api-token>"
  },
  "model": "sonnet"
}
```

> 如果使用官方 Anthropic API，`ANTHROPIC_BASE_URL` 可省略，仅填 `ANTHROPIC_AUTH_TOKEN`。

---

## 第三步：启用 Playwright MCP 插件

在 `%USERPROFILE%\.claude\settings.json` 中添加 `enabledPlugins` 节（若已存在则合并）：

```json
{
  "enabledPlugins": {
    "playwright@claude-plugins-official": true
  }
}
```

完整示例：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "<your-api-base-url>",
    "ANTHROPIC_AUTH_TOKEN": "<your-api-token>"
  },
  "model": "sonnet",
  "enabledPlugins": {
    "playwright@claude-plugins-official": true
  }
}
```

启动 Claude Code 后，插件会**自动下载安装**，无需手动执行 `npx` 命令。

---

## 第四步：安装 site-explorer 命令

将迁移包中的命令文件复制到 Claude Code 自定义命令目录：

**方法 A：运行批处理文件（推荐）**

```
双击运行：install.bat
```

**方法 B：手动复制**

```powershell
# 创建命令目录（如不存在）
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands"

# 复制命令文件
Copy-Item "commands\site-explorer.md" "$env:USERPROFILE\.claude\commands\site-explorer.md"
```

---

## 第五步：验证安装

1. 启动 Claude Code：

```powershell
claude
```

2. 在 Claude Code 对话框中输入：

```
/site-explorer https://example.com --pages=3 --no-screenshots
```

3. 预期看到：

```
[site-explorer] Target : https://example.com
[site-explorer] Mode   : sample | Pages: 3 | Timeout: 10min
[site-explorer] Output : ./site-explorer-output
[site-explorer] Phase 0: 检测认证状态...
[site-explorer] Phase 0: ✓ 已认证，直接进入爬取
[site-explorer] Phase 1: 开始结构爬取...
```

---

## 常见问题

### 问题：`/site-explorer` 命令找不到

检查命令文件是否在正确位置：

```powershell
Test-Path "$env:USERPROFILE\.claude\commands\site-explorer.md"
```

应返回 `True`。

### 问题：Playwright 浏览器无法启动

首次使用时 Playwright 需要下载浏览器，可手动触发：

```powershell
npx playwright install chromium
```

### 问题：Claude Code 报 API 认证失败

检查 `settings.json` 中的 `ANTHROPIC_AUTH_TOKEN` 是否正确，或联系管理员获取最新 Token。

### 问题：Bun EPERM NtSetInformationFile 错误

这是 Windows 安全软件拦截导致的，不影响 site-explorer 使用（site-explorer 使用 Playwright MCP，不依赖 Bun 二进制）。

---

## 目录结构说明

部署完成后的相关路径：

```
%USERPROFILE%\.claude\
  settings.json              <- Claude Code 全局配置
  commands\
    site-explorer.md         <- site-explorer 命令文件（本包安装）
  plugins\                   <- 插件目录（Claude Code 自动管理）
```

探索结果默认输出到运行命令时的当前目录下：

```
.\site-explorer-output\
  site-explorer-<domain>-<date>\
    feature-design.md
    user-manual.md
    screenshots\
    raw-data.json
    ...
```
