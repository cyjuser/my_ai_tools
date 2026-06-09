# site-explorer 使用操作手册

> 版本：2026-05-27

---

## 什么是 site-explorer

`/site-explorer` 是一个 Claude Code 自定义命令，能自动探索指定网站，梳理所有功能模块，并生成两份可直接使用的文档：

- **`feature-design.md`** — 功能设计文档，记录网站架构、模块详情、用户角色
- **`user-manual.md`** — 用户使用手册，包含操作步骤和速查表

整个过程分三个阶段：结构爬取（Phase 1）→ 精细交互（Phase 2）→ 文档合成（Phase 3），无需手工操作。

---

## 快速开始

### 最简调用

```
/site-explorer https://example.com
```

使用所有默认参数：sample 模式，最多 20 页，中文文档，polite 速率，不执行增删改。

### 典型场景

```bash
# 探索公开站点
/site-explorer https://linear.app

# 探索内网系统（需手动登录）
/site-explorer https://intranet.corp.com

# 快速探索，最多 30 页
/site-explorer https://example.com --pages=30 --preset=fast

# 指定输出目录，生成英文文档
/site-explorer https://example.com --output=./docs/site-report --lang=en

# 想亲自控制表单填写内容
/site-explorer https://intranet.corp.com --write-mode=interactive
```

---

## 参数速查表

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `<url>` | 必填 | — | 目标网站地址（http/https） |
| `--pages=N` | 整数 | `20` | 最多访问页数 |
| `--timeout=N` | 分钟 | `10` | 总时间上限 |
| `--mode=sample\|full` | 字符串 | `sample` | 采样模式 / 全站爬取 |
| `--depth=N` | 整数 | `3` | BFS 最大层深（full 模式有效） |
| `--output=<dir>` | 路径 | `./site-explorer-output` | 文档输出目录 |
| `--lang=zh\|en` | 字符串 | `zh` | 输出文档语言 |
| `--preset=polite\|normal\|fast` | 字符串 | `polite` | 速率预设 |
| `--delay=N` | 秒 | 由 preset 决定 | 操作间隔 |
| `--no-screenshots` | 开关 | 关 | 不截图（加快速度） |
| `--respectrobots=yes\|no` | 字符串 | `yes` | 是否遵守 robots.txt |
| `--write-mode=off\|interactive` | 字符串 | `off` | 增删改操作模式 |
| `--auth=browser\|<file>` | 字符串 | — | 认证方式 |

### 速率预设

| 预设 | 间隔 | 适用场景 |
|------|------|---------|
| `polite`（默认） | 3s ± 1s | 公开站点、外部 SaaS |
| `normal` | 2s ± 1s | 内部系统 |
| `fast` | 1s | 本地/测试环境 |

---

## 处理需要登录的网站

site-explorer 会在 Phase 0 自动检测是否遇到登录墙。

### 情况一：需要扫码 / 手动登录（推荐用于内网系统）

直接运行命令，遇到登录页时 Claude 会提示：

```
[site-explorer] Phase 0: 需要手动登录，启动可见浏览器...
请在浏览器中完成登录后，回到 Claude Code 输入「继续」
```

完成登录（如飞书扫码）后，在对话框输入**「继续」**，探索自动恢复。

### 情况二：已有 Cookie 文件

```bash
/site-explorer https://example.com --auth=cookies.json
```

Cookie 文件支持 Playwright `storageState` 格式。

### 情况三：从本地 Chrome 导入 Cookie

```bash
/site-explorer https://example.com --auth=browser
```

---

## 增删改操作说明（write-mode）

### 默认模式（`--write-mode=off`）

| 操作类型 | 行为 |
|---------|------|
| 新建 | 自动用 `-cc` 后缀填充，不等待确认 |
| 修改 | 跳过，仅截图 UI |
| 删除 | 跳过，仅截图 UI |

### 交互模式（`--write-mode=interactive`）

遇到每个写操作时 Claude 会**暂停探索**，展示当前表单结构：

```
[site-explorer] ⏸  遇到写操作，等待您的指示
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  页面  : /settings/teams
  操作  : CREATE
  元素  : 「新建团队」按钮
  表单字段:
    · 团队名称（文本，必填）
    · 描述（文本，选填）
    · 可见性（下拉，必填）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  请选择：
  [填值]  逐字段输入，格式：字段名: 值
  [传图]  粘贴截图文件路径，Claude 解析后填写
  [确认]  输入 y — 用默认值（名称自动加 -cc 后缀）
  [取消]  输入 n 或 skip — 跳过此操作
```

**四种回应方式：**

| 输入 | 行为 |
|------|------|
| `团队名称: 测试团队` | Claude 按您给的值填表，填完截图展示，再等您输入 `y` 确认提交 |
| 截图路径（如 `C:\screen.png`） | Claude 读图识别已填字段值，复现到当前表单，展示后等 `y` 确认 |
| `y` | 用默认值直接提交（文本字段加 `-cc` 后缀） |
| `n` 或 `skip` | 跳过此操作，继续探索下一页 |

---

## 输出文件说明

每次探索结果存放在：

```
./site-explorer-output/site-explorer-<domain>-<日期>/
```

| 文件 | 用途 |
|------|------|
| `feature-design.md` | **功能设计文档**（主要输出） |
| `user-manual.md` | **用户使用手册**（主要输出） |
| `screenshots/` | 各页面截图 |
| `raw-data.json` | Phase 1 原始爬取数据（调试用） |
| `features.json` | Phase 2 功能结构化数据（调试用） |
| `visited.txt` | 已访问 URL 列表 |
| `robots-disallow.txt` | robots.txt 中的禁止路径 |
| `cc-created.txt` | 探索中新建/修改的内容清单（需手动清理） |
| `skipped.txt` | interactive 模式下被跳过的写操作记录 |

---

## 关于 cc 标识（测试数据清理）

探索过程中，如果 Claude 需要测试"新建"操作，会在所有创建的内容名称中加入 `cc` 标识（如 `cc_test_ns`、`探索测试-cc`），并在 `cc-created.txt` 中记录。

探索完成后，请**手动到网站删除这些测试内容**。

---

## 常见问题

**Q：探索中途卡住了怎么办？**
检查是否停在需要登录的页面或遇到弹窗。可截图查看当前状态，然后手动操作后告诉 Claude「继续」。

**Q：生成的文档内容不完整？**
可能是页数限制导致部分功能未覆盖。查看 `user-manual.md` 末尾的"未覆盖区域"一节，增加 `--pages=N` 重新运行。

**Q：探索速度太慢？**
内部系统可用 `--preset=normal` 或 `--preset=fast`。

**Q：只想要文档，不需要截图？**
加 `--no-screenshots` 参数，探索速度明显加快。

**Q：探索完成后如何更新文档？**
目前不支持增量更新，需重新运行整个 `/site-explorer` 命令。

**Q：Windows 上运行正常吗？**
是的，Windows 环境下 site-explorer 自动使用 Playwright MCP 代替 gstack 浏览器工具，功能完全等价。

---

## 执行流程概览

```
Phase 0  认证检测
  └─ 已登录 → 直接进入
  └─ 需登录 → 提示用户，等「继续」

Phase 1  结构爬取（BFS 遍历）
  └─ 每页：导航 → 截图 → 提取链接 → 记录摘要
  └─ 输出：raw-data.json

Phase 2  精细交互（AI 选取核心路由）
  └─ 每路由：展开下拉/Tab/Modal → 截图
  └─ 遇写操作：按 write-mode 规则处理
  └─ 输出：features.json

Phase 3  文档合成
  └─ 输出：feature-design.md + user-manual.md
```
