if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface PostCard_Params {
    post?: Post;
}
import type { Post } from '../models/types';
import { formatCount } from "@normalized:N&&&entry/src/main/ets/utils/format&";
export class PostCard extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__post = new SynchedPropertyObjectOneWayPU(params.post, this, "post");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: PostCard_Params) {
        if (params.post === undefined) {
            this.__post.set({});
        }
    }
    updateStateVars(params: PostCard_Params) {
        this.__post.reset(params.post);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__post.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__post.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __post: SynchedPropertySimpleOneWayPU<Post>;
    get post() {
        return this.__post.get();
    }
    set post(newValue: Post) {
        this.__post.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/components/PostCard.ets(9:5)", "entry");
            Column.width('100%');
            Column.padding(12);
            Column.backgroundColor({ "id": 16777228, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
            Column.borderRadius(12);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.post.coverImage) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Image.create(this.post.coverImage);
                        Image.debugLine("entry/src/main/ets/components/PostCard.ets(11:9)", "entry");
                        Image.width('100%');
                        Image.height(160);
                        Image.objectFit(ImageFit.Cover);
                        Image.borderRadius(8);
                        Image.margin({ bottom: 8 });
                    }, Image);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.post.title ?? '');
            Text.debugLine("entry/src/main/ets/components/PostCard.ets(18:7)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor({ "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
            Text.maxLines(2);
            Text.textOverflow({ overflow: TextOverflow.Ellipsis });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/components/PostCard.ets(25:7)", "entry");
            Row.margin({ top: 8 });
            Row.justifyContent(FlexAlign.Start);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('⭐ ' + formatCount(this.post.upCount));
            Text.debugLine("entry/src/main/ets/components/PostCard.ets(26:9)", "entry");
            Text.fontSize(13);
            Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('💬 ' + formatCount(this.post.commentCount));
            Text.debugLine("entry/src/main/ets/components/PostCard.ets(29:9)", "entry");
            Text.fontSize(13);
            Text.fontColor({ "id": 16777232, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
            Text.margin({ left: 12 });
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
