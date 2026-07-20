if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface HomeTab_Params {
    posts?: Post[];
    displayTags?: Tag[];
    sortIndex?: number;
    tagIndex?: number;
    page?: number;
    loading?: boolean;
    finished?: boolean;
    isRefreshing?: boolean;
    error?: string;
}
import router from "@ohos:router";
import type { Post, Tag } from '../models/types';
import { listPosts, listTags } from "@normalized:N&&&entry/src/main/ets/services/api&";
import { PostCard } from "@normalized:N&&&entry/src/main/ets/components/PostCard&";
import { TagNav } from "@normalized:N&&&entry/src/main/ets/components/TagNav&";
type SortKey = 'hot' | 'latest' | 'recommend';
const SUB_TABS: string[] = ['热榜', '最新', '推荐'];
const SORT_KEYS: SortKey[] = ['hot', 'latest', 'recommend'];
const ALL_TAG: Tag = { name: '全部', emoji: '🔥' };
export class HomeTab extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__posts = new ObservedPropertyObjectPU([], this, "posts");
        this.__displayTags = new ObservedPropertyObjectPU([], this, "displayTags");
        this.__sortIndex = new ObservedPropertySimplePU(0, this, "sortIndex");
        this.__tagIndex = new ObservedPropertySimplePU(0, this, "tagIndex");
        this.__page = new ObservedPropertySimplePU(1, this, "page");
        this.__loading = new ObservedPropertySimplePU(false, this, "loading");
        this.__finished = new ObservedPropertySimplePU(false, this, "finished");
        this.__isRefreshing = new ObservedPropertySimplePU(false, this, "isRefreshing");
        this.__error = new ObservedPropertySimplePU('', this, "error");
        this.setInitiallyProvidedValue(params);
        this.declareWatch("tagIndex", this.onTagChanged);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: HomeTab_Params) {
        if (params.posts !== undefined) {
            this.posts = params.posts;
        }
        if (params.displayTags !== undefined) {
            this.displayTags = params.displayTags;
        }
        if (params.sortIndex !== undefined) {
            this.sortIndex = params.sortIndex;
        }
        if (params.tagIndex !== undefined) {
            this.tagIndex = params.tagIndex;
        }
        if (params.page !== undefined) {
            this.page = params.page;
        }
        if (params.loading !== undefined) {
            this.loading = params.loading;
        }
        if (params.finished !== undefined) {
            this.finished = params.finished;
        }
        if (params.isRefreshing !== undefined) {
            this.isRefreshing = params.isRefreshing;
        }
        if (params.error !== undefined) {
            this.error = params.error;
        }
    }
    updateStateVars(params: HomeTab_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__posts.purgeDependencyOnElmtId(rmElmtId);
        this.__displayTags.purgeDependencyOnElmtId(rmElmtId);
        this.__sortIndex.purgeDependencyOnElmtId(rmElmtId);
        this.__tagIndex.purgeDependencyOnElmtId(rmElmtId);
        this.__page.purgeDependencyOnElmtId(rmElmtId);
        this.__loading.purgeDependencyOnElmtId(rmElmtId);
        this.__finished.purgeDependencyOnElmtId(rmElmtId);
        this.__isRefreshing.purgeDependencyOnElmtId(rmElmtId);
        this.__error.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__posts.aboutToBeDeleted();
        this.__displayTags.aboutToBeDeleted();
        this.__sortIndex.aboutToBeDeleted();
        this.__tagIndex.aboutToBeDeleted();
        this.__page.aboutToBeDeleted();
        this.__loading.aboutToBeDeleted();
        this.__finished.aboutToBeDeleted();
        this.__isRefreshing.aboutToBeDeleted();
        this.__error.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __posts: ObservedPropertyObjectPU<Post[]>;
    get posts() {
        return this.__posts.get();
    }
    set posts(newValue: Post[]) {
        this.__posts.set(newValue);
    }
    private __displayTags: ObservedPropertyObjectPU<Tag[]>;
    get displayTags() {
        return this.__displayTags.get();
    }
    set displayTags(newValue: Tag[]) {
        this.__displayTags.set(newValue);
    }
    private __sortIndex: ObservedPropertySimplePU<number>;
    get sortIndex() {
        return this.__sortIndex.get();
    }
    set sortIndex(newValue: number) {
        this.__sortIndex.set(newValue);
    }
    private __tagIndex: ObservedPropertySimplePU<number>;
    get tagIndex() {
        return this.__tagIndex.get();
    }
    set tagIndex(newValue: number) {
        this.__tagIndex.set(newValue);
    }
    private __page: ObservedPropertySimplePU<number>;
    get page() {
        return this.__page.get();
    }
    set page(newValue: number) {
        this.__page.set(newValue);
    }
    private __loading: ObservedPropertySimplePU<boolean>;
    get loading() {
        return this.__loading.get();
    }
    set loading(newValue: boolean) {
        this.__loading.set(newValue);
    }
    private __finished: ObservedPropertySimplePU<boolean>;
    get finished() {
        return this.__finished.get();
    }
    set finished(newValue: boolean) {
        this.__finished.set(newValue);
    }
    private __isRefreshing: ObservedPropertySimplePU<boolean>;
    get isRefreshing() {
        return this.__isRefreshing.get();
    }
    set isRefreshing(newValue: boolean) {
        this.__isRefreshing.set(newValue);
    }
    private __error: ObservedPropertySimplePU<string>;
    get error() {
        return this.__error.get();
    }
    set error(newValue: string) {
        this.__error.set(newValue);
    }
    aboutToAppear(): void {
        this.loadTags();
        this.refresh();
    }
    async loadTags(): Promise<void> {
        try {
            const tags = await listTags();
            this.displayTags = [ALL_TAG, ...tags];
        }
        catch (e) {
            // 标签加载失败不阻断列表；保留 "全部"
            this.displayTags = [ALL_TAG];
        }
    }
    // 重置并加载第一页
    async refresh(): Promise<void> {
        this.page = 1;
        this.finished = false;
        await this.fetch(true);
    }
    // 追加下一页
    async loadMore(): Promise<void> {
        if (this.finished || this.loading || this.isRefreshing) {
            return;
        }
        this.page += 1;
        await this.fetch(false);
    }
    onTagChanged(): void {
        this.refresh();
    }
    private currentTag(): string | undefined {
        return this.tagIndex > 0 ? this.displayTags[this.tagIndex]?.name : undefined;
    }
    private async fetch(reset: boolean): Promise<void> {
        if (this.loading) {
            return;
        }
        this.loading = true;
        this.error = '';
        const sort = SORT_KEYS[this.sortIndex];
        try {
            const res = await listPosts({ page: this.page, limit: 20, sort, tag: this.currentTag() });
            if (reset) {
                this.posts = res.list;
            }
            else {
                this.posts = this.posts.concat(res.list);
            }
            if (res.list.length < 20) {
                this.finished = true;
            }
        }
        catch (e) {
            this.error = (e as Error).message;
        }
        finally {
            this.loading = false;
        }
    }
    refreshBuilder(parent = null): void {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/components/HomeTab.ets(92:5)", "entry");
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            LoadingProgress.create();
            LoadingProgress.debugLine("entry/src/main/ets/components/HomeTab.ets(93:7)", "entry");
            LoadingProgress.width(20);
            LoadingProgress.height(20);
        }, LoadingProgress);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('刷新中…');
            Text.debugLine("entry/src/main/ets/components/HomeTab.ets(94:7)", "entry");
            Text.fontSize(12);
            Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
        }, Text);
        Text.pop();
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/components/HomeTab.ets(99:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.alignItems(HorizontalAlign.Start);
            Column.backgroundColor({ "id": 16777226, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部大标题
            Text.create('大蓝书');
            Text.debugLine("entry/src/main/ets/components/HomeTab.ets(101:7)", "entry");
            // 顶部大标题
            Text.fontSize(34);
            // 顶部大标题
            Text.fontWeight(FontWeight.Bold);
            // 顶部大标题
            Text.fontColor({ "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
            // 顶部大标题
            Text.padding({ left: 16, top: 6, bottom: 6 });
        }, Text);
        // 顶部大标题
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 三子 Tab（下划线指示器）
            Row.create({ space: 24 });
            Row.debugLine("entry/src/main/ets/components/HomeTab.ets(108:7)", "entry");
            // 三子 Tab（下划线指示器）
            Row.padding({ left: 16, bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = (_item, idx: number) => {
                const name = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.debugLine("entry/src/main/ets/components/HomeTab.ets(110:11)", "entry");
                    Column.onClick(() => {
                        if (this.sortIndex !== idx) {
                            this.sortIndex = idx;
                            this.refresh();
                        }
                    });
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(name);
                    Text.debugLine("entry/src/main/ets/components/HomeTab.ets(111:13)", "entry");
                    Text.fontSize(16);
                    Text.fontWeight(this.sortIndex === idx ? FontWeight.Bold : FontWeight.Medium);
                    Text.fontColor(this.sortIndex === idx ? { "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" } : { "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    Text.padding({ bottom: 6 });
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (this.sortIndex === idx) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Divider.create();
                                Divider.debugLine("entry/src/main/ets/components/HomeTab.ets(117:15)", "entry");
                                Divider.width(20);
                                Divider.height(2);
                                Divider.color({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                            }, Divider);
                        });
                    }
                    else {
                        this.ifElseBranchUpdateFunction(1, () => {
                        });
                    }
                }, If);
                If.pop();
                Column.pop();
            };
            this.forEachUpdateFunction(elmtId, SUB_TABS, forEachItemGenFunction, (name: string) => name, true, false);
        }, ForEach);
        ForEach.pop();
        // 三子 Tab（下划线指示器）
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.padding({ bottom: 8 });
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // 标签筛选栏
                    TagNav(this, {
                        tags: this.displayTags,
                        selectedIndex: this.__tagIndex
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/components/HomeTab.ets", line: 131, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            tags: this.displayTags,
                            selectedIndex: this.tagIndex
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        tags: this.displayTags
                    });
                }
            }, { name: "TagNav" });
        }
        __Common__.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 列表区
            if (this.posts.length === 0 && this.loading) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/components/HomeTab.ets(139:9)", "entry");
                        Column.layoutWeight(1);
                        Column.width('100%');
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.debugLine("entry/src/main/ets/components/HomeTab.ets(140:11)", "entry");
                        LoadingProgress.width(28);
                        LoadingProgress.height(28);
                    }, LoadingProgress);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('加载中…');
                        Text.debugLine("entry/src/main/ets/components/HomeTab.ets(141:11)", "entry");
                        Text.fontSize(13);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                        Text.margin({ top: 10 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
            else if (this.posts.length === 0) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/components/HomeTab.ets(147:9)", "entry");
                        Column.layoutWeight(1);
                        Column.width('100%');
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.error ? ('加载失败：' + this.error) : '暂无内容');
                        Text.debugLine("entry/src/main/ets/components/HomeTab.ets(148:11)", "entry");
                        Text.fontSize(14);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Refresh.create({ refreshing: this.isRefreshing, builder: this.refreshBuilder.bind(this) });
                        Refresh.debugLine("entry/src/main/ets/components/HomeTab.ets(156:9)", "entry");
                        Refresh.onRefreshing(() => {
                            this.isRefreshing = true;
                            this.refresh().finally(() => {
                                this.isRefreshing = false;
                            });
                        });
                        Refresh.layoutWeight(1);
                        Refresh.width('100%');
                    }, Refresh);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Grid.create();
                        Grid.debugLine("entry/src/main/ets/components/HomeTab.ets(157:11)", "entry");
                        Grid.columnsTemplate('1fr 1fr');
                        Grid.columnsGap(12);
                        Grid.rowsGap(12);
                        Grid.padding(12);
                        Grid.onScrollIndex((_start: number, end: number) => {
                            if (end >= this.posts.length - 1) {
                                this.loadMore();
                            }
                        });
                    }, Grid);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const post = _item;
                            {
                                const itemCreation2 = (elmtId, isInitialRender) => {
                                    GridItem.create(() => { }, false);
                                    GridItem.debugLine("entry/src/main/ets/components/HomeTab.ets(161:17)", "entry");
                                };
                                const observedDeepRender = () => {
                                    this.observeComponentCreation2(itemCreation2, GridItem);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        __Common__.create();
                                        __Common__.onClick(() => {
                                            if (post.id !== undefined) {
                                                router.pushUrl({ url: 'pages/DetailPage', params: { id: post.id.toString() } });
                                            }
                                        });
                                    }, __Common__);
                                    {
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            if (isInitialRender) {
                                                let componentCall = new PostCard(this, { post: post }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/components/HomeTab.ets", line: 162, col: 19 });
                                                ViewPU.create(componentCall);
                                                let paramsLambda = () => {
                                                    return {
                                                        post: post
                                                    };
                                                };
                                                componentCall.paramsGenerator_ = paramsLambda;
                                            }
                                            else {
                                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                                    post: post
                                                });
                                            }
                                        }, { name: "PostCard" });
                                    }
                                    __Common__.pop();
                                    GridItem.pop();
                                };
                                observedDeepRender();
                            }
                        };
                        this.forEachUpdateFunction(elmtId, this.posts, forEachItemGenFunction, (post: Post) => post.id?.toString() ?? '', false, false);
                    }, ForEach);
                    ForEach.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        if (this.finished) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                {
                                    const itemCreation2 = (elmtId, isInitialRender) => {
                                        GridItem.create(() => { }, false);
                                        GridItem.columnStart(0);
                                        GridItem.columnEnd(1);
                                        GridItem.debugLine("entry/src/main/ets/components/HomeTab.ets(173:15)", "entry");
                                    };
                                    const observedDeepRender = () => {
                                        this.observeComponentCreation2(itemCreation2, GridItem);
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Text.create('没有更多了');
                                            Text.debugLine("entry/src/main/ets/components/HomeTab.ets(174:17)", "entry");
                                            Text.fontSize(12);
                                            Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                            Text.width('100%');
                                            Text.textAlign(TextAlign.Center);
                                            Text.padding(16);
                                        }, Text);
                                        Text.pop();
                                        GridItem.pop();
                                    };
                                    observedDeepRender();
                                }
                            });
                        }
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    Grid.pop();
                    Refresh.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
