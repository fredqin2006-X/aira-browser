import { resolveAppResourceText } from '../resources/AppResourceText';
import { BrowserCreateTabOptions, BrowserTabState } from '../tabs/TabManager';
import { BrowserTabsOverviewSectionPolicy } from './tabsOverview/BrowserTabsOverviewSectionPolicy';

export type BrowserTabsOverviewActionSection = 'tabs' | 'privacy';

export type BrowserTabsOverviewDeleteKind = 'close_tabs';
export type BrowserTabsOverviewHomeRevealMotion = 'scale' | 'steady';

export interface BrowserTabsOverviewDeletePlan {
  kind: BrowserTabsOverviewDeleteKind;
  tabIds: string[];
  count: number;
  homeOptions: BrowserCreateTabOptions;
  title: string;
  message: string;
  confirmLabel: string;
  emptyMessage: string;
  helperMessage: string;
  runtimeEventType: string;
  homeRevealMotion: BrowserTabsOverviewHomeRevealMotion;
}

export type BrowserTabsOverviewReturnKind = 'tab' | 'home';

export interface BrowserTabsOverviewReturnPlan {
  kind: BrowserTabsOverviewReturnKind;
  tabId: string;
  homeOptions: BrowserCreateTabOptions;
  helperMessage: string;
}

const REGULAR_HOME_OPTIONS: BrowserCreateTabOptions = {
  profileId: 'profile-main',
  privacyMode: 'regular',
  dataScope: 'profile_persistent'
};

const PRIVATE_HOME_OPTIONS: BrowserCreateTabOptions = {
  profileId: 'profile-main',
  privacyMode: 'private',
  dataScope: 'session_ephemeral'
};

export class BrowserTabsOverviewActionBarPolicy {
  private sectionPolicy: BrowserTabsOverviewSectionPolicy = new BrowserTabsOverviewSectionPolicy();

  buildDeletePlan(
    section: BrowserTabsOverviewActionSection,
    tabs: BrowserTabState[],
    activeTabId: string
  ): BrowserTabsOverviewDeletePlan {
    const targetTabs = this.getTabsForSection(section, tabs);
    const backgroundTabIds = targetTabs
      .filter((tab: BrowserTabState) => tab.id !== activeTabId)
      .map((tab: BrowserTabState) => tab.id);
    const activeTabIds = targetTabs
      .filter((tab: BrowserTabState) => tab.id === activeTabId)
      .map((tab: BrowserTabState) => tab.id);
    const tabIds = backgroundTabIds.concat(activeTabIds);
    const privateSection = section === 'privacy';
    return {
      kind: 'close_tabs',
      tabIds: tabIds,
      count: tabIds.length,
      homeOptions: privateSection ? PRIVATE_HOME_OPTIONS : REGULAR_HOME_OPTIONS,
      title: privateSection
        ? resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_010'))
        : resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_001')),
      message: privateSection
        ? resolveAppResourceText($r('app.string.tabs_burn_confirm', tabIds.length))
        : resolveAppResourceText($r('app.string.tabs_close_regular_confirm', tabIds.length)),
      confirmLabel: privateSection
        ? resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_009'))
        : resolveAppResourceText($r('app.string.ui_close')),
      emptyMessage: privateSection
        ? resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_008'))
        : resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_007')),
      helperMessage: privateSection
        ? resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_003'))
        : resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_002')),
      runtimeEventType: privateSection ? 'private_tabs_closed_all' : 'regular_tabs_closed_all',
      homeRevealMotion: 'steady'
    };
  }

  buildReturnPlan(
    section: BrowserTabsOverviewActionSection,
    tabs: BrowserTabState[],
    activeTabId: string
  ): BrowserTabsOverviewReturnPlan {
    if (section === 'privacy') {
      const tab = this.resolveSelectedTabForSection(section, tabs, activeTabId);
      if (tab !== undefined) {
        return {
          kind: 'tab',
          tabId: tab.id,
          homeOptions: this.buildPrivateHomeOptions(tab),
          helperMessage: resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_005'))
        };
      }
      return {
        kind: 'home',
        tabId: '',
        homeOptions: PRIVATE_HOME_OPTIONS,
        helperMessage: resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_006'))
      };
    }
    const regularTab = this.resolveSelectedTabForSection('tabs', tabs, activeTabId);
    if (regularTab !== undefined) {
      return {
        kind: 'tab',
        tabId: regularTab.id,
        homeOptions: this.buildRegularHomeOptions(regularTab),
        helperMessage: resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_004'))
      };
    }
    return {
      kind: 'home',
      tabId: '',
      homeOptions: REGULAR_HOME_OPTIONS,
      helperMessage: resolveAppResourceText($r('app.string.browser_shell_008'))
    };
  }

  private resolveSelectedTabForSection(
    section: BrowserTabsOverviewActionSection,
    tabs: BrowserTabState[],
    activeTabId: string
  ): BrowserTabState | undefined {
    const sectionTabs = this.getTabsForSection(section, tabs);
    const activeTab = sectionTabs.find((tab: BrowserTabState) => tab.id === activeTabId);
    if (activeTab !== undefined) {
      return activeTab;
    }
    return sectionTabs.slice().sort((left: BrowserTabState, right: BrowserTabState) => {
      if (right.lastActiveAt !== left.lastActiveAt) {
        return right.lastActiveAt - left.lastActiveAt;
      }
      return right.id.localeCompare(left.id);
    })[0];
  }

  private getTabsForSection(section: BrowserTabsOverviewActionSection, tabs: BrowserTabState[]): BrowserTabState[] {
    return this.sectionPolicy.resolveTabsForSection(tabs, section === 'privacy' ? 'privacy' : 'tabs');
  }

  private buildRegularHomeOptions(tab: BrowserTabState): BrowserCreateTabOptions {
    return {
      profileId: tab.profileId,
      privacyMode: 'regular',
      dataScope: 'profile_persistent'
    };
  }

  private buildPrivateHomeOptions(tab: BrowserTabState): BrowserCreateTabOptions {
    return {
      profileId: tab.profileId,
      privacyMode: 'private',
      dataScope: 'session_ephemeral'
    };
  }

}
