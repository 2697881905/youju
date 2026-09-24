// 发帖正文 @提及候选：横向滚动的「头像 + 昵称」卡片条。
// - 关键字为空：展示「我关注的人」（scope=following，默认列表）
// - 输入昵称：全站昵称检索（scope=all），规避重名昵称
// 点选候选后由父页将「@昵称 」回填进正文并记录精确 userId（随发布透传后端入库）。
//
// 形态说明：横向条内联在输入框**上方**（由父页摆放），高度固定、不随候选数量变化，
// 因此出现/消失时对页面布局的扰动恒定且很小。此前是竖向列表，一出现就把下方内容
// 整体推走一截，且候选越多推得越远。
import { searchMentionUsers } from '../services/api';
import { MentionCandidate } from '../models/types';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { ShadowTokens } from '../design/tokens/shadow';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

const AVATAR_SIZE: number = 44;
// 单项宽度：昵称超长时省略号截断，保证横向条节奏均匀
const CHIP_WIDTH: number = 60;

@Component
export struct AtMentionSuggest {
  // 当前进行中 @提及 已输入片段（父页实时更新）
  @Prop @Watch('onKeywordChange') keyword: string = '';
  onPick: (candidate: MentionCandidate) => void = (candidate: MentionCandidate): void => {};
  @State candidates: MentionCandidate[] = [];
  @State loading: boolean = false;
  private loadToken: number = 0;

  onKeywordChange(): void {
    this.reload();
  }

  aboutToAppear(): void {
    this.reload();
  }

  aboutToDisappear(): void {
    // 卸载后使进行中的请求失效，避免旧响应写已销毁组件的状态
    this.loadToken += 1;
  }

  // 关键字变化/挂载时拉取候选；带请求序号防止旧响应覆盖新输入
  private async reload(): Promise<void> {
    const kw: string = this.keyword.trim();
    const token: number = this.loadToken + 1;
    this.loadToken = token;
    this.loading = true;
    try {
      const res = await searchMentionUsers(kw, kw.length > 0 ? 'all' : 'following', 20);
      if (token !== this.loadToken) {
        return;
      }
      this.candidates = res.list;
    } catch (e) {
      if (token !== this.loadToken) {
        return;
      }
      this.candidates = [];
    } finally {
      if (token === this.loadToken) {
        this.loading = false;
      }
    }
  }

  private scopeTitle(): string {
    const kw: string = this.keyword.trim();
    if (kw.length === 0) {
      return '我关注的人';
    }
    return '搜索“' + kw + '”';
  }

  private initialOf(nickname: string): string {
    if (nickname.length === 0) {
      return '?';
    }
    return nickname.slice(0, 1);
  }

  // 单个候选：圆形首字头像 + 下方昵称
  @Builder
  chip(c: MentionCandidate): void {
    Column({ space: 6 }) {
      Stack() {
        Text(this.initialOf(c.nickname))
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.onBrand)
      }
      .width(AVATAR_SIZE)
      .height(AVATAR_SIZE)
      .borderRadius(AVATAR_SIZE / 2)
      .backgroundColor(ColorTokens.brand)

      Text(c.nickname)
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .lineHeight(TypeTokens.caption.lineHeight)
        .fontColor(ColorTokens.primary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(CHIP_WIDTH)
        .textAlign(TextAlign.Center)
    }
    .width(CHIP_WIDTH)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onPick(c);
    })
  }

  build() {
    Column({ space: SpaceTokens.xs }) {
      Row({ space: SpaceTokens.sm }) {
        Text('@ 提及')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.brand)
        Text(this.scopeTitle())
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        Text('左右滑动 · 点选回填')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .width('100%')

      if (this.loading && this.candidates.length === 0) {
        Row({ space: SpaceTokens.sm }) {
          LoadingProgress().width(16).height(16)
          Text('正在查找…')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .width('100%')
        .height(AVATAR_SIZE)
        .justifyContent(FlexAlign.Center)
      } else if (this.candidates.length === 0) {
        Text(this.keyword.trim().length > 0 ? '未找到匹配的用户' : '暂无关注的人，输入昵称可搜索全部用户')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .width('100%')
          .height(AVATAR_SIZE)
          .textAlign(TextAlign.Center)
      } else {
        Scroll() {
          Row({ space: SpaceTokens.md }) {
            ForEach(this.candidates, (c: MentionCandidate) => {
              this.chip(c)
            }, (c: MentionCandidate) => 'at_' + c.id)
          }
          .padding({ left: SpaceTokens.xs, right: SpaceTokens.xs })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        // 固定高度：横向条不与候选数量挂钩，出现/消失时布局扰动恒定
        .height(AVATAR_SIZE + 24)
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    // 实色底：此前用 barSurface（#70FBF8EE，alpha 仅 44% 的半透明玻璃），盖在封面图或
    // 正文上时头像与文字几乎看不出边界、可读性差。改用 ds_elevated（#FFFCF3，与内容卡片
    // 同底、全不透明），并补一层投影把它从底层内容里抬起来。
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.md)
    .shadow(ShadowTokens.cardAmbient)
    .alignItems(HorizontalAlign.Start)
  }
}
