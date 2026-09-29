// SearchInputProps —— 搜索输入组件（GlowInput / GlowInput_Api26 / GlowInput_Api23）的统一参数契约。
// 三个实现对外暴露完全相同的成员签名，SearchPanel 按 API 版本分支选择实现，调用方无感知。
// 说明：ArkTS 自定义组件的 @Prop/@Link 不能直接 implements 接口，本接口作为签名契约文档，
// 三个实现逐一手工对齐（改任何一个实现的成员必须同步这里与其余两个实现）。

export interface SearchInputProps {
  placeholder: string;
  text: string; // 外部传入的当前值（组件以 @Link 双向绑定对齐）
  fillWidth: boolean; // 是否参与 Row 内 flex 拉伸
  debounceMs?: number; // onChange 防抖时长（ms），0 或不传 = 即时
  onChange: (value: string) => void;
  onEnter: (value: string) => void;
  onFocusChanged: (focused: boolean) => void;
}
