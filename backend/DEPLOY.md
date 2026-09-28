# youju 生产部署 Runbook

> 部署形态：单台腾讯云轻量服务器（Ubuntu 22.04）+ docker-compose（mysql + backend + nginx）。
> nginx 容器内终止 TLS（Let's Encrypt / certbot webroot 模式），反代 backend:3000。
> mysql 仅内部网络可达，3306 不对外开放。

## 一、前置（由你准备）
- 腾讯云轻量服务器：Ubuntu 22.04 / **2核2G 起（推荐 4G）** / 磁盘 ≥40GB / 带宽 ≥3Mbps；安全组放行 22/80/443，**拒绝 3306 入站**
  > 已对 2G 小内存机器做好调优：`docker-compose.prod.yml` 中 mysql 限制 1g + `innodb-buffer-pool-size=384M`、backend 限制 1g + `NODE_OPTIONS=--max-old-space-size=512`、nginx 限制 256m。2G 可直接跑，4G 上这些只是兜底上限、不影响性能。
- 域名 `api.youju.chat` 做 A 记录解析到服务器公网 IP
- 华为 AGC：申请 Release 签名证书（.cer + .p7b），在 DevEco 配 Signing Config
- 本机 Docker 可正常构建镜像

## 二、服务器初始化
```bash
ssh root@<服务器IP>
apt update && apt install -y docker.io docker-compose-plugin
ufw allow 22,80,443
ufw deny 3306
ufw enable
```

## 三、上传代码
```bash
git clone <你的仓库> ~/youju   # 或将本地 backend/ 打包 scp 上去
cd ~/youju/backend
```

## 四、配置环境变量
```bash
cp env.prod.example .env
vi .env   # 填入真实密码 / JWT_SECRET / COS / 华为 Secret / ADMIN_USER_IDS / CORS_ORIGIN / BACKEND_PUBLIC_URL
```
> 注意：`CORS_ORIGIN` 与 `BACKEND_PUBLIC_URL` 在生产模式是**必填且必须 https**，缺失会启动即崩溃。

## 五、先启动 mysql + backend + nginx（仅 80）
此时 `nginx/conf.d/` 只有 `80.conf`，`443.conf` 尚未启用，避免证书不存在导致 nginx 启动失败。
```bash
docker compose -f docker-compose.prod.yml up -d
```

## 六、初始化数据库
```bash
docker compose -f docker-compose.prod.yml exec backend npx prisma db push
# 可选种子：docker compose -f docker-compose.prod.yml exec backend npm run seed:tags
```
> backend 依赖 mysql 就绪；若初期日志报数据库连接错误，待 mysql 起来后会随 restart 策略自动恢复。

## 七、签发 Let's Encrypt 证书
```bash
docker run --rm \
  -v $PWD/certbot/conf:/etc/letsencrypt \
  -v $PWD/certbot/web:/var/www/certbot \
  certbot/certbot certonly --webroot -w /var/www/certbot \
  -d api.youju.chat --email admin@youju.chat --agree-tos --non-interactive
```

## 八、启用 443 并 reload
```bash
cp nginx/443.conf nginx/conf.d/443.conf
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

## 九、验证
```bash
curl -I https://api.youju.chat/
docker compose -f docker-compose.prod.yml logs -f backend   # 确认无 fail-hard 报错
```

## 十、证书自动续期
加入 crontab（`crontab -e`）：
```bash
0 3 * * * cd ~/youju/backend && docker run --rm -v $PWD/certbot/conf:/etc/letsencrypt -v $PWD/certbot/web:/var/www/certbot certbot/certbot renew --quiet && docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

## 十一、后续更新后端
```bash
git pull
docker compose -f docker-compose.prod.yml up -d --build backend
```

## 十二、前端 Release 包（DevEco，你来做）
- `entry/src/main/ets/services/api.ets` 第 13 行 release URL 已改为 `https://api.youju.chat`，构建 Release 包时无需再改
- DevEco：File → Project Structure → Signing Configs，导入 AGC 的 .cer / .p7b + profile
- Build → Build Hap(s)/App(s) → Release

## 文件清单
- `Dockerfile`：多阶段构建（tsc 编译 + prisma generate + 运行时 node dist）
- `docker-compose.prod.yml`：mysql + backend + nginx
- `nginx/conf.d/80.conf`：ACME 校验 + 80→443 跳转（默认启用）
- `nginx/443.conf`：TLS 终止 + 反代（签发证书后 cp 进 conf.d 启用）
- `env.prod.example`：生产环境变量模板
- `scripts/deploy-backend.sh`：滚动部署（构建镜像 → 新容器健康检查 → 替换旧容器 → 失败回滚 → schema 对账）
- `scripts/auto-deploy.sh` + `scripts/systemd/`：Git 自动部署（见下节）
- 运行期会在服务器生成 `certbot/conf`、`certbot/web`、`.env`（均不提交）

---

## 十三、自动部署（Git → 生产，可选）

目标：`git push` 到 `main` 后自动上线，且**完整保留** `deploy-backend.sh` 的健康检查、失败回滚与 schema 对账。

机制：服务器上的 **systemd timer 每 2 分钟** 执行一次 `git fetch`；发现新的 `origin/main` 提交时 fast-forward 拉取并滚动部署；无变化则静默退出。

### 安装（在服务器执行一次）

```bash
cd ~/youju/backend
chmod +x scripts/auto-deploy.sh
sudo cp scripts/systemd/youju-autodeploy.service scripts/systemd/youju-autodeploy.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now youju-autodeploy.timer
systemctl list-timers youju-autodeploy.timer
```

> 若服务器用户名 / 仓库路径不是 `ubuntu` / `/home/ubuntu/youju`，先改 `youju-autodeploy.service` 中的 `User`、`Group`、`WorkingDirectory`、`Environment=REPO_DIR=`、`ExecStart` 五处。

### 前置检查（重要）

自动部署在 systemd 中**非交互**运行，必须先确认 `git fetch` 不需要输入凭据：

```bash
sudo -u ubuntu git -C ~/youju fetch origin main && echo "非交互 fetch OK"
```

若失败：给 `ubuntu` 用户配置一个对仓库只读的 SSH Deploy Key（GitHub → Settings → Deploy keys），或把 remote 换成带 token 的 HTTPS。

### 常用操作

```bash
sudo systemctl start youju-autodeploy.service               # 立即检查并部署一次
journalctl -u youju-autodeploy.service -n 100 --no-pager     # 查看部署日志
systemctl list-timers youju-autodeploy.timer                 # 查看下次触发时间
```

### 行为与保护

- `flock` 并发保护：上一次部署未结束时本次跳过。
- **已跟踪文件**有未提交改动 → 拒绝部署（不会覆盖服务器上的手工修改）；未跟踪文件（如服务器生成的 `certbot/`、`uploads/`）不影响部署。
- 仅 fast-forward，不产生自动合并提交。
- 是否需要部署，以**上次成功部署的 SHA**（`~/.local/state/youju-autodeploy/last-deployed`）为准，而**不是本地 HEAD**。原因：若在服务器上手动执行过 `git pull`，HEAD 会追平远端，按 HEAD 判断会把那次提交**静默跳过**（本项目真实发生过一次）。首次运行无记录时会部署一次。
- **部署失败**：回退检出到原提交，并把该提交记入 `~/.local/state/youju-autodeploy/last-failed`，**不再每 2 分钟重试**（避免反复构建）。修好后推一个新提交即自动恢复；或删除该文件后手动 `systemctl start` 重试。
- 部署成功记录于 `~/.local/state/youju-autodeploy/last-deployed`。
- ⚠️ 不要在服务器上手动 `git pull` 后就以为已上线——那只更新了代码，**没有构建与重启**。需要某次提交立即上线时，用 `sudo systemctl start youju-autodeploy.service`（或 `bash scripts/deploy-backend.sh`）。

### 想要「推完即刻上线」（可选）

2 分钟轮询是刻意折中：无入站端口、无密钥下发，最坏延迟 2 分钟。若需秒级，可改为 GitHub Webhook 触发（服务器加一个小 HTTP 服务校验 `X-Hub-Signature-256` 后调 `sudo systemctl start youju-autodeploy.service`）；代价是新增一个入站端口与一个校验密钥，安全面比轮询大。
