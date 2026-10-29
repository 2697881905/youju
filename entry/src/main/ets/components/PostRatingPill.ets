import { ColorTokens } from '../design/tokens/color';
import { TypeTokens } from '../design/tokens/type';
import { ratePost, PostRatingResult } from '../services/api';

// 帖子社区评分胶囊（2026-10-29 替代作者主观「推荐指数」主视觉）：
// 收起态 = ★均值 · N人（无人打分 = 「评分」引导位），挂在详情页标题区体裁行右侧；
// 点击展开半星打分条（5 颗星、每颗左右半区各 0.5 步进），点星即提交（upsert 可改票）。
// 未登录点击走 onNeedLogin 由宿主接登录流程；提交后回写聚合（均值/人数/我的评分）。
@Component
export struct PostRatingPill {
  @Prop postId: number = 0;
  @Prop ratingAvg: number | null = null;
  @Prop ratingCount: number = 0;
  @Prop myRating: number = 0; // 半星×2（0 = 未打）
  onUpdated: (avg: number, count: number, my: number) => void = (): void => {};
  // 展开打分条前询问宿主：已登录返回 true（组件展开）；未登录宿主拉起登录并返回 false
  onExpandRequest: () => boolean = (): boolean => true;

  @State private expanded: boolean = false;
  @State private submitting: boolean = false;

  // 我的评分显示（星，一位小数）：0 = 未打
  private myStars(): number {
    return this.myRating / 2;
  }

  // 第 i 颗星（0-based）在给定分数下的填充：2=全星 1=半星 0=空
  private fillOf(starIndex: number, scoreX2: number): number {
    const filled: number = scoreX2 - starIndex * 2;
    if (filled >= 2) {
      return 2;
    }
    return filled === 1 ? 1 : 0;
  }

  private async submit(scoreX2: number): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    try {
      const result: PostRatingResult = await ratePost(this.postId, scoreX2);
      this.onUpdated(result.ratingAvg, result.ratingCount, result.myRating);
      // 提交成功收起打分条（胶囊回写新均值）
      this.expanded = false;
    } catch (e) {
      // 失败保持展开态，用户可重试；错误提示由 api 层统一弹
    }
    this.submitting = false;
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 4 }) {
        Text('★')
          .fontSize(13).fontFamily($r('app.string.font_family'))
          .fontColor(ColorTokens.brandPress)
        Text(this.ratingAvg !== null && this.ratingAvg !== undefined
          && this.ratingAvg > 0
          ? this.ratingAvg.toFixed(1) + (this.ratingCount > 0 ? ' · ' + this.ratingCount + '人' : '')
          : '评分')
          .fontSize(12).fontFamily($r('app.string.font_family'))
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
      }
      .backgroundColor(ColorTokens.brandTint)
      .borderRadius(10)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .onClick((): void => {
        if (this.expanded) {
          this.expanded = false;
          return;
        }
        if (this.postId <= 0) {
          return;
        }
        // 登录门控在宿主：未登录时宿主拉起登录页且不展开
        if (this.onExpandRequest()) {
          this.expanded = true;
        }
      })

      if (this.expanded) {
        // 半星打分条：每颗星左/右半区各 0.5 步进，点星即提交
        Row({ space: 2 }) {
          ForEach([0, 1, 2, 3, 4], (starIndex: number) => {
            Stack({ alignContent: Alignment.Start }) {
              Text('★')
                .fontSize(24).fontFamily($r('app.string.font_family'))
                .fontColor(ColorTokens.tertiary)
              // 实星按填充比例裁宽：全星 100% / 半星 50% / 空 0
              Text('★')
                .fontSize(24).fontFamily($r('app.string.font_family'))
                .fontColor('#F5A623')
                .width(this.fillOf(starIndex, this.myRating) === 2 ? '100%'
                  : (this.fillOf(starIndex, this.myRating) === 1 ? '50%' : '0%'))
                .clip(true)
            }
            .width(26)
            .height(28)
            .hitTestBehavior(HitTestMode.Transparent)
            .gesture(
              // 左半区 = 0.5 步进，右半区 = 整星
              TapGesture()
                .onAction((event: GestureEvent) => {
                  const localX: number = event.fingerList.length > 0
                    && event.fingerList[0].localX !== undefined
                    ? event.fingerList[0].localX : 0;
                  const half: number = localX < 13 ? 1 : 2;
                  this.submit(starIndex * 2 + half);
                })
            )
          }, (starIndex: number): string => String(starIndex))

          Text(this.myRating > 0 ? '我的 ' + this.myStars().toFixed(1) : '点星评分')
            .fontSize(11).fontFamily($r('app.string.font_family'))
            .fontColor(ColorTokens.tertiary)
        }
        .justifyContent(this.gripAligned ? FlexAlign.End : FlexAlign.Start)
      }
    }
    .alignItems(this.gripAligned ? HorizontalAlign.End : HorizontalAlign.Start)
  }

  // 与 DetailPostHeader 同款握持手适配：右手握持整组居右
  @StorageProp('gripOnRight') gripAligned: boolean = false;
}
