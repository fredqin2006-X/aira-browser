import { describe, expect, test } from 'vitest';
import { desktopBrowserIdentity } from './deviceTabsClient';

describe('desktop browser identity published to the phone', () => {
  test('keeps Chromium forks distinct from Chrome', () => {
    const chromeLike = 'Mozilla/5.0 Chrome/128.0.0.0 Safari/537.36';
    expect(desktopBrowserIdentity('vivaldi', chromeLike, 'macOS')).toEqual({
      platform: 'macOS',
      browserName: 'Vivaldi',
      browserVersion: '128.0.0.0',
    });
    expect(desktopBrowserIdentity('brave', chromeLike, 'Windows').browserName).toBe('Brave');
    expect(desktopBrowserIdentity('opera', 'Mozilla/5.0 Chrome/128.0 OPR/114.0', 'macOS')).toEqual({
      platform: 'macOS',
      browserName: 'Opera',
      browserVersion: '114.0',
    });
    expect(desktopBrowserIdentity('edge', 'Mozilla/5.0 Chrome/128.0 Edg/128.0.1', 'Windows').browserName).toBe('Edge');
    expect(desktopBrowserIdentity('chrome', chromeLike, 'macOS').browserName).toBe('Chrome');
    expect(desktopBrowserIdentity('firefox', 'Mozilla/5.0 Firefox/135.0', 'Linux').browserName).toBe('Firefox');
  });
});
