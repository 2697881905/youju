// 发帖正文 @提及候选列表：
// - 关键字为空：展示“我关注的人”（scope=following，默认列表）
// - 输入昵称：全站昵称检索（scope=all），规避重名昵称
// 点选候选后由父页将「@昵称 」回填进正文并记录精确 userId（随发布透传后端入库）。
import { searchMentionUsers } from '../services/api';
import { MentionCandidate } from '../models/types';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

const MAX_VISIBLE_ROWS: number = 6;
const AVATAR_SIZE: number = 36;

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

  private visibleRows(): MentionCandidate[] {
    const total: number = this.candidates.length;
    return total > MAX_VISIBLE_ROWS ? this.candidates.slice(0, MAX_VISIBLE_ROWS) : this.candidates;
  }

  private scopeTitle(): string {
    const kw: string = this.keyword.trim();
    if (kw.length === 0) {
      return '我关注的人';
    }
    return '全站搜索 “' + kw + '”';
  }

  private initialOf(nickname: string): string {
    if (nickname.length === 0) {
      return '?';
    }
    return nickname.slice(0, 1);
  }

  private bioOf(c: MentionCandidate): string {
    const bio: string = (c.bio ?? '').trim();
    return bio.length > 0 ? bio : '用户 ' + c.id;
  }

  @Builder
  row(c: MentionCandidate): void {
    Row({ space: SpaceTokens.md }) {
      // 首字符圆形占位头像（避免候选列表拉头像图的网络开销与失败态）
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

      Column({ space: 2 }) {
        Text(c.nickname)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.bioOf(c))
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(ColorTokens.secondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('提及')
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.brand)
    }
    .width('100%')
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .borderRadius(RadiusTokens.sm)
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
        Text('点选回填正文')
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
        .justifyContent(FlexAlign.Center)
        .padding({ top: 12, bottom: 12 })
      } else if (this.candidates.length === 0) {
        Text(this.keyword.trim().length > 0 ? '未找到匹配的用户' : '暂无关注的人，输入昵称可搜索全部用户')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 12 })
      } else {
        ForEach(this.visibleRows(), (c: MentionCandidate) => {
          this.row(c)
        }, (c: MentionCandidate) => 'at_' + c.id)
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    .backgroundColor(ColorTokens.barSurface)
    .borderRadius(RadiusTokens.md)
    .alignItems(HorizontalAlign.Start)
  }
}
