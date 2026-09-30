import promptAction from '@ohos.promptAction';
import { showCenteredAlertDialog } from '../common/CenteredDialogSurface';
import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import { ManualElementHideSiteRulesScreen } from './ManualElementHideSiteRulesScreen';
import {
  ManualElementHideSettingsViewModel,
  ManualElementHideSiteRulesViewState
} from '../../../core/adblock/ManualElementHideSettingsViewModel';
import {
  sharedManualElementHideRepository,
  sharedPreferencesRepository
} from '../../bootstrap/BrowserAppRuntime';
import {
  BrowserThemeViewState,
  BrowserThemeViewStateFactory
} from '../../../core/theme/BrowserThemeViewState';
import { AppServiceModeGateService } from '../../../services/settings/AppServiceModeGateService';
import {
  ManualElementHideSettingsBoundary,
  ManualElementHideSettingsCoordinator,
  ManualElementHideSettingsMutationResult
} from '../../../core/adblock/ManualElementHideSettingsCoordinator';

@Component
export struct ManualElementHideSiteRulesHost {
  private viewModel: ManualElementHideSettingsViewModel = new ManualElementHideSettingsViewModel();
  private themeViewStateFactory: BrowserThemeViewStateFactory = new BrowserThemeViewStateFactory();
  private appServiceModeGateService: AppServiceModeGateService =
    new AppServiceModeGateService(sharedPreferencesRepository);
  private settingsCoordinator: ManualElementHideSettingsCoordinator =
    new ManualElementHideSettingsCoordinator(sharedManualElementHideRepository);
  private themePreferencesListenerKey: string = '';
  @Prop host: string = '';
  @Prop dataScope: string = '';
  @Prop privacyMode: string = '';
  @Prop boundarySource: string = '';
  @Prop embedded: boolean = false;
  @Prop desktopPresentation: boolean = false;
  onBack: () => void = () => {};
  onSiteRemoved: () => void = () => {};
  onRulesChanged: () => void = () => {};
  @State private state: ManualElementHideSiteRulesViewState =
    this.viewModel.buildSiteState(sharedManualElementHideRepository.getSettings(), '');
  @State private theme: BrowserThemeViewState =
    this.themeViewStateFactory.build(sharedPreferencesRepository.getPreferences());

  aboutToAppear(): void {
    this.bindThemePreferencesUpdates();
    this.refreshState();
  }

  aboutToDisappear(): void {
    this.unbindThemePreferencesUpdates();
  }

  build() {
    ManualElementHideSiteRulesScreen({
      state: this.state,
      dataScope: this.dataScope,
      privacyMode: this.privacyMode,
      useTopSafeInset: !this.embedded,
      desktopPresentation: this.desktopPresentation,
      pageBackground: this.theme.pageBackground,
      surfaceBackground: this.theme.surfaceBackground,
      pressedBackground: this.theme.pressedBackground,
      dividerColor: this.theme.divider,
      primaryTextColor: this.theme.textPrimary,
      secondaryTextColor: this.theme.textSecondary,
      onSiteEnabledChange: (host: string, enabled: boolean) => {
        this.updateSiteEnabled(host, enabled);
      },
      onDeleteRule: (host: string, ruleId: string, selector: string) => {
        this.confirmDeleteRule(host, ruleId, selector);
      },
      onClearSite: (host: string) => {
        this.confirmClearSite(host);
      },
      onBack: () => {
        this.onBack();
      }
    })
      .width('100%')
      .height('100%')
  }

  private refreshState(): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.refreshThemeState();
    this.refreshRules();
  }

  private refreshRules(): void {
    const nextState = this.viewModel.buildSiteState(sharedManualElementHideRepository.getSettings(), this.host);
    this.state = nextState;
    if (!nextState.hasRules) {
      this.onSiteRemoved();
    }
  }

  private refreshThemeState(): void {
    this.theme = this.themeViewStateFactory.build(sharedPreferencesRepository.getPreferences());
  }

  private bindThemePreferencesUpdates(): void {
    if (this.themePreferencesListenerKey.length > 0) {
      return;
    }
    this.themePreferencesListenerKey = sharedPreferencesRepository.subscribe((_preferences, scope) => {
      if (scope === 'theme_mode' || scope === 'appearance') {
        this.refreshThemeState();
      }
    });
  }

  private unbindThemePreferencesUpdates(): void {
    if (this.themePreferencesListenerKey.length <= 0) {
      return;
    }
    sharedPreferencesRepository.unsubscribe(this.themePreferencesListenerKey);
    this.themePreferencesListenerKey = '';
  }

  private updateSiteEnabled(host: string, enabled: boolean): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.settingsCoordinator.setSiteEnabled(host, enabled, this.buildBoundary())
      .then((result: ManualElementHideSettingsMutationResult) => {
        this.refreshRules();
        if (!result.allowed) {
          this.showToast($r('app.string.element_hide_session_readonly'));
          return;
        }
        this.onRulesChanged();
      })
      .catch((_error: Error) => {
        this.refreshRules();
        this.showToast($r('app.string.element_hide_update_failed'));
      });
  }

  private confirmDeleteRule(host: string, ruleId: string, selector: string): void {
    showCenteredAlertDialog({
      title: resolveAppResourceText($r('app.string.element_hide_delete_rule_title')),
      message: resolveAppResourceText($r('app.string.element_hide_delete_rule_message', selector)),
      autoCancel: true,
      primaryButton: {
        value: resolveAppResourceText($r('app.string.element_hide_dialog_cancel')),
        action: () => {
        }
      },
      secondaryButton: {
        value: resolveAppResourceText($r('app.string.element_hide_dialog_delete')),
        fontColor: $r('app.color.permission_blocked'),
        action: () => {
          this.deleteRule(host, ruleId);
        }
      }
    });
  }

  private deleteRule(host: string, ruleId: string): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.settingsCoordinator.removeRule(host, ruleId, this.buildBoundary())
      .then((result: ManualElementHideSettingsMutationResult) => {
        this.refreshRules();
        if (!result.allowed) {
          this.showToast($r('app.string.element_hide_session_readonly'));
          return;
        }
        this.onRulesChanged();
        this.showToast(result.changed
          ? $r('app.string.element_hide_deleted')
          : $r('app.string.element_hide_rule_not_found'));
      })
      .catch((_error: Error) => {
        this.refreshRules();
        this.showToast($r('app.string.element_hide_delete_failed'));
      });
  }

  private confirmClearSite(host: string): void {
    showCenteredAlertDialog({
      title: resolveAppResourceText($r('app.string.element_hide_clear_site_title')),
      message: resolveAppResourceText($r('app.string.element_hide_clear_site_message', host)),
      autoCancel: true,
      primaryButton: {
        value: resolveAppResourceText($r('app.string.element_hide_dialog_cancel')),
        action: () => {
        }
      },
      secondaryButton: {
        value: resolveAppResourceText($r('app.string.element_hide_dialog_clear')),
        fontColor: $r('app.color.permission_blocked'),
        action: () => {
          this.clearSite(host);
        }
      }
    });
  }

  private clearSite(host: string): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.settingsCoordinator.clearSite(host, this.buildBoundary())
      .then((result: ManualElementHideSettingsMutationResult) => {
        if (!result.allowed) {
          this.refreshRules();
          this.showToast($r('app.string.element_hide_session_readonly'));
          return;
        }
        this.onRulesChanged();
        if (result.changed) {
          this.onSiteRemoved();
        } else {
          this.refreshRules();
        }
        this.showToast(result.changed
          ? $r('app.string.element_hide_cleared')
          : $r('app.string.element_hide_site_not_found'));
      })
      .catch((_error: Error) => {
        this.refreshRules();
        this.showToast($r('app.string.element_hide_clear_failed'));
      });
  }

  private showToast(message: ResourceStr): void {
    promptAction.showToast({
      message: message,
      duration: 1800
    });
  }

  private buildBoundary(): ManualElementHideSettingsBoundary {
    return {
      dataScope: this.dataScope,
      privacyMode: this.privacyMode
    };
  }

  private ensureOptionalServiceRoute(): boolean {
    if (this.appServiceModeGateService.canUseOptionalService()) {
      return true;
    }
    this.onBack();
    return false;
  }
}
