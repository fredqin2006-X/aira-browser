import { useEffect, useState } from 'react';
import {
  readInstalledHistoryBrowser,
  resolveHistoryBrowserKind,
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
  if (/Vivaldi\//i.test(userAgent) || brands.some((brand) => /vivaldi/i.test(brand))) {
    return 'vivaldi';
  }
  const detected = resolveHistoryBrowserKind({ userAgent, brands, isBrave: false });
  // Chrome and Edge stay on their own pages even when a later probe is uncertain.
  if (detected === 'chrome' || detected === 'chromium') return 'chrome';
  if (detected === 'edge') return 'edge';
  return detected === 'firefox' ? null : detected;
}
