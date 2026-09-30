import { hasAppResourceText, isAppString } from '../resources/AppResourceText';

export interface SyncOperationProgressTipsState {
  tips: ResourceStr[];
  index: number;
  activeTip: ResourceStr;
}

export interface SyncOperationProgressTimingProfile {
  tipIntervalMs: number;
  visualIntervalMs: number;
  minVisibleMs: number;
  timeoutMs: number;
  finishIntervalMs: number;
  successVisibleMs: number;
  inProgressTarget: number;
}

export const SYNC_OPERATION_PROGRESS_TIMING: SyncOperationProgressTimingProfile = {
  tipIntervalMs: 900,
  visualIntervalMs: 140,
  minVisibleMs: 900,
  timeoutMs: 120000,
  finishIntervalMs: 260,
  successVisibleMs: 1600,
  inProgressTarget: 88
};

const SYNC_TIP_RESOURCES: string[] = [
  'settings_sync_progress_tip_collecting_local',
  'settings_sync_progress_tip_checking_cloud',
  'settings_sync_progress_tip_comparing',
  'settings_sync_progress_tip_protecting',
  'settings_sync_progress_tip_applying',
  'settings_sync_progress_tip_writing_record',
  'settings_sync_progress_tip_wrapping_up'
];

const UPLOAD_TIP_RESOURCES: string[] = [
  'settings_sync_progress_tip_collecting_content',
  'settings_sync_progress_tip_preparing_cloud',
  'settings_sync_progress_tip_uploading_bookmarks',
  'settings_sync_progress_tip_verifying_cloud_write',
  'settings_sync_progress_tip_updating_record'
];

const DOWNLOAD_TIP_RESOURCES: string[] = [
  'settings_sync_progress_tip_connecting_cloud',
  'settings_sync_progress_tip_reading_cloud',
  'settings_sync_progress_tip_checking_integrity',
  'settings_sync_progress_tip_preparing_local_write',
  'settings_sync_progress_tip_updating_local_bookmarks'
];

const IMPORT_TIP_RESOURCES: string[] = [
  'settings_sync_progress_tip_reading_file',
  'settings_sync_progress_tip_checking_bookmarks',
  'settings_sync_progress_tip_preparing_restore',
  'settings_sync_progress_tip_writing_local_bookmarks',
  'settings_sync_progress_tip_finishing_import'
];

const EXPORT_TIP_RESOURCES: string[] = [
  'settings_sync_progress_tip_collecting_local',
  'settings_sync_progress_tip_generating_file',
  'settings_sync_progress_tip_writing_file',
  'settings_sync_progress_tip_confirming_saved',
  'settings_sync_progress_tip_finishing_export'
];

const GENERIC_TIP_RESOURCES: string[] = [
  'settings_sync_progress_tip_reading_state',
  'settings_sync_progress_tip_collecting_info',
  'settings_sync_progress_tip_updating_display'
];

/**
 * The progress dialog names its operation through a resource, so the tips branch on the
 * operation identity rather than matching Chinese text: `isAppString` compares the resource
 * the caller passed, and that identity survives translation.
 *
 * Tips are held as `ResourceStr` and resolved by the renderer, so a language change reaches
 * them like any other string. The tip lists are resource names rather than `$r` values
 * because an ArkTS module cannot build a `Resource` in a top-level constant.
 */
export class SyncOperationProgressViewModel {
  resolveSuccessProgress(current: number, targetProgress: number): number {
    return Math.max(current, Math.min(100, Math.round(targetProgress)));
  }

  resolveVisualProgress(currentProgress: number, targetProgress: number, elapsedMs: number): number {
    const current = this.clampProgress(currentProgress);
    const visualCap = Math.min(this.resolveElapsedProgress(elapsedMs), this.clampProgress(targetProgress));
    const target = Math.max(current, Math.min(92, visualCap));
    if (current >= target) {
      return current;
    }
    return target;
  }

  resolveTimeoutMessage(title: ResourceStr): ResourceStr {
    if (this.isOperation(title, 'settings_sync_progress_title_upload')) {
      return this.stringResource('settings_sync_progress_timeout_upload');
    }
    if (this.isOperation(title, 'settings_sync_progress_title_download')) {
      return this.stringResource('settings_sync_progress_timeout_download');
    }
    if (this.isOperation(title, 'settings_sync_progress_title_import') ||
      this.isOperation(title, 'settings_sync_progress_title_export')) {
      return this.stringResource('settings_sync_progress_timeout_bookmark_file');
    }
    return this.stringResource('settings_sync_progress_timeout_sync');
  }

  buildInitialTips(title: ResourceStr, firstTip: ResourceStr): SyncOperationProgressTipsState {
    const tips: ResourceStr[] = this.buildTips(title, firstTip);
    return {
      tips: tips,
      index: 0,
      activeTip: tips.length > 0 ? tips[0] : firstTip
    };
  }

  appendTip(state: SyncOperationProgressTipsState, tip: ResourceStr): SyncOperationProgressTipsState {
    const tips: ResourceStr[] = state.tips.slice();
    this.pushUniqueTip(tips, tip);
    return {
      tips: tips,
      index: state.index,
      activeTip: state.activeTip
    };
  }

  advanceTip(state: SyncOperationProgressTipsState): SyncOperationProgressTipsState {
    if (state.tips.length === 0) {
      return state;
    }
    const index: number = (state.index + 1) % state.tips.length;
    return {
      tips: state.tips,
      index: index,
      activeTip: state.tips[index]
    };
  }

  private buildTips(title: ResourceStr, firstTip: ResourceStr): ResourceStr[] {
    const tips: ResourceStr[] = [];
    this.pushUniqueTip(tips, firstTip);
    if (this.isOperation(title, 'settings_sync_progress_title_sync')) {
      return this.appendResourceTips(tips, SYNC_TIP_RESOURCES);
    }
    if (this.isOperation(title, 'settings_sync_progress_title_upload')) {
      return this.appendResourceTips(tips, UPLOAD_TIP_RESOURCES);
    }
    if (this.isOperation(title, 'settings_sync_progress_title_download')) {
      return this.appendResourceTips(tips, DOWNLOAD_TIP_RESOURCES);
    }
    if (this.isOperation(title, 'settings_sync_progress_title_import')) {
      return this.appendResourceTips(tips, IMPORT_TIP_RESOURCES);
    }
    if (this.isOperation(title, 'settings_sync_progress_title_export')) {
      return this.appendResourceTips(tips, EXPORT_TIP_RESOURCES);
    }
    return this.appendResourceTips(tips, GENERIC_TIP_RESOURCES);
  }

  private appendResourceTips(tips: ResourceStr[], names: string[]): ResourceStr[] {
    for (let index = 0; index < names.length; index += 1) {
      this.pushUniqueTip(tips, this.stringResource(names[index]));
    }
    return tips;
  }

  private isOperation(title: ResourceStr, name: string): boolean {
    return typeof title !== 'string' && isAppString(title, this.stringResource(name));
  }

  /** The resource for a progress string, named explicitly so the compiler can check it. */
  private stringResource(name: string): Resource {
    switch (name) {
      case 'settings_sync_progress_title_sync':
        return $r('app.string.settings_sync_progress_title_sync');
      case 'settings_sync_progress_title_upload':
        return $r('app.string.settings_sync_progress_title_upload');
      case 'settings_sync_progress_title_download':
        return $r('app.string.settings_sync_progress_title_download');
      case 'settings_sync_progress_title_import':
        return $r('app.string.settings_sync_progress_title_import');
      case 'settings_sync_progress_title_export':
        return $r('app.string.settings_sync_progress_title_export');
      case 'settings_sync_progress_timeout_upload':
        return $r('app.string.settings_sync_progress_timeout_upload');
      case 'settings_sync_progress_timeout_download':
        return $r('app.string.settings_sync_progress_timeout_download');
      case 'settings_sync_progress_timeout_bookmark_file':
        return $r('app.string.settings_sync_progress_timeout_bookmark_file');
      case 'settings_sync_progress_timeout_sync':
        return $r('app.string.settings_sync_progress_timeout_sync');
      case 'settings_sync_progress_tip_collecting_local':
        return $r('app.string.settings_sync_progress_tip_collecting_local');
      case 'settings_sync_progress_tip_checking_cloud':
        return $r('app.string.settings_sync_progress_tip_checking_cloud');
      case 'settings_sync_progress_tip_comparing':
        return $r('app.string.settings_sync_progress_tip_comparing');
      case 'settings_sync_progress_tip_protecting':
        return $r('app.string.settings_sync_progress_tip_protecting');
      case 'settings_sync_progress_tip_applying':
        return $r('app.string.settings_sync_progress_tip_applying');
      case 'settings_sync_progress_tip_writing_record':
        return $r('app.string.settings_sync_progress_tip_writing_record');
      case 'settings_sync_progress_tip_wrapping_up':
        return $r('app.string.settings_sync_progress_tip_wrapping_up');
      case 'settings_sync_progress_tip_collecting_content':
        return $r('app.string.settings_sync_progress_tip_collecting_content');
      case 'settings_sync_progress_tip_preparing_cloud':
        return $r('app.string.settings_sync_progress_tip_preparing_cloud');
      case 'settings_sync_progress_tip_uploading_bookmarks':
        return $r('app.string.settings_sync_progress_tip_uploading_bookmarks');
      case 'settings_sync_progress_tip_verifying_cloud_write':
        return $r('app.string.settings_sync_progress_tip_verifying_cloud_write');
      case 'settings_sync_progress_tip_updating_record':
        return $r('app.string.settings_sync_progress_tip_updating_record');
      case 'settings_sync_progress_tip_connecting_cloud':
        return $r('app.string.settings_sync_progress_tip_connecting_cloud');
      case 'settings_sync_progress_tip_reading_cloud':
        return $r('app.string.settings_sync_progress_tip_reading_cloud');
      case 'settings_sync_progress_tip_checking_integrity':
        return $r('app.string.settings_sync_progress_tip_checking_integrity');
      case 'settings_sync_progress_tip_preparing_local_write':
        return $r('app.string.settings_sync_progress_tip_preparing_local_write');
      case 'settings_sync_progress_tip_updating_local_bookmarks':
        return $r('app.string.settings_sync_progress_tip_updating_local_bookmarks');
      case 'settings_sync_progress_tip_reading_file':
        return $r('app.string.settings_sync_progress_tip_reading_file');
      case 'settings_sync_progress_tip_checking_bookmarks':
        return $r('app.string.settings_sync_progress_tip_checking_bookmarks');
      case 'settings_sync_progress_tip_preparing_restore':
        return $r('app.string.settings_sync_progress_tip_preparing_restore');
      case 'settings_sync_progress_tip_writing_local_bookmarks':
        return $r('app.string.settings_sync_progress_tip_writing_local_bookmarks');
      case 'settings_sync_progress_tip_finishing_import':
        return $r('app.string.settings_sync_progress_tip_finishing_import');
      case 'settings_sync_progress_tip_generating_file':
        return $r('app.string.settings_sync_progress_tip_generating_file');
      case 'settings_sync_progress_tip_writing_file':
        return $r('app.string.settings_sync_progress_tip_writing_file');
      case 'settings_sync_progress_tip_confirming_saved':
        return $r('app.string.settings_sync_progress_tip_confirming_saved');
      case 'settings_sync_progress_tip_finishing_export':
        return $r('app.string.settings_sync_progress_tip_finishing_export');
      case 'settings_sync_progress_tip_reading_state':
        return $r('app.string.settings_sync_progress_tip_reading_state');
      case 'settings_sync_progress_tip_collecting_info':
        return $r('app.string.settings_sync_progress_tip_collecting_info');
      case 'settings_sync_progress_tip_updating_display':
        return $r('app.string.settings_sync_progress_tip_updating_display');
      default:
        return $r('app.string.settings_sync_progress_timeout_sync');
    }
  }

  private pushUniqueTip(tips: ResourceStr[], tip: ResourceStr): void {
    if (!hasAppResourceText(tip)) {
      return;
    }
    for (let index = 0; index < tips.length; index += 1) {
      const existing: ResourceStr = tips[index];
      if (typeof existing !== 'string' && typeof tip !== 'string' && isAppString(existing, tip)) {
        return;
      }
      if (typeof existing === 'string' && existing === tip) {
        return;
      }
    }
    tips.push(tip);
  }

  private clampProgress(progress: number): number {
    return Math.max(0, Math.min(100, Math.round(progress)));
  }

  private resolveElapsedProgress(elapsedMs: number): number {
    const elapsed = Math.max(0, elapsedMs);
    const progress = 92 * (1 - Math.exp(0 - elapsed / 8500));
    return Math.max(0, Math.min(92, Math.floor(progress)));
  }
}
