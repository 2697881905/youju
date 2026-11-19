// 建圈表单：从旧面板 CircleExploreSheet 的表单片段迁出（旧面板阶段 4 退役）。
//
// 组件选择（按「尽量官方 + 沉浸光感」）：
// - 输入 → GlowInput（统一输入框，底色传系统三级背景以适配半模态材质面板）
// - 分类 → ToggleChip（可选中 chip 家族唯一源）
// - 提交 → DesignButton primary
// - 表面由宿主 bindSheet 的 SheetOptions.systemMaterial 提供，本组件不铺底
import { createTag } from '../services/api';
import { Tag } from '../models/types';
import { GlowInput } from '../design/components/GlowInput';
import { ToggleChip } from '../design/components/ToggleChip';
import { DesignButton } from '../design/components/DesignButton';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { safeShowToast } from '../utils/toast';

// 建圈成功后的回传载荷：带完整元信息，宿主不必再查一次
export class CircleCreatedPayload {
  name: string = '';
  emoji: string = '';
  category: string = '';
  description: string = '';
  memberCount: number = 0;
  creatorId: number = 0;
}

// 与旧面板同一份白名单（后端 createTag 只接受这些分类）
const CIRCLE_CATEGORIES: string[] = ['消费选购', '动手改造', '职场与收入', '生活与家庭', '兴趣休闲'];

@Component
export struct CircleCreateSheet {
  @State name: string = '';
  @State category: string = '';
  @State description: string = '';
  @State submitting: boolean = false;
  onCreated: (payload: CircleCreatedPayload) => void = (): void => {};
  onCancel: () => void = (): void => {};

  private canSubmit(): boolean {
    const trimmed: string = this.name.trim();
    return trimmed.length >= 2 && trimmed.length <= 8
      && this.category.length > 0
      && this.description.trim().length > 0
      && !this.submitting;
  }

  private async submit(): Promise<void> {
    if (!this.canSubmit()) {
      return;
    }
    this.submitting = true;
    try {
      const tag: Tag = await createTag(this.name.trim(), this.category, this.description.trim());
      const payload: CircleCreatedPayload = new CircleCreatedPayload();
      payload.name = tag.name ?? this.name.trim();
      payload.emoji = tag.emoji ?? '';
      payload.category = tag.category ?? this.category;
      payload.description = tag.description ?? this.description.trim();
      payload.memberCount = tag.followCount ?? 1;
      payload.creatorId = tag.creatorId ?? 0;
      this.onCreated(payload);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '创建失败：' + (e as Error).message });
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Column({ space: SpaceTokens.base }) {
      Text('点亮一颗新星')
        .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.title.weight)
        .fontColor(ColorTokens.primary)
      Text('新圈子会挂到你的星图上，随时可以发第一帖')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)

      GlowInput({
        text: $name,
        placeholder: '圈子名字（2~8 字）',
        fillWidth: false,
        inputHeight: 40,
        fontSize: TypeTokens.callout.size,
        maxLength: 8,
        fillColor: $r('sys.color.comp_background_tertiary'),
      })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(CIRCLE_CATEGORIES, (item: string) => {
          ToggleChip({
            label: item,
            selected: this.category === item,
            outlined: true,
            action: (): void => { this.category = item; },
          })
            .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
        }, (item: string) => item)
      }
      .width('100%')

      GlowInput({
        text: $description,
        placeholder: '一句话简介（1~24 字）',
        fillWidth: false,
        inputHeight: 40,
        fontSize: TypeTokens.callout.size,
        maxLength: 24,
        fillColor: $r('sys.color.comp_background_tertiary'),
      })

      DesignButton({
        label: this.submitting ? '创建中…' : '创建圈子',
        variant: 'primary',
        fillWidth: true,
        disabled: !this.canSubmit(),
        action: (): void => { this.submit(); },
      })
    }
    .width('100%')
    .padding({ left: SpaceTokens.xl, right: SpaceTokens.xl, top: SpaceTokens.base, bottom: SpaceTokens.x2l })
    .alignItems(HorizontalAlign.Start)
  }
}
