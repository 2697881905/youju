# 跨 Tab 跳转修复 - 交付概览

**项目**：大蓝书 HarmonyOS NEXT 应用
**日期**：2026-07-19
**团队**：software-nav-migration（架构师高见远 → 工程师寇豆码 → QA 严过关）
**commit**：`cb281a5`（已推送 main）

## TL;DR

修复首页 HomeTab 关注流空态「去发现」按钮点击无效问题。根因是 `AppStorage.setOrCreate('homeTabIndex', 1)` 写了信号但**全项目无人订阅**。采用方案 A（AppStorage 桥接 + @StorageLink + @Watch）补全监听链路，3 文件 +20/-2 行改动，assembleHap 编译通过，QA 独立验证全项 PASS。

## 交付概览

| 项 | 状态 |
|----|------|
| 交付状态 | ✅ 已交付（已推送 main） |
| 编译验证 | ✅ assembleHap BUILD SUCCESSFUL |
| QA 验证 | ✅ 5 项全 PASS（源码审查/编译/逻辑链路/边界/回归） |
| 已知问题 | 0 |
| 改动文件 | 3 个核心 + 2 个文档 |

## 改动文件清单

### 核心代码改动（3 文件 +20/-2 行）

| 文件 | 改动 |
|------|------|
| `entry/src/main/ets/utils/nav.ts` | 新增 `emitTabSwitch(target)` 信号发射器（递增序列号保证每次触发 @Watch） |
| `entry/src/main/ets/pages/Index.ets` | 新增 `@StorageLink('tabSwitchSignal') @Watch('onTabSwitch') tabSwitchSignal` + `onTabSwitch()` 方法 |
| `entry/src/main/ets/components/HomeTab.ets` | import 加 `emitTabSwitch`，onClick 从 `AppStorage.setOrCreate('homeTabIndex', 1)` 改为 `emitTabSwitch(1)` |

### 设计文档（新增 2 个）

| 文件 | 内容 |
|------|------|
| `docs/nav-migration-design.md` | 完整设计文档（含方案 A/B/C 对比 + 实现细节 + 风险评估） |
| `docs/nav-sequence-diagram.mermaid` | 数据流时序图 |

## 数据流

```
用户点击「去发现」(HomeTab.ets)
  ↓ emitTabSwitch(1)
nav.ts:
  AppStorage.setOrCreate('tabSwitchTarget', 1)   ← 先写 target
  AppStorage.setOrCreate('tabSwitchSignal', seq+1) ← 后递增 signal
  ↓ @StorageLink 检测 signal 变化
Index.ets:
  @Watch('onTabSwitch') 触发
  onTabSwitch(): target = 1, currentIndex = 1
  ↓ Tabs({ index: currentIndex }) 重渲染
切到 CircleTab（圈子 Tab，索引 1） ✅
```

## 关键设计点

1. **递增序列号**：直接写 target 在连续点击时 @Watch 不触发（同值不触发），用 signal 递增规避
2. **写入顺序**：target 先写、signal 后写，保证 @Watch 回调读到最新 target
3. **边界守卫**：`if (target >= 0 && target <= 4)` 防越界
4. **`?? 0` 兜底**：target 未初始化时不崩
5. **复用已有模式**：HomeTab.ets:39 的 `@StorageLink('authToken') @Watch('onTokenReady')` 已验证可行，方案 A 完全复用此模式

## 长期路径

方案 A 不阻碍未来 Navigation 迁移。架构师建议下个迭代作为独立 epic 走方案 C（全量 Navigation + 自定义底部 TabBar），届时 `emitTabSwitch` 被 NavPathStack 替换即可，不产生技术债。

**TabsController 不可导入问题仍存在**，但通过本方案已绕过，不再阻碍跨 Tab 跳转。

## 用户下一步建议

1. **真机验证**：DevEco Studio Run 重装 HAP，登录后首页切到「关注」流，关注 0 人时点「去发现」应切到圈子 Tab
2. **回归测试**：测试 5 个 Tab 普通点按/滑动切换、消息红点、登录跳转是否正常
3. **扩展场景**：未来 ProfilePage/MessagePage 需跳首页时，直接调 `emitTabSwitch(0)` 即可
4. **Navigation 迁移**：作为独立 epic 规划（方案 C），可参考 `docs/nav-migration-design.md` 中的对比分析
