import { BrowserAppServiceMode } from '../../common/models/BrowserModels';
import { localizeSettingsCopy } from '../../core/settings/SettingsCopy';

export interface AppServiceModeConfirmationPrompt {
  title: ResourceStr;
  message: ResourceStr;
  cancelLabel: ResourceStr;
  confirmLabel: ResourceStr;
  confirmIsDestructive: boolean;
}

export class AppServiceModeConfirmationViewModel {
  buildPrompt(
    currentMode: BrowserAppServiceMode,
    targetMode: BrowserAppServiceMode
  ): AppServiceModeConfirmationPrompt | undefined {
    if (currentMode === targetMode || targetMode !== 'basic') {
      return undefined;
    }
    return {
      title: localizeSettingsCopy('切换到基本模式？'),
      message: localizeSettingsCopy('基本模式会关闭账号登录、同步、会员、翻译、脚本、网页内容过滤、壁纸、远程建议和实验功能。大部分增强能力将不可用，App 会重启以应用更改；已保存的数据不会删除。'),
      cancelLabel: localizeSettingsCopy('取消'),
      confirmLabel: localizeSettingsCopy('切换到基本模式'),
      confirmIsDestructive: true
    };
  }
}
