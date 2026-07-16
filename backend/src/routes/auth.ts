import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { prisma } from '../prisma';
import { login, updateProfile } from '../services/authService';

const router = Router();

// 鸿蒙账号授权登录
// POST /v1/auth/login  |  POST /v1/users/login
router.post('/login', async (req: AuthRequest, res: Response) => {
  const { openId, nickname, avatar } = req.body ?? {};
  if (!openId) return fail(res, CODE.BAD_REQUEST, '缺少 openId');
  const result = await login(openId, nickname, avatar);
  return ok(res, result);
});

// 当前用户信息
// GET /v1/auth/me  |  GET /v1/users/me
router.get('/me', auth, async (req: AuthRequest, res: Response) => {
  const user = await prisma.user.findUnique({ where: { id: req.userId! } });
  return ok(res, user);
});

// 更新个人信息（昵称/头像）
// PUT /v1/auth/me  |  PUT /v1/users/me
router.put('/me', auth, async (req: AuthRequest, res: Response) => {
  const { nickname, avatar } = req.body ?? {};
  const user = await updateProfile(req.userId!, nickname, avatar);
  return ok(res, user);
});

export default router;
