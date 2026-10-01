import { DownloadV2TaskEntity } from '../../domain/downloadv2/DownloadV2TaskEntity';
import { resolveAppResourceText } from '../resources/AppResourceText';

export class DownloadToolbarIndicatorState {
  visible: boolean;
  progressValue: number;
  progressKnown: boolean;
  activeTaskCount: number;

  constructor(
    visible: boolean,
    progressValue: number,
    progressKnown: boolean,
    activeTaskCount: number
  ) {
    this.visible = visible;
    this.progressValue = progressValue;
    this.progressKnown = progressKnown;
    this.activeTaskCount = activeTaskCount;
  }

  accessibilityText(): string {
    if (!this.visible) {
      return '';
    }
    if (!this.progressKnown) {
      return this.activeTaskCount > 1
        ? resolveAppResourceText($r('app.string.download_indicator_many_unknown', this.activeTaskCount))
        : resolveAppResourceText($r('app.string.download_indicator_unknown'));
    }
    return this.activeTaskCount > 1
      ? resolveAppResourceText($r('app.string.download_indicator_many_percent', this.activeTaskCount, this.progressValue))
      : resolveAppResourceText($r('app.string.download_indicator_percent', this.progressValue));
  }
}

export function createHiddenDownloadToolbarIndicatorState(): DownloadToolbarIndicatorState {
  return new DownloadToolbarIndicatorState(false, 0, false, 0);
}

/**
 * Desktop toolbar download button. It stays hidden until this process sees a
 * download, then remains until the browser process itself is gone. Nothing is
 * written down, so the next launch starts hidden again.
 */
const DESKTOP_DOWNLOAD_ENTRY_SESSION_STARTED_AT: number = Date.now();
let desktopDownloadEntryPinned: boolean = false;

export function hasDesktopDownloadEntryActivity(
  tasks: DownloadV2TaskEntity[],
  sessionStartedAt: number
): boolean {
  for (let index = 0; index < tasks.length; index++) {
    const task = tasks[index];
    if (task === undefined) {
      continue;
    }
    if (task.status === 'running') {
      return true;
    }
    const createdAt = task.timing.createdAt;
    if (Number.isFinite(createdAt) && createdAt >= sessionStartedAt) {
      return true;
    }
  }
  return false;
}

export function isDesktopDownloadEntryVisible(tasks: DownloadV2TaskEntity[]): boolean {
  if (desktopDownloadEntryPinned) {
    return true;
  }
  if (hasDesktopDownloadEntryActivity(tasks, DESKTOP_DOWNLOAD_ENTRY_SESSION_STARTED_AT)) {
    desktopDownloadEntryPinned = true;
    return true;
  }
  return false;
}

export class DownloadToolbarIndicatorViewModel {
  buildState(tasks: DownloadV2TaskEntity[]): DownloadToolbarIndicatorState {
    const activeTasks = tasks.filter((task: DownloadV2TaskEntity): boolean => task.status === 'running');
    if (activeTasks.length === 0) {
      return createHiddenDownloadToolbarIndicatorState();
    }

    let knownTotalBytes = 0;
    let knownReceivedBytes = 0;
    activeTasks.forEach((task: DownloadV2TaskEntity): void => {
      const totalBytes = this.normalizeByteCount(task.progress.totalBytes);
      if (totalBytes <= 0) {
        return;
      }
      knownTotalBytes += totalBytes;
      knownReceivedBytes += Math.min(totalBytes, this.normalizeByteCount(task.progress.receivedBytes));
    });

    const progressKnown = knownTotalBytes > 0;
    const progressValue = progressKnown ?
      Math.min(99, Math.max(0, Math.floor(knownReceivedBytes * 100 / knownTotalBytes))) : 0;
    return new DownloadToolbarIndicatorState(true, progressValue, progressKnown, activeTasks.length);
  }

  private normalizeByteCount(value: number): number {
    if (!Number.isFinite(value) || value <= 0) {
      return 0;
    }
    return value;
  }
}
