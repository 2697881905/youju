// 剪贴板发现帖子链接的确认面板（底部拉起式）。
// 骨架与 ProfileShareSheet/ShareSheet 同构：抓手 + 居中标题 + elevated 主卡片，
// 外层左右/底部留边；调用侧须配 alignment=Bottom + customStyle=true。
// 合规考量：剪贴板命中后必须由用户确认才跳转，不静默打开；「忽略」与点击
// 面板外区域都会让该链接本会话内不再打扰（由调用侧 markClipboardIdHandled 承担）。
import { DesignButton } from '../design/components/DesignButton';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { TypeTokens } from '../design/tokens/type';

export interface ClipboardPostPayload {
  postId: number;
  title: string;
  authorName: string;
}

@CustomDialog
export struct ClipboardPostSheet {
  controller: CustomDialogController;
  getPayload: () => ClipboardPostPayload | null = (): ClipboardPostPayload | null => null;
  onOpen: () => void = (): void => {};
  onIgnore: () => void = (): void => {};

  // 控制器会复用 builder：payload 清空后仍可能重渲染，兜底空数据防崩
  private payload(): ClipboardPostPayload {
    const p: ClipboardPostPayload | null = this.getPayload();
    if (p !== null) {
      return p;
    }
    const empty: ClipboardPostPayload = { postId: 0, title: '', authorName: '' };
    return empty;
  }

  private postTitle(): string {
    const t: string = this.payload().title.trim();
    return t.length > 0 ? t : '有据帖子';
  }

  private authorLine(): string {
    const name: string = this.payload().authorName.trim();
    return '「' + (name.length > 0 ? name : '有据用户') + '」的帖子';
  }

  build() {
    Column() {
      Column() {
        Row()
          .width(36)
          .height(4)
          .backgroundColor(ColorTokens.separator)
          .borderRadius(RadiusTokens.pill)
          .margin({ top: SpaceTokens.md, bottom: SpaceTokens.sm })

        Text('发现帖子链接')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.secondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ bottom: SpaceTokens.md })

        Column({ space: SpaceTokens.xs }) {
          Text(this.postTitle())
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.authorLine())
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(SpaceTokens.md)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(RadiusTokens.md)
        .margin({ bottom: SpaceTokens.md })

        Row({ space: SpaceTokens.sm }) {
          // 次键自绘：elevated 底上 DesignButton outlined 变体的描边对比度 ≈1.1:1（不可见），
          // 与隐私弹窗次键同款——透明底 + separator 描边 + secondary 字。
          // 用内置 Text（可链式 layoutWeight）+ stateStyles 按压反馈：Pressable 尾随闭包
          // 与属性链不能共存（ArkTS 编译错误 10505001，见 Index 隐私弹窗同款写法）。
          Text('忽略')
            .layoutWeight(1)
            .height(LayoutTokens.minTouchTarget)
            .textAlign(TextAlign.Center)
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.secondary)
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.lg)
            .stateStyles({
              normal: {
                .opacity(1)
              },
              pressed: {
                .opacity(0.7)
                .scale({ x: 0.97, y: 0.97 })
              }
            })
            .onClick((): void => { this.onIgnore(); })

          DesignButton({
            label: '打开帖子',
            fillWidth: true,
            visualHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.onOpen(); },
          })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, bottom: SpaceTokens.lg })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.lg)
      .clip(true)
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.lg })
  }
}
