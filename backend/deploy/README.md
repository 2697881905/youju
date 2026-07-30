# 腾讯云轻量服务器部署

该目录用于首发期的一台 Ubuntu 22.04 LTS 腾讯云轻量应用服务器。架构为 Nginx (80/443) -> API (Node.js) -> MySQL，图片仍上传腾讯云 COS。MySQL 与 API 没有对宿主机开放端口。

## 1. 购买与网络

- 选择 Ubuntu 22.04 LTS、2 核 4 GB、60 GB SSD、5 Mbps 起步；生产用户量增长后升级为 4 核 8 GB。
- 在轻量服务器防火墙仅放行 TCP `22`、`80`、`443`。不要放行 `3000` 或 `3306`。
- 为域名添加 A 记录：`api.<你的域名>` 指向服务器公网 IPv4。确认 DNS 生效后再申请证书。

## 2. 准备服务器

以普通 sudo 用户登录，安装 Docker 与 Compose 插件：

```bash
sudo apt update
sudo apt install -y ca-certificates curl
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
newgrp docker
```

将仓库部署到 `/opt/bigbluebook`，进入 `backend/deploy` 后创建生产变量文件：

```bash
cp .env.production.example .env.production
chmod 600 .env.production
```

填写 `.env.production`：所有密码使用独立的强随机值；`API_DOMAIN` 与 `BACKEND_PUBLIC_URL` 必须是同一个真实 HTTPS 域名；填写 COS 五项、华为登录密钥以及真实管理员用户 ID。不要提交该文件。

## 3. 首次 HTTPS 与启动

在 DNS 已指向当前服务器、80 端口已放行时执行。先签发证书，避免 Nginx 因证书文件不存在而无法启动：

```bash
docker volume create bigbluebook_letsencrypt
docker run --rm -p 80:80 -v bigbluebook_letsencrypt:/etc/letsencrypt certbot/certbot certonly --standalone -d api.<你的域名> --email <你的邮箱> --agree-tos --no-eff-email
docker compose --env-file .env.production -f docker-compose.production.yml up -d --build
docker compose --env-file .env.production -f docker-compose.production.yml run --rm api npx prisma db push --skip-generate
docker compose --env-file .env.production -f docker-compose.production.yml run --rm api npm run seed:tags
curl -fsS https://api.<你的域名>/health
```

`prisma db push` 仅用于首次建表或当前无迁移历史的项目。上线后涉及数据结构变更时，先为 Prisma 建立可审计 migration，再执行迁移；不要在有生产数据时盲目使用可能造成数据丢失的 schema 同步操作。

## 4. 日常操作

```bash
# 查看 API 日志
docker compose --env-file .env.production -f docker-compose.production.yml logs -f api

# 更新代码并滚动重建
git pull
docker compose --env-file .env.production -f docker-compose.production.yml up -d --build

# 手动数据库备份
bash scripts/backup-mysql.sh
```

设置每天 03:30 备份（执行 `crontab -e`）：

```cron
30 3 * * * cd /opt/bigbluebook/backend/deploy && /usr/bin/env bash scripts/backup-mysql.sh >> /var/log/bigbluebook-backup.log 2>&1
```

同时将备份同步到 COS、另一台机器或云备份盘；同一台服务器上的备份不能替代异地备份。

## 5. 证书续期

每月执行一次，或放入 cron。续期后重载 Nginx：

```bash
docker run --rm -v bigbluebook_letsencrypt:/etc/letsencrypt certbot/certbot renew
docker compose --env-file .env.production -f docker-compose.production.yml exec nginx nginx -s reload
```

## 6. App 上线前最后一步

在 `entry/src/main/ets/services/api.ets` 中，将正式 `BASE_URL` 从当前占位 `https://api.bigbluebook.com` 改成你已经拥有、证书已生效的 `API_DOMAIN`，然后重新构建签名 Release 包并在真机上验证登录、COS 图片上传、发布、互动与推送。
