---
title: "SmartReach:基于 HarmonyOS 的智感握姿体验应用项目 - AtomGit"
id: weburl_b16b53cf4dbe3dbb7773ebdbc1689e9f_3bcbd5384e2493014f06d1e8faca8ff27507970766173784
kb: HarmonyOS
folder: "智感握姿"
media_type: 2
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 智感握姿

## 介绍

本示例基于HdsTabs组件，实现了一个能体验智感握姿的应用界面。HdsTabs底部页签组件，集成了悬浮和左右跟手显示的功能，开发者可以根据本示例在折叠屏和平板设备上实现底部页签组件的悬浮效果和左右跟手效果。

## 效果图预览

|                       **手机**                       |                     **折叠屏**                     |                      **平板**                       | 
|:--------------------------------------------------:|:-----------------------------------------------:|:-------------------------------------------------:|
| ![Index](screenshots/device/smart_reach_phone.png) | ![Get](screenshots/device/smart_reach_fold.png) | ![OnDrop](screenshots/device/smart_reach_pad.png) |


## 使用说明

1. 进入应用首页，分别点击或滑动屏幕左边和右边，底部的悬浮页签组件会根据点击的位置左右变化。
2. 进入应用首页，分别使用左右手握持设备，并滑动或点击页面，底部的悬浮页签组件的位置会根据握持滑动状态左右变化。

## 工程目录

```
├──entry/src/main/ets                         // 代码区
│  ├──common
│  │  └──CommonConstants.ets                  // 公共常量
│  ├──component
│  │  └──WaterFlowView.ets                    // 瀑布流内容页面
│  ├──entryability
│  │  └──EntryAbility.ets       
│  ├──model
│  │  ├──GlobalInfoModel.ets                  // 一多公共数据实体类
│  │  └──TabsBarModel.ets                     // 底部页签实体类       
│  ├──pages
│  │  └──MainPage.ets                         // 主页面       
│  └──utils
│     ├──BreakpointSystem.ets                 // 一多断点工具类
│     ├──Logger.ets                           // 日志打印工具类
│     ├──PreferenceManager.ets                // 本地数据持久化工具类
│     └──WindowUtil.ets                       // 窗口工具类
└──entry/src/main/resources                   // 应用资源目录
```

## 相关权限

允许应用获取动作感知能力：ohos.permission.DETECT_GESTURE

## 依赖

不涉及

## 约束与限制

1. 本示例仅支持标准系统上运行，支持设备：直板机，双折叠，阔折叠，三折叠，平板，部分机型暂不支持该功能，请以设备实际体验为准。

2. HarmonyOS系统：HarmonyOS 6.1.0 Release及以上。

3. DevEco Studio版本：DevEco Studio 6.1.0 Release及以上。

4. HarmonyOS SDK版本：HarmonyOS 6.1.0 Release SDK及以上。
