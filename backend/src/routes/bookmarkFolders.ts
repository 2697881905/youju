// 收藏夹（专辑）路由：创建/列表/重命名/删除 + 夹内帖子分页
// 挂载在 /v1/bookmark-folders 下（全部需登录）
import { Router, Response } from 'express';
import { ok, CODE } from '../utils/response';
import { auth, AuthRequest } from '../middleware/auth';
import { asyncHandler } from '../middleware/asyncHandler';
import * as folderService from '../services/bookmarkFolderService';
import { ValidationError } from '../utils/errors';

const router = Router();

// 创建收藏夹：POST /v1/bookmark-folders { name }
router.post('/', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const name = folderService.validateFolderName((req.body ?? {}).name);
  const folder = await folderService.createFolder(req.userId!, name);
  return ok(res, folder);
}));

// 我的收藏夹列表（含计数与封面）：GET /v1/bookmark-folders
router.get('/', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const folders = await folderService.listFolders(req.userId!);
  return ok(res, folders);
}));

// 重命名：PATCH /v1/bookmark-folders/:id { name }
router.patch('/:id', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const folderId = Number(req.params.id);
  if (!Number.isInteger(folderId) || folderId <= 0) {
    throw new ValidationError('收藏夹 ID 无效');
  }
  const name = folderService.validateFolderName((req.body ?? {}).name);
  const folder = await folderService.renameFolder(req.userId!, folderId, name);
  return ok(res, folder);
}));

// 删除：DELETE /v1/bookmark-folders/:id（收藏记录保留，置回未分类）
router.delete('/:id', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const folderId = Number(req.params.id);
  if (!Number.isInteger(folderId) || folderId <= 0) {
    throw new ValidationError('收藏夹 ID 无效');
  }
  const result = await folderService.deleteFolder(req.userId!, folderId);
  return ok(res, result);
}));

// 夹内帖子列表（分页）：GET /v1/bookmark-folders/:id/posts?page=&limit=
router.get('/:id/posts', auth, asyncHandler(async (req: AuthRequest, res: Response) => {
  const folderId = Number(req.params.id);
  if (!Number.isInteger(folderId) || folderId <= 0) {
    throw new ValidationError('收藏夹 ID 无效');
  }
  const data = await folderService.listFolderPosts(req.userId!, folderId);
  return ok(res, data);
}));

export default router;