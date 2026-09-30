import {
  AiraSyncProviderKind,
  AiraBookmarkSyncFailure,
  AiraSyncDomainRuntimeState,
  AiraSyncProviderRuntimeState,
  AiraSyncRemoteKind,
  AiraSyncSettings,
  resolveAiraSyncActiveProviderLastSuccessAt
} from '../../common/models/AiraSyncModels';
import { PersonalizationSyncConfig } from '../../common/models/PersonalizationSyncModels';
import { SyncExperiencePersistedState } from '../../data/sync/SyncExperienceStateStore';
import {
  PersonalizationSyncItemState,
  PersonalizationSyncSettingsViewModel
} from './PersonalizationSyncSettingsViewModel';
import { WebdavProviderCatalog } from './WebdavProviderCatalog';
import { SyncFailurePresentationService } from './SyncFailurePresentationService';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';

export type SyncExperienceStatusKind = 'setup' | 'normal' | 'initializing' | 'syncing' | 'attention' | 'paused';
export type SyncExperiencePreActiveStatusKind =
  'initial-loading' | 'huawei-activating' | 'load-failed' | 'huawei-load-failed' | 'inactive';

interface SyncExperienceGoalDescriptor {
  id: AiraSyncProviderKind;
  title: ResourceStr;
  description: ResourceStr;
  requiresPro: boolean;
}

const SYNC_EXPERIENCE_GOALS: SyncExperienceGoalDescriptor[] = [
  {
    id: 'aira_cloud',
    title: $r('app.string.settings_sync_goal_cloud'),
    description: $r('app.string.settings_sync_goal_cloud_desc'),
    requiresPro: true
  },
  {
    id: 'huawei_space',
    title: $r('app.string.settings_sync_goal_huawei'),
    description: $r('app.string.settings_sync_goal_huawei_desc'),
    requiresPro: false
  },
  {
    id: 'webdav',
    title: $r('app.string.settings_sync_goal_webdav'),
    description: $r('app.string.settings_sync_goal_webdav_desc'),
    requiresPro: false
  },
  {
    id: 'self_hosted',
    title: $r('app.string.settings_pro_self_hosting'),
    description: $r('app.string.settings_sync_goal_self_host_desc'),
    requiresPro: false
  }
];

function resolveDistributionSyncExperienceGoals(): SyncExperienceGoalDescriptor[] {
  if (AIRA_DISTRIBUTION_CAPABILITY_OWNER.isOfficial()) {
    return SYNC_EXPERIENCE_GOALS;
  }
  const goals: SyncExperienceGoalDescriptor[] = [];
  SYNC_EXPERIENCE_GOALS.forEach((goal: SyncExperienceGoalDescriptor): void => {
    if (goal.id === 'self_hosted') {
      goals.push(goal);
    }
  });
  SYNC_EXPERIENCE_GOALS.forEach((goal: SyncExperienceGoalDescriptor): void => {
    if (goal.id === 'webdav') {
      goals.push(goal);
    }
  });
  return goals;
}

function resolveDistributionGoalTitle(goal: SyncExperienceGoalDescriptor): ResourceStr {
  if (AIRA_DISTRIBUTION_CAPABILITY_OWNER.isCommunity()) {
    if (goal.id === 'self_hosted') {
      return $r('app.string.settings_pro_self_hosting');
    }
    if (goal.id === 'webdav') {
      return $r('app.string.settings_sync_goal_webdav');
    }
  }
  return goal.title;
}

export interface SyncExperienceGoalOption {
  id: AiraSyncProviderKind;
  title: ResourceStr;
  description: ResourceStr;
  isSelected: boolean;
  requiresPro: boolean;
}

export interface SyncExperienceViewState {
  hasActiveProvider: boolean;
  hasConfiguredSync: boolean;
  masterEnabled: boolean;
  suspended: boolean;
  bookmarkSelected: boolean;
  personalizationSelected: boolean;
  historySelected: boolean;
  historySupported: boolean;
  historyProviderLabel: string;
  statusKind: SyncExperienceStatusKind;
  statusTitle: ResourceStr;
  statusMessage: ResourceStr;
  statusDetail: ResourceStr;
  goalLabel: ResourceStr;
  lastSyncLabel: ResourceStr;
  enabledPersonalizationItemCount: number;
  canSyncNow: boolean;
  requiresAiraProAction: boolean;
  additionalBackupSummary: ResourceStr;
  huaweiSpaceBookmarkUpgradeRequired: boolean;
  airaCloudActive: boolean;
  huaweiSpaceActive: boolean;
  huaweiBookmarkInitializing: boolean;
  goalOptions: SyncExperienceGoalOption[];
  personalizationItems: PersonalizationSyncItemState[];
}

export interface SyncExperienceViewModelInput {
  settings: AiraSyncSettings;
  experienceState: SyncExperiencePersistedState;
  personalizationConfig: PersonalizationSyncConfig;
  novelBookshelfSyncEnabled: boolean;
  airaCloudEligible: boolean;
  isSyncing: boolean;
  huaweiSpaceBookmarkUpgradeRequired: boolean;
}

interface SyncExperienceContentSelection {
  bookmarkSelected: boolean;
  personalizationSelected: boolean;
  historySelected: boolean;
}

export function createDefaultSyncExperienceViewState(): SyncExperienceViewState {
  const personalizationItems = new PersonalizationSyncSettingsViewModel().buildDefaultState().items;
  return {
    hasActiveProvider: false,
    hasConfiguredSync: false,
    masterEnabled: false,
    suspended: false,
    bookmarkSelected: true,
    personalizationSelected: true,
    historySelected: true,
    historySupported: true,
    historyProviderLabel: AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud') ? 'Aira 云' : '尚未选择',
    statusKind: 'setup',
    statusTitle: $r('app.string.settings_sync_not_started'),
    statusMessage: $r('app.string.settings_sync_setup_message'),
    statusDetail: '',
    goalLabel: $r('app.string.settings_sync_unset'),
    lastSyncLabel: $r('app.string.settings_sync_last_never'),
    enabledPersonalizationItemCount: personalizationItems.filter(
      (item: PersonalizationSyncItemState): boolean => item.enabled
    ).length,
    canSyncNow: false,
    requiresAiraProAction: false,
    additionalBackupSummary: $r('app.string.settings_sync_backup_unset'),
    huaweiSpaceBookmarkUpgradeRequired: false,
    airaCloudActive: false,
    huaweiSpaceActive: false,
    huaweiBookmarkInitializing: false,
    goalOptions: resolveDistributionSyncExperienceGoals().filter((goal: SyncExperienceGoalDescriptor): boolean => {
      return goal.id !== 'aira_cloud' || AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud');
    }).map((goal: SyncExperienceGoalDescriptor): SyncExperienceGoalOption => {
      return {
        id: goal.id,
        title: resolveDistributionGoalTitle(goal),
        description: goal.description,
        isSelected: false,
        requiresPro: goal.requiresPro
      };
    }),
    personalizationItems: personalizationItems
  };
}

export class SyncExperienceViewModel {
  private syncFailurePresentationService: SyncFailurePresentationService = new SyncFailurePresentationService();
  private personalizationViewModel: PersonalizationSyncSettingsViewModel = new PersonalizationSyncSettingsViewModel();
  private webdavProviderCatalog: WebdavProviderCatalog = new WebdavProviderCatalog();

  buildState(input: SyncExperienceViewModelInput): SyncExperienceViewState {
    const activeProvider = this.resolveAvailableProvider(input.settings.remoteKind);
    const hasActiveProvider = this.isProviderKind(activeProvider);
    const personalizationItems = this.buildPersonalizationItems(input, hasActiveProvider);
    const enabledPersonalizationItemCount = personalizationItems.filter(
      (item: PersonalizationSyncItemState): boolean => item.enabled
    ).length;
    const contentSelection = this.resolveContentSelection(input, hasActiveProvider);
    const hasEnabledContent = contentSelection.bookmarkSelected || contentSelection.personalizationSelected ||
      contentSelection.historySelected;
    const hasConfiguredSync = hasActiveProvider;
    const masterEnabled = hasConfiguredSync && !input.experienceState.suspended;
    const huaweiBookmarkInitializing = this.isHuaweiBookmarkInitializing(input.settings);
    const statusKind = this.resolveStatusKind(input, activeProvider, hasConfiguredSync, hasEnabledContent);
    return {
      hasActiveProvider: hasActiveProvider,
      hasConfiguredSync: hasConfiguredSync,
      masterEnabled: masterEnabled,
      suspended: input.experienceState.suspended,
      bookmarkSelected: contentSelection.bookmarkSelected,
      personalizationSelected: contentSelection.personalizationSelected,
      historySelected: input.experienceState.historySelected,
      historySupported: activeProvider !== 'webdav',
      historyProviderLabel: this.resolveHistoryProviderLabel(activeProvider),
      statusKind: statusKind,
      statusTitle: this.resolveStatusTitle(statusKind, hasConfiguredSync),
      statusMessage: this.resolveStatusMessage(
        statusKind,
        input,
        activeProvider,
        contentSelection
      ),
      statusDetail: this.resolveStatusDetail(statusKind, input, activeProvider),
      goalLabel: this.resolveGoalLabelResource(activeProvider, input.settings),
      lastSyncLabel: this.formatLastSyncLabel(Math.max(
        resolveAiraSyncActiveProviderLastSuccessAt(input.settings),
        input.personalizationConfig.lastSyncAt
      )),
      enabledPersonalizationItemCount: enabledPersonalizationItemCount,
      canSyncNow: masterEnabled && hasEnabledContent && statusKind !== 'paused' && statusKind !== 'syncing',
      requiresAiraProAction: activeProvider === 'aira_cloud' && !input.airaCloudEligible,
      additionalBackupSummary: this.resolveAdditionalBackupSummary(input.settings),
      huaweiSpaceBookmarkUpgradeRequired: input.huaweiSpaceBookmarkUpgradeRequired,
      airaCloudActive: activeProvider === 'aira_cloud',
      huaweiSpaceActive: activeProvider === 'huawei_space',
      huaweiBookmarkInitializing: huaweiBookmarkInitializing,
      goalOptions: this.buildGoalOptions(activeProvider, input.settings),
      personalizationItems: personalizationItems
    };
  }

  resolveGoalLabelResource(remoteKind: AiraSyncRemoteKind, settings?: AiraSyncSettings): ResourceStr {
    if (remoteKind === 'none') {
      return $r('app.string.settings_sync_unset');
    }
    if (remoteKind === 'webdav') {
      const endpoint = settings?.webdav.endpoint.trim() ?? '';
      if (endpoint.length <= 0) {
        return $r('app.string.settings_sync_goal_webdav');
      }
      return this.webdavProviderCatalog.resolveProviderForEndpoint(endpoint).name;
    }
    const goal = SYNC_EXPERIENCE_GOALS.find((item: SyncExperienceGoalDescriptor) => item.id === remoteKind);
    return goal !== undefined ? resolveDistributionGoalTitle(goal) : $r('app.string.settings_sync_unset');
  }

  resolveGoalLabel(remoteKind: AiraSyncRemoteKind, settings?: AiraSyncSettings): string {
    if (remoteKind === 'huawei_space') {
      if (!AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_space')) {
        return '尚未选择';
      }
      return '华为云空间';
    }
    if (remoteKind === 'aira_cloud') {
      if (!AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud')) {
        return '尚未选择';
      }
      return 'Aira 云同步';
    }
    if (remoteKind === 'webdav') {
      return this.resolveWebdavProviderLabel(settings);
    }
    if (remoteKind === 'self_hosted') {
      return '私有化部署';
    }
    return '尚未选择';
  }

  private resolveHistoryProviderLabel(provider: AiraSyncRemoteKind): string {
    if (provider === 'huawei_space') {
      if (!AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_space')) {
        return '尚未选择';
      }
      return '华为云空间';
    }
    if (provider === 'aira_cloud' && !AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud')) {
      return '尚未选择';
    }
    if (provider === 'self_hosted') {
      return '私有化部署';
    }
    return 'Aira 云';
  }

  private resolveStatusKind(
    input: SyncExperienceViewModelInput,
    activeProvider: AiraSyncRemoteKind,
    hasConfiguredSync: boolean,
    hasEnabledContent: boolean
  ): SyncExperienceStatusKind {
    if (!hasConfiguredSync) {
      return 'setup';
    }
    if (input.experienceState.suspended) {
      return 'paused';
    }
    if (activeProvider === 'huawei_space' && input.huaweiSpaceBookmarkUpgradeRequired) {
      return 'attention';
    }
    if (!hasEnabledContent) {
      return 'setup';
    }
    if (activeProvider === 'aira_cloud' && !input.airaCloudEligible) {
      return 'attention';
    }
    if (this.isHuaweiBookmarkInitializing(input.settings)) {
      return 'initializing';
    }
    if (input.isSyncing) {
      return 'syncing';
    }
    if (this.bookmarkNeedsAttention(input, activeProvider) ||
      this.personalizationNeedsAttention(input, activeProvider)) {
      return 'attention';
    }
    if (this.hasAdditionalBackupAttention(input.settings)) {
      return 'attention';
    }
    return 'normal';
  }

  private resolveStatusTitle(kind: SyncExperienceStatusKind, hasConfiguredSync: boolean): ResourceStr {
    if (kind === 'setup') {
      return hasConfiguredSync
        ? $r('app.string.settings_sync_choose_content')
        : $r('app.string.settings_sync_not_started');
    }
    if (kind === 'attention') {
      return $r('app.string.settings_sync_attention');
    }
    if (kind === 'paused') {
      return $r('app.string.settings_sync_paused');
    }
    if (kind === 'syncing') {
      return $r('app.string.settings_sync_syncing');
    }
    if (kind === 'initializing') {
      return $r('app.string.settings_sync_initializing_bookmarks');
    }
    return $r('app.string.settings_sync_normal');
  }

  private resolveStatusMessage(
    kind: SyncExperienceStatusKind,
    input: SyncExperienceViewModelInput,
    activeProvider: AiraSyncRemoteKind,
    contentSelection: SyncExperienceContentSelection
  ): ResourceStr {
    if (kind === 'setup') {
      if (activeProvider === 'none') {
        return $r('app.string.settings_sync_setup_message');
      }
      if (!contentSelection.bookmarkSelected && !contentSelection.personalizationSelected &&
        !contentSelection.historySelected) {
        if (activeProvider === 'webdav') {
          return $r('app.string.settings_sync_choose_webdav_content');
        }
        return $r('app.string.settings_sync_choose_content_active');
      }
      return $r('app.string.settings_sync_saved_resume');
    }
    if (kind === 'paused') {
      return $r('app.string.settings_sync_paused_message');
    }
    if (kind === 'attention') {
      if (activeProvider === 'huawei_space' && input.huaweiSpaceBookmarkUpgradeRequired) {
        return $r('app.string.settings_sync_huawei_upgrade_status');
      }
      if (activeProvider === 'aira_cloud' && !input.airaCloudEligible) {
        return $r('app.string.settings_sync_pro_restore_status');
      }
      const bookmarkNeedsAttention = this.bookmarkNeedsAttention(input, activeProvider);
      const personalizationNeedsAttention = this.personalizationNeedsAttention(input, activeProvider);
      const systemUpdateGuidance = this.resolveHuaweiSpacePersonalizationSystemUpdateGuidance(
        input,
        activeProvider
      );
      if (bookmarkNeedsAttention && personalizationNeedsAttention) {
        return systemUpdateGuidance.length > 0
          ? $r('app.string.settings_sync_attention_both_update')
          : $r('app.string.settings_sync_attention_both');
      }
      if (bookmarkNeedsAttention) {
        return systemUpdateGuidance.length > 0
          ? $r('app.string.settings_sync_attention_bookmarks_update')
          : $r('app.string.settings_sync_attention_bookmarks');
      }
      if (personalizationNeedsAttention) {
        return systemUpdateGuidance.length > 0
          ? $r('app.string.settings_sync_attention_personalization_update')
          : $r('app.string.settings_sync_attention_personalization');
      }
      if (this.hasAdditionalBackupAttention(input.settings)) {
        return $r('app.string.settings_sync_attention_backup');
      }
      return $r('app.string.settings_sync_attention_generic');
    }
    if (kind === 'syncing') {
      return contentSelection.historySelected
        ? $r('app.string.settings_sync_syncing_history')
        : $r('app.string.settings_sync_syncing_safe');
    }
    if (kind === 'initializing') {
      return $r('app.string.settings_sync_initializing_message');
    }
    return contentSelection.historySelected
      ? $r('app.string.settings_sync_normal_history')
      : $r('app.string.settings_sync_normal_bookmarks');
  }

  private resolveContentSelection(
    input: SyncExperienceViewModelInput,
    hasActiveProvider: boolean
  ): SyncExperienceContentSelection {
    const historySelected = input.experienceState.historySelected && input.settings.remoteKind !== 'webdav';
    if (!hasActiveProvider || input.experienceState.suspended) {
      return {
        bookmarkSelected: input.experienceState.bookmarkSelected,
        personalizationSelected: input.experienceState.personalizationSelected,
        historySelected: historySelected
      };
    }
    return {
      bookmarkSelected: input.settings.bookmarkSyncEnabled === true,
      personalizationSelected: input.settings.personalizationSyncEnabled === true &&
        (input.personalizationConfig.items.some((item): boolean => item.enabled) || input.novelBookshelfSyncEnabled),
      historySelected: historySelected
    };
  }

  private buildPersonalizationItems(
    input: SyncExperienceViewModelInput,
    hasActiveProvider: boolean
  ): PersonalizationSyncItemState[] {
    const items = this.personalizationViewModel.buildDefaultState(
      input.personalizationConfig,
      input.novelBookshelfSyncEnabled
    ).items;
    const hiddenDomainPaused = hasActiveProvider && !input.experienceState.suspended &&
      input.settings.personalizationSyncEnabled !== true;
    if (!hiddenDomainPaused) {
      return items;
    }
    return items.map((item: PersonalizationSyncItemState): PersonalizationSyncItemState => {
      return {
        id: item.id,
        title: item.title,
        summary: item.summary,
        enabled: false
      };
    });
  }

  private buildGoalOptions(
    activeProvider: AiraSyncRemoteKind,
    settings: AiraSyncSettings
  ): SyncExperienceGoalOption[] {
    return resolveDistributionSyncExperienceGoals().filter((goal: SyncExperienceGoalDescriptor): boolean => {
      return this.isProviderAvailable(goal.id);
    }).map((goal: SyncExperienceGoalDescriptor): SyncExperienceGoalOption => {
      return {
        id: goal.id,
        title: this.resolveGoalOptionTitle(goal, settings),
        description: goal.description,
        isSelected: activeProvider === goal.id,
        requiresPro: goal.requiresPro
      };
    });
  }

  private resolveWebdavProviderLabel(settings?: AiraSyncSettings): string {
    const endpoint = settings?.webdav.endpoint.trim() ?? '';
    if (endpoint.length <= 0) {
      return 'WebDAV 同步';
    }
    return this.webdavProviderCatalog.resolveProviderForEndpoint(endpoint).name;
  }

  private resolveGoalOptionTitle(
    goal: SyncExperienceGoalDescriptor,
    settings: AiraSyncSettings
  ): ResourceStr {
    if (goal.id === 'webdav' && AIRA_DISTRIBUTION_CAPABILITY_OWNER.isOfficial()) {
      const endpoint = settings.webdav.endpoint.trim();
      if (endpoint.length <= 0) {
        return $r('app.string.settings_sync_goal_webdav');
      }
      return this.webdavProviderCatalog.resolveProviderForEndpoint(endpoint).name;
    }
    return resolveDistributionGoalTitle(goal);
  }

  private resolveAdditionalBackupSummary(settings: AiraSyncSettings): ResourceStr {
    const backupKinds = (settings.additionalBackupRemoteKinds ?? []).filter(
      (kind: AiraSyncProviderKind): boolean => kind === 'webdav'
    );
    if (backupKinds.length <= 0) {
      return settings.remoteKind === 'webdav'
        ? $r('app.string.settings_sync_backup_is_webdav')
        : $r('app.string.settings_sync_backup_unset');
    }
    if (settings.additionalBackupEnabled !== true) {
      return $r('app.string.settings_sync_backup_paused');
    }
    const days = settings.additionalBackupIntervalDays === 1 || settings.additionalBackupIntervalDays === 3
      ? settings.additionalBackupIntervalDays
      : 7;
    if (days === 1) {
      return $r('app.string.settings_sync_backup_daily');
    }
    return $r('app.string.settings_sync_backup_interval', days);
  }

  private findRuntimeState(
    settings: AiraSyncSettings,
    activeProvider: AiraSyncRemoteKind
  ): AiraSyncProviderRuntimeState | undefined {
    return (settings.providerStates ?? []).find((state: AiraSyncProviderRuntimeState): boolean => {
      return state.remoteKind === activeProvider;
    });
  }

  private bookmarkNeedsAttention(
    input: SyncExperienceViewModelInput,
    activeProvider: AiraSyncRemoteKind
  ): boolean {
    if (input.settings.bookmarkSyncEnabled !== true) {
      return false;
    }
    const state = this.findRuntimeState(input.settings, activeProvider);
    return state !== undefined && this.isRuntimeUnhealthy(state.bookmark);
  }

  private resolveStatusDetail(
    kind: SyncExperienceStatusKind,
    input: SyncExperienceViewModelInput,
    activeProvider: AiraSyncRemoteKind
  ): ResourceStr {
    if (kind !== 'attention' || !this.bookmarkNeedsAttention(input, activeProvider)) {
      return '';
    }
    const state = this.findRuntimeState(input.settings, activeProvider);
    return this.syncFailurePresentationService.buildBookmarkFailureResource({
      remoteKind: activeProvider,
      operationName: '书签同步',
      failure: state === undefined ? undefined : this.resolveRuntimeBookmarkFailure(state.bookmark)
    });
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

  private personalizationNeedsAttention(
    input: SyncExperienceViewModelInput,
    activeProvider: AiraSyncRemoteKind
  ): boolean {
    if (input.settings.personalizationSyncEnabled !== true) {
      return false;
    }
    const state = this.findRuntimeState(input.settings, activeProvider);
    return state !== undefined && this.isRuntimeUnhealthy(state.personalization);
  }

  private resolveHuaweiSpacePersonalizationSystemUpdateGuidance(
    input: SyncExperienceViewModelInput,
    activeProvider: AiraSyncRemoteKind
  ): string {
    if (activeProvider !== 'huawei_space') {
      return '';
    }
    const state = this.findRuntimeState(input.settings, activeProvider);
    if (state === undefined) {
      return '';
    }
    return this.syncFailurePresentationService
      .buildHuaweiSpacePersonalizationSystemUpdateGuidance(state.personalization.lastError);
  }

  private isRuntimeUnhealthy(state: AiraSyncDomainRuntimeState): boolean {
    return state.health === 'degraded' || state.health === 'unavailable';
  }

  private isHuaweiBookmarkInitializing(settings: AiraSyncSettings): boolean {
    if (!AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_space') ||
      settings.remoteKind !== 'huawei_space' || settings.bookmarkSyncEnabled !== true ||
      (settings.pendingBookmarkSyncAt ?? 0) <= 0) {
      return false;
    }
    const state = this.findRuntimeState(settings, 'huawei_space');
    return state === undefined || (!state.bookmark.blocked && state.bookmark.lastSuccessAt <= 0);
  }

  private hasAdditionalBackupAttention(settings: AiraSyncSettings): boolean {
    if (settings.additionalBackupEnabled !== true) {
      return false;
    }
    const backupKinds = settings.additionalBackupRemoteKinds ?? [];
    return backupKinds.some((remoteKind: AiraSyncProviderKind): boolean => {
      const state = this.findRuntimeState(settings, remoteKind);
      return state !== undefined && (
        this.isRuntimeUnhealthy(state.bookmarkBackup) ||
        this.isRuntimeUnhealthy(state.personalizationBackup)
      );
    });
  }

  private isProviderKind(remoteKind: AiraSyncRemoteKind): boolean {
    return this.isProviderAvailable(remoteKind);
  }

  private resolveAvailableProvider(remoteKind: AiraSyncRemoteKind): AiraSyncRemoteKind {
    if (!this.isProviderAvailable(remoteKind)) {
      return 'none';
    }
    return remoteKind;
  }

  private isProviderAvailable(remoteKind: AiraSyncRemoteKind): boolean {
    if (remoteKind === 'aira_cloud') {
      return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_space');
    }
    return remoteKind === 'webdav' || remoteKind === 'self_hosted';
  }

  private formatLastSyncLabel(timestamp: number): ResourceStr {
    if (timestamp <= 0) {
      return $r('app.string.settings_sync_last_never');
    }
    const date = new Date(timestamp);
    const now = new Date();
    const time = `${this.padTwoDigits(date.getHours())}:${this.padTwoDigits(date.getMinutes())}`;
    if (date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth() &&
      date.getDate() === now.getDate()) {
      return $r('app.string.settings_sync_last_today', time);
    }
    return $r('app.string.settings_sync_last_date', date.getMonth() + 1, date.getDate(), time);
  }

  private padTwoDigits(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
