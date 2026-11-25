---
title: "experience-index.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_f3eb174e32bc158dba32e4b625cd5c877505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
last_updated: 2026-09-16T00:02:01
last_refined: 2026-09-15T23:53:25
active_count: 13
archived_count: 1
count_from_last_refined: 4
---

# Experience Index

## coding-pattern (total: 7)
- [HarmonyOS ArkUI Image 组件必须绑定 onError 和 alt 防止加载失败白屏](coding-pattern/2026-09-15-arkui-image-error-handling.md) | quality_score: 82 | tier: A | keywords: Image, onError, alt, placeholder, backgroundColor, resolveDisplayImageUrl, default_avatar, 加载失败, 白屏, 占位图, ArkUI | problem_patterns: image-load-failure-no-fallback, avatar-url-nonempty-but-broken | updated_at: 2026-09-15T23:54:39 | hit_count: 0 | low_quality_hit_count: 0
- [ArkUI 卡堆弹簧物理动画：springMotion 多层独立弹簧参数模式](coding-pattern/2026-09-15-arkui-spring-motion-card-deck.md) | quality_score: 83 | tier: A | keywords: springMotion, curves.springMotion, response, dampingFraction, card deck, 卡堆, 弹簧动画, 跟手拖拽, 回弹, DailyPostDeck, DECK_SPRING, DECK_ROT_SPRING | problem_patterns: unnatural-card-swipe, uniform-spring-stiffness, no-parallax-depth | updated_at: 2026-09-15T15:08:04 | hit_count: 1 | low_quality_hit_count: 0
- [ArkUI TransitionEffect 分层错峰入场动画模式](coding-pattern/2026-09-15-arkui-transition-effect-staggered-enter.md) | quality_score: 80 | tier: A | keywords: TransitionEffect, OPACITY, combine, translate, scale, animation, delay, stagger, 错峰入场, 分层进入, 转场动画, ArkUI transition | problem_patterns: flat-enter-animation, no-stagger, jarring-page-enter | updated_at: 2026-09-15T15:25:09 | hit_count: 0 | low_quality_hit_count: 0
- [ArkUI V1 编译器丢弃组件 plain getter 导致运行时崩溃](coding-pattern/2026-09-15-arkui-v1-plain-getter-dropped.md) | quality_score: 90 | tier: S | keywords: ArkUI V1, plain getter, get accessor, compiler drop, undefined, runtime crash, sharedId, @State, @Prop, component method | problem_patterns: silent-getter-removal, undefined-at-runtime, compiler-strips-unbound-getter | updated_at: 2026-09-15T15:19:54 | hit_count: 2 | low_quality_hit_count: 0
- [代码审查中系统性识别空 catch 块和 fire-and-forget async 调用的方法](coding-pattern/2026-09-15-empty-catch-block-audit.md) | quality_score: 72 | tier: A | keywords: catch, empty-catch, fire-and-forget, .catch(() => {}), hilog, try-catch, async-await, rejection, 未处理, 静默吞错, 日志记录 | problem_patterns: empty-catch-block-no-logging, fire-and-forget-async-without-catch | updated_at: 2026-09-15T23:54:39 | hit_count: 0 | low_quality_hit_count: 0
- [HarmonyOS 组件 aboutToDisappear 必须清理所有 setTimeout/setInterval 包括动画过渡类](coding-pattern/2026-09-15-harmonyos-component-timer-cleanup.md) | quality_score: 76 | tier: A | keywords: setTimeout, setInterval, aboutToDisappear, clearTimeout, clearInterval, 内存泄漏, timer, 动画, 过渡, navigateBack, dragOffsetX, flyPost, advancing | problem_patterns: animation-settimeout-not-cleaned, navigate-back-settimeout-not-cleaned | updated_at: 2026-09-15T23:54:39 | hit_count: 0 | low_quality_hit_count: 0
- [ArkUI sharedTransition 共享元素"一镜到底"转场实现模式](coding-pattern/2026-09-15-harmonyos-shared-transition-pattern.md) | quality_score: 88 | tier: S | keywords: sharedTransition, sharedTransitionOptions, MotionShared, hero占位, 一镜到底, PostDetailIntent, MotionShared, 共享元素转场, ArkUI动画, emphasized曲线, standard曲线, hero animation, shared element transition, holdHero, buildFadePageTransition | problem_patterns: 共享元素转场卡顿, 进入退出动画不流畅, 图片拉伸变形, disjoint-page-transition, no-visual-continuity, double-motion-conflict | updated_at: 2026-09-15T23:43:13 | hit_count: 1 | low_quality_hit_count: 0

## testing (total: 0)

## architecture (total: 2)
- [ArkUI 动画设计令牌系统：集中管理动画参数以保障全局一致性](architecture/2026-09-15-arkui-motion-design-token-system.md) | quality_score: 86 | tier: S | keywords: MotionTokens, MotionCurves, design token, animateTo, TransitionEffect, cubicBezierCurve, springMotion, ArkUI animation, 动画令牌, 动画一致性 | problem_patterns: animation-parameter-drift, inconsistent-motion-feel, hardcoded-duration | updated_at: 2026-09-15T15:25:09 | hit_count: 1 | low_quality_hit_count: 0
- [绕过统一网络请求封装的旁路调用会丢失全局错误处理和认证拦截](architecture/2026-09-15-unified-api-wrapper-bypass-risk.md) | quality_score: 80 | tier: A | keywords: request, uploadChatMedia, http.createHttp, 401, markAuthExpired, isNetworkConnectionError, ApiResult, bypass, 旁路, 绕过, 统一封装, 错误码解析 | problem_patterns: bypass-unified-wrapper-loss-of-global-protection, upload-function-direct-http-call | updated_at: 2026-09-15T23:54:39 | hit_count: 0 | low_quality_hit_count: 0

## build-env (total: 2)
- [ArkTS 严格模式编译约束与常见错误规避](build-env/2026-09-15-arkts-strict-mode-constraints.md) | quality_score: 72 | tier: A | keywords: arkts-no-standalone-this, arkts-no-implicit-return-types, arkts-no-any-unknown, ArkTS编译错误, hvigor, ArkTS严格模式 | problem_patterns: ArkTS编译失败, 类型推断错误, this上下文错误 | updated_at: 2026-09-15T16:03:04 | hit_count: 2 | low_quality_hit_count: 0
- [HarmonyOS module.json5 权限声明必须包含 reason 字段以通过 AGC 审核](build-env/2026-09-15-harmonyos-permission-reason-field.md) | quality_score: 84 | tier: A | keywords: requestPermissions, reason, usedScene, ohos.permission.INTERNET, module.json5, AGC审核, 权限说明, string.json, HarmonyOS权限配置 | problem_patterns: AGC审核被拒-权限缺少reason, 权限声明不完整 | updated_at: 2026-09-15T23:37:17 | hit_count: 0 | low_quality_hit_count: 0

## debugging (total: 0)

## workflow (total: 1)
- [HarmonyOS 应用 AGC 审核前配置文件完整性检查清单](workflow/2026-09-15-agc-review-config-checklist.md) | quality_score: 86 | tier: S | keywords: AGC, 审核配置, module.json5, app.json5, build-profile.json5, requestPermissions, reason字段, signingConfig, 隐私政策, 用户协议, AGC审核阻断, HarmonyOS上架 | problem_patterns: AGC审核被拒, 配置文件不完整, 权限声明缺失reason, 签名配置错误 | updated_at: 2026-09-15T23:43:13 | hit_count: 0 | low_quality_hit_count: 0

## agent-ops (total: 1)
- [Edit 工具操作大型 ArkTS 文件导致结构破坏的失败模式](agent-ops/2026-09-15-edit-tool-large-file-structure-corruption.md) | quality_score: 68 | tier: B | keywords: edit工具, 大文件编辑, 代码结构破坏, pageEnterTransition, build方法丢失, 编译错误链, edit验证 | problem_patterns: 编辑后构建失败, 代码块重复, 方法结构破坏 | updated_at: 2026-09-15T16:03:04 | hit_count: 0 | low_quality_hit_count: 0
