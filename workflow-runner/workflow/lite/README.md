# Sprint 交付 Workflow 套件

一组围绕 **Jira + GitHub + OpenCode（AI 编码代理）** 的端到端 Sprint 交付流水线，由 workflow-runner 驱动、DeepSeek 执行。

设计原则：

- **lite / deep 分层**：日常单 Task 循环用轻量 `*-lite`（低 token、少 step）；Sprint 级规划与验收用 `*-deep`（保留深度）。
- **大产物落文件**：diff、ticket、评审结果等大件写入 `.ao-output/...`，step 间只传**路径**，不 inline 大块上下文，省 token。
- **确定性动作交脚本**：git / gh / Jira transition / 校验 / 写 result.json 等交给 devops automator 或 PowerShell，不让 LLM "判断"。
- **人工确认靠文件边界 + 参数门**：需要审批的地方拆成独立 workflow，用 `confirm_sync=true` 这类参数门 + `exit 1` 硬失败实现，**不靠 prompt 写"必须暂停"**。
- **默认 `concurrency: 1`**，避免并发 agent 重复吃上下文。

---

## 全链路总览

### Task 链（单张 Jira Task 的生命周期）

```
task-development-lite   →   task-review-lite   →   ┌─ pass ─→  task-merge-close
（开发建 PR）               （评审出结论）           └─ fail ─→  task-fix-review-lite ─┐
                                                                  （返修推送）         │
                                        ▲─────────── 重新 review ──────────────────────┘
```

### Sprint 链（一个 Sprint 的规划到验收）

```
sprint-plan-review-deep  →  [人工批准]  →  sprint-jira-dryrun  →  [人工核对]  →  sprint-jira-apply (confirm_sync=true)  →  sprint-adr-persist
（规划 + 审批包）                          （同步预案，零写入）                   （唯一写 Jira）                            （ADR 落库）

                                          ... Sprint 全部 Task 合并后 ...
                                          sprint-review-deep（整体验收，写回 Jira）
```

---

## Workflow 清单

| 文件 | 层级 | 用途 | max_tokens | 步骤数 |
|---|---|---|---|---|
| `task-development-lite.yaml` | lite | 单 Task 开发建 PR | 2048 | 8 |
| `task-review-lite.yaml` | lite | 单 PR 评审出结论 | 2048 | 5 |
| `task-fix-review-lite.yaml` | lite | 按评审结果返修 | 2048 | 7 |
| `task-merge-close.yaml` | — | 评审通过后合并关单 | 1536 | 2 |
| `sprint-plan-review-deep.yaml` | deep | Sprint 规划 + 审批包 | 4096 | 4 |
| `sprint-jira-dryrun.yaml` | — | Jira 同步预案（只读） | 2048 | 1 |
| `sprint-jira-apply.yaml` | — | 幂等写入 Jira（参数门） | 2048 | 3 |
| `sprint-adr-persist.yaml` | — | ADR 落库 `docs/adr/` | 2048 | 1 |
| `sprint-review-deep.yaml` | deep | Sprint 整体验收 | 3072 | 4 |

全部 `concurrency: 1`、`provider: deepseek` / `model: deepseek-chat`、`agents_dir: agents/agency-agents-zh`。

---

## 各 Workflow 详解

### task-development-lite

OpenCode 执行单张 Jira Task 的标准开发循环，**支持重跑**（分支/PR 已存在则复用）。

- **关键 inputs**：`jira_id`（必填）、`repo`（默认 `jadephong/BasePortal`）、`cloud_id`
- **Step graph**：
  ```
  mark_in_progress → setup_branch → read_ticket → implement
    → test_and_verify → commit → open_pr → mark_resolved
  ```
- **要点**：`setup_branch` / `open_pr` 幂等；`test_and_verify` 合并了原 dev_test + qa + verify；`open_pr` 内含 rebase onto main。
- **产物**：`.ao-output/task-<jira_id>/`（ticket.json、impl-summary.md、verify_result.md）

### task-review-lite

一 Task 一 PR 后触发的评审。安全交 Snyk weekly scan、代码异味/复杂度交 SonarQube，本流程不重复。

- **关键 inputs**：`story_key`、`pr_url`、`repo`、`sonar_project_key`（必填）、`max_rounds`（默认 **3**）、`context_mode` / `last_reviewed_sha`（增量评审）
- **Step graph**：
  ```
  mark_in_review → gather_context → review_once → write_back → validate_output
  ```
- **要点**：`review_once` 单步内含 **DoD 门 + Large PR 升级 + AC/Spec/逻辑/测试/性能**，diff 只读一次；`write_back` 确定性回写 GitHub 评论 + Jira 流转。
- **产物**：`.ao-output/review-<story_key>/`（diff.patch、review-context.json、final_review-round<N>.md、**review-result.json**）

### task-fix-review-lite

按 `review-result.json` 的 `blocking_findings` / `non_blocking_findings`（🟡 也算 fail）返修，推送到已有 PR 分支，不新建 PR。

- **关键 inputs**：`jira_id`、`review_result_path`、`repo`、`cloud_id`
- **Step graph**：
  ```
  resume_branch → read_fix_context → implement_fix → test_and_verify
    → commit → push_update → produce_result
  ```
- **要点**：Jira 流转由 n8n 读 `fix-result.json` 的 `jira_transition_to` 执行。
- **产物**：`.ao-output/task-<jira_id>/`（fix-context.json、verify_result.md、**fix-result.json**）

### task-merge-close

评审通过后合并 PR 并关单。

- **关键 inputs**：`jira_id`、`pr_url`、`repo`、`merge_method`（默认 squash）、`allow_missing_review_result`（默认 **false**）
- **Step graph**：
  ```
  preflight → merge_and_close
  ```
- **门控**：`preflight` 第一道门检查 `review-result.json`：
  - `status=pass` → 放行
  - 存在但 `status≠pass` → `exit 1` 禁止合并
  - 不存在且 `allow_missing_review_result=false` → `exit 1`
  - 不存在且 `=true` → 回退 gh `reviewDecision=APPROVED` 判定
- **产物**：`.ao-output/task-<jira_id>/close-material.json`

### sprint-plan-review-deep

Sprint 规划，**非交互**（一次性输出推荐决策 + 待确认问题清单 + 默认值，不卡住等用户）。本流程自然结束即审批暂停点，**零 Jira 写入**。

- **关键 inputs**：`sprint_name`、`run_dir`（默认 `.ao-output/<sprint_name>`）、`sprint_goal`（必填）、`backlog`、`tech_context`、`capacity`、`prev_sprint_review`
- **Step graph**：
  ```
  align_and_plan → story_detail → story_spec → review_gate
  （PM 对齐拆解）  （PM 逐 Story PRD）（架构师补技术字段）（质检+ADR草案+审批包）
  ```
- **产物（均在 `run_dir/`）**：sprint-backlog.md、stories/*.md、stories/INDEX.md、tech_conventions.md、**approval_bundle.md**

### sprint-jira-dryrun

审批后第一步：只生成同步预案，**绝不写 Jira**。幂等查重（label + 临时 ID）。

- **关键 inputs**：`sprint_name`、`run_dir`、`jira_project`（必填）、`approved_plan_path`、`cloud_id`
- **Step graph**：`jira_dryrun`（单步）
- **产物**：`run_dir/jira_dryrun.md`、`run_dir/jira_sync_candidates.json`

### sprint-jira-apply

**唯一允许写 Jira 的工作流**。仅当 `confirm_sync=true` 才执行。

- **关键 inputs**：`sprint_name`、`run_dir`、`jira_project`、`candidates_json_path`、`approved_plan_path`、**`confirm_sync`（必填，默认 false）**
- **Step graph**：
  ```
  confirm_gate → jira_apply → sync_verify
  ```
- **参数门**：`confirm_gate` 是确定性 PowerShell——`confirm_sync != "true"` 或候选文件不可解析时 `exit 1` 硬失败，`jira_apply` 不会运行。
- **写入规则**：先建/复用 Epic，每个 Story `parent` 指向 Epic，Tech Spec **全文写入 description**（禁附件/外链）。
- **产物**：`run_dir/jira_apply_result.json`、`run_dir/sync_verify.json`

### sprint-adr-persist

与 Jira 写入解耦：把已批准的 ADR 草案落库 `docs/adr/`，用 `sync_verify.json` 的真实 Issue Key 回填关联，状态置 Accepted。

- **关键 inputs**：`sprint_name`、`run_dir`、`approved_plan_path`、`sync_verify_path`（默认 `run_dir/sync_verify.json`）
- **Step graph**：`persist_decisions`（单步）
- **产物**：`docs/adr/ADR-<编号>-<标题>.md`

### sprint-review-deep

Sprint 全部 Task 合并后的整体验收（区别于按单 PR 的 task-review）。

- **关键 inputs**：`sprint_name`、`run_dir`、`jira_project`、`sprint_goal`（必填）、`repo`、`cloud_id`
- **Step graph**：
  ```
  collect_sprint → completion_and_integration → regression_check → sprint_acceptance
  ```
- **要点**：`sprint_acceptance` 写回 Jira（Epic 评论：判定/目标达成/阻塞项/carryover）。
- **产物（均在 `run_dir/`）**：inventory.json、completion-integration.md、regression.md、**acceptance_report.md**

---

## 运行顺序与手动接力点

### 跑一个 Sprint（4 段手动接力）

```bash
# 1. 规划 → 产出 approval_bundle.md，人工 Review
run sprint-plan-review-deep  sprint_name=Sprint-7 sprint_goal="..." run_dir=.ao-output/Sprint-7

# 2. 批准后预览 Jira 同步（零写入），人工核对 candidates
run sprint-jira-dryrun  sprint_name=Sprint-7 jira_project=BP approved_plan_path=.ao-output/Sprint-7

# 3. 核对无误后真正写入 Jira —— 必须显式传 confirm_sync=true
run sprint-jira-apply  sprint_name=Sprint-7 jira_project=BP \
    candidates_json_path=.ao-output/Sprint-7/jira_sync_candidates.json \
    approved_plan_path=.ao-output/Sprint-7 confirm_sync=true

# 4. ADR 落库
run sprint-adr-persist  sprint_name=Sprint-7 approved_plan_path=.ao-output/Sprint-7
```

### 跑一张 Task

```bash
run task-development-lite  jira_id=BP-50
run task-review-lite       story_key=BP-50 pr_url=<PR> sonar_project_key=baseportal
# pass → task-merge-close jira_id=BP-50 pr_url=<PR>
# fail → task-fix-review-lite jira_id=BP-50 → 重新 review
```

### Sprint 收尾

```bash
run sprint-review-deep  sprint_name=Sprint-7 jira_project=BP sprint_goal="..."
```

---

## 关键约定

| 约定 | 说明 |
|---|---|
| **`run_dir`** | 所有 sprint workflow 共享的稳定产物根目录，默认 `.ao-output/<sprint_name>`。各段必须传同一个 `run_dir` 串起整条链。 |
| **`review-result.json`** | task-review-lite 的结构化结论，字段含 `status`、`blocking_findings`、`non_blocking_findings`、`jira_transition_to`。是 n8n 编排层与 task-merge-close 的唯一结果来源。 |
| **确定性门 `exit 1`** | `sprint-jira-apply` 的 confirm_gate、`task-merge-close` 的 review 结果门都用脚本 `exit 1` 硬失败。**依赖 runner 把非零退出码当 workflow 失败并中断 depends_on 链**——需确认 runner 行为。 |
| **Jira 流转职责** | task-review-lite 的 `write_back` 自己流转；task-fix-review-lite 交 n8n 读 `fix-result.json` 执行。 |
| **模板** | 产物遵循 `templates/` 下对应模板（相对路径，runner base = 本目录）。 |
| **外部工具** | 安全 = Snyk weekly scan；代码异味/复杂度/Quality Gate = SonarQube（task-review-lite 需传 `sonar_project_key`）。 |
| **Bot 身份** | developer / reviewer 两个 GitHub App 发 PR/评论/合并，详见下方「GitHub App Bot 身份」章节；私钥放 `.secrets/*.pem`。 |

---

## GitHub App Bot 身份

四个 task workflow 用两个 GitHub App 以 **bot 身份** 发 PR / 评论 / 合并，让"开发"和"评审"动作在 GitHub 上有清晰可辨的来源（显示为 `xxx[bot]`）。

| Workflow | 步骤 | Bot | 动作 |
|---|---|---|---|
| `task-development-lite` | `open_pr` | **jp-developer-bot** | 建/更新 PR + "请 review" 评论 |
| `task-fix-review-lite` | `push_update` | **jp-developer-bot** | "已返修，请重新 review" 评论 |
| `task-review-lite` | `write_back` | **jp-reviewer-bot** | 评审结论 PR 评论 |
| `task-merge-close` | `merge_and_close` | **jp-reviewer-bot** | 合并 PR + 关单评论 |

### 凭据（已作为 workflow inputs 默认值）

| Bot | App ID | Installation ID | private key 路径 |
|---|---|---|---|
| jp-developer-bot | `3954083` | `137794452` | `.secrets/jp-developer-bot.pem` |
| jp-reviewer-bot | `3954150` | `137794369` | `.secrets/jp-reviewer-bot.pem` |

App ID / Installation ID 已写进各 workflow 的 `bot_app_id` / `bot_installation_id` 默认值，正常调用无需传参。

### 取 token 脚本（两平台等价）

`scripts/` 下两个等价脚本，把 `app_id + installation_id + pem` 换成 installation access token 打到 stdout：

| 脚本 | 平台 | 依赖 | 参数形式 |
|---|---|---|---|
| `gh-app-token.ps1` | Windows | PowerShell 7+（`RSA.ImportFromPem`） | `-AppId -InstallationId -PemPath` |
| `gh-app-token.sh` | Linux/macOS | `openssl` + `curl` | 位置参数 `<app_id> <installation_id> <pem_path>` |

机制：脚本用 private key 签 RS256 JWT → 调 `/app/installations/<id>/access_tokens` 换 token。workflow 步骤里把它赋给 `GH_TOKEN`，后续 `gh` 命令即以该 bot 身份执行，token 仅在该步生效。

```bash
# Linux/macOS
export GH_TOKEN=$(bash scripts/gh-app-token.sh 3954083 137794452 .secrets/jp-developer-bot.pem)
gh pr comment 12 --repo jadephong/BasePortal --body "..."
```
```powershell
# Windows
$env:GH_TOKEN = & pwsh scripts/gh-app-token.ps1 -AppId 3954083 -InstallationId 137794452 -PemPath .secrets/jp-developer-bot.pem
gh pr comment 12 --repo jadephong/BasePortal --body "..."
```

### 首次配置清单（必做）

1. **下载 private key**：到各 App 设置页 `Generate a private key`，下载 .pem，放到上表路径。
2. **`.gitignore` 排除 `.secrets/`**：私钥绝不能进仓库。
3. **配置 App 权限**（Permissions 页，改后需在 Installation 处 Accept 新权限）：
   - jp-developer-bot：Pull requests = **Read & write**
   - jp-reviewer-bot：Pull requests = **Read & write** + Contents = **Read & write**（合并需要 Contents 写权限）
4. **运行环境依赖**：
   - Windows：`pwsh -v` 确认 PowerShell 7+（5.1 不支持 `RSA.ImportFromPem`）。
   - Linux/macOS：`openssl`、`curl` 一般自带；不需要 jq。
5. **`.sh` 换行符**：若脚本在 Windows 侧编辑后拿到 Ubuntu，先 `sed -i 's/\r$//' scripts/gh-app-token.sh` 去掉 CRLF，否则 `bash` 报 `\r` 错。

### 注意

- `git push` 仍用宿主 git 凭证，**commit author 不变**；只有 PR/评论/合并是 bot 身份。
- reviewer bot 合并 PR 需要 Contents 写权限，否则 `gh pr merge` 会 403。

---

## 被替代的旧 workflow

以下旧文件已被本套件取代，保留作对照，确认后可删除：

| 旧文件 | 替代为 |
|---|---|
| `task-development.yaml` | `task-development-lite.yaml` |
| `task-review.yaml` | `task-review-lite.yaml` |
| `task-fix-review.yaml` | `task-fix-review-lite.yaml` |
| `sprint-plan-review.yaml` | `sprint-plan-review-deep.yaml` |
| `sprint-jira-sync.yaml` | `sprint-jira-dryrun.yaml` + `sprint-jira-apply.yaml` + `sprint-adr-persist.yaml` |
| `sprint-review.yaml` | `sprint-review-deep.yaml` |

（`task-merge-close.yaml` 为原地重写，非新增。）
