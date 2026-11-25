---
title: "2026-10-05-arkui-settings-list-itemgroup-migration.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_3b27dfa255db1287f0e915336b2c00487505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-05-arkui-settings-list-itemgroup-migration
title: ArkUI 设置页从 Scroll+Column+自定义卡片行迁移到官方 List+ListItemGroup+ListItem
category: coding-pattern
nature: decision
created_at: 2026-10-05T02:26:38
updated_at: 2026-10-05T02:26:38
tags: [arkui, list, listitemgroup, listitem, settings-page, scroll, migration, official-component]
keywords: [List, ListItemGroup, ListItem, Scroll, Column, sectionRow, 设置页, 连续分组列表, 独立卡片行, ListItemGroup header, @Builder, @StorageLink, Toggle行, CARD_SHADOW, ArkUI列表范式, 官方推荐组件]
problem_patterns: [custom-card-list-vs-official-grouped-list, scroll-column-sectionrow-to-list-itemgroup-listitem, settings-page-list-migration-decision]
source_sessions: [ses_ef7eb2ec0ffeDRPQj3vxMFaUQC]
project: HarmonyProject1
severity: medium
quality_score: 88
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: S
related_experiences: [2026-10-05-hmos-custom-to-native-component-replacement, 2026-09-16-arkui-list-interaction-completeness]
---

# ArkUI 设置页从 Scroll+Column+自定义卡片行迁移到官方 List+ListItemGroup+ListItem

## Scenario

HarmonyOS 应用中设置页通常使用 `Scroll` + `Column` + 自定义卡片行（每行独立圆角+阴影+间距）构建分组列表。当用户偏好官方原生组件时，需要决定是否迁移到官方 `List` + `ListItemGroup` + `ListItem` 方案，以及如何实施迁移同时保持功能完整性。

典型触发条件：
- 用户要求将设置页的选项卡/卡片行改为官方原生组件
- 项目编码偏好明确倾向官方/原生实现
- 设置页使用 `Scroll` + `Column` + 自定义 `@Builder sectionRow` 构建分组列表
- 当前每行是独立卡片（圆角 + 阴影 + 行间间距），非连续分组列表风格

## Key Signals

1. 设置页使用 `Scroll` + `Column({ space: 24 })` + 多个 `Column({ space: 10 })` 分区构建，每行通过 `@Builder sectionRow()` 生成独立卡片
2. 每行卡片有 `backgroundColor` + `borderRadius(CARD_RADIUS)` + `shadow(CARD_SHADOW)` + `onClick`——典型的"独立卡片行"风格
3. 分区标题（如"账号与安全"、"隐私"）是 `Column` 内的 `Text` 组件，非 `ListItemGroup` 的 `header`
4. Toggle 行（如深色模式开关）使用 `@StorageLink` 双向绑定，通过 `@Builder` 传入时存在值快照问题
5. 用户询问"官方 List + ListItemGroup + ListItem 是官方最推荐的组件吗"——表明对官方范式的需求

## Essence

**决策准则**：`List` + `ListItemGroup` + `ListItem` 是 ArkUI 列表场景的官方首选组件，系统应用（如系统设置页）均使用此方案。当用户追求官方规范和系统一致性时，应迁移；当更看重卡片的视觉层次感和呼吸感时，可保持现状。

**两种风格的核心差异**：

| 维度 | Scroll+Column+独立卡片行 | List+ListItemGroup+ListItem |
|------|--------------------------|------------------------------|
| 视觉风格 | 每行独立卡片（圆角+阴影+间距） | 连续分组列表（组内行紧邻、分组整体圆角） |
| 性能 | 全量渲染，无懒加载 | 支持懒加载，大数据量性能更优 |
| 官方范式 | 非官方列表范式 | 官方首选列表方案 |
| 层次感 | 强（卡片阴影+间距呼吸感） | 较平（连续行无间距） |
| 系统一致性 | 低（自定义风格） | 高（与系统设置页风格一致） |

**关键约束**：
- `ListItemGroup` 的 `header` 必须是 `@Builder` 函数，用于渲染分区标题
- `ListItem` 内不能直接使用 `@Builder sectionRow()` 传参绑定 `@StorageLink` Toggle——`@Builder` 传参会创建值快照，导致 Toggle 状态不同步；Toggle 行必须内联在 `ListItem` 中直接绑 `@StorageLink`
- 迁移后 `CARD_SHADOW` 等 import 不再使用，需清理

## Approach

### 步骤 1：评估迁移决策

确认用户偏好和场景需求：
- 追求官方规范和系统一致性 → 迁移
- 更看重卡片视觉层次感 → 保持现状
- 设置页行数较多（>20行）→ 迁移（懒加载性能优势）
- 设置页行数较少 → 两者均可

### 步骤 2：改造 sectionRow @Builder 为 ListItem 生成器

```typescript
// 改造前：sectionRow 生成独立卡片
@Builder sectionRow(icon: Resource, label: string, action: () => void) {
  Row({ space: 12 }) {
    Image(icon).width(22).height(22).fillColor($r('app.color.ds_icon'))
    Text(label).fontSize(16).layoutWeight(1)
    Image($r('app.media.chevron_right')).width(18).height(18).fillColor($r('app.color.ds_icon'))
  }
  .width('100%')
  .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  .backgroundColor($r('app.color.card_bg'))
  .borderRadius(CARD_RADIUS)
  .shadow(CARD_SHADOW)
  .onClick(action)
}

// 改造后：sectionRow 生成 ListItem（无卡片圆角/阴影，由 ListItemGroup 统一裁剪）
@Builder sectionRow(icon: Resource, label: string, action: () => void) {
  ListItem() {
    Row({ space: 12 }) {
      Image(icon).width(22).height(22).fillColor($r('app.color.ds_icon'))
      Text(label).fontSize(16).layoutWeight(1)
      Image($r('app.media.chevron_right')).width(18).height(18).fillColor($r('app.color.ds_icon'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(action)
  }
}
```

### 步骤 3：新增分组 header @Builder

```typescript
@Builder groupHeader(title: string) {
  Text(title)
    .fontSize(13).fontFamily($r('app.string.font_family'))
    .fontColor($r('app.color.text_secondary'))
    .padding({ left: 16, top: 8, bottom: 4 })
}
```

### 步骤 4：Toggle 行内联处理

```typescript
// ❌ 错误：通过 @Builder 传入 @StorageLink Toggle——值快照导致状态不同步
@Builder toggleRow(icon: Resource, label: string, storageLink: boolean) {
  ListItem() {
    Row() {
      Image(icon)...
      Text(label)...
      Toggle({ type: ToggleType.Switch, isOn: storageLink }) // 快照值，不联动
    }
  }
}

// ✅ 正确：Toggle 行内联在 ListItem 中，直接绑 @StorageLink
ListItem() {
  Row() {
    Image(resolveSettingsIcon('moon'))...
    Text('深色模式')...
    Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
      .onChange((isOn: boolean) => { this.darkMode = isOn; toggleDarkMode(isOn); })
  }
  .width('100%')
  .padding({ left: 16, right: 16, top: 14, bottom: 14 })
}
```

### 步骤 5：重写 build 方法

```typescript
// 改造前：Scroll + Column + 分区 Column
build() {
  Column() {
    // 顶栏...
    Scroll() {
      Column({ space: 24 }) {
        Column({ space: 10 }) {
          Text('账号与安全')...
          this.sectionRow('phone', '账号绑定', () => { ... });
          // ...
        }
        // 其他分区...
      }
    }
  }
}

// 改造后：List + ListItemGroup + ListItem
build() {
  Column() {
    // 顶栏...
    List({ space: 16 }) {
      ListItemGroup({ header: this.groupHeader('账号与安全') }) {
        this.sectionRow('phone', '账号绑定', () => { ... });
        // ...
      }
      // 其他分组...
      // 退出登录/注销：登录时渲染为额外 ListItemGroup（无 header）
      if (this.authUserId !== '') {
        ListItemGroup() {
          ListItem() { /* 退出登录 */ }
          ListItem() { /* 账号注销 */ }
        }
      }
    }
    .layoutWeight(1)
    .width('100%')
  }
}
```

### 步骤 6：清理不再使用的 import

移除 `CARD_SHADOW`（不再使用阴影）、`CARD_RADIUS`（由 ListItemGroup 统一圆角裁剪）等 import。

### 步骤 7：编译验证

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --no-daemon
```

确认 BUILD SUCCESSFUL，且未引入新的 ERROR/WARN。

## Faster Next Time

- **检查清单**：迁移前先确认 Toggle 行不能通过 `@Builder` 传参绑定 `@StorageLink`——必须内联在 `ListItem` 中
- **决策捷径**：用户问"官方最推荐的组件吗"时，`List` + `ListItemGroup` + `ListItem` 是 ArkUI 列表场景的确定答案；系统设置页就是此方案的参考实现
- **视觉风格预期管理**：迁移前明确告知用户——从"独立卡片行"变为"连续分组列表"，层次感降低但系统一致性提高；让用户确认接受风格变化再实施
- **header @Builder 模式**：`ListItemGroup` 的 `header` 参数接受 `@Builder` 函数，用于渲染分区标题——这是从 `Column` 内 `Text` 标题迁移到 `ListItemGroup` 的关键映射
- **无 header ListItemGroup**：退出登录/注销等高风险操作可以作为独立的 `ListItemGroup`（不传 `header`），与常规设置分组视觉分离
- **import 清理**：迁移后检查 `CARD_SHADOW`、`CARD_RADIUS` 是否还有使用方，无则移除——避免遗留无用 import

## Applicability Boundaries

**适用场景**：
- 设置页、配置页等分组列表页面
- 用户偏好官方原生组件和系统一致性
- 列表行数较多，需要懒加载性能优化
- 从 `Scroll` + `Column` + 自定义卡片行迁移到官方列表范式

**不适用场景**：
- 页面行数极少（<5行），`List` 的懒加载优势不体现
- 必须保持"每行独立卡片+阴影"的视觉风格
- `ListItemGroup` 的连续行裁剪行为与设计需求冲突
- Toggle 行需要通过 `@Builder` 复用时（`@StorageLink` 快照问题无法绕过）

**边界提醒**：
- `@Builder` 传参绑定 `@StorageLink` 的值快照问题是 ArkUI 状态管理的通用限制，不仅限于 Toggle——任何需要双向同步的 `@StorageLink`/`@Link` 变量都不能通过 `@Builder` 传参实现
- `ListItemGroup` 的圆角裁剪行为由系统控制，自定义行内圆角可能被裁剪覆盖

## Evidence or Examples

**项目实例**（HarmonyProject1 SettingsPage.ets）：

1. 设置页原结构：`Scroll` + `Column({ space: 24 })` + 4 个分区 `Column({ space: 10 })`，每行通过 `@Builder sectionRow()` 生成独立卡片（`backgroundColor` + `borderRadius(CARD_RADIUS)` + `shadow(CARD_SHADOW)`）
2. 分区标题：账号与安全 / 隐私 / 通用 / 关于
3. Toggle 行：深色模式（`@StorageLink('isDarkMode')`）、跟随系统（`@StorageLink('followSystem')`）
4. 退出登录/注销：登录时显示，随内容滚动

**迁移后结构**：
- `List({ space: 16 })` + 4 个 `ListItemGroup({ header: this.groupHeader(...) })` + 1 个无 header `ListItemGroup`（退出登录/注销）
- `sectionRow` 改为生成 `ListItem`（去掉卡片圆角/阴影/按压态）
- Toggle 行内联在 `ListItem` 中（直接绑 `@StorageLink`）
- 移除 `CARD_SHADOW` import

**编译验证**：`BUILD SUCCESSFUL in 5s 839ms`，无新增 ERROR/WARN。
