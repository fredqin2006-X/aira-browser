import { resolveAppResourceText } from '../../resources/AppResourceText';
import { BrowserTabState } from '../../tabs/TabManager';
import {
  BrowserTabsOverviewSection,
  BrowserTabsOverviewSectionPolicy
} from './BrowserTabsOverviewSectionPolicy';

export type BrowserTabsOverviewBottomChromeReturnKind = 'tab' | 'home';
export type BrowserTabsOverviewCloseAllMenuSection = 'tabs' | 'privacy';

export interface BrowserTabsOverviewBottomChromeInput {
  tabs: BrowserTabState[];
  locallyRemovedTabIds: string[];
  entryTabId: string;
  activeTabId: string;
}

export interface BrowserTabsOverviewBottomChromeState {
  regularTabCount: number;
  regularTabsLabel: string;
  returnKind: BrowserTabsOverviewBottomChromeReturnKind;
  returnTabId: string;
}

export class BrowserTabsOverviewBottomChromeViewModel {
  private sectionPolicy: BrowserTabsOverviewSectionPolicy = new BrowserTabsOverviewSectionPolicy();

  buildState(input: BrowserTabsOverviewBottomChromeInput): BrowserTabsOverviewBottomChromeState {
    const removedTabIds = this.buildRemovedTabIdMap(input.locallyRemovedTabIds);
    const regularTabCount = this.resolveRegularTabCount(input.tabs, removedTabIds);
    const returnTab = this.resolveReturnTab(input, removedTabIds);
    return {
      regularTabCount: regularTabCount,
      regularTabsLabel: resolveAppResourceText($r('app.string.tabs_overview_count', regularTabCount)),
      returnKind: returnTab === undefined || returnTab.isHome ? 'home' : 'tab',
      returnTabId: returnTab === undefined || returnTab.isHome ? '' : returnTab.id
    };
  }

  private resolveRegularTabCount(tabs: BrowserTabState[], removedTabIds: Record<string, boolean>): number {
    return this.sectionPolicy.countVisibleTabs(tabs, 'tabs', removedTabIds);
  }

  private resolveReturnTab(
    input: BrowserTabsOverviewBottomChromeInput,
    removedTabIds: Record<string, boolean>
  ): BrowserTabState | undefined {
    const entryTab = this.findAvailableTab(input.tabs, input.entryTabId, removedTabIds);
    if (entryTab !== undefined) {
      return entryTab;
    }
    return this.findAvailableTab(input.tabs, input.activeTabId, removedTabIds);
  }

  private findAvailableTab(
    tabs: BrowserTabState[],
    tabId: string,
    removedTabIds: Record<string, boolean>
  ): BrowserTabState | undefined {
    const normalizedTabId = tabId.trim();
    if (normalizedTabId.length <= 0 || removedTabIds[normalizedTabId] === true) {
      return undefined;
    }
    for (let index = 0; index < tabs.length; index += 1) {
      if (tabs[index].id === normalizedTabId) {
        return tabs[index];
      }
    }
    return undefined;
  }

  private buildRemovedTabIdMap(tabIds: string[]): Record<string, boolean> {
    const removedTabIds: Record<string, boolean> = {};
    for (let index = 0; index < tabIds.length; index += 1) {
      const tabId = tabIds[index].trim();
      if (tabId.length > 0) {
        removedTabIds[tabId] = true;
      }
    }
    return removedTabIds;
  }
}

/**
 * A long press offers to close the section the user is already looking at.
 * Pressing another segment must not close tabs that are not on screen, and the
 * cross-device segment never closes local tabs.
 */
export function resolveTabsOverviewCloseAllMenuSection(
  selectedSection: BrowserTabsOverviewSection,
  pressedSegment: string
): BrowserTabsOverviewCloseAllMenuSection | '' {
  if (selectedSection !== 'tabs' && selectedSection !== 'privacy') {
    return '';
  }
  if (pressedSegment !== selectedSection) {
    return '';
  }
  return selectedSection;
}
