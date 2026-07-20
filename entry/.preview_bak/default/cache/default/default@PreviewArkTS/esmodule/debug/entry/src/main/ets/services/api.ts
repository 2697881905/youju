import http from "@ohos:net.http";
import type { Post, Comment, Tag, User, Pagination, Genre } from '../models/types';
// 本地后端地址（按运行环境替换）：
// - 鸿蒙模拟器访问宿主机：'http://10.0.2.2:3000'
// - 真机/同局域网：'http://<你电脑局域网IP>:3000'
// - 上架后：'https://api.bigbluebook.com'
const BASE_URL = 'http://10.0.2.2:3000';
let authToken: string = '';
export function setToken(t: string): void { authToken = t; }
export function getToken(): string { return authToken; }
export interface ApiResult<T> {
    code: number;
    data: T;
    message: string;
}
async function request<T>(method: http.RequestMethod, path: string, body?: Object): Promise<T> {
    const url = BASE_URL + path;
    const req = http.createHttp();
    const header: Record<string, string> = { 'Content-Type': 'application/json' };
    if (authToken) {
        header['Authorization'] = 'Bearer ' + authToken;
    }
    try {
        const resp = await req.request(url, {
            method,
            header,
            extraData: body ? JSON.stringify(body) : undefined,
            expectDataType: http.HttpDataType.OBJECT,
            connectTimeout: 10000,
            readTimeout: 10000,
        });
        if (resp.responseCode !== 200) {
            throw new Error('HTTP ' + resp.responseCode);
        }
        const result = resp.result as ApiResult<T>;
        if (result.code !== 0) {
            throw new Error(result.message || '请求失败');
        }
        return result.data;
    }
    finally {
        req.destroy();
    }
}
interface ApiClient {
    get: <T>(path: string) => Promise<T>;
    post: <T>(path: string, body?: Object) => Promise<T>;
    put: <T>(path: string, body?: Object) => Promise<T>;
    del: <T>(path: string) => Promise<T>;
}
export const api: ApiClient = {
    get: <T>(path: string): Promise<T> => request<T>(http.RequestMethod.GET, path),
    post: <T>(path: string, body?: Object): Promise<T> => request<T>(http.RequestMethod.POST, path, body),
    put: <T>(path: string, body?: Object): Promise<T> => request<T>(http.RequestMethod.PUT, path, body),
    del: <T>(path: string): Promise<T> => request<T>(http.RequestMethod.DELETE, path),
};
// ===== 领域类型 =====
export type SortType = 'hot' | 'latest' | 'recommend';
export interface ListResult<T> {
    list: T[];
    pagination: Pagination;
}
// 详情接口返回的帖子自带 comments（后端 getPost include comments）
export interface PostWithComments extends Post {
    comments?: Comment[];
}
export interface ListPostsParams {
    page?: number;
    limit?: number;
    sort?: SortType;
    tag?: string;
}
export interface CreatePostBody {
    title: string;
    content?: string;
    coverImage?: string;
    images?: string[];
    genre: Genre;
    tags: string[];
    structuredData?: Object;
}
export interface CreateCommentBody {
    content: string;
    parentId?: number;
    isFact?: boolean;
}
export interface LoginBody {
    openId: string;
    nickname?: string;
    avatar?: string;
}
export interface LoginResult {
    token: string;
    user: User;
}
export interface UploadToken {
    provider: string;
    bucket?: string;
    region?: string;
    endpoint?: string;
    cdnBase?: string;
}
// 拼接 query string（跳过 undefined/null/空串）
function toQuery(fields: Array<[
    string,
    string | number | undefined
]>): string {
    const parts: string[] = [];
    for (const f of fields) {
        const v = f[1];
        if (v !== undefined && v !== null && v !== '') {
            parts.push(f[0] + '=' + encodeURIComponent(String(v)));
        }
    }
    return parts.length > 0 ? '?' + parts.join('&') : '';
}
// ===== 帖子 =====
// GET /v1/posts?page=&limit=&sort=hot|latest|recommend&tag=
export function listPosts(params: ListPostsParams = {}): Promise<ListResult<Post>> {
    const path = '/v1/posts' + toQuery([
        ['page', params.page],
        ['limit', params.limit],
        ['sort', params.sort],
        ['tag', params.tag],
    ]);
    return api.get<ListResult<Post>>(path);
}
// GET /v1/posts/:id（含 comments）
export function getPost(id: number): Promise<PostWithComments> {
    return api.get<PostWithComments>('/v1/posts/' + id);
}
// POST /v1/posts（进入待审核）
export function createPost(body: CreatePostBody): Promise<Post> {
    return api.post<Post>('/v1/posts', body);
}
// DELETE /v1/posts/:id（仅本人）
export async function deletePost(id: number): Promise<void> {
    await api.del<null>('/v1/posts/' + id);
}
// ===== 评论 =====
// GET /v1/posts/:id/comments?page=
export function listComments(postId: number, page?: number): Promise<ListResult<Comment>> {
    const path = '/v1/posts/' + postId + '/comments' + toQuery([['page', page]]);
    return api.get<ListResult<Comment>>(path);
}
// POST /v1/posts/:id/comments
export function createComment(postId: number, body: CreateCommentBody): Promise<Comment> {
    return api.post<Comment>('/v1/posts/' + postId + '/comments', body);
}
// DELETE /v1/comments/:id（仅本人）
export async function deleteComment(id: number): Promise<void> {
    await api.del<null>('/v1/comments/' + id);
}
// ===== 互动 =====
// POST/DELETE /v1/posts/:id/up
export async function upPost(id: number): Promise<void> {
    await api.post<null>('/v1/posts/' + id + '/up');
}
export async function cancelUpPost(id: number): Promise<void> {
    await api.del<null>('/v1/posts/' + id + '/up');
}
// POST/DELETE /v1/posts/:id/bookmark
export async function bookmarkPost(id: number): Promise<void> {
    await api.post<null>('/v1/posts/' + id + '/bookmark');
}
export async function cancelBookmarkPost(id: number): Promise<void> {
    await api.del<null>('/v1/posts/' + id + '/bookmark');
}
// ===== 标签 =====
// GET /v1/tags
export function listTags(): Promise<Tag[]> {
    return api.get<Tag[]>('/v1/tags');
}
// ===== 用户 / 鉴权 =====
// POST /v1/auth/login（成功后自动缓存 token）
export function login(body: LoginBody): Promise<LoginResult> {
    return api.post<LoginResult>('/v1/auth/login', body).then((r: LoginResult) => {
        setToken(r.token);
        return r;
    });
}
// GET /v1/auth/me
export function getMe(): Promise<User> {
    return api.get<User>('/v1/auth/me');
}
// PUT /v1/auth/me
export interface UpdateMeBody {
    nickname?: string;
    avatar?: string;
}
export function updateMe(body: UpdateMeBody): Promise<User> {
    return api.put<User>('/v1/auth/me', body);
}
// ===== 上传 =====
// POST /v1/upload/token（OSS/OBS 直传凭证，待配置云厂商）
export function getUploadToken(): Promise<UploadToken> {
    return api.post<UploadToken>('/v1/upload/token');
}
