# OrchLand SonarCloud 零问题修复计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 OrchLand 项目中所有 188 个开放的 SonarCloud issues，达到零问题状态。

**架构：** 将 HTML 文件的内联 CSS 和 JavaScript 代码分离到独立文件，并按 SonarCloud 规则优先级（CRITICAL > MAJOR > MINOR）逐步修复。使用 git worktree 和 feature 分支确保可追溯性，频繁提交。

**技术栈：** HTML5、CSS3、JavaScript/Node.js、PowerShell、Python、SonarCloud CLI

---

## 问题分布统计

| 文件 | 数量 | 主要规则 |
|-----|------|--------|
| studio/ui/index.html | 88 | S6853(27), S7924(23), S2486(15), S3776(3) |
| Shell/PowerShell 脚本 | 16 | S8657 |
| studio/ui/server-static.js | 6 | 混合 |
| studio/n8n-generator.js | 6 | 混合 |
| n8n/test-orchestrator-logic.js | 6 | S2486, S1534 |
| 其他文件 | 60+ | 混合 |
| **总计** | **188** | |

---

## 阶段 1: HTML/CSS/JavaScript 重构 (88 issues)

### 任务 1: 提取 CSS - 准备工作

**文件：**
- 修改：`studio/ui/index.html:7-150` (提取 <style> 块)
- 创建：`studio/ui/styles/studio.css`

- [ ] **步骤 1：在 studio/ui 下创建 styles 目录**

```bash
cd E:\Workspace\OrchLand
mkdir -p studio\ui\styles
```

- [ ] **步骤 2：创建 studio.css 文件**

从 index.html 的 `<style>` 块中，复制所有 CSS 内容（约 200+ 行）到新文件。

```bash
# 手动操作：
# 1. 打开 studio/ui/index.html
# 2. 复制第 7 行到第 150 行的 CSS 内容（从 <style> 到 </style>）
# 3. 粘贴到 studio/ui/styles/studio.css
# 4. 移除开头的 <style> 和末尾的 </style> 标签
```

示例 studio/ui/styles/studio.css 开头：
```css
:root {
  --ink: #26251f; --muted: #746f64; --paper: #fff8ec; --paper-2: #f4e4d2;
  --sage: #8fb58f; --sage-deep: #3f765f; --teal: #4ca9a4; --amber: #f4b85f;
  --rose: #d98f7f; --blue: #6b9ac4;
  --line: rgba(72,58,43,.16); --glass: rgba(255,248,236,.74);
  --shadow: 0 22px 70px rgba(35,27,17,.26);
  --soft-shadow: 0 12px 34px rgba(61,45,26,.18);
}
[x-cloak] { display:none !important; }
* { box-sizing: border-box; }
html, body { height: 100%; margin: 0; color: var(--ink); font-family: Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; background: #171711; overflow: hidden; }
/* ... 更多 CSS ... */
```

- [ ] **步骤 3：从 index.html 移除 <style> 块**

在 index.html 中，移除第 7-150 行的整个 `<style>...</style>` 块。

- [ ] **步骤 4：在 index.html <head> 中添加 CSS 链接**

在 `</head>` 前添加：
```html
  <link rel="stylesheet" href="./styles/studio.css">
</head>
```

修改后 index.html 的 <head> 部分看起来像：
```html
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>OrchLand Agent Studio</title>
  <link rel="stylesheet" href="./styles/studio.css">
</head>
```

- [ ] **步骤 5：验证文件结构**

```bash
ls -la studio/ui/styles/
# 应该看到 studio.css 文件存在
```

- [ ] **步骤 6：Commit**

```bash
git add studio/ui/styles/studio.css studio/ui/index.html
git commit -m "refactor: extract inline CSS from index.html to styles/studio.css - Move all styles from <style> block to external CSS file - Add stylesheet link to index.html head - No functional changes, CSS extraction only"
```

---

### 任务 2: 提取 JavaScript - 准备工作

**文件：**
- 修改：`studio/ui/index.html` (查找所有 <script> 块)
- 创建：`studio/ui/scripts/studio.js`

- [ ] **步骤 1：在 studio/ui 下创建 scripts 目录**

```bash
mkdir -p studio\ui\scripts
```

- [ ] **步骤 2：查找并列出 index.html 中的所有 <script> 块**

在 index.html 中搜索所有 `<script>` 标签。根据前面的分析，应该有内联 JavaScript 代码。

示例命令：
```bash
grep -n "<script" studio/ui/index.html
```

- [ ] **步骤 3：创建 studio.js 并提取 JavaScript**

创建 `studio/ui/scripts/studio.js` 并将所有内联 JavaScript 代码移入。

示例结构（根据实际 index.html 内容调整）：
```javascript
// Initialize Alpine.js and other global setup
document.addEventListener('DOMContentLoaded', function() {
  // Copy all <script> tag content here
  // Preserve the exact functionality
});
```

- [ ] **步骤 4：从 index.html 移除 <script> 块**

删除所有内联 `<script>...</script>` 块。

- [ ] **步骤 5：在 index.html </body> 前添加 script 标签**

```html
  <script src="./scripts/studio.js"></script>
</body>
```

- [ ] **步骤 6：Commit**

```bash
git add studio/ui/scripts/studio.js studio/ui/index.html
git commit -m "refactor: extract inline JavaScript from index.html to scripts/studio.js - Move all script content to external JS file - Add script link before closing body tag - Preserve all functionality"
```

---

### 任务 3: 修复 HTML 属性问题 (Web:S6853 - 27 issues)

**文件：**
- 修改：`studio/ui/index.html`

这个规则通常关于：
- 属性值引号问题
- HTML 属性格式问题
- 无效的属性组合

- [ ] **步骤 1：获取具体问题清单**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&rule=Web:S6853&statuses=OPEN" | \
  jq '.issues[] | {line: .line, message: .message}' > /tmp/s6853-issues.json
```

- [ ] **步骤 2：查看前 5 个问题**

```bash
cat /tmp/s6853-issues.json | head -20
```

根据问题信息，修复 index.html 中的属性问题。常见修复：

1. **确保所有属性值都带引号**：
```html
<!-- ❌ 错误 -->
<div class = "container" id = app></div>

<!-- ✅ 正确 -->
<div class="container" id="app"></div>
```

2. **修复属性间的空格**：
```html
<!-- ❌ 错误 -->
<div class = "container" id = "app">

<!-- ✅ 正确 -->
<div class="container" id="app">
```

- [ ] **步骤 3：手动或用脚本修复所有 HTML 属性**

```bash
# PowerShell 脚本修复缝隙
powershell << 'PSHEOF'
$file = "E:\Workspace\OrchLand\studio\ui\index.html"
$content = Get-Content $file -Raw

# 修复: class = "x" → class="x"
$content = $content -replace '\s*=\s*"', '="'
$content = $content -replace '\s*=\s*\'', '=\''

Set-Content $file $content -Force
Write-Host "✅ HTML attributes fixed"
PSHEOF
```

- [ ] **步骤 4：验证修复**

```bash
# 检查没有奇怪的空格在属性赋值中
grep -n " = " studio/ui/index.html | head -20
```

应该返回空或很少的结果。

- [ ] **步骤 5：Commit**

```bash
git add studio/ui/index.html
git commit -m "fix(S6853): normalize HTML attributes in index.html - Remove spaces around = in attribute assignments - Ensure all attribute values are properly quoted - Fix 27 Web:S6853 issues"
```

---

### 任务 4: 修复 CSS 问题 (css:S7924 - 23 issues)

**文件：**
- 修改：`studio/ui/styles/studio.css`

S7924 通常关于 CSS 的：
- 颜色值格式
- 单位格式
- CSS 属性用法问题

- [ ] **步骤 1：获取 S7924 问题列表**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&rule=css:S7924&statuses=OPEN" | \
  jq '.issues[] | {line: .line, message: .message}' > /tmp/s7924-issues.json
```

- [ ] **步骤 2：分析问题类型**

```bash
cat /tmp/s7924-issues.json | head -30
```

根据消息内容，通常的修复包括：

1. **修复颜色值格式**：
```css
/* ❌ 错误 */
color: RGB(255, 0, 0);
background: hsl(0, 100%, 50%);

/* ✅ 正确 */
color: rgb(255, 0, 0);
background: hsl(0 100% 50%);
```

2. **修复渐变语法**：
```css
/* ❌ 旧语法 */
background: linear-gradient(90deg, #fff, #000);

/* ✅ 正确 */
background: linear-gradient(to right, #fff, #000);
```

- [ ] **步骤 3：应用 CSS 修复**

依据具体的 S7924 问题，在 studio/ui/styles/studio.css 中应用修复。这可能涉及：
- 标准化颜色格式
- 修复渐变函数
- 规范化 CSS 属性值

示例修复脚本：
```bash
powershell << 'PSHEOF'
$file = "E:\Workspace\OrchLand\studio\ui\styles\studio.css"
$content = Get-Content $file -Raw

# 标准化 rgb/hsl 函数（大小写）
$content = $content -replace 'RGB\(', 'rgb('
$content = $content -replace 'HSL\(', 'hsl('
$content = $content -replace 'RGBA\(', 'rgba('
$content = $content -replace 'HSLA\(', 'hsla('

Set-Content $file $content -Force
Write-Host "✅ CSS fixed"
PSHEOF
```

- [ ] **步骤 4：验证没有语法错误**

```bash
# 简单的 CSS 语法检查
grep -n "RGB\|HSL" studio/ui/styles/studio.css
```

应该返回空。

- [ ] **步骤 5：Commit**

```bash
git add studio/ui/styles/studio.css
git commit -m "fix(S7924): normalize CSS syntax and values - Standardize color function formats (rgb, hsl, rgba, hsla) - Fix CSS property value formats - Fix 23 css:S7924 issues"
```

---

### 任务 5: 修复 JavaScript 异常处理 (javascript:S2486 - 15 issues)

**文件：**
- 修改：`studio/ui/scripts/studio.js`（或 index.html 中的 <script> 块)

S2486 规则：**异常处理 - "Handle this exception or don't catch it at all"**

这意味着存在空 try-catch 块或只记录而没有处理异常的 catch 块。

- [ ] **步骤 1：获取 S2486 问题列表**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&rule=javascript:S2486&statuses=OPEN&pageSize=500" | \
  jq '.issues[] | select(.component | contains("studio/ui")) | {line: .line, message: .message, component: .component}' > /tmp/s2486-issues.json
```

- [ ] **步骤 2：分析问题**

```bash
cat /tmp/s2486-issues.json | head -30
```

找出所有的空 catch 块或不处理异常的情况。

- [ ] **步骤 3：修复异常处理**

在 studio/ui/scripts/studio.js 或 index.html 中找到这些模式并修复：

```javascript
// ❌ 错误 - 空 catch 块
try {
  someFunction();
} catch (e) {
  // 什么都不做
}

// ✅ 正确选项 1 - 有意忽略但要说明
try {
  someFunction();
} catch (e) {
  // 此异常可以安全忽略 - 逻辑描述
  console.debug('Expected error:', e);
}

// ✅ 正确选项 2 - 删除不必要的 try-catch
someFunction();

// ✅ 正确选项 3 - 有意义的错误处理
try {
  someFunction();
} catch (e) {
  console.error('Failed to execute:', e);
  handleError(e);
}
```

- [ ] **步骤 4：应用修复**

根据每个具体的异常处理问题应用适当的修复。

- [ ] **步骤 5：Commit**

```bash
git add studio/ui/scripts/studio.js studio/ui/index.html
git commit -m "fix(S2486): add proper exception handling in JavaScript - Add meaningful error handling or remove unnecessary try-catch blocks - Add console logging for expected exceptions - Fix 15 javascript:S2486 issues"
```

---

### 任务 6: 修复 JavaScript 认知复杂度 (javascript:S3776 - 3 issues)

**文件：**
- 修改：`studio/ui/scripts/studio.js` 或 `studio/ui/index.html:scripts`

S3776：认知复杂度过高。

- [ ] **步骤 1：查找复杂函数**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&rule=javascript:S3776&statuses=OPEN" | \
  jq '.issues[] | select(.component | contains("studio/ui")) | {line: .line, message: .message}' > /tmp/s3776-issues.json
```

- [ ] **步骤 2：分析函数复杂度**

找出这 3 个函数，分析它们的嵌套 if/switch 结构。

- [ ] **步骤 3：重构为更简单的结构**

使用：
- 早期返回（guard clauses）
- 提取函数
- 对象映射替代 switch/if 链

示例：
```javascript
// ❌ 高复杂度
function process(type, status) {
  if (type === 'A') {
    if (status === '1') {
      // 10 行代码
    } else if (status === '2') {
      // 10 行代码
    } else {
      // ...
    }
  } else if (type === 'B') {
    // 更多嵌套
  }
}

// ✅ 低复杂度
const handlers = {
  'A:1': () => { /* 10 行 */ },
  'A:2': () => { /* 10 行 */ },
  'B:1': () => { /* ... */ }
};

function process(type, status) {
  const handler = handlers[`${type}:${status}`];
  if (!handler) throw new Error('Invalid combination');
  return handler();
}
```

- [ ] **步骤 4：验证重构**

确保函数逻辑完全相同，只是结构更简洁。

- [ ] **步骤 5：Commit**

```bash
git add studio/ui/scripts/studio.js
git commit -m "refactor(S3776): reduce cognitive complexity in JavaScript functions - Extract nested logic to separate functions - Use object maps instead of if-else chains - Fix 3 javascript:S3776 issues"
```

---

## 阶段 2: 其他文件修复 (100 issues)

### 任务 7: 修复 studio/ui/server-static.js (6 issues)

**文件：**
- 修改：`studio/ui/server-static.js`

- [ ] **步骤 1：获取所有问题**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&statuses=OPEN&pageSize=500" | \
  jq '.issues[] | select(.component | contains("server-static.js")) | {rule: .rule, line: .line, message: .message}' > /tmp/server-static-issues.json
```

- [ ] **步骤 2：读取文件并分析**

```bash
head -100 studio/ui/server-static.js
```

- [ ] **步骤 3：按规则修复**

根据具体的规则应用修复（S2486、S1481 等）。

- [ ] **步骤 4：Commit**

```bash
git add studio/ui/server-static.js
git commit -m "fix: resolve 6 SonarCloud issues in server-static.js"
```

---

### 任务 8: 修复 studio/n8n-generator.js (6 issues)

**文件：**
- 修改：`studio/n8n-generator.js`

重复任务 7 的步骤，目标文件改为 n8n-generator.js。

---

### 任务 9: 修复 n8n/test-orchestrator-logic.js (6 issues)

**文件：**
- 修改：`n8n/test-orchestrator-logic.js`

重复任务 7 的步骤，目标文件改为 test-orchestrator-logic.js。

---

### 任务 10: 修复 PowerShell/Shell 脚本 (16+ issues)

**文件：**
- 修改：`scripts/*.sh`、`scripts/*.ps1`、`.github/workflows/*.yml`

- [ ] **步骤 1：获取所有脚本相关问题**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&statuses=OPEN&pageSize=500" | \
  jq '.issues[] | select(.component | contains(".sh") or contains(".ps1") or contains(".yml")) | {component: .component, rule: .rule, line: .line}' | head -40
```

- [ ] **步骤 2：按脚本文件分类**

整理出各个脚本文件的问题。

- [ ] **步骤 3：修复 PowerShell 规则问题 (S8657)**

常见 PowerShell 问题：
- 缺少引号的变量
- 不规范的缩进
- 不安全的脚本执行

- [ ] **步骤 4：修复 Shell 脚本问题**

检查 .sh 文件的语法和安全问题。

- [ ] **步骤 5：修复 GitHub Actions 问题 (S8233, S8264)**

检查 .yml 工作流文件。

- [ ] **步骤 6：Commit**

```bash
git add scripts/ .github/workflows/
git commit -m "fix: resolve 16+ SonarCloud issues in shell and PowerShell scripts"
```

---

### 任务 11: 修复 Python 文件 (3-5 issues)

**文件：**
- 修改：`n8n/mock_test_orchestrator.py`、`n8n/test-opencode-config.js`

- [ ] **步骤 1：获取 Python 相关问题**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&statuses=OPEN&pageSize=500" | \
  jq '.issues[] | select(.component | contains(".py")) | {rule: .rule, line: .line, message: .message}' > /tmp/python-issues.json
```

- [ ] **步骤 2：修复 Python 文件**

根据具体问题修复。常见规则：S1481（未使用变量）等。

- [ ] **步骤 3：Commit**

```bash
git add n8n/mock_test_orchestrator.py
git commit -m "fix: resolve SonarCloud issues in Python files"
```

---

### 任务 12: 修复其他 JavaScript/HTML 文件 (60+ issues)

**文件：**
- 修改：所有剩余的问题文件

- [ ] **步骤 1：统计剩余问题**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&statuses=OPEN&pageSize=500" | \
  jq '.issues | length'
```

- [ ] **步骤 2：按文件分批修复**

逐个处理剩余的文件。对每个文件：
1. 获取问题列表
2. 分析问题类型
3. 应用修复
4. 提交

- [ ] **步骤 3：最终验证**

```bash
curl -s -u "12ff18adebc16aa09565c519ba797b125895fbd7:" \
  "https://sonarcloud.io/api/issues/search?componentKeys=jadephong_OrchLand&statuses=OPEN&pageSize=500" | \
  jq '.total'
```

验证返回值为 0。

---

## 验收标准

✅ **所有 188 个 issues 已解决**
✅ **SonarCloud 显示 0 个开放 issues**
✅ **所有修改已提交到 git**
✅ **代码功能保持不变**
✅ **HTML、CSS、JavaScript 代码已分离到独立文件**

---

## 注意事项

- 使用 `git worktree` + feature 分支保持工作隔离
- 每个任务完成后立即 commit，便于追踪
- 测试修复：修改后在浏览器中验证 UI 功能正常
- SonarCloud 分析可能延迟 5-10 分钟才反映新修复

