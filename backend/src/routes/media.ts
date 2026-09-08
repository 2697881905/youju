import { Router, Request, Response } from 'express';
import { getCosViewUrl, isValidMediaKey } from '../services/uploadService';
import * as https from 'https';

// 私有 COS 媒体代理。业务数据只保存 cos://key，客户端每次加载时由此路由换取 5 分钟 GET 签名。
// 真机 ArkUI <Image>/<Video> 对 302 重定向支持不稳定，统一改为后端字节流代理：
// - 透传上游 Content-Type / Content-Length（key 多为 UUID 无扩展名，靠上游 MIME 识别）
// - 透传 Range 头，支持视频分段（206）与浏览器/播放器进度拖动
// - 跟随一次 COS 重定向后 pipe，客户端无感
const router = Router();

function proxyCosStream(req: Request, res: Response, viewUrl: string): void {
  const fetch = (url: string, depth: number): void => {
    if (depth > 2) {
      res.sendStatus(404);
      return;
    }
    const options: https.RequestOptions = {};
    // 透传 Range（视频拖动关键）：仅支持 bytes
    const range: string | undefined = req.headers.range;
    if (range !== undefined && /^bytes=/.test(range)) {
      options.headers = { Range: range };
    }
    const reqUp = https.get(url, options, (up) => {
      const code: number = up.statusCode ?? 500;
      if (code >= 300 && code < 400 && up.headers.location) {
        up.resume();
        fetch(up.headers.location, depth + 1);
        return;
      }
      if (code !== 200 && code !== 206) {
        up.resume();
        res.sendStatus(code >= 400 && code < 500 ? code : 502);
        return;
      }
      res.status(code);
      const ctype: string | undefined = up.headers['content-type'];
      res.setHeader('Content-Type', ctype ?? 'application/octet-stream');
      const clen: string | undefined = up.headers['content-length'];
      if (clen !== undefined) {
        res.setHeader('Content-Length', clen);
      }
      const crange: string | undefined = up.headers['content-range'];
      if (crange !== undefined) {
        res.setHeader('Content-Range', crange);
      }
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Cache-Control', 'public, max-age=3600');
      up.pipe(res);
    });
    reqUp.on('error', () => {
      res.sendStatus(502);
    });
  };
  fetch(viewUrl, 0);
}

// 支持含斜杠的 key 路径（客户端可按未编码 URL 直出，规避个别 Image 栈对 %2F 编码路径的不兼容）
// 同时保留 %2F 编码形式（decodeURIComponent 后同样可解析）
router.use('/', (req: Request, res: Response) => {
  const raw: string = decodeURIComponent(req.url.split('?')[0].replace(/^\//, ''));
  if (raw.length === 0) {
    res.sendStatus(404);
    return;
  }
  console.log('[media.read]', raw, 'ua=' + ((req.headers['user-agent'] ?? '') as string).slice(0, 60));
  if (!isValidMediaKey(raw)) {
    console.log('[media.read] INVALID_KEY', raw);
    res.sendStatus(404);
    return;
  }
  try {
    const viewUrl = getCosViewUrl(raw);
    proxyCosStream(req, res, viewUrl);
  } catch (error) {
    console.error('[media.read]', error);
    res.sendStatus(404);
  }
});

export default router;