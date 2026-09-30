/**
 * Which brand mark the online-device row should draw. `generic` is the
 * Chromium mark, used when the published name is Chromium or not one we have.
 */
export type CrossDeviceBrowserIconKind =
  'chrome' |
  'edge' |
  'firefox' |
  'floorp' |
  'librewolf' |
  'waterfox' |
  'brave' |
  'opera' |
  'vivaldi' |
  'zen' |
  'generic';

/**
 * The phone only knows the name the desktop published. Older builds sent
 * "Google Chrome" / "Microsoft Edge"; current builds send "Chrome" / "Edge".
 * Chromium is not Chrome. An unknown name uses that same Chromium mark as the fallback.
 */
export function resolveCrossDeviceBrowserIconKind(browserName: string, deviceName: string = ''): CrossDeviceBrowserIconKind {
  const source = `${browserName} ${deviceName}`.trim().toLowerCase();
  if (source.length === 0) {
    return 'generic';
  }
  if (source.includes('vivaldi')) {
    return 'vivaldi';
  }
  if (source.includes('brave')) {
    return 'brave';
  }
  if (source.includes('opera')) {
    return 'opera';
  }
  if (source.includes('edge')) {
    return 'edge';
  }
  if (source.includes('zen')) {
    return 'zen';
  }
  if (source.includes('floorp')) {
    return 'floorp';
  }
  if (source.includes('librewolf')) {
    return 'librewolf';
  }
  if (source.includes('waterfox')) {
    return 'waterfox';
  }
  if (source.includes('firefox')) {
    return 'firefox';
  }
  if (source.includes('chromium')) {
    return 'generic';
  }
  if (source.includes('chrome')) {
    return 'chrome';
  }
  return 'generic';
}
