// 举报弹窗组件（理由单选 + 补充说明 + 提交/取消）
// 「其他」理由时补充说明必填，否则提交按钮置灰
import { ReportReason } from '../models/types';

interface ReasonItem {
  value: ReportReason;
  label: string;
}

@CustomDialog
export struct ReportDialog {
  controller: CustomDialogController;
  targetType: string = 'post';
  targetId: number = 0;
  onSubmit: (reason: ReportReason, description: string) => void = (_reason: ReportReason, _desc: string) => {};

  @State selectedReason: ReportReason = 'political';
  @State description: string = '';
  @State submitting: boolean = false;

  private reasonList: ReasonItem[] = [
    { value: 'political', label: '涉政敏感' },
    { value: 'pornographic', label: '色情低俗' },
    { value: 'personal_attack', label: '人身攻击' },
    { value: 'gender_war', label: '男女对立引战' },
    { value: 'advertisement', label: '广告推广' },
    { value: 'spam', label: '垃圾信息' },
    { value: 'other', label: '其他（需填写说明）' },
  ];

  // 提交按钮是否可用
  private canSubmit(): boolean {
    if (this.submitting) {
      return false;
    }
    if (this.selectedReason === 'other') {
      return this.description.trim().length > 0;
    }
    return true;
  }

  build() {
    Column({ space: 16 }) {
      Text('举报')
        .fontSize(18)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))

      Text('请选择举报理由：')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))

      // 单选理由列表
      ForEach(
        this.reasonList,
        (item: ReasonItem) => {
          Row({ space: 8 }) {
            Radio({ value: item.value, group: 'reportReason' })
              .checked(this.selectedReason === item.value)
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selectedReason = item.value;
                }
              })
            Text(item.label)
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
        },
        (item: ReasonItem) => item.value
      )

      // 补充说明
      Text('补充说明（选填）：')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
      TextArea({ placeholder: '请输入补充说明（选填，最多200字）', text: this.description })
        .maxLength(200)
        .height(80)
        .fontSize(14)
        .backgroundColor($r('app.color.bg_primary'))
        .borderRadius(8)
        .onChange((v: string) => {
          this.description = v;
        })

      // 按钮行
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_primary'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
          })
        Button('提交举报')
          .layoutWeight(1)
          .enabled(this.canSubmit())
          .onClick(() => {
            this.submitting = true;
            this.onSubmit(this.selectedReason, this.description.trim());
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}
