import {
  BrowserGeneralSettings,
  BrowserTabAutoClosePolicy
} from '../../common/models/BrowserModels';

export interface GeneralTabAutoCloseOptionState {
  policy: BrowserTabAutoClosePolicy;
  title: ResourceStr;
}

export interface GeneralTabAutoCloseSettingsState {
  tabAutoClosePolicy: BrowserTabAutoClosePolicy;
  tabAutoCloseOptions: GeneralTabAutoCloseOptionState[];
  footer: ResourceStr;
}

export class GeneralTabAutoCloseSettingsViewModel {
  buildState(general: BrowserGeneralSettings): GeneralTabAutoCloseSettingsState {
    return {
      tabAutoClosePolicy: general.tabAutoClosePolicy,
      tabAutoCloseOptions: [
        {
          policy: 'manual',
          title: $r('app.string.settings_general_tab_manual')
        },
        {
          policy: 'after_15_days',
          title: $r('app.string.settings_general_unused_days', 15)
        },
        {
          policy: 'after_7_days',
          title: $r('app.string.settings_general_unused_days', 7)
        },
        {
          policy: 'after_3_days',
          title: $r('app.string.settings_general_unused_days', 3)
        },
        {
          policy: 'after_1_day',
          title: $r('app.string.settings_general_unused_days', 1)
        },
        {
          policy: 'on_app_exit',
          title: $r('app.string.settings_general_clear_on_exit')
        }
      ],
      footer: this.resolveFooter(general.tabAutoClosePolicy)
    };
  }

  buildGeneralSettingsWithPolicy(
    current: BrowserGeneralSettings,
    policy: BrowserTabAutoClosePolicy
  ): BrowserGeneralSettings {
    return {
      startupRestorePolicy: current.startupRestorePolicy,
      tabAutoClosePolicy: policy,
      privateTabRestorePolicy: current.privateTabRestorePolicy,
      privateModeAuthenticationEnabled: current.privateModeAuthenticationEnabled,
      alwaysUsePrivateMode: current.alwaysUsePrivateMode === true,
      privateModePreserveCookiesOnClose: current.privateModePreserveCookiesOnClose,
      privateModeThemeEnabled: current.privateModeThemeEnabled
    };
  }

  resolveLabel(policy: BrowserTabAutoClosePolicy): string {
    switch (policy) {
      case 'after_15_days':
        return '15 天';
      case 'after_7_days':
        return '7 天';
      case 'after_3_days':
        return '3 天';
      case 'after_1_day':
        return '1 天';
      case 'on_app_exit':
        return '退出后清除';
      case 'manual':
      default:
        return '不自动关闭';
    }
  }

  private resolveFooter(policy: BrowserTabAutoClosePolicy): ResourceStr {
    if (policy === 'on_app_exit') {
      return $r('app.string.settings_general_tab_footer_exit');
    }
    if (policy === 'manual') {
      return $r('app.string.settings_general_tab_footer_manual');
    }
    return $r('app.string.settings_general_tab_footer_days', this.resolveUnusedDays(policy));
  }

  private resolveUnusedDays(policy: BrowserTabAutoClosePolicy): number {
    if (policy === 'after_15_days') {
      return 15;
    }
    if (policy === 'after_7_days') {
      return 7;
    }
    if (policy === 'after_3_days') {
      return 3;
    }
    return 1;
  }
}
