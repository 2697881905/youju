import { EmptyState } from '../design/components/EmptyState';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 列表容器只在加载或没有内容时使用；实际滚动布局由各页面保留，避免统一组件改变瀑布流/网格行为。
@Component
export struct PostCollectionState {
  @Prop loading: boolean = false;
  @Prop error: string = '';
  @Prop emptyTitle: string = '';
  onRetry: () => void = (): void => {};

  build() {
    Column() {
      if (this.loading) {
        LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
        Text('加载中…')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .letterSpacing(TypeTokens.callout.tracking)
          .fontColor(ColorTokens.secondary)
          .margin({ top: SpaceTokens.md })
      } else {
        EmptyState({
          title: this.error.length > 0 ? '加载失败' : this.emptyTitle,
          message: this.error.length > 0 ? this.error : '内容出现后会显示在这里',
          actionLabel: this.error.length > 0 ? '重试' : '',
          onAction: (): void => { this.onRetry(); },
        })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
