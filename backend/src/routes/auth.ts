import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { prisma } from '../prisma';
import { env } from '../config/env';
import { login, updateProfile, loginWithHuawei, deactivateUser } from '../services/authService';
import { exchangeCodeForToken, fetchHuaweiUserProfile } from '../services/huaweiAuth';
import * as postService from '../services/postService';
import * as tagService from '../services/tagService';

const router = Router();

// 鸿蒙账号授权登录
// POST /v1/auth/login  |  POST /v1/users/login
router.post('/login', async (req: AuthRequest, res: Response) => {
  const { openId, nickname, avatar } = req.body ?? {};
  if (!openId) return fail(res, CODE.BAD_REQUEST, '缺少 openId');
  const result = await login(openId, nickname, avatar);
  return ok(res, result);
});

// 华为账号登录（Account Kit）：用 Authorization Code 换取 UnionID 并落地用户
// POST /v1/auth/huawei/exchange  |  POST /v1/users/huawei/exchange
router.post('/huawei/exchange', async (req: AuthRequest, res: Response) => {
  const code: string = req.body?.code;
  if (!code) {
    return fail(res, CODE.BAD_REQUEST, '缺少 code');
  }
  try {
    const accessToken: string = await exchangeCodeForToken(code);
    const profile = await fetchHuaweiUserProfile(accessToken);
    const result = await loginWithHuawei(profile.unionID, profile.nickName, profile.avatarUri);
    return ok(res, result);
  } catch (e) {
    return fail(res, CODE.HUAWEI_AUTH_FAILED, '华为登录失败，请稍后重试或切换其他登录方式', 200);
  }
});

// 当前用户信息
// GET /v1/auth/me  |  GET /v1/users/me
router.get('/me', auth, async (req: AuthRequest, res: Response) => {
  const user = await prisma.user.findUnique({ where: { id: req.userId! } });
  if (!user) return fail(res, CODE.NOT_FOUND, '用户不存在', 404);
  return ok(res, { ...user, isAdmin: env.adminUserIds.includes(user.id) });
});

// 更新个人信息（昵称/头像/简介/性别；仅传入字段更新，性别可设 null/保密）
// PUT /v1/auth/me  |  PUT /v1/users/me
router.put('/me', auth, async (req: AuthRequest, res: Response) => {
  const { nickname, avatar, bio, gender } = req.body ?? {};
  const user = await updateProfile(req.userId!, nickname, avatar, bio, gender);
  return ok(res, user);
});

// 账号注销（软删）：POST /v1/auth/me/deactivate | POST /v1/users/me/deactivate
// 仅操作当前登录用户自身（req.userId 来自 auth 中间件）；成功后旧 token 经 auth 中间件返回 401。
router.post('/me/deactivate', auth, async (req: AuthRequest, res: Response) => {
  await deactivateUser(req.userId!);
  return ok(res, { success: true });
});

// 我的收藏帖子列表（分页）
// GET /v1/auth/me/bookmarks?page=1&limit=20
router.get('/me/bookmarks', auth, async (req: AuthRequest, res: Response) => {
  const page = req.query.page ? Number(req.query.page) : 1;
  const limit = req.query.limit ? Number(req.query.limit) : 20;
  const data = await postService.listBookmarks(req.userId!, page, limit);
  return ok(res, data);
});

// 我关注的标签列表（圈子已加入）
// GET /v1/auth/me/followed-tags
router.get('/me/followed-tags', auth, async (req: AuthRequest, res: Response) => {
  const tags = await tagService.listFollowedTags(req.userId!);
  return ok(res, tags);
});

export default router;
