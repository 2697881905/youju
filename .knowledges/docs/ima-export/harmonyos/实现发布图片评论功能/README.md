---
title: "README.md"
id: markdown_b16b53cf4dbe3dbb7773ebdbc1689e9f_3b7bfa2bdbb2c7b7a8f1ae06b3ce65bf7507970766173784
kb: HarmonyOS
folder: "实现发布图片评论功能"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 实现发布图片评论功能

### 简介

本示例通过拉起系统相机实现发布图片评论，便于用户了解系统相机接口的调用方式。

### 效果预览

| 360vp                              | 600vp                                    | 840vp                                   |
| ---------------------------------- |------------------------------------------|-----------------------------------------|
| ![](screenshots/Devices/ImageComment.png) | ![](screenshots/Devices/ImageComment_fold.png) | ![](screenshots/Devices/ImageComment_pad.png) |

使用说明：

1.启动后点击文本框，再点击相机按钮，拉起系统相机。

2.拍照后返回，点击发布按钮。

### 库目录

```
├──entry/src/main/ets
│  ├──commmon/constants
│  │  └──CommonConstants.ets       // 常量类 
│  ├──pages                                  
│  │  └──ImageCommentComponent.ets // 首页                            
│  ├──model
│  │  ├──CommentModel.ets          // 评论类
│  │  └──MockCommentData.ets       // 评论数据
│  ├──utils
│  │  ├──BreakpointUtils.ets       // 断点工具类        
│  │  ├──CameraUtils.ets           // 拉起相机 
│  │  ├──Logger.ets                // 日志工具类                        
│  │  └──WindowUtil.ets            // 窗口工具类
│  ├──view
│  │  ├──CommentInputDialog.ets    // 发布评论弹窗
│  │  ├──CommentItemView.ets       // 弹窗组件
│  │  ├──CommentItemView.ets       // 评论组件
│  │  └──ImageListView.ets         // 评论图片列表
│  └──ImageCommentController.ets   // 导出工具类
└──entry/src/main/resources        // 应用资源目录
```

### 相关权限

不涉及

### 约束与限制

1. 本示例仅支持标准系统上运行，支持设备：phone，table，PC/2in1。

2. HarmonyOS系统：HarmonyOS 5.0.0 Release及以上。

3. DevEco Studio版本：DevEco Studio 5.0.0 Release及以上。

4. HarmonyOS SDK版本：HarmonyOS 5.0.0 Release SDK及以上。
