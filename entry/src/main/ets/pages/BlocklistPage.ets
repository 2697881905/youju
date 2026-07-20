// 拉黑管理页：查看/取消拉黑列表（分页加载）
import { router } from '@kit.ArkUI';
import { listBlocked, unblockUser } from '../services/api';
import { BlockUser, Pagination } from '../models/types';
import { safeShowToast } from '../utils/toast';

@Entry
@Component
export struct BlocklistPage {
  @State users: BlockUser[] = [];
  @State loadFinished: boolean = false;
  @State loadError: string = '';
  @State loadingMore: boolean = false;
  private pagination: Pagination = { page: 1, limit: 20, total: 0 };

  aboutToAppear(): void {
    this.loadFirst();
  }

  private async loadFirst(): Promise<void> {
    this.loadError = '';
    this.loadFinished = false;
    try {
      const r = await listBlocked(1, 20);
      this.users = r.list;
      this.pagination = r.pagination;
    } catch (e) {
      this.loadError = (e as Error).message;
    }
    this.loadFinished = true;
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    if (this.users.length >= this.pagination.total) return;
    this.loadingMore = true;
    try {
      const r = await listBlocked(this.pagination.page + 1, 20);
      for (let i = 0; i < r.list.length; i++) {
        this.users.push(r.list[i]);
      }
      this.pagination = r.pagination;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
    this.loadingMore = false;
  }

  private onUnblock(user: BlockUser): void {
    this.getUIContext().showAlertDialog({
      title: '取消拉黑？',
      message: '取消后，' + user.nickname + ' 将可以正常与你互动。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确认取消', fontColor: '#FF453A', action: async (): Promise<void> => {
        try {
          await unblockUser(user.id);
          const idx = this.users.indexOf(user);
          if (idx >= 0) {
            this.users.splice(idx, 1);
          }
          safeShowToast(this.getUIContext(), { message: '已取消拉黑' });
        } catch (e) {
          safeShowToast(this.getUIContext(), { message: (e as Error).message });
        }
      } },
    });
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.text_primary'))
          .width(48)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.back(); });
        Text('拉黑管理')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Text('')
          .width(48);
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      if (!this.loadFinished) {
        Column() {
          LoadingProgress().width(40).height(40).color($r('app.color.text_secondary'));
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.loadError) {
        Column() {
          Text('加载失败').fontSize(15).fontColor($r('app.color.text_secondary'));
          Text(this.loadError).fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 4 });
          Button('重试').margin({ top: 12 }).onClick(() => { this.loadFirst(); });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.users.length === 0) {
        Column() {
          Text('暂无拉黑用户').fontSize(15).fontColor($r('app.color.text_secondary'));
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        List() {
          ForEach(this.users, (user: BlockUser) => {
            ListItem() {
              Row() {
                // 头像占位
                Column() {
                  Text(user.nickname.charAt(0))
                    .fontSize(16)
                    .fontColor('#FFFFFF');
                }
                .width(40).height(40)
                .borderRadius(20)
                .backgroundColor($r('app.color.text_secondary'))
                .justifyContent(FlexAlign.Center);

                Text(user.nickname)
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .margin({ left: 12 });

                Button('取消拉黑')
                  .fontSize(13)
                  .fontColor('#FF453A')
                  .backgroundColor('#1AFF453A')
                  .borderRadius(6)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .onClick(() => { this.onUnblock(user); });
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor($r('app.color.card_bg'));
            }
          });

          ListItem() {
            Row() {
              if (this.users.length < this.pagination.total) {
                Text(this.loadingMore ? '加载中...' : '加载更多')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .onClick(() => { this.loadMore(); });
              } else {
                Text('已加载全部')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'));
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 12, bottom: 12 });
          }
        }
        .layoutWeight(1).width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 });
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg_primary'));
    .transition(TransitionEffect.OPACITY
      .animation({ duration: 300, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ x: 50 })
        .animation({ duration: 350, curve: Curve.EaseOut })))
  }
}
