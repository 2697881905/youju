// 有据 主框架：悬浮底部导航栏（系统背景模糊 + 半透明分层 + 动态高光透镜）
// Tab：首页 / 圈子 / 发布 / 消息 / 我的；帖子详情经 router 单独跳转（pages/DetailPage）
import { HomeTab, FeedMode } from '../components/HomeTab';
import { CircleTab } from '../components/CircleTab';
import { CircleOnboarding } from '../components/CircleOnboarding';
import { MessagePage } from './MessagePage';
import { ProfilePage, PROFILE_SEGMENTS, BOOKMARK_SEGMENTS } from './ProfilePage';
import { initAuthStorage, getToken, getUserId, setPrivacyAgreed, isPrivacyAgreed, clearSession, PRIVACY_POLICY_VERSION } from '../utils/auth';
import { getUnreadCount, getDmUnreadCount, getMe, recordPrivacyConsent, followTag, listTags, getPost, PostWithComments, resolveDisplayImageUrl } from '../services/api';
import { Tag } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { PublishMode, PublishModePanel } from '../components/PublishModePanel';
import { SearchPanelDestination } from './SearchPanelDestination';
import { SpringPanel } from '../design/motion/SpringPanel';
import { DesignButton } from '../design/components/DesignButton';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { bottomNavInset, DOCK_WIDTH_SMALL, DOCK_BOTTOM_MARGIN_BASE, DOCK_SIDE_MARGIN_MIN, DOCK_GRADIENT_MASK_HEIGHT, DOCK_MATERIAL_TYPE, DOCK_MATERIAL_LEVEL, DOCK_BAR_HEIGHT_VP } from '../utils/cardTokens';
import { refreshBottomNavInset } from '../utils/navMode';
import { RadiusTokens } from '../design/tokens/radius';
import { ColorTokens } from '../design/tokens/color';
import { TypeTokens } from '../design/tokens/type';
import { IconTokens } from '../design/tokens/icon';
import { Pressable } from '../design/motion/Pressable';
import { resolveActionIcon } from '../utils/actionIcons';
import { resolveSettingsIcon } from '../utils/settingsIcons';
import { EXTERNAL_SHARE_ENABLED } from '../utils/share';
import { ProfileHeader } from '../components/ProfileHeader';
import { SegmentedControl } from '../design/components/SegmentedControl';
import { User } from '../models/types';
import { common } from '@kit.AbilityKit';
import { window, display, LengthMetrics } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { publishFlowStore } from '../utils/publishFlowStore';
import { AppTab, subscribeTabSwitch, emitTabSwitch, openPostDetail, openPostDetailAtComment, openChat, openFollowList, openUserProfile } from '../utils/nav';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { takePushRoute, syncPushToken, requestNotificationPermission } from '../utils/push';
import { readClipboardPostId, markClipboardIdHandled } from '../utils/clipboardJump';
import { ClipboardPostSheet, ClipboardPostPayload } from '../components/ClipboardPostSheet';
import { setMainNavStack, setSharedUiContext } from '../utils/navigationTransition';
import { AnimateCallback, CustomTransition } from '../utils/longTake/customNavigationUtils';
import { setSerifTypeface, setSerifBodyTypeface } from '../utils/poster/posterText';
import { drawing } from '@kit.ArkGraphics2D';
import { HdsTabs, HdsTabsController, HdsNavigation, HdsNavigationTitleMode,
  ScrollEffectType } from '@kit.UIDesignKit';
import { HdsMiniBarButton } from '../components/HdsMiniBarButton';
// 只 import type：这些接口在运行时被擦除，不会像 hdsMaterial 那样在 API 22 上「import 即崩」。
// 材质档位因此传数值字面量（见 immersiveMaterial 的 HDS_MATERIAL_TYPE_IMMERSIVE / _LEVEL_ADAPTIVE）。
import type {
  HdsNavigationTitleBarOptions,
  SystemMaterialParams,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  HdsNavigationBackgroundStyle,
  HdsNavigationMenuContentOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationIconOptions,
  HdsTitleBarContentStyle, HdsNavigationIconItemStyle,
} from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported, isSystemMaterialActive, FloatingTopButtonMaterialModifier, GlassBlurStyle, getSheetImmersiveMaterial, HDS_MATERIAL_TYPE_IMMERSIVE, HDS_MATERIAL_LEVEL_EXQUISITE } from '../utils/immersiveMaterial';
import { requestSystemBarRefresh } from '../utils/systemBar';
import { BottomTabBar } from '../design/components/BottomTabBar';
import { PostDetailDestination } from './PostDetailDestination';
import { UserProfileDestination } from './UserProfileDestination';
import { CircleDetailDestination } from './CircleDetailDestination';
import { ChatDestination } from './ChatDestination';
import { MyFollowDestination } from './MyFollowDestination';
import { LoginDestination } from './LoginDestination';
import { VideoPlayerDestination } from './VideoPlayerDestination';

// 剪贴板回流（「复制有据链接 → 回 App 提示打开」）依赖受限 ACL 权限 ohos.permission.READ_PASTEBOARD。
// 该权限在 AGC 的 **发布** 场景未获批（新建发布 Profile 勾选「受限ACL权限」后 allowed-acls 仍为空），
// 包内声明它会被 AGC 判 7014「包内权限必须是 Profile 申请权限的子集」→ v1.0.1 提审先关闭此入口，
// module.json5 同步移除了权限声明（两处注释互相引用）。
// 待 AGC 批下 release 的 ACL 权限后：把本开关置 true + module.json5 加回声明即可完整复原
// （utils/clipboardJump.ets 与 components/ClipboardPostSheet.ets 均未删除）。
const PASTEBOARD_LINK_JUMP_ENABLED: boolean = false;

// —— 「我的」顶栏（迁入内嵌 HdsNavigation，路线 B：与首页/圈子/消息同构）——
// 结构：content.stackBuilder 自排衬线标题 + content.menu 官方 40vp 圆钮，栏体**只有这一行**。
// 资料卡与分段栏不再挂 bottomBuilder —— 栏体节点之内抓不到滚动源，装进去就等于从手势里摘出去，
// 带资料卡那一版实测把屏顶 41%（栏底 1209px）变成滑动盲区。它们回到 ProfilePage 那条 List 里：
// 资料卡 = 第 0 项（随列表滚走、穿到栏底之下被模糊），分段栏 = 吸顶组头。见基准 §7.6.13b。
// 官方 MINI 标题行高：实测 175px ÷ 3.125 = 56vp，系统定值、不可调。
const PROFILE_TITLE_ROW_VP: number = 56;
// 滚动渐变模糊生效区间终点：与首页/圈子定稿一致
const PROFILE_BLUR_END_VP: number = 32;
// 标题栏高斯半径，沿用迁移前外层标题栏 backgroundEffect 的实测值。取值区间 [0,128]。
// 官方限定只在 GRADIENT_BLUR / IMMERSIVE_GRADIENT_BLUR 下生效，本页用后者。
const PROFILE_BLUR_RADIUS: number = 50;

// —— 底部 Dock 液态选中指示器（沉浸光感 tabbar 优化方案落地，基准 §7.6.32）——
// 参照华为开发者文章 03212848303315412。官方 HdsTabs 悬浮条**没有**选中态胶囊：
// 真机 dumpLayout 只量到 TabBar > Column > {Image, Text}，选中仅换 fillColor
// （首页 255 画布上蓝 0066CC vs 灰 3C3C43），正是原文说的「状态指示辨识度不足」。
// 故按原文思路在 Dock 之上叠一层覆盖式指示器，靠「行进 + 鼓包 + 落地回弹」讲清选中位置。
// 与原文的两处偏离（理由见基准 §7.6.32 / §7.6.33）：
// ① 不接拖拽切页 —— 整页左右滑已开放（§7.6.33），再给胶囊单独挂 PanGesture 就是叠第二个
//    手势；且 HdsTabsAttribute 没有 onGestureSwipe，胶囊无法与页面同帧跟手，只能挂
//    onAnimationStart 与翻页动画同批飞。
// ② 宽度按**实测槽距**而非槽位节点宽度 —— 页签 Column 写死 64vp，但系统按 barWidth 档
//    排出的实际中心间距只有 55.2vp（实测中心 222/394/567/740/912px，间距 172.5px），
//    相邻槽位框互叠 27.5px，照节点宽度画会盖住邻居。
// 胶囊尺寸按参照图的**比例**来，不是往槽位里塞：原文效果预览量到胶囊宽 ≈ 1.22 倍槽距、
// 高 ≈ 0.93 倍栏高 —— 它是盖过槽位、并在行进中溢出 Dock 圆端的。上一版做成"槽位内缩
// 6/3vp"，尺寸方向整个反了：胶囊比内容还窄，玻璃的体积感无从谈起。
const DOCK_PILL_W_RATIO: number = 1.22;
// 相对实测槽高（54vp；栏高 56vp，槽位框向下溢 2vp）
const DOCK_PILL_H_RATIO: number = 0.96;
// 行进中的额外放大（用户拍板 2026-10-26 弹动加强：+6 → +10）。
const DOCK_PILL_BULGE: number = 10;
const DOCK_PILL_TRAVEL_MS: number = 300;
// 落定回弹时长：曲线换 springBounce（overshoot 果冻感）后给足走完物理行程的余量。
const DOCK_PILL_SETTLE_MS: number = 400;
// HdsMiniBarButton 容器 contentPadding（防光效裁切的余量）。⚠️ 容器 size 公式是
// 「barHeight + contentPadding×4」（高 32）而玻璃条在容器内居中——position 补偿量 =
// 容器半高 − 玻璃半高 = contentPadding×2 = 16（上一版只补 8，残差偏下 8vp 致底部溢出）。
const DOCK_PILL_MINI_PAD: number = 16;
// —— 拖拽液态交互参数（原型页 DockPillDragProtoPage 真机定档 2026-10-26，移植进主框架）——
// 速度形变上限（vp）：快甩的拉扯感。
const DOCK_PILL_SPEED_MAX_DEFORM: number = 22;
// 反方向（回拉）交叉形变系数：回拉收宽涨高。
const DOCK_PILL_DEFORM_CROSS: number = 0.5;
// 速度归一基准（vp/s）：轻甩约 400-600、快甩约 1200-1800。
const DOCK_PILL_SPEED_NORMALIZE_VP: number = 1200;
// 速度低于此值不形变（滤手抖噪声）。
const DOCK_PILL_SPEED_MIN_VP: number = 120;
// 速度指数平滑因子。
const DOCK_PILL_SPEED_SMOOTH: number = 0.3;
// 停顿判定：超过 90ms 无 200vp/s 以上速度视为停顿，重置形变方向。
const DOCK_PILL_PAUSE_MS: number = 90;
const DOCK_PILL_PAUSE_SPEED_VP: number = 200;
// 边缘阻尼：首/尾槽往界外拖的跟手衰减。
const DOCK_PILL_EDGE_DAMPING: number = 0.3;
// 冷启动时覆盖层与 TabBar 槽位的先后不确定，量不到就按帧重试这么多回。
const DOCK_PILL_MEASURE_RETRIES: number = 6;

// ⚠️ 点光源（hdsEffect）在自绘玻璃上**不可用**，试过三档、结论记在这里免得再走一遍：
//   BRIGHT + BORDER_CONTENT → 整块过曝（胶囊 231→255、图标 86→252，内容被擦掉）；
//   SOFT + BORDER → +4 级，等于没反应；BRIGHT + BORDER → 同样 +4 级。
// 机理：`illuminatedType` 的「照边框」作用在**材质自己的边框**上，而覆盖层拿不到
// systemMaterial（§7.6.26 + 本轮判定实验），所以只有「照内容」那条路会出效果 —— 而它
// 洗的正是我们要保持清晰的图标。原文那档 BORDER_CONTENT 是深色底，光打上去是反光；
// 压到近乎纯白的 Dock（251，上限 255）上就只剩白化。按压反馈改走按压缩放，见 dockSelectionPill。
// ✅ 2026-10-26 终解：胶囊本体换 HdsMiniBarButton（hds_button 源码本地集成，见
// components/HdsMiniBarButton.ets）——它内部「Row 包 HdsTabs」借悬浮态官方材质通道，
// 在覆盖层出真沉浸光感玻璃，自绘 tint/rim/backdropBlur 全部退役。

// Dock 指示器的一帧几何：中心点相对 dockPillLayer 左上角，单位 vp。
interface DockPillFrame {
  cx: number;
  cy: number;
  w: number;
  h: number;
}

// 窗口坐标下的一个矩形（vp）。只用来算差值，不参与渲染，故存普通成员而非 @State。
interface DockArea {
  x: number;
  y: number;
  w: number;
  h: number;
}

// 底部页签数据项（含发布占位 tab）。发布 tab 也走同一 builder，展示 + 图标。
interface IndexTabItem {
  key: string;
  title: string;
  icon: Resource;
  color?: ResourceColor;
}

// 首启/更新隐私同意弹窗。
// 样式层完全对齐应用设计系统，面板规格与 PublishModePanel / FolderNameDialog 同规格
// （panelWidth 344 / panelPadding lg / radius lg / solid 实色档）：
//   · 材质走 solid 档（elevated 实色暖纸底 + separator 1px 发丝描边 + cardAmbient 阴影）。
//     承载合规正文的浮层不用半透明玻璃 —— 玻璃底会让正文对比度随背景漂移，
//     且 docs/feature-index.md 已实测「大面积承载正文不适合 outlined/透明底」。
//   · 正文与链接落在 solid 底上的实测对比度（WCAG）：
//     浅色 primary 17.9:1 / secondary 11.0:1 / brand 5.1:1；
//     深色 primary 15.1:1 / secondary 8.1:1 / brand 7.6:1。全部 AA 及以上。
//   · 底部两键：主键 DesignButton primary（brand 实色 + onBrand 字，浅 5.2:1 / 深 8.2:1），
//     次键自绘（透明底 + separator 描边 + secondary 字，浅 11.0:1 / 深 8.1:1），
//     不再用 iOS 亮红（旧实现 semantic_red 在浅色玻璃底上仅 3.1:1，不达 AA）。
//   · 正文放 Scroll 并按屏高封顶（maxBodyHeightVp），长文滚动不塌陷、
//     标题与按钮行常驻可见；面板宽度按屏宽封顶 344、下限 280，适配小屏与大屏。
// 仅调整样式层：打开/关闭、协议跳转、同意/不同意行为与回调签名均未改动。
@CustomDialog
struct PrivacyConsentDialog {
  controller: CustomDialogController;
  getIsUpdate: () => boolean = (): boolean => false;
  onReadPrivacy: () => void = (): void => {};
  onReadAgreement: () => void = (): void => {};
  onAgree: () => void = (): void => {};
  onDecline: () => void = (): void => {};

  // 屏宽（vp）：面板宽度基准。px→vp 走 densityPixels 除法（与 utils/navMode.ets 同法，
  // 不依赖 px2vp 的 UIContext 形态 —— 那是 @since 22，高于工程下限 20）。
  // 取不到时按应用标准宽度 344 兜底。
  private screenWidthVp(): number {
    try {
      const d: number = display.getDefaultDisplaySync().densityPixels;
      const w: number = display.getDefaultDisplaySync().width;
      return d > 0 && w > 0 ? w / d : 344;
    } catch (e) {
      return 344;
    }
  }

  // 面板宽度：标准 344；窄屏按屏宽留边不溢出，宽屏不再无限拉伸。
  private panelWidth(): number {
    const w: number = this.screenWidthVp();
    return Math.max(280, Math.min(344, w - 48));
  }

  // 正文区最大高度（vp）：约屏高 1/3 封顶，保证标题与按钮行始终留在可视区内。
  private maxBodyHeightVp(): number {
    try {
      const d: number = display.getDefaultDisplaySync().densityPixels;
      const h: number = display.getDefaultDisplaySync().height;
      if (d <= 0 || h <= 0) {
        return 240;
      }
      return Math.max(160, Math.round(h / d / 3));
    } catch (e) {
      return 240;
    }
  }

  @Builder
  policyLink(label: string, action: () => void): void {
    // 条款链接与 LoginView 底部「《用户协议》/《隐私政策》」同语言：brand 色 + headline 字重，
    // 不加下划线（应用内链接统一不装饰，避免与正文混淆）。
    Text(label)
      .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight)
      .lineHeight(TypeTokens.callout.lineHeight)
      .fontColor(ColorTokens.brand)
      .onClick((): void => {
        action();
      })
  }

  build() {
    SpringPanel({ panelWidth: this.panelWidth(), panelPadding: SpaceTokens.lg, solid: true }) {
      Column({ space: SpaceTokens.base }) {
        // 标题：衬线 + headline 字级（与 PublishModePanel / FolderNameDialog 弹窗标题同规格）
        Text(this.getIsUpdate() ? '隐私政策更新' : '隐私政策与用户协议')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(ColorTokens.primary)
          .width('100%')
          .textAlign(TextAlign.Center)

        // 正文 + 条款链接：可滚动区，长文本滚动时标题/按钮不塌陷
        Scroll() {
          Column({ space: SpaceTokens.md }) {
            Text(this.getIsUpdate()
              ? '我们的隐私政策已更新，请阅读并重新同意以继续使用。'
              : '欢迎使用有据。我们仅在为你提供内容推荐、账号安全等必要服务时收集相关信息。')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .fontColor(ColorTokens.secondary)
              .width('100%')

            // 链接区：Flex 换行容器，窄屏/大字体下链接换行而不溢出
            Flex({ wrap: FlexWrap.Wrap }) {
              Text('点击查看')
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.callout.weight)
                .lineHeight(TypeTokens.callout.lineHeight)
                .fontColor(ColorTokens.tertiary)
              this.policyLink('《隐私政策》', (): void => { this.onReadPrivacy(); })
              Text('和')
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.callout.weight)
                .lineHeight(TypeTokens.callout.lineHeight)
                .fontColor(ColorTokens.tertiary)
              this.policyLink('《用户协议》', (): void => { this.onReadAgreement(); })
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .width('100%')
        .constraintSize({ maxHeight: this.maxBodyHeightVp() })
        .scrollBar(BarState.Auto)

        // 底部操作：主次分明。
        // ⚠️ 写法约束（ArkTS 解析规则，报 10505001）：自定义组件若带尾随闭包
        // `Foo({...}) { ... }`，闭包后**不能再接属性链**。Pressable / SpringPanel 都属此类，
        // 不能写成 `Pressable({...}){...}.layoutWeight(1)`（本项目 ReportAdminPage.ets:1153
        // 已记过同一条坑）。DesignButton 走构造参数、无尾随闭包，故可以链式挂 layoutWeight。
        //   · 同意 = DesignButton primary：brand 实色 + onBrand 字（浅 5.2:1 / 深 8.2:1），
        //     填充与面板 5.1:1 / 7.6:1，主键辨识度足够。
        //   · 不同意 = 自绘：透明底 + separator 描边 + secondary 字。
        //     不用 DesignButton('outlined'/'glass')：二者在 elevated 实色底上的描边
        //     分别只有 1.07:1 与 1.09:1（barBorder / separator 压 elevated），
        //     等于看不见 —— 见 docs/home-segmented-control-style-audit.md §5.2。
        //     按压反馈用 Text.stateStyles（同 SettingsPage.ets:189 写法）。
        Row({ space: SpaceTokens.md }) {
          Text('不同意')
            .layoutWeight(1)
            .height(LayoutTokens.minTouchTarget)
            .textAlign(TextAlign.Center)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary)
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.pill)
            .stateStyles({
              normal: {
                .opacity(1)
              },
              pressed: {
                .opacity(0.7)
                .scale({ x: 0.97, y: 0.97 })
              }
            })
            .onClick((): void => {
              this.controller.close();
              this.onDecline();
            })

          DesignButton({
            label: '同意并继续',
            fillWidth: true,
            visualHeight: LayoutTokens.minTouchTarget,
            action: (): void => {
              this.controller.close();
              this.onAgree();
            },
          })
            .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
    }
  }
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State privacyDialogShown: boolean = false; // 防隐私弹窗重复弹出
  @State privacyDialogIsUpdate: boolean = false;
  // 隐私同意标记（PersistentStorage 字符串 '0'/'1'，见 utils/auth.ets）。
  // 未同意前不构建主 Tab 内容——TabContent 的子组件会立即挂载，而 HomeTab/CircleTab/
  // MessagePage/ProfilePage 的 aboutToAppear 里就会发网络请求（continueLaunchFlow 的
  // 同意闸门只挡住 startInit()，挡不住这条路径，属「告知—同意前处理」红线）。
  @StorageLink('privacyAgreed') privacyAgreed: string = '0';
  @StorageLink('unreadMessageCount') unreadCount: number = 0;
  @StorageLink('unreadDmCount') dmUnread: number = 0;
  @StorageLink('circleOnboardingPendingUserId') @Watch('onCircleOnboardingPendingChanged') circleOnboardingPendingUserId: string = '';
  // 登录态过期标记：api.ets 在服务端 401（非登录接口）时写入，本页统一清态 + 提示 + 引导重登
  @StorageLink('authExpiredAt') @Watch('onAuthExpired') authExpiredAt: number = 0;
  // 通知点击带来的待处理路由序号（值 payload 在 AppStorage['pendingPushRoute']）。
  // 用单调递增的序号而非 payload 本身做信号：连点两条同类通知时值可能相同，
  // AppStorage 对同值写入不派发变更，必须有序号才会触发回调。
  @StorageLink('pushRouteSeq') @Watch('onPushRouteChanged') pushRouteSeq: number = 0;
  // 剪贴板分享链接检查信号（EntryAbility.onForeground 递增）：暖前台回切时重新检测。
  // 冷启动的检测点在 continueLaunchFlow / agreePrivacy（挂载后一次性触发）。
  @StorageLink('clipboardCheckSeq') @Watch('onClipboardCheckSeq') clipboardCheckSeq: number = 0;
  // 剪贴板命中的帖子（确认面板数据）。id > 0 = 面板展示中，期间忽略重复检查信号。
  @State clipboardPostId: number = 0;
  @State clipboardPostTitle: string = '';
  @State clipboardAuthorName: string = '';
  private clipboardBusy: boolean = false;
  @State showCircleOnboarding: boolean = false;
  @State onboardingTags: Tag[] = [];
  @State onboardingSelectedNames: string[] = [];
  @State onboardingLoading: boolean = false;
  @State onboardingSubmitting: boolean = false;
  @State statusBarHeight: number = 0;
  @State navBarHeight: number = 0;
  @State launchComplete: boolean = false;
  private hdsController: HdsTabsController = new HdsTabsController();
  // API 20-22 分支用内置 Tabs（API 7）承载内容，底栏由自绘玻璃药丸（BottomTabBar）负责。
  private tabsController: TabsController = new TabsController();
  // 悬浮玻璃底栏（barFloatingStyle 及其全部字段）@since 6.1.0(23)：API 6.0.2(22) 上调用会抛
  // TypeError（方法不存在）导致首页无法渲染。isImmersiveLightSenseSupported() 现为同步确定值
  // （deviceInfo.sdkApiVersion + canIUse，进程级缓存），不会运行期翻转 → 组件不会重建。
  private hdsFloatingBar: boolean = isImmersiveLightSenseSupported();
  // —— Dock 液态选中指示器（几何全部来自实测，不写死槽位坐标）——
  // 中心点相对 dockPillLayer 左上角，单位 vp；ready 前不绘制，避免首帧在 (0,0) 闪一下。
  @State dockPillReady: boolean = false;
  // 胶囊当前盖住（并代替官方那份显示清晰副本）的页签下标；-1 = 还没落位，官方全部照常绘制。
  @State dockPillCovered: number = -1;
  // 手指正按在玻璃上：按压缩放 + 落影收紧，见 dockSelectionPill。
  @State dockPillPressed: boolean = false;
  @State dockPillX: number = 0;
  @State dockPillY: number = 0;
  @State dockPillW: number = 0;
  @State dockPillH: number = 0;
  // 槽位 / 覆盖层的窗口矩形（vp），来自各自 onAreaChange.globalPosition。
  // ⚠️ 不用 componentUtils.getRectangleById：它对 TabBar 子树返回的 windowOffset.y 比
  //    实际渲染位置低 88px（真机实测：槽位渲染在 y=2439，接口回 2527），照它画会把
  //    胶囊甩到 Dock 底下。onAreaChange 与 .position() 同为 vp 窗口坐标，同源才不会偏。
  private dockSlotAreas: DockArea[] = [];
  private dockLayerArea: DockArea | null = null;
  // 复位测量去重 + 有限重试：覆盖层与 TabBar 槽位谁先布局不固定。
  private dockPillMeasurePending: boolean = false;
  private dockPillMeasureRetries: number = 0;
  private dockPillSettleTimer: number = -1;
  // —— 玻璃珠拖拽（原型页验证过的交互移植，2026-10-26）——
  // 拖拽实时偏移：逐帧直写跟手，travel 里随 animateTo 归零插值。
  @State dockPillDragOffsetX: number = 0;
  // 拖拽过程量（非渲染态）：采样点 / 平滑速度 / 形变方向 / 停顿检测。
  private dockPillLastGestureX: number = 0;
  private dockPillLastGestureTs: number = 0;
  private dockPillSmoothedVp: number = 0;
  private dockPillInitialDirection: number = 0;
  private dockPillLastActiveTs: number = 0;
  private dockPillPauseDetected: boolean = false;
  // 实测槽距缓存：拖拽松手换算「拖了几个槽」（dockPillFrameOf 成功路径顺带回填）。
  private dockPillPitch: number = 0;
  // —— 首页顶栏共享状态：顶部区域（品牌标题/搜索/分段栏/圈子按钮）整体驻留
  // Navigation 标题栏后由本页持有，HomeTab 通过 @Link 共用并联动信息流 ——
  @State feedIndex: number = 0;
  @State feedMode: FeedMode = 'recommend';
  @State tagIndex: number = 0;
  @State displayTags: Tag[] = [];
  @State showCircleDropdown: boolean = false;
  // —— 「我的」页顶栏共享状态：顶栏（我的/分享/设置 + 资料区 + 主分段栏）同样驻留标题栏 ——
  @State profileUser: User = {};
  @State profileFollowingCount: number = 0;
  @State profileFollowerCount: number = 0;
  @State profileTotalLikes: number = 0;
  @State profileTabIdx: number = 0;
  // 「我收藏」子分段（帖子 | 收藏夹）：控件渲染在标题栏，选中态由 Index 持有、@Link 下发给 ProfilePage
  @State profileBookmarkSubTab: number = 0;
  // 收藏夹条数：ProfilePage 拉完后回写，标题栏据此决定「管理」入口出不出现（空列表无可管理的东西）
  @State profileFolderCount: number = 0;
  @State profilePresented: boolean = false;
  @State profileShareSeq: number = 0;
  // 顶栏模糊出图开关：**绝对滚动偏移** >0 即开（onListScroll 喂入 currentOffset，非每帧增量
  // ——增量正负会被松手回弹的负帧打灭，「松手模糊消失」根因，2026-10-24 修复）。
  @State profileBarScrolled: boolean = false;
  // 「我的」整页只剩一条 List（资料卡是它的第 0 项，四分段改为点击切换），所以只有一个滚动源。
  // 交给内嵌 HdsNavigation 的 bindToScrollable 驱动标题栏渐变模糊 —— GRADIENT_BLUR 与
  // bindToScrollable 是一对，只开模糊不绑源会把列表滚动整条吃掉（真机实证，基准 §7.6.12）。
  private profileScrollers: Scroller[] = [new Scroller()];

  // —— 「消息」页共享状态：分段选中态/未读徽标源（顶栏已迁入 MessagePage 内嵌 HdsNavigation）——
  // （unreadCount/dmUnread 经 AppStorage @StorageLink 直达 MessagePage 与底栏红点）
  @State messageTabIndex: number = 0;
  @State messageTabPulse: boolean = false;
  @State messageMarkAllSeq: number = 0;
  // —— 「圈子」页顶栏共享状态：顶栏（圈子标题 + 已加入药丸）迁入标题栏 ——
  // （星环画布、选中卡片等仍在 CircleTab 内容区，不经此处）
  @State circleJoinedCount: number = 0;   // 已加入 N 个：CircleTab 加载后经 @Link 回写
  @State circleJoinedSeq: number = 0;     // 点击药丸的递增信号，弹窗仍由 CircleTab 承接
  // 顶栏分段切换的透明反馈动画遵循系统「减弱动态效果」
  @StorageLink('reduceMotion') reduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  // 全局断点（sm/md/lg）：供悬浮栏宽度档取值——见 barFloatingStyle.barWidth 的说明
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';
  // 导航栈：主框架为 Navigation 首页，帖子详情等走 navDestination（首页卡片一镜到底）
  private pageStack: NavPathStack = new NavPathStack();
  private unsubscribeTabSwitch: () => void = () => {};
  // 发布方式面板：bindSheet 半模态（SheetType.CENTER + detents FIT_CONTENT），双向绑定控制显隐。
  // 手势下滑 / 返回键 / 点遮罩关闭时由 $$ 与 onDisappear 同步回 false，无需 CustomDialogController。
  // 剪贴板分享链接确认面板：命中 youju.chat/post/{id} 后由用户决定是否打开
  private clipboardSheetController: CustomDialogController = new CustomDialogController({
    builder: ClipboardPostSheet({
      getPayload: (): ClipboardPostPayload | null => this.clipboardPayload(),
      onOpen: (): void => { this.openClipboardPost(); },
      onIgnore: (): void => { this.dismissClipboardPost(); },
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true,
    // 点击面板外/返回键关闭同样视为「忽略」：本会话内不再对该链接打扰
    cancel: (): void => { this.dismissClipboardPost(); },
  });
  private privacyConsentController: CustomDialogController = new CustomDialogController({
    builder: PrivacyConsentDialog({
      getIsUpdate: (): boolean => this.privacyDialogIsUpdate,
      onReadPrivacy: (): void => {
        // 审核修复：先关闭弹窗再打开政策页，避免内容被 Modal 遮挡无法阅读；返回后未同意则重弹
        this.privacyDialogShown = true;
        this.privacyConsentController.close();
        this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage' });
      },
      onReadAgreement: (): void => {
        this.privacyDialogShown = true;
        this.privacyConsentController.close();
        this.getUIContext().getRouter().pushUrl({ url: 'pages/UserAgreementPage' });
      },
      onAgree: (): void => { this.agreePrivacy(); },
      onDecline: (): void => { this.declinePrivacy(); },
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
  });

  private bottomTabItems(): IndexTabItem[] {
    return [
      { key: 'home', title: '首页', icon: $r('app.media.nav_home'), color: $r('app.color.ds_brand') },
      { key: 'circle', title: '圈子', icon: $r('app.media.nav_circle'), color: '#34C759' },
      { key: 'publish', title: '发布', icon: $r('app.media.nav_publish'), color: '#FF9500' },
      { key: 'message', title: '消息', icon: $r('app.media.nav_message'), color: '#AF52DE' },
      { key: 'profile', title: '我的', icon: $r('app.media.nav_profile'), color: '#FF2D55' },
    ];
  }

  // 内置开源宋体（Noto Serif SC），保证「全文科感」标题在无系统宋体的设备上也真实呈现。
  private registerSerifFont(): void {
    try {
      this.getUIContext().getFont().registerFont({
        familyName: 'Noto Serif SC',
        familySrc: $rawfile('fonts/NotoSerifSC-Bold.otf'),
      });
      // 正文字重：Regular 单独注册一个 family（一个 familyName 只能绑一个字体文件），
      // 正文用 Bold 字形会被整体拉粗，与标题失去层次。
      this.getUIContext().getFont().registerFont({
        familyName: 'Noto Serif SC Body',
        familySrc: $rawfile('fonts/NotoSerifSC-Regular.otf'),
      });
      // 创建 drawing Typeface 并传递给 textPoster.ets，让 canvas 绘制也使用衬线字体
      const typeface: drawing.Typeface = drawing.Typeface.makeFromRawFile($rawfile('fonts/NotoSerifSC-Bold.otf'));
      setSerifTypeface(typeface);
      // 海报正文用 Regular 字重，标题仍用 Bold
      const bodyTypeface: drawing.Typeface = drawing.Typeface.makeFromRawFile($rawfile('fonts/NotoSerifSC-Regular.otf'));
      setSerifBodyTypeface(bodyTypeface);
      hilog.info(0x0000, 'Index', 'serif font registered');
    } catch (err) {
      hilog.error(0x0000, 'Index', 'register serif font failed: %{public}s', JSON.stringify(err));
    }
  }

  aboutToAppear(): void {
    // 注册全局唯一 UIContext：util 文件（auth/navigationTransition 等）没有组件上下文，
    // 替换已废弃的全局 router/组件工具 API 时从这里取（与 mainNavStack 同一注册时机）。
    setSharedUiContext(this.getUIContext());
    this.registerSerifFont();
    initAuthStorage();
    setMainNavStack(this.pageStack);
    AppStorage.setOrCreate<number>('circleLogoDismissVersion', AppStorage.get<number>('circleLogoDismissVersion') ?? 0);
    this.unsubscribeTabSwitch();
    this.unsubscribeTabSwitch = subscribeTabSwitch((target: AppTab): void => {
      this.selectTab(target);
    });
    // TabContent 会提前创建隐藏页面；先广播真实激活项，避免隐藏页误触发登录守卫。
    AppStorage.setOrCreate<number>('activeTab', this.currentIndex);
    this.setupFullScreen();
    this.continueLaunchFlow();
  }

  onPageShow(): void {
    // 从隐私政策/用户协议页返回时，若用户尚未同意，重新弹出同意弹窗（审核可用性修复）
    if (this.privacyDialogShown && !isPrivacyAgreed()) {
      this.showPrivacyDialog(this.privacyDialogIsUpdate);
      return;
    }
    if (this.launchComplete && getToken() !== '') {
      this.refreshUnread();
      this.maybeShowCircleOnboarding();
      // 登录/切号返回首页时补推送初始化：冷启动为访客时 startInit 会跳过推送注册，
      // 这里兜住「游客 → 应用内登录」路径（syncPushToken 幂等，已上报则空跑）
      this.initPushCapabilities();
    }
  }

  aboutToDisappear(): void {
    this.unsubscribeTabSwitch();
    this.unsubscribeTabSwitch = () => {};
  }

  private async setupFullScreen(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }
      const win = await window.getLastWindow(ctx);
      await win.setWindowLayoutFullScreen(true);
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = this.getUIContext().px2vp(area.topRect.height);
      // 底部导航高度（审核问题③）：三键导航条区域在 NEXT 上由 TYPE_NAVIGATION_INDICATOR 报告
      //（TYPE_SYSTEM bottomRect 实测为 0），手势指示条也在该类型。取两者最大值——
      // 三键 ≈28-40vp 抬升避让，手势 ≈16vp 顺带避开指示条。
      const sysBottom = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navIndicator = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.navBarHeight = Math.max(this.getUIContext().px2vp(sysBottom.bottomRect.height), this.getUIContext().px2vp(navIndicator.bottomRect.height));
      AppStorage.setOrCreate<number>('statusBarHeight', this.statusBarHeight);
      AppStorage.setOrCreate<number>('navBarHeight', this.navBarHeight);
      // 首帧实测回写后立即重算避让量：initNavModeWatcher 在窗口实测之前跑过一轮
      // （那时 navBarHeight 还没测出来，非华为 ROM 上靠它兜底判三键会算成 0）。
      // 这里补齐，避免「详情页外的底栏避让量停在 0」。
      refreshBottomNavInset();
    } catch (e) {
      // 失败不阻断
    }
  }

  private startInit(): void {
    // 冷启动即探测一次沉浸光感能力（真实日志输出），确保设备能力在首页构建期可用。
    isImmersiveLightSenseSupported();
    // 访客可浏览首页/圈子等公开内容；登录仅用于发布/私信/个人中心等需鉴权操作。
    // 未登录不再强制弹出登录页，避免“进首页即强制登录”的体验；登录态就绪时再补拉个人数据。
    if (getToken() === '') {
      // 访客也可能经 youju:// 分享链接（落地页「去有据看看」按钮）或通知点击冷启动：
      // 帖子/主页内容公开，路由意图的消费不依赖登录态——否则访客冷启动的直达意图会被静默丢掉
      this.consumePendingPushRoute();
      return;
    }
    this.validateStartupSession();
    this.refreshUnread();
    this.maybeShowCircleOnboarding();
    this.initPushCapabilities();
    // 冷启动若来自通知点击，路由意图在 Index 挂载前已由 EntryAbility 写入 AppStorage，此处补消费
    this.consumePendingPushRoute();
  }

  // 登录后启用推送：先申请通知权限（未授权时系统不把 Push 消息展示进通知栏），再上报本机 Token。
  // 两者都异步且失败静默 —— 取不到 token 只影响推送，不波及主流程。
  private initPushCapabilities(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined && ctx !== null) {
      requestNotificationPermission(ctx as common.UIAbilityContext);
    }
    syncPushToken();
  }

  // 消费通知点击带来的路由意图（一次性取出即清空）
  private consumePendingPushRoute(): void {
    const route = takePushRoute();
    if (route === null) {
      return;
    }
    if (route.type === 'dm' && route.peerId > 0) {
      // 私信：直接进会话页，peer 头像缺失交给 ChatView 走占位
      openChat({ peerId: route.peerId, peerName: route.peerName, peerAvatar: '' });
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ChatPage' });
      } catch (e) {
        hilog.warn(0x0000, 'push', '通知跳转私信页失败 %{public}s', JSON.stringify(e));
      }
      return;
    }
    if (route.userId > 0) {
      // deep link youju://user/{id}（分享落地页拉起）：与站内点击头像同通道进他人主页
      openUserProfile(route.userId);
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
      } catch (e) {
        hilog.warn(0x0000, 'push', '链接拉起用户主页失败 %{public}s', JSON.stringify(e));
      }
      return;
    }
    if (route.postId > 0) {
      // @提及带 commentId 时定位到具体评论，其余进详情顶部
      if (route.commentId > 0) {
        openPostDetailAtComment(String(route.postId), route.commentId);
      } else {
        openPostDetail(String(route.postId));
      }
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
      } catch (e) {
        hilog.warn(0x0000, 'push', '通知跳转详情页失败 %{public}s', JSON.stringify(e));
      }
      return;
    }
    // 无关联帖子（关注 / 系统通知）：落到消息 Tab
    emitTabSwitch(3);
  }

  private onPushRouteChanged(): void {
    // 启动流程未走完时 Tab 容器还没就绪，先不跳：pendingPushRoute 保留着，
    // 由 startInit 兜底消费；已就绪则该走 @Watch 的实时路径（热启动点通知）。
    if (!this.launchComplete) {
      return;
    }
    this.consumePendingPushRoute();
  }

  // ===== 剪贴板分享链接：抖音式「复制打开有据」 =====
  // 链接只来自我们自己生成的分享文案（youju.chat/post/{id}）；命中后先弹确认面板，
  // 用户点「打开帖子」才跳转 —— 不静默读取跳转；同一链接本会话内只打扰一次。

  private clipboardPayload(): ClipboardPostPayload | null {
    if (this.clipboardPostId <= 0) {
      return null;
    }
    const payload: ClipboardPostPayload = {
      postId: this.clipboardPostId,
      title: this.clipboardPostTitle,
      authorName: this.clipboardAuthorName,
    };
    return payload;
  }

  private onClipboardCheckSeq(): void {
    // 启动流程未走完（或隐私未同意）不检测：冷启动由 continueLaunchFlow/agreePrivacy 统一触发
    if (!this.launchComplete || !isPrivacyAgreed()) {
      return;
    }
    this.checkClipboardPostLink();
  }

  private async checkClipboardPostLink(): Promise<void> {
    // 权限未获批期间整条链路关闭（见文件头 PASTEBOARD_LINK_JUMP_ENABLED 说明）
    if (!PASTEBOARD_LINK_JUMP_ENABLED) {
      return;
    }
    if (this.clipboardBusy || this.clipboardPostId > 0) {
      return;
    }
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined || ctx === null) {
      return;
    }
    const id: number = await readClipboardPostId(ctx as common.UIAbilityContext);
    // 异步窗口内可能已被处理（重复信号 / 面板已打开）
    if (id <= 0 || this.clipboardBusy || this.clipboardPostId > 0) {
      return;
    }
    this.clipboardBusy = true;
    try {
      const post: PostWithComments = await getPost(id);
      this.clipboardPostId = id;
      this.clipboardPostTitle = post.title ?? '';
      this.clipboardAuthorName = post.user?.nickname ?? '有据用户';
      this.clipboardSheetController.open();
    } catch (e) {
      // 帖子已删除 / 无权访问 / 网络失败：本会话不再对同一链接重复打扰
      markClipboardIdHandled(id);
    } finally {
      this.clipboardBusy = false;
    }
  }

  private openClipboardPost(): void {
    const id: number = this.clipboardPostId;
    this.dismissClipboardPost();
    if (id <= 0) {
      return;
    }
    // 与通知点击跳转同一通道：意图通道 openPostDetail + router 推 DetailPage
    openPostDetail(String(id));
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    } catch (e) {
      hilog.warn(0x0000, 'Index', '剪贴板跳转详情页失败 %{public}s', JSON.stringify(e));
    }
  }

  private dismissClipboardPost(): void {
    markClipboardIdHandled(this.clipboardPostId);
    this.clipboardPostId = 0;
    this.clipboardSheetController.close();
  }

  // 启动就绪后的剪贴板检查：有待消费的通知跳转意图时让位（本次跳过，回前台信号会再来）
  private checkClipboardPostLinkAfterStart(): void {
    if ((AppStorage.get<string>('pendingPushRoute') ?? '') !== '') {
      return;
    }
    this.checkClipboardPostLink();
  }

  private onCircleOnboardingPendingChanged(): void {
    if (!this.launchComplete) {
      return;
    }
    this.maybeShowCircleOnboarding();
  }

  // 登录态过期（服务端 401，api.ets 打的全局标记）：清本地登录态 → 提示 → 引导重新登录。
  // 用户此前"看起来还登录着"（本地 token 在、界面显示昵称），但所有鉴权操作都会失败——
  // 统一在此收口，避免用户到处碰壁却不知道要重新登录。
  private onAuthExpired(): void {
    if (!this.authExpiredAt) {
      return;
    }
    // 能走到这里必然是「本地曾有 token 但服务端判定失效」—— 匿名访客的 401 已在 api.ets
    // 的 markAuthExpired 里被拦掉（不打标记），那种情况交给各入口/目标页自己的登录闸门。
    clearSession();
    safeShowToast(this.getUIContext(), { message: '登录已过期，请重新登录' });
    try {
      const r = this.getUIContext().getRouter();
      const state = r.getState();
      // 已在登录页时不重复入栈
      if (!state || state.path !== 'pages/LoginPage') {
        r.pushUrl({ url: 'pages/LoginPage' });
      }
    } catch (e) {
      // router 未就绪等异常不阻断（下次 401 标记会再试）
    }
  }

  private continueLaunchFlow(): void {
    if (this.launchComplete) {
      return;
    }
    this.launchComplete = true;
    // 隐私需「明示同意」：首启未同意时弹出自检同意弹窗（含「不同意」退出，满足审核红线）。
    // 不再叠加 checkPrivacyUpdate 的版本更新二次弹窗，避免多个隐私弹窗。
    if (!isPrivacyAgreed()) {
      this.showPrivacyDialog();
      return;
    }
    this.startInit();
    // 冷启动剪贴板分享链接检查（首启同意隐私后走 agreePrivacy 的同名钩子）
    this.checkClipboardPostLinkAfterStart();
  }

  private maybeShowCircleOnboarding(): void {
    const currentUserId: string = String(getUserId());
    if (!getToken() || currentUserId === '0' || this.circleOnboardingPendingUserId !== currentUserId ||
      this.showCircleOnboarding || this.onboardingLoading) {
      return;
    }
    this.showCircleOnboarding = true;
    this.loadOnboardingTags();
  }

  private async loadOnboardingTags(): Promise<void> {
    this.onboardingLoading = true;
    try {
      this.onboardingTags = await listTags();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '圈子加载失败，请稍后重试' });
    } finally {
      this.onboardingLoading = false;
    }
  }

  private toggleOnboardingTag(name: string): void {
    if (name.length === 0 || this.onboardingSubmitting) {
      return;
    }
    if (this.onboardingSelectedNames.indexOf(name) >= 0) {
      this.onboardingSelectedNames = this.onboardingSelectedNames.filter((item: string) => item !== name);
    } else {
      this.onboardingSelectedNames = [...this.onboardingSelectedNames, name];
    }
  }

  private finishCircleOnboarding(): void {
    this.showCircleOnboarding = false;
    this.onboardingSelectedNames = [];
    AppStorage.setOrCreate('circleOnboardingPendingUserId', '');
    const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
    AppStorage.setOrCreate('circleMembershipVersion', version + 1);
  }

  private async confirmCircleOnboarding(): Promise<void> {
    if (this.onboardingSubmitting) {
      return;
    }
    if (this.onboardingSelectedNames.length === 0) {
      this.finishCircleOnboarding();
      return;
    }
    this.onboardingSubmitting = true;
    try {
      await Promise.all(this.onboardingSelectedNames.map((name: string) => followTag(name)));
      this.finishCircleOnboarding();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '加入圈子失败，请重试' });
    } finally {
      this.onboardingSubmitting = false;
    }
  }

  // 冷启动时校验持久化 JWT 是否仍有效。
  // 过期一律走正常 401 流程（api 写 authExpiredAt → onAuthExpired 统一清态并引导重登），
  // **不自动重登**：原先这里有一个 debug 专用的 loginWithDevStub 静默重登分支，
  // 提审前已移除——发布包不应包含「自动用测试账号重建会话」的路径。
  private async validateStartupSession(): Promise<void> {
    if (getToken() === '') {
      return;
    }
    try {
      await getMe();
    } catch (_) {
      // 校验失败不阻断启动：页面各自的网络重试机制稍后会再次拉取；
      // 若确为登录过期，401 处理器会把用户引到登录页。
    }
  }

  // 登录态稳定后异步核对服务端隐私同意版本；过期则重新弹窗（版本更新场景）。
  // 网络失败/未配置时不阻断使用，以本地 privacyAgreed 标记为准。
  private checkPrivacyUpdate(): void {
    if (this.privacyDialogShown) {
      return;
    }
    getMe().then((me) => {
      if (me.privacyRequired) {
        this.privacyDialogShown = true;
        this.showPrivacyDialog(true);
      }
    }).catch((e: Error) => {
      // 失败不阻断（离线/后端未起），但保留最小日志便于排查
      hilog.warn(0x0000, 'Index', 'getMe 失败（不阻断首启）: %{public}s', String(e.message));
    });
  }

  private showPrivacyDialog(isUpdate: boolean = false): void {
    this.privacyDialogIsUpdate = isUpdate;
    this.privacyConsentController.open();
  }

  private agreePrivacy(): void {
    setPrivacyAgreed(); // 本地兜底（离线也能拦截首启）
    // 已登录则落地服务端（PIPL 可追溯）；失败不阻断（离线/后端未起）
    if (getToken() !== '') {
      recordPrivacyConsent(PRIVACY_POLICY_VERSION).catch((e: Error) => {
        // 失败不阻断（离线/后端未起），本地已置位；保留日志用于追溯
        hilog.warn(0x0000, 'Index', '隐私同意落地失败（不阻断）: %{public}s', String(e.message));
      });
    }
    this.privacyDialogShown = false;
    this.startInit();
    // 首启刚同意隐私：此刻起才允许读剪贴板，补一次检查（此前红线是「告知—同意前处理」）
    this.checkClipboardPostLinkAfterStart();
  }

  private declinePrivacy(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.terminateSelf();
  }

  private refreshUnread(): void {
    getUnreadCount()
      .then((res) => { this.unreadCount = res.count; })
      .catch(() => {});
    getDmUnreadCount()
      .then((res) => { this.dmUnread = res.count; })
      .catch(() => {});
  }

  private selectTab(index: number): void {
    if (this.currentIndex === index) {
      return;
    }
    // 离开首页时收起圈子下拉面板：标题栏会隐藏，但面板挂在 HomeTab 内容层，需显式关闭
    this.showCircleDropdown = false;
    this.currentIndex = index;
    AppStorage.setOrCreate<number>('activeTab', index);
    this.dockPillTravel(index);
  }

  // 未登录闸门：原先在页签点击拦截里（点发布先判登录），发布成为实体页之后挪到这里 ——
  // 停在发布页不要求登录，选定方式、真要进编辑器时才拦。取消登录返回时露出的就是发布页
  // （用户就站在这页上，可以再选一次或滑走），不会被莫名弹到别的页。
  private openPublish(mode: PublishMode): void {
    if (getToken() === '') {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    publishFlowStore.startNew(mode);
    const url: string = mode === 'video' ? 'pages/VideoPublishPage'
      : (mode === 'text' ? 'pages/TextPublishPage' : 'pages/PhotoPublishPage');
    this.getUIContext().getRouter().pushUrl({ url: url });
  }

  private broadcastCircleLogoDismissal(): void {
    const version: number = AppStorage.get<number>('circleLogoDismissVersion') ?? 0;
    AppStorage.setOrCreate<number>('circleLogoDismissVersion', version + 1);
  }

  // 导航目的地注册：pushPathByName(name, params) 对应的 NavDestination
  @Builder
  pageMap(name: string, _param: Object) {
    if (name === 'PostDetail') {
      PostDetailDestination()
    } else if (name === 'UserProfile') {
      UserProfileDestination()
    } else if (name === 'CircleDetail') {
      CircleDetailDestination()
    } else if (name === 'ChatPage') {
      ChatDestination()
    } else if (name === 'MyFollow') {
      MyFollowDestination()
    } else if (name === 'Login') {
      LoginDestination()
    } else if (name === 'VideoPlayer') {
      // 独立视频播放器页：帖子等入口点击视频后进入（详情页不再内嵌播放器浮层）
      VideoPlayerDestination()
    } else if (name === 'SearchPanel') {
      // 搜索面板：首页搜索按钮一镜到底的落点（自定义转场，整页从按钮帧缩放展开）
      SearchPanelDestination()
    }
  }

  // —— Dock 液态选中指示器：几何全部来自实测，动画来自 UIContext.animateTo ——

  // 记录某个页签槽位的窗口矩形（vp）。五颗各回调一次，去重后统一补一次定位。
  private recordDockSlotArea(index: number, area: Area): void {
    this.dockSlotAreas[index] = {
      x: Number(area.globalPosition.x),
      y: Number(area.globalPosition.y),
      w: Number(area.width),
      h: Number(area.height),
    };
    this.scheduleDockPillRemeasure();
  }

  // 量出 index 号槽位上胶囊的一帧几何。任一环缺数据返回 null —— 宁可这一帧不画，
  // 也不画一个坐标错误的胶囊（错位的色块比缺失的色块更像 bug）。
  private dockPillFrameOf(index: number): DockPillFrame | null {
    const count: number = this.bottomTabItems().length;
    const layer: DockArea | null = this.dockLayerArea;
    const first: DockArea | undefined = this.dockSlotAreas[0];
    const last: DockArea | undefined = this.dockSlotAreas[count - 1];
    const slot: DockArea | undefined = this.dockSlotAreas[index];
    if (layer === null || layer.w <= 0 || first === undefined || last === undefined
      || slot === undefined || slot.w <= 0) {
      return null;
    }
    // 一律换算到覆盖层自己的坐标系：两者都是窗口坐标，差值即为 .position() 要的相对值。
    const firstCx: number = first.x - layer.x + first.w / 2;
    const lastCx: number = last.x - layer.x + last.w / 2;
    const cx: number = slot.x - layer.x + slot.w / 2;
    // ⚠️ Y 不取槽位上报值：其 globalPosition 相对真实位置带一档 barBottomMargin 偏差，
    // 旧版「上报值 − 28」的修正在 HdsMiniBarButton 玻璃珠上真机实测仍偏下（用户反馈
    // 2026-10-26）。改锚 Dock 栏体几何中心——barBottomMargin 与栏高（DOCK_BAR_HEIGHT_VP）
    // 都是本页传给系统的已知量，零上报依赖（原型页 DockPillDragProtoPage 同款已验证）。
    // X 不受该偏差影响，仍用各槽实测中心。
    const cy: number = layer.h - (DOCK_BOTTOM_MARGIN_BASE + bottomNavInset()) - DOCK_BAR_HEIGHT_VP / 2;
    // 槽距由两端中心反算（不写死）：换 barWidth 档、换导航方式、转屏都会变。
    const pitch: number = count > 1 ? (lastCx - firstCx) / (count - 1) : first.w;
    this.dockPillPitch = pitch;
    const frame: DockPillFrame = {
      cx: cx,
      cy: cy,
      w: pitch * DOCK_PILL_W_RATIO,
      h: slot.h * DOCK_PILL_H_RATIO,
    };
    return frame;
  }

  // 把指示器即时贴到 index 号槽位（无动画）。
  private dockPillSnap(index: number): boolean {
    const frame: DockPillFrame | null = this.dockPillFrameOf(index);
    if (frame === null) {
      return false;
    }
    this.dockPillX = frame.cx;
    this.dockPillY = frame.cy;
    this.dockPillW = frame.w;
    this.dockPillH = frame.h;
    this.dockPillCovered = index;
    this.dockPillReady = true;
    return true;
  }

  // 切页：先鼓包 + 位移（行进），到点再 spring 收回静止尺寸 —— 原文那套「液态」观感的
  // tap 分支。（原文的速度形变只服务于它的拖拽手势，本应用不接拖拽，故不搬。）
  private dockPillTravel(index: number): void {
    if (!this.hdsFloatingBar) {
      return;
    }
    const frame: DockPillFrame | null = this.dockPillFrameOf(index);
    if (frame === null) {
      return;
    }
    if (!this.dockPillReady) {
      this.dockPillSnap(index);
      return;
    }
    // 同一次切换会被 onTabBarClick 与 onAnimationStart 各触发一次；已经到位且无拖拽
    // 残留就不要再发一遍动画（否则胶囊会在终点上重新鼓一次包）。
    if (this.dockPillCovered === index && Math.abs(this.dockPillDragOffsetX) < 0.5
      && Math.abs(this.dockPillX - frame.cx) < 0.5) {
      return;
    }
    // 「落定才接管」（用户拍板 2026-10-26：图标不跟玻璃跑）：行进期间玻璃珠是纯光标，
    // 官方份全部显示、图标留在槽位里（玻璃扫过谁、谁的图标在磨砂下短暂糊化）；settle
    // 到点才由玻璃接管目标槽——真磨砂下选中槽不接管则图标不可读，落定接管是唯一兼顾。
    this.dockPillCovered = -1;
    this.getUIContext().animateTo({ duration: DOCK_PILL_TRAVEL_MS, curve: MotionCurves.springSoft }, () => {
      this.dockPillX = frame.cx;
      this.dockPillY = frame.cy;
      this.dockPillW = frame.w + DOCK_PILL_BULGE;
      this.dockPillH = frame.h + DOCK_PILL_BULGE;
      this.dockPillDragOffsetX = 0;
    });
    if (this.dockPillSettleTimer >= 0) {
      clearTimeout(this.dockPillSettleTimer);
    }
    const restW: number = frame.w;
    const restH: number = frame.h;
    this.dockPillSettleTimer = setTimeout((): void => {
      this.dockPillSettleTimer = -1;
      this.getUIContext().animateTo({ duration: DOCK_PILL_SETTLE_MS, curve: MotionCurves.springBounce }, () => {
        this.dockPillW = restW;
        this.dockPillH = restH;
      });
      // 落定即接管：目标槽官方份隐掉、玻璃内清晰副本顶上（与官方份逐像素重合，无跳变）。
      this.dockPillCovered = index;
    }, DOCK_PILL_TRAVEL_MS);
  }

  // —— 玻璃珠拖拽三阶段（原型页 DockPillDragProtoPage 真机验证版移植）——
  // 手势只挂在玻璃珠本体（覆盖层 hitTest None + 珠体 Transparent），与整页左右滑
  // 分区共存：内容区滑动归 HdsTabs，Dock 上的横向拖拽归玻璃珠。
  // 拖拽中玻璃珠是纯光标（官方份全显、图标原位），松手过半格吸附、边缘阻尼。

  private handleDockPillDragStart(): void {
    // 打断在途 settle：手指接管，一切以手势为准。
    if (this.dockPillSettleTimer >= 0) {
      clearTimeout(this.dockPillSettleTimer);
      this.dockPillSettleTimer = -1;
    }
    this.dockPillLastGestureX = 0;
    this.dockPillLastGestureTs = 0;
    this.dockPillSmoothedVp = 0;
    this.dockPillInitialDirection = 0;
    this.dockPillLastActiveTs = 0;
    this.dockPillPauseDetected = false;
    // 拖拽即纯光标：官方份全部露出，图标留在槽位里。
    this.dockPillCovered = -1;
    // 起手鼓包：从静止尺寸"被拿起"（springBounce 一记明显轻弹）。
    const frame: DockPillFrame | null = this.dockPillFrameOf(this.currentIndex);
    if (frame === null) {
      return;
    }
    this.getUIContext().animateTo({
      duration: MotionTokens.fast,
      curve: MotionCurves.springBounce,
    }, () => {
      this.dockPillW = frame.w + DOCK_PILL_BULGE;
      this.dockPillH = frame.h + DOCK_PILL_BULGE;
    });
  }

  private handleDockPillDragUpdate(event: GestureEvent): void {
    if (!this.dockPillReady || this.dockPillPitch <= 0) {
      return;
    }
    const x: number = event.offsetX;
    const now: number = Date.now();
    // 速度按 vp/s 归一（不依赖手势回调帧率），指数平滑滤抖。
    if (this.dockPillLastGestureTs > 0) {
      const dt: number = Math.max(now - this.dockPillLastGestureTs, 1);
      const instVp: number = (x - this.dockPillLastGestureX) / dt * 1000;
      this.dockPillSmoothedVp = this.dockPillSmoothedVp * (1 - DOCK_PILL_SPEED_SMOOTH)
        + instVp * DOCK_PILL_SPEED_SMOOTH;
    }
    this.dockPillLastGestureX = x;
    this.dockPillLastGestureTs = now;
    // 停顿检测：短促停顿后视为新一轮甩动，重置形变方向。
    if (Math.abs(this.dockPillSmoothedVp) >= DOCK_PILL_PAUSE_SPEED_VP) {
      this.dockPillLastActiveTs = now;
    }
    if (this.dockPillLastActiveTs > 0 && Math.abs(this.dockPillSmoothedVp) < DOCK_PILL_PAUSE_SPEED_VP
      && now - this.dockPillLastActiveTs >= DOCK_PILL_PAUSE_MS) {
      this.dockPillPauseDetected = true;
      this.dockPillInitialDirection = 0;
      this.dockPillLastActiveTs = 0;
    }
    // 速度 → 形变：sqrt 缓动，同向拉宽缩高、反向收宽涨高。
    const absV: number = Math.abs(this.dockPillSmoothedVp);
    let deformW: number = 0;
    let deformH: number = 0;
    if (absV >= DOCK_PILL_SPEED_MIN_VP) {
      if (this.dockPillInitialDirection === 0 || this.dockPillPauseDetected) {
        this.dockPillInitialDirection = this.dockPillSmoothedVp > 0 ? 1 : -1;
        this.dockPillPauseDetected = false;
      }
      const eased: number = Math.sqrt(Math.min(absV / DOCK_PILL_SPEED_NORMALIZE_VP, 1));
      const deform: number = eased * DOCK_PILL_SPEED_MAX_DEFORM;
      const sameDir: boolean = (this.dockPillSmoothedVp > 0 ? 1 : -1) === this.dockPillInitialDirection;
      if (sameDir) {
        deformW = deform;
        deformH = -deform * DOCK_PILL_DEFORM_CROSS;
      } else {
        deformW = -deform * DOCK_PILL_DEFORM_CROSS;
        deformH = deform;
      }
    }
    const frame: DockPillFrame | null = this.dockPillFrameOf(this.currentIndex);
    if (frame === null) {
      return;
    }
    this.dockPillW = frame.w + DOCK_PILL_BULGE + deformW;
    this.dockPillH = frame.h + DOCK_PILL_BULGE + deformH;
    // 边缘阻尼：首槽往左/尾槽往右拖时跟手衰减（rubber-band 手感）。
    const lastIndex: number = this.bottomTabItems().length - 1;
    if ((this.currentIndex === 0 && x < 0) || (this.currentIndex === lastIndex && x > 0)) {
      this.dockPillDragOffsetX = x * DOCK_PILL_EDGE_DAMPING;
    } else {
      this.dockPillDragOffsetX = x;
    }
  }

  private handleDockPillDragEnd(): void {
    // 按实测槽距取整：过半格吸附。
    const slots: number = this.dockPillPitch > 0 ? Math.round(this.dockPillDragOffsetX / this.dockPillPitch) : 0;
    const lastIndex: number = this.bottomTabItems().length - 1;
    const target: number = Math.max(0, Math.min(lastIndex, this.currentIndex + slots));
    if (target === this.currentIndex) {
      // 未过半格：回弹到当前槽（travel 的去重条件含拖拽偏移判断，会正常执行回弹）。
      this.dockPillTravel(target);
      return;
    }
    // 过半格吸附：走 selectTab 统一链路（页面切换 + 玻璃珠飞行 + 落定接管）。
    this.selectTab(target);
  }

  // 覆盖层尺寸一变（转屏 / 折叠 / 分栏拖宽 / 导航区高度回写）就重新贴一次实测槽位。
  // 延一帧再量：onAreaChange 本身在布局阶段回调，此刻读到的还是旧几何。
  private scheduleDockPillRemeasure(): void {
    if (!this.hdsFloatingBar || this.dockPillMeasurePending) {
      return;
    }
    this.dockPillMeasurePending = true;
    setTimeout((): void => {
      this.dockPillMeasurePending = false;
      if (this.dockPillSnap(this.currentIndex)) {
        this.dockPillMeasureRetries = 0;
        return;
      }
      // 拿不到槽位就有限次重试；始终量不到就一直不画 —— 宁可没有指示器，
      // 也不画一个坐标错误的胶囊（错位的色块比缺失的色块更像 bug）。
      if (this.dockPillMeasureRetries < DOCK_PILL_MEASURE_RETRIES) {
        this.dockPillMeasureRetries += 1;
        this.scheduleDockPillRemeasure();
      }
    }, 32);
  }

  // Dock 之上的覆盖式指示器。整层 hitTestBehavior=None：不吃任何点击，
  // 页签命中仍归官方 TabBar（本应用刻意不让指示器带手势，见常量注释②）。
  @Builder
  dockSelectionPill() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.dockPillReady) {
        // 液态玻璃珠 = HdsMiniBarButton（hds_button 源码本地集成，见 components/）：
        // 内部「Row 包 HdsTabs」借悬浮态官方材质通道，在覆盖层出真沉浸光感玻璃——
        // 自绘 tint/rim/backdropBlur 全部退役（自绘复刻不出玻璃折射，用户多轮反馈
        // 「没有液态玻璃感」的根因）。材质参数传数值字面量（IMMERSIVE=101/EXQUISITE=0，
        // 组件本地化已斩断 hdsMaterial 依赖，见 components/HdsMiniBarButton.ets 头注释）。
        // ⚠️ @ComponentV2 自定义组件不能直接挂通用属性，包一层 Stack 承载定位/按压/命中。
        Stack() {
          HdsMiniBarButton({
            maskColor: '#00ffffff',
            barWidth: this.dockPillW,
            barHeight: this.dockPillH,
            materialType: DOCK_MATERIAL_TYPE,
            materialLevel: DOCK_MATERIAL_LEVEL,
          }) {
            Column() {
              // 真玻璃会把压在下面的官方图标糊掉（磨砂对内容不可逆），清晰的那份
              // 必须由玻璃自己带；配合 tabBarBuilder 里对被盖槽的 opacity 0，玻璃下面
              // 只剩 Dock 表面，不会再透出同色光晕。
              // ⚠️ 不能直接 this.tabItemContent(this.dockPillCovered)：@Builder 的参数是**值快照**，
              // 落位后 index 变了那份副本不会刷新（真机实证：胶囊飞到「消息」里画的还是「首页」）。
              // 用 key 随 dockPillCovered 变化的单元素 ForEach 强制重建这一项 —— key 生成器必须
              // 含会变的字段，否则等于没 key。
              if (this.dockPillCovered >= 0) {
                ForEach([this.dockPillCovered], (i: number) => {
                  this.tabItemContent(i)
                }, (i: number): string => String(i))
              }
            }
            .width('100%')
            .height('100%')
            // 副本必须与官方那份**逐像素重合**，否则落位瞬间图标会跳一下：官方那份是被
            // Stack(alignContent: Center) 居中的，这里 Column 主轴默认从顶排，必须显式居中
            // （真机实测漏写时副本比官方高 9px = 2.9vp）。
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .clip(false)
        // ⚠️ HdsMiniBarButton 容器自带 contentPadding=8（防光效裁切），Row 比玻璃条大
        // 16vp——position 以 Stack 左上角为锚，需反向补偿 padding 让玻璃条中心对准锚点，
        // 副本与官方份的逐像素重合才成立。
        .position({
          x: this.dockPillX - this.dockPillW / 2 - DOCK_PILL_MINI_PAD,
          y: this.dockPillY - this.dockPillH / 2 - DOCK_PILL_MINI_PAD,
        })
        // 按压反馈：玻璃被按下去一档（pressSlideScale=0.94，华为应用商店同款按压缩放）；
        // 材质自带落影，自绘 shadow 不再叠加。
        .scale({
          x: this.dockPillPressed ? MotionTokens.pressSlideScale : 1,
          y: this.dockPillPressed ? MotionTokens.pressSlideScale : 1,
        })
        .animation({ duration: MotionTokens.fast, curve: MotionCurves.springInteract })
        // ⚠️ 必须是 Transparent 而不是 None：None 时玻璃收不到手指，按住底栏整颗胶囊毫无反应
        // （用户实测反馈）。Transparent 让玻璃自己收到按压，同时把命中继续透给下层官方页签
        // —— 这正是原文覆盖层用 HitTestMode.Transparent 的原因。改命中模式后必须真点一次
        // 切页，确认没吃掉官方页签的点击（防漂移第 31/39 条同源，已真机复点五格）。
        .onTouch((event: TouchEvent): void => {
          const type: TouchType = event.type;
          this.dockPillPressed = type === TouchType.Down || type === TouchType.Move;
        })
        // 拖拽跟手与 travel 归零插值都走这一个 translate。
        .translate({ x: this.dockPillDragOffsetX })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, fingers: 1, distance: 5 })
            .onActionStart((): void => {
              this.handleDockPillDragStart();
            })
            .onActionUpdate((event: GestureEvent): void => {
              this.handleDockPillDragUpdate(event);
            })
            .onActionEnd((): void => {
              this.handleDockPillDragEnd();
            })
        )
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_o: Area, n: Area): void => {
      this.dockLayerArea = {
        x: Number(n.globalPosition.x),
        y: Number(n.globalPosition.y),
        w: Number(n.width),
        h: Number(n.height),
      };
      this.scheduleDockPillRemeasure();
    })
  }

  // 页签内容（图标 + 可选未读红点 + 文字）。**被两处复用**：官方 TabBar 的每一颗，
  // 以及 Dock 玻璃胶囊内部。必须共用同一个 builder —— 胶囊里的副本要和官方那份逐像素重合，
  // 抄两份必然漂移（字号/间距/红点样式任何一处不一致，切到那一页就会看出重影）。
  @Builder
  tabItemContent(index: number) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (index === 3 && (this.unreadCount + this.dmUnread) > 0) {
          Badge({
            count: this.unreadCount + this.dmUnread,
            position: BadgePosition.RightTop,
            style: { badgeColor: $r('app.color.semantic_red'), color: ColorTokens.onDanger, badgeSize: 14 },
          })           {
            Image(this.bottomTabItems()[index].icon)
              .width(24).height(24)
              .objectFit(ImageFit.Contain)
              .fillColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
          }
        } else {
          Image(this.bottomTabItems()[index].icon)
            .width(24).height(24)
            .objectFit(ImageFit.Contain)
            .fillColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
        }
      }
      .width(28).height(28)
      Text(this.bottomTabItems()[index].title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('app.color.ds_brand') : $r('app.color.ds_icon'))
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 官方 HdsTabs 页签：图标 + 文字，选中态品牌色；消息 tab（index=3）叠加未读红点。
  // 每颗用 onAreaChange 回抛自己的窗口矩形，供指示器实测槽位——槽位宽/间距由系统
  // 按 barWidth 档位自己排，写死坐标会在换档或换导航方式时错位。
  // 被玻璃胶囊盖住的那一颗整份隐掉（opacity 0）：胶囊是真磨砂，留着它只会在玻璃下面
  // 糊出一团同色光晕，而清晰的那份由胶囊自己带（见 tabItemContent）。
  @Builder
  tabBarBuilder(index: number) {
    Stack({ alignContent: Alignment.Center }) {
      this.tabItemContent(index)
    }
    .width(64).height(54)
    .opacity(this.dockPillCovered === index ? 0 : 1)
    .onAreaChange((_o: Area, n: Area): void => { this.recordDockSlotArea(index, n); })
  }

  // —— 首页/圈子/消息 三个 Tab 顶栏均已迁入各自 Tab 内嵌 HdsNavigation（路线 B）——
  // —— 四个主 Tab 顶栏均已迁入各自内嵌 HdsNavigation（路线 B）——
  // 外层 Navigation 不再承载任何页的标题栏；发布占位 Tab 与隐私壳无顶栏。

  // 「我的」子分段行右侧「管理收藏夹」钮的材质修饰器（这颗不在 content.menu 里，
  // 它跟着子分段栏走，仍是自排 Pressable，所以保留同源官方材质）。
  // 带投影那一档：真机对照原生电话顶栏圆钮，表面比背板亮 +6~8 L、下方有 −8 L 钟形落影。
  // 见基准文档 §7.6.5 / §7.6.6。
  private profileActionMaterial: FloatingTopButtonMaterialModifier = new FloatingTopButtonMaterialModifier();

  // 栏级沉浸光感：官方圆钮的 rim + 落影 + 玻璃折射只在这一档打开时才出图
  // （不传 → 默认 3% 黑平面，无轮廓）。
  // 档位传数值字面量而非 hdsMaterial 枚举：hdsMaterial 模块在 API 22 上不存在，值 import 即崩
  // 栏级沉浸材质（EXQUISITE 才有「玻璃珠折射」，ADAPTIVE 只出普通半透——基准 §7.6.17；
  // 用户拍板保留原观感，2026-10-24 回退统一时恢复）。
  private profileSystemMaterial(): SystemMaterialParams | undefined {
    if (!isImmersiveLightSenseSupported()) {
      return undefined;
    }
    return {
      materialType: HDS_MATERIAL_TYPE_IMMERSIVE,
      materialLevel: HDS_MATERIAL_LEVEL_EXQUISITE,
    };
  }

  // —— 「我的」页顶栏（我的/分享/设置 + 资料区 + 主分段栏）：驻留 Navigation 标题栏 ——
  // 数据来自 ProfilePage 的共享态（@Link），跳转/登录引导在此接线；分享流程仍由 ProfilePage 完成。
  private profileLoggedIn(): boolean {
    return (this.profileUser.id ?? 0) > 0;
  }

  // 关注/粉丝数字块：已登录进列表页，未登录就地引导登录（与旧 ProfilePage 行为一致）
  private openProfileFollow(mode: string): void {
    const uid: number = this.profileUser.id ?? 0;
    if (uid === 0) {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    openFollowList({ userId: uid, mode: mode === 'followers' ? 'followers' : 'following' });
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MyFollowPage' });
  }

  // 资料区背景图地址（空串 = 无背景图）：profileBackground 为可选字段，
  // 这里统一收敛类型，供 @Builder 分支与 Image 源共用（@Builder 体内不能声明 const）。
  private profileBackgroundUrl(): string {
    return this.profileUser.profileBackground ?? '';
  }

  // 屏宽（vp）：背景图卡按 16:10 估算高度用。px→vp 走 densityPixels 除法
  // （与 PrivacyConsentDialog.screenWidthVp 同法，不依赖 px2vp 的 UIContext 形态）。
  private screenWidthVp(): number {
    try {
      const d: number = display.getDefaultDisplaySync().densityPixels;
      const w: number = display.getDefaultDisplaySync().width;
      return d > 0 && w > 0 ? w / d : 400;
    } catch (e) {
      return 400;
    }

  }

  // 屏高（vp）：与 screenWidthVp 同法。给「我的」列表的状态页撑底用 —— ListItem 里
  // constraintSize minHeight 写 '100%' 不生效（List 内容高度无界，百分比没有参照），
  // 必须给具体 vp 值，见基准 §7.6.25。取不到按 600 兜底。
  private screenHeightVp(): number {
    try {
      const d: number = display.getDefaultDisplaySync().densityPixels;
      const h: number = display.getDefaultDisplaySync().height;
      return d > 0 && h > 0 ? h / d : 600;
    } catch (e) {
      return 600;
    }
  }

  // 「我收藏」子分段栏（帖子 | 收藏夹）为栏体多让出来的那一条：顶部间隙 + 栏体本体。
  // 只有该分段有二级视图，所以栏体高随主分段变化——它也是唯一需要联动资料卡让位量的一条。
  private profileHasSubSeg(): boolean {
    return this.profileTabIdx === 1;
  }


  // 交给 List 的 contentStartOffset：内容起始端让开整条 56vp 标题栏，吸顶分段栏也就钉在那儿。
  // ⚠️ 必须含 statusBarHeight。`enableComponentSafeArea:false` 下 List 的**布局原点仍在窗口 0**，
  // 节点报 [0,106] 是裁剪后的可视框（防漂移第 12 条）。真机实测：只给 56vp 时资料卡项落在
  // y=175px，正压在标题栏（106..281）底下、头像被「我的」那行切掉一半；补上 34vp 才落到 281。
  private profileListInset(): number {
    return this.statusBarHeight + PROFILE_TITLE_ROW_VP;
  }

  // 资料区本体（ProfileHeader 只呈现，跳转/登录引导等意图在这里接线）
  @Builder
  profileHeaderBlock(onBackground: boolean) {
    ProfileHeader({
      avatar: this.profileUser.avatar ?? '',
      name: this.profileLoggedIn() ? (this.profileUser.nickname ?? '有据用户') : '未登录',
      gender: this.profileUser.gender ?? 0,
      bio: this.profileLoggedIn() ? (this.profileUser.bio ?? '') : '登录后查看与发布你的内容',
      userId: this.profileUser.id ?? 0,
      isLoggedIn: this.profileLoggedIn(),
      followingCount: this.profileFollowingCount,
      followerCount: this.profileFollowerCount,
      totalLikes: this.profileTotalLikes,
      onBackground: onBackground,
      onOpenFollowing: (): void => { this.openProfileFollow('following'); },
      onOpenFollowers: (): void => { this.openProfileFollow('followers'); },
      onEdit: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/EditProfilePage' }); },
      onOpenDrafts: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/DraftBoxPage' }); },
      onOpenTrash: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/TrashBoxPage' }); },
      onLogin: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' }); },
    })
  }

  // 资料卡：交给 ProfilePage 整页那条 List 的第 0 项（@BuilderParam heroHeader）。
  // 不再住在标题栏 bottomBuilder 里 —— 栏体节点之内抓不到滚动源，资料卡留在栏里等于把屏顶
  // 41% 变成手势盲区，且它不随列表滚走（基准 §7.6.13b）。入场动效留在这一层，观感不变。
  @Builder
  profileHeroBlock() {
    Column() {
      if (this.profileBackgroundUrl() !== '') {
        Column() {
          Stack() {
            Image(resolveDisplayImageUrl(this.profileBackgroundUrl()))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover);
            Column() {
              this.profileHeaderBlock(true);
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.End)
            .backgroundColor('#52000000');
          }
          .width('100%')
          .aspectRatio(16 / 10)
          .borderRadius(RadiusTokens.lg)
          .clip(true);
        }
        .width('100%')
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs });
      } else {
        Column() {
          this.profileHeaderBlock(false);
        }
        .width('100%');
      }
    }
    .width('100%')
    .opacity(this.profilePresented ? 1 : 0)
    .translate({ y: this.profilePresented ? 0 : SpaceTokens.xl })
    .scale({
      x: this.profilePresented ? 1 : MotionTokens.enterScale,
      y: this.profilePresented ? 1 : MotionTokens.enterScale,
    })
    .animation({
      duration: MotionTokens.page,
      curve: MotionCurves.emphasized,
    })
  }

  // 主分段 + （子分段）两行控件：交给 ProfilePage 那条 List 的吸顶组头（ListItemGroup.header），
  // 于是资料卡排在它上面、上滑时先滚走、这一行粘在 56vp 标题栏之下。
  // 标题行不在这儿——「我的」三个字走 content.stackBuilder，分享/设置走官方 content.menu。
  @Builder
  profileSegRows() {
    Column({ space: SpaceTokens.none }) {
      // 主分段栏：我发布 / 我收藏 / 我赞过 / 我评论（官方 SegmentButton tab 档 + 沉浸光感系统材质）
      // 撑满父容器（itemWidth 取默认 0），不再定宽 67×4=268vp 的短栏：
      // 参考实测智慧生活顶栏轨道 331.5vp / 屏宽 363.52 → 左右各 16vp，这里用 base 内缩正好复现该宽。
      // 主分段栏：我发布 / 我收藏 / 我赞过 / 我评论（自绘 SegmentedControl，回迁 1.0.1 样式）
      // 参数照抄 1.0.1（c50f8318）：材质生效时描边底透出系统材质；本栏现住列表流（非标题栏
      // 生效区），材质不渲染 → 呈现即 1.0.1 的「透明轨道 + #99EFEFF2 滑块」观感。
      SegmentedControl({
        items: PROFILE_SEGMENTS,
        selectedIndex: $profileTabIdx,
        itemWidth: 67,
        immersive: !isSystemMaterialActive(),
        outlined: isSystemMaterialActive(),
        glowEnabled: false,
        // 不挂系统材质（列表区本就不渲染；全线纯自绘，保住底部软阴影）
        useSystemMaterial: false,
        onSelect: (idx: number): void => {
          // 只写选中值：滑块弹性动画由 SharedSlide 承担，列表刷新由 @Watch(tabIdx) 承接
          this.profileTabIdx = idx;
        },
      })
        .margin({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.xs })

      // 「我收藏」子分段栏（帖子 | 收藏夹）：与主分段栏同一条磨砂区内，材质配置照抄上面那份。
      // 原先它是内容区浮层——uiMaterial 在内容区完全不渲染，只能自绘玻璃，
      // 与栏体材质两套模糊半径/着色叠在一起，接缝就落在两条栏之间那一条 xs 上。
      // 整行铺满（官方组件把可用宽度等分给两条目），管理入口靠右，二者靠一层 layoutWeight 容器分格。
      // 出现/消失走 transition：栏高随 tabIdx 跳变那一帧由淡入遮住。
      if (this.profileHasSubSeg()) {
        Row({ space: SpaceTokens.xs }) {
          // fillWidth 保持整行铺满（两条目各占一半），但外层套一个 layoutWeight(1) 容器：
          // 控件根节点是 width('100%')，直接和右侧图标同排会按**父 Row** 全宽解析、把分段栏挤偏
          // （它当年被移出顶栏就是这个原因）；包一层加权容器后 100% 落在扣掉图标的那一格上。
          Column() {
            // 子分段栏（帖子 | 收藏夹）：与主分段栏**同款配置**（outlined 透明轨道 + 标题栏外
            // 由描边承载、低版本回退沉浸玻璃）——1.0.1 原参数是 immersive 玻璃底，
            // 与主栏两套观感；统一后两条栏一致（用户拍板 2026-10-24）。
            SegmentedControl({
              items: BOOKMARK_SEGMENTS,
              selectedIndex: $profileBookmarkSubTab,
              itemWidth: 46,
              immersive: !isSystemMaterialActive(),
              outlined: isSystemMaterialActive(),
              glowEnabled: false,
              useSystemMaterial: false,
            })
          }
          .layoutWeight(1)
          .height(LayoutTokens.segmentBarHeight)
          .justifyContent(FlexAlign.Center)
          // 收藏夹管理入口（重命名/删除）：从收藏夹列表头部提到这里，滚动时不再被卷走。
          // 只在「收藏夹」子页且确有收藏夹时出现——空列表没有可管理的东西。
          // 外面这层 Row 只为承载 transition：Pressable 是自定义组件，挂不上通用属性，
          // 而 if 分支删插时动画只认被增删的那个节点。
          if (this.profileBookmarkSubTab === 1 && this.profileFolderCount > 0) {
            Row() {
              Pressable({
                visualHeight: LayoutTokens.iconButton,
                touchTargetHeight: LayoutTokens.minTouchTarget,
                action: (): void => {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/BookmarkFolderPage' });
                },
              }) {
                Row() {
                  Image(resolveSettingsIcon('edit'))
                    .width(IconTokens.standard)
                    .height(IconTokens.standard)
                    .fillColor(ColorTokens.icon)
                }
                .width(LayoutTokens.iconButton)
                .height(LayoutTokens.iconButton)
                .justifyContent(FlexAlign.Center)
                // 与顶栏分享/设置同源材质（低版本自动跳过；无底色/描边，仅材质）
                .borderRadius(RadiusTokens.lg)
                .attributeModifier(this.profileActionMaterial)
                .accessibilityText('管理收藏夹')
              }
            }
            .transition(TransitionEffect.OPACITY.animation({
              duration: MotionTokens.container,
              curve: MotionCurves.emphasized,
            }))
          }
        }
        .width('100%')
        // 左右内缩与主分段栏同值（base 16vp），两条栏左边缘必须对齐
        .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.xs })
        .transition(TransitionEffect.OPACITY.animation({
          duration: MotionTokens.container,
          curve: MotionCurves.emphasized,
        }))
      }
    }
    .width('100%')
    // 这一行**不带任何表面**。它跟着资料区一起滚走，绝大多数时间直接站在页面画布上 ——
    // 官方 SegmentButton 轨道在画布上的表现已经量过并认定与原生同档（基准 §7.6.18 / §7.7），
    // 所以不需要再补一层底。
    //
    // 曾经垫过的三层底全是否定结论，别再走回头路：
    // · 实色 canvas → 一条实心白板压在列表上，没有悬浮感；
    // · backgroundBlurStyle(BACKGROUND_REGULAR/THICK) → 原样透出背板，深色卡片压顶时
    //   未选中标签实测 4.26~4.50:1，掉出 WCAG AA；
    // · backgroundBlurStyle(COMPONENT_THICK/REGULAR) → 达标但偏实，悬浮感仍不对。
    // 根因是吸顶行必须自给表面，而内容区拿不到栏体材质（systemMaterial 挂在内容区普通组件上
    // 完全不渲染，见 immersiveMaterial.ets:182）。不吸顶，这个需求就消失了。见 §7.6.23。
    .padding({ bottom: SpaceTokens.xs })
  }

  // 标题行左侧「我的」：走 content.stackBuilder 而不是 content.title。
  // 官方 content.title 只有系统字体，保不住工程的衬线字族（titleSerif）；实测 stackBuilder
  // 与 content.menu 同栏共存、互不挤占（基准 §7.6.10）。
  @Builder
  profileStackTitle() {
    Row() {
      Text('我的')
        .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .lineHeight(TypeTokens.titleSerif.lineHeight)
        .fontColor(ColorTokens.primary)
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
    .alignItems(VerticalAlign.Center)
  }

  // 右上角官方圆钮排：content.menu 白送 40vp 项宽 / 8vp 间距 / 右缘避让 / 超量折叠成「更多」
  // / badge / 无障碍（基准 §7.6）。自研那颗 40vp 圆从此退役，只留子分段行的「管理收藏夹」。
  private profileMenuItems(): Array<HdsNavigationMenuItemOptions> {
    const settingContent: HdsNavigationIconOptions = {
      icon: resolveSettingsIcon('gear'),
      label: '设置',
      action: (): void => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
      },
    };
    const setting: HdsNavigationMenuItemOptions = { content: settingContent };
    if (!EXTERNAL_SHARE_ENABLED) {
      return [setting];
    }
    const shareContent: HdsNavigationIconOptions = {
      icon: resolveActionIcon('share'),
      label: '分享主页',
      action: (): void => {
        // 递增信号 → ProfilePage @Watch：分享弹层/文案/系统分享仍由 ProfilePage 完成
        this.profileShareSeq += 1;
      },
    };
    const share: HdsNavigationMenuItemOptions = { content: shareContent };
    return [share, setting];
  }

  // 「我的」标题栏配置（嵌套 HdsNavigation，路线 B：与首页/圈子/消息同构）
  // stackBuilder 衬线标题 + content.menu 官方圆 + GRADIENT_BLUR + avoid/!enableComponentSafeArea
  // （后者是穿底的前提，基准 §7.6.9）。栏体只剩这一行 56vp，与官方参照页节点同尺寸（§7.6.13b）。
  // 逐层显式标注 SDK 类型。
  private profileTitleBarOptions(): HdsNavigationTitleBarOptions {
    const menu: HdsNavigationMenuContentOptions = { value: this.profileMenuItems() };
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.profileStackTitle(); },
      menu: menu,
      // 不再挂 bottomBuilder：栏体节点之内抓不到滚动源，装进栏里的东西等于从手势里摘出去。
      // 资料卡与分段栏都回到列表流里（heroHeader / segHeader），栏体只留这一行 56vp。
    };
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      // IMMERSIVE_GRADIENT_BLUR（用户拍板保留原观感）：配 EXQUISITE 栏级材质出沉浸磨砂。
      // 它的模糊只在 originalStyle.blurRadius 出图时可见（见下），开关由**绝对滚动偏移**驱动
      //（停在滚动态恒为开）——旧实现用每帧增量正负驱动，松手弹簧回弹的负增量会把开关打灭
      //（「松手模糊消失」根因，2026-10-24 修复）。滚动源由 bindToScrollable 供给。
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(PROFILE_BLUR_END_VP),
    };
    // originalStyle：blurRadius 是 IMMERSIVE 变体模糊的出图开关，由 profileBarScrolled
    //（绝对偏移 >0，见 onListScroll）门控——静止在顶部不糊、滚过即糊且停住保持。
    // maskExtraHeight 压 0：官方默认 32vp 会把模糊区多伸到栏底之下，磨砂正好停在栏底。
    const backgroundStyle: HdsNavigationBackgroundStyle = {
      backgroundColor: Color.Transparent,
      blurRadius: this.profileBarScrolled ? PROFILE_BLUR_RADIUS : 0,
      maskExtraHeight: 0,
    };
    // content.menu 图标色默认是**白**（HDS 的约定：静止态那条透明栏压在 hero 媒体上）。
    // 本页静止时栏下是页面画布（浅色 L255），白图标直接和白底重合 —— 真机实测圆盘 L252 /
    // 字形 L251，对比度 1.02:1，两颗钮完全看不见；而左侧「我的」是黑的，因为 stackBuilder
    // 那层我们自己写了 fontColor。同一个槽位没人管，就只有菜单图标翻车。
    // 官方出口是 originalStyle.contentStyle.menuStyle.iconColor（menuStyle 只暴露
    // backgroundColor / iconColor / textColor 三个纯色，见 HdsMenuVerifyPage.ets:158）。
    // 用 token 不用常量：深色模式下画布是 #121212，图标要跟着翻白。
    const menuStyle: HdsNavigationIconItemStyle = { iconColor: ColorTokens.primary };
    const contentStyle: HdsTitleBarContentStyle = { menuStyle: menuStyle };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: { backgroundStyle: backgroundStyle, contentStyle: contentStyle },
    };
    const material: SystemMaterialParams | undefined = this.profileSystemMaterial();
    if (material !== undefined) {
      style.systemMaterialEffect = material;
    }
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      // true 会把内容区顶到栏体之下（实测 Scroll 起点 = 栏底）→ 帖子穿不到栏底下。
      // 改 false 让内容区从窗口原点起算，让位由 ProfilePage 的 topInset 承担。
      enableComponentSafeArea: false,
    };
    return options;
  }

  // —— 「消息」页顶栏（消息/全部已读 + 通知|私信分段 + 三类快捷筛选）：已迁入 MessagePage 内嵌 HdsNavigation。
  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.systemReduceMotion;
  }

  // 「消息」顶栏（标题 + 全部已读 + 分段栏）已迁入 MessagePage 内嵌 HdsNavigation（路线 B）。

  // 五个页签内容：首页 / 圈子 / 发布 / 消息 / 我的，五格全部可停靠、可左右滑到达。
  @Builder
  mainTabContents() {
    // TabContent 默认在页面边界裁剪内容：每日一帖的飞行卡向上抛射需溢出到
    // 屏幕顶部（状态栏区域），首页 Tab 关闭裁剪，其余 Tab 内容各自不溢出、不受影响。
    // 首页：顶栏已整体迁入 Navigation 标题栏，这里通过 @Link 共享顶栏状态
    TabContent() {
      HomeTab({
        feedIndex: $feedIndex,
        feedMode: $feedMode,
        tagIndex: $tagIndex,
        displayTags: $displayTags,
        showCircleDropdown: $showCircleDropdown,
      })
    }
      .clip(false)
      .tabBar(this.tabBarBuilder(0))
    // 「圈子」：顶栏（圈子标题 + 已加入药丸）已迁入 CircleTab 内嵌 HdsNavigation（路线 B），
    // TabContent 关闭裁剪：内容超高滚动时需穿出顶边画到 HDS 标题栏下方（模糊采样素材）
    TabContent() {
      CircleTab({
        circleJoinedCount: $circleJoinedCount,
        circleJoinedSeq: $circleJoinedSeq,
      })
    }
      .clip(false)
      .tabBar(this.tabBarBuilder(1))
    // 发布：一整页的发布方式选择（原先是半模态面板）。它可以被滑到、也可以停在上面，
    // 状态栏与悬浮 Dock 的避让由 PublishModePanel 自己做（本页没有内嵌 HdsNavigation）。
    TabContent() {
      PublishModePanel({
        onSelect: (mode: PublishMode): void => { this.openPublish(mode); },
      })
    }
      .tabBar(this.tabBarBuilder(2))
    // 「消息」：顶栏（消息 + 全部已读 + 分段栏）已迁入 MessagePage 内嵌 HdsNavigation（路线 B），
    // TabContent 关闭裁剪：列表滚动需穿出顶边画到 HDS 标题栏下方（模糊采样素材）
    TabContent() {
      MessagePage({
        dmTabIndex: $messageTabIndex,
        tabPulse: $messageTabPulse,
        markAllSeq: $messageMarkAllSeq,
      })
    }
      .clip(false)
      .tabBar(this.tabBarBuilder(3))
    // 「我的」：顶栏迁入本页内嵌 HdsNavigation（路线 B，与首页/圈子/消息同构）。
    // 顶栏状态仍由 Index 持有、@Link 下发给 ProfilePage —— 迁移只搬了渲染位置，没搬数据归属。
    TabContent() {
      HdsNavigation() {
        ProfilePage({
          user: $profileUser,
          followingCount: $profileFollowingCount,
          followerCount: $profileFollowerCount,
          totalLikes: $profileTotalLikes,
          tabIdx: $profileTabIdx,
          // 「我收藏」子分段选中态：控件在本页标题栏，动作（拉收藏夹/刷新收藏）在 ProfilePage 的 @Watch
          bookmarkSubTab: $profileBookmarkSubTab,
          folderCount: $profileFolderCount,
          profilePresented: $profilePresented,
          profileShareSeq: $profileShareSeq,
          // 资料卡下发给列表第 0 项：它跟着列表滚走、穿到栏底之下，不再占住标题栏的手势盲区
          heroHeader: (): void => { this.profileHeroBlock(); },
          // 分段栏两行：资料卡之下、列表之上，随列表滚到顶后吸住
          segHeader: (): void => { this.profileSegRows(); },
          // 单一滚动源下发：标题栏渐变模糊要读它的滚动偏移
          scrollers: this.profileScrollers,
          // 模糊出图开关：offsetY 为**绝对偏移**（ProfilePage 用 currentOffset 喂入），
          // 停在滚动态恒为开、回顶归零即关——只在翻转帧写 @State，逐帧写会逐帧重建标题栏配置。
          onListScroll: (offsetY: number): void => {
            const on: boolean = offsetY > 0;
            if (on !== this.profileBarScrolled) {
              this.profileBarScrolled = on;
            }
            // 滚回顶部：HDS 会在此回写系统栏内容色，去抖补设（utils/systemBar.ets）
            if (offsetY <= 0) {
              requestSystemBarRefresh();
            }
          },
          // 穿底内缩：栏体是覆盖式（enableComponentSafeArea:false）+ 材质透明，内容区从窗口原点起算，
          // 资料卡自己让开「标题行 + 两行分段控件」（这段留白随它一起滚走，帖子才能穿到栏底下）。
          topInset: this.profileListInset(),
          viewportMinHeightVp: this.screenHeightVp(),
        })
      }
      .titleMode(HdsNavigationTitleMode.MINI)
      .titleBar(this.profileTitleBarOptions())
      // 「我的」是 Tab 根页，可这层 HdsNavigation 嵌在外层 Navigation 里，官方仍会画一颗返回钮，
      // 它的材质圆盘正好压在衬线标题底下（实测 Button [50,131][175,256] 与 Text「我的」同区）。
      // 关掉：既去掉幽灵返回，也让 stackBuilder 从 x=50 起排不留空洞。
      .hideBackButton(true)
      // GRADIENT_BLUR 的滚动源。整页只剩一条 List，引用恒定，不再需要切段时换绑。
      .bindToScrollable(this.profileScrollers)
      .width('100%')
      .height('100%')
      // 资料区入场动效（translate/scale）与分段栏材质投影都要溢出各自行边界，链路上不能留 clip(true)
      .clip(false)
    }
      .clip(false)
      .tabBar(this.tabBarBuilder(4))
  }

  // API 23+ 分支：悬浮玻璃底栏（barFloatingStyle/HdsTabsFloatingStyle/hdsMaterial 均 @since 23）。
  // systemMaterialEffect 传数值字面量（IMMERSIVE=101 / ADAPTIVE=10，对照见 immersiveMaterial.ets），
  // 避免静态 import hdsMaterial——该模块在 API 22 上不存在，import 即崩（审核问题①根因）。
  @Builder
  mainTabsFloating() {
    HdsTabs({ controller: this.hdsController }) {
      this.mainTabContents()
    }
    .clip(false)                             // 首页飞行卡向上抛射需溢出页面边界（状态栏区域）
    .barOverlap(true)                        // 悬浮：页签覆盖内容
    .barPosition(BarPosition.End)            // 底部
    .vertical(false)                         // 水平
    .barFloatingStyle({
      // barBottomMargin 在系统导航区之上再留 28vp：三键导航设备 navInset≈28-32vp，
      // 固定 28 会让底栏侵入导航条（审核问题③）；手势导航 navInset=0，维持原设计。
      // —— barWidth 档位（官方规则：440-600vp 用 medium；600-840vp 按 Tabs 宽高比在
      // medium/large 间二选一；>840vp 用 large）——「我的」页标题栏含资料区、内容区显著变矮，
      // 600-840vp 窗口下宽高比会跌破 0.8 → 系统把档位从 large 切回 medium → 切页时底栏忽长忽短
      //（用户实测反馈）。故 600vp 以上窗口把两档取同值 560：跳档不再可见，宽度只随窗口宽度走；
      // 440-600vp 窄窗口保持 420，手机小窗（<440）仍走 small 档 300。
      barWidth: {
        smallWidth: DOCK_WIDTH_SMALL,
        mediumWidth: this.currentBreakpoint === 'sm' ? 420 : 560,
        largeWidth: 560,
      },
      barSideMargin: DOCK_SIDE_MARGIN_MIN,
      barBottomMargin: DOCK_BOTTOM_MARGIN_BASE + bottomNavInset(),
      gradientMask: { maskColor: $r('app.color.bar_gradient_mask'), maskHeight: DOCK_GRADIENT_MASK_HEIGHT },
      systemMaterialEffect: {
        materialType: DOCK_MATERIAL_TYPE,
        materialLevel: DOCK_MATERIAL_LEVEL,
      },
    })
    .scrollable(true)                        // 整页左右滑动切页已开放（发布是实体页，滑动链无断点）
    // 胶囊起飞点：挂在 onAnimationStart 而不是 onChange —— onChange 是**落定之后**才发，
    // 挂那里的话页面已经滑完了玻璃才飞过去，看着像两件事。动画起点触发才与翻页同批。
    // ⚠️ 做不到"贴着手指走"：HdsTabsAttribute 把 Tabs 的 onGestureSwipe / onContentDidScroll
    // 两个逐帧回调都收掉了（枚举其 28 个方法确认），HDS 封装没留这个口。
    .onAnimationStart((index: number, targetIndex: number, _e: TabsAnimationEvent): void => {
      this.dockPillTravel(targetIndex);
    })
    .onTabBarClick((index: number): void => { this.selectTab(index); })
    .onChange((index: number): void => { this.selectTab(index); })
  }

  // API 20-22 / 模拟器分支：HdsTabs.barFloatingStyle @since 23 不可用，但视觉不降级——
  // 内置 Tabs（API 7）承载内容（barHeight(0) 隐藏自带条 + 隐藏分隔线），底部悬浮玻璃药丸
  // 由自绘 BottomTabBar（纯标准 ArkUI API，圆角/模糊/描边/阴影/点光源/弹性高亮全保留）
  // 叠加实现，视觉与 API 23+ 悬浮条同款。三键导航避让由药丸外层 margin 承担。
  @Builder
  mainTabsPlain() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      this.mainTabContents()
    }
    .width('100%')
    .height('100%')
    .clip(false)                             // 首页飞行卡向上抛射需溢出页面边界（状态栏区域）
    .vertical(false)
    .scrollable(true)
    .barHeight(0)
    .divider({ strokeWidth: 0, color: Color.Transparent })
    .onChange((index: number): void => { this.selectTab(index); })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // —— 组件导航根：主框架（Tabs + 悬浮底栏）作为 Navigation 首页 ——
      // 首页卡片→详情走 navDestination（customNavContentTransition + componentSnapshot 一镜到底）
      Navigation(this.pageStack) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            // ⚠️ 隐私红线：未同意隐私政策前不构建主 Tab 内容。
            // 同意后 privacyAgreed 变 '1' → build 重跑 → 正常构建 Tab 并加载。
            if (this.privacyAgreed !== '1') {
              Blank()
            } else if (this.hdsFloatingBar) {
              this.mainTabsFloating()
            } else {
              this.mainTabsPlain()
            }
          }
          .width('100%')
          .height('100%')
          // 外层不给任何 Tab 让状态栏：四个主 Tab 的顶栏在各自内嵌 HdsNavigation 里，
          // 发布页由 PublishModePanel 自己避让。⚠️ 这条 padding 曾经按 currentIndex===2
          // 加在**包着 Tabs 的 Column** 上 —— 发布页可停留之后，它会把整条 Tabs 连 Dock
          // 一起下推/上跳一档（Dock 是 Tabs 的 barPosition(End)），所以必须留在页面内解决。

          // Dock 液态选中指示器：只服务 API 23+ 的官方悬浮条（低版本分支的 BottomTabBar
          // 自带高亮，两套选中语言不并存）。放在 Column 之后 → 天然压在 Dock 之上。
          if (this.hdsFloatingBar && this.privacyAgreed === '1') {
            this.dockSelectionPill()
          }

          // API 20-22 分支：自绘悬浮玻璃药丸底栏（BottomTabBar，纯标准 ArkUI，无 HDS 依赖）。
          // 与 API 23+ 的 HdsTabs 悬浮条同款视觉；三键导航避让由 margin 承担（审核问题③）。
          // 未同意隐私政策时不渲染底栏（此时没有可切换的页面，避免空白壳里出现可点的假壳）。
          if (!this.hdsFloatingBar && this.privacyAgreed === '1') {
            Row() {
              BottomTabBar({
                items: this.bottomTabItems(),
                currentIndex: $currentIndex,
                unreadCount: this.unreadCount + this.dmUnread,
                onSelect: (index: number): void => {
                  this.selectTab(index);
                  this.tabsController.changeIndex(index);
                },
              })
            }
            .width('100%')
            .padding({ left: LayoutTokens.tabBarSideMargin, right: LayoutTokens.tabBarSideMargin })
            .margin({ bottom: LayoutTokens.tabBarBottomGap + bottomNavInset() })
            .zIndex(50)
          }
        }
        .width('100%')
        .height('100%')
      }
      // 主导航必须显式 Stack：NavigationMode.Auto 在展开宽度下切 Split，且右栏内容区
      // **常驻预留**（未压目的地也不还给 navBar）→ 首页被压在 ~400vp 左窄列、右侧空白
      // （Mate X7 展开实测截图）。本应用首页是发现流，双栏范式不适用——展开态用
      // responsive.ets 的多列信息流铺满全宽。日后若做列表-详情双栏，需专门设计
      // navBarWidthRange + 空态展开，单独立项。
      .mode(NavigationMode.Stack)
      .id('mainNav')
      // 外层标题栏彻底退役：四个主 Tab 的顶栏都在各自内嵌 HdsNavigation 里（「我的」是最后
      // 一个，本轮迁入）。原先它用 BarStyle.STACK + 无色罩纯高斯承载「我的」整块顶栏，
      // 那套数学（状态栏 + 顶栏行 + 资料区实测回写）现已由 HdsNavigation 的
      // avoidLayoutSafeArea + bottomBuilder 声明高等价接管，见基准 §7.6.9 / §7.6.10。
      .hideTitleBar(true)
      // 首页每日一帖飞行卡向上抛射需一路溢出到窗口顶部（状态栏区域），
      // 关闭 Navigation 内容裁剪（详情页全屏、快照转场在独立层，均不受影响）。
      .clip(false)
      .navDestination(this.pageMap)
      // 首页卡片 → 帖子详情：一镜到底按官方范式实现——目的地页在 onReady 里
      // 按自己的 navDestinationId 注册转场，这里只负责按 from/to 的 id 查表并转交
      // （PUSH 交 to、POP 交 from）。未注册的目的地返回 undefined，走系统默认转场。
      .customNavContentTransition((from: NavContentInfo, to: NavContentInfo,
        operation: NavigationOperation): NavigationAnimatedTransition | undefined => {
        // ⚠️ 官方在此处要求 from/to **都**有 navDestinationId，那条守卫成立的前提是
        // 「源页本身也是 NavDestination」（官方示例的卡片列表页就是）。本项目源页是
        // Navigation 的**根内容**（HomeTab 在 navBar 位），PUSH 时 from.navDestinationId 为空，
        // 照抄这条守卫会让首页→详情的自定义转场整条失效（踩过：页面不展开变形、内容停在
        // 0 透明度，屏幕上只剩一张放大的卡片截图）。因此这里只用 id 查表，取不到即视为未注册。
        const toParam: AnimateCallback = CustomTransition.getInstance().getAnimateParam(to.navDestinationId ?? '');
        const fromParam: AnimateCallback =
          CustomTransition.getInstance().getAnimateParam(from.navDestinationId ?? '');
        // 未注册自定义转场的目的地（含返回目标）走系统默认转场
        if (fromParam.animation === undefined && toParam.animation === undefined) {
          return undefined;
        }
        CustomTransition.getInstance().operation = operation;
        const customAnimation: NavigationAnimatedTransition = {
          // PUSH 交 to、POP 交 from
          timeout: operation === NavigationOperation.PUSH ? toParam.timeout : fromParam.timeout,
          onTransitionEnd: (): void => {
            CustomTransition.getInstance().proxy = undefined;
          },
          transition: (transitionProxy: NavigationTransitionProxy): void => {
            CustomTransition.getInstance().proxy = transitionProxy;
            const animateParam: AnimateCallback =
              operation === NavigationOperation.PUSH ? toParam : fromParam;
            if (animateParam.animation !== undefined) {
              animateParam.animation(transitionProxy);
            } else {
              transitionProxy.finishTransition();
            }
          }
        };
        return customAnimation;
      })
      .width('100%')
      .height('100%')

      if (this.showCircleOnboarding) {
        CircleOnboarding({
          tags: this.onboardingTags,
          selectedNames: this.onboardingSelectedNames,
          loading: this.onboardingLoading,
          submitting: this.onboardingSubmitting,
          onToggle: (name: string): void => { this.toggleOnboardingTag(name); },
          onSkip: (): void => { this.finishCircleOnboarding(); },
          onConfirm: (): void => { this.confirmCircleOnboarding(); },
        })
        .zIndex(100)
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    // 所有页面点击统一通知圈子页；Logo 点击由 CircleTab 的时间戳保护过滤。
    .onClick((): void => { this.broadcastCircleLogoDismissal(); })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
