if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface DetailPage_Params {
    postId?: string;
    post?: PostWithComments | null;
    fields?: FieldPair[];
    images?: string[];
    loading?: boolean;
    error?: string;
    uped?: boolean;
    bookmarked?: boolean;
    commenting?: boolean;
    commentText?: string;
}
import router from "@ohos:router";
import promptAction from "@ohos:promptAction";
import { getPost, createComment, upPost, cancelUpPost, bookmarkPost, cancelBookmarkPost, } from "@normalized:N&&&entry/src/main/ets/services/api&";
import type { PostWithComments } from "@normalized:N&&&entry/src/main/ets/services/api&";
import type { Genre, StructuredData } from '../models/types';
import { timeAgo, formatCount } from "@normalized:N&&&entry/src/main/ets/utils/format&";
import { CommentList } from "@normalized:N&&&entry/src/main/ets/components/CommentList&";
// 字段定义：[结构化字段键, 中文标签]，按产品文档 2.4 各体裁字段表
type FieldDef = [
    keyof StructuredData,
    string
];
// 渲染用：[中文标签, 值]
type FieldPair = [
    string,
    string
];
// ArkTS V1 禁止按变量索引对象，这里用显式 switch 读取结构化字段
function readField(sd: StructuredData, key: keyof StructuredData): string | number | undefined {
    switch (key) {
        case 'pros':
            return sd.pros;
        case 'cons':
            return sd.cons;
        case 'rating':
            return sd.rating;
        case 'targetAudience':
            return sd.targetAudience;
        case 'pitfallExperience':
            return sd.pitfallExperience;
        case 'lossAmount':
            return sd.lossAmount;
        case 'correctApproach':
            return sd.correctApproach;
        case 'tools':
            return sd.tools;
        case 'steps':
            return sd.steps;
        case 'timeDifficulty':
            return sd.timeDifficulty;
        case 'planA':
            return sd.planA;
        case 'planB':
            return sd.planB;
        default:
            return undefined;
    }
}
interface GenreMeta {
    label: string;
    icon: string;
}
function genreMeta(genre?: Genre): GenreMeta {
    switch (genre) {
        case 'review':
            return { label: '测评报告', icon: '📊' };
        case 'pitfall':
            return { label: '避坑指南', icon: '⚠️' };
        case 'tutorial':
            return { label: '实操教程', icon: '🛠️' };
        case 'debate':
            return { label: '辩论投票', icon: '🗳️' };
        default:
            return { label: '经验分享', icon: '📝' };
    }
}
function structuredFieldDefs(genre?: Genre): FieldDef[] {
    switch (genre) {
        case 'review':
            return [['pros', '优点'], ['cons', '缺点'], ['rating', '推荐指数'], ['targetAudience', '适合人群']];
        case 'pitfall':
            return [['pitfallExperience', '踩坑经历'], ['lossAmount', '损失金额'], ['correctApproach', '正确做法']];
        case 'tutorial':
            return [['tools', '准备工具'], ['steps', '步骤拆解'], ['timeDifficulty', '耗时/难度']];
        case 'debate':
            return [['planA', '方案A'], ['planB', '方案B']];
        default:
            return [];
    }
}
class DetailPage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__postId = new ObservedPropertySimplePU((router.getParams() as Record<string, string>)?.id ?? '', this, "postId");
        this.__post = new ObservedPropertyObjectPU(null, this, "post");
        this.__fields = new ObservedPropertyObjectPU([], this, "fields");
        this.__images = new ObservedPropertyObjectPU([], this, "images");
        this.__loading = new ObservedPropertySimplePU(true, this, "loading");
        this.__error = new ObservedPropertySimplePU('', this, "error");
        this.__uped = new ObservedPropertySimplePU(false, this, "uped");
        this.__bookmarked = new ObservedPropertySimplePU(false, this, "bookmarked");
        this.__commenting = new ObservedPropertySimplePU(false, this, "commenting");
        this.__commentText = new ObservedPropertySimplePU('', this, "commentText");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: DetailPage_Params) {
        if (params.postId !== undefined) {
            this.postId = params.postId;
        }
        if (params.post !== undefined) {
            this.post = params.post;
        }
        if (params.fields !== undefined) {
            this.fields = params.fields;
        }
        if (params.images !== undefined) {
            this.images = params.images;
        }
        if (params.loading !== undefined) {
            this.loading = params.loading;
        }
        if (params.error !== undefined) {
            this.error = params.error;
        }
        if (params.uped !== undefined) {
            this.uped = params.uped;
        }
        if (params.bookmarked !== undefined) {
            this.bookmarked = params.bookmarked;
        }
        if (params.commenting !== undefined) {
            this.commenting = params.commenting;
        }
        if (params.commentText !== undefined) {
            this.commentText = params.commentText;
        }
    }
    updateStateVars(params: DetailPage_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__postId.purgeDependencyOnElmtId(rmElmtId);
        this.__post.purgeDependencyOnElmtId(rmElmtId);
        this.__fields.purgeDependencyOnElmtId(rmElmtId);
        this.__images.purgeDependencyOnElmtId(rmElmtId);
        this.__loading.purgeDependencyOnElmtId(rmElmtId);
        this.__error.purgeDependencyOnElmtId(rmElmtId);
        this.__uped.purgeDependencyOnElmtId(rmElmtId);
        this.__bookmarked.purgeDependencyOnElmtId(rmElmtId);
        this.__commenting.purgeDependencyOnElmtId(rmElmtId);
        this.__commentText.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__postId.aboutToBeDeleted();
        this.__post.aboutToBeDeleted();
        this.__fields.aboutToBeDeleted();
        this.__images.aboutToBeDeleted();
        this.__loading.aboutToBeDeleted();
        this.__error.aboutToBeDeleted();
        this.__uped.aboutToBeDeleted();
        this.__bookmarked.aboutToBeDeleted();
        this.__commenting.aboutToBeDeleted();
        this.__commentText.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __postId: ObservedPropertySimplePU<string>;
    get postId() {
        return this.__postId.get();
    }
    set postId(newValue: string) {
        this.__postId.set(newValue);
    }
    private __post: ObservedPropertyObjectPU<PostWithComments | null>;
    get post() {
        return this.__post.get();
    }
    set post(newValue: PostWithComments | null) {
        this.__post.set(newValue);
    }
    private __fields: ObservedPropertyObjectPU<FieldPair[]>;
    get fields() {
        return this.__fields.get();
    }
    set fields(newValue: FieldPair[]) {
        this.__fields.set(newValue);
    }
    private __images: ObservedPropertyObjectPU<string[]>;
    get images() {
        return this.__images.get();
    }
    set images(newValue: string[]) {
        this.__images.set(newValue);
    }
    private __loading: ObservedPropertySimplePU<boolean>;
    get loading() {
        return this.__loading.get();
    }
    set loading(newValue: boolean) {
        this.__loading.set(newValue);
    }
    private __error: ObservedPropertySimplePU<string>;
    get error() {
        return this.__error.get();
    }
    set error(newValue: string) {
        this.__error.set(newValue);
    }
    private __uped: ObservedPropertySimplePU<boolean>;
    get uped() {
        return this.__uped.get();
    }
    set uped(newValue: boolean) {
        this.__uped.set(newValue);
    }
    private __bookmarked: ObservedPropertySimplePU<boolean>;
    get bookmarked() {
        return this.__bookmarked.get();
    }
    set bookmarked(newValue: boolean) {
        this.__bookmarked.set(newValue);
    }
    private __commenting: ObservedPropertySimplePU<boolean>;
    get commenting() {
        return this.__commenting.get();
    }
    set commenting(newValue: boolean) {
        this.__commenting.set(newValue);
    }
    private __commentText: ObservedPropertySimplePU<string>;
    get commentText() {
        return this.__commentText.get();
    }
    set commentText(newValue: string) {
        this.__commentText.set(newValue);
    }
    aboutToAppear(): void {
        this.load();
    }
    async load(): Promise<void> {
        if (!this.postId || isNaN(this.pid)) {
            this.loading = false;
            this.error = '帖子参数缺失';
            return;
        }
        this.loading = true;
        this.error = '';
        try {
            const p = await getPost(this.pid);
            if (!p) {
                this.error = '帖子不存在或已下架';
                return;
            }
            this.post = p;
            this.fields = this.buildFields(p);
            this.images = this.imagesOf(p);
        }
        catch (e) {
            this.error = (e as Error).message;
        }
        finally {
            this.loading = false;
        }
    }
    // 把后端自由结构的结构化字段，按体裁映射成 [中文标签, 值] 列表
    private buildFields(p: PostWithComments): FieldPair[] {
        const defs = structuredFieldDefs(p.genre);
        if (defs.length === 0) {
            return [];
        }
        const sd: StructuredData | undefined = p.structuredData;
        const out: FieldPair[] = [];
        if (sd) {
            for (const item of defs) {
                const raw = readField(sd, item[0]);
                if (raw !== undefined && raw !== null) {
                    out.push([item[1], String(raw)]);
                }
            }
        }
        return out;
    }
    private imagesOf(p: PostWithComments): string[] {
        const imgs = p.images ?? [];
        if (imgs.length === 0 && p.coverImage) {
            return [p.coverImage];
        }
        return imgs;
    }
    async onUp(): Promise<void> {
        if (!this.post || this.post.id === undefined) {
            return;
        }
        const id = this.post.id;
        const willUp = !this.uped;
        this.uped = willUp;
        this.post.upCount = (this.post.upCount ?? 0) + (willUp ? 1 : -1);
        try {
            if (willUp) {
                await upPost(id);
            }
            else {
                await cancelUpPost(id);
            }
        }
        catch (e) {
            this.uped = !willUp;
            this.post.upCount = (this.post.upCount ?? 0) + (willUp ? -1 : 1);
            promptAction.showToast({ message: '操作失败，请先登录' });
        }
    }
    async onBookmark(): Promise<void> {
        if (!this.post || this.post.id === undefined) {
            return;
        }
        const id = this.post.id;
        const willMark = !this.bookmarked;
        this.bookmarked = willMark;
        this.post.bookmarkCount = (this.post.bookmarkCount ?? 0) + (willMark ? 1 : -1);
        try {
            if (willMark) {
                await bookmarkPost(id);
            }
            else {
                await cancelBookmarkPost(id);
            }
        }
        catch (e) {
            this.bookmarked = !willMark;
            this.post.bookmarkCount = (this.post.bookmarkCount ?? 0) + (willMark ? -1 : 1);
            promptAction.showToast({ message: '操作失败，请先登录' });
        }
    }
    onShare(): void {
        promptAction.showToast({ message: '分享功能开发中' });
    }
    async onSendComment(): Promise<void> {
        const text = this.commentText.trim();
        if (!text || !this.post || this.post.id === undefined) {
            return;
        }
        try {
            await createComment(this.post.id, { content: text });
            this.commentText = '';
            this.commenting = false;
            await this.load();
        }
        catch (e) {
            promptAction.showToast({ message: '评论失败，请先登录' });
        }
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(223:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor({ "id": 16777226, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部导航
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/DetailPage.ets(225:7)", "entry");
            // 顶部导航
            Row.width('100%');
            // 顶部导航
            Row.padding({ top: 12, bottom: 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('← 返回');
            Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(226:9)", "entry");
            Text.fontSize(16);
            Text.fontColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
            Text.onClick(() => router.back());
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('帖子详情');
            Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(230:9)", "entry");
            Text.fontSize(17);
            Text.fontWeight(600);
            Text.layoutWeight(1);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('');
            Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(235:9)", "entry");
            Text.width(48);
        }, Text);
        Text.pop();
        // 顶部导航
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.loading) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(242:9)", "entry");
                        Column.layoutWeight(1);
                        Column.width('100%');
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.debugLine("entry/src/main/ets/pages/DetailPage.ets(243:11)", "entry");
                        LoadingProgress.width(28);
                        LoadingProgress.height(28);
                    }, LoadingProgress);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('加载中…');
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(244:11)", "entry");
                        Text.fontSize(13);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                        Text.margin({ top: 10 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
            else if (this.error) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(253:9)", "entry");
                        Column.layoutWeight(1);
                        Column.width('100%');
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.error);
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(254:11)", "entry");
                        Text.fontSize(14);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('重试');
                        Button.debugLine("entry/src/main/ets/pages/DetailPage.ets(257:11)", "entry");
                        Button.margin({ top: 16 });
                        Button.onClick(() => this.load());
                    }, Button);
                    Button.pop();
                    Column.pop();
                });
            }
            else if (this.post) {
                this.ifElseBranchUpdateFunction(2, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Scroll.create();
                        Scroll.debugLine("entry/src/main/ets/pages/DetailPage.ets(265:9)", "entry");
                        Scroll.layoutWeight(1);
                        Scroll.width('100%');
                    }, Scroll);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 16 });
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(266:11)", "entry");
                        Column.padding(16);
                        Column.width('100%');
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 标签 + 体裁 + 标题 + 作者
                        Column.create({ space: 8 });
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(268:13)", "entry");
                        // 标签 + 体裁 + 标题 + 作者
                        Column.width('100%');
                        // 标签 + 体裁 + 标题 + 作者
                        Column.alignItems(HorizontalAlign.Start);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        if (this.post.tags && this.post.tags.length > 0) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Row.create({ space: 8 });
                                    Row.debugLine("entry/src/main/ets/pages/DetailPage.ets(270:17)", "entry");
                                }, Row);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    ForEach.create();
                                    const forEachItemGenFunction = _item => {
                                        const t = _item;
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Text.create(t.startsWith('#') ? t : ('#' + t));
                                            Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(274:23)", "entry");
                                            Text.fontSize(13);
                                            Text.fontColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                        }, Text);
                                        Text.pop();
                                    };
                                    this.forEachUpdateFunction(elmtId, this.post.tags, forEachItemGenFunction, (t: string) => t, false, false);
                                }, ForEach);
                                ForEach.pop();
                                Row.pop();
                            });
                        }
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/DetailPage.ets(282:15)", "entry");
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(genreMeta(this.post.genre).icon + ' ' + genreMeta(this.post.genre).label);
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(283:17)", "entry");
                        Text.fontSize(12);
                        Text.fontColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                        Text.backgroundColor('#E8F1FF');
                        Text.borderRadius(4);
                        Text.padding({ left: 8, right: 8, top: 3, bottom: 3 });
                    }, Text);
                    Text.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.post.title ?? '');
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(290:15)", "entry");
                        Text.fontSize(20);
                        Text.fontWeight(700);
                        Text.fontColor({ "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 8 });
                        Row.debugLine("entry/src/main/ets/pages/DetailPage.ets(294:15)", "entry");
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.post.user?.nickname ?? '匿名用户');
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(295:17)", "entry");
                        Text.fontSize(13);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(timeAgo(this.post.createdAt));
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(298:17)", "entry");
                        Text.fontSize(13);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    Row.pop();
                    // 标签 + 体裁 + 标题 + 作者
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        // 九宫格图
                        if (this.images.length > 0) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Flex.create({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween });
                                    Flex.debugLine("entry/src/main/ets/pages/DetailPage.ets(308:15)", "entry");
                                    Flex.width('100%');
                                }, Flex);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    ForEach.create();
                                    const forEachItemGenFunction = _item => {
                                        const url = _item;
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Image.create(url);
                                            Image.debugLine("entry/src/main/ets/pages/DetailPage.ets(312:21)", "entry");
                                            Image.width('32%');
                                            Image.aspectRatio(1);
                                            Image.objectFit(ImageFit.Cover);
                                            Image.borderRadius(8);
                                        }, Image);
                                    };
                                    this.forEachUpdateFunction(elmtId, this.images, forEachItemGenFunction, (url: string) => url, false, false);
                                }, ForEach);
                                ForEach.pop();
                                Flex.pop();
                            });
                        }
                        // 结构化字段
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        // 结构化字段
                        if (this.fields.length > 0) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Column.create({ space: 10 });
                                    Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(326:15)", "entry");
                                    Column.width('100%');
                                    Column.padding(14);
                                    Column.backgroundColor({ "id": 16777228, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                    Column.borderRadius(12);
                                }, Column);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    ForEach.create();
                                    const forEachItemGenFunction = _item => {
                                        const f = _item;
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Row.create({ space: 8 });
                                            Row.debugLine("entry/src/main/ets/pages/DetailPage.ets(330:21)", "entry");
                                            Row.width('100%');
                                            Row.alignItems(VerticalAlign.Top);
                                        }, Row);
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Text.create(f[0]);
                                            Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(331:23)", "entry");
                                            Text.fontSize(14);
                                            Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                            Text.width(76);
                                        }, Text);
                                        Text.pop();
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Text.create(f[1]);
                                            Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(335:23)", "entry");
                                            Text.fontSize(14);
                                            Text.fontColor({ "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                            Text.layoutWeight(1);
                                        }, Text);
                                        Text.pop();
                                        Row.pop();
                                    };
                                    this.forEachUpdateFunction(elmtId, this.fields, forEachItemGenFunction, (f: FieldPair) => f[0], false, false);
                                }, ForEach);
                                ForEach.pop();
                                Column.pop();
                            });
                        }
                        // 正文
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        // 正文
                        if (this.post.content) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Text.create(this.post.content);
                                    Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(354:15)", "entry");
                                    Text.fontSize(15);
                                    Text.fontColor({ "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                    Text.lineHeight(24);
                                    Text.width('100%');
                                }, Text);
                                Text.pop();
                            });
                        }
                        // 评论区
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 评论区
                        Column.create({ space: 10 });
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(362:13)", "entry");
                        // 评论区
                        Column.width('100%');
                        // 评论区
                        Column.alignItems(HorizontalAlign.Start);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('评论 ' + formatCount(this.post.commentCount));
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(363:15)", "entry");
                        Text.fontSize(16);
                        Text.fontWeight(600);
                        Text.fontColor({ "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new CommentList(this, { comments: this.post.comments ?? [] }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/DetailPage.ets", line: 367, col: 15 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        comments: this.post.comments ?? []
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    comments: this.post.comments ?? []
                                });
                            }
                        }, { name: "CommentList" });
                    }
                    // 评论区
                    Column.pop();
                    Column.pop();
                    Scroll.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        // 评论输入框
                        if (this.commenting) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Row.create({ space: 8 });
                                    Row.debugLine("entry/src/main/ets/pages/DetailPage.ets(380:11)", "entry");
                                    Row.width('100%');
                                    Row.padding({ left: 12, right: 12, top: 8, bottom: 8 });
                                    Row.backgroundColor({ "id": 16777228, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                }, Row);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    TextInput.create({ placeholder: '理性补充，有图有真相', text: this.commentText });
                                    TextInput.debugLine("entry/src/main/ets/pages/DetailPage.ets(381:13)", "entry");
                                    TextInput.layoutWeight(1);
                                    TextInput.height(40);
                                    TextInput.backgroundColor({ "id": 16777226, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                    TextInput.borderRadius(20);
                                    TextInput.onChange((v: string) => {
                                        this.commentText = v;
                                    });
                                }, TextInput);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Button.createWithLabel('发送');
                                    Button.debugLine("entry/src/main/ets/pages/DetailPage.ets(389:13)", "entry");
                                    Button.height(36);
                                    Button.onClick(() => this.onSendComment());
                                }, Button);
                                Button.pop();
                                Row.pop();
                            });
                        }
                        // 底部操作栏
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 底部操作栏
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/DetailPage.ets(399:9)", "entry");
                        // 底部操作栏
                        Row.width('100%');
                        // 底部操作栏
                        Row.padding({ top: 8, bottom: 12 });
                        // 底部操作栏
                        Row.backgroundColor({ "id": 16777228, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                        // 底部操作栏
                        Row.borderWidth({ top: 0.5 });
                        // 底部操作栏
                        Row.borderColor({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 2 });
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(400:11)", "entry");
                        Column.layoutWeight(1);
                        Column.onClick(() => this.onUp());
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('👍');
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(401:13)", "entry");
                        Text.fontSize(20);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create((this.uped ? '已' : '') + '顶 ' + formatCount(this.post.upCount));
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(402:13)", "entry");
                        Text.fontSize(11);
                        Text.fontColor(this.uped ? { "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" } : { "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 2 });
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(409:11)", "entry");
                        Column.layoutWeight(1);
                        Column.onClick(() => this.onBookmark());
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('📥');
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(410:13)", "entry");
                        Text.fontSize(20);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create((this.bookmarked ? '已' : '') + '抄作业 ' + formatCount(this.post.bookmarkCount));
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(411:13)", "entry");
                        Text.fontSize(11);
                        Text.fontColor(this.bookmarked ? { "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" } : { "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 2 });
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(418:11)", "entry");
                        Column.layoutWeight(1);
                        Column.onClick(() => {
                            this.commenting = true;
                        });
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('💬');
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(419:13)", "entry");
                        Text.fontSize(20);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('评论 ' + formatCount(this.post.commentCount));
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(420:13)", "entry");
                        Text.fontSize(11);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 2 });
                        Column.debugLine("entry/src/main/ets/pages/DetailPage.ets(429:11)", "entry");
                        Column.layoutWeight(1);
                        Column.onClick(() => this.onShare());
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('🔗');
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(430:13)", "entry");
                        Text.fontSize(20);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('分享');
                        Text.debugLine("entry/src/main/ets/pages/DetailPage.ets(431:13)", "entry");
                        Text.fontSize(11);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    Column.pop();
                    // 底部操作栏
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(3, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "DetailPage";
    }
}
registerNamedRoute(() => new DetailPage(undefined, {}), "", { bundleName: "com.bigbluebook.app", moduleName: "entry", pagePath: "pages/DetailPage", pageFullPath: "entry/src/main/ets/pages/DetailPage", integratedHsp: "false", moduleType: "followWithHap" });
