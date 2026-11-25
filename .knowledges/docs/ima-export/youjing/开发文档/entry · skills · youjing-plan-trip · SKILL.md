---
title: "entry · skills · youjing-plan-trip · SKILL.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_95b75fe503c2b1bbd0dacf8e0521b5297526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
name: youjing-plan-trip
description: 为「有径」记下旅行基础参数，用户打开应用后自动进入行程规划页并预填，响应“帮我规划去上海的行程”等说法
---

# youjing-plan-trip

本Skill基于ArkTS函数`planTrip`，响应自然语言中"帮我规划去某地""安排几天几晚的旅行"等意图，
把目的地、出发日期、天数、同行人数记入宿主应用「有径」的规划草稿，
由用户在页面内继续选择玩法偏好与景点后生成行程。

> **手机上的拉起限制**：HarmonyOS 不允许后台应用自行拉起界面（`startAbility` 返回 201，
> 该豁免权限只给系统应用）。因此本Skill在手机上**不会**直接弹出有径，
> 而是把参数记下并返回 `data.launched=false`。小艺回复时应如实说明
> 「已记下，打开有径就会自动进入行程规划页」；用户点开有径后，页面会自动预填这些参数。
> PC/2in1 上若系统允许拉起，`launched` 为 `true`，回复可直接说已打开。

## 触发场景

当用户明确表达**新建一段旅行规划**，且目的地属于北京、上海、广州、深圳时调用。典型话术:

- “帮我规划去北京的行程”
- “安排一次上海三天两晚的旅游”
- “下个月去广州玩四天，两个人”
- “我想去深圳玩，9 月 10 号出发”

不要调用的情况:

- 用户只是问景点介绍、天气、订票或美食推荐——本Skill只负责预填行程参数。
- 用户说“看看我之前做的行程”“打开我的行程”——意图是查看已有行程，不是新建规划。
- 目的地不在北京、上海、广州、深圳——当前数据未覆盖，不要调用，直接告知暂不支持。
- 用户没有给出出发日期——先追问具体日期，不要猜测或代填今天。
- 用户已经打开有径且正在规划另一段行程——不要打断当前编辑，先询问是否新建。

### 场景1:预填行程参数(planTrip)

**触发场景**:用户说"帮我规划去北京的行程"、"安排一次上海三天两晚的旅游"等

**执行参数**:
示例如下:

```
exec-cli(command: ohos-arkTSScript --skillName 'youjing-plan-trip' --scriptPath 'scripts/PlanTripSkill.ets' --functionName 'planTrip' --args '{
    "arg1": "上海",
    "arg2": "2026-08-01",
    "arg3": "4",
    "arg4": "3"
}'
)
```

约束如下:

```
{
    "type": "object",
    "properties": {
        "command": {
            "type": "string",
            "description": "命令行",
            "const": "ohos-arkTSScript"
        },
        "skillName": {
            "type": "string",
            "description": "skill名称",
            "const": "youjing-plan-trip"
        },
        "scriptPath": {
            "type": "string",
            "description": "ETS文件路径",
            "const": "scripts/PlanTripSkill.ets"
        },
        "functionName": {
            "type": "string",
            "description": "函数名称",
            "const": "planTrip"
        },
        "args": {
            "type": "object",
            "description": "Object类型的参数,由系统智能体填入。举例:{'arg1':'上海','arg2':'2026-08-01','arg3':'4','arg4':'3'}",
            "properties": {
                "arg1": {
                    "type": "string",
                    "description": "目的地城市,只支持北京、上海、广州、深圳",
                    "enum": ["北京", "上海", "广州", "深圳"]
                },
                "arg2": {
                    "type": "string",
                    "description": "出发日期,ISO 格式 YYYY-MM-DD,如 2026-08-01"
                },
                "arg3": {
                    "type": "string",
                    "description": "行程天数(含首尾),1-30 的整数字符串;用户未说天数时省略,默认 3 天"
                },
                "arg4": {
                    "type": "string",
                    "description": "同行人数,1-30 的整数字符串;用户未说人数时省略,默认 2 人"
                }
            },
            "required": ["arg1", "arg2"]
        }
    },
    "required": [
        "command",
        "skillName",
        "scriptPath",
        "functionName",
        "args"
    ]
}
```

**执行返回值**:
示例如下:

1. 成功记下参数（手机上的正常路径，App 未被自动拉起）

```
{
  "type": "result",
  "status": "success",
  "data": {
    "destination": "上海",
    "startDate": "2026-08-01",
    "days": 4,
    "people": 3,
    "route": "TripInput",
    "launched": false,
    "message": "已记下：上海，8月1日出发，4天，3人。打开「有径」会自动进入行程规划页并填好这些信息。"
  }
}
```

2. 入参非法

```
{
  "type": "result",
  "status": "failed",
  "errCode": "ERR_INVALID_PARAMS",
  "errMsg": "destination 成都 is not supported",
  "suggestion": "目前只支持北京、上海、广州、深圳，你想去哪一个？"
}
```

3. 内部错误（参数没能落盘）

```
{
  "type": "result",
  "status": "failed",
  "errCode": "ERR_INTERNAL",
  "errMsg": "prefill persist failed",
  "suggestion": "没能记下这次规划，请打开「有径」手动填写行程信息"
}
```

约束如下:

```
{
  "type": "object",
  "required": ["type", "status"],
  "properties": {
    "type": {
      "type": "string",
      "description": "结果类型标识",
      "const": "result"
    },
    "status": {
      "type": "string",
      "description": "执行状态: success表示成功, failed表示失败",
      "enum": ["success", "failed"]
    },
    "data": {
      "type": "object",
      "description": "开发者返回的自定义业务数据,结构由具体分支决定"
    },
    "errCode": {
      "type": "string",
      "description": "错误码,仅在status=failed时出现",
      "enum": ["ERR_INVALID_PARAMS", "ERR_INTERNAL"]
    },
    "errMsg": {
      "type": "string",
      "description": "错误描述",
      "minLength": 1
    },
    "suggestion": {
      "type": "string",
      "description": "建议的下一步操作,可由系统智能体直接组织成自然语言回复",
      "minLength": 1
    }
  },
  "oneOf": [
    {
      "description": "成功: 参数已记下（手机）或已拉起（PC/2in1）; 用户打开有径即自动预填屏2",
      "properties": {
        "status": { "const": "success" },
        "data": {
          "type": "object",
          "required": ["destination", "startDate", "days", "people", "route", "launched", "message"],
          "properties": {
            "destination": {
              "type": "string",
              "description": "目的地城市",
              "minLength": 1
            },
            "startDate": {
              "type": "string",
              "description": "出发日期,ISO 格式 YYYY-MM-DD",
              "minLength": 1
            },
            "days": {
              "type": "integer",
              "description": "行程天数(含首尾)",
              "minimum": 1,
              "maximum": 30
            },
            "people": {
              "type": "integer",
              "description": "同行人数",
              "minimum": 1,
              "maximum": 30
            },
            "route": {
              "type": "string",
              "description": "已打开的页面路由",
              "const": "TripInput"
            },
            "launched": {
              "type": "boolean",
              "description": "是否已自动拉起应用页面。手机恒为 false（系统禁止后台拉起），此时参数已记下，用户打开有径即自动预填"
            },
            "message": {
              "type": "string",
              "description": "可直接作为小艺回复主体的中文说明,如实描述已记下/已打开以及下一步",
              "minLength": 1
            }
          }
        }
      },
      "required": ["type", "status", "data"]
    },
    {
      "description": "失败-参数: 目的地/日期/天数/人数非法,不可重试(同入参)",
      "properties": {
        "status":  { "const": "failed" },
        "errCode": { "const": "ERR_INVALID_PARAMS" },
        "errMsg":  { "type": "string", "minLength": 1 },
        "suggestion": {
          "type": "string",
          "description": "例如:目前只支持北京、上海、广州、深圳，你想去哪一个？"
        }
      },
      "required": ["type", "status", "errCode", "errMsg", "suggestion"]
    },
    {
      "description": "失败-内部: 参数无法落盘或未知异常,可重试(建议节流)",
      "properties": {
        "status":  { "const": "failed" },
        "errCode": { "const": "ERR_INTERNAL" },
        "errMsg":  { "type": "string", "minLength": 1 },
        "suggestion": {
          "type": "string",
          "description": "例如:没能记下这次规划，请打开「有径」手动填写行程信息"
        }
      },
      "required": ["type", "status", "errCode", "errMsg", "suggestion"]
    }
  ]
}
```
