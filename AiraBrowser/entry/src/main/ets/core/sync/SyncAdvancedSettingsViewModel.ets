import {
  AIRA_FEATURE_CLOUD_SYNC,
  AIRA_FEATURE_WEBDAV_SYNC,
  AiraFeatureKey
} from '../../common/constants/MembershipFeatureKeys';
import {
  AIRA_SYNC_DEFAULT_ROOT,
  AiraSyncBaselineRecord,
  AiraSyncRemoteKind,
  AiraSyncSettings,
  buildAiraHuaweiSpaceRemoteStatusProviderKey,
  buildAiraPersonalServerRemoteStatusProviderKey,
  buildAiraWebdavRemoteStatusProviderKey,
  isAiraSyncProviderEnabled,
  resolveAiraSyncProviderRuntimeState
} from '../../common/models/AiraSyncModels';
import {
  AIRA_CLOUD_BOOKMARK_API_LARGE_PAYLOAD_TIMEOUT_MS
} from '../../services/sync/AiraCloudBookmarkRemoteStore';
import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  SYNC_OPERATION_PROGRESS_TIMING
} from './SyncOperationProgressViewModel';
import { BookmarkLocalOverviewCounts } from '../bookmarks/BookmarkLocalOverviewViewModel';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';

export interface SyncAdvancedStatusViewState {
  providerText: ResourceStr;
  baselineText: ResourceStr;
  localText: ResourceStr;
  remoteText: ResourceStr;
  lastSyncText: ResourceStr;
}

export interface SyncAdvancedProviderActionState {
  showHuaweiCloud: boolean;
  showHuaweiSpace: boolean;
  showWebdav: boolean;
  mergeRequiresPro: boolean;
}

export type SyncAdvancedProviderIdResolver = (remoteKind: AiraSyncRemoteKind) => string;

export class SyncAdvancedSettingsViewModel {
  buildPrivateStatus(): SyncAdvancedStatusViewState {
    return {
      providerText: $r('app.string.settings_sync_advanced_private'),
      baselineText: $r('app.string.settings_sync_advanced_unavailable'),
      localText: $r('app.string.settings_sync_advanced_private_skip'),
      remoteText: $r('app.string.settings_sync_advanced_unavailable'),
      lastSyncText: $r('app.string.settings_sync_advanced_private_skip')
    };
  }

  buildStatus(
    settings: AiraSyncSettings,
    baselines: AiraSyncBaselineRecord[],
    providerIdResolver: SyncAdvancedProviderIdResolver,
    localCounts?: BookmarkLocalOverviewCounts
  ): SyncAdvancedStatusViewState {
    const enabledKinds = this.resolveEnabledRemoteKinds(settings);
    return {
      providerText: this.buildEnabledProviderSummary(enabledKinds),
      baselineText: this.buildBaselineSummary(baselines, enabledKinds, providerIdResolver),
      localText: localCounts === undefined
        ? $r('app.string.settings_sync_advanced_reading')
        : this.formatBookmarkCounts(localCounts.bookmarkFolderCount, localCounts.bookmarkItemCount),
      remoteText: this.buildCachedRemoteSummary(settings, enabledKinds),
      lastSyncText: this.buildLastSyncSummary(settings, enabledKinds)
    };
  }

  buildProviderActions(settings: AiraSyncSettings): SyncAdvancedProviderActionState {
    return {
      showHuaweiCloud: AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud') &&
        this.isProviderConfigured(settings, 'aira_cloud'),
      showHuaweiSpace: AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_space') &&
        this.isProviderConfigured(settings, 'huawei_space'),
      showWebdav: this.isProviderConfigured(settings, 'webdav'),
      mergeRequiresPro: this.resolveEnabledRemoteKinds(settings).indexOf('aira_cloud') >= 0
    };
  }

  resolveEnabledRemoteKinds(settings: AiraSyncSettings): AiraSyncRemoteKind[] {
    if (this.isRemoteKindEnabled(settings, settings.remoteKind)) {
      return [settings.remoteKind];
    }
    if (this.isRemoteKindEnabled(settings, 'huawei_space')) {
      return ['huawei_space'];
    }
    if (this.isRemoteKindEnabled(settings, 'webdav')) {
      return ['webdav'];
    }
    if (this.isRemoteKindEnabled(settings, 'aira_cloud')) {
      return ['aira_cloud'];
    }
    return [];
  }

  isProviderSyncReady(settings: AiraSyncSettings, remoteKind: AiraSyncRemoteKind): boolean {
    if (remoteKind === 'aira_cloud') {
      return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud') &&
        isAiraSyncProviderEnabled(settings, remoteKind) &&
        settings.huaweiCloud.uid.trim().length > 0;
    }
    if (remoteKind === 'huawei_space') {
      return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_space') &&
        isAiraSyncProviderEnabled(settings, remoteKind) &&
        settings.huaweiSpace.uid.trim().length > 0;
    }
    if (remoteKind === 'webdav') {
      return isAiraSyncProviderEnabled(settings, remoteKind) &&
        settings.webdav.endpoint.trim().length > 0 &&
        settings.webdav.username.trim().length > 0;
    }
    if (remoteKind === 'self_hosted') {
      const config = settings.selfHosted;
      return isAiraSyncProviderEnabled(settings, remoteKind) && config !== undefined &&
        config.instanceId.trim().length > 0 && config.deviceToken.trim().length > 0;
    }
    return false;
  }

  resolveActiveSyncServiceKey(settings: AiraSyncSettings, fallbackRemoteKind: AiraSyncRemoteKind): AiraFeatureKey {
    const enabledKinds = this.resolveEnabledRemoteKinds(settings);
    const remoteKind = enabledKinds.length === 1 ? enabledKinds[0] : fallbackRemoteKind;
    return this.resolveProviderSyncServiceKey(remoteKind);
  }

  resolveProviderSyncServiceKey(remoteKind: AiraSyncRemoteKind): AiraFeatureKey {
    if (remoteKind === 'aira_cloud') {
      return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud')
        ? AIRA_FEATURE_CLOUD_SYNC
        : '' as AiraFeatureKey;
    }
    if (remoteKind === 'webdav') {
      return AIRA_FEATURE_WEBDAV_SYNC;
    }
    if (remoteKind === 'huawei_space') {
      return '' as AiraFeatureKey;
    }
    return '' as AiraFeatureKey;
  }

  resolveActiveSyncServiceName(settings: AiraSyncSettings, fallbackRemoteKind: AiraSyncRemoteKind): string {
    const enabledKinds = this.resolveEnabledRemoteKinds(settings);
    const remoteKind = enabledKinds.length === 1 ? enabledKinds[0] : fallbackRemoteKind;
    return this.resolveProviderServiceName(remoteKind);
  }

  resolveProviderServiceName(remoteKind: AiraSyncRemoteKind): string {
    if (remoteKind === 'aira_cloud') {
      return resolveAppResourceText($r('app.string.settings_sync_goal_cloud'));
    }
    if (remoteKind === 'huawei_space') {
      return resolveAppResourceText($r('app.string.settings_sync_advanced_huawei_sync'));
    }
    if (remoteKind === 'webdav') {
      return 'WebDAV';
    }
    if (remoteKind === 'self_hosted') {
      return resolveAppResourceText($r('app.string.settings_sync_self_host_title'));
    }
    return resolveAppResourceText($r('app.string.settings_sync_advanced_service'));
  }

  resolveProviderShortLabel(remoteKind: AiraSyncRemoteKind): string {
    if (remoteKind === 'aira_cloud') {
      return resolveAppResourceText($r('app.string.settings_sync_advanced_cloud_short'));
    }
    if (remoteKind === 'huawei_space') {
      return resolveAppResourceText($r('app.string.settings_sync_advanced_huawei_short'));
    }
    if (remoteKind === 'webdav') {
      return 'WebDAV';
    }
    if (remoteKind === 'self_hosted') {
      return resolveAppResourceText($r('app.string.settings_sync_self_host_title'));
    }
    return resolveAppResourceText($r('app.string.settings_sync_advanced_remote_short'));
  }

  resolveProviderCheckActionLabel(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_check_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_check_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_check_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_check_self_host');
    }
    return $r('app.string.settings_sync_advanced_check_remote');
  }

  resolveProviderOperationTimeoutMs(remoteKind: AiraSyncRemoteKind): number {
    return remoteKind === 'aira_cloud'
      ? AIRA_CLOUD_BOOKMARK_API_LARGE_PAYLOAD_TIMEOUT_MS
      : SYNC_OPERATION_PROGRESS_TIMING.timeoutMs;
  }

  resolveMergeActionLabel(): ResourceStr {
    return $r('app.string.settings_sync_advanced_merge');
  }

  resolveProviderSectionTitle(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_goal_cloud');
    }
    return this.resolveProviderServiceResource(remoteKind);
  }

  resolveProviderServiceResource(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_goal_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_huawei_sync');
    }
    if (remoteKind === 'webdav') {
      return 'WebDAV';
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_pro_self_hosting');
    }
    return $r('app.string.settings_sync_advanced_service');
  }

  resolvePushActionLabel(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_push_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_push_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_push_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_push_self_host');
    }
    return $r('app.string.settings_sync_advanced_push_remote');
  }

  resolvePullActionLabel(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_pull_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_pull_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_pull_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_pull_self_host');
    }
    return $r('app.string.settings_sync_advanced_pull_remote');
  }

  resolvePushConfirmTitle(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_push_confirm_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_push_confirm_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_push_confirm_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_push_confirm_self_host');
    }
    return $r('app.string.settings_sync_advanced_push_confirm_remote');
  }

  resolvePullConfirmTitle(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_pull_confirm_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_pull_confirm_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_pull_confirm_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_pull_confirm_self_host');
    }
    return $r('app.string.settings_sync_advanced_pull_confirm_remote');
  }

  resolvePushConfirmMessage(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_push_message_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_push_message_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_push_message_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_push_message_self_host');
    }
    return $r('app.string.settings_sync_advanced_push_message_service');
  }

  resolvePullConfirmMessage(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_pull_message_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_pull_message_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_pull_message_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_pull_message_self_host');
    }
    return $r('app.string.settings_sync_advanced_pull_message_service');
  }

  resolveReadingStatus(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_reading_status_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_reading_status_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_reading_status_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_reading_status_self_host');
    }
    return $r('app.string.settings_sync_advanced_reading_status_remote');
  }

  resolveConnecting(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_connecting_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_connecting_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_connecting_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_connecting_self_host');
    }
    return $r('app.string.settings_sync_advanced_connecting_remote');
  }

  resolveRefreshed(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_refreshed_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_refreshed_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_refreshed_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_refreshed_self_host');
    }
    return $r('app.string.settings_sync_advanced_refreshed_remote');
  }

  resolveReadingData(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_reading_data_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_reading_data_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_reading_data_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_reading_data_self_host');
    }
    return $r('app.string.settings_sync_advanced_reading_data_remote');
  }

  resolvePreparingSpace(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_preparing_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_preparing_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_preparing_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_preparing_self_host');
    }
    return $r('app.string.settings_sync_advanced_preparing_remote');
  }

  resolveSavingBookmarks(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_saving_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_saving_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_saving_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_saving_self_host');
    }
    return $r('app.string.settings_sync_advanced_saving_remote');
  }

  resolveSwitchActionLabel(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_switch_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_switch_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_switch_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_switch_confirm_self_host');
    }
    return $r('app.string.settings_sync_advanced_switch_confirm_service');
  }

  resolveCurrentSwitchActionLabel(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_using_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_using_huawei');
    }
    return $r('app.string.settings_sync_advanced_using_webdav');
  }

  resolveSwitchConfirmTitle(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_switch_confirm_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_switch_confirm_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_switch_confirm_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_switch_confirm_self_host');
    }
    return $r('app.string.settings_sync_advanced_switch_confirm_service');
  }

  resolveSwitchConfirmMessage(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_switch_message_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_switch_message_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_switch_message_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_switch_message_self_host');
    }
    return $r('app.string.settings_sync_advanced_switch_message_service');
  }

  resolveMergingData(remoteKind: AiraSyncRemoteKind): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_merging_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_merging_huawei');
    }
    if (remoteKind === 'webdav') {
      return $r('app.string.settings_sync_advanced_merging_webdav');
    }
    if (remoteKind === 'self_hosted') {
      return $r('app.string.settings_sync_advanced_merging_self_host');
    }
    return $r('app.string.settings_sync_advanced_merging_service');
  }

  resolveMissingConfigurationMessage(
    settings: AiraSyncSettings,
    remoteKind: AiraSyncRemoteKind
  ): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return $r('app.string.settings_sync_advanced_enable_cloud');
    }
    if (remoteKind === 'huawei_space') {
      return $r('app.string.settings_sync_advanced_enable_huawei');
    }
    if (remoteKind === 'webdav') {
      return settings.webdav.endpoint.trim().length > 0 && settings.webdav.username.trim().length > 0
        ? $r('app.string.settings_sync_advanced_enable_saved_webdav')
        : $r('app.string.settings_sync_advanced_fill_webdav');
    }
    return $r('app.string.settings_sync_advanced_enable_one');
  }

  updateRemoteSummaryText(summary: string): string {
    return summary;
  }

  resolveRemoteStatusProviderKey(settings: AiraSyncSettings, remoteKind: AiraSyncRemoteKind): string {
    if (remoteKind === 'aira_cloud') {
      if (!AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud')) {
        return 'none';
      }
      return `aira_cloud|${settings.huaweiCloud.uid.trim()}|${AIRA_SYNC_DEFAULT_ROOT}`;
    }
    if (remoteKind === 'huawei_space') {
      return buildAiraHuaweiSpaceRemoteStatusProviderKey(
        settings.huaweiSpace.uid,
        settings.huaweiSpace.databaseName,
        AIRA_SYNC_DEFAULT_ROOT
      );
    }
    if (remoteKind === 'webdav') {
      return buildAiraWebdavRemoteStatusProviderKey(
        settings.webdav.endpoint,
        settings.webdav.username,
        AIRA_SYNC_DEFAULT_ROOT
      );
    }
    if (remoteKind === 'self_hosted') {
      const config = settings.selfHosted;
      if (config === undefined) {
        return 'none';
      }
      return buildAiraPersonalServerRemoteStatusProviderKey(config.instanceId, config.baseUrl);
    }
    return 'none';
  }

  private isProviderConfigured(settings: AiraSyncSettings, remoteKind: AiraSyncRemoteKind): boolean {
    if (remoteKind === 'aira_cloud') {
      return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud') &&
        settings.huaweiCloud.uid.trim().length > 0;
    }
    if (remoteKind === 'huawei_space') {
      return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_space') &&
        settings.huaweiSpace.uid.trim().length > 0;
    }
    if (remoteKind === 'webdav') {
      return settings.webdav.endpoint.trim().length > 0 &&
        settings.webdav.username.trim().length > 0;
    }
    if (remoteKind === 'self_hosted') {
      const config = settings.selfHosted;
      return config !== undefined && config.baseUrl.trim().length > 0 &&
        config.instanceId.trim().length > 0 && config.deviceToken.trim().length > 0;
    }
    return false;
  }

  private buildEnabledProviderSummary(enabledKinds: AiraSyncRemoteKind[]): ResourceStr {
    if (enabledKinds.length <= 0) {
      return $r('app.string.settings_sync_advanced_disabled');
    }
    return this.resolveProviderServiceResource(enabledKinds[0]);
  }

  private buildCachedRemoteSummary(settings: AiraSyncSettings, enabledKinds: AiraSyncRemoteKind[]): ResourceStr {
    if (enabledKinds.length <= 0) {
      return $r('app.string.settings_sync_advanced_disabled');
    }
    return this.resolveProviderCachedSummary(settings, enabledKinds[0]);
  }

  private resolveProviderCachedSummary(settings: AiraSyncSettings, remoteKind: AiraSyncRemoteKind): ResourceStr {
    const cache = remoteKind === 'aira_cloud'
      ? settings.huaweiCloud.remoteStatusCache
      : (remoteKind === 'huawei_space'
        ? settings.huaweiSpace.remoteStatusCache
        : (remoteKind === 'webdav'
          ? settings.webdav.remoteStatusCache
          : (remoteKind === 'self_hosted' ? (settings.selfHosted?.remoteStatusCache ?? null) : null)));
    if (cache === null || cache.providerKey !== this.resolveRemoteStatusProviderKey(settings, remoteKind)) {
      return $r('app.string.settings_sync_advanced_not_checked');
    }
    return cache.summary;
  }

  private formatBookmarkCounts(folderCount: number, itemCount: number): ResourceStr {
    return $r('app.string.settings_sync_advanced_counts', Math.max(0, folderCount), Math.max(0, itemCount));
  }

  private buildBaselineSummary(
    records: AiraSyncBaselineRecord[],
    enabledKinds: AiraSyncRemoteKind[],
    providerIdResolver: SyncAdvancedProviderIdResolver
  ): ResourceStr {
    if (enabledKinds.length <= 0) {
      return $r('app.string.settings_sync_advanced_disabled');
    }
    const remoteKind = enabledKinds[0];
    const providerId = providerIdResolver(remoteKind);
    const hasBaseline = records.some((record: AiraSyncBaselineRecord) => record.providerId === providerId);
    return this.resolveBaselineResource(remoteKind, hasBaseline);
  }

  private resolveBaselineResource(remoteKind: AiraSyncRemoteKind, hasBaseline: boolean): ResourceStr {
    if (remoteKind === 'aira_cloud') {
      return hasBaseline
        ? $r('app.string.settings_sync_advanced_baseline_cloud_ready')
        : $r('app.string.settings_sync_advanced_baseline_cloud_missing');
    }
    if (remoteKind === 'huawei_space') {
      return hasBaseline
        ? $r('app.string.settings_sync_advanced_baseline_huawei_ready')
        : $r('app.string.settings_sync_advanced_baseline_huawei_missing');
    }
    if (remoteKind === 'webdav') {
      return hasBaseline
        ? $r('app.string.settings_sync_advanced_baseline_webdav_ready')
        : $r('app.string.settings_sync_advanced_baseline_webdav_missing');
    }
    if (remoteKind === 'self_hosted') {
      return hasBaseline
        ? $r('app.string.settings_sync_advanced_baseline_self_host_ready')
        : $r('app.string.settings_sync_advanced_baseline_self_host_missing');
    }
    return hasBaseline
      ? $r('app.string.settings_sync_advanced_baseline_remote_ready')
      : $r('app.string.settings_sync_advanced_baseline_remote_missing');
  }

  private buildLastSyncSummary(settings: AiraSyncSettings, enabledKinds: AiraSyncRemoteKind[]): ResourceStr {
    if (enabledKinds.length <= 0) {
      return $r('app.string.settings_sync_advanced_none');
    }
    const timestamp = this.resolveProviderLastSuccessAt(settings, enabledKinds[0]);
    return timestamp > 0 ? new Date(timestamp).toLocaleString() : $r('app.string.settings_sync_advanced_none');
  }

  private isRemoteKindEnabled(settings: AiraSyncSettings, remoteKind: AiraSyncRemoteKind): boolean {
    return remoteKind !== 'none' && this.isProviderAvailable(remoteKind) &&
      isAiraSyncProviderEnabled(settings, remoteKind);
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

  private resolveProviderLastSuccessAt(settings: AiraSyncSettings, remoteKind: AiraSyncRemoteKind): number {
    if (remoteKind === 'none') {
      return 0;
    }
    const state = resolveAiraSyncProviderRuntimeState(settings, remoteKind);
    return Math.max(state.bookmark.lastSuccessAt, state.personalization.lastSuccessAt);
  }
}
