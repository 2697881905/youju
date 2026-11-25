---
title: "README (1).md"
id: markdown_b16b53cf4dbe3dbb7773ebdbc1689e9f_d5caf6f77112697aad27f4e33f62049a7507970766173784
kb: HarmonyOS
folder: "多设备新闻阅读界面"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 多设备新闻阅读界面

## 项目简介

本示例展示如何通过一套代码适配手机、折叠屏、平板、电脑等多种设备形态，降低多端开发和维护成本，为新闻类应用的多设备适配提供参考实践。

功能上涵盖推荐首页的多 Tab 内容栏目（热点要闻、大图轮播、上文下图卡片、新闻列表、热榜等）、新闻详情页（文章正文、评论区、悬浮工具栏）以及沉浸式搜索栏，各功能区块随设备形态自适应排列。

技术上采用自适应布局与响应式布局，基于 `products → features → common` 三层架构实现模块解耦，利用断点机制驱动栅格列数与区块排列变化，并结合沉浸光感材质与侧边栏/底部 Tab 栏实现不同设备形态的交互适配。

适用于直板机、折叠屏、平板和电脑产品。

## 效果预览

|                         阔折叠（外屏）                         |                          直板机                           |                            双折叠                            |
|:-------------------------------------------------------:|:------------------------------------------------------:|:---------------------------------------------------------:|
|  <img src="screenshots/device/purax.png" width="200"/>  | <img src="screenshots/device/phone.png" width="180" /> | <img src="screenshots/device/foldable.png" width="330" /> |
|                         **平板**                          |                         **电脑**                         |                                                           |
| <img src="screenshots/device/tablet.png" width="400" /> |    <img src="screenshots/device/pc.png" width="440" />    |                                                           |

## 使用说明

1. 运行应用后，页面会根据直板机、折叠屏、平板、电脑等设备形态呈现不同布局。

2. 直板机、折叠屏、平板等产品入口为`products/default`，采用沉浸式全屏布局与底部悬浮 Tab 栏；电脑产品入口为`products/pc`，聚焦大屏体验，采用沉浸式标题栏与侧边栏布局，不参与底部 Tab 栏切换。

3. 首页推荐页底部提供多个 Tab（推荐、热门、视频、小说等），点击 Tab 切换不同内容栏目。首页 Tab 内包含热点要闻、大图轮播、上文下图卡片、新闻列表、热榜等多个内容区块，区块数量与排列方式随断点自适应。

4. 顶部搜索栏下方提供可滚动的子 Tab 栏（推荐、热门、视频、财经、科技、房产等），在API版本为26.0.0以上时，搜索栏区域会展现沉浸光感材质。点击子 Tab 切换首页内容。电脑与大屏设备会以侧边栏形态展示子 Tab。

5. 新闻列表区块会随设备宽度断点自适应：sm 断点下以纵向列表单列展示，md 断点及以上以栅格双列展示，并控制新闻摘要内容的显隐。

6. 点击任意新闻卡片进入新闻详情页，底部悬浮工具栏提供保存、听、更多等样式按钮。底部工具栏在API版本为26.0.0及以上设备使用沉浸光感材质，低版本降级为背景模糊。

7. 详情页布局随设备形态适配：sm 断点下文章正文与评论区紧凑堆叠，md 断点及以上以侧边栏并排展示文章正文与评论区，评论区可滚动。

8. 电脑产品在详情页采用内联工具栏模式，标题栏提供返回、保存、听、更多按钮并避让系统窗口三按钮。

## 工程目录

```
├──common                                               // 公共能力层
│  ├──Index.ets                                         // 模块桶文件
│  └──src
│     └──main
│        ├──ets
│        │  ├──components                               // 公共 UI 组件
│        │  │  ├──NewsCard.ets                          // 左文右图卡片
│        │  │  ├──SwiperCardSection.ets                 // 大图轮播
│        │  │  ├──TextHeadlineSection.ets               // 蓝点要闻
│        │  │  └──TopTextBottomImageCard.ets            // 上文下图卡片
│        │  ├──constants
│        │  │  └──CommonConstants.ets                   // 通用常量与断点常量
│        │  ├──types
│        │  │  └──NewsCardDisplayData.ets               // 展示层数据契约接口
│        │  └──utils
│        │     ├──Logger.ets                            // 日志工具
│        │     ├──WidthBreakpointType.ets               // 断点映射工具
│        │     └──WindowUtil.ets                        // 窗口管理工具
│        └──resources                                   // 公共资源
├──features                                             // 基础特性层
│  ├──newsdetail                                        // 新闻详情模块
│  │  ├──Index.ets                                      // 模块桶文件
│  │  └──src
│  │     └──main
│  │        ├──ets
│  │        │  ├──constants                             // 栅格列数、工具栏高度、侧栏宽、标题栏配置等详情常量
│  │        │  │  ├──NewsDetailConstants.ets
│  │        │  │  └──NewsDetailNavigationOptions.ets
│  │        │  ├──model                                 // 详情与评论数据提供者及业务数据模型
│  │        │  │  ├──NewsDetailData.ets
│  │        │  │  └──NewsDetailModel.ets
│  │        │  ├──view                                  // 详情页主组件、文章正文视图、评论区视图
│  │        │  │  ├──CommentView.ets
│  │        │  │  ├──NewsContentView.ets
│  │        │  │  └──NewsDetailPage.ets
│  │        │  └──viewmodel                             // 详情视图模型与视图数据
│  │        │     ├──NewsDetailViewModel.ets
│  │        │     └──NewsDetailViewState.ets
│  │        └──resources                                // 新闻详情资源
│  └──recommendation                                    // 推荐首页模块
│     ├──Index.ets                                      // 模块桶文件
│     └──src
│        └──main
│           ├──ets
│           │  ├──constants                             // Tab 列表、子 Tab、列数、Swiper 间隔等推荐常量
│           │  │  └──RecommendationConstants.ets
│           │  ├──model                                 // 推荐数据提供者及业务数据模型
│           │  │  ├──NewsData.ets
│           │  │  └──RecommendationModel.ets
│           │  ├──view                                  // 推荐首页,顶部搜索栏、新闻列表、热榜、上文下图等区块视图
│           │  │  ├──MockPageView.ets
│           │  │  ├──NewsListSectionView.ets
│           │  │  ├──RecommendationView.ets
│           │  │  ├──TopBarSectionView.ets
│           │  │  └──TopTextBottomImageSectionView.ets
│           │  └──viewmodel                             // 推荐视图模型与视图数据
│           │     ├──RecommendationViewModel.ets
│           │     └──RecommendationViewData.ets
│           └──resources                                // 推荐首页资源
└──products                                             // 产品定制层
   ├──default                                           // 默认（直板机/折叠屏/平板）产品
   │  └──src
   │     └──main
   │        ├──ets
   │        │  ├──defaultability                        // 默认产品入口 Ability
   │        │  │  └──DefaultAbility.ets
   │        │  └──pages                                 // 默认产品页面装配
   │        │     └──Index.ets
   │        └──resources                                // 默认产品资源
   └──pc                                                // 电脑产品
      └──src
         └──main
            ├──ets
            │  ├──pages                                 // 电脑产品页面装配
            │  │  └──Index.ets
            │  ├──pcability                             // 电脑产品入口 Ability
            │  │  └──PcAbility.ets
            │  ├──view                                  // 电脑首页标题栏、详情标题栏等纯视图
            │  │  ├──PcDetailTitleBar.ets
            │  │  └──PcHomeTitleBar.ets
            │  ├──viewmodel                             // 电脑页面展示状态
            │  │  └──PcIndexViewModel.ets
            │  └──window                                // 电脑窗口策略
            │     └──PcWindowController.ets
            └──resources                                // 电脑产品资源
```

## 具体实现

1. 工程采用`products`、`features`、`common`三层架构：产品层负责不同设备的页面装配，特性层包含推荐首页和新闻详情业务，公共层提供通用组件、数据契约、断点及窗口管理能力。模块保持`products → features → common`单向依赖。

2. 推荐首页根据宽高断点调整顶部导航、轮播、新闻卡片、列表和热榜的排列方式；默认产品使用底部 Tab，电脑 产品使用侧边导航。

3. 新闻详情页在小尺寸设备上纵向展示正文与评论，在中大尺寸设备上并排展示；悬浮工具栏根据系统版本使用沉浸光感材质或背景模糊效果。

4. 电脑产品提供独立的沉浸式标题栏和窗口适配，并在首页与详情页中避让系统窗口按钮区域。

## 相关权限

不涉及

## 依赖

不涉及

## 约束与限制

1. 本示例仅支持标准系统上运行，支持设备：直板机、双折叠（Mate X 系列）、三折叠、阔折叠、平板和电脑。

2. HarmonyOS系统：HarmonyOS 6.1.0 Release及以上。

3. DevEco Studio版本：DevEco Studio 6.1.0 Release及以上。

4. HarmonyOS SDK版本：HarmonyOS 6.1.0 Release SDK及以上。
