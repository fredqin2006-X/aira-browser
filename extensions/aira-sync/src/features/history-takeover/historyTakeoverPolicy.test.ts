import { describe, expect, test } from 'vitest';
import {
  detectHistoryBrowserKind,
  detectHistoryPlatform,
  readInstalledHistoryBrowser,
  resolveHistoryBrowserKind,
  formatAssignedHistoryShortcut,
  geckoHistoryCommandShortcut,
  historyShortcutLabel,
  isExtensionHistoryCommandShortcut,
  isHistoryTakeoverShortcut,
  isNativeHistoryPageUrl,
  shouldAssignExtensionHistoryShortcut,
  tabHasVivaldiMetadata,
  vivaldiFromExtensionClientHints,
  vivaldiProbeRejectionMeansInstalled,
} from './historyTakeoverPolicy';

const down = {
  ctrlKey: false,
  metaKey: false,
  altKey: false,
  shiftKey: false,
};

describe('history takeover browser detection', () => {
  test('keeps Chromium forks distinct from generic Chrome', () => {
    expect(detectHistoryBrowserKind('Mozilla/5.0 Firefox/135.0 Zen/1.12.1')).toBe('zen');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Firefox/145.0 Waterfox/6.6.5')).toBe('waterfox');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Firefox/128.0 LibreWolf/128.0')).toBe('librewolf');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Firefox/128.0 Floorp/11.0')).toBe('floorp');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Firefox/128.0')).toBe('firefox');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Chrome/128.0 OPR/114.0')).toBe('opera');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Chrome/128.0 Vivaldi/6.8')).toBe('vivaldi');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Chrome/128.0 Edg/128.0')).toBe('edge');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Chrome/128.0')).toBe('chromium');
    expect(detectHistoryPlatform('MacIntel')).toBe('mac');
    expect(detectHistoryPlatform('Win32')).toBe('other');
  });

  test('separates Brave from Chrome when the browser exposes its own signal', () => {
    const chromeUserAgent = 'Mozilla/5.0 Chrome/128.0 Safari/537.36';
    expect(resolveHistoryBrowserKind({
      userAgent: chromeUserAgent,
      brands: ['Chromium', 'Google Chrome'],
      isBrave: false,
    })).toBe('chrome');
    expect(resolveHistoryBrowserKind({
      userAgent: chromeUserAgent,
      brands: ['Chromium', 'Brave'],
      isBrave: true,
    })).toBe('brave');
    expect(resolveHistoryBrowserKind({
      userAgent: chromeUserAgent,
      brands: ['Chromium'],
      isBrave: true,
    })).toBe('brave');
    expect(resolveHistoryBrowserKind({
      userAgent: chromeUserAgent,
      isBrave: false,
    })).toBe('chrome');
    expect(resolveHistoryBrowserKind({
      userAgent: 'Mozilla/5.0 Chrome/128.0 Edg/128.0',
      brands: ['Chromium', 'Microsoft Edge'],
      isBrave: false,
    })).toBe('edge');
    expect(resolveHistoryBrowserKind({
      userAgent: chromeUserAgent,
      brands: ['Chromium', 'Google Chrome'],
      isVivaldi: true,
    })).toBe('vivaldi');
  });

  test('recognizes Vivaldi when it masks itself as Chrome', () => {
    expect(tabHasVivaldiMetadata({ vivExtData: '{}' })).toBe(true);
    expect(tabHasVivaldiMetadata({ id: 1 })).toBe(false);
    expect(vivaldiProbeRejectionMeansInstalled('No tab with id: -1.')).toBe(true);
    expect(vivaldiProbeRejectionMeansInstalled("Unexpected property: 'vivExtData'.")).toBe(false);
    expect(vivaldiProbeRejectionMeansInstalled('')).toBe(false);
    expect(vivaldiFromExtensionClientHints({
      protocol: 'chrome-extension:',
      userAgent: 'Mozilla/5.0 Chrome/128.0 Safari/537.36',
      brands: [],
      platform: '',
    })).toBe(true);
    expect(vivaldiFromExtensionClientHints({
      protocol: 'https:',
      userAgent: 'Mozilla/5.0 Chrome/128.0 Safari/537.36',
      brands: [],
      platform: '',
    })).toBe(false);
    expect(vivaldiFromExtensionClientHints({
      protocol: 'chrome-extension:',
      userAgent: 'Mozilla/5.0 Chrome/128.0 Safari/537.36',
      brands: ['Google Chrome'],
      platform: 'macOS',
    })).toBe(false);
    expect(shouldAssignExtensionHistoryShortcut('vivaldi', '')).toBe(true);
    expect(shouldAssignExtensionHistoryShortcut('vivaldi', 'Command+Y')).toBe(true);
    expect(shouldAssignExtensionHistoryShortcut('vivaldi', 'Command+Shift+Y')).toBe(false);
    expect(shouldAssignExtensionHistoryShortcut('chrome', '')).toBe(false);
  });

  test('reads Brave from the browser object instead of the Chrome-like user agent', async () => {
    const detected = await readInstalledHistoryBrowser({
      userAgent: 'Mozilla/5.0 Chrome/128.0 Safari/537.36',
      brave: { isBrave: async () => true },
    });
    expect(detected).toBe('brave');
  });

  test('reads Zen from the Gecko browser name when the user agent still says Firefox', async () => {
    const runtime = {
      getBrowserInfo: async () => ({ name: 'Zen', vendor: 'Zen Team' }),
    };
    Object.assign(globalThis, { browser: { runtime } });
    try {
      const detected = await readInstalledHistoryBrowser({
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:135.0) Gecko/20100101 Firefox/135.0',
      });
      expect(detected).toBe('zen');
    } finally {
      delete (globalThis as { browser?: unknown }).browser;
    }
  });

  test('reads Zen from the hidden info.zen field even when the name and user agent look like Chrome', async () => {
    const runtime = {
      getBrowserInfo: async () => ({
        name: 'Firefox',
        vendor: 'Mozilla',
        version: '156.0.1',
        zen: { version: '1.22.3b' },
      }),
    };
    Object.assign(globalThis, { browser: { runtime } });
    try {
      const detected = await readInstalledHistoryBrowser({
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15) AppleWebKit/537.36 Chrome/146.0.0.0 Safari/537.36',
        userAgentData: { brands: [{ brand: 'Google Chrome' }, { brand: 'Chromium' }] },
      });
      expect(detected).toBe('zen');
    } finally {
      delete (globalThis as { browser?: unknown }).browser;
    }
  });

  test('reads Floorp from the Gecko browser name when the user agent is plain Firefox', async () => {
    const runtime = {
      getBrowserInfo: async () => ({ name: 'Floorp', vendor: 'Ablaze' }),
    };
    Object.assign(globalThis, { browser: { runtime } });
    try {
      const detected = await readInstalledHistoryBrowser({
        userAgent: 'Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0',
      });
      expect(detected).toBe('floorp');
    } finally {
      delete (globalThis as { browser?: unknown }).browser;
    }
  });
});

describe('history takeover shortcuts', () => {
  test('captures Edge Ctrl+Y without stealing Redo or the overridden Ctrl+H', () => {
    expect(isHistoryTakeoverShortcut('edge', 'other', { ...down, ctrlKey: true, code: 'KeyY' })).toBe(true);
    expect(isHistoryTakeoverShortcut('edge', 'other', { ...down, ctrlKey: true, shiftKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('edge', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('edge', 'mac', { ...down, metaKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('chromium', 'other', { ...down, ctrlKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('chromium', 'mac', { ...down, metaKey: true, code: 'KeyY' })).toBe(false);
  });

  test('captures the history shortcuts of browsers that cannot replace the history page', () => {
    expect(isHistoryTakeoverShortcut('opera', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('opera', 'mac', { ...down, metaKey: true, shiftKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('opera', 'mac', { ...down, metaKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('zen', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('firefox', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('firefox', 'other', { ...down, ctrlKey: true, shiftKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('firefox', 'mac', { ...down, metaKey: true, shiftKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('firefox', 'mac', { ...down, metaKey: true, shiftKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('vivaldi', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('vivaldi', 'other', { ...down, ctrlKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('vivaldi', 'mac', { ...down, metaKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('vivaldi', 'mac', { ...down, metaKey: true, shiftKey: true, code: 'KeyY' })).toBe(false);
    expect(isExtensionHistoryCommandShortcut('mac', { ...down, metaKey: true, shiftKey: true, code: 'KeyY' })).toBe(true);
    expect(isExtensionHistoryCommandShortcut('other', { ...down, ctrlKey: true, shiftKey: true, code: 'KeyY' })).toBe(true);
    expect(isExtensionHistoryCommandShortcut('mac', { ...down, metaKey: true, code: 'KeyY' })).toBe(false);
    expect(isExtensionHistoryCommandShortcut('mac', { ...down, metaKey: true, shiftKey: true, altKey: true, code: 'KeyY' })).toBe(false);
  });
});

describe('history shortcut labels', () => {
  test('uses the shortcut that opens Aira history for each browser and system', () => {
    expect(historyShortcutLabel('chrome', 'other')).toBe('Ctrl+H');
    expect(historyShortcutLabel('brave', 'mac')).toBe('⌘Y');
    expect(historyShortcutLabel('edge', 'other')).toBe('Ctrl+Y');
    expect(historyShortcutLabel('edge', 'mac')).toBe('⌘Y');
    expect(historyShortcutLabel('opera', 'mac')).toBe('⌘⇧H');
    expect(historyShortcutLabel('opera', 'other')).toBe('Ctrl+H');
    expect(historyShortcutLabel('vivaldi', 'mac')).toBe('⌘⇧Y');
    expect(historyShortcutLabel('vivaldi', 'other')).toBe('Ctrl+Shift+Y');
    expect(historyShortcutLabel('firefox', 'other')).toBe('Ctrl+Shift+Y');
    expect(historyShortcutLabel('firefox', 'mac')).toBe('⌘⇧Y');
    expect(historyShortcutLabel('zen', 'mac')).toBe('⌘⇧Y');
    expect(geckoHistoryCommandShortcut('mac')).toBe('Command+Shift+Y');
    expect(geckoHistoryCommandShortcut('other')).toBe('Ctrl+Shift+Y');
    expect(formatAssignedHistoryShortcut('Command+Shift+Y', 'mac')).toBe('⌘⇧Y');
    expect(formatAssignedHistoryShortcut('Ctrl+Shift+Y', 'mac')).toBe('⌘⇧Y');
    expect(formatAssignedHistoryShortcut('Ctrl+Shift+Y', 'other')).toBe('Ctrl+Shift+Y');
    expect(formatAssignedHistoryShortcut('MacCtrl+Shift+Y', 'mac')).toBe('⌃⇧Y');
  });
});

describe('native history page urls', () => {
  test('matches history pages across browser schemes and ignores nearby pages', () => {
    expect(isNativeHistoryPageUrl('chrome://history')).toBe(true);
    expect(isNativeHistoryPageUrl('edge://history/?q=aira')).toBe(true);
    expect(isNativeHistoryPageUrl('brave://history/')).toBe(true);
    expect(isNativeHistoryPageUrl('opera://history')).toBe(true);
    expect(isNativeHistoryPageUrl('vivaldi://history')).toBe(true);
    expect(isNativeHistoryPageUrl('about:history')).toBe(true);
    expect(isNativeHistoryPageUrl('chrome://history-clusters')).toBe(false);
    expect(isNativeHistoryPageUrl('https://example.com/history')).toBe(false);
  });
});
