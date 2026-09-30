import { DEFAULT_THEME_PALETTE } from '../../features/theme/palettes/DefaultThemePalette';
import {
  BrowserGeneralSettings,
  BrowserPrivateTabRestorePolicy
} from '../../common/models/BrowserModels';
import {
  GeneralPrivateTabsSettingsState,
  GeneralPrivateTabsSettingsViewModel
} from '../../core/settings/GeneralPrivateTabsSettingsViewModel';
import { sharedPreferencesRepository } from '../bootstrap/BrowserAppRuntime';
import { SettingsOptionRow, SettingsSwitchRow } from '../components/settings/SettingsRows';
import { SettingsHdsScaffold } from '../components/settings/SettingsHdsScaffold';
import { resolveCenteredDialogControllerWidth,  resolveCenteredDialogSurfaceColor, CENTERED_DIALOG_CORNER_RADIUS_VP } from '../components/common/CenteredDialogSurface';
import {
  SettingsGroupCard,
  SettingsGroupDivider,
  SettingsScrollBody,
  SettingsSection
} from '../components/settings/SettingsLayout';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../core/theme/BrowserThemeStorageKeys';
import { SettingsNavigationCoordinator } from '../router/SettingsNavigationCoordinator';
import { AlwaysPrivateModeConfirmationDialog } from '../components/settings/AlwaysPrivateModeConfirmationDialog';
import { readBrowserBoundaryRouteState } from '../../common/utils/RouteParamUtils';
import { SettingsDetailInteractionCoordinator } from '../../core/settings/SettingsDetailInteractionCoordinator';

@Entry
@Component
struct GeneralPrivateTabsSettingsPage {
  private navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private viewModel: GeneralPrivateTabsSettingsViewModel = new GeneralPrivateTabsSettingsViewModel();
  private interactionCoordinator: SettingsDetailInteractionCoordinator =
    new SettingsDetailInteractionCoordinator(sharedPreferencesRepository);
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @State private generalSettings: BrowserGeneralSettings = sharedPreferencesRepository.getPreferences().general;
  @State private state: GeneralPrivateTabsSettingsState = this.viewModel.buildState(
    sharedPreferencesRepository.getPreferences().general
  );
  @State private alwaysPrivateConfirmationAccepted: boolean = false;
  @State private dataScope: string = '';
  @State private privacyMode: string = '';
  @State private boundarySource: string = '';
  private alwaysPrivateConfirmationDialogController: CustomDialogController = new CustomDialogController({
    builder: AlwaysPrivateModeConfirmationDialog({
      accepted: $alwaysPrivateConfirmationAccepted,
      onCancel: () => {
        this.alwaysPrivateConfirmationAccepted = false;
      },
      onConfirm: () => {
        this.alwaysPrivateConfirmationAccepted = false;
        this.updateAlwaysUsePrivateModeConfirmed(true);
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('s'),
  });

  aboutToAppear(): void {
    this.syncBoundaryRouteState();
    this.refreshState();
  }

  build() {
    Column() {
      SettingsHdsScaffold({
        title: $r('app.string.settings_privacy_restore_tabs'),
        backIconKind: 'back',
        pageBackground: this.storedPageBackgroundColor,
        headerButtonBackground: this.storedPressedBackgroundColor,
        primaryTextColor: this.storedPrimaryTextColor,
        dividerColor: this.storedDividerColor,
        onBack: () => {
          this.navigationCoordinator.back();
        }
      }) {
        SettingsScrollBody({ topPadding: 16, bottomPadding: 32 }) {
          this.buildAlwaysPrivateSection()
          this.buildRestoreSection()
          this.buildDataSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
  }

  @Builder
  private buildAlwaysPrivateSection() {
    SettingsSection({
      title: $r('app.string.settings_privacy_mode_default'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        SettingsSwitchRow({
          title: $r('app.string.settings_always_private_title'),
          checked: this.state.alwaysUsePrivateMode,
          rowPosition: 'single',
          onChange: (checked: boolean) => {
            this.updateAlwaysUsePrivateMode(checked);
          }
        })
      }

      Text($r('app.string.settings_privacy_always_note'))
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.storedSecondaryTextColor)
        .padding({ left: 6, right: 6 })
    }
  }

  @Builder
  private buildDataSection() {
    SettingsSection({
      title: $r('app.string.settings_site_customization_fragment_clear_on_close'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        SettingsSwitchRow({
          title: $r('app.string.settings_site_customization_keep_cookies'),
          checked: this.state.preserveCookiesOnClose,
          rowPosition: 'single',
          onChange: (checked: boolean) => {
            this.updatePreserveCookiesOnClose(checked);
          }
        })
      }

      Text(this.state.preserveCookiesOnClose
        ? $r('app.string.settings_privacy_cookies_kept')
        : $r('app.string.settings_privacy_cookies_cleared'))
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.storedSecondaryTextColor)
        .padding({ left: 6, right: 6 })
    }
  }

  @Builder
  private buildRestoreSection() {
    SettingsSection({
      title: $r('app.string.settings_privacy_restore_section'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        SettingsOptionRow({
          title: $r('app.string.settings_privacy_never_restore'),
          helperText: $r('app.string.settings_privacy_never_restore_detail'),
          rowPosition: 'first',
          isSelected: this.state.restorePolicy === 'never_restore',
          selectedIndicatorColor: this.storedAccentColor,
          onAction: () => {
            this.updatePolicy('never_restore');
          }
        })
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsOptionRow({
          title: $r('app.string.settings_privacy_allow_restore'),
          helperText: $r('app.string.settings_privacy_allow_restore_detail'),
          rowPosition: 'last',
          isSelected: this.state.restorePolicy === 'restore_private_tabs',
          selectedIndicatorColor: this.storedAccentColor,
          onAction: () => {
            this.updatePolicy('restore_private_tabs');
          }
        })
      }
    }
  }

  private refreshState(): void {
    const preferences = sharedPreferencesRepository.getPreferences();
    this.generalSettings = preferences.general;
    this.state = this.viewModel.buildState(this.generalSettings);
  }

  private updatePolicy(policy: BrowserPrivateTabRestorePolicy): void {
    if (this.state.restorePolicy === policy) {
      return;
    }
    const previousSettings = this.generalSettings;
    const nextSettings = this.viewModel.buildGeneralSettingsWithRestorePolicy(this.generalSettings, policy);
    this.generalSettings = nextSettings;
    this.state = this.viewModel.buildState(this.generalSettings);
    this.interactionCoordinator.commitGeneralSettings({
      dataScope: this.dataScope,
      privacyMode: this.privacyMode
    }, nextSettings)
      .then((settings: BrowserGeneralSettings) => {
        this.generalSettings = settings;
        this.state = this.viewModel.buildState(this.generalSettings);
      })
      .catch((_error: Error) => {
        this.generalSettings = previousSettings;
        this.state = this.viewModel.buildState(this.generalSettings);
      });
  }

  private updateAlwaysUsePrivateMode(enabled: boolean): void {
    if (this.state.alwaysUsePrivateMode === enabled) {
      return;
    }
    if (enabled) {
      this.alwaysPrivateConfirmationAccepted = false;
      this.alwaysPrivateConfirmationDialogController.open();
      return;
    }
    this.updateAlwaysUsePrivateModeConfirmed(false);
  }

  private updateAlwaysUsePrivateModeConfirmed(enabled: boolean): void {
    if (this.state.alwaysUsePrivateMode === enabled) {
      return;
    }
    const previousSettings = this.generalSettings;
    const nextSettings = this.viewModel.buildGeneralSettingsWithAlwaysUsePrivateMode(this.generalSettings, enabled);
    this.generalSettings = nextSettings;
    this.state = this.viewModel.buildState(this.generalSettings);
    this.interactionCoordinator.commitGeneralSettings({
      dataScope: this.dataScope,
      privacyMode: this.privacyMode
    }, nextSettings)
      .then((settings: BrowserGeneralSettings) => {
        this.generalSettings = settings;
        this.state = this.viewModel.buildState(this.generalSettings);
      })
      .catch((_error: Error) => {
        this.generalSettings = previousSettings;
        this.state = this.viewModel.buildState(this.generalSettings);
      });
  }

  private updatePreserveCookiesOnClose(enabled: boolean): void {
    if (this.state.preserveCookiesOnClose === enabled) {
      return;
    }
    const previousSettings = this.generalSettings;
    const nextSettings = this.viewModel.buildGeneralSettingsWithPreserveCookiesOnClose(this.generalSettings, enabled);
    this.generalSettings = nextSettings;
    this.state = this.viewModel.buildState(this.generalSettings);
    this.interactionCoordinator.commitGeneralSettings({
      dataScope: this.dataScope,
      privacyMode: this.privacyMode
    }, nextSettings)
      .then((settings: BrowserGeneralSettings) => {
        this.generalSettings = settings;
        this.state = this.viewModel.buildState(this.generalSettings);
      })
      .catch((_error: Error) => {
        this.generalSettings = previousSettings;
        this.state = this.viewModel.buildState(this.generalSettings);
      });
  }

  private syncBoundaryRouteState(): void {
    const boundary = readBrowserBoundaryRouteState({
      dataScope: this.dataScope,
      privacyMode: this.privacyMode,
      boundarySource: this.boundarySource
    });
    this.dataScope = boundary.dataScope;
    this.privacyMode = boundary.privacyMode;
    this.boundarySource = boundary.boundarySource;
  }

}
