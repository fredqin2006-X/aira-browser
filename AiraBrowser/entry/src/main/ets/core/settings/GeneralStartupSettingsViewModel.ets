import {
  BrowserGeneralSettings,
  BrowserStartupRestorePolicy
} from '../../common/models/BrowserModels';

export interface GeneralStartupRestoreOptionState {
  policy: BrowserStartupRestorePolicy;
  title: ResourceStr;
}

export interface GeneralStartupSettingsState {
  startupRestorePolicy: BrowserStartupRestorePolicy;
  startupOptions: GeneralStartupRestoreOptionState[];
}

export class GeneralStartupSettingsViewModel {
  buildState(general: BrowserGeneralSettings): GeneralStartupSettingsState {
    return {
      startupRestorePolicy: general.startupRestorePolicy,
      startupOptions: [
        {
          policy: 'restore_regular_tabs',
          title: $r('app.string.settings_general_restore_tabs_page')
        },
        {
          policy: 'open_home',
          title: $r('app.string.settings_general_open_home')
        }
      ]
    };
  }

  buildGeneralSettingsWithStartupRestorePolicy(
    current: BrowserGeneralSettings,
    policy: BrowserStartupRestorePolicy
  ): BrowserGeneralSettings {
    return {
      startupRestorePolicy: policy,
      tabAutoClosePolicy: current.tabAutoClosePolicy,
      privateTabRestorePolicy: current.privateTabRestorePolicy,
      privateModeAuthenticationEnabled: current.privateModeAuthenticationEnabled,
      alwaysUsePrivateMode: current.alwaysUsePrivateMode === true,
      privateModePreserveCookiesOnClose: current.privateModePreserveCookiesOnClose,
      privateModeThemeEnabled: current.privateModeThemeEnabled
    };
  }
}
