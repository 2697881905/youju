// 分享落地页 SSR（服务端渲染）：为 youju.chat/post/{id}、user/{id} 提供动态 OG 标签。
// 微信/其他平台抓取链接时读取 og:title / og:description / og:image 渲染富卡片；
// 页面主体是纯内联 CSS 的极简预览卡（无 JS 依赖），浏览器打开同样体面。
import { Router, Request, Response } from 'express';
import { prisma } from '../prisma';
import { env } from '../config/env';

const router = Router();

// 分享主站根域（App 内 buildPostShareUrl 同源），og:url 用真实分享链接
const SHARE_HOST = 'https://youju.chat';

function esc(v: string): string {
  return v
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// 摘要：剥离换行/连续空白，截断
function excerpt(s: string, max: number): string {
  const t = (s ?? '').replace(/\s+/g, ' ').trim();
  return t.length > max ? t.slice(0, max) + '…' : t;
}

// 图片 → 可公开访问的绝对 URL（微信抓 og:image 必须匿名可达）
function toAbsoluteImage(url: string | null | undefined): string {
  const u = (url ?? '').trim();
  if (u === '') {
    return '';
  }
  const base = env.backendPublicUrl;
  if (u.startsWith('cos://')) {
    return base + '/v1/media/' + encodeURIComponent(u.slice('cos://'.length));
  }
  if (u.startsWith('http://') || u.startsWith('https://')) {
    return u;
  }
  if (u.startsWith('/')) {
    return base + u;
  }
  return base + '/v1/media/' + encodeURIComponent(u);
}

// 极简预览页模板（纯 inline，无外部资源）
function renderPage(meta: {
  title: string;
  description: string;
  image: string;
  url: string;
  bodyImage?: string;
  author?: string;
  badge?: string;
}): string {
  const imageTag = meta.image ? `<meta property="og:image" content="${esc(meta.image)}">
    <meta name="twitter:image" content="${esc(meta.image)}">` : '';
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(meta.title)}</title>
<meta name="description" content="${esc(meta.description)}">
<meta property="og:site_name" content="有据">
<meta property="og:type" content="article">
<meta property="og:title" content="${esc(meta.title)}">
<meta property="og:description" content="${esc(meta.description)}">
${imageTag}
<meta property="og:url" content="${esc(meta.url)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="robots" content="index,follow">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:-apple-system,'PingFang SC','Noto Sans SC',system-ui,sans-serif;background:#F4EFE6;color:#26221A;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px}
  .card{width:min(520px,100%);background:#FFFDF8;border:1px solid rgba(38,34,26,.08);border-radius:20px;overflow:hidden;box-shadow:0 12px 40px rgba(38,34,26,.08)}
  .cover{width:100%;aspect-ratio:16/9;object-fit:cover;display:block;background:#E8E2D6}
  .body{padding:24px 26px 28px}
  .badge{display:inline-block;font-size:12px;letter-spacing:.14em;color:#8A6D3B;background:#F3EAD8;padding:4px 12px;border-radius:99px;margin-bottom:14px}
  h1{font-size:22px;line-height:1.4;font-weight:700;color:#26221A;margin-bottom:12px}
  p.desc{font-size:15px;line-height:1.7;color:#6B6353}
  .author{display:flex;align-items:center;gap:10px;margin-top:18px;padding-top:16px;border-top:1px solid rgba(38,34,26,.08)}
  .avatar{width:34px;height:34px;border-radius:50%;object-fit:cover;background:#E8E2D6}
  .author .name{font-size:14px;color:#26221A;font-weight:600}
  .author .hint{font-size:12px;color:#8A8372}
  .btn{display:block;margin-top:18px;text-align:center;background:#26221A;color:#F4EFE6;font-size:15px;font-weight:600;padding:13px 0;border-radius:12px;text-decoration:none}
  .note{margin-top:12px;font-size:12px;color:#A39A88;text-align:center}
</style>
</head>
<body>
  <div class="card">
    ${meta.bodyImage ? `<img class="cover" src="${esc(meta.bodyImage)}" alt="" referrerpolicy="no-referrer">` : ''}
    <div class="body">
      ${meta.badge ? `<span class="badge">${esc(meta.badge)}</span>` : ''}
      <h1>${esc(meta.title)}</h1>
      <p class="desc">${esc(meta.description)}</p>
      ${meta.author ? `<div class="author"><img class="avatar" src="${esc(meta.bodyImage || '')}" alt="" referrerpolicy="no-referrer"><span><span class="name">${esc(meta.author)}</span><br><span class="hint">在「有据」分享</span></span></div>` : ''}
      <a class="btn" href="https://youju.chat/">去「有据」看看</a>
    </div>
  </div>
  <div class="note" style="position:fixed;bottom:14px;left:0;right:0;text-align:center">有据 · 真实生活经验社区</div>
</body>
</html>`;
}

// GET /v1/share/post/:id — 帖子落地页（微信卡片：标题+摘要+封面）
router.get('/post/:id', async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!id || isNaN(id)) {
    res.status(404).send('Not Found');
    return;
  }
  const post = await prisma.post.findUnique({
    where: { id },
    include: { user: { select: { id: true, nickname: true, avatar: true } } },
  });
  if (!post || post.deletedAt !== null || post.status !== 1) {
    res.status(404).send('Not Found');
    return;
  }
  const rawImage: string | null = post.coverImage ?? (post.videoCover ?? null);
  const image = toAbsoluteImage(rawImage);
  const title = post.title || '有据分享';
  const desc = excerpt(post.content ?? '', 120) || `来自「有据」的分享：${title}`;
  res.status(200).type('html').send(
    renderPage({
      title,
      description: desc,
      image,
      url: `${SHARE_HOST}/post/${id}`,
      bodyImage: image,
      badge: '有据 · 帖子分享',
      author: post.user?.nickname ?? '',
    })
  );
});

// GET /v1/share/user/:id — 用户主页落地页
router.get('/user/:id', async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!id || isNaN(id)) {
    res.status(404).send('Not Found');
    return;
  }
  const user = await prisma.user.findUnique({ where: { id } });
  if (!user || user.deletedAt !== null) {
    res.status(404).send('Not Found');
    return;
  }
  const nickname = user.nickname || '有据用户';
  const avatar = toAbsoluteImage(user.avatar);
  const bio = excerpt(user.bio ?? '', 120) || `来看看 ${nickname} 在「有据」分享的经验吧`;
  res.status(200).type('html').send(
    renderPage({
      title: `${nickname} 的有据主页`,
      description: bio,
      image: avatar,
      url: `${SHARE_HOST}/user/${id}`,
      bodyImage: avatar,
      badge: '有据 · 个人主页',
      author: nickname,
    })
  );
});

export default router;