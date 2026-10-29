// design token: color. 页面与组件只消费此入口，不直接依赖资源名。
export class ColorTokens {
  static readonly canvas: ResourceColor = $r('app.color.ds_canvas');
  static readonly elevated: ResourceColor = $r('app.color.ds_elevated');
  static readonly subtle: ResourceColor = $r('app.color.ds_subtle');
  static readonly sunken: ResourceColor = $r('app.color.ds_sunken');
  // 次级内容面板底：比卡片底（elevated）深一档、比 sunken 浅得多的中性灰。
  // 用途：媒体下方的信息条 / 需要「看得出是一块面板」但不想厚重的区域。
  // 浅色 #EFEFF2（对卡片底 #F7F7F8 可辨但不厚重）；深色 #28282C（比卡片底 #1E1E1E 略亮，
  // 是「微微抬起的面板」而不是一个黑洞 —— sunken 的 #0D0D0F 在深色下更黑）。
  static readonly panel: ResourceColor = $r('app.color.ds_panel');
  // 悬浮面板的磨砂底/描边（深浅成对）：叠在页面底上要「看得出是一块面板」。
  // 浅色 = 中性黑低透明（叠白底呈深一档磨砂）；深色 = 白低透明（叠深灰底呈亮一档磨砂）。
  // 用途：私信表情面板 / 媒体菜单 —— 写死的 #20FFFFFF 在白底上不可辨（QA D3）。
  // 消费方式：backdropBlur + backgroundColor(overlay) + border(overlayBorder)。
  static readonly overlay: ResourceColor = $r('app.color.ds_overlay');
  static readonly overlayBorder: ResourceColor = $r('app.color.ds_overlay_border');

  // 承载系统材质（沉浸光感）的画布底：浅色 #F1F3F5 / 深色 #121212。
  // 为什么不是 canvas：canvas 浅色侧是纯白 #FFFFFF，官方材质圆铺在上面时 rim 与落影
  // 没有可比背板、全被压平（实测圆/底反差 +5 L → 换 #F1F3F5 后 +9 L）。原生电话
  // Navigation 节点真值正是 #F1F3F5（浅）/ #121212（深）。
  // ⚠️ 必须成对：写死 #F1F3F5 会在深色模式下让官方标题与图标出白字压浅底（实测不可读）。
  // 见 docs/harmonyos-official-ui-alignment-baseline.md §7.6.3 / §7.6.8 / 决策点 E 候选 0。
  static readonly materialCanvas: ResourceColor = $r('app.color.ds_material_canvas');

  static readonly primary: ResourceColor = $r('app.color.ds_text_primary');
  static readonly secondary: ResourceColor = $r('app.color.ds_text_secondary');
  // 图标专用色：浅色 #3C3C43（比次要文字 #5A5A60 深一档，线条更挺括），深色为纯白。
  // 与次要文字分开放的原因：深色下次要文字用中性灰（#A8A8AE），图标线条用纯白，可视对比更好。
  static readonly icon: ResourceColor = $r('app.color.ds_icon');
  static readonly tertiary: ResourceColor = $r('app.color.ds_text_tertiary');
  static readonly quaternary: ResourceColor = $r('app.color.ds_text_quaternary');

  static readonly brand: ResourceColor = $r('app.color.ds_brand');
  static readonly brandTint: ResourceColor = $r('app.color.ds_brand_tint');
  static readonly brandPress: ResourceColor = $r('app.color.ds_brand_press');
  // brand **实色大面积底**（主按钮 / 选中 chip / 头像圆牌）专用，与作文字色、描边用的 brand 分开。
  // 为什么单独一档：深色 ds_brand 是 #0A84FF，白字压上去只有 3.65:1（14fp 半粗不达 AA）。
  // 试过「字改墨」——但禁用态整颗按钮被 .opacity(0.45) 往背板压，墨字与暗化后的蓝底会塌到
  // 1.73:1（比改前白字的 2.61 还差），除非重设计禁用态否则无解。所以改立面：
  // 深色 #0050A0 → 启用态白字 7.91:1、禁用态 3.33:1（原 2.61），两处都不需要新增特例。
  // 浅色侧保持 #0066CC 不变（白字 5.57:1）。
  static readonly brandSolid: ResourceColor = $r('app.color.ds_brand_solid');
  // brandSolid 实色底上的文字。
  static readonly onBrand: ResourceColor = $r('app.color.ds_on_brand');
  // @提及专用靛蓝：品牌色改蓝后，与 #话题#（brand 蓝 #0066CC）靠色相区分（靛 243° vs 蓝 210°），
  // 让用户一眼看出点的是「人」而不是「话题」。
  // 两套色板均按 WCAG AA 校过对比度：浅色 #5856D6 对 ds_canvas #FFFFFF ≈ 5.65:1；
  // 深色 #7D7AFF 对 ds_canvas #121212 ≈ 5.44:1。
  static readonly mention: ResourceColor = $r('app.color.ds_mention');

  static readonly warm: ResourceColor = $r('app.color.ds_warm');
  static readonly success: ResourceColor = $r('app.color.ds_success');
  static readonly danger: ResourceColor = $r('app.color.ds_danger');
  // danger 实色底上的文字（未读数徽标 / 系统 Badge）：浅色白字 5.44:1 达标；
  // 深色 #FF453A 是亮底，白字只有 3.41:1（11–12px 小字不达 AA），必须压 #121212 墨字 = 5.50:1。
  static readonly onDanger: ResourceColor = $r('app.color.ds_on_danger');
  // 危险按钮的 tint 底（SoftChip danger 档「取消拉黑」同款）：10% danger 红。
  // 危险动作用 tint 底 + danger 字而非实色 danger 底——示警不抢层级
  static readonly dangerTint: ResourceColor = '#1AFF3B30';
  static readonly like: ResourceColor = $r('app.color.ds_like');
  static readonly bookmark: ResourceColor = $r('app.color.ds_bookmark');
  static readonly separator: ResourceColor = $r('app.color.ds_separator');

  static readonly skeletonBase: ResourceColor = $r('app.color.ds_skeleton_base');
  static readonly skeletonHighlight: ResourceColor = $r('app.color.ds_skeleton_highlight');

  static readonly shadowSegmented: ResourceColor = '#10000000';
  static readonly shadowPopover: ResourceColor = '#12000000';

  static readonly glassClear: ResourceColor = '#00FFFFFF';
  static readonly glassWhite: ResourceColor = '#FFFFFF';
  // 按压光斑专用色（normal 混合，替代白底上数学不可见的 SCREEN 白光斑）
  static readonly glowTint: ResourceColor = $r('app.color.glow_tint');
  // 分段玻璃（白底上"白玻璃+白高光"失效：浅色改烟灰玻璃，深色保持白高光）
  static readonly segmentBg: ResourceColor = $r('app.color.glass_segment_bg');
  static readonly segmentBorder: ResourceColor = $r('app.color.glass_segment_border');
  static readonly barSurface: ResourceColor = $r('app.color.bar_surface');
  static readonly barBorder: ResourceColor = $r('app.color.bar_border');
  static readonly barShadow: ResourceColor = $r('app.color.bar_shadow');
  static readonly barSelectionSurface: ResourceColor = $r('app.color.bar_selection_surface');
  static readonly barSelectionBorder: ResourceColor = $r('app.color.bar_selection_border');

  // 官方 SegmentButton（tab 档）的选中面。不传这个字段时官方取
  // sys.color.segment_button_checked_foreground_color，深色实测 #E5E5E5 —— 它不随主题翻，
  // 而选中文字 text_primary 翻了白 → 白字压白珠 1.20:1（真机首页/我的页三处实拍一致）。
  // 深色给 20% 白：压在实测 #313131 的轨道上合成约 L90，白字 6.8:1，
  // 且保持「选中面只比轨道亮一档」的原生观感（参考实现 84.5 vs 79.6）。
  static readonly barTabSelectedBg: ResourceColor = $r('app.color.bar_tab_selected_bg');

  // 结构化文档主题（warm/cool）的两套表面与强调色。
  // 这六个值原先写死在 StructuredFlowView 里，只有浅色一档：卡面钉在 L249 而块内正文
  // 走 ColorTokens.primary（深 #F2F2F4 = L246）→ 真机实测对比度 1.03:1，整块读不出来。
  // 深色侧按「accent 低透明叠 elevated」推导，保证 primary/secondary/tertiary 三档文字
  // 与 accent 字全部 ≥5:1。
  static readonly warmSurfacePrimary: ResourceColor = $r('app.color.ds_warm_surface_primary');
  static readonly warmSurfaceSecondary: ResourceColor = $r('app.color.ds_warm_surface_secondary');
  static readonly coolSurfacePrimary: ResourceColor = $r('app.color.ds_cool_surface_primary');
  static readonly coolSurfaceSecondary: ResourceColor = $r('app.color.ds_cool_surface_secondary');
  static readonly warmAccent: ResourceColor = $r('app.color.ds_warm_accent');
  static readonly coolAccent: ResourceColor = $r('app.color.ds_cool_accent');

  // 每日一帖「无封面」时的编辑部衬线海报卡面（活 UI，不是作者发布时烤好的海报资产，
  // 所以要随主题翻）。同层标题用 ColorTokens.primary，写死白底即白字压白底。
  static readonly posterFaceTop: ResourceColor = $r('app.color.ds_poster_face_top');
  static readonly posterFaceBottom: ResourceColor = $r('app.color.ds_poster_face_bottom');
  static readonly posterSeal: ResourceColor = $r('app.color.ds_poster_seal');
  // 卡堆拖拽提示药丸：同层字 tertiary、描边 separator 都是成对 token，底不能是单值白。
  static readonly hintPillBg: ResourceColor = $r('app.color.ds_hint_pill_bg');

  // 性别徽章（男=蓝、女=粉）。定稿的是「淡底 + 同色相深字」这套关系，
  // 不是那两块淡粉淡蓝本身 —— 深色下换成深底 + 提亮字，色相身份保留。
  static readonly genderMaleSurface: ResourceColor = $r('app.color.ds_gender_male_surface');
  static readonly genderMaleText: ResourceColor = $r('app.color.ds_gender_male_text');
  static readonly genderFemaleSurface: ResourceColor = $r('app.color.ds_gender_female_surface');
  static readonly genderFemaleText: ResourceColor = $r('app.color.ds_gender_female_text');
}
