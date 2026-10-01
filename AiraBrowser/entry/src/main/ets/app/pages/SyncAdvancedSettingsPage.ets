import router from '@ohos.router';
import {
  resolveCenteredDialogControllerWidth,
  resolveCenteredDialogSurfaceColor,
  CENTERED_DIALOG_CORNER_RADIUS_VP,
  showCenteredAlertDialog
} from '../components/common/CenteredDialogSurface';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  AiraBookmarkConflictResolution,
  AiraSyncRemoteKind
} from '../../common/models/AiraSyncModels';
import {
  sharedMembershipFeature,
  sharedPreferencesRepository,
  sharedSyncExperienceCoordinator
} from '../bootstrap/BrowserAppRuntime';
import {
  AiraFeatureKey
} from '../../common/constants/MembershipFeatureKeys';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { EntitlementDecision } from '../../common/models/MembershipModels';
import { SettingsNavigationCoordinator } from '../router/SettingsNavigationCoordinator';
import { BrowserBoundaryRouteState } from '../../common/utils/RouteParamUtils';
import {
  BrowserPrivateBoundaryNavigationService,
  BrowserPrivateSyncBoundaryAction,
  BrowserPrivateSyncBoundaryPlan
} from '../../core/browser/BrowserPrivateBoundaryNavigationService';
import {
  SYNC_OPERATION_PROGRESS_TIMING,
  SyncOperationProgressViewModel
} from '../../core/sync/SyncOperationProgressViewModel';
import {
  SyncAdvancedProviderActionState,
  SyncAdvancedSettingsViewModel,
  SyncAdvancedStatusViewState
} from '../../core/sync/SyncAdvancedSettingsViewModel';
import {
  SyncExperienceAdvancedMergeOutcome,
  SyncExperienceAdvancedProviderReadiness,
  SyncExperienceAdvancedRemoteSummaryOutcome,
  SyncExperienceAdvancedState,
  SyncExperienceProviderSelectionPresentation
} from '../../core/sync/SyncExperienceCoordinator';
import {
  SyncAdvancedOperationsSection,
  SyncAdvancedProviderSelectionSection
} from '../components/sync/SyncAdvancedSettingsSections';
import {
  SyncFailureDetailItem,
  SyncFailurePresentationService
} from '../../core/sync/SyncFailurePresentationService';
import {
  SyncOperationProgressDialog
} from '../components/sync/SyncOperationProgressDialog';
import {
  SettingsStaticValueRow
} from '../components/settings/SettingsRows';
import { SettingsHdsScaffold } from '../components/settings/SettingsHdsScaffold';
import {
  SettingsGroupCard,
  SettingsScrollBody,
  SettingsSection
} from '../components/settings/SettingsLayout';
import { SyncFailureDialog } from '../components/sync/SyncFailureDialog';
import { SyncExperienceLinesDialog } from '../components/sync/SyncExperienceLinesDialog';
import { SyncResultDialog } from '../components/sync/SyncResultDialog';
import { SyncMasterControlSection } from '../components/sync/SyncMasterControlSection';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY
} from '../../core/theme/BrowserThemeStorageKeys';
import { AppServiceModeGateService } from '../../services/settings/AppServiceModeGateService';
import { SYNC_SETTINGS_REFRESH_REVISION_KEY } from '../../core/sync/SyncSettingsRefreshSignal';

@Entry
@Component
struct SyncAdvancedSettingsPage {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = '#F6F8FB';
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageLink(SYNC_SETTINGS_REFRESH_REVISION_KEY) @Watch('refreshStatusFromSignal')
  private syncSettingsRefreshRevision: number = 0;
  private privateBoundaryNavigationService: BrowserPrivateBoundaryNavigationService =
    new BrowserPrivateBoundaryNavigationService();
  private syncAdvancedSettingsViewModel: SyncAdvancedSettingsViewModel = new SyncAdvancedSettingsViewModel();
  private syncOperationProgressViewModel: SyncOperationProgressViewModel = new SyncOperationProgressViewModel();
  private syncFailurePresentationService: SyncFailurePresentationService = new SyncFailurePresentationService();
  private navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private appServiceModeGateService: AppServiceModeGateService =
    new AppServiceModeGateService(sharedPreferencesRepository);

  @State private isBusy: boolean = false;
  @State private isSessionEphemeral: boolean = false;
  @State private baselineText: ResourceStr = $r('app.string.settings_sync_advanced_reading');
  @State private localText: ResourceStr = $r('app.string.settings_sync_advanced_reading');
  @State private remoteText: ResourceStr = $r('app.string.settings_sync_advanced_not_checked');
  @State private lastSyncText: ResourceStr = $r('app.string.settings_sync_advanced_none');
  @State private providerText: ResourceStr = $r('app.string.settings_sync_advanced_reading');
  @State private mergeActionLabel: ResourceStr = $r('app.string.settings_sync_advanced_merge');
  @State private providerActionState: SyncAdvancedProviderActionState = {
    showHuaweiCloud: false,
    showHuaweiSpace: false,
    showWebdav: false,
    mergeRequiresPro: false
  };
  @State private activeRemoteKind: AiraSyncRemoteKind = 'none';
  private activeSyncServiceKey: AiraFeatureKey = '' as AiraFeatureKey;
  private activeSyncServiceName: string = resolveAppResourceText($r('app.string.settings_sync_advanced_service'));
  private activeSyncReady: boolean = false;
  private activeSyncMissingConfigurationMessage: ResourceStr =
    $r('app.string.settings_sync_advanced_enable_one');
  private providerReadiness: SyncExperienceAdvancedProviderReadiness[] = [];
  @State private syncFloatingTitle: ResourceStr = '';
  @State private syncFloatingSubtitle: ResourceStr = '';
  @State private syncFloatingProgress: number = 0;
  @State private syncFloatingInProgress: boolean = false;
  @State private syncProgressDetailsText: ResourceStr = '';
  @State private syncProgressDetailOpacity: number = 1;
  @State private syncFailureDialogTitle: ResourceStr = '';
  @State private syncFailureDialogSummary: ResourceStr = '';
  @State private syncFailureDialogDetails: SyncFailureDetailItem[] = [];
  @State private syncResultDialogTitle: ResourceStr = '';
  @State private syncResultDialogMessage: ResourceStr = '';
  @State private outcomeDialogTitle: ResourceStr = '';
  @State private outcomeDialogLines: ResourceStr[] = [];
  @State private outcomeDialogActionKind: string = 'confirm';
  private syncFailureDiagnosticsText: string = '';
  private syncFailureDialogController: CustomDialogController = new CustomDialogController({
    builder: SyncFailureDialog({
      title: $syncFailureDialogTitle,
      summary: $syncFailureDialogSummary,
      details: $syncFailureDialogDetails,
      copyDetails: () => {
        this.copyCurrentSyncFailureDiagnostics();
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('s'),
  });
  private syncResultDialogController: CustomDialogController = new CustomDialogController({
    builder: SyncResultDialog({
      title: $syncResultDialogTitle,
      message: $syncResultDialogMessage
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('m'),
  });
  private outcomeLinesDialogOpen: boolean = false;
  private outcomeLinesDialogController: CustomDialogController = new CustomDialogController({
    builder: SyncExperienceLinesDialog({
      title: $outcomeDialogTitle,
      lines: $outcomeDialogLines,
      actionKind: $outcomeDialogActionKind,
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
  private syncProgressTipTimer: number = -1;
  private syncProgressVisualTimer: number = -1;
  private syncProgressTimeoutTimer: number = -1;
  private syncProgressTimeoutMs: number = SYNC_OPERATION_PROGRESS_TIMING.timeoutMs;
  private syncProgressStartTime: number = 0;
  private syncProgressTargetProgress: number = SYNC_OPERATION_PROGRESS_TIMING.inProgressTarget;
  private syncProgressFinishTimer: number = -1;
  private syncProgressCompletionTimer: number = -1;
  private syncProgressResourceTips: ResourceStr[] = [];
  private syncProgressResourceTipIndex: number = 0;
  private syncProgressDialogController: CustomDialogController = new CustomDialogController({
    builder: SyncOperationProgressDialog({
      inProgress: $syncFloatingInProgress,
      title: $syncFloatingTitle,
      subtitle: $syncFloatingSubtitle,
      progress: $syncFloatingProgress,
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
      if (!this.syncFloatingInProgress) {
        dismissDialogAction.dismiss();
      }
    }
  });

  aboutToAppear(): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.isSessionEphemeral = this.privateBoundaryNavigationService.isSessionEphemeralRoute(
      router.getParams() as Record<string, string | undefined> | undefined
    );
    this.refreshStatus();
  }

  aboutToDisappear(): void {
    this.stopSyncProgressTimers();
  }

  onBackPress(): boolean {
    return this.syncProgressDialogOpen && this.syncFloatingInProgress;
  }

  build() {
    Column() {
      SettingsHdsScaffold({
        title: $r('app.string.settings_sync_advanced_options'),
        backIconKind: 'back',
        pageBackground: this.storedPageBackgroundColor,
        headerButtonBackground: this.storedPressedBackgroundColor,
        primaryTextColor: this.storedPrimaryTextColor,
        dividerColor: this.storedDividerColor,
        showPrivateIndicator: this.isSessionEphemeral,
        onBack: () => {
          this.navigationCoordinator.back();
        }
      }) {
        SettingsScrollBody({
          contentSpace: 16,
          topPadding: 8,
          bottomPadding: 28
        }) {
          SyncMasterControlSection({
            isPrivateSession: this.isSessionEphemeral,
            pageBusy: this.isBusy
          })
          this.buildStatusSection()
          this.buildCloudCheckSection()
          this.buildProviderSelectionSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
  }

  @Builder
  private buildStatusSection() {
    SettingsSection({ title: $r('app.string.settings_sync_advanced_status') }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        SettingsStaticValueRow({
          title: $r('app.string.settings_sync_advanced_method'),
          value: this.providerText,
          rowPosition: 'first'
        })
        this.buildDivider()
        SettingsStaticValueRow({
          title: $r('app.string.settings_sync_advanced_baseline'),
          value: this.baselineText,
          rowPosition: 'middle'
        })
        this.buildDivider()
        SettingsStaticValueRow({
          title: $r('app.string.settings_sync_advanced_local'),
          value: this.localText,
          rowPosition: 'middle'
        })
        this.buildDivider()
        SettingsStaticValueRow({
          title: $r('app.string.settings_sync_advanced_remote'),
          value: this.remoteText,
          rowPosition: 'middle'
        })
        this.buildDivider()
        SettingsStaticValueRow({
          title: $r('app.string.settings_sync_advanced_last'),
          value: this.lastSyncText,
          rowPosition: 'last'
        })
      }
    }
  }

  @Builder
  private buildCloudCheckSection() {
    SyncAdvancedOperationsSection({
      mergeActionLabel: this.mergeActionLabel,
      actionState: this.resolveProviderActionState(),
      isBusy: this.isBusy,
      isPrivateSession: this.isSessionEphemeral,
      accentColor: this.storedAccentColor,
      pressedBackgroundColor: this.storedPressedBackgroundColor,
      onMerge: () => {
        this.mergeRemoteData();
      },
      onCheckProvider: (remoteKind: AiraSyncRemoteKind) => {
        this.readProviderSummary(remoteKind);
      },
      onPushProvider: (remoteKind: AiraSyncRemoteKind) => {
        this.confirmPushLocalSnapshot(remoteKind);
      },
      onPullProvider: (remoteKind: AiraSyncRemoteKind) => {
        this.confirmPullRemoteSnapshot(remoteKind);
      }
    })
  }

  @Builder
  private buildProviderSelectionSection() {
    SyncAdvancedProviderSelectionSection({
      actionState: this.resolveProviderActionState(),
      activeRemoteKind: this.activeRemoteKind,
      isBusy: this.isBusy,
      isPrivateSession: this.isSessionEphemeral,
      accentColor: this.storedAccentColor,
      pressedBackgroundColor: this.storedPressedBackgroundColor,
      onSelectProvider: (remoteKind: AiraSyncRemoteKind) => {
        this.confirmSelectProvider(remoteKind);
      }
    })
  }

  @Builder
  private buildDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(this.storedDividerColor)
      .margin({ left: 16, right: 16 })
  }

  private refreshStatus(): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    const isPrivateSession = this.isSessionEphemeral;
    this.applyAdvancedState(sharedSyncExperienceCoordinator.readAdvancedState(isPrivateSession));
    if (isPrivateSession) {
      return;
    }
    sharedSyncExperienceCoordinator.loadAdvancedState(false)
      .then((state: SyncExperienceAdvancedState) => {
        this.applyAdvancedState(state);
      })
      .catch((_error: Error) => {
      });
  }

  private applyStatusViewState(state: SyncAdvancedStatusViewState): void {
    this.providerText = state.providerText;
    this.baselineText = state.baselineText;
    this.localText = state.localText;
    this.remoteText = state.remoteText;
    this.lastSyncText = state.lastSyncText;
  }

  private applyAdvancedState(state: SyncExperienceAdvancedState): void {
    this.applyStatusViewState(state.status);
    this.providerActionState = state.providerActions;
    this.mergeActionLabel = state.mergeActionLabel;
    this.activeRemoteKind = state.activeRemoteKind;
    this.activeSyncServiceKey = state.activeSyncServiceKey;
    this.activeSyncServiceName = state.activeSyncServiceName;
    this.activeSyncReady = state.activeSyncReady;
    this.activeSyncMissingConfigurationMessage = state.activeSyncMissingConfigurationMessage;
    this.providerReadiness = state.providerReadiness;
  }

  private refreshStatusFromSignal(): void {
    this.refreshStatus();
  }

  private resolveProviderActionState(): SyncAdvancedProviderActionState {
    return this.providerActionState;
  }

  private async readProviderSummary(remoteKind: AiraSyncRemoteKind): Promise<void> {
    if (this.isBusy || !this.guardSyncBoundary('read_webdav_remote')) {
      return;
    }
    const title = this.syncAdvancedSettingsViewModel.resolveProviderCheckActionLabel(remoteKind);
    if (!this.guardProviderSyncReady(remoteKind, title)) {
      return;
    }
    if (!await this.ensureProviderSyncAccess(remoteKind, title)) {
      return;
    }
    this.isBusy = true;
    this.beginSyncFloatingOperation(
      title,
      this.syncAdvancedSettingsViewModel.resolveReadingStatus(remoteKind),
      this.resolveProviderOperationTimeoutMs(remoteKind)
    );
    this.updateSyncFloatingStep(title, this.syncAdvancedSettingsViewModel.resolveConnecting(remoteKind), 28);
    sharedSyncExperienceCoordinator.readAdvancedRemoteSummary(remoteKind)
      .then((outcome: SyncExperienceAdvancedRemoteSummaryOutcome) => {
        this.remoteText = this.syncAdvancedSettingsViewModel.updateRemoteSummaryText(
          outcome.summary
        );
        this.updateSyncFloatingStep(title, $r('app.string.settings_sync_advanced_updating_status'), 72);
        this.finishSyncFloatingOperation(
          $r('app.string.settings_sync_advanced_remote_updated'),
          this.syncAdvancedSettingsViewModel.resolveRefreshed(remoteKind),
          100,
          true
        );
      })
      .catch((error: Error) => {
        this.finishSyncFloatingOperation(
          $r('app.string.settings_sync_advanced_check_failed'),
          $r('app.string.settings_sync_advanced_try_later'),
          100,
          false
        );
        this.showSyncFailureDialog(
          resolveAppResourceText($r('app.string.settings_sync_advanced_check_remote')),
          this.resolveProviderServiceName(remoteKind),
          error);
      })
      .finally(() => {
        this.isBusy = false;
      });
  }

  private confirmPushLocalSnapshot(remoteKind: AiraSyncRemoteKind): void {
    const title = this.syncAdvancedSettingsViewModel.resolvePushActionLabel(remoteKind);
    if (!this.guardSyncBoundary('push_webdav') || !this.guardProviderSyncReady(remoteKind, title)) {
      return;
    }
    showCenteredAlertDialog({
      title: this.syncAdvancedSettingsViewModel.resolvePushConfirmTitle(remoteKind),
      message: this.syncAdvancedSettingsViewModel.resolvePushConfirmMessage(remoteKind),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_account_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_sync_advanced_overwrite'),
        action: () => {
          this.forceBookmarkAuthority(remoteKind, 'prefer-local');
        }
      }
    });
  }

  private confirmPullRemoteSnapshot(remoteKind: AiraSyncRemoteKind): void {
    const title = this.syncAdvancedSettingsViewModel.resolvePullActionLabel(remoteKind);
    if (!this.guardSyncBoundary('pull_webdav') || !this.guardProviderSyncReady(remoteKind, title)) {
      return;
    }
    showCenteredAlertDialog({
      title: this.syncAdvancedSettingsViewModel.resolvePullConfirmTitle(remoteKind),
      message: this.syncAdvancedSettingsViewModel.resolvePullConfirmMessage(remoteKind),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_account_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_sync_advanced_overwrite'),
        action: () => {
          this.forceBookmarkAuthority(remoteKind, 'prefer-remote');
        }
      }
    });
  }

  private async forceBookmarkAuthority(
    remoteKind: AiraSyncRemoteKind,
    resolution: AiraBookmarkConflictResolution
  ): Promise<void> {
    if (remoteKind === 'none' || this.isBusy) {
      return;
    }
    const title = resolution === 'prefer-remote'
      ? this.syncAdvancedSettingsViewModel.resolvePullActionLabel(remoteKind)
      : this.syncAdvancedSettingsViewModel.resolvePushActionLabel(remoteKind);
    const boundaryAction = resolution === 'prefer-remote' ? 'pull_webdav' : 'push_webdav';
    if (!this.guardSyncBoundary(boundaryAction) || !this.guardProviderSyncReady(remoteKind, title)) {
      return;
    }
    if (!await this.ensureProviderSyncAccess(remoteKind, title)) {
      return;
    }
    this.isBusy = true;
    this.beginSyncFloatingOperation(
      title,
      resolution === 'prefer-remote'
        ? this.syncAdvancedSettingsViewModel.resolveReadingData(remoteKind)
        : this.syncAdvancedSettingsViewModel.resolvePreparingSpace(remoteKind),
      this.resolveProviderOperationTimeoutMs(remoteKind)
    );
    this.updateSyncFloatingStep(
      title,
      resolution === 'prefer-remote'
        ? $r('app.string.settings_sync_advanced_updating_local')
        : this.syncAdvancedSettingsViewModel.resolveSavingBookmarks(remoteKind),
      48
    );
    sharedSyncExperienceCoordinator.forceAdvancedBookmarkAuthority(remoteKind, resolution)
      .then((outcome: SyncExperienceAdvancedMergeOutcome) => {
        if (outcome.result.blocked) {
          this.finishSyncFloatingOperation(
            $r('app.string.settings_sync_advanced_overwrite_incomplete'),
            $r('app.string.settings_sync_advanced_check_status'),
            100,
            false
          );
          this.showDialog(outcome.dialogTitle, outcome.message);
          return;
        }
        this.updateSyncFloatingStep(title, $r('app.string.settings_sync_advanced_confirming'), 84);
        this.finishSyncFloatingOperation(outcome.completionTitle, outcome.completionSubtitle, 100, true);
        this.recordProviderSyncUsageIfNeeded(remoteKind);
        this.showDialog(outcome.dialogTitle, outcome.message);
        this.refreshStatus();
      })
      .catch((error: Error) => {
        this.finishSyncFloatingOperation(
          $r('app.string.settings_sync_advanced_overwrite_failed'),
          $r('app.string.settings_sync_advanced_check_network'),
          100,
          false
        );
        this.showSyncFailureDialog(
          resolveAppResourceText($r('app.string.settings_sync_01')),
          this.resolveProviderServiceName(remoteKind),
          error);
      })
      .finally(() => {
        this.isBusy = false;
      });
  }

  private async mergeRemoteData(): Promise<void> {
    if (this.isBusy || !this.guardSyncBoundary('merge_webdav')) {
      return;
    }
    const mergeTitle = $r('app.string.settings_sync_advanced_merge');
    if (!this.guardActiveSyncReady(mergeTitle)) {
      return;
    }
    if (!await this.ensureActiveSyncAccess(mergeTitle)) {
      return;
    }
    this.isBusy = true;
    const syncingTitle = $r('app.string.settings_sync_advanced_syncing');
    this.beginSyncFloatingOperation(
      syncingTitle,
      $r('app.string.settings_sync_advanced_preparing_both'),
      this.resolveProviderOperationTimeoutMs(this.resolveActiveRemoteKind())
    );
    this.updateSyncFloatingStep(syncingTitle, $r('app.string.settings_sync_advanced_comparing'), 34);
    const activeRemoteKind = this.resolveActiveRemoteKind();
    sharedSyncExperienceCoordinator.mergeAdvancedActiveBookmarks(activeRemoteKind)
      .then((outcome: SyncExperienceAdvancedMergeOutcome) => {
        if (outcome.result.blocked) {
          this.finishSyncFloatingOperation(
            $r('app.string.settings_sync_advanced_needs_confirm'),
            $r('app.string.settings_sync_advanced_review'),
            100,
            false
          );
          this.showDialog($r('app.string.settings_sync_advanced_stopped'), outcome.message);
          return;
        }
        this.updateSyncFloatingStep(syncingTitle, $r('app.string.settings_sync_advanced_organizing'), 82);
        this.finishSyncFloatingOperation(
          outcome.completionTitle,
          outcome.completionSubtitle,
          100,
          true
        );
        this.recordCloudSyncUsageIfNeeded();
        this.showDialog(outcome.dialogTitle, outcome.message);
        this.refreshStatus();
      })
      .catch((error: Error) => {
        this.finishSyncFloatingOperation(
          $r('app.string.settings_sync_failed'),
          $r('app.string.settings_sync_advanced_try_later'),
          100,
          false
        );
        this.showSyncFailureDialog(
          resolveAppResourceText($r('app.string.settings_sync_advanced_merge')),
          this.resolveActiveSyncServiceName(),
          error);
      })
      .finally(() => {
        this.isBusy = false;
      });
  }

  private confirmSelectProvider(remoteKind: AiraSyncRemoteKind): void {
    if (remoteKind === 'none') {
      return;
    }
    showCenteredAlertDialog({
      title: this.syncAdvancedSettingsViewModel.resolveSwitchConfirmTitle(remoteKind),
      message: this.syncAdvancedSettingsViewModel.resolveSwitchConfirmMessage(remoteKind),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_account_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_sync_advanced_merge_and_change'),
        action: () => {
          this.selectProvider(remoteKind);
        }
      }
    });
  }

  private selectProvider(remoteKind: AiraSyncRemoteKind): void {
    if (remoteKind === 'none' || this.isBusy || !this.guardSyncBoundary('merge_webdav')) {
      return;
    }
    this.isBusy = true;
    this.beginSyncFloatingOperation(
      $r('app.string.settings_sync_changing'),
      this.syncAdvancedSettingsViewModel.resolveMergingData(remoteKind),
      this.resolveProviderOperationTimeoutMs(remoteKind)
    );
    sharedSyncExperienceCoordinator.selectAdvancedProvider(remoteKind)
      .then((presentation: SyncExperienceProviderSelectionPresentation) => {
        this.finishSyncFloatingOperation(
          presentation.completionTitle,
          presentation.completionSubtitle,
          100,
          presentation.type === 'selected'
        );
        if (presentation.type === 'blocked' || presentation.type === 'selected') {
          this.showProviderSelectionMessage(presentation);
          if (presentation.type === 'selected') {
            this.refreshStatus();
          }
          return;
        }
        if (presentation.type === 'membership-required' && presentation.membershipDecision !== undefined) {
          this.showSyncMembershipDialog(presentation.dialogTitle, presentation.membershipDecision);
          return;
        }
        const failureTitle = typeof presentation.dialogTitle === 'string'
          ? presentation.dialogTitle
          : resolveAppResourceText($r('app.string.settings_sync_advanced_change_method'));
        const failureMessage = typeof presentation.message === 'string' ? presentation.message : '';
        this.showSyncFailureDialog(
          failureTitle,
          presentation.providerLabel,
          new Error(failureMessage)
        );
      })
      .finally(() => {
        this.isBusy = false;
      });
  }

  private guardSyncBoundary(action: BrowserPrivateSyncBoundaryAction): boolean {
    const plan: BrowserPrivateSyncBoundaryPlan = this.privateBoundaryNavigationService.buildSyncBoundaryPlan(
      action,
      this.isSessionEphemeral ? 'session_ephemeral' : 'profile_persistent',
      this.isSessionEphemeral ? 'private' : 'regular'
    );
    if (plan.allowed) {
      return true;
    }
    this.showDialog(
      $r('app.string.settings_sync_advanced_private_title'),
      $r('app.string.settings_sync_advanced_private_message')
    );
    return false;
  }

  private async ensureActiveSyncAccess(title: ResourceStr): Promise<boolean> {
    const featureKey = this.resolveActiveSyncServiceKey();
    return this.ensureFeatureAccess(featureKey, title);
  }

  private async ensureProviderSyncAccess(remoteKind: AiraSyncRemoteKind, title: ResourceStr): Promise<boolean> {
    const featureKey = this.resolveProviderSyncServiceKey(remoteKind);
    return this.ensureFeatureAccess(featureKey, title);
  }

  private async ensureFeatureAccess(featureKey: AiraFeatureKey, title: ResourceStr): Promise<boolean> {
    if (featureKey.length <= 0) {
      return true;
    }
    const decision = await sharedMembershipFeature.canUse(featureKey, {
      dataScope: this.isSessionEphemeral ? 'session_ephemeral' : 'profile_persistent',
      privacyMode: this.isSessionEphemeral ? 'private' : 'regular',
      loggedIn: true
    });
    if (decision.allowed) {
      return true;
    }
    this.showSyncMembershipDialog(title, decision);
    return false;
  }

  private showSyncMembershipDialog(title: ResourceStr, decision: EntitlementDecision): void {
    const primaryLabel = decision.primaryAction === 'open_pro'
      ? $r('app.string.settings_sync_view_pro')
      : $r('app.string.settings_sync_view_benefits');
    showCenteredAlertDialog({
      title: decision.title.length > 0 ? decision.title : title,
      message: decision.message,
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_sync_later'),
        action: () => {}
      },
      secondaryButton: {
        value: primaryLabel,
        action: () => {
          this.navigationCoordinator.openAiraPro(this.buildBoundaryState('sync_advanced_settings'));
        }
      }
    });
  }

  private recordCloudSyncUsageIfNeeded(): void {
    const featureKey = this.resolveActiveSyncServiceKey();
    if (featureKey.length <= 0) {
      return;
    }
    void sharedMembershipFeature.recordUsage(featureKey);
  }

  private resolveActiveSyncServiceKey(): AiraFeatureKey {
    return this.activeSyncServiceKey;
  }

  private recordProviderSyncUsageIfNeeded(remoteKind: AiraSyncRemoteKind): void {
    const featureKey = this.resolveProviderSyncServiceKey(remoteKind);
    if (featureKey.length <= 0) {
      return;
    }
    void sharedMembershipFeature.recordUsage(featureKey);
  }

  private resolveProviderSyncServiceKey(remoteKind: AiraSyncRemoteKind): AiraFeatureKey {
    return this.syncAdvancedSettingsViewModel.resolveProviderSyncServiceKey(remoteKind);
  }

  private guardActiveSyncReady(title: ResourceStr): boolean {
    if (this.activeSyncReady) {
      return true;
    }
    if (this.activeRemoteKind === 'none') {
      this.showDialog(title, $r('app.string.settings_sync_advanced_enable_one'));
      return false;
    }
    showCenteredAlertDialog({
      title: title,
      message: this.activeSyncMissingConfigurationMessage,
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_account_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_sync_advanced_fill'),
        action: () => {
          this.openActiveSyncConfigPage(this.activeRemoteKind);
        }
      }
    });
    return false;
  }

  private guardProviderSyncReady(remoteKind: AiraSyncRemoteKind, title: ResourceStr): boolean {
    const readiness = this.resolveProviderReadiness(remoteKind);
    if (readiness !== undefined && readiness.ready) {
      return true;
    }
    showCenteredAlertDialog({
      title: title,
      message: readiness !== undefined
        ? readiness.missingConfigurationMessage
        : $r('app.string.settings_sync_advanced_enable_method'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_account_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_sync_advanced_go_settings'),
        action: () => {
          this.openActiveSyncConfigPage(remoteKind);
        }
      }
    });
    return false;
  }

  private resolveActiveRemoteKind(): AiraSyncRemoteKind {
    return this.activeRemoteKind;
  }

  private resolveActiveSyncServiceName(): string {
    return this.activeSyncServiceName;
  }

  private resolveProviderReadiness(
    remoteKind: AiraSyncRemoteKind
  ): SyncExperienceAdvancedProviderReadiness | undefined {
    return this.providerReadiness.find((value: SyncExperienceAdvancedProviderReadiness): boolean => {
      return value.remoteKind === remoteKind;
    });
  }

  private resolveProviderServiceName(remoteKind: AiraSyncRemoteKind): string {
    return this.syncAdvancedSettingsViewModel.resolveProviderServiceName(remoteKind);
  }

  private resolveProviderOperationTimeoutMs(remoteKind: AiraSyncRemoteKind): number {
    return this.syncAdvancedSettingsViewModel.resolveProviderOperationTimeoutMs(remoteKind);
  }

  private openWebdavConfigPage(): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    this.navigationCoordinator.openSyncWebdavConfig(this.buildBoundaryState('sync_advanced_settings'));
  }

  private openActiveSyncConfigPage(remoteKind: AiraSyncRemoteKind): void {
    if (!this.ensureOptionalServiceRoute()) {
      return;
    }
    if (remoteKind === 'aira_cloud') {
      this.navigationCoordinator.openSyncSettings(this.buildBoundaryState('sync_advanced_settings'));
      return;
    }
    if (remoteKind === 'huawei_space') {
      this.navigationCoordinator.openSyncSettings(this.buildBoundaryState('sync_advanced_settings'));
      return;
    }
    this.openWebdavConfigPage();
  }

  private buildBoundaryState(boundarySource: string): BrowserBoundaryRouteState {
    return {
      dataScope: this.isSessionEphemeral ? 'session_ephemeral' : 'profile_persistent',
      privacyMode: this.isSessionEphemeral ? 'private' : 'regular',
      boundarySource: boundarySource
    };
  }

  private showDialog(title: ResourceStr, message: ResourceStr): void {
    this.syncResultDialogTitle = title;
    this.syncResultDialogMessage = message;
    this.syncResultDialogController.open();
  }

  private showProviderSelectionMessage(presentation: SyncExperienceProviderSelectionPresentation): void {
    if (typeof presentation.message !== 'string') {
      this.showDialog(presentation.dialogTitle, presentation.message);
      return;
    }
    const lines = this.syncFailurePresentationService.localizeProviderMessageLines(presentation.message);
    if (lines.length > 1) {
      this.outcomeDialogTitle = presentation.dialogTitle;
      this.outcomeDialogLines = lines;
      this.outcomeDialogActionKind = 'confirm';
      if (!this.outcomeLinesDialogOpen) {
        this.outcomeLinesDialogOpen = true;
        this.outcomeLinesDialogController.open();
      }
      return;
    }
    this.showDialog(presentation.dialogTitle, lines.length === 1 ? lines[0] : presentation.message);
  }

  private closeOutcomeLinesDialog(): void {
    if (!this.outcomeLinesDialogOpen) {
      return;
    }
    this.outcomeLinesDialogOpen = false;
    this.outcomeLinesDialogController.close();
  }

  private showSyncFailureDialog(operationName: string, serviceName: string, error: Error): void {
    const presentation = this.syncFailurePresentationService.build({
      serviceName: serviceName,
      operationName: operationName,
      errorMessage: this.stringifyError(error)
    });
    this.syncFailureDialogTitle = presentation.title;
    this.syncFailureDialogSummary = presentation.summary;
    this.syncFailureDialogDetails = presentation.details;
    this.syncFailureDiagnosticsText = presentation.diagnostics;
    this.syncFailureDialogController.open();
  }

  private copyCurrentSyncFailureDiagnostics(): void {
    if (this.syncFailureDiagnosticsText.length === 0) {
      this.showToast($r('app.string.settings_sync_advanced_copy_empty'));
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.syncFailureDiagnosticsText);
      pasteboard.getSystemPasteboard().setData(data)
        .then(() => {
          this.showToast($r('app.string.settings_sync_advanced_copied'));
        })
        .catch((_error: Error) => {
          this.showToast($r('app.string.settings_account_copy_failed'));
        });
    } catch (_error) {
      this.showToast($r('app.string.settings_account_copy_failed'));
    }
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1500
      });
    } catch (_error) {
    }
  }

  private beginSyncFloatingOperation(
    title: ResourceStr,
    subtitle: ResourceStr,
    timeoutMs: number = SYNC_OPERATION_PROGRESS_TIMING.timeoutMs
  ): void {
    this.stopSyncProgressTimers();
    this.syncFloatingTitle = title;
    this.syncFloatingSubtitle = subtitle;
    this.syncFloatingProgress = 0;
    this.syncProgressTimeoutMs = timeoutMs;
    this.syncProgressTargetProgress = SYNC_OPERATION_PROGRESS_TIMING.inProgressTarget;
    this.syncProgressStartTime = Date.now();
    this.syncFloatingInProgress = true;
    this.beginSyncProgressTips(subtitle);
    this.startSyncProgressVisualTimer();
    this.startSyncProgressTimeoutTimer();
    this.openSyncProgressDialog();
  }

  private updateSyncFloatingStep(title: ResourceStr, subtitle: ResourceStr, progress: number): void {
    this.syncFloatingTitle = title;
    this.syncFloatingSubtitle = subtitle;
    this.syncProgressTargetProgress = Math.max(this.syncProgressTargetProgress, progress);
    this.showSyncProgressTip(subtitle);
  }

  private finishSyncFloatingOperation(
    title: ResourceStr,
    subtitle: ResourceStr,
    progress: number = 100,
    animateCompletion: boolean = true
  ): void {
    if (!this.syncProgressDialogOpen) {
      return;
    }
    if (animateCompletion && progress >= 100) {
      this.completeSyncProgressWithRamp(title, subtitle);
      return;
    }
    this.syncFloatingTitle = title;
    this.syncFloatingSubtitle = subtitle;
    this.syncFloatingProgress = progress;
    this.showSyncProgressTip(subtitle);
    const remainingMs = Math.max(0, SYNC_OPERATION_PROGRESS_TIMING.minVisibleMs -
    (Date.now() - this.syncProgressStartTime));
    if (remainingMs > 0) {
      this.syncProgressFinishTimer = setTimeout(() => {
        this.completeSyncProgressDialog();
      }, remainingMs);
      return;
    }
    this.completeSyncProgressDialog();
  }

  private beginSyncProgressTips(firstTip: ResourceStr): void {
    this.syncProgressResourceTips = this.buildSyncProgressResourceTips(firstTip);
    this.syncProgressResourceTipIndex = 0;
    this.showSyncProgressTip(this.syncProgressResourceTips.length > 0 ? this.syncProgressResourceTips[0] : firstTip);
    this.syncProgressTipTimer = setInterval(() => {
      this.advanceSyncProgressTip();
    }, SYNC_OPERATION_PROGRESS_TIMING.tipIntervalMs);
  }

  private buildSyncProgressResourceTips(firstTip: ResourceStr): ResourceStr[] {
    return [
      firstTip,
      $r('app.string.settings_sync_tip_local'),
      $r('app.string.settings_sync_tip_cloud_status'),
      $r('app.string.settings_sync_tip_compare'),
      $r('app.string.settings_sync_tip_protect'),
      $r('app.string.settings_sync_tip_changes'),
      $r('app.string.settings_sync_tip_records'),
      $r('app.string.settings_sync_tip_wrap_up')
    ];
  }

  private advanceSyncProgressTip(): void {
    if (!this.syncFloatingInProgress || this.syncProgressResourceTips.length === 0) {
      return;
    }
    this.syncProgressResourceTipIndex = (this.syncProgressResourceTipIndex + 1) % this.syncProgressResourceTips.length;
    this.showSyncProgressTip(this.syncProgressResourceTips[this.syncProgressResourceTipIndex]);
  }

  private showSyncProgressTip(tip: ResourceStr): void {
    this.syncProgressDetailOpacity = 0.22;
    setTimeout(() => {
      this.syncProgressDetailsText = tip;
      this.syncProgressDetailOpacity = 1;
    }, 80);
  }

  private startSyncProgressVisualTimer(): void {
    this.syncProgressVisualTimer = setInterval(() => {
      if (!this.syncFloatingInProgress) {
        return;
      }
      this.syncFloatingProgress = this.syncOperationProgressViewModel.resolveVisualProgress(
        this.syncFloatingProgress,
        this.syncProgressTargetProgress,
        Date.now() - this.syncProgressStartTime
      );
    }, SYNC_OPERATION_PROGRESS_TIMING.visualIntervalMs);
  }

  private startSyncProgressTimeoutTimer(): void {
    this.syncProgressTimeoutTimer = setTimeout(() => {
      if (!this.syncFloatingInProgress) {
        return;
      }
      this.completeSyncProgressDialog();
      this.isBusy = false;
      this.showDialog(
        $r('app.string.settings_sync_advanced_timeout'),
        $r('app.string.settings_sync_advanced_timeout_message')
      );
    }, this.syncProgressTimeoutMs);
  }

  private completeSyncProgressDialog(): void {
    this.syncFloatingInProgress = false;
    this.stopSyncProgressTimers();
    this.closeSyncProgressDialog();
  }

  private completeSyncProgressWithRamp(title: ResourceStr, subtitle: ResourceStr): void {
    this.stopSyncProgressActiveTimers();
    this.syncFloatingSubtitle = $r('app.string.settings_sync_advanced_finishing');
    this.showSyncProgressTip($r('app.string.settings_sync_advanced_finishing'));
    this.syncProgressCompletionTimer = setInterval(() => {
      const nextProgress = Math.min(100, this.syncFloatingProgress + 4);
      this.syncFloatingProgress = nextProgress;
      if (nextProgress < 100) {
        return;
      }
      if (this.syncProgressCompletionTimer >= 0) {
        clearInterval(this.syncProgressCompletionTimer);
        this.syncProgressCompletionTimer = -1;
      }
      this.syncFloatingTitle = title;
      this.syncFloatingSubtitle = subtitle;
      this.showSyncProgressTip(subtitle);
      this.syncFloatingInProgress = false;
      this.syncProgressFinishTimer = setTimeout(() => {
        this.completeSyncProgressDialog();
      }, SYNC_OPERATION_PROGRESS_TIMING.successVisibleMs);
    }, SYNC_OPERATION_PROGRESS_TIMING.finishIntervalMs);
  }

  private stopSyncProgressActiveTimers(): void {
    if (this.syncProgressTipTimer >= 0) {
      clearInterval(this.syncProgressTipTimer);
      this.syncProgressTipTimer = -1;
    }
    if (this.syncProgressVisualTimer >= 0) {
      clearInterval(this.syncProgressVisualTimer);
      this.syncProgressVisualTimer = -1;
    }
    if (this.syncProgressTimeoutTimer >= 0) {
      clearTimeout(this.syncProgressTimeoutTimer);
      this.syncProgressTimeoutTimer = -1;
    }
  }

  private stopSyncProgressTimers(): void {
    this.stopSyncProgressActiveTimers();
    if (this.syncProgressFinishTimer >= 0) {
      clearTimeout(this.syncProgressFinishTimer);
      this.syncProgressFinishTimer = -1;
    }
    if (this.syncProgressCompletionTimer >= 0) {
      clearInterval(this.syncProgressCompletionTimer);
      this.syncProgressCompletionTimer = -1;
    }
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

  private stringifyError(error: Error): string {
    if (error.message !== undefined && error.message.length > 0) {
      return error.message;
    }
    const serialized = JSON.stringify(error);
    return serialized.length > 0
      ? serialized
      : resolveAppResourceText($r('app.string.media_resource_unknown_error'));
  }

  private ensureOptionalServiceRoute(): boolean {
    if (this.appServiceModeGateService.canUseOptionalService()) {
      return true;
    }
    this.navigationCoordinator.back();
    return false;
  }
}
