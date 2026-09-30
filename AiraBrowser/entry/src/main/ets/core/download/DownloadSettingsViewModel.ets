import {
  BrowserDownloadAutoClearPolicy,
  BrowserDownloadLocation,
  BrowserHlsSegmentConcurrency,
  BrowserPrivateDownloadFilePolicy,
  BrowserPrivateDownloadRecordPolicy,
  BrowserDownloadSettings
} from '../../common/models/BrowserModels';
import { resolveAppResourceText } from '../resources/AppResourceText';

export interface DownloadSettingsOptionView<T> {
  value: T;
  label: string;
  helperText: string;
}

export interface DownloadSettingsSectionState {
  summaryText: string;
  helperText: string;
  defaultLocation: BrowserDownloadLocation;
  defaultLocationLabel: string;
  customLocationUri: string;
  customLocationLabel: string;
  askBeforeDownload: boolean;
  allowCellularDownloads: boolean;
  autoResumeAfterRestart: boolean;
  hlsSegmentConcurrency: BrowserHlsSegmentConcurrency;
  autoClearPolicy: BrowserDownloadAutoClearPolicy;
  privateFilePolicy: BrowserPrivateDownloadFilePolicy;
  privateRecordPolicy: BrowserPrivateDownloadRecordPolicy;
  autoClearOptions: DownloadSettingsOptionView<BrowserDownloadAutoClearPolicy>[];
  hlsSegmentConcurrencyOptions: DownloadSettingsOptionView<BrowserHlsSegmentConcurrency>[];
  privateFileOptions: DownloadSettingsOptionView<BrowserPrivateDownloadFilePolicy>[];
  privateRecordOptions: DownloadSettingsOptionView<BrowserPrivateDownloadRecordPolicy>[];
}

function buildDownloadAutoClearOptions(): DownloadSettingsOptionView<BrowserDownloadAutoClearPolicy>[] {
  return [
  {
    value: 'manual',
    label: resolveAppResourceText($r('app.string.settings_web_download_clear_manual')),
    helperText: resolveAppResourceText($r('app.string.settings_web_download_clear_manual_hint'))
  },
  {
    value: 'clear_completed',
    label: resolveAppResourceText($r('app.string.settings_web_download_clear_completed')),
    helperText: resolveAppResourceText($r('app.string.settings_web_download_clear_completed_hint'))
  },
  {
    value: 'clear_completed_and_failed',
    label: resolveAppResourceText($r('app.string.settings_web_download_clear_failed')),
    helperText: resolveAppResourceText($r('app.string.settings_web_download_clear_failed_hint'))
  }
  ];
}

const HLS_SEGMENT_CONCURRENCY_OPTIONS: DownloadSettingsOptionView<BrowserHlsSegmentConcurrency>[] = [
  {
    value: '4',
    label: '4',
    helperText: ''
  },
  {
    value: '8',
    label: '8',
    helperText: ''
  },
  {
    value: '16',
    label: '16',
    helperText: ''
  }
];

function buildPrivateDownloadFileOptions(): DownloadSettingsOptionView<BrowserPrivateDownloadFilePolicy>[] {
  return [
  {
    value: 'prompt_for_location',
    label: resolveAppResourceText($r('app.string.settings_web_download_ask')),
    helperText: resolveAppResourceText($r('app.string.settings_web_download_private_ask_hint'))
  },
  {
    value: 'session_temp_only',
    label: resolveAppResourceText($r('app.string.settings_web_download_private_temp')),
    helperText: resolveAppResourceText($r('app.string.settings_web_download_private_temp_hint'))
  }
  ];
}

function buildPrivateDownloadRecordOptions(): DownloadSettingsOptionView<BrowserPrivateDownloadRecordPolicy>[] {
  return [
  {
    value: 'keep_until_window_close',
    label: resolveAppResourceText($r('app.string.settings_web_download_private_keep')),
    helperText: resolveAppResourceText($r('app.string.settings_web_download_private_keep_hint'))
  },
  {
    value: 'clear_after_export',
    label: resolveAppResourceText($r('app.string.settings_web_download_private_export')),
    helperText: resolveAppResourceText($r('app.string.settings_web_download_private_export_hint'))
  }
  ];
}

export class DownloadSettingsViewModel {
  buildState(settings: BrowserDownloadSettings): DownloadSettingsSectionState {
    return {
      summaryText: this.buildSummaryText(settings),
      helperText: this.buildHelperText(settings),
      defaultLocation: settings.defaultLocation,
      defaultLocationLabel: this.getLocationLabel(settings),
      customLocationUri: settings.customLocationUri,
      customLocationLabel: settings.customLocationLabel,
      askBeforeDownload: settings.askBeforeDownload,
      allowCellularDownloads: settings.allowCellularDownloads,
      autoResumeAfterRestart: settings.autoResumeAfterRestart,
      hlsSegmentConcurrency: settings.hlsSegmentConcurrency,
      autoClearPolicy: settings.autoClearPolicy,
      privateFilePolicy: settings.privateFilePolicy,
      privateRecordPolicy: settings.privateRecordPolicy,
      autoClearOptions: buildDownloadAutoClearOptions(),
      hlsSegmentConcurrencyOptions: HLS_SEGMENT_CONCURRENCY_OPTIONS.slice(),
      privateFileOptions: buildPrivateDownloadFileOptions(),
      privateRecordOptions: buildPrivateDownloadRecordOptions()
    };
  }

  buildSettingsPatch(
    currentSettings: BrowserDownloadSettings,
    patch: Partial<BrowserDownloadSettings>
  ): BrowserDownloadSettings {
    return {
      defaultLocation: patch.defaultLocation ?? currentSettings.defaultLocation,
      customLocationUri: patch.customLocationUri ?? currentSettings.customLocationUri,
      customLocationLabel: patch.customLocationLabel ?? currentSettings.customLocationLabel,
      askBeforeDownload: patch.askBeforeDownload ?? currentSettings.askBeforeDownload,
      allowCellularDownloads: patch.allowCellularDownloads ?? currentSettings.allowCellularDownloads,
      autoResumeAfterRestart: patch.autoResumeAfterRestart ?? currentSettings.autoResumeAfterRestart,
      hlsSegmentConcurrency: patch.hlsSegmentConcurrency ?? currentSettings.hlsSegmentConcurrency,
      autoClearPolicy: patch.autoClearPolicy ?? currentSettings.autoClearPolicy,
      privateFilePolicy: patch.privateFilePolicy ?? currentSettings.privateFilePolicy,
      privateRecordPolicy: patch.privateRecordPolicy ?? currentSettings.privateRecordPolicy
    };
  }

  private buildSummaryText(settings: BrowserDownloadSettings): string {
    const askBeforeDownloadLabel = resolveAppResourceText(settings.askBeforeDownload
      ? $r('app.string.settings_web_download_ask')
      : $r('app.string.settings_web_download_direct'));
    const networkLabel = resolveAppResourceText(settings.allowCellularDownloads
      ? $r('app.string.settings_web_download_cellular_allowed')
      : $r('app.string.settings_web_download_wlan_only'));
    const resumeLabel = resolveAppResourceText(settings.autoResumeAfterRestart
      ? $r('app.string.settings_web_download_resume_on')
      : $r('app.string.settings_web_download_resume_manual'));
    return `${this.getLocationLabel(settings)} · ${askBeforeDownloadLabel} · ${networkLabel} · ${resumeLabel}`;
  }

  private buildHelperText(settings: BrowserDownloadSettings): string {
    if (!settings.autoResumeAfterRestart) {
      return resolveAppResourceText($r('app.string.settings_web_download_helper_no_resume'));
    }
    if (settings.askBeforeDownload) {
      return resolveAppResourceText($r('app.string.settings_web_download_helper_ask'));
    }
    if (settings.autoClearPolicy === 'manual') {
      return resolveAppResourceText($r('app.string.settings_web_download_helper_manual_clear'));
    }
    return resolveAppResourceText($r('app.string.settings_web_download_helper_auto_clear'));
  }

  private getLocationLabel(settings: BrowserDownloadSettings): string {
    if (settings.defaultLocation === 'custom' && settings.customLocationLabel.trim().length > 0) {
      return settings.customLocationLabel.trim();
    }
    return resolveAppResourceText($r('app.string.settings_web_download_system_location'));
  }

}
