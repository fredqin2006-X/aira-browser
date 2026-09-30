import type { ComponentType } from 'react';
import type { HistoryBrowserKind } from '@/features/history-takeover/historyTakeoverPolicy';
import { BraveHistoryPage } from './brave/BraveHistoryPage';
import { ChromeHistoryPage } from './chrome/ChromeHistoryPage';
import { EdgeHistoryPage } from './edge/EdgeHistoryPage';
import { FirefoxHistoryPage } from './firefox/FirefoxHistoryPage';
import { VivaldiHistoryPage } from './vivaldi/VivaldiHistoryPage';
import { ZenHistoryPage } from './zen/ZenHistoryPage';

// Add a browser by dropping its page into its own folder and registering it here.
// Floorp, LibreWolf, and Waterfox keep Firefox's Places history, so they share that surface.
// An unrecognized browser uses the Chrome history surface.
const HISTORY_SKINS: Partial<Record<HistoryBrowserKind, ComponentType>> = {
  brave: BraveHistoryPage,
  chrome: ChromeHistoryPage,
  edge: EdgeHistoryPage,
  firefox: FirefoxHistoryPage,
  floorp: FirefoxHistoryPage,
  librewolf: FirefoxHistoryPage,
  waterfox: FirefoxHistoryPage,
  vivaldi: VivaldiHistoryPage,
  zen: ZenHistoryPage,
};

export function resolveHistorySkin(kind: HistoryBrowserKind): ComponentType {
  return HISTORY_SKINS[kind] ?? ChromeHistoryPage;
}
