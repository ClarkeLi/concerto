<p align="center"><img src="assets/banner.png" alt="Concerto — Opus conducts, Sonnets play." width="100%"></p>

**Opus 指挥，Sonnet 演奏。**

[English](README.md) · 简体中文 · [Deutsch](README.de.md)

Concerto 把 [Claude Code](https://claude.com/claude-code) 变成一条自动、并行的编码流水线。你只管不断丢想法：Opus 负责规划，多个 Sonnet 在各自独立的 git worktree 里并行实现，小卡由 Opus 快速检查、其余卡由独立 verifier 批量验收，最后全部自动合并，不需要你盯着。

它是为"想法停不下来"的人设计的（对 ADHD 友好）：记录一个想法只要一条很短的命令，处理整堆想法只要再一条。

```
/hum 修复登录超时                    # 一行记录，瞬间完成
/hum 给 CLI 加 --json 输出
/hum 把 utils 拆成三个模块
/opus                               # 规划 → 并行实现 → 验收 → 合并，全自动
```

## 工作原理

```
        ┌──────────────┐
想法 →  │ Opus         │  侦察代码库、拆任务卡、画依赖图
        │ （编排者）    │
        └──────┬───────┘
               │ 依赖满足的任务卡立即派发（最多同时 4 个）
     ┌─────────┼──────────┐
     ▼         ▼          ▼
 executor   executor   executor      Sonnet（S 卡用 Haiku），各用一个 git worktree
     │         │          │
     ▼         ▼          ▼
 ┌───────────────────────────┐
 │ 验收                      │      S 卡：Opus 快速看 diff
 └─────────────┬─────────────┘      M/L 卡：每 ≤3 张一个 Sonnet verifier
               ▼ 通过 → 合并到 concerto/<plan-id> 并跑测试
        ┌──────────────┐
        │ 原分支       │  全部通过后才 fast-forward 合回
        └──────────────┘
```

- **依赖驱动调度**：一张卡的依赖一合并就立刻开工，不必等整个波次。会改同一批文件的卡不会同时运行。
- **流水线式、省 token 的验收**：每个 executor 一返回就验收、合并。简单的小卡由 Opus 快速看一遍 diff；其余卡交给独立、只读的 verifier，一个 verifier 一次最多审 3 张，不必每张卡都付一次新 agent 的启动开销。失败的卡会带着 verifier 给出的具体修复指示重试两次，之后由 Opus 亲自接手。
- **多轮续跑**：一轮运行期间新增的想法，会在下一轮自动接上，最多连续 3 轮，所以你可以在另一个终端继续记录。
- **可续跑**：所有状态都在 `.claude/work/<plan-id>/plan.md` 和 `log.md` 里，中断后用 `/da-capo` 继续。
- **默认安全**：Concerto 绝不 push、绝不 force。工作在 `concerto/<plan-id>` 分支上进行，测试全部通过才会合回；否则停在该分支，留给你检查。

## 命令

| 命令 | 作用 |
|---|---|
| `/opus <需求>` | 端到端规划并执行一个或多个需求（用 `；` 分隔）。 |
| `/opus` | 不带参数：取走想法池里**所有未处理的想法**，分组后让互不冲突的并行执行。 |
| `/hum <想法>` | 把想法追加到 `.claude/work/ideas.md`。只记一行，不做分析。 |
| `/hum` | 给未处理的想法分组，并建议对应的 `/opus` 命令。 |
| `/encore` | 看板：当前项目所有计划的进度（含失败或阻塞的卡）和未处理想法。只读。 |
| `/da-capo [plan-id]` | 续跑或重跑计划（默认选最近一个未完成的）。手动修改 `plan.md` 后也用它。 |

另外有一个 `SessionStart` hook：每次在项目里开新会话，都会提醒你有未完成的计划和待处理的想法。

## 安装

前提：[Claude Code](https://claude.com/claude-code)、`git`、`jq`，macOS 或 Linux（bash）。

```bash
git clone https://github.com/ClarkeLi/concerto.git
cd concerto
./install.sh
```

安装脚本会把 2 个 agent、4 个 skill、一个 hook 脚本和计划模板复制到 `~/.claude/`（可用 `CLAUDE_HOME` 指定其他位置），在 `~/.claude/CLAUDE.md` 末尾追加一小段说明，并在备份为 `settings.json.bak-concerto` 之后，向 `~/.claude/settings.json` 追加一条 `SessionStart` hook。它不会覆盖你现有的设置，重复运行也是安全的；被替换的文件会先另存为 `*.bak-concerto`。

用 `./uninstall.sh` 卸载（项目里的 `.claude/work/` 数据和备份文件不会被删除）。

建议在 **Opus** 会话里运行 `/opus` 以获得最佳规划质量；executor 使用 Sonnet（S 小卡第一次用 Haiku，重试时改用 Sonnet），verifier 始终使用 Sonnet。

## 项目数据

按项目存放，按需创建，并写入 `.git/info/exclude`，不会被提交：

```
.claude/work/
├── ideas.md              # 想法池："- [ ] 2026-10-28 <想法>"
└── <plan-id>/            # YYYYMMDD-HHMM-短slug
    ├── plan.md           # 任务卡 + 状态：唯一的事实来源
    └── log.md            # 派发 / 验收 / 合并流水
```

想法池是按项目隔离的：在项目 A 里记下的想法，在项目 B 里看不到。

## 须知

- 琐碎的改动（单文件、约 30 行以内）不走流水线，Opus 直接做完。
- Opus 只在这几种情况下才会停下来问你：猜错代价很大（丢数据、改公共 API、不可逆迁移）、需要密钥或付费资源、需求与现有架构根本冲突。
- 如果目录不是 git 仓库，Concerto 会执行 `git init`（绝不在 `$HOME` 或 `/` 下）并做一次初始快照提交。
- 运行前未提交的改动会自动 stash，结束后恢复。
- 子代理的 worktree 默认基于默认分支创建，所以每个 executor 开工前会先合并 `concerto/<plan-id>` 以获取之前的成果。
- Concerto 依赖的 Claude Code 功能（skills、带 `isolation: worktree` 的子代理、hooks）更新很快。如果更新后出了问题，欢迎提 issue。

## 为什么叫"Concerto"？

协奏曲是独奏者与管弦乐队的合作演出。Opus 是独奏者，Sonnet 们是乐队，命令是乐谱：`hum` 哼一个主题，奏完整部 `opus`，来一段 `encore`（安可），或者回到开头 *da capo*。

## 许可证

MIT
