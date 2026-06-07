# ProjectTemplate

一键创建标准化项目模板，集成 GitHub Actions、代码扫描、AI Agent、openspec spec-driven 流程，以及一套 agent-first 的 **Harness** 操作体系。

## 使用方式

```bash
# 1. 安装 Copier（一次性）
pip install copier

# 2. 交互式创建项目（推荐）
copier copy --trust gh:jadephong/ProjectTemplate my-project

#    或使用预设配置文件
copier copy --trust --data-file project.config.yaml gh:jadephong/ProjectTemplate my-project

# 3. 配置 Secrets（在 .env 中填写 token）
cd my-project
cat > .env << 'EOF'
SONARQUBE_TOKEN=your-sonarqube-token
SNYK_TOKEN=your-snyk-token
EOF

# 4. 运行初始化脚本
bash scripts/init.sh
```

`init.sh` 会：
1. 从 `.env` 读取 SonarQube / Snyk token
2. 注入 GitHub Secrets
3. 设置 main 分支保护规则
4. 创建标准目录结构

> `--trust` 参数授权 Copier 执行 `_tasks`（安装后提示），是必需的。

## 项目结构

生成的项目自带一套 **Harness**（agent-first 操作体系）：

```
├── AGENTS.md                     # agent 路由地图（§0-9：默认行为/任务分级/openspec/模块路由/红线/skill/git…）
├── openspec/                     # spec-driven 变更（CLI；project.md + specs/ + changes/archive/）
├── docs/
│   ├── harness/                  # 治理文档（HARNESS_PROFILE/ARCHITECTURE/DESIGN/QUALITY_SCORE/RELIABILITY/SECURITY/FRONTEND/PLANS/PRODUCT_SENSE）
│   ├── design-docs/  (adr/)      # 设计信条 core-beliefs + 架构决策 ADR
│   ├── product-specs/            # 产品规格 + VISION + onboarding
│   ├── exec-plans/               # active/ completed/ templates/（sprint 约定：active/sprint-N、completed/sprint-N/{plan,sprint-review}）
│   ├── references/               # 引用索引 + skill-routing.md（skill 速查地图）
│   └── PRD.md
├── .github/workflows/            # SonarCloud + Snyk 自动扫描
├── scripts/init.sh               # 初始化脚本
├── agents/                       # AI Agent 定义（agency-agents-zh）
├── skills/                       # Claude Code 技能
├── workflow-runner/              # Sprint 交付流水线
├── harness/                      # 内部 autoharness（dev 工具，与产品分离）
├── src/                          # 源代码（初始化后创建）
└── .copier-answers.yml           # Copier 追踪文件（自动生成，勿手动编辑）
```

> Harness 治理文档多为**占位模板**（带 `<!-- TODO -->` + `{{ project_name }}` / `{{ jira_project_key }}` 变量），生成后按提示填项目事实。`AGENTS.md` 与 `skill-routing.md` 是通用层，开箱即用。

## 工作流

1. **填 Harness 事实** → `docs/harness/HARNESS_PROFILE.md`（项目事实源）+ `docs/product-specs/VISION.md`（愿景）
2. **启用 openspec** → `openspec init --tools claude,codex,opencode`（生成 `/opsx:*` slash 命令）
3. **任务分级**（见 `AGENTS.md` §2）→ T0 直接做 / T1 轻量 plan 落 `docs/exec-plans/active/` / T2 走 openspec
4. **Sprint** → 进行中 `docs/exec-plans/active/sprint-N/`；完成 `docs/exec-plans/completed/sprint-N/{plan,sprint-review}`
5. **Development** → Feature branch → PR 自动触发 SonarCloud + Snyk 扫描
6. **Branch Protection** → Scan 必须通过才能 merge，code review 必须批准
7. **Template Sync** → 模板更新时自动在 downstream repo 开 Sync Issue

## 模板同步

- 给你的项目打上 GitHub topic `jadep-template`
- 当模板仓库 push to main 时，自动在打了 tag 的所有项目开 Issue
- 在项目中运行 `copier update` 拉取最新模板变更
- 解决冲突后关闭 Issue

## Secrets 管理

在 `.env` 文件中配置（不提交到 Git）：

```env
SONARQUBE_TOKEN=your-sonarqube-token
SNYK_TOKEN=your-snyk-token
```

## 详细文档

见 [docs/PRD.md](docs/PRD.md)
