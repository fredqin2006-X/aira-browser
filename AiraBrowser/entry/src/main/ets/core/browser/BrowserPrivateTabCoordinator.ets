import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  BrowserCreateTabOptions,
  BrowserTabState
} from '../tabs/TabManager';
import {
  DEFAULT_BROWSER_PROFILE_ID
} from '../../common/models/BrowserModels';
import { BrowserProfileBoundaryService } from './BrowserProfileBoundaryService';
import {
  BrowserTabCloseCoordinator
} from './BrowserTabCloseCoordinator';
import { BrowserPrivateModeLockCoordinator } from '../privacy/BrowserPrivateModeLockCoordinator';
import { BrowserPrivateWindowLaunchService } from '../../services/browser/BrowserPrivateWindowLaunchService';
import { BrowserPrivateWindowPolicyService } from '../../services/browser/BrowserPrivateWindowPolicyService';

export interface BrowserPrivateModeEntryPlan {
  options: BrowserCreateTabOptions;
  helperMessage: string;
}

export type BrowserPrivateModeToggleSurface = 'bottom_panel' | 'tabs_overview_mode_button';
export type BrowserPrivateModeToggleTarget = 'confirm_enter_private' | 'confirm_exit_private';
export type BrowserPrivateModeToggleSection = 'tabs' | 'privacy';
export type BrowserPrivateModeConfirmationKind = 'enter_private' | 'exit_private';

export interface BrowserPrivateModeToggleInput {
  surface: BrowserPrivateModeToggleSurface;
  currentBoundaryPrivate?: boolean;
  requestedTabsOverviewSection?: BrowserPrivateModeToggleSection;
}

export interface BrowserPrivateModeTogglePlan {
  target: BrowserPrivateModeToggleTarget;
}

export interface BrowserPrivateModeConfirmationState {
  kind: BrowserPrivateModeConfirmationKind;
  title: string;
  message: string;
  cancelLabel: string;
  confirmLabel: string;
  showClearPrivateDataOption: boolean;
  clearPrivateDataLabel: string;
}

export interface BrowserPrivateModeTogglePresentationHost {
  resolveCurrentBoundaryPrivate: () => boolean;
  resolveTabs: () => BrowserTabState[];
  presentConfirmation: (state: BrowserPrivateModeConfirmationState) => void;
}

export interface BrowserPrivateModeConfirmationHost {
  enterPrivateTabInCurrentWindow: (plan: BrowserPrivateModeEntryPlan) => void;
  isLargeScreenShellActive: () => boolean;
  showMessage: (message: string) => void;
  requestExitPrivateMode: (clearPrivateData: boolean) => void;
}

export interface BrowserPrivateModeExitHost {
  applyTabsAfterPrivateModeExit: (tabs: BrowserTabState[], activeTabId: string) => void;
  showRegularHomeSurface: (helperMessage: string, options: BrowserCreateTabOptions) => void;
  setTabsOverviewSection: (section: BrowserPrivateModeToggleSection) => void;
}

export class BrowserPrivateTabCoordinator {
  private readonly privateModeLockCoordinator: BrowserPrivateModeLockCoordinator;
  private readonly privateWindowLaunchService: BrowserPrivateWindowLaunchService;
  private readonly privateWindowPolicyService: BrowserPrivateWindowPolicyService;
  private profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService();

  constructor(
    privateModeLockCoordinator: BrowserPrivateModeLockCoordinator,
    privateWindowLaunchService: BrowserPrivateWindowLaunchService = new BrowserPrivateWindowLaunchService(),
    privateWindowPolicyService: BrowserPrivateWindowPolicyService = new BrowserPrivateWindowPolicyService()
  ) {
    this.privateModeLockCoordinator = privateModeLockCoordinator;
    this.privateWindowLaunchService = privateWindowLaunchService;
    this.privateWindowPolicyService = privateWindowPolicyService;
  }

  buildPrivateTabCreateOptions(): BrowserCreateTabOptions {
    return {
      profileId: DEFAULT_BROWSER_PROFILE_ID,
      privacyMode: 'private',
      dataScope: 'session_ephemeral'
    };
  }

  buildEnterPrivateModePlan(): BrowserPrivateModeEntryPlan {
    return {
      options: this.buildPrivateTabCreateOptions(),
      helperMessage: resolveAppResourceText($r('app.string.browser_browser_tabs_overview_action_bar_policy_006'))
    };
  }

  buildRegularTabCreateOptions(): BrowserCreateTabOptions {
    return {
      profileId: DEFAULT_BROWSER_PROFILE_ID,
      privacyMode: 'regular',
      dataScope: 'profile_persistent'
    };
  }

  async openPrivateWindow(initialUrl: string = ''): Promise<boolean> {
    try {
      await this.privateWindowLaunchService.openNewPrivateWindow(initialUrl);
      return true;
    } catch (_error) {
      return false;
    }
  }

  buildPrivateModeTogglePlan(input: BrowserPrivateModeToggleInput): BrowserPrivateModeTogglePlan {
    if (input.surface === 'tabs_overview_mode_button') {
      return {
        target: input.requestedTabsOverviewSection === 'privacy' ?
          'confirm_enter_private' : 'confirm_exit_private'
      };
    }
    return {
      target: input.currentBoundaryPrivate === true ? 'confirm_exit_private' : 'confirm_enter_private'
    };
  }

  buildModeSwitchConfirmationState(
    plan: BrowserPrivateModeTogglePlan,
    privateTabCount: number
  ): BrowserPrivateModeConfirmationState {
    if (plan.target === 'confirm_enter_private') {
      return {
        kind: 'enter_private',
        title: resolveAppResourceText($r('app.string.browser_browser_private_tab_coordinator_004')),
        message: resolveAppResourceText($r('app.string.browser_browser_private_tab_coordinator_003')),
        cancelLabel: resolveAppResourceText($r('app.string.settings_custom_home_cancel')),
        confirmLabel: resolveAppResourceText($r('app.string.browser_browser_private_tab_coordinator_004')),
        showClearPrivateDataOption: false,
        clearPrivateDataLabel: ''
      };
    }
    const safePrivateTabCount = Math.max(0, Math.floor(privateTabCount));
    return {
      kind: 'exit_private',
      title: resolveAppResourceText($r('app.string.bottom_panel_exit_private')),
      message: resolveAppResourceText($r('app.string.browser_browser_private_tab_coordinator_005')),
      cancelLabel: resolveAppResourceText($r('app.string.settings_custom_home_cancel')),
      confirmLabel: resolveAppResourceText($r('app.string.bottom_panel_exit_private')),
      showClearPrivateDataOption: true,
      clearPrivateDataLabel: safePrivateTabCount > 0
        ? resolveAppResourceText($r('app.string.private_clear_and_close', safePrivateTabCount))
        : resolveAppResourceText($r('app.string.browser_browser_private_tab_coordinator_002'))
    };
  }

  requestBottomPanelModeToggle(host: BrowserPrivateModeTogglePresentationHost): void {
    const plan = this.buildPrivateModeTogglePlan({
      surface: 'bottom_panel',
      currentBoundaryPrivate: host.resolveCurrentBoundaryPrivate()
    });
    host.presentConfirmation(this.buildModeSwitchConfirmationState(plan, this.countPrivateTabs(host.resolveTabs())));
  }

  async confirmModeSwitch(
    confirmation: BrowserPrivateModeConfirmationState,
    clearPrivateData: boolean,
    host: BrowserPrivateModeConfirmationHost
  ): Promise<void> {
    if (confirmation.kind === 'enter_private') {
      if (host.isLargeScreenShellActive() && this.privateWindowPolicyService.resolveTarget() === 'new_window') {
        if (!await this.openPrivateWindow()) {
          host.showMessage(resolveAppResourceText($r('app.string.browser_browser_private_tab_coordinator_006')));
        }
        return;
      }
      host.enterPrivateTabInCurrentWindow(this.buildEnterPrivateModePlan());
      return;
    }
    host.requestExitPrivateMode(confirmation.showClearPrivateDataOption && clearPrivateData);
  }

  countPrivateTabs(tabs: BrowserTabState[]): number {
    return tabs.filter((tab: BrowserTabState) => this.isPrivateTab(tab)).length;
  }

  async exitPrivateMode(
    tabs: BrowserTabState[],
    activeTabId: string,
    tabCloseCoordinator: BrowserTabCloseCoordinator,
    clearPrivateData: boolean,
    host: BrowserPrivateModeExitHost
  ): Promise<void> {
    const privateTabs = tabs.filter((tab: BrowserTabState) => this.isPrivateTab(tab));
    const privateTabIds = privateTabs.map((tab: BrowserTabState) => tab.id);
    let nextActiveTabId = activeTabId;
    if (clearPrivateData) {
      await tabCloseCoordinator.cleanupPrivateTabsForExit(tabs, activeTabId, privateTabs);
      const remainingTabs = tabs.filter((tab: BrowserTabState) => !privateTabIds.includes(tab.id));
      nextActiveTabId = privateTabIds.includes(activeTabId) ?
        this.resolveNextActiveTabId(remainingTabs) : activeTabId;
      host.applyTabsAfterPrivateModeExit(remainingTabs, nextActiveTabId);
    }
    host.showRegularHomeSurface(resolveAppResourceText($r('app.string.browser_browser_private_tab_coordinator_001')), this.buildRegularTabCreateOptions());
    host.setTabsOverviewSection('tabs');
    this.privateModeLockCoordinator.synchronizeCurrentBoundary();
  }

  private isPrivateTab(tab: BrowserTabState | undefined): boolean {
    if (tab === undefined) {
      return false;
    }
    return this.profileBoundaryService.isSessionEphemeral(
      this.profileBoundaryService.buildBoundaryInput(tab.profileId, tab.privacyMode, tab.dataScope)
    );
  }

  private resolveNextActiveTabId(tabs: BrowserTabState[]): string {
    if (tabs.length === 0) {
      return '';
    }
    return tabs[tabs.length - 1].id;
  }

}
