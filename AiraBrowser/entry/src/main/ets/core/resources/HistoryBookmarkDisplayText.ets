import {
  BOOKMARK_OTHER_ROOT_ID,
  BOOKMARK_TOOLBAR_ROOT_ID,
  PRIVATE_BOOKMARK_OTHER_ROOT_ID,
  PRIVATE_BOOKMARK_TOOLBAR_ROOT_ID
} from '../../data/repositories/BookmarkRepositoryCore';

/**
 * System bookmark roots keep their Chinese titles in storage so sync and
 * imports stay stable. Only the display surface localizes them.
 */
export function resolveBookmarkNodeDisplayTitle(nodeId: string, storedTitle: string): ResourceStr {
  if (nodeId === BOOKMARK_TOOLBAR_ROOT_ID) {
    return $r('app.string.bookmark_root_toolbar');
  }
  if (nodeId === BOOKMARK_OTHER_ROOT_ID) {
    return $r('app.string.bookmark_root_other');
  }
  if (nodeId === PRIVATE_BOOKMARK_TOOLBAR_ROOT_ID) {
    return $r('app.string.bookmark_root_private_toolbar');
  }
  if (nodeId === PRIVATE_BOOKMARK_OTHER_ROOT_ID) {
    return $r('app.string.bookmark_root_private_other');
  }
  return storedTitle;
}

/**
 * Day buckets are stored as `今天` / `昨天` or `YYYY-MM-DD` and also used as
 * group keys. Localize only at display.
 */
export function localizeHistoryDayLabel(label: string): ResourceStr {
  if (label === '今天') {
    return $r('app.string.history_today');
  }
  if (label === '昨天') {
    return $r('app.string.history_yesterday');
  }
  return label;
}

/**
 * Empty hosts are grouped under the stored sentinel `未知站点`. That value is
 * also a lookup key, so callers must keep the stored host and localize here.
 */
export function localizeHistoryHost(host: string): ResourceStr {
  if (host.length === 0 || host === '未知站点') {
    return $r('app.string.history_unknown_site');
  }
  return host;
}
