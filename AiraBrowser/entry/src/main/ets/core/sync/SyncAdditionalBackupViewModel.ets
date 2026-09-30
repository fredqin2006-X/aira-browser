import {
  AiraAdditionalBackupIntervalDays,
  AiraSyncSettings
} from '../../common/models/AiraSyncModels';
import { SyncAdditionalBackupPolicyService } from '../../services/sync/SyncAdditionalBackupPolicyService';
import { SyncSettingsProviderCardViewState } from './SyncSettingsCenterViewModel';

export interface SyncAdditionalBackupViewState {
  enabled: boolean;
  intervalDays: AiraAdditionalBackupIntervalDays;
  intervalLabel: ResourceStr;
  providerCards: SyncSettingsProviderCardViewState[];
  providerSummary: ResourceStr;
  lastBackupLabel: ResourceStr;
  statusMessage: ResourceStr;
  canBackupNow: boolean;
}

export function createDefaultSyncAdditionalBackupViewState(): SyncAdditionalBackupViewState {
  return {
    enabled: false,
    intervalDays: 7,
    intervalLabel: $r('app.string.settings_sync_backup_every_days', 7),
    providerCards: [],
    providerSummary: $r('app.string.settings_sync_backup_unset'),
    lastBackupLabel: $r('app.string.settings_sync_backup_last_never'),
    statusMessage: $r('app.string.settings_sync_backup_status_note'),
    canBackupNow: false
  };
}

export class SyncAdditionalBackupViewModel {
  private policyService: SyncAdditionalBackupPolicyService = new SyncAdditionalBackupPolicyService();

  buildState(
    settings: AiraSyncSettings,
    providerCards: SyncSettingsProviderCardViewState[]
  ): SyncAdditionalBackupViewState {
    const destinationCard = this.resolveWebdavDestination(providerCards);
    const destinationReady = destinationCard !== undefined && destinationCard.role === 'additional_backup';
    const enabled = this.policyService.isEnabled(settings);
    const lastBackupAt = this.policyService.resolveLastCompleteBackupAt(settings);
    return {
      enabled: enabled,
      intervalDays: this.policyService.resolveIntervalDays(settings),
      intervalLabel: this.resolveIntervalLabel(this.policyService.resolveIntervalDays(settings)),
      providerCards: destinationCard === undefined ? [] : [destinationCard],
      providerSummary: this.resolveProviderSummary(destinationCard, settings),
      lastBackupLabel: this.formatTimestamp(lastBackupAt),
      statusMessage: this.resolveStatusMessage(enabled, destinationReady, destinationCard),
      canBackupNow: enabled && destinationReady &&
        (settings.bookmarkSyncEnabled === true || settings.personalizationSyncEnabled === true)
    };
  }

  private resolveWebdavDestination(
    providerCards: SyncSettingsProviderCardViewState[]
  ): SyncSettingsProviderCardViewState | undefined {
    return providerCards.find((card: SyncSettingsProviderCardViewState): boolean => {
      return card.id === 'webdav';
    });
  }

  private resolveIntervalLabel(days: AiraAdditionalBackupIntervalDays): ResourceStr {
    return days === 1
      ? $r('app.string.settings_sync_backup_every_day')
      : $r('app.string.settings_sync_backup_every_days', days);
  }

  private resolveProviderSummary(
    destinationCard: SyncSettingsProviderCardViewState | undefined,
    settings: AiraSyncSettings
  ): ResourceStr {
    if (destinationCard === undefined) {
      return settings.remoteKind === 'webdav'
        ? $r('app.string.settings_sync_backup_is_webdav')
        : $r('app.string.settings_sync_backup_unavailable');
    }
    if (destinationCard.role === 'additional_backup') {
      const endpoint = settings.webdav.endpoint.trim();
      return endpoint.length > 0 ? endpoint : $r('app.string.settings_sync_backup_webdav_on');
    }
    return destinationCard.isConfigured
      ? $r('app.string.settings_sync_backup_filled_off')
      : $r('app.string.settings_sync_backup_unset');
  }

  private resolveStatusMessage(
    enabled: boolean,
    destinationReady: boolean,
    destinationCard: SyncSettingsProviderCardViewState | undefined
  ): ResourceStr {
    if (destinationCard === undefined) {
      return $r('app.string.settings_sync_backup_already_webdav');
    }
    if (!destinationReady) {
      return $r('app.string.settings_sync_backup_status_note');
    }
    if (!enabled) {
      return $r('app.string.settings_sync_backup_status_paused');
    }
    return $r('app.string.settings_sync_backup_status_on');
  }

  private formatTimestamp(timestamp: number): ResourceStr {
    if (timestamp <= 0) {
      return $r('app.string.settings_sync_backup_last_never');
    }
    const date = new Date(timestamp);
    const now = new Date();
    const time = `${this.pad(date.getHours())}:${this.pad(date.getMinutes())}`;
    if (date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth() &&
      date.getDate() === now.getDate()) {
      return $r('app.string.settings_sync_backup_last_today', time);
    }
    return $r('app.string.settings_sync_backup_last_date', date.getMonth() + 1, date.getDate(), time);
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
