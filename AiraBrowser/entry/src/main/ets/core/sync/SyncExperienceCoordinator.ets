import { EntitlementDecision } from '../../common/models/MembershipModels';
import { AiraCloudBookmarkV4BootstrapTransitionDomain } from
  '../../common/models/AiraCloudBookmarkV4BootstrapModels';
import {
  AIRA_FEATURE_CLOUD_SYNC,
  AiraFeatureKey
} from '../../common/constants/MembershipFeatureKeys';
import {
  AiraAdditionalBackupIntervalDays,
  AiraBookmarkConflictResolution,
  AiraBookmarkMergeSyncResult,
  AiraBookmarkSyncFailure,
  AiraSyncDomainRuntimeState,
  AiraSyncProviderKind,
  AiraSyncRemoteKind,
  AiraSyncSettings,
  resolveAiraHuaweiAccountIdentity,
  resolveAiraPersonalServerConfig,
  resolveAiraSyncDomainRuntimeState
} from '../../common/models/AiraSyncModels';
import {
  PERSONALIZATION_SYNC_ITEM_IDS,
  PersonalizationSyncConfig,
  PersonalizationSyncContentId,
  PersonalizationSyncItemId,
  PersonalizationSyncRunResult
} from '../../common/models/PersonalizationSyncModels';
import { NovelBookshelfSyncSelectionState } from '../../common/models/NovelBookshelfSyncModels';
import { PersonalizationSyncConfigStore } from '../../data/sync/PersonalizationSyncConfigStore';
import {
  HuaweiSpaceBookmarkUpgradeStore
} from '../../data/sync/HuaweiSpaceBookmarkUpgradeStore';
import { PreferencesRepository } from '../../data/preferences/PreferencesRepository';
import {
  SyncExperiencePersistedState,
  SyncExperienceStateStore
} from '../../data/sync/SyncExperienceStateStore';
import { MembershipFeature } from '../../features/membership/MembershipFeature';
import { AiraSyncConfigStore } from '../../services/sync/AiraSyncConfigStore';
import {
  HistorySyncService,
  resolveHistorySyncProviderKind
} from '../../services/sync/HistorySyncService';
import { SyncService } from '../../services/sync/SyncService';
import { AiraSyncJankProbe } from '../../common/debug/AiraSyncJankProbe';
import {
  SyncExperienceAutomaticRuntime,
  SyncExperienceRuntimeRunResult
} from './SyncExperienceAutomaticRuntime';
import { SyncBookmarkDomain } from './SyncBookmarkDomain';
import {
  SyncExperienceViewModel,
  SyncExperienceViewState
} from './SyncExperienceViewModel';
import { SyncPersonalizationDomain } from './SyncPersonalizationDomain';
import {
  SyncExperienceProviderOperations,
  SyncExperienceProviderOutcome,
  SyncWebdavActivationOutcome,
  SyncWebdavConfigurationParams
} from './SyncExperienceProviderOperations';
import { SyncActivationResult } from './SyncActivationModels';
import { shouldClearHistoryAccountBinding } from './HistoryAccountBindingPolicy';
import {
  SyncAdditionalBackupViewModel,
  SyncAdditionalBackupViewState
} from './SyncAdditionalBackupViewModel';
import { SyncSettingsCenterViewModel } from './SyncSettingsCenterViewModel';
import {
  SyncAdvancedProviderActionState,
  SyncAdvancedSettingsViewModel,
  SyncAdvancedStatusViewState
} from './SyncAdvancedSettingsViewModel';
import {
  SyncAdvancedMergeOutcome,
  SyncAdvancedRemoteSummaryOutcome,
  SyncAdvancedStatusOverview,
  SyncExperienceAdvancedOperations,
  SyncProviderSelectionPresentation
} from './SyncExperienceAdvancedOperations';
import {
  SyncFirstActivationItemState,
  SyncFirstActivationItemsState
} from './SyncFirstActivationItemsCoordinator';
import { SyncWebdavProviderRole } from './SyncWebdavConfigViewModel';
import { SyncFailurePresentationService } from './SyncFailurePresentationService';
import { WebNetworkAvailabilityService } from '../../services/web/WebNetworkAvailabilityService';

export type SyncExperienceActionOutcomeType =
  | 'completed'
  | 'confirmation-required'
  | 'configuration-required'
  | 'membership-required'
  | 'blocked'
  | 'failed';

export type SyncExperienceRetryAction = 'sync' | 'reload';

export interface SyncExperienceActionOutcome {
  type: SyncExperienceActionOutcomeType;
  title: ResourceStr;
  message: ResourceStr;
  messageLines?: ResourceStr[];
  remoteKind?: AiraSyncProviderKind;
  membershipDecision?: EntitlementDecision;
  enableDefaultContent?: boolean;
  requiresBookmarkResolution?: boolean;
  bookmarkFailure?: AiraBookmarkSyncFailure;
  personalizationConfig?: PersonalizationSyncConfig;
  retryAction?: SyncExperienceRetryAction;
}

export interface SyncExperienceHuaweiSpaceBookmarkUpgradePromptState {
  required: boolean;
  shouldPresent: boolean;
}

export type SyncAdditionalBackupActionOutcomeType = 'completed' | 'blocked' | 'failed';

export interface SyncAdditionalBackupActionOutcome {
  type: SyncAdditionalBackupActionOutcomeType;
  title: ResourceStr;
  message: ResourceStr;
  messageLines?: ResourceStr[];
  requiresOptions?: boolean;
}

export type SyncExperienceProviderSelectionOutcome = SyncExperienceProviderOutcome;

export type SyncExperienceWebdavActivationOutcome = SyncWebdavActivationOutcome;
export type SyncExperienceWebdavConfigurationParams = SyncWebdavConfigurationParams;
export type SyncExperienceWebdavTargetRole = 'active' | 'additional_backup';

export interface SyncExperienceWebdavConfigurationState {
  endpoint: string;
  username: string;
  password: string;
  providerRole: SyncWebdavProviderRole;
  bookmarkDomainEnabled: boolean;
}

export type SyncExperienceAdvancedMergeOutcome = SyncAdvancedMergeOutcome;
export type SyncExperienceAdvancedRemoteSummaryOutcome = SyncAdvancedRemoteSummaryOutcome;
export type SyncExperienceProviderSelectionPresentation = SyncProviderSelectionPresentation;

export interface SyncExperienceAdvancedProviderReadiness {
  remoteKind: AiraSyncProviderKind;
  ready: boolean;
  missingConfigurationMessage: ResourceStr;
}

export interface SyncExperienceAdvancedState {
  status: SyncAdvancedStatusViewState;
  providerActions: SyncAdvancedProviderActionState;
  mergeActionLabel: ResourceStr;
  activeRemoteKind: AiraSyncRemoteKind;
  activeSyncServiceKey: AiraFeatureKey;
  activeSyncServiceName: string;
  activeSyncReady: boolean;
  activeSyncMissingConfigurationMessage: ResourceStr;
  providerReadiness: SyncExperienceAdvancedProviderReadiness[];
}

interface SyncExperienceDomainIssue {
  domain: 'bookmark' | 'personalization' | 'history';
  type: 'blocked' | 'failed';
  message?: string;
  failure?: AiraBookmarkSyncFailure;
}

interface SyncExperienceContext {
  settings: AiraSyncSettings;
  activeProvider: AiraSyncRemoteKind;
  experienceState: SyncExperiencePersistedState;
}

export class SyncExperienceCoordinator implements AiraCloudBookmarkV4BootstrapTransitionDomain {
  private syncFailurePresentationService: SyncFailurePresentationService = new SyncFailurePresentationService();
  private networkAvailabilityService: WebNetworkAvailabilityService = new WebNetworkAvailabilityService();
  private syncService: SyncService;
  private syncConfigStore: AiraSyncConfigStore;
  private personalizationConfigStore: PersonalizationSyncConfigStore;
  private experienceStateStore: SyncExperienceStateStore;
  private providerOperations: SyncExperienceProviderOperations;
  private personalizationDomain: SyncPersonalizationDomain;
  private bookmarkDomain: SyncBookmarkDomain;
  private historySyncService: HistorySyncService;
  private automaticRuntime: SyncExperienceAutomaticRuntime;
  private advancedOperations: SyncExperienceAdvancedOperations;
  private membershipFeature: MembershipFeature;
  private huaweiSpaceBookmarkUpgradeStore: HuaweiSpaceBookmarkUpgradeStore;
  private huaweiSpaceBookmarkUpgradePreparationPromise?: Promise<void>;
  private pendingGoalChangePromise?: Promise<SyncExperienceActionOutcome>;
  private viewModel: SyncExperienceViewModel = new SyncExperienceViewModel();
  private additionalBackupViewModel: SyncAdditionalBackupViewModel = new SyncAdditionalBackupViewModel();
  private settingsCenterViewModel: SyncSettingsCenterViewModel = new SyncSettingsCenterViewModel();
  private advancedViewModel: SyncAdvancedSettingsViewModel = new SyncAdvancedSettingsViewModel();

  constructor(
    syncService: SyncService,
    syncConfigStore: AiraSyncConfigStore,
    personalizationConfigStore: PersonalizationSyncConfigStore,
    experienceStateStore: SyncExperienceStateStore,
    providerOperations: SyncExperienceProviderOperations,
    personalizationDomain: SyncPersonalizationDomain,
    bookmarkDomain: SyncBookmarkDomain,
    historySyncService: HistorySyncService,
    automaticRuntime: SyncExperienceAutomaticRuntime,
    advancedOperations: SyncExperienceAdvancedOperations,
    membershipFeature: MembershipFeature,
    huaweiSpaceBookmarkUpgradeStore: HuaweiSpaceBookmarkUpgradeStore =
      new HuaweiSpaceBookmarkUpgradeStore()
  ) {
    this.syncService = syncService;
    this.syncConfigStore = syncConfigStore;
    this.personalizationConfigStore = personalizationConfigStore;
    this.experienceStateStore = experienceStateStore;
    this.providerOperations = providerOperations;
    this.personalizationDomain = personalizationDomain;
    this.bookmarkDomain = bookmarkDomain;
    this.historySyncService = historySyncService;
    this.automaticRuntime = automaticRuntime;
    this.advancedOperations = advancedOperations;
    this.membershipFeature = membershipFeature;
    this.huaweiSpaceBookmarkUpgradeStore = huaweiSpaceBookmarkUpgradeStore;
  }

  async load(): Promise<SyncExperienceViewState> {
    await this.awaitPendingGoalChange();
    await this.prepareHuaweiSpaceBookmarkUpgrade();
    await this.completeHuaweiSpaceBookmarkUpgradeIfNeeded(
      this.syncService.getAiraSyncSettings().remoteKind
    );
    const settings = this.syncService.getAiraSyncSettings();
    const activeProvider = settings.remoteKind;
    const values = await Promise.all([
      this.personalizationConfigStore.initialize(),
      this.reconcileHistoryAccountBinding(settings),
      this.personalizationDomain.initializeNovelBookshelfSelection()
    ]);
    const experienceState = values[1];
    return this.viewModel.buildState({
      settings: settings,
      personalizationConfig: values[0],
      experienceState: experienceState,
      novelBookshelfSyncEnabled: values[2].enabled,
      airaCloudEligible: this.membershipFeature.getState().plan === 'pro',
      isSyncing: this.automaticRuntime.isRunning(),
      huaweiSpaceBookmarkUpgradeRequired: this.isHuaweiSpaceBookmarkUpgradeRequired(settings)
    });
  }

  runLocalBackupImport<T>(operation: () => Promise<T>): Promise<T> {
    return this.automaticRuntime.runProviderTransition(operation);
  }

  runAiraCloudBookmarkV4Bootstrap<T>(operation: () => Promise<T>): Promise<T> {
    return this.automaticRuntime.runProviderTransition(operation);
  }

  async prepareHuaweiSpaceBookmarkUpgrade(): Promise<SyncExperienceHuaweiSpaceBookmarkUpgradePromptState> {
    if (this.huaweiSpaceBookmarkUpgradePreparationPromise === undefined) {
      this.huaweiSpaceBookmarkUpgradePreparationPromise = this.runHuaweiSpaceBookmarkUpgradePreparation()
        .catch((error: Error) => {
          this.huaweiSpaceBookmarkUpgradePreparationPromise = undefined;
          throw error;
        });
    }
    await this.huaweiSpaceBookmarkUpgradePreparationPromise;
    return {
      required: this.huaweiSpaceBookmarkUpgradeStore.isCurrentVersionRequired(),
      shouldPresent: this.huaweiSpaceBookmarkUpgradeStore.shouldPresentCurrentVersion()
    };
  }

  async acknowledgeHuaweiSpaceBookmarkUpgradePrompt(): Promise<void> {
    await this.huaweiSpaceBookmarkUpgradeStore.markPrompted();
  }

  bindPreferenceChanges(preferencesRepository: PreferencesRepository): void {
    this.automaticRuntime.bindPreferenceChanges(preferencesRepository);
  }

  markSyncRepositoriesReady(): void {
    this.automaticRuntime.markRepositoriesReady();
  }

  notifyAppContentReady(): void {
    AiraSyncJankProbe.mark('content_ready_requested');
    this.runAfterHuaweiSpaceBookmarkUpgradePreparation((): void => {
      this.automaticRuntime.notifyAppContentReady();
    });
  }

  notifyAppForeground(): void {
    this.runAfterHuaweiSpaceBookmarkUpgradePreparation((): void => {
      this.automaticRuntime.notifyAppForeground();
    });
  }

  notifyAppBackground(): void {
    this.automaticRuntime.notifyAppBackground();
  }

  notifyBookmarkSurfaceForeground(): void {
    this.automaticRuntime.scheduleBookmarkPeriodicSync();
  }

  recordBookmarkMutation(changedAt: number): Promise<void> {
    return this.automaticRuntime.recordBookmarkMutation(changedAt);
  }

  runPendingBookmarksOnForeground(): void {
    this.runAfterHuaweiSpaceBookmarkUpgradePreparation((): void => {
      this.automaticRuntime.runPendingBookmarksOnForeground();
    });
  }

  notifyPersonalizationLocalSettingsChanged(): void {
    this.automaticRuntime.notifyPersonalizationLocalSettingsChanged();
  }

  notifyHomeShortcutsChanged(): void {
    this.automaticRuntime.notifyHomeShortcutsChanged();
  }

  notifyMembershipStateChanged(): void {
    this.automaticRuntime.notifyMembershipStateChanged();
  }

  async reconcileHistoryAccountLifecycle(): Promise<SyncExperiencePersistedState> {
    this.automaticRuntime.cancelHistoryAutomaticSync();
    const settings = await this.syncService.initializeAiraSyncSettings();
    const accountUid = this.resolveHistoryAccountUid(settings);
    await this.historySyncService.cancelForIdentityChange(accountUid);
    const state = await this.reconcileHistoryAccountBinding(settings);
    await this.historySyncService.detachRemoteProjectionsExcept(accountUid);
    await this.automaticRuntime.notifyAccountChanged();
    return state;
  }

  private async reconcileHistoryAccountBinding(
    currentSettings?: AiraSyncSettings
  ): Promise<SyncExperiencePersistedState> {
    const settings = currentSettings ?? await this.syncService.initializeAiraSyncSettings();
    const initializedState = await this.experienceStateStore.initialize(
      settings.bookmarkSyncEnabled === true,
      settings.personalizationSyncEnabled === true,
      settings.remoteKind !== 'none'
    );
    const state = await this.clearHistorySelectionForWebdav(settings.remoteKind, initializedState);
    if (!state.historySelected) {
      return state;
    }
    const accountUid = this.resolveHistoryAccountUid(settings);
    const boundAccountUid = state.historyAccountUid.trim();
    if (shouldClearHistoryAccountBinding(boundAccountUid, accountUid)) {
      const cleared = await this.experienceStateStore.setHistorySelected(false);
      this.automaticRuntime.cancelHistoryAutomaticSync();
      return cleared;
    }
    if (boundAccountUid.length <= 0 && accountUid.length > 0 &&
      resolveHistorySyncProviderKind(settings.remoteKind) !== undefined) {
      return this.experienceStateStore.setHistorySelected(true, accountUid);
    }
    return state;
  }

  requestGoalChange(
    remoteKind: AiraSyncProviderKind,
    confirmed: boolean = false,
    firstActivationItems?: SyncFirstActivationItemsState
  ): Promise<SyncExperienceActionOutcome> {
    const operation = this.executeGoalChange(remoteKind, confirmed, firstActivationItems);
    return this.trackGoalChange(operation);
  }

  private async executeGoalChange(
    remoteKind: AiraSyncProviderKind,
    confirmed: boolean,
    firstActivationItems?: SyncFirstActivationItemsState
  ): Promise<SyncExperienceActionOutcome> {
    try {
      const context = await this.loadContext();
      let providerSwitchMessage = '';
      const hasNoActiveProvider = context.activeProvider === 'none';
      const needsInitialDomainActivation = hasNoActiveProvider ||
        (context.settings.bookmarkSyncEnabled !== true && context.settings.personalizationSyncEnabled !== true &&
          !context.experienceState.suspended);
      if (needsInitialDomainActivation && firstActivationItems !== undefined) {
        await this.persistFirstActivationItems(firstActivationItems);
      }
      const firstActivationSelection = this.experienceStateStore.getState();
      if (needsInitialDomainActivation && !firstActivationSelection.bookmarkSelected &&
        !firstActivationSelection.personalizationSelected && !firstActivationSelection.historySelected) {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_choose_content'),
          message: $r('app.string.settings_sync_choose_content_required')
        };
      }
      if (needsInitialDomainActivation && remoteKind === 'webdav' &&
        !firstActivationSelection.bookmarkSelected && !firstActivationSelection.personalizationSelected) {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_choose_webdav_required_title'),
          message: $r('app.string.settings_sync_choose_webdav_required')
        };
      }
      if (remoteKind === 'webdav' && context.settings.webdav.endpoint.trim().length <= 0) {
        return {
          type: 'configuration-required',
          title: $r('app.string.settings_sync_configure_webdav'),
          message: $r('app.string.settings_sync_configure_webdav_message'),
          remoteKind: 'webdav',
          enableDefaultContent: needsInitialDomainActivation
        };
      }
      if (remoteKind === 'self_hosted') {
        const selfHosted = resolveAiraPersonalServerConfig(context.settings);
        if (selfHosted.baseUrl.trim().length <= 0 || selfHosted.instanceId.trim().length <= 0 ||
          selfHosted.credentialId.trim().length <= 0 || selfHosted.deviceToken.trim().length <= 0) {
          return {
            type: 'configuration-required',
            title: $r('app.string.settings_sync_connect_self_host'),
            message: $r('app.string.settings_sync_connect_self_host_message'),
            remoteKind: 'self_hosted',
            enableDefaultContent: needsInitialDomainActivation
          };
        }
      }
      if (!hasNoActiveProvider && context.activeProvider !== remoteKind && !confirmed) {
        return {
          type: 'confirmation-required',
          title: $r('app.string.settings_sync_change_method_title'),
          message: this.resolveGoalChangeConfirmMessage(remoteKind),
          remoteKind: remoteKind
        };
      }
      const requestOutcome = await this.providerOperations.requestProviderSelection(remoteKind);
      const requestResult = this.mapProviderSelectionRequestOutcome(requestOutcome);
      if (requestResult !== undefined) {
        if (requestResult.type === 'configuration-required') {
          requestResult.enableDefaultContent = needsInitialDomainActivation;
        }
        return requestResult;
      }
      if (requestOutcome.type === 'no-action' && !needsInitialDomainActivation) {
        return {
          type: 'completed',
          title: $r('app.string.settings_sync_method_unchanged'),
          message: this.resolveGoalUnchangedMessage(remoteKind, context.settings),
          remoteKind: remoteKind
        };
      }
      if (hasNoActiveProvider && needsInitialDomainActivation) {
        return this.activateFirstSelection(remoteKind, firstActivationSelection);
      }
      if (requestOutcome.type === 'provider-selection-confirmation-required') {
        const switchOutcome = await this.providerOperations.selectProvider(remoteKind);
        const switchResult = this.mapProviderSelectionCompletionOutcome(switchOutcome);
        if (switchResult !== undefined) {
          return switchResult;
        }
        providerSwitchMessage = switchOutcome.message;
      }
      const switchLines = providerSwitchMessage.length > 0
        ? this.syncFailurePresentationService.localizeProviderMessageLines(providerSwitchMessage)
        : [];
      if (needsInitialDomainActivation) {
        const activationOutcome = await this.activateFirstSelection(
          remoteKind,
          firstActivationSelection
        );
        if (switchLines.length > 0 && activationOutcome.type === 'completed') {
          const activationLines = activationOutcome.messageLines !== undefined &&
            activationOutcome.messageLines.length > 0
            ? activationOutcome.messageLines
            : [activationOutcome.message];
          return this.withMessageLines(activationOutcome, switchLines.concat(activationLines));
        }
        return activationOutcome;
      }
      if (!this.isHuaweiBookmarkInitializationPending(this.syncService.getAiraSyncSettings())) {
        await this.refreshBookmarkRemoteStatus(remoteKind);
      }
      return this.withMessageLines({
        type: 'completed',
        title: $r('app.string.settings_sync_method_changed'),
        message: switchLines.length > 0 ? switchLines[0] : this.resolveGoalChangedMessage(remoteKind),
        remoteKind: remoteKind
      }, switchLines);
    } catch (error) {
      return this.failure($r('app.string.settings_sync_change_failed'), error as Error, remoteKind);
    }
  }

  private trackGoalChange(
    operation: Promise<SyncExperienceActionOutcome>
  ): Promise<SyncExperienceActionOutcome> {
    this.pendingGoalChangePromise = operation;
    operation.then(
      (): void => {
        this.clearPendingGoalChange(operation);
      },
      (): void => {
        this.clearPendingGoalChange(operation);
      }
    );
    return operation;
  }

  private async awaitPendingGoalChange(): Promise<void> {
    const operation = this.pendingGoalChangePromise;
    if (operation === undefined) {
      return;
    }
    try {
      await operation;
    } catch (_error) {
    }
  }

  private clearPendingGoalChange(operation: Promise<SyncExperienceActionOutcome>): void {
    if (this.pendingGoalChangePromise === operation) {
      this.pendingGoalChangePromise = undefined;
    }
  }

  async completeConfiguredGoal(remoteKind: AiraSyncProviderKind): Promise<SyncExperienceActionOutcome> {
    try {
      return await this.requestGoalChange(remoteKind, true);
    } catch (error) {
      return this.failure($r('app.string.settings_sync_open_incomplete'), error as Error, remoteKind);
    }
  }

  async requestFirstActivationWebdavConfiguration(
    firstActivationItems: SyncFirstActivationItemsState
  ): Promise<SyncExperienceActionOutcome> {
    try {
      const context = await this.loadContext();
      if (context.activeProvider !== 'none') {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_state_updated'),
          message: $r('app.string.settings_sync_state_updated_message'),
          remoteKind: 'webdav'
        };
      }
      await this.persistFirstActivationItems(firstActivationItems);
      const selection = this.experienceStateStore.getState();
      if (!selection.bookmarkSelected && !selection.personalizationSelected && !selection.historySelected) {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_choose_content'),
          message: $r('app.string.settings_sync_choose_content_required'),
          remoteKind: 'webdav'
        };
      }
      return {
        type: 'configuration-required',
        title: $r('app.string.settings_sync_configure_webdav'),
        message: $r('app.string.settings_sync_configure_webdav_message'),
        remoteKind: 'webdav',
        enableDefaultContent: true
      };
    } catch (error) {
      return this.failure($r('app.string.settings_sync_webdav_not_started'), this.normalizeError(error), 'webdav');
    }
  }

  async configureWebdavAndActivate(
    params: SyncWebdavConfigurationParams
  ): Promise<SyncExperienceActionOutcome> {
    try {
      const configurationOutcome = await this.providerOperations.saveWebdavConfiguration('active', params, true);
      if (configurationOutcome.type === 'configuration-saved') {
        return await this.completeConfiguredGoal('webdav');
      }
      if (configurationOutcome.membershipDecision !== undefined) {
        return {
          type: 'membership-required',
          title: configurationOutcome.title,
          message: configurationOutcome.message,
          remoteKind: 'webdav',
          membershipDecision: configurationOutcome.membershipDecision
        };
      }
      return {
        type: configurationOutcome.type === 'activation-blocked' ? 'blocked' : 'failed',
        title: configurationOutcome.title,
        message: configurationOutcome.message,
        remoteKind: 'webdav'
      };
    } catch (error) {
      return this.failure($r('app.string.settings_sync_webdav_not_started'), this.normalizeError(error), 'webdav');
    }
  }

  readWebdavConfigurationState(): SyncExperienceWebdavConfigurationState {
    return this.buildWebdavConfigurationState(this.syncConfigStore.getSettings());
  }

  async loadWebdavConfigurationState(): Promise<SyncExperienceWebdavConfigurationState> {
    return this.buildWebdavConfigurationState(await this.syncConfigStore.initialize());
  }

  async saveWebdavConfiguration(
    role: SyncExperienceWebdavTargetRole,
    params: SyncExperienceWebdavConfigurationParams
  ): Promise<SyncExperienceWebdavActivationOutcome> {
    return this.providerOperations.saveWebdavConfiguration(role, params);
  }

  async deactivateWebdav(): Promise<SyncExperienceWebdavActivationOutcome> {
    return this.providerOperations.deactivateWebdav();
  }

  async signInHuaweiAccountForSync(): Promise<SyncExperienceWebdavActivationOutcome> {
    return this.providerOperations.signInHuaweiAccountForSync();
  }

  async signInHuaweiAccount(): Promise<SyncActivationResult> {
    return this.providerOperations.signInHuaweiAccount();
  }

  async refreshHuaweiAccountIdentity(): Promise<SyncActivationResult> {
    return this.providerOperations.refreshHuaweiAccountIdentity();
  }

  async clearHuaweiAccountIdentity(): Promise<void> {
    return this.providerOperations.clearHuaweiAccountIdentity();
  }

  async deactivateForAppServiceMode(): Promise<void> {
    try {
      await this.providerOperations.deactivateCurrentSync();
    } catch (error) {
      throw this.normalizeError(error as Object);
    }
  }

  readAdvancedState(isPrivateSession: boolean = false): SyncExperienceAdvancedState {
    return this.buildAdvancedState(this.syncConfigStore.getSettings(), undefined, isPrivateSession);
  }

  async loadAdvancedState(isPrivateSession: boolean = false): Promise<SyncExperienceAdvancedState> {
    const settings = await this.syncConfigStore.initialize();
    if (isPrivateSession) {
      return this.buildAdvancedState(settings, undefined, true);
    }
    const enabledKinds = this.advancedViewModel.resolveEnabledRemoteKinds(settings);
    const overview = await this.advancedOperations.loadStatusOverview(enabledKinds);
    return this.buildAdvancedState(this.syncConfigStore.getSettings(), overview, false);
  }

  async readAdvancedRemoteSummary(
    remoteKind: AiraSyncRemoteKind
  ): Promise<SyncExperienceAdvancedRemoteSummaryOutcome> {
    return this.advancedOperations.readRemoteSummary(remoteKind);
  }

  async mergeAdvancedActiveBookmarks(
    remoteKind: AiraSyncRemoteKind
  ): Promise<SyncExperienceAdvancedMergeOutcome> {
    const runResult = await this.automaticRuntime.runManualBookmarkMaintenance();
    const bookmarkOutcome = runResult.bookmark;
    if (bookmarkOutcome === undefined) {
      throw new Error('书签同步尚未开启。');
    }
    if (bookmarkOutcome.result === undefined) {
      throw new Error(this.syncFailurePresentationService.buildBookmarkFailureMessage({
        remoteKind: remoteKind,
        operationName: '书签同步',
        failure: bookmarkOutcome.failure
      }));
    }
    return this.advancedOperations.presentActiveBookmarkMerge(remoteKind, bookmarkOutcome.result);
  }

  async forceAdvancedBookmarkAuthority(
    remoteKind: AiraSyncProviderKind,
    resolution: AiraBookmarkConflictResolution
  ): Promise<SyncExperienceAdvancedMergeOutcome> {
    return this.automaticRuntime.runProviderTransition(() => {
      return this.advancedOperations.forceBookmarkAuthority(remoteKind, resolution);
    });
  }

  async selectAdvancedProvider(
    remoteKind: AiraSyncRemoteKind
  ): Promise<SyncExperienceProviderSelectionPresentation> {
    return this.advancedOperations.selectProvider(remoteKind);
  }

  async setMasterEnabled(enabled: boolean): Promise<SyncExperienceActionOutcome> {
    try {
      const context = await this.loadContext();
      if (enabled && context.activeProvider === 'none') {
        return {
          type: 'configuration-required',
          title: $r('app.string.settings_sync_choose_method_title'),
          message: $r('app.string.settings_sync_choose_devices')
        };
      }
      return enabled
        ? await this.resumeExperience(context.experienceState)
        : await this.suspendExperience(context.settings, context.experienceState);
    } catch (error) {
      return this.failure(
        enabled ? $r('app.string.settings_sync_resume_failed') : $r('app.string.settings_sync_pause_failed'),
        error as Error
      );
    }
  }

  async setBookmarkSelected(selected: boolean): Promise<SyncExperienceActionOutcome> {
    try {
      const context = await this.loadContext();
      if (context.experienceState.suspended || context.activeProvider === 'none') {
        await this.experienceStateStore.setBookmarkSelected(selected);
        return {
          type: 'completed',
          title: selected
            ? $r('app.string.settings_sync_bookmarks_selected')
            : $r('app.string.settings_sync_bookmarks_paused_choice'),
          message: context.experienceState.suspended
            ? $r('app.string.settings_sync_resume_choice')
            : $r('app.string.settings_sync_apply_choice')
        };
      }
      const outcome = await this.providerOperations.setBookmarkDomainEnabled(selected);
      if (outcome.type === 'bookmark-domain-enabled' || outcome.type === 'bookmark-domain-disabled') {
        if (selected) {
          await this.completeHuaweiSpaceBookmarkUpgradeIfNeeded(context.activeProvider);
          if (!this.isHuaweiBookmarkInitializationPending(this.syncService.getAiraSyncSettings())) {
            await this.refreshBookmarkRemoteStatus(context.activeProvider);
          }
        }
        await this.experienceStateStore.setBookmarkSelected(selected);
        return {
          type: 'completed',
          title: selected
            ? $r('app.string.settings_sync_bookmarks_on')
            : $r('app.string.settings_sync_bookmarks_paused'),
          message: this.syncFailurePresentationService.localizeKnownProviderMessage(outcome.message)
        };
      }
      return this.mapProviderSelectionFailure(outcome);
    } catch (error) {
      const activeProvider = this.syncService.getAiraSyncSettings().remoteKind;
      return {
        type: 'failed',
        title: selected
          ? $r('app.string.settings_sync_bookmarks_not_on')
          : $r('app.string.settings_sync_bookmarks_not_off'),
        message: this.syncFailurePresentationService.buildBookmarkFailureResource({
          remoteKind: activeProvider,
          operationName: selected ? '开启书签同步' : '暂停书签同步',
          failure: this.syncService.resolveBookmarkSyncFailure(error as Error)
        })
      };
    }
  }

  async setHistorySelected(selected: boolean): Promise<SyncExperienceActionOutcome> {
    try {
      const context = await this.loadContext();
      if (!selected) {
        await this.experienceStateStore.setHistorySelected(false);
        this.automaticRuntime.cancelHistoryAutomaticSync();
        return {
          type: 'completed',
          title: $r('app.string.settings_sync_history_paused'),
          message: this.resolveHistoryPausedMessage(context.activeProvider)
        };
      }
      if (context.activeProvider === 'none') {
        return {
          type: 'configuration-required',
          title: $r('app.string.settings_sync_choose_method_before_history'),
          message: $r('app.string.settings_sync_history_follows')
        };
      }
      if (context.activeProvider === 'webdav') {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_webdav_no_history'),
          message: $r('app.string.settings_sync_webdav_no_history_message')
        };
      }
      const accountUid = this.resolveHistoryAccountUid(context.settings);
      if (accountUid.length <= 0) {
        return {
          type: 'configuration-required',
          title: context.activeProvider === 'self_hosted'
            ? $r('app.string.settings_sync_connect_self_host_first')
            : $r('app.string.settings_sync_sign_in_huawei'),
          message: $r('app.string.settings_sync_history_location'),
          remoteKind: context.activeProvider === 'self_hosted' ? 'self_hosted' : undefined
        };
      }
      if (context.activeProvider === 'aira_cloud') {
        const decision = await this.membershipFeature.canUse(AIRA_FEATURE_CLOUD_SYNC, {
          dataScope: 'profile_persistent',
          privacyMode: 'regular',
          loggedIn: true
        });
        if (!decision.allowed) {
          return {
            type: 'membership-required',
            title: decision.title.length > 0 ? decision.title : $r('app.string.settings_sync_cloud_needs_pro'),
            message: decision.message,
            membershipDecision: decision
          };
        }
      }
      await this.experienceStateStore.setHistorySelected(true, accountUid);
      if (context.experienceState.suspended) {
        return {
          type: 'completed',
          title: $r('app.string.settings_sync_history_selected'),
          message: $r('app.string.settings_sync_history_resume')
        };
      }
      this.automaticRuntime.scheduleEnabledHistorySync();
      return {
        type: 'completed',
        title: $r('app.string.settings_sync_history_on'),
        message: $r('app.string.settings_sync_history_on_message')
      };
    } catch (error) {
      return this.failure($r('app.string.settings_sync_history_failed'), this.normalizeError(error));
    }
  }

  private resolveHistoryProviderLabel(provider: AiraSyncRemoteKind): string {
    if (provider === 'huawei_space') {
      return '华为云空间';
    }
    if (provider === 'aira_cloud') {
      return 'Aira 云';
    }
    if (provider === 'self_hosted') {
      return '私有化部署';
    }
    return '云端';
  }

  private resolveHistoryPausedMessage(provider: AiraSyncRemoteKind): ResourceStr {
    if (provider === 'huawei_space') {
      return $r('app.string.settings_sync_history_kept_huawei');
    }
    if (provider === 'aira_cloud') {
      return $r('app.string.settings_sync_history_kept_cloud');
    }
    if (provider === 'self_hosted') {
      return $r('app.string.settings_sync_history_kept_self_host');
    }
    return $r('app.string.settings_sync_history_kept_remote');
  }

  private resolveGoalChangeConfirmMessage(remoteKind: AiraSyncProviderKind): ResourceStr {
    return this.resolveNamedGoalMessage(
      remoteKind,
      $r('app.string.settings_sync_change_to_cloud'),
      $r('app.string.settings_sync_change_to_huawei'),
      $r('app.string.settings_sync_change_to_webdav'),
      $r('app.string.settings_sync_change_to_self_host'),
      'settings_sync_change_to_named'
    );
  }

  private resolveGoalUnchangedMessage(
    remoteKind: AiraSyncProviderKind,
    settings: AiraSyncSettings
  ): ResourceStr {
    return this.resolveNamedGoalMessage(
      remoteKind,
      $r('app.string.settings_sync_using_cloud'),
      $r('app.string.settings_sync_using_huawei'),
      $r('app.string.settings_sync_using_webdav'),
      $r('app.string.settings_sync_using_self_host'),
      'settings_sync_using_named',
      settings
    );
  }

  private resolveGoalChangedMessage(remoteKind: AiraSyncProviderKind): ResourceStr {
    return this.resolveNamedGoalMessage(
      remoteKind,
      $r('app.string.settings_sync_now_using_cloud'),
      $r('app.string.settings_sync_now_using_huawei'),
      $r('app.string.settings_sync_now_using_webdav'),
      $r('app.string.settings_sync_now_using_self_host'),
      'settings_sync_now_using_named'
    );
  }

  private resolveNamedGoalMessage(
    remoteKind: AiraSyncProviderKind,
    cloud: ResourceStr,
    huawei: ResourceStr,
    webdav: ResourceStr,
    selfHosted: ResourceStr,
    namedKey: string,
    settings?: AiraSyncSettings
  ): ResourceStr {
    if (remoteKind === 'huawei_space') {
      return huawei;
    }
    if (remoteKind === 'self_hosted') {
      return selfHosted;
    }
    if (remoteKind === 'webdav') {
      const label = this.viewModel.resolveGoalLabel(remoteKind, settings);
      if (label === 'WebDAV 同步') {
        return webdav;
      }
      if (namedKey === 'settings_sync_change_to_named') {
        return $r('app.string.settings_sync_change_to_named', label);
      }
      if (namedKey === 'settings_sync_using_named') {
        return $r('app.string.settings_sync_using_named', label);
      }
      return $r('app.string.settings_sync_now_using_named', label);
    }
    return cloud;
  }

  private readableOutcomeText(value: ResourceStr): string {
    return typeof value === 'string' ? value : '';
  }

  async setPersonalizationItemSelected(
    id: PersonalizationSyncContentId,
    selected: boolean
  ): Promise<SyncExperienceActionOutcome> {
    let previousConfig: PersonalizationSyncConfig | undefined = undefined;
    let previousBookshelfSelection: NovelBookshelfSyncSelectionState | undefined = undefined;
    try {
      const context = await this.loadContext();
      previousConfig = await this.personalizationConfigStore.initialize();
      previousBookshelfSelection = await this.personalizationDomain.initializeNovelBookshelfSelection();
      const activeExperience = context.activeProvider !== 'none' && !context.experienceState.suspended;
      const domainEnabled = context.settings.personalizationSyncEnabled === true;
      const hadSelectedItems = activeExperience && !domainEnabled
        ? false
        : this.hasEnabledPersonalizationContent(previousConfig, previousBookshelfSelection.enabled);
      if (activeExperience && !domainEnabled && selected) {
        await this.clearRetainedPersonalizationSelections(
          previousConfig,
          previousBookshelfSelection.enabled,
          id
        );
      }
      const updateOutcome = await this.personalizationDomain.updateItemEnabled(id, selected);
      if (!updateOutcome.ok) {
        throw new Error(updateOutcome.message);
      }
      const hasSelectedItems = this.hasEnabledPersonalizationContent(
        updateOutcome.config,
        updateOutcome.novelBookshelfSelection.enabled
      );
      if (!activeExperience) {
        await this.experienceStateStore.setPersonalizationSelected(hasSelectedItems);
        return {
          type: 'completed',
          title: $r('app.string.settings_sync_content_saved'),
          message: context.experienceState.suspended
            ? $r('app.string.settings_sync_content_resume')
            : $r('app.string.settings_sync_content_after_method'),
          personalizationConfig: updateOutcome.config
        };
      }
      if (!hadSelectedItems && hasSelectedItems) {
        const result = await this.enablePersonalizationDomain();
        if (!result.ok) {
          throw new Error(result.message);
        }
      } else if (hadSelectedItems && !hasSelectedItems) {
        await this.disablePersonalizationDomain();
      }
      await this.experienceStateStore.setPersonalizationSelected(hasSelectedItems);
      if (selected) {
        this.automaticRuntime.notifyPersonalizationLocalSettingsChanged();
      }
      return {
        type: 'completed',
        title: selected
          ? $r('app.string.settings_sync_content_on')
          : $r('app.string.settings_sync_content_off'),
        message: hasSelectedItems
          ? $r('app.string.settings_sync_content_saved_sync')
          : $r('app.string.settings_sync_content_all_paused'),
        personalizationConfig: updateOutcome.config
      };
    } catch (_error) {
      let restored: boolean = true;
      if (previousConfig !== undefined && previousBookshelfSelection !== undefined) {
        await this.personalizationDomain.restoreContentSelection(
          previousConfig,
          previousBookshelfSelection.enabled
        ).catch((_restoreError: Error): void => {
          restored = false;
        });
      }
      if (!restored) {
        return {
          type: 'failed',
          title: $r('app.string.settings_sync_selection_unconfirmed'),
          message: $r('app.string.settings_sync_selection_unconfirmed_message'),
          personalizationConfig: this.personalizationConfigStore.getConfig()
        };
      }
      return this.personalizationContentFailure(
        selected ? $r('app.string.settings_sync_content_not_on') : $r('app.string.settings_sync_content_not_off'),
        this.personalizationConfigStore.getConfig()
      );
    }
  }

  async syncNow(): Promise<SyncExperienceActionOutcome> {
    try {
      await this.prepareHuaweiSpaceBookmarkUpgrade();
      const settings = this.syncService.getAiraSyncSettings();
      if (this.isHuaweiSpaceBookmarkUpgradeRequired(settings)) {
        return this.setBookmarkSelected(true);
      }
      return this.runEnabledDomains('sync');
    } catch (error) {
      return this.failure($r('app.string.settings_sync_now_failed'), error as Error, undefined, undefined, 'sync');
    }
  }

  async backupNow(): Promise<SyncExperienceActionOutcome> {
    return this.runEnabledDomains('backup');
  }

  async loadAdditionalBackup(isPrivateSession: boolean = false): Promise<SyncAdditionalBackupViewState> {
    const settings = await this.syncConfigStore.initialize();
    const centerState = this.settingsCenterViewModel.buildState({
      settings: settings,
      hasCloudConfig: settings.huaweiCloud.uid.trim().length > 0,
      hasHuaweiSpaceConfig: settings.huaweiSpace.uid.trim().length > 0,
      hasWebdavConfig: settings.webdav.endpoint.trim().length > 0 && settings.webdav.username.trim().length > 0,
      huaweiSpaceReadiness: settings.huaweiSpace.uid.trim().length > 0 ? 'ready' : 'needs_account',
      isPrivateSession: isPrivateSession
    });
    return this.additionalBackupViewModel.buildState(settings, centerState.additionalBackupProviderCards);
  }

  async setAdditionalBackupEnabled(enabled: boolean): Promise<SyncAdditionalBackupActionOutcome> {
    try {
      const settings = await this.syncConfigStore.initialize();
      const backupKinds = settings.additionalBackupRemoteKinds ?? [];
      if (enabled && backupKinds.length <= 0) {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_backup_setup_title'),
          message: $r('app.string.settings_sync_backup_setup_message'),
          requiresOptions: true
        };
      }
      await this.syncConfigStore.setAdditionalBackupEnabled(enabled);
      return {
        type: 'completed',
        title: enabled
          ? $r('app.string.settings_sync_backup_enabled')
          : $r('app.string.settings_sync_backup_paused_done'),
        message: enabled
          ? $r('app.string.settings_sync_backup_enabled_message')
          : $r('app.string.settings_sync_backup_paused_message')
      };
    } catch (error) {
      return this.additionalBackupFailure($r('app.string.settings_sync_backup_settings_failed'), error as Error);
    }
  }

  async setAdditionalBackupIntervalDays(
    days: AiraAdditionalBackupIntervalDays
  ): Promise<SyncAdditionalBackupActionOutcome> {
    try {
      await this.syncConfigStore.setAdditionalBackupIntervalDays(days);
      return {
        type: 'completed',
        title: $r('app.string.settings_sync_backup_frequency_updated'),
        message: days === 1
          ? $r('app.string.settings_sync_backup_frequency_daily_message')
          : $r('app.string.settings_sync_backup_frequency_days_message', days)
      };
    } catch (error) {
      return this.additionalBackupFailure($r('app.string.settings_sync_backup_frequency_failed'), error as Error);
    }
  }

  async setAdditionalBackupProviderEnabled(
    remoteKind: AiraSyncProviderKind,
    enabled: boolean
  ): Promise<SyncExperienceProviderSelectionOutcome> {
    const outcome = await this.providerOperations.setAdditionalBackupEnabled(remoteKind, enabled);
    if (enabled && outcome.type === 'additional-backup-enabled') {
      await this.completeHuaweiSpaceBookmarkUpgradeIfNeeded(remoteKind);
    }
    if (outcome.type === 'additional-backup-disabled') {
      const settings = this.syncConfigStore.getSettings();
      if ((settings.additionalBackupRemoteKinds ?? []).length <= 0) {
        await this.syncConfigStore.setAdditionalBackupEnabled(false);
      }
    }
    return outcome;
  }

  async runAdditionalBackupNow(): Promise<SyncAdditionalBackupActionOutcome> {
    try {
      const settings = await this.syncConfigStore.initialize();
      const readiness = this.validateAdditionalBackupNow(settings);
      if (readiness !== undefined) {
        return readiness;
      }
      const outcome = await this.backupNow();
      return {
        type: outcome.type === 'completed' ? 'completed' : outcome.type === 'blocked' ? 'blocked' : 'failed',
        title: outcome.title,
        message: outcome.message,
        messageLines: outcome.messageLines
      };
    } catch (error) {
      return this.additionalBackupFailure($r('app.string.settings_sync_backup_now_failed'), error as Error);
    }
  }

  private async runEnabledDomains(mode: 'sync' | 'backup'): Promise<SyncExperienceActionOutcome> {
    try {
      const context = await this.loadContext();
      const isBackup = mode === 'backup';
      if (!isBackup && context.experienceState.suspended) {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_paused_title'),
          message: $r('app.string.settings_sync_paused_retry_message')
        };
      }
      const networkSnapshot = this.networkAvailabilityService.refresh();
      if (networkSnapshot.reliable && !networkSnapshot.available) {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_offline'),
          message: isBackup
            ? $r('app.string.settings_sync_backup_offline')
            : $r('app.string.settings_sync_offline_sync')
        };
      }
      const issues: SyncExperienceDomainIssue[] = [];
      let bookmarkFinished = false;
      let personalizationFinished = false;
      let historyFinished = false;
      let bookmarkBackedUp = false;
      let personalizationBackedUp = false;
      const runResult: SyncExperienceRuntimeRunResult = await this.automaticRuntime.runManual(mode);
      if (context.settings.bookmarkSyncEnabled === true && runResult.bookmark !== undefined) {
        const bookmarkOutcome = runResult.bookmark;
        if (bookmarkOutcome.type === 'failed' || bookmarkOutcome.type === 'blocked') {
          issues.push({
            domain: 'bookmark',
            type: bookmarkOutcome.type,
            message: bookmarkOutcome.message,
            failure: bookmarkOutcome.failure
          });
        } else if (isBackup) {
          bookmarkBackedUp = true;
        } else {
          bookmarkFinished = true;
        }
      }
      if (context.settings.personalizationSyncEnabled === true && runResult.personalization !== undefined) {
        const personalizationOutcome = runResult.personalization;
        if (personalizationOutcome.type === 'failed') {
          issues.push({
            domain: 'personalization',
            type: 'failed',
            message: personalizationOutcome.message
          });
        } else if (isBackup) {
          personalizationBackedUp = true;
        } else {
          personalizationFinished = true;
        }
      }
      if (!isBackup && context.experienceState.historySelected && runResult.history !== undefined) {
        if (!runResult.history.ok) {
          issues.push({
            domain: 'history',
            type: 'failed',
            message: runResult.history.message
          });
        } else {
          historyFinished = true;
        }
      }
      if (issues.length > 0) {
        if (isBackup) {
          return this.withMessageLines({
            type: issues.some((issue: SyncExperienceDomainIssue): boolean => issue.type === 'failed')
              ? 'failed'
              : 'blocked',
            title: $r('app.string.settings_sync_backup_attention'),
            message: $r('app.string.settings_sync_backup_attention'),
            remoteKind: context.activeProvider === 'none' ? undefined : context.activeProvider,
            requiresBookmarkResolution: issues.some((issue: SyncExperienceDomainIssue): boolean => {
              return issue.domain === 'bookmark' && issue.type === 'blocked';
            })
          }, this.resolveBackupIssueLines(
            issues,
            context.activeProvider,
            bookmarkBackedUp,
            personalizationBackedUp
          ));
        }
        return {
          type: issues.some((issue: SyncExperienceDomainIssue): boolean => issue.type === 'failed')
            ? 'failed'
            : 'blocked',
          title: $r('app.string.settings_sync_attention'),
          message: this.resolveManualSyncIssueLines(issues, context.activeProvider)[0],
          messageLines: this.manualSyncIssueLinesOrUndefined(issues, context.activeProvider),
          remoteKind: context.activeProvider === 'none' ? undefined : context.activeProvider,
          retryAction: 'sync',
          requiresBookmarkResolution: issues.some((issue: SyncExperienceDomainIssue): boolean => {
            return issue.domain === 'bookmark' && issue.type === 'blocked';
          })
        };
      }
      if (isBackup) {
        const backupFailureLines = this.resolveAdditionalBackupFailureLines(
          this.syncConfigStore.getSettings()
        );
        if (backupFailureLines.length > 0) {
          return this.withMessageLines({
            type: 'failed',
            title: $r('app.string.settings_sync_backup_attention'),
            message: backupFailureLines[0],
            remoteKind: context.activeProvider === 'none' ? undefined : context.activeProvider
          }, this.appendBackupCompletedLines(
            backupFailureLines,
            bookmarkBackedUp,
            personalizationBackedUp
          ));
        }
      }
      return {
        type: 'completed',
        title: isBackup ? $r('app.string.settings_sync_backup_done') : $r('app.string.settings_sync_done'),
        message: isBackup
          ? this.resolveBackupSuccessMessage(bookmarkBackedUp, personalizationBackedUp)
          : this.resolveManualSyncSuccessMessage(bookmarkFinished, personalizationFinished, historyFinished)
      };
    } catch (error) {
      return this.failure(
        mode === 'backup' ? $r('app.string.settings_sync_backup_now_failed') : $r('app.string.settings_sync_now_failed'),
        error as Error,
        undefined,
        undefined,
        mode === 'backup' ? undefined : 'sync'
      );
    }
  }

  private withMessageLines(
    outcome: SyncExperienceActionOutcome,
    lines: ResourceStr[]
  ): SyncExperienceActionOutcome {
    if (lines.length === 0) {
      return outcome;
    }
    outcome.message = lines[0];
    outcome.messageLines = lines.length > 1 ? lines : undefined;
    return outcome;
  }

  private manualSyncIssueLinesOrUndefined(
    issues: SyncExperienceDomainIssue[],
    activeProvider: AiraSyncRemoteKind
  ): ResourceStr[] | undefined {
    const lines = this.resolveManualSyncIssueLines(issues, activeProvider);
    return lines.length > 1 ? lines : undefined;
  }

  private resolveManualSyncIssueLines(
    issues: SyncExperienceDomainIssue[],
    activeProvider: AiraSyncRemoteKind
  ): ResourceStr[] {
    const lines: ResourceStr[] = [];
    for (let index = 0; index < issues.length; index += 1) {
      lines.push(this.resolveManualSyncIssueLine(issues[index], activeProvider));
    }
    if (lines.length === 0) {
      lines.push($r('app.string.settings_sync_attention_generic'));
    }
    return lines;
  }

  private resolveManualSyncIssueLine(
    issue: SyncExperienceDomainIssue,
    activeProvider: AiraSyncRemoteKind
  ): ResourceStr {
    if (issue.domain === 'bookmark') {
      return this.syncFailurePresentationService.buildBookmarkFailureResource({
        remoteKind: activeProvider,
        operationName: '书签同步',
        failure: issue.failure
      });
    }
    const detail = issue.message !== undefined ? issue.message.trim() : '';
    const known = detail.length > 0
      ? this.syncFailurePresentationService.matchKnownProviderLine(detail)
      : undefined;
    if (known !== undefined) {
      return known;
    }
    if (issue.domain === 'history') {
      return detail.length > 0
        ? $r('app.string.settings_sync_history_incomplete_detail', detail)
        : $r('app.string.settings_sync_history_incomplete');
    }
    const guidance = activeProvider === 'huawei_space'
      ? this.syncFailurePresentationService.buildHuaweiSpacePersonalizationSystemUpdateGuidance(detail)
      : '';
    if (guidance.length > 0) {
      return $r('app.string.settings_sync_personalization_incomplete_update');
    }
    return detail.length > 0
      ? $r('app.string.settings_sync_line_content_raw', detail)
      : $r('app.string.settings_sync_personalization_incomplete');
  }

  private localizeLabeledFailure(message: string, labeled: ResourceStr): ResourceStr {
    const known = this.syncFailurePresentationService.matchKnownProviderLine(message);
    return known !== undefined ? known : labeled;
  }

  private resolveBackupSuccessMessage(
    bookmarkBackedUp: boolean,
    personalizationBackedUp: boolean
  ): ResourceStr {
    if (bookmarkBackedUp && personalizationBackedUp) {
      return $r('app.string.settings_sync_backup_done_both');
    }
    if (bookmarkBackedUp) {
      return $r('app.string.settings_sync_backup_done_bookmarks');
    }
    if (personalizationBackedUp) {
      return $r('app.string.settings_sync_backup_done_personalization');
    }
    return $r('app.string.settings_sync_backup_nothing');
  }

  private resolveBackupIssueLines(
    issues: SyncExperienceDomainIssue[],
    activeProvider: AiraSyncRemoteKind,
    bookmarkBackedUp: boolean,
    personalizationBackedUp: boolean
  ): ResourceStr[] {
    const lines: ResourceStr[] = [];
    for (let index = 0; index < issues.length; index += 1) {
      lines.push(this.resolveBackupIssueLine(issues[index], activeProvider));
    }
    return this.appendBackupCompletedLines(lines, bookmarkBackedUp, personalizationBackedUp);
  }

  private resolveBackupIssueLine(
    issue: SyncExperienceDomainIssue,
    activeProvider: AiraSyncRemoteKind
  ): ResourceStr {
    if (issue.domain === 'bookmark') {
      return this.syncFailurePresentationService.buildBookmarkFailureResource({
        remoteKind: activeProvider,
        operationName: '书签备份',
        failure: issue.failure
      });
    }
    const detail = issue.message !== undefined ? issue.message : '';
    const guidance = activeProvider === 'huawei_space'
      ? this.syncFailurePresentationService.buildHuaweiSpacePersonalizationSystemUpdateGuidance(detail)
      : '';
    return guidance.length > 0
      ? $r('app.string.settings_sync_backup_personalization_incomplete_update')
      : $r('app.string.settings_sync_backup_personalization_incomplete');
  }

  private appendBackupCompletedLines(
    lines: ResourceStr[],
    bookmarkBackedUp: boolean,
    personalizationBackedUp: boolean
  ): ResourceStr[] {
    const next = lines.slice(0);
    if (bookmarkBackedUp) {
      next.push($r('app.string.settings_sync_backup_done_bookmarks'));
    }
    if (personalizationBackedUp) {
      next.push($r('app.string.settings_sync_backup_done_personalization'));
    }
    if (next.length === 0) {
      next.push($r('app.string.settings_sync_backup_attention'));
    }
    return next;
  }

  private resolveManualSyncSuccessMessage(
    bookmarkFinished: boolean,
    personalizationFinished: boolean,
    historyFinished: boolean
  ): ResourceStr {
    if (bookmarkFinished && personalizationFinished && historyFinished) {
      return $r('app.string.settings_sync_done_all');
    }
    if (bookmarkFinished && personalizationFinished) {
      return $r('app.string.settings_sync_done_bookmarks_personalization');
    }
    if (bookmarkFinished && historyFinished) {
      return $r('app.string.settings_sync_done_bookmarks_history');
    }
    if (personalizationFinished && historyFinished) {
      return $r('app.string.settings_sync_done_personalization_history');
    }
    if (bookmarkFinished) {
      return $r('app.string.settings_sync_done_bookmarks');
    }
    if (personalizationFinished) {
      return $r('app.string.settings_sync_done_personalization');
    }
    if (historyFinished) {
      return $r('app.string.settings_sync_done_history');
    }
    return $r('app.string.settings_sync_nothing_to_sync');
  }

  async resolveBookmarkConflicts(
    remoteKind: AiraSyncProviderKind,
    resolution: AiraBookmarkConflictResolution
  ): Promise<SyncExperienceActionOutcome> {
    try {
      let completesFirstActivation = false;
      const result = await this.automaticRuntime.runProviderTransition(
        async (): Promise<AiraBookmarkMergeSyncResult> => {
          const beforeResolution = this.syncService.getAiraSyncSettings();
          completesFirstActivation = beforeResolution.remoteKind === 'none' &&
            beforeResolution.bookmarkSyncEnabled !== true &&
            beforeResolution.personalizationSyncEnabled !== true;
          return this.syncService.resolveAiraBookmarkConflicts(remoteKind, resolution);
        }
      );
      if (result.blocked) {
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_conflicts_remain'),
          message: result.summary,
          remoteKind: remoteKind,
          requiresBookmarkResolution: true
        };
      }
      await this.refreshBookmarkRemoteStatus(remoteKind);
      const settings = this.syncService.getAiraSyncSettings();
      if (settings.remoteKind !== remoteKind) {
        const selection = await this.providerOperations.selectProvider(remoteKind);
        const selectionFailure = this.mapProviderSelectionCompletionOutcome(selection);
        if (selectionFailure !== undefined) {
          return selectionFailure;
        }
      }
      const activationSelection = this.experienceStateStore.getState();
      const currentSettings = this.syncService.getAiraSyncSettings();
      if (currentSettings.remoteKind === remoteKind && currentSettings.bookmarkSyncEnabled !== true &&
        activationSelection.bookmarkSelected) {
        await this.syncService.setBookmarkSyncEnabled(true);
        this.automaticRuntime.scheduleBookmarkPeriodicSync();
      }
      await this.completeHuaweiSpaceBookmarkUpgradeIfNeeded(remoteKind);
      if (completesFirstActivation) {
        if (activationSelection.personalizationSelected) {
          const personalizationResult = await this.enablePersonalizationDomain();
          if (!personalizationResult.ok) {
            return this.firstActivationFailure(
              $r('app.string.settings_sync_open_incomplete'),
              personalizationResult.message,
              remoteKind
            );
          }
        }
        await this.experienceStateStore.setSelections(
          activationSelection.bookmarkSelected,
          activationSelection.personalizationSelected,
          false
        );
      }
      return {
        type: 'completed',
        title: $r('app.string.settings_sync_conflicts_done'),
        message: result.summary.length > 0
          ? this.syncFailurePresentationService.localizeBookmarkSummary(result.summary)
          : $r('app.string.settings_sync_conflicts_done_message'),
        remoteKind: remoteKind
      };
    } catch (error) {
      const bookmarkFailure = this.syncService.resolveBookmarkSyncFailure(error as Error);
      return {
        type: 'failed',
        title: $r('app.string.settings_sync_conflicts_failed'),
        message: this.syncFailurePresentationService.buildBookmarkFailureResource({
          remoteKind: remoteKind,
          operationName: '处理书签冲突',
          failure: bookmarkFailure
        }),
        remoteKind: remoteKind,
        bookmarkFailure: bookmarkFailure
      };
    }
  }

  private async activateFirstSelection(
    remoteKind: AiraSyncProviderKind,
    selection: SyncExperiencePersistedState
  ): Promise<SyncExperienceActionOutcome> {
    try {
      const providerSelection = await this.providerOperations.selectProvider(remoteKind, {
        bookmarks: false,
        personalization: false,
        history: false
      });
      const providerSelectionFailure = this.mapProviderSelectionCompletionOutcome(providerSelection);
      if (providerSelectionFailure !== undefined) {
        return providerSelectionFailure;
      }
      const failures: ResourceStr[] = [];
      let bookmarkBlockedOutcome: SyncExperienceProviderOutcome | undefined = undefined;
      let completedDomainCount = 0;
      if (selection.bookmarkSelected) {
        const bookmarkOutcome = await this.providerOperations.setBookmarkDomainEnabled(true);
        if (bookmarkOutcome.type === 'bookmark-domain-enabled') {
          completedDomainCount += 1;
        } else if (bookmarkOutcome.type === 'bookmark-domain-blocked') {
          bookmarkBlockedOutcome = bookmarkOutcome;
        } else {
          failures.push(bookmarkOutcome.bookmarkFailure === undefined
            ? this.syncFailurePresentationService.localizeProviderLine(bookmarkOutcome.message)
            : this.syncFailurePresentationService.buildBookmarkFailureResource({
              remoteKind: bookmarkOutcome.remoteKind,
              operationName: '开启书签同步',
              failure: bookmarkOutcome.bookmarkFailure
            }));
        }
      }
      if (selection.personalizationSelected) {
        const personalizationResult = await this.enablePersonalizationDomain();
        if (personalizationResult.ok) {
          completedDomainCount += 1;
        } else {
          failures.push(this.syncFailurePresentationService.localizePrefixedContentLine(personalizationResult.message));
        }
      }
      if (selection.historySelected && remoteKind !== 'webdav') {
        const historyOutcome = await this.setHistorySelected(true);
        if (historyOutcome.type === 'completed') {
          completedDomainCount += 1;
        } else {
          failures.push(typeof historyOutcome.message === 'string'
            ? this.syncFailurePresentationService.localizePrefixedHistoryLine(historyOutcome.message)
            : historyOutcome.message);
        }
      }
      if (selection.bookmarkSelected &&
        !this.isHuaweiBookmarkInitializationPending(this.syncService.getAiraSyncSettings())) {
        void this.refreshBookmarkRemoteStatus(remoteKind);
      }
      const historySelected = remoteKind !== 'webdav' && selection.historySelected;
      await this.experienceStateStore.setSelections(
        selection.bookmarkSelected,
        selection.personalizationSelected,
        false,
        historySelected
      );
      if (bookmarkBlockedOutcome !== undefined) {
        const blockedSummary = this.syncFailurePresentationService.localizeBookmarkSummary(
          bookmarkBlockedOutcome.message
        );
        return {
          type: 'blocked',
          title: $r('app.string.settings_sync_bookmarks_need_attention'),
          message: completedDomainCount > 0 && typeof blockedSummary === 'string'
            ? $r('app.string.settings_sync_bookmarks_blocked_continue', blockedSummary)
            : blockedSummary,
          remoteKind: remoteKind,
          requiresBookmarkResolution: true
        };
      }
      if (failures.length > 0) {
        const failureLines = failures.slice(0);
        if (completedDomainCount > 0) {
          failureLines.push($r('app.string.settings_sync_open_partial_note'));
        }
        return this.withMessageLines({
          type: 'failed',
          title: $r('app.string.settings_sync_open_incomplete'),
          message: failureLines[0],
          remoteKind: remoteKind
        }, failureLines);
      }
      return {
        type: 'completed',
        title: $r('app.string.settings_sync_opened'),
        message: this.buildFirstActivationSuccessMessage(selection, remoteKind),
        remoteKind: remoteKind
      };
    } catch (error) {
      return this.firstActivationFailure(
        $r('app.string.settings_sync_open_incomplete'),
        this.normalizeError(error).message,
        remoteKind
      );
    }
  }

  private async runHuaweiSpaceBookmarkUpgradePreparation(): Promise<void> {
    const startedAt = Date.now();
    AiraSyncJankProbe.mark('upgrade_prep_start');
    const settings = await this.syncService.initializeAiraSyncSettings();
    const huaweiBookmarkSelected = settings.remoteKind === 'huawei_space';
    const affectedLegacySelection = huaweiBookmarkSelected && settings.bookmarkSyncEnabled === true &&
      settings.huaweiSpace.uid.trim().length > 0;
    const upgradeState = await this.huaweiSpaceBookmarkUpgradeStore.prepareCurrentVersion(
      affectedLegacySelection
    );
    if (upgradeState.requiredVersion <= 0) {
      AiraSyncJankProbe.end('upgrade_prep', startedAt);
      return;
    }
    await this.automaticRuntime.runProviderTransition(async (): Promise<void> => {
      await this.syncConfigStore.prepareHuaweiSpaceBookmarkReenable();
      if (settings.remoteKind === 'huawei_space') {
        this.automaticRuntime.cancelBookmarkAutomaticSync();
      }
    });
    AiraSyncJankProbe.endExtra('upgrade_prep', startedAt, 'reenable');
  }

  private runAfterHuaweiSpaceBookmarkUpgradePreparation(action: () => void): void {
    void this.prepareHuaweiSpaceBookmarkUpgrade()
      .then((): void => {
        action();
      })
      .catch((_error: Error): void => {
        action();
      });
  }

  private isHuaweiSpaceBookmarkUpgradeRequired(settings: AiraSyncSettings): boolean {
    return settings.remoteKind === 'huawei_space' &&
      this.huaweiSpaceBookmarkUpgradeStore.isCurrentVersionRequired();
  }

  private async completeHuaweiSpaceBookmarkUpgradeIfNeeded(remoteKind: AiraSyncRemoteKind): Promise<void> {
    if (remoteKind !== 'huawei_space' ||
      !this.huaweiSpaceBookmarkUpgradeStore.isCurrentVersionRequired()) {
      return;
    }
    const settings = this.syncService.getAiraSyncSettings();
    const activeHuaweiBookmark = settings.remoteKind === 'huawei_space' &&
      settings.bookmarkSyncEnabled === true;
    if (!activeHuaweiBookmark) {
      return;
    }
    const bookmarkRuntime = resolveAiraSyncDomainRuntimeState(settings, 'huawei_space', 'bookmark');
    if ((settings.pendingBookmarkSyncAt ?? 0) > 0 || bookmarkRuntime.lastSuccessAt <= 0 || bookmarkRuntime.blocked) {
      return;
    }
    await this.huaweiSpaceBookmarkUpgradeStore.markCompleted();
  }

  private isHuaweiBookmarkInitializationPending(settings: AiraSyncSettings): boolean {
    if (settings.remoteKind !== 'huawei_space' || settings.bookmarkSyncEnabled !== true ||
      (settings.pendingBookmarkSyncAt ?? 0) <= 0) {
      return false;
    }
    return resolveAiraSyncDomainRuntimeState(settings, 'huawei_space', 'bookmark').lastSuccessAt <= 0;
  }

  private async persistFirstActivationItems(state: SyncFirstActivationItemsState): Promise<void> {
    await this.personalizationConfigStore.initialize();
    const bookmarkSelected = state.items.some((item: SyncFirstActivationItemState): boolean => {
      return item.id === 'bookmarks' && item.enabled;
    });
    const historySelected = state.items.some((item: SyncFirstActivationItemState): boolean => {
      return item.id === 'history' && item.enabled;
    });
    let personalizationSelected = false;
    for (let index = 0; index < PERSONALIZATION_SYNC_ITEM_IDS.length; index += 1) {
      const id: PersonalizationSyncItemId = PERSONALIZATION_SYNC_ITEM_IDS[index];
      const item = state.items.find((value: SyncFirstActivationItemState): boolean => value.id === id);
      const enabled = item?.enabled !== false;
      personalizationSelected = personalizationSelected || enabled;
      await this.personalizationConfigStore.setItemEnabled(id, enabled, enabled ? 0 : Date.now());
    }
    const bookshelfItem = state.items.find((value: SyncFirstActivationItemState): boolean => {
      return value.id === 'novel_bookshelf';
    });
    const bookshelfEnabled = bookshelfItem?.enabled !== false;
    const bookshelfOutcome = await this.personalizationDomain.updateItemEnabled(
      'novel_bookshelf',
      bookshelfEnabled
    );
    if (!bookshelfOutcome.ok) {
      throw new Error(bookshelfOutcome.message);
    }
    personalizationSelected = personalizationSelected || bookshelfEnabled;
    await this.experienceStateStore.setSelections(
      bookmarkSelected,
      personalizationSelected,
      false,
      historySelected
    );
  }

  private async refreshBookmarkRemoteStatus(remoteKind: AiraSyncProviderKind): Promise<void> {
    await this.bookmarkDomain.refreshRemoteStatus(remoteKind).catch((_error: Error): void => {
    });
  }

  private buildFirstActivationSuccessMessage(
    selection: SyncExperiencePersistedState,
    remoteKind: AiraSyncProviderKind
  ): ResourceStr {
    if (selection.historySelected && remoteKind !== 'webdav') {
      return $r('app.string.settings_sync_opened_history');
    }
    if (selection.bookmarkSelected && selection.personalizationSelected) {
      return $r('app.string.settings_sync_opened_both');
    }
    return selection.bookmarkSelected
      ? $r('app.string.settings_sync_opened_bookmarks')
      : $r('app.string.settings_sync_opened_personalization');
  }

  private firstActivationFailure(
    title: ResourceStr,
    message: string,
    remoteKind: AiraSyncProviderKind
  ): SyncExperienceActionOutcome {
    return {
      type: 'failed',
      title: title,
      message: message,
      remoteKind: remoteKind
    };
  }

  private async loadContext(): Promise<SyncExperienceContext> {
    const settings = await this.syncService.initializeAiraSyncSettings();
    const activeProvider = settings.remoteKind;
    const experienceState = await this.reconcileHistoryAccountBinding(settings);
    return {
      settings: settings,
      activeProvider: activeProvider,
      experienceState: experienceState
    };
  }

  private async clearHistorySelectionForWebdav(
    activeProvider: AiraSyncRemoteKind,
    state: SyncExperiencePersistedState
  ): Promise<SyncExperiencePersistedState> {
    if (activeProvider !== 'webdav' || !state.historySelected) {
      return state;
    }
    await this.automaticRuntime.clearHistorySelectionForWebdav();
    return this.experienceStateStore.getState();
  }

  private resolveHistoryAccountUid(settings: AiraSyncSettings): string {
    if (settings.remoteKind === 'self_hosted') {
      return resolveAiraPersonalServerConfig(settings).instanceId.trim();
    }
    return resolveAiraHuaweiAccountIdentity(settings.huaweiCloud, settings.huaweiSpace).uid.trim();
  }

  private async enablePersonalizationDomain(): Promise<PersonalizationSyncRunResult> {
    return this.automaticRuntime.runProviderTransition(async (): Promise<PersonalizationSyncRunResult> => {
      const result = await this.personalizationDomain.enableDomain();
      if (result.ok) {
        this.automaticRuntime.notifyPersonalizationLocalSettingsChanged();
        void this.automaticRuntime.notifyAccountChanged();
      }
      return result;
    });
  }

  private async disablePersonalizationDomain(): Promise<void> {
    await this.automaticRuntime.runProviderTransition(async (): Promise<void> => {
      await this.personalizationDomain.disableDomain();
      this.automaticRuntime.cancelPersonalizationAutomaticSync();
    });
  }

  private async suspendExperience(
    settings: AiraSyncSettings,
    previousState: SyncExperiencePersistedState
  ): Promise<SyncExperienceActionOutcome> {
    const bookmarkSelected = settings.bookmarkSyncEnabled === true ? true : previousState.bookmarkSelected;
    const personalizationSelected = settings.personalizationSyncEnabled === true
      ? true
      : previousState.personalizationSelected;
    const historySelected = previousState.historySelected;
    await this.experienceStateStore.setSelections(
      bookmarkSelected,
      personalizationSelected,
      previousState.suspended,
      historySelected
    );
    const failures: ResourceStr[] = [];
    if (settings.personalizationSyncEnabled === true) {
      try {
        await this.disablePersonalizationDomain();
      } catch (error) {
        const message = this.normalizeError(error as Error).message;
        failures.push(this.localizeLabeledFailure(
          message,
          $r('app.string.settings_sync_pause_personalization_raw', message)
        ));
      }
    }
    if (settings.bookmarkSyncEnabled === true) {
      try {
        const outcome = await this.providerOperations.setBookmarkDomainEnabled(false);
        if (outcome.type !== 'bookmark-domain-disabled') {
          failures.push(outcome.bookmarkFailure === undefined
            ? this.localizeLabeledFailure(
              outcome.message,
              $r('app.string.settings_sync_pause_bookmarks_raw', outcome.message)
            )
            : this.syncFailurePresentationService.buildBookmarkFailureResource({
              remoteKind: outcome.remoteKind,
              operationName: '暂停书签同步',
              failure: outcome.bookmarkFailure
            }));
        }
      } catch (error) {
        const message = this.normalizeError(error as Error).message;
        failures.push(this.localizeLabeledFailure(
          message,
          $r('app.string.settings_sync_pause_bookmarks_raw', message)
        ));
      }
    }
    this.automaticRuntime.cancelHistoryAutomaticSync();
    if (failures.length > 0) {
      await this.experienceStateStore.setSelections(
        bookmarkSelected,
        personalizationSelected,
        false,
        historySelected
      );
      const failureLines = failures.slice(0);
      failureLines.push($r('app.string.settings_sync_pause_partial_note'));
      return this.withMessageLines({
        type: 'failed',
        title: $r('app.string.settings_sync_pause_incomplete'),
        message: failureLines[0]
      }, failureLines);
    }
    await this.experienceStateStore.suspend(bookmarkSelected, personalizationSelected, historySelected);
    return {
      type: 'completed',
      title: $r('app.string.settings_sync_paused_title'),
      message: $r('app.string.settings_sync_pause_kept')
    };
  }

  private async resumeExperience(
    experienceState: SyncExperiencePersistedState
  ): Promise<SyncExperienceActionOutcome> {
    let current = this.syncService.getAiraSyncSettings();
    const historySelected = experienceState.historySelected &&
      (current.remoteKind === 'aira_cloud' || current.remoteKind === 'huawei_space' ||
        current.remoteKind === 'self_hosted');
    if (!experienceState.bookmarkSelected && !experienceState.personalizationSelected &&
      !historySelected) {
      return {
        type: 'blocked',
        title: $r('app.string.settings_sync_choose_content'),
        message: $r('app.string.settings_sync_resume_choose_message')
      };
    }
    const failures: ResourceStr[] = [];
    let resumedDomainCount: number = 0;
    if (experienceState.bookmarkSelected && current.remoteKind !== 'none') {
      if (current.bookmarkSyncEnabled === true) {
        resumedDomainCount += 1;
      } else {
        try {
          const outcome = await this.providerOperations.setBookmarkDomainEnabled(true);
          if (outcome.type !== 'bookmark-domain-enabled') {
            failures.push(outcome.bookmarkFailure === undefined
              ? this.syncFailurePresentationService.localizeProviderLine(outcome.message)
              : this.syncFailurePresentationService.buildBookmarkFailureResource({
                remoteKind: outcome.remoteKind,
                operationName: '恢复书签同步',
                failure: outcome.bookmarkFailure
              }));
          } else {
            resumedDomainCount += 1;
          }
        } catch (error) {
          failures.push(this.syncFailurePresentationService.buildBookmarkFailureResource({
            remoteKind: current.remoteKind,
            operationName: '恢复书签同步',
            failure: this.syncService.resolveBookmarkSyncFailure(error as Error)
          }));
        }
      }
    }
    current = this.syncService.getAiraSyncSettings();
    if (experienceState.personalizationSelected && current.remoteKind !== 'none') {
      if (current.personalizationSyncEnabled === true) {
        resumedDomainCount += 1;
      } else {
        try {
          const result = await this.enablePersonalizationDomain();
          if (!result.ok) {
            failures.push(this.localizeLabeledFailure(
              result.message,
              $r('app.string.settings_sync_resume_personalization_raw', result.message)
            ));
          } else {
            resumedDomainCount += 1;
          }
        } catch (error) {
          const message = this.normalizeError(error as Error).message;
          failures.push(this.localizeLabeledFailure(
            message,
            $r('app.string.settings_sync_resume_personalization_raw', message)
          ));
        }
      }
    }
    if (historySelected) {
      try {
        const historyOutcome = await this.setHistorySelected(true);
        if (historyOutcome.type === 'completed') {
          resumedDomainCount += 1;
        } else {
          failures.push(typeof historyOutcome.message === 'string'
            ? this.localizeLabeledFailure(
              historyOutcome.message,
              $r('app.string.settings_sync_resume_history_raw', historyOutcome.message)
            )
            : historyOutcome.message);
        }
      } catch (error) {
        const message = this.normalizeError(error as Error).message;
        failures.push(this.localizeLabeledFailure(
          message,
          $r('app.string.settings_sync_resume_history_raw', message)
        ));
      }
    }
    if (resumedDomainCount > 0) {
      await this.experienceStateStore.resume();
      await this.automaticRuntime.notifyAccountChanged();
    }
    if (failures.length > 0) {
      const failureLines = failures.slice(0);
      failureLines.push(resumedDomainCount > 0
        ? $r('app.string.settings_sync_resume_partial_note')
        : $r('app.string.settings_sync_resume_still_paused_note'));
      return this.withMessageLines({
        type: 'failed',
        title: $r('app.string.settings_sync_resume_incomplete'),
        message: failureLines[0]
      }, failureLines);
    }
    return {
      type: 'completed',
      title: $r('app.string.settings_sync_resumed'),
      message: $r('app.string.settings_sync_resumed_message')
    };
  }

  private mapProviderSelectionRequestOutcome(outcome: SyncExperienceProviderOutcome): SyncExperienceActionOutcome | undefined {
    if (outcome.type === 'configuration-required') {
      return {
        type: 'configuration-required',
        title: outcome.title,
        message: this.syncFailurePresentationService.localizeKnownProviderMessage(outcome.message),
        remoteKind: outcome.remoteKind
      };
    }
    if (outcome.type === 'membership-required') {
      return {
        type: 'membership-required',
        title: outcome.title,
        message: outcome.message,
        remoteKind: outcome.remoteKind,
        membershipDecision: outcome.membershipDecision
      };
    }
    if (outcome.type === 'provider-selection-blocked') {
      return {
        type: 'blocked',
        title: outcome.title,
        message: this.syncFailurePresentationService.localizeKnownProviderMessage(outcome.message),
        remoteKind: outcome.remoteKind,
        requiresBookmarkResolution: this.requiresBookmarkResolution(outcome)
      };
    }
    if (outcome.type === 'failed') {
      if (outcome.bookmarkFailure !== undefined) {
        return {
          type: 'failed',
          title: outcome.title,
          message: this.buildProviderBookmarkFailureMessage(outcome, '书签同步'),
          remoteKind: outcome.remoteKind
        };
      }
      return {
        type: 'failed',
        title: outcome.title,
        message: this.syncFailurePresentationService.localizeKnownProviderMessage(outcome.message),
        remoteKind: outcome.remoteKind
      };
    }
    return undefined;
  }

  private mapProviderSelectionCompletionOutcome(outcome: SyncExperienceProviderOutcome): SyncExperienceActionOutcome | undefined {
    if (outcome.type === 'provider-selected') {
      return undefined;
    }
    return this.mapProviderSelectionRequestOutcome(outcome) ?? this.mapProviderSelectionFailure(outcome);
  }

  private mapProviderSelectionFailure(outcome: SyncExperienceProviderOutcome): SyncExperienceActionOutcome {
    if (outcome.type === 'membership-required') {
      return {
        type: 'membership-required',
        title: outcome.title,
        message: outcome.message,
        remoteKind: outcome.remoteKind,
        membershipDecision: outcome.membershipDecision
      };
    }
    if (outcome.type === 'bookmark-domain-blocked' || outcome.type === 'provider-selection-blocked') {
      return {
        type: 'blocked',
        title: outcome.title,
        message: this.syncFailurePresentationService.localizeKnownProviderMessage(outcome.message),
        remoteKind: outcome.remoteKind,
        requiresBookmarkResolution: this.requiresBookmarkResolution(outcome)
      };
    }
    if (outcome.bookmarkFailure !== undefined) {
      return {
        type: 'failed',
        title: outcome.title,
        message: this.buildProviderBookmarkFailureMessage(outcome, '书签同步'),
        remoteKind: outcome.remoteKind
      };
    }
    return {
      type: 'failed',
      title: outcome.title,
      message: this.syncFailurePresentationService.localizeKnownProviderMessage(outcome.message),
      remoteKind: outcome.remoteKind
    };
  }

  private buildProviderBookmarkFailureMessage(
    outcome: SyncExperienceProviderOutcome,
    operationName: string
  ): ResourceStr {
    if (outcome.bookmarkFailure === undefined) {
      return this.syncFailurePresentationService.localizeKnownProviderMessage(outcome.message);
    }
    return this.syncFailurePresentationService.buildBookmarkFailureResource({
      remoteKind: outcome.remoteKind,
      operationName: operationName,
      failure: outcome.bookmarkFailure
    });
  }

  private hasEnabledPersonalizationContent(
    config: PersonalizationSyncConfig,
    novelBookshelfEnabled: boolean
  ): boolean {
    return novelBookshelfEnabled || config.items.some((item): boolean => item.enabled);
  }

  private async clearRetainedPersonalizationSelections(
    config: PersonalizationSyncConfig,
    novelBookshelfEnabled: boolean,
    selectedId: PersonalizationSyncContentId
  ): Promise<void> {
    for (let index = 0; index < config.items.length; index += 1) {
      const item = config.items[index];
      if (item.id === selectedId || !item.enabled) {
        continue;
      }
      const outcome = await this.personalizationDomain.updateItemEnabled(item.id, false);
      if (!outcome.ok) {
        throw new Error(outcome.message);
      }
    }
    if (selectedId !== 'novel_bookshelf' && novelBookshelfEnabled) {
      const outcome = await this.personalizationDomain.updateItemEnabled('novel_bookshelf', false);
      if (!outcome.ok) {
        throw new Error(outcome.message);
      }
    }
  }

  private personalizationContentFailure(
    title: ResourceStr,
    config: PersonalizationSyncConfig
  ): SyncExperienceActionOutcome {
    return {
      type: 'failed',
      title: title,
      message: $r('app.string.settings_sync_content_unchanged'),
      personalizationConfig: config
    };
  }

  private buildAdvancedState(
    settings: AiraSyncSettings,
    overview: SyncAdvancedStatusOverview | undefined,
    isPrivateSession: boolean
  ): SyncExperienceAdvancedState {
    const enabledKinds = this.advancedViewModel.resolveEnabledRemoteKinds(settings);
    const activeRemoteKind = settings.remoteKind;
    const status = isPrivateSession
      ? this.advancedViewModel.buildPrivateStatus()
      : this.advancedViewModel.buildStatus(
        settings,
        overview?.baselines ?? [],
        (remoteKind: AiraSyncRemoteKind): string => this.syncService.resolveAiraProviderIdForKind(remoteKind),
        overview?.localCounts
      );
    return {
      status: status,
      providerActions: this.advancedViewModel.buildProviderActions(settings),
      mergeActionLabel: this.advancedViewModel.resolveMergeActionLabel(),
      activeRemoteKind: activeRemoteKind,
      activeSyncServiceKey: this.advancedViewModel.resolveActiveSyncServiceKey(settings, activeRemoteKind),
      activeSyncServiceName: this.advancedViewModel.resolveActiveSyncServiceName(settings, activeRemoteKind),
      activeSyncReady: enabledKinds.length > 0,
      activeSyncMissingConfigurationMessage: this.resolveAdvancedMissingConfigurationMessage(
        settings,
        activeRemoteKind
      ),
      providerReadiness: [
        this.buildAdvancedProviderReadiness(settings, 'aira_cloud'),
        this.buildAdvancedProviderReadiness(settings, 'huawei_space'),
        this.buildAdvancedProviderReadiness(settings, 'webdav')
      ]
    };
  }

  private buildAdvancedProviderReadiness(
    settings: AiraSyncSettings,
    remoteKind: AiraSyncProviderKind
  ): SyncExperienceAdvancedProviderReadiness {
    return {
      remoteKind: remoteKind,
      ready: this.advancedViewModel.isProviderSyncReady(settings, remoteKind),
      missingConfigurationMessage: this.resolveAdvancedMissingConfigurationMessage(settings, remoteKind)
    };
  }

  private resolveAdvancedMissingConfigurationMessage(
    settings: AiraSyncSettings,
    remoteKind: AiraSyncRemoteKind
  ): ResourceStr {
    return this.advancedViewModel.resolveMissingConfigurationMessage(settings, remoteKind);
  }

  private buildWebdavConfigurationState(
    settings: AiraSyncSettings
  ): SyncExperienceWebdavConfigurationState {
    let providerRole: SyncWebdavProviderRole = 'inactive';
    if (settings.remoteKind === 'webdav') {
      providerRole = 'active';
    } else if ((settings.additionalBackupRemoteKinds ?? []).indexOf('webdav') >= 0) {
      providerRole = 'additional_backup';
    }
    return {
      endpoint: settings.webdav.endpoint,
      username: settings.webdav.username,
      password: settings.webdav.password,
      providerRole: providerRole,
      bookmarkDomainEnabled: providerRole === 'active' && settings.bookmarkSyncEnabled === true
    };
  }

  private validateAdditionalBackupNow(
    settings: AiraSyncSettings
  ): SyncAdditionalBackupActionOutcome | undefined {
    if (settings.additionalBackupEnabled !== true) {
      return {
        type: 'blocked',
        title: $r('app.string.settings_sync_backup_not_on'),
        message: $r('app.string.settings_sync_backup_turn_on')
      };
    }
    if ((settings.additionalBackupRemoteKinds ?? []).length <= 0) {
      return {
        type: 'blocked',
        title: $r('app.string.settings_sync_backup_setup_title'),
        message: $r('app.string.settings_sync_backup_setup_message'),
        requiresOptions: true
      };
    }
    if (settings.bookmarkSyncEnabled !== true && settings.personalizationSyncEnabled !== true) {
      return {
        type: 'blocked',
        title: $r('app.string.settings_sync_backup_nothing_title'),
        message: $r('app.string.settings_sync_backup_nothing_message')
      };
    }
    return undefined;
  }

  private resolveAdditionalBackupFailureLines(settings: AiraSyncSettings): ResourceStr[] {
    if (settings.additionalBackupEnabled !== true) {
      return [];
    }
    const lines: ResourceStr[] = [];
    const backupKinds = settings.additionalBackupRemoteKinds ?? [];
    for (let index = 0; index < backupKinds.length; index += 1) {
      const remoteKind = backupKinds[index];
      if (settings.bookmarkSyncEnabled === true && this.isAdditionalBackupDomainUnhealthy(
        resolveAiraSyncDomainRuntimeState(settings, remoteKind, 'bookmark_backup')
      )) {
        const runtime = resolveAiraSyncDomainRuntimeState(settings, remoteKind, 'bookmark_backup');
        lines.push(this.syncFailurePresentationService.buildBookmarkFailureResource({
          remoteKind: remoteKind,
          operationName: '额外书签副本',
          failure: this.resolveRuntimeBookmarkFailure(runtime)
        }));
      }
      if (settings.personalizationSyncEnabled === true && this.isAdditionalBackupDomainUnhealthy(
        resolveAiraSyncDomainRuntimeState(settings, remoteKind, 'personalization_backup')
      )) {
        lines.push(remoteKind === 'webdav'
          ? $r('app.string.settings_sync_backup_extra_personalization_webdav')
          : $r('app.string.settings_sync_backup_extra_personalization_named',
            this.providerOperations.resolveProviderLabel(remoteKind)));
      }
    }
    return lines;
  }

  private isAdditionalBackupDomainUnhealthy(state: AiraSyncDomainRuntimeState): boolean {
    return state.health === 'degraded' || state.health === 'unavailable';
  }

  private resolveRuntimeBookmarkFailure(state: AiraSyncDomainRuntimeState): AiraBookmarkSyncFailure | undefined {
    if (state.failureCode.length <= 0 || state.failureStage === '' || state.failureDetail.length <= 0) {
      return undefined;
    }
    return {
      code: state.failureCode,
      stage: state.failureStage,
      safeDetail: state.failureDetail
    };
  }

  private additionalBackupFailure(title: ResourceStr, error: Error): SyncAdditionalBackupActionOutcome {
    return {
      type: 'failed',
      title: title,
      message: error.message.length > 0
        ? $r('app.string.settings_sync_backup_retry')
        : $r('app.string.settings_sync_backup_action_incomplete')
    };
  }

  private failure(
    title: ResourceStr,
    error: Error,
    remoteKind?: AiraSyncProviderKind,
    bookmarkFailure?: AiraBookmarkSyncFailure,
    retryAction?: SyncExperienceRetryAction
  ): SyncExperienceActionOutcome {
    return {
      type: 'failed',
      title: title,
      message: error.message.length > 0 ? error.message : JSON.stringify(error),
      remoteKind: remoteKind,
      bookmarkFailure: bookmarkFailure,
      retryAction: retryAction
    };
  }

  private normalizeError(error: Object): Error {
    if (error instanceof Error) {
      return error;
    }
    return new Error(JSON.stringify(error));
  }

  private requiresBookmarkResolution(outcome: SyncExperienceProviderOutcome): boolean {
    return outcome.bookmarkResult !== undefined &&
      (outcome.bookmarkResult.blocked || outcome.bookmarkResult.conflictCount > 0);
  }
}
