# BigBlueBook 生产部署 Runbook

> 部署形态：单台腾讯云轻量服务器（Ubuntu 22.04）+ docker-compose（mysql + backend + nginx）。
> nginx 容器内终止 TLS（Let's Encrypt / certbot webroot 模式），反代 backend:3000。
> mysql 仅内部网络可达，3306 不对外开放。

## 一、前置（由你准备）
- 腾讯云轻量服务器：Ubuntu 22.04 / **2核2G 起（推荐 4G）** / 磁盘 ≥40GB / 带宽 ≥3Mbps；安全组放行 22/80/443，**拒绝 3306 入站**
  > 已对 2G 小内存机器做好调优：`docker-compose.prod.yml` 中 mysql 限制 1g + `innodb-buffer-pool-size=384M`、backend 限制 1g + `NODE_OPTIONS=--max-old-space-size=512`、nginx 限制 256m。2G 可直接跑，4G 上这些只是兜底上限、不影响性能。
- 域名 `api.mindtype.cn` 做 A 记录解析到服务器公网 IP
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
git clone <你的仓库> ~/bigbluebook   # 或将本地 backend/ 打包 scp 上去
cd ~/bigbluebook/backend
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
  -d api.mindtype.cn --email admin@mindtype.cn --agree-tos --non-interactive
```

## 八、启用 443 并 reload
```bash
cp nginx/443.conf nginx/conf.d/443.conf
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

## 九、验证
```bash
curl -I https://api.mindtype.cn/
docker compose -f docker-compose.prod.yml logs -f backend   # 确认无 fail-hard 报错
```

## 十、证书自动续期
加入 crontab（`crontab -e`）：
```bash
0 3 * * * cd ~/bigbluebook/backend && docker run --rm -v $PWD/certbot/conf:/etc/letsencrypt -v $PWD/certbot/web:/var/www/certbot certbot/certbot renew --quiet && docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

## 十一、后续更新后端
```bash
git pull
docker compose -f docker-compose.prod.yml up -d --build backend
```

## 十二、前端 Release 包（DevEco，你来做）
- `entry/src/main/ets/services/api.ets` 第 13 行 release URL 已改为 `https://api.mindtype.cn`，构建 Release 包时无需再改
- DevEco：File → Project Structure → Signing Configs，导入 AGC 的 .cer / .p7b + profile
- Build → Build Hap(s)/App(s) → Release

## 文件清单
- `Dockerfile`：多阶段构建（tsc 编译 + prisma generate + 运行时 node dist）
- `docker-compose.prod.yml`：mysql + backend + nginx
- `nginx/conf.d/80.conf`：ACME 校验 + 80→443 跳转（默认启用）
- `nginx/443.conf`：TLS 终止 + 反代（签发证书后 cp 进 conf.d 启用）
- `env.prod.example`：生产环境变量模板
- 运行期会在服务器生成 `certbot/conf`、`certbot/web`、`.env`（均不提交）
