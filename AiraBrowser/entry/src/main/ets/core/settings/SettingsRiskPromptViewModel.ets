import { SettingsDetailRowAction } from './SettingsDetailViewModel';

export interface SettingsRiskPromptState {
  title: ResourceStr;
  message: ResourceStr;
  confirmLabel: ResourceStr;
  cancelLabel: ResourceStr;
  confirmIsDestructive: boolean;
}

export class SettingsRiskPromptViewModel {
  buildPrompt(action: SettingsDetailRowAction, nextEnabled: boolean): SettingsRiskPromptState | undefined {
    switch (action) {
      case 'toggle_reduce_media_motion_during_scroll':
        return nextEnabled ? {
          title: $r('app.string.settings_experiments_risk_title'),
          message: $r('app.string.settings_experiments_risk_message'),
          confirmLabel: $r('app.string.settings_experiments_risk_confirm'),
          cancelLabel: $r('app.string.settings_account_cancel'),
          confirmIsDestructive: false
        } : undefined;
      default:
        return undefined;
    }
  }
}
