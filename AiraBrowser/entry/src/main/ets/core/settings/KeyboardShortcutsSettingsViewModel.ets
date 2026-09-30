import { resolveBrowserDesktopMenuShortcutLabel } from '../browser/BrowserDesktopMenuShortcutCatalog';

export interface KeyboardShortcutRowState {
  id: string;
  title: ResourceStr;
  shortcut: ResourceStr;
}

export interface KeyboardShortcutGroupState {
  id: string;
  title: ResourceStr;
  rows: KeyboardShortcutRowState[];
}

export class KeyboardShortcutsSettingsViewModel {
  buildGroups(): KeyboardShortcutGroupState[] {
    return [
      {
        id: 'tabs',
        title: $r('app.string.settings_shortcuts_tabs'),
        rows: [
          this.row('new_tab', $r('app.string.settings_shortcuts_new_tab'), 'Ctrl+T'),
          this.row('close_tab', $r('app.string.settings_shortcuts_close_tab'), 'Ctrl+W'),
          this.row('restore_tab', $r('app.string.settings_shortcuts_restore_tab'), 'Ctrl+Shift+T'),
          this.row('next_tab', $r('app.string.settings_shortcuts_next_tab'), 'Ctrl+Tab'),
          this.row('previous_tab', $r('app.string.settings_shortcuts_previous_tab'), 'Ctrl+Shift+Tab'),
          this.row('numbered_tabs', $r('app.string.settings_shortcuts_numbered_tabs'), 'Ctrl+1~9'),
          this.row('tabs_overview', $r('app.string.settings_shortcuts_tabs_overview'), 'Ctrl+Shift+A'),
          this.row('tabs_overview_keyboard', $r('app.string.settings_shortcuts_tabs_overview_keyboard'), $r('app.string.settings_shortcuts_arrow_enter'))
        ]
      },
      {
        id: 'browse',
        title: $r('app.string.settings_shortcuts_browse'),
        rows: [
          this.row('address_alt', $r('app.string.settings_shortcuts_address'), 'Alt+D'),
          this.row('address_ctrl', $r('app.string.settings_shortcuts_address'), 'Ctrl+L'),
          this.row('find', $r('app.string.settings_shortcuts_find'), 'Ctrl+F'),
          this.row('reload_ctrl', $r('app.string.settings_shortcuts_reload'), 'Ctrl+R'),
          this.row('reload_f5', $r('app.string.settings_shortcuts_reload'), 'F5'),
          this.row('fullscreen', $r('app.string.settings_shortcuts_fullscreen'), 'F11'),
          this.row('escape', $r('app.string.settings_shortcuts_escape'), 'Esc')
        ]
      },
      {
        id: 'navigation',
        title: $r('app.string.settings_shortcuts_navigation'),
        rows: [
          this.row('back', $r('app.string.settings_shortcuts_back'), 'Alt+Left'),
          this.row('forward', $r('app.string.settings_shortcuts_forward'), 'Alt+Right')
        ]
      },
      {
        id: 'management',
        title: $r('app.string.settings_shortcuts_management'),
        rows: [
          this.row('history', $r('app.string.settings_shortcuts_history'), resolveBrowserDesktopMenuShortcutLabel('history')),
          this.row('downloads', $r('app.string.settings_shortcuts_downloads'), resolveBrowserDesktopMenuShortcutLabel('downloads')),
          this.row('bookmarks_manager', $r('app.string.settings_shortcuts_bookmarks'), resolveBrowserDesktopMenuShortcutLabel('openBookmarks')),
          this.row('bookmark_bar', $r('app.string.settings_shortcuts_bookmark_bar'), resolveBrowserDesktopMenuShortcutLabel('bar')),
          this.row('bookmark', $r('app.string.settings_shortcuts_bookmark'), resolveBrowserDesktopMenuShortcutLabel('bookmark')),
          this.row('save_offline', $r('app.string.settings_shortcuts_save_offline'), resolveBrowserDesktopMenuShortcutLabel('offline')),
          this.row('settings', $r('app.string.settings_shortcuts_settings'), resolveBrowserDesktopMenuShortcutLabel('settings')),
          this.row('private_mode', $r('app.string.settings_shortcuts_private'), resolveBrowserDesktopMenuShortcutLabel('newPrivateTab')),
          this.row('print', $r('app.string.settings_shortcuts_print'), resolveBrowserDesktopMenuShortcutLabel('print')),
          this.row('inspect', $r('app.string.settings_shortcuts_inspect'), resolveBrowserDesktopMenuShortcutLabel('elementInspection'))
        ]
      }
    ];
  }

  private row(id: string, title: ResourceStr, shortcut: ResourceStr): KeyboardShortcutRowState {
    return {
      id: id,
      title: title,
      shortcut: shortcut
    };
  }
}
