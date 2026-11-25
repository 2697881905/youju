---
title: "2026-10-07-agent-shell-search-command-guardrails.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_db7652dcfa9c4a28f30204264a5446bb7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-07-agent-shell-search-command-guardrails
title: Agent 在 zsh 环境执行搜索/探测命令的前置护栏：glob 加引号、工具回退、cwd 确认
category: agent-ops
nature: pitfall
created_at: 2026-10-07T00:27:01
updated_at: 2026-10-07T00:44:17
tags: [agent-shell, zsh, glob-quoting, tool-fallback, macos]
keywords: [zsh no matches found, nomatch, --include=*.ets, glob 引号, ripgrep rg not found, command not found, cwd 误判, 工作目录, 多子项目工作区, 搜索命令失败, grep -r, find -exec, Agent 环境适配]
problem_patterns: [unquoted-glob-fails-whole-command-in-zsh, agent-assumes-search-tool-installed, relative-path-breaks-assuming-workspace-root, empty-output-misread-as-no-match]
source_sessions: [ses_ef42f4035ffekN6vk5fZoDuUMc]
project: HarmonyProject1
severity: medium
quality_score: 80
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-10-07-compose-v1-v2-avoid-up-use-rolling-deploy-script, 2026-09-27-degraded-delivery-when-retrieval-unavailable]
---

# Agent 在 zsh 环境执行搜索/探测命令的前置护栏：glob 加引号、工具回退、cwd 确认

## Scenario

Agent 在一个含多个语言子项目（如 ArkTS 前端 + Node/TS 后端）的工作区中，自主执行搜索与探测命令（`grep` / `find` / `rg` / `cat`）来定位代码。命令因 shell 行为差异或工具可用性假设而失败，表面上「没搜到」，实际是命令根本没执行成功，导致定位多花若干轮次。

适用于任何在 macOS（默认 shell 为 zsh）上自动执行 shell 命令的 Agent。

## Key Signals

1. `zsh:1: no matches found: --include=*.ets` —— 命令**整条未执行**，而非搜索无命中。
2. `zsh:1: command not found: rg` —— Agent 假设了未安装的搜索工具（`rg` 非 POSIX 预装）。
3. `cat: package.json: No such file or directory` —— 在含多个子项目的工作区里，相对路径依赖 cwd，默认 cwd 是工作区根而非子项目目录。
4. 「搜索无结果」与「命令失败」外观相似（都近乎空输出），需先判定命令是否真的跑起来了。
5. 同一搜索命令在不同轮次重复报同一错误 —— 说明该护栏未被内化。

## Essence

Agent 的 shell 调用在 macOS 默认走 **zsh**，与 bash 存在两处关键差异，叠加多子项目工作区会同时引爆:

1. **zsh 默认开启 `nomatch`**：未加引号的 glob（`--include=*.ets`、`*.ts`）在无匹配文件时会**直接报错并使整条命令失败**；bash 则原样把模式字符串传给程序。因此凡是参数里含 `*` / `?` / `[` 的，都必须加引号。
2. **工具可用性不可假设**：`rg`（ripgrep）不是标准预装；`--include` 是 GNU grep 的扩展，macOS 自带 grep 也未必按预期支持。
3. **cwd 不等于你脑子里那个目录**：多子项目工作区里，`package.json` / `prisma` 等文件在各子目录下，相对路径命令必须先确认 `pwd` 或显式切换目录。

核心判据：**把「命令执行失败」和「搜索无命中」分开**。报 `no matches found` / `command not found` 属于前者，说明**没有进行任何搜索**，结论不可信。

## Approach

1. **glob 一律加引号**（写搜索命令时的默认动作）：
   ```bash
   grep -rn --include='*.ets' 'pattern' .
   ```
2. **不假设 `rg` 存在，先探测再回退**：
   ```bash
   command -v rg >/dev/null 2>&1 && rg -n 'pattern' || grep -rn 'pattern' .
   ```
3. **按扩展名过滤不依赖 `--include`**：用 `find` + `-exec`，跨平台更稳：
   ```bash
   find . -name '*.ets' -exec grep -n 'pattern' {} +
   ```
4. **先确认 cwd，再发相对路径命令**：`pwd` / `ls`，或直接 `cd backend && ...`（把子目录前缀写进同一条命令）。
5. **把空输出当可疑信号**：若无结果，先回看命令是否出现过 `no matches found` / `command not found` / `No such file`。
6. **探测环境用非破坏性命令**：`command -v`、`pwd`、`ls`，不要用「假设存在然后失败」的方式探测。

## Faster Next Time

- **写命令时的三条默认护栏**：glob 加引号、不假设 `rg`、相对路径先确认 cwd。
- **bash 经验会骗你**：习惯 bash 的人易漏引号，zsh 下同样的命令会整条失败。
- **失败 ≠ 无结果**：看到 `no matches found` 就重写命令，别据此下「代码里没有」的结论。
- **一次写对胜过重试**：与其反复试错，不如直接采用 `find ... -exec grep` 这种对 shell 差异不敏感的形式。
- **多子项目工作区**：把子目录写进同一条 `bash` 命令（`cd <sub> && ...`），避免依赖会话默认 cwd。

## Applicability Boundaries

- **适用**：macOS 默认 zsh 环境下自动执行 shell 命令的 Agent；含多个语言/子项目的工作区。
- **不适用**：bash 环境——`--include=*.ets` 不加引号通常也能工作（但加引号仍更安全，无副作用）。
- **不适用**：IDE / MCP 提供的原生搜索工具（如 `grep` / `glob` 工具）——它们不走 shell，不受 glob 展开影响，应优先使用。
- **注意**：本条解决「命令是否成功执行」的问题，不涉及搜索语义（正则、大小写、忽略目录）；语义问题需单独排查。
- **注意**：macOS 自带 grep 与 GNU grep 在 `-P`、`--include` 等选项上存在差异，回退方案宜选可移植写法。

## Evidence or Examples

HarmonyProject1 的会话 trace（`ses_ef42f4035ffekN6vk5fZoDuUMc`）中同一批命令反复失败：

- `zsh:1: no matches found: --include=*.ets` —— 多条 `grep --include=*.ets` 命令因未加引号整条失败。
- `zsh:1: command not found: rg` —— Agent 直接使用 `rg`，环境未安装。
- `cat: package.json: No such file or directory` —— 工作区根无 `package.json`，实际位于 `backend/`；体现多子项目下的 cwd 误判。
- 这些失败使得「评论删除后计数不变」的定位链路额外消耗数轮；最终改用可移植的 `grep -rn` 与 `find` 组合才稳定拿到结果。
- 对比：同项目启用 IDE 原生 `grep` / `glob` 工具时不受上述 shell 差异影响，检索更可靠。- 关联经验：同一次任务中另一类 shell/环境陷阱（`bash` 变量后紧跟中文须写 `${VAR}`、Compose 版本与路径差异）见 `2026-10-07-compose-v1-v2-avoid-up-use-rolling-deploy-script`；检索/工具全线不可用时的降级交付策略见 `2026-09-27-degraded-delivery-when-retrieval-unavailable`。
