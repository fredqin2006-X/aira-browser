import {
  AiraBookmarkConflictResolution,
  AiraBookmarkOverview,
  AiraBookmarkMergeSyncResult,
  AiraSyncBaselineRecord,
  AiraSyncProviderKind,
  AiraSyncRemoteKind
} from '../../common/models/AiraSyncModels';
import { EntitlementDecision } from '../../common/models/MembershipModels';
import {
  AiraLocalBookmarkOverviewCacheRepository
} from '../../data/sync/AiraLocalBookmarkOverviewCacheRepository';
import { SyncService } from '../../services/sync/SyncService';
import {
  BookmarkLocalOverviewCounts,
  BookmarkLocalOverviewViewModel
} from '../bookmarks/BookmarkLocalOverviewViewModel';
import { SyncRemoteStatusCoordinator } from './SyncRemoteStatusCoordinator';
import {
  SyncExperienceProviderOperations,
  SyncExperienceProviderOutcome
} from './SyncExperienceProviderOperations';

export interface SyncAdvancedRemoteSummaryOutcome {
  summary: string;
}

export interface SyncAdvancedMergeOutcome {
  result: AiraBookmarkMergeSyncResult;
  completionTitle: ResourceStr;
  completionSubtitle: ResourceStr;
  dialogTitle: ResourceStr;
  message: ResourceStr;
}

export interface SyncAdvancedStatusOverview {
  localCounts: BookmarkLocalOverviewCounts;
  baselines: AiraSyncBaselineRecord[];
}

export type SyncProviderSelectionPresentationType =
  | 'selected'
  | 'blocked'
  | 'membership-required'
  | 'failed';

export interface SyncProviderSelectionPresentation {
  type: SyncProviderSelectionPresentationType;
  providerLabel: string;
  completionTitle: ResourceStr;
  completionSubtitle: ResourceStr;
  dialogTitle: ResourceStr;
  message: ResourceStr;
  messageLines?: ResourceStr[];
  membershipDecision?: EntitlementDecision;
}

export class SyncExperienceAdvancedOperations {
  private syncService: SyncService;
  private remoteStatusCoordinator: SyncRemoteStatusCoordinator;
  private localOverviewCacheRepository: AiraLocalBookmarkOverviewCacheRepository;
  private providerOperations: SyncExperienceProviderOperations;
  private localOverviewViewModel: BookmarkLocalOverviewViewModel = new BookmarkLocalOverviewViewModel();

  constructor(
    syncService: SyncService,
    remoteStatusCoordinator: SyncRemoteStatusCoordinator,
    localOverviewCacheRepository: AiraLocalBookmarkOverviewCacheRepository,
    providerOperations: SyncExperienceProviderOperations
  ) {
    this.syncService = syncService;
    this.remoteStatusCoordinator = remoteStatusCoordinator;
    this.localOverviewCacheRepository = localOverviewCacheRepository;
    this.providerOperations = providerOperations;
  }

  async selectProvider(remoteKind: AiraSyncRemoteKind): Promise<SyncProviderSelectionPresentation> {
    if (remoteKind === 'none') {
      throw new Error('请先选择同步来源。');
    }
    const outcome = await this.providerOperations.selectProvider(remoteKind);
    if (outcome.type === 'provider-selected') {
      await this.readRemoteSummary(remoteKind).catch((_error: Error): void => {
      });
    }
    return this.presentProviderSelection(outcome);
  }

  async readRemoteSummary(remoteKind: AiraSyncRemoteKind): Promise<SyncAdvancedRemoteSummaryOutcome> {
    if (remoteKind === 'none') {
      throw new Error('请先选择同步来源。');
    }
    const result = await this.remoteStatusCoordinator.readAndCache(remoteKind);
    return {
      summary: result.summary
    };
  }

  async loadStatusOverview(enabledKinds: AiraSyncRemoteKind[]): Promise<SyncAdvancedStatusOverview> {
    const values = await Promise.all([
      this.loadLocalBookmarkCounts(),
      this.readEnabledBaselines(enabledKinds),
      this.refreshEnabledRemoteSummaries(enabledKinds)
    ]);
    return {
      localCounts: values[0],
      baselines: values[1]
    };
  }

  async presentActiveBookmarkMerge(
    remoteKind: AiraSyncRemoteKind,
    result: AiraBookmarkMergeSyncResult
  ): Promise<SyncAdvancedMergeOutcome> {
    return {
      result: result,
      completionTitle: this.resolveMergeCompletionTitle(result, remoteKind),
      completionSubtitle: this.resolveMergeCompletionSubtitle(result, remoteKind),
      dialogTitle: this.resolveMergeDialogTitle(result, remoteKind),
      message: this.buildMergeResultMessage(result, remoteKind)
    };
  }

  async forceBookmarkAuthority(
    remoteKind: AiraSyncProviderKind,
    resolution: AiraBookmarkConflictResolution
  ): Promise<SyncAdvancedMergeOutcome> {
    const result = await this.syncService.resolveAiraBookmarkConflicts(remoteKind, resolution);
    const remoteWins = resolution === 'prefer-remote';
    if (result.blocked) {
      return {
        result: result,
        completionTitle: $r('app.string.settings_sync_advanced_overwrite_incomplete'),
        completionSubtitle: $r('app.string.settings_sync_advanced_handle_status'),
        dialogTitle: $r('app.string.settings_sync_advanced_overwrite_incomplete'),
        message: result.summary
      };
    }
    return {
      result: result,
      completionTitle: remoteWins
        ? this.resolvePulledTitle(remoteKind)
        : this.resolvePushedTitle(remoteKind),
      completionSubtitle: remoteWins
        ? this.resolveUpdatedFromRemote(remoteKind)
        : this.resolveRemoteUpdatedFromLocal(remoteKind),
      dialogTitle: $r('app.string.settings_sync_advanced_overwrite_done'),
      message: remoteWins
        ? this.resolveSnapshotFromRemote(remoteKind)
        : this.resolveSnapshotToRemote(remoteKind)
    };
  }

  readEnabledBaselines(enabledKinds: AiraSyncRemoteKind[]): Promise<AiraSyncBaselineRecord[]> {
    const tasks: Promise<AiraSyncBaselineRecord | undefined>[] = [];
    enabledKinds.forEach((remoteKind: AiraSyncRemoteKind): void => {
      tasks.push(this.syncService.readAiraSyncBaselineForKind(remoteKind));
    });
    return Promise.all(tasks).then((records: (AiraSyncBaselineRecord | undefined)[]): AiraSyncBaselineRecord[] => {
      const result: AiraSyncBaselineRecord[] = [];
      records.forEach((record: AiraSyncBaselineRecord | undefined): void => {
        if (record !== undefined) {
          result.push(record);
        }
      });
      return result;
    });
  }

  private async refreshEnabledRemoteSummaries(enabledKinds: AiraSyncRemoteKind[]): Promise<void> {
    const tasks: Promise<void>[] = [];
    enabledKinds.forEach((remoteKind: AiraSyncRemoteKind): void => {
      if (remoteKind === 'none') {
        return;
      }
      tasks.push(this.remoteStatusCoordinator.readAndCache(remoteKind)
        .then((): void => undefined)
        .catch((_error: Error): void => undefined));
    });
    await Promise.all(tasks);
  }

  private presentProviderSelection(outcome: SyncExperienceProviderOutcome): SyncProviderSelectionPresentation {
    if (outcome.type === 'provider-selection-blocked') {
      return {
        type: 'blocked',
        providerLabel: outcome.providerLabel,
        completionTitle: $r('app.string.settings_sync_advanced_switch_incomplete'),
        completionSubtitle: $r('app.string.settings_sync_advanced_switch_retry'),
        dialogTitle: $r('app.string.settings_sync_advanced_switch_incomplete'),
        message: outcome.message
      };
    }
    if (outcome.type === 'provider-selected') {
      return {
        type: 'selected',
        providerLabel: outcome.providerLabel,
        completionTitle: $r('app.string.settings_sync_method_changed'),
        completionSubtitle: this.resolveSwitchedSubtitle(outcome.remoteKind),
        dialogTitle: $r('app.string.settings_sync_advanced_switch_done'),
        message: outcome.message
      };
    }
    if (outcome.type === 'membership-required' && outcome.membershipDecision !== undefined) {
      return {
        type: 'membership-required',
        providerLabel: outcome.providerLabel,
        completionTitle: $r('app.string.settings_sync_advanced_switch_failed'),
        completionSubtitle: $r('app.string.settings_sync_advanced_membership_required'),
        dialogTitle: $r('app.string.settings_sync_advanced_change_method'),
        message: outcome.message,
        membershipDecision: outcome.membershipDecision
      };
    }
    return {
      type: 'failed',
      providerLabel: outcome.providerLabel,
      completionTitle: $r('app.string.settings_sync_advanced_switch_failed'),
      completionSubtitle: $r('app.string.settings_sync_advanced_try_later'),
      dialogTitle: outcome.title.length > 0 ? outcome.title : $r('app.string.settings_sync_advanced_change_method'),
      message: outcome.message
    };
  }

  private async loadLocalBookmarkCounts(): Promise<BookmarkLocalOverviewCounts> {
    return this.localOverviewViewModel.loadCurrentCounts(
      this.localOverviewCacheRepository,
      (): Promise<AiraBookmarkOverview> => {
        return this.syncService.buildFreshAiraBookmarkOverview();
      }
    );
  }

  private resolveMergeCompletionTitle(result: AiraBookmarkMergeSyncResult, remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'huawei_space' && result.merged) {
      return $r('app.string.settings_sync_advanced_saved_library');
    }
    return result.merged
      ? $r('app.string.settings_sync_advanced_merge_done')
      : $r('app.string.settings_sync_advanced_already_current');
  }

  private resolveMergeCompletionSubtitle(result: AiraBookmarkMergeSyncResult, remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (!result.merged) {
      return $r('app.string.settings_sync_advanced_no_changes');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_huawei_background');
    }
    return $r('app.string.settings_sync_advanced_consistent');
  }

  private resolveMergeDialogTitle(result: AiraBookmarkMergeSyncResult, remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (!result.merged) {
      return $r('app.string.settings_sync_advanced_no_sync_needed');
    }
    return remoteKind === 'huawei_space'
      ? $r('app.string.settings_sync_advanced_saved_library')
      : $r('app.string.settings_sync_advanced_sync_success');
  }

  private buildMergeResultMessage(result: AiraBookmarkMergeSyncResult, remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'huawei_space') {
      return this.simplifyHuaweiSpaceMergeSummary(result);
    }
    return this.simplifyMergeSummary(result);
  }

  private simplifyMergeSummary(result: AiraBookmarkMergeSyncResult): ResourceStr {
    if (result.blocked) {
      return result.conflictCount > 0
        ? $r('app.string.settings_sync_advanced_conflicts', result.conflictCount)
        : $r('app.string.settings_sync_advanced_confirm_continue');
    }
    if (!result.merged) {
      return $r('app.string.settings_sync_advanced_already_match');
    }
    if (result.localChangeCount > 0 && result.remoteChangeCount > 0) {
      return $r('app.string.settings_sync_advanced_merged');
    }
    if (result.localChangeCount > 0) {
      return $r('app.string.settings_sync_advanced_saved_cloud');
    }
    if (result.remoteChangeCount > 0) {
      return $r('app.string.settings_sync_advanced_applied_cloud');
    }
    return $r('app.string.settings_sync_advanced_bookmarks_done');
  }

  private simplifyHuaweiSpaceMergeSummary(result: AiraBookmarkMergeSyncResult): ResourceStr {
    if (result.blocked) {
      return result.conflictCount > 0
        ? $r('app.string.settings_sync_advanced_huawei_conflicts', result.conflictCount)
        : $r('app.string.settings_sync_advanced_confirm_continue');
    }
    if (!result.merged) {
      return $r('app.string.settings_sync_advanced_huawei_no_changes');
    }
    if (result.localChangeCount > 0 && result.remoteChangeCount > 0) {
      return $r('app.string.settings_sync_advanced_huawei_merged');
    }
    if (result.localChangeCount > 0) {
      return $r('app.string.settings_sync_advanced_huawei_saved');
    }
    if (result.remoteChangeCount > 0) {
      return $r('app.string.settings_sync_advanced_huawei_applied');
    }
    return $r('app.string.settings_sync_advanced_huawei_confirmed');
  }

  private resolvePulledTitle(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_pulled_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_pulled_huawei');
    }
    return $r('app.string.settings_sync_advanced_pulled_webdav');
  }

  private resolvePushedTitle(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_pushed_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_pushed_huawei');
    }
    return $r('app.string.settings_sync_advanced_pushed_webdav');
  }

  private resolveUpdatedFromRemote(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_updated_from_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_updated_from_huawei');
    }
    return $r('app.string.settings_sync_advanced_updated_from_webdav');
  }

  private resolveRemoteUpdatedFromLocal(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_remote_updated_from_local_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_remote_updated_from_local_huawei');
    }
    return $r('app.string.settings_sync_advanced_remote_updated_from_local_webdav');
  }

  private resolveSnapshotFromRemote(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_snapshot_from_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_snapshot_from_huawei');
    }
    return $r('app.string.settings_sync_advanced_snapshot_from_webdav');
  }

  private resolveSnapshotToRemote(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_snapshot_to_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_snapshot_to_huawei');
    }
    return $r('app.string.settings_sync_advanced_snapshot_to_webdav');
  }

  private resolveSwitchedSubtitle(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_switched_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_switched_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_switched_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_switched_self_host');
    }
    return $r('app.string.settings_sync_advanced_switched_service');
  }
}
