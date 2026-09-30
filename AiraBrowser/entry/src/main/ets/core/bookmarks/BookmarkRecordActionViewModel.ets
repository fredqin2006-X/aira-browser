import {
  BookmarkNode,
  BookmarkStorageScope
} from '../../common/models/BrowserModels';
import { isBookmarkRootNodeId } from '../../data/repositories/BookmarkRepositoryCore';

export interface BookmarkRecordActionView {
  id: BookmarkRecordActionId;
  title: ResourceStr;
  role: 'normal' | 'destructive';
}

export type BookmarkRecordActionId =
  'enter_edit_mode' |
  'add_to_home' |
  'remove_from_home' |
  'share' |
  'open_current_tab' |
  'open_new_tab' |
  'open_background_tab' |
  'edit_bookmark' |
  'edit_folder' |
  'move' |
  'delete';

export interface BookmarkRecordActionContext {
  scope: BookmarkStorageScope;
  canSelect: boolean;
  isAddedToHome: boolean;
}

export class BookmarkRecordActionViewModel {
  buildActions(node: BookmarkNode, context: BookmarkRecordActionContext): BookmarkRecordActionView[] {
    if (node.type === 'folder') {
      if (isBookmarkRootNodeId(node.id)) {
        return [];
      }
      const actions: BookmarkRecordActionView[] = [
        { id: 'edit_folder', title: $r('app.string.bookmark_edit_folder'), role: 'normal' },
        { id: 'move', title: $r('app.string.ui_move'), role: 'normal' }
      ];
      if (context.canSelect) {
        actions.unshift({ id: 'enter_edit_mode', title: $r('app.string.ui_multi_select'), role: 'normal' });
      }
      actions.push({ id: 'delete', title: $r('app.string.settings_delete'), role: 'destructive' });
      return actions;
    }

    const actions: BookmarkRecordActionView[] = [
      { id: 'share', title: $r('app.string.ui_share'), role: 'normal' },
      { id: 'open_current_tab', title: $r('app.string.ui_open'), role: 'normal' },
      { id: 'open_new_tab', title: $r('app.string.history_open_new_tab_short'), role: 'normal' },
      { id: 'open_background_tab', title: $r('app.string.history_open_background'), role: 'normal' },
      { id: 'edit_bookmark', title: $r('app.string.bookmark_edit_bookmark'), role: 'normal' },
      { id: 'move', title: $r('app.string.ui_move'), role: 'normal' },
      { id: 'delete', title: $r('app.string.settings_delete'), role: 'destructive' }
    ];
    if (context.scope === 'regular') {
      actions.unshift({
        id: context.isAddedToHome ? 'remove_from_home' : 'add_to_home',
        title: context.isAddedToHome ? $r('app.string.history_remove_home') : $r('app.string.history_add_home'),
        role: 'normal'
      });
    }
    if (context.canSelect) {
      actions.unshift({ id: 'enter_edit_mode', title: $r('app.string.ui_multi_select'), role: 'normal' });
    }
    return actions;
  }
}
