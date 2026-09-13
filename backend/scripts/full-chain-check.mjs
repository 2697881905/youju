#!/usr/bin/env node
// ============================================================================
// 有据 · 全链路接口自检（提审前 / 发版前回归）
// ============================================================================
// 用法：
//   node scripts/full-chain-check.mjs                  # 默认打本机 127.0.0.1:3000
//   BASE=http://127.0.0.1:3000/v1 node scripts/full-chain-check.mjs
//   BASE=https://api.youju.chat/v1 node scripts/full-chain-check.mjs   # 生产（会写测试数据！）
//
// 覆盖：登录 → 发帖 → 列表/详情 → 点赞/收藏/评论/回复 → 关注/关注流 → 私信 →
//       通知 → 搜索/标签 → 收藏夹 → 隐私/拉黑/不喜欢/导出 → 越权与安全边界 →
//       帖生命周期（回收站/恢复/彻底删除/举报/投票）→ 注销
// 说明：脚本会在库里创建测试数据（帖子/评论/私信）；仅建议在本地或预发环境执行。
// ============================================================================

const BASE = process.env.BASE || 'http://127.0.0.1:3000/v1';

const results = [];
let section = '';

function setSection(s) {
  section = s;
  console.log(`\n===== ${s} =====`);
}
function ok(name) {
  results.push({ section, name, ok: true });
  console.log(`✅ ${name}`);
}
function bad(name, detail) {
  results.push({ section, name, ok: false, detail });
  console.log(`❌ ${name}${detail ? ' — ' + detail : ''}`);
}
function warn(name, detail) {
  results.push({ section, name, ok: null, detail });
  console.log(`⚠️  ${name}${detail ? ' — ' + detail : ''}`);
}

async function api(method, path, opts = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (opts.token) headers.Authorization = 'Bearer ' + opts.token;
  let res;
  try {
    res = await fetch(BASE + path, {
      method,
      headers,
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    });
  } catch (e) {
    return { status: 0, code: -1, message: 'fetch 失败: ' + e.message };
  }
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* 非 JSON */
  }
  return { status: res.status, code: json?.code, data: json?.data, message: json?.message };
}

function assert(sectionName, name, cond, detail) {
  sectionName === section || setSection(sectionName);
  cond ? ok(name) : bad(name, detail);
}

const S = { A: null, B: null, C: null }; // A/B 主测账号，C 用于注销

async function main() {
  console.log(`全链路自检 → ${BASE}\n`);

  // ---------------- 1. 登录 ----------------
  setSection('1. 登录与会话');
  for (const [key, openId, nickname] of [
    ['A', 'dev-seed-openid', '科技老张'],
    ['B', 'dev-seed-openid-2', '虚拟小美'],
    ['C', 'dev-seed-openid-3', '注销测试号'],
  ]) {
    const r = await api('POST', '/auth/login', { body: { openId, nickname } });
    if (r.code === 0 && r.data?.token) {
      S[key] = { token: r.data.token, id: r.data.user?.id, nickname: r.data.user?.nickname };
      ok(`登录 ${nickname}（id=${r.data.user?.id}）`);
    } else {
      bad(`登录 ${nickname}`, `status=${r.status} code=${r.code} msg=${r.message}`);
    }
  }
  const meA = await api('GET', '/auth/me', { token: S.A?.token });
  assert('1. 登录与会话', 'GET /auth/me 返回自己的资料', meA.code === 0 && meA.data?.id === S.A?.id, `code=${meA.code}`);
  const noToken = await api('GET', '/auth/me');
  assert('1. 登录与会话', '无 token 访问鉴权接口 → 401', noToken.status === 401, `status=${noToken.status}`);
  const badToken = await api('GET', '/auth/me', { token: 'invalid.token.here' });
  assert('1. 登录与会话', '无效 token → 401', badToken.status === 401, `status=${badToken.status}`);

  // ---------------- 2. 发帖与读取 ----------------
  setSection('2. 发帖与读取');
  const p1 = await api('POST', '/posts', {
    token: S.A?.token,
    body: { title: '全链路自检·图文帖', genre: 'share', content: '这是一条自检数据，用于验证发布链路。', tags: ['数码选购'] },
  });
  assert('2. 发帖与读取', 'A 发布图文帖', p1.code === 0 && p1.data?.id, `code=${p1.code} msg=${p1.message}`);
  const postId = p1.data?.id;

  const p2 = await api('POST', '/posts', {
    token: S.A?.token,
    body: { title: '全链路自检·长文帖', genre: 'tutorial', content: '长文正文', publishMode: 'text' },
  });
  assert('2. 发帖与读取', 'A 发布长文帖（publishMode=text）', p2.code === 0, `code=${p2.code} msg=${p2.message}`);
  const post2Id = p2.data?.id;

  const p3 = await api('POST', '/posts', {
    token: S.A?.token,
    body: { title: '全链路自检·辩论帖', genre: 'debate', content: 'A 方案 vs B 方案', structuredData: { planA: '方案A', planB: '方案B' } },
  });
  assert('2. 发帖与读取', 'A 发布辩论帖', p3.code === 0, `code=${p3.code} msg=${p3.message}`);
  const debateId = p3.data?.id;

  const emptyTitle = await api('POST', '/posts', { token: S.A?.token, body: { genre: 'share' } });
  assert('2. 发帖与读取', '缺标题 → 400', emptyTitle.status === 400, `status=${emptyTitle.status}`);
  const longTitle = await api('POST', '/posts', { token: S.A?.token, body: { title: 'x'.repeat(101), genre: 'share' } });
  assert('2. 发帖与读取', '标题超 100 字 → 400', longTitle.status === 400, `status=${longTitle.status}`);
  const badGenre = await api('POST', '/posts', { token: S.A?.token, body: { title: '体裁非法', genre: 'nope' } });
  assert('2. 发帖与读取', '非法体裁 → 400', badGenre.status === 400, `status=${badGenre.status}`);
  const noAuthPost = await api('POST', '/posts', { body: { title: '匿名发帖', genre: 'share' } });
  assert('2. 发帖与读取', '未登录发帖 → 401', noAuthPost.status === 401, `status=${noAuthPost.status}`);
  const sensitive = await api('POST', '/posts', {
    token: S.A?.token,
    body: { title: '网络刷单诈骗', genre: 'share', content: '请勿参与网络刷单诈骗' },
  });
  assert('2. 发帖与读取', '敏感词内容 → 被拒（非 0 code）', sensitive.code !== 0, `code=${sensitive.code} msg=${sensitive.message}`);

  const list = await api('GET', '/posts?page=1&limit=20');
  assert('2. 发帖与读取', 'GET /posts 列表含新帖', list.code === 0 && Array.isArray(list.data?.list) && list.data.list.some((p) => p.id === postId), `count=${list.data?.list?.length}`);
  const detail = await api('GET', `/posts/${postId}`, { token: S.B?.token });
  assert('2. 发帖与读取', 'GET /posts/:id 详情可读（他人视角）', detail.code === 0 && detail.data?.id === postId, `code=${detail.code}`);
  assert('2. 发帖与读取', '详情返回 myUp/myBookmark 字段', detail.data?.myUp === false && detail.data?.myBookmark === false, `myUp=${detail.data?.myUp} myBookmark=${detail.data?.myBookmark}`);
  const notFound = await api('GET', '/posts/999999999');
  assert('2. 发帖与读取', '不存在的帖子 → 404', notFound.status === 404, `status=${notFound.status}`);
  const byKeyword = await api('GET', '/posts?keyword=' + encodeURIComponent('全链路自检'));
  assert('2. 发帖与读取', '关键词搜索命中自检帖', byKeyword.code === 0 && byKeyword.data?.list?.length >= 1, `count=${byKeyword.data?.list?.length}`);

  // ---------------- 3. 互动（点赞/收藏/评论） ----------------
  setSection('3. 互动');
  const up1 = await api('POST', `/posts/${postId}/up`, { token: S.B?.token });
  assert('3. 互动', 'B 点赞 A 的帖子', up1.code === 0, `code=${up1.code} msg=${up1.message}`);
  const up2 = await api('POST', `/posts/${postId}/up`, { token: S.B?.token });
  assert('3. 互动', '重复点赞幂等（仍返回成功）', up2.code === 0, `code=${up2.code}`);
  const detail2 = await api('GET', `/posts/${postId}`, { token: S.B?.token });
  assert('3. 互动', '点赞后 myUp=true', detail2.data?.myUp === true, `myUp=${detail2.data?.myUp}`);
  const unUp = await api('DELETE', `/posts/${postId}/up`, { token: S.B?.token });
  assert('3. 互动', '取消点赞', unUp.code === 0, `code=${unUp.code}`);

  const bm = await api('POST', `/posts/${postId}/bookmark`, { token: S.B?.token, body: {} });
  assert('3. 互动', 'B 收藏帖子', bm.code === 0, `code=${bm.code} msg=${bm.message}`);
  const myBm = await api('GET', '/auth/me/bookmarks', { token: S.B?.token });
  assert('3. 互动', '收藏出现在「我的收藏」', myBm.code === 0 && (myBm.data?.list ?? myBm.data ?? []).some?.((p) => p.id === postId), `type=${Array.isArray(myBm.data) ? 'array' : typeof myBm.data}`);
  const unBm = await api('DELETE', `/posts/${postId}/bookmark`, { token: S.B?.token });
  assert('3. 互动', '取消收藏', unBm.code === 0, `code=${unBm.code}`);

  const c1 = await api('POST', `/posts/${postId}/comments`, { token: S.B?.token, body: { content: '自检评论·一级' } });
  assert('3. 互动', 'B 发一级评论', c1.code === 0 && c1.data?.id, `code=${c1.code} msg=${c1.message}`);
  const commentId = c1.data?.id;
  const c2 = await api('POST', `/posts/${postId}/comments`, { token: S.A?.token, body: { content: '自检评论·回复', parentId: commentId } });
  assert('3. 互动', 'A 回复评论（parentId）', c2.code === 0, `code=${c2.code} msg=${c2.message}`);
  const cList = await api('GET', `/posts/${postId}/comments`);
  assert('3. 互动', '评论列表含一级 + 回复', cList.code === 0 && (cList.data?.list?.length ?? 0) >= 1, `count=${cList.data?.list?.length}`);
  const cUp = await api('POST', `/comments/${commentId}/up`, { token: S.A?.token });
  assert('3. 互动', '给评论点赞', cUp.code === 0, `code=${cUp.code} msg=${cUp.message}`);
  const cReport = await api('POST', `/comments/${commentId}/report`, { token: S.A?.token, body: { reason: 'spam', description: '自检举报' } });
  assert('3. 互动', '举报评论', cReport.code === 0, `code=${cReport.code} msg=${cReport.message}`);
  const emptyComment = await api('POST', `/posts/${postId}/comments`, { token: S.B?.token, body: { content: '' } });
  assert('3. 互动', '空评论 → 400/校验拦截', emptyComment.status === 400 || emptyComment.code !== 0, `status=${emptyComment.status} code=${emptyComment.code}`);

  // ---------------- 4. 关注与关注流 ----------------
  setSection('4. 关注');
  const follow = await api('POST', `/users/${S.A?.id}/follow`, { token: S.B?.token });
  assert('4. 关注', 'B 关注 A', follow.code === 0, `code=${follow.code} msg=${follow.message}`);
  const following = await api('GET', '/posts/following', { token: S.B?.token });
  assert('4. 关注', '关注流含 A 的帖子', following.code === 0 && (following.data?.list ?? []).some((p) => p.userId === S.A?.id), `count=${following.data?.list?.length}`);
  const uA = await api('GET', `/users/${S.A?.id}`, { token: S.B?.token });
  assert('4. 关注', 'GET /users/:id 返回 isFollowing=true', uA.code === 0 && uA.data?.isFollowing === true, `isFollowing=${uA.data?.isFollowing}`);
  const followers = await api('GET', `/users/${S.A?.id}/followers`, { token: S.B?.token });
  assert('4. 关注', 'A 的粉丝列表含 B', followers.code === 0 && (followers.data?.list ?? followers.data ?? []).some?.((u) => u.id === S.B?.id), `count=${followers.data?.list?.length ?? followers.data?.length}`);
  const unfollow = await api('DELETE', `/users/${S.A?.id}/follow`, { token: S.B?.token });
  assert('4. 关注', 'B 取关 A', unfollow.code === 0, `code=${unfollow.code}`);

  // ---------------- 5. 私信 ----------------
  setSection('5. 私信');
  const send = await api('POST', '/messages', { token: S.B?.token, body: { receiverId: S.A?.id, content: '自检私信', type: 'text' } });
  assert('5. 私信', 'B 给 A 发私信', send.code === 0, `code=${send.code} msg=${send.message}`);
  const convs = await api('GET', '/messages/conversations', { token: S.A?.token });
  assert('5. 私信', 'A 会话列表含 B', convs.code === 0 && (convs.data?.list ?? convs.data ?? []).some?.((c) => c.peer?.id === S.B?.id), `count=${convs.data?.list?.length ?? convs.data?.length}`);
  const unread = await api('GET', '/messages/unread', { token: S.A?.token });
  assert('5. 私信', 'A 有未读私信计数', unread.code === 0, `data=${JSON.stringify(unread.data)}`);
  const msgList = await api('GET', `/messages/${S.B?.id}`, { token: S.A?.token });
  assert('5. 私信', 'A 读取与 B 的会话消息', msgList.code === 0 && (msgList.data?.list?.length ?? 0) >= 1, `count=${msgList.data?.list?.length}`);
  const readAll = await api('POST', `/messages/${S.B?.id}/read`, { token: S.A?.token });
  assert('5. 私信', '标记私信已读', readAll.code === 0, `code=${readAll.code}`);

  // ---------------- 6. 通知 ----------------
  setSection('6. 通知');
  const noti = await api('GET', '/notifications', { token: S.A?.token });
  assert('6. 通知', 'A 收到互动通知（评论/关注）', noti.code === 0 && (noti.data?.list?.length ?? 0) >= 1, `count=${noti.data?.list?.length}`);
  const unreadCount = await api('GET', '/notifications/unread-count', { token: S.A?.token });
  assert('6. 通知', '未读通知数接口可用', unreadCount.code === 0, `data=${JSON.stringify(unreadCount.data)}`);
  const readNoti = await api('POST', '/notifications/read-all', { token: S.A?.token });
  assert('6. 通知', '全部标记已读', readNoti.code === 0, `code=${readNoti.code}`);

  // ---------------- 7. 搜索与标签 ----------------
  setSection('7. 搜索与标签');
  const hot = await api('GET', '/search/hot', { token: S.A?.token });
  assert('7. 搜索与标签', '热门搜索可用', hot.code === 0, `code=${hot.code}`);
  const suggest = await api('GET', '/search/suggest?keyword=' + encodeURIComponent('自检'));
  assert('7. 搜索与标签', '搜索建议可用', suggest.code === 0, `code=${suggest.code}`);
  const searchUsers = await api('GET', '/search/users?keyword=' + encodeURIComponent('科技'), { token: S.A?.token });
  assert('7. 搜索与标签', '搜索用户可用', searchUsers.code === 0, `code=${searchUsers.code}`);
  const addHist = await api('POST', '/search/history', { token: S.A?.token, body: { keyword: '自检词' } });
  assert('7. 搜索与标签', '写入搜索历史', addHist.code === 0, `code=${addHist.code}`);
  const getHist = await api('GET', '/search/history', { token: S.A?.token });
  assert('7. 搜索与标签', '搜索历史可读', getHist.code === 0, `code=${getHist.code}`);
  const delHist = await api('DELETE', '/search/history', { token: S.A?.token });
  assert('7. 搜索与标签', '清空搜索历史', delHist.code === 0, `code=${delHist.code}`);
  const tags = await api('GET', '/tags');
  assert('7. 搜索与标签', '标签列表可用', tags.code === 0 && (tags.data?.length ?? tags.data?.items?.length ?? 0) > 0, `count=${tags.data?.length ?? tags.data?.items?.length}`);

  // ---------------- 8. 收藏夹 ----------------
  setSection('8. 收藏夹');
  const fCreate = await api('POST', '/bookmark-folders', { token: S.B?.token, body: { name: '自检收藏夹' } });
  assert('8. 收藏夹', '创建收藏夹', fCreate.code === 0 && fCreate.data?.id, `code=${fCreate.code} msg=${fCreate.message}`);
  const folderId = fCreate.data?.id;
  const fList = await api('GET', '/bookmark-folders', { token: S.B?.token });
  assert('8. 收藏夹', '收藏夹列表含新建', fList.code === 0 && (fList.data?.list ?? fList.data ?? []).some?.((f) => f.id === folderId), `code=${fList.code}`);
  const fRename = await api('PATCH', `/bookmark-folders/${folderId}`, { token: S.B?.token, body: { name: '自检收藏夹·改名' } });
  assert('8. 收藏夹', '重命名收藏夹', fRename.code === 0, `code=${fRename.code}`);
  const bmInFolder = await api('POST', `/posts/${postId}/bookmark`, { token: S.B?.token, body: { folderId } });
  assert('8. 收藏夹', '收藏到指定收藏夹', bmInFolder.code === 0, `code=${bmInFolder.code}`);
  const fPosts = await api('GET', `/bookmark-folders/${folderId}/posts`, { token: S.B?.token });
  assert('8. 收藏夹', '收藏夹内帖子可读', fPosts.code === 0 && (fPosts.data?.list?.length ?? 0) >= 1, `count=${fPosts.data?.list?.length}`);
  const fDel = await api('DELETE', `/bookmark-folders/${folderId}`, { token: S.B?.token });
  assert('8. 收藏夹', '删除收藏夹', fDel.code === 0, `code=${fDel.code}`);

  // ---------------- 9. 隐私与安全设置 ----------------
  setSection('9. 隐私与安全');
  const priv = await api('GET', '/me/privacy', { token: S.B?.token });
  assert('9. 隐私与安全', '读取隐私设置', priv.code === 0, `code=${priv.code}`);
  const privPut = await api('PUT', '/me/privacy', { token: S.B?.token, body: { profileVisible: true, showLikes: true } });
  assert('9. 隐私与安全', '更新隐私设置', privPut.code === 0, `code=${privPut.code} msg=${privPut.message}`);
  const prefs = await api('GET', '/me/notification-prefs', { token: S.B?.token });
  assert('9. 隐私与安全', '读取通知偏好', prefs.code === 0, `code=${prefs.code}`);
  const prefsPut = await api('PUT', '/me/notification-prefs', { token: S.B?.token, body: { up: true, comment: true, follow: true, system: true } });
  assert('9. 隐私与安全', '更新通知偏好', prefsPut.code === 0, `code=${prefsPut.code} msg=${prefsPut.message}`);
  const block = await api('POST', `/me/block/${S.A?.id}`, { token: S.B?.token });
  assert('9. 隐私与安全', 'B 拉黑 A', block.code === 0, `code=${block.code} msg=${block.message}`);
  const blockList = await api('GET', '/me/blocklist', { token: S.B?.token });
  assert('9. 隐私与安全', '拉黑列表含 A', blockList.code === 0 && (blockList.data?.list ?? blockList.data ?? []).some?.((u) => u.id === S.A?.id), `count=${blockList.data?.list?.length ?? blockList.data?.length}`);
  const blockedView = await api('GET', `/users/${S.B?.id}`, { token: S.A?.token });
  warn('9. 隐私与安全', '被拉黑方查看对方主页', `isBlocked=${blockedView.data?.isBlocked}（前端据此隐藏内容）`);
  const unblock = await api('DELETE', `/me/block/${S.A?.id}`, { token: S.B?.token });
  assert('9. 隐私与安全', '取消拉黑', unblock.code === 0, `code=${unblock.code}`);
  const dis = await api('POST', `/me/dislike/${post2Id}`, { token: S.B?.token });
  assert('9. 隐私与安全', '不喜欢某帖', dis.code === 0, `code=${dis.code} msg=${dis.message}`);
  const disList = await api('GET', '/me/dislikelist', { token: S.B?.token });
  assert('9. 隐私与安全', '不喜欢列表可读', disList.code === 0, `code=${disList.code}`);
  const undis = await api('DELETE', `/me/dislike/${post2Id}`, { token: S.B?.token });
  assert('9. 隐私与安全', '取消不喜欢', undis.code === 0, `code=${undis.code}`);
  const exp = await api('GET', '/me/export', { token: S.B?.token });
  assert('9. 隐私与安全', '数据导出返回完整结构', exp.code === 0 && exp.data?.profile && Array.isArray(exp.data?.posts), `postsCount=${exp.data?.postsCount}`);
  const likes = await api('GET', '/auth/me/likes', { token: S.A?.token });
  assert('9. 隐私与安全', '「我赞过」可读', likes.code === 0, `code=${likes.code}`);
  const commented = await api('GET', '/auth/me/commented', { token: S.A?.token });
  assert('9. 隐私与安全', '「我评论过」可读', commented.code === 0, `code=${commented.code}`);
  const bindings = await api('GET', '/account/bindings', { token: S.A?.token });
  assert('9. 隐私与安全', '账号绑定列表可读', bindings.code === 0, `code=${bindings.code}`);

  // ---------------- 10. 越权与边界 ----------------
  setSection('10. 越权与边界');
  const delOtherPost = await api('DELETE', `/posts/${postId}`, { token: S.B?.token });
  assert('10. 越权与边界', 'B 删 A 的帖子 → 拒绝', delOtherPost.code !== 0 || delOtherPost.status >= 400, `status=${delOtherPost.status} code=${delOtherPost.code}`);
  const editOtherPost = await api('PUT', `/posts/${postId}`, { token: S.B?.token, body: { title: '越权改标题' } });
  assert('10. 越权与边界', 'B 改 A 的帖子 → 拒绝', editOtherPost.code !== 0 || editOtherPost.status >= 400, `status=${editOtherPost.status} code=${editOtherPost.code}`);
  const delOtherComment = await api('DELETE', `/comments/${commentId}`, { token: S.A?.token });
  assert('10. 越权与边界', 'A 删 B 的评论 → 拒绝', delOtherComment.code !== 0 || delOtherComment.status >= 400, `status=${delOtherComment.status} code=${delOtherComment.code}`);

  // ---------------- 11. 帖生命周期 ----------------
  setSection('11. 帖生命周期');
  const vote = await api('POST', `/posts/${debateId}/vote`, { token: S.B?.token, body: { choice: 'A' } });
  assert('11. 帖生命周期', '辩论帖投票', vote.code === 0, `code=${vote.code} msg=${vote.message}`);
  const report = await api('POST', `/posts/${postId}/report`, { token: S.B?.token, body: { reason: 'spam', description: '自检举报' } });
  assert('11. 帖生命周期', '举报帖子', report.code === 0, `code=${report.code} msg=${report.message}`);
  const delSelf = await api('DELETE', `/posts/${post2Id}`, { token: S.A?.token });
  assert('11. 帖生命周期', 'A 删除自己的帖子（进回收站）', delSelf.code === 0, `code=${delSelf.code} msg=${delSelf.message}`);
  const trash = await api('GET', '/posts/trash', { token: S.A?.token });
  assert('11. 帖生命周期', '回收站含被删帖', trash.code === 0 && (trash.data?.list ?? []).some((p) => p.id === post2Id), `count=${trash.data?.list?.length}`);
  const restore = await api('POST', `/posts/${post2Id}/restore`, { token: S.A?.token });
  assert('11. 帖生命周期', '从回收站恢复', restore.code === 0, `code=${restore.code} msg=${restore.message}`);
  const delAgain = await api('DELETE', `/posts/${post2Id}`, { token: S.A?.token });
  const permanent = await api('DELETE', `/posts/${post2Id}/permanent`, { token: S.A?.token });
  assert('11. 帖生命周期', '彻底删除（不可恢复）', delAgain.code === 0 && permanent.code === 0, `del=${delAgain.code} perm=${permanent.code}`);

  // ---------------- 12. 埋点与推送 ----------------
  setSection('12. 埋点与推送');
  const metric = await api('POST', '/metrics/post-event', { token: S.A?.token, body: { postId, action: 'expose', scene: 'selftest' } });
  assert('12. 埋点与推送', '上报行为埋点', metric.code === 0, `code=${metric.code} msg=${metric.message}`);
  const push = await api('POST', '/push/register', { token: S.A?.token, body: { token: 'selftest-push-token', platform: 'harmonyos' } });
  assert('12. 埋点与推送', '注册推送 Token', push.code === 0, `code=${push.code} msg=${push.message}`);
  // 分享落地页是主站 nginx 静态页（https://youju.chat/post/{id}），不在 API 域内，单独用 curl 验证
  warn('12. 埋点与推送', '分享落地页（主站 /post/{id}）需单独验证', '不在 /v1 API 域');

  // ---------------- 13. 注销 ----------------
  setSection('13. 注销');
  const deact = await api('POST', '/auth/me/deactivate', { token: S.C?.token });
  assert('13. 注销', 'C 注销账号', deact.code === 0, `code=${deact.code} msg=${deact.message}`);
  const afterDeact = await api('GET', '/auth/me', { token: S.C?.token });
  assert('13. 注销', '注销后旧 token 失效（401）', afterDeact.status === 401, `status=${afterDeact.status}`);

  // ---------------- 汇总 ----------------
  const pass = results.filter((r) => r.ok === true).length;
  const fail = results.filter((r) => r.ok === false).length;
  const warnN = results.filter((r) => r.ok === null).length;
  console.log('\n================ 汇总 ================');
  console.log(`✅ 通过 ${pass}   ❌ 失败 ${fail}   ⚠️ 需人工确认 ${warnN}   共 ${results.length} 项`);
  if (fail) {
    console.log('\n失败项：');
    results.filter((r) => r.ok === false).forEach((r) => console.log(` - [${r.section}] ${r.name}${r.detail ? ' — ' + r.detail : ''}`));
  }
  process.exit(fail > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error('脚本异常终止：', e);
  process.exit(2);
});
