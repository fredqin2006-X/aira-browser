import { SettingsDetailRowAction } from './SettingsDetailViewModel';
import { localizeSettingsCopy } from '../../core/settings/SettingsCopy';

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
          title: '开启媒体扰动抑制？',
          message: '开启后，滚动时会弱化广告 iframe，并暂停离屏视频，可能提升流畅度，但少数网页的视频或广告位表现会变化。',
          confirmLabel: '开启',
          cancelLabel: localizeSettingsCopy('取消'),
          confirmIsDestructive: false
        } : undefined;
      default:
        return undefined;
    }
  }
}
