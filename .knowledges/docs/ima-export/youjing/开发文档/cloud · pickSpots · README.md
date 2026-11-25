---
title: "cloud · pickSpots · README.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_b7786da64573107e240eedef3d6660ef7526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# pickSpots 云函数（P1 AI 精选）

零依赖 AGC 云函数，供端侧 `PickClient` 在无自购服务器时调用。
只做候选池排序 + 每站一句理由；任何失败端侧都回退到确定性规则。

## AGC 部署

1. AGC 控制台 → 云函数 → 创建函数，函数名 `pickSpots`，运行时 Node 18/20，超时 8 秒。
2. 入口文件用本目录 `index.js`，入口函数填 `handler`；`prompt/` 是 `bff/scripts/sync-prompt-contract.mjs`
   从 entry/ SOT 同步来的生成物，一起上传，不要手改。
3. 触发器选 HTTP，把 URL 填进客户端 [PickConfig.ets](../../entry/src/main/ets/common/config/PickConfig.ets)
   的 `URL`/`TOKEN`；`TOKEN` 必须与函数环境变量 `YOUJING_PICK_TOKEN` 一致
   （未配置时回退 `YOUJING_REPLAN_TOKEN`）。两项留空时端侧走 BFF `/v1/pick/spots`，
   仍不可达则回退确定性规则。
4. 环境变量：
   - `YOUJING_PICK_TOKEN`：端侧 `x-youjing-token` 必须与它一致。
   - `LLM_CHAT_URL`：OpenAI 兼容的 `chat/completions` 地址。联调时 = `bff/.env` 的
     `LLM_BASE_URL` + `/chat/completions`。
   - `LLM_API_KEY`：只存在云函数环境变量；联调时 = `bff/.env` 的 `DEEPSEEK_API_KEY`。
   - `LLM_MODEL`：模型名，与 `bff/.env` 的 `LLM_MODEL` 同值。

## 本地测试

```bash
cd cloud/pickSpots
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --test
```

## 失败口径

401 token 不匹配；400 body 非 JSON；422 候选/决策不合法；500 函数没配 token；
502 上游超时/非 2xx/内容缺失。端侧对所有非 2xx 一视同仁：返回 null，
`SpotPickPage`/`StayPickPage` 保留现有确定性排序，界面不卡死。
