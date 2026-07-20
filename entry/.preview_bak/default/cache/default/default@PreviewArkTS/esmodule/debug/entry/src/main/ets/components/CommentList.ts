if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CommentList_Params {
    comments?: Comment[];
}
import type { Comment } from '../models/types';
import { timeAgo, formatCount } from "@normalized:N&&&entry/src/main/ets/utils/format&";
export class CommentList extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__comments = new SynchedPropertyObjectOneWayPU(params.comments, this, "comments");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CommentList_Params) {
        if (params.comments === undefined) {
            this.__comments.set([]);
        }
    }
    updateStateVars(params: CommentList_Params) {
        this.__comments.reset(params.comments);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__comments.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__comments.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __comments: SynchedPropertySimpleOneWayPU<Comment[]>;
    get comments() {
        return this.__comments.get();
    }
    set comments(newValue: Comment[]) {
        this.__comments.set(newValue);
    }
    avatar(c: Comment, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (c.user?.avatar) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Image.create(c.user.avatar);
                        Image.debugLine("entry/src/main/ets/components/CommentList.ets(12:7)", "entry");
                        Image.width(36);
                        Image.height(36);
                        Image.borderRadius(18);
                        Image.objectFit(ImageFit.Cover);
                    }, Image);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create((c.user?.nickname ?? '匿').slice(0, 1));
                        Text.debugLine("entry/src/main/ets/components/CommentList.ets(18:7)", "entry");
                        Text.width(36);
                        Text.height(36);
                        Text.borderRadius(18);
                        Text.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                        Text.fontColor(Color.White);
                        Text.fontSize(14);
                        Text.textAlign(TextAlign.Center);
                    }, Text);
                    Text.pop();
                });
            }
        }, If);
        If.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("entry/src/main/ets/components/CommentList.ets(30:5)", "entry");
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.comments.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('还没有评论，来抢沙发');
                        Text.debugLine("entry/src/main/ets/components/CommentList.ets(32:9)", "entry");
                        Text.fontSize(13);
                        Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const c = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Row.create({ space: 10 });
                                Row.debugLine("entry/src/main/ets/components/CommentList.ets(39:13)", "entry");
                                Row.width('100%');
                                Row.alignItems(VerticalAlign.Top);
                            }, Row);
                            this.avatar.bind(this)(c);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Column.create({ space: 4 });
                                Column.debugLine("entry/src/main/ets/components/CommentList.ets(41:15)", "entry");
                                Column.layoutWeight(1);
                                Column.alignItems(HorizontalAlign.Start);
                            }, Column);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Row.create({ space: 6 });
                                Row.debugLine("entry/src/main/ets/components/CommentList.ets(42:17)", "entry");
                            }, Row);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(c.user?.nickname ?? '匿名用户');
                                Text.debugLine("entry/src/main/ets/components/CommentList.ets(43:19)", "entry");
                                Text.fontSize(14);
                                Text.fontWeight(FontWeight.Medium);
                                Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                            }, Text);
                            Text.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                If.create();
                                if (c.isFact === 1) {
                                    this.ifElseBranchUpdateFunction(0, () => {
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Text.create('事实补充');
                                            Text.debugLine("entry/src/main/ets/components/CommentList.ets(48:21)", "entry");
                                            Text.fontSize(11);
                                            Text.fontColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                                            Text.border({ width: 0.5, color: { "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" } });
                                            Text.borderRadius(4);
                                            Text.padding({ left: 4, right: 4, top: 1, bottom: 1 });
                                        }, Text);
                                        Text.pop();
                                    });
                                }
                                else {
                                    this.ifElseBranchUpdateFunction(1, () => {
                                    });
                                }
                            }, If);
                            If.pop();
                            Row.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(c.content ?? '');
                                Text.debugLine("entry/src/main/ets/components/CommentList.ets(56:17)", "entry");
                                Text.fontSize(15);
                                Text.fontColor({ "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                            }, Text);
                            Text.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(timeAgo(c.createdAt) + ' · ' + formatCount(c.upCount) + ' 顶');
                                Text.debugLine("entry/src/main/ets/components/CommentList.ets(59:17)", "entry");
                                Text.fontSize(12);
                                Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                            }, Text);
                            Text.pop();
                            Column.pop();
                            Row.pop();
                        };
                        this.forEachUpdateFunction(elmtId, this.comments, forEachItemGenFunction, (c: Comment) => c.id?.toString() ?? '', false, false);
                    }, ForEach);
                    ForEach.pop();
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
