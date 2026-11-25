---
title: "nav-sequence-diagram_260925023958.mermaid"
id: markdown_798285c88467638f6a8dc28635ad6f33_5170d1d475caf25f0f175e36f86f5af77505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
sequenceDiagram
    participant U as 用户
    participant HT as HomeTab (Tab 0)
    participant NAV as utils/nav.ts
    participant AS as AppStorage
    participant IDX as Index (@Entry)
    participant T as Tabs 组件

    U->>HT: 点击「去发现」
    HT->>NAV: emitTabSwitch(1)
    NAV->>AS: setOrCreate('tabSwitchTarget', 1)
    NAV->>AS: setOrCreate('tabSwitchSignal', N+1)
    AS-->>IDX: @StorageLink 同步 tabSwitchSignal 变化
    IDX->>IDX: @Watch('onTabSwitch') 触发
    IDX->>AS: get('tabSwitchTarget') → 1
    IDX->>IDX: this.currentIndex = 1
    IDX->>T: index={this.currentIndex} 重渲染
    T-->>U: 切换到 CircleTab (Tab 1)
