# ProjectTemplate

一键创建标准化项目模板，集成 GitHub Actions、代码扫描、AI Agent 和 Sprint 管理流程。

## 使用方式

```bash
# 交互式创建（推荐）
copier copy gh:jadephong/ProjectTemplate my-project

# 或使用预设配置文件
copier copy --data-file project.config.yaml gh:jadephong/ProjectTemplate my-project

# 进入项目并初始化
cd my-project
bash scripts/init.sh
```

`init.sh` 会：
1. 从 `.env` 读取 SonarQube / Snyk token
2. 注入 GitHub Secrets
3. 设置 main 分支保护规则
4. 创建标准目录结构

## 项目结构

```
├── .github/workflows/scan.yml    # SonarCloud + Snyk 自动扫描
├── docs/
│   ├── product-direction/        # 产品方向模板
│   ├── sprint/                   # Sprint 计划模板
│   └── retro/                    # Retro 模板
├── scripts/init.sh               # 初始化脚本
├── agents/                       # AI Agent 定义
├── skills/                       # Claude Code 技能
├── workflow-runner/              # Sprint 交付流水线
├── src/                          # 源代码（初始化后创建）
└── .copier-answers.yml           # Copier 追踪文件（自动生成，勿手动编辑）
```

## 工作流

1. **Product Direction** → 填写 `docs/product-direction/VISION.md`
2. **Sprint Planning** → 填写 `docs/sprint/SPRINT-N.md`，同步到 Jira
3. **Development** → Feature branch → PR 自动触发 SonarCloud + Snyk 扫描
4. **Branch Protection** → Scan 必须通过才能 merge，code review 必须批准
5. **Retro** → 填写 `docs/retro/SPRINT-N-RETRO.md`
6. **Template Sync** → 模板更新时自动在 downstream repo 开 Sync Issue

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
