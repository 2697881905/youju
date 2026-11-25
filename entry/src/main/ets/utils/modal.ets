// CustomBuilder / DialogAlignment / DismissDialogAction 是 ArkUI 全局声明类型，
// 不在 @kit.ArkUI 命名导出内（kit 导入会编译报错），直接全局使用即可。
import { ComponentContent, PromptAction, UIContext } from '@kit.ArkUI';

export interface AppModalOptions {
  onDismiss?: () => void;   // 弹窗关闭通知（点外/返回键/代码 close 都会触发）
  autoCancel?: boolean;     // 点外/返回键是否允许关闭，默认 true；明示同意类弹窗（隐私协议）传 false
}

export class AppModalController {
  private prompt: PromptAction | null = null;
  private dialogId: number = -1;
  // 同步防重标志：openCustomDialog 的 dialogId 经 Promise 异步回填，真机实测回填明显滞后于
  // 弹窗出现——连续两次 open 在竞态窗口内 dialogId 均为 -1，双层弹窗（2026-11-25 真机实锤）。
  // pending 在 open 入口同步置位，Promise 回填或 close 时复位，覆盖「弹窗开着」与「关闭复开」。
  private pending: boolean = false;
  private content?: ComponentContent<Object>;
  private onDismiss?: () => void;

  // ComponentContent 版打开：关闭走 closeCustomDialog(content) 同步可靠、不依赖 dialogId
  //（单对象重载的 dialogId 经 Promise 回填，真机实为弹窗关闭时才 resolve，整个生命周期恒 -1，
  // 2026-11-25 双层弹窗实锤）。pending 防重语义与 open 一致。
  openContent(uiContext: UIContext, content: ComponentContent<Object>, options?: AppModalOptions): void {
    if (this.dialogId >= 0 || this.pending) {
      return;
    }
    this.pending = true;
    this.onDismiss = options?.onDismiss;
    this.content = content;
    this.prompt = uiContext.getPromptAction();
    this.prompt.openCustomDialog(content, {
      alignment: DialogAlignment.Center,
      autoCancel: options?.autoCancel ?? true,

      onWillDismiss: (action: DismissDialogAction): void => {
        this.onDismiss?.();
        action.dismiss();
      },
    }).then((): void => {
    }).catch((): void => {
      this.pending = false;
    });
  }

  open(uiContext: UIContext, builder: CustomBuilder, options?: AppModalOptions): void {
    // 重复 open 防御：同一控制器弹层开着时忽略新 open（避免叠层与 dialogId 覆盖）。
    // dialogId 是异步回填值，防重必须叠加同步 pending 标志（见字段注释）。
    if (this.dialogId >= 0 || this.pending) {
      return;
    }
    this.pending = true;
    this.onDismiss = options?.onDismiss;
    this.prompt = uiContext.getPromptAction();
    // UIContext.PromptAction.openCustomDialog 的单对象重载（options: CustomDialogOptions，
    // 含 builder 字段，返回 Promise<number> dialogId）；双参重载首参是 ComponentContent，
    // 不接受页面 builder 闭包（编译实证）。
    this.prompt.openCustomDialog({
      builder: builder,
      alignment: DialogAlignment.Center,
      autoCancel: options?.autoCancel ?? true,
      // 壳全透明：表面与圆角由内容自绘壳承担（ReportDialog bg_primary 底 / FolderNameDialog
      // SpringPanel solid / FolderPickDialog card_bg 底 / ResolveReasonDialog 内容自绘），
      // 与原 CustomDialog customStyle:true 的全自绘结构一致
      backgroundColor: Color.Transparent,
      onWillDismiss: (action: DismissDialogAction): void => {
        // 点外/返回键：系统不自动关（dismiss 由我们调），统一走宿主 onDismiss → close()，
        // dialogId 才能同步（close 先复位再异步关，见下）
        this.onDismiss?.();
        action.dismiss();
      },
    }).then((id: number): void => {
      this.dialogId = id;
      this.pending = false;
    }).catch((): void => {
      this.dialogId = -1;
      this.pending = false;
    });
  }

  close(): void {
    // 优先按 content 关闭（openContent 路径，同步可靠）；dialogId 路径为旧 open 兼容
    //（注意其 Promise 回填时机在真机上滞后，遗留消费点待全站迁移后下线）。
    if (this.content !== undefined && this.prompt !== null) {
      this.prompt.closeCustomDialog(this.content);
      this.content = undefined;
      this.dialogId = -1;
      this.pending = false;
      return;
    }
    if (this.dialogId >= 0 && this.prompt !== null) {
      this.prompt.closeCustomDialog(this.dialogId);
    }
    this.dialogId = -1;
    this.pending = false;
  }
}