# PRD: Project Template Automation System

## Problem Statement

每次开新项目都要重复做同样的事：GitHub Actions 配置、folder structure、agents/skills 初始化、Jira 流程对接等。这些步骤机械且容易出错，没有一套统一的标准，导致项目间差异大、维护成本高。

同时，当模板需要更新时（比如 GitHub Actions 配置改进），很难同步到已有的项目上，导致老项目与新项目逐渐漂移。

## Solution

建立一个 **Project Template 系统**，由以下部分组成：

1. **独立的 GitHub Template Repository**（`jadephong/ProjectTemplate`）
   - 使用 Copier 框架实现动态模板
   - 包含所有初始化逻辑（folder structure、workflows、配置）
   - 支持用户交互式配置

2. **自动化初始化脚本**
   - 一行命令创建新项目：`copier copy gh:jadephong/ProjectTemplate my-project`
   - 自动注入 GitHub secrets（SonarQube、Snyk）
   - 设置 branch protection rules

3. **自动化模板同步系统**
   - 模板更新时自动在 downstream repos 开 Issue
   - 各项目通过 `copier update` 拉取更新
   - 用 GitHub topic tag 管理 downstream repo 列表

## User Stories

1. 作为新项目的发起者，我想一行命令快速初始化项目，所以不用手动复制文件和配置
2. 作为开发者，我想自动注入 GitHub secrets，所以不用手动到 Settings 粘贴 API keys
3. 作为开发者，我想自动配置 SonarQube + Snyk 的 GitHub Actions，所以扫描能自动跑
4. 作为开发者，我想自动设置 branch protection，所以 PR 必须通过 scan 才能 merge
5. 作为项目 PM，我想有统一的 product direction 和 sprint 计划模板，所以每个项目结构一致
6. 作为项目 PM，我想有统一的 sprint retro 模板，所以记录标准化
7. 作为模板维护者，我想当模板更新时自动通知所有用这个模板的项目，所以不会有漂移
8. 作为项目开发者，我想收到「模板已更新」的 Issue，所以知道什么时候该运行 `copier update`
9. 作为项目开发者，我想 `copier update` 只改动模板文件，所以业务代码不受干扰
10. 作为新项目发起者，我想通过 `project.config.yaml` 预先填写配置，所以不用交互式逐个回答问题
11. 作为新项目发起者，我想如果有遗漏的必填项，脚本能交互式补问，所以不会因为配置不完整而出错
12. 作为项目管理员，我想给 repo 打 GitHub topic tag，所以自动纳入模板同步范围
13. 作为项目开发者，我想代码扫描和 code review 都是自动化的，所以流程不能被跳过
14. 作为项目团队，我想所有新项目都默认用 Jira 作为 issue tracker，所以 sprint 管理统一

## Implementation Decisions

1. **单栈模板 MVP**
   - 第一版只支持单一技术栈，多栈扩展留给未来版本

2. **Copier 框架**
   - 使用 Copier 处理模板和变量替换
   - 支持 `copier update` 自动同步到 existing projects

3. **配置两层结构**
   - 静态配置（直接 copy）：GitHub Actions YAML、folder structure、agents/skills 文件
   - 动态配置（变量替换）：项目名、repo URL、团队成员、organization ID 等

4. **配置来源策略**
   - 用户先填 `project.config.yaml` 模板
   - 初始化脚本从 `.env`（本地、不 commit）读取 secrets
   - 脚本对比 config 和环境变量，缺失的必填项才交互式补问

5. **GitHub Secrets 注入**
   - 用 GitHub CLI（`gh secret set`）脚本化，不需手动
   - Secrets 值从本地 `.env` 读取

6. **清单由用户手动完成**
   - Product direction：Markdown 填空模板
   - Sprint plan：Markdown 模板 → 用户手动同步到 Jira
   - Retro：`docs/retro/YYYY-MM-DD.md`
   - Code review：`/code-review` AI 先跑，人工后审

7. **GitHub Actions 自动扫描**
   - PR 自动触发 SonarQube + Snyk
   - Branch protection rule：checks 必须 pass 才能 merge

8. **模板同步机制**
   - 用 GitHub topic tag（`jadep-template`）维护 downstream repo 列表
   - 模板 push to main → GitHub Actions 自动查询所有 topic 的 repo
   - 每个 downstream repo 自动开 Issue：`chore: sync template vX.X.X`
   - 开发者在各项目跑 `copier update`，resolve conflicts，close issue

9. **Issue Tracker 统一为 Jira**
   - 所有 sprint plan、close sprint 工作流都对接 Jira

10. **MVP 第一版范围**
    - Copier 配置 + folder structure + GitHub Actions YAML
    - 初始化脚本（secrets 注入）
    - 清单 Markdown（product direction + sprint + retro 模板）
    - Sync notifier workflow

## Testing Decisions

暂无（这个 PRD 主要是架构和工程流程）

后续会补充：
- 脚本集成测试
- GitHub Actions workflow 测试
- Copier template 测试

## Out of Scope

1. 多栈支持
2. CLI 全局安装工具
3. Jira 自动创建/关闭 sprint
4. Confluence 集成
5. 与其他模板工具的比较

## Further Notes

1. **边用边完善**：第一版不求完美，重点是能跑
2. **版本追踪**：Copier 会记录每个项目使用的 template commit
3. **冲突处理**：`copier update` 时有冲突需手动 resolve
