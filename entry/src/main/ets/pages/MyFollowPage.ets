
import { FollowUser } from '../models/types';
import { listFollowing, listFollowers, followUser, unfollowUser } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';

@Entry
@Component
export struct MyFollowPage {
  @State mode: string = 'following';
  @State targetId: number = 0;
  @State list: FollowUser[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State ready: boolean = false;

  aboutToAppear(): void {
    this.resolveParams();
    this.loadAll();
  }

  private resolveParams(): void {
    let rawId: string | undefined = AppStorage.get<string>('targetUserId');
    let rawMode: string | undefined = AppStorage.get<string>('followMode');
    if (!rawId) {
      const params: Object | undefined = this.getUIContext().getRouter().getParams();
      if (params !== undefined && typeof params === 'object') {
        const p: Record<string, Object> = params as Record<string, Object>;
        const v: Object | undefined = p['userId'];
        if (typeof v === 'string') {
          rawId = v;
        }
        const m: Object | undefined = p['mode'];
        if (typeof m === 'string') {
          rawMode = m;
        }
      }
    }
    const id: number = Number(rawId);
    if (!Number.isNaN(id) && id > 0) {
      this.targetId = id;
    }
    if (rawMode === 'followers') {
      this.mode = 'followers';
    }
  }

  async loadAll(): Promise<void> {
    this.ready = false;
    await this.refresh();
    this.ready = true;
  }

  async refresh(): Promise<void> {
    this.page = 1;
    this.finished = false;
    await this.fetch(true);
  }

  async loadMore(): Promise<void> {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.page += 1;
    await this.fetch(false);
  }

  private async fetch(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    if (this.targetId === 0) {
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const res = this.mode === 'following'
        ? await listFollowing(this.targetId, this.page, 20)
        : await listFollowers(this.targetId, this.page, 20);
      const data: FollowUser[] = res.list;
      if (reset) {
        this.list = data;
      } else {
        this.list = this.list.concat(data);
      }
      if (data.length < 20) {
        this.finished = true;
      }
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
    }
  }

  // 关注/取关（乐观更新，避免对象展开，用显式拷贝）
  private updatedItem(item: FollowUser, isFollowing: boolean): FollowUser {
    return {
      id: item.id,
      nickname: item.nickname,
      avatar: item.avatar,
      bio: item.bio,
      isFollowing: isFollowing,
    };
  }

  async onToggle(item: FollowUser): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    if (item.isFollowing) {
      this.getUIContext().showAlertDialog({
        title: '取消关注',
        message: '确定不再关注 ' + (item.nickname !== '' ? item.nickname : '') + ' 吗？',
        primaryButton: { value: '取消', action: (): void => {} },
        secondaryButton: {
          value: '取消关注',
          fontColor: $r('app.color.semantic_red'),
          action: (): void => {
            this.doToggle(item);
          },
        },
      });
    } else {
      await this.doToggle(item);
    }
  }

  async doToggle(item: FollowUser): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const id: number = item.id;
    const willFollow: boolean = !item.isFollowing;
    const updated: FollowUser[] = [];
    for (let i = 0; i < this.list.length; i++) {
      const curId: number | undefined = this.list[i].id;
      if (curId === id) {
        updated.push(this.updatedItem(this.list[i], willFollow));
      } else {
        updated.push(this.list[i]);
      }
    }
    this.list = updated;
    try {
      if (willFollow) {
        await followUser(id);
      } else {
        await unfollowUser(id);
      }
    } catch (e) {
      const reverted: FollowUser[] = [];
      for (let i = 0; i < this.list.length; i++) {
        const curId: number | undefined = this.list[i].id;
        if (curId === id) {
          reverted.push(this.updatedItem(this.list[i], !willFollow));
        } else {
          reverted.push(this.list[i]);
        }
      }
      this.list = reverted;
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private goProfile(item: FollowUser): void {
    if (item.id === undefined) {
      return;
    }
    AppStorage.setOrCreate('targetUserId', String(item.id));
    this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage', params: { userId: String(item.id) } });
  }

  build() {
    Column() {
      Row() {
        Text('返回')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .width(48)
          .onClick(() => {
            this.getUIContext().getRouter().back();
          });
        Text(this.mode === 'following' ? '我的关注' : '我的粉丝')
          .fontSize(17).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center);
        Text('').width(48);
      }
      .width('100%').padding({ top: 12, bottom: 8 });

      if (!this.ready) {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.list.length === 0) {
        Column() {
          Text(this.error ? ('加载失败：' + this.error) : '这里还什么都没有')
            .fontSize(14).fontColor($r('app.color.text_secondary'));
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        List() {
          ForEach(this.list, (item: FollowUser) => {
            ListItem() {
              Row({ space: 12 }) {
                if (item.avatar) {
                  Image(item.avatar).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover);
                } else {
                  Text((item.nickname !== '' ? item.nickname : '?').charAt(0))
                    .width(44).height(44).borderRadius(22).fontSize(18).fontColor('#fff')
                    .backgroundColor($r('app.color.brand_primary')).textAlign(TextAlign.Center);
                }
                Column({ space: 4 }) {
                  Text(item.nickname).fontSize(15).fontColor($r('app.color.text_primary'));
                  if (item.bio) {
                    Text(item.bio).fontSize(12).fontColor($r('app.color.text_secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .onClick(() => {
                  this.goProfile(item);
                });

                Button(item.isFollowing ? '已关注' : '回关')
                  .height(32).borderRadius(16).padding({ left: 16, right: 16 })
                  .backgroundColor(item.isFollowing ? $r('app.color.card_bg') : $r('app.color.brand_primary'))
                  .fontColor(item.isFollowing ? $r('app.color.text_primary') : '#fff')
                  .onClick(() => {
                    this.onToggle(item);
                  });
              }
              .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 });
            }
          }, (item: FollowUser) => item.id !== undefined ? item.id.toString() : '');
        }
        .layoutWeight(1).width('100%');
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}
