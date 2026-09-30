import {
  OfflinePageListItem,
  OfflinePageListState,
  OfflinePageOpenStatus,
  OfflinePageRecord
} from '../../common/models/OfflinePageModels';
import { resolveAppResourceText } from '../resources/AppResourceText';

export class OfflinePageListViewModel {
  buildLoadingState(): OfflinePageListState {
    return {
      loading: true,
      empty: false,
      items: [],
      message: $r('app.string.offline_list_loading')
    };
  }

  buildState(records: OfflinePageRecord[]): OfflinePageListState {
    const items = records.map((record: OfflinePageRecord): OfflinePageListItem => this.buildItem(record));
    return {
      loading: false,
      empty: items.length === 0,
      items: items,
      message: items.length === 0 ? $r('app.string.offline_list_empty') : ''
    };
  }

  buildFailureState(message: ResourceStr): OfflinePageListState {
    return {
      loading: false,
      empty: true,
      items: [],
      message: message
    };
  }

  private buildItem(record: OfflinePageRecord): OfflinePageListItem {
    const title = record.title.trim().length > 0
      ? record.title.trim()
      : resolveAppResourceText($r('app.string.offline_unnamed_page'));
    const siteName = record.siteName.trim().length > 0
      ? record.siteName.trim()
      : (record.host.trim().length > 0
        ? record.host.trim()
        : resolveAppResourceText($r('app.string.offline_unknown_source')));
    return {
      id: record.id,
      title: title,
      siteName: siteName,
      host: record.host,
      savedAtText: this.formatSavedAt(record.savedAt),
      sizeText: this.formatBytes(record.totalBytes),
      previewImageUri: record.previewImageUri,
      faviconUri: record.faviconUri,
      originalUrl: record.originalUrl,
      canOpen: record.openStatus === 'available',
      openStatusText: this.resolveOpenStatusText(record.openStatus)
    };
  }

  private resolveOpenStatusText(status: OfflinePageOpenStatus): ResourceStr {
    if (status === 'available') {
      return $r('app.string.offline_open_status_available');
    }
    if (status === 'missing_snapshot') {
      return $r('app.string.offline_open_status_missing_snapshot');
    }
    if (status === 'missing_assets') {
      return $r('app.string.offline_open_status_missing_assets');
    }
    return $r('app.string.offline_open_status_corrupted');
  }

  private formatSavedAt(value: number): string {
    if (value <= 0) {
      return '';
    }
    const date = new Date(value);
    return `${date.getFullYear()}-${this.pad2(date.getMonth() + 1)}-${this.pad2(date.getDate())} ` +
      `${this.pad2(date.getHours())}:${this.pad2(date.getMinutes())}`;
  }

  private formatBytes(value: number): string {
    const bytes = Math.max(0, Math.floor(value));
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    const kb = bytes / 1024;
    if (kb < 1024) {
      return `${this.formatOneDecimal(kb)} KB`;
    }
    const mb = kb / 1024;
    return `${this.formatOneDecimal(mb)} MB`;
  }

  private formatOneDecimal(value: number): string {
    return (Math.round(value * 10) / 10).toString();
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : value.toString();
  }
}
