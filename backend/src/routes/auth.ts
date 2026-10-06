import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { prisma } from '../prisma';
import { env } from '../config/env';
import { login, updateProfile, loginWithHuawei, deactivateUser, recordPrivacyConsent } from '../services/authService';
import { exchangeCodeForToken, fetchHuaweiUserProfile } from '../services/huaweiAuth';
import * as postService from '../services/postService';
import * as tagService from '../services/tagService';

import { asyncHandler } from '../middleware/asyncHandler';
import { parsePage, parseLimit } from '../utils/pagination';
import { normalizeMediaRefInput } from '../utils/mediaRef';

const router = Router();

// 鸿蒙账号授权登录
// POST /v1/auth/login  |  POST /v1/users/login
// 开放 openId 登录：仅本地开发/测试允许。生产环境禁用（存在身份冒充风险，任何人可伪造 openId 获取任意用户令牌）。
// 生产登录统一走 /huawei/exchange（服务端用 client_secret 换 token，无法伪造）。
router.post('/login', asyncHandler(async (req: AuthRequest, res: Response) => {
  if (env.isProduction) {
    return fail(res, CODE.FORBIDDEN, '开放登录已禁用', 403);
  }
  const { openId, nickname, avatar } = req.body ?? {};
  if (!openId) return fail(res, CODE.BAD_REQUEST, '缺少 openId');
  const result = await login(openId, nickname, avatar);
  return ok(res, result);
}));

// 华为账号登录（Account Kit）：用 Authorization Code 换取 UnionID 并落地用户
// POST /v1/auth/huawei/exchange  |  POST /v1/users/huawei/exchange
router.post('/huawei/exchange', asyncHandler(async (req: AuthRequest, res: Response) => {
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
    // 记录真实错误到后端日志，便于定位（secret 缺失 / AGC OAuth 客户端未配 / redirect_uri 不匹配 / 网络等）
    const realMsg: string = e instanceof Error ? e.message : String(e);
    console.error('[huawei exchange] 华为登录后端换 token 失败:', realMsg);
    return fail(res, CODE.HUAWEI_AUTH_FAILED, '华为登录失败，请稍后重试或切换其他登录方式', 200);
  }
}));

// 当前用户信息
// GET /v1/auth/me  |  GET /v1/users/me
router.get('/me', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  // 白名单字段返回，杜绝 openId/unionID 等华为账号标识（PII）与内部字段泄露给客户端。
  const user = await prisma.user.findUnique({
    where: { id: req.userId! },
    select: {
      id: true,
      nickname: true,
      avatar: true,
      profileBackground: true,
      bio: true,
      gender: true,
      privacyPolicyVersion: true,
      privacyAgreedAt: true,
    },
  });
  if (!user) return fail(res, CODE.NOT_FOUND, '用户不存在', 404);
  const privacyRequired: boolean =
    !user.privacyPolicyVersion || user.privacyPolicyVersion !== env.privacyPolicyVersion;
  return ok(res, {
    ...user,
    isAdmin: env.adminUserIds.includes(user.id),
    privacyRequired,
  });
}));

// 记录隐私政策同意（PIPL 可追溯）：前端弹窗"同意"时上报当前版本。
// 仅接受与当前生效版本一致的上报，防止旧前端用过期版本蒙混过关。
// PATCH /v1/auth/privacy-consent
router.patch('/privacy-consent', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const version: string = req.body?.version;
  if (!version) return fail(res, CODE.BAD_REQUEST, '缺少 version');
  if (version !== env.privacyPolicyVersion) {
    return fail(res, CODE.BAD_REQUEST, '隐私政策版本不匹配，请更新应用后重新同意', 409);
  }
  await recordPrivacyConsent(req.userId!, version);
  return ok(res, { success: true });
}));

// 更新个人信息（昵称/头像/主页背景/简介/性别；仅传入字段更新，性别可设 null/保密）
// PUT /v1/auth/me  |  PUT /v1/users/me
router.put('/me', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const { nickname, avatar, profileBackground, bio, gender } = req.body ?? {};
  // 资料媒体走本系统上传体系（EditProfile 上传后回填 cos:// 或 /uploads/ 引用）；
  // 头像/背景会被其他用户客户端自动加载，任意外链 = 跟踪打点，拒绝。
  // （登录态的华为头像由服务端从华为接口回填，不经此处，不受影响。）
  if (avatar !== undefined && avatar !== null && (avatar as string) !== '' && !normalizeMediaRefInput(avatar).ok) {
    return fail(res, CODE.BAD_REQUEST, '头像引用无效');
  }
  if (profileBackground !== undefined && profileBackground !== null &&
    (profileBackground as string) !== '' && !normalizeMediaRefInput(profileBackground).ok) {
    return fail(res, CODE.BAD_REQUEST, '背景图引用无效');
  }
  const user = await updateProfile(req.userId!, nickname, avatar, profileBackground, bio, gender);
  return ok(res, user);
}));

// 账号注销（软删）：POST /v1/auth/me/deactivate | POST /v1/users/me/deactivate
// 仅操作当前登录用户自身（req.userId 来自 auth 中间件）；成功后旧 token 经 auth 中间件返回 401。
router.post('/me/deactivate', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  await deactivateUser(req.userId!);
  return ok(res, { success: true });
}));

// 我的收藏帖子列表（分页）
// GET /v1/auth/me/bookmarks?page=1&limit=20
router.get('/me/bookmarks', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const page = parsePage(req.query.page);
  const limit = parseLimit(req.query.limit, 20);
  const data = await postService.listBookmarks(req.userId!, page, limit);
  return ok(res, data);
}));

// 我赞过的帖子列表（分页）
// GET /v1/auth/me/likes?page=1&limit=20
router.get('/me/likes', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const page = parsePage(req.query.page);
  const limit = parseLimit(req.query.limit, 20);
  const data = await postService.listLikedPosts(req.userId!, page, limit);
  return ok(res, data);
}));

// 我评论过的帖子列表（按帖子去重，分页）
// GET /v1/auth/me/commented?page=1&limit=20
router.get('/me/commented', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const page = parsePage(req.query.page);
  const limit = parseLimit(req.query.limit, 20);
  const data = await postService.listCommentedPosts(req.userId!, page, limit);
  return ok(res, data);
}));

// 我关注的标签列表（圈子已加入）
// GET /v1/auth/me/followed-tags
router.get('/me/followed-tags', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const tags = await tagService.listFollowedTags(req.userId!);
  return ok(res, tags);
}));

export default router;
