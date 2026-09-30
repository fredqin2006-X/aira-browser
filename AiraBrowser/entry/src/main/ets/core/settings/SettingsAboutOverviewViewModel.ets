import { SettingsAboutAppIdentity } from './SettingsAboutCoordinator';
import { localizeSettingsCopy } from '../../core/settings/SettingsCopy';

export interface SettingsAboutOverviewState {
  appTitle: string;
  versionTitle: ResourceStr;
  versionText: string;
  moreButtonTitle: ResourceStr;
}

export class SettingsAboutOverviewViewModel {
  buildState(identity: SettingsAboutAppIdentity): SettingsAboutOverviewState {
    return {
      appTitle: 'Aira',
      versionTitle: localizeSettingsCopy('当前版本'),
      versionText: `${identity.versionName} (${identity.versionCode})`,
      moreButtonTitle: localizeSettingsCopy('查看更多')
    };
  }
}
