# git worktree 使用约定（本机多 agent 会话）

> 立此文档的直接原因：2026-09-27 「首页分段栏左右滑动 + 一镜到底」突然消失。
> 复盘结论：**不是 git 丢功能，是主检出的 `HomeTab.ets` 被一份陈旧 worktree 的旧版本覆盖**。

## 一、事故是怎么发生的

1. WorkBuddy 的 agent 会话需要隔离改动时，会在 `~/WorkBuddy/Worktrees/<repo>/main-<hash>` 下
   `git worktree add` 一个工作树，分支 `workbuddy/main-<hash>`，**起点是该会话启动时的 main**。
2. 会话结束后**没有任何清理**：worktree 目录留着、分支永久停在旧提交上。
   本次清理前三个工作树分别落后 main **35 / 189 / 121** 个提交，最早的是 09-07。
3. 某个环节把陈旧工作树里的**整份文件**写回主检出（会话回写 / 在旧目录里打开并保存后应用）。
   因为 `git status` 只显示「几个文件被改」，症状看起来像普通未提交改动，极难发现。
4. 被覆盖的是已提交的活功能：`postsCache` 三页 Swiper 分页、`openDetailViaNav` 一镜到底接线，
   以及当时**最新的** `974f859`（P1-3 分页竞态修复）。

**关键认识**：分支本身不会覆盖文件，**只有「第二份已检出的工作树」才是覆盖通路**。
所以根治的手段是「不留陈旧检出」，而不是「删分支」。

## 二、四道防线

### 防线 1 — 主检出是唯一事实源
所有改动都在 `/Users/itxiaobai/HarmonyProject1` 完成。其它 worktree 只当临时沙箱，**用完即删**。

### 防线 2 — 提交前自动拦截（已启用）
`.githooks/pre-commit` → `scripts/check-stale-overwrite.mjs`，由仓库级配置启用：

```bash
git config core.hooksPath .githooks      # 已设置，一次即可
```

三道判据，任一命中即阻止提交并打印证据：

| 判据 | 内容 |
|---|---|
| A | staged 文件的内容与**任一现存 worktree 的同名文件**逐字节相同 → 几乎不可能是有意为之 |
| B | 单文件净删除 ≥ 150 行且删除 ≥ 新增的 3 倍 → 「大段回退」兜底 |
| C | 用 `git log --all --find-object=<blob>` 打印内容来自哪个提交（取证） |

旁路（确认是有意的删除/重构时）：
```bash
SKIP_STALE_CHECK=1 git commit ...
```

### 防线 3 — 定期体检 / 清理（`scripts/git-doctor.mjs`）

```bash
node scripts/git-doctor.mjs              # 只体检：列出所有 worktree 的落后/独有/脏状态 + 陈旧支线
node scripts/git-doctor.mjs --sync       # 把「干净且无独有提交」的 worktree 快进到 main
node scripts/git-doctor.mjs --prune      # 删除「干净且无独有提交」的 worktree + 分支（推荐）
node scripts/git-doctor.mjs --snapshot   # 把主检出未提交改动打包成 refs/snapshots/<ts>
node scripts/git-doctor.mjs --dry-run    # 只预演
node scripts/git-doctor.mjs --base dev   # 换基线分支（默认 main）
```

`--prune` 只处理 **`ahead == 0 && dirty == 0`** 的工作树 —— 有独有提交或工作树脏的一律跳过，
永不误删。`--sync` 同理。

**约定：任何 agent 会话结束后跑一次 `--prune`。**

### 防线 4 — 手工快照兜底
覆盖事故里最痛的是「未提交改动被冲掉」。关键改动前先留一份快照：

```bash
node scripts/git-doctor.mjs --snapshot
# 恢复全部：   git stash apply <sha>
# 恢复单文件： git show <sha>:path/to/file > path/to/file
```

## 三、「功能消失」的排查顺序（别盲目 checkout）

```bash
git status --short          # 看未提交改动的方向：deletions >> insertions 就是警报
git log --oneline -25       # HEAD 是不是全仓库最新？其后有没有提交？
git worktree list           # 有没有第二份检出？

# 决定性一步：反查工作树文件的内容来自哪条支线
blob=$(git hash-object path/to/file)
git log --all --oneline --find-object=$blob
```
- **能在提交里查到** → 是旧版覆盖 → 备份后 `git checkout HEAD -- <file>`
- **任何提交里都查不到** → 是某会话的原生改动（可能是有意的清理）→ **别动**

## 四、当前状态（2026-09-27 清理后）

| 项 | 状态 |
|---|---|
| worktree | 仅主检出 1 个（原 3 个陈旧检出已删，释放 337MB） |
| 已删分支 | `workbuddy/main-a4a58c8a`(e340600) / `workbuddy/main-d9e689ec`(87ea784) / `workbuddy/main-f6455155`(1d47986) —— 三者都是 main 的祖先，零独有提交，内容全在 main 历史里 |
| 陈旧支线（待你决定） | `exp/waterflow-feed`、`origin/wip/2026-09-20-nav-structured` —— 均已完全并入 main，可删 |
| 护栏 | `core.hooksPath=.githooks` 已启用，回归测试通过（能精确拦住本次事故形态） |

删除远程陈旧支线（可选，需你确认后执行）：
```bash
git push origin --delete exp/waterflow-feed
git push origin --delete wip/2026-09-20-nav-structured
```
