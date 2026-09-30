import { HistoryViewMode } from './HistoryViewModel';

export type HistorySelectionMoreActionId =
  'copy_links' | 'add_bookmarks' | 'remove_bookmarks' | 'share_links' | 'delete_selected_sites';

export interface HistorySelectionMoreMenuItem {
  id: HistorySelectionMoreActionId;
  title: ResourceStr;
}

export interface HistorySelectionMoreMenuPlan {
  emptySelectionMessage: ResourceStr;
  selectedCount: number;
  items: HistorySelectionMoreMenuItem[];
}

export const HISTORY_SELECTION_MORE_EMPTY_MESSAGE: ResourceStr = $r('app.string.history_select_first');

export function planHistorySelectionMoreMenu(
  viewMode: HistoryViewMode,
  selectedCount: number,
  includeRemoveBookmarks: boolean = false
): HistorySelectionMoreMenuPlan {
  const items: HistorySelectionMoreMenuItem[] = [];
  if (viewMode === 'sites') {
    items.push({
      id: 'delete_selected_sites',
      title: $r('app.string.history_delete_selected_sites')
    });
  } else {
    items.push({
      id: 'copy_links',
      title: $r('app.string.history_batch_copy')
    });
    items.push({
      id: 'add_bookmarks',
      title: $r('app.string.history_batch_add_bookmarks')
    });
    if (includeRemoveBookmarks) {
      items.push({
        id: 'remove_bookmarks',
        title: $r('app.string.history_batch_remove_bookmarks')
      });
    }
    items.push({
      id: 'share_links',
      title: $r('app.string.history_batch_share')
    });
  }
  return {
    emptySelectionMessage: HISTORY_SELECTION_MORE_EMPTY_MESSAGE,
    selectedCount: selectedCount,
    items: items
  };
}
