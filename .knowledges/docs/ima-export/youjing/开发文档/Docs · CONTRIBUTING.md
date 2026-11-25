---
title: "Docs · CONTRIBUTING.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_2b37035b53101c671511587c3cd3b4f67526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# CONTRIBUTING.md · 有径贡献规范

## 提交规范

- 格式：`type(scope): 中文摘要`，模板见根目录 `.gitmessage.txt`（可选启用：`git config commit.template .gitmessage.txt`）。
- type 限定：`feat` / `fix` / `refactor` / `docs` / `chore` / `test`。
- scope 用目录名：如 `common`、`design`、`docs`、`ets`、`root`。
- 粒度：**单 commit 单意图**；一轮工作打包为一个提交，不拆无关改动、不混入顺手优化。

## 分支策略

- `main` 为主干，保持随时可构建。
- 功能开发走 `feature/xxx` 短分支，合并回 main 后即删除，不保留长命分支。

## 本地验收清单（提交前逐项过）

1. ArkTS 静态检查通过（hvigor `assembleHap` 零 error；LSP 可用时优先 `check_ets_files`）。
2. 构建通过（debug 模式 BUILD SUCCESSFUL）。
3. 变更范围与本次意图一致（`git status` / `git diff --cached` 复核，无步骤外文件）。

## pre-commit hook 启用

hooks 不随仓库分发，新克隆需手动启用：

```sh
# 在仓库根目录执行
cp <hook 来源>/pre-commit .git/hooks/pre-commit   # 或按现有 .git/hooks/pre-commit 内容重建
chmod +x .git/hooks/pre-commit
```

门禁内容：.ets 变更时扫描 console 直接调用与显式 any，并运行 hvigor 编译检查，任一失败拒绝提交。零依赖，纯 POSIX sh，不引入三方 hook 框架。

## 代码红线（详见 Docs/ARCHITECTURE.md）

- 禁 any、禁对象解构、对象字面量必带具名 interface（ArkTS 严格模式）。
- 分层单向依赖：pages → components → model/data/ai/utils → common；页面不得直接操作 RDB 或发起 LLM 请求。
- 配置单点：URL/开关/阈值只在 `common/config/`、`common/constants/` 定义。
- 样式单点：色值/字号/间距/动效一律引用 `design/` tokens，禁止裸值。
- 新增依赖：默认零运行时依赖，确需新增先按 `Docs/TECH_STACK.md` 四项评估登记。
