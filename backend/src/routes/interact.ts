import { Router, Response } from 'express';
import { ok, fail, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import * as interactService from '../services/interactService';
import { assertFolderOwnedOrNull } from '../services/bookmarkFolderService';
import { prisma } from '../prisma';
import { getAccessiblePublishedPost } from '../services/accessControl';

// 该路由挂在 /v1 下，路径为完整路径
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

// 顶帖子：POST /v1/posts/:id/up
router.post('/posts/:id/up', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  if (!(await getAccessiblePublishedPost(postId, req.userId!))) {
    return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
  }
  await interactService.upPost(postId, req.userId!);
  return ok(res, null, '已顶');
}));

// 取消顶：DELETE /v1/posts/:id/up
router.delete('/posts/:id/up', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  await interactService.cancelUp(Number(req.params.id), req.userId!);
  return ok(res, null, '已取消顶');
}));

// 收藏（抄作业）：POST /v1/posts/:id/bookmark，可选 body.folderId 归入指定收藏夹（0/null=未分类）
router.post('/posts/:id/bookmark', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  if (!(await getAccessiblePublishedPost(postId, req.userId!))) {
    return fail(res, CODE.NOT_FOUND, '帖子不存在', 404);
  }
  const folderId = await assertFolderOwnedOrNull(req.userId!, (req.body ?? {}).folderId);
  await interactService.bookmarkPost(postId, req.userId!, folderId);
  return ok(res, null, '已收藏');
}));

// 移动已收藏帖子的收藏夹：PATCH /v1/posts/:id/bookmark，body.folderId（0/null=移出收藏夹，收藏保留）
router.patch('/posts/:id/bookmark', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const postId = Number(req.params.id);
  const folderId = await assertFolderOwnedOrNull(req.userId!, (req.body ?? {}).folderId);
  const bookmark = await prisma.bookmark.findUnique({
    where: { userId_postId: { userId: req.userId!, postId } },
  });
  if (!bookmark) {
    return fail(res, CODE.NOT_FOUND, '尚未收藏该帖子', 404);
  }
  await prisma.bookmark.update({ where: { id: bookmark.id }, data: { folderId } });
  return ok(res, null, '已移动收藏夹');
}));

// 取消收藏：DELETE /v1/posts/:id/bookmark
router.delete('/posts/:id/bookmark', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  await interactService.cancelBookmark(Number(req.params.id), req.userId!);
  return ok(res, null, '已取消收藏');
}));

export default router;
