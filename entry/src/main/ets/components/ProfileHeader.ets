import { ProfileIdentity } from './ProfileIdentity';
import { ProfileStatItem } from './ProfileStatItem';
import { GlassPillButton } from '../design/components/GlassPillButton';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';

// 个人资料区只负责呈现与操作意图；页面决定跳转、分享和数据加载等领域行为。
// 三颗按钮（编辑资料 / 草稿箱 / 废纸篓）统一走 GlassPillButton 模板（useSystemMaterial=false：
// 本组件宿主在内容区，材质渲染不出图，玻璃兜底配方收在模板内部，见基准 §7.6.26）。
@Component
export struct ProfileHeader {
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop gender: number = 0;
  @Prop bio: string = '';
  @Prop userId: number = 0;
  @Prop isLoggedIn: boolean = false;
  @Prop followingCount: number = 0;
  @Prop followerCount: number = 0;
  @Prop totalLikes: number = 0;
  @Prop onBackground: boolean = false;
  onOpenFollowing: () => void = (): void => {};
  onOpenFollowers: () => void = (): void => {};
  onEdit: () => void = (): void => {};
  onOpenDrafts: () => void = (): void => {};
  onOpenTrash: () => void = (): void => {};
  onLogin: () => void = (): void => {};


  build() {
    Column() {
      ProfileIdentity({
        avatar: this.avatar,
        name: this.name,
        gender: this.gender,
        bio: this.bio,
        userId: this.userId,
        onBackground: this.onBackground,
      })
      Row({ space: SpaceTokens.sm }) {
        ProfileStatItem({
          value: this.followingCount,
          label: '关注',
          onBackground: this.onBackground,
          clickable: true,
          onOpen: (): void => { this.onOpenFollowing(); },
        })
        ProfileStatItem({
          value: this.followerCount,
          label: '粉丝',
          onBackground: this.onBackground,
          clickable: true,
          onOpen: (): void => { this.onOpenFollowers(); },
        })
        ProfileStatItem({ value: this.totalLikes, label: '获赞', onBackground: this.onBackground })
        Blank().layoutWeight(1)
        GlassPillButton({
          label: this.isLoggedIn ? '编辑资料' : '去登录',
          highlight: !this.isLoggedIn,
          action: (): void => { this.isLoggedIn ? this.onEdit() : this.onLogin(); },
        })
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.sm })

      if (this.isLoggedIn) {
        Row({ space: SpaceTokens.sm }) {
          Column() {
            GlassPillButton({
              label: '草稿箱',
              icon: 'draftBox',
              fillWidth: true,
              action: (): void => { this.onOpenDrafts(); },
            })
          }
          .layoutWeight(1)
          Column() {
            GlassPillButton({
              label: '废纸篓',
              icon: 'trash',
              fillWidth: true,
              action: (): void => { this.onOpenTrash(); },
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.xs })
      }
    }
    .width('100%')
  }
}
