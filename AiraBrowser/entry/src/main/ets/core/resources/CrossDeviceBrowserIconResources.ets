import { CrossDeviceBrowserIconKind } from '../sync/CrossDeviceBrowserIcon';

export class CrossDeviceBrowserIconResources {
  static icon(kind: CrossDeviceBrowserIconKind): Resource {
    if (kind === 'chrome') {
      return $r('app.media.sync_browser_chrome');
    }
    if (kind === 'edge') {
      return $r('app.media.sync_browser_edge');
    }
    if (kind === 'firefox') {
      return $r('app.media.sync_browser_firefox');
    }
    if (kind === 'floorp') {
      return $r('app.media.sync_browser_floorp');
    }
    if (kind === 'librewolf') {
      return $r('app.media.sync_browser_librewolf');
    }
    if (kind === 'waterfox') {
      return $r('app.media.sync_browser_waterfox');
    }
    if (kind === 'brave') {
      return $r('app.media.sync_browser_brave');
    }
    if (kind === 'opera') {
      return $r('app.media.sync_browser_opera');
    }
    if (kind === 'vivaldi') {
      return $r('app.media.sync_browser_vivaldi');
    }
    if (kind === 'zen') {
      return $r('app.media.sync_browser_zen');
    }
    return $r('app.media.sync_browser_chromium');
  }
}
