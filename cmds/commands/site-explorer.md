# site-explorer

Auto-explore a website, map its features, and generate feature-design.md + user-manual.md.

Usage: /site-explorer <url> [--mode=sample|full] [--pages=N] [--timeout=Nmin]
       [--auth=browser|<file>] [--output=<dir>] [--lang=zh|en]
       [--preset=polite|normal|fast] [--delay=Ns] [--jitter=Ns] [--rps=N]
       [--no-screenshots] [--respectrobots=yes|no]
       [--write-mode=off|interactive]

Write-mode options:
  off          (default) CREATE adds -cc suffix and logs; MODIFY/DELETE are skipped
  interactive  Pause before every write op; user fills values, provides a screenshot, or cancels

## Preamble (run first)

```bash
ARGS="$ARGUMENTS"

TARGET_URL=$(echo "$ARGS" | grep -oE 'https?://[^ ]+' | head -1)
get_flag() { echo "$ARGS" | sed -n "s/.*--${1}=\([^ ]*\).*/\1/p" | head -1; }

MODE=$(get_flag mode);    MODE=${MODE:-sample}
PAGES=$(get_flag pages);  PAGES=${PAGES:-20}
TIMEOUT=$(get_flag timeout); TIMEOUT=${TIMEOUT:-10}
DEPTH=$(get_flag depth);  DEPTH=${DEPTH:-3}
AUTH=$(get_flag auth);    AUTH=${AUTH:-}
OUTPUT=$(get_flag output); OUTPUT=${OUTPUT:-./site-explorer-output}
LANG=$(get_flag lang);    LANG=${LANG:-zh}
PRESET=$(get_flag preset); PRESET=${PRESET:-polite}
NO_SCREENSHOTS=$(echo "$ARGS" | grep -c '\-\-no-screenshots' 2>/dev/null || echo 0)
RESPECT_ROBOTS=$(get_flag respectrobots); RESPECT_ROBOTS=${RESPECT_ROBOTS:-yes}
WRITE_MODE=$(get_flag write-mode);   WRITE_MODE=${WRITE_MODE:-off}

case $PRESET in
  polite) DELAY=3; JITTER=1; RPS="0.3" ;;
  normal) DELAY=2; JITTER=1; RPS="0.5" ;;
  fast)   DELAY=1; JITTER=0; RPS="1.0" ;;
  *)      DELAY=3; JITTER=1; RPS="0.3" ;;
esac
_d=$(get_flag delay);  [ -n "$_d" ] && DELAY=$_d
_j=$(get_flag jitter); [ -n "$_j" ] && JITTER=$_j
_r=$(echo "$ARGS" | sed -n 's/.*--rps=\([0-9.]*\).*/\1/p' | head -1)
[ -n "$_r" ] && RPS=$_r

if [ -z "$TARGET_URL" ]; then
  echo "ERROR: URL is required."
  exit 1
fi

DOMAIN=$(echo "$TARGET_URL" | grep -oE '://[^/?]+' | sed 's|://||;s/^www\.//')
RUN_DATE=$(date +%Y-%m-%d)
OUT_DIR="${OUTPUT}/site-explorer-${DOMAIN}-${RUN_DATE}"
mkdir -p "${OUT_DIR}/screenshots"

B="${GSTACK_B:-$HOME/.claude/skills/gstack/browse/dist/browse}"

echo "[site-explorer] Target : $TARGET_URL"
echo "[site-explorer] Mode   : $MODE | Pages: $PAGES | Timeout: ${TIMEOUT}min"
echo "[site-explorer] Output : $OUT_DIR"
echo "[site-explorer] Rate   : ${DELAY}s ± ${JITTER}s | RPS: $RPS"
echo "[site-explorer] Writes : $WRITE_MODE"
```

## Phase 0: Authentication

```bash
echo "[site-explorer] Phase 0: 检测认证状态..."
"$B" goto "$TARGET_URL"
PAGE_URL=$("$B" url 2>/dev/null || echo "")
PAGE_TEXT=$("$B" text 2>/dev/null | head -c 500 || echo "")
echo "LANDED_URL: $PAGE_URL"
```

Analyze `PAGE_URL` and `PAGE_TEXT`:

**Login wall detected** if URL contains `/login`, `/signin`, `/auth`, `/sso`
OR text contains "log in", "sign in", "登录", "请登录":

- If `$AUTH` = `browser`:
  ```bash
  echo "[site-explorer] Phase 0: 从本地 Chrome 导入 Cookie..."
  DOMAIN_FOR_IMPORT=$(echo "$TARGET_URL" | grep -oE '://[^/?]+' | sed 's|://||')
  "$B" cookie-import-browser --domain "$DOMAIN_FOR_IMPORT"
  "$B" goto "$TARGET_URL"
  sleep 2
  echo "[site-explorer] Phase 0: ✓ Cookie 注入完成"
  ```

- If `$AUTH` is a file path (non-empty, not "browser"):
  ```bash
  echo "[site-explorer] Phase 0: 从 Cookie 文件导入: $AUTH"
  "$B" cookie-import "$AUTH"
  "$B" goto "$TARGET_URL"
  sleep 2
  echo "[site-explorer] Phase 0: ✓ Cookie 注入完成"
  ```

- If `$AUTH` is empty:
  ```bash
  echo "[site-explorer] Phase 0: 需要手动登录，启动可见浏览器..."
  "$B" handoff "请在浏览器中完成登录后，回到 Claude Code 输入「继续」"
  ```
  Wait for user to type "继续" before proceeding to Phase 1.

**No login wall:**
```bash
echo "[site-explorer] Phase 0: ✓ 已认证，直接进入爬取"
```

## Phase 1: Structure Crawl

```bash
echo "[site-explorer] Phase 1: 开始结构爬取..."
START_TIME=$(date +%s)
VISITED_FILE="${OUT_DIR}/visited.txt"
FRONTIER_FILE="${OUT_DIR}/frontier.txt"
RAW_DATA_FILE="${OUT_DIR}/raw-data.json"
PAGE_COUNT=0

touch "$VISITED_FILE"
echo "$TARGET_URL" > "$FRONTIER_FILE"
echo '{"pages":[],"link_graph":{},"unvisited":[]}' > "$RAW_DATA_FILE"

if [ "$RESPECT_ROBOTS" = "yes" ]; then
  "$B" goto "${TARGET_URL%/}/robots.txt" 2>/dev/null
  DISALLOW_FILE="${OUT_DIR}/robots-disallow.txt"
  "$B" text 2>/dev/null | grep -iE '^Disallow:' | awk '{print $2}' > "$DISALLOW_FILE" || true
  echo "[site-explorer] Phase 1: robots.txt 解析完成 ($(wc -l < "$DISALLOW_FILE" | tr -d ' ') 条规则)"
fi

jitter_sleep() {
  local base=$1 j=$2
  local extra=$(( RANDOM % (j * 2 + 1) - j ))
  local t=$(( base + extra ))
  [ "$t" -lt 1 ] && t=1
  sleep "$t"
}
```

Execute BFS loop until `$PAGE_COUNT >= $PAGES` or elapsed >= `$TIMEOUT` minutes.

For each iteration, pick next unvisited URL from `$FRONTIER_FILE`. Skip if already visited, not same domain as `$DOMAIN`, or path matches a Disallow pattern. Then:

```bash
echo "[site-explorer] Phase 1: 爬取中 ($((PAGE_COUNT+1))/$PAGES 页) — $CURRENT_URL"

"$B" goto "$CURRENT_URL"
jitter_sleep $DELAY $JITTER

if [ "$NO_SCREENSHOTS" = "0" ]; then
  SLUG=$(echo "$CURRENT_URL" | grep -oE '[^/?=]+$' | head -c 30 || echo "page")
  SHOT="${OUT_DIR}/screenshots/$(printf '%02d' $PAGE_COUNT)-${SLUG}.png"
  "$B" screenshot "$SHOT" 2>/dev/null || true
fi
sleep 0.5

LINKS=$("$B" links 2>/dev/null | grep -oE "https?://${DOMAIN}[^ \"'<>]*" | sort -u | head -50 || echo "")
sleep 0.5

TITLE=$("$B" title 2>/dev/null || echo "")
SUMMARY=$("$B" text 2>/dev/null | head -c 800 || echo "")

echo "$LINKS" | while IFS= read -r link; do
  [ -z "$link" ] && continue
  grep -qF "$link" "$VISITED_FILE" 2>/dev/null || echo "$link" >> "$FRONTIER_FILE"
done

echo "$CURRENT_URL" >> "$VISITED_FILE"
PAGE_COUNT=$((PAGE_COUNT + 1))
```

Append page data to `raw-data.json` after each page using the Write tool or python3, updating `pages` array and `link_graph` map. After the loop finishes, record remaining unvisited URLs:

```bash
comm -23 <(sort "$FRONTIER_FILE") <(sort "$VISITED_FILE") | head -50 >> "${OUT_DIR}/raw-data.json" || true
echo "[site-explorer] Phase 1: ✓ 完成，共 $PAGE_COUNT 页"
```

## Phase 2: Selective Deep Dive

```bash
echo "[site-explorer] Phase 2: 分析功能模块，选取核心路由..."
FEATURES_FILE="${OUT_DIR}/features.json"
CC_LOG="${OUT_DIR}/cc-created.txt"
SHOT_IDX=$(ls "${OUT_DIR}/screenshots/"*.png 2>/dev/null | wc -l | tr -d ' ' || echo 0)
touch "$CC_LOG"
```

Read `$RAW_DATA_FILE`. Identify distinct functional modules. Select 5-10 routes with highest information value.

For each selected route:

```bash
"$B" goto "<selected_url>"
jitter_sleep $DELAY $JITTER
"$B" snapshot
```

Classify each interactive element and act according to the rules for `$WRITE_MODE`:

---

### WRITE_MODE = off (default)

**READ (navigate/expand/view) — execute directly:**
```bash
"$B" hover <@ref>
sleep 0.3
"$B" click <@ref>
sleep 0.5
SHOT_IDX=$((SHOT_IDX+1))
"$B" screenshot "${OUT_DIR}/screenshots/$(printf '%02d' $SHOT_IDX)-<slug>.png"
```

**CREATE (new record/file) — add -cc suffix, log it:**
```bash
"$B" fill <@ref_name_field> "<描述>-cc"
"$B" fill <@ref_note_field> "由 Claude Code site-explorer 自动创建，可删除 [cc]"
SHOT_IDX=$((SHOT_IDX+1))
"$B" screenshot "${OUT_DIR}/screenshots/$(printf '%02d' $SHOT_IDX)-<slug>-create.png"
"$B" click <@ref_submit>
echo "<current_url> | <item_type> | <item_name>-cc" >> "$CC_LOG"
```

**MODIFY or DELETE — forbidden, screenshot UI only:**
```bash
SHOT_IDX=$((SHOT_IDX+1))
"$B" screenshot "${OUT_DIR}/screenshots/$(printf '%02d' $SHOT_IDX)-<slug>-edit-ui.png"
```

**SUBMIT affecting existing data — skip entirely.**

---

### WRITE_MODE = interactive

**READ operations** are always executed directly without pausing.

**CREATE, MODIFY, DELETE, or non-trivial SUBMIT** — pause and ask the user.

**Step 1:** Take a screenshot of the current state, then present to the user:

```
[site-explorer] ⏸  遇到写操作，等待您的指示
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  页面  : <current_url>
  操作  : <CREATE | MODIFY | DELETE>
  元素  : <button/link label that triggered this>
  表单字段（如有）:
    · <字段名1>（<类型>，<必填?>）
    · <字段名2>（<类型>，<必填?>）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  请选择：
  [填值]  逐字段输入，格式：字段名: 值
  [传图]  粘贴截图文件路径，Claude 解析后填写
  [确认]  输入 y — 用默认值（CREATE 自动加 -cc 后缀）
  [取消]  输入 n 或 skip — 跳过此操作
```

**Step 2:** Wait for the user's response. Handle each case:

- **字段值输入**（`字段名: 值`）：按给定值填表，截图展示，等 `y` 确认后提交
- **截图路径**（如 `C:\xxx.png`）：Read tool 读图识别字段值，复现填写，截图展示，等 `y` 确认后提交
- **`y`**：用默认值提交（CREATE 文本字段加 `-cc` 后缀）
- **`n` / `skip`**：跳过，继续探索

**Step 3:** 执行后记录：
```bash
SHOT_IDX=$((SHOT_IDX+1))
"$B" screenshot "${OUT_DIR}/screenshots/$(printf '%02d' $SHOT_IDX)-<slug>-<op>.png"
echo "<current_url> | <op_type> | <item_name>" >> "$CC_LOG"
```

---

After all routes, write `$FEATURES_FILE`:
```json
{
  "modules": [
    {
      "name": "<模块名>",
      "url": "<主要路径>",
      "sub_features": ["<子功能1>", "<子功能2>"],
      "screenshots": ["<file1>.png"],
      "key_actions": ["<操作1>"],
      "notes": ""
    }
  ]
}
```

```bash
echo "[site-explorer] Phase 2: ✓ 交互完成"
```

## Phase 3: Document Synthesis

```bash
echo "[site-explorer] Phase 3: 生成文档中..."
DESIGN_FILE="${OUT_DIR}/feature-design.md"
MANUAL_FILE="${OUT_DIR}/user-manual.md"
```

Read `$FEATURES_FILE` and `$RAW_DATA_FILE`. Use the Write tool to create both files.

**Write `$DESIGN_FILE`** with structure:
```
# <网站名> 功能设计文档
> 生成时间：<RUN_DATE> | 探索页数：<PAGE_COUNT> | 模式：<MODE> | 工具：site-explorer [cc]

## 1. 网站概述
## 2. 用户角色
## 3. 功能模块总览（含截图）
## 4. 核心用户流程
## 5. 导航结构
## 6. 未覆盖区域（含 robots.txt Disallow 路径）
```

**Write `$MANUAL_FILE`** with structure:
```
# <网站名> 用户使用手册
> 生成时间：<RUN_DATE> | 工具：site-explorer [cc]

## 快速开始
## 功能指南（每模块一节，含截图）
## 常见操作速查表
## 注意事项
```

After both files are written:

```bash
echo "[site-explorer] Phase 3: ✓ 文档已生成"
echo "  → $DESIGN_FILE"
echo "  → $MANUAL_FILE"

if [ -s "$CC_LOG" ]; then
  echo ""
  echo "[site-explorer] ⚠️  本次探索共创建/修改以下内容，建议手动清理："
  cat "$CC_LOG"
fi

SKIPPED_FILE="${OUT_DIR}/skipped.txt"
if [ -s "$SKIPPED_FILE" ]; then
  echo ""
  echo "[site-explorer] ℹ️  以下写操作被跳过（interactive 模式）："
  cat "$SKIPPED_FILE"
fi

echo ""
echo "[site-explorer] 完成！输出目录: $OUT_DIR"
```
