---
title: "2026-10-07-compose-v1-v2-avoid-up-use-rolling-deploy-script.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_c30356aa7a6976b2ac642fb3f2d48e5e7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-07-compose-v1-v2-avoid-up-use-rolling-deploy-script
title: 生产容器部署三层前置核对：代码是否已同步、Compose 版本是否一致、有无安全滚动部署脚本
category: build-env
nature: pitfall
created_at: 2026-10-07T00:42:01
updated_at: 2026-10-07T00:42:01
tags: [docker-compose, deployment, rolling-deploy, outage-avoidance, ops]
keywords: [docker compose unknown shorthand flag, docker-compose v1, compose v2, container_name 冲突, up 重建容器, 停机, 滚动部署, 健康检查回滚, deploy-backend.sh, 生产部署, git push 同步, 服务器路径, 自动部署 timer]
problem_patterns: [deploy-command-fails-due-to-compose-v1-v2-mismatch, up-recreates-container-and-deletes-running-one-causing-outage, deploying-code-not-yet-pushed-to-target-environment]
source_sessions: [ses_ef42f4035ffekN6vk5fZoDuUMc]
project: HarmonyProject1
severity: high
quality_score: 87
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-07-fix-derived-data-needs-historical-backfill, 2026-10-07-read-time-recompute-override-stale-counter, 2026-10-07-run-ops-scripts-in-slim-runtime-image]
---

# 生产容器部署三层前置核对：代码是否已同步、Compose 版本是否一致、有无安全滚动部署脚本

## Scenario

把本地改好并通过测试的修复部署到生产环境（`docker-compose` 管理的多容器：mysql + backend + nginx）。按本地开发的习惯，在服务器上敲 `docker compose -f docker-compose.prod.yml up -d --build backend` 期望更新服务。

适用于任何「本地开发 → 远程容器化生产」的团队，尤其是**容器由 Compose v2 创建、但服务器命令行只装了 v1**，以及项目自带滚动部署脚本的场景。

## Key Signals

1. `docker: unknown shorthand flag: 'f' in -f` 或 `'compose' is not a docker command` —— 服务器只有 **Compose v1**（独立二进制 `docker-compose`），`docker compose` 子命令不可用。
2. 服务器上 `cd backend` → `No such file or directory`；`cd /Users/<me>/Project/...`（本地 macOS 绝对路径）同样不存在 —— 目标环境路径与本地不同，且往往项目根下才是 `backend/`。
3. 提交历史 / `git status` 显示改动**尚未 commit/push**，而服务器代码是旧的 —— 此时无论怎么重启，跑的都是旧代码。
4. 项目里已存在自定义部署脚本（如 `scripts/deploy-backend.sh`），其头部注释明确写了「**不要用 `up`**」及历史事故 —— 说明常规 `up` 已被团队弃用。
5. 服务器装有自动部署定时器（`systemd timer`），`git push` 到主分支即触发滚动部署 —— 手工重启是多余且危险的动作。

## Essence

生产部署失败通常不是「命令参数写错」，而是**三层前置没有核对**：

1. **代码是否已到达目标环境**（commit + push + server `git pull`）。未同步时任何重启都是空转。
2. **命令行工具版本与创建容器的版本是否一致**。Compose v1 与 v2 是两套实现：v2 用 `docker compose`（子命令），v1 用 `docker-compose`（独立二进制）。混用会出现「命令不存在」；即便勉强运行，v1 也可能**认不出** v2 创建的容器。
3. **该环境是否有官方认可的安全部署入口**。

关键风险：Compose 的 `up` 语义是「使容器达到期望状态」，而非「原地滚动替换」。在 `container_name` 固定且由另一版本创建的情况下，v1 的 `up` 会尝试**重建**容器、撞名失败；更糟的是**失败之前可能已删除正在运行的旧容器**，造成线上 API 中断。因此正确的入口是项目自带的、以「新容器健康检查通过后才删除旧容器、失败自动回滚」为契约的滚动部署脚本，而不是自拟 `up` 命令。

## Approach

1. **先同步代码，再谈部署**（本地）：
   ```bash
   git add <改动文件> && git commit -m "<type>(scope): 描述" && git push
   ```
   服务器侧：`cd ~/<repo> && git pull`。
2. **探测目标环境实际可用的 Compose**：
   ```bash
   docker compose version 2>/dev/null || docker-compose version
   ```
   用实际存在的那个，不要按本地经验混用。
3. **不要在生产直接 `up`**，改走项目滚动部署脚本（本例 `scripts/deploy-backend.sh`）：
   ```bash
   cd ~/youju/backend && bash scripts/deploy-backend.sh
   # --no-build：跳过构建，用现有镜像替换
   # --allow-drift：明知库与 schema 有差异仍部署
   ```
   该脚本契约：构建新容器 → 健康检查通过 → 删除旧容器；失败自动回滚，旧容器全程不动。
4. **注意脚本的前置条件**：数据库可达、`.env` 齐全、schema 对账（缺列会导致接口 P2022 全 500，而 `/health` 仍返回 ok）。若检测到 drift，先补迁移或显式确认。
5. **确认是否已有自动部署通道**：若装了自动部署 timer，`git push` 即可，无需手工操作，且不要与之竞争部署。
6. **验证**：`curl -I https://<域名>/` + 后端健康检查；确认新容器在跑、旧容器已被替换、日志无重启错误。

## Faster Next Time

- **部署前必答三问**：代码 push 了吗？目标环境该用哪个 Compose？这个项目有没有官方部署脚本？
- **信号 → 动作**：出现 `unknown shorthand flag: 'f'` → 立即切 `docker-compose`（v1）或检查部署脚本，别再逐字调整参数。
- **信号 → 动作**：服务器上 `cd` 找不到目录 / 看到本地绝对路径 → 先 `git push` + 服务器 `git pull`，再部署。
- **默认怀疑 `up`**：生产机器上「能建新容器」不等于「能安全替换」；优先找已有的滚动脚本（含回滚），其次才是自拟命令。
- **脚本优先于手敲**：带健康检查与回滚的部署脚本 > 手工 `up`，后者失败路径可能先删旧容器导致停机。

## Applicability Boundaries

- **适用**：docker-compose 管理、停机敏感的远程生产环境；宿主机命令行 Compose 版本与创建容器的版本不一致；项目已提供滚动部署脚本。
- **不适用**：本地开发机（`docker compose up` 通常正常）；单容器、无固定 `container_name`、可容忍短时停机的场景可放宽。
- **前提约束**：不同机器的 Compose 版本可能不同，结论必须按**目标环境实测**得出，不能照搬本地或他人环境。
- **注意**：即使使用滚动脚本，也需先完成代码同步，否则只是把旧镜像滚了一遍。

## Evidence or Examples

HarmonyProject1，「帖子评论删除后评论数未更新」修复的部署环节：

- 用户在服务器（Ubuntu，`ubuntu@VM-0-7-ubuntu`）执行并失败：
  - `cd backend` → `-bash: cd: backend: No such file or directory`（项目实际在 `~/youju/backend`）。
  - `cd /Users/itxiaobai/HarmonyProject1/backend` → 本地 macOS 路径在 Ubuntu 上不存在。
  - `docker compose -f docker-compose.prod.yml up -d --build backend` → `unknown shorthand flag: 'f' in -f`（只有 v1）。
- `scripts/deploy-backend.sh` 头部注释原文要点：「为什么不用 docker-compose up：这台机器的容器由 compose v2 创建，而命令行只有 apt 的 v1，v1 认不出它们。`up` 会尝试重建 youju-mysql 并撞名失败；更糟的是失败之前它可能已经把 backend 容器删掉了，导致线上 API 中断（2026-09-24 就发生过一次）。本脚本直接管理 backend 容器，并保证：新容器健康检查通过之后才删除旧容器 —— 失败自动回滚，旧容器全程不动。」脚本还做 schema 对账（缺列会导致接口全 500 而 `/health` 仍 ok）。该脚本变量引用一律写 `${VAR}`（中文紧跟变量时不加大括号会被 bash 并入变量名）。
- 部署前提：改动此前只在本地未提交，服务器是旧代码，重启无效；正确流程为本地 `git push` → 服务器 `git pull` → `bash scripts/deploy-backend.sh`。该机器还装有自动部署 timer，`git push` 到 `main` 后约 2 分钟自动滚动部署。
- 关联经验：被部署的修复见 `2026-10-07-fix-derived-data-needs-historical-backfill` 与 `2026-10-07-read-time-recompute-override-stale-counter`；同一部署环节中「生产镜像内执行一次性脚本」的问题见 `2026-10-07-run-ops-scripts-in-slim-runtime-image`。
