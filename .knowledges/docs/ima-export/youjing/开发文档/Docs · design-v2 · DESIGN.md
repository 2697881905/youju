---
title: "Docs · design-v2 · DESIGN.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_16282c52f75739eb1c915562ba5cb7227526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
> **2026-11-07 全量对齐决议（覆盖声明）**
> 唯一事实源是 `/Users/itxiaobai/HarmonyProject1` 当前源码；本文件与 IMA 知识库、旧 spec 裁决冲突时一律以源码为准。
> 2026-11-07 用户裁决：此前 C5–C8 / spec §10 #24/25/26 的「有意偏离有据」结论全部推翻，不再保留。
> 材质点位不再封闭为「四处玻璃面」，以 `Docs/superpowers/specs/2026-11-07-表现层全量对齐-差异表.md` §6 登记的点位为准；卡片、输入框、弹窗、浮层允许自绘玻璃（`GlassPanel` / `GlowInput` / `SpringPanel` / `ImmersiveSurface` / `GlassPillButton`）。
> 状态表达允许 opacity：禁用 `.opacity(0.45)`、按下 `.opacity(0.92)` + `scale 0.97`（140ms）；不再禁止「opacity 表达状态」。
> 「官方件优先、禁自绘」禁令废止；但材质生效时自绘 border/shadow/backgroundBlurStyle 归零、内容区 systemMaterial 不渲染、API 版本门禁三条避让仍然有效。
> 交互态只做默认 / 按下 / 禁用（含聚焦 / 加载 / 空 / 错误），**不加 hover / hoverEffect**。
> 三处栏面 blur 50 + `scrolled ? 50 : 0` 绝对偏移门控、分段控件组件内 blur 20、sheet/菜单走 options.systemMaterial 的既有规则继续有效。
> 本文件里标注为「实测」「取证」「历史记录」「稿件缺陷」的行（尤其 `blur(24px)`、`scrollHeight=820`、`2.67:1`、`#00000000`、md5、帧哈希）逐字节不动；本决议只覆盖「规范性」表述。

---
version: alpha
name: youju-family-design-language
description: "The shared visual language of the 有据 product family on HarmonyOS NEXT. Two apps, one contract: 有据 (Substantiate) — a real-experience community where posts trace back to their sources; and 有径 (Youjing) — an AI travel-itinerary planner where a route traces from stop to stop. Pure white canvas, near-black ink, exactly one deep electric blue (#0066CC), Chinese serif for editorial titles over HarmonyOS Sans for everything operable, 4vp baseline grid, 3:4 media, system \"immersive light\" glass on the top bar and floating dock only. Signature visual is a traceable constellation: 有据 draws tags as planets on faint orbit rings (star map), 有径 draws itinerary stops on a thin blue route over hairline contours (route trace). Same geometry, same restraint, two palettes. Dark mode is a luminance ladder (#121212 → #1E1E1E → #28282C), never a shadow system."
colors:
  canvas: "#FFFFFF"
  surface-elevated: "#F7F7F8"
  surface-subtle: "#F2F2F4"
  surface-panel: "#EFEFF2"
  surface-sunken: "#E9E9EC"
  skeleton-base: "#E8E8EC"
  skeleton-highlight: "#F8F8FA"
  ink: "#17171A"
  body: "#5A5A60"
  muted: "#69696E"
  faint: "#9E9EA3"
  icon: "#3C3C43"
  on-dark: "#FFFFFF"
  dark-on-primary: "#121212"
  primary: "#0066CC"
  primary-press: "#0055BB"
  primary-tint: "rgba(0, 102, 204, 0.1)"
  on-primary: "#FFFFFF"
  accent-mention: "#5856D6"
  success: "#1C7440"
  warning: "#A06400"
  danger: "#C0392B"
  like: "#C0392B"
  bookmark: "#9A6206"
  hairline: "#E5E5EA"
  separator: "rgba(60, 60, 67, 0.2)"
  hairline-strong: "#E0E0E5"
  glass-bar-surface: "rgba(255, 255, 255, 0.44)"
  glass-bar-border: "rgba(196, 196, 202, 0.4)"
  glass-bar-shadow: "rgba(26, 26, 30, 0.18)"
  glass-bar-gradient-mask: "rgba(242, 242, 245, 0.4)"
  glass-selection-surface: "rgba(239, 239, 242, 0.6)"
  glass-selection-border: "rgba(196, 196, 202, 0.4)"
  glass-selection-shadow: "rgba(0, 102, 204, 0.18)"
  glass-segment-bg: "rgba(60, 60, 67, 0.1)"
  glass-segment-border: "rgba(60, 60, 67, 0.18)"
  glass-overlay: "rgba(23, 23, 26, 0.1)"
  modal-scrim: "rgba(23, 23, 26, 0.32)"
  glass-overlay-border: "rgba(23, 23, 26, 0.16)"
  dark-canvas: "#121212"
  dark-surface-elevated: "#1E1E1E"
  dark-surface-subtle: "#232326"
  dark-surface-panel: "#28282C"
  dark-surface-sunken: "#0D0D0F"
  dark-ink: "#F2F2F4"
  dark-body: "#A8A8AE"
  dark-muted: "#97979E"
  dark-faint: "#8A8A91"
  dark-icon: "#FFFFFF"
  dark-primary: "#0A84FF"
  dark-primary-press: "#3D9BFF"
  dark-primary-tint: "rgba(10, 132, 255, 0.2)"
  dark-accent-mention: "#7D7AFF"
  dark-success: "#30D158"
  dark-warning: "#FF9F0A"
  dark-danger: "#FF453A"
  dark-like: "#FF453A"
  dark-bookmark: "#FFD60A"
  dark-separator: "rgba(84, 84, 88, 0.3)"
  dark-hairline: "#3A3A3F"
  dark-skeleton-base: "#2A2A2F"
  dark-skeleton-highlight: "#35353B"
  dark-glass-bar-surface: "rgba(18, 18, 18, 0.35)"
  dark-glass-bar-border: "rgba(69, 69, 75, 0.32)"
  dark-glass-bar-shadow: "rgba(0, 0, 0, 0.55)"
  dark-glass-bar-gradient-mask: "rgba(42, 47, 54, 0.4)"
  dark-glass-selection-surface: "rgba(46, 46, 50, 0.2)"
  dark-glass-segment-bg: "rgba(255, 255, 255, 0.13)"
  dark-glass-segment-border: "rgba(255, 255, 255, 0.14)"
  dark-glass-overlay: "rgba(255, 255, 255, 0.13)"
  dark-glass-overlay-border: "rgba(255, 255, 255, 0.19)"
  route-paper-path: "#0066CC"
  route-paper-path-soft: "rgba(0, 102, 204, 0.35)"
  route-paper-node-fill: "#FFFFFF"
  route-paper-node-stroke: "#17171A"
  route-paper-contour: "rgba(26, 26, 26, 0.15)"
  route-paper-water: "#EAF2FA"
  route-paper-land: "#F7F7F8"
  route-paper-gold: "#A06400"
  route-paper-bg-top: "#FFFFFF"
  route-paper-bg-bottom: "#F1F2F5"
  route-night-path: "#7DB8FF"
  route-night-path-soft: "rgba(125, 184, 255, 0.3)"
  route-night-node-fill: "#16203A"
  route-night-node-stroke: "#ECE8DF"
  route-night-contour: "rgba(255, 255, 255, 0.12)"
  route-night-water: "#0B1424"
  route-night-land: "#16203A"
  route-night-gold: "#D9A441"
  route-night-bg-top: "#070B16"
  route-night-bg-bottom: "#0E1830"
  star-paper-ink: "#1A1A1A"
  star-paper-ring: "rgba(26, 26, 26, 0.3)"
  star-paper-icon: "#0066CC"
  star-paper-gold: "#A06400"
  star-paper-bg-top: "#FFFFFF"
  star-paper-bg-bottom: "#F1F2F5"
  star-night-ink: "#ECE8DF"
  star-night-ring: "rgba(255, 255, 255, 0.15)"
  star-night-icon: "#7DB8FF"
  star-night-gold: "#D9A441"
  star-night-badge: "#4D9FFF"
  star-night-bg-top: "#070B16"
  star-night-bg-bottom: "#0E1830"
typography:
  font-family: "'HarmonyOS Sans', ui-sans-serif, system-ui, sans-serif"
  serif-family: "'Noto Serif SC', 'Songti SC', serif"
  letterSpacing: "0"
  fontFeature: "tnum for every numeral: times, durations, distances, step counts"
  hierarchy:
    display:
      fontFamily: "serif"
      fontSize: "32px"
      fontWeight: 700
      lineHeight: "44px"
      letterSpacing: "0"
    display-sans:
      fontSize: "32px"
      fontWeight: 700
      lineHeight: "40px"
      letterSpacing: "0"
    title:
      fontFamily: "serif"
      fontSize: "21px"
      fontWeight: 700
      lineHeight: "32px"
      letterSpacing: "0"
    title-sans:
      fontSize: "21px"
      fontWeight: 650
      lineHeight: "28px"
      letterSpacing: "0"
    headline:
      fontSize: "18px"
      fontWeight: 600
      lineHeight: "24px"
      letterSpacing: "0"
    body:
      fontSize: "16px"
      fontWeight: 400
      lineHeight: "24px"
      letterSpacing: "0"
    body-serif:
      fontFamily: "serif"
      fontSize: "16px"
      fontWeight: 400
      lineHeight: "26px"
      letterSpacing: "0"
    callout:
      fontSize: "14px"
      fontWeight: 400
      lineHeight: "20px"
      letterSpacing: "0"
    caption:
      fontSize: "12px"
      fontWeight: 450
      lineHeight: "16px"
      letterSpacing: "0"
    overline:
      fontSize: "11px"
      fontWeight: 600
      lineHeight: "14px"
      letterSpacing: "0"
    nav-label:
      fontSize: "10px"
      fontWeight: 400
      lineHeight: "14px"
      letterSpacing: "0"
    button:
      fontSize: "14px"
      fontWeight: 600
      lineHeight: "20px"
      letterSpacing: "0"
    itinerary-time:
      fontSize: "12px"
      fontWeight: 600
      lineHeight: "16px"
      letterSpacing: "0"
      fontFeature: "tnum"
      note: "left gutter clock, e.g. 09:30"
    itinerary-duration:
      fontSize: "12px"
      fontWeight: 450
      lineHeight: "16px"
      letterSpacing: "0"
      fontFeature: "tnum"
      note: "dwell or transit, e.g. 停留 2小时 / 步行 18分钟"
    day-label:
      fontFamily: "serif"
      fontSize: "21px"
      fontWeight: 700
      lineHeight: "28px"
      letterSpacing: "0"
      note: "Day 3 · 6月12日 周四"
rounded:
  none: "0px"
  xs: "6px"
  sm: "10px"
  md: "14px"
  lg: "20px"
  xl: "28px"
  floating-bar: "30px"
  pill: "999px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  base: "16px"
  md: "20px"
  lg: "24px"
  xl: "32px"
  xxl: "48px"
layout:
  grid-baseline: "4px"
  page-padding: "16px"
  page-padding-wide: "20px"
  item-gap: "12px"
  block-gap: "16px"
  section-gap: "24px"
  grid-gutter: "12px"
  content-max-width: "720px"
  breakpoint-compact: "440px"
  breakpoint-expanded: "840px"
  min-touch-target: "44px"
  media-aspect-ratio: "3:4"
  title-bar-height: "60px"
  segmented-control-height: "36px"
  tab-bar-height: "64px"
  floating-dock-width: "300px"
  floating-dock-bottom-margin: "28px"
  floating-dock-side-margin: "16px"
  bottom-scroll-reserve: "94px"
  hairline-width: "0.5px"
  glass-blur: "50"
  glass-bar-scroll-gated: "true"
  glass-border-width: "1px"
  sheet-panel-width: "344px"
  sheet-panel-padding: "20px"
  itinerary-time-gutter: "52px"
  itinerary-spine-width: "2px"
  itinerary-node-size: "24px"
  itinerary-node-dot: "10px"
  itinerary-row-min-height: "76px"
  itinerary-block-gap: "12px"
  transit-leg-height: "44px"
  route-line-width: "2px"
  map-overlay-inset: "16px"
  map-height-compact: "200px"
  day-divider-height: "44px"
  question-option-gap: "8px"
  question-progress-dot: "6px"
  widget-2x2-padding: "12px"
  widget-2x4-padding: "16px"
  widget-min-text: "11px"
  feed_columns_phone: "2"
  post_card_padding: "16px"
  post_card_radius: "20px"
  compose_genre_card_height: "112px"
  compose_body_height: "124px"
  compose_field_height: "72px"
  profile_stat_width: "72px"
  tab_item_width: "58px"
  tab_item_height: "50px"
  tab_glow_size: "180px"
  tab_side_margin: "18px"
  tab_bottom_gap: "18px"
elevation:
  none: "0px 0px 0px 0px rgba(0,0,0,0)"
  cardContact: "0px 0px 1px 0px rgba(0,0,0,0.03)"
  cardAmbient: "0px 3px 10px 0px rgba(0,0,0,0.07)"
  floating: "0px 6px 16px 0px rgba(0,0,0,0.09)"
  pillFloat: "0px 3px 8px 0px rgba(0,0,0,0.15)"
  segmented: "0px 0px 8px 0px rgba(0,0,0,0.06)"
  popover: "0px 0px 8px 0px rgba(0,0,0,0.07)"
motion:
  press: "140ms"
  control: "220ms"
  container: "320ms"
  page-enter: "420ms"
  emphasis: "460ms"
  stagger: "40ms"
  shimmer: "1200ms"
  shared-element: "380ms"
  curve-standard: "cubic-bezier(0.2, 0.8, 0.2, 1)"
  curve-decelerate: "cubic-bezier(0, 0, 0.2, 1)"
  curve-emphasized: "cubic-bezier(0.16, 1, 0.3, 1)"
  curve-spring: "cubic-bezier(0.34, 1.56, 0.64, 1)"
  curve-spring-soft: "cubic-bezier(0.22, 1.22, 0.36, 1)"
  press-scale: "0.97"
  press-opacity: "0.92"
  segmented-press-scale: "0.94"
  path-draw: "460ms"
  reveal-offset: "8px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    darkBackgroundColor: "{colors.dark-primary}"
    darkTextColor: "{colors.dark-canvas}"
    typography: "{typography.hierarchy.button}"
    rounded: "{rounded.pill}"
    height: "44px"
    padding: "10px 24px"
  button-primary-pressed:
    backgroundColor: "{colors.primary-press}"
    textColor: "{colors.on-primary}"
    darkBackgroundColor: "{colors.dark-primary-press}"
    darkTextColor: "{colors.dark-canvas}"
    rounded: "{rounded.pill}"
    scale: "{motion.press-scale}"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.hierarchy.button}"
    rounded: "{rounded.pill}"
    border: "1px solid {colors.glass-bar-border}"
    height: "44px"
    padding: "10px 24px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    typography: "{typography.hierarchy.button}"
    rounded: "{rounded.pill}"
    border: "1px solid {colors.primary}"
    height: "44px"
  icon-button:
    backgroundColor: "transparent"
    iconColor: "{colors.icon}"
    rounded: "{rounded.lg}"
    size: "44px"
  card:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.body}"
    typography: "{typography.hierarchy.body}"
    rounded: "{rounded.lg}"
    padding: "16px"
    innerGap: "12px"
    elevation: "{elevation.cardAmbient}"
  top-bar-immersive:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    height: "{layout.title-bar-height}"
    brandTitleFont: "serif"
    bottomGradientMask: "{colors.glass-bar-gradient-mask}"
    material: "system immersive light (blur 50) + 0.5px hairline only when system material unavailable"
  segmented-control:
    backgroundColor: "{colors.glass-segment-bg}"
    textColor: "{colors.ink}"
    typography: "{typography.hierarchy.headline}"
    rounded: "{rounded.floating-bar}"
    height: "{layout.segmented-control-height}"
    border: "1px solid {colors.glass-segment-border}"
    blur: "20"
    selectedItemSurface: "{colors.glass-selection-surface}"
    selectedItemShadow: "{colors.glass-selection-shadow}"
  floating-dock:
    backgroundColor: "{colors.glass-bar-surface}"
    iconColor: "{colors.icon}"
    typography: "{typography.hierarchy.nav-label}"
    rounded: "{rounded.floating-bar}"
    width: "{layout.floating-dock-width}"
    height: "{layout.tab-bar-height}"
    bottomMargin: "{layout.floating-dock-bottom-margin}"
    border: "1px solid {colors.glass-bar-border}"
    elevation: "{colors.glass-bar-shadow}"
    blur: "{layout.glass-blur}"
    pressGlow: "{colors.primary-tint}"
  sheet-modal:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    width: "{layout.sheet-panel-width}"
    padding: "{layout.sheet-panel-padding}"
    innerGap: "{layout.block-gap}"
    elevation: "{elevation.floating}"
  separator:
    backgroundColor: "{colors.separator}"
    height: "{layout.hairline-width}"
  avatar:
    backgroundColor: "{colors.surface-subtle}"
    rounded: "{rounded.pill}"
    sizes: "24px, 40px, 56px"
  badge-dot:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.pill}"
    minSize: "16px"
  skeleton:
    backgroundColor: "{colors.skeleton-base}"
    highlightColor: "{colors.skeleton-highlight}"
    rounded: "{rounded.md}"
    shimmerDuration: "{motion.shimmer}"
  empty-state:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.muted}"
    typography: "{typography.hierarchy.callout}"
    iconColor: "{colors.muted}"
    titleTypography: "{typography.hierarchy.title}"
    titleFont: "serif"
  destination-picker:
    backgroundColor: "{colors.canvas}"
    titleFont: "serif"
    textColor: "{colors.ink}"
    typography: "{typography.hierarchy.display}"
    fieldSurface: "{colors.surface-elevated}"
    fieldRounded: "{rounded.lg}"
    fieldPadding: "16px"
    hairline: "{colors.hairline}"
  date-field:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.ink}"
    typography: "{typography.hierarchy.headline}"
    rounded: "{rounded.lg}"
    height: "64px"
    padding: "12px 16px"
    captionColor: "{colors.muted}"
    numeralFeature: "tnum"
  question-card:
    backgroundColor: "{colors.canvas}"
    questionColor: "{colors.ink}"
    typography: "{typography.hierarchy.title}"
    questionFont: "serif"
    helperColor: "{colors.muted}"
    rounded: "{rounded.none}"
    padding: "24px 16px"
    optionGap: "{layout.question-option-gap}"
  option-chip:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.ink}"
    typography: "{typography.hierarchy.body}"
    rounded: "{rounded.lg}"
    minHeight: "56px"
    padding: "12px 16px"
    border: "1px solid transparent"
    selectedBackgroundColor: "{colors.primary-tint}"
    selectedTextColor: "{colors.ink}"
    selectedDarkBackgroundColor: "{colors.dark-primary-tint}"
    selectedDarkTextColor: "{colors.dark-ink}"
    selectedBorder: "1px solid {colors.primary}"
    selectedDarkBorder: "1px solid {colors.dark-primary}"
    checkIconColor: "{colors.primary}"
  option-chip-pressed:
    scale: "{motion.press-scale}"
    duration: "{motion.press}"
  progress-dots:
    activeColor: "{colors.primary}"
    inactiveColor: "{colors.surface-sunken}"
    size: "{layout.question-progress-dot}"
    gap: "8px"
  ai-generating-panel:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.body}"
    stageLabelColor: "{colors.muted}"
    typography: "{typography.hierarchy.callout}"
    headlineTypography: "{typography.hierarchy.title}"
    headlineFont: "serif"
    skeletonBase: "{colors.skeleton-base}"
    skeletonHighlight: "{colors.skeleton-highlight}"
    progressStroke: "{colors.primary}"
    trackStroke: "{colors.surface-sunken}"
    rounded: "{rounded.lg}"
    padding: "24px 16px"
  day-header:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.hierarchy.day-label}"
    dateColor: "{colors.muted}"
    weatherColor: "{colors.body}"
    height: "{layout.day-divider-height}"
    stickySurface: "{colors.glass-bar-surface}"
    blur: "{layout.glass-blur}"
  itinerary-row:
    backgroundColor: "{colors.canvas}"
    timeColor: "{colors.ink}"
    timeTypography: "{typography.hierarchy.itinerary-time}"
    nameColor: "{colors.ink}"
    nameTypography: "{typography.hierarchy.headline}"
    metaColor: "{colors.muted}"
    metaTypography: "{typography.hierarchy.itinerary-duration}"
    minHeight: "{layout.itinerary-row-min-height}"
    timeGutter: "{layout.itinerary-time-gutter}"
    spineWidth: "{layout.itinerary-spine-width}"
    spineColor: "{colors.surface-sunken}"
    spineColorActive: "{colors.primary}"
    nodeSize: "{layout.itinerary-node-size}"
    nodeDot: "{layout.itinerary-node-dot}"
    gap: "{layout.itinerary-block-gap}"
    rounded: "{rounded.lg}"
    selectedSurface: "{colors.surface-elevated}"
  transit-leg:
    backgroundColor: "{colors.surface-subtle}"
    textColor: "{colors.muted}"
    iconColor: "{colors.icon}"
    typography: "{typography.hierarchy.itinerary-duration}"
    rounded: "{rounded.sm}"
    height: "{layout.transit-leg-height}"
    padding: "8px 12px"
    dashed-spine: "2px dashed {colors.separator}"
    numeralFeature: "tnum"
  activity-photo:
    rounded: "{rounded.xs}"
    aspectRatio: "3:4"
    placeholderFill: "{colors.surface-sunken}"
  booking-badge:
    requiredBackgroundColor: "{colors.warning}"
    requiredTextColor: "{colors.on-primary}"
    requiredDarkBackgroundColor: "{colors.dark-warning}"
    requiredDarkTextColor: "{colors.dark-canvas}"
    bookedBackgroundColor: "{colors.success}"
    bookedTextColor: "{colors.on-primary}"
    bookedDarkBackgroundColor: "{colors.dark-success}"
    bookedDarkTextColor: "{colors.dark-canvas}"
    freeBackgroundColor: "{colors.surface-subtle}"
    freeTextColor: "{colors.muted}"
    freeDarkBackgroundColor: "{colors.dark-surface-panel}"
    freeDarkTextColor: "{colors.dark-ink}"
    typography: "{typography.hierarchy.caption}"
    rounded: "{rounded.pill}"
    padding: "4px 10px"
  highlight-badge:
    backgroundColor: "{colors.bookmark}"
    textColor: "{colors.on-primary}"
    darkBackgroundColor: "{colors.dark-bookmark}"
    darkTextColor: "{colors.dark-canvas}"
    typography: "{typography.hierarchy.overline}"
    rounded: "{rounded.pill}"
    padding: "3px 8px"
  reason-block:
    backgroundColor: "{colors.surface-panel}"
    textColor: "{colors.body}"
    typography: "{typography.hierarchy.callout}"
    labelColor: "{colors.muted}"
    rounded: "{rounded.md}"
    padding: "12px"
    leftRule: "2px solid {colors.primary}"
  activity-type-dot:
    sight: "{colors.primary}"
    food: "{colors.bookmark}"
    stay: "{colors.accent-mention}"
    transit: "{colors.icon}"
    rest: "{colors.faint}"
    size: "8px"
  route-map-canvas:
    pathColor: "{colors.route-paper-path}"
    pathSoftColor: "{colors.route-paper-path-soft}"
    pathWidth: "{layout.route-line-width}"
    nodeFill: "{colors.route-paper-node-fill}"
    nodeStroke: "{colors.route-paper-node-stroke}"
    contourColor: "{colors.route-paper-contour}"
    waterColor: "{colors.route-paper-water}"
    landColor: "{colors.route-paper-land}"
    goldColor: "{colors.route-paper-gold}"
    labelColor: "{colors.ink}"
    labelTypography: "{typography.hierarchy.caption}"
    bgGradientTop: "{colors.route-paper-bg-top}"
    bgGradientBottom: "{colors.route-paper-bg-bottom}"
    darkPathColor: "{colors.route-night-path}"
    darkPathSoftColor: "{colors.route-night-path-soft}"
    darkNodeFill: "{colors.route-night-node-fill}"
    darkNodeStroke: "{colors.route-night-node-stroke}"
    darkContourColor: "{colors.route-night-contour}"
    darkWaterColor: "{colors.route-night-water}"
    darkLandColor: "{colors.route-night-land}"
    darkGoldColor: "{colors.route-night-gold}"
    darkBgGradientTop: "{colors.route-night-bg-top}"
    darkBgGradientBottom: "{colors.route-night-bg-bottom}"
    overlayInset: "{layout.map-overlay-inset}"
    compactHeight: "{layout.map-height-compact}"
    rounded: "{rounded.lg}"
    drawMotion: "{motion.path-draw} {motion.curve-emphasized}"
  itinerary-summary-card:
    backgroundColor: "{colors.surface-elevated}"
    titleColor: "{colors.ink}"
    titleFont: "serif"
    statColor: "{colors.ink}"
    statTypography: "{typography.hierarchy.headline}"
    statLabelColor: "{colors.muted}"
    rounded: "{rounded.lg}"
    padding: "16px"
    elevation: "{elevation.cardAmbient}"
    statGap: "12px"
    numeralFeature: "tnum"
  widget-card:
    backgroundColor: "{colors.surface-elevated}"
    darkBackgroundColor: "{colors.dark-surface-elevated}"
    textColor: "{colors.ink}"
    metaColor: "{colors.muted}"
    typography: "{typography.hierarchy.callout}"
    titleFont: "serif"
    rounded: "{rounded.lg}"
    padding2x2: "{layout.widget-2x2-padding}"
    padding2x4: "{layout.widget-2x4-padding}"
    minTextSize: "{layout.widget-min-text}"
    border: "1px solid {colors.hairline}"
    note: "launcher surface — solid fill only, never blur or translucency"
  calendar-sync-row:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    descColor: "{colors.muted}"
    typography: "{typography.hierarchy.body}"
    height: "64px"
    chevronColor: "{colors.faint}"
    switchOnColor: "{colors.primary}"
  card-media:
    backgroundColor: "{colors.surface-sunken}"
    rounded: "{rounded.xs}"
    aspectRatio: "3:4"
  feed-column:
    backgroundColor: "{colors.canvas}"
    padding: "16px"
    gap: "12px"
    columns: "2"
    gutter: "12px"
  tag-pill:
    backgroundColor: "{colors.primary-tint}"
    textColor: "{colors.primary}"
    typography: "{typography.hierarchy.caption}"
    rounded: "{rounded.pill}"
    padding: "4px 10px"
  mention-token:
    textColor: "{colors.accent-mention}"
    typography: "{typography.hierarchy.body}"
  stat-number:
    textColor: "{colors.ink}"
    typography: "{typography.hierarchy.headline}"
    fontFeature: "tnum"
  stat-label:
    textColor: "{colors.muted}"
    typography: "{typography.hierarchy.caption}"
  star-map-canvas:
    backgroundColor: "{colors.star-paper-bg-top}"
    inkColor: "{colors.star-paper-ink}"
    ringColor: "{colors.star-paper-ring}"
    accentColor: "{colors.star-paper-icon}"
    goldColor: "{colors.star-paper-gold}"
    darkBackgroundColor: "{colors.star-night-bg-top}"
    darkInkColor: "{colors.star-night-ink}"
    darkRingColor: "{colors.star-night-ring}"
    darkAccentColor: "{colors.star-night-icon}"
    darkGoldColor: "{colors.star-night-gold}"
transitions:
  page-enter: "opacity 220ms + translate{x:12px} 240ms"
  page-fade: "opacity 380ms, decelerate, delay 60ms"
  feed-stagger-step: "{motion.stagger}"
  long-take: "350ms, radius 16px -> 24px"
  snapshot-handover: "min 300ms, max 1500ms"
---

# Overview
This is the single design contract for the **有据 product family** on HarmonyOS NEXT. It exists so that two different products read as one brand and so that neither can silently drift: **every value in this file is shared** unless a section explicitly names a product.

The family has two members:

| Product | What it is | Its signature canvas |
| --- | --- | --- |
| **有据** (Substantiate) | A community for structured, evidence-backed experience reports — posts that trace back to a source | the **star map**: tags as planets on hairline orbit rings |
| **有径** (Youjing) | An AI-driven itinerary planner — pick a city and dates, answer option-based questions, get a day-by-day route you can walk | the **route trace**: numbered stops on a thin blue path over contours |

The names are the thesis: 有**据** = "there is evidence", 有**径** = "there is a path". Both promise *traceability*, and both express it the same way — a quiet white page, one blue, hairline structure, and content that shows where it came from. That shared promise is why the visual language is one document, not two style guides.

Rule of precedence: a product layer may **add** components, palettes and geometry, but it may never re-tune a family token. If a value is missing, derive it from what is here; do not invent.

The product idea that must be visible in the UI: **AI is the analysis engine, not the data source.** Points of interest and lodging areas are curated, first-party data; the AI only filters, orders, routes, and explains. So the interface must never look like a chat bot improvising. Every recommendation carries its reason, its duration, and its booking state as legible data. The look is "a well-edited itinerary page", not "an AI output".

Three family signatures, in priority order (the first two are shared, the third is the pair of product canvases):

1. **The route trace.** A thin blue path threading numbered stop-nodes over a map surface — faint contour lines on paper (light) or glowing on ink-dark terrain (dark). It is 有径's equivalent of 有据's star map: same restraint, same "structure you can read at a glance", same two-palette discipline (identical geometry, swapped palette).
2. **The itinerary spine.** A single 2px vertical line down the left of the day, with 10px node dots at each stop, a 52px tabular-figure time gutter, and short dashed segments where you're in transit. The whole product is one line you read top to bottom.
3. **The option-based interview.** Preferences are never typed. Each question is a serif title, a grey helper line, and a stack of large selectable cards with a check mark. It should feel like a well-set questionnaire, not a chat window: no speech bubbles, no typing indicator, no avatar-for-AI.

Feeling: calm authority, legible at a glance, and honest about what the AI decided. White floor, one blue, generous whitespace, hairlines used sparingly.

## 0. Color-format law (read this before touching any color)

**Every 8-digit-looking color in this file has been rewritten as `rgba(r, g, b, a)` on purpose.**
The source app is HarmonyOS, whose color strings are `#AARRGGBB` — **alpha first**. CSS, Tailwind and
Stitch read an 8-digit hex as `#RRGGBBAA` — **alpha last**. The same literal therefore means two
different colors, and that single mismatch has already produced real defects in generated frames:

- `1A 00 66 CC` (written as spaced bytes so it cannot be pasted) is ArkTS for *blue at 10%* (a pale selection tint). Read as CSS it becomes **`rgb(26, 0, 102)` at 80% — a solid indigo block**, which is where the off-brand violet option cards came from.
- `99 EF EF F2` is ArkTS for *`#EFEFF2` at 60%*. Read as CSS it becomes **cyan `rgb(153, 239, 255)`**, which is where the turquoise selected segment came from.

Rules:
- Never write, copy or invent an 8-digit hex in a mock, a prompt or a stylesheet. Use `rgba()`, or the 6-digit opaque token.
- Where a translucent surface must be flattened (export, poster, launcher widget), blend it against its own background and use the resulting 6-digit hex — do not drop the alpha byte.
- ArkUI code keeps the alpha-first form. The right-hand column of the ledger writes those four bytes **separated by spaces on purpose** (`1A 00 66 CC`) so nothing in this document is a copy-pasteable 8-digit hex; when you go back to `color.json`, concatenate the bytes and prefix `#` in that same order — alpha first.

### 0.1 Palette closure — this file is the only color source

- Emit colors **literally at the point of use**: a 6-digit contract hex, or an `rgba()`. Do not generate a `tailwind.config` block, a `:root` custom-property palette, or any semantic token layer of your own. A frame that carries an injected palette has been generated under some *other* design system, and every color in it is untrustworthy.
- These token names do not exist in this contract and must never appear: `surface-container-low` / `-high` / `-highest`, `surface-variant`, `surface-tint`, `surface-dim`, `surface-bright`, `on-surface`, `on-surface-variant`, `on-primary-container`, `outline`, `outline-variant`, `primary-container`, `secondary-container`, `tertiary-container`, `error-container`, `inverse-primary`, `*-fixed`, `*-fixed-dim`. They belong to Material 3. When a frame is generated under a Material-derived system, `primary` silently resolves to a navy that is not `{colors.primary}` and every heading falls back to a Latin grotesque.
- Text colors are a closed set of five: `#17171A` `#5A5A60` `#69696E` `#9E9EA3` `#3C3C43`. The action hue is a single blue — `#0066CC`, pressed `#0055BB`, dark mode `#0A84FF`, dark pressed `#3D9BFF`. Semantic and activity hues are closed and enumerated in §3: `#9A6206` 必去/招牌 · `#A06400` 需预约/警告 · `#1C7440` 已确认 · `#C0392B` 冲突/危险 · `#5856D6` 住宿 (`accent-mention`, dark `#7D7AFF`). Auxiliary surfaces outside the six-step ladder are also closed and named: `#E8E8EC` skeleton base, `#F1F2F5` canvas-gradient foot, `#121212` dark-mode ink. **A hue is a defect only if it appears in none of the tables in this file** — check §1, §3 and the Translucency ledger before calling one.
- Fonts are a closed set of two families: `Noto Serif SC` (400 and 700 only; place, day and question titles) and `HarmonyOS Sans` (everything operable, every stop name, every numeral). No Plus Jakarta Sans, no Inter, no Roboto, no `system-ui`.
- Geometry is closed too. Radii are exactly the eight `rounded` tokens above — `0 / 6 / 10 / 14 / 20 / 28 / 30 / 999` — where `xs 6` is media and nested-in-card, `sm 10` is chips and inputs, `md 14` is reason blocks, `lg 20` is cards and sheets, `xl 28` is hero panels, `floating-bar 30` is the dock and segmented control, `pill 999` is every button, badge and avatar. Type sizes are exactly `10 / 11 / 12 / 14 / 16 / 18 / 21 / 32`. Do not tighten this ladder and do not widen it.

### Translucency ledger — CSS spelling ↔ ArkTS spelling

| Token | CSS / Stitch — use this | ArkTS `color.json` — alpha FIRST (byte pairs, not a CSS literal) |
| --- | --- | --- |
| `dark-glass-bar-border` | `rgba(69, 69, 75, 0.32)` | `52 45 45 4B` |
| `dark-glass-bar-gradient-mask` | `rgba(42, 47, 54, 0.4)` | `66 2A 2F 36` |
| `dark-glass-bar-shadow` | `rgba(0, 0, 0, 0.55)` | `8C 00 00 00` |
| `dark-glass-bar-surface` | `rgba(18, 18, 18, 0.35)` | `59 12 12 12` |
| `dark-glass-overlay` | `rgba(255, 255, 255, 0.13)` | `20 FF FF FF` |
| `dark-glass-overlay-border` | `rgba(255, 255, 255, 0.19)` | `30 FF FF FF` |
| `dark-glass-segment-bg` | `rgba(255, 255, 255, 0.13)` | `20 FF FF FF` |
| `dark-glass-segment-border` | `rgba(255, 255, 255, 0.14)` | `24 FF FF FF` |
| `dark-glass-selection-surface` | `rgba(46, 46, 50, 0.2)` | `33 2E 2E 32` |
| `dark-primary-tint` | `rgba(10, 132, 255, 0.2)` | `33 0A 84 FF` |
| `dark-separator` | `rgba(84, 84, 88, 0.3)` | `4D 54 54 58` |
| `glass-bar-border` | `rgba(196, 196, 202, 0.4)` | `66 C4 C4 CA` |
| `glass-bar-gradient-mask` | `rgba(242, 242, 245, 0.4)` | `66 F2 F2 F5` |
| `glass-bar-shadow` | `rgba(26, 26, 30, 0.18)` | `2E 1A 1A 1E` |
| `glass-bar-surface` | `rgba(255, 255, 255, 0.44)` | `70 FF FF FF` |
| `glass-overlay` | `rgba(23, 23, 26, 0.1)` | `1A 17 17 1A` |
| `modal-scrim` | `rgba(23, 23, 26, 0.32)` | `52 17 17 1A` |
| `glass-overlay-border` | `rgba(23, 23, 26, 0.16)` | `29 17 17 1A` |
| `glass-segment-bg` | `rgba(60, 60, 67, 0.1)` | `1A 3C 3C 43` |
| `glass-segment-border` | `rgba(60, 60, 67, 0.18)` | `2E 3C 3C 43` |
| `glass-selection-border` | `rgba(196, 196, 202, 0.4)` | `66 C4 C4 CA` |
| `glass-selection-shadow` | `rgba(0, 102, 204, 0.18)` | `2E 00 66 CC` |
| `glass-selection-surface` | `rgba(239, 239, 242, 0.6)` | `99 EF EF F2` |
| `primary-tint` | `rgba(0, 102, 204, 0.1)` | `1A 00 66 CC` |
| `route-night-contour` | `rgba(255, 255, 255, 0.12)` | `1F FF FF FF` |
| `route-night-path-soft` | `rgba(125, 184, 255, 0.3)` | `4D 7D B8 FF` |
| `route-paper-contour` | `rgba(26, 26, 26, 0.15)` | `26 1A 1A 1A` |
| `route-paper-path-soft` | `rgba(0, 102, 204, 0.35)` | `59 00 66 CC` |
| `separator` | `rgba(60, 60, 67, 0.2)` | `33 3C 3C 43` |
| `star-night-ring` | `rgba(255, 255, 255, 0.15)` | `26 FF FF FF` |
| `star-paper-ring` | `rgba(26, 26, 26, 0.3)` | `4D 1A 1A 1A` |
| `brand-solid` | `rgba(0, 102, 204, 1)` | `FF 00 66 CC` |
| `dark-brand-solid` | `rgba(0, 80, 160, 1)` | `FF 00 50 A0` |
| `on-brand` | `rgba(255, 255, 255, 1)` | `FF FF FF FF` |
| `dark-on-brand` | `rgba(255, 255, 255, 1)` | `FF FF FF FF` |
| `danger-tint` | `rgba(255, 59, 48, 0.1)` | `1A FF 3B 30` |
| `dark-danger-tint` | `rgba(255, 59, 48, 0.1)` | `1A FF 3B 30` |
| `glass-card-bg` | `rgba(247, 247, 248, 1)` | `FF F7 F7 F8` |
| `dark-glass-card-bg` | `rgba(30, 30, 30, 1)` | `FF 1E 1E 1E` |

# Colors

Two things are non-negotiable about color, and they are the whole reason the family looks like one product: **the canvas is a single flat neutral** (never tinted, never gradient) and **there is exactly one action hue**. Everything else is a surface step, a text weight, or a semantic accent that appears only as a small badge or a dot.

Every value below is paired light / dark. Light is the reference polarity; dark is a *luminance ladder* — surfaces get lighter as they rise, and shadows are dropped rather than strengthened.

## 1. Surfaces (the ladder)

| Role | Token | Light | Dark | Where it is used |
| --- | --- | --- | --- | --- |
| Page floor | `colors.canvas` | `#FFFFFF` | `#121212` | Behind everything. Never a card, never a panel. |
| Raised surface | `colors.surface-elevated` | `#F7F7F8` | `#1E1E1E` | Cards, option chips, sheets, input fields, widgets. |
| Secondary surface | `colors.surface-subtle` | `#F2F2F4` | `#232326` | Transit legs, neutral badges, inactive controls. |
| Deliberate panel | `colors.surface-panel` | `#EFEFF2` | `#28282C` | The "why this stop" reason block. One step above a card, far below `sunken` — reads as "a panel", not "a hole". |
| Well / placeholder | `colors.surface-sunken` | `#E9E9EC` | `#0D0D0F` | Photo placeholders, progress track, inactive dots. |
| Skeleton base | `colors.skeleton-base` | `#E8E8EC` | `#2A2A2F` | Loading blocks; highlight sweep `#35353B`. |

Note the direction flip: in light mode the steps go **down** from white (subtraction = depth); in dark mode they go **up** from `#121212` (addition = depth). `dark-surface-sunken` (`#0D0D0F`) is the only dark surface *darker* than the canvas, and it is reserved for image wells — never for content.

## 2. Text and icons

| Role | Token | Light | Dark | Usage | Measured on its usual background |
| --- | --- | --- | --- | --- | --- |
| Primary | `colors.ink` | `#17171A` | `#F2F2F4` | Titles, stop names, times, selected option labels | 17.89:1 AAA (ink on canvas) |
| Secondary | `colors.body` | `#5A5A60` | `#A8A8AE` | AI reasoning prose, descriptions | 6.85:1 AA (body on canvas) |
| Tertiary | `colors.muted` | `#69696E` | `#97979E` | Durations, area names, helper lines | 5.46:1 AA (muted on canvas) |
| Quaternary | `colors.faint` | `#9E9EA3` | `#8A8A91` | Placeholders, disabled text, chevrons only | 2.67:1 FAIL — **below AA: decorative/disabled only, never meaningful text** |
| Icon stroke | `colors.icon` | `#3C3C43` | `#FFFFFF` | All line icons | 10.94:1 AAA (icon on canvas) |
| On accent fill | `colors.on-primary` | `#FFFFFF` | **`#121212`** | Labels sitting on a solid color | **§4 极性规则覆盖本行**：深色亮底配画布墨字，白字压亮底只有 2.0–3.4:1，直接不过 AA。2026-10-21 定稿时修正（原值 `#FFFFFF` 与 §4 矛盾） |

Icons are deliberately **not** `body`: light icons are `#3C3C43` (one step darker than `#5A5A60` text) so thin strokes stay crisp, and dark icons are pure white while dark body text stays grey. Mixing them is the fastest way to make a sibling app look unrelated.

## 3. Accents — one action hue, five closed semantics

| Role | Token | Light | Dark | Meaning here |
| --- | --- | --- | --- | --- |
| Action / route | `colors.primary` | `#0066CC` | `#0A84FF` | Tappable, selected, authoritative — and the only route-line color. 5.57:1 AA on canvas. |
| Pressed | `colors.primary-press` | `#0055BB` | `#3D9BFF` | Button fill under finger. |
| Wash | `colors.primary-tint` | `1A 00 66 CC` | `33 0A 84 FF` | = `#0066CC` at 10.2% alpha over the surface. Selected option chips, pressed glow, brand highlight. |
| Stay / lodging | `colors.accent-mention` | `#5856D6` | `#7D7AFF` | Inherited indigo, reused here for lodging. 5.65:1 AA on canvas — distinct from topic-blue by hue (243° vs 210°), not by saturation. |
| Confirmed | `colors.success` | `#1C7440` | `#30D158` | 已确认 / 已预约. |
| Needs action | `colors.warning` | `#A06400` | `#FF9F0A` | 需预约 / 需证件 / 建议提前购票. |
| Conflict | `colors.danger` | `#C0392B` | `#FF453A` | 闭馆日 / 时间冲突 / 删除. |
| Signature pick | `colors.bookmark` | `#9A6206` | `#FFD60A` | 必去 / 招牌. |
| Hairline | `colors.hairline` | `#E5E5EA` | `#3A3A3F` | Card dividers (rare), widget border. |
| Separator | `colors.separator` | `33 3C 3C 43` | `4D 54 54 58` | = `#3C3C43` at 20% — list-row rules only. |

**The activity-type allocation is closed**, and these consume existing hues only:

| Activity type | Color | Token |
| --- | --- | --- |
| 景点 sight | blue | `{colors.primary}` |
| 餐饮 food | ochre | `{colors.bookmark}` |
| 住宿 stay | indigo | `{colors.accent-mention}` |
| 交通 transit | graphite | `{colors.icon}` |
| 休整 rest | grey | `{colors.faint}` |

A sixth type is expressed by an icon or a word, never a new hue. Travel apps drift into candy-color chaos faster than any other genre; the family's credibility rests on there being one blue and four muted semantics.

## 4. Text-on-fill polarity (this is where dark mode usually breaks)

Light-mode accents are deep earth tones that hold white labels. Dark-mode accents are the system-bright set, and white on them fails accessibility outright — measured:

| Badge / button | Light fill + white | Dark fill + white | Dark fill + canvas ink `#121212` |
| --- | --- | --- | --- |
| 需预约 | 4.86:1 AA | 2.06:1 FAIL | 9.11:1 AAA |
| 已确认 | 5.80:1 AA | 2.02:1 FAIL | 9.27:1 AAA |
| 必去 | 5.09:1 AA | 1.41:1 FAIL | 13.27:1 AAA |
| 冲突/危险 | 5.44:1 AA | 3.41:1 AA-large | 5.50:1 AA |
| 实心主按钮 | 5.57:1 AA | 3.65:1 AA-large | 5.14:1 AA |
| 主按钮按下态 | 6.96:1 AA | 2.86:1 FAIL | 6.54:1 AA |

**Rule: in dark mode, bright fills take dark ink, not white.** Text on a bright surface is `#121212`, never `#000000` (black-on-neon looks soiled) and never `#FFFFFF`. This still governs the accent badges above. The solid primary button now follows the `brand-solid` / `on-brand` recipe instead: its label is `callout 14 / 600` white text, and on the deep brand fill it clears AA comfortably — dark `brandSolid #0050A0` with white measures 7.91:1, light `brandSolid #0066CC` with white measures ≥4.5:1 — so no AA-large exception is needed.

In light mode the polarity is the opposite: white labels on `#0066CC`, `#A06400`, `#1C7440`, `#C0392B`, `#9A6206` — all 4.86:1 to 5.80:1.

## 5. Material / glass tokens — bar-surface tokens (material points registered in 差异表 §6)

These exist so the top bar, the dock, the sticky day header, and sheets read as one physical material. Their alpha is tuned against a *specific* background, which is why they must not be repurposed.

| Token | Light | Dark | Notes |
| --- | --- | --- | --- |
| `glass-bar-surface` | `70 FF FF FF` | `59 12 12 12` | white @ 43.9% / canvas @ 34.9% |
| `glass-bar-border` | `66 C4 C4 CA` | `52 45 45 4B` | neutral grey @ 40% / warm grey @ 32.2% |
| `glass-bar-shadow` | `2E 1A 1A 1E` | `8C 00 00 00` | 18% / 55% black |
| `glass-bar-gradient-mask` | `66 F2 F2 F5` | `66 2A 2F 36` | 40% fade behind the bar |
| `glass-selection-surface` | `99 EF EF F2` | `33 2E 2E 32` | the segmented/dock selected pill |
| `glass-selection-shadow` | `2E 00 66 CC` | `5C 0A 84 FF` | = `#0066CC` @ 18% — selection is tinted, not grey |
| `glass-segment-bg` | `1A 3C 3C 43` | `20 FF FF FF` | **why it changes polarity:** white glass on a white canvas is mathematically invisible, so light mode falls back to smoked graphite (`#3C3C43` @ 10%) while dark keeps the white sheen (`#FFFFFF` @ 12.5%). Re-derive both if the canvas stops being white. |
| `glass-overlay` | `1A 17 17 1A` | `20 FF FF FF` | floating popovers: `#17171A` @ 10% / `#FFFFFF` @ 12.5% |
| `glass-overlay-border` | `29 17 17 1A` | `30 FF FF FF` | the same hue at 16% / 19% |
| blur | 50 | 50 | the three bar surfaces share this one radius; the segmented control is the single written exception at 20 (its own in-component value, not a fifth glass surface) |

## 6. Route-map palette (closed, canvas-only)

The signature visual. Same geometry in both themes, only the palette swaps — this mirrors 有据's star map exactly.

| Element | Light ("map drawn on paper") | Dark ("ink night terrain") |
| --- | --- | --- |
| Canvas gradient | `#FFFFFF` → `#F1F2F5` | `#070B16` → `#0E1830` |
| Land | `#F7F7F8` | `#16203A` |
| Water | `#EAF2FA` | `#0B1424` |
| Contour hairlines | `#1A1A1A` @ 15% | `#FFFFFF` @ 12% |
| Route line (2px) | `#0066CC` | `#7DB8FF` |
| Route halo (wide, under the line) | `#0066CC` @ 35% | `#7DB8FF` @ 30% |
| Node fill / ring | `#FFFFFF` / `#17171A` | `#16203A` / `#ECE8DF` |
| 必去 highlight ring | `#A06400` | `#D9A441` |
| Label text | `#17171A` | `#F2F2F4` |

Measured line-on-terrain contrast: `5.20:1 AA` (light path on paper land), `7.81:1 AAA` (dark path on night land) — both clear the 3:1 graphics floor. Contours and water stay *below* 3:1 on purpose: they are texture, not information.

## 7. Star-map palette (有据's signature canvas — closed, canvas-only)

The sibling product's canvas uses the identical rule set as the route trace above: one structure, two palettes, geometry unchanged.

| Element | Light ("star chart on paper") | Dark ("ink night sky") |
| --- | --- | --- |
| Canvas gradient | `#FFFFFF` → `#F1F2F5` | `#070B16` → `#0E1830` |
| Orbit rings | `#1A1A1A` @ 15% | `#FFFFFF` @ 15% |
| Star name text | `#1A1A1A` | `#ECE8DF` |
| Glow core / halo | `#0066CC` @ 16% / @ 25% | `#4D9FFF` @ 18% / `#7DB8FF` @ 24% |
| Background dust (40 dots) | `#1A1A1A` | `#C8D4E8` |
| Planet disc / stroke | `#FFFFFF` / `#E0E0E5` | `#1A2233` / `#FFFFFF` @ 20% |
| Member ring / featured | `#A06400` gold | `#D9A441` gold |
| Icon, ripple, selection | `#0066CC` | `#7DB8FF` |
| New seed / daily seed | `#0066CC` / `#A06400` | `#7DB8FF` / `#FFD27D` |
| Unread badge | `#0066CC` | `#4D9FFF` |

Both canvases keep the same floors: labels ride the ink color, decorative dust and rings sit below 3:1 on purpose, and any information-bearing stroke clears 3:1. The gold is the *same* gold in both products — 必去 in 有径 and 每日一帖 in 有据 read as one idea.

## 8. Contrast floors

- Body copy and labels: **≥ 4.5:1**. Large text (≥ 24px regular / ≥ 18.66px bold): ≥ 3:1. Icons, dots, route lines and other meaningful graphics: ≥ 3:1 against their background.
- `faint` is the only sub-AA token and fails even the 3:1 graphic floor in light mode, so it is restricted to disabled and placeholder text. **A chevron that means "this row opens" is a control affordance and takes `muted` `#69696E`** (5.46:1) — using `faint` for chevrons is a 有据-era habit that this family now corrects. If a string or glyph carries information or affordance, it is at least `muted`.

**Colored microcopy has its own background rule.** A 11–12px `warning` `#A06400` advisory reads 4.86:1 on canvas and 4.54:1 on `elevated`, but only **4.24:1 on `panel` `#EFEFF2`** — under AA at that size. So colored advisory text sits on canvas or elevated; on a panel it becomes `ink` text with the color carried by the 2px left rule, a dot, or an icon. A `bookmark` `#9A6206` label (4.76:1 on elevated) is fine; the same hue inverted — white on `#9A6206` — is the badge recipe (5.09:1).
- Never use pure `#000000` for text and never pure `#FFFFFF` for cards in light mode: the contract is `#17171A` on `#F7F7F8` (16.71:1 AAA).
- Tints are alpha over an *opaque* surface, never an alpha value sitting directly on the page floor — a 10% wash over white and over `#F7F7F8` are different colors, and the ladder must survive the overlap.


## 9. Tinted selection surfaces — the one inherited defect to avoid

`primary-tint` is `#0066CC` at 10% over the card, which composites to about `#DEE8F4`. Blue label text on it measures **4.49:1 — just under the 4.5:1 AA floor** (dark mode is worse: `#0A84FF` at 20% over `#1E1E1E` composites to `#1A324B`, and blue on it is **3.59:1**). 有据's tag pills ship with exactly this blue-on-blue-tint combination; do not copy it.

The correct selected-state recipe, measured:

| Layer | Light | Dark | Ratio |
| --- | --- | --- | --- |
| Fill | `primary-tint` (≈ `#DEE8F4`) | `dark-primary-tint` (≈ `#1A324B`) | — |
| **Label text** | `ink` `#17171A` | `dark-ink` `#F2F2F4` | 14.44 / 11.73 |
| 1px selection border | `primary` `#0066CC` | `dark-primary` `#0A84FF` | 4.49 / 3.59 — passes the 3:1 *graphic* floor, which is what a stroke needs |
| Check icon | `primary` | `dark-primary` | graphic, ≥ 3:1 ✓ |

So: **a tint fill carries an ink label plus a blue stroke, never a blue label.** Blue-as-text is only allowed on the flat canvas or on an opaque `elevated`/`subtle` surface (5.57 / 5.20:1). If a screen genuinely needs a blue label on a selected row, darken the label to `primary-press` `#0055BB` (5.62:1) rather than lightening the tint.
# Typography

Type is the product's credibility device. 有径 has no photography budget, no illustration system, and must not look like a chatbot's output — so the entire "an editor made this, not a model" feeling is carried by two families used in strictly separated roles.

## 1. Family inventory (what actually ships)

| Family | Real name to register | Source | Weights available | Role |
| --- | --- | --- | --- | --- |
| Sans | `HarmonyOS Sans` | system, always present | 400 / 450 / 500 / 600 / 650 / 700 (variable) | every operable or scannable string |
| Serif — titles | `Noto Serif SC` | bundled `NotoSerifSC-Bold.otf` (~12 MB) | **700 only** | destination names, day labels, questions, hero/section titles |
| Serif — body | `Noto Serif SC Body` | bundled `NotoSerifSC-Regular.otf` (~11 MB) | **400 only** | long-form reading text (route notes, tips, 为什么这样排) |

Three consequences that must survive into the build, and that a designer needs to know before drawing anything:

1. **The serif has exactly two weights.** The engine registers one font file per family name, so `Bold` and `Regular` are two *different families*, not two weights of one. Asking the serif for 500/600 does not give you a medium — it gives you synthetic (fake) bolding or the request is ignored. Any serif string in a mock must be either 400 (Body family) or 700 (Title family).
2. **To get real serif bold, switch family**, not weight: `Noto Serif SC Body` → `Noto Serif SC`. Mocks that show "serif medium 500" cannot be implemented and will be rejected at handoff.
3. **The serif is bundled, not requested from the system**, precisely so the editorial look holds on devices without a CJK serif installed. Registration happens once at launch, before first paint; there is also a canvas `Typeface` built from the same two files so generated share-images and the map labels match the UI.

Fallback stacks: serif → `'Noto Serif SC', 'Songti SC', serif`; sans → `'HarmonyOS Sans', ui-sans-serif, system-ui, sans-serif`. Never set a Latin-only face (no DIN, no Inter, no Roboto) — Chinese and Latin must render in the same run and the same family.

## 2. Scale

Letter-spacing is **0 everywhere**, at every size. Negative tracking clips CJK glyphs and breaks line-break opportunities; the display sizes get their tightness from the serif's own metrics, not from tracking.

| Token | Family | Size | Weight | Leading | Where |
| --- | --- | --- | --- | --- | --- |
| `display` | serif | 32 | 700 | 44 | Destination hero name, empty-state headline |
| `display-sans` | sans | 32 | 700 | 40 | Only if a numeral or Latin string must lead (rare) |
| `title` | serif | 21 | 700 | 32 | Interview question, day label, section title |
| `title-sans` | sans | 21 | 650 | 28 | Sheet titles, panels where serif is too editorial |
| `headline` | sans | 18 | 600 | 24 | Stop name, summary stat number, sheet item primary |
| `body` | sans | 16 | 400 | 24 | Option labels, descriptions, input text |
| `body-serif` | serif | 16 | 400 | 26 | Long-form route notes and tips only |
| `callout` | sans | 14 | 400 | 20 | Reason-block prose, widget rows, secondary text |
| `caption` | sans | 12 | 450 | 16 | Meta rows: area, dwell, badge text |
| `overline` | sans | 11 | 600 | 14 | Eyebrow labels ("为什么排在这里"), step counters |
| `nav-label` | sans | 10 | 400 | 14 | Dock item labels — the only sub-11px string allowed |
| `button` | sans | 14 | 600 | 20 | All button labels — `DesignButton` sets `callout` size + `headline` weight (有据 `DesignButton.ets:91-93`), which is the measured truth; this row follows the code, not the other way round |
| `itinerary-time` | sans | 12 | 600 | 16 | Spine time gutter, tabular |
| `itinerary-duration` | sans | 12 | 450 | 16 | "停留 2小时", "步行 18分钟 · 1.2km", tabular |
| `day-label` | serif | 21 | 700 | 28 | "Day 3 · 6月12日 周四" |

Reading sizes: 16px is the default and never drops below 14px where more than one line appears. Sub-12px text is limited to `caption` (12), `overline` (11), the widget floor (11), and `nav-label` (10) — a paragraph is never set below 14.

## 3. Which strings are serif

Serif is reserved for "this page is *about* this place or this day". It is never used on a control.

| Serif | Sans |
| --- | --- |
| Destination name (杭州), day label, interview question, section/panel title, hero empty-state line, widget day overline, long-form route note | Stop name, option chip label, button label, time, duration, distance, badge, stat number, filter chip, toast, sheet item, input value, dock label |

The tell: if the user taps it, types it, or reads it once, it is sans. If it names a place or a day, it is serif. Stop names in particular stay `headline` sans — a serif list row makes the itinerary scan like an article instead of a plan.

## 4. Numerals

Every number in the product is tabular (`tnum`): times, dwell minutes, transit minutes, distances, day counts, step counters, summary stats, widget rows. This is not decoration — the time gutter is a *column*, and proportional figures make 09:30 and 14:00 jump horizontally, which reads as a rendering bug.

Number formatting is fixed by role and shown here so mocks and code agree:

| Role | Format | Example |
| --- | --- | --- |
| Clock | `HH:mm`, 24-hour | `09:30` |
| Dwell | 停留 N小时N分钟, drop zero hours | `停留 2小时` · `停留 45分钟` |
| Transit | mode + 时间 · 距离, both always present | `步行 18分钟 · 1.2km` |
| Day | `Day N` + 月日 + 周X | `Day 3 · 6月12日 周四` |
| Trip length | `N天M晚` | `5天4晚` |
| Summary | integer + unit, no thousands separator | `景点 12` · `步行 6.4km` |
| Step counter | `第 N/M 步` | `第 2/5 步` |

Never write a duration as a distance alone (`1.2km`) or a distance as a duration alone — the product's promise is that the plan is walkable, and both quantities have to be visible to prove it.

## 5. Leading, alignment, wrapping

- Leading is the token value, never `auto`. Ratios: display 1.35, title 1.5, headline 1.33, body 1.5, caption 1.33 — long-form `body-serif` runs 1.625 for CJK readability.
- Body and reasoning prose: left-aligned (ragged right). Never justify CJK — it creates rivers between ideographs.
- Time gutter: right-aligned so the spine edge is a straight line.
- Two-line clamp on stop names, single line on badges, times, and labels; three-line clamp on the reason block, and beyond that it collapses behind a "展开" in `primary`.
- Chinese punctuation is never followed by a space; latin units keep a thin space (`6.4km` → no space, per the table above).
- No all-caps CJK equivalent, no letter-spaced caps for eyebrows — `overline` is weight + size only.

## 6. Where type is drawn rather than laid out

Both products render text outside the normal view tree — 有据 exports share posters, 有径 draws map labels — and those paths must use the *same* two font files, or the brand splits in two. In ArkUI a canvas `Typeface` is built from the bundled OTF (`drawing.Typeface.makeFromRawFile`) and passed to the painter; it does not inherit `fontFamily`. Two consequences: poster and map code needs its own serif handle, and the bold/regular split applies there too (posters use Bold for titles, Regular for body).

## 7. Text scaling and the accessibility floor

HarmonyOS lets the user scale system text (commonly up to 1.3–1.6×). The design must survive it:

- Row heights grow with content; nothing has a fixed height that clips a scaled label. The 76px stop row and 56px option card are *minimums*, not caps.
- Fixed-width columns get slack: the 52px time gutter tolerates ~1.3× before it must reflow; at larger scales the gutter grows to 64px rather than truncating a time.
- Badges, chips and stats wrap to a second line; they never ellipsis mid-number.
- The only strings allowed to stay small are the dock label (10px) and widget text (11px floor), because both are secondary to an icon or a number.
- Truncation policy: two lines on stop names, one line on badges/times/labels, three lines on reason blocks with a 展开 in `primary`.

# Layout

All values are HarmonyOS `vp`, which equals CSS `px` at 1× on a 360vp-wide phone artboard. **Every number in the product is a multiple of 4** — if a mock shows 15px or 18px, it is wrong, not refined.

## 1. Spacing scale

| Token | Value | Used for |
| --- | --- | --- |
| `spacing.xxs` | 4px | Icon-to-label gap, badge padding halves, dot-to-text |
| `spacing.xs` | 8px | Between inline elements, option chip gap, list row inner gap |
| `spacing.sm` | 12px | Between list items, grid gutters, stop-to-stop on the spine |
| `spacing.base` | 16px | Card padding, page horizontal padding, block separation |
| `spacing.md` | 20px | Sheet panel padding, wide-page padding |
| `spacing.lg` | 24px | Section separation, question card vertical padding |
| `spacing.xl` | 32px | Hero top/bottom whitespace, between major page groups |
| `spacing.xxl` | 48px | Full-page empty state, onboarding bands |

Semantic aliases the code actually consumes, so a mock can be named the same way: `inline-tight` 4 · `inline` 8 · `item` 12 · `block` 16 · `section` 24 · `page-compact` 16 · `page-wide` 20.

## 2. Page skeleton

| Measurement | Value | Notes |
| --- | --- | --- |
| Artboard | 360 × 780vp | Phone portrait; also produce 840vp-wide expanded at 600×960 |
| Page horizontal padding | 16px | 20px past the 840px breakpoint |
| Title bar | 60px | 44px touch + one 16px step; status-bar inset is added here and nowhere else |
| Segmented control | 36px tall | sits inside the title bar's second row |
| Floating dock | 300 × 64px | 30px radius, centered, 28px above the system nav inset, ≥ 16px from the screen edge |
| Bottom scroll reserve | 94px + nav inset | so the last stop can scroll clear of the dock |
| Sheet | 344px wide, 20px panel padding, 16px inner gaps | half-modal, rounded 20px |
| Grid gutter | 12px | |
| Block / section gap | 16px / 24px | |
| Min touch target | 44 × 44px | even when the drawn glyph is 12px |
| Reading column max | 720px | |
| Breakpoints | 440px compact · 840px expanded | |
| Hairline | 0.5px | dividers between like rows only; cards are separated by whitespace |

## 3. Itinerary spine geometry

This is the layout that defines the product, so it is specified down to the pixel:

| Element | Value | Rule |
| --- | --- | --- |
| Time gutter | 52px | right-aligned, `itinerary-time`, tabular figures |
| Spine | 2px wide | `surface-sunken`; the segment belonging to the selected/current stop is `primary` |
| Node | 24px circle | centered on the spine; 10px inner dot tinted by activity type; white fill + `ink` ring by default |
| Stop row | ≥ 76px tall | grows with content, never below 76 |
| Row gap | 12px | |
| Transit leg | 44px tall | `surface-subtle`, 10px radius, 8px/12px padding, 2px dashed connector, icon + `步行 18分钟 · 1.2km` |
| Day divider | 44px | serif `day-label` left, muted meta right; sticky variant uses `glass-bar-surface` + blur 50 |
| Route line | 2px | over a wider soft halo (same hue @ 30–35%) |
| Map card | 200px tall (compact) | `lg` radius, labels inset 16px |

## 4. Concentric radius rule

A nested element's radius = parent radius − parent padding, floored at 0. A 20px card with 16px padding holds **6px** media corners. This is why `xs` exists at 6 and not at 8.

## 5. Feed geometry (有据)

| Element | Value | Rule |
| --- | --- | --- |
| Columns | 2 on phone, 3 past 600vp | 12px gutter, 16px page padding |
| Post card | `elevated`, 20px radius, 16px padding | cover 3:4 on 6px corners, 12px to the text block |
| Card text | title `headline` (serif in 有据's detail page only), excerpt `callout` 2-line clamp, meta `caption` | tags bottom-left as `tag-pill`, actions bottom-right as 44px icon buttons |
| Sticky top bar | 60px, grows +36px per extra segmented row | measured via `onAreaChange` when content-driven, with a token-based first-frame estimate |
| Detail action bar | 44px icons, glass dock material | never overlaps the system nav inset |

The waterfall's rhythm — 12px gutters, 3:4 covers, 20px cards on 16px padding — is the single most recognizable thing about 有据. 有径 reuses the same card and gutter numbers for its own trip list so the two apps feel cut from one cloth even on screens that share no component.

# Elevation & Depth

Three devices, in strict order of preference: **surface color step → whitespace → shadow.**

- `cardContact` (1px blur, 0px y, 3% black): the crisp edge under a card; never alone.
- `cardAmbient` (10px blur, 3px y, 7% black): itinerary cards, summary card, sheets — layered under `cardContact` by two nested containers, since ArkUI renders one shadow layer per node.
- `floating` (16px blur, 6px y, 9% black): sheets, popovers, the dock.
- `pillFloat` (8px blur, 3px y, 15% black): floating pills and drag-elevated rows.
- Segmented bars and popovers use flat ambient (no offset).

Shadow is black-with-alpha, which is theme-neutral: it stays in dark mode and carries no zeroing branch. Only large-area drops (`bar_shadow`) are promoted to a paired resource (light `#2E1A1A1E`, dark `#8C000000`). Note: the 有径 app's four page-level `.shadow()` sites still carry a legacy dark-zeroing branch pending the T4 migration; the gate is flipped in that batch, not here.

The app's real depth device is **blur**, and the **bar** surfaces' written blur radius is still the three bar surfaces at 50 — ① the top bar (`components.top-bar-immersive`), ② the floating dock (`components.floating-dock`), ③ the sticky day divider (`components.day-header` in its sticky variant) — all three at blur 50 with a 1px `glass-bar-border` stroke and a 92px gradient mask fading content into the bar. In addition, the self-drawn material points registered in 差异表 §6 may use the system `backgroundBlurStyle` grades (Floating / Card / Press / Dialog); no new written blur number is invented. ④ Sheets and menus are **material surfaces, not blur surfaces**: where system material is available it takes over the panel, and the self-drawn fallback is exactly the opaque `components.sheet-modal` recipe above (`surface-elevated` + `floating` elevation + scrim), which invents no blur value. The segmented control is **not a fifth glass surface**: it carries only its own in-component value (`components.segmented-control.blur: 20`), the single written exception, scoped inside one component and never readable by the bar gate. **When system material (沉浸光感) is active, the surface must zero out its own background, border, and shadow** — otherwise you get a second ring around the bar and a hard grey seam under the header. Every material feature must sit behind an explicit API-level gate with a self-drawn glass/stroke/solid fallback that looks the same. The bar surface is gated by the **absolute** scroll offset (`scrolled ? 50 : 0`), never by per-frame delta, because a spring-back negative delta turns the blur off at rest.

Depth in the route canvas is drawn, not shadowed: overlapping contour hairlines and a soft wide `path-soft` stroke under the 2px `path` line (a halo, not a drop shadow). Widgets on the launcher get no blur and no elevation — solid surface plus a 1px hairline border so they stay legible against any wallpaper.
# Shapes

| Token | Value | Used by |
| --- | --- | --- |
| `rounded.none` | 0px | Canvas backgrounds, full-bleed map surface, question-card background |
| `rounded.xs` | 6px | Photos, map label chips, anything nested inside a `lg` card |
| `rounded.sm` | 10px | Transit legs, small inputs, inline tags |
| `rounded.md` | 14px | Reason blocks, wells, skeleton blocks |
| `rounded.lg` | 20px | **The default card.** Itinerary cards, option chips, sheets, popovers, widgets, map containers |
| `rounded.xl` | 28px | Hero panels, generated-itinerary banner |
| `rounded.floating-bar` | 30px | Dock, segmented control, sticky filter bar — the three "floating chrome" objects share one radius |
| `rounded.pill` | 999px | Buttons, badges, booking tags, avatars |

Rules:
- **Buttons are always pill**, at every size. A `sm`/`md` radius on a button is the single most common way to make a sibling app look unrelated.
- **Option chips are `lg` 20px squares, never pills** — a pill reads as a tag (already chosen), a square reads as a choice (tap to choose).
- Cards are 20px; photos inside them are 6px (see the concentric rule above).
- Avatars are always circles; a square avatar reads as a bug in this family.
- Corners are squared only for canvas and full-bleed map surfaces.
# Components

Shared first, then each product's own layer. A component that exists in both apps is defined once here and must not be re-specified.

## 1. Family-wide components

**Buttons.** Four variants: `primary` (solid `brand-solid` / `on-brand` text, pill, 44px) for the one main CTA per screen; `outlined` (transparent, 1vp `bar-border`, pill); `ghost` (transparent, no stroke); `glass` (self-drawn `GlassPillButton`). Labels are `callout 14 / 600` (replacing `body 16`). Ratio discipline: exactly one `primary` per view, everything else `outlined` / `ghost`. Press = `scale 0.97 + opacity 0.92` / 140ms; disabled = `.opacity(0.45)`.

Dark mode note: a solid `primary` button in dark mode paints `#0A84FF` with a `#121212` ink label, not white — see Colors §4.


**Cards.** `surface-elevated`, 20px radius, 16px padding, 12px internal gap, `cardAmbient` shadow. Where a material point is registered in 差异表 §6, a card may be a self-drawn `GlassPanel`: `backgroundBlurStyle(GlassBlurStyle.Card)` + 1vp `separator` stroke + `cardAmbient` shadow + `clip`. Keep 20px radius / 16px padding / 12px internal gap. Structure: 3:4 media on 6px radius, optional `title` line (serif), `body` excerpt, meta row in `caption` / `faint`, tag pills bottom-left, action icons bottom-right. No border on cards in light mode — the fill step does the separating.

**Segmented control.** The signature navigator: 36px tall, pill-ish 30px radius, smoked-glass track (`glass-segment-bg` 10% + 1px border) with blur 20, and a selection pill in `glass-selection-surface` with a blue-tinted shadow. Selected item text is `ink`, unselected `muted`. Pressing squishes the track to 0.94 with a spring back. When system material is active, the self-drawn stroke and shadow must go to zero.

**Top bar.** Full-bleed canvas behind a system "immersive light" material. Line 1: brand block — serif wordmark with an `overline` latin subtitle and a `caption` tagline, plus a search icon-button on the right. Line 2 (optional): the segmented control, or filter chips. Scroll blurs content under it with a gradient mask. Status bar inset is applied here and only here.

**Floating dock.** 300×64px, `rounded.floating-bar`, `glass-bar-surface` with blur 50 + `glass-bar-border`, `floating` elevation, centered icons with `nav-label` text beneath, and a blue glow spot (`glow_tint`, ~180px) that follows the pressed item. The publish/center action is the same dock item, not a separate FAB. Reserve 94px + nav inset under any scrolling list.

**Sheet (half-modal).** `SpringPanel` recipe: `panelWidth 344` + `panelPadding 20` (`SpaceTokens.lg`), three material grades (glass / outlined / solid), entrance `opacity` / `translate` / `scale` on `container 320` with `springSoft`; `surface-elevated` (light) / `#1E1E1E` (dark) fallback, floating elevation, scrim behind. Handles: publish method picker, tag selection, filters.

**Stat row.** Number in `headline` with `tnum`, label in `caption` / `muted`, laid out 72px per stat, left-aligned, no divider.

**Skeleton.** `skeleton-base` blocks on `md` radius, 160px default width with a 56px highlight line, shimmer sweep at 1200ms linear. Skeletons mirror the real card layout — same media ratio, same padding. Mirror the real layout exactly: 76px rows, 24px circles, 52px time blocks, `md` radius, 160px default width with a 56px highlight line.

**Empty state.** Centered: **`IconTokens.empty` 44 glyph** in `muted` `#69696E` (`viewBox` 24, stroke-width 2 — `faint` is barred here by §8: it measures 2.67:1 on canvas and fails the 3:1 graphic floor), a `headline 18/600` serif line, `callout 14` explanation in `muted`, one `brand-solid` action button. Never a wall of text, never an illustration in a new hue. When generation fails, say which step failed and offer retry — that is on-brand for a product whose whole premise is traceability.


## 2. 有据 product layer

**Tag pill / mention.** `primary-tint` background with `primary` text for topics (`#话题#` style), `accent-mention` text for `@people` with no fill. Never swap these two — the hue difference is the semantic.

**Star map (signature).** Rings at 1px `star-paper-ring` on the paper canvas with a top-to-bottom `bgTop → bgBottom` gradient; planets are filled discs (`discFill` + `discStroke`), member highlights in `gold`, new posts as small seed dots in `icon`/`seedBlue`, featured posts in `seedGold`, unread badges in `badge`. Dark mode swaps to the "ink sky" gradient with glowing rings. Content labels are always `ink`, and the geometry is identical between palettes.


## 3. 有径 product layer

**Destination & date entry.** Serif `display` city name on the canvas, a 64px `surface-elevated` field row (label in `muted` caption, value in `headline`, chevron in `faint`) for dates and travelers, then one `primary` CTA. No map screenshot, no stock photo hero — the entry screen is type on white.

**Interview question (`question-card`).** Full-bleed canvas, 24px/16px padding: serif `title` question, a `muted` `callout` helper line, then a stack of `option-chip` cards with 8px gaps. Each chip: `surface-elevated`, `lg` radius, min 56px tall, 16px padding, `body` label, optional `caption` sub-line, and a `primary` check mark top-right when selected. Selected state = `brand-solid` solid fill + `on-brand` label. Press = scale 0.97 / 140ms. Progress is a row of 6px dots (active `primary`, inactive `surface-sunken`) plus an `overline` "第 2/5 步". Skip is `button-ghost`, never a grey text link. No chat bubbles, no AI avatar, no typing indicator.

**AI generating state.** The only place shimmer is allowed. Serif `title` ("正在为你规划 5 天行程"), a `callout` stage list ticking through real steps (筛选景点 → 排布动线 → 校验开放时间 → 估算耗时), each revealed with a 40ms stagger; a 2px `primary` progress bar on a `surface-sunken` track; below it, skeleton `md` blocks shaped exactly like the day cards that will land, shimmering at 1200ms linear. Never a spinner alone, never fake percentage text.

**Day section.** `day-header` (serif 21 + muted date + pace/weather meta), then the spine of `itinerary-row`s, then `transit-leg`s between them. Each stop row: time in the 52px gutter, node dot, `headline` stop name, `caption`/`muted` area + dwell time, activity-type dot, and right-aligned badges (`booking-badge`, `highlight-badge`). Optionally a 3:4 photo on `xs`. The "why" is a `reason-block`: `surface-panel` with a 2px `primary` left rule, `muted` `overline` label ("为什么排在这里"), `callout` `body` prose — this is the product's honesty device and must never be hidden behind a tap.

**Badges.** `booking-badge` three states: 需预约 (warning fill), 已确认 (success fill), 自由安排 (`surface-subtle` + `muted`). `highlight-badge` 必去/招牌 in `bookmark`. All pill, 4px/10px padding, `caption` or `overline`. Color never carries meaning alone — every badge has a word.

**Route map (`route-map-canvas`).** Compact 200px card on `lg`, or full screen with floating chrome. Path draws in over 460ms with `curve-emphasized`, nodes pop in on a 40ms stagger with `curve-spring`. Numbered white nodes with a near-black ring; a thin `path-soft` halo under the 2px line; hairline contours for terrain; gold ring for 必去 stops; labels in `caption` with a `xs` surface chip behind them for legibility. Light = paper, dark = ink; geometry identical.

**Itinerary summary card.** Title serif `headline`-size, then a stat row: 景点 12 / 步行 6.4km / 需预约 3, each number `headline` + tnum, label `caption` + `muted`, 72–84px per stat, left-aligned, no dividers.

**Widget (万能卡片).** Solid `surface-elevated` (dark `#1E1E1E`), 1px `hairline` border, `lg` radius, 12px padding at 2×2 / 16px at 2×4, no blur, no shadow, no translucency. Content is "今日行程": serif overline day label, up to three upcoming stops as `callout` rows with tnum times, an activity-type dot each, and a `caption` footer ("还剩 2 个预约节点"). Floor text size 11px. It must be readable over a bright or dark wallpaper without any background assistance.

**Calendar sync row.** 64px, `body` title + `muted` one-line explanation of exactly what gets written, `primary` switch on the right, chevron if it opens a sub-panel. Never a permission ask inside a sheet.

**Badge text polarity flips with the theme, and this is not a stylistic choice.** Light-mode fills are deep earth tones (#A06400 / #1C7440 / #C0392B / #9A6206) that hold white text at 4.86–5.8:1. Dark-mode fills are the system-bright set (#FF9F0A / #30D158 / #FF453A / #FFD60A) — white on those is 2.0–3.4:1 and fails AA outright. In dark mode the badge text must therefore be the *canvas* color (#121212), which measures 9.11:1 on #FF9F0A, 9.27:1 on #30D158, 13.27:1 on #FFD60A and 5.50:1 on #FF453A — dark ink punched into a bright pill. Never keep white-on-bright. The neutral 自由安排 badge is an exception: it is a grey panel (`#28282C`) with `dark-ink` text, 13.13:1.

# Do's and Don'ts
Do:
- Keep the canvas pure white / `#121212` and let the surface step separate content.
- Use serif for destination/day/question titles and sans for every operable item; when unsure, use sans.
- Put exactly one `primary` blue action per screen, pill-shaped, 44px, and make everything else `outline`.
- Show the reason, the duration, and the booking state for every stop — as visible data, not a hidden detail.
- Use tabular figures for every numeral, and right-align the time gutter so the spine reads as a table.
- Animate only `transform` and `opacity`. Press 140ms < control 220ms < container 320ms < page 420ms; `curve-standard` for exits, `curve-decelerate` for entries, `curve-spring` for confirmations, `curve-emphasized` for the route draw. Stagger list reveals at 40ms.
- Draw dark-mode depth as a luminance ladder.
- Gate system material behind an API-level check and ship a self-drawn fallback that looks the same.
- Keep the dock and sticky header clear of the safe area, reserve 94px + nav inset under scrolling content, and keep 16px body text selectable/zoomable.
- Use single-color line icons tinted from tokens (currentColor), never baked-color assets.
- Make the interview skippable and every AI decision editable — one `outline` "改主意" entry per day.

Don't:
- Don't apply glass, blur, or gradients to itinerary rows, option chips, or reason blocks. Glass / blur may appear only at the material points registered in 差异表 §6; cards, inputs, dialogs and floating layers may carry self-drawn glass at those registered points.
- Don't stack a self-drawn border/shadow on a surface that already has system material (double ring + grey seam).
- Don't set blue label text on a blue tint fill (4.49:1 light / 3.59:1 dark, both sub-AA). Tint fills take an `ink` label plus a blue stroke.
- Don't put white text on a dark-mode bright fill (2.02–3.65:1); bright fills take `#121212` ink.
- Don't introduce new hues for new activity types or moods. The five-type allocation is closed; the sixth meaning is carried by an icon or a word.
- Don't style AI output like chat: no speech bubbles, no AI avatar, no typing indicator, no gradient text, no "magic" sparkles as a primary motif.
- Don't fake precision: no invented percentages, no fake distance numbers, no decorative map pins without a real coordinate.
- Don't use stock photography or map-screenshot heroes on the entry screen; type on white is the brand.
- Don't add letter-spacing (positive or negative) to CJK.
- Don't set colored advisory text (warning / bookmark / danger hues) at 11–12px on a `surface-panel` fill — 4.24:1. Panels carry color as a rule, a dot, or an icon.
- Don't use pure black #000 text or pure white cards in light mode (`#17171A` on `#F7F7F8` is the contract).
- Don't use square or `md`-radius buttons, `lg` radius on photos, or small radii on cards.
- Don't blur or make launcher widgets translucent — they must stay readable on any wallpaper.
- Don't express dark mode by inverting plus heavier shadows.
- Don't chain more than two timed animations on a single tap, and don't animate layout properties.
- Don't let a duration read as distance alone ("1.2km") — always pair with time ("步行 18分钟 · 1.2km").

Family-wide (applies to both products):
- Don't fork a shared token value per product. If 有据 needs a new surface step, 有径 inherits it.
- Don't let one app invent a third glass surface, a third radius tier, or a second display family — that is how sibling brands drift apart.
- Do keep the serif/sans split, the 4px baseline, the 20px card and the 300×64 dock identical in both, because those four are what a user actually recognizes across apps.

---

## 9. 有径定稿决议（2026-10-21，冻结前清账）

以下八条是 19 浅色帧 + 深色批次审计后剩下的未决项（第 8 条来自 2026-10-22 深色 19 帧全量复算）。**已按现有证据定死，实现期照此执行；若产品侧要翻，翻一条即可，不必重开全局。**

| # | 议题 | 决议 | 依据 |
|---|---|---|---|
| 1 | 内容图标是否存在第三档（14/16px） | **按有据源码采用 `IconTokens` 全档（16/20/24/44/56/68），控制档 24、展示档 44。** | 21 帧实测：除状态栏外无一内容图标离档 |
| 2 | 屏 8 dock 徽标数字 | **取 3**，与屏 12「我的行程」三张进行中行程卡同源。徽标数必须与内容同源，不许出现"徽标 3 / 列表 2" | 屏 12 `f037b5c4` 实渲三张 `.trip-card` |
| 3 | `modal-scrim` | **采纳为契约件**：`rgba(23, 23, 26, 0.32)` / ArkTS `52 17 17 1A`。已有消费方，不是空 token | 屏 14 `d04983a4` 渲染出 `.modal-scrim` 类，实测距底 0、满幅覆盖 |
| 4 | 费用 hero 卡是否带阴影 | **hero 永不带影**（`elevation` 只给卡片与浮层）。屏 11 与屏 15 实测**均已合规**，此条不再是矛盾，只作禁令保留 | 两帧的 `floating` 阴影都只落在 dock 上，`.hero-panel` 注释与规则都是零阴影 |
| 5 | 屏 13 帧内 `Widget A/B/C` 元标注 | **保留在稿、不进入产品**。它是给人看的标注，因此按"有意义文字"要求配色：深色底上从 `dark-faint #8A8A91`（2.67:1）改为 **`dark-body #A8A8AE`**；ArkTS 实现时整行删除 | DESIGN.md §2 明写 `faint` 只许装饰/禁用 |
| 6 | 屏专属滚动预留与缩进（64 / 72 / 76 / 84 / 104 / 138 / 180px） | **在 `layout` 增设具名层** `scroll-reserve--*` 与 `indent--*`，允许离开通用 `spacing` 阶梯，但**必须具名且写成 `calc(Npx + env(safe-area-inset-bottom, 12px))`**。未具名的离表值仍算缺陷 | 5 帧 6 处，均为滚动预留而非误填 |
| 7 | 深色帧的 `html` / `body` 底色 | **必须显式写 `dark-canvas #121212`**。屏 8 深色实测 `#070B16`、屏 12 深色实测 `#000000`，都被满幅 `.device-frame` 盖住所以画面不可见，但 ArkTS 窗口底色取自该层会闪黑 | 渲染实测 `body` 背景 vs `.device-frame` 背景 |
| 8 | `dark-glass-bar-shadow` 与「深色零阴影」谁赢 | **深色侧零 CSS 阴影赢。** 该 token 只描述 ArkTS 侧 HDS 材质自带的系统投影量级，**不得翻成帧里的 `box-shadow:` 声明**；稿件里出现即为缺陷，实现期直接删掉这一行、材质层自然给到 | 屏 15 深色 `4d55fd31` 实测 1 条 `0px 6px 16px 0px rgba(0, 0, 0, 0.55)`，值恰好等于该 token |

**另加两条禁令（同为清账产物）**：

- **状态栏不许玻璃化。** `.status-bar` / `.status-icons` 是设备 chrome，`backdrop-filter` 必须为 `none`。屏 4 实测带 `blur(24px)`，等于在契约四处之外开了第五处玻璃面。
- **画板高度是硬边界。** `.device-frame` 固定 360×780 且 `overflow: hidden`；任何 `position: absolute; bottom: 0` 的底栏，其包含块必须是 `.device-frame` 本身。屏 4 实测 `document.scrollHeight = 820`、底栏 `bottom = 800`、主 CTA 距底 **−4px**，即底栏被推出画布——**这是 21 帧里唯一的几何溢出，实现时必须按 780 收回来，不得照抄稿件。**
