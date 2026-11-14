# 有据 · 11-15 复工执行包

**日期**：2026-11-15（周日）
**取代口径**：11 月改为渠道验证期，达标月改 **12 月**（`growth-400mau-youju-2026-10-28.md` 顶部已同步）
**依据**：`growth-channel-assets-youju-2026-10-28.md`、`editorial-2026-11-dual11.md`、`scripts/seed-rehome.sql`、`growth-400mau` §6.7

> ## ⚠ 发之前必须知道：10-28 弹药包的功能承诺已作废
>
> 远端 `main` 11-05~11-07 的提交改了产品方向（`54f6be2` 可核验阅读版式、`1859b68` 删跨帖对比表与主数字派生列、`4e297f4` 删前端对比表组件、`a501712` 发布流改 AI 拆块审稿）：
> - **「发帖必填主数字 / 自动拉成对比表」整体退役**。`metric` 数字块 11-05 起停止新增，存量降级成普通行；`PostCompareSheet.ets`、`postMetric.ts`、schema 派生列全删。新字段表是 `review` 优点/缺点、`pitfall` 踩坑经历/损失金额/正确做法、`tutorial` 步骤拆解、`debate` 方案 A/B（`backend/src/utils/structuredFields.ts`）。
> - **在架仍是 1.0.5（11-03）**，上述改动一个都没发版。旧文案对当前商店里的包没说错，但对下一版是假的，而商店页文案会长期挂着。
> - 结论：**对外一律不提主数字、不提自动对比表、不提 AI 拆块（未发版）**。本文件三条文案已按此重写。弹药包 §B/§C/§D/§N 与 §K3/§K8 里涉及这几处的段落**全部作废，别直接复制**。
> - 连带两件：商店页简介已按新口径整份重写（`entry/Docs/AGC_STORE_COPY.md`）；编辑部 8 篇成稿正文（法条出处）可用，字段录入按 §3.5 映射。
>
> **已定口径**：「结构化体裁 + 出处可追问 + 鸿蒙原生交互 + 一人全栈」。三条对外文案与商店页均按此写定。
>
> ---

> **只复制标记 `bash` 的代码块进终端。** 标记 `text` 的是发到邮件/论坛/私信的文案，标记 `sql` 的要贴进数据库客户端，都不是终端命令。命令块内没有任何注释，整块粘进去即可。

---

## 0. 先纠三个事实，再发任何东西

| 旧成稿（10-28） | 今天（11-15） | 处理 |
| --- | --- | --- |
| 「双 11 前想买台洗地机」「双 11 避坑征集」 | 双 11 已结束 | 全部改成**售后**：退货时限、保价兑现、安装加价、赠品退回 |
| 「现在是 1.0.3」「在架 1.0.1」 | **在架 1.0.5**（11-03 过审） | D1 花粉帖那句删掉；其余文案不提版本号 |
| 「11-01 提交编辑推荐 / 11-08 双 11 专题」 | 两次都过期 | 改 **11-15 应用整体 / 12-01 年末专题** |
| 朋友圈第 2 波「11-12 双 11 这周数据」 | 日期已过 | 整条作废，不复用 |
| 「发帖必填主数字 → 自动对比表」（§B/§C/§D/§N/§K3/§K8） | 11-05/11-07 已退役，下一版不再有 | 全部删掉，改说结构化体裁与出处可追问 |

**为什么今天只发 3 条**：编辑推荐、开发者论坛、召回私信都不把首屏推给陌生大众，且文案已自陈「真实用户只有几十人」。面向大众的微信群/朋友圈/花粉社区/酷安要等首屏修完再发——它们是一次性信任曝光，编辑或用户点进来看到 331 篇「示例亲历」，这个渠道本季度就废了。

---

## 1. 今天发出去的 3 条

### 1.1 编辑推荐申请邮件（最长排期，今天必须发）

收件人 `developer@huawei.com`，主题行严格按官方要求。

```text
《编辑推荐》栏目申请+有据
```

正文：

```text
华为应用市场编辑团队：

申请《编辑推荐》栏目，应用「有据」（包名 com.youju.app，HarmonyOS 5.0+，2026-11-03 在架版本 1.0.5）。

一句话：鸿蒙原生「可核验经验」社区——把散乱经历整理成有出处、能追问的结构，而不是又一篇长文。

为什么值得被推荐：
1. 内容形态是原生设计。发帖分四种结构化体裁：测评填优点/缺点，踩坑填经历/正确做法，教程填步骤拆解，辩论填方案 A/B。它把一段经历逼成可核验的结构，而不是任它写成情绪长文；每条结论都能被追问出处，评论可标「事实补充」与证伪。
2. 圈子是星图。标签按近 14 天热度排成三环公转的宇宙，点行星降落进圈子，点星子直达某一篇。这套交互只在鸿蒙上做，用了沉浸光感材质与液态玻璃 Dock，低版本设备自动回退自绘，视觉不断档。
3. 智感握姿：换手时操作栏跟着手走，单手可用整页交互。
4. 一个开发者独立完成的 HarmonyOS NEXT 原生全栈（ArkTS/ArkUI + Node/Express/Prisma/MySQL），全量官方组件，无第三方 UI 库。
5. 11 月在做「双 11 售后避坑」可核验内容：退货法定时限、保价兑现、家电安装加价，每篇都给法条或公开规则出处；12 月接年末消费与国考考研择校决策场景。

可提供的运营配合：专题内容排期、真机截图与 15 秒演示视频、上线后一周内的内容更新；需要补任何材料我当天回。

也想如实说明现状：站内早期有一批我自己撰写的示例内容，正在统一标注为「示例」并逐步替换；目前真实用户帖只有二十余篇，日活常在 1–3 人。这是冷启动的真实水位，我不回避，申请推荐也不是想把这点藏起来。

附件：6 张 1080×1920 预览图、15 秒真机演示视频、亮点说明。
商店页：https://appgallery.huawei.com/app/detail?id=com.youju.app
官网：https://youju.chat/

白逸飞
2697881905@qq.com
```

附件取 `screenshot/` 的真机实拍 + `hyperframes-promo/youju-promo-animated.mp4`。**不要用 `appgallery-previews-1080x1920/` 那 6 张**：10-05 旧版，画面里还有已删的「推荐指数」字段，编辑一对照就露馅。申请表按官方《编辑推荐业务介绍》页的 xlsx 填好后一起打包；正式预览图重截后在编辑回复时补。

> 邮件里**不放 `?src=`**：编辑自己点一下不是渠道量，会污染 `agrec` 归因。

### 1.2 华为开发者论坛（同行视角，文案自陈现状，不依赖首屏质量）

```text
一个人全栈做的 HarmonyOS NEXT 原生社区 App（ArkTS + HdsNavigation + 沉浸光感），求拍砖

客户端纯 ArkTS/ArkUI，顶栏统一 HdsNavigation（MINI + stackBuilder 品牌行 + bottomBuilder 分段行 + GRADIENT_BLUR），材质走 ImmersiveMaterial，用 deviceInfo.apiAvailable('26.0.0') 字面量门禁，低版本自动回退到自绘描边/毛玻璃；47 个页面；服务端 Node + Express + Prisma + MySQL + 腾讯云 COS，Docker Compose 单机部署。

踩过的坑可以写一篇：@Builder 参数是值快照不刷新导致红点点了不变；Http OBJECT 模式对 75KB 响应体静默降级成字符串，只能改 STRING 手动 parse；bindSheet 里的 Scroll 吃 '100%' 会把主按钮顶出屏幕；Map Kit off() 拆除期反调回调能崩进程。

产品侧在整理「双 11 售后避坑」的可核验内容（退货时限、保价兑现、安装加价，每条都给法条出处），欢迎开发者来当第一个挑刺的人。现在真实用户只有几十位，日活 1–3 人，工具做得再细内容不够也没人看，这点我认。

应用市场搜「有据」，预览：https://youju.chat/?src=devfor
```

> 上面几处技术细节是 10-28 快照。11-07 改版动过发布流与结构化组件，发之前对一眼当前实现，哪句变了就删哪句——同行会逐条核代码，别在这里丢信任。

### 1.3 存量召回第一批（≤9 人，唯一目的是拿到「为什么走」的原话）

发送纪律：3 批 × ≤9 人、间隔 ≥2 天、每条写不同的话。发前排掉自测号 id41、id72。A 段 12 人的逐人开场白见弹药包 §L，先发这 9 位。

零信号的 B 段用这条，别改：

```text
我是「有据」唯一的那个人开发者。你 10 月初装过/注册过，之后就没来过。
我不想发什么大促话术骗你回来，只想问一句：是打开就撞上登录，还是进来发现内容都是半年前的？你回我一个词就行，我照着改。
（如果你已经卸载了，也完全没关系，不用有负担。）
```

> 预期只拉回 3–8 台。这 9 条私信的真正产出是留存原话，不是月活。

### 1.4 明天（11-16 周一）09:30 发 IT之家

弹药包 §N 的 820 字全文**不能只改两处**：第 3 段整段在讲「必填主数字 → 自动对比表」，那是 11-07 已退役的功能。把该段整段删掉，换成下面这段：

```text
所以我做的 App 定了条硬规矩：发经验不能只写感受，得按体裁把结构补齐——测评写优点和缺点，踩坑写经历和正确做法，教程拆步骤，辩论摆方案 A/B。写完读者能逐条追问「出处在哪」，评论里可以标事实补充和证伪。我不承诺这里的内容绝对真实，只承诺每句结论都能被追问得动。
```

另外三处改动：

| 位置 | 改成 |
| --- | --- |
| 结尾「11 月我在做『双 11 避坑』征集，欢迎拿你的真实数字来砸我。」 | 「11 月我在整理双 11 售后避坑：退货时限、保价兑现、安装加价，每篇都给法条出处。欢迎拿你的真实经历来砸我。」 |
| 配图 2「一篇 pitfall 帖的主数字 + 自动生成的对比表」 | 换成一条 pitfall 帖的「踩坑经历 / 正确做法」结构截图，用编辑部 8 篇成稿里的真实条目，不要示例帖 |
| 第 5 段自陈现状 | 保留原样（「真实用户只有几十个人、日活 1–3 人、示例内容」都是事实，别删） |

`?src=ithome` 保留。主题行「独立开发者投稿｜鸿蒙原生」。**同一篇不要一稿多投**，少数派/什么值得买按 §C2/§C3 各自改写，同样先删掉主数字与对比表。

---

## 2. 暂缓清单（别提前放）

| 渠道 | 卡在什么前置 | 解锁条件 |
| --- | --- | --- |
| 花粉社区 D1 / 酷安 D3 / 微信群 E / 朋友圈 | 首屏前 20 条仍是示例内容 | 归队 + 编辑部 8 篇上线 + 计数对账完成 |
| 每日一帖推送 | 未归队时会推「伪造亲历」 | 归队 SQL 的 `EXEMPLAR_MARKER` 生效后先 dryRun |
| 25 人全量召回 | 一次性发完像群控 | 按 3 批间隔执行 |
| AGC 改分类 | 可能触发重审核，拖住在架状态 | 12 月看榜单实际露出再决定 |

---

## 3. 内容地基：正确顺序（**不用改后端代码**）

### 3.1 一个关键修正

`seed-rehome.sql` 第 105 行说「先做机制配额（改 `postService.ts` 排序），再跑 SQL」，`growth-400mau` §6.7 说「对账比配额更干净」。两处冲突，按 §6.7 走：

**计数对账 X 用真实行为表回填 `upCount` / `bookmarkCount` 后调 `recompute-hot`，所有帖子 hotScore 一起回落到接近 0，排序自然退到 `createdAt desc`，编辑部新内容自动上位。** 真实帖 hotScore 全 0 的问题随之消失，§6 处置 4 的「推荐流保底配额」不必做。

→ **本轮不改任何 ArkTS / 后端代码。** 省一次发版，也避开「方案没对齐就抢跑改代码」。

### 3.2 已定：X 全对账 + 授权归队（11-15 拍板）

| 项 | 决定 | 理由 |
| --- | --- | --- |
| 计数对账 | **X 全对账** | 数字诚实、热度机制恢复可用、能被媒体核查；代价是首屏短期「0 顶」，靠编辑部内容与真实互动长回来。Y 让热度信号永久失真，Z 同一页面两种真假计数说不清 |
| 归队 SQL | **授权执行** `scripts/seed-rehome.sql` | 331 帖 / 45 号由假 UGC 转官方 PGC，消除虚构口碑的信任与合规风险 |

已落成可直接执行的 `scripts/growth-day0-2026-11-15.sql`（含计数列备份、前后对照读数、回填、验证）。**我没有执行任何生产库写操作**——命令在 §3.3，由你粘贴运行。

`viewCount` **保留不清零**（详情页「N 人看过」否则全空）。`commentCount` 与 `Comment` 表已对得上，不动。

### 3.3 执行顺序（逐条跑，每条看行数再往下）

1. 只读复核（第一组命令，不改数据）
2. 全量备份 `Post` / `Up` / `Bookmark` 到本地文件，**确认文件非空**再往下
3. 归队 `scripts/seed-rehome.sql`（自带 `RelabelBackup202610` 备份表；第 86 行软注销仍是注释，不执行）
4. 计数回填 X：`scripts/growth-day0-2026-11-15.sql`（自带 `CountBackup20261115` 备份表）
5. 重算 hotScore（两种走法见下）
6. 编辑部 8 篇按 §3.5 字段映射录入
7. 验首屏前 10 条：应出现带法条出处的编辑部内容，不是《出师表》
8. 每日一帖 `dryRun` → 确认选帖不含示例 → 再实发

**只读复核命令**（纯查询，不改数据）：

```bash
./scripts/mau-report.sh 2026-11
./scripts/src-report.sh 168h
```

**备份命令**（同样在目标服务器终端执行，**不要 ssh 到自己**——那会多一次密码交互且毫无必要）：

```bash
docker exec -i youju-mysql sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" youju Post Up Bookmark' > ~/youju-backup-20261115.sql
```

先 `ls -lh ~/youju-backup-20261115.sql` 确认落盘文件非空再往下。若容器内没有 `mysqldump`，改用 seed-rehome.sql 自带的 `RelabelBackup202610` 备份表覆盖归队部分，并单独导出 `Up` / `Bookmark` 两张行为表——**别跳过备份**。

**归队 + 对账：一条命令，零依赖（11-15 修正）**

> ⚠️ **在目标服务器终端执行**（提示符 `ubuntu@VM-0-7-ubuntu:~$`），**不是本机 Mac 终端**。
> 不要 `git pull`、不要 `git stash`、不要动工作区：服务器上没有 `scripts/` 文件时 `< scripts/xxx.sql` 必然报 `No such file or directory`；本机主检出有未提交改动时 `git pull` 会被拒。下面用 heredoc 直接把 SQL 喂进容器，不依赖任何本地文件、不依赖网络、不碰 git。
> **整块只跑一次**。`CHAR(10)` 是 SQL 里的换行，不是命令换行；不要改成别的写法。

```bash
docker exec -i youju-mysql sh -c 'mysql --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD" youju' <<'SQL'
CREATE TABLE IF NOT EXISTS RelabelBackup202610 AS
SELECT p.id AS postId, p.userId AS oldUserId, p.hotScore AS oldHotScore,
       p.content AS oldContent, p.title AS oldTitle, u.nickname AS oldNickname, u.bio AS oldBio
FROM Post p JOIN User u ON u.id = p.userId WHERE 1 = 0;
START TRANSACTION;
INSERT INTO RelabelBackup202610
SELECT p.id, p.userId, p.hotScore, p.content, p.title, u.nickname, u.bio
FROM Post p JOIN User u ON u.id = p.userId
WHERE p.deletedAt IS NULL AND (p.userId = 40 OR p.userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId,unionID),4)='seed'));
UPDATE Post SET content = CONCAT('> 示例内容 · 编辑部整理。非当事人亲历，观点与数据均来自公开资料，可在评论区追问出处。', CHAR(10), CHAR(10), COALESCE(content, ''))
WHERE deletedAt IS NULL AND userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId, unionID), 4) = 'seed')
  AND (content IS NULL OR content NOT LIKE '%示例内容 · 编辑部整理%');
UPDATE Post SET hotScore = hotScore * 0.5 WHERE deletedAt IS NULL AND content LIKE '> 示例内容 · 编辑部整理%';
UPDATE Post SET userId = 40 WHERE deletedAt IS NULL AND userId IN (SELECT id FROM User WHERE LEFT(COALESCE(openId, unionID), 4) = 'seed');
UPDATE User SET nickname = '有据编辑部', bio = '官方内容 · 编辑部整理，每条都给出处。这里不发广告、不装亲历。' WHERE id = 40;
COMMIT;
CREATE TABLE CountBackup20261115 AS
SELECT id AS postId, upCount AS oldUpCount, bookmarkCount AS oldBookmarkCount, hotScore AS oldHotScore FROM Post;
SELECT COUNT(*) AS posts, SUM(upCount) AS up_before, SUM(bookmarkCount) AS bookmark_before FROM Post WHERE deletedAt IS NULL;
UPDATE Post p SET p.upCount = (SELECT COUNT(*) FROM Up u WHERE u.postId = p.id);
UPDATE Post p SET p.bookmarkCount = (SELECT COUNT(*) FROM Bookmark b WHERE b.postId = p.id);
SELECT COUNT(*) AS posts, SUM(upCount) AS up_after, SUM(bookmarkCount) AS bookmark_after FROM Post WHERE deletedAt IS NULL;
SELECT COUNT(*) AS backed_up_rows FROM CountBackup20261115;
SQL
```

这段等价于 `scripts/seed-rehome.sql` 第 0/2 步 + `scripts/growth-day0-2026-11-15.sql` 的全部写操作；`scripts/` 两份文件仍留作审计与回滚依据。`示例内容 · 编辑部整理` 这个标记串被 `dailyDigestService.ts` 的 `EXEMPLAR_MARKER` 依赖，**一个字都不能改**。

`mysql` **故意没带 `-f`**：遇错即停；别为了「跑通」加回去。`CountBackup20261115` 建表不带 `IF NOT EXISTS`，重复执行会直接报错停下，这是防覆盖保护，**别删表重跑**。

### 3.6 执行结果（2026-11-15 01:16，已成功）

| 指标 | 10-28 快照预期 | 实测 | 判读 |
| --- | ---: | ---: | --- |
| `posts`（`deletedAt IS NULL`） | 350 | **360** | 10-28 后新增 10 篇真实帖 |
| `up_before` | 15081 | **15129** | +48 = 新增真实顶 |
| `up_after` | 36 | **84** | `Up` 表真实行数 36 → 84，同样是 +48 |
| `bookmark_before` | 4648 | **4670** | +22 = 新增真实收藏 |
| `bookmark_after` | 15 | **37** | `Bookmark` 表 15 → 37，同样是 +22 |
| `backed_up_rows` | — | **367** | 比 360 多 7，是软删帖；备份表 `SELECT` 不带 `deletedAt` 过滤，正常 |

**交叉验证**：假计数部分 `15129-84=15045` 顶、`4670-37=4633` 收藏，与 10-28 快照的 `15081-36` / `4648-15` **完全一致**。说明回填只覆盖了灌水部分，新增的真实互动一条没丢。事务已 `COMMIT`，两张备份表已建，**无需回滚**。

**归队验收（01:20，全部通过）**：`User.id=40` 昵称 `有据编辑部` / `seed_posts_left=0` / `marked_exemplars=331` / `official_posts=337`（331 + 原有 6）。

**hotScore 重算已完成（01:20）**：`docker restart youju-backend` 后日志出现「初始化热度分完成，共 360 帖」，健康检查返回 `{"ok":true}`。**内容地基全链路闭环**，首屏排序此刻已退到 `createdAt desc`；下一步是验首屏与发渠道，不是继续修数据。

**计数回填 SQL 已落成脚本**：`scripts/growth-day0-2026-11-15.sql`，字段名已核 `backend/prisma/schema.prisma`。它先建 `CountBackup20261115`，再打印前后读数、回填、再打印验证读数；重复执行会因备份表已存在而报错，这是防覆盖保护，**别删表重跑**。

**重算 hotScore（二选一，别都做）**：

- 带管理员 token 调 `POST https://api.youju.chat/v1/admin/recompute-hot`（`backend/src/routes/admin.ts:139`）。
- 或（**最省事，推荐**）在服务器执行 `docker restart youju-backend`：`backend/src/index.ts:52` 启动时无条件全量 `recomputeAllHotScores()`，不需要管理员 token。重启后 `docker logs youju-backend --tail 30 | grep hotScore` 应看到「初始化热度分完成」。

重算后所有帖子 hotScore 回落到接近 0，排序退到 `createdAt desc`。

### 3.4 回滚

- 归队：`seed-rehome.sql` 第 89–94 行的 `RelabelBackup202610` 逐行还原，或整表还原 `~/youju-backup-20261115.sql`。
- 计数：`CountBackup20261115` 里有 `oldUpCount` / `oldBookmarkCount` / `oldHotScore`，按 `growth-day0-2026-11-15.sql` 头部那条 UPDATE 反填即可；也可整表还原 mysqldump。
- **别在没跑备份的情况下执行第 4 步。**

### 3.5 编辑部 8 篇 · 新字段录入映射

`editorial-2026-11-dual11.md` 的正文（法条出处）全部可用，**只是「主数字」不再是独立字段**。数值照抄进「踩坑经历 / 步骤拆解」正文里，信息一条不丢。新字段表见 `backend/src/utils/structuredFields.ts`。

| 帖 | 体裁 | 正文主体放哪 | 损失金额 / 步骤拆解 | 正确做法 |
| --- | --- | --- | --- | --- |
| 1 退货被拒 4 句 | pitfall | 踩坑经历 | 损失金额留空；`168 小时`写进经历 | 逐句对法条反驳 |
| 2 退货前 3 个开关 | tutorial | — | 步骤拆解＝运费/赠品/时限三项核查 | — |
| 3 预售定金 | pitfall | 踩坑经历 | 损失金额留空；`20%`写进经历 | 三种情况分别能否退 |
| 4 先涨后降 | pitfall | 踩坑经历 | 损失金额留空；`前 7 日最低成交价`写进经历 | 怎么取证与申诉 |
| 5 大家电三包 | pitfall | 踩坑经历 | `修理 2 次`写进经历 | 换货主张路径 |
| 6 安装加价 | tutorial | — | 步骤拆解＝安装前 3 项收费依据核查 | — |
| 7 直播间话术 | pitfall | 踩坑经历 | `4 类证据`写进经历 | 当场留证清单 |
| 8 保价 | tutorial | — | 步骤拆解＝主张保价前备齐的 5 项材料 | — |

- 每篇「来源」栏的法条/公开全文逐条贴进正文末尾或证据块（V2 每块最多 6 条证据），这就是「出处可追问」的具体落点。
- 标题口径改成售后向（双 11 **后**退货/保价/安装），别再用「双 11 前」。
- 发布前再点一遍来源链接，法条与平台规则若有修订以现行文本为准。

---

## 4. 12 月作战日历（达标月）

### 4.1 三个资格截止，先确认再做任何运营

| 事项 | 截止 | 状态 |
| --- | --- | --- |
| 报名「鸿蒙应用开发者激励计划 2026」 | **2026-12-25** | 待你确认是否已报名 |
| 开通并通过商户服务审核（收款用） | **2026-12-31** | 待你确认 |
| 首次正式上架 HarmonyOS 5.0+ 市场 | 2026-03-12 ~ 12-31 | ✅ 11-03 已完成（1.0.5） |

新应用档硬条件两条：任一自然月有效月活 ≥400；评分 >3 且评分数 ≥10。**官方明确答复：月活达标的月份与评分达标的月份可以不同，两者独立计算**（11-15 核实开发者联盟 FAQ 与实测帖）。当前评分 **1 条**，缺 9 条——评分可以跨月慢慢攒，不必挤在 12 月。评分靠 §G 的三个正向动作触发，**禁止奖励换好评、禁止互助刷分**。

**真值入口**（别拿 DB 代理值判达标）：

| 来源 | 路径 | 用途 |
| --- | --- | --- |
| 激励计划专属页「有效活跃及评分明细数据」 | 开发者联盟 → 激励计划 2026 活动页 | **达标判定真值**，按月给有效月活 / 评分 / 评分个数，数据滞后一天 |
| AGC 分析 | HarmonyOS 开发者中心 →「应用管理」→ 选应用 →「分析 > 概览 > 本应用概览」→ 用户看板 | 活跃用户数趋势；**口径与激励活动不同，只作参照** |
| 有效月活口径 | 正式上架次日起 ~ 2027-01-31，任一自然月 HarmonyOS 5.0+ 去重活跃设备取最高值 | 排除模拟器 / 群控 / 刷机 / 样机 |

> 月活按**自然月去重设备**计，12-01 计数器清零。11 月的尾巴不带进 12 月，12 月必须整月持续供血。

### 4.2 周闸门（已从 11 月的不可能值重排）

| 节点 | 目标 | 判定 |
| --- | --- | --- |
| 11-21 | 累计 ≥30 台 | 渠道验证：哪个 `src` 有点击 |
| 11-30 | 累计 ≥80 台 | 11 月收官，只要求跑通 2 条有效渠道 |
| 12-07 | ≥150 | 12 月放量起跑 |
| 12-14 | ≥250 | 连续 3 天日新增 <8 台就换渠道 |
| 12-21 | ≥330 | 补评分，不发同类渠道第二遍 |
| 12-31 | ≥400 | 达标判定以激励后台真值 |

11 月不追 400。11 月唯一产出是**哪条渠道能把落地页点击变成安装**，以及首屏修好后真实内容能不能留住人。

---

## 5. 每天一条命令（30 秒，台账别再断）

```bash
./scripts/mau-report.sh 2026-11
./scripts/src-report.sh 24h
./scripts/daily-ledger.sh 2026-11
```

台账 `mau-ledger.md` 最后一行停在 11-02，今天补上第一行。12 月起把月份参数换成 `2026-12`。

AGC 侧（你本人控制台操作）：

1. **商店页文案已整份写好**：`entry/Docs/AGC_STORE_COPY.md` 按新口径重写完毕（副标题 `消费避坑 · 真实测评 · 经验社区` / 简介 / 标签 / 关键词 / 审核红线自查）。**11-15 AGC 控制台实证：应用信息页不可编辑，所有改动必须随新版本提审才生效**——原方案「副标题/关键词可先行单独改」的判断作废。
2. 隐私标签取消「联系人信息」「位置信息」声明（真值见弹药包 §K7）。
3. 确认「鸿蒙应用开发者激励计划 2026」报名状态与商户服务审核（12-25 / 12-31 双截止）。
4. 去「鸿蒙激励计划 2026 → 有效活跃及评分明细数据」读 11 月有效月活与评分个数（**达标判定真值**），截给我。新版控制台没有 Connect API「API 客户端」入口，别再找凭据了，详见 §7。
5. 去「财务结算 → 商户服务」确认审核状态；12-31 前没通过，达标也不发钱。

**发版前必须处理**：`deliverables/appgallery-previews-1080x1920/` 的 6 张预览图是 10-05 旧版，含已删的「推荐指数」字段，商店页与编辑推荐材料都要用真机重截，别拿旧图送审。

---

## 6. 已交付 / 待你操作

| 已交付（本次做完） | 只能你做 |
| --- | --- |
| 今日 3 条发送文案、IT之家改稿指令、11-15 时效纠偏、`entry/Docs/AGC_STORE_COPY.md` 新口径商店文案、`scripts/growth-day0-2026-11-15.sql` 对账脚本、8 篇字段映射、AGC 取数脚本修复、12 月周闸门 | AGC 控制台操作、发邮件/投稿/社区帖/私信、粘贴执行生产库命令、部署后端、真机重截 6 张预览图 |

## 7. 需要你给的（按优先级）

1. **官方活跃设备真值——别再找 API 客户端了**（11-15 浏览器实测结论）：
   - 新版控制台「开发者管理 → ID、证书和Profile → 凭证」只有**服务账号凭证 / API Key 凭证 / 应用级 OAuth 客户端**三块；「开发者级凭证」下服务账号列表为空。**没有**旧版 AGC「用户与访问 → API 密钥 → Connect API → API 客户端」入口。前几轮让你去找的东西在这个账号下不存在，是我判断错了。
   - AGC 登录账号密码 → `203882498 invalid client id`；OAuth 2.0 Client ID/Secret → `203890688 client id or secret error`。**两者都不是 Connect API 凭据**，别再试第三对。
   - **最快**：控制台「鸿蒙激励计划 2026 → 有效活跃及评分明细数据」读 11 月有效月活与评分个数，截给我。这条本身就是达标判定真值。
   - 想让我自动取数：给「项目级凭证」里现成的服务账号 `youju-push-server`（绑定「有据」，角色含 APP管理员/开发/财务，私钥 JSON 已在服务器 `backend/agc-service-account.json`）补「运营 / 查看分析数据」角色，再把 JSON 放到**仓库外**用 `AGC_CRED_PATH` 指过去。之前它取得到 token 但报表返回 `205524993`（角色不够）。
   - 私钥 / 密钥一律不入库；明文发过的密码尽快改、别复用。
2. **§3.3 三条命令的输出**：备份文件大小、归队行数、对账前后读数。有输出我才能判第 5 步该不该往下走。
3. **6 张真机截图**：发版前重截，旧图含已删字段。
4. **两件状态确认**：激励计划是否已报名、商户服务是否已通过审核。漏一项，400 达标也不发钱。
5. **发送回执**：编辑推荐邮件、开发者论坛帖、IT之家投稿发出后告诉我用了哪个 `src`，我用 `scripts/src-report.sh` 核点击。

**未执行**：所有生产库写操作、所有对外发送动作、所有 AGC 控制台改动。

**红线**：不刷量（机器刷量 / 人工互助被华为风控剔除并取消资格）、不用奖励换好评、2027-03-31 前不主动下架、不与其他 2026 鸿蒙激励同享。
