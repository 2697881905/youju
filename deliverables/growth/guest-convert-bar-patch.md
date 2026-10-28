# 游客引导条 · 待应用补丁（已写好但**未合入**）

**为什么先停在这里**（两条硬理由，不是偷懒）：
1. 这个会话里**没有 ArkTS 编译检查工具**（无 `check_ets_files` / DevEco MCP），我无法证明它能编译通过；
   而并行设计会话正在构建 `entry/` 同一模块 —— 塞进一个未编译验证的 `.ets` 可能直接让他们的构建失败，
   还会让人家来查我的改动。
2. 首版实现有一个**会造成可见 bug 的隐患**（下面 §2），必须先改掉再合，否则老用户会看到不该看到的东西。

组件源码：`deliverables/growth/GuestConvertBar.ets.txt`（改名放这里，避免被 hvigor 当源码编译）。

---

## 1. 三处改动（机械应用即可）

**① 新建组件**：把 `GuestConvertBar.ets.txt` 复制为 `entry/src/main/ets/components/GuestConvertBar.ets`。

**② `components/HomeTab.ets` 顶部 import**（第 8 行那句）：
```ts
import { getUserId } from '../utils/auth';
// 改成：
import { getUserId, getToken } from '../utils/auth';
import { GuestConvertBar } from './GuestConvertBar';
```

**③ 状态声明 + 挂载**（`@Builder feedScroll(seg)` 之前加状态；栅格 Column 的第一个子节点前加渲染）：
```ts
  // 登录态：@StorageProp 保证登录后引导条自动消失；但冷启动时 AppStorage 可能尚未水合，
  // 因此初值在 aboutToAppear 里用 getToken() 兜一次（见 §2）
  @StorageProp('authToken') authToken: string = '';
  @State guestBarDismissed: boolean = false;
  @State guestBarReady: boolean = false;   // ← 关键：没测出登录态之前一律不画
```
```ts
      Column({ space: SpaceTokens.sm }) {
        // 游客态引导条（满幅一行，放在两列栅格之前：不参与列数与 key 计算，关掉即消失）
        if (this.guestBarReady && this.authToken === '' && !this.guestBarDismissed) {
          GuestConvertBar({
            onLogin: (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
            },
            onDismiss: (): void => {
              this.guestBarDismissed = true;
            },
          })
        }
        Row({ space: SpaceTokens.xs }) { ... }   // ← 原有两列栅格，不动
```

---

## 2. 必须先补的隐患：`authToken` 已不是 PersistentStorage 键

`utils/auth.ets:19-21` 写明：登录态持久化已从 PersistentStorage **迁到 `sessionStore`（dataPreferences）**，
只保留非关键 UI 态走 PersistentStorage；`authToken` 是靠 `AppStorage.setOrCreate('authToken', token)` 在登录/登出时写入的。

**后果**：冷启动时如果 `@StorageProp('authToken')` 先于水合执行，它会拿到默认值 `''` →
**已登录用户会在首页看到一条"登录后可收藏"的引导条**。这是不能上线的观感 bug。

**修法**（就是 §1 里 `guestBarReady` 的作用）：在 HomeTab 的 `aboutToAppear()` 末尾补一行，
用直读 `getToken()`（走 sessionStore，可靠）决定要不要画：
```ts
  aboutToAppear(): void {
    // ...原有逻辑...
    this.authToken = getToken();      // 水合兜底：@StorageProp 只在变更后触发，初值不可信
    this.guestBarReady = true;
  }
```
> 注意 `getToken()` 直读不触发重绘（这是本项目反复踩过的坑），所以**登录后靠 `@StorageProp` 的变更事件消失，
> 首帧靠 `aboutToAppear` 的直读定值**，两者配合才对。

---

## 3. 合入后必须做的真机验收（6 项，缺一项不算完成）

| # | 验收项 | 判据 |
| --- | --- | --- |
| 1 | 游客态出现 | 卸载重装或退出登录后，首页顶部有一条引导；文案不被截断 |
| 2 | **已登录用户绝不出现** | 覆盖安装后冷启动（正是 auth.ets 记载的水合坑场景）不闪现在登录用户首页 |
| 3 | 点「登录」进 LoginPage | 返回后引导条消失（验证 @StorageProp 生效） |
| 4 | 点 ✕ 消失 | 本次会话内滚动、切分段、下拉刷新都不再出现 |
| 5 | 深色模式 | 引导条底色/描边/文字对比度正常（token 走 `ColorTokens.canvas/separator/primary`，需实拍确认） |
| 6 | 折叠屏两档 | Pocket 2 外屏（sm，2 列）与内屏（md，3–4 列）下栅格不被挤动、引导条不错位 |

**为什么第 6 项必须测**：引导条插在两列栅格**之前**（满幅一行），不影响列计算，但 `feedScroll` 的
`constraintSize({ minHeight: '100%' })` 与末卡让位逻辑对首行高度变化敏感 —— 只能靠真机像素确认。

---

## 4. 预期收益与测量（别凭感觉判断它有没有用）

- 现状基线（2026-10-28 实测）：30 天约 **211** 个设备出口在用 App，但只有 **43** 个用户注册过 PushToken，
  其中 7 人还关了系统通知 → **可召回率约 17%**（36/211）。
- 这条引导的目标是把「设备 → 注册」的转化率抬起来。判定方法：
  合入发版后跑 `./scripts/daily-ledger.sh`，对比发版前后 14 天的
  **当月新注册数 / 活跃设备出口数**（`./scripts/app-device-ips.sh` 的 posts IP 数做分母）。
- 若两周后该比值没有可辨变化，就说明问题不在引导而在**内容/留存**，应把资源转向 §6 的内容底座而不是加第二条弹窗。
