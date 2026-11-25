---
title: "bottom-drawer-slide-case:基于 HarmonyOS 的底部抽屉滑动效果实现项目 - AtomGit"
id: weburl_b16b53cf4dbe3dbb7773ebdbc1689e9f_d5e2f9a46c469c486d58dc3d707f8e417507970766173784
kb: HarmonyOS
folder: "实现底部抽屉滑动效果"
media_type: 2
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 实现底部抽屉滑动效果

### 介绍

本示例介绍了利用List实现底部抽屉滑动效果场景，使用RelativeContainer和Stack布局，将界面沉浸式（全屏）显示，实现地图拖动功能，开发者可以使用底部抽屉滑动效果。

### 效果图预览

<img src='screenshots/device/BottomDrawerSlideCase.gif' width=320>

##### 使用说明

1. 向上滑动底部列表，支持根据滑动距离进行分阶抽屉式段滑动。

### 工程目录

```
├──entry/src/main/ets                     // 代码区
│  ├──constants
│  │  └──CommonConstants.ets              // 公共常量
│  ├──entryability
│  │  └──EntryAbility.ets                 // 应用入口
│  ├──pages
│  │  └──BottomDrawerSlideCase.ets        // 主页面
│  ├──utils
│  │  ├──ArrayUtil.ets                    // 数组工具类
│  │  ├──GlobalContext.ets                // 全局上下文
│  │  ├──Logger.ets                       // 日志工具类
│  │  ├──SettingItem.ets                  // 设置项实体类
│  │  └──WindowModel.ets                  // 窗口管理工具
│  └──view
│     └──ComComponent.ets                 // 公共子组件
└──entry/src/main/resources               // 应用资源目录

```

### 具体实现

* RelativeContainer和Stack布局：使用RelativeContainer和Stack容器组件实现沉浸式全屏显示，将可滑动列表放置在页面底部，实现抽屉式滑动效果。

* 触摸事件处理：通过List组件的onTouch事件监听手势，记录手指按下和离开屏幕的纵坐标，判断手势是上滑还是下滑。

* 动态高度调整：根据手指滑动的距离动态调整列表高度，实现列表跟随手势实时变化的效果。

* 分阶滑动：在手指离开屏幕后，通过判断列表高度处于哪个区间（第一阶、第二阶、第三阶），自动将列表滑动到相应的高度位置。

* 窗口管理：通过WindowModel工具类获取窗口高度、状态栏高度和底部导航栏高度，实现沉浸式显示和布局计算。

* 动画效果：使用animation属性为列表高度变化添加动画效果，通过duration、curve等参数控制动画的流畅度。


### 相关权限

不涉及。

### 约束与限制

1. 本示例仅支持标准系统上运行，支持设备：直板机。

2. HarmonyOS系统：HarmonyOS 5.0.5 Release及以上。

3. DevEco Studio版本：DevEco Studio 5.0.5 Release及以上。

4. HarmonyOS SDK版本：HarmonyOS 5.0.5 Release SDK及以上。
