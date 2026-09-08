// 打开外部 URL（系统浏览器 / 应用内预览）：私信文件、外链分享通用
import { common, Want } from '@kit.AbilityKit';

// 用系统「查看」意图打开 URL（无实体可查看该类型时由系统兜底选择应用）
export async function openExternalUrl(context: common.UIAbilityContext, url: string): Promise<void> {
  const want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: url,
  };
  await context.startAbility(want);
}