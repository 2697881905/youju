# 有据上线预告宣传视频（HyperFrames）实施计划

## Summary
基于「有据」上线预告海报系列 P1–P4（1080×1920 竖版）与既有品牌设计令牌，用 HyperFrames 将其转化为一段 **约 17 秒、竖版 1080×1920、9:16** 的品牌宣传视频。视频以 P1 主海报开场快速抓眼球，中间按价值观顺序展示 P2 理性 / P3 友善 / P4 共创并各配一句卖点标语字幕，结尾以品牌 Logo + 行动号召收尾。转场统一使用 ≤0.5s 的 Crossfade，字幕采用与海报一致的宋体衬线（Noto Serif SC）与纸白面板，全程色调严格锁定品牌令牌（纸白 #FAFAFA + 墨黑 #0D0F12 + 品牌蓝 #1677FF 仅点缀）。

## Current State Analysis
- **海报素材（已存在）**：`design/beta-posters/export/` 下 4 张 **1080×1920** PNG：`P1-预告主海报.png`、`P2-理性.png`、`P3-友善.png`、`P4-共创.png`。
  - P1 主海报：主标「真实经验，有据可循」+ 灰阶信息流卡片，底部卖点「把真话，讲给懂的人听」
  - P2 理性：主标「拒绝标题党，把经验讲清楚」+ 五体裁卡 + 方案A/B投票，卖点「少一点标题党，多一点真话」
  - P3 友善：主标「不喜欢就少推点，拉黑就别再见」+ 引号宣言，卖点「不喜欢就少推点，别吵架」
  - P4 共创：主标「把经验，装进口袋」+ 五条上架预约清单，卖点「好经验，值得被更多人看见」
  - 统一副文案：真实经验，有据可循 · 敬请期待；页脚 ©2026 有据 · 鸿蒙原生理性内容社区
- **品牌元素**：`design/beta-posters/有据logo.png`（品牌 Logo，实际用于海报页）、`设计令牌`（见 index.html :root，已锁定：纸白 `#FAFAFA`、卡片白 `#FFFFFF`、浅灰块 `#F2F2F5`、主文字 `#0D0F12`、次级 `#6E6E73`、三级 `#AEAEB2`、分隔线 `#E5E5EA`、品牌蓝 `#1677FF`；中文大标 Songti SC/Noto Serif SC serif 900；正文 PingFang SC/Noto Sans SC 300/400）。
- **环境**：上轮已完成 FFmpeg 9.0.1 安装；Node v23、Chrome、Docker 可用；此前在 `hyperframes-demo/` 已跑通「HTML→check→render MP4」全流程。`hyperframes` CLI（0.8.10）与技能均已就绪。
- **字体可嵌入性**：HyperFrames 编译器从 Google Fonts 嵌入字体。中文衬线用 **Noto Serif SC**（对应宋体大标）、无衬线用 **Noto Sans SC**（对应正文），均在 Google Fonts 托管、可嵌入；`Songti SC / PingFang SC` 为 macOS 系统字体不可嵌入，故字幕/叠加文案改用 Noto 系列以保持字形相近且可渲染。

## 方案设计（分镜 / 时间轴，总约 17s）
竖版 1080×1920。场景用海报 PNG 全出血作为背景（Ken Burns 轻微推近，增强呼吸感），下方叠加纸白半透明面板承载卖点字幕（高对比、衬线排版），与海报保持一致。转场统一 **Crossfade 0.45s**（≤0.5s 要求）。

| 片段 | 时间 | 画面 | 呈现字幕/标题 |
|---|---|---|---|
| S1 开场 | 0.0–2.3 | **P1 主海报** 全出血出现（scale 1.0→1.04 推近） | 顶部 eyebrow「有据 · 即将上线 · HARMONYOS NEXT」淡入；**不做底部面板**，保留海报冲击力 |
| S2 理性 | 2.3–6.3 | **P2 理性**（Ken Burns） | 纸白面板 + 宋体标语「少一点标题党，多一点真话」；面板内小标「价值观 01 · 理性」 |
| S3 友善 | 6.3–10.3 | **P3 友善**（Ken Burns） | 纸白面板 + 标语「不喜欢就少推点，别吵架」；小标「价值观 02 · 友善」 |
| S4 共创 | 10.3–14.3 | **P4 共创**（Ken Burns） | 纸白面板 + 标语「好经验，值得被更多人看见」；小标「价值观 03 · 共创」 |
| S5 结尾 | 14.3–17.0 | 纸白纯色底 → 品牌 Logo + 大标「真实经验，有据可循」+ CTA「敬请期待 · 欢迎点赞 / 收藏 / 转发」 | 结尾允许淡出至画面干净收尾 |

结果：4 张海报全部出镜（P1 开场 + P2/P3/P4 中段），符合「按逻辑顺序依次展示全部海报」；开场 ≤2.3s 用 P1 抓眼球；结尾引导转发。

## Proposed Changes
1. **新建工程**：运行 `npx hyperframes init hyperframes-promo --example blank --non-interactive`，生成于 `/Users/itxiaobai/HarmonyProject1/hyperframes-promo/`。
2. **注入素材**：将海报与 Logo 复制进工程 `assets/`：
   - `assets/P1.png` ← `design/beta-posters/export/P1-预告主海报.png`
   - `assets/P2.png` ← P2-理性.png；`assets/P3.png` ← P3-友善.png；`assets/P4.png` ← P4-共创.png
   - `assets/logo.png` ← `design/beta-posters/有据logo.png`
   - （PNG 走 `<img>` 或被 div 背景引用，均为本地静态资源，不触发网络请求）
3. **`design.md`（视觉身份门禁）**：逐条记录锁定的品牌令牌（上文色板/字体/蓝色仅点缀）、动效规则、禁止项（禁止渐变文字、禁止异地配色、蓝色仅 CTA/关键数字/锚点）。
4. **`index.html`（主合成）**：`data-width=1080 data-height=1920`，`data-duration≈17`。结构要点：
   - 每个海报片段为一个 `.scene clip`（`data-start`/`data-duration`/`data-track-index` 递增，`class="clip"`，后续片段初始 `opacity:0` + 提升 z-index 以支持 Crossfade）。
   - 海报用 `position:absolute; inset:0` 的外层裁剪容器 + 内层 `<img>` 做 `scale` 推近（只动画 wrapper/图片 scale 与 x/y，不碰视频）。图片 `crossorigin="anonymous"`。
   - 纸白面板 `.caption`：绝对定位底部（含安全边距），背景 `#FAFAFA` + 顶部分隔细线；宋体（Noto Serif SC 900）标语 + 小标（Noto Sans SC）。
   - GSAP `window.__timelines["main"]` 单一时间线；每场景元素用 `gsap.from` 入场；转场用 `tl.to(旧,{opacity:0})` + `tl.fromTo(新,{opacity:0},{opacity:1})` 于切换点（≈0.45s）。
   - 结尾片段允许淡出收尾（final scene exception）。
5. **`字幕文案.md`（交付物）**：`/Users/itxiaobai/HarmonyProject1/hyperframes-promo/字幕文案-分镜.md`，含分镜表（画面/时间/字幕/转场）与逐条字幕文案，供核对（呼应补充要求 #5）。
6. **校验与渲染**：
   - `cd hyperframes-promo && npm run check` → 修至 **0 error**（lint / 运行时 / 布局 / 动效 / 对比度）。
   - `npm run render -- --output youju-promo.mp4 --quality high`。
   - 必要时启动 `npx hyperframes preview --background` 供 Studio 交互预览。

## Assumptions & Decisions
- **竖版 9:16（1080×1920）**：海报封装面向抖音/朋友圈竖屏（README 明确），全片随海报竖版。
- **以 PNG 海报为背景 + HTML 叠加字幕** 而非用 HTML 重绘海报：保证与设计稿像素级一致，避免二次实现偏差。
- **静音版**：简报未提及配音/音乐；默认输出无音轨。如需 BGM 或旁白（TTS），可后续补充（已具备 hyperframes tts / media 能力）。
- **无网络依赖**：素材全部本地化；字体由编译器内嵌（Google Fonts 缓存）。
- **字幕与海报自身 CTA 文本一致**：海报 PNG 底部自带卖点文字，视频下方再用纸白面板呈现同一句标语以提升清晰可读性；开场(P1)与结尾不叠加底部面板，避免与海报冲击力或 CTA 冲突。

## Verification
1. `npm run check` 全部通过（尤其对比度对字幕面板内文字 WCAG AA）。
2. 渲染出的 `youju-promo.mp4`：竖版 1080×1920、约 17s、转场均 ≤0.5s、4 张海报全出镜、结尾含 Logo+CTAA。
3. 人工过片核对：P1→P2→P3→P4 顺序正确、字幕与切换同步、品牌色未漂移。
4. 交付：成片 MP4 + `字幕文案-分镜.md`（分镜说明 + 字幕文案）+ Studio 预览地址。