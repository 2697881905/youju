if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface TagNav_Params {
    tags?: Tag[];
    selectedIndex?: number;
}
import type { Tag } from '../models/types';
export class TagNav extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__tags = new SynchedPropertyObjectOneWayPU(params.tags, this, "tags");
        this.__selectedIndex = new SynchedPropertySimpleTwoWayPU(params.selectedIndex, this, "selectedIndex");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: TagNav_Params) {
        if (params.tags === undefined) {
            this.__tags.set([]);
        }
    }
    updateStateVars(params: TagNav_Params) {
        this.__tags.reset(params.tags);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__tags.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedIndex.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__tags.aboutToBeDeleted();
        this.__selectedIndex.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __tags: SynchedPropertySimpleOneWayPU<Tag[]>;
    get tags() {
        return this.__tags.get();
    }
    set tags(newValue: Tag[]) {
        this.__tags.set(newValue);
    }
    private __selectedIndex: SynchedPropertySimpleTwoWayPU<number>;
    get selectedIndex() {
        return this.__selectedIndex.get();
    }
    set selectedIndex(newValue: number) {
        this.__selectedIndex.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/components/TagNav.ets(9:5)", "entry");
            Scroll.scrollable(ScrollDirection.Horizontal);
            Scroll.scrollBar(BarState.Off);
            Scroll.width('100%');
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/components/TagNav.ets(10:7)", "entry");
            Row.padding({ left: 12, right: 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = (_item, index: number) => {
                const tag = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create((tag.emoji ?? '') + ' ' + (tag.name ?? ''));
                    Text.debugLine("entry/src/main/ets/components/TagNav.ets(14:13)", "entry");
                    Text.fontSize(12);
                    Text.fontWeight(FontWeight.Medium);
                    Text.padding({ left: 12, right: 12, top: 6, bottom: 6 });
                    Text.backgroundColor(this.selectedIndex === index ? { "id": 16777227, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" } : { "id": 16777228, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    Text.fontColor(this.selectedIndex === index ? '#FFFFFF' : { "id": 16777231, "type": 10001, params: [], "bundleName": "com.bigbluebook.app", "moduleName": "entry" });
                    Text.borderRadius(16);
                    Text.onClick(() => {
                        if (this.selectedIndex !== index) {
                            this.selectedIndex = index;
                        }
                    });
                }, Text);
                Text.pop();
            };
            this.forEachUpdateFunction(elmtId, this.tags, forEachItemGenFunction, (tag: Tag) => tag.id?.toString() ?? (tag.name ?? ''), true, false);
        }, ForEach);
        ForEach.pop();
        Row.pop();
        Scroll.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
