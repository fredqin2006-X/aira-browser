import { DownloadV2Status } from '../../domain/downloadv2/DownloadV2Types';
import { resolveAppResourceText } from '../resources/AppResourceText';

export interface DownloadSelectionCandidate {
  guid: string;
  status: DownloadV2Status;
}

export function downloadSelectionEmptyToast(): string {
  return resolveAppResourceText($r('app.string.download_selection_empty'));
}

export function buildDownloadSelectionTitle(selectedCount: number): string {
  return resolveAppResourceText($r('app.string.download_selection_title', selectedCount));
}

/**
 * Only completed downloads can be batched. Active tasks keep their per-row controls
 * (pause/resume/cancel) because a batch action must not race the running transfer.
 */
export function canSelectDownloadTask(status: DownloadV2Status): boolean {
  return status === 'completed';
}

export function collectSelectableDownloadGuids(candidates: DownloadSelectionCandidate[]): string[] {
  const guids: string[] = [];
  candidates.forEach((candidate: DownloadSelectionCandidate) => {
    if (canSelectDownloadTask(candidate.status)) {
      guids.push(candidate.guid);
    }
  });
  return guids;
}

export function pruneDownloadSelection(selectedGuids: string[], selectableGuids: string[]): string[] {
  return selectedGuids.filter((guid: string) => selectableGuids.indexOf(guid) >= 0);
}
