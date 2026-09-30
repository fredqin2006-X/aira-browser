import { useEffect, useState } from 'react';
import {
  detectHistoryBrowserKind,
  readInstalledHistoryBrowser,
  vivaldiFromExtensionClientHints,
  type HistoryBrowserKind,
} from '@/features/history-takeover/historyTakeoverPolicy';
import { resolveHistorySkin } from './skins/registry';

export function HistorySurface() {
  const [kind, setKind] = useState<HistoryBrowserKind | null>(() => initialHistoryBrowserKind());

  useEffect(() => {
    let disposed = false;
    void readInstalledHistoryBrowser().then((detected) => {
      if (!disposed) setKind(detected);
    });
    return () => {
      disposed = true;
    };
  }, []);

  if (!kind) return null;
  const Skin = resolveHistorySkin(kind);
  return <Skin />;
}

type ClientHintsNavigator = Navigator & {
  userAgentData?: { brands?: Array<{ brand?: string }>; platform?: string };
};

function initialHistoryBrowserKind(): HistoryBrowserKind | null {
  const navigatorObject = globalThis.navigator as ClientHintsNavigator | undefined;
  const userAgent = navigatorObject?.userAgent || '';
  const brands = navigatorObject?.userAgentData?.brands?.map((item) => String(item?.brand || '')) || [];
  // Vivaldi masks itself as Chrome. The extension page is the one place that
  // still gives a usable signal before the async tab probe returns.
  if (vivaldiFromExtensionClientHints({
    protocol: globalThis.location?.protocol,
    userAgent,
    brands,
    platform: navigatorObject?.userAgentData?.platform,
  })) {
    return 'vivaldi';
  }
  const detected = detectHistoryBrowserKind(userAgent);
  // Chrome-like and Firefox-like user agents can still be Brave, Zen, or Vivaldi
  // until their own browser signal is read.
  return detected === 'chromium' || detected === 'firefox' || detected === 'chrome' ? null : detected;
}
