# ProjectTemplate

一个自动化的新项目开启模板系统，用 Copier 管理动态配置，自动化 GitHub Actions、secrets 注入和模板同步。

## Quick Start

### 为新项目使用本模板

```bash
copier copy gh:jadephong/ProjectTemplate my-new-project
cd my-new-project
```

### 初始化项目

1. 复制并填写 `project.config.yaml`
2. 创建 `.env` 文件，写入 secrets
3. 运行 `bash scripts/init.sh`
4. 完成！开始开发

## 项目结构

```
.
├── .github/workflows/        # GitHub Actions 工作流
├── docs/                     # 文档和规划
├── scripts/                  # 初始化脚本
├── agents/                   # AI agents
├── skills/                   # Claude Code skills
├── src/                      # 源代码
├── copier.yml                # Copier 配置
└── project.config.yaml       # 项目配置
```

## 工作流程

1. **Product Direction** → 填写 `docs/product-direction/VISION.md`
2. **Sprint Planning** → 复制 `docs/sprint/SPRINT-TEMPLATE.md`，同步到 Jira
3. **Development** → Feature branch, code review, scans
4. **Retro** → 填写 `docs/retro/SPRINT-N-RETRO.md`
5. **Template Sync** → 自动监听更新，通知 downstream repos

## GitHub Actions

- **scan.yml**: SonarQube + Snyk（必须通过才能 merge）
- **template-sync.yml**: 自动向 downstream repos 开 sync issue

## 更多信息

见 `docs/PRD.md`