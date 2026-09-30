import {
  HISTORY_TAKEOVER_OPEN_MESSAGE,
  detectHistoryBrowserKind,
  detectHistoryPlatform,
  isExtensionHistoryCommandShortcut,
  isHistoryTakeoverShortcut,
} from './historyTakeoverPolicy';

const browser = detectHistoryBrowserKind(globalThis.navigator?.userAgent || '');
const platform = detectHistoryPlatform(
  globalThis.navigator?.platform || '',
  globalThis.navigator?.userAgent || '',
);

globalThis.addEventListener('keydown', (event) => {
  if (event.repeat || globalThis.window !== globalThis.window.top) return;
  // Vivaldi cannot register an extension command shortcut. Catch the same combo
  // while a page is focused, without waiting to identify the browser.
  const nativeShortcut = isHistoryTakeoverShortcut(browser, platform, event);
  const extensionShortcut = isExtensionHistoryCommandShortcut(platform, event);
  if (!nativeShortcut && !extensionShortcut) return;
  event.preventDefault();
  event.stopPropagation();
  globalThis.chrome?.runtime?.sendMessage({ type: HISTORY_TAKEOVER_OPEN_MESSAGE });
}, true);
