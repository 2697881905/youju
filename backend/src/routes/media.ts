import { Router, Request, Response } from 'express';
import { getCosViewUrl, isValidMediaKey } from '../services/uploadService';

// 私有 COS 媒体代理。业务数据只保存 cos://key，客户端每次加载时由此路由换取 5 分钟 GET 签名。
const router = Router();

router.get('/:key', (req: Request, res: Response) => {
  const key = req.params.key;
  if (!isValidMediaKey(key)) {
    res.sendStatus(404);
    return;
  }
  try {
    const viewUrl = getCosViewUrl(key);
    res.setHeader('Cache-Control', 'no-store');
    res.redirect(302, viewUrl);
  } catch (error) {
    console.error('[media.read]', error);
    res.sendStatus(404);
  }
});

export default router;
