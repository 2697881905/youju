---
title: "Docs · 调试探针手册.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_07adff0c3eeff31c54ad7d74a0c23f997526104239726721
kb: 有径-YouJing
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 调试探针手册（有径）

> 全部探针只进 **debug 构建**（`BuildConfig.IS_DEBUG`），正式包无效。
> 通用姿势：
>
> ```bash
> HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
> T=<设备序列号>          # hdc list targets，如 10.72.138.50:46077
> $HDC -t $T install -r entry/build/default/outputs/default/entry-default-signed.hap
> $HDC -t $T shell aa force-stop com.youjing.app
> $HDC -t $T shell hilog -r
> $HDC -t $T shell aa start -a EntryAbility -b com.youjing.app --ps <探针> <参数>
> sleep N                  # 各探针等待秒数见下表
> $HDC -t $T shell hilog -x | grep 'Probe\.'   # 或对应 TAG
> ```

## 端侧探针（EntryAbility）

| 探针 | 参数 | 用途 | 期望输出（TAG） | 等待 |
|---|---|---|---|---|
| 生成直连 | `--ps genprobe 1` | P0：杨凌 1 天真实生成（直连优先于 BFF） | `杨凌生成成功 days=1 activities=…`、`LLM 用量 model=…`（`Probe.Gen`） | ~18s |
| 精选 | `--ps pickprobe 1` | P1：杨凌 10 站候选走 AGC→BFF→直连→规则 | `精选成功 ranked=10` + 前 3 条理由（`Probe.Pick`） | ~12s |
| 提醒全链路 | `--ps remindsyncprobe 1` | P4：合成行程（含 `advanceDays=7`）走 `TripReminder.syncTrip`，先清本 App 旧提醒 | `清理前有效提醒=N`、`scheduled=… failed=… blocked=… blockedLimit=…`（`Probe.RemindSync`） | ~10s |
| 提醒单发 | `--ps remindprobe 45` | P4：N 秒后弹一条系统提醒，验**锁屏/退后台真的响**（AGC 代理提醒开通后用） | `提醒探针已发布 id=…`（`Data.TripReminder`） | 弹窗即验 |
| 到站通知 | `--ps arrivalprobe 1` | P5：直接发一条本地到站通知 | `到站通知探针 ok=true`（`Probe.Arrival`） | ~8s |
| 围栏注册 | `--ps geoprobe 1` | P5：博览园坐标注册 100m 围栏，验证 AGC 围栏监测是否放行 | `围栏注册成功 id=…` / 事件回调（`Probe.Geofence`） | 现场走点 |
| 坐标校准 | `--ps coordprobe 1` | 杨凌现场：读一次 GPS，打印最近 3 个种子站距离 | `fix lat=… acc=…`、`#1 <站名> 距离=…m seed=…`（`Probe.Coord`） | ~15s |

补充：
- `darkprobe` / `lightprobe=1` 强制深/浅色档（色板探针）。
- 深链预填：`--ps destination 杨凌 --ps start 2026-11-10 --ps end 2026-11-10 --ps param <json>`。

### 通路切换（genprobe / pickprobe）

- 走本地 BFF：`ApiConfig.BFF_BASE_URL` 填本机地址（当前 `http://192.168.2.1:3000`）。
- 走端侧直连：[DirectConfig.ets](../entry/src/main/ets/common/config/DirectConfig.ets) 填 URL/KEY，
  **同时把 `BFF_BASE_URL` 置空**；测完清 Key 重装干净包。
- `pickprobe` 在 BFF 通路下会先补一次设备激活（探针早于 Index 的激活时序）。

## 工具脚本（本机，不占设备）

| 脚本 | 用途 | 备注 |
|---|---|---|
| `node tools/probe_llm_rules.mjs --days 1 --yes` | 真模型提示词回归（validator + 规则 4/13/18/20/不重叠） | ≈¥0.003；`--strict` 把规则 19 升为硬门槛 |
| `node tools/probe_yangling_gen.mjs [--yes]` | 杨凌 1 天种子 10 站真模型生成回归 | 不带 `--yes` 只算预算 |
| `node tools/check_cloud_deploy.mjs [--test]` | AGC 云函数部署自检（文件/handler/单测/prompt 单源/env 映射/端侧回填位） | 全 PASS 才上控制台 |
| `node bff/scripts/reset-dev-quota.mjs [--dry]` | 重置本地 BFF 赠送额度（402 → 可用） | 仅开发库；生产禁用 |
| `bash tools/verify_replan_logic.sh` | 离线断言全集（`SKIP_PLANNER_OK cases=118` / `REPLAN_PARSER_OK cases=26`） | 改排程/解析逻辑后必跑 |

## 已知外部闸门（探针无法绕过）

| 闸门 | 现象 | 状态 |
|---|---|---|
| 代理提醒 | `publishReminder` 报 `1700002` 且本 App 有效提醒为 0 ⇒ 能力未开通（非真超限） | AGC 申请中 |
| 围栏监测 | `addGnssGeofence` 注册成功但事件零回调 | AGC「围栏后台唤醒」申请中 |
| 实况窗 | 已被 AGC 驳回（场景不在开放范围），**不再申请、代码已移除** | 关闭 |
| 云函数 | AGC「云函数」未开通；开通后部署并回填 `REPLAN_URL` / `PickConfig.URL` | 待开通 |
