import { BrowserLaunchPayload } from '../../app/runtime/BrowserWindowRuntime';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { BrowserCreateTabOptions, BrowserTabState } from '../../core/tabs/TabManager';
import { DesktopWebEntryRecord } from '../../data/webapps/WebAppInstallModels';
import {
  TabReusePolicyService,
  TabReuseMatchReason
} from '../tabs/TabReusePolicyService';

export type DesktopWebEntryLaunchAction = 'invalid' | 'activate_existing_tab' | 'open_launch_url';

export interface DesktopWebEntryLaunchPlan {
  action: DesktopWebEntryLaunchAction;
  targetUrl: string;
  tabId: string;
  options: BrowserCreateTabOptions;
  reuseReason: TabReuseMatchReason;
  message: string;
}

export class DesktopWebEntryLaunchService {
  private tabReusePolicyService: TabReusePolicyService = new TabReusePolicyService();

  buildPlan(
    payload: BrowserLaunchPayload,
    record: DesktopWebEntryRecord | undefined,
    tabs: BrowserTabState[],
    activeTabId: string
  ): DesktopWebEntryLaunchPlan {
    const shortcut = payload.shortcut;
    if (shortcut === undefined) {
      return this.buildInvalidPlan();
    }
    const targetUrl = this.resolveLaunchUrl(record, payload.uri);
    if (targetUrl.length === 0) {
      return this.buildInvalidPlan();
    }
    const launchContext = this.tabReusePolicyService.buildDesktopWebEntryLaunchContext(
      shortcut.shortcutId,
      targetUrl
    );
    const options: BrowserCreateTabOptions = {
      profileId: payload.profileId,
      privacyMode: payload.privacyMode,
      dataScope: payload.dataScope,
      launchContext: launchContext,
      openSource: 'external'
    };
    const entryScopedTabs = this.filterTabsForDesktopEntry(tabs, shortcut.shortcutId);
    const reusable = this.tabReusePolicyService.findReusableTab(entryScopedTabs, {
      targetUrl: targetUrl,
      activeTabId: '',
      boundary: {
        profileId: payload.profileId,
        privacyMode: payload.privacyMode,
        dataScope: payload.dataScope
      },
      launchContext: launchContext
    });
    if (reusable.tab !== undefined) {
      return {
        action: 'activate_existing_tab',
        targetUrl: targetUrl,
        tabId: reusable.tab.id,
        options: options,
        reuseReason: reusable.reason,
        message: resolveAppResourceText($r('app.string.desktop_shortcut_returned'))
      };
    }
    const entryScopedFallback = this.findMostRecentDesktopEntryTab(entryScopedTabs);
    if (entryScopedFallback !== undefined) {
      return {
        action: 'activate_existing_tab',
        targetUrl: targetUrl,
        tabId: entryScopedFallback.id,
        options: options,
        reuseReason: 'launch_source_id',
        message: resolveAppResourceText($r('app.string.desktop_shortcut_returned'))
      };
    }
    return {
      action: 'open_launch_url',
      targetUrl: targetUrl,
      tabId: activeTabId,
      options: options,
      reuseReason: 'none',
      message: payload.action.length > 0
        ? resolveAppResourceText($r('app.string.browser_browser_window_launch_application_008'))
        : resolveAppResourceText($r('app.string.desktop_shortcut_opening'))
    };
  }

  private filterTabsForDesktopEntry(tabs: BrowserTabState[], shortcutId: string): BrowserTabState[] {
    const sourceId = shortcutId.trim();
    if (sourceId.length === 0) {
      return [];
    }
    return tabs.filter((tab: BrowserTabState) => {
      return tab.launchContext.sourceType === 'desktop_web_entry' &&
        tab.launchContext.sourceId === sourceId;
    });
  }

  private resolveLaunchUrl(record: DesktopWebEntryRecord | undefined, payloadUrl: string): string {
    const currentUrl = record?.currentUrl.trim() ?? '';
    if (record?.installState === 'installed' && currentUrl.length > 0) {
      return currentUrl;
    }
    const recordUrl = record?.launchUrl.trim() ?? '';
    if (recordUrl.length > 0) {
      return recordUrl;
    }
    return payloadUrl.trim();
  }

  private findMostRecentDesktopEntryTab(tabs: BrowserTabState[]): BrowserTabState | undefined {
    let selected: BrowserTabState | undefined = undefined;
    tabs.forEach((tab: BrowserTabState) => {
      if (selected === undefined || tab.lastActiveAt > selected.lastActiveAt) {
        selected = tab;
      }
    });
    return selected;
  }

  private buildInvalidPlan(): DesktopWebEntryLaunchPlan {
    return {
      action: 'invalid',
      targetUrl: '',
      tabId: '',
      options: {},
      reuseReason: 'none',
      message: resolveAppResourceText($r('app.string.desktop_shortcut_entry_invalid'))
    };
  }
}
