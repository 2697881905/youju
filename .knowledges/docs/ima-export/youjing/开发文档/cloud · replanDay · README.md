---
title: "cloud · replanDay · README.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_812e74b44ec266a9c3979d7e6cd7f2d47526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# replanDay 云函数

有径「不去下一站」的重排决策函数。契约见 `Docs/实况窗方案.md` §3.4。

## AGC 部署

1. AGC 控制台 → 云函数 → 创建函数，函数名 `replanDay`，运行时 Node 18/20，超时 8 秒
   （与端侧 `ApiConfig.REPLAN_READ_TIMEOUT_MS` 同为 8s；函数比端侧先超时会让这次调用白跑）。
2. 入口文件用本目录 `index.js`，入口函数填 `handler`（零依赖，不需要安装 node_modules）。
3. 触发器选 HTTP，记下 URL，填进客户端 `ApiConfig.REPLAN_URL`（该值不提交仓库）。
4. 环境变量：
   - `YOUJING_REPLAN_TOKEN`：客户端 `ApiConfig.REPLAN_TOKEN` 必须与它一致；未配置时函数返回 500。
   - `LLM_CHAT_URL`：OpenAI 兼容的 `chat/completions` 地址。联调时 = `bff/.env` 的
     `LLM_BASE_URL` + `/chat/completions`。
   - `LLM_API_KEY`：只存在云函数环境变量，绝不进客户端；联调时 = `bff/.env` 的 `DEEPSEEK_API_KEY`。
   - `LLM_MODEL`：模型名，与 `bff/.env` 的 `LLM_MODEL` 同值。
5. 用控制台测试事件复制 `test/replan.test.js` 里的 `bodyOf()`，请求头带 `x-youjing-token`。

## 本地测试

```bash
cd cloud/replanDay
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --test
```

零依赖；上游用注入的 `deps.fetch` 假实现，不发真实请求。

## 失败口径

- 401：token 不匹配；400：body 不是 JSON；422：请求或决策不合法；500：函数没配 token；502：上游超时/非 2xx/内容缺失。
- 客户端对所有非 2xx 一视同仁：返回 `null`，走本地兜底。
