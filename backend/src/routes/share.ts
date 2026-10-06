// 分享落地页 SSR（服务端渲染）：为 youju.chat/post/{id}、user/{id} 提供动态 OG 标签。
// 微信/其他平台抓取链接时读取 og:title / og:description / og:image 渲染富卡片；
// 页面主体是纯内联 CSS 的极简预览卡（无 JS 依赖），浏览器打开同样体面。
import { Router, Request, Response } from 'express';
import QRCode from 'qrcode';
import { prisma } from '../prisma';
import { env } from '../config/env';
import { canViewerSeeAuthorPosts } from '../services/accessControl';

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
  // 无 COS 时的降级格式（base64 data URI）：本身就是可直接内联渲染的图，
  // 原样返回。若落到末尾分支会被拼成 /v1/media/<超长编码串>，后端 key 校验失败 → 404。
  if (u.startsWith('data:')) {
    return u;
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

// 落地页模板（纯 inline，无外部资源）。视觉对齐 App 内分享卡图（utils/shareCard.ets）：
// 白卡 + 大封面（占卡高 70%，App 卡图同比例）+ 标题/两行摘要 + 左下角头像作者行 + 右下角品牌；
// 备案号在卡片外部容器（页面级，卡下方居中），原 nginx sub_filter 注入的底部白条已移除。
function renderPage(meta: {
  title: string;
  description: string;
  image: string;
  url: string;
  bodyImage?: string;
  avatar?: string;
  author?: string;
  deepLink?: string;
}): string {
  // og:image 必须是被抓取方可匿名拉取的绝对地址；data URI 微信/微博不认，退回不输出标签
  const ogImage = /^https?:\/\//.test(meta.image) ? meta.image : '';
  const imageTag = ogImage ? `<meta property="og:image" content="${esc(ogImage)}">
    <meta name="twitter:image" content="${esc(ogImage)}">` : '';
  // 封面缺省兜底与 App 卡图 drawCover 同款：品牌色块 + 白字「有据」
  const coverBlock = meta.bodyImage
    ? `<img class="cover" src="${esc(meta.bodyImage)}" alt="" referrerpolicy="no-referrer">`
    : `<div class="cover cover-fallback"><span>有据</span></div>`;
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
  body{font-family:-apple-system,'PingFang SC','Noto Sans SC',system-ui,sans-serif;background:#FFFFFF;color:#111827;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:16px;gap:14px}
  /* 卡片整体 3:4（与 App 分享卡图 1080×1440 同比例）且完整落在视口内；
     封面 flex-basis 70% = 卡图同款占比；按钮/备案号在卡片外部容器 */
  .card{width:min(360px,100%);aspect-ratio:3/4;display:flex;flex-direction:column;background:#FFFFFF;border:1px solid rgba(17,24,39,.08);border-radius:16px;overflow:hidden;box-shadow:0 16px 48px rgba(17,24,39,.12)}
  .cover{width:100%;aspect-ratio:15/14;object-fit:cover;display:block;background:#F3F4F6;flex:none}
  .cover-fallback{display:flex;align-items:center;justify-content:center;background:#8A6548}
  .cover-fallback span{font-size:40px;font-weight:700;color:#FFFFFF;font-family:'Noto Serif SC',Songti SC,serif}
  .body{flex:1;min-height:0;display:flex;flex-direction:column;padding:10px 16px 12px;overflow:hidden}
  h1{font-size:16px;line-height:1.35;font-weight:700;color:#111827;margin-bottom:4px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
  p.desc{font-size:12px;line-height:1.55;color:#6B7280;display:-webkit-box;-webkit-line-clamp:1;-webkit-box-orient:vertical;overflow:hidden}
  .footer{display:flex;align-items:center;gap:8px;margin-top:auto}
  .avatar{width:26px;height:26px;border-radius:50%;object-fit:cover;background:#F3F4F6;flex:none}
  .name{font-size:12px;color:#111827;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
  .brand{margin-left:auto;font-size:10px;color:#8A6548;white-space:nowrap;flex:none}
  .btn{width:min(360px,100%);text-align:center;background:#111827;color:#FFFFFF;font-size:15px;font-weight:600;padding:13px 0;border-radius:12px;text-decoration:none;flex:none}
  .icp{font-size:11px;text-align:center}
  .icp a{color:#9CA3AF;text-decoration:none}
</style>
</head>
<body>
  <div class="card">
    ${coverBlock}
    <div class="body">
      <h1>${esc(meta.title)}</h1>
      <p class="desc">${esc(meta.description)}</p>
      ${meta.author ? `<div class="footer"><img class="avatar" src="${esc(meta.avatar || '')}" alt="" referrerpolicy="no-referrer"><span class="name">${esc(meta.author)}</span><span class="brand">有据 · 真实经验，有据可循</span></div>` : `<div class="footer"><span class="brand">有据 · 真实经验，有据可循</span></div>`}
    </div>
  </div>
  <a class="btn" id="openAppBtn" href="https://youju.chat/">去「有据」看看</a>
  <div class="icp"><a href="https://beian.miit.gov.cn/" target="_blank" rel="noopener noreferrer">陕ICP备2026014636号-3</a></div>
  <script>
  (function () {
    // 「去有据看看」按钮接入应用拉起（Deep Link）。两个实测结论（2026-10-03 真机）：
    // 1) 鸿蒙浏览器只认【用户对 scheme href 锚点的原生点击】——preventDefault 后再
    //    location.href / window.open 跳 youju:// 会被静默丢弃，系统连确认框都不弹；
    // 2) App 侧 skills 必须含 entity.system.browsable，否则浏览器隐式 Want 匹配不上。
    // 故做法：加载后把 <a> 的 href 换成 youju:// 链接，点击原生放行，由系统弹
    // 「打开 App」确认框；拉起成功则页面失活，3 秒仍可见（未安装/被拦截/未确认）
    // 回落到原行为——打开官网首页。JS 禁用时 href 保持官网链接，行为与接入前一致。
    var deepLink = '${esc(meta.deepLink ?? '')}';
    if (deepLink === '') { return; }
    var btn = document.getElementById('openAppBtn');
    if (!btn) { return; }
    btn.href = deepLink;
    var gone = false;
    btn.addEventListener('click', function () {
      gone = false;
      setTimeout(function () {
        if (!gone && !document.hidden) {
          window.location.href = 'https://youju.chat/';
        }
      }, 3000);
    });
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) { gone = true; }
    });
    window.addEventListener('pagehide', function () { gone = true; });
  })();
  </script>
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
  // 与站内口径对齐（匿名 viewer）：作者被封禁/注销、双向拉黑、postVisibility 非 public
  // 的内容一律 404——落地页此前只查 deletedAt/status，SSR 会绕过全部可见性规则。
  if (!(await canViewerSeeAuthorPosts(undefined, post.userId))) {
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
      avatar: toAbsoluteImage(post.user?.avatar),
      author: post.user?.nickname ?? '',
      deepLink: 'youju://post/' + id,
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
  // 与 GET /v1/users/:id 口径对齐：封禁（status!==1）与已注销用户一律 404，
  // 避免落地页成为被封账号信息的枚举旁路
  if (!user || user.deletedAt !== null || user.status !== 1) {
    res.status(404).send('Not Found');
    return;
  }
  const nickname = user.nickname || '有据用户';
  const avatar = toAbsoluteImage(user.avatar);
  // 主页封面位用「个人主页背景图」，此前误用头像：正方形头像被 16:9 框拉宽裁切，
  // 且未设置背景图的用户会看到一个无意义的横条。未设置背景图时不输出封面。
  const background = toAbsoluteImage(user.profileBackground);
  const bio = excerpt(user.bio ?? '', 120) || `来看看 ${nickname} 在「有据」分享的经验吧`;
  res.status(200).type('html').send(
    renderPage({
      title: `${nickname} 的有据主页`,
      description: bio,
      image: avatar || background,
      url: `${SHARE_HOST}/user/${id}`,
      bodyImage: background,
      avatar,
      author: nickname,
      deepLink: 'youju://user/' + id,
    })
  );
});

// GET /v1/share/qr/:type/:id — 分享卡图二维码（匿名，仅允许生成 youju.chat 域下的落地页链接）。
// 前端分享卡片绘制时拉取此图嵌入，扫一扫 → youju.chat/post/{id} 或 /user/{id}。
router.get('/qr/:type/:id', async (req: Request, res: Response) => {
  const type = req.params.type;
  const id = Number(req.params.id);
  if (!['post', 'user'].includes(type) || !id || isNaN(id)) {
    res.status(400).json({ code: 400, message: 'bad request' });
    return;
  }
  try {
    const png = await QRCode.toBuffer(`${SHARE_HOST}/${type}/${id}`, {
      errorCorrectionLevel: 'M',
      width: 320,
      margin: 1,
      color: { dark: '#111827FF', light: '#FFFFFFFF' },
    });
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=86400'); // 同一帖子二维码 1 天缓存
    res.status(200).send(png);
  } catch (e) {
    res.status(500).json({ code: 500, message: 'generate failed' });
  }
});

export default router;