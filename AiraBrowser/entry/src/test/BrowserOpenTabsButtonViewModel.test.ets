import { describe, expect, it } from '@ohos/hypium';
import { BrowserTabState } from '../main/ets/core/tabs/TabManager';
import { BrowserOpenTabsButtonViewModel } from '../main/ets/core/browser/BrowserOpenTabsButtonViewModel';
import {
  BrowserTabsOverviewBottomChromeViewModel,
  resolveTabsOverviewCloseAllMenuSection
} from '../main/ets/core/browser/tabsOverview/BrowserTabsOverviewBottomChromeViewModel';

function buildTab(id: string, isHome: boolean, privacyMode: 'regular' | 'private'): BrowserTabState {
  const url = isHome ? 'https://home.invalid/' : `https://example.invalid/${id}`;
  return {
    id: id,
    profileId: 'profile-main',
    title: id,
    url: url,
    isHome: isHome,
    lastActiveAt: 1,
    pendingUrl: isHome ? '' : url,
    navigationHistory: isHome ? [] : [url],
    navigationIndex: 0,
    runtimeState: 'suspended',
    lastError: '',
    lastRestoreReason: '',
    lastDiscardReason: '',
    lastCrashReason: '',
    lastLoadedAt: 1,
    webStatePath: '',
    webStateUpdatedAt: 0,
    scrollOffsetY: 0,
    lastGoodUrl: url,
    lastGoodTitle: id,
    lastRestorableUrl: url,
    lastRestorableTitle: id,
    lastRestoreType: 'reload',
    privacyMode: privacyMode,
    dataScope: privacyMode === 'private' ? 'session_ephemeral' : 'profile_persistent',
    launchContext: {
      sourceType: '',
      sourceId: '',
      sourceUrl: '',
      key: ''
    },
    openerTabId: '',
    openSource: '',
    openedByNewWindow: false,
    pinned: false,
    muted: false,
    audible: false
  };
}

export default function browserOpenTabsButtonViewModelTest(): void {
  describe('BrowserOpenTabsButtonViewModel', () => {
    it('counts the same ordinary tabs as the tabs overview middle badge', 0, () => {
      const tabs: BrowserTabState[] = [
        buildTab('home', true, 'regular'),
        buildTab('page-a', false, 'regular'),
        buildTab('page-b', false, 'regular'),
        buildTab('private-a', false, 'private')
      ];
      const buttonCount = new BrowserOpenTabsButtonViewModel().resolveTabCount(tabs);
      const overviewCount = new BrowserTabsOverviewBottomChromeViewModel().buildState({
        tabs: tabs,
        locallyRemovedTabIds: [],
        entryTabId: 'page-a',
        activeTabId: 'page-a'
      }).regularTabCount;

      expect(buttonCount).assertEqual(2);
      expect(overviewCount).assertEqual(buttonCount);
    });

    it('drops a tab the overview has already removed locally', 0, () => {
      const tabs: BrowserTabState[] = [
        buildTab('page-a', false, 'regular'),
        buildTab('page-b', false, 'regular')
      ];
      const overviewCount = new BrowserTabsOverviewBottomChromeViewModel().buildState({
        tabs: tabs,
        locallyRemovedTabIds: ['page-b'],
        entryTabId: 'page-a',
        activeTabId: 'page-a'
      }).regularTabCount;

      expect(overviewCount).assertEqual(1);
    });
  });

  describe('tabs overview close-all menu', () => {
    it('opens only for the local section the user is already viewing', 0, () => {
      expect(resolveTabsOverviewCloseAllMenuSection('privacy', 'privacy')).assertEqual('privacy');
      expect(resolveTabsOverviewCloseAllMenuSection('tabs', 'tabs')).assertEqual('tabs');
      expect(resolveTabsOverviewCloseAllMenuSection('privacy', 'tabs')).assertEqual('');
      expect(resolveTabsOverviewCloseAllMenuSection('tabs', 'privacy')).assertEqual('');
      expect(resolveTabsOverviewCloseAllMenuSection('privacy', 'device')).assertEqual('');
      expect(resolveTabsOverviewCloseAllMenuSection('devices', 'privacy')).assertEqual('');
      expect(resolveTabsOverviewCloseAllMenuSection('devices', 'devices')).assertEqual('');
    });
  });
}
