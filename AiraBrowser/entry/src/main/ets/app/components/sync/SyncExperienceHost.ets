import router from '@ohos.router';
import {
  resolveCenteredDialogControllerWidth,
  resolveCenteredDialogSurfaceColor,
  CENTERED_DIALOG_CORNER_RADIUS_VP,
  showCenteredAlertDialog
} from '../common/CenteredDialogSurface';
import {
  AiraBookmarkConflictResolution,
  AiraSyncProviderKind
} from '../../../common/models/AiraSyncModels';
import { PersonalizationSyncContentId } from '../../../common/models/PersonalizationSyncModels';
import { EntitlementDecision } from '../../../common/models/MembershipModels';
import {
  BrowserBoundaryRouteState,
  readBrowserBoundaryRouteState
} from '../../../common/utils/RouteParamUtils';
import {
  SyncExperienceActionOutcome
} from '../../../core/sync/SyncExperienceCoordinator';
import { SyncFirstActivationItemsState } from '../../../core/sync/SyncFirstActivationItemsCoordinator';
import {
  SyncOperationProgressController,
  SyncOperationProgressUiState
} from '../../../core/sync/SyncOperationProgressController';
import {
  createDefaultSyncExperienceViewState,
  SyncExperiencePreActiveStatusKind,
  SyncExperienceViewState
} from '../../../core/sync/SyncExperienceViewModel';
import { AppServiceModeGateService } from '../../../services/settings/AppServiceModeGateService';
import {
  sharedPreferencesRepository,
  sharedSyncExperienceCoordinator,
  sharedClientUpdatePolicyService
} from '../../bootstrap/BrowserAppRuntime';
import { SyncExperienceScreen } from './SyncExperienceScreen';
import { SyncAdditionalBackupHost } from './SyncAdditionalBackupHost';
import { SyncOperationProgressDialog } from './SyncOperationProgressDialog';
import { SyncExperienceLinesDialog } from './SyncExperienceLinesDialog';
import { SettingsNavigationCoordinator } from '../../router/SettingsNavigationCoordinator';
import { SystemSettingsLaunchService } from '../../../services/system/SystemSettingsLaunchService';
import { AppRuntimeContext } from '../../runtime/AppRuntimeContext';
import { SYNC_SETTINGS_REFRESH_REVISION_KEY } from '../../../core/sync/SyncSettingsRefreshSignal';
import { SettingsContentKind } from '../../../core/settings/SettingsContentLayoutPolicy';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_ON_ACCENT_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';

const DEFAULT_SYNC_EXPERIENCE_STATE: SyncExperienceViewState = createDefaultSyncExperienceViewState();

@Component
export struct SyncExperienceHost {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string =
    DEFAULT_THEME_PALETTE.light.accent;
  @StorageProp(BROWSER_THEME_STORAGE_ON_ACCENT_KEY) private storedOnAccentColor: string =
    DEFAULT_THEME_PALETTE.light.onAccent;
  private navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private systemSettingsLaunchService: SystemSettingsLaunchService = new SystemSettingsLaunchService();
  private appServiceModeGateService: AppServiceModeGateService =
    new AppServiceModeGateService(sharedPreferencesRepository);
  @StorageLink(SYNC_SETTINGS_REFRESH_REVISION_KEY) @Watch('refreshState')
  private syncSettingsRefreshRevision: number = 0;
  @State private boundary: BrowserBoundaryRouteState = {
    dataScope: '',
    privacyMode: '',
    boundarySource: ''
  };
  @State private state: SyncExperienceViewState = DEFAULT_SYNC_EXPERIENCE_STATE;
  @State private isBusy: boolean = false;
  @State private isSyncing: boolean = false;
  private hostVisible: boolean = false;
  @State private preActiveStatusKind: SyncExperiencePreActiveStatusKind = 'initial-loading';
  @State private activeSheetVisible: boolean = false;
  @State private desktopGuideNavigationActive: boolean = false;
  @State private syncProgressTitle: ResourceStr = '';
  @State private syncProgressSubtitle: ResourceStr = '';
  @State private syncProgressValue: number = 0;
  @State private syncProgressInProgress: boolean = false;
  @State private syncProgressDetailsText: ResourceStr = '';
  @State private syncProgressDetailOpacity: number = 1;
  private stateRefreshRevision: number = 0;
  private setupSelectionCommitted: boolean = false;
  @State private outcomeDialogTitle: ResourceStr = '';
  @State private outcomeDialogLines: ResourceStr[] = [];
  @State private outcomeDialogActionKind: string = 'confirm';
  private outcomeLinesDialogOpen: boolean = false;
  private outcomeLinesDialogController: CustomDialogController = new CustomDialogController({
    builder: SyncExperienceLinesDialog({
      title: $outcomeDialogTitle,
      lines: $outcomeDialogLines,
      actionKind: $outcomeDialogActionKind,
      onRetry: () => {
        this.closeOutcomeLinesDialog();
        this.syncNow();
      },
      onChangeMethod: () => {
        this.closeOutcomeLinesDialog();
        this.activeSheetVisible = true;
      },
      onDismiss: () => {
        this.closeOutcomeLinesDialog();
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('m'),
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      this.outcomeLinesDialogOpen = false;
      dismissDialogAction.dismiss();
    }
  });
  private syncProgressDialogOpen: boolean = false;
  private syncProgressDialogController: CustomDialogController = new CustomDialogController({
    builder: SyncOperationProgressDialog({
      inProgress: $syncProgressInProgress,
      title: $syncProgressTitle,
      subtitle: $syncProgressSubtitle,
      progress: $syncProgressValue,
      details: $syncProgressDetailsText,
      detailOpacity: $syncProgressDetailOpacity
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('xs'),
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      if (!this.syncProgressInProgress) {
        dismissDialogAction.dismiss();
      }
    }
  });
  private syncProgressController: SyncOperationProgressController = new SyncOperationProgressController(
    (state: SyncOperationProgressUiState): void => {
      this.syncProgressTitle = state.title;
      this.syncProgressSubtitle = state.subtitle;
      this.syncProgressValue = state.progress;
      this.syncProgressInProgress = state.inProgress;
      this.syncProgressDetailsText = state.details;
      this.syncProgressDetailOpacity = state.detailOpacity;
    },
    (): boolean => this.syncProgressDialogOpen,
    (): void => {
      this.openSyncProgressDialog();
    },
    (): void => {
      this.closeSyncProgressDialog();
    },
    (title: ResourceStr, subtitle: ResourceStr): void => {
      this.showDialog(title, subtitle);
    }
  );
  @Prop showBackButton: boolean = true;
  @Prop showTitleBar: boolean = true;
  @Prop useTopSafeInset: boolean = true;
  @Prop contentKind: SettingsContentKind = 'standard';
  @Prop useLargeScreenSelectionDialog: boolean = false;
  @Prop desktopPresentation: boolean = false;
  onExit?: () => void;
  onOpenAiraPro?: () => void;
  @State private syncWorkspaceView: 'overview' | 'additional_backup' = 'overview';

  aboutToAppear(): void {
    this.hostVisible = true;
    this.refreshState(true);
  }

  onPageShow(): void {
    this.hostVisible = true;
    if (this.desktopGuideNavigationActive) {
      this.desktopGuideNavigationActive = false;
      this.activeSheetVisible = true;
    }
    this.refreshState(true);
  }

  aboutToDisappear(): void {
    this.hostVisible = false;
    this.syncProgressController.dispose();
  }

  onBackPress(): boolean {
    return this.isBusy && !this.isSyncing;
  }

  build() {
    Column() {
      if (this.desktopPresentation && this.syncWorkspaceView === 'additional_backup') {
        SyncAdditionalBackupHost({
          desktopPresentation: true,
          dataScope: this.boundary.dataScope,
          privacyMode: this.boundary.privacyMode,
          boundarySource: 'sync_experience_backup',
          onBack: () => {
            this.syncWorkspaceView = 'overview';
            this.refreshState(true);
          }
        })
          .width('100%')
          .height('100%')
      } else {
        SyncExperienceScreen({
        state: this.state,
        isBusy: this.isBusy,
        isSyncing: this.isSyncing,
        preActiveStatusKind: this.preActiveStatusKind,
        isPrivateSession: this.boundary.privacyMode === 'private',
        activeSheetVisible: $activeSheetVisible,
        showBackButton: this.showBackButton,
        showTitleBar: this.showTitleBar,
        useTopSafeInset: this.useTopSafeInset,
        contentKind: this.contentKind,
        desktopPresentation: this.desktopPresentation,
        useLargeScreenSelectionDialog: this.useLargeScreenSelectionDialog,
        desktopGuideNavigationActive: this.desktopGuideNavigationActive,
        onBack: () => {
          this.exitSyncExperience();
        },
        onGoalSelected: (
          remoteKind: AiraSyncProviderKind,
          firstActivationItems?: SyncFirstActivationItemsState
        ) => {
          this.submitGoalSelection(remoteKind, firstActivationItems);
        },
        onSetupDismissed: () => {
          this.exitSyncExperience();
        },
        onBookmarkSelected: (enabled: boolean) => {
          this.changeBookmarkSelection(enabled);
        },
        onHistorySelected: (enabled: boolean) => {
          this.changeHistorySelection(enabled);
        },
        onPersonalizationItemSelected: (id: PersonalizationSyncContentId, enabled: boolean) => {
          this.changePersonalizationItemSelection(id, enabled);
        },
        onSyncNow: () => {
          this.syncNow();
        },
        onRetryStateLoad: () => {
          this.retryStateLoad();
        },
        onOpenAdditionalBackup: () => {
          if (this.desktopPresentation) {
            this.syncWorkspaceView = 'additional_backup';
            return;
          }
          this.navigationCoordinator.openSyncAdditionalBackup(this.buildBoundary('sync_experience_backup'));
        },
        onOpenAiraPro: () => {
          if (this.desktopPresentation && this.onOpenAiraPro !== undefined) {
            this.onOpenAiraPro();
            return;
          }
          this.navigationCoordinator.openAiraPro(this.buildBoundary('sync_experience_membership'));
        },
        onOpenAdvanced: () => {
          this.navigationCoordinator.openSyncAdvancedSettings(this.buildBoundary('sync_experience'));
        },
        onOpenDesktopGuide: (restoreSheet: boolean) => {
          this.desktopGuideNavigationActive = restoreSheet;
          this.navigationCoordinator.openSyncDesktopBookmarkGuide(
            this.buildBoundary('sync_experience_desktop_guide')
          );
        },
        onConfigureWebdav: (
          firstActivationItems?: SyncFirstActivationItemsState
        ) => {
          this.openWebdavConfiguration(firstActivationItems);
        }
      })
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  private refreshState(openRequiredSetup: boolean = false): void {
    if (!this.appServiceModeGateService.canUseOptionalService()) {
      this.navigationCoordinator.back();
      return;
    }
    const params = router.getParams() as Record<string, string | undefined> | undefined;
    this.boundary = readBrowserBoundaryRouteState({
      dataScope: params?.dataScope ?? this.boundary.dataScope,
      privacyMode: params?.privacyMode ?? this.boundary.privacyMode,
      boundarySource: params?.boundarySource ?? this.boundary.boundarySource
    });
    const refreshRevision = ++this.stateRefreshRevision;
    const mayOpenRequiredSetup = openRequiredSetup && !this.setupSelectionCommitted && !this.isBusy;
    sharedSyncExperienceCoordinator.load()
      .then((state: SyncExperienceViewState) => {
        if (refreshRevision !== this.stateRefreshRevision) {
          return;
        }
        this.state = state;
        if (state.hasConfiguredSync || !this.isBusy) {
          this.preActiveStatusKind = 'inactive';
        }
        if (mayOpenRequiredSetup && !this.setupSelectionCommitted && !this.isBusy && !state.hasConfiguredSync) {
          this.activeSheetVisible = true;
        }
      })
      .catch((_error: Error) => {
        if (refreshRevision !== this.stateRefreshRevision) {
          return;
        }
        this.preActiveStatusKind = this.preActiveStatusKind === 'huawei-activating'
          ? 'huawei-load-failed'
          : 'load-failed';
        if (mayOpenRequiredSetup && !this.setupSelectionCommitted && !this.isBusy) {
          this.activeSheetVisible = true;
        }
      });
  }

  private submitGoalSelection(
    remoteKind: AiraSyncProviderKind,
    firstActivationItems?: SyncFirstActivationItemsState
  ): void {
    if (!this.state.hasActiveProvider && firstActivationItems !== undefined) {
      this.setupSelectionCommitted = true;
      this.stateRefreshRevision += 1;
      this.activeSheetVisible = false;
    }
    this.changeGoal(remoteKind, false, firstActivationItems);
  }

  private openWebdavConfiguration(
    firstActivationItems?: SyncFirstActivationItemsState
  ): void {
    if (firstActivationItems === undefined) {
      this.navigationCoordinator.openSyncWebdavConfig(
        this.buildBoundary('sync_experience_webdav_provider'),
        'active'
      );
      return;
    }
    if (this.isBusy || this.boundary.privacyMode === 'private') {
      return;
    }
    this.setupSelectionCommitted = true;
    this.stateRefreshRevision += 1;
    this.activeSheetVisible = false;
    this.isBusy = true;
    sharedSyncExperienceCoordinator.requestFirstActivationWebdavConfiguration(firstActivationItems)
      .then((outcome: SyncExperienceActionOutcome) => {
        this.renderOutcome(outcome);
      })
      .finally(() => {
        this.isBusy = false;
        this.refreshState();
      });
  }

  private exitSyncExperience(): void {
    this.hostVisible = false;
    if (this.onExit !== undefined) {
      this.onExit();
      return;
    }
    this.navigationCoordinator.back();
  }

  private changeGoal(
    remoteKind: AiraSyncProviderKind,
    confirmed: boolean,
    firstActivationItems?: SyncFirstActivationItemsState
  ): void {
    if (this.isBusy || this.boundary.privacyMode === 'private') {
      return;
    }
    if (remoteKind === 'self_hosted' && this.state.hasActiveProvider &&
      this.state.goalOptions.some((option): boolean => option.id === 'self_hosted' && option.isSelected)) {
      this.navigationCoordinator.openSyncPersonalServerConfig(
        this.buildBoundary('sync_experience_personal_server')
      );
      return;
    }
    this.isBusy = true;
    const silentFirstActivation = !this.state.hasActiveProvider;
    if (!silentFirstActivation) {
      this.syncProgressController.begin(
        $r('app.string.settings_sync_changing'),
        $r('app.string.settings_sync_changing_detail'),
        'sync'
      );
    }
    sharedSyncExperienceCoordinator.requestGoalChange(remoteKind, confirmed, firstActivationItems)
      .then((outcome: SyncExperienceActionOutcome) => {
        if (silentFirstActivation) {
          if (outcome.type !== 'completed') {
            this.renderOutcome(outcome);
          }
          return;
        }
        this.completeProgressOutcome(outcome);
      })
      .finally(() => {
        this.isBusy = false;
        this.refreshState();
      });
  }

  private retryStateLoad(): void {
    if (this.isBusy) {
      return;
    }
    this.preActiveStatusKind = this.preActiveStatusKind === 'huawei-load-failed'
      ? 'huawei-activating'
      : 'initial-loading';
    this.refreshState();
  }

  private syncNow(): void {
    if (this.isBusy || this.boundary.privacyMode === 'private') {
      return;
    }
    this.isBusy = true;
    this.isSyncing = true;
    // Ordinary sync runs in the shared owner; keep scrolling and navigation available.
    // isBusy still prevents repeat requests and provider/content changes during this run.
    sharedSyncExperienceCoordinator.syncNow()
      .then((outcome: SyncExperienceActionOutcome) => {
        if (this.hostVisible && outcome.type !== 'completed') {
          this.renderOutcome(outcome);
        }
      })
      .finally(() => {
        this.isSyncing = false;
        this.isBusy = false;
        if (this.hostVisible) {
          this.refreshState();
        }
      });
  }

  private changeBookmarkSelection(enabled: boolean): void {
    if (this.isBusy || this.boundary.privacyMode === 'private') {
      return;
    }
    this.isBusy = true;
    if (!enabled) {
      this.syncProgressController.begin(
        $r('app.string.settings_sync_pausing_bookmarks'),
        $r('app.string.settings_sync_pausing_bookmarks_detail'),
        'sync'
      );
    }
    sharedSyncExperienceCoordinator.setBookmarkSelected(enabled)
      .then((outcome: SyncExperienceActionOutcome) => {
        if (enabled) {
          if (outcome.type !== 'completed') {
            this.renderOutcome(outcome);
          }
          return;
        }
        this.completeProgressOutcome(outcome);
      })
      .finally(() => {
        this.isBusy = false;
        this.refreshState();
      });
  }

  private changeHistorySelection(enabled: boolean): void {
    if (this.isBusy || this.boundary.privacyMode === 'private' || !this.state.historySupported) {
      return;
    }
    this.isBusy = true;
    sharedSyncExperienceCoordinator.setHistorySelected(enabled)
      .then((outcome: SyncExperienceActionOutcome) => {
        if (outcome.type !== 'completed') {
          this.renderOutcome(outcome);
        }
      })
      .finally(() => {
        this.isBusy = false;
        this.refreshState();
      });
  }

  private changePersonalizationItemSelection(id: PersonalizationSyncContentId, enabled: boolean): void {
    if (this.isBusy || this.boundary.privacyMode === 'private') {
      return;
    }
    const changesHiddenDomain = this.state.masterEnabled && (
      (enabled && !this.state.personalizationSelected) ||
      (!enabled && this.state.personalizationSelected && this.state.enabledPersonalizationItemCount === 1)
    );
    this.isBusy = true;
    if (changesHiddenDomain && !enabled) {
      this.syncProgressController.begin(
        $r('app.string.settings_sync_saving_content'),
        $r('app.string.settings_sync_saving_content_detail'),
        'sync'
      );
    }
    sharedSyncExperienceCoordinator.setPersonalizationItemSelected(id, enabled)
      .then((outcome: SyncExperienceActionOutcome) => {
        if (changesHiddenDomain && !enabled) {
          this.completeProgressOutcome(outcome);
        } else if (outcome.type !== 'completed') {
          this.renderOutcome(outcome);
        }
      })
      .finally(() => {
        this.isBusy = false;
        this.refreshState();
      });
  }

  private completeProgressOutcome(outcome: SyncExperienceActionOutcome): void {
    if (outcome.type === 'completed') {
      this.syncProgressController.finish(outcome.title, outcome.message, () => {
        if (this.hasMultipleOutcomeLines(outcome)) {
          this.showMultipleOutcomeLines(outcome, 'confirm');
        }
      }, false);
      return;
    }
    this.syncProgressController.fail(outcome.title, outcome.message);
    this.renderOutcome(outcome);
  }

  private renderOutcome(outcome: SyncExperienceActionOutcome): void {
    if (outcome.type === 'confirmation-required' && outcome.remoteKind !== undefined) {
      showCenteredAlertDialog({
        title: outcome.title,
        message: outcome.message,
        autoCancel: true,
        primaryButton: { value: $r('app.string.settings_account_cancel'), action: () => {} },
        secondaryButton: {
          value: $r('app.string.settings_sync_change'),
          action: () => {
            this.changeGoal(outcome.remoteKind as AiraSyncProviderKind, true);
          }
        }
      });
      return;
    }
    if (outcome.type === 'configuration-required') {
      if (outcome.remoteKind === 'webdav') {
        this.navigationCoordinator.openSyncWebdavConfig(
          this.buildBoundary('sync_experience_goal'),
          'active',
          outcome.enableDefaultContent === true
        );
        return;
      }
      if (outcome.remoteKind === 'self_hosted') {
        this.navigationCoordinator.openSyncPersonalServerConfig(
          this.buildBoundary('sync_experience_goal'),
          outcome.enableDefaultContent === true
        );
        return;
      }
      this.showOutcomeOrDialog(outcome);
      return;
    }
    if (outcome.type === 'membership-required' && outcome.membershipDecision !== undefined) {
      this.showMembershipDecision(outcome.membershipDecision);
      return;
    }
    if (outcome.type === 'failed') {
      this.showFailureRecoveryDialog(outcome);
      return;
    }
    if (outcome.type === 'blocked' && outcome.requiresBookmarkResolution === true) {
      if (outcome.remoteKind === undefined) {
        this.showOutcomeOrDialog(outcome);
        return;
      }
      const conflictRemoteKind = outcome.remoteKind;
      showCenteredAlertDialog({
        title: outcome.title,
        message: outcome.message,
        autoCancel: true,
        primaryButton: {
          value: $r('app.string.settings_sync_prefer_cloud'),
          action: () => {
            this.resolveBookmarkConflicts(conflictRemoteKind, 'prefer-remote');
          }
        },
        secondaryButton: {
          value: $r('app.string.settings_sync_prefer_local'),
          action: () => {
            this.resolveBookmarkConflicts(conflictRemoteKind, 'prefer-local');
          }
        }
      });
      return;
    }
    this.showOutcomeOrDialog(outcome);
  }

  private showFailureRecoveryDialog(outcome: SyncExperienceActionOutcome): void {
    if (outcome.bookmarkFailure?.code === 'BKM-PROTOCOL-UPDATE-001') {
      showCenteredAlertDialog({
        title: $r('app.string.settings_sync_upgrade_required_title'),
        message: $r('app.string.settings_sync_upgrade_required_message'),
        autoCancel: false,
        buttonDirection: DialogButtonDirection.VERTICAL,
        buttons: [
          {
            value: $r('app.string.settings_sync_go_update'),
            primary: true,
            fontColor: this.storedOnAccentColor,
            backgroundColor: this.storedAccentColor,
            action: (): void => {
              sharedClientUpdatePolicyService.deferCurrentRequirement();
              if (!AppRuntimeContext.hasUIAbilityContext()) {
                this.showDialog(
                  $r('app.string.settings_sync_update_open_failed'),
                  $r('app.string.settings_sync_update_search')
                );
                return;
              }
              this.systemSettingsLaunchService.openAppGalleryDetailPage(
                AppRuntimeContext.getUIAbilityContext()
              ).then((result): void => {
                if (!result.success) {
                  this.showDialog(
                    $r('app.string.settings_sync_update_open_failed'),
                    $r('app.string.settings_sync_update_failed_detail', result.message)
                  );
                }
              });
            }
          },
          {
            value: $r('app.string.settings_sync_change_method'),
            action: (): void => {
              sharedClientUpdatePolicyService.deferCurrentRequirement();
              this.activeSheetVisible = true;
            }
          },
          {
            value: $r('app.string.settings_sync_keep_local'),
            action: (): void => {
              sharedClientUpdatePolicyService.deferCurrentRequirement();
            }
          }
        ]
      });
      return;
    }
    if (outcome.retryAction === 'sync' && outcome.remoteKind !== undefined) {
      if (this.showMultipleOutcomeLines(outcome, 'retry_change')) {
        return;
      }
      showCenteredAlertDialog({
        title: this.hasVisibleOutcomeTitle(outcome.title) ? outcome.title : $r('app.string.settings_sync_failed'),
        message: outcome.message,
        autoCancel: true,
        buttonDirection: DialogButtonDirection.VERTICAL,
        buttons: [
          {
            value: $r('app.string.settings_sync_retry_sync'),
            primary: true,
            fontColor: this.storedOnAccentColor,
            backgroundColor: this.storedAccentColor,
            action: () => {
              this.syncNow();
            }
          },
          {
            value: $r('app.string.settings_sync_change_method'),
            fontColor: this.storedAccentColor,
            action: () => {
              this.activeSheetVisible = true;
            }
          },
          { value: $r('app.string.settings_pro_got_it'), action: () => {} }
        ]
      });
      return;
    }
    if (outcome.retryAction === 'sync') {
      if (this.showMultipleOutcomeLines(outcome, 'retry')) {
        return;
      }
      showCenteredAlertDialog({
        title: this.hasVisibleOutcomeTitle(outcome.title) ? outcome.title : $r('app.string.settings_sync_failed'),
        message: outcome.message,
        autoCancel: true,
        buttonDirection: DialogButtonDirection.VERTICAL,
        buttons: [
          {
            value: $r('app.string.settings_sync_retry_sync'),
            primary: true,
            fontColor: this.storedOnAccentColor,
            backgroundColor: this.storedAccentColor,
            action: () => {
              this.syncNow();
            }
          },
          { value: $r('app.string.settings_pro_got_it'), action: () => {} }
        ]
      });
      return;
    }
    if (outcome.remoteKind !== undefined) {
      if (this.showMultipleOutcomeLines(outcome, 'change')) {
        return;
      }
      showCenteredAlertDialog({
        title: this.hasVisibleOutcomeTitle(outcome.title) ? outcome.title : $r('app.string.settings_sync_failed'),
        message: outcome.message,
        autoCancel: true,
        buttonDirection: DialogButtonDirection.VERTICAL,
        buttons: [
          {
            value: $r('app.string.settings_sync_change_method'),
            primary: true,
            fontColor: this.storedOnAccentColor,
            backgroundColor: this.storedAccentColor,
            action: () => {
              this.activeSheetVisible = true;
            }
          },
          { value: $r('app.string.settings_pro_got_it'), action: () => {} }
        ]
      });
      return;
    }
    this.showOutcomeOrDialog(outcome);
  }

  private resolveBookmarkConflicts(
    remoteKind: AiraSyncProviderKind,
    resolution: AiraBookmarkConflictResolution
  ): void {
    if (this.isBusy || this.boundary.privacyMode === 'private') {
      return;
    }
    this.isBusy = true;
    this.syncProgressController.begin(
      $r('app.string.settings_sync_resolving_conflicts'),
      $r('app.string.settings_sync_resolving_conflicts_detail'),
      'sync'
    );
    sharedSyncExperienceCoordinator.resolveBookmarkConflicts(remoteKind, resolution)
      .then((outcome: SyncExperienceActionOutcome) => {
        this.completeProgressOutcome(outcome);
      })
      .finally(() => {
        this.isBusy = false;
        this.refreshState();
      });
  }

  private showMembershipDecision(decision: EntitlementDecision): void {
    const isCrossSystemBookmarkUpgrade = decision.featureKey === 'cloud_sync' &&
      decision.primaryAction === 'open_pro';
    if (isCrossSystemBookmarkUpgrade) {
      showCenteredAlertDialog({
        title: $r('app.string.settings_sync_pro_required_title'),
        message: $r('app.string.settings_sync_pro_required_message'),
        autoCancel: true,
        buttonDirection: DialogButtonDirection.VERTICAL,
        buttons: [
          {
            value: $r('app.string.settings_sync_view_pro'),
            primary: true,
            fontColor: this.storedOnAccentColor,
            backgroundColor: this.storedAccentColor,
            action: () => {
              this.navigationCoordinator.openAiraPro(this.buildBoundary('sync_experience_membership'));
            }
          },
          {
            value: $r('app.string.settings_sync_choose_other'),
            fontColor: this.storedAccentColor,
            action: () => {
              this.activeSheetVisible = true;
            }
          }
        ]
      });
      return;
    }
    showCenteredAlertDialog({
      title: decision.title.length > 0 ? decision.title : $r('app.string.settings_sync_pro_needed'),
      message: decision.message,
      autoCancel: true,
      primaryButton: { value: $r('app.string.settings_sync_later'), action: () => {} },
      secondaryButton: {
        value: decision.primaryAction === 'open_pro'
          ? $r('app.string.settings_sync_view_pro')
          : $r('app.string.settings_sync_view_benefits'),
        action: () => {
          this.navigationCoordinator.openAiraPro(this.buildBoundary('sync_experience_membership'));
        }
      }
    });
  }

  private showOutcomeOrDialog(outcome: SyncExperienceActionOutcome): void {
    if (this.showMultipleOutcomeLines(outcome, 'confirm')) {
      return;
    }
    this.showDialog(outcome.title, outcome.message);
  }

  private hasMultipleOutcomeLines(outcome: SyncExperienceActionOutcome): boolean {
    return outcome.messageLines !== undefined && outcome.messageLines.length > 1;
  }

  private showMultipleOutcomeLines(outcome: SyncExperienceActionOutcome, actionKind: string): boolean {
    if (!this.hasMultipleOutcomeLines(outcome)) {
      return false;
    }
    const lines = outcome.messageLines !== undefined ? outcome.messageLines : [];
    this.outcomeDialogTitle = this.hasVisibleOutcomeTitle(outcome.title)
      ? outcome.title
      : $r('app.string.settings_sync_result_fallback');
    this.outcomeDialogLines = lines;
    this.outcomeDialogActionKind = actionKind;
    if (!this.outcomeLinesDialogOpen) {
      this.outcomeLinesDialogOpen = true;
      this.outcomeLinesDialogController.open();
    }
    return true;
  }

  private closeOutcomeLinesDialog(): void {
    if (!this.outcomeLinesDialogOpen) {
      return;
    }
    this.outcomeLinesDialogOpen = false;
    this.outcomeLinesDialogController.close();
  }

  private hasVisibleOutcomeTitle(title: ResourceStr): boolean {
    return typeof title !== 'string' || title.length > 0;
  }

  private showDialog(title: ResourceStr, message: ResourceStr): void {
    showCenteredAlertDialog({
      title: title,
      message: message,
      confirm: { value: $r('app.string.settings_pro_got_it'), action: () => {} }
    });
  }

  private openSyncProgressDialog(): void {
    if (this.syncProgressDialogOpen) {
      return;
    }
    this.syncProgressDialogOpen = true;
    this.syncProgressDialogController.open();
  }

  private closeSyncProgressDialog(): void {
    if (!this.syncProgressDialogOpen) {
      return;
    }
    this.syncProgressDialogOpen = false;
    this.syncProgressDialogController.close();
  }

  private buildBoundary(source: string): BrowserBoundaryRouteState {
    return {
      dataScope: this.boundary.dataScope,
      privacyMode: this.boundary.privacyMode,
      boundarySource: source
    };
  }
}
