import { BrowserWebLoadDataPayload } from '../browser/BrowserWebLoadCoordinator';
import { resolveAppResourceText } from '../resources/AppResourceText';

export const SAVED_PAGE_WEB_TAB_URL_PREFIX: string = 'aira://saved-page';

export interface SavedPageWebTabRoute {
  pageId: string;
  dataScope: string;
  privacyMode: string;
  originalUrl: string;
}

export function buildSavedPageWebTabUrl(
  pageId: string,
  dataScope: string,
  privacyMode: string,
  originalUrl: string = ''
): string {
  return `${SAVED_PAGE_WEB_TAB_URL_PREFIX}?id=${encodeURIComponent(pageId)}` +
    `&scope=${encodeURIComponent(dataScope)}` +
    `&privacy=${encodeURIComponent(privacyMode)}` +
    `&origin=${encodeURIComponent(originalUrl)}`;
}

export function isSavedPageWebTabUrl(url: string): boolean {
  return url.trim().startsWith(SAVED_PAGE_WEB_TAB_URL_PREFIX);
}

export function parseSavedPageWebTabUrl(url: string): SavedPageWebTabRoute | undefined {
  const normalizedUrl = url.trim();
  if (!normalizedUrl.startsWith(SAVED_PAGE_WEB_TAB_URL_PREFIX)) {
    return undefined;
  }
  const queryIndex = normalizedUrl.indexOf('?');
  if (queryIndex < 0) {
    return undefined;
  }
  const values = new Map<string, string>();
  normalizedUrl.substring(queryIndex + 1).split('&').forEach((part: string) => {
    const separator = part.indexOf('=');
    if (separator <= 0) {
      return;
    }
    values.set(
      decodeURIComponent(part.substring(0, separator)),
      decodeURIComponent(part.substring(separator + 1))
    );
  });
  const pageId = values.get('id')?.trim() ?? '';
  if (pageId.length === 0) {
    return undefined;
  }
  return {
    pageId: pageId,
    dataScope: values.get('scope')?.trim() ?? 'profile_persistent',
    privacyMode: values.get('privacy')?.trim() ?? 'regular',
    originalUrl: values.get('origin')?.trim() ?? ''
  };
}

export function resolveSavedPageWebTabDisplayUrl(url: string): string {
  const route = parseSavedPageWebTabUrl(url);
  if (route !== undefined && route.originalUrl.length > 0) {
    return route.originalUrl;
  }
  return url;
}

export function buildSavedPageLoadingPayload(url: string): BrowserWebLoadDataPayload {
  const title = resolveAppResourceText($r('app.string.offline_saved_web_loading_title'));
  const message = resolveAppResourceText($r('app.string.offline_saved_web_loading'));
  return {
    data: `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${title}</title></head>` +
      `<body><p>${message}</p></body></html>`,
    mimeType: 'text/html',
    encoding: 'UTF-8',
    baseUrl: url,
    historyUrl: url
  };
}
