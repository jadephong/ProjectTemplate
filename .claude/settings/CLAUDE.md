# Claude Code Configuration

此文件定义项目的 Claude Code 行为和偏好。

## Language Preference

所有回复使用中文。

## Git Workflow

- 使用 git worktree + feature 分支开发
- 避免在 main 分支冲突
- 开发完成后自动 git commit

## Issue Tracker

新任务发布到 Jira（不用 GitHub Issues）

## 实现流程

新需求时：
1. 先运行 `/to-prd` 生成 PRD
2. 再进行实现

完成后：
1. 自动 `git commit`
2. 提交代码审查

## 项目工作流

1. **产品规划** → 产品方向、Sprint 计划
2. **开发** → Feature 分支、代码审查、自动扫描
3. **交付** → PR 合并、Jira 更新
4. **回顾** → Sprint retro

## Code Standards

- Code review 必须通过（人工 + AI）
- SonarQube 和 Snyk 扫描必须通过
- 所有代码需要单元测试（目标覆盖率 > 80%）

## 参考资源

- Product Direction: `docs/product-direction/`
- Sprint Plans: `docs/sprint/`
- Retros: `docs/retro/`
- PRD: `docs/PRD.md`
