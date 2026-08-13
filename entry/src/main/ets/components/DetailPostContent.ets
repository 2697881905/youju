import { StructuredData } from '../models/types';
import { formatCount } from '../utils/format';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { debateVoteStore } from '../utils/debateVoteStore';

// 详情正文只负责体裁内容的展示；投票的请求和回滚仍由 DetailPage 持有。
export type DetailField = [string, string];

@Component
export struct DetailPostContent {
  @Prop fields: DetailField[] = [];
  @Prop genre: string = '';
  @Prop content: string = '';
  @Prop planA: string = '';
  @Prop planB: string = '';
  @Prop votePostId: number = 0;
  onVote: (choice: string) => void = (_choice: string): void => {};
  @State planAVotes: number = 0;
  @State planBVotes: number = 0;
  @State myVote: string = '';
  private unsubscribeVote: () => void = () => {};

  aboutToAppear(): void {
    this.refreshVoteState();
    this.unsubscribeVote = debateVoteStore.subscribe((postId: number): void => {
      if (postId === this.votePostId) {
        this.refreshVoteState();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribeVote();
    this.unsubscribeVote = () => {};
  }

  private refreshVoteState(): void {
    const vote = debateVoteStore.get(this.votePostId);
    if (!vote) {
      return;
    }
    // 给本组件的原始 @State 赋值，确保 ArkUI 重新计算票数文本和进度宽度。
    this.planAVotes = vote.planAVotes;
    this.planBVotes = vote.planBVotes;
    this.myVote = vote.choice;
  }

  private totalVotes(): number {
    return this.planAVotes + this.planBVotes;
  }

  private voteWidth(votes: number): string {
    const total: number = this.totalVotes();
    return total > 0 ? (votes / total) * 100 + '%' : '0%';
  }

  private voteCount(choice: string): number {
    return choice === 'A' ? this.planAVotes : this.planBVotes;
  }

  @Builder
  private voteRow(planName: string, fallbackLabel: string, choice: string): void {
    Row() {
      Text(planName.length > 0 ? planName : fallbackLabel)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ right: SpaceTokens.sm });
      Row() {
        Column()
          .width(this.voteWidth(this.voteCount(choice)))
          .height(6)
          .borderRadius(3)
          .backgroundColor(ColorTokens.brand);
        Column()
          .layoutWeight(1)
          .height(6)
          .borderRadius(3)
          .backgroundColor(ColorTokens.sunken);
      }
      .width(72)
      .height(6)
      .margin({ right: SpaceTokens.sm });
      Text(formatCount(this.voteCount(choice)) + '票')
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .margin({ left: SpaceTokens.sm });
      Row({ space: 2 }) {
        if (this.myVote === choice) {
          Image(resolveActionIcon('check'))
            .width(13)
            .height(13)
            .fillColor(ColorTokens.brand)
        }
        Text(this.myVote === choice ? '已投' : '投票')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.myVote === choice ? ColorTokens.brand : ColorTokens.secondary)
      }
      .width(52)
      .justifyContent(FlexAlign.Center)
      .onClick((): void => { this.onVote(choice); });
    }
    .width('100%');
  }

  @Builder
  private debatePanel(): void {
    Column({ space: SpaceTokens.md }) {
      this.voteRow(this.planA, '方案A', 'A');
      this.voteRow(this.planB, '方案B', 'B');
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.md)
    .border({ width: 0.5, color: ColorTokens.separator, style: BorderStyle.Solid });
  }

  @Builder
  private structuredFields(): void {
    if (this.fields.length > 0 && this.genre !== 'debate') {
      Column({ space: SpaceTokens.md }) {
        ForEach(
          this.fields,
          (field: DetailField) => {
            Row({ space: SpaceTokens.sm }) {
              Text(field[0])
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.secondary)
                .width(76)
              Text(field[1])
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.primary)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          },
          (field: DetailField) => field[0]
        )
      }
      .width('100%')
      .padding(14)
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.md)
      .border({ width: 0.5, color: ColorTokens.separator, style: BorderStyle.Solid })
    }
  }

  build() {
    Column({ space: SpaceTokens.base }) {
      if (this.genre === 'debate') {
        this.debatePanel();
      }
      this.structuredFields();
      if (this.content.length > 0) {
        Text(this.content)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
          .lineHeight(27)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
