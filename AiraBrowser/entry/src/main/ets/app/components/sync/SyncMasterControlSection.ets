import { SyncExperienceActionOutcome } from '../../../core/sync/SyncExperienceCoordinator';
import {
  resolveCenteredDialogControllerWidth,
  resolveCenteredDialogSurfaceColor,
  CENTERED_DIALOG_CORNER_RADIUS_VP,
  showCenteredAlertDialog
} from '../common/CenteredDialogSurface';
import {
  createDefaultSyncExperienceViewState,
  SyncExperienceViewState
} from '../../../core/sync/SyncExperienceViewModel';
import {
  SyncOperationProgressController,
  SyncOperationProgressUiState
} from '../../../core/sync/SyncOperationProgressController';
import { SyncSettingsRefreshSignal } from '../../../core/sync/SyncSettingsRefreshSignal';
import { SettingsColoredTileIconResources } from '../../../core/resources/SettingsColoredTileIconResources';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SETTINGS_ICON_FOREGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import {
  sharedPreferencesRepository,
  sharedSyncExperienceCoordinator
} from '../../bootstrap/BrowserAppRuntime';
import { BrowserThemeViewStateFactory } from '../../../core/theme/BrowserThemeViewState';
import {
  SettingsFooterText,
  SettingsGroupCard,
  SettingsSection
} from '../settings/SettingsLayout';
import { SettingsSwitchRow } from '../settings/SettingsRows';
import { SyncOperationProgressDialog } from './SyncOperationProgressDialog';

const DEFAULT_SYNC_EXPERIENCE_STATE: SyncExperienceViewState = createDefaultSyncExperienceViewState();

@Component
export struct SyncMasterControlSection {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string =
    DEFAULT_THEME_PALETTE.light.accent;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.pressedBackground;
  @StorageProp(BROWSER_THEME_STORAGE_SETTINGS_ICON_FOREGROUND_KEY) private storedSettingsIconForegroundColor: string =
    DEFAULT_THEME_PALETTE.light.settingsIconForeground;
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.surfaceBackground;
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string =
    DEFAULT_THEME_PALETTE.light.textPrimary;
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string =
    DEFAULT_THEME_PALETTE.light.textSecondary;
  @Prop isPrivateSession: boolean = false;
  @Prop pageBusy: boolean = false;
  @State private state: SyncExperienceViewState = DEFAULT_SYNC_EXPERIENCE_STATE;
  @State private isBusy: boolean = false;
  @State private progressTitle: ResourceStr = '';
  @State private progressSubtitle: ResourceStr = '';
  @State private progressValue: number = 0;
  @State private progressInProgress: boolean = false;
  @State private progressDetails: ResourceStr = '';
  @State private progressDetailOpacity: number = 1;
  private refreshRevision: number = 0;
  private progressDialogOpen: boolean = false;
  private refreshSignal: SyncSettingsRefreshSignal = new SyncSettingsRefreshSignal();
  private progressDialogController: CustomDialogController = new CustomDialogController({
    builder: SyncOperationProgressDialog({
      inProgress: $progressInProgress,
      title: $progressTitle,
      subtitle: $progressSubtitle,
      progress: $progressValue,
      details: $progressDetails,
      detailOpacity: $progressDetailOpacity
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('xs'),
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      if (!this.progressInProgress) {
        dismissDialogAction.dismiss();
      }
    }
  });
  private progressController: SyncOperationProgressController = new SyncOperationProgressController(
    (state: SyncOperationProgressUiState): void => {
      this.progressTitle = state.title;
      this.progressSubtitle = state.subtitle;
      this.progressValue = state.progress;
      this.progressInProgress = state.inProgress;
      this.progressDetails = state.details;
      this.progressDetailOpacity = state.detailOpacity;
    },
    (): boolean => this.progressDialogOpen,
    (): void => {
      this.openProgressDialog();
    },
    (): void => {
      this.closeProgressDialog();
    },
    (title: ResourceStr, subtitle: ResourceStr): void => {
      this.showDialog(title, subtitle);
    }
  );

  aboutToAppear(): void {
    this.refreshState();
  }

  private resolveMasterIconBackgroundColor(): ResourceColor {
    return new BrowserThemeViewStateFactory().build(
      sharedPreferencesRepository.getPreferences()
    ).settingsIconBackgrounds.syncMethod;
  }

  aboutToDisappear(): void {
    this.progressController.dispose();
  }

  build() {
    SettingsSection({
      title: $r('app.string.settings_sync_advanced_control'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        SettingsSwitchRow({
          title: $r('app.string.settings_sync_advanced_master'),
          checked: this.state.masterEnabled,
          icon: $r('sys.symbol.arrow_clockwise'),
          imageIcon: SettingsColoredTileIconResources.foregroundIcon('sync'),
          iconBackgroundColor: this.resolveMasterIconBackgroundColor(),
          iconColor: this.storedSettingsIconForegroundColor,
          rowPosition: 'single',
          isEnabled: this.state.hasConfiguredSync && !this.isPrivateSession && !this.pageBusy && !this.isBusy,
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          onChange: (enabled: boolean) => {
            this.requestMasterStateChange(enabled);
          }
        })
      }
      SettingsFooterText({
        text: $r('app.string.settings_sync_advanced_master_note'),
        secondaryTextColor: this.storedSecondaryTextColor
      })
    }
  }

  private requestMasterStateChange(enabled: boolean): void {
    if (enabled) {
      this.changeMasterState(true);
      return;
    }
    showCenteredAlertDialog({
      title: $r('app.string.settings_sync_advanced_turn_off_title'),
      message: $r('app.string.settings_sync_advanced_master_note'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_sync_advanced_keep'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_sync_advanced_confirm_off'),
        fontColor: this.storedAccentColor,
        action: () => {
          this.changeMasterState(false);
        }
      }
    });
  }

  private changeMasterState(enabled: boolean): void {
    if (this.isBusy || this.pageBusy || this.isPrivateSession) {
      return;
    }
    this.isBusy = true;
    this.progressController.begin(
      enabled
        ? $r('app.string.settings_sync_advanced_turning_on')
        : $r('app.string.settings_sync_advanced_turning_off'),
      enabled
        ? $r('app.string.settings_sync_advanced_restoring')
        : $r('app.string.settings_sync_advanced_saving_state'),
      'sync'
    );
    sharedSyncExperienceCoordinator.setMasterEnabled(enabled)
      .then((outcome: SyncExperienceActionOutcome) => {
        if (outcome.type === 'completed') {
          this.progressController.finish(outcome.title, outcome.message, undefined, false);
          return;
        }
        this.progressController.complete();
        this.showDialog(outcome.title, outcome.message);
      })
      .catch((_error: Error) => {
        this.progressController.complete();
        this.showDialog(
          $r('app.string.settings_sync_advanced_unchanged'),
          $r('app.string.settings_sync_advanced_unchanged_message')
        );
      })
      .finally(() => {
        this.isBusy = false;
        this.refreshSignal.bump();
        this.refreshState();
      });
  }

  private refreshState(): void {
    const revision = ++this.refreshRevision;
    sharedSyncExperienceCoordinator.load()
      .then((state: SyncExperienceViewState) => {
        if (revision === this.refreshRevision) {
          this.state = state;
        }
      })
      .catch((_error: Error) => undefined);
  }

  private showDialog(title: ResourceStr, message: ResourceStr): void {
    showCenteredAlertDialog({
      title: title,
      message: message,
      confirm: { value: $r('app.string.settings_pro_got_it'), action: () => {} }
    });
  }

  private openProgressDialog(): void {
    if (this.progressDialogOpen) {
      return;
    }
    this.progressDialogOpen = true;
    this.progressDialogController.open();
  }

  private closeProgressDialog(): void {
    if (!this.progressDialogOpen) {
      return;
    }
    this.progressDialogOpen = false;
    this.progressDialogController.close();
  }
}
