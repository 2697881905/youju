// @提及 / #话题# 高亮文本：把纯文本按分段渲染为「Text + Span」，
//   @昵称 → 蓝色（ColorTokens.mention）且可点
//   #话题# → 品牌棕（ColorTokens.brand）且可点
// 其余文字走常规色。
//
// 跳转口径：三种场景的数据完整度不同，统一在这里兜底 ——
//   · 调用方传了 mentions（帖子正文来自 post.mentions）→ 精确取 userId 跳主页
//   · 未传（评论 / 私信，后端 Comment / Message 模型暂无 mentions 字段）
//     → 退化为按昵称全站搜索，命中即跳、否则 toast 提示。
import { MentionRef, MentionCandidate } from '../models/types';
import { HighlightSegment, parseHighlightSegments } from '../utils/textHighlight';
import { searchMentionUsers } from '../services/api';
import { openCircleDetail, openUserProfile } from '../utils/nav';
import { ColorTokens } from '../design/tokens/color';
import { TypeTokens } from '../design/tokens/type';
import { safeShowToast } from '../utils/toast';

// maxLines 的「不限制」取值：ArkUI 的 maxLines(0) 语义不是不限，故用一个大数兜底
const NO_LINE_LIMIT: number = 99999;

@Component
export struct HighlightedText {
  @Prop text: string = '';
  // 精确的 @提及 → userId 映射（可选）。评论/私信暂无该数据，留空即走「按昵称搜索」兜底。
  @Prop mentions: MentionRef[] = [];
  @Prop fontSize: number = TypeTokens.body.size;
  @Prop lineHeight: number = TypeTokens.body.lineHeight;
  @Prop maxLines: number = 0;
  // true 用衬线体（帖子标题）；false 用无衬线（评论 / 私信正文）
  @Prop serif: boolean = false;
  @Prop bold: boolean = false;
  @Prop letterSpacing: number = 0;

  // 分段配色：正文常规 / @提及蓝 / #话题# 品牌棕
  private colorOf(type: string): ResourceColor {
    if (type === 'text') {
      return ColorTokens.primary;
    }
    if (type === 'mention') {
      return ColorTokens.mention;
    }
    return ColorTokens.brand;
  }

  // 点 @提及：优先用精确映射，没有则退化为按昵称搜索
  private tapMention(name: string): void {
    for (const m of this.mentions) {
      if (m.name === name && m.userId > 0) {
        openUserProfile(m.userId);
        return;
      }
    }
    this.searchAndOpen(name);
  }

  private async searchAndOpen(name: string): Promise<void> {
    try {
      const res = await searchMentionUsers(name, 'all', 20);
      const hit: MentionCandidate | undefined =
        res.list.find((c: MentionCandidate): boolean => c.nickname === name);
      if (hit !== undefined) {
        openUserProfile(hit.id);
        return;
      }
    } catch (e) {
      // 网络失败按「未找到」处理，不打断阅读
    }
    safeShowToast(this.getUIContext(), { message: '未找到用户 @' + name });
  }

  build() {
    Text() {
      ForEach(parseHighlightSegments(this.text), (seg: HighlightSegment) => {
        Span(seg.raw)
          .fontColor(this.colorOf(seg.type))
          .fontWeight(seg.type === 'text' ? FontWeight.Normal : FontWeight.Medium)
          .onClick(() => {
            if (seg.type === 'tag') {
              openCircleDetail(seg.name);
              this.getUIContext().getRouter().pushUrl({ url: 'pages/CircleDetailPage' });
            } else if (seg.type === 'mention') {
              this.tapMention(seg.name);
            }
          })
      }, (seg: HighlightSegment) => seg.type + ':' + seg.raw)
    }
    .fontSize(this.fontSize)
    .fontFamily(this.serif ? TypeTokens.fontFamilySerif : TypeTokens.fontFamily)
    .fontWeight(this.bold ? TypeTokens.headline.weight : FontWeight.Normal)
    .lineHeight(this.lineHeight)
    .letterSpacing(this.letterSpacing)
    .textAlign(TextAlign.Start)
    .maxLines(this.maxLines > 0 ? this.maxLines : NO_LINE_LIMIT)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}
