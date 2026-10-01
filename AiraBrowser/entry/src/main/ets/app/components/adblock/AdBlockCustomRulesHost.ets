import { common } from '@kit.AbilityKit';
import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import {
  resolveCenteredDialogControllerWidth,
  CENTERED_DIALOG_CORNER_RADIUS_VP,
  CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER,
  resolveCenteredDialogSurfaceColor,
  showCenteredAlertDialog
} from '../common/CenteredDialogSurface';
import {
  AdBlockCustomRulesScreen,
  AdBlockGithubRuleDialog
} from './AdBlockCustomRulesScreen';
import {
  AdBlockSettingsViewModel,
  AdBlockSettingsViewState
} from '../../../core/adblock/AdBlockSettingsViewModel';
import {
  AdBlockRuleSourceCoordinator,
  AdBlockRuleSourceResult,
  AdBlockThirdPartyRuleConsent
} from '../../../core/adblock/AdBlockRuleSourceCoordinator';
import {
  AdBlockSettingsBoundary,
  AdBlockSettingsCoordinator,
  AdBlockSettingsMutationResult
} from '../../../core/adblock/AdBlockSettingsCoordinator';
import {
  AdBlockPreferences
} from '../../../common/models/BrowserModels';
import {
  sharedAdBlockRepository,
  sharedAdBlockRuntimeGenerationCoordinator,
  sharedPreferencesRepository
} from '../../bootstrap/BrowserAppRuntime';
import { AppServiceModeGateService } from '../../../services/settings/AppServiceModeGateService';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';

@CustomDialog
struct AdBlockRuleImportProgressDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Link title: string;
  @Link subtitle: string;
  controller?: CustomDialogController;

  build() {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(this.storedAccentColor)

      Text(this.title.length > 0 ? this.title : resolveAppResourceText($r('app.string.settings_advanced_backup_exporting')))
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)

      Text(this.subtitle.length > 0 ? this.subtitle : resolveAppResourceText($r('app.string.settings_sync_please_wait')))
        .fontSize(14)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .fontColor(this.storedSecondaryTextColor)
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }
}

/**
 * 自定义规则页的共享主体：手机端由 AdBlockCustomRulesPage 全屏承载，大屏端由设置
 * 工作区就地承载。边界通过 @Prop 传入，返回通过 onBack 回调（手机=路由返回，大屏=回上一层）。
 */
@Component
export struct AdBlockCustomRulesHost {
  private viewModel: AdBlockSettingsViewModel = new AdBlockSettingsViewModel();
  private coordinator: AdBlockRuleSourceCoordinator = new AdBlockRuleSourceCoordinator(sharedAdBlockRepository);
  private settingsCoordinator: AdBlockSettingsCoordinator = new AdBlockSettingsCoordinator(
    sharedAdBlockRepository,
    sharedAdBlockRuntimeGenerationCoordinator
  );
  private appServiceModeGateService: AppServiceModeGateService =
    new AppServiceModeGateService(sharedPreferencesRepository);
  @Prop dataScope: string = '';
  @Prop privacyMode: string = '';
  @Prop boundarySource: string = '';
  @Prop embedded: boolean = false;
  @Prop desktopPresentation: boolean = false;
  onBack?: () => void;
  private githubRuleDialogController: CustomDialogController = new CustomDialogController({
    builder: AdBlockGithubRuleDialog({
      ruleUrl: $githubRuleUrl,
      confirm: () => {
        this.addGithubRuleSource();
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('s'),
  });
  private ruleImportDialogOpen: boolean = false;
  private ruleImportDialogController: CustomDialogController = new CustomDialogController({
    builder: AdBlockRuleImportProgressDialog({
      title: $ruleImportTitle,
      subtitle: $ruleImportSubtitle
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('xs'),
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      if (!this.ruleImportInProgress) {
        dismissDialogAction.dismiss();
      }
    }
  });
  @State private githubRuleUrl: string = '';
  @State private ruleImportTitle: string = '';
  @State private ruleImportSubtitle: string = '';
  @State private ruleImportInProgress: boolean = false;
  @State private state: AdBlockSettingsViewState =
    this.viewModel.buildState(sharedAdBlockRepository.getSettings());

  aboutToAppear(): void {
    this.refreshState();
  }

  build() {
    AdBlockCustomRulesScreen({
      sources: this.state.customRuleSources,
      adBlockEnabled: this.state.enabled,
      updateOnForeground: this.state.updateOnForeground,
      dataScope: this.dataScope,
      privacyMode: this.privacyMode,
      useTopSafeInset: !this.embedded,
      desktopPresentation: this.desktopPresentation,
      onImportLocal: () => {
        this.importLocalRuleSource();
      },
      onOpenGithubDialog: () => {
        this.openGithubRuleDialog();
      },
      onUpdateOnForegroundChange: (enabled: boolean) => {
        void this.updatePreference('updateOnForeground', enabled);
      },
      onRefreshSource: (sourceId: string) => {
        this.refreshRuleSource(sourceId);
      },
      onRemoveSource: (sourceId: string) => {
        this.confirmRemoveRuleSource(sourceId);
      },
      onSourceEnabledChange: (sourceId: string, enabled: boolean) => {
        this.setRuleSourceEnabled(sourceId, enabled);
      },
      onBack: () => {
        this.onBack?.();
      }
    })
      .width('100%')
      .height('100%')
  }

  private refreshState(): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.state = this.viewModel.buildState(sharedAdBlockRepository.getSettings());
  }

  private async updatePreference(key: 'updateOnForeground', enabled: boolean): Promise<void> {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    const current = sharedAdBlockRepository.getSettings().preferences;
    const nextPreferences: AdBlockPreferences = this.viewModel.buildPreferencesPatch(current, key, enabled);
    const previousState = this.state;
    const currentSettings = sharedAdBlockRepository.getSettings();
    this.state = this.viewModel.buildState({
      preferences: nextPreferences,
      siteExceptions: currentSettings.siteExceptions,
      customRuleSources: currentSettings.customRuleSources,
      stats: currentSettings.stats,
      lastRuleUpdateAt: currentSettings.lastRuleUpdateAt,
      engineUnavailableReason: currentSettings.engineUnavailableReason,
      updatedAt: currentSettings.updatedAt
    });
    this.settingsCoordinator.updatePreferences(nextPreferences, this.buildSettingsBoundary())
      .then((result: AdBlockSettingsMutationResult) => {
        if (!result.allowed) {
          this.state = previousState;
          this.showToast(resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_003')));
          return;
        }
        this.state = this.viewModel.buildState(result.settings);
      })
      .catch((_error: Error) => {
        this.state = previousState;
        this.showToast(resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_004')));
      });
  }

  private importLocalRuleSource(): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    if (this.ruleImportInProgress) {
      return;
    }
    this.coordinator.pickLocalRuleFile(this.getPickerContext())
      .then((uri: string | undefined) => {
        if (uri === undefined || uri.length === 0) {
          return undefined;
        }
        this.beginRuleImportOperation(
          resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_007')),
          resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_010'))
        );
        return this.coordinator.importLocalSource(uri, this.buildSettingsBoundary());
      })
      .then((result: AdBlockRuleSourceResult | undefined) => {
        if (result === undefined) {
          return;
        }
        this.completeRuleImportOperation();
        this.applyResult(result);
      })
      .catch((error: Error) => {
        this.completeRuleImportOperation();
        this.showToast(this.stringifyError(error));
      });
  }

  private openGithubRuleDialog(): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.githubRuleUrl = '';
    this.githubRuleDialogController.open();
  }

  private addGithubRuleSource(): void {
    if (this.ruleImportInProgress) {
      return;
    }
    const url = this.githubRuleUrl.trim();
    if (url.length === 0) {
      this.showToast(resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_014')));
      return;
    }
    this.importGithubRuleSource(url);
  }

  private importGithubRuleSource(url: string): void {
    this.beginRuleImportOperation(
      resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_008')),
      resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_005'))
    );
    this.coordinator.addSource(url, this.buildSettingsBoundary())
      .then((result: AdBlockRuleSourceResult) => {
        this.githubRuleUrl = '';
        this.completeRuleImportOperation();
        this.applyResult(result);
      })
      .catch((error: Error) => {
        this.completeRuleImportOperation();
        this.showToast(this.stringifyError(error));
      });
  }

  private refreshRuleSource(sourceId: string): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    if (this.ruleImportInProgress) {
      return;
    }
    this.beginRuleImportOperation(
      resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_009')),
      resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_011'))
    );
    this.coordinator.refreshSource(sourceId, this.buildSettingsBoundary())
      .then((result: AdBlockRuleSourceResult) => {
        this.completeRuleImportOperation();
        this.applyResult(result);
      })
      .catch((error: Error) => {
        this.completeRuleImportOperation();
        this.showToast(this.stringifyError(error));
      });
  }

  private setRuleSourceEnabled(sourceId: string, enabled: boolean): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    if (this.ruleImportInProgress) {
      this.refreshState();
      return;
    }
    if (enabled) {
      const consent = this.coordinator.buildThirdPartyPresetConsent(sourceId);
      if (consent !== undefined) {
        this.refreshState();
        this.showThirdPartyPresetConsent(consent);
        return;
      }
    }
    this.persistRuleSourceEnabled(sourceId, enabled);
  }

  private showThirdPartyPresetConsent(consent: AdBlockThirdPartyRuleConsent): void {
    showCenteredAlertDialog({
      title: consent.title,
      message: consent.message,
      autoCancel: true,
      primaryButton: {
        value: consent.cancelLabel,
        action: () => {
          this.refreshState();
        }
      },
      secondaryButton: {
        value: consent.acceptLabel,
        action: () => {
          this.downloadAndEnableThirdPartyPreset(consent);
        }
      }
    });
  }

  private downloadAndEnableThirdPartyPreset(consent: AdBlockThirdPartyRuleConsent): void {
    if (this.ruleImportInProgress) {
      this.refreshState();
      return;
    }
    this.beginRuleImportOperation(
      resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_006')),
      resolveAppResourceText($r('app.string.adblock_downloading_named', consent.sourceTitle))
    );
    this.coordinator.downloadAndEnableThirdPartyPreset(consent.sourceId, this.buildSettingsBoundary())
      .then((result: AdBlockRuleSourceResult) => {
        this.completeRuleImportOperation();
        this.state = this.viewModel.buildState(result.settings);
        if (!result.success) {
          this.showRuleDownloadFailure(consent.sourceTitle, result.message);
          return;
        }
        this.showToast(result.message);
      })
      .catch((error: Error) => {
        this.completeRuleImportOperation();
        this.refreshState();
        this.showRuleDownloadFailure(consent.sourceTitle, this.stringifyError(error));
      });
  }

  private persistRuleSourceEnabled(sourceId: string, enabled: boolean): void {
    this.coordinator.setSourceEnabled(sourceId, enabled, this.buildSettingsBoundary())
      .then((result: AdBlockRuleSourceResult) => {
        this.applyResult(result);
      })
      .catch((error: Error) => {
        this.showToast(this.stringifyError(error));
      });
  }

  private confirmRemoveRuleSource(sourceId: string): void {
    showCenteredAlertDialog({
      title: $r('app.string.adblock_ui_ad_block_custom_rules_host_002'),
      message: $r('app.string.adblock_ui_ad_block_custom_rules_host_001'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_custom_home_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_delete'),
        fontColor: $r('app.color.permission_blocked'),
        action: () => {
          this.removeRuleSource(sourceId);
        }
      }
    });
  }

  private removeRuleSource(sourceId: string): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.coordinator.removeSource(sourceId, this.buildSettingsBoundary())
      .then((result: AdBlockRuleSourceResult) => {
        this.applyResult(result);
      })
      .catch((error: Error) => {
        this.showToast(this.stringifyError(error));
      });
  }

  private applyResult(result: AdBlockRuleSourceResult): void {
    this.state = this.viewModel.buildState(result.settings);
    this.showToast(result.message);
  }

  private buildSettingsBoundary(): AdBlockSettingsBoundary {
    return new AdBlockSettingsBoundary(this.dataScope, this.privacyMode);
  }

  private getPickerContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private showToast(message: string): void {
    if (message.trim().length === 0) {
      return;
    }
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: 1800
    });
  }

  private showDialog(title: string, message: string): void {
    showCenteredAlertDialog({
      title: title,
      message: message,
      autoCancel: true,
      confirm: {
        value: $r('app.string.settings_advanced_backup_confirm'),
        action: () => {
        }
      }
    });
  }

  private showRuleDownloadFailure(sourceTitle: string, detail: string): void {
    const detailText = detail.trim().length > 0 ? `\n\n${detail.trim()}` : '';
    this.showDialog(
      resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_013')),
      resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_015', sourceTitle, detailText))
    );
  }

  private beginRuleImportOperation(title: string, subtitle: string): void {
    this.ruleImportTitle = title;
    this.ruleImportSubtitle = subtitle;
    this.ruleImportInProgress = true;
    this.openRuleImportDialog();
  }

  private completeRuleImportOperation(): void {
    this.ruleImportInProgress = false;
    this.closeRuleImportDialog();
  }

  private openRuleImportDialog(): void {
    if (this.ruleImportDialogOpen) {
      return;
    }
    this.ruleImportDialogOpen = true;
    this.ruleImportDialogController.open();
  }

  private closeRuleImportDialog(): void {
    if (!this.ruleImportDialogOpen) {
      return;
    }
    this.ruleImportDialogOpen = false;
    this.ruleImportDialogController.close();
  }

  private stringifyError(error: Error): string {
    if (error.message !== undefined && error.message.length > 0) {
      return error.message;
    }
    return resolveAppResourceText($r('app.string.adblock_ui_ad_block_custom_rules_host_012'));
  }

  private ensureOptionalServiceRoute(): boolean {
    if (this.appServiceModeGateService.canUseOptionalService()) {
      return true;
    }
    this.onBack?.();
    return false;
  }
}
