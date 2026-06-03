# Sprint 交付流水线（规划 → 同步 → 开发 → 评审 → 合并 → 验收）

七个工作流串成一条从需求到 OpenCode 自动实现、再到人工/Claude 把关的闭环。两处**审批硬边界**（同步、合并）都拆成独立工作流、必须人工触发，不靠 LLM 自觉守门；开发、返修与评审按 **Task 粒度**循环；Sprint 收尾再做一次整体验收。

```
① sprint-plan-review     ② sprint-jira-sync       ③ task-development
┌──────────────────┐ 批准 ┌──────────────────┐ 执行 ┌──────────────────┐ 请review
│ 拆 Task + Tech   │────▶ │ Dry-run 查重 →   │清单  │ 切分支 → 读 ticket│────────┐
│ Spec + Spec 校验 │(人工)│ 幂等同步 → 回读  │────▶ │ → 只改范围内文件  │        │
│ → 待审批包(暂停) │      │ → OpenCode 清单  │(OC读 │ → dev+QA 测试 →  │        │
└──────────────────┘      └──────────────────┘ Jira)│ verify → commit  │        │
                                                     │ → 建 PR(暂停)    │        │
                                                     └──────────────────┘        │
                                                                                 ▼
   ⑥ sprint-review            ⑤ task-merge-close          ④ task-review
┌──────────────────┐  全部   ┌──────────────────┐  通过  ┌──────────────────┐
│ 盘点 → 完成度审计│  Task   │ preflight 验    │◀───────│ 拉 PR+AC → DoD → │
│ → 集成接缝 + 回归│  合并后 │ APPROVED → 合并 │        │ 质量/安全/性能 → │
│ → 验收报告       │◀────────│ → Jira Done     │        │ 判定 → 写回 Jira │
└──────────────────┘         │ → 评论四要素     │        └────────┬─────────┘
                             └──────────────────┘        🔁打回↑__↓返修 / ⛔升级
```

③④ 之间按 Task 循环：建 PR → Claude 评审 → 打回则 OpenCode 跑返修流 → 通过则 ⑤ 合并；全部 Task 合并后跑 ⑥ 整体验收。

## PR ↔ Jira 约定

| 约定 | 规则 | 示例 |
|------|------|------|
| 分支命名 | `feature/<JiraKey>`，从最新 main 派生 | `feature/EMT-54` |
| 一 Task 一 PR | 每个 Jira Task 对应独立 PR，隔离评审与打回 | PR#8 ↔ EMT-54 |
| 一次一张 Task | OpenCode 同时只做一张 Task | — |
| commit message | `<JiraKey> <英文动词短句>`（祈使句，源自 Jira Summary） | `EMT-50 Add tenant login rate limiting` |
| 幂等 label | 同步时打 `sprint:<sprint_name>` + `tmpid:<临时ID>`，重跑据此查重 | `sprint:Sprint 1` `tmpid:S1-1` |
| 反馈回流 | 评审结论写回对应 Jira Issue 评论，OpenCode 读 Issue 取返修指令 | — |
| Jira 站点 | `jadephong.atlassian.net`（`cloud_id` 默认值） | — |
| 仓库 | `jadephong/BasePortal`（`repo` 默认值） | — |

## 用法

### ① 规划与评审 — `sprint-plan-review.yaml`（我执行）
跑完停在「待审批包」。**全程产物只落本地 `.ao-output/`，任何步骤一律零 Jira 写入、不写 docs/adr/**——grill 之后只改本地，擅自建 Jira 属于越界。你 Review 后回复「批准」。
```
运行 vendor/workflows/dev/sprint-plan-review.yaml
  sprint_name: Sprint 1
  sprint_goal: 完成租户管理与登录鉴权
  jira_project: EMT                  # 仅用于同步预案标注
  backlog: <上一 Sprint 产物或 PRD>   # 可选
  prev_sprint_review: <上个 Sprint 的 sprint-review 报告>   # 可选，估点校准+避免重踩坑
```
`requirement_alignment`（**grill-me 需求对齐**：一次一问、每问给推荐答案、能查代码先查、追问到共识才放行）→ `sprint_planning` 拆 Story（含 AC/估点/依赖，吃上轮复盘做估点校准与 carryover）→ `story_grill`（**逐 Story 再 grill-me**：一次一个 Story、能查代码先查，对齐后**用 to-prd 的 PRD 结构定稿**，每个 Story 一个本地文件 `.ao-output/<sprint>/stories/<临时ID>.md` + `INDEX.md`）→ `tech_spec` 把面向 OpenCode 的规格按 Story 追加进各 Story 本地 PRD → `spec_lint` 查覆盖度+歧义（🔴阻塞/🟡建议）→ `decision_record` 草拟 ADR → `review_gate` 出待审批包并暂停。

### ② 同步到 Jira — `sprint-jira-sync.yaml`（我执行，审批硬边界）
**批准后手动触发**。`sprint_name` 必须与①一致（幂等键依赖它）。
```
运行 vendor/workflows/dev/sprint-jira-sync.yaml
  sprint_name: Sprint 1
  jira_project: EMT
  approved_plan: <粘贴待审批包，或 .ao-output 路径>
```
`jira_dryrun` 查重出预案并暂停等「确认同步」→ `jira_sync` **先建/复用 Epic → 各 Story 的 `parent` 设为该 Epic（Epic 串联 Story）**，幂等创建/更新，**每个 Story 的完整 Tech Spec 写入 description 正文**（OpenCode 从 ticket 正文读，**禁用附件/外部链接**否则丢失）→ `sync_verify` 回读核对（含 parent 指向 Epic、Tech Spec 全文在正文）并产出 **OpenCode 执行清单**（仅含校验通过的条目）→ `persist_decisions` 把批准的 ADR 落库到 `docs/adr/`（随仓库提交，跨 Sprint 决策记忆）。

> **本地 vs Jira 的分工**：① 的产物（含 Tech Spec）只在 `.ao-output/` 暂存，是过程稿；OpenCode 看不到 `.ao-output`。② 才把完整 Story+Tech Spec 灌进 Jira ticket 正文——交给 OpenCode 的**事实源是 Jira ticket**，不是本地文件。

### ③ 单 Task 开发 — `task-development.yaml`（OpenCode 执行）
按执行清单逐张 Task 跑；开始先把 Jira 转到 `Work In Progress`，建完 PR 后转到 `Resolved` 并停在「请review」。该工作流只负责首轮开发，不再内嵌返修模式。
```
运行 vendor/workflows/dev/task-development.yaml
  jira_id: EMT-50
```
`setup_branch`(切 `feature/EMT-50`) → `read_ticket`(读 AC/Files to touch/Out of scope/Verification) → `implement`(只改范围内、不做 out-of-scope) → `dev_test`+`qa_automation`(强制) → `verify`(跑 Verification，失败停在本 Task 修) → `commit`(一 Task 一 commit) → `refresh_and_reverify`(**rebase 最新 main + 重验**，把跨 Task 冲突挡在合并前) → `open_pr`(`--force-with-lease` 推送，暂停"请review")。

### ④ Task 评审 — `task-review.yaml`（我执行）
OpenCode 建完 PR 后对该 Task 触发；开始评审先把 Jira 流转到 `In Review`。
```
运行 vendor/workflows/dev/task-review.yaml
  story_key: EMT-54
  pr_url: https://github.com/jadephong/BasePortal/pull/8
  review_round: 1            # 打回后改 2、3…
```
`mark_in_review`(Jira → `In Review`) → `gather_context`(拉 PR，**diff 落 `.ao-output/review-<key>/diff.patch`**，产出精简上下文+风险分类) → `dod_gate`(**只看证据不读 diff**，坏构建零成本打回) → `review`(基线合并评审，**diff 只读一次**) + `security_check`/`perf_check`(**按风险自适应**：不碰敏感面就轻量跳过、碰了才读 diff 深审) → `summary`(判定) → `write_back`(GitHub 发完整 review comment；Jira 只写“轮次 + 结论 + GitHub review comment link”，并流转到 `Reviewed` / `Reopened`)。
- **省 token 设计**：diff 落文件不重复内联；DoD 不达标在读 diff 前就打回；安全/性能维度对 docs/CRUD 类 PR 自动跳过深审——独立评审、AC 对照、敏感面深审均保留。

### ④b Task 返修 — `task-fix-review.yaml`（OpenCode 执行）
评审打回后触发；开始先把 Jira 转到 `Work In Progress`，推送返修更新后转到 `Resolved`；只修 review 阻塞项，不重复首轮建分支 / 开 PR 步骤。
```
运行 vendor/workflows/dev/task-fix-review.yaml
  jira_id: EMT-50
  review_report: <填 task-review GitHub review comment 里的阻塞项>
```
`resume_branch`(切回 `feature/<jira_id>` 并对齐远端) → `read_ticket` → `implement_fix`(只修阻塞项) → `dev_test`+`qa_automation` → `verify` → `commit` → `push_update`(推送更新并停在“请重新review”)。

### ⑤ 合并与关单 — `task-merge-close.yaml`（OpenCode 执行，合并硬边界）
**评审通过后手动触发**。
```
运行 vendor/workflows/dev/task-merge-close.yaml
  jira_id: EMT-50
  pr_url: https://github.com/jadephong/BasePortal/pull/8
```
`preflight`(`gh pr view` 验 `reviewDecision=APPROVED` + 可合并 + CI 全绿，并抓关单素材) → `merge_and_close`(合并 main → Jira `Done` → 评论四要素：Jira Link / PR Link / 改动摘要 / dev 测试 / QA 测试)。

### ⑥ Sprint 整体验收 — `sprint-review.yaml`（我执行）
全部 Task 合并后跑一次，看整体而非单点。
```
运行 vendor/workflows/dev/sprint-review.yaml
  sprint_name: Sprint 1
  jira_project: EMT
  sprint_goal: 完成租户管理与登录鉴权
```
`collect_sprint`(JQL 拉全部 Task + `gh pr list` 拉已合并 PR，核对关联) → `completion_audit`(目标达成/carryover/燃尽) → `integration_review`(跨 Task 接缝/契约一致性) ‖ `regression_check`(最新 main 全量测试+回归) → `sprint_acceptance`(验收判定 + 报告写回 Jira + 下个 Sprint 跟进项)。

## 谁执行哪个

| 工作流 | 执行方 | 性质 |
|--------|--------|------|
| ① sprint-plan-review | 我（Claude，角色扮演） | 规划+评审，到审批止 |
| ② sprint-jira-sync | 我 | **审批硬边界**，人工触发 |
| ③ task-development | OpenCode | 单 Task 首轮开发，到 PR 止 |
| ④ task-review | 我 | 单 PR 三维评审，GitHub 留完整评论，Jira 只回链 |
| ④b task-fix-review | OpenCode | 单 Task 返修，只修 review 阻塞项 |
| ⑤ task-merge-close | OpenCode | **合并硬边界**，评审通过后人工触发并把 Jira 转 Done |
| ⑥ sprint-review | 我 | Sprint 收尾整体验收 |

## 防纰漏要点

- **Spec 校验门**（①）：OpenCode 不追问、会忠实实现模糊处，进审批前先把洞照出来。
- **两道审批硬边界**（②⑤）：同步、合并都是独立工作流靠人工触发；⑤ 还直读 GitHub `reviewDecision` 客观验 APPROVED。
- **Dry-run + 幂等**（②）：写 Jira 前先预览确认；按 label 查重，重跑不建重复。
- **回读校验**（②）：回读 Jira 核对，"汇报成功"≠"真的建好"，没建好的不交给 OpenCode。
- **范围闸**（③）：只改 Files to touch、不做 Out of scope，越界即停问用户。
- **DoD 门 + 轮次上限**（③④）：不评审坏构建；不无限打回，3 轮升级人工。
- **整体验收看接缝**（⑥）：单 PR 全过 ≠ 拼一起没问题；专查跨 Task 集成与回归。
- **grill-me 需求对齐**（①）：拆任务前先一次一问逼到共识，避免基于误解拆一堆错 Task。
- **逐 Story grill + to-prd 定稿**（①）：拆完 Story 后再逐个 grill（能查代码先查），用 to-prd 的 PRD 结构逐 Story 定稿，单个 Story 的含糊不会漏到实现阶段。
- **本地 only、零 Jira**（①）：规划/grill 阶段所有产物只落 `.ao-output/`，任何步骤禁止调用 Jira MCP——擅自建 Jira 是越界，Jira 写入只属于 ②。
- **Epic 串联 Story**（②）：先建 1 个 Sprint Epic，所有 Story 的 `parent` 指向它，看板上成树而非散落。
- **Tech Spec 进 ticket 正文**（②）：完整 Tech Spec 写进 Story 的 description 正文，禁用附件/外链——OpenCode 从 ticket 正文读，本地 `.ao-output` 它看不到。
- **read_ticket 契约字段**（①→③）：每个 Story 必须含 **Summary / 验收标准(AC) / Files to touch(具体路径) / Out of scope / Verification commands(可运行) / Steps**——这是 ③ `task-development` 的 `read_ticket` 强制解析项，缺 Files to touch 或 Verification commands 时 OpenCode 直接停。① 的 story_grill/tech_spec 必须按此生成。
- **分支新鲜度防护**（③）：建 PR 前 rebase 最新 main 并重验，跨 Task 冲突挡在合并前而非验收时。
- **反馈闭环**（⑥→①）：上个 Sprint 的复盘（估点偏差/carryover/教训）喂回下次规划，校准估点、不重踩坑。
- **跨 Sprint 决策记忆**（①→②）：关键决策落 `docs/adr/`，下个 Sprint 的 grill 先读 ADR，不重新扯皮。
