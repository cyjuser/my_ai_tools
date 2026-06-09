# site-explorer 迁移部署说明


## 包含文件

```
site-explorer-migration-pkg/
  README.md                      <- 本文件
  install.bat                    <- 一键安装（双击运行）
  uninstall.bat                  <- 卸载命令
  verify.bat                     <- 验证安装是否成功
  deploy-manual.md               <- 详细部署手册
  user-manual.md                 <- 使用操作手册
  commands/
    site-explorer.md             <- Claude Code 命令文件（核心）
```

## 快速安装（3 步）

**第一步**：确认已安装 Claude Code
```powershell
claude --version
```
若未安装：`npm install -g @anthropic-ai/claude-code`

**第二步**：双击运行 `install.bat`

**第三步**：双击运行 `verify.bat` 确认安装成功

## 验证

安装完成后，启动 Claude Code 并输入：
```
/site-explorer https://example.com --pages=3 --no-screenshots
```

看到 `[site-explorer] Phase 0:` 开头的输出即表示安装成功。

## 详细说明

- 部署步骤、配置方法、常见问题 → 查看 `deploy-manual.md`
- 命令参数、使用场景、输出说明 → 查看 `user-manual.md`
