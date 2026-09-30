export type HistoryVisitContextActionId =
  'multi_select' |
  'add_to_home' |
  'remove_from_home' |
  'add_bookmark' |
  'remove_bookmark' |
  'share' |
  'copy_link' |
  'details' |
  'open' |
  'open_new_tab' |
  'open_background' |
  'delete_site' |
  'delete';

export interface HistoryVisitContextAction {
  id: HistoryVisitContextActionId;
  label: ResourceStr;
}

export function historyVisitContextAction(id: HistoryVisitContextActionId): HistoryVisitContextAction {
  return { id: id, label: historyVisitContextActionLabel(id) };
}

export function historyVisitContextActionLabel(id: HistoryVisitContextActionId): ResourceStr {
  if (id === 'multi_select') {
    return $r('app.string.ui_multi_select');
  }
  if (id === 'add_to_home') {
    return $r('app.string.history_add_home');
  }
  if (id === 'remove_from_home') {
    return $r('app.string.history_remove_home');
  }
  if (id === 'add_bookmark') {
    return $r('app.string.history_add_bookmark');
  }
  if (id === 'remove_bookmark') {
    return $r('app.string.history_remove_bookmark');
  }
  if (id === 'share') {
    return $r('app.string.ui_share');
  }
  if (id === 'copy_link') {
    return $r('app.string.ui_copy_link');
  }
  if (id === 'details') {
    return $r('app.string.ui_details');
  }
  if (id === 'open') {
    return $r('app.string.ui_open');
  }
  if (id === 'open_new_tab') {
    return $r('app.string.history_open_new_tab_short');
  }
  if (id === 'open_background') {
    return $r('app.string.history_open_background');
  }
  if (id === 'delete_site') {
    return $r('app.string.history_delete_site_short');
  }
  return $r('app.string.settings_delete');
}
